# Apigee Hybrid Custom Logger - Test Suite

This directory contains the testing infrastructure for the custom logging solution.

## Test Types

### 1. Integration Tests (`tests/integration/`)
These tests validate the end-to-end log processing pipeline using a native Ruby simulation of the Fluentd engine. They ensure that raw Kubernetes logs (CRI format) are correctly parsed, enriched, and transformed into the final standardized JSON format.

**Key Features:**
- **Golden File Testing**: Results are compared against expected JSON "golden files" in `fixtures/output/`.
- **High Fidelity**: The test engine uses the exact same regex patterns and Ruby logic defined in the production `ConfigMap`.
- **Zero Dependencies**: Requires only Ruby (pre-installed on most systems), with no need for a running Kubernetes cluster or Docker.

### 2. Live Environment Testing
In addition to local integration tests, you can test the logger directly in a Kubernetes cluster.

**Testing the Catch-all Parser (Plain Text):**
To verify that Fluentd successfully captures and parses unstructured plain text logs that don't match specific formats, create a temporary pod in your cluster:

```bash
# 1. Generate a live unstructured log message
kubectl run test-catchall --image=busybox --restart=Never -- /bin/sh -c "echo 'This is a LIVE unformatted test message for the catch-all parser' && sleep 3600"

# 2. Exec into your fluentd pod and navigate to today's NAS mount folder
kubectl exec -it <YOUR_FLUENTD_POD_NAME> -n platform-ops -- sh
cd /mnt/nas-logs/$(date +%Y-%m-%d)

# 3. Find the log file and verify its contents
cat default_test-catchall_*.log
```

The output should correctly format your plain text message into the standard JSON structure with the default `INFO` severity. 

**Cleanup:**
```bash
kubectl delete pod test-catchall
```

---

## How to Run

### Prerequisites
- **Ruby**: Ensure Ruby 2.x+ is installed on your system.
  ```bash
  ruby -v
  ```

### Execution
Run the test runner script from the project root:
```bash
./tests/integration/run.sh
```

## Adding New Test Cases

1. **Add Input Sample**: Create a new `.log` file in `tests/integration/fixtures/input/`. This file must be in standard **CRI format** (e.g., `2026-03-12T03:28:10.653Z stdout F <YOUR_LOG_MESSAGE>`).
2. **Run Tests**: Execute `./tests/integration/run.sh`. The script will detect the new input and generate a corresponding "golden" JSON file in `tests/integration/fixtures/output/`.
3. **Verify & Commit**: Open the generated `.json` file, verify the field extraction is correct, and commit both the input `.log` and output `.json` files to the repository.
