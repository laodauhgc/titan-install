#!/bin/bash

# Điểm mount
MOUNT_POINT="/titan"

# Kiểm tra nếu điểm mount tồn tại
if mount | grep -q "$MOUNT_POINT"; then
    # Unmount ổ đĩa ảo
    echo "Unmounting $MOUNT_POINT..."
    sudo umount "$MOUNT_POINT"
else
    echo "$MOUNT_POINT không được mount."
fi

# Tìm và xóa tệp ảnh ảo
IMAGE_FILE=$(mount | grep "$MOUNT_POINT" | awk '{print $1}')
if [ ! -z "$IMAGE_FILE" ]; then
    echo "Tệp ảnh ảo tại $MOUNT_POINT là: $IMAGE_FILE"
    
    # Xóa cấu hình trong /etc/fstab nếu tồn tại
    if grep -q "$IMAGE_FILE" /etc/fstab; then
        echo "Xóa cấu hình của $IMAGE_FILE khỏi /etc/fstab..."
        sudo sed -i "\|$IMAGE_FILE|d" /etc/fstab
    fi

    # Xóa tệp ảnh ảo
    echo "Đang xóa tệp ảnh ảo $IMAGE_FILE..."
    sudo rm "$IMAGE_FILE"
else
    echo "Không tìm thấy tệp ảnh ảo nào để xóa."
fi

# Xóa thư mục /titan nếu cần
if [ -d "$MOUNT_POINT" ]; then
    echo "Đang xóa thư mục $MOUNT_POINT..."
    sudo rm -rf "$MOUNT_POINT"
fi

echo "Hoàn thành việc xóa ổ đĩa ảo tại $MOUNT_POINT."
