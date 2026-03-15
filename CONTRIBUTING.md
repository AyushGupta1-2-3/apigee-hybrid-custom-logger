# Contributing to Apigee Hybrid Custom Logger

First off, thank you for considering contributing to this project!

## How Can I Contribute?

### Reporting Bugs
If you find a bug, please create an issue on GitHub. Include:
- A clear title and description.
- Steps to reproduce the bug.
- Any relevant configuration files (redacted).

### Suggesting Enhancements
Enhancement suggestions are welcome! Please open an issue to discuss your ideas.

### Pull Requests
1. Fork the repository.
2. Create a new branch for your feature or fix.
3. Commit your changes with clear messages.
4. Push to your fork and submit a pull request.

## Contributing a New Sink
We encourage contributions for new log destinations! To add a new sink:
1. Create a new directory under `k8s/sinks/<destination-name>`.
2. Provide a `configmap.yaml` and `daemonset.yaml` following the pattern in the NAS sink.
3. Follow the [Sink Development Guide](docs/sink-development.md).
4. Update the `README.md` to list the new destination.

## Style Guide
- Keep Kubernetes manifests clean and logical.
- Comment complex Fluentd configurations.
- Ensure all documentation is clear and easy to follow.

## License
By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
