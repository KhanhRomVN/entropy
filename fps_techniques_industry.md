# 🎮 Kỹ thuật Tối ưu FPS — Industry Standards từ các Game lớn

> Tổng hợp từ GDC Talks, postmortems, engine docs của các game thực tế.  
> Sources: Minecraft, Terraria, Stardew Valley, Celeste, Noita, Factorio, RimWorld, Hollow Knight, Cities: Skylines, RTS games.

---

## PHẦN 1: SPATIAL PARTITIONING & CULLING

### 1.1 Frustum Culling (Unity, Unreal, mọi engine hiện đại)
Không render bất kỳ object nào nằm ngoài vùng nhìn của camera.
```
Godot: VisibleOnScreenNotifier2D / VisibleOnScreenEnabler2D
→ Tự động disable _process() khi object ra ngoài màn hình
```

### 1.2 Spatial Hashing / Quad-Tree (Noita, RimWorld, Factorio)
Thay vì duyệt toàn bộ object list O(N), dùng grid để tìm kiếm O(1) ~ O(log N).
```gdscript
# Thay vì: for obj in _all_objects (có thể 10,000 obj)
# Dùng:   _spatial_grid[cell] chỉ trả về ~20 obj gần nhất
var _spatial_grid: Dictionary = {}  # {Vector2i(grid_x, grid_y): Array[Node]}
const GRID_SIZE = 500  # pixel

func register(node: Node2D):
    var cell = Vector2i(node.position / GRID_SIZE)
    if not _spatial_grid.has(cell): _spatial_grid[cell] = []
    _spatial_grid[cell].append(node)

func query_nearby(pos: Vector2, radius: float) -> Array:
    var results = []
    var cells_radius = ceili(radius / GRID_SIZE)
    var center_cell = Vector2i(pos / GRID_SIZE)
    for dx in range(-cells_radius, cells_radius + 1):
        for dy in range(-cells_radius, cells_radius + 1):
            var cell = center_cell + Vector2i(dx, dy)
            if _spatial_grid.has(cell):
                results.append_array(_spatial_grid[cell])
    return results
```

### 1.3 Level of Detail — LOD (Minecraft, GTA, mọi 3D game lớn)
Object ở xa → dùng phiên bản đơn giản hơn.
```
Xa > 2000px:  Không render gì (hoặc chỉ 1 pixel màu)
Xa > 500px:   Dùng sprite thu nhỏ (không có shadow, collision)
Gần < 500px:  Render đầy đủ với shadow, collision
```

---

## PHẦN 2: UPDATE THROTTLING & TIME SLICING

### 2.1 Staggered Updates (RimWorld, Dwarf Fortress, Factorio)
Không update MỌI object MỌII frame. Chia nhỏ ra nhiều frame.
```gdscript
# Hệ thống: Update mỗi object 1 lần / N frames, KHÔNG đồng thời
var _update_index: int = 0

func _process(delta):
    var objects_to_update = _all_npcs.slice(_update_index, _update_index + 5)
    for npc in objects_to_update:
        npc.think()  # AI update chỉ 5 NPC/frame thay vì 500/frame
    _update_index = (_update_index + 5) % _all_npcs.size()
```

### 2.2 Fixed-Rate Logic (Minecraft TPS, Terraria)
Tách logic simulation (20 tick/s) khỏi rendering (60 FPS).
```
Minecraft: 20 TPS logic + 60 FPS rendering
Terraria:  60 Hz logic, nhưng nhiều subsystem chỉ update 10-30 Hz
```
```gdscript
# Godot: Dùng physics_process (default 60Hz) cho movement
# Nhưng dùng Timer hoặc throttle cho ai/world logic
var _ai_timer: float = 0.0
const AI_TICK_RATE = 0.1  # 10 lần/giây thay vì 60

func _process(delta):
    _ai_timer += delta
    if _ai_timer >= AI_TICK_RATE:
        _ai_timer = 0.0
        _update_all_ai()  # Chỉ chạy 10x/s
```

### 2.3 Time Slicing cho World Gen (Minecraft, Terraria, Starbound)
Chia việc tạo chunk ra nhiều frame thay vì làm xong 1 lần.
```
Minecraft: Mỗi frame chỉ generate vài column, không phải cả chunk
→ Kết quả: "Terraforming animation" khi chunk load
```

---

## PHẦN 3: OBJECT POOLING

### 3.1 Pool Pattern (mọi game commercial đều dùng)
Không tạo/xóa Node liên tục (cực kỳ tốn GC). Dùng lại Node đã có.
```gdscript
# Thay vì: node.queue_free() rồi var new_node = MyNode.new()
# Dùng pool:

class_name NodePool
var _pool: Array = []
var _scene: PackedScene

func _init(scene: PackedScene):
    _scene = scene
    # Pre-warm pool
    for i in 20:
        var n = scene.instantiate()
        n.visible = false
        _pool.append(n)

func get() -> Node:
    if _pool.is_empty():
        return _scene.instantiate()
    var n = _pool.pop_back()
    n.visible = true
    return n

func release(node: Node):
    node.visible = false
    node.position = Vector2(-99999, -99999)  # Out of screen
    _pool.push_back(node)
```

### 3.2 Bullet/Particle Pool (mọi action game)
```
Doom, Quake: Pool 256 bullets, recycle khi hit
Hollow Knight: Pool 50 particle systems, không tạo mới
```

---

## PHẦN 4: RENDERING OPTIMIZATION

### 4.1 Sprite Atlasing / Texture Atlas (mọi 2D game hiện đại)
Gom nhiều texture vào 1 PNG → giảm draw calls từ N → 1.
```
Unity Sprite Atlas, Godot TileSet: đều làm điều này
Stardew Valley: 1 large tileset PNG thay vì 1000 file riêng lẻ
→ Kết quả: 1000 draw calls → 1 draw call
```

### 4.2 Batching / GPU Instancing (Unity, Unreal, Godot MultiMeshInstance)
Render nhiều bản sao của cùng 1 mesh chỉ với 1 GPU draw call.
```gdscript
# Thay vì 1000 Sprite2D riêng biệt:
var mm = MultiMeshInstance2D.new()
mm.multimesh = MultiMesh.new()
mm.multimesh.transform_format = MultiMesh.TRANSFORM_2D
mm.multimesh.mesh = QuadMesh.new()
mm.multimesh.instance_count = 1000
# Set transform cho mỗi instance bằng set_instance_transform_2d()
# → 1 draw call thay vì 1000!
```

### 4.3 Occlusion Culling (Minecraft, GTA V)
Không render gì bị chặn bởi đối tượng khác (tường, nhà).
```
Minecraft: Không render block bị xung quanh hoàn toàn bởi block khác
→ Kết quả: 70% ít vertices phải render hơn
Tools trong Godot: OccluderPolygon2D (chỉ cho nguồn sáng)
```

### 4.4 Dirty Flag / Lazy Rendering (React, Godot Control nodes)
Chỉ re-render khi có thay đổi thực sự.
```gdscript
var _is_dirty: bool = false

func update_value(new_val):
    if new_val == _current_val: return  # Không cần re-render
    _current_val = new_val
    _is_dirty = true

func _process(delta):
    if _is_dirty:
        _redraw()
        _is_dirty = false
```

---

## PHẦN 5: DATA-ORIENTED DESIGN

### 5.1 Structure of Arrays thay vì Array of Structures (Factorio, modern engines)
```gdscript
# BAD: Array of Structs (cache-unfriendly)
var entities = []  # [{pos, vel, hp, sprite}, {pos, vel, hp, sprite}, ...]

# GOOD: Struct of Arrays (cache-friendly, 3-5x faster loop)
var positions: PackedVector2Array = []
var velocities: PackedVector2Array = []
var healths: PackedFloat32Array = []
# Loop position: tất cả positions nằm liên tiếp trong memory → CPU cache hit
```

### 5.2 ECS (Entity Component System) — Unity DOTS, Bevy, Flecs
Tách Data khỏi Behavior để tối ưu cache.
```
Unity DOTS: 10-100x nhanh hơn OOP cổ điển cho simulation nặng
Minecraft Java → Bedrock: Rewrite sang C++ + ECS để tăng performance
```

### 5.3 Flat Arrays over Dictionaries cho hot path (RimWorld optimization)
```gdscript
# BAD (hot loop): Dictionary lookup O(1) but has hashing overhead
var tile_data = {}
tile_data[Vector2i(x, y)] = sid  # Hash mỗi lần

# GOOD: Flat array, index tính bằng công thức
var tile_array: PackedInt32Array = PackedInt32Array()
tile_array.resize(CHUNK_SIZE * CHUNK_SIZE)
tile_array[y * CHUNK_SIZE + x] = sid  # Direct index, không hash
```

---

## PHẦN 6: MEMORY MANAGEMENT

### 6.1 Pre-allocation (Factorio, C++ games)
Cấp phát bộ nhớ 1 lần ngay từ đầu, không cấp phát trong runtime.
```gdscript
# BAD: Resize array trong loop (gây reallocation)
var result = []
for i in 10000:
    result.append(calculate(i))

# GOOD: Pre-allocate
var result = []
result.resize(10000)
for i in 10000:
    result[i] = calculate(i)
```

### 6.2 Object Lifetime Management (C++ games)
Biết rõ khi nào tạo, khi nào xóa. Tránh circular references.
```
GDScript: Dùng weakref() cho back-references để tránh memory leak
C# Godot: IDisposable pattern
```

### 6.3 Texture Streaming (GTA V, Minecraft)
Load texture khi cần, unload khi xa.
```
Godot: ResourceLoader.load_threaded_request() + cache manual
```

---

## PHẦN 7: CONCURRENCY & THREADING

### 7.1 Job System (Unreal 5, Unity Jobs, Godot WorkerThreadPool)
Chia công việc nặng thành nhiều job chạy song song trên nhiều CPU core.
```gdscript
# Noise generation song song cho 4 chunks cùng lúc:
for chunk in new_chunks:
    WorkerThreadPool.add_task(_generate_noise.bind(chunk))
# Main thread tiếp tục render trong khi noise tính ở background
```

### 7.2 Lock-Free Structures (high-performance engines)
Tránh Mutex bằng cách dùng atomic operations.
```
Factorio: Custom lock-free queue cho multi-threaded belt logic
Godot: Dùng call_deferred() thay vì Mutex khi có thể
```

### 7.3 Thread-Local Storage
Mỗi thread có "scratchpad" riêng để tránh lock.
```gdscript
# Thay vì: _shared_buffer (cần lock)
# Mỗi thread tạo local buffer riêng:
func _worker_thread():
    var local_buffer = []  # Không cần lock
    # ... xử lý ...
    # Chỉ lock khi commit kết quả cuối cùng
    _mutex.lock()
    _results.append(local_buffer)
    _mutex.unlock()
```

---

## PHẦN 8: AI & GAME LOGIC OPTIMIZATION

### 8.1 Hierarchical State Machines (Game AI Pro series)
Thay vì check mọi điều kiện mọi frame, dùng state machine để skip logic.
```
NPC đang ngủ → không check collision, pathfinding, line-of-sight
→ Chỉ check "Thức dậy?" mỗi 5 giây
```

### 8.2 Influence Maps (RTS games: Starcraft, Age of Empires)
Precompute map "ai nên đi đâu" một lần, nhiều unit dùng chung.
```
Thay vì: 200 unit mỗi unit pathfind riêng → 200 A* searches/frame
Dùng:    1 influence map update mỗi 0.5s, 200 unit đọc cùng map
```

### 8.3 Behavioral Trees với interruption (Unreal BehaviorTree)
Chỉ re-evaluate tree khi có sự kiện, không mọi frame.

---

## PHẦN 9: PHYSICS OPTIMIZATION

### 9.1 Sleeping Bodies (mọi Physics engine hiện đại)
Rigidbody không di chuyển → đưa vào trạng thái "ngủ", không tính physics.
```
Godot: RigidBody2D/3D tự động sleep khi velocity ~ 0
Bullet Physics, PhysX: Tương tự
```

### 9.2 Broad Phase / Narrow Phase Separation
- **Broad Phase**: AABB check nhanh → loại bỏ 95% cặp object không thể collision
- **Narrow Phase**: GJK/SAT check chính xác chỉ với ~5% còn lại
```
Godot dùng: BVH (Bounding Volume Hierarchy) tự động
Tự optimize: Tắt collision cho object không cần (cây tự nhiên, decoration)
```

### 9.3 Layer Masking (Godot, Unity, Unreal)
Dùng collision layers để quyết định ai check collision với ai.
```
Layer 1: Player
Layer 2: Terrain
Layer 4: Buildings
Layer 8: Projectiles (chỉ check với Player và Terrain)
→ Không bao giờ check projectile vs projectile
```

---

## PHẦN 10: PROFILING & MEASUREMENT (quan trọng nhất)

### 10.1 Godot Built-in Profiler
```bash
# Chạy với profiler:
godot4 --profiling scene.tscn

# Verbose mode (in ra toàn bộ Engine events):
godot4 --verbose scene.tscn 2>&1 | tee debug.log
```

### 10.2 Custom Frame Timing (kỹ thuật dùng trong AAA games)
```gdscript
# Đo chính xác từng subsystem:
var _frame_times: Dictionary = {}

func _begin(label: String):
    _frame_times[label] = Time.get_ticks_usec()

func _end(label: String) -> float:
    return (Time.get_ticks_usec() - _frame_times.get(label, 0)) / 1000.0

# Dùng:
_begin("ai_update")
_update_all_ai()
var ai_ms = _end("ai_update")

_begin("physics")
_do_physics()
var phys_ms = _end("physics")
```

### 10.3 Frame Graph / Flame Graph (Unity Profiler, Unreal Insights, RenderDoc)
Visualize mọi function call trong 1 frame dưới dạng biểu đồ.
```
→ Godot: Editor > Debugger > Profiler (chạy trong Editor)
→ Hoặc: Xuất dữ liệu rồi dùng tools như Perfetto, Tracy
```

### 10.4 GPU Profiling (RenderDoc, NVIDIA NSight, Intel GPA)
```bash
# Capture frame với RenderDoc:
renderdoccmd capture --working-dir . godot4 scene.tscn

# Hoặc: Wrap với apitrace
apitrace trace --api gl godot4 scene.tscn
```

---

## PHẦN 11: GAME-SPECIFIC TECHNIQUES

### 11.1 Minecraft-style Chunk System ✅ (Entropy đã có)
- Generate chunk background thread ✅
- Render distance giới hạn ✅
- Unload chunk xa ✅
- **Cần thêm**: Chỉ update chunk khi dirty

### 11.2 Terraria-style World Array (siêu nhanh)
Thay vì Node tree, dùng flat array 2D cho mọi tile:
```gdscript
# 8400 x 2400 tiles = ~20MB flat array
var world_tiles: PackedInt32Array
world_tiles.resize(WORLD_WIDTH * WORLD_HEIGHT)

func get_tile(x: int, y: int) -> int:
    return world_tiles[y * WORLD_WIDTH + x]  # O(1), direct memory access
```

### 11.3 Stardew Valley-style Zone Loading
Chỉ load zone hiện tại + zone kề. Unload zone xa.
```
Current zone: Full quality
Adjacent zones: Preload in background
Distant zones: Not loaded
```

### 11.4 Factorio Belt Optimization (data-oriented extreme)
Không dùng Node cho item trên belt, dùng array của struct thuần.
```cpp
// 60,000 items/belt không lag vì là POD struct array
struct Item { int type; float progress; };
Item belt_items[MAX_ITEMS];  // Flat array, không pointer
```

### 11.5 Noita World Simulation (Falling Sand)
256x256 tile chunk, mỗi frame chỉ update chunk đang "active":
```
Active chunk: có vật thể đang di chuyển
Inactive chunk: không update (frozen)
→ Simulation 1 triệu pixel không lag vì 95% là inactive
```

---

## BẢNG SO SÁNH IMPACT

| Kỹ thuật | Impact FPS | Khó thực hiện | Game áp dụng |
|----------|------------|---------------|--------------|
| Object Pooling | 🔴 Rất cao | Trung bình | Mọi game |
| Spatial Hashing | 🔴 Rất cao | Trung bình | Factorio, RimWorld |
| Staggered Updates | 🔴 Cao | Dễ | RimWorld, Dwarf Fortress |
| Frustum Culling | 🔴 Cao | Rất dễ (Godot built-in) | Mọi game |
| MultiMeshInstance | 🔴 Cao | Trung bình | Mọi 2D game có cây cối |
| Flat Array vs Dict | 🟠 Cao | Dễ | Terraria, Factorio |
| Thread-based Gen | 🟠 Cao | Khó | Minecraft, Starbound |
| LOD System | 🟠 Cao | Trung bình | GTA, Minecraft |
| Y-Sort chỉ khi cần | 🟠 Trung bình | Rất dễ | Mọi isometric game |
| Texture Atlas | 🟡 Trung bình | Dễ | Mọi 2D game |
| AI Hierarchical SM | 🟡 Trung bình | Trung bình | RTS, RPG games |
| Physics Sleep | 🟢 Nhỏ | Rất dễ (tự động) | Mọi game |
| Dirty Flag | 🟢 Nhỏ | Rất dễ | UI-heavy games |
| Pre-allocation | 🟢 Nhỏ | Dễ | C++ games |

---

## ƯU TIÊN CHO ENTROPY (Theo thứ tự ROI)

1. **MultiMeshInstance2D cho cây cối** → 1 draw call thay vì 1000 Sprite2D
2. **Spatial Hashing cho Fade/LOD check** → O(1) thay vì O(N) static objects
3. **Staggered AI Updates** → NPC chỉ think 10x/s thay vì 60x/s
4. **Flat Array cho tile data** → Cache-friendly tile lookup
5. **Dirty Chunk system** → Chỉ re-render chunk khi có thay đổi
