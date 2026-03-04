# Entropy

Entropy là một dự án game quy mô lớn được xây dựng bằng **Java** và **LibGDX**, lấy cảm hứng từ cấu trúc bền vững và khả năng mở rộng của **Mindustry**.

## 🚀 Tính năng hiện tại

- **Dashboard (Main Menu)**: Giao diện hiện đại với các lựa chọn Campaign, Mods, Maps, và Settings.
- **Campaign Management**: Hệ thống quản lý bản đồ chiến dịch (Earth, Moon, Mars).
- **Map Editor**: Công cụ tạo bản đồ tích hợp sẵn các Toolbar (Terrain, Blocks, Lighting).
- **Hệ thống Content**: Kiến trúc quản lý Block và Planet linh hoạt, dễ dàng thêm nội dung mới.
- **Stone Block**: Khối cơ bản đầu tiên đã được tích hợp.

## 🏗️ Kiến trúc dự án

Dự án được thiết kế để tối ưu hóa việc quản lý tài nguyên và mở rộng:

- `core/src/entropy/Vars.java`: Lưu trữ các biến hệ thống và tham chiếu toàn cục.
- `core/src/entropy/content/`: Chứa định nghĩa về Blocks, Planets và ContentLoader.
- `core/src/entropy/ui/`: Các màn hình (Screens) và tiện ích UI.
- `core/src/entropy/world/`: Định nghĩa các đối tượng trong thế giới game.

## 🛠️ Yêu cầu hệ thống

- **Java**: OpenJDK 17 hoặc tương đương (Hỗ trợ target Java 8).
- **Gradle**: Hỗ trợ tốt nhất trên Gradle 4.4.1 (theo cấu hình dự án hiện tại).

## 🏃 Cách chạy Game (Desktop)

Sử dụng Gradle để khởi động phiên bản Desktop:

```bash
./gradlew :desktop:run
```

*Lưu ý: Nếu bạn gặp lỗi tương thích Gradle với plugin Android trên môi trường hệ thống, bạn có thể tạm thời vô hiệu hóa project `:android` trong `settings.gradle` và `build.gradle` để chạy bản Desktop.*

## 📂 Cấu trúc thư mục chính

```text
Entropy/
├── core/               # Mã nguồn xử lý logic game chính
│   └── src/entropy/
│       ├── content/    # Quản lý Blocks, Planets
│       ├── ui/         # Giao diện Dashboards, Editor
│       └── world/      # Đối tượng thế giới (Block base, v.v.)
├── desktop/            # Cấu hình khởi chạy trên Desktop
├── android/            # Cấu hình khởi chạy trên Android
└── assets/             # Tài nguyên hình ảnh, âm thanh (nằm trong core/assets)
```

## 📝 Giấy phép

Dự án đang trong giai đoạn phát triển sơ khai. Toàn bộ nội dung thuộc quyền sở hữu của nhà phát triển.
