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

# Verification and Testing Guide

Since this solution involves infrastructure components, testing should be performed in a non-production Kubernetes environment. Follow these steps to verify the complete solution.

## 1. Syntax & Manifest Validation
Before applying to the cluster, validate the YAML syntax:

```bash
# Validate RBAC
kubectl apply --dry-run=client -f k8s/base/rbac.yaml

# Validate NAS Sink
kubectl apply --dry-run=client -f k8s/sinks/nas/configmap.yaml
kubectl apply --dry-run=client -f k8s/sinks/nas/daemonset.yaml
```

## 2. Deployment Verification
After applying the manifests, verify that the Fluentd pods are running correctly:

```bash
# Check Pod status
kubectl get pods -n platform-ops -l app=fluentd-daemonset

# Check Fluentd logs for startup errors (e.g., config errors, mounting issues)
kubectl logs -n platform-ops -l app=fluentd-daemonset
```

## 3. NAS Storage Verification Methods

### Method 1: Verification from inside a Fluentd Pod
This is the easiest way to check if the NFS mount is working and if Fluentd has permission to write files.

1. **Find the pod name**:
   ```bash
   kubectl get pods -n platform-ops -l app=fluentd-daemonset
   ```

2. **Exec into one of the pods**:
   ```bash
   kubectl exec -it <pod-name> -n platform-ops -- sh
   ```

3. **Navigate to the mount point and list files**:
   ```bash
   cd /mnt/nas-logs
   ls -lrt
   ```
   *Check for the date-based folder structure defined in your config (e.g., 2026-03-15/).*

4. **Tail a specific log file to see the content**:
   ```bash
   # Replace with an actual file found in your LS command
   tail -f 2026-03-15/default_my-app_node-1.log
   ```

**Pro-Tip: Testing Write Permissions**
If you are inside the pod and want to do a quick manual test, run:
```bash
touch /mnt/nas-logs/test-write.txt
```
If this command succeeds without an error, the mount is healthy.

### Method 2: Verification from the NFS Server
If you have SSH access to the NAS server itself (e.g., `10.172.239.194`), you can verify the files directly on the source disk.

1. **SSH into the NAS server**.
2. **Navigate to the exported path**:
   ```bash
   cd /vol1
   ls -alh
   ```
   If you see the files here, the network connection and permissions are 100% correct.

#### Option: Using a Support/Bastion VM
If you don't have direct access to the NAS, you can create a "debug" instance in the same VPC to browse the logs.

1. **SSH into a Linux VM** in the same VPC as your Filestore:
   ```bash
   gcloud compute ssh [VM_NAME] --zone [ZONE]
   ```
2. **Install the NFS client**:
   ```bash
   sudo apt-get update && sudo apt-get install nfs-common -y
   ```
3. **Mount the NAS to a local folder**:
   ```bash
   sudo mkdir -p /mnt/nas-verify
   # Replace with your Filestore IP and Share Name
   sudo mount 10.172.239.194:/vol1 /mnt/nas-verify
   ```
4. **Explore your files**:
   ```bash
   cd /mnt/nas-verify
   ls -R
   ```

### Method 3: Troubleshoot using Fluentd Logs
If you don't see any files in `/mnt/nas-logs`, check Fluentd's internal logs for errors.

```bash
kubectl logs -f <pod-name> -n platform-ops
```

**Common things to look for:**
- `[warn]: /mnt/nas-logs/... Permission denied`: This means the NFS export doesn't allow the user (UID 0/root) to write. Ensure `no_root_squash` is enabled on the NFS server.
- `[error]: failed to flush the buffer`: This indicates a network connection issue between the Kubernetes node and the NAS IP.

## 4. GCP Filestore Specific Steps

If you are using **Google Cloud Filestore** as your NAS sink, follow these steps to ensure connectivity:

### A. Networking & VPC
1. **Same VPC**: Ensure your Filestore instance and GKE cluster are in the same VPC network.
2. **IP Range**: Note the "reserved IP range" of your Filestore instance; it must not overlap with your GKE pod or services CIDR.

### B. Firewall Rules
Ensure there is a firewall rule allowing traffic on the NFS port (**2049**) within your VPC:
```bash
gcloud compute firewall-rules create allow-nfs-internal \
    --network=[VPC_NAME] \
    --allow=tcp:2049,udp:2049 \
    --source-ranges=[GKE_NODE_CIDR]
```

### C. Retrieve Filestore Details
Get the IP and Share Name via gcloud:
```bash
gcloud filestore instances list
# Note the 'IP_ADDRESS' and 'FILE_SHARE_NAME'
```

### D. Verification from GKE
Run a temporary pod to test the mount directly without the DaemonSet:
```bash
kubectl run nfs-test --image=busybox --restart=Never -- /bin/sh -c "sleep 3600"
# (Wait for pod to be ready)
# Then follow Method 1 to exec and test 'mount' logic manually if needed.
```
