# CI/CD Workflow Guide

This repository now includes both CI/CD options:

- GitHub Actions: `.github/workflows/ci-cd.yml`
- GitLab CI: `.gitlab-ci.yml`

Both pipelines implement:

- Code checkout
- Dependency caching (`npm` / `maven` / `pip`)
- Linting
- Trivy security scan with fail gate on `HIGH,CRITICAL`
- Docker build
- Docker Hub push with semantic tags (`sha-...`, `v1.0.x`) and **no `latest` tag**
- Continuous Delivery to `Docker Swarm` or `Kubernetes`

## Required Configuration

### Shared variables (adjust in workflow file or CI variables)

- `APP_DIR`: application directory to build
- `PACKAGE_MANAGER`: `npm` | `maven` | `pip`
- `ORCHESTRATOR`: `swarm` | `kubernetes`
- `DOCKER_IMAGE`: e.g. `yourdockerhubuser/final-tier4-app`

### Docker Hub secrets

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

### Swarm deployment secrets

- `SWARM_MANAGER_HOST`
- `SWARM_MANAGER_USER`
- `SWARM_SSH_PRIVATE_KEY`
- `SWARM_SERVICE_NAME`

### Kubernetes deployment secrets

- `KUBECONFIG_B64`
- `K8S_NAMESPACE`
- `K8S_DEPLOYMENT_NAME`
- `K8S_CONTAINER_NAME`

## Tag strategy

- `sha-<short_commit_sha>`
- `v1.0.<pipeline_or_run_number>`
- Optional release tag passthrough when git tag matches `vX.Y.Z`
