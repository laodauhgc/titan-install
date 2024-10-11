#!/bin/bash

# Định nghĩa biến cho ổ đĩa
DISK="/dev/sdb"
PARTITION="${DISK}1"
MOUNTPOINT="/titan"

# Kiểm tra xem ổ đĩa có phân vùng hay không
if lsblk | grep -q "^$PARTITION"; then
    echo "Phân vùng $PARTITION đã tồn tại."
else
    echo "Đang tạo phân vùng trên $DISK..."
    
    # Tạo phân vùng với GPT và hệ thống tập tin ext4
    sudo parted "$DISK" mklabel gpt --script
    sudo parted -a optimal "$DISK" mkpart primary ext4 0% 100% --script
    sudo mkfs.ext4 "$PARTITION"
fi

# Tạo thư mục mountpoint nếu chưa tồn tại
if [ ! -d "$MOUNTPOINT" ]; then
    echo "Đang tạo thư mục $MOUNTPOINT..."
    sudo mkdir -p "$MOUNTPOINT"
fi

# Mount phân vùng vào mountpoint
if ! mount | grep -q "$PARTITION"; then
    echo "Đang mount phân vùng $PARTITION vào $MOUNTPOINT..."
    sudo mount "$PARTITION" "$MOUNTPOINT"
else
    echo "$MOUNTPOINT đã được mount."
fi

# Thêm vào /etc/fstab để mount tự động sau khi khởi động lại
UUID=$(sudo blkid -s UUID -o value "$PARTITION")
if ! grep -q "$UUID" /etc/fstab; then
    echo "Thêm $UUID vào /etc/fstab để mount tự động..."
    echo "UUID=$UUID $MOUNTPOINT ext4 defaults 0 0" | sudo tee -a /etc/fstab
fi

# Hiển thị thông tin phân vùng
df -h
echo "Hoàn thành!"
