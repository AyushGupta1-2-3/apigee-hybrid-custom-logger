<!--
 Copyright 2026 Google LLC

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->

# NAS Sink - Fluentd Processing Pipeline

This document explains how logs are processed and transformed specifically for the NAS (Network Attached Storage) sink.

## Fluentd Processing Pipeline

Each log entry goes through a series of transformations to ensure it is standardized and enriched. Below is the step-by-step journey of a single log line:

### 1. Input (Source)
The `tail` plugin reads a raw line from the CRI log file.
- **State**: `2024-03-15T12:00:00Z stdout F {"level":"error","message":"disk full"}`

### 2. Metadata Enrichment
The `kubernetes_metadata` filter injects cluster-specific context.
- **Added Fields**: `kubernetes.pod_name`, `kubernetes.namespace_name`, `kubernetes.labels.app`, etc.

### 3. Parsing
The `parser` filter extracts the application payload from the `log` field (supports JSON and klog).
- **New Fields**: `level: "error"`, `message: "disk full"` (if JSON) or `level_klog`, `msg_val` (if klog).
- **Note**: Currently supported formats for automated parsing are JSON, klog and logfmt.

### 4. Normalization
The `record_transformer` maps various field names to a standard set (e.g., `sev_val`, `msg_val`).
- **State**: `sev_val: "ERROR"`, `msg_val: "disk full"`, `res_pod: "apigee-runtime-abc"`

### 5. Filtering
The `grep` filter checks the `sev_val` against a whitelist (e.g., `ERROR`, `WARN`).
- **Action**: Keep or Drop the record.

### 6. Packaging
The final `record_transformer` compiles the standardized fields into a single JSON object called `final_payload`.
- **State**: `final_payload: {"resource":{...}, "message":"...", "severity":"...", "timestamp":"..."}`

### 7. Output
The `match` plugin writes the `final_payload` to the NAS mounting point using a directory structure based on date and namespace.

## Step-by-Step Transformation Trace

To better understand the pipeline, let's trace a single error log from an Apigee Runtime container.

### Phase 1: Raw Container Log (on Node)
The log exists in a file like `/var/log/containers/apigee-runtime-xyz.log`:
```text
2026-03-12T03:28:10.653Z stdout F {"level":"INFO","message":"Keep alive is false...","severity":"INFO","logger":"HTTP.SERVER"}
```

### Phase 2: After Input & Metadata (Steps 1 & 2)
Fluentd reads the line and enriches it with Kubernetes context.
```json
{
  "time": "2026-03-12T03:28:10.653Z",
  "stream": "stdout",
  "log": "{\"level\":\"INFO\",\"message\":\"Keep alive is false...\",\"severity\":\"INFO\"}",
  "kubernetes": {
    "namespace_name": "apigee",
    "pod_name": "apigee-runtime-xyz",
    "container_name": "apigee-runtime",
    "host": "gke-node-1",
    "labels": { "app": "apigee-runtime" }
  }
}
```

### Phase 3: After Parsing (Step 3)
The inner JSON is extracted.
```json
{
  "level": "INFO",
  "message": "Keep alive is false...",
  "severity": "INFO",
  "kubernetes": { ... }
}
```

### Phase 4: After Normalization (Step 4)
Fields are standardized.
```json
{
  "res_ns": "apigee",
  "res_pod": "apigee-runtime-xyz",
  "res_cont": "apigee-runtime",
  "res_node": "gke-node-1",
  "msg_val": "Keep alive is false...",
  "sev_val": "INFO",
  "time_val": "2026-03-12T03:28:10.653000Z",
  "k8s_ns": "apigee",
  "k8s_app": "apigee-runtime"
}
```

### Phase 5: Final Packaging (Step 6)
```json
{
  "final_payload": "{\"resource\":{\"namespace\":\"apigee\",\"pod\":\"...\"},\"message\":\"Keep alive is false...\",\"severity\":\"INFO\",\"timestamp\":\"...\"}"
}
```

## Data Transformation & Field Mapping

The following table details how fields are transformed from the raw source to the final package.

### 1. Source Fields (Input)
These fields are available after **Step 2 (Enrichment)**.

| Field | Source | Description |
| :--- | :--- | :--- |
| `time` | CRI | Log timestamp from the container runtime. |
| `stream` | CRI | Log stream (stdout or stderr). |
| `log` | CRI | The raw log string (JSON, klog, or plain text). |
| `kubernetes.namespace_name` | K8s API | The namespace where the pod is running. |
| `kubernetes.pod_name` | K8s API | The name of the pod. |
| `kubernetes.container_name` | K8s API | The name of the container. |
| `kubernetes.labels.app` | K8s API | The 'app' label assigned to the pod. |

### 2. Standardized Fields (Intermediate)
Calculated in **Step 4 (Transformation)** for internal consistency.

| Field | Source Logic | Purpose |
| :--- | :--- | :--- |
| `msg_val` | `record['message'] \|\| record['log']` | The extracted message body. |
| `sev_val` | Level mapping (JSON level or klog [IWEF]) | Normalized severity (INFO, WARN, ERROR, FATAL). |
| `res_pod` | `kubernetes.pod_name` | Resource identifier for the final JSON. |
| `k8s_app` | `labels['app'] \|\| labels['name']` | Application name used for file path logic. |

### 3. Final Payload (Output)
The structure of the JSON string written to the NAS share.

| Field | Path | Description |
| :--- | :--- | :--- |
| `resource.namespace` | `.resource.namespace` | K8s namespace. |
| `resource.pod` | `.resource.pod` | K8s pod name. |
| `resource.container` | `.resource.container` | K8s container name. |
| `resource.node` | `.resource.node` | K8s node name (host). |
| `message` | `.message` | The processed log message content. |
| `severity` | `.severity` | Normalized log level (e.g., ERROR). |
| `timestamp` | `.timestamp` | ISO8601 formatted timestamp. |

### Case 2: klog Format (cert-manager)
**Raw Log (from node):**
```text
I0316 05:05:35.347703 1 reconciler.go:141] "Updated object" logger="cert-manager" name="cert-manager-webhook"
```

**Final Processed Log (on NAS):**
```json
{
  "resource": {
    "namespace": "cert-manager",
    "pod": "cert-manager-abc",
    "container": "cert-manager",
    "node": "gke-node-1"
  },
  "message": "\"Updated object\" logger=\"cert-manager\" name=\"cert-manager-webhook\"",
  "severity": "INFO",
  "timestamp": "2026-03-16T05:05:35.347703Z"
}
```

### Case 3: logfmt Format (Node Exporter)
**Raw Log (from node):**
```text
2026-03-12T03:26:22.182Z stdout F ts=2026-03-12T03:26:22.182Z caller=node_exporter.go:117 level=info collector=zfs
```

**Final Processed Log (on NAS):**
```json
{
  "resource": {
    "namespace": "monitoring",
    "pod": "prometheus-node-exporter-abc",
    "container": "node-exporter",
    "node": "gke-node-1"
  },
  "message": "collector=zfs",
  "severity": "INFO",
  "timestamp": "2026-03-12T03:26:22.182000Z"
}
```

## Verification & Troubleshooting

To verify that logs are flowing correctly to your NAS storage, follow the detailed steps in the **[Verification & Testing Guide](../../../docs/verification-guide.md)**.

**Quick Checks:**
- **From Pod**: `kubectl exec -it <pod-name> -n platform-ops -- ls -lrt <YOUR_NAS_MOUNT_PATH>`
- **Write Test**: `kubectl exec -it <pod-name> -n platform-ops -- touch <YOUR_NAS_MOUNT_PATH>/test.txt`
- **Check Logs**: `kubectl logs -n platform-ops -l app=fluentd-daemonset`
