---
modified: "2022-01-26T10:47:38.831Z"
---

# ztp-pipeline-relocatable

This Repository contains a pipeline using GitHub Actions that can be used to configure a running OpenShift instance (reachable via provided `KUBECONFIG`) to:

- deploy Advanced Cluster Management (ACM) components
- a Registry with mirrored images
- configure spoke clusters into ACM based on the `spokes.yaml` file provided as input
- deploy a mirror in the spoke cluster
- etc

The pipeline has two parts:

- One that deploys the HUB cluster configuration (based on existing requirements, like OCP deployed with ODF and volumes created)
- Another that deploys Spoke clusters based on the configuration

The actual workflow can be checked at the files inside the `.github/workflows/` folder.
