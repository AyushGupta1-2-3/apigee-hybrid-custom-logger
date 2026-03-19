# Apigee Hybrid Custom Logger - Test Suite

This directory contains the testing infrastructure for the custom logging solution.

## Test Types

### 1. Integration Tests (`tests/integration/`)
These tests validate the end-to-end log processing pipeline using a native Ruby simulation of the Fluentd engine. They ensure that raw Kubernetes logs (CRI format) are correctly parsed, enriched, and transformed into the final standardized JSON format.

**Key Features:**
- **Golden File Testing**: Results are compared against expected JSON "golden files" in `fixtures/output/`.
- **High Fidelity**: The test engine uses the exact same regex patterns and Ruby logic defined in the production `ConfigMap`.
- **Zero Dependencies**: Requires only Ruby (pre-installed on most systems), with no need for a running Kubernetes cluster or Docker.

### 2. Generic Tests
Currently, the focus is on integration testing of the log parsing logic, which is the core of the custom logger's functionality. Generic tests for script utilities and manifest validation are primarily handled via `kubectl --dry-run`.

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
