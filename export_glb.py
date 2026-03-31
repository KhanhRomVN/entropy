import os
import subprocess
import sys

# ============================================================
# CẤU HÌNH - Sửa biến này cho đúng với máy bạn
# ============================================================
BLENDER_PATH = "blender" # Ubuntu default
# ============================================================

ASSETS_DIR = "./assets"  # Thư mục assets trong Godot project

BLENDER_EXPORT_SCRIPT = """
import bpy, sys, os

blend_file = sys.argv[sys.argv.index('--') + 1]
output_file = sys.argv[sys.argv.index('--') + 2]

bpy.ops.wm.open_mainfile(filepath=blend_file)

bpy.ops.export_scene.gltf(
    filepath=output_file,
    export_format='GLB',
    export_apply=True,
    export_materials='EXPORT',
    export_animations=True,
    export_yup=True,
)
print(f"[OK] Exported: {output_file}")
"""

TEMP_SCRIPT = "__blender_export_temp__.py"

def find_blend_files(root_dir: str) -> list[str]:
    result = []
    for dirpath, _, filenames in os.walk(root_dir):
        for fname in filenames:
            if fname.lower().endswith(".blend"):
                result.append(os.path.join(dirpath, fname))
    return result

def export_blend_to_glb(blend_path: str) -> bool:
    glb_path = os.path.splitext(blend_path)[0] + ".glb"

    if os.path.exists(glb_path):
        os.remove(glb_path)
        print(f"  [DEL] Đã xóa: {glb_path}")

    cmd = [
        BLENDER_PATH,
        "--background",
        "--python", TEMP_SCRIPT,
        "--",
        os.path.abspath(blend_path),
        os.path.abspath(glb_path),
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
    except FileNotFoundError:
        print(f"[ERR] Không tìm thấy '{BLENDER_PATH}'. Vui lòng sửa biến BLENDER_PATH.")
        return False

    if result.returncode != 0 or not os.path.exists(glb_path):
        print(f"  [ERR] Thất bại: {blend_path}")
        print(result.stderr[-500:] if result.stderr else "(no stderr)")
        return False

    size_kb = os.path.getsize(glb_path) // 1024
    print(f"  [OK]  {glb_path} ({size_kb} KB)")
    return True

def main():
    with open(TEMP_SCRIPT, "w", encoding="utf-8") as f:
        f.write(BLENDER_EXPORT_SCRIPT)

    blend_files = find_blend_files(ASSETS_DIR)
    if not blend_files:
        print(f"[INFO] Không tìm thấy file .blend nào trong: {ASSETS_DIR}")
        return

    print(f"[INFO] Tìm thấy {len(blend_files)} file .blend. Bắt đầu export...\n")

    success = 0
    fail = 0
    for blend in blend_files:
        print(f"-> {blend}")
        if export_blend_to_glb(blend):
            success += 1
        else:
            fail += 1
        print()

    if os.path.exists(TEMP_SCRIPT):
        os.remove(TEMP_SCRIPT)

    print("=" * 50)
    print(f"[DONE] Thành công: {success} | Thất bại: {fail}")

if __name__ == "__main__":
    main()
