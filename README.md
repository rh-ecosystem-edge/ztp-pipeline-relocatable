# ztp-pipeline-relocatable

This Repository contains a pipeline using GitHub Actions that can be used to configure a running OpenShift instance (reachable via provided `KUBECONFIG`) to:

- deploy Advanced Cluster Management (ACM) components
- a Registry with mirrored images
- configure spoke clusters into ACM based on the `spokes.yaml` file provided as input
- deploy a mirror in the spoke cluster
- etc
