# TODO LIST

## Phase 1 & 2 (Infra)

- [ ] Define Cloud Provider & Tech Stack.
- [x] Write Terraform `.tf` files (AWS/GCP, VPC, subnets, SG/Firewall 22,80,443, Swarm/K8s options).
- [x] Write Ansible `playbook.yml` (Install dependencies, Docker, Swarm init/join, Traefik + Let's Encrypt).
- [ ] Buy/Setup Domain & configure DNS records.

## Phase 3 (App & Swarm)

- [ ] Write optimized `Dockerfile`.
- [ ] Write `swarm-stack.yml` (Traefik reverse proxy + App replicas + DB volumes).

## Phase 4 (CI/CD)

- [x] Create CI/CD workflow file.
- [x] Add Linting & Dependency caching.
- [x] Add Trivy Security Scan (fail on critical).
- [x] Add Docker Build & Push (with Git SHA/Version tags, no latest).
- [x] Add CD step to update Swarm service via SSH (and Kubernetes option).

## Phase 5 (Monitoring)

- [x] Add Prometheus to monitoring stack for Docker Swarm.
- [x] Add Grafana to monitoring stack and dashboard import guide (CPU/Memory/Container status).

## Phase 6 (Demo & Report)

- [x] Prepare minute-by-minute video demo script (action + narration).
- [ ] Test failure simulation (Kill container -> Watch auto-restart).
- [ ] Record Demo Video (Code change -> CI/CD -> HTTPS Web -> Grafana -> Failure).
- [ ] Write 5-chapter Technical Report.
