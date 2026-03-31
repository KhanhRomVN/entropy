import os
import subprocess
import sys

# ============================================================
# CẤU HÌNH - Sửa biến này cho đúng với máy bạn (Ubuntu mặc định là "blender")
# ============================================================
BLENDER_PATH = "blender" 
ASSETS_DIR = "./assets"

# Script Python chạy bên trong Blender để export
BLENDER_EXPORT_SCRIPT = """
import bpy, sys, os

blend_file = sys.argv[sys.argv.index('--') + 1]
output_file = sys.argv[sys.argv.index('--') + 2]

bpy.ops.wm.open_mainfile(filepath=blend_file)

# Export sang GLB
bpy.ops.export_scene.gltf(
    filepath=output_file,
    export_format='GLB',
    export_apply=True,
    export_materials='EXPORT',
    export_animations=True,
    export_yup=True,
)
"""

TEMP_SCRIPT_NAME = "__tmp_export_script.py"

def main():
    # 1. Tạo script tạm cho Blender
    with open(TEMP_SCRIPT_NAME, "w", encoding="utf-8") as f:
        f.write(BLENDER_EXPORT_SCRIPT)

    print(f"[*] Đang quét thư mục: {ASSETS_DIR}")
    
    blend_files = []
    for root, dirs, files in os.walk(ASSETS_DIR):
        for file in files:
            if file.lower().endswith(".blend"):
                blend_files.append(os.path.join(root, file))

    if not blend_files:
        print("[!] Không tìm thấy file .blend nào.")
        return

    print(f"[!] Tìm thấy {len(blend_files)} file .blend.")

    success_count = 0
    for blend_path in blend_files:
        # Xác định đường dẫn file glb tương ứng
        glb_path = os.path.splitext(blend_path)[0] + ".glb"
        
        print(f"\n--- Xử lý: {os.path.basename(blend_path)} ---")
        
        # 2. Xóa file .glb cũ nếu có
        if os.path.exists(glb_path):
            try:
                os.remove(glb_path)
                print(f"[X] Đã xóa file .glb cũ: {os.path.basename(glb_path)}")
            except Exception as e:
                print(f"[!] Lỗi khi xóa file .glb: {e}")
        
        # 3. Export file .glb mới
        print(f"[>] Đang export sang .glb...")
        cmd = [
            BLENDER_PATH,
            "--background",
            "--python", TEMP_SCRIPT_NAME,
            "--",
            os.path.abspath(blend_path),
            os.path.abspath(glb_path)
        ]
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0 and os.path.exists(glb_path):
                print(f"[OK] Export thành công: {os.path.basename(glb_path)}")
                success_count += 1
            else:
                print(f"[ERR] Thất bại khi export {os.path.basename(blend_path)}")
                print(result.stderr)
        except Exception as e:
            print(f"[!] Lỗi thực thi Blender: {e}")

    # Xóa script tạm
    if os.path.exists(TEMP_SCRIPT_NAME):
        os.remove(TEMP_SCRIPT_NAME)

    print("\n" + "="*30)
    print(f"[HOÀN TẤT] Đã xử lý xong {len(blend_files)} file. Thành công: {success_count}")
    print("="*30)

if __name__ == "__main__":
    main()
