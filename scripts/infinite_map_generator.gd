extends Node2D

const CHUNK_SIZE = 16
var RENDER_DISTANCE = 3 

@export var tileset: TileSet
@export var force_block_id: int = -1 # Nếu >= 0, ép tất cả các khối dùng ID này
@export var spawn_building_type: String = "" # Tòa nhà xuất hiện tại (0,0)
@export var map_size: int = 2000 # Kích thước map tối đa (tiles)
@export var continent_radius: float = 0.55 # Thu nhỏ bán kính gốc để nhường chỗ cho warp lấn ra bãi biển # Tỉ lệ lục địa chiếm trong map_size
var chunks: Dictionary = {} 
var camera: Camera2D

var _grass_heatmap: Dictionary = {} 
var _building_roots: Dictionary = {} 
var _windmill_texture: Texture2D 
var _apple_tree_texture: Texture2D 
var _temp_layer: TileMapLayer 
var _fps_label: Label # Label hiển thị FPS độ chính xác cao
var _fps_timer: float = 0.0
var _ui_update_timer: float = 0.0 # Bộ đếm thời gian cập nhật UI nhãn
var _show_2d_checkbox: CheckBox
var _ui_prof_noise: Label
var _ui_prof_tiles: Label
var _ui_prof_objects: Label
var _ui_prof_physics: Label

var _occupied_tiles: Dictionary = {} # Trình quản lý các ô đã có nhà (Vector2i -> bool)
var _noise: FastNoiseLite
var _forest_noise: FastNoiseLite
var _river_noise: FastNoiseLite
var _river_mask_noise: FastNoiseLite # Lớp mặt nạ để sông thưa thớt hơn
var _temp_noise: FastNoiseLite    # Noise cho Nhiệt độ (Lạnh -> Nóng)
var _moisture_noise: FastNoiseLite # Noise cho Độ ẩm (Khô -> Ướt)
var _biome_noise: FastNoiseLite    # Noise đặc thù để phân chia 14 vùng Biome
var _mist_noise: FastNoiseLite     # Noise cho sương mù ở Misty Grassland
var _scatter_noise: FastNoiseLite    # Noise tần số cao để phân tán vật thể (Quặng)
var _warp_noise: FastNoiseLite       # Noise chuyên dụng làm biến dạng lục địa (V6)
var _giant_warp_noise: FastNoiseLite # Noise tần số siêu thấp để thay đổi hình dạng vĩ mô (V7)
var _archipelago_filter_noise: FastNoiseLite # Noise để lọc cụm đảo tập trung (V7)
var _fault_noise: FastNoiseLite              # Noise mô phỏng đứt gãy địa chất → tạo vịnh + đảo
var _noise_cache: Dictionary = {} # Cache noise values theo chunk position
var _pending_teleport_tile: Vector2 = Vector2(-99999, -99999) # Chẩn đoán sau khi đáp xuống
var _expected_biome_after_teleport: String = "" # Để so khớp với Map

var _ui_layer: CanvasLayer

# --- UI COMPONENTS ---
var _pause_menu_layer: CanvasLayer
var _pause_panel: PanelContainer
var _blur_rect: ColorRect
var _settings_menu: CanvasLayer

# CÁC THANH TRƯỢT 2D (ẢNH TÒA NHÀ)
var _2d_x_slider: HSlider
var _2d_y_slider: HSlider
var _2d_scale_slider: HSlider
var _lbl_2d_x: Label
var _lbl_2d_y: Label
var _lbl_2d_scale: Label

var _windmill_tex = preload("res://assets/structures/windmill/windmill_SouthWest.png")
var _camfire_tex = preload("res://assets/structures/camfire/camfire.png")
var _core_tex = preload("res://assets/structures/core/core.png")
var _oak_tree_tex = preload("res://assets/props/plants/trees/oak_tree/oak_tree.png")
var _maple_tree_tex = preload("res://assets/props/plants/trees/maple_tree/maple_tree.png")
var _coffee_tree_tex = preload("res://assets/props/plants/trees/coffee_tree/coffee_tree.png")
var _cotton_tree_tex = preload("res://assets/props/plants/trees/cotton_tree/cotton_tree.png")
var _bamboo_tex = preload("res://assets/props/plants/trees/bambo/bambo_1.png")
var _cactus_tex = preload("res://assets/props/plants/trees/cactus/cactus_1.png")
var _winter_pine_tex = preload("res://assets/props/plants/trees/winter_pine_tree/winter_pine_tree.png")

# TÀI NGUYÊN KHOÁNG SẢN (ORES)
var _stone_ore_tex = preload("res://assets/props/minerals/stone_ore/stone_ore_1.png")
var _tin_ore_tex = preload("res://assets/props/minerals/tin_ore/tin_ore_1.png")
var _gold_ore_tex = preload("res://assets/props/minerals/gold_ore/gold_ore_1.png")
var _copper_ore_tex = preload("res://assets/props/minerals/copper_ore/copper_ore_1.png")
var _silver_ore_tex = preload("res://assets/props/minerals/sliver_ore/sliver_ore_1.png")



# ĐƯỜNG DẪN TÀI NGUYÊN (CHỈ GIỮ LẠI REAL ASSETS + 3D PROXY)
var windmill_real_path = "res://assets/structures/windmill/windmill_SouthWest.png"
var windmill_info_path = "res://assets/structures/windmill/info.json"
var apple_tree_real_path = "res://assets/props/plants/trees/oak_tree/oak_tree.png"
var apple_tree_info_path = "res://assets/props/plants/trees/oak_tree/info.json"
var core_info_path = "res://assets/structures/core/info.json"
var _chunk_script = preload("res://scripts/chunk.gd") 
var _windmill_offset: Vector2 = Vector2(-500, -4865) 
var _core_offset: Vector2 = Vector2.ZERO

# CẤU HÌNH CÂY CỐI (HỖ TRỢ LÀM MỜ)
var _tree_defs = {
	"oak": {"tex": _oak_tree_tex, "scale": 1.0, "offset": Vector2(0, -400)},
	"maple": {"tex": _maple_tree_tex, "scale": 1.1, "offset": Vector2(0, -420)},
	"coffee": {"tex": _coffee_tree_tex, "scale": 0.9, "offset": Vector2(0, -200)},
	"cotton": {"tex": _cotton_tree_tex, "scale": 0.8, "offset": Vector2(0, -150)},
	"bamboo": {"tex": _bamboo_tex, "scale": 0.8, "offset": Vector2(0, -200)},
	"cactus": {"tex": _cactus_tex, "scale": 0.8, "offset": Vector2(0, -200)},
	"winter_pine": {"tex": _winter_pine_tex, "scale": 1.2, "offset": Vector2(0, -420)},
	"stone_ore": {"tex": _stone_ore_tex, "scale": 0.6, "offset": Vector2(0, -50)},
	"tin_ore": {"tex": _tin_ore_tex, "scale": 0.6, "offset": Vector2(0, -50)},
	"gold_ore": {"tex": _gold_ore_tex, "scale": 0.6, "offset": Vector2(0, -50)},
	"copper_ore": {"tex": _copper_ore_tex, "scale": 0.5, "offset": Vector2(0, -50)},
	"silver_ore": {"tex": _silver_ore_tex, "scale": 0.6, "offset": Vector2(0, -50)}
}

# HỆ THỐNG XÂY DỰNG MỚI
var _selected_building: String = ""
var _ghost_sprite: Sprite2D
var _ghost_shadow: Sprite2D
var _preview_outline: Line2D

# GIAO DIỆN TOOLBAR
var _style_normal: StyleBox
var _style_active: StyleBox

# BIẾN THEO DÕI HIỆU NĂNG (OPTIMIZATION)
var _last_cam_update_pos: Vector2 = Vector2(-9999, -9999) # Đảm bảo update_chunks() chạy lần đầu
var _is_window_focused: bool = true 
var _last_mouse_tile_pos: Vector2i = Vector2i(-999, -999)
var _ghost_update_timer: float = 0.0 # Throttle ghost update
var _static_objects: Dictionary = {} # Chuyển từ Array sang Dictionary (O(1) access)
var _lighting_objects: Dictionary = {} # Chuyển từ Array sang Dictionary (O(1) access)
var _active_lighting_objects: Dictionary = {} # Chỉ chứa các đống lửa đang hiện trên màn hình
var _chunk_objects: Dictionary = {} # Lưu danh sách vật thể theo chunk (Vector2i -> Array[Node2D])
var _cleanup_timer: float = 0.0 # Bộ đếm thời gian dọn dẹp vật thể (10s/lần)
var _chunk_update_timer: float = 0.0 # Throttling cho update_chunks (0.15s/lần)
const CHUNK_UPDATE_INTERVAL = 0.15

# CONSTANTS TỐI ƯU (Không tạo Array mỗi tile)
const FLUID_TILE_IDS: Array = [3, 13, 14, 15, 16, 21, 26]
const SOLID_TILE_IDS: Array = [4, 7, 27] # Stone, Bazan, Black Bazan
const PROP_STRUCTURES: Array = ["windmill", "core"] # CHỈ công trình mới cần Physics
const MAX_CONCURRENT_NOISE_TASKS: int = 4 # Giới hạn thread tasks đồng thời

# HÀNG ĐỢI PROP (Tạo cây/đá từng tí, không tạo hàng loạt 1 frame)
var _pending_props: Array = []
const PROP_BUDGET_PER_FRAME: int = 2 # Tối đa 2 prop/frame để giữ FPS

# FADE CHECK (Thay thế Area2D per-prop)
var _fade_check_timer: float = 0.0
const FADE_CHECK_INTERVAL: float = 0.5 # Check mỗi 0.5s thay vì dùng Area2D
var _cached_player: CharacterBody2D = null

# COMPONENT C: Spatial Hash — fade check O(1) thay vì O(N)
const SPATIAL_CELL: float = 1000.0  # Ô lưới 1000px (~2 tile)
var _spatial_hash: Dictionary = {}  # {Vector2i(cell) -> Array[Node2D (pivots)]}

# COMPONENT B: MultiMeshTreeRenderer
const _MULTIMESH_SCRIPT = preload("res://scripts/multi_mesh_tree_renderer.gd")
var _tree_renderer: Node2D = null
# Các loại cây dùng MultiMesh (thiên nhiên, rất nhiều) — công trình vẫn dùng Sprite2D
const MULTIMESH_TREE_TYPES: Array = ["oak", "maple", "bamboo", "cactus", "coffee", "cotton", "winter_pine"]

# ZERO-LAG WORLD GEN (Stage 2: Perfect Smoothness)
var _generation_queue: Array[Vector2i] = [] 
var _generation_set: Dictionary = {} # Dùng để tra cứu O(1) tránh đứng hình khi tìm trong mảng
var _removal_queue: Array[Vector2i] = [] # Hàng đợi xóa các vùng đất cũ
var _removal_set: Dictionary = {} # Dictionary để tra cứu O(1) cho hàng đợi xóa

var _noise_mutex: Mutex = Mutex.new() # Bảo vệ cache khi dùng đa luồng
var _pending_noise_chunks: Dictionary = {} # Theo dõi các chunk đang tính toán trong nền

var _current_gen_chunk: Vector2i = Vector2i(-999, -999) 
var _current_tile_idx: int = 0 
var _genesis_timer: float = 3.0 # Giảm xuống 3s tải siêu tốc
var _max_tiles_per_frame: int = 24 # Giảm xuống 24 tiles để mượt hơn
var _gen_budget_usec: int = 1500 # Siết chặt budget xuống 1.5ms
const BASE_MAX_TILES = 24
const BASE_GEN_BUDGET = 1500

# CACHING UI NODES (Tối ưu performance)
var _ui_fps: Label
var _ui_zoom: Label
var _ui_statics: Label
var _ui_lighting: Label
var _ui_flicker_time: Label
var _ui_chunk_time: Label
var _ui_queue_lbl: Label
var _world_map_instance: CanvasLayer
var _world_map_scene = preload("res://scenes/ui/world_map.tscn")
# --- PROFILING VARIABLES ---
var _t_noise: int = 0
var _t_tiles: int = 0
var _t_objects: int = 0
var _t_physics_reg: int = 0
var _t_process_other: int = 0 # Thêm tracking cho các phần update_chunks, removal, fade

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_is_window_focused = false
		# TỐI ƯU: Nếu đang mở Bản đồ, không hiện Menu Pause để tránh chồng chéo khi dùng chuột phải
		if _world_map_instance and !_world_map_instance.visible:
			_toggle_pause_menu(true) # Tự động hiện menu và pause
			print("[SYSTEM] Auto-Pause: Window lost focus.")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_is_window_focused = true
		# Không tự động unpause ở đây để người dùng nhấn nút Tiếp tục hoặc tự tắt menu
		print("[SYSTEM] Window focused: Game remains paused if menu is up.")

func _ready():
	randomize() # Đảm bảo Seed thực sự ngẫu nhiên mỗi lần chạy
	process_mode = Node.PROCESS_MODE_ALWAYS # Đảm bảo script này vẫn chạy khi game bị pause
	_spatial_hash.clear() # Đảm bảo sạch rác khi khởi động
	print("InfiniteMapGenerator: Initializing Pure 3D World...")
	
	# 0. KHỞI TẠO NOISE CẤU TRÚC THỀ GIỚI (QUY MÔ SIÊU LỤC ĐỊA)
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	print("InfiniteMapGenerator: World Genesis with seed: ", _noise.seed)
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 0.00015 # Tăng nhẹ tần số để đất liền gồ ghề hơn
	_noise.fractal_octaves = 5 
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.5
	
	# Noise cho Nhiệt độ (Climate Zones) - TĂNG TẦN SỐ ĐỂ ĐA DẠNG BIOME
	_temp_noise = FastNoiseLite.new()
	_temp_noise.seed = _noise.seed + 101
	_temp_noise.frequency = 0.0025 # Tăng để tạo đủ vùng nóng/lạnh xen kẽ
	_temp_noise.fractal_octaves = 4  # Thêm octave để chi tiết hơn
	
	# Noise cho Độ ẩm (Moisture Zones)
	_moisture_noise = FastNoiseLite.new()
	_moisture_noise.seed = _noise.seed + 202
	_moisture_noise.frequency = 0.0022
	_moisture_noise.fractal_octaves = 4
	# Noise cho Rừng (cụm nhỏ)
	_forest_noise = FastNoiseLite.new()
	_forest_noise.seed = _noise.seed + 1000
	_forest_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_forest_noise.frequency = 0.05
	_forest_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	
	# Noise cho Biome (Các vùng lớn) - TĂNG TẦN SỐ ĐỂ DỄ TÌM THẤY
	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = _noise.seed + 5000
	_biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_biome_noise.frequency = 0.0018 # Biome quy mô vừa (giảm 1/2 so với V21)
	_biome_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	
	# Noise Phân tán (Đánh nát các cụm quặng)
	_scatter_noise = FastNoiseLite.new()
	_scatter_noise.seed = _noise.seed + 8000
	_scatter_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_scatter_noise.frequency = 0.3 
	_scatter_noise.fractal_octaves = 1 
	
	# Noise cho Sương mù
	_mist_noise = FastNoiseLite.new()
	_mist_noise.seed = _noise.seed + 6000
	_mist_noise.frequency = 0.02
	_mist_noise.fractal_octaves = 1 
	
	# [NEW] Noise chuyên dụng để làm biến dạng lục địa (QUYẾT ĐỊNH ĐỘ TỰ NHIÊN)
	_warp_noise = FastNoiseLite.new()
	_warp_noise.seed = _noise.seed + 9999
	_warp_noise.frequency = 0.01 # Tần số cao để tạo chi tiết gồ ghề
	_warp_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_warp_noise.fractal_octaves = 4
	_warp_noise.fractal_lacunarity = 2.0
	_warp_noise.fractal_gain = 0.5	
	
	# [NEW-V7] Giant Warp: Làm biến dạng quy mô lớn (Amoeba)
	_giant_warp_noise = FastNoiseLite.new()
	_giant_warp_noise.seed = _noise.seed + 777
	_giant_warp_noise.frequency = 0.0005 # Cực thấp để tạo các mảng nhô thụt lớn
	_giant_warp_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_giant_warp_noise.fractal_octaves = 2
	
	# [NEW-V7] Archipelago Filter: Lọc cụm đảo
	_archipelago_filter_noise = FastNoiseLite.new()
	_archipelago_filter_noise.seed = _noise.seed + 888
	_archipelago_filter_noise.frequency = 0.002
	_archipelago_filter_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_archipelago_filter_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE	# [NEW] Fault Noise: Mô phỏng đứt gãy địa chất → khoét vịnh + tạo đảo tách rời
	_fault_noise = FastNoiseLite.new()
	_fault_noise.seed = _noise.seed + 3141
	_fault_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_fault_noise.frequency = 0.0008   # Tần số thấp → các đứt gãy rộng, tự nhiên
	_fault_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_fault_noise.fractal_octaves = 3
	_fault_noise.fractal_lacunarity = 2.2
	_fault_noise.fractal_gain = 0.6

	# Noise cho sông
	_river_noise = FastNoiseLite.new()
	_river_noise.seed = _noise.seed + 1234
	_river_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_river_noise.frequency = 0.008 
	_river_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_river_noise.fractal_octaves = 4 
	_river_noise.fractal_lacunarity = 2.2
	_river_noise.fractal_gain = 0.55
	
	# Noise cho mặt nạ sông
	_river_mask_noise = FastNoiseLite.new()
	_river_mask_noise.seed = _noise.seed + 9999
	_river_mask_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_river_mask_noise.frequency = 0.0006 
	_river_mask_noise.fractal_octaves = 2
	
	print("InfiniteMapGenerator: World Genesis with seed: ", _noise.seed)
	
	_windmill_texture = load(windmill_real_path)
	if not _windmill_texture: print("[ERROR] Failed to load windmill texture: ", windmill_real_path)
	_apple_tree_texture = load(apple_tree_real_path)
	if not _apple_tree_texture: print("[ERROR] Failed to load apple_tree texture: ", apple_tree_real_path)
	
	if not tileset:
		tileset = load("res://resources/tilesets/main_tileset.tres")
	
	camera = get_viewport().get_camera_2d()
	# --- HỆ THỐNG LOAD BUILDING INFO (Hỗ trợ visual_offset & texture_origin) ---
	_windmill_offset = _load_offset_from_json(windmill_info_path, _windmill_texture, _windmill_offset)
	_core_offset = _load_offset_from_json(core_info_path, _core_tex, _core_offset)
	
	self.y_sort_enabled = true 
	
	_temp_layer = TileMapLayer.new()
	_temp_layer.tile_set = tileset
	add_child(_temp_layer)
	_temp_layer.visible = false 
	
	_windmill_texture = _windmill_tex
	_apple_tree_texture = preload("res://assets/props/plants/trees/oak_tree/oak_tree.png")
	
	_setup_debug_ui()
	_setup_pause_menu() # KHỞI TẠO MENU TẠM DỪNG
	_setup_settings_menu() # KHỞI TẠO MENU CÀI ĐẶT
	
	# Lắng nghe thay đổi cài đặt
	Config.settings_changed.connect(_on_settings_updated)
	_on_settings_updated() # Áp dụng lần đầu
	
	# MỞ KHÓA FPS (Sẽ được Config.gd quản lý)
	
	# KHỞI TẠO HỆ THỐNG GHOST (XEM TRƯỚC)
	_ghost_sprite = Sprite2D.new()
	_ghost_sprite.texture = _windmill_tex
	_ghost_sprite.scale = Vector2(0.3, 0.3) # Giá trị khởi tạo tạm thời
	_ghost_sprite.centered = true
	_ghost_sprite.modulate = Color(1, 1, 1, 0.4) # Trong suốt 40%
	_ghost_sprite.z_index = 100
	_ghost_sprite.visible = false
	add_child(_ghost_sprite)
	
	_ghost_shadow = Sprite2D.new()
	_ghost_shadow.modulate = Color(1, 1, 1, 0.3) # Bóng mờ 30%
	_ghost_shadow.z_index = 99 # Nằm dưới ghost_sprite
	_ghost_shadow.visible = false
	add_child(_ghost_shadow)
	
	# KHỞI TẠO KHUNG VIỀN 2X2 (XEM TRƯỚC VÙNG ĐẶT)
	_preview_outline = Line2D.new()
	_preview_outline.width = 2.0
	_preview_outline.default_color = Color(1, 1, 1, 0.8) # Màu trắng mờ
	_preview_outline.z_index = 98 # Nằm dưới bóng
	_preview_outline.visible = false
	# Tạo sẵn 5 điểm để vẽ thành hình thoi khép kín
	_preview_outline.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	add_child(_preview_outline)
	
	# 1. KHỞI TẠO CÁC STYLE CHO TOOLBAR
	var hotbar_hbox = get_node_or_null("../UI/HotbarContainer/HBox")
	if hotbar_hbox and hotbar_hbox.get_child_count() > 0:
		var base_style = (hotbar_hbox.get_child(0) as Panel).get_theme_stylebox("panel")
		if base_style:
			_style_normal = base_style.duplicate()
			var active = _style_normal.duplicate() as StyleBoxFlat
			active.border_color = Color(1, 0.8, 0.2, 0.8)
			active.border_width_left = 4
			active.border_width_top = 4
			active.border_width_right = 4
			active.border_width_bottom = 4
			active.bg_color = Color(1, 1, 1, 0.1)
			_style_active = active
	
	_update_hotbar_ui()
	
	# KHỞI TẠO WORLD MAP
	_world_map_instance = _world_map_scene.instantiate()
	_world_map_instance.process_mode = Node.PROCESS_MODE_ALWAYS # Quan trọng: Để Map xử lý được Signal khi game Pause
	add_child(_world_map_instance)
	_world_map_instance.visible = false
	
	# Kết nối tín hiệu Dịch chuyển từ bản đồ
	var map_root = _world_map_instance.get_node("Root")
	if map_root.has_signal("teleport_requested"):
		map_root.teleport_requested.connect(_on_map_teleport_requested)
		print("[SYSTEM] World Map Signal Connected.")
	
	# ĐẶT TRẠNG THÁI BAN ĐẦU (Time-Slicing: Không tạo tức thì để tránh lag Engine)
	_update_hotbar_ui()
	
	# THIẾT LẬP ĐIỂM HỒI SINH (CORE BUILDING)
	if spawn_building_type != "":
		var b_size = Vector2i(1, 1) # Mặc định Core là 1x1
		_building_roots[Vector2i(0, 0)] = {"type": spawn_building_type, "size": b_size}
		var footprint = generate_footprint(Vector2i(0, 0), b_size.x, b_size.y)
		for t in footprint:
			_occupied_tiles[t] = true
	
	print("InfiniteMapGenerator: Starting smooth world genesis...")
	update_chunks(false) # Chế độ FALSE (Mượt) thay vì TRUE (Đứng hình)
	
	# CACHE PLAYER REFERENCE (Tránh get_first_node_in_group mỗi frame)
	_cached_player = get_tree().get_first_node_in_group("player")
	
	# COMPONENT B: Khởi tạo MultiMeshTreeRenderer
	# Build texture map từ _tree_defs cho các loại cây được hỗ trợ
	var texture_map: Dictionary = {}
	for tree_type in MULTIMESH_TREE_TYPES:
		if _tree_defs.has(tree_type) and _tree_defs[tree_type]["tex"] != null:
			texture_map[tree_type] = _tree_defs[tree_type]["tex"]
	
	if not texture_map.is_empty():
		_tree_renderer = _MULTIMESH_SCRIPT.new()
		_tree_renderer.name = "MultiMeshTreeRenderer"
		add_child(_tree_renderer)
		_tree_renderer.setup(texture_map)
		print("[MultiMesh] Tree renderer khởi tạo thành công: %d loại cây" % texture_map.size())
	else:
		push_warning("[MultiMesh] Không có texture nào, fallback sang Sprite2D mode")
	
	_update_ui_labels()
	
	# LOG KHÖI ĐÀU: Biome t\u1ea1i (0,0)
	var n0 = _noise.get_noise_2d(0, 0) - 0.1
	var t0 = _temp_noise.get_noise_2d(0, 0)
	var m0 = _moisture_noise.get_noise_2d(0, 0)
	var b0 = (_biome_noise.get_noise_2d(0, 0) + 1.0) / 2.0
	var start_biome = _get_biome_name_debug(n0, t0, m0, b0)
	print("[STARTUP-LOG] Player Spawn at (0,0) | Biome: ", start_biome)

func _setup_debug_ui():
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	_ui_layer.layer = 100
	_ui_layer.visible = false # Ẩn mặc định theo yêu cầu
	
	# BẢNG ĐIỀU KHIỂN CHÍNH (Glassmorphism Style)
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.8) # Tối mịn, trong suốt
	style.corner_radius_top_left = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.set_content_margin_all(15)
	style.border_width_left = 2
	style.border_color = Color(0.3, 0.5, 0.8, 0.5) # Viền xanh nhẹ
	panel.add_theme_stylebox_override("panel", style)
	
	panel.position = Vector2(20, 20) # Chuyển lên góc trái trên
	panel.custom_minimum_size = Vector2(320, 0)
	_ui_layer.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var vsync_check = CheckBox.new()
	vsync_check.text = "V-Sync (Giới hạn 60 FPS)"
	vsync_check.button_pressed = false
	vsync_check.toggled.connect(func(t): 
		if t: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		else: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	)
	vbox.add_child(vsync_check)

	vbox.add_child(HSeparator.new())
	
	# --- NHÓM 2D VISUALS (XÂY DỰNG) ---
	var lbl_head_2d = Label.new()
	lbl_head_2d.text = "--- [2D BUILDING VISUALS] ---"
	lbl_head_2d.add_theme_color_override("font_color", Color(0, 1.0, 0.4)) # EMERALD
	vbox.add_child(lbl_head_2d)

	_lbl_2d_scale = Label.new()
	vbox.add_child(_lbl_2d_scale)
	_2d_scale_slider = HSlider.new(); _2d_scale_slider.min_value = 0.1; _2d_scale_slider.max_value = 4.0; _2d_scale_slider.value = 1.0; _2d_scale_slider.step = 0.01
	vbox.add_child(_2d_scale_slider)
	
	_show_2d_checkbox = CheckBox.new(); _show_2d_checkbox.text = "Hiện 2D Sprite (Hình ảnh)"; _show_2d_checkbox.button_pressed = true
	vbox.add_child(_show_2d_checkbox)
	
	_lbl_2d_x = Label.new()
	vbox.add_child(_lbl_2d_x)
	_2d_x_slider = HSlider.new(); _2d_x_slider.min_value = -500.0; _2d_x_slider.max_value = 500.0; _2d_x_slider.value = 0.0
	vbox.add_child(_2d_x_slider)
	
	_lbl_2d_y = Label.new()
	vbox.add_child(_lbl_2d_y)
	_2d_y_slider = HSlider.new(); _2d_y_slider.min_value = -500.0; _2d_y_slider.max_value = 500.0; _2d_y_slider.value = 0.0
	vbox.add_child(_2d_y_slider)
	
	vbox.add_child(HSeparator.new())
	
	_ui_fps = Label.new(); _ui_fps.add_theme_color_override("font_color", Color.YELLOW); vbox.add_child(_ui_fps)
	_ui_zoom = Label.new(); _ui_zoom.add_theme_color_override("font_color", Color.CYAN); vbox.add_child(_ui_zoom)
	_ui_statics = Label.new(); vbox.add_child(_ui_statics)
	_ui_lighting = Label.new(); vbox.add_child(_ui_lighting)
	_ui_flicker_time = Label.new(); vbox.add_child(_ui_flicker_time)
	_ui_chunk_time = Label.new(); vbox.add_child(_ui_chunk_time)
	_ui_queue_lbl = Label.new(); _ui_queue_lbl.add_theme_color_override("font_color", Color.ORANGE); vbox.add_child(_ui_queue_lbl)
	
	vbox.add_child(HSeparator.new())
	var lbl_prof = Label.new(); lbl_prof.text = "--- [MODULE PROFILER] ---"; vbox.add_child(lbl_prof)
	_ui_prof_noise = Label.new(); vbox.add_child(_ui_prof_noise)
	_ui_prof_tiles = Label.new(); vbox.add_child(_ui_prof_tiles)
	_ui_prof_objects = Label.new(); vbox.add_child(_ui_prof_objects)
	_ui_prof_physics = Label.new(); vbox.add_child(_ui_prof_physics)
	
	vbox.add_child(HSeparator.new())
	var lbl_tp = Label.new(); lbl_tp.text = "--- [TELEPORT TO BIOME] ---"; lbl_tp.add_theme_color_override("font_color", Color.VIOLET); vbox.add_child(lbl_tp)
	
	var hf_tp = FlowContainer.new(); vbox.add_child(hf_tp)
	var biomes = ["Desert", "Jungle", "Snowy", "Taiga", "Plains", "Volcano"]
	for b_type in biomes:
		var btn = Button.new()
		btn.text = b_type
		btn.pressed.connect(func(): teleport_to_nearest_biome(b_type))
		hf_tp.add_child(btn)

func _precalculate_clusters():
	# CỐI XAY GIÓ KHÔNG CÒN HARDCODE Ở (0,0)
	print("Construction System: Ready. Press '1' to build a windmill.")

func generate_footprint(root: Vector2i, w: int, h: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for i in range(w):
		for j in range(h):
			tiles.append(root + Vector2i(i, j))
	return tiles

func get_geometric_center(layer: TileMapLayer, footprint: Array[Vector2i]) -> Vector2:
	if footprint.is_empty(): return Vector2.ZERO
	var sum_p = Vector2.ZERO
	for tile in footprint:
		sum_p += layer.map_to_local(tile)
	return sum_p / float(footprint.size())

func _is_footprint_occupied(footprint: Array[Vector2i]) -> bool:
	for t in footprint:
		if _occupied_tiles.has(t):
			return true
	return false

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			if _selected_building == "windmill":
				_cancel_building() # NHẤN LẦN NỮA SẼ TẮT
			else:
				_selected_building = "windmill"
				_ghost_sprite.visible = true
				_ghost_shadow.visible = true
				_preview_outline.visible = true
				print("Building Mode: Windmill Selected.")
				_update_hotbar_ui()
		elif event.keycode == KEY_2:
			if _selected_building == "camfire":
				_cancel_building()
			else:
				_selected_building = "camfire"
				_ghost_sprite.texture = _camfire_tex
				_ghost_sprite.visible = true
				_ghost_shadow.visible = false # CAMPFIRE KHÔNG ĐỔ BÓNG 3D
				_preview_outline.visible = true
				print("Building Mode: Campfire Selected.")
				_update_hotbar_ui()
		elif event.keycode == KEY_ESCAPE:
			if _selected_building != "":
				_cancel_building()
			elif _world_map_instance.visible:
				_toggle_world_map(false)
			else:
				_toggle_pause_menu(!get_tree().paused)
		elif event.keycode == KEY_M:
			_toggle_world_map(!_world_map_instance.visible)
		elif event.keycode == KEY_F3:
			if _ui_layer:
				_ui_layer.visible = !_ui_layer.visible
			
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _selected_building != "":
			var m_pos = get_global_mouse_position()
			var t_pos = _temp_layer.local_to_map(_temp_layer.to_local(m_pos))
			# CHỌN KÍCH THƯỚC THEO LOẠI
			var b_size = Vector2i(1, 1)
			if _selected_building == "windmill":
				b_size = Vector2i(2, 2)
			var footprint = generate_footprint(t_pos, b_size.x, b_size.y)
			
			# CHẶN NẾU Ô ĐÃ CÓ NHÀ
			if _is_footprint_occupied(footprint):
				print("Vị trí này đã có công trình!")
				return
				
			_build_at_mouse(_selected_building, b_size)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_building()

func _cancel_building():
	_selected_building = ""
	_ghost_sprite.visible = false
	_ghost_shadow.visible = false
	_preview_outline.visible = false
	_update_hotbar_ui()
	print("Building Mode: Cancelled.")

func _update_hotbar_ui():
	var hotbar_hbox = get_node_or_null("UI/HotbarContainer/HBox")
	if not hotbar_hbox or not _style_normal: return
	
	for i in range(hotbar_hbox.get_child_count()):
		var slot = hotbar_hbox.get_child(i) as Panel
		var slot_num = i + 1
		
		# Hiện tại chỉ có phím 1 là cối xay gió
		if _selected_building == "windmill" and slot_num == 1:
			slot.add_theme_stylebox_override("panel", _style_active)
		elif _selected_building == "camfire" and slot_num == 2:
			slot.add_theme_stylebox_override("panel", _style_active)
		else:
			slot.add_theme_stylebox_override("panel", _style_normal)

func _build_at_mouse(type: String, size: Vector2i):
	if not _temp_layer: return
	
	# 1. TỌA ĐỘ CHUỘT -> TỌA ĐỘ Ô (TILE)
	var m_pos = get_global_mouse_position()
	# Phải dùng to_local vì map generator có thể bị di chuyển
	var tile_pos = _temp_layer.local_to_map(_temp_layer.to_local(m_pos))
	
	# 2. KIỂM TRA TRÙNG LẶP
	if _building_roots.has(tile_pos):
		print("Lỗi: Đã có công trình tại vị trí này!")
		return
	
	# 3. ĐĂNG KÝ CÔNG TRÌNH (KHÔNG ÉP BUỘC TẠO CỎ NỮA)
	_building_roots[tile_pos] = {"type": type, "size": size}
	
	# ĐÁNH DẤU CÁC Ô ĐÃ BỊ CHIẾM DỤNG
	var footprint = generate_footprint(tile_pos, size.x, size.y)
	for t in footprint:
		_occupied_tiles[t] = true
		
	update_chunks()
	# 4. CẬP NHẬT CHI TIẾT TRÊN BẢN ĐỒ (CHUNK HIỆN TẠI)
	var c_pos = Vector2i(floorf(tile_pos.x / float(CHUNK_SIZE)), floorf(tile_pos.y / float(CHUNK_SIZE)))
	if chunks.has(c_pos):
		var layer = chunks[c_pos].get_child(0)
		# KHÔNG set_cell để tạo cỏ nữa theo ý USER
		
		# Thêm bóng và ảnh 2D vào lớp
		footprint = generate_footprint(tile_pos, size.x, size.y)
		var c = get_geometric_center(layer, footprint)
		_add_rotation_test_object(chunks[c_pos], c, size, type)
		print("Xây dựng thành công: ", type, " tại ", tile_pos)

func _process(delta):
	# CHẾ ĐỘ TIẾT KIỆM (Optimize khi Window không active)
	if not _is_window_focused: 
		return
		
	var start_time = Time.get_ticks_usec()
	var frame_start = Time.get_ticks_msec()
	var current_fps = 1.0 / delta
	
	# 1. CẬP NHẬT UI NHÃN (Throttled - 5 lần/giây)
	var t_ghost_start = Time.get_ticks_usec()
	_ghost_update_timer += delta
	if _selected_building != "" and _temp_layer and _ghost_update_timer >= 0.033:
		_update_ghost_position()
		_ghost_update_timer = 0.0
	var t_ghost = Time.get_ticks_usec() - t_ghost_start
	
	# 2. CẬP NHẬT UI NHÃN (TIẾT KIỆM CPU: 5 lần/giây)
	var t_ui_start = Time.get_ticks_usec()
	_ui_update_timer += delta
	if _ui_update_timer >= 0.2:
		_update_ui_labels()
		_update_debug_labels(current_fps)
		_ui_update_timer = 0.0
	var t_ui = Time.get_ticks_usec() - t_ui_start
	
	# 3. HIỆU ỨNG NHẤP NHÁY (FLICKER) & DỌN DẸP BỘ NHỚ
	var t_cleanup_start = Time.get_ticks_usec()
	_cleanup_timer += delta
	# Dọn dẹp định kỳ cho các vật thể mọc tự nhiên (Prop) - Thưa hơn: 10s/lần
	if _cleanup_timer >= 10.0:
		# Dọn dẹp Dictionary bằng cách duyệt qua các Key (Chỉ chạy 10s một lần nên O(N) vẫn chấp nhận được)
		for key in _static_objects.keys():
			if not is_instance_valid(key): _static_objects.erase(key)
		for key in _lighting_objects.keys():
			if not is_instance_valid(key): _lighting_objects.erase(key)
		_cleanup_timer = 0.0
	var t_cleanup = Time.get_ticks_usec() - t_cleanup_start
		
	var t_flicker_start = Time.get_ticks_usec()
	var processed_count = 0
	
	# TỐI ƯU CỰC ĐỘ: Chỉ quét qua các đèn đang THỰC SỰ HIỆN TRÊN MÀN HÌNH (O(1...10))
	for pivot in _active_lighting_objects.keys():
		if not is_instance_valid(pivot): 
			_active_lighting_objects.erase(pivot)
			continue
			
		if processed_count >= 10: break # Giới hạn tối đa 10 đèn flicker/frame cho GPU yếu
		
		var light = pivot.get_node_or_null("CampfireLight") as PointLight2D
		if light:
			light.energy = 1.2 + randf() * 0.4
			light.texture_scale = 1.0 + randf() * 0.05
			processed_count += 1
	var t_flicker = Time.get_ticks_usec() - t_flicker_start
	
	# 4. CHUNK UPDATE (Genesis Burst & Adaptive Power)
	var t_chunk_start = Time.get_ticks_usec()
	if _genesis_timer > 0: _genesis_timer -= delta
	
	if camera:
		var zoom_factor = 1.0 / camera.zoom.x
		var power_multiplier = clampi(ceili(zoom_factor), 1, 3)
		
		# CHẾ ĐỘ BURST: Thắt chặt công suất ngay cả khi mới vào
		if _genesis_timer > 0:
			_max_tiles_per_frame = 64 # Giảm từ 256 xuống 64 để tránh khựng
			_gen_budget_usec = 4000    # Giảm từ 16ms xuống 4ms
		elif _generation_queue.size() > 50:
			_max_tiles_per_frame = 48
			_gen_budget_usec = 3000
		else:
			_max_tiles_per_frame = BASE_MAX_TILES * power_multiplier
			_gen_budget_usec = BASE_GEN_BUDGET * power_multiplier
		
		# TỐI ƯU CỰC ĐỘ: Chỉ quét tìm chunk mới theo chu kỳ (Throttling)
		_chunk_update_timer += delta
		if _chunk_update_timer >= CHUNK_UPDATE_INTERVAL:
			var t_start = Time.get_ticks_usec()
			update_chunks()
			_t_process_other += (Time.get_ticks_usec() - t_start)
			_chunk_update_timer = 0.0
	
	# Xử lý hàng đợi tạo chunk với ngân sách thích ứng
	var tiles_generated = _process_generation_queue(_gen_budget_usec)
	
	# Xử lý hàng đợi xóa chunk cũ (1 chunk mỗi frame) để tránh lag Engine render
	var t_rem_start = Time.get_ticks_usec()
	var chunks_removed = _process_removal_queue()
	_t_process_other += (Time.get_ticks_usec() - t_rem_start)
	
	# T\u1ed0I \u01afU CRITICAL: Gi\u1ea3i ph\u00f3ng h\u00e0ng \u0111\u1ee3i Prop t\u1eebng t\u00ed (tr\u00e1nh Physics Server b\u1ecb qu\u00e1 t\u1ea3i 1 frame)
	if not _pending_props.is_empty():
		var count = mini(PROP_BUDGET_PER_FRAME, _pending_props.size())
		for i in range(count):
			var p = _pending_props.pop_front()
			if is_instance_valid(p["parent"]):
				_add_rotation_test_object(p["parent"], p["center"], p["size"], p["type"])
	
	# COMPONENT C: Distance-based Fade dùng Spatial Hash (O(1) với radius nhỏ)
	_fade_check_timer += delta
	if _fade_check_timer >= FADE_CHECK_INTERVAL:
		var t_fade_start = Time.get_ticks_usec()
		_fade_check_timer = 0.0
		if not _cached_player or not is_instance_valid(_cached_player):
			_cached_player = get_tree().get_first_node_in_group("player")
		if _cached_player:
			var p_pos = _cached_player.global_position
			# Query chỉ cells xưng quanh player (bán kính 1 cell = 1000px)
			var nearby = _spatial_query(p_pos, SPATIAL_CELL)
			for pivot in nearby:
				if not is_instance_valid(pivot): continue
				var dist_sq = pivot.global_position.distance_squared_to(p_pos)
				var building_ref = pivot.get_meta("building_ref", null)
				if building_ref and is_instance_valid(building_ref):
					_fade_building(building_ref, 0.2 if dist_sq < 302500 else 1.0)
		_t_process_other += (Time.get_ticks_usec() - t_fade_start)

	var t_chunk = Time.get_ticks_usec() - t_chunk_start
	
	# PROFILING: Log chi tiết khi cực kỳ chậm (>25ms)
	var total_process = Time.get_ticks_usec() - start_time
	var frame_time = Time.get_ticks_msec() - frame_start
	
	if frame_time > 16: # 16ms = ngưỡng không đạt 60 FPS
		print("[SLOW FRAME] Total: %dms | Script: %.2fms | Noise: %.1fms | Tiles: %.1fms | Objects: %.1fms | Other: %.1fms" % [
			frame_time, 
			total_process / 1000.0,
			_t_noise / 1000.0,
			_t_tiles / 1000.0,
			_t_objects / 1000.0,
			_t_process_other / 1000.0
		])
		
	if frame_time > 33: # 33ms = ngưỡng không đạt 30 FPS (Critical)
		print("[ALERT] Critical FPS Drop: %.2f (%d ms) | NGUYÊN NHÂN: Noise: %.1fms, Tiles: %.1fms, Objects: %.1fms, Other: %.1fms" % [
			current_fps, frame_time, _t_noise/1000.0, _t_tiles/1000.0, _t_objects/1000.0, _t_process_other/1000.0
		])
		
	# Reset bộ đếm sau khi log
	_t_noise = 0; _t_tiles = 0; _t_objects = 0; _t_physics_reg = 0; _t_process_other = 0

func _update_ui_labels():
	if not _lbl_2d_scale or not _2d_scale_slider: return
	_lbl_2d_scale.text = "2D Size: %.2f" % _2d_scale_slider.value
	_lbl_2d_x.text = "2D Offset X: %.1f" % _2d_x_slider.value
	_lbl_2d_y.text = "2D Offset Y: %.1f" % _2d_y_slider.value
	
func _update_debug_labels(fps: float):
	# Sử dụng hoàn toàn Caching Nodes để tránh lag
	if _ui_fps: 
		_ui_fps.text = "FPS: %d (%.1f ms)" % [fps, 1000.0/fps if fps > 0 else 0]
		_ui_fps.add_theme_color_override("font_color", Color.YELLOW if fps > 45 else Color.RED)
		
	if _ui_zoom and camera: 
		_ui_zoom.text = "Zoom: %.2f x %.2f" % [camera.zoom.x, camera.zoom.y]
		
	if _ui_statics: 
		_ui_statics.text = "Vật thể tĩnh: %d" % _static_objects.size()
	
	# CHI TIẾT PROFILER
	if _ui_prof_noise: _ui_prof_noise.text = "Noise Math: %.2f ms" % (_t_noise / 1000.0)
	if _ui_prof_tiles: _ui_prof_tiles.text = "Tile Setting: %.2f ms" % (_t_tiles / 1000.0)
	if _ui_prof_objects: _ui_prof_objects.text = "Object Spawn: %.2f ms" % (_t_objects / 1000.0)
	if _ui_prof_physics: _ui_prof_physics.text = "Physics Reg: %.2f ms" % (_t_physics_reg / 1000.0)
	
	# Cảnh báo module nặng
	if _ui_prof_noise and _t_noise > 8000: _ui_prof_noise.add_theme_color_override("font_color", Color.RED)
	else: _ui_prof_noise.add_theme_color_override("font_color", Color.WHITE)
		
	if _ui_lighting: 
		_ui_lighting.text = "Vật thể ánh sáng: %d" % _lighting_objects.size()

	if camera and _ui_chunk_time:
		var cp = camera.global_position
		var tp = _temp_layer.local_to_map(_temp_layer.to_local(cp))
		var chunk_p = Vector2i(floorf(tp.x / float(CHUNK_SIZE)), floorf(tp.y / float(CHUNK_SIZE)))
		
		# Tính toán Biome tại chỗ
		var n = _noise.get_noise_2d(tp.x, tp.y) - 0.1
		var t = _temp_noise.get_noise_2d(tp.x, tp.y)
		var m = _moisture_noise.get_noise_2d(tp.x, tp.y)
		var b = (_biome_noise.get_noise_2d(tp.x, tp.y) + 1.0) / 2.0
		var b_name = _get_biome_name_debug(n, t, m, b)
		
		_ui_chunk_time.text = "Coordinate: %.0f, %.0f | Tile: %d, %d | Chunk: %d,%d\nBiome: %s" % [cp.x, cp.y, tp.x, tp.y, chunk_p.x, chunk_p.y, b_name]
		
	if _ui_queue_lbl:
		_ui_queue_lbl.text = "Hàng đợi (Vẽ/Xóa): %d / %d" % [_generation_queue.size(), _removal_queue.size()]

func _get_biome_name_debug(n_val, t_val, m_val, b_val, r_val = 1.0, gpos: Vector2 = Vector2.ZERO):
	if n_val < -0.4: return "Biển sâu (Deep Sea)"
	if n_val < -0.32: return "Bờ biển (Beach)"
	if r_val == 0.0: return "Sông (River)"
	
	# 2. VÙNG ĐẶC BIỆT (Priority High)
	var v_center = Vector2(250, -250)
	var v_warp = _warp_noise.get_noise_2d(gpos.x * 2.5, gpos.y * 2.5) * 80.0
	var dist_v = gpos.distance_to(v_center) + v_warp
	
	var v_mask = smoothstep(400.0, 50.0, dist_v) 
	var v_final = b_val * 0.4 + v_mask * 0.7 
	
	# Hồ dung nham cũng uốn lượn (Warp mạnh hơn)
	var l_warp = _warp_noise.get_noise_2d(gpos.x * 5.0, gpos.y * 5.0) * 25.0
	if (gpos.distance_to(v_center) + l_warp) < 50.0: return "Núi lửa (Volcano)" 
	
	if v_final > 0.8: return "Núi lửa (Volcano)"
	if b_val < 0.15: return "Rừng tre (Bamboo Forest)"
	
	var is_hot = t_val > 0.3
	var is_cold = t_val < -0.45
	var is_dry = m_val < -0.2
	var is_wet = m_val > 0.3
	
	if is_cold: 
		return "Đài nguyên (Tundra)"
	
	if is_hot:
		if is_dry: return "Sa mạc (Desert)"
		if is_wet: return "Rừng nhiệt đới (Jungle)"
		return "Savannah nhiệt đới"
	else:
		if is_wet: return "Rừng ôn đới (Forest)"
		if is_dry: return "Thảo nguyên khô (Steppe)"
		return "Đồng cỏ (Plains)"

func _update_ghost_position():
	if not _temp_layer: return
	var m_pos = get_global_mouse_position()
	var t_pos = _temp_layer.local_to_map(_temp_layer.to_local(m_pos))
	
	# Chỉ quan tâm đến việc di chuyển tile
	if t_pos == _last_mouse_tile_pos: return
	_last_mouse_tile_pos = t_pos
	
	var b_size = Vector2i(1, 1)
	if _selected_building == "windmill":
		b_size = Vector2i(2, 2)
	var footprint = generate_footprint(t_pos, b_size.x, b_size.y)
	var snapped_center = get_geometric_center(_temp_layer, footprint)
	
	_ghost_sprite.position = snapped_center
	if _ghost_sprite.texture:
		var h = _ghost_sprite.texture.get_height()
		var s2d = _2d_scale_slider.value
		_ghost_sprite.position.y -= (h * s2d) / 2.0
	
	_ghost_sprite.position.x += _2d_x_slider.value
	_ghost_sprite.position.y += _2d_y_slider.value
	_ghost_sprite.scale = Vector2(_2d_scale_slider.value, _2d_scale_slider.value)
	
	if _is_footprint_occupied(footprint):
		_preview_outline.default_color = Color(1, 0, 0, 0.8)
	else:
		_preview_outline.default_color = Color(1, 1, 1, 0.8)
	
	var offset_w = 250.0 * b_size.x
	var offset_h = 125.0 * b_size.y
	var p_top = snapped_center + Vector2(0, -offset_h)
	var p_right = snapped_center + Vector2(offset_w, 0)
	var p_bottom = snapped_center + Vector2(0, offset_h)
	var p_left = snapped_center + Vector2(-offset_w, 0)
	_preview_outline.points = PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top])



func update_chunks(immediate: bool = false):
	if not camera: return
	var cam_pos = camera.global_position
	
	var t_update_start = Time.get_ticks_usec()
	# CHỈ CẬP NHẬT KHI DI CHUYỂN ĐỦ XA (256px - 16 gạch) HOẶC ZOOM THAY ĐỔI
	if cam_pos.distance_to(_last_cam_update_pos) < 256.0 and not immediate:
		_t_physics_reg += (Time.get_ticks_usec() - t_update_start) # Mượn physics_reg để đo logic update
		return
	_last_cam_update_pos = cam_pos
	
	var tile_pos = _temp_layer.local_to_map(_temp_layer.to_local(cam_pos))
	var cur_c = Vector2i(floorf(tile_pos.x / CHUNK_SIZE), floorf(tile_pos.y / CHUNK_SIZE))
	
	# TÍNH TOÁN TẦM NHÌN ĐỘNG (Dynamic Sight) DỰA TRÊN ZOOM
	var zoom_factor = 1.0 / camera.zoom.x
	# GIỚI HẠN THẮT CHẶT: Tầm nhìn tối tối đa 12 chunk (đủ cho 1080p zoom out)
	var effective_dist = clampi(ceili(RENDER_DISTANCE * zoom_factor), RENDER_DISTANCE, 12)
	
	# GIỚI HẠN MAP: Tính chunk boundary
	var max_chunk = ceili(map_size / float(CHUNK_SIZE))
	var min_chunk = -max_chunk
	
	# 1. TÌM CHUNK MỚI THEO HÌNH XOÁY (O(N^2) Optimized)
	for r in range(effective_dist + 1):
		# Duyệt hàng trên và hàng dưới
		for dx in range(-r, r + 1):
			var c1 = cur_c + Vector2i(dx, r)
			var c2 = cur_c + Vector2i(dx, -r)
			if _is_chunk_in_bounds(c1, min_chunk, max_chunk): _check_and_add_chunk(c1)
			if r > 0 and _is_chunk_in_bounds(c2, min_chunk, max_chunk): _check_and_add_chunk(c2)
		# Duyệt cột trái và cột phải (tránh các góc đã duyệt ở trên)
		for dy in range(-r + 1, r):
			var c1 = cur_c + Vector2i(r, dy)
			var c2 = cur_c + Vector2i(-r, dy)
			if _is_chunk_in_bounds(c1, min_chunk, max_chunk): _check_and_add_chunk(c1)
			if _is_chunk_in_bounds(c2, min_chunk, max_chunk): _check_and_add_chunk(c2)
	
	if immediate:
		_process_generation_queue(999999) 

	# 2. TÌM CHUNK CŨ ĐỂ XÓA (Buffer Zone)
	var removal_dist = effective_dist + 2
	for cp in chunks.keys():
		if abs(cp.x - cur_c.x) > removal_dist or abs(cp.y - cur_c.y) > removal_dist:
			if not _removal_set.has(cp):
				_removal_queue.push_back(cp)
				_removal_set[cp] = true
	
	_t_physics_reg += (Time.get_ticks_usec() - t_update_start)

func _is_chunk_in_bounds(cp: Vector2i, min_c: int, max_c: int) -> bool:
	return cp.x >= min_c and cp.x <= max_c and cp.y >= min_c and cp.y <= max_c

func _check_and_add_chunk(cp: Vector2i):
	# TỐI ƯU: Hủy xóa bằng cách xóa khỏi Set. 
	if _removal_set.has(cp):
		_removal_set.erase(cp)
		return
		
	if not chunks.has(cp) and not _generation_set.has(cp): 
		# THỰC HIỆN GIỚI HẠN BẢN ĐỒ (BOUNDARY CHECK)
		var max_c = floorf(map_size / float(CHUNK_SIZE)) / 2.0
		if abs(cp.x) > max_c or abs(cp.y) > max_c:
			return # Không tạo chunk nằm ngoài hình vuông giới hạn
			
		_generation_queue.push_back(cp)
		_generation_set[cp] = true
		_trigger_background_noise(cp)

func _create_chunk_node(cpos: Vector2i):
	var t_obj_start = Time.get_ticks_usec()
	var chunk_node = Node2D.new()
	chunk_node.set_script(_chunk_script)
	chunk_node.y_sort_enabled = true 
	add_child.call_deferred(chunk_node) # TỐI ƯU: Đưa vào Scene Tree bất đối xứng
	chunks[cpos] = chunk_node
	chunk_node.setup(cpos, tileset)
	_t_objects += (Time.get_ticks_usec() - t_obj_start)
	return chunk_node
		
# --- CHỨC NĂNG DỊCH CHUYỂN BIOME (SPIRAL SEARCH) ---
func teleport_to_nearest_biome(type: String):
	if not camera: return
	print("[TELEPORT] Đang tìm kiếm Biome: ", type)
	
	var start_c = Vector2i(floorf(camera.global_position.x / (CHUNK_SIZE * 16)), floorf(camera.global_position.y / (CHUNK_SIZE * 16)))
	var found = false
	var target_pos = Vector2.ZERO
	
	# Quét rộng ra 50 chunk xung quanh (Bản kính lớn để tìm vùng hiếm)
	for r in range(1, 50):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) == r or abs(dy) == r:
					var cp = start_c + Vector2i(dx, dy)
					var gx = cp.x * CHUNK_SIZE * 16
					var gy = cp.y * CHUNK_SIZE * 16
					
					# Sample Noise tại tâm của chunk đó
					var n = _noise.get_noise_2d(gx, gy) - 0.35
					if n < -0.3: continue # Bỏ qua biển
					
					var t = _temp_noise.get_noise_2d(gx, gy)
					var m = _moisture_noise.get_noise_2d(gx, gy)
					var b = (_biome_noise.get_noise_2d(gx, gy) + 1.0) / 2.0
					
					var match_found = false
					match type:
						"Desert": match_found = t > 0.3 and m < -0.2
						"Jungle": match_found = t > 0.3 and m > 0.3
						"Snowy":  match_found = t < -0.2 and m < -0.2
						"Taiga":  match_found = t < -0.2 and m > 0.3
						"Plains": match_found = abs(t) < 0.2 and abs(m) < 0.2
						"Volcano": match_found = b > 0.95
					
					if match_found:
						target_pos = Vector2(gx, gy)
						found = true
						break
			if found: break
		if found: break
		
	if found:
		print("[TELEPORT] Đã tìm thấy! Dịch chuyển tới: ", target_pos)
		camera.global_position = target_pos
		update_chunks(true) # Force cập nhật ngay lập tức
	else:
		print("[TELEPORT] Không tìm thấy Biome này trong phạm vi 50 chunks.")

func _process_generation_queue(budget: int) -> int:
	var start_time = Time.get_ticks_usec()
	var tiles_this_frame = 0 # Giới hạn số ô gạch mỗi khung hình (Engine Budget)
	var chunks_completed = 0
	var cache_hits = 0
	var cache_misses = 0
	
	while not _generation_queue.is_empty() or _current_gen_chunk != Vector2i(-999, -999):
		# TỐI ƯU CỰC ĐỘ: Kiểm tra budget ngay khi bắt đầu một Chunk mới
		# Nếu hết thời gian, không pop thêm chunk từ queue, giữ lại cho frame sau
		if Time.get_ticks_usec() - start_time > budget:
			return tiles_this_frame

		if _current_gen_chunk == Vector2i(-999, -999):
			_current_gen_chunk = _generation_queue.pop_front()
			_generation_set.erase(_current_gen_chunk)
			_current_tile_idx = 0
			# KHÔNG tạo node ở đây nữa (Trì hoãn cho đến khi có Noise)
			
		# KIỂM TRA AN TOÀN: Nếu Chunk này bị xóa trong lúc đang vẽ dở (Race condition)
		if not chunks.has(_current_gen_chunk):
			_current_gen_chunk = Vector2i(-999, -999)
			_current_tile_idx = 0
			continue
			
		var chunk_node = chunks[_current_gen_chunk]
		var layer = chunk_node.height_layers[0]
		var prop_layer = chunk_node.prop_layer
		var s = _current_gen_chunk * CHUNK_SIZE
		
		# TRUY XUẤT NOISE AN TOÀN (Dùng Mutex)
		var t_noise_start = Time.get_ticks_usec()
		var cached_noise = null
		_noise_mutex.lock()
		if _noise_cache.has(_current_gen_chunk):
			cached_noise = _noise_cache[_current_gen_chunk]
		_noise_mutex.unlock()
		_t_noise += (Time.get_ticks_usec() - t_noise_start)
		
		# Nếu chưa có Noise (đang tính trong thread), BỎ QUA HOÀN TOÀN
		if not cached_noise:
			_trigger_background_noise(_current_gen_chunk)
			_generation_queue.push_back(_current_gen_chunk)
			_current_gen_chunk = Vector2i(-999, -999)
			continue
		
		# CHỈ TẠO NODE KHI ĐÃ CÓ NOISE VÀ CÒN BUDGET
		if not chunks.has(_current_gen_chunk):
			_create_chunk_node(_current_gen_chunk)
		
		# COMPONENT D: Local variable cache — tránh double dict lookup trong hot loop
		# Thay vì cached_noise["terrain"][idx] (2 lookups) → dùng _cn_terrain[idx] (1 access)
		var _cn_terrain = cached_noise["terrain"]
		var _cn_forest  = cached_noise["forest"]
		var _cn_river   = cached_noise["river"]
		var _cn_temp    = cached_noise["temp"]
		var _cn_moist   = cached_noise["moisture"]
		var _cn_riv_mask = cached_noise["riv_mask"]
		var _cn_biome   = cached_noise["biome"]
		var _cn_scatter = cached_noise["scatter"]
		
		while _current_tile_idx < CHUNK_SIZE * CHUNK_SIZE:
			# Kiểm tra cả số lượng và thời gian thực hiện
			if tiles_this_frame >= _max_tiles_per_frame:
				return tiles_this_frame
			# Kiểm tra thời gian thực sau mỗi 2 ô gạch (Thay vì 8) để thắt chặt kỷ luật ngân sách
			if tiles_this_frame % 2 == 0 and Time.get_ticks_usec() - start_time > budget:
				return tiles_this_frame
				
			var lx = _current_tile_idx % CHUNK_SIZE
			var ly = _current_tile_idx / CHUNK_SIZE
			var gpos = s + Vector2i(lx, ly)
			
			# KIỂM TRA GIỚI HẠN MAP
			if abs(gpos.x) > map_size or abs(gpos.y) > map_size:
				layer.set_cell(gpos, 21, Vector2i(0, 0)) # Nước mặn bao quanh
				_current_tile_idx += 1
				tiles_this_frame += 1
				continue
			
			# TÍNH KHOẢNG CÁCH TỪ TÂM (0,0) ĐỂ TẠO LỤC ĐỊA TRÒN
			# [V4-OPTIMIZE] Bỏ qua vì đã được tính trong Thread Noise
			var dist_from_center = Vector2(gpos.x, gpos.y).length() / map_size
			# var continent_mask = smoothstep(continent_radius, continent_radius + 0.15, dist_from_center)
			
			# ĐỌC NOISE (Đã chứa toàn bộ logic mask và địa hình)
			var n_val      = _cn_terrain[_current_tile_idx]
			var forest_val = _cn_forest[_current_tile_idx]
			var river_val  = _cn_river[_current_tile_idx]
			var r_mask_val = (_cn_riv_mask[_current_tile_idx] + 1.0) / 2.0 # Chuẩn hóa 0..1
			var temp_val   = _cn_temp[_current_tile_idx]
			var moist_val  = _cn_moist[_current_tile_idx]
			var b_val      = (_cn_biome[_current_tile_idx] + 1.0) / 2.0
			var scatter_val= (_cn_scatter[_current_tile_idx] + 1.0) / 2.0
			
			# n_val = n_val - (continent_mask * 0.8)
			
			var sid = 1 # Mặc định: Cỏ
			var prop_id = -1 # Mặc định: Không có vật thể
			var tree_type = ""
			var is_large_tree = false
			
			if force_block_id >= 0:
				sid = force_block_id
			else:
				# --- HỆ THỐNG BIOME VĨ MÔ (MINECRAFT STYLE) ---
				
				# 1. ĐẠI DƯƠNG (Ocean) - Dựa trên độ cao (Noise chính)
				if n_val < -0.4:
					sid = 21 # Salt Water (Mặn)
				elif n_val < -0.32:
					sid = 2 # Tất cả bờ biển đều là Cát vàng (Sand)
				
				# 2. MA TRẬN KHÍ HẬU (Nhiệt độ x Độ ẩm)
				else:
					var is_hot = temp_val > 0.3
					var is_cold = temp_val < -0.45
					var is_dry = moist_val < -0.1
					var is_wet = moist_val > 0.2
					
					# PHÂN LOẠI BIOME CHÍNH
					if is_cold:
						sid = 8 # Snow Block
						if forest_val > 0.3: prop_id = 26 # Winter Pine
						if scatter_val > 0.95: prop_id = 30 # Stone Ore (thường thấy ở vùng lạnh)
					elif is_hot:
						if is_dry: # Sa mạc (Desert)
							sid = 2 # Sand
							if forest_val > 0.55: prop_id = 20 # Cactus — xuất hiện nhiều hơn
							if scatter_val > 0.96: prop_id = 33 # Copper
						elif is_wet: # Rừng nhiệt đới ẩm
							sid = 9 # Đất rừng xậm
							if forest_val > 0.1: prop_id = 23 # Coffee/Jungle trees
						else: # Savannah nhiệt đới (nóng nhưng không khô, không ẩm)
							sid = 1 # Cỏ
							if forest_val > 0.75: prop_id = 6 # Bụi rậm thưa
					else:
						# Vùng ôn đới (Grassland / Forest)
						sid = 1 
						if is_wet: # Rừng rậm ôn đới
							if forest_val > 0.2: prop_id = 18 # Oak
						elif is_dry: # Savannah
							sid = 1
							if forest_val > 0.8: prop_id = 6 # Bush
						else: # Plains
							if forest_val > 0.9: prop_id = 6
					
					# 3. CÁC BIOME SÔNG NGÒI (Natural Rivers)
					# SÔNG MỚI: river_val từ thread đã encode sẵn (0.0=sông chính, 0.5=sông nhánh, 1.0=đất)
					# Chỉ áp sông khi đất không phải biển/bờ biển
					if river_val < 0.8 and n_val > -0.1 and n_val < 0.45:
						sid = 3 # Sông chính → Nước ngọt
					elif river_val < 0.6 and n_val > -0.05 and n_val < 0.4:
						sid = 3 # Sông nhánh
					
					# 4. ĐỊA HÌNH ĐẶC BIỆT (Cellular Noise)
					# --- BIOME DECISION ---
					var v_final = b_val
					var v_center = Vector2(250, -250)
					var v_warp = _warp_noise.get_noise_2d(gpos.x * 2.5, gpos.y * 2.5) * 80.0
					var dist_v = gpos.distance_to(v_center) + v_warp
					
					if n_val > -0.25: # Chỉ có núi lửa trên cạn
						var v_mask = smoothstep(400.0, 50.0, dist_v)
						v_final = b_val * 0.4 + v_mask * 0.7

					# Hồ dung nham cũng uốn lượn tự nhiên (Warp riêng)
					var l_warp = _warp_noise.get_noise_2d(gpos.x * 5.0, gpos.y * 5.0) * 25.0
					var dist_lake = gpos.distance_to(v_center) + l_warp
					
					if dist_lake < 50.0 and n_val > -0.2: # HỒ DUNG NHAM TRUNG TÂM (Tự nhiên)
						sid = 26 # Lava Block
						prop_id = 25 # Tro bụi
					elif v_final > 0.8: # BIOME NÚI LỬA (Volcano / Rocky Peaks)
						if n_val < -0.15: # Vùng trũng trong núi lửa -> LAVA
							sid = 26 # Lava Block
						else:
							sid = 27 # Black Bazan Block
						
						# Phủ tro bụi núi lửa (Ash Overlay) - TỐI ƯU: GIẢM MẬT ĐỘ (Thưa thớt hơn)
						if forest_val > 0.7: # Chỉ 15% diện tích có tro bụi (Giảm lag)
							prop_id = 25 # Volcanic Ash Overlay
						# Quặng vàng hiếm ở núi lửa
						if scatter_val > 0.98: prop_id = 32 # Gold Ore
					elif b_val < 0.15: # Rừng tre (Bamboo)
						sid = 10
						if forest_val > 0.4: prop_id = 19

			# ĐẢM BẢO VÙNG SPAWN (0,0) KHÔNG BỊ TRỐNG HOẶC KẸT
			if abs(gpos.x) < 2 and abs(gpos.y) < 2:
				sid = 1 # Cỏ mặc định cho vùng spawn
				prop_id = -1 # Không cho phép cây cối đè lên người chơi

			# ĐẶT TILE NỀN
			var t_tile_base = Time.get_ticks_usec()
			
			# CHẨN ĐOÁN & BIẾN ĐỔI TILE NỀN (V3)
			# Phá bỏ vành đai cát đồng nhất: Bãi cát giờ đây phụ thuộc vào độ dốc và noise phân tán
			var beach_jitter = scatter_val * 0.1
			if sid == 2: # Nếu logic trước đó định nghĩa là Beach
				if n_val < -0.38 + beach_jitter: # Nếu quá sâu -> Về lại nước cạn hoặc giữ cát tùy noise
					pass
				elif n_val > -0.3 + beach_jitter: # Nếu quá cao -> Chuyển thành Cỏ (Plains) lấn ra biển
					sid = 1 
			
			layer.set_cell(gpos, sid, Vector2i(0, 0))
			_t_tiles += (Time.get_ticks_usec() - t_tile_base)
			
			# CHẨN ĐOÁN SAU TELEPORT (Sửa lỗi làm tròn số âm bằng cách check bán kính 2 ô)
			if _pending_teleport_tile.distance_to(Vector2(gpos)) < 1.5:
				var actual_biome = _get_biome_name_debug(n_val, temp_val, moist_val, b_val, river_val, gpos)
				var match_status = "[MATCH]" if actual_biome == _expected_biome_after_teleport else "[MISMATCH]"
				
				print("[DEBUG-MAP] Arrival Check | Tile: %s" % gpos)
				print("    -> MAP Expected: %s" % _expected_biome_after_teleport)
				print("    -> GAME Actual:   %s %s" % [actual_biome, match_status])
				print("    -> Details: Height: %.2f | Temp: %.2f | Moist: %.2f" % [n_val, temp_val, moist_val])
				# Lưu ý: Không reset _pending_teleport_tile ngay lập tức để in được vài ô xung quanh
			
			# ĐẶT VẬT THỂ (PROPS)
			if prop_id >= 0:
				# DÙNG CONSTANT thay vì tạo Array mỗi tile (tiết kiệm allocation)
				if sid in FLUID_TILE_IDS:
					prop_id = -1 
				# Chặn cây cối trên đá, nhưng cho phép tro bụi (Ash)
				elif sid in SOLID_TILE_IDS:
					if prop_id != 25: # Nếu KHÔNG PHẢI là Ash
						prop_id = -1
			
			if prop_id >= 0:
				tree_type = ""
				match prop_id:
					18: tree_type = "oak"
					17: tree_type = "maple"
					19: tree_type = "bamboo"
					20: tree_type = "cactus"
					23: tree_type = "coffee"
					24: tree_type = "cotton"
					26: tree_type = "winter_pine"
					5: tree_type = "oak" 
					25: tree_type = "" # Ash (Tĩnh)
					6: tree_type = "bush"
					# CÁC LOẠI QUẶNG (30-34) KHÔNG GÁN tree_type ĐỂ TỰ ĐỘNG DÙNG TILEMAP (TỐI ƯU FPS)
				
				# Phân loại để xử lý làm mờ (Node) hoặc tĩnh (TileMap)
				is_large_tree = (tree_type != "")
				
				if is_large_tree:
					# T\u1ed0I \u01afU CRITICAL: Đẩy vào hàng đợi thay vì tạo ngay → dàn trải Physics overhead
					_pending_props.append({
						"parent": chunk_node,
						"center": layer.map_to_local(gpos),
						"size": Vector2i(1, 1),
						"type": tree_type
					})
				else:
					# Đóng vai trò là vật thể nhỏ (Cây bụi, đá nhỏ, v.v.)
					prop_layer.set_cell(gpos, prop_id, Vector2i(0, 0))
			
			if _building_roots.has(gpos):
				var data = _building_roots[gpos]
				var fp = generate_footprint(gpos, data["size"].x, data["size"].y)
				var c = get_geometric_center(layer, fp)
				_add_rotation_test_object(chunk_node, c, data["size"], data["type"])
				
			_current_tile_idx += 1
			tiles_this_frame += 1
			
			if Time.get_ticks_usec() - start_time > budget:
				return tiles_this_frame
				
			# Sau khi sinh 1 vật thể lớn (Rotation Test Object), check budget ngay vì nó tốn CPU nhất
			if prop_id >= 0 and tree_type != "":
				if Time.get_ticks_usec() - start_time > budget:
					return tiles_this_frame
				
		_current_gen_chunk = Vector2i(-999, -999)
		_current_tile_idx = 0
		chunks_completed += 1
		
		if Time.get_ticks_usec() - start_time > budget or tiles_this_frame >= _max_tiles_per_frame:
			return tiles_this_frame
	
	return tiles_this_frame

func _process_removal_queue() -> int:
	if _removal_queue.is_empty(): return 0
	
	# Xóa tối đa 1 chunk mỗi frame để tránh giật hình
	var cp = _removal_queue.pop_front()
	
	# O(1) Check: Nếu chunk đã bị "Hủy xóa" (không còn trong Set), bỏ qua ngay
	if not _removal_set.has(cp): return 0
	
	_noise_mutex.lock()
	_noise_cache.erase(cp) # Xóa cache noise
	_noise_mutex.unlock()
	
	if chunks.has(cp):
		# TỐI ƯU O(1): Xóa vật thể dựa trên Dictionary _chunk_objects thay vì duyệt node
		if _chunk_objects.has(cp):
			for obj in _chunk_objects[cp]:
				if is_instance_valid(obj):
					_lighting_objects.erase(obj)
					_static_objects.erase(obj)
					_active_lighting_objects.erase(obj)
					_spatial_unregister(obj) # VÁ LỖI: Xóa khỏi spatial hash để tránh rò rỉ rác
			_chunk_objects.erase(cp)
		
		# COMPONENT B: Xóa MultiMesh instances của chunk này
		if _tree_renderer != null:
			_tree_renderer.remove_chunk(cp)
		
		chunks[cp].queue_free()
		chunks.erase(cp)
		return 1
	
	return 0

func _add_rotation_test_object(parent_node: Node2D, center: Vector2, b_size: Vector2i, type: String):
	var s2d = _2d_scale_slider.value if _2d_scale_slider else 1.0
	
	# COMPONENT B: MultiMesh Fast Path cho cây thiên nhiên (1 draw call!)
	if _tree_renderer != null and type in MULTIMESH_TREE_TYPES:
		# Tính chunk pos để đăng ký vào renderer (phục vụ remove khi unload)
		var cp_f = _temp_layer.local_to_map(_temp_layer.to_local(center))
		var chunk_pos = Vector2i(floorf(float(cp_f.x) / CHUNK_SIZE), floorf(float(cp_f.y) / CHUNK_SIZE))
		
		# Lấy y_offset từ _tree_defs nếu có
		var y_off = -2373.0
		if _tree_defs.has(type):
			y_off = _tree_defs[type]["offset"].y
		
		_tree_renderer.add_tree(type, center, s2d, y_off, chunk_pos)
		return  # Không tạo Sprite2D nữa — done!
	
	# FALLBACK: Sprite2D path cho công trình (windmill, core, camfire) và unknown types
	# 1. TẠO PIVOT QUẢN LÝ
	var pivot = Node2D.new()
	pivot.name = "Pivot_Building_" + type
	pivot.position = center
	pivot.y_sort_enabled = true
	parent_node.add_child(pivot)
	
	# 2. TẠO SPRITE TÒA NHÀ 2D
	var building = Sprite2D.new()
	building.name = "BuildingSprite"
	
	match type:
		"windmill": building.texture = _windmill_tex
		"camfire": building.texture = _camfire_tex
		"core": building.texture = _core_tex
		_: 
			if _tree_defs.has(type):
				building.texture = _tree_defs[type]["tex"]
			else:
				building.texture = null # Không còn fallback về campfire
		
	if building.texture:
		if type == "mist":
			building.modulate.a = 0.4 # Làm mờ đám mây sương mù
			building.z_index = 5 # Cho sương mù bay lơ lửng trên đầu
		building.scale = Vector2(s2d, s2d)
		
	building.centered = true
	building.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	if type == "camfire":
		var light = PointLight2D.new()
		light.name = "CampfireLight"
		light.color = Color("#ffaa44")
		light.energy = 1.5
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color(1, 1, 1, 1))
		gradient.add_point(1.0, Color(1, 1, 1, 0))
		var g_tex = GradientTexture2D.new()
		g_tex.gradient = gradient
		g_tex.fill = GradientTexture2D.FILL_RADIAL
		g_tex.texture_scale = 10.0
		light.texture = g_tex
		light.shadow_enabled = true
		pivot.add_child(light)
		pivot.set_meta("light_ref", light)

	# 3. VA CHẠM VẬT LÝ (STATICBODY2D)
	# T\u1ed0I \u01afU CRITICAL: Ch\u1ec8 t\u1ea1o Physics cho C\u00d4NG TR\u00ccNH l\u1edbn, kh\u00f4ng cho c\u00e2y t\u1ef1 nhi\u00ean
	if type in PROP_STRUCTURES:
		var body = StaticBody2D.new()
		body.collision_layer = 1 # Để Player va chạm vào
		var col = CollisionShape2D.new()
		var shape = ConvexPolygonShape2D.new()
		var hw_col = 250.0 * b_size.x * 0.8
		var hh_col = 125.0 * b_size.y * 0.8
		shape.points = PackedVector2Array([Vector2(0, -hh_col), Vector2(hw_col, 0), Vector2(0, hh_col), Vector2(-hw_col, 0)])
		col.shape = shape
		body.add_child(col)
		pivot.add_child(body)
		
		# T\u1ea1o LightOccluder2D CH\u1ec8 cho công trình lớn
		var occluder = LightOccluder2D.new()
		occluder.name = "BaseOccluder"
		var occ_poly = OccluderPolygon2D.new()
		var hw_occ = 100.0 * b_size.x
		var hh_occ = 50.0 * b_size.y
		occ_poly.polygon = PackedVector2Array([Vector2(0, -hh_occ), Vector2(hw_occ, 0), Vector2(0, hh_occ), Vector2(-hw_occ, 0)])
		occluder.occluder = occ_poly
		pivot.add_child(occluder)
		
		# T\u1ea1o Line2D outline CH\u1ec8 cho công trình lớn
		var out = Line2D.new()
		out.name = "BuildingOutline"
		out.width = 2.0
		out.default_color = Color(0.4, 0.7, 1.0, 0.6)
		out.z_index = 10
		var hw2 = 250.0 * b_size.x
		var hh2 = 125.0 * b_size.y
		out.points = PackedVector2Array([Vector2(0, -hh2), Vector2(hw2, 0), Vector2(0, hh2), Vector2(-hw2, 0), Vector2(0, -hh2)])
		pivot.add_child(out)

	# T\u1ed0I \u01afU: Bỏ Area2D per-prop. Fade được xử lý bằng distance check trong _process()
	
	if building.texture:
		var h = building.texture.get_height()
		var w = building.texture.get_width()
		var base_offset = Vector2.ZERO
		
		match type:
			"windmill": base_offset = _windmill_offset
			"core": base_offset = _core_offset
			"oak", "pine", "maple", "bamboo", "cactus":
				base_offset = Vector2(0, -2373 * s2d)
			_:
				base_offset = Vector2(0, -2373 * s2d)
			
		var slider_off_x = _2d_x_slider.value if _2d_x_slider else 0.0
		var slider_off_y = _2d_y_slider.value if _2d_y_slider else 0.0
		building.position = Vector2(base_offset.x + slider_off_x, base_offset.y + slider_off_y)
	
	pivot.add_child(building)
	pivot.set_meta("building_ref", building)
	
	# 7. TỐI ƯU HIỆU NĂNG FRAME (VISIBLE NOTIFIER)
	var hw = 250.0 * b_size.x
	var hh = 125.0 * b_size.y
	var notifier = VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-hw, -hh, hw * 2, hh * 2)
	pivot.add_child(notifier)
	
	# Đăng ký vào hệ thống quản lý theo Chunk (Để xóa O(1))
	var cp = _temp_layer.local_to_map(_temp_layer.to_local(center))
	var c_pos = Vector2i(floorf(cp.x / float(CHUNK_SIZE)), floorf(cp.y / float(CHUNK_SIZE)))
	if not _chunk_objects.has(c_pos): _chunk_objects[c_pos] = []
	_chunk_objects[c_pos].append(pivot)

	if type == "camfire":
		_lighting_objects[pivot] = true
		# Tự động bật/tắt flicker dựa trên việc nó có hiện trên màn hình không
		notifier.screen_entered.connect(func(): _active_lighting_objects[pivot] = true)
		notifier.screen_exited.connect(func(): _active_lighting_objects.erase(pivot))
		# Kiểm tra ban đầu
		if notifier.is_on_screen(): _active_lighting_objects[pivot] = true
		_spatial_register(pivot)  # COMPONENT C: Đăng ký vào spatial hash
	else:
		_static_objects[pivot] = true
		_spatial_register(pivot)  # COMPONENT C: Đăng ký vào spatial hash

func _fade_building(node: CanvasItem, target_alpha: float):
	# TỐI ƯU: Không tạo tween nếu độ mờ đã khớp (Tránh Tween Storm)
	if abs(node.modulate.a - target_alpha) < 0.01:
		return
		
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", target_alpha, 0.3).set_trans(Tween.TRANS_SINE)

# --- HỆ THỐNG MENU TẠM DỪNG (PAUSE MENU) ---

func _setup_pause_menu():
	_pause_menu_layer = CanvasLayer.new()
	_pause_menu_layer.layer = 110 # Cao hơn cả Debug UI
	add_child(_pause_menu_layer)
	_pause_menu_layer.visible = false
	
	# 1. HIỆU ỨNG BLUR
	_blur_rect = ColorRect.new()
	_blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/screen_blur.gdshader")
	_blur_rect.material = mat
	_pause_menu_layer.add_child(_blur_rect)
	
	# 2. PANEL CHÍNH
	_pause_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.7)
	style.corner_radius_top_left = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(0.4, 1.0, 0.6, 0.4) # Viền xanh Emerald mờ
	style.set_content_margin_all(40)
	_pause_panel.add_theme_stylebox_override("panel", style)
	
	# Căn giữa màn hình
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause_menu_layer.add_child(_pause_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	_pause_panel.add_child(vbox)
	
	var lbl_title = Label.new()
	lbl_title.text = "GAME ĐÃ TẠM DỪNG"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 32)
	lbl_title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.8))
	vbox.add_child(lbl_title)
	
	vbox.add_child(HSeparator.new())
	
	# NÚT TIẾP TỤC
	var btn_resume = Button.new()
	btn_resume.text = "TIẾP TỤC"
	btn_resume.custom_minimum_size = Vector2(250, 60)
	btn_resume.pressed.connect(func(): _toggle_pause_menu(false))
	vbox.add_child(btn_resume)
	
	# NÚT CÀI ĐẶT
	var btn_settings = Button.new()
	btn_settings.text = "CÀI ĐẶT"
	btn_settings.custom_minimum_size = Vector2(250, 60)
	btn_settings.pressed.connect(func(): 
		_pause_panel.visible = false
		_settings_menu.visible = true
	)
	vbox.add_child(btn_settings)

	# NÚT THOÁT
	var btn_quit = Button.new()
	btn_quit.text = "THOÁT GAME"
	btn_quit.custom_minimum_size = Vector2(250, 60)
	btn_quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(btn_quit)

func _toggle_pause_menu(active: bool):
	if _pause_menu_layer:
		_pause_menu_layer.visible = active
		get_tree().paused = active
		
		if active:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_pause_panel.visible = true # Đảm bảo hiện pause panel
			if _settings_menu: _settings_menu.visible = false # Ẩn settings menu
			_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		else:
			pass

func _setup_settings_menu():
	var settings_scene = load("res://scenes/ui/settings_menu.tscn")
	if settings_scene:
		_settings_menu = settings_scene.instantiate()
		add_child(_settings_menu)
		_settings_menu.visible = false
		_settings_menu.closed.connect(func(): _pause_panel.visible = true)

func _on_settings_updated():
	# Cập nhật Render Distance
	if RENDER_DISTANCE != Config.render_distance:
		RENDER_DISTANCE = Config.render_distance
		update_chunks(true) # Force update ngay lập tức
	
	# Cập nhật Debug UI
	if _ui_layer:
		_ui_layer.visible = Config.show_debug

# --- HỆ THỐNG ĐA LUỒNG (THREADING HELPERS) ---

func _trigger_background_noise(cpos: Vector2i):
	_noise_mutex.lock()
	if _noise_cache.has(cpos) or _pending_noise_chunks.has(cpos):
		_noise_mutex.unlock()
		return
	# T\u1ed0I \u01afU: Gi\u1edbi h\u1ea1n tasks \u0111\u1ed3ng th\u1eddi \u0111\u1ec3 tr\u00e1nh thread bomb khi zoom out xa
	if _pending_noise_chunks.size() >= MAX_CONCURRENT_NOISE_TASKS:
		_noise_mutex.unlock()
		return
	_pending_noise_chunks[cpos] = true
	_noise_mutex.unlock()
	
	# Đẩy công việc vào hàng đợi xử lý của WorkerThreadPool
	if _noise == null or _temp_noise == null or _moisture_noise == null:
		print("[ERROR] Noise objects not initialized in Generator!")
		return
		
	WorkerThreadPool.add_task(_thread_generate_noise.bind(
		cpos, _noise, _forest_noise, _river_noise, _biome_noise, 
		_mist_noise, _river_mask_noise, _temp_noise, _moisture_noise, _scatter_noise, _warp_noise,
		_giant_warp_noise, _archipelago_filter_noise, _fault_noise
	))

func _thread_generate_noise(cpos, terrain_n, forest_n, river_n, biome_n, mist_n, riv_mask_n, temp_n, moist_n, scatter_n, warp_n, giant_n, filter_n, fault_n):
	var s = cpos * CHUNK_SIZE
	var total = CHUNK_SIZE * CHUNK_SIZE
	
	var terrain_data  = PackedFloat32Array(); terrain_data.resize(total)
	var forest_data   = PackedFloat32Array(); forest_data.resize(total)
	var river_data    = PackedFloat32Array(); river_data.resize(total)
	var temp_data     = PackedFloat32Array(); temp_data.resize(total)
	var moist_data    = PackedFloat32Array(); moist_data.resize(total)
	var riv_mask_data = PackedFloat32Array(); riv_mask_data.resize(total)
	var biome_data    = PackedFloat32Array(); biome_data.resize(total)
	var mist_data     = PackedFloat32Array(); mist_data.resize(total)
	var scatter_data  = PackedFloat32Array(); scatter_data.resize(total)
	
	var terrain_sum = 0.0
	var idx = 0
	
	var max_dist = (map_size / 2.0) * continent_radius
	
	# === FAULT CENTERS (seed-based, cố định mỗi world) ===
	# Góc fault dựa trên seed → mỗi world có vị trí vịnh khác nhau
	var seed_f = float(terrain_n.seed)
	var fault_angle_1 = fmod(seed_f * 0.618033, TAU)
	# Fault 2 nằm lệch ~150°-210° so với fault 1 (không đối diện hoàn toàn, tự nhiên hơn)
	var fault_angle_2 = fault_angle_1 + PI + (fmod(seed_f * 0.333, 0.6) - 0.3)
	# Fault nằm ở vùng bờ biển: 60%~85% max_dist từ tâm
	var fault_r1 = max_dist * (0.60 + fmod(seed_f * 0.271, 0.25))
	var fault_r2 = max_dist * (0.60 + fmod(seed_f * 0.137, 0.25))
	var fault_center_1 = Vector2(cos(fault_angle_1), sin(fault_angle_1)) * fault_r1
	var fault_center_2 = Vector2(cos(fault_angle_2), sin(fault_angle_2)) * fault_r2
	
	# === ĐẢO ĐỊA CHẤT: 2 đảo lớn (10~15% diện tích lục địa) ===
	# Đảo nằm ngoài khơi, cách bờ một khoảng, không quá gần nhau
	# Island 1: cùng hướng với fault_1 nhưng xa hơn (ngoài khơi)
	var isl_angle_1 = fault_angle_1 + (fmod(seed_f * 0.159, 0.5) - 0.25) # Lệch nhẹ so với fault
	var isl_dist_1  = max_dist * (0.95 + fmod(seed_f * 0.113, 0.20))      # 95%~115% max_dist
	var isl_center_1 = Vector2(cos(isl_angle_1), sin(isl_angle_1)) * isl_dist_1
	var isl_radius_1 = max_dist * 0.22  # Bán kính đảo ~22% max_dist → đảo to
	
	# Island 2: gần fault_2 nhưng cách bờ xa hơn
	var isl_angle_2 = fault_angle_2 + (fmod(seed_f * 0.271, 0.5) - 0.25)
	var isl_dist_2  = max_dist * (0.95 + fmod(seed_f * 0.229, 0.20))
	var isl_center_2 = Vector2(cos(isl_angle_2), sin(isl_angle_2)) * isl_dist_2
	var isl_radius_2 = max_dist * 0.20  # Đảo 2 hơi nhỏ hơn đảo 1
	
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var gx = s.x + lx
			var gy = s.y + ly
			var gpos_f = Vector2(gx, gy)
			var raw_dist = gpos_f.length()
			
			# === CONTINENTAL MASK V16 ===
			var giant_val = giant_n.get_noise_2d(gx, gy)
			
			# [NEW] North-West to North-East Bulge & Solidifier
			var angle = atan2(gy, gx)
			
			# === DIRECTIONAL BIOME BIAS (V22: Early Declaration) ===
			var se_target = PI/4.0   
			var nw_target = -3.0*PI/4.0
			var sw_target = 3.0*PI/4.0
			
			var se_diff = abs(angle - se_target)
			if se_diff > PI: se_diff = TAU - se_diff
			var se_bias_f = smoothstep(PI/2.5, 0.0, se_diff)
			
			var nw_diff = abs(angle - nw_target)
			if nw_diff > PI: nw_diff = TAU - nw_diff
			var nw_bias_f = smoothstep(PI/2.5, 0.0, nw_diff)
			
			var sw_diff = abs(angle - sw_target)
			if sw_diff > PI: sw_diff = TAU - sw_diff
			var sw_bias_f = smoothstep(PI/2.0, 0.0, sw_diff)
			
			# Hướng Tây (phá vỡ hình tròn)
			var w_target = PI if angle > 0 else -PI
			var w_diff = abs(angle - w_target)
			var west_factor = smoothstep(PI/2.0, 0.0, w_diff) 
			
			# Hướng Đông (làm đặc vùng nát)
			var e_target = 0.0
			var e_diff = abs(angle - e_target)
			var east_factor = smoothstep(PI/2.5, 0.0, e_diff)
			
			# ne_factor tập trung vào hướng nhô ra Đông Bắc
			var ne_target = -PI/4.0
			var ne_diff = abs(angle - ne_target)
			if ne_diff > PI: ne_diff = TAU - ne_diff
			var ne_factor = smoothstep(PI/2.5, 0.0, ne_diff) 
			
			# north_factor (Nhấp nhô macro phía Bắc)
			var n_target = -PI/2.0
			var n_diff = abs(angle - n_target)
			if n_diff > PI: n_diff = TAU - n_diff
			var is_north = smoothstep(PI/1.5, 0.0, n_diff) 
			
			# Nhô ra Đông Bắc (30%) & Đông/Đông Nam
			var ne_bulge = 1.0 + (ne_factor * 0.3)
			var se_bulge = 1.0 + (se_bias_f * 0.35) 
			var east_bulge = 1.0 + (east_factor * 0.2) 
			
			# [V22] Tinh chỉnh hệ số thu nhỏ, cho phép hướng NE gồ ghề hơn
			var local_max_dist = max_dist * ne_bulge * se_bulge * east_bulge * 0.86

			# Warp biên độ: Phá vỡ sự mượt mà trên toàn bộ chu vi lục địa
			# [V23] Tăng cường warp cho các hướng SE và E để không bị tròn quá mức
			var warp_mult = 1.0 + (west_factor * 0.5) + (nw_bias_f * 0.45) + (ne_factor * 0.4) + (se_bias_f * 0.35) - (east_factor * 0.05)
			var wx = warp_n.get_noise_2d(gx, gy) * 240.0 * warp_mult
			var wy = warp_n.get_noise_2d(gy + 500, gx + 500) * 240.0 * warp_mult
			var warped_pos = Vector2(gx + wx, gy + wy)
			
			# Nhấp nhô macro (thụt xuống nhô lên) - Phá vỡ hình tròn toàn diện 360 độ
			var macro_warp_w = warp_n.get_noise_2d(gx * 0.002, gy * 0.002) * 125.0 * west_factor
			var macro_warp_nw = warp_n.get_noise_2d(gx * 0.003, gy * 0.003) * 130.0 * nw_bias_f
			var macro_warp_ne = warp_n.get_noise_2d(gx * 0.0035, gy * 0.0035 + 100) * 140.0 * ne_factor
			var macro_warp_se = warp_n.get_noise_2d(gx * 0.004, gy * 0.004 + 200) * 135.0 * se_bias_f # Phá tròn SE
			var macro_bump = warp_n.get_noise_2d(gx * 0.005, gy * 0.005) * 45.0 * is_north
			
			# Thêm một chút nhiễu nền toàn cục để không hướng nào bị "tròn hoàn hảo"
			var global_annoyance = warp_n.get_noise_2d(gx * 0.001, gy * 0.001) * 60.0 
			
			var radius_distort = 1.0 + (giant_val * (1.2 - east_factor * 0.35))
			var dist = (warped_pos.length() + macro_bump + macro_warp_w + macro_warp_nw + macro_warp_ne + macro_warp_se + global_annoyance) * radius_distort
			dist += warp_n.get_noise_2d(gx * 2.5, gy * 2.5) * 16.0 * warp_mult
			
			var falloff = 1.0
			if dist > local_max_dist * 0.55:
				falloff = smoothstep(local_max_dist, local_max_dist * 0.55, dist)
			
			# === PHÁ VỠ SỰ TRÒN TRỊA (IRREGULAR BORDER) ===
			var border_warp = warp_n.get_noise_2d(gx * 0.003, gy * 0.003) * local_max_dist * (0.12 + west_factor * 0.08)
			var border_warp2 = giant_n.get_noise_2d(gx * 0.0015, gy * 0.0015) * local_max_dist * 0.08
			var warped_raw_dist = raw_dist + border_warp + border_warp2
			
			var absolute_cutoff = smoothstep(local_max_dist * 1.15, local_max_dist * 0.80, warped_raw_dist)
			var base_mask = falloff * absolute_cutoff
			
			# === FAULT SYSTEM V2 (Vình tự nhiên, không xé nát) ===
			var shore_factor = smoothstep(0.0, 0.35, base_mask) * smoothstep(0.85, 0.45, base_mask)
			shore_factor *= (1.0 - ne_factor * 0.8) 
			shore_factor *= (1.0 - east_factor * 0.6) 
			shore_factor *= (1.0 - sw_bias_f * 0.4) # [V21] Giảm vỡ nát ở phía Tây Nam
			
			var d1 = gpos_f.distance_to(fault_center_1)
			# Fault width được điều chỉnh bằng noise để có hình dạng tự nhiên
			var fault_noise_1 = fault_n.get_noise_2d(gx * 0.004, gy * 0.004) * 0.4 + 1.0
			var fault_width_1 = local_max_dist * 0.18 * fault_noise_1  # ~18% max_dist
			var fault_cut_1 = smoothstep(fault_width_1, fault_width_1 * 0.1, d1) * 0.70 * shore_factor
			
			var d2 = gpos_f.distance_to(fault_center_2)
			var fault_noise_2 = fault_n.get_noise_2d(gx * 0.004 + 333, gy * 0.004 + 333) * 0.4 + 1.0
			var fault_width_2 = local_max_dist * 0.16 * fault_noise_2
			var fault_cut_2 = smoothstep(fault_width_2, fault_width_2 * 0.1, d2) * 0.65 * shore_factor
			
			var combined_fault_cut = maxf(fault_cut_1, fault_cut_2)
			
			# === TERRAIN HEIGHT ===
			var nv = terrain_n.get_noise_2d(gx, gy)
			nv = (nv + 0.40) * base_mask - 0.95 * (1.0 - base_mask)
			# Fault khoét vào địa hình (chỉ ở vùng bờ)
			nv -= combined_fault_cut
			
			# === FIX HỒ NỘI ĐỊA ===
			# Chỉ áp dụng khi base_mask mạnh VÀ không phải vùng fault
			if base_mask > 0.65 and nv < -0.32 and combined_fault_cut < 0.2:
				var inland_lift = (base_mask - 0.65) * 2.0
				nv = nv + inland_lift
				if nv < -0.31: nv = -0.31
			
			# === ĐẢO ĐỊA CHẤT (TECTONIC ISLANDS) ===
			# [V18] Đã loại bỏ hoàn toàn các hòn đảo lớn xung quanh lục địa.
			# [V21] Thêm các hòn đảo siêu nhỏ rải rác xung quanh TOÀN BỘ lục địa
			var isl_contrib = 0.0
			if base_mask < 0.08: # Áp dụng cho mọi hướng trên biển gần bờ
				var tiny_isl_noise = (filter_n.get_noise_2d(gx * 0.02, gy * 0.02) + 1.0) * 0.5
				if tiny_isl_noise > 0.988: # Tăng độ hiếm để đảo không quá dày
					var tiny_h = (tiny_isl_noise - 0.988) / 0.012
					isl_contrib = maxf(isl_contrib, tiny_h * 0.75)
			
			if isl_contrib > 0.0:
				nv = nv + isl_contrib * 0.9
			
			
			terrain_data[idx] = nv
			terrain_sum += nv
			
			# === BIOME JITTERING ===
			var jitter_val = warp_n.get_noise_2d(gx * 4.0, gy * 4.0) * 0.25
			
			# === LATITUDE BIAS (Địa lý thực tế) ===
			var norm_lat = clamp(gy / max_dist, -1.0, 1.0)
			var polar_factor = smoothstep(0.5, 1.0, abs(norm_lat))
			var latitude_temp_bonus = -(polar_factor * polar_factor) * 0.3 + 0.08
			
			# Áp dụng Bias Nhiệt độ & Độ ẩm
			var t_raw = temp_n.get_noise_2d(gx, gy) + latitude_temp_bonus + jitter_val
			t_raw += se_bias_f * 0.6  # [V21] Nóng lên SE (Giảm nhẹ cường độ)
			t_raw -= nw_bias_f * 0.65  # Lạnh đi NW
			t_raw -= sw_bias_f * 0.15  # Tây Nam ôn hòa (hơi mát một chút)
			
			var m_raw = moist_n.get_noise_2d(gx, gy) + (jitter_val * -0.6)
			m_raw += sw_bias_f * 0.45  # Tây Nam ẩm hơn (nhiều rừng/sông)
			m_raw -= (se_bias_f * 0.2) * (1.0 - m_raw) # SE khô hơn nếu đang nóng
			
			# Rain shadow gần fault
			var rain_shadow = clamp(combined_fault_cut * 0.35, 0.0, 0.35)
			m_raw -= rain_shadow
			
			temp_data[idx]  = t_raw
			moist_data[idx] = m_raw
			
			# === SÔNG CÓ HƯỚNG ===
			forest_data[idx]   = forest_n.get_noise_2d(gx, gy)
			riv_mask_data[idx] = riv_mask_n.get_noise_2d(gx, gy)
			
			var h_right_r = terrain_n.get_noise_2d(gx + 3.0, gy)
			var h_down_r  = terrain_n.get_noise_2d(gx, gy + 3.0)
			var grad_x = h_right_r - nv
			var grad_y = h_down_r  - nv
			var flow_proj = river_n.get_noise_2d(gx + grad_x * 120.0, gy + grad_y * 120.0)
			
			var is_river_zone = nv > -0.1 and nv < 0.45
			
			# Lọc sông theo khí hậu (Nóng/Lạnh cực đoan chỉ giữ 2-5 con sông lớn)
			var t_bias_abs = abs(t_raw)
			var climate_filter = smoothstep(0.4, 0.9, t_bias_abs) # 0.0 (ôn hòa) -> 1.0 (khắc nghiệt)
			
			# Tăng mật độ sông ở Tây Nam (nhưng hạn chế hơn trước)
			var river_boost = sw_bias_f * 0.45 
			
			# Ngưỡng sinh sông: Khắc nghiệt thì ngưỡng cực cao (khó sinh sông), Ôn hòa thì bình thường
			var river_difficulty = 1.0 + (climate_filter * 8.0) 
			var main_river_threshold = (0.038 + river_boost * 0.015) / river_difficulty * clamp(m_raw + 0.8, 0.3, 1.5)
			var branch_river_threshold = (0.012 + river_boost * 0.008) / (river_difficulty * 1.5) * clamp(m_raw + 0.5, 0.1, 1.0)
			
			var river_val = 1.0
			if is_river_zone:
				if abs(flow_proj) < main_river_threshold:
					river_val = 0.0
				elif abs(river_n.get_noise_2d(gx, gy)) < branch_river_threshold:
					river_val = 0.5
			
			river_data[idx] = river_val
			
			biome_data[idx]   = (biome_n.get_noise_2d(gx, gy) + 1.0) / 2.0 # Chuẩn hóa [0, 1] cho đồng bộ
			mist_data[idx]    = mist_n.get_noise_2d(gx, gy)
			scatter_data[idx] = scatter_n.get_noise_2d(gx, gy)
			idx += 1
	
	var avg_terrain = terrain_sum / total
	
	# Ghi dữ liệu vào Cache an toàn
	_noise_mutex.lock()
	_noise_cache[cpos] = {
		"terrain": terrain_data,
		"forest":  forest_data,
		"river":   river_data,
		"riv_mask":riv_mask_data,
		"temp":    temp_data,
		"moisture":moist_data,
		"biome":   biome_data,
		"mist":    mist_data,
		"scatter": scatter_data
	}
	_pending_noise_chunks.erase(cpos)
	_noise_mutex.unlock()
	
	if avg_terrain == 0.0:
		print("[WARNING-THREAD] Chunk ", cpos, " generated with all 0.0 terrain noise!")
	else:
		# print("[DEBUG-THREAD] Chunk ", cpos, " cached. Avg Terrain: ", avg_terrain)
		pass
func _load_offset_from_json(path: String, texture: Texture2D, current_offset: Vector2) -> Vector2:
	if not FileAccess.file_exists(path): return current_offset
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return current_offset
	var json = JSON.parse_string(file.get_as_text())
	if not json: return current_offset
	
	if json.has("visual_offset"):
		var vo = json["visual_offset"]
		return Vector2(vo[0], vo[1])
	elif json.has("texture_origin") and texture:
		var origin = json["texture_origin"]
		var size = texture.get_size()
		# Công thức: Offset = (Center) - Origin
		var cal_offset = (size / 2.0) - Vector2(origin[0], origin[1])
		print("[INFO] Building Info Loaded: ", path.get_file(), " | Calculated Offset: ", cal_offset)
		return cal_offset
	return current_offset

func _toggle_world_map(active: bool):
	if _world_map_instance:
		_world_map_instance.visible = active
		get_tree().paused = active
		
		if active:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			var cp = camera.global_position if camera else Vector2.ZERO
			# Chuyển đổi tọa độ thế giới sang tọa độ ô (Tile) để Map dễ xử lý
			var tp = _temp_layer.local_to_map(_temp_layer.to_local(cp))
			
			var map_root = _world_map_instance.get_node("Root")
			map_root.view_center = Vector2(tp.x, tp.y)
			map_root.view_zoom = 1.0 # Reset zoom khi mở
			map_root.set_player_pos(Vector2(tp.x, tp.y)) # Cập nhật chấm đỏ
			
			# Gán player để map tự cập nhật real-time
			map_root.player_node = camera # Camera thường đi kèm với nhân vật
			
			map_root.setup(_noise, _forest_noise, _river_noise, _temp_noise, _moisture_noise, _biome_noise, _scatter_noise, _warp_noise, _giant_warp_noise, _archipelago_filter_noise, _fault_noise, map_size, continent_radius)
		else:
			# Có thể thêm logic ẩn cursor nếu cần
			pass

func _on_map_teleport_requested(target_tile_pos: Vector2, expected_biome: String):
	print("[SYSTEM-DEBUG] Received teleport_requested signal in Generator!")
	_expected_biome_after_teleport = expected_biome
	var player = get_tree().get_first_node_in_group("player")
	var target_node = player if player else camera
	
	print("[DEBUG-TP] Tile Clicked: ", target_tile_pos)
	
	if !target_node: 
		print("[MAP] Lỗi: Không tìm thấy Player hoặc Camera để dịch chuyển!")
		return
	
	# 1. Chuyển đổi tọa độ Tile sang tọa độ World (Pixel) chính xác (Hỗ trợ 500x250 Isometric)
	var world_pos = _temp_layer.map_to_local(Vector2i(target_tile_pos))
	print("[DEBUG-TP] Target World Pos: ", world_pos)
	print("[DEBUG-TP] Moving node: ", target_node.name)
	
	# 2. Di chuyển Player/Camera và ép đồng bộ Transform
	target_node.global_position = world_pos
	if target_node is CharacterBody2D:
		target_node.force_update_transform()
	
	# Cập nhật camera ngay lập tức
	if camera and is_instance_valid(camera):
		camera.global_position = world_pos
		camera.force_update_scroll()
		camera.reset_smoothing() # Nếu có smoothing, reset để tránh trượt
		print("[DEBUG-TP] Camera forced update to: ", camera.global_position)
	
	# 3. Kích hoạt chẩn đoán gạch thực tế tại điểm đến
	_pending_teleport_tile = target_tile_pos
	
	# 4. Ép cập nhật lại toàn bộ Chunk xung quanh vị trí mới
	call_deferred("update_chunks", true) 
	
	# 5. Đóng bản đồ và tiếp tục game
	_toggle_world_map(false)
	print("[MAP] Dịch chuyển THÀNH CÔNG tới: ", world_pos)

# --- COMPONENT C: SPATIAL HASH HELPERS ---

func _spatial_register(node: Node2D):
	var cell = Vector2i(node.global_position / SPATIAL_CELL)
	if not _spatial_hash.has(cell):
		_spatial_hash[cell] = []
	_spatial_hash[cell].append(node)

func _spatial_unregister(node: Node2D):
	var cell = Vector2i(node.global_position / SPATIAL_CELL)
	var arr = _spatial_hash.get(cell)
	if arr:
		arr.erase(node)
		if arr.is_empty():
			_spatial_hash.erase(cell)

## Query tất cả objects trong bán kính radius quanh pos — O(cells_checked) không phải O(N)
func _spatial_query(pos: Vector2, radius: float) -> Array:
	var center_cell = Vector2i(pos / SPATIAL_CELL)
	var cells_r = ceili(radius / SPATIAL_CELL)
	var result = []
	for dx in range(-cells_r, cells_r + 1):
		for dy in range(-cells_r, cells_r + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var arr = _spatial_hash.get(cell)
			if arr:
				result.append_array(arr)
	return result
