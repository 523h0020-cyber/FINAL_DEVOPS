# CI/CD setup and run guide

This project uses GitHub Actions to run CI, build/push a pinned Docker image, wait for manual production approval, and deploy to Docker Swarm over SSH.

## 1. GitHub environment manual approval

Create a protected GitHub Environment so the `cd` job pauses before deployment.

1. Open your repository on GitHub.
2. Go to `Settings` -> `Environments` -> `New environment`.
3. Name the environment exactly: `production`.
4. Enable `Required reviewers`.
5. Add yourself or the teacher/demo reviewer.
6. Save protection rules.

The workflow job `.github/workflows/ci-cd.yml` uses:

```yaml
environment:
  name: production
  url: https://${{ secrets.DOMAIN_NAME }}
```

GitHub will run CI and image build first. Before the final deploy job, it will show a `Review deployments` approval button.

## 2. Required GitHub secrets

Go to `Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret` and add:

| Secret | Example | Purpose |
| --- | --- | --- |
| `DOCKERHUB_USERNAME` | `your-dockerhub-user` | Docker Hub namespace used for image push. |
| `DOCKERHUB_TOKEN` | `dckr_pat_xxx` | Docker Hub access token for login/push/pull. |
| `SSH_HOST` | `1.2.3.4` | Swarm manager Elastic IP from Terraform output `swarm_manager_elastic_ip`. |
| `SSH_USER` | `ubuntu` | SSH user for the EC2 AMI. |
| `SSH_PRIVATE_KEY` | full private key text | Private key that can SSH to the Swarm manager. |
| `SWARM_SERVICE_NAME` | `app_app` | Docker Swarm service name to update. Check with `docker service ls`. |
| `DOMAIN_NAME` | `523h0020.site` | Domain shown in the deployment environment URL. |

Optional Kubernetes secrets are only needed if you change `ORCHESTRATOR` to `kubernetes`.

## 3. Required server state before CD

On the Swarm manager, the stack and service must already exist at least once. The CD job updates an existing service image.

Run from your local machine after Terraform and Ansible are ready:

```powershell
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml
```

Deploy the application stack once:

```powershell
$env:DOMAIN_NAME="523h0020.site"
$env:DOCKER_IMAGE="your-dockerhub-user/final-tier4-app"
$env:APP_VERSION="v1.0.1"
docker stack deploy -c swarm-stack.yml app --with-registry-auth
```

Check the real service name:

```powershell
docker service ls
```

Use that service name for `SWARM_SERVICE_NAME`, for example `app_app`.

## 4. Monitoring setup

Create the external overlay network if it does not exist:

```powershell
docker network create --driver overlay --attachable monitoring
```

Deploy monitoring with a strong Grafana password and a config version suffix:

```bash
cd monitoring
export DOMAIN_NAME="523h0020.site"
export CONFIG_VERSION=_v1
printf "your-strong-password" | docker secret create grafana_admin_password_v1 -
docker stack deploy -c docker-stack.monitoring.yml monitoring
```

Grafana will auto-provision:

- Prometheus datasource: `http://prometheus:9090`
- Dashboard: `Docker Swarm CPU and RAM Overview`

## 5. How to run CI/CD

### Pull request validation

Open a pull request into `main`:

1. GitHub runs `ci`.
2. It installs dependencies.
3. It runs lint if present.
4. It runs Trivy filesystem scan and fails on `HIGH,CRITICAL`.
5. It does not deploy.

### Production deployment

Push or merge to `main`:

1. `ci` runs.
2. `build_and_push` builds the image.
3. Trivy scans the image and fails on `HIGH,CRITICAL`.
4. Docker Hub receives two tags:
   - `sha-<short_sha>`
   - `v1.0.<github_run_number>`
5. `cd` waits for manual approval in the `production` environment.
6. After approval, GitHub SSHs into the Swarm manager and runs `docker service update` with the new image.

Manual run is also available from `Actions` -> `production-ci-cd` -> `Run workflow`, but deployment only happens for push to `main` with the current workflow condition.

## 6. Verification commands after deploy

Run on the Swarm manager:

```powershell
docker service ls
docker service ps app_app --no-trunc
docker service inspect app_app --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'
curl -I https://523h0020.site
```

Expected results:

- `app_app` has `3/3` replicas.
- Image tag is not `latest`.
- HTTPS returns a valid response.
- Grafana is reachable at `https://grafana.523h0020.site` after DNS is configured.

## 7. Common failures

| Symptom | Fix |
| --- | --- |
| `cd` job does not pause | Check GitHub Environment name is exactly `production` and has required reviewers. |
| SSH deploy fails | Check `SSH_HOST`, `SSH_USER`, `SSH_PRIVATE_KEY`, security group SSH CIDR, and manager EIP. |
| `docker service update` fails | Check `SWARM_SERVICE_NAME` matches `docker service ls`. |
| Docker pull denied | Check Docker Hub token and repository name. |
| Trivy fails | Fix or justify vulnerabilities; the pipeline intentionally blocks `HIGH,CRITICAL`. |
| Grafana stack fails | Set `GF_SECURITY_ADMIN_PASSWORD`; no insecure default is allowed. |
