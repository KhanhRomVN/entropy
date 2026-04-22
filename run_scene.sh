#!/bin/bash

# Tìm tất cả các file scene trong thư mục scenes
SCENES=($(find scenes -name "*.tscn"))

if [ ${#SCENES[@]} -eq 0 ]; then
    echo "Không tìm thấy file .tscn nào trong thư mục scenes/"
    exit 1
fi

LOG_DIR="logs"
LOG_FILE="$LOG_DIR/log.log"

# Tạo thư mục log nếu chưa có
mkdir -p "$LOG_DIR"

echo "--- Vui lòng chọn Scene để chạy ---"
select scene in "${SCENES[@]}"; do
    if [ -n "$scene" ]; then
        echo "Đang chạy scene: $scene"
        echo "[LOG] Toàn bộ log sẽ được ghi đè vào: $LOG_FILE"
        
        # Xóa log cũ để ghi đè log mới cho phiên này
        > "$LOG_FILE"
        
        # Chạy godot4 với scene đã chọn và các flag debug
        /home/khanhromvn/.local/bin/godot4 "$scene" --verbose 2>&1 | tee "$LOG_FILE"
        
        echo ""
        echo "--- Phiên chạy kết thúc ---"
        echo "Phân tích nhanh log:"
        echo "  Errors  : $(grep -c '^ERROR' "$LOG_FILE" 2>/dev/null || echo 0)"
        echo "  Warnings: $(grep -c '^WARNING' "$LOG_FILE" 2>/dev/null || echo 0)"
        echo "Log đầy đủ tại: $LOG_FILE"
        break
    else
        echo "Lựa chọn không hợp lệ. Vui lòng chọn lại."
    fi
done
