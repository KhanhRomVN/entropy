import argparse
import os
import sys

try:
    from PIL import Image
except ImportError:
    print("Lỗi: Thư viện 'Pillow' chưa được cài đặt.")
    print("Vui lòng cài đặt bằng lệnh: pip install Pillow")
    sys.exit(1)

def flip_image_horizontal(input_path, output_dir, output_name):
    """
    Đảo ngược ảnh theo phương ngang (hiệu ứng gương).
    """
    # 1. Kiểm tra file đầu vào
    if not os.path.exists(input_path):
        print(f"Lỗi: Không tìm thấy file nguồn tại {input_path}")
        return

    # 2. Đảm bảo thư mục đầu ra tồn tại
    if not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir)
            print(f"Đã tạo thư mục: {output_dir}")
        except Exception as e:
            print(f"Lỗi khi tạo thư mục: {e}")
            return

    # 3. Mở và xử lý ảnh
    try:
        with Image.open(input_path) as img:
            # FLIP_LEFT_RIGHT là đảo ngược theo phương ngang
            flipped_img = img.transpose(Image.FLIP_LEFT_RIGHT)
            
            # 4. Lưu ảnh
            output_path = os.path.join(output_dir, output_name)
            flipped_img.save(output_path)
            print(f"Thành công! Ảnh đã được đảo ngược và lưu tại: {output_path}")
    except Exception as e:
        print(f"Lỗi khi xử lý ảnh: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Công cụ đảo ngược ảnh theo phương ngang (Mirror).")
    parser.add_argument("input", help="Đường dẫn đến file ảnh gốc")
    parser.add_argument("outdir", help="Đường dẫn đến thư mục lưu ảnh đầu ra")
    parser.add_argument("outname", help="Tên file ảnh đầu ra (ví dụ: result.png)")

    # Nếu không có đối số, in hướng dẫn
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()
    flip_image_horizontal(args.input, args.outdir, args.outname)
