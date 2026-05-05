#!/bin/bash
set -e

# Màu sắc cho Terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 BẮT ĐẦU QUY TRÌNH TỰ ĐỘNG KHÔI PHỤC LAB...${NC}"

# 1. Kiểm tra AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ Lỗi: Chưa cài đặt AWS CLI.${NC}"
    echo -e "Hãy chạy: curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\" && unzip awscliv2.zip && sudo ./aws/install"
    exit 1
fi
echo -e "${GREEN}✅ Đã có AWS CLI.${NC}"

# 2. Kiểm tra Ansible
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}❌ Lỗi: Chưa cài đặt Ansible.${NC}"
    echo -e "Hãy chạy: sudo apt update && sudo apt install -y ansible"
    exit 1
fi
echo -e "${GREEN}✅ Đã có Ansible.${NC}"

# 3. Load cấu hình .env (Nơi bạn copy AWS Learner Lab token)
if [ -f ".env" ]; then
    echo -e "${YELLOW}📦 Đang nạp cấu hình AWS từ file .env...${NC}"
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${RED}❌ Không tìm thấy file ssh_auto/.env.${NC}"
    echo -e "Vui lòng copy từ .env.example, đổi tên thành .env và điền Token AWS Learner Lab mới nhất."
    exit 1
fi

# 4. Kiểm tra file .pem và cấp quyền 400
# Lưu ý: Cấu hình mặc định tìm file final-devops-key.pem ở thư mục gốc
PEM_FILE="../final-devops-key.pem" 
if [ -f "$PEM_FILE" ]; then
    # Cấp đúng quyền bảo mật cho khóa SSH trong Linux/WSL
    chmod 400 "$PEM_FILE"
    echo -e "${GREEN}✅ Đã set quyền 400 thành công cho $PEM_FILE.${NC}"
else
    echo -e "${RED}❌ Không tìm thấy khóa SSH ($PEM_FILE).${NC}"
    echo -e "Hãy tải file .pem từ AWS và để vào thư mục gốc của project (ngang hàng với ssh_auto/)."
    exit 1
fi

# 5. Dùng AWS CLI tự động lấy IP hiện tại
echo -e "${YELLOW}🔍 Đang lấy 2 IP mới nhất từ AWS của cụm Swarm...${NC}"

# Tìm máy Manager (dựa vào tags)
MANAGER_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Role,Values=manager" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PublicIpAddress" --output text)

# Tìm máy Worker (dựa vào tags)
WORKER_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Role,Values=worker" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PublicIpAddress" --output text)

if [ -z "$MANAGER_IP" ] || [ -z "$WORKER_IP" ]; then
    echo -e "${RED}❌ Không tìm thấy IP! Quên chưa chạy \`terraform apply\` hoặc EC2 chưa bật (Running) rồi.${NC}"
    exit 1
fi

echo -e "   📍 ${GREEN}Manager IP: $MANAGER_IP${NC}"
echo -e "   📍 ${GREEN}Worker IP: $WORKER_IP${NC}"

# 6. Ghi đè thông tin IP mới vào Ansible hosts.ini
HOSTS_FILE="../ansible/inventory/hosts.ini"
cat <<EOF > "$HOSTS_FILE"
[managers]
manager1 ansible_host=$MANAGER_IP ansible_user=ubuntu ansible_ssh_private_key_file=../final-devops-key.pem

[workers]
worker1 ansible_host=$WORKER_IP ansible_user=ubuntu ansible_ssh_private_key_file=../final-devops-key.pem
EOF
echo -e "${GREEN}✅ Đã cập nhật xong file host cho Ansible ($HOSTS_FILE).${NC}"

# Kiểm tra và Cài đặt tự động GitHub CLI nếu chưa có
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}📦 Máy chưa cài GitHub CLI (\`gh\`). Đang tiến hành cài đặt tự động...${NC}"
    (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y
    echo -e "${GREEN}✅ Cài đặt GitHub CLI thành công!${NC}"
fi

if command -v gh &> /dev/null; then
    # Thử login tự động bằng GITHUB_TOKEN truyền từ .env nếu chưa login
    if [ -n "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}🔑 Đang sử dụng GITHUB_TOKEN để xác thực...${NC}"
        echo "$GITHUB_TOKEN" | gh auth login --with-token &> /dev/null || true
    fi

    if gh auth status &> /dev/null; then
        echo -e "${YELLOW}🔐 Đang tự động đồng bộ lên GitHub Secrets...${NC}"
        gh secret set SSH_HOST --body "$MANAGER_IP"
        gh secret set SSH_PRIVATE_KEY < "$PEM_FILE"
        gh secret set SSH_USER --body "ubuntu"
        gh secret set SWARM_SERVICE_NAME --body "app_service" # Đổi tên này thành tên docker swarm service name tương ứng của bạn

        # Setup thêm DOCKERHUB secrets nếu người dùng nhập trong .env
        if [ -n "$DOCKERHUB_USERNAME" ] && [ -n "$DOCKERHUB_TOKEN" ]; then
            gh secret set DOCKERHUB_USERNAME --body "$DOCKERHUB_USERNAME"
            gh secret set DOCKERHUB_TOKEN --body "$DOCKERHUB_TOKEN"
            echo -e "${GREEN}✅ GitHub Secrets (SSH_HOST, SSH_PRIVATE_KEY, SSH_USER, SWARM_SERVICE_NAME, và DOCKERHUB) đã được setup tự động!${NC}"
        else
            echo -e "${GREEN}✅ GitHub Secrets (cấu hình SSH) đã được setup! (Bỏ qua DOCKERHUB do chưa điền trong .env)${NC}"
        fi
    else
        echo -e "${RED}⚠️  GitHub CLI chưa xác thực. Hãy cấp quyền bằng \`gh auth login\` hoặc thêm GITHUB_TOKEN vào .env.${NC}"
    fi
else
    echo -e "${RED}⚠️  Quá trình cài đặt GitHub CLI thất bại. Bỏ qua cập nhật Github Secrets.${NC}"
fi

# 7. Xử lý "Swarm treo" do đổi IP
echo -e "${YELLOW}🧹 Đang force-leave (Reset) Swarm cũ trên Manager & Worker...${NC}"
# Sử dụng StrictHostKeyChecking=no để tránh lỗi xác nhận fingerprint khi IP đổi
ssh -o StrictHostKeyChecking=no -i "$PEM_FILE" ubuntu@$WORKER_IP "sudo docker swarm leave --force" 2>/dev/null || true
ssh -o StrictHostKeyChecking=no -i "$PEM_FILE" ubuntu@$MANAGER_IP "sudo docker swarm leave --force" 2>/dev/null || true
echo -e "${GREEN}✅ Đã dọn dẹp Swarm state.${NC}"

# 8. Chạy lại Ansible để dựng Swarm mới tinh
echo -e "${YELLOW}⚙️ Đang kích hoạt Ansible tạo lại Swarm...${NC}"
cd ../ansible
ansible-playbook -i inventory/hosts.ini playbooks/01-bootstrap.yml

# 9. In kết quả cuối cùng
clear

# Nếu biến GIT_BRANCH không được set, mặc định là 'main'
TARGET_BRANCH=${GIT_BRANCH:-main}

echo -e "${GREEN}🎉 HOÀN TẤT TỰ ĐỘNG HÓA!${NC}"
echo -e "👉 ${YELLOW}$WORKER_IP${NC}"
echo -e "👉 ${YELLOW}$MANAGER_IP${NC}"
echo -e ""

while true; do
    echo -en "${YELLOW}Đã cập nhật SSH_HOST xong chưa? Có muốn script tự động Git Push không? (y/n): ${NC}"
    read yn
    case $yn in
        [Yy]* ) 
            echo -e "\n${GREEN}🚀 Đang thực hiện push code lên nhánh $TARGET_BRANCH...${NC}"
            cd .. # Lùi ra thư mục gốc để chạy git
            git push origin "$TARGET_BRANCH"
            echo -e "${GREEN}✅ Đã push thành công! Hãy mở tab Actions trên GitHub để xem tiến trình chạy CI/CD.${NC}"
            break;;
        [Nn]* ) 
            echo -e "\n${YELLOW}Ghi nhận! Khi nào thiết lập GitHub xong, bạn hãy tự trỏ ra thư mục gốc và gõ lệnh:${NC}"
            echo -e "👉 ${GREEN}git push origin $TARGET_BRANCH${NC}"
            break;;
        * ) echo -e "${RED}Vui lòng chọn y hoặc n.${NC}";;
    esac
done
echo -e "=========================================================="