#!/bin/bash

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Configuration script to set the NAS Server IP using a template
# Usage: ./scripts/configure-nas.sh <IP_ADDRESS>

NAS_IP=$1
TEMPLATE="k8s/sinks/nas/daemonset.yaml.template"
OUTPUT="k8s/sinks/nas/daemonset.yaml"

if [ -z "$NAS_IP" ]; then
    echo "Usage: $0 <NAS_IP_ADDRESS>"
    exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
    echo "Error: Template file $TEMPLATE not found."
    exit 1
fi

# Create the output file from the template
cp "$TEMPLATE" "$OUTPUT"

# Detect OS for sed compatibility
OS="$(uname)"

if [ "$OS" == "Darwin" ]; then
    # Mac OS
    sed -i '' "s/<YOUR_NFS_SERVER_IP>/$NAS_IP/g" "$OUTPUT"
else
    # Linux and others
    sed -i "s/<YOUR_NFS_SERVER_IP>/$NAS_IP/g" "$OUTPUT"
fi

echo "Successfully generated $OUTPUT with NAS server IP: $NAS_IP"
echo "Note: This file is ignored by Git to keep your internal IP private."
