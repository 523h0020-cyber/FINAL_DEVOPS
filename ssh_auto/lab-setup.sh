#!/bin/bash
# 1. Thu thập thông tin từ người dùng
echo "--- QUICK SETUP FOR AWS LEARNER LAB ---"
read -p "Access Key ID: " ak
read -p "Secret Key: " sk
read -p "Session Token: " st

# 2. Ghi đè vào file .env (để auto-fix.sh có cái mà dùng)
cat <<EOF > .env
AWS_ACCESS_KEY_ID=$ak
AWS_SECRET_ACCESS_KEY=$sk
AWS_SESSION_TOKEN=$st
AWS_DEFAULT_REGION=us-east-1
EOF

echo "✅ Đã lưu cấu hình vào .env"

# 3. GỌI LUÔN script auto-fix.sh của bạn
# (Giả sử bạn để 2 file cùng một thư mục scripts/)
chmod +x ./auto-fix.sh
./auto-fix.sh