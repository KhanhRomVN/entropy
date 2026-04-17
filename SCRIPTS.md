# Project Scripts Map

Tài liệu này mô tả ngắn gọn chức năng của từng file script trong dự án, được tổ chức theo cấu trúc module mới.

## 📂 scripts/world/ (Khởi tạo & Quản lý thế giới)
- **`world_orchestrator.gd`**: Bộ não điều phối chính, quản lý vòng đời của các chunk và thực hiện vẽ TileMap.
- **`generation_worker.gd`**: Chuyên trách tính toán Noise ở background và quản lý bộ nhớ đệm dữ liệu địa hình.
- **`building_system.gd`**: Quản lý logic xây dựng, kiểm tra vùng đặt (footprint) và hiển thị bóng (ghost preview).
- **`world_shape_engine.gd`**: Engine toán học dùng SDF để định hình lục địa và phân chia ranh giới biome. Hỗ trợ tối ưu hóa AABB để tăng tốc độ truy vấn địa hình.
- **`world_blueprint.gd`**: Chứa các "bản thiết kế" tĩnh (Pangaea, Laurasia...) và bố cục biome.
- **`chunk.gd`**: Script gắn vào từng node Chunk để quản lý các lớp TileMapLayer riêng biệt.

## 📂 scripts/ui/ (Giao diện người dùng)
- **`debug_ui_manager.gd`**: Quản lý HUD thông số (F3), Menu Pause (ESC) và các bảng điều khiển debug.
- **`world_map.gd`**: Logic hiển thị bản đồ lớn (M), hỗ trợ render đa luồng với cơ chế Downsampling để đạt hiệu suất tối đa.
- **`hud.gd`**: Giao diện hiển thị trạng thái người chơi (máu, hotbar, đồng hồ).
- **`settings_menu.gd`**: Quản lý các tùy chỉnh đồ họa và âm thanh.
- **`footprint_preview.gd`**: Hỗ trợ hiển thị vùng đặt công trình (thanh preview mờ).

## 📂 scripts/core/ (Hệ thống cốt lõi)
- **`camera_controller.gd`**: Điều khiển Camera 2D, hỗ trợ mượt mà việc di chuyển và thu phóng.
- **`day_night_cycle.gd`**: Quản lý thời gian thực và tự động điều chỉnh ánh sáng môi trường.
- **`multi_mesh_tree_renderer.gd`**: Tối ưu hóa render cây cối bằng MultiMesh2D, cho phép hiển thị hàng nghìn cây.
- **`shadow_proxy_generator.gd`**: Sinh ra các vùng đổ bóng tối ưu cho vật thể tĩnh.

## 📂 scripts/entities/ (Thực thể)
- **`player.gd`**: Xử lý input, di chuyển và các tương tác vật lý của nhân vật chính.

## 📂 scripts/global/ (Toàn cục)
- **`config.gd`**: Singleton (Auto-load) lưu trữ và đồng bộ hóa cài đặt người dùng trên toàn bộ game.
