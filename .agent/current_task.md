# CURRENT TASK

**Status**: Phase 6 in progress (Demo script prepared).
**Current Focus**: Execute recording run and capture mandatory evidence for final submission.

**Action Required from User**:

1. Cập nhật secret GitHub Actions cho Docker Hub và Server SSH (`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `SWARM_MANAGER_HOST`, `SWARM_MANAGER_USER`, `SWARM_SSH_PRIVATE_KEY`).
2. Run `terraform apply` trong thư mục `terraform/aws` để khởi tạo hạ tầng.
3. Chạy `ansible-playbook` để cấu hình server và init Docker Swarm.
4. Trỏ domain `523h0020.site` về IP của Swarm Manager.
5. Xem lại video demo script (`demo/video-demo-script.md`) và tiến hành quay.
