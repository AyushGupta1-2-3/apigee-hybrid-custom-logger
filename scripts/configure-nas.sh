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
NAS_IP=$1
NAS_SHARE=$2
MOUNT_PATH=${3:-/mnt/nas-logs}

if [ -z "$NAS_IP" ] || [ -z "$NAS_SHARE" ]; then
    echo "Usage: $0 <NAS_IP_ADDRESS> <NAS_SHARE_NAME> [INTERNAL_MOUNT_PATH]"
    echo "Example: $0 10.226.29.34 /vol1 /mnt/nas-logs"
    exit 1
fi

# Ensure NAS_SHARE and MOUNT_PATH start with /
[[ $NAS_SHARE != /* ]] && NAS_SHARE="/$NAS_SHARE"
[[ $MOUNT_PATH != /* ]] && MOUNT_PATH="/$MOUNT_PATH"

DS_TEMPLATE="k8s/sinks/nas/daemonset.yaml.template"
DS_OUTPUT="k8s/sinks/nas/daemonset.yaml"
CM_OUTPUT="k8s/sinks/nas/configmap.yaml"
JN_TEMPLATE="k8s/sinks/nas/janitor.yaml.template"
JN_OUTPUT="k8s/sinks/nas/janitor.yaml"

if [ -z "$NAS_IP" ] || [ -z "$NAS_SHARE" ]; then
    echo "Usage: $0 <NAS_IP_ADDRESS> <NAS_SHARE_NAME> [INTERNAL_MOUNT_PATH]"
    echo "Example: $0 10.226.29.34 /vol1 /mnt/nas-logs"
    exit 1
fi

# Detect OS for sed compatibility
OS="$(uname)"
SED_CMD="sed -i"
if [ "$OS" == "Darwin" ]; then
    SED_CMD="sed -i ''"
fi

# 1. Process DaemonSet
if [ -f "$DS_TEMPLATE" ]; then
    cp "$DS_TEMPLATE" "$DS_OUTPUT"
    eval "$SED_CMD \"s/<YOUR_NFS_SERVER_IP>/$NAS_IP/g\" $DS_OUTPUT"
    eval "$SED_CMD \"s|<YOUR_NFS_SHARE_NAME>|$NAS_SHARE|g\" $DS_OUTPUT"
    eval "$SED_CMD \"s|<YOUR_NAS_MOUNT_PATH>|$MOUNT_PATH|g\" $DS_OUTPUT"
    echo "Successfully generated $DS_OUTPUT"
else
    echo "Warning: $DS_TEMPLATE not found"
fi

# 2. Process ConfigMap
if [ -f "$CM_TEMPLATE" ]; then
    cp "$CM_TEMPLATE" "$CM_OUTPUT"
    eval "$SED_CMD \"s|<YOUR_NAS_MOUNT_PATH>|$MOUNT_PATH|g\" $CM_OUTPUT"
    echo "Successfully generated $CM_OUTPUT"
else
    echo "Warning: $CM_TEMPLATE not found"
fi

# 3. Process Janitor CronJob
if [ -f "$JN_TEMPLATE" ]; then
    cp "$JN_TEMPLATE" "$JN_OUTPUT"
    eval "$SED_CMD \"s|<YOUR_NAS_IP>|$NAS_IP|g\" $JN_OUTPUT"
    eval "$SED_CMD \"s|<YOUR_NAS_PATH>|$NAS_SHARE|g\" $JN_OUTPUT"
    echo "Successfully generated $JN_OUTPUT"
else
    echo "Warning: $JN_TEMPLATE not found"
fi

echo "Configuration Summary:"
echo "  NAS server IP: $NAS_IP"
echo "  NAS share path (Remote): $NAS_SHARE"
echo "  NAS mount point (Local): $MOUNT_PATH"
echo "Note: This file is ignored by Git to keep your internal IP private."
