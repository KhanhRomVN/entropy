#!/bin/bash

# =============================================================================
# DEBUG SCENE RUNNER - Tối đa hóa log output để phân tích FPS
# =============================================================================

SCENES=($(find scenes -name "*.tscn"))

if [ ${#SCENES[@]} -eq 0 ]; then
    echo "Không tìm thấy file .tscn nào trong thư mục scenes/"
    exit 1
fi

echo ""
echo "========================================="
echo "  ENTROPY - DEBUG MODE LOG RUNNER"
echo "========================================="
echo ""
echo "--- Chọn Scene ---"
select scene in "${SCENES[@]}"; do
    if [ -n "$scene" ]; then
        echo ""
        echo "[DEBUG] Đang chạy scene: $scene"
        echo "[DEBUG] Các flag debug đang bật:"
        echo "  --verbose       : Log chi tiết Engine internals"
        echo "  --debug-collisions : Hiển thị collision shapes"
        echo ""

        # Tạo thư mục log nếu chưa có
        mkdir -p logs

        # Timestamp cho tên file log
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        LOG_FILE="logs/debug_${TIMESTAMP}.log"

        echo "[DEBUG] Log sẽ được lưu vào: $LOG_FILE"
        echo "========================================="
        echo ""

        # Chạy Godot với TOÀN BỘ các flag debug
        /home/khanhromvn/.local/bin/godot4 \
            "$scene" \
            --verbose \
            2>&1 | tee "$LOG_FILE"

        echo ""
        echo "========================================="
        echo "[DEBUG] Session kết thúc. Log đã lưu: $LOG_FILE"
        echo ""
        echo "Phân tích nhanh:"
        echo "  FPS Alerts   : $(grep -c 'ALERT.*FPS' "$LOG_FILE" 2>/dev/null || echo 0) lần"
        echo "  Slow Frames  : $(grep -c 'SLOW FRAME' "$LOG_FILE" 2>/dev/null || echo 0) lần"
        echo "  Errors       : $(grep -c '^ERROR' "$LOG_FILE" 2>/dev/null || echo 0) lần"
        echo "  Warnings     : $(grep -c '^WARNING' "$LOG_FILE" 2>/dev/null || echo 0) lần"
        echo ""
        echo "Xem log:"
        echo "  cat $LOG_FILE"
        echo "  grep 'ALERT\\|SLOW\\|ERROR' $LOG_FILE"
        echo "========================================="
        break
    else
        echo "Lựa chọn không hợp lệ. Vui lòng chọn lại."
    fi
done
