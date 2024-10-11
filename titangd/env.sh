#!/bin/bash

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
sudo cat /etc/rancher/k3s/k3s.yaml | tee ~/.kube/config >/dev/null
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

echo "Cài đặt môi trường hoàn tất!"

echo "***"
echo "Bạn cần copy thư mục .titancandidate đã backup trước đó vào thư muc /root trước khi khởi động L1"
echo "Sau khi copy xong chỉ cần chạy lệnh: systemctl start titand.service"
echo "DONE."
