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

# GCP Filestore Setup & Integration

This guide provides the commands required to provision a Google Cloud Filestore instance and connect it as a storage sink for your Apigee Hybrid logs.

## 1. Provision Filestore Instance

Run the following command to create a basic Filestore instance. 

> [!IMPORTANT]
> Ensure the `--network` name matches the VPC where your GKE cluster is running.

```bash
gcloud filestore instances create apigee-log-store \
    --project=[PROJECT_ID] \
    --zone=[ZONE] \
    --tier=BASIC_HDD \
    --file-share=name="vol1",capacity=1TiB \
    --network=name="[VPC_NAME]"
```

## 2. Retrieve Instance Details

Once the creation is complete (usually takes 2-5 minutes), retrieve the internal IP address:

```bash
gcloud filestore instances describe apigee-log-store --zone=[ZONE]
# Look for 'ipAddresses' in the output.
```

## 3. Connect to the Logger Sink

Now that you have the **IP Address** and the **Share Name** (`vol1`), use the automation script to configure your manifests.

1. **Configure the IP**:
   ```bash
   ./scripts/configure-nas.sh [FILESTORE_IP]
   ```

2. **Verify the Share Name**:
   Open `k8s/sinks/nas/daemonset.yaml` and ensure the `path` matches your `--file-share=name` (which is `/vol1` in the example above).

## 4. Deploy to GKE

Apply the final manifests to your cluster:

```bash
kubectl apply -f k8s/sinks/nas/configmap.yaml
kubectl apply -f k8s/sinks/nas/daemonset.yaml
```

## 5. Next Steps
Follow the **[Verification Guide](verification-guide.md)** to ensure logs are successfully being written to the new Filestore instance.
