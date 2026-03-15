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

## 3. Storage Connectivity Test
Ensure the DaemonSet can successfully mount the NAS/NFS share:

```bash
# Exec into a fluentd pod
kubectl exec -it $(kubectl get pods -n platform-ops -l app=fluentd-daemonset -o jsonpath='{.items[0].metadata.name}') -n platform-ops -- ls -lh /mnt/nas-logs
```

## 4. End-to-End Log Flow Test
To verify the entire pipeline (Parsing -> Transformation -> Output), you can inject a mock log file into a container's log path or simply trigger an error in an existing application.

### Verification Script
Run this script on a node or as a temporary pod to test the parsing:

```bash
# 1. Identify a container log path on the node
LOG_PATH=$(kubectl get pod <TARGET_POD> -o jsonpath='{.status.containerStatuses[0].containerID}' | sed 's|cri-containerd://||')
# Note: Real path is usually /var/log/pods/... or /var/log/containers/...

# 2. Check the NAS directory for the corresponding output
# Path format: /mnt/nas-logs/YYYY-MM-DD/namespace_app_node/
ls -R /mnt/nas-logs/$(date +%Y-%m-%d)/
```

## 5. Troubleshooting Common Issues
- **MountVolume.SetUp failed**: Check NFS server IP and export path in `daemonset.yaml`.
- **Permission Denied**: Ensure the NAS share allows writes from the Kubernetes node IPs.
- **Config error**: Check Fluentd logs; a common issue is missing plugins (this image uses `fluent/fluentd-kubernetes-daemonset:v1.16-debian-nfs-1` which includes most required plugins).
