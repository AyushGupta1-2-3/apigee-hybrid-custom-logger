#!/bin/bash

# Copyright 2026 Google LLC
# Integration Test Runner for Log Formats (Native Ruby Version)

set -e

# Path to the directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

cd "$PROJECT_ROOT"

echo "--------------------------------------------------------"
echo "🚀 Starting Log Integration Tests (Ruby)..."
echo "--------------------------------------------------------"

# Ensure script is executable
chmod +x tests/integration/test_processor.rb

# Run the Ruby processor
ruby tests/integration/test_processor.rb

echo "--------------------------------------------------------"
echo "✨ Integration Tests Completed."
echo "--------------------------------------------------------"
