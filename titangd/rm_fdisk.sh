#!/bin/bash

# Đường dẫn tệp ảnh ảo và điểm mount
IMAGE_FILE="/titan/virtualdisk.img"
MOUNT_POINT="/titan"

# Kiểm tra nếu tệp ảnh tồn tại
if [ -f "$IMAGE_FILE" ]; then
    # Unmount nếu đang mount
    if mount | grep -q "$MOUNT_POINT"; then
        echo "Unmounting $MOUNT_POINT..."
        sudo umount "$MOUNT_POINT"
    else
        echo "$MOUNT_POINT không được mount."
    fi

    # Xóa cấu hình trong /etc/fstab nếu tồn tại
    if grep -q "$IMAGE_FILE" /etc/fstab; then
        echo "Xóa cấu hình của $IMAGE_FILE khỏi /etc/fstab..."
        sudo sed -i "\|$IMAGE_FILE|d" /etc/fstab
    else
        echo "Không tìm thấy cấu hình của $IMAGE_FILE trong /etc/fstab."
    fi

    # Xóa tệp ảnh ảo
    echo "Đang xóa tệp $IMAGE_FILE..."
    sudo rm "$IMAGE_FILE"

    # Xóa thư mục /titan nếu cần
    if [ -d "$MOUNT_POINT" ]; then
        echo "Đang xóa thư mục $MOUNT_POINT..."
        sudo rm -rf "$MOUNT_POINT"
    fi

    echo "Hoàn thành việc xóa ổ đĩa ảo /titan."
else
    echo "Tệp $IMAGE_FILE không tồn tại."
fi
