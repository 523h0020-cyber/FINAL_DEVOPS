# Kịch Bản Video Demo (Docker Swarm + CI/CD + Monitoring)

## 1) Chuẩn bị trước khi quay (Pre-flight)

- Đảm bảo domain `523h0020.site` đã trỏ đúng IP public và HTTPS hoạt động.
- Chuẩn bị 3 cửa sổ terminal:
  - Terminal 1: máy local để sửa code, commit, push.
  - Terminal 2: SSH vào Docker Swarm manager để kiểm tra rollout và mô phỏng lỗi.
  - Terminal 3: tạo traffic nhẹ để biểu đồ Grafana nhảy rõ.
- Chuẩn bị 4 tab trình duyệt:
  - Tab GitHub `Actions` (hoặc GitLab `Pipelines`).
  - Tab Docker Hub tags của image.
  - Tab web production: `https://523h0020.site`.
  - Tab Grafana dashboard.
- Thời lượng khuyến nghị: 12-14 phút.

## 2) Kịch bản theo từng phút

| Thời gian | Hành động trên màn hình | Lời thoại gợi ý |
| --- | --- | --- |
| 00:00 - 00:45 | Mở sơ đồ/README kiến trúc tổng quan (AWS + Swarm + Traefik HTTPS + GitHub Actions + Prometheus/Grafana). | "Đây là hệ thống Tier 4 của nhóm em: triển khai trên AWS, orchestration bằng Docker Swarm đa node, CI/CD tự động bằng GitHub Actions, có HTTPS và Monitoring đầy đủ." |
| 00:45 - 01:35 | Mở file UI: `app/views/partials/head.ejs`. | "Em sẽ thay đổi một chi tiết UI dễ nhận biết để chứng minh bản deploy mới đã lên production." |
| 01:35 - 02:20 | Đổi heading từ `Products` thành `Products - Demo Release v1.0.x`, lưu file. | "Đây là thay đổi giao diện có thể nhìn thấy ngay trên website sau khi pipeline chạy xong." |
| 02:20 - 03:20 | Trên terminal local chạy: `git status`, `git add .`, `git commit -m "feat(ui): update visible demo heading"`, `git push origin main`. | "Em commit và push vào nhánh chính để trigger pipeline CI/CD tự động, không có thao tác deploy thủ công." |
| 03:20 - 04:10 | Mở GitHub Actions, refresh để thấy run mới. | "Pipeline đã tự khởi chạy ngay khi có push vào main." |
| 04:10 - 05:30 | Zoom từng bước CI: Checkout -> Setup Node + cache npm -> Install dependencies -> Linting. | "Đây là phần CI chuẩn: checkout mã nguồn, cache dependencies, cài dependency và lint code." |
| 05:30 - 06:40 | Zoom bước Trivy `filesystem scan` và `image scan`, nhấn mạnh điều kiện fail HIGH/CRITICAL. | "Phần DevSecOps: pipeline sẽ fail ngay nếu Trivy phát hiện lỗ hổng mức HIGH hoặc CRITICAL." |
| 06:40 - 07:30 | Zoom bước versioning: `Prepare semantic tags`, `Build and push semantic tags (no latest)`. Mở Docker Hub tags để show `sha-xxxxxxx`, `v1.0.xxx`, không có `latest`. | "Nhóm em dùng semantic versioning bằng commit SHA và version theo run number, tuyệt đối không dùng latest để tránh deploy nhầm." |
| 07:30 - 08:30 | Zoom job CD: `Deploy to Docker Swarm via SSH`. | "Sau khi CI pass và security scan pass, CD tự SSH vào manager để update service bằng image mới." |
| 08:30 - 09:10 | Terminal manager: chạy `docker service ls` và `docker service ps <SWARM_SERVICE_NAME>`. | "Đây là bằng chứng rollout đã hoàn tất và service đang chạy image mới trên cụm Swarm." |
| 09:10 - 10:00 | Mở `https://523h0020.site`, hard refresh (Ctrl+F5), chỉ biểu tượng khóa HTTPS và heading mới. | "Website public qua HTTPS đã cập nhật đúng thay đổi giao diện vừa commit." |
| 10:00 - 11:00 | Mở Grafana dashboard ID 1860 và 193. Trên terminal 3 chạy load nhẹ để biểu đồ biến thiên rõ. | "Grafana đang hiển thị CPU, RAM và metrics container theo thời gian thực. Khi có traffic, biểu đồ nhảy ngay." |
| 11:00 - 12:20 | Mô phỏng lỗi trên manager: lấy container app và `docker rm -f <CONTAINER_ID>`, sau đó chạy `docker service ps <SWARM_SERVICE_NAME>`. | "Em vừa tắt cưỡng bức một container. Swarm tự phát hiện lệch desired state và tự tạo task mới. Đây là self-healing." |
| 12:20 - 13:10 | Quay lại website + Grafana để chứng minh hệ thống vẫn online và metric phản ánh sự kiện lỗi/phục hồi. | "Dù có lỗi runtime, hệ thống vẫn phục vụ bình thường và tự phục hồi, đúng yêu cầu production-grade." |
| 13:10 - 13:40 | Kết thúc bằng checklist tổng kết. | "Tổng kết: có thay đổi code, CI/CD tự động, security gate, semantic versioning, HTTPS public domain, monitoring và self-healing." |

## 3) Lệnh dùng trực tiếp khi quay

```bash
# A. Commit & push
git status
git add .
git commit -m "feat(ui): update visible demo heading"
git push origin main

# B. Kiểm tra rollout trên Swarm
docker service ls
docker service ps <SWARM_SERVICE_NAME>

# C. Tạo traffic để dashboard nhảy rõ
while true; do curl -s https://523h0020.site > /dev/null; sleep 0.3; done

# D. Mô phỏng lỗi và kiểm tra self-healing
docker ps --filter name=<SWARM_SERVICE_NAME>
docker rm -f <CONTAINER_ID>
docker service ps <SWARM_SERVICE_NAME>
```

## 4) Checklist bằng chứng bắt buộc trong video

- [ ] Có sửa UI trước khi push.
- [ ] Có màn hình pipeline chạy tự động.
- [ ] Có nhấn mạnh Trivy security scan fail gate.
- [ ] Có nhấn mạnh semantic tags và không dùng `latest`.
- [ ] Có màn hình job CD update service.
- [ ] Có website `https://523h0020.site` với thay đổi mới.
- [ ] Có dashboard Grafana đang cập nhật metric.
- [ ] Có mô phỏng lỗi và bằng chứng tự phục hồi.

## 5) Nếu dùng GitLab thay vì GitHub

- Thay màn hình `Actions` bằng `CI/CD -> Pipelines`.
- Giữ nguyên trình tự thuyết minh: CI -> Security scan -> Versioning -> CD -> Verify web -> Grafana -> Self-healing.
