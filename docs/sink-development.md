# Sink Development Guide

This guide explains how to add a new log destination (sink) to the Apigee Hybrid Custom Logger project.

## Overview
A sink is a target destination for logs processed by Fluentd. Examples include Elasticsearch, Kafka, Splunk, or a simple NAS/NFS share.

## Directory Structure
Each sink should live in its own directory under `k8s/sinks/`:
```
k8s/sinks/
└── your-sink-name/
    ├── configmap.yaml  # Fluentd configuration for output
    └── daemonset.yaml  # DaemonSet definition (mounts, env vars)
```

## Step-by-Step Implementation

### 1. Define the ConfigMap
Your `configmap.yaml` should contain the `<match>` section for your destination. It should also include the base parsing and filtering logic (you can copy this from the NAS sink and modify only the output section).

Key considerations:
- Use placeholders for sensitive information (e.g., `<YOUR_ELASTICSEARCH_HOST>`).
- Ensure the `final_payload` is used appropriately.

### 2. Define the DaemonSet
Your `daemonset.yaml` should include any necessary:
- **Environment Variables**: For credentials or hostnames.
- **Volume Mounts**: For local caching or mounting persistent storage.
- **Resource Requests/Limits**: Tailored to the sink's performance needs.

### 3. Testing
Before submitting a PR, ensure that:
- The YAML files are syntactically correct.
- Placeholders are clearly marked.
- You have documented any sink-specific prerequisites.

### 4. Documentation
Update the main `README.md` to include your sink in the "Supported Destinations" list.

## Sink Template
You can use the [NAS sink](../k8s/sinks/nas/) as a reference implementation.
