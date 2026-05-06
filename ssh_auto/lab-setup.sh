#!/bin/bash

# ============================================================
# 🔑 LAB-SETUP — Cấu hình nhanh AWS Credentials
# ============================================================

# 1. Xác định đường dẫn (Đồng bộ với auto-fix.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

echo -e "\033[1;33m--- 🔐 QUICK SETUP FOR AWS LEARNER LAB ---\033[0m"

# 2. Khởi tạo file .env nếu chưa có
if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_EXAMPLE" ]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        echo "✅ Đã tạo file .env từ template."
    else
        touch "$ENV_FILE"
        echo "📝 Đã tạo file .env mới."
    fi
fi

# 3. Thu thập thông tin từ người dùng
read -p "🔹 Access Key ID: " ak
read -p "🔹 Secret Key: " sk
echo "🔹 Session Token (Paste vào rồi nhấn Enter): "
read -r st

# 4. Cập nhật vào file .env (Dùng sed để thay thế chính xác, giữ lại các biến khác)
# Xóa các dòng cũ nếu đã tồn tại để tránh trùng lặp
sed -i '/^AWS_ACCESS_KEY_ID=/d' "$ENV_FILE"
sed -i '/^AWS_SECRET_ACCESS_KEY=/d' "$ENV_FILE"
sed -i '/^AWS_SESSION_TOKEN=/d' "$ENV_FILE"
sed -i '/^AWS_DEFAULT_REGION=/d' "$ENV_FILE"

# Ghi giá trị mới vào cuối file
{
    echo "AWS_ACCESS_KEY_ID=$ak"
    echo "AWS_SECRET_ACCESS_KEY=$sk"
    echo "AWS_SESSION_TOKEN=$st"
    echo "AWS_DEFAULT_REGION=us-east-1"
} >> "$ENV_FILE"

echo "----------------------------------------"
echo -e "\033[0;32m✅ Đã cập nhật AWS Credentials vào: $ENV_FILE\033[0m"
echo -e "\033[1;34m🚀 Đang gọi auto-fix.sh...\033[0m"
echo "----------------------------------------"

# 5. Thực thi auto-fix.sh
chmod +x "$SCRIPT_DIR/auto-fix.sh"
"$SCRIPT_DIR/auto-fix.sh"