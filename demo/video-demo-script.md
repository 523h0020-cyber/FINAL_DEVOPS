# Video Demo Script (Docker Swarm, CI/CD, Monitoring)

## Pre-flight (do before recording)

- Ensure DNS `523h0020.site` already points to your public entrypoint and HTTPS is valid.
- Prepare terminal tabs:
  - Tab 1: local repo for code change + git push.
  - Tab 2: Docker Swarm manager (`ssh`).
  - Tab 3: optional load generator (curl loop).
- Open browser tabs in advance:
  - GitHub repo (Actions tab) or GitLab CI page.
  - Docker Hub tags page for your image repo.
  - `https://523h0020.site`
  - Grafana dashboard page.
- Suggested demo length: 12-14 minutes.

## Minute-by-minute script

| Time | Hanh dong tren man hinh | Loi thoai thuyet minh |
| --- | --- | --- |
| 00:00 - 00:40 | Mo slide/README tong quan kien truc (Swarm, Traefik HTTPS, CI/CD, Monitoring). | "Day la he thong Tier 4 cua nhom em: Docker Swarm da node, CI/CD tu dong, HTTPS public domain va monitoring bang Prometheus + Grafana." |
| 00:40 - 01:30 | Mo source code UI file `sample-final-project/sample-midterm-node.js-project/views/partials/head.ejs`. | "Em se thay doi UI de de nhan biet phien ban moi sau deployment." |
| 01:30 - 02:20 | Chinh sua heading, vi du doi `Products` thanh `Products - Demo Release v1.0.x` va luu file. | "Em vua doi heading giao dien de chung minh CD cap nhat dung image moi." |
| 02:20 - 03:10 | Terminal local: `git status`, `git add .`, `git commit -m "feat(ui): demo visible banner for release"`, `git push origin main`. | "Bay gio em commit va push truc tiep len nhanh chinh de trigger pipeline tu dong." |
| 03:10 - 04:00 | Mo GitHub Actions (hoac GitLab Pipeline) va refresh den khi run moi xuat hien. | "Pipeline da duoc trigger tu dong khi co push vao main, khong can thao tac tay." |
| 04:00 - 05:20 | Zoom job CI: checkout, cache dependencies, install deps, linting. | "Day la phan CI: checkout code, cache npm/maven/pip, cai dependencies, va linting." |
| 05:20 - 06:30 | Zoom 2 buoc Trivy: filesystem scan va image scan. | "Phan quan trong ve DevSecOps: Trivy scan se fail ngay neu phat hien HIGH hoac CRITICAL. Nen deployment chi xay ra khi image an toan." |
| 06:30 - 07:20 | Zoom step versioning: `Prepare semantic tags` + `Build and push semantic tags (no latest)`. Mo Docker Hub tags de show `sha-xxxxxxx`, `v1.0.xxx` va khong co `latest`. | "Nhom em su dung semantic versioning theo run number va commit SHA. Tuyet doi khong dung tag latest de tranh deploy nham ban build." |
| 07:20 - 08:20 | Zoom job CD: `Deploy to Docker Swarm via SSH` (hoac Kubernetes step neu ban chay K8s). | "Day la phan CD tu dong. Sau khi build va scan dat, pipeline SSH vao manager va update service len image moi." |
| 08:20 - 09:00 | Tren terminal manager: `docker service ps <SWARM_SERVICE_NAME>` va `docker service ls` de show service da rollout. | "Rollout da hoan tat, service dang chay image moi tren cum Swarm." |
| 09:00 - 09:50 | Mo `https://523h0020.site`, refresh hard (Ctrl+F5), show icon khoa HTTPS va UI heading moi. | "Day la domain public voi HTTPS hop le. UI da doi dung voi code vua push, chung minh CD thanh cong." |
| 09:50 - 10:50 | Mo Grafana, chon dashboard ID 1860 va 193 da import. Co the chay load nhe o terminal: `while true; do curl -s https://523h0020.site > /dev/null; sleep 0.3; done` de metric nhay ro hon. | "Tren Grafana, em theo doi CPU, memory muc host va metrics container theo thoi gian thuc. Co traffic thi metric nhay ngay lap tuc." |
| 10:50 - 12:20 | Gia lap loi tren manager: `docker ps --filter name=<SWARM_SERVICE_NAME>` -> lay container id -> `docker rm -f <container_id>`. Ngay sau do chay `docker service ps <SWARM_SERVICE_NAME>` de show task moi duoc tao lai. | "Em vua kill mot container dang chay. Swarm phat hien trang thai khong dat desired state va tu dong tao task moi. Day la co che self-healing." |
| 12:20 - 13:00 | Quay lai website + Grafana de show service van online, metric co bien dong khi su co va phuc hoi. | "Du bi loi container, he thong van phuc vu binh thuong va tu phuc hoi. Day la diem chinh cua kien truc orchestration production-grade." |
| 13:00 - 13:30 | Ket video bang checklist nhanh (CI pass, security pass, versioning, CD auto, HTTPS, Monitoring, self-healing). | "Tong ket: he thong dat day du yeu cau Infrastructure as Code, CI/CD, Security gate, HTTPS, Monitoring va Self-healing." |

## Command block ready-to-use (for copy while recording)

```bash
# 1) Commit and push
git status
git add .
git commit -m "feat(ui): demo visible banner for release"
git push origin main

# 2) Verify Swarm rollout
docker service ls
docker service ps <SWARM_SERVICE_NAME>

# 3) Generate load for visible metrics
while true; do curl -s https://523h0020.site > /dev/null; sleep 0.3; done

# 4) Simulate failure + self-healing
docker ps --filter name=<SWARM_SERVICE_NAME>
docker rm -f <CONTAINER_ID>
docker service ps <SWARM_SERVICE_NAME>
```

## Quick mapping for GitLab CI (if you use GitLab instead of GitHub)

- Replace "Actions" screen with "CI/CD -> Pipelines".
- Keep the same narration order: lint -> Trivy security gate -> semantic tags -> deploy job.
- Evidence remains identical: Docker Hub tags, HTTPS UI update, Grafana metrics, self-healing.
