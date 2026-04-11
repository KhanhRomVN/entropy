#!/bin/bash

# Tìm tất cả các file scene trong thư mục scenes
SCENES=($(find scenes -name "*.tscn"))

if [ ${#SCENES[@]} -eq 0 ]; then
    echo "Không tìm thấy file .tscn nào trong thư mục scenes/"
    exit 1
fi

echo "--- Vui lòng chọn Scene để chạy ---"
select scene in "${SCENES[@]}"; do
    if [ -n "$scene" ]; then
        echo "Đang chạy scene: $scene"
        # Chạy godot4 với scene đã chọn
        /home/khanhromvn/.local/bin/godot4 "$scene"
        break
    else
        echo "Lựa chọn không hợp lệ. Vui lòng chọn lại."
    fi
done
