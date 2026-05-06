#!/bin/bash

# ============================================================
# 🔑 LAB-SETUP — Cấu hình AWS Credentials (Bảo toàn dữ liệu)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

echo -e "\033[1;33m--- 🔐 QUICK SETUP FOR AWS LEARNER LAB ---\033[0m"

# 1. Khởi tạo file .env nếu chưa có
if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_EXAMPLE" ]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        echo "✅ Đã tạo file .env từ template."
    else
        touch "$ENV_FILE"
        echo "📝 Đã tạo file .env mới."
    fi
fi

# 2. Thu thập thông tin từ người dùng
read -p "🔹 Access Key ID: " ak
read -p "🔹 Secret Key: " sk
echo "🔹 Session Token: "
read -r st

# 3. Hàm cập nhật biến an toàn
update_env() {
    local key=$1
    local value=$2
    if grep -q "^${key}=" "$ENV_FILE"; then
        # Nếu đã có thì thay thế (Dùng dấu | làm delimiter để tránh lỗi nếu value có dấu /)
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        # Nếu chưa có thì thêm vào cuối
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

# 4. Cập nhật các biến AWS
update_env "AWS_ACCESS_KEY_ID" "$ak"
update_env "AWS_SECRET_ACCESS_KEY" "$sk"
update_env "AWS_SESSION_TOKEN" "$st"
update_env "AWS_DEFAULT_REGION" "us-east-1"

echo "----------------------------------------"
echo -e "\033[0;32m✅ Đã cập nhật Credentials. Các biến khác (DOMAIN_NAME,...) vẫn được giữ nguyên.\033[0m"
echo -e "\033[1;34m🚀 Đang gọi auto-fix.sh...\033[0m"
echo "----------------------------------------"

# 5. Thực thi auto-fix.sh
chmod +x "$SCRIPT_DIR/auto-fix.sh"
"$SCRIPT_DIR/auto-fix.sh"