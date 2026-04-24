# Ansible Post-Terraform Setup (Docker Swarm + Let's Encrypt)

This directory automates post-provisioning steps after Terraform:

- Install base dependencies on all nodes.
- Install and configure Docker Engine.
- Initialize Docker Swarm manager and join workers.
- Deploy Traefik ingress with automatic Let's Encrypt certificates for `523h0020.site`.

## Files

- `playbooks/01-bootstrap.yml`: OS dependencies + Docker.
- `playbooks/02-swarm.yml`: Swarm init/join.
- `playbooks/03-traefik-letsencrypt.yml`: Traefik and HTTPS automation.
- `playbooks/site.yml`: run all playbooks in order.
- `scripts/generate_inventory_from_terraform.ps1`: generate inventory from Terraform output.

## Prerequisites

1. Terraform has finished and produced `swarm_public_ips` output.
2. DNS `A` record for `523h0020.site` points to your public entrypoint IP (Load Balancer or manager node).
3. Security controls allow internet traffic on ports `80` and `443`.
4. Swarm node-to-node traffic is allowed internally on:
   - `2377/tcp`
   - `7946/tcp`
   - `7946/udp`
   - `4789/udp`

## Run

From workspace root:

```powershell
cd ansible
ansible-galaxy collection install -r requirements.yml
Copy-Item inventories/production/hosts.ini.example inventories/production/hosts.ini
.\scripts\generate_inventory_from_terraform.ps1 -TerraformDir ..\terraform\aws -AnsibleUser ec2-user
ansible-playbook playbooks/site.yml
```

For GCP, switch `-TerraformDir` and user:

```powershell
.\scripts\generate_inventory_from_terraform.ps1 -TerraformDir ..\terraform\gcp -AnsibleUser debian
```

## Verification

After successful run:

- `docker node ls` on manager should show 1 manager + worker nodes.
- `docker service ls` should show Traefik stack services.
- Opening `https://523h0020.site` should return the whoami service over a valid Let's Encrypt certificate.
