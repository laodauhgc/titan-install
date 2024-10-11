#!/bin/bash

# Điểm mount
MOUNT_POINT="/titan"
IMAGE_FILE="/titan/virtualdisk.img"

# Kiểm tra nếu điểm mount tồn tại
if mount | grep -q "$MOUNT_POINT"; then
    # Unmount ổ đĩa ảo
    echo "Đang unmount $MOUNT_POINT..."
    sudo umount "$MOUNT_POINT"
else
    echo "$MOUNT_POINT không được mount."
fi

# Xóa tệp ảnh ảo nếu tồn tại
if [ -f "$IMAGE_FILE" ]; then
    echo "Đang xóa tệp ảnh ảo $IMAGE_FILE..."
    sudo rm "$IMAGE_FILE"
else
    echo "Tệp ảnh ảo $IMAGE_FILE không tồn tại."
fi

# Xóa cấu hình trong /etc/fstab nếu tồn tại
if grep -q "$IMAGE_FILE" /etc/fstab; then
    echo "Xóa cấu hình của $IMAGE_FILE khỏi /etc/fstab..."
    sudo sed -i "\|$IMAGE_FILE|d" /etc/fstab
else
    echo "Không tìm thấy cấu hình của $IMAGE_FILE trong /etc/fstab."
fi

# Xóa thư mục /titan nếu cần
if [ -d "$MOUNT_POINT" ]; then
    echo "Đang xóa thư mục $MOUNT_POINT..."
    sudo rm -rf "$MOUNT_POINT"
fi

echo "Hoàn thành việc xóa ổ đĩa ảo tại $MOUNT_POINT."
