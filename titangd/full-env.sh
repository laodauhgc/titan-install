#!/bin/bash

# Lấy tham số vm_name từ metadata của VM
vm_name=$(/usr/bin/curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/vm_name" -H "Metadata-Flavor: Google")

if [[ -z "$vm_name" ]]; then
    echo "Error: VM name not found in metadata."
    exit 1
fi

# Hàm để kiểm tra và cài đặt unzip nếu cần
check_and_install_unzip() {
  if ! command -v unzip &> /dev/null; then
    echo "unzip is not installed. Installing..."
    apt update
    apt install -y unzip
    if [ $? -ne 0 ]; then
      echo "Error: Failed to install unzip."
      return 1
    fi
    echo "unzip installed successfully."
  fi
  return 0
}

# Hàm để tải và giải nén file
download_and_unzip() {
  local name="$1"
  local zip_url=""
  local zip_file=""

  case "$name" in
    "titangd-01")
      zip_url="https://utfs.io/f/iLnP4naFfLyou7wMYiIL3EU9P6nKYajv7w1BfqkoQOJcg28d"
      zip_file="titangd-01.zip"
      ;;
    "titangd-02")
      zip_url="https://utfs.io/f/iLnP4naFfLyoJugj0Nf4uKtLS2edD0fGlbpWI5M8rH7YhsF4"
      zip_file="titangd-02.zip"
      ;;
    "titangd-03")
      zip_url="https://utfs.io/f/iLnP4naFfLyo52KeRHGRCUsieyqpxZb1nJzDFOkN7mKAE380"
      zip_file="titangd-03.zip"
      ;;
     "av-titangd-01")
      zip_url="https://utfs.io/f/iLnP4naFfLyovfGs2nB0UWw1V3L2nYtgPIJdcuR8GaQKqyDE"
      zip_file="av-titangd-01.zip"
       ;;
    *)
      echo "Error: Invalid VM name '$name'. Must be one of: titangd-01, titangd-02, titangd-03, av-titangd-01"
      return 1
      ;;
  esac

  echo "Downloading $zip_file..."
  wget -O "$zip_file" "$zip_url"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to download $zip_file"
    return 1
  fi

  echo "Unzipping $zip_file..."
  unzip "$zip_file"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to unzip $zip_file"
    return 1
  fi


  local folder_name=$(echo "$zip_file" | sed 's/\.zip$//')

  #Copy file titancandidate vào thư mục root

  if [ -d "$folder_name"/.titancandidate ]; then
    echo "Copying .titancandidate folder to /root"
    cp -r "$folder_name"/.titancandidate /root
    if [ $? -ne 0 ]; then
       echo "Error: Failed to copy .titancandidate folder to /root"
       return 1
    fi

     echo "Copy .titancandidate folder to /root successfully"
  else
    echo "Error: .titancandidate folder not found in extracted folder"
    return 1
  fi

  echo "Finished processing $name"
  return 0
}

# Chờ 30 giây trước khi tải
sleep 30s

# Kiểm tra và cài đặt unzip trước khi tiếp tục
check_and_install_unzip
if [ $? -ne 0 ]; then
  exit 1
fi


# Gọi hàm download và unzip
download_and_unzip "$vm_name"
if [ $? -ne 0 ]; then
    echo "Error: download_and_unzip function failed."
    exit 1
fi

# Tạo thư mục /titan
mkdir -p /titan

# Kiểm tra nếu tệp ảnh đã tồn tại, nếu không thì tạo
if [ ! -f /titan/virtualdisk.img ]; then
    echo "Đang tạo tệp ảnh ảo 4TB..."
    dd if=/dev/zero of=/titan/virtualdisk.img bs=1M count=0 seek=10000000
else
    echo "Tệp ảnh đã tồn tại."
fi

# Kiểm tra nếu hệ thống tập tin đã được tạo trên tệp ảnh
if ! file -s /titan/virtualdisk.img | grep -q ext4; then
    echo "Đang tạo hệ thống tập tin ext4 trên tệp ảnh..."
    mkfs.ext4 /titan/virtualdisk.img
else
    echo "Hệ thống tập tin đã được tạo."
fi

# Mount tệp ảnh vào thư mục /titan
if ! mount | grep -q "/titan"; then
    echo "Đang mount tệp ảnh vào /titan..."
    mount -o loop /titan/virtualdisk.img /titan
else
    echo "/titan đã được mount."
fi
# Kiểm tra và thêm mục vào /etc/fstab nếu chưa có
if ! grep -q "/titan/virtualdisk.img" /etc/fstab; then
    echo "Thêm cấu hình mount tự động vào /etc/fstab..."
    echo "/titan/virtualdisk.img /titan ext4 loop 0 0" | tee -a /etc/fstab > /dev/null
else
    echo "Mục fstab đã tồn tại."
fi

echo "Hoàn thành!"

sleep 15s

# Kiểm tra và tạo thư mục /titan/storage
if [ ! -d "/titan/storage" ]; then
    mkdir -p /titan/storage
    chmod -R 777 /titan/storage
    echo "Thư mục /titan/storage đã được tạo và cấp quyền 777."
else
    echo "Thư mục /titan/storage đã tồn tại."
fi

# Cài đặt K3s
echo "Bắt đầu cài đặt K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -s -
echo "K3s đã được cài đặt."

# Cấu hình kubeconfig
echo "Cấu hình kubeconfig..."
mkdir -p ~/.kube
cat /etc/rancher/k3s/k3s.yaml | tee ~/.kube/config >/dev/null
echo "kubeconfig đã được cấu hình."

# Xác minh cài đặt K3s
echo "Xác minh cài đặt K3s..."
kubectl get nodes

# Cài đặt Helm
echo "Bắt đầu cài đặt Helm..."
wget https://get.helm.sh/helm-v3.11.0-linux-amd64.tar.gz
tar -zxvf helm-v3.11.0-linux-amd64.tar.gz
install linux-amd64/helm /usr/local/bin/helm
echo "Helm đã được cài đặt."

# Cài đặt Ingress Nginx
echo "Cài đặt Ingress Nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
echo "Ingress Nginx đã được cài đặt."

# Cấu hình StorageClass
echo "Cấu hình StorageClass..."
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
cat <<EOF > storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
parameters:
  path: "/titan/storage"
EOF

kubectl apply -f storageclass.yaml
kubectl patch configmap local-path-config -n kube-system --type=json -p='[{"op": "replace", "path": "/data/config.json", "value":"{\n  \"nodePathMap\":[\n  {\n    \"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\n    \"paths\":[\"/titan/storage\"]\n  }\n  ]\n}"}]'
echo "StorageClass đã được cấu hình."

# Tải xuống và cài đặt titan-L1 guardian
echo "Tải xuống titan-L1 guardian..."
wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.21/titan-l1-guardian
mv titan-l1-guardian /usr/local/bin/
chmod 0755 /usr/local/bin/titan-l1-guardian
echo "titan-L1 guardian đã được cài đặt."

# Tạo file systemd cho titan L1 node
echo "Tạo file systemd cho titan L1 node..."
cat <<EOF > /etc/systemd/system/titand.service
[Unit]
Description=Titan L1 Guardian Node
After=network.target
StartLimitIntervalSec=0

[Service]
User=root
Environment="QUIC_GO_DISABLE_ECN=true"
Environment="TITAN_METADATAPATH=/titan/storage"
Environment="TITAN_ASSETSPATHS=/titan/storage"
ExecStart=titan-l1-guardian daemon start
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

# Kích hoạt dịch vụ systemd
echo "Kích hoạt titand.service..."
systemctl enable titand.service
echo "Dịch vụ titan L1 đã được kích hoạt."
