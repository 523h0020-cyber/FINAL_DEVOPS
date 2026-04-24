# Monitoring Stack for Docker Swarm

This stack deploys:

- Prometheus (metrics storage and query)
- Grafana (visualization)
- Node Exporter (host CPU/memory metrics)
- cAdvisor (container metrics and state)

## 1. Deploy stack

Run on Swarm manager:

```bash
cd monitoring
cp .env.example .env
set -a
source .env
set +a
docker stack deploy -c docker-stack.monitoring.yml monitoring
```

Check status:

```bash
docker stack services monitoring
docker service ls | grep monitoring
```

Endpoints:

- Prometheus: `http://<manager-ip>:9090`
- Grafana: `http://<manager-ip>:3000`

Default Grafana account is loaded from `.env`.

## 2. Import ready dashboards in Grafana

1. Open Grafana and login.
2. Go to Dashboards -> New -> Import.
3. Import Dashboard ID `1860` (Node Exporter Full).
4. Select datasource `Prometheus` and click Import.
5. Repeat import with Dashboard ID `193` (Docker monitoring with Prometheus and cAdvisor).

What you get:

- Dashboard `1860`: host-level CPU usage and Memory usage.
- Dashboard `193`: container-level CPU/Memory, container runtime state.

## 3. Notes for "Pods/Containers status"

This environment is Docker Swarm, so you monitor **containers/services** (not Kubernetes pods).

For service status in Swarm, use:

```bash
docker service ls
docker service ps <service-name>
```

In Grafana, dashboard `193` visualizes running container behavior from cAdvisor metrics.

## 4. Optional hardening for production

- Expose Grafana behind Traefik with HTTPS instead of direct port `3000`.
- Change admin password in `.env` before first deploy.
- Restrict access to ports `3000` and `9090` by source IP.
