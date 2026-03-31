#!/bin/bash
# Script đóng gói Đa nền tảng với Menu lựa chọn (Entropy)

GODOT_BIN="/home/khanhromvn/.local/bin/godot4"
DIST_DIR="dist"

# Hàm thực hiện Export
export_platform() {
    local platform_name=$1
    local preset_name=$2
    local output_path=$3
    
    echo "----------------------------------------------------------"
    echo "[*] Đang đóng gói bản $platform_name..."
    mkdir -p $(dirname "$output_path")
    $GODOT_BIN --headless --export-release "$preset_name" "$output_path"
    
    if [ $? -eq 0 ]; then
        echo "[OK] Thành công: $output_path"
        if [[ "$platform_name" == "LINUX" ]]; then chmod +x "$output_path"; fi
    else
        echo "[!] THẤT BẠI: $platform_name"
    fi
}

echo "=========================================================="
echo "      HỆ THỐNG ĐÓNG GÓI ENTROPY (PRO)             "
echo "=========================================================="
echo "1) Build LINUX"
echo "2) Build WINDOWS"
echo "3) Build ANDROID"
echo "4) Build TẤT CẢ (All Platforms)"
echo "5) Thoát"
echo "----------------------------------------------------------"
read -p "Chọn nền tảng bạn muốn build (1-5): " choice

# 1. Đồng bộ Assets trước khi build (nếu không thoát)
if [ "$choice" != "5" ]; then
    echo "[*] Đang đồng bộ hoá Asset từ Blender..."
    python3 export_glb_clean.py
fi

case $choice in
    1)
        export_platform "LINUX" "Linux/X11" "$DIST_DIR/linux/entropy.x86_64"
        ;;
    2)
        export_platform "WINDOWS" "Windows Desktop" "$DIST_DIR/window/entropy.exe"
        ;;
    3)
        export_platform "ANDROID" "Android" "$DIST_DIR/android/entropy.apk"
        ;;
    4)
        export_platform "LINUX" "Linux/X11" "$DIST_DIR/linux/entropy.x86_64"
        export_platform "WINDOWS" "Windows Desktop" "$DIST_DIR/window/entropy.exe"
        export_platform "ANDROID" "Android" "$DIST_DIR/android/entropy.apk"
        ;;
    5)
        echo "[*] Đã thoát."
        exit 0
        ;;
    *)
        echo "[!] Lựa chọn không hợp lệ."
        exit 1
        ;;
esac

echo ""
echo "=========================================================="
echo "QUÁ TRÌNH KẾT THÚC."
echo "=========================================================="
