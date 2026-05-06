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
HOSTS_FILE="$ANSIBLE_DIR/inventories/production/hosts.ini"

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
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
    echo -e "${RED}⚠️ Cảnh báo: File .env thiếu thông tin Credentials quan trọng (Access Key, Secret Key hoặc Session Token).${NC}"
    echo -e "${YELLOW}🔄 Đang khởi động lại quá trình Setup...${NC}"
    bash "$SCRIPT_DIR/lab-setup.sh"
    exit 0
fi

# --- HÀM UPSERT BIẾN .ENV ---
upsert_env() {
    local key=$1
    local value=$2
    # Xoá dòng cũ nếu có (bất kể là có bị comment hay không)
    sed -i "/^#\{0,1\}[[:space:]]*${key}=/d" "$ENV_FILE"    # Thêm dòng mới
    echo "${key}=${value}" >> "$ENV_FILE"
}
read_secret() {
      local prompt="$1"
      local secret=""
      # In prompt ra stderr để vẫn thấy khi dùng command substitution
      printf "%s" "$prompt" >&2
      IFS= read -r -s secret
      echo "" >&2
      # Loại CR nếu paste từ clipboard Windows
      secret="${secret%$'\r'}"
      printf "%s" "$secret"
  }
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
# CONFIG_VERSION dùng timestamp — Luôn tạo mới để tránh conflict config cũ
export CONFIG_VERSION=$(date +%s)
upsert_env "CONFIG_VERSION" "$CONFIG_VERSION"

export GF_ADMIN_USER=${GF_SECURITY_ADMIN_USER:-admin}
export GF_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-ChangeMe_123!}
upsert_env "GF_SECURITY_ADMIN_USER" "$GF_ADMIN_USER"
upsert_env "GF_SECURITY_ADMIN_PASSWORD" "$GF_ADMIN_PASSWORD"
echo -e ""
echo -en "${YELLOW}Có muốn cập nhật các giá trị GitHub/Docker Hub ngay bây giờ? (y/n): ${NC}"
read setup_choice
if [ "$setup_choice" = "y" ] || [ "$setup_choice" = "Y" ]; then
    echo -e ""
    echo -e "${YELLOW}🔧 Nhập các thông tin bên dưới (bỏ qua nếu không cần):${NC}"
    
    read -p "GitHub Personal Token (GITHUB_TOKEN) [leave blank to skip]: " input_github_token
    if [ -n "$input_github_token" ]; then
        upsert_env "GITHUB_TOKEN" "$input_github_token"
        export GITHUB_TOKEN="$input_github_token"
        echo -e "${GREEN}✅ Đã cập nhật GITHUB_TOKEN${NC}"
    fi
    
    read -p "Docker Hub Username (DOCKERHUB_USERNAME) [leave blank to skip]: " input_docker_user
    if [ -n "$input_docker_user" ]; then
        upsert_env "DOCKERHUB_USERNAME" "$input_docker_user"
        export DOCKERHUB_USERNAME="$input_docker_user"
        echo -e "${GREEN}✅ Đã cập nhật DOCKERHUB_USERNAME${NC}"
    fi
    
    input_docker_token="$(read_secret "Docker Hub Token (DOCKERHUB_TOKEN) [leave blank to skip]: ")"
    if [ -n "$input_docker_token" ]; then
        upsert_env "DOCKERHUB_TOKEN" "$input_docker_token"
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
    upsert_env "DOMAIN_NAME" "$DOMAIN_NAME"
fi
export DOMAIN_NAME



# --- PHASE 4: KIỂM TRA SSH KEY & LẤY IP ---

# 4. Kiểm tra file .pem
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}❌ Lỗi: Không thấy file $SSH_KEY. Kiểm tra lại config Terraform!${NC}"
    exit 1
fi

# WSL KEY STAGING (không phụ thuộc cứng vào ~/.ssh)
  # Ưu tiên ~/.ssh, nếu không ghi được thì fallback sang /tmp.
  KEY_CANDIDATES=("$HOME/.ssh/final-devops-key.pem" "/tmp/final-devops-key.pem")
  STAGED_KEY=""

  for candidate in "${KEY_CANDIDATES[@]}"; do
      target_dir="$(dirname "$candidate")"
      mkdir -p "$target_dir" 2>/dev/null || true

      if [ -w "$target_dir" ]; then
          # install set luôn permission 600, gọn hơn cp + chmod
          if install -m 600 "$SSH_KEY" "$candidate" 2>/dev/null; then
              STAGED_KEY="$candidate"
              break
          fi
      fi
  done

  if [ -z "$STAGED_KEY" ]; then
      echo -e "${RED}❌ Không thể staging SSH key vào ~/.ssh hoặc /tmp.${NC}"
      echo -e "${YELLOW}➡️ Chạy: sudo chown -R $(whoami):$(whoami) $HOME/.ssh && chmod 700 $HOME/.ssh${NC}"
      exit 1
  fi

  SSH_KEY="$STAGED_KEY"
  upsert_env "SSH_KEY_PATH" "$SSH_KEY"
  echo -e "${GREEN}✅ SSH key đã staging và bảo mật tại: $SSH_KEY${NC}"

# 5. Dùng AWS CLI tự động lấy IP hiện tại
echo -e "${YELLOW}🔍 Đang lấy 2 IP mới nhất từ AWS của cụm Swarm...${NC}"


 MANAGER_IP=$(aws ec2 describe-instances \
      --filters "Name=tag:Role,Values=manager" "Name=instance-state-name,Values=running" \
      --query "Reservations[*].Instances[*].PublicIpAddress" --output text | head -n 1)
# Tìm máy Manager (dựa vào tags)
 WORKER_IPS=$(aws ec2 describe-instances \
      --filters "Name=tag:Role,Values=worker" "Name=instance-state-name,Values=running" \
      --query "Reservations[*].Instances[*].PublicIpAddress" --output text | tr '\t' '\n' | awk 'NF' | sort -u)

  WORKER_IP_PRIMARY=$(echo "$WORKER_IPS" | head -n 1)

  if [ -z "$MANAGER_IP" ] || [ -z "$WORKER_IP_PRIMARY" ]; then
      echo -e "${RED}❌ Không tìm thấy IP manager/worker.${NC}"
      exit 1
  fi

  upsert_env "MANAGER_IP" "$MANAGER_IP"
  upsert_env "WORKER_IP_PRIMARY" "$WORKER_IP_PRIMARY"
  upsert_env "WORKER_IPS" "$(echo "$WORKER_IPS" | paste -sd ',' -)"

# 6. Ghi đè thông tin IP mới vào Ansible hosts.ini
mkdir -p "$(dirname "$HOSTS_FILE")"
cat > "$HOSTS_FILE" <<EOF
# Group name phải khớp với 'hosts:' trong các Ansible playbook
[manager]
manager1 ansible_host=$MANAGER_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY

[workers]
EOF

# Ghi danh sách worker (hỗ trợ nhiều worker nếu có)
i=1
for ip in $WORKER_IPS; do
    echo "worker$i ansible_host=$ip ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY" >> "$HOSTS_FILE"
    i=$((i+1))
done

cat >> "$HOSTS_FILE" <<EOF

[swarm:children]
manager
workers
EOF
echo -e "${GREEN}✅ Đã cập nhật xong file host cho Ansible ($HOSTS_FILE).${NC}"
 if [ -z "${DOCKERHUB_USERNAME:-}" ] || [ -z "${DOCKERHUB_TOKEN:-}" ]; then
      echo -e "${YELLOW}⚠️ Thiếu DOCKERHUB_USERNAME/DOCKERHUB_TOKEN trong .env.${NC}"
      read -p "Nhập Docker Hub Username: " input_docker_user_force
      input_docker_token_force="$(read_secret "Nhập Docker Hub Token: ")"
      echo ""
      if [ -z "$input_docker_user_force" ] || [ -z "$input_docker_token_force" ]; then
          echo -e "${RED}❌ Không thể tiếp tục CI/CD nếu thiếu DockerHub credentials.${NC}"
          exit 1
      fi
      upsert_env "DOCKERHUB_USERNAME" "$input_docker_user_force"
      upsert_env "DOCKERHUB_TOKEN" "$input_docker_token_force"
      export DOCKERHUB_USERNAME="$input_docker_user_force"
      export DOCKERHUB_TOKEN="$input_docker_token_force"
  fi

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
        gh secret set SWARM_SERVICE_NAME --body "app_app" # Đổi tên này thành tên docker swarm service name tương ứng của bạn

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
echo -e "${YELLOW}🧹 Đang force-leave (Reset) Swarm cũ trên Manager & Workers...${NC}"
# Sử dụng StrictHostKeyChecking=no để tránh lỗi xác nhận fingerprint khi IP đổi
for ip in $WORKER_IPS; do
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_KEY" ubuntu@$ip "sudo docker swarm leave --force" 2>/dev/null || true
done
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_KEY" ubuntu@$MANAGER_IP "sudo docker swarm leave --force" 2>/dev/null || true

echo -e "${GREEN}✅ Đã dọn dẹp Swarm state.${NC}"
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$MANAGER_IP" 2>/dev/null || true
for ip in $WORKER_IPS; do
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$ip" 2>/dev/null || true
done


 # --- DNS GATE: xác nhận DNS trước khi tiếp tục ---
  echo -e "${YELLOW}🌐 Kiểm tra DNS trước khi tiếp tục...${NC}"
  echo -e "Cần trỏ các bản ghi sau về: ${GREEN}$MANAGER_IP${NC}"
  echo -e "  - ${DOMAIN_NAME}"
  echo -e "  - grafana.${DOMAIN_NAME}"
  echo -e "  - prometheus.${DOMAIN_NAME}"

  while true; do
    read -p "Bạn đã cấu hình DNS trên TenTen xong chưa? (y/n): " dns_ready
    case "$dns_ready" in
      [Yy]*)
        ROOT_IP=$(nslookup "$DOMAIN_NAME" 2>/dev/null | awk '/^Address: /{print $2}' | tail -n1)
        GRAFANA_IP=$(nslookup "grafana.$DOMAIN_NAME" 2>/dev/null | awk '/^Address: /{print $2}' | tail -n1)
        PROM_IP=$(nslookup "prometheus.$DOMAIN_NAME" 2>/dev/null | awk '/^Address: /{print $2}' | tail -n1)

        if [ "$ROOT_IP" = "$MANAGER_IP" ] && [ "$GRAFANA_IP" = "$MANAGER_IP" ] && [ "$PROM_IP" = "$MANAGER_IP" ]; then
          echo -e "${GREEN}✅ DNS đã đúng. Tiếp tục deploy...${NC}"
          break
        else
          echo -e "${RED}❌ DNS chưa đúng.${NC}"
          echo -e "  root:      ${ROOT_IP:-N/A}"
          echo -e "  grafana:   ${GRAFANA_IP:-N/A}"
          echo -e "  prometheus:${PROM_IP:-N/A}"
        fi
        ;;
      [Nn]*)
        echo -e "${YELLOW}⏸ Tạm dừng. Cấu hình DNS xong thì chạy lại script.${NC}"
        exit 0
        ;;
      *)
        echo "Vui lòng nhập y hoặc n."
        ;;
    esac
  done

# --- PHASE 4.6: ANSIBLE — Cấu hình Server & Docker Swarm ---

# 8. Chạy Ansible để cấu hình Server và Docker Swarm
echo -e "${YELLOW}⚙️ Đang chạy Ansible cấu hình hệ thống với domain: ${DOMAIN_NAME}${NC}"

# Chuyển vào thư mục ansible
cd "$ANSIBLE_DIR"

# Thực thi Playbook
ansible-playbook -i "$HOSTS_FILE" \
    --private-key "$SSH_KEY" \
    playbooks/01-bootstrap.yml \
    playbooks/02-swarm.yml \
    playbooks/03-traefik-letsencrypt.yml \
    --extra-vars "domain_name=${DOMAIN_NAME} letsencrypt_email=admin@${DOMAIN_NAME}"

# set -e sẽ tự thoát nếu ansible-playbook lỗi
echo -e "${GREEN}✅ Cấu hình Ansible hoàn tất.${NC}"

# Quay lại thư mục gốc để chuẩn bị cho bước tiếp theo
cd "$PROJECT_ROOT"

# --- PHASE 4.7: APP DEPLOYMENT ---
echo -e "${YELLOW}🚀 Phase 4.7: Đang chuẩn bị và triển khai Stack Application...${NC}"

# 1. Chờ Traefik sẵn sàng (Network traefik-public phải tồn tại)
echo -e "${YELLOW}⏳ Đang chờ Traefik network sẵn sàng...${NC}"
until ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$MANAGER_IP "docker network ls | grep -q traefik-public" ; do
  echo -n "."
  sleep 2
done
echo -e "${GREEN} OK!${NC}"

# 1.5 Đảm bảo network monitoring tồn tại trước khi deploy app
# Tránh lỗi external network "monitoring" chưa có ở lần chạy đầu.
echo -e "${YELLOW}🕸️ Đảm bảo network monitoring tồn tại...${NC}"
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$MANAGER_IP \
"docker network inspect monitoring >/dev/null 2>&1 || docker network create --driver overlay --attachable monitoring"
echo -e "${GREEN}✅ monitoring network đã sẵn sàng.${NC}"

# 2. Copy file stack lên Manager
echo -e "${YELLOW}📤 Đang copy swarm-stack.yml lên Manager...${NC}"
scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$PROJECT_ROOT/swarm-stack.yml" ubuntu@$MANAGER_IP:/home/ubuntu/swarm-stack.yml

# 3. Deploy App Stack TỪ XA qua SSH
echo -e "${YELLOW}🚀 Đang thực thi docker stack deploy trên Manager...${NC}"
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$MANAGER_IP \
"DOMAIN_NAME=$DOMAIN_NAME \
DOCKER_IMAGE=${DOCKER_IMAGE:-giang/final-tier4-app} \
APP_VERSION=${APP_VERSION:-v1.0.1} \
docker stack deploy -c /home/ubuntu/swarm-stack.yml app --with-registry-auth"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Triển khai Application thành công.${NC}"
    echo -e "${YELLOW}⏳ Đang chờ App hội tụ...${NC}"
    sleep 15
else
    echo -e "${RED}❌ Lỗi khi triển khai Application.${NC}"
    exit 1
fi

# --- DỌN DẸP CONFIG RÁC VÀ GIT PUSH ---
echo -e "=========================================================="

# --- PHASE 5: MONITORING DEPLOYMENT ---

echo -e "${YELLOW}📊 Đang cấu hình hệ thống giám sát cho Domain: ${DOMAIN_NAME}${NC}"

# CONFIG_VERSION đã được khai báo ở Phase 1, dùng lại ở đây để đảm bảo nhất quán
# Lấy Admin User/Pass từ .env hoặc mặc định
GF_USER=${GF_SECURITY_ADMIN_USER:-admin}
GF_PASS=${GF_SECURITY_ADMIN_PASSWORD:-ChangeMe_123!}

# 2. Copy thư mục monitoring lên Manager
echo -e "${YELLOW}📤 Đang đồng bộ thư mục monitoring lên Manager...${NC}"
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$MANAGER_IP "mkdir -p /home/ubuntu/monitoring"
scp -o StrictHostKeyChecking=no -r -i "$SSH_KEY" "$MONITORING_DIR/"* ubuntu@$MANAGER_IP:/home/ubuntu/monitoring/

# 3. Deploy Stack Monitoring TỪ XA
echo -e "${YELLOW}🚀 Đang thực thi docker stack deploy monitoring trên Manager...${NC}"
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$MANAGER_IP \
"cd /home/ubuntu/monitoring && \
DOMAIN_NAME=$DOMAIN_NAME \
CONFIG_VERSION=$CONFIG_VERSION \
GF_SECURITY_ADMIN_USER=$GF_USER \
GF_SECURITY_ADMIN_PASSWORD=$GF_PASS \
docker stack deploy -c docker-stack.monitoring.yml monitoring --with-registry-auth"

if [ $? -eq 0 ]; then
    echo -e "${YELLOW}⏳ Đang chờ hệ thống Monitoring sẵn sàng (60s)...${NC}"
    # Chờ các service hội tụ (converge)
    sleep 30
    echo -e "${YELLOW}🔍 Kiểm tra trạng thái các service...${NC}"
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@$MANAGER_IP "docker service ls --filter label=com.docker.stack.namespace=monitoring"
    
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

# --- PHẦN DỌN DẸP CONFIG RÁC (CLEANUP) ------

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
        # Chỉ xóa config KHÔNG nằm trong danh sách active (Dùng grep -Fxq để match chính xác nguyên dòng)
        if ! echo "$ACTIVE_CONFIG_IDS" | grep -Fxq "$config_id"; then
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
 # --- KẾT QUẢ & GIT PUSH ---
  TARGET_BRANCH=${GIT_BRANCH:-main}

  echo -e ""
  echo -e "${GREEN}🎉 HOÀN TẤT PIPELINE HẠ TẦNG + SWARM + APP + MONITORING${NC}"
  echo -e "👉 ${YELLOW}Manager: $MANAGER_IP${NC}"
  echo -e "👉 ${YELLOW}Workers: $(echo "$WORKER_IPS" | tr '\n' ' ')${NC}"

  while true; do
      echo -en "${YELLOW}Có muốn script tự động git push lên nhánh $TARGET_BRANCH để chạy GitHub Actions không? (y/n): ${NC}"
      read yn
      case $yn in
          [Yy]* )
              cd "$PROJECT_ROOT"
              git push origin "$TARGET_BRANCH"
              echo -e "${GREEN}✅ Đã push. Kiểm tra tab Actions để theo dõi CI/CD.${NC}"
              break;;
          [Nn]* )
              echo -e "${YELLOW}ℹ️ Bỏ qua tự động push. Bạn có thể chạy: git push origin $TARGET_BRANCH${NC}"
              break;;
          * ) echo -e "${RED}Vui lòng chọn y hoặc n.${NC}";;
      esac
  done