# 🚀 ENTROPY - TOÀN BỘ GIẢI PHÁP TỐI ƯU HÓA FPS

> Dựa trên phân tích code thực tế + dữ liệu Profiler ngày 11/04/2026  
> **Log thực tế**: `Tiles: 56ms, Physics: 54.9ms, Objects: 19.3ms` (lần đầu) → sau đó 7-8 FPS với chỉ ~2ms script time (nguyên nhân ẩn ở Engine).

---

## 🔴 NHÓM 1: CRITICAL — Nguyên nhân chính gây 7 FPS (Ưu tiên làm NGAY)

### 1.1 [Tile] `layer.set_cell()` gây nghẽn Engine Render
**Vấn đề**: Trong `_process_generation_queue()`, mỗi lần gọi `set_cell()` trên TileMapLayer đều có thể trigger Engine cập nhật nội bộ (bake quad, collision, shader). Điều này giải thích tại sao script chỉ chiếm 2ms nhưng FPS vẫn rớt thảm (Engine overhead sau khi hàm trả về).

**Giải pháp A — Batch Update bằng `set_cells_terrain_path()`** (Mạnh nhất):
```gdscript
# THAY VÌ: gọi set_cell() từng ô một trong vòng lặp
layer.set_cell(gpos, sid, Vector2i(0, 0))

# DÙNG: Thu thập tất cả cells của một chunk, rồi set_cells một lần khi chunk hoàn thành
# Khai báo biến tích lũy ngoài vòng lặp:
var _pending_cells: Dictionary = {} # {Vector2i: [source_id, atlas_coords]}

# Trong vòng lặp tile:
_pending_cells[gpos] = [sid, Vector2i(0, 0)]

# Sau khi hoàn tất 1 chunk (thay set_cell từng ô):
for pos in _pending_cells.keys():
    layer.set_cell(pos, _pending_cells[pos][0], _pending_cells[pos][1])
_pending_cells.clear()
```

**Giải pháp B — Giảm CHUNK_SIZE xuống 8** (Dễ làm nhất):
```gdscript
const CHUNK_SIZE = 8  # Thay vì 16
# Ưu điểm: Mỗi chunk chỉ có 64 tiles thay vì 256, chia nhỏ công việc Set_Cell
# Nhược điểm: Nhiều node hơn, cần tăng RENDER_DISTANCE tương ứng
```

---

### 1.2 [Physics] StaticBody2D + CollisionShape2D cho MỌI cây cối (Cực nặng)
**Vấn đề**: Trong `_add_rotation_test_object()` (dòng 1096-1112), TẤT CẢ các loại prop (cây, đá, quặng) đều tạo một `StaticBody2D` + `ConvexPolygonShape2D`. Physics Server phải đăng ký hàng trăm collision shape cùng lúc khi chunk mới xuất hiện → **`Physics: 54.9ms`** trong log.

**Giải pháp — Loại bỏ collision cho cây cối tự nhiên**:
```gdscript
# Hiện tại: chỉ loại trừ oak, pine, maple, bamboo, cactus, camfire
var walkthrough_types = ["oak", "pine", "maple", "bamboo", "cactus", "camfire"]

# MỞ RỘNG: Loại bỏ collision cho MỌI prop tự nhiên (chỉ giữ cho công trình)
var has_collision_types = ["windmill", "core"]  # Chỉ công trình mới cần va chạm
if type in has_collision_types:
    # tạo StaticBody2D như cũ
```
**Kết quả dự kiến**: Giảm Physics overhead 80-90% → từ 54ms xuống còn ~5ms.

---

### 1.3 [Node] `add_child.call_deferred()` tạo nhiều Node quá trong 1 frame
**Vấn đề**: Dù dùng `call_deferred()`, tất cả các `add_child` bị gom lại và chạy cùng nhau ở cuối frame, tạo ra hàng chục Node (Pivot, Sprite2D, StaticBody2D, Area2D, Line2D, LightOccluder2D, VisibleOnScreenNotifier2D) cho mỗi prop.

**Giải pháp — Giới hạn số Node tạo mỗi frame**:
```gdscript
# Thêm biến:
var _pending_props: Array = []  # Hàng đợi prop chờ tạo
var _prop_budget_per_frame: int = 3  # Tối đa 3 prop/frame

# Trong _process_generation_queue: thay vì gọi thẳng _add_rotation_test_object()
# chỉ thêm vào hàng đợi:
_pending_props.append({"parent": chunk_node, "center": center, "type": tree_type})

# Trong _process(): giải phóng hàng đợi từ từ
for i in range(min(_prop_budget_per_frame, _pending_props.size())):
    var p = _pending_props.pop_front()
    _add_rotation_test_object(p.parent, p.center, Vector2i(1,1), p.type)
```

---

### 1.4 [Signal] `stat_changed.emit()` phát ra 5 signal MỖI FRAME từ Player
**Vấn đề**: `player.gd` phát 5 signal `stat_changed` mỗi frame trong `_physics_process()` kể cả khi giá trị không thay đổi. Với 60 FPS = 300 signal/giây → HUD phải xử lý liên tục.

**Giải pháp — Chỉ phát khi thay đổi**:
```gdscript
# Khai báo biến cache:
var _last_stats: Dictionary = {}

func _emit_if_changed(stat_name: String, current: float, max_val: float):
    var key = "%s_%.1f" % [stat_name, current]
    if _last_stats.get(stat_name) != key:
        _last_stats[stat_name] = key
        stat_changed.emit(stat_name, current, max_val)
```

---

## 🟠 NHÓM 2: HIGH — Tối ưu kiến trúc (Ảnh hưởng lớn)

### 2.1 [Area2D] OcclusionSensor cho MỌI cây → Cực nhiều Collision Area
**Vấn đề**: Tại dòng 1114-1134, mỗi prop tạo một `Area2D` với `CircleShape2D` để fade khi player đến gần. Hàng trăm Area2D = hàng trăm collision check mỗi frame trong Physics Server.

**Giải pháp — Dùng Distance Check thay Area2D**:
```gdscript
# Thay vì Area2D, dùng VisibleOnScreenNotifier2D (đã có sẵn) + kiểm tra khoảng cách định kỳ
# Trong _process() với throttle 0.5s:
_fade_check_timer += delta
if _fade_check_timer >= 0.5:
    _fade_check_timer = 0.0
    var player = get_tree().get_first_node_in_group("player")
    if player:
        for pivot in _static_objects.keys():
            if is_instance_valid(pivot):
                var dist = pivot.global_position.distance_squared_to(player.global_position)
                var building_ref = pivot.get_meta("building_ref", null)
                if building_ref:
                    _fade_building(building_ref, 0.3 if dist < 300000 else 1.0)
```

---

### 2.2 [LightOccluder2D] Tạo cho MỌI prop → GPU Heavy
**Vấn đề**: Tại dòng 1136-1145, mỗi prop (cây, đá, quặng) đều có `LightOccluder2D`. Với hàng trăm cây trên màn hình, GPU phải tính hàng trăm bóng khuất sáng.

**Giải pháp — Chỉ tạo cho công trình lớn**:
```gdscript
# Chỉ bật Occluder cho công trình, không cho cây tự nhiên
var large_structures = ["windmill", "core", "camfire"]
if type in large_structures:
    var occluder = LightOccluder2D.new()
    # ... code occluder như cũ
```

---

### 2.3 [Noise] 8 FastNoiseLite objects × 7 Octave FRACTAL_FBM (Cực nặng CPU)
**Vấn đề**: Chúng ta có 8 noise objects. Noise chính dùng `fractal_octaves = 7` với `FRACTAL_FBM` — đây là cấu hình nặng nhất có thể cho FastNoiseLite (7 lần sample). Mỗi tile sample 8 noise objects.

**Giải pháp — Giảm Octaves**:
```gdscript
# Noise chính: từ 7 → 5 octave (vẫn rất chi tiết nhưng nhanh hơn 28%)
_noise.fractal_octaves = 5

# Noise phụ (temp, moisture, biome, scatter, mist): chỉ cần 1-2 octave
_temp_noise.fractal_octaves = 1
_moisture_noise.fractal_octaves = 1
_scatter_noise.fractal_octaves = 1
```

**Giải pháp thay thế — Pre-bake noise vào Texture**:
Thay vì tính noise real-time, dùng FastNoiseLite để generate Image/Texture một lần rồi đọc pixel (nhanh hơn 10-50x).

---

### 2.4 [TileMap] Y_Sort_Enabled trên cả Generator, Chunks, và TileMapLayer (Triple overhead)
**Vấn đề**: `self.y_sort_enabled = true` (dòng 237) trên Node gốc, cộng với `chunk_node.y_sort_enabled = true` (dòng 788), cộng với `terrain.y_sort_enabled = true` trong chunk.gd. Ba lớp Y-sorting lồng nhau nhân overhead GPU lên đáng kể.

**Giải pháp**:
```gdscript
# Chỉ bật Y-sort ở lớp prop (nơi cây cối cần sort), không cần ở terrain và node gốc
terrain.y_sort_enabled = false  # Terrain tiles không cần sort
# Chỉ prop_layer.y_sort_enabled = true là đủ
```

---

### 2.5 [Camera] `get_first_node_in_group("player")` gọi MỖI FRAME trong Camera
**Vấn đề**: `camera_controller.gd` dòng 19 gọi `get_tree().get_first_node_in_group("player")` TRONG `_process()` mỗi frame. Đây là thao tác duyệt cây Node tốn kém.

**Giải pháp — Cache reference**:
```gdscript
var _player: CharacterBody2D

func _ready():
    _player = get_tree().get_first_node_in_group("player")

func _process(delta):
    if _player and is_instance_valid(_player):
        global_position = global_position.lerp(_player.global_position, 10.0 * delta)
```

---

## 🟡 NHÓM 3: MEDIUM — Cải thiện đáng kể

### 3.1 [UI] Debug Labels cập nhật MỌI frame khi FPS thấp
**Vấn đề**: Khi FPS thấp và `frame_time > 25ms`, code tại dòng 646-656 gọi `print()` nhiều chuỗi lớn + reset counters → tốn thêm time trong frame đã bị nghẽn.

**Giải pháp**: Chuyển log ra luồng phụ hoặc dùng `call_deferred("print", ...)`.

---

### 3.2 [Tween] `create_tween()` tạo Tween object mỗi lần fade
**Vấn đề**: Dòng 1214 tạo mới Tween object mỗi khi player vào gần một cây. Hàng chục tween objects tồn tại song song khi di chuyển qua rừng.

**Giải pháp**:
```gdscript
# Dùng 1 Tween duy nhất per-node bằng cách lưu vào meta:
func _fade_building(node: CanvasItem, target_alpha: float):
    var old_tween = node.get_meta("fade_tween", null)
    if old_tween and old_tween.is_valid(): old_tween.kill()
    var tween = create_tween()
    node.set_meta("fade_tween", tween)
    tween.tween_property(node, "modulate:a", target_alpha, 0.3).set_trans(Tween.TRANS_SINE)
```

---

### 3.3 [Array] `var fluid_ids = [3, 13, 14, 15, 16, 21]` tạo MỖI TILE
**Vấn đề**: Dòng 956 tạo một Array mới cho mỗi trong số 256 tile của mỗi chunk.

**Giải pháp — Khai báo là constant**:
```gdscript
# Khai báo ở đầu file (ngoài hàm)
const FLUID_TILE_IDS: Array = [3, 13, 14, 15, 16, 21]
const SOLID_TILE_IDS: Array = [4, 7]  # Stone, Bazan

# Trong vòng lặp:
if sid in FLUID_TILE_IDS:
    prop_id = -1
```

---

### 3.4 [Dictionary] Nhiều phép `_noise_cache.has()` + `_generation_set.has()` trong hot loop
**Vấn đề**: Các thao tác Dictionary lookup lồng nhau trong `update_chunks()` và `_process_generation_queue()`.

**Giải pháp**: Đã ổn với Dictionary, nhưng cần đảm bảo xóa cache noise kịp thời để không phình RAM.

---

### 3.5 [Spawn] `_building_roots.has(gpos)` kiểm tra MỖI TILE (dòng 992)
**Vấn đề**: Dù `_building_roots` thường rỗng hoặc rất ít entry, việc kiểm tra vẫn xảy ra cho mọi tile vì nằm trong hot loop. Tuy nhiên do Dictionary O(1), ảnh hưởng nhỏ.

---

### 3.6 [String] String matching `type == "oak"` trong hot path
**Vấn đề**: Ở dòng 966-976, match statement dùng String literals. String comparison chậm hơn int comparison.

**Giải pháp — Dùng enum hoặc int constants**:
```gdscript
enum PropType { OAK = 18, MAPLE = 17, BAMBOO = 19, CACTUS = 20, COFFEE = 23 }
enum TreeType { NONE = 0, OAK, MAPLE, BAMBOO, CACTUS, COFFEE }
```

---

## 🟢 NHÓM 4: LOW — Polish & Engine Config

### 4.1 [Godot Config] V-Sync + Physics Tick Rate
```
Project Settings > Display > Window > Android:
- Vsync Mode = Disabled (hoặc Adaptive) để không bị forced 60fps ceiling
Project Settings > Physics > Common:
- Physics Ticks Per Second = 30 (từ 60) — Player không cần physics 60Hz
```

---

### 4.2 [Render] Tắt Shadows cho HẦU HẾT các LightOccluder2D
**Vấn đề**: `light.shadow_enabled = true` tại dòng 1092 cho campfire. Shadow rendering rất tốn GPU.

**Giải pháp**: Tắt hoặc giảm shadow resolution.

---

### 4.3 [Thread] Noise generation thread không có giới hạn số task đồng thời
**Vấn đề**: `WorkerThreadPool.add_task()` tại dòng 1293 không kiểm tra số lượng task đang chờ. Khi zoom out (tạo nhiều chunk cùng lúc), có thể tạo hàng chục thread tasks cùng lúc.

**Giải pháp — Giới hạn concurrent tasks**:
```gdscript
const MAX_CONCURRENT_NOISE_TASKS = 4

func _trigger_background_noise(cpos: Vector2i):
    _noise_mutex.lock()
    var too_many = _pending_noise_chunks.size() >= MAX_CONCURRENT_NOISE_TASKS
    _noise_mutex.unlock()
    if too_many: return
    # ... rest of function
```

---

### 4.4 [GDScript] `is_instance_valid()` overhead trong hot loops
**Vấn đề**: Các vòng lặp cleanup tại dòng 583-587 gọi `is_instance_valid()` cho mọi entry trong `_static_objects` và `_lighting_objects`.

**Giải pháp**: Sử dụng built-in `weakref()` để tự động handle invalid references, hoặc giữ nguyên nhưng giảm tần suất cleanup xuống 30s.

---

### 4.5 [Memory] `_noise_cache` có thể phình to khi di chuyển nhiều
**Vấn đề**: Cache noise không bị xóa cho đến khi chunk bị remove. Nếu người chơi đi xa rồi quay lại, sẽ tạo cache entries mới trong khi entries cũ vẫn còn.

**Giải pháp**: Đã có logic xóa trong `_process_removal_queue()` — tốt. Chỉ cần đảm bảo `_removal_queue` không bị block.

---

### 4.6 [World Map] Thread render bản đồ tạo `Image.create()` lớn mỗi lần
**Vấn đề**: `world_map.gd` tạo `Image.create(640, 360)` mỗi lần render. Cấp phát 230,400 pixel mỗi lần zoom/pan.

**Giải pháp — Reuse Image object**:
```gdscript
var _map_image: Image  # Khai báo 1 lần

func _render_worker(center: Vector2, zoom: float):
    if not _map_image:
        _map_image = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
    # Thay vì Image.create(), dùng _map_image trực tiếp
```

---

### 4.7 [TileSet] Phân mảnh TileSet thành nhiều TileSet nhỏ
**Vấn đề**: Nếu `main_tileset.tres` chứa tất cả tile (terrain + props + structures), GPU phải upload texture atlas lớn.

**Giải pháp**: Tách thành `terrain_tileset.tres` (terrain) và `props_tileset.tres` (props) để giảm texture size mỗi draw call.

---

## 📋 BẢNG TÓM TẮT THEO IMPACT & KHÓ KHĂN

| # | Giải pháp | Impact | Khó thực hiện | Ưu tiên |
|---|-----------|--------|---------------|---------|
| 1.1 | Loại bỏ Physics cho cây tự nhiên | 🔴 Rất cao | Dễ | **NGAY** |
| 1.2 | Loại bỏ Area2D per-prop, dùng distance check | 🔴 Rất cao | Trung bình | **NGAY** |
| 1.3 | Hàng đợi prop tạo dần (Prop Queue) | 🔴 Cao | Trung bình | **NGAY** |
| 2.1 | Cache `_player` reference trong Camera | 🟠 Cao | Rất dễ | Sớm |
| 2.2 | Tắt Y-sort cho terrain layer | 🟠 Cao | Rất dễ | Sớm |
| 2.3 | Loại bỏ LightOccluder2D cho cây tự nhiên | 🟠 Cao | Dễ | Sớm |
| 2.4 | Chỉ phát signal stat khi giá trị thay đổi | 🟠 Trung bình | Dễ | Sớm |
| 3.1 | Giảm fractal_octaves noise phụ xuống 1-2 | 🟡 Trung bình | Rất dễ | Bình thường |
| 3.2 | `const FLUID_TILE_IDS` thay vì tạo Array per-tile | 🟡 Nhỏ | Rất dễ | Bình thường |
| 3.3 | Reuse Image trong WorldMap Thread | 🟡 Nhỏ | Dễ | Bình thường |
| 4.1 | Physics Ticks = 30 trong Project Settings | 🟢 Trung bình | Rất dễ | Optional |
| 4.2 | MAX_CONCURRENT_NOISE_TASKS giới hạn thread | 🟢 Nhỏ | Dễ | Optional |
| 4.3 | Tắt shadow trong LightConfig | 🟢 Nhỏ | Rất dễ | Optional |

---

## 💡 PHÂN TÍCH NGUYÊN NHÂN 7 FPS "BÍ ẨN"

Log cho thấy: **Script chiếm 2ms nhưng FPS vẫn 7** = **Engine overhead 120ms** nằm ngoài tầm kiểm soát của GDScript.

Nguyên nhân phổ biến nhất:
1. **Physics Server flush**: Khi `add_child()` hoặc `call_deferred()` thêm StaticBody2D/Area2D, Physics Server phải rebuild broadphase → xảy ra ở đầu frame tiếp theo, **không được đo bởi profiler script**.
2. **Rendering Server**: Khi nhiều TileMapLayer mới được thêm vào, Godot Rendering Server phải upload vertex buffers lên GPU.
3. **Y-Sort Cost**: Ba lớp Y-sort lồng nhau trên hàng trăm tile → rendering pass tốn kém.

**Giải pháp tổng thể**: Ưu tiên **nhóm 1** (loại bỏ StaticBody2D + Area2D cho cây tự nhiên) vì đây là nguyên nhân chính khiến Physics Server bị quá tải ngay cả khi script đã chạy xong.
