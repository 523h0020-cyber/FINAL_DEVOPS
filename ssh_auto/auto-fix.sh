#!/bin/bash

# ============================================================
# 🔧 AUTO-FIX SCRIPT — Tự động hoá triển khai DevOps Pipeline
# ============================================================

# ===========================================
# 1. XÁC ĐỊNH THƯ MỤC GỐC (PROJECT ROOT)
#    Bất kể chạy script từ đâu, nó cũng sẽ
#    tìm đúng gốc dự án.
# ===========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ===========================================
# 2. ĐỊNH NGHĨA CÁC ĐƯỜNG DẪN QUAN TRỌNG
#    Tất cả đều dựa trên PROJECT_ROOT
# ===========================================
TERRAFORM_DIR="$PROJECT_ROOT/terraform/aws"
MONITORING_DIR="$PROJECT_ROOT/monitoring"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
SSH_KEY="$TERRAFORM_DIR/final-devops-key.pem"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"
HOSTS_FILE="$ANSIBLE_DIR/inventory/hosts.ini"

set -e

# Màu sắc cho Terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- PHASE 0: KIỂM TRA & CÀI ĐẶT CÔNG CỤ ---
echo -e "${CYAN}🛠 Đang kiểm tra các công cụ cần thiết...${NC}"

# 1. Kiểm tra Terraform
if ! command -v terraform &> /dev/null; then
    echo -en "${YELLOW}⚠️ Chưa thấy Terraform. Bạn có muốn cài đặt tự động không? (y/n): ${NC}"
    read install_tf
    if [[ "$install_tf" =~ ^[Yy]$ ]]; then
        sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt-get update && sudo apt-get install terraform -y
        echo -e "${GREEN}✅ Đã cài đặt Terraform.${NC}"
    else
        echo -e "${RED}❌ Thiếu Terraform. Script không thể tiếp tục.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Đã có Terraform.${NC}"
fi

# 2. Kiểm tra AWS CLI
if ! command -v aws &> /dev/null; then
    echo -en "${YELLOW}⚠️ Chưa thấy AWS CLI. Bạn có muốn cài đặt tự động không? (y/n): ${NC}"
    read install_aws
    if [[ "$install_aws" =~ ^[Yy]$ ]]; then
        sudo apt-get update && sudo apt-get install -y unzip curl
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        sudo ./aws/install
        rm -rf awscliv2.zip aws/
        echo -e "${GREEN}✅ Đã cài đặt AWS CLI.${NC}"
    else
        echo -e "${RED}❌ Thiếu AWS CLI. Script không thể tiếp tục.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Đã có AWS CLI.${NC}"
fi

# 3. Kiểm tra Ansible
if ! command -v ansible-playbook &> /dev/null; then
    echo -en "${YELLOW}⚠️ Chưa thấy Ansible. Bạn có muốn cài đặt tự động không? (y/n): ${NC}"
    read install_ansible
    if [[ "$install_ansible" =~ ^[Yy]$ ]]; then
        sudo apt-get update && sudo apt-get install -y ansible
        echo -e "${GREEN}✅ Đã cài đặt Ansible.${NC}"
    else
        echo -e "${RED}❌ Thiếu Ansible. Script không thể tiếp tục.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Đã có Ansible.${NC}"
fi

# --- PHASE 1: NẠP CẤU HÌNH ---

# Nạp cấu hình từ .env (Cực kỳ quan trọng để Terraform và AWS CLI có quyền chạy)
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}ℹ️ Không tìm thấy file .env. Tự động chuyển sang chế độ Setup...${NC}"
    bash "$SCRIPT_DIR/lab-setup.sh"
    exit 0 # Kết thúc phiên này để phiên do lab-setup.sh gọi lấy quyền điều khiển
fi

echo -e "${YELLOW}📦 Đang nạp cấu hình từ file .env...${NC}"
export $(grep -v '^#' "$ENV_FILE" | xargs)

# Kiểm tra nhanh xem đã nạp được Access Key chưa, nếu chưa có thì cũng gọi Setup
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
    echo -e "${RED}⚠️ Cảnh báo: File .env thiếu thông tin Credentials quan trọng.${NC}"
    echo -e "${YELLOW}🔄 Đang khởi động lại quá trình Setup...${NC}"
    bash "$SCRIPT_DIR/lab-setup.sh"
    exit 0
fi

# --- PHASE 2: TERRAFORM — Chuẩn bị hạ tầng ---
echo -e "${YELLOW}🚀 Đang chuẩn bị hạ tầng với Terraform...${NC}"

cd "$TERRAFORM_DIR" || { echo -e "${RED}❌ Không tìm thấy thư mục Terraform tại: $TERRAFORM_DIR${NC}"; exit 1; }

# Khởi tạo và đồng bộ lock file
terraform init -upgrade

# Chạy apply (set -e sẽ tự thoát nếu lỗi, không cần kiểm tra $? thêm)
terraform apply -auto-approve

echo -e "${GREEN}✅ Hạ tầng đã sẵn sàng.${NC}"

# Quay lại thư mục script
cd "$SCRIPT_DIR"

# 3.5 Interactive setup cho các giá trị optional (GitHub, Docker Hub)
# --- Phần cấu hình cho Monitoring ---
# CONFIG_VERSION dùng timestamp — khai báo 1 lần duy nhất ở đây để dùng xuyên suốt
export CONFIG_VERSION=$(date +%s)
export GF_ADMIN_USER=${GF_SECURITY_ADMIN_USER:-admin}
export GF_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-ChangeMe_123!}
echo -e ""
echo -en "${YELLOW}Có muốn cập nhật các giá trị GitHub/Docker Hub ngay bây giờ? (y/n): ${NC}"
read setup_choice
if [ "$setup_choice" = "y" ] || [ "$setup_choice" = "Y" ]; then
    echo -e ""
    echo -e "${YELLOW}🔧 Nhập các thông tin bên dưới (bỏ qua nếu không cần):${NC}"
    
    read -p "GitHub Personal Token (GITHUB_TOKEN) [leave blank to skip]: " input_github_token
    if [ -n "$input_github_token" ]; then
        # Match cả dòng active (GITHUB_TOKEN=) lẫn dòng bị comment (# GITHUB_TOKEN=)
        if grep -q '^GITHUB_TOKEN=' "$ENV_FILE"; then
            sed -i "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=$input_github_token|" "$ENV_FILE"
        else
            sed -i "s|^# GITHUB_TOKEN=.*|GITHUB_TOKEN=$input_github_token|" "$ENV_FILE"
        fi
        export GITHUB_TOKEN="$input_github_token"
        echo -e "${GREEN}✅ Đã cập nhật GITHUB_TOKEN${NC}"
    fi
    
    read -p "Docker Hub Username (DOCKERHUB_USERNAME) [leave blank to skip]: " input_docker_user
    if [ -n "$input_docker_user" ]; then
        if grep -q '^DOCKERHUB_USERNAME=' "$ENV_FILE"; then
            sed -i "s|^DOCKERHUB_USERNAME=.*|DOCKERHUB_USERNAME=$input_docker_user|" "$ENV_FILE"
        else
            sed -i "s|^# DOCKERHUB_USERNAME=.*|DOCKERHUB_USERNAME=$input_docker_user|" "$ENV_FILE"
        fi
        export DOCKERHUB_USERNAME="$input_docker_user"
        echo -e "${GREEN}✅ Đã cập nhật DOCKERHUB_USERNAME${NC}"
    fi
    
    read -sp "Docker Hub Token (DOCKERHUB_TOKEN) [leave blank to skip]: " input_docker_token
    if [ -n "$input_docker_token" ]; then
        if grep -q '^DOCKERHUB_TOKEN=' "$ENV_FILE"; then
            sed -i "s|^DOCKERHUB_TOKEN=.*|DOCKERHUB_TOKEN=$input_docker_token|" "$ENV_FILE"
        else
            sed -i "s|^# DOCKERHUB_TOKEN=.*|DOCKERHUB_TOKEN=$input_docker_token|" "$ENV_FILE"
        fi
        export DOCKERHUB_TOKEN="$input_docker_token"
        echo -e ""
        echo -e "${GREEN}✅ Đã cập nhật DOCKERHUB_TOKEN${NC}"
    fi
    echo -e ""
fi
if [[ -z "$DOMAIN_NAME" ]]; then
    # Lấy domain cũ từ .env nếu có, nếu không thì để mặc định
    DEFAULT_DOMAIN=$(grep DOMAIN_NAME "$ENV_FILE" | cut -d '=' -f2)
    read -p "Nhập Domain của bạn [${DEFAULT_DOMAIN:-523h0020.site}]: " INPUT_DOMAIN
    DOMAIN_NAME=${INPUT_DOMAIN:-${DEFAULT_DOMAIN:-523h0020.site}}
    
    # Lưu lại vào .env để lần sau không phải nhập lại
    sed -i "/^DOMAIN_NAME=/d" "$ENV_FILE"
    echo "DOMAIN_NAME=$DOMAIN_NAME" >> "$ENV_FILE"
fi
export DOMAIN_NAME



# --- PHASE 4: KIỂM TRA SSH KEY & LẤY IP ---

# 4. Kiểm tra file .pem
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}❌ Lỗi: Không thấy file $SSH_KEY. Kiểm tra lại config Terraform!${NC}"
    exit 1
fi

# WSL FIX: chmod 0400 không có tác dụng trên /mnt/c/ (NTFS mount của Windows).
# Giải pháp: Copy key sang Linux filesystem thật (~/.ssh/) nơi chmod hoạt động đúng.
WSL_SSH_KEY="$HOME/.ssh/final-devops-key.pem"
mkdir -p "$HOME/.ssh"
cp "$SSH_KEY" "$WSL_SSH_KEY"
chmod 600 "$WSL_SSH_KEY"

# Cập nhật biến SSH_KEY trỏ sang bản copy trên Linux filesystem
SSH_KEY="$WSL_SSH_KEY"
echo -e "${GREEN}✅ SSH key đã được sao chép sang Linux filesystem và bảo mật tại: $SSH_KEY${NC}"

# 5. Dùng AWS CLI tự động lấy IP hiện tại
echo -e "${YELLOW}🔍 Đang lấy 2 IP mới nhất từ AWS của cụm Swarm...${NC}"

# Tìm máy Manager (dựa vào tags)
MANAGER_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Role,Values=manager" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PublicIpAddress" --output text | head -n 1)

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
mkdir -p "$(dirname "$HOSTS_FILE")"
cat > "$HOSTS_FILE" <<EOF
# Group name phải khớp với 'hosts:' trong các Ansible playbook
[manager]
manager1 ansible_host=$MANAGER_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY

[workers]
worker1 ansible_host=$WORKER_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY

[swarm:children]
manager
workers
EOF
echo -e "${GREEN}✅ Đã cập nhật xong file host cho Ansible ($HOSTS_FILE).${NC}"

# --- GITHUB CLI: CÀI ĐẶT & SETUP SECRETS ---

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
        gh secret set SSH_PRIVATE_KEY < "$SSH_KEY"
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

# --- PHASE 4.5: RESET DOCKER SWARM ---

# 7. Xử lý "Swarm treo" do đổi IP
echo -e "${YELLOW}🧹 Đang force-leave (Reset) Swarm cũ trên Manager & Worker...${NC}"
# Sử dụng StrictHostKeyChecking=no để tránh lỗi xác nhận fingerprint khi IP đổi
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$WORKER_IP "sudo docker swarm leave --force" 2>/dev/null || true
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$MANAGER_IP "sudo docker swarm leave --force" 2>/dev/null || true
echo -e "${GREEN}✅ Đã dọn dẹp Swarm state.${NC}"
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$MANAGER_IP" 2>/dev/null || true
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$WORKER_IP" 2>/dev/null || true


# --- PHASE 4.6: ANSIBLE — Cấu hình Server & Docker Swarm ---

# 8. Chạy Ansible để cấu hình Server và Docker Swarm
echo -e "${YELLOW}⚙️ Đang chạy Ansible cấu hình hệ thống với domain: ${DOMAIN_NAME}${NC}"

# Chuyển vào thư mục ansible
cd "$ANSIBLE_DIR"

# Thực thi Playbook
ansible-playbook -i inventory/hosts.ini \
    playbooks/01-bootstrap.yml \
    playbooks/02-swarm.yml \
    playbooks/03-traefik-letsencrypt.yml \
    --extra-vars "domain_name=${DOMAIN_NAME} letsencrypt_email=admin@${DOMAIN_NAME}"

# set -e sẽ tự thoát nếu ansible-playbook lỗi
echo -e "${GREEN}✅ Cấu hình Ansible hoàn tất.${NC}"

# Quay lại thư mục gốc để chuẩn bị cho bước tiếp theo
cd "$PROJECT_ROOT"

# --- KẾT QUẢ VÀ GIT PUSH ---

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
            cd "$PROJECT_ROOT"
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

# --- PHASE 5: MONITORING DEPLOYMENT ---

echo -e "${YELLOW}📊 Đang cấu hình hệ thống giám sát cho Domain: ${DOMAIN_NAME}${NC}"

# CONFIG_VERSION đã được khai báo ở Phase 1, dùng lại ở đây để đảm bảo nhất quán
# Lấy Admin User/Pass từ .env hoặc mặc định
GF_USER=${GF_SECURITY_ADMIN_USER:-admin}
GF_PASS=${GF_SECURITY_ADMIN_PASSWORD:-ChangeMe_123!}

# 2. Chuyển vào thư mục chứa stack monitoring
cd "$MONITORING_DIR" || { echo -e "${RED}❌ Không tìm thấy thư mục Monitoring tại: $MONITORING_DIR${NC}"; exit 1; }

# 3. Deploy Stack Monitoring 
# Lưu ý: Chúng ta truyền DOMAIN_NAME vào để file YAML bốc được
DOMAIN_NAME=$DOMAIN_NAME \
CONFIG_VERSION=$CONFIG_VERSION \
GF_SECURITY_ADMIN_USER=$GF_USER \
GF_SECURITY_ADMIN_PASSWORD=$GF_PASS \
docker stack deploy -c docker-stack.monitoring.yml monitoring --with-registry-auth

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Phase 5 hoàn tất!${NC}"
    echo -e "${CYAN}-------------------------------------------------------${NC}"
    echo -e "${WHITE}🔗 Grafana:    https://grafana.${DOMAIN_NAME}${NC}"
    echo -e "${WHITE}🔗 Prometheus: https://prometheus.${DOMAIN_NAME}${NC}"
    echo -e "${CYAN}-------------------------------------------------------${NC}"
else
    echo -e "${RED}❌ Lỗi khi triển khai Phase 5.${NC}"
    exit 1
fi

# Quay lại thư mục gốc
cd "$PROJECT_ROOT"

# --- PHẦN DỌN DẸP CONFIG RÁC (CLEANUP) ---

echo -e "${YELLOW}🧹 Đang dọn dẹp các Docker Config cũ không còn sử dụng...${NC}"

# Đợi Swarm converge và cập nhật Service sang Config mới
sleep 10

# Lấy danh sách TẤT CẢ config ID đang được service trong stack monitoring sử dụng (ACTIVE)
ACTIVE_CONFIG_IDS=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$MANAGER_IP \
    "docker service inspect \$(docker service ls --filter label=com.docker.stack.namespace=monitoring -q) \
    --format '{{range .Spec.TaskTemplate.ContainerSpec.Configs}}{{.ConfigID}} {{end}}'" 2>/dev/null | tr ' ' '\n' | sort -u)

# Lấy TẤT CẢ config thuộc namespace monitoring
ALL_CONFIGS=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$MANAGER_IP \
    "docker config ls --filter label=com.docker.stack.namespace=monitoring -q" 2>/dev/null)

DELETED=0
if [ -n "$ALL_CONFIGS" ]; then
    for config_id in $ALL_CONFIGS; do
        # Chỉ xóa config KHÔNG nằm trong danh sách active
        if ! echo "$ACTIVE_CONFIG_IDS" | grep -q "$config_id"; then
            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$MANAGER_IP \
                "docker config rm $config_id" > /dev/null 2>&1 && \
            echo -e "${BLUE}  - Đã xóa config cũ: $config_id${NC}"
            DELETED=$((DELETED + 1))
        fi
    done
fi

if [ "$DELETED" -gt 0 ]; then
    echo -e "${GREEN}✨ Đã dọn dẹp $DELETED config cũ!${NC}"
else
    echo -e "${CYAN}ℹ️ Không có config rác nào cần dọn dẹp.${NC}"
fi