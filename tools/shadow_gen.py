import os
from PIL import Image, ImageOps, ImageFilter

# Thư mục gốc cần quét (Bao gồm tất cả thư mục con bên trong)
ROOT_DIR = "assets/tiles"

# Cấu hình bóng đổ
SHADOW_COLOR = (40, 40, 40) # Màu xám tối
SHADOW_ALPHA_MULT = 0.6     # Độ đậm của bóng (0.0 - 1.0)
SQUASH_FACTOR = 1.0         # Giữ nguyên tỉ lệ (theo yêu cầu)
ROTATE_180 = False          # Không xoay ngược bóng (theo yêu cầu mới)
BLUR_RADIUS = 2             # Độ mờ viền

def generate_shadow(image_path):
    # Đường dẫn file bóng
    base, ext = os.path.splitext(image_path)
    shadow_path = f"{base}_shadow{ext}"
    
    # Ở phiên bản này, ta sẽ ghi đè bóng cũ nếu người dùng muốn thay đổi style
    # Nếu bạn muốn giữ file cũ, hãy bỏ check shadow_path
    if image_path.endswith("_shadow.png"):
        return False

    try:
        with Image.open(image_path) as img:
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # 1. Tạo Silhouette (Lấy Alpha của ảnh gốc đè lên màu bóng)
            r, g, b, a = img.split()
            a = a.point(lambda p: p * SHADOW_ALPHA_MULT)
            
            shadow = Image.merge('RGBA', (
                Image.new('L', img.size, SHADOW_COLOR[0]),
                Image.new('L', img.size, SHADOW_COLOR[1]),
                Image.new('L', img.size, SHADOW_COLOR[2]),
                a
            ))
            
            # 2. Xoay 180 độ (nếu cấu hình)
            if ROTATE_180:
                shadow = shadow.rotate(180)
            
            # 3. Bóp bẹt (Resize Height 1.0 = không bóp)
            new_size = (img.width, int(img.height * SQUASH_FACTOR))
            # Nếu size không đổi, ta có thể bỏ qua resize để giữ quality
            if SQUASH_FACTOR != 1.0:
                shadow = shadow.resize(new_size, Image.Resampling.LANCZOS)
            
            # 4. Làm mờ viền (Soft Shadow)
            shadow = shadow.filter(ImageFilter.GaussianBlur(BLUR_RADIUS))
            
            # 4. Lưu lại
            shadow.save(shadow_path)
            print(f"  [CREATED] {os.path.relpath(shadow_path, ROOT_DIR)}")
            return True
            
    except Exception as e:
        print(f"  [ERROR] {image_path}: {e}")
        return False

def main():
    print("=== Entropy Recursive Shadow Generator ===")
    if not os.path.exists(ROOT_DIR):
        print(f"Error: Directory {ROOT_DIR} not found!")
        return

    count = 0
    print(f"Scanning all folders inside: {ROOT_DIR}...")
    
    for root, dirs, files in os.walk(ROOT_DIR):
        for filename in files:
            # Chỉ xử lý file PNG, không phải là shadow, và không phải là normal map
            if filename.lower().endswith(".png") and not filename.endswith("_shadow.png"):
                if "normal_map" in filename.lower():
                    continue
                
                full_path = os.path.join(root, filename)
                if generate_shadow(full_path):
                    count += 1
    
    print(f"=== Done! Processed {count} new shadows ===")

if __name__ == "__main__":
    main()
