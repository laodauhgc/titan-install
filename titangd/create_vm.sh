#!/bin/bash

# ***************************************************
# LƯU Ý:
# 1. Bạn cần phải đăng nhập Google Cloud bằng lệnh:
#    gcloud auth login
#    trước khi chạy script này.
# ***************************************************

# Lấy tên VM từ tham số dòng lệnh
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm=*)
      VM_NAME="${1#*=}"
      shift
      ;;
    *)
      echo "Tham số không hợp lệ: $1"
      exit 1
      ;;
  esac
done

# Kiểm tra xem tên VM đã được cung cấp chưa
if [[ -z "$VM_NAME" ]]; then
  echo "Vui lòng cung cấp tên VM bằng --vm=ten_vm"
  exit 1
fi

# Lấy project ID hiện tại từ cài đặt gcloud
PROJECT_ID=$(gcloud config get-value project)

# Kiểm tra xem Project ID có được tìm thấy không
if [[ -z "$PROJECT_ID" ]]; then
    echo "Không tìm thấy project hiện tại. Vui lòng kiểm tra cấu hình gcloud hoặc đăng nhập lại"
    exit 1
fi

# Lấy email service account mặc định của project
SERVICE_ACCOUNT=$(gcloud iam service-accounts list --project="$PROJECT_ID" --filter="email~compute@developer.gserviceaccount.com"  --format='value(email)')

# Kiểm tra xem Service Account có được tìm thấy không
if [[ -z "$SERVICE_ACCOUNT" ]]; then
    echo "Không tìm thấy service account mặc định của project. Bạn đã đăng nhập đúng tài khoản chưa?"
    exit 1
fi

# URL của các script
fdisk_script_url="https://raw.githubusercontent.com/laodauhgc/titan-install/refs/heads/main/titangd/fdisk.sh"
env_script_url="https://raw.githubusercontent.com/laodauhgc/titan-install/refs/heads/main/titangd/env.sh"

# Tạo startup script kết hợp
STARTUP_SCRIPT=$(cat << EOF
#!/bin/bash

# Đánh dấu rằng script đã chạy để tránh bị chạy lại nhiều lần
if [ -f /tmp/.titan_virtualdisk_configured ]; then
    echo "Virtual disk đã được cấu hình trước đó. Bỏ qua cấu hình lại."
    exit 0
fi

# Tải và chạy fdisk.sh
echo "Tải và chạy fdisk.sh"
curl -s '$fdisk_script_url' | bash

# Kiểm tra xem /titan đã được mount chưa
if mount | grep -q "/titan"; then
    echo "/titan đã mount thành công, tiến hành cài đặt env.sh"
    # Đánh dấu để tránh chạy lại env.sh
    if [ ! -f /tmp/.titan_env_configured ]; then
        echo "Tải và chạy env.sh"
        curl -s '$env_script_url' | bash
        touch /tmp/.titan_env_configured
    else
    echo "env.sh đã được chạy trước đó, bỏ qua"
    fi
else
    echo "/titan chưa được mount, bỏ qua cài đặt env.sh"
fi
# Đánh dấu rằng script đã chạy
touch /tmp/.titan_virtualdisk_configured
EOF
)

# Tạo VM sử dụng tên VM, Project ID, Service Account và Startup Script
gcloud compute instances create "$VM_NAME" \
    --project="$PROJECT_ID" \
    --zone=us-east5-c \
    --machine-type=t2d-standard-8 \
    --network-interface=network-tier=PREMIUM,nic-type=GVNIC,stack-type=IPV4_ONLY,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account="$SERVICE_ACCOUNT" \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
    --enable-display-device \
    --create-disk=auto-delete=yes,boot=yes,device-name="$VM_NAME",image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20241218,mode=rw,size=80,type=pd-ssd \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
    --metadata startup-script="$STARTUP_SCRIPT"

echo "VM $VM_NAME đang được tạo trong project $PROJECT_ID với service account $SERVICE_ACCOUNT và startup script. Vui lòng chờ vài phút."
