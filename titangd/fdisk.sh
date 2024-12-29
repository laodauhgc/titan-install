#!/bin/bash

# Tạo thư mục /titan
sudo mkdir -p /titan

# Kiểm tra nếu tệp ảnh đã tồn tại, nếu không thì tạo
if [ ! -f /titan/virtualdisk.img ]; then
    echo "Đang tạo tệp ảnh ảo 4TB..."
    sudo dd if=/dev/zero of=/titan/virtualdisk.img bs=1M count=0 seek=10000000
else
    echo "Tệp ảnh đã tồn tại."
fi

# Kiểm tra nếu hệ thống tập tin đã được tạo trên tệp ảnh
if ! sudo file -s /titan/virtualdisk.img | grep -q ext4; then
    echo "Đang tạo hệ thống tập tin ext4 trên tệp ảnh..."
    sudo mkfs.ext4 /titan/virtualdisk.img
else
    echo "Hệ thống tập tin đã được tạo."
fi

# Mount tệp ảnh vào thư mục /titan
if ! mount | grep -q "/titan"; then
    echo "Đang mount tệp ảnh vào /titan..."
    sudo mount -o loop /titan/virtualdisk.img /titan
else
    echo "/titan đã được mount."
fi
# Kiểm tra và thêm mục vào /etc/fstab nếu chưa có
if ! grep -q "/titan/virtualdisk.img" /etc/fstab; then
    echo "Thêm cấu hình mount tự động vào /etc/fstab..."
    echo "/titan/virtualdisk.img /titan ext4 loop 0 0" | sudo tee -a /etc/fstab > /dev/null
else
    echo "Mục fstab đã tồn tại."
fi

echo "Hoàn thành!"

reboot
