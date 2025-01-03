#!/bin/bash

# ***************************************************
# LƯU Ý:
# 1. Bạn cần phải đăng nhập Google Cloud bằng lệnh:
#    gcloud auth login
#    trước khi chạy script này.
# ***************************************************

# Danh sách các tên VM hợp lệ
declare -a VALID_VM_NAMES=("titangd-01" "titangd-02" "titangd-03" "av-titangd-01")

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

# Kiểm tra xem tên VM có hợp lệ không
is_valid=false
for valid_name in "${VALID_VM_NAMES[@]}"; do
  if [[ "$VM_NAME" == "$valid_name" ]]; then
    is_valid=true
    break
  fi
done

if ! $is_valid; then
  echo "Tên VM không hợp lệ: '$VM_NAME'. Phải là một trong: ${VALID_VM_NAMES[*]}"
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

# URL của startup script trên Github
startup_script_url="https://raw.githubusercontent.com/laodauhgc/titan-install/refs/heads/main/titangd/full-env.sh"

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
    --metadata=startup-script-url="$startup_script_url",vm_name="$VM_NAME" \

echo "VM $VM_NAME đang được tạo trong project $PROJECT_ID với service account $SERVICE_ACCOUNT và startup script. Vui lòng chờ vài phút."
