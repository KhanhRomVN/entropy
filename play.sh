#!/bin/bash
# Script tự động đồng bộ Asset và chạy Game Godot 4

# 1. Chạy Script đồng bộ Asset (Xóa GLB cũ và xuất GLB mới từ Blender)
echo "[*] Đang đồng bộ hoá Asset từ Blender..."
python3 export_glb_clean.py

# 2. Chạy Game Godot (không cần mở Editor)
# Chế độ chạy:
#   --path . : Chạy project ở thư mục hiện tại
#   --main-scene : (Tuỳ chọn) Chạy một scene cụ thể
echo "[*] Đang khởi động Entropy..."
/home/khanhromvn/.local/bin/godot4 --path .
