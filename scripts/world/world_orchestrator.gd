# scripts/world/world_orchestrator.gd
# V2.0 Modular — Hệ thống chính điều phối việc tạo thế giới và quản lý các Module con
extends Node2D

class_name WorldOrchestrator

const CHUNK_SIZE = 16
var RENDER_DISTANCE = 3

@export var tileset: TileSet
@export var map_size: int = 1024 # Diameter (Full extent -X to +X is world_radius*2)
@export var force_block_id: int = -1
@export var spawn_building_type: String = ""
@export var override_biome_map: String = ""

# ═══════════════════════════════════════════════════════════════
# MODULES
# ═══════════════════════════════════════════════════════════════
var gen_worker: Node
var building_sys: Node2D
var ui_manager: Node

# ═══════════════════════════════════════════════════════════════
# WORLD STATE
# ═══════════════════════════════════════════════════════════════
var shape_engine: WorldShapeEngine = null
var active_biomes_snapshot: Array = []
var active_continent_type: String = "pangaea"
var world_seed: int = 0

var detail_noise: FastNoiseLite
var forest_noise: FastNoiseLite
var river_noise: FastNoiseLite
var river_mask_noise: FastNoiseLite
var scatter_noise: FastNoiseLite
var warp_noise: FastNoiseLite
var mist_noise: FastNoiseLite

var chunks: Dictionary = {}
var camera: Camera2D
var player: Node2D
var temp_layer: TileMapLayer

# ═══════════════════════════════════════════════════════════════
# ASSETS & DEFINITIONS
# ═══════════════════════════════════════════════════════════════
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
var _stone_ore_tex = preload("res://assets/props/minerals/stone_ore/stone_ore_1.png")
var _tin_ore_tex = preload("res://assets/props/minerals/tin_ore/tin_ore_1.png")
var _gold_ore_tex = preload("res://assets/props/minerals/gold_ore/gold_ore_1.png")
var _copper_ore_tex = preload("res://assets/props/minerals/copper_ore/copper_ore_1.png")
var _silver_ore_tex = preload("res://assets/props/minerals/sliver_ore/sliver_ore_1.png")

var _tree_defs = {
	"oak": {"tex": null, "scale": 1.0, "offset": Vector2(0, -400)},
	"maple": {"tex": null, "scale": 1.1, "offset": Vector2(0, -420)},
	"coffee": {"tex": null, "scale": 0.9, "offset": Vector2(0, -200)},
	"cotton": {"tex": null, "scale": 0.8, "offset": Vector2(0, -150)},
	"bamboo": {"tex": null, "scale": 0.8, "offset": Vector2(0, -200)},
	"cactus": {"tex": null, "scale": 0.8, "offset": Vector2(0, -200)},
	"winter_pine": {"tex": null, "scale": 1.2, "offset": Vector2(0, -420)},
	"stone_ore": {"tex": null, "scale": 0.6, "offset": Vector2(0, -50)},
	"tin_ore": {"tex": null, "scale": 0.6, "offset": Vector2(0, -50)},
	"gold_ore": {"tex": null, "scale": 0.6, "offset": Vector2(0, -50)},
	"copper_ore": {"tex": null, "scale": 0.5, "offset": Vector2(0, -50)},
	"silver_ore": {"tex": null, "scale": 0.6, "offset": Vector2(0, -50)}
}

const FLUID_TILE_IDS: Array = [3, 13, 14, 15, 16, 21, 26]
const SOLID_TILE_IDS: Array = [4, 7, 27]
const MULTIMESH_TREE_TYPES: Array = ["oak", "maple", "bamboo", "cactus", "coffee", "cotton", "winter_pine"]

# Internal Vars for Balancing
var _generation_queue: Array[Vector2i] = []
var _generation_set: Dictionary = {}
var _removal_queue: Array[Vector2i] = []
var _removal_set: Dictionary = {}
var _pending_props: Array = []
var _spatial_hash: Dictionary = {}
var _static_objects: Dictionary = {}
var _lighting_objects: Dictionary = {}
var _chunk_objects: Dictionary = {}

var _current_gen_chunk: Vector2i = Vector2i(-999, -999)
var _current_tile_idx: int = 0
var _genesis_timer: float = 3.0
var _last_cam_update_pos: Vector2 = Vector2(-9999, -9999)
var _chunk_update_timer: float = 0.0
var _ui_update_timer: float = 0.0

# Profiling
var _t_noise: int = 0; var _t_tiles: int = 0; var _t_objects: int = 0; var _t_physics: int = 0

const _CHUNK_SCRIPT = preload("res://scripts/world/chunk.gd")
const _MULTIMESH_SCRIPT = preload("res://scripts/core/multi_mesh_tree_renderer.gd")
var _tree_renderer: Node2D = null

# ═══════════════════════════════════════════════════════════════
# INIT & READY
# ═══════════════════════════════════════════════════════════════

func _ready():
	# randomize() # Đã tắt để giữ hình dạng thế giới cố định (Hardcore)
	process_mode = Node.PROCESS_MODE_ALWAYS
	world_seed = 12345 # Con số cố định để thế giới không bị thay đổi mỗi lần chạy
	
	# 2. Setup Camera & Player
	# Tìm player qua group "player" vì player có thể ở bất kỳ đâu trong scene tree
	player = get_tree().get_first_node_in_group("player")
	camera = get_viewport().get_camera_2d()
	
	if !player:
		player = get_parent().find_child("Player", true, false)
	
	if player and !camera:
		camera = player.get_node_or_null("Camera2D")
	
	self.y_sort_enabled = true

	# 1. Noise setup
	_setup_noises()

	# 2. Shape Engine
	active_continent_type = _pick_continent_type(world_seed)
	
	var blueprint = WorldBlueprint
	var template = blueprint.CONTINENT_TEMPLATES.get(active_continent_type, blueprint.CONTINENT_TEMPLATES["pangaea"])
	var mask_img: Image = null
	
	# Ưu tiên load mask nếu template yêu cầu hoặc có đường dẫn hợp lệ
	var should_use_mask = template.get("use_mask", false) or template.has("mask_path")
	
	var biome_mask_img: Image = null
	if override_biome_map.ends_with(".entmap"):
		var map_data = _load_entmap_data(override_biome_map)
		mask_img = map_data.get("image")
		active_biomes_snapshot = map_data.get("snapshot", [])
		biome_mask_img = mask_img
		printerr("[DEBUG-ORCHESTRATOR] Loaded .entmap: ", override_biome_map, " | Snapshot count: ", active_biomes_snapshot.size())
		print("[ORCHESTRATOR] SUCCESS: Land & Biome mask nạp từ .entmap -> ", override_biome_map)
	elif should_use_mask:
		var path = template.get("mask_path", "res://assets/world/continent_mask.png")
		if ResourceLoader.exists(path):
			mask_img = load(path).get_image()
			print("[ORCHESTRATOR] SUCCESS: Mask loaded from -> ", path)
	
	# Fallback Biome Mask if not set from entmap
	if !biome_mask_img:
		var biome_path = "res://assets/world/custom_biomes.png"
		if ResourceLoader.exists(biome_path):
			biome_mask_img = load(biome_path).get_image()

	shape_engine = WorldShapeEngine.new()
	# map_size is Diameter, so Radius = map_size / 2.0
	shape_engine.setup(world_seed, active_continent_type, float(map_size) / 2.0, warp_noise, detail_noise, mask_img, biome_mask_img, active_biomes_snapshot)

	# 3. Layer setup
	temp_layer = TileMapLayer.new()
	temp_layer.tile_set = tileset
	add_child(temp_layer); temp_layer.visible = false

	# 4. MultiMesh setup
	_setup_tree_renderer()

	# 5. MODULES CORE
	_init_modules()

	# 6. Start World Generation
	update_chunks(true)
	
	# 7. Spawn Initial Building if set
	if spawn_building_type != "" and building_sys:
		var spawn_pos = Vector2i(0, 0)
		if not building_sys.building_roots.has(spawn_pos):
			var b_size = Vector2i(1, 1) # Default size for core
			building_sys.building_roots[spawn_pos] = {"type": spawn_building_type, "size": b_size}
			var footprint = building_sys.generate_footprint(spawn_pos, b_size.x, b_size.y)
			for t in footprint:
				building_sys.occupied_tiles[t] = true
			print("[ORCHESTRATOR] Initial building spawned: ", spawn_building_type, " at ", spawn_pos)

func _init_modules():
	# Generation Worker
	gen_worker = load("res://scripts/world/generation_worker.gd").new()
	add_child(gen_worker)
	gen_worker.setup(shape_engine, map_size / 2, detail_noise, forest_noise, river_noise, river_mask_noise, scatter_noise)

	# Building System
	building_sys = load("res://scripts/world/building_system.gd").new()
	add_child(building_sys)
	building_sys.setup(temp_layer, camera, _windmill_tex, _camfire_tex, _core_tex)

	# UI Manager
	ui_manager = load("res://scripts/ui/debug_ui_manager.gd").new()
	add_child(ui_manager)
	ui_manager.setup(self)

func _setup_noises():
	# Tăng octaves detail_noise để địa hình phong phú hơn
	detail_noise = _make_noise(world_seed, FastNoiseLite.TYPE_PERLIN, 0.00012, 6)
	forest_noise = _make_noise(world_seed + 1000, FastNoiseLite.TYPE_CELLULAR, 0.04, 1)
	forest_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	river_noise = _make_noise(world_seed + 1234, FastNoiseLite.TYPE_PERLIN, 0.004, 5)
	river_mask_noise = _make_noise(world_seed + 9991, FastNoiseLite.TYPE_PERLIN, 0.0004, 2)
	scatter_noise = _make_noise(world_seed + 8000, FastNoiseLite.TYPE_PERLIN, 0.3, 1)
	# Tăng frequency warp để bờ biển gập ghềnh hơn
	warp_noise = _make_noise(world_seed + 9999, FastNoiseLite.TYPE_PERLIN, 0.006, 4)
	mist_noise = _make_noise(world_seed + 6000, FastNoiseLite.TYPE_PERLIN, 0.02, 1)

func _setup_tree_renderer():
	_tree_defs["oak"]["tex"] = _oak_tree_tex; _tree_defs["maple"]["tex"] = _maple_tree_tex
	_tree_defs["coffee"]["tex"] = _coffee_tree_tex; _tree_defs["cotton"]["tex"] = _cotton_tree_tex
	_tree_defs["bamboo"]["tex"] = _bamboo_tex; _tree_defs["cactus"]["tex"] = _cactus_tex
	_tree_defs["winter_pine"]["tex"] = _winter_pine_tex; _tree_defs["stone_ore"]["tex"] = _stone_ore_tex
	_tree_defs["tin_ore"]["tex"] = _tin_ore_tex; _tree_defs["gold_ore"]["tex"] = _gold_ore_tex
	_tree_defs["copper_ore"]["tex"] = _copper_ore_tex; _tree_defs["silver_ore"]["tex"] = _silver_ore_tex
	
	var texture_map: Dictionary = {}
	for tree_type in MULTIMESH_TREE_TYPES:
		if _tree_defs.has(tree_type) and _tree_defs[tree_type]["tex"] != null:
			texture_map[tree_type] = _tree_defs[tree_type]["tex"]

	if not texture_map.is_empty():
		_tree_renderer = _MULTIMESH_SCRIPT.new()
		add_child(_tree_renderer); _tree_renderer.setup(texture_map)

# ═══════════════════════════════════════════════════════════════
# PROCESS LOOP
# ═══════════════════════════════════════════════════════════════

func _process(delta):
	# 1. Update Modules
	if building_sys and building_sys.selected_building != "":
		building_sys.update_ghost(get_global_mouse_position(), ui_manager.scale_slider.value, ui_manager.x_slider.value, ui_manager.y_slider.value)
	
	_ui_update_timer += delta
	if _ui_update_timer >= 0.2:
		var current_fps = Engine.get_frames_per_second()
		if ui_manager:
			ui_manager.update_debug_labels(current_fps, _t_noise, _t_tiles, _t_objects, _t_physics, _static_objects.size(), _lighting_objects.size(), _generation_queue.size(), _removal_queue.size())
		_ui_update_timer = 0.0
		_t_noise = 0; _t_tiles = 0; _t_objects = 0; _t_physics = 0

	# 2. Chunk Lifecycle
	if _genesis_timer > 0: _genesis_timer -= delta
	_chunk_update_timer += delta
	if _chunk_update_timer >= 0.15:
		update_chunks(); _chunk_update_timer = 0.0

	_process_generation_queue(2500 if _genesis_timer > 0 else 1500)
	_process_removal_queue()

	# 3. Object Updates
	# (Lighting effects removed)



# ═══════════════════════════════════════════════════════════════
# GENERATION CORE
# ═══════════════════════════════════════════════════════════════

func update_chunks(force: bool = false):
	if not camera: return
	var cp = camera.global_position
	if not force and cp.distance_to(_last_cam_update_pos) < 256.0: return
	_last_cam_update_pos = cp
	
	var tp = local_to_cartesian_idx(cp)
	var cur_c = Vector2i(floorf(tp.x / 16.0), floorf(tp.y / 16.0))
	var zoom_factor = 1.0 / camera.zoom.x
	var dist = clampi(ceili(RENDER_DISTANCE * zoom_factor), RENDER_DISTANCE, 10)
	
	for r in range(dist + 1):
		for dx in range(-r, r + 1):
			_check_and_add_chunk(cur_c + Vector2i(dx, r))
			if r > 0: _check_and_add_chunk(cur_c + Vector2i(dx, -r))
		for dy in range(-r + 1, r):
			_check_and_add_chunk(cur_c + Vector2i(r, dy))
			_check_and_add_chunk(cur_c + Vector2i(-r, dy))
	
	# Removal
	var rem_dist = dist + 2
	for key in chunks.keys():
		if abs(key.x - cur_c.x) > rem_dist or abs(key.y - cur_c.y) > rem_dist:
			if not _removal_set.has(key): _removal_queue.push_back(key); _removal_set[key] = true

func _check_and_add_chunk(cp: Vector2i):
	if _removal_set.has(cp): _removal_set.erase(cp); return
	if not chunks.has(cp) and not _generation_set.has(cp):
		var limit = floorf(map_size / 32.0)
		if abs(cp.x) > limit or abs(cp.y) > limit: return
		_generation_queue.push_back(cp); _generation_set[cp] = true
		gen_worker.trigger_task(cp)

const BIOME_NAMES_LIST = ["deep_sea", "beach", "plains", "forest", "jungle", "desert", "tundra", "taiga", "savannah", "volcano", "bamboo", "salt_desert", "coal"]

func _process_generation_queue(budget: int) -> int:
	var start_t = Time.get_ticks_usec()
	var tiles_done = 0
	
	while not _generation_queue.is_empty() or _current_gen_chunk != Vector2i(-999,-999):
		if Time.get_ticks_usec() - start_t > budget: return tiles_done
		
		if _current_gen_chunk == Vector2i(-999,-999):
			_current_gen_chunk = _generation_queue.pop_front()
			_generation_set.erase(_current_gen_chunk)
			_current_tile_idx = 0
			
		var cached = gen_worker.get_cached_data(_current_gen_chunk)
		if not cached:
			gen_worker.trigger_task(_current_gen_chunk)
			_generation_queue.push_back(_current_gen_chunk)
			_current_gen_chunk = Vector2i(-999,-999); continue

		if not chunks.has(_current_gen_chunk): _create_chunk_node(_current_gen_chunk)
		var node = chunks[_current_gen_chunk]
		var layer = node.height_layers[0]
		var fluid_l = node.fluid_layer
		var prop_l = node.prop_layer
		var start_tile = _current_gen_chunk * 16
		
		# Inner loop for tiles
		while _current_tile_idx < 256:
			if tiles_done >= 24: return tiles_done
			
			var lx = _current_tile_idx % 16; var ly = _current_tile_idx / 16
			var gpos = start_tile + Vector2i(lx, ly)
			
			var land = cached["land"][_current_tile_idx]
			var biome_idx = cached["biome"][_current_tile_idx]
			var river = cached["river"][_current_tile_idx]
			var scatter = cached["scatter"][_current_tile_idx]
			var forest = cached["forest"][_current_tile_idx]
			var b_name = BIOME_NAMES_LIST[biome_idx]
			var sid = _biome_to_tile_id(b_name, land, river, scatter)
			var is_fluid = FLUID_TILE_IDS.has(sid)
			var target_layer = fluid_l if is_fluid else layer
			var other_layer = layer if is_fluid else fluid_l
			var alt = 1 if is_fluid else 0

			
			# Ensure no overlap
			other_layer.set_cell(gpos, -1)
			target_layer.set_cell(gpos, sid, Vector2i(0, 0), alt)
			
			# Props
			var prop_id = _biome_to_prop(b_name, forest, scatter)
			if prop_id >= 17 and prop_id <= 26: # Trees mapping
				var tree_type = ["maple","oak","bamboo","cactus","","","coffee","cotton","","winter_pine"][prop_id - 17]
				if tree_type != "":
					_add_rotation_test_object(node, layer.map_to_local(gpos), Vector2i(1,1), tree_type)
			elif prop_id >= 0:
				prop_l.set_cell(gpos, prop_id, Vector2i(0, 0))

			# Buildings from building_sys
			if building_sys.building_roots.has(gpos):
				var b_data = building_sys.building_roots[gpos]
				var fp = building_sys.generate_footprint(gpos, b_data["size"].x, b_data["size"].y)
				_add_rotation_test_object(node, building_sys.get_geometric_center(layer, fp), b_data["size"], b_data["type"])

			_current_tile_idx += 1; tiles_done += 1
			if Time.get_ticks_usec() - start_t > budget: return tiles_done
			
		_current_gen_chunk = Vector2i(-999,-999)

	return tiles_done

func _create_chunk_node(cpos: Vector2i):
	var node = Node2D.new()
	node.set_script(_CHUNK_SCRIPT)
	node.y_sort_enabled = true; add_child(node)
	chunks[cpos] = node
	node.setup(cpos, tileset)

func _process_removal_queue():
	if _removal_queue.is_empty(): return
	var cp = _removal_queue.pop_front()
	if not _removal_set.has(cp): return
	_removal_set.erase(cp)
	gen_worker.erase_cache(cp)
	if chunks.has(cp):
		if _chunk_objects.has(cp):
			for obj in _chunk_objects[cp]:
				if is_instance_valid(obj):
					_static_objects.erase(obj); _lighting_objects.erase(obj); _spatial_unregister(obj)
			_chunk_objects.erase(cp)
		if _tree_renderer: _tree_renderer.remove_chunk(cp)
		chunks[cp].queue_free(); chunks.erase(cp)

# ═══════════════════════════════════════════════════════════════
# INPUT & SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: building_sys.select_building("windmill")
			KEY_2: building_sys.select_building("camfire")
			KEY_ESCAPE:
				if building_sys.selected_building != "": building_sys.cancel_building()
				else: ui_manager.toggle_pause_menu(!get_tree().paused)
			KEY_M: ui_manager.toggle_world_map(!ui_manager.world_map_instance.visible)
			KEY_F3: ui_manager.ui_layer.visible = !ui_manager.ui_layer.visible

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and building_sys.selected_building != "":
			var result = building_sys.build_at_mouse(get_global_mouse_position())
			if not result.is_empty():
				update_chunks(true) # Add building to visual nodes immediately
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			building_sys.cancel_building()

func _on_map_teleport_requested(target_tile: Vector2, _expected_biome: String):
	# Dịch chuyển dựa trên tọa độ Cartesian chuẩn hóa (Bypass TileMap transformation drift)
	var world_pos = cartesian_idx_to_local(target_tile)
	
	if player:
		player.global_position = world_pos
	
	if camera:
		camera.global_position = world_pos
		camera.force_update_scroll()
		if camera.has_method("reset_smoothing"):
			camera.reset_smoothing()
			
	# --- TELEPORT AUDIT ---
	var ix = target_tile.x; var iy = target_tile.y
	var land = shape_engine.get_land_value(target_tile)
	var bd = shape_engine.get_biome(target_tile, land)
	var game_biome = bd["biome"]
	print(">>>> [TELEPORT-AUDIT] <<<<")
	print("  Target (Cartesian): %s" % target_tile)
	print("  Expected (Map):     %s" % _expected_biome)
	print("  Actual (Game):       %s" % game_biome)
	print("  Land Value:         %.3f" % land)
	print("  Status:             %s" % ("MATCH" if game_biome.to_lower() == _expected_biome.to_lower() else "MISMATCH / DRIFT"))
	print(">>>>>>>>>>>>>>>>>>>>>>>>")

func local_to_cartesian_idx(world_pos: Vector2) -> Vector2:
	# Isometric Math for 500x250 tiles
	var px = world_pos.x; var py = world_pos.y
	var ix = (px / 250.0 + py / 125.0) / 2.0
	var iy = (py / 125.0 - px / 250.0) / 2.0
	var res = Vector2(ix, iy)
	return res

func cartesian_idx_to_local(idx: Vector2) -> Vector2:
	var res = Vector2((idx.x - idx.y) * 250.0, (idx.x + idx.y) * 125.0)
	return res
	
	update_chunks(true)
	ui_manager.toggle_world_map(false)

func teleport_to_nearest_biome(type: String):
	for zone in shape_engine.biome_zones:
		if zone["type"] == type:
			var tile_pos = Vector2i(zone["pos"] * shape_engine.map_scale)
			camera.global_position = temp_layer.map_to_local(tile_pos)
			update_chunks(true); return

# ═══════════════════════════════════════════════════════════════
# MAPPING ENGINE (Logic remains here as part of Tile Orchestration)
# ═══════════════════════════════════════════════════════════════

func _biome_to_tile_id(biome: String, land_val: float, river_val: float, _scatter_val: float) -> int:
	if force_block_id != -1: return force_block_id
	
	# Global Ocean threshold - strictly enforce
	if land_val > 0.1: 
		return 21 # Water

	match biome:
		"tundra":      return 8
		"taiga":       return 7
		"volcano":     return 27 if land_val > 0.5 else 26
		"desert":      return 2
		"savannah":    return 4
		"jungle":      return 9
		"beach":       return 2
		"bamboo":      return 10
		"coal":        return 10
		"salt_desert": return 8
		"forest":      return 1
		"plains":      return 1
		"deep_sea":    return 21
		_:             
			return 2 if land_val < 0.1 else 21 # Default to sand if on land, ocean if not

func _biome_to_prop(biome: String, forest_val: float, scatter_val: float) -> int:
	match biome:
		"tundra":
			if forest_val > 0.3: return 26
		"taiga":
			if forest_val > 0.2: return 26
		"forest":
			if forest_val > 0.2: return 18
		"jungle":
			if forest_val > 0.2: return 23
		"desert":
			# Xóa cactus theo yêu cầu người dùng
			if forest_val > 0.6: return -1 
		"bamboo":
			if forest_val > 0.3: return 19
	return -1

# ═══════════════════════════════════════════════════════════════
# OBJECT HANDLING
# ═══════════════════════════════════════════════════════════════

func _add_rotation_test_object(parent: Node2D, center: Vector2, size: Vector2i, type: String):
	var s2d = ui_manager.scale_slider.value if ui_manager else 1.0
	if _tree_renderer and type in MULTIMESH_TREE_TYPES:
		var tp = local_to_cartesian_idx(center)
		var cp = Vector2i(floorf(float(tp.x)/16.0), floorf(float(tp.y)/16.0))
		var off = _tree_defs[type]["offset"].y if _tree_defs.has(type) else 0.0
		_tree_renderer.add_tree(type, center, s2d, off, cp)
		return

	var pivot = Node2D.new(); pivot.position = center; pivot.y_sort_enabled = true; parent.add_child(pivot)
	var sprite = Sprite2D.new(); pivot.add_child(sprite); sprite.scale = Vector2(s2d, s2d)
	
	# Căn chỉnh dựa trên texture_origin của isometric system (2373 cho 500x5000)
	sprite.centered = false
	match type:
		"windmill": 
			sprite.texture = _windmill_tex
			sprite.offset = Vector2(-512, -512) # Windmill 1024x1024 centered
		"camfire":  
			sprite.texture = _camfire_tex
			sprite.offset = Vector2(-512, -512) # Camfire 1024x1024 centered
		"core":     
			sprite.texture = _core_tex
			# Core 500x5000, origin 2373
			sprite.offset = Vector2(-250, -2373)
		_: 
			if _tree_defs.has(type): 
				sprite.texture = _tree_defs[type]["tex"]
				sprite.centered = true # Giữ centered cho cây cối vì chúng dùng offset riêng trong _tree_defs

	_register_object_system(pivot, type, size)


func _register_object_system(pivot: Node2D, type: String, size: Vector2i):
	var cp = local_to_cartesian_idx(pivot.position)
	var c_pos = Vector2i(floorf(cp.x / 16.0), floorf(cp.y / 16.0))
	if not _chunk_objects.has(c_pos): _chunk_objects[c_pos] = []
	_chunk_objects[c_pos].append(pivot)
	
	if type == "camfire": _lighting_objects[pivot] = true
	else: _static_objects[pivot] = true
	_spatial_register(pivot)

# [Legacy / Misc helpers]
func _make_noise(s, t, f, o):
	var n = FastNoiseLite.new(); n.seed=s; n.noise_type=t; n.frequency=f; n.fractal_octaves=o; return n
func _pick_continent_type(s):
	return ["pangaea","laurasia","twin_continents","crescent","isolated_isle"][s%5]
func _get_biome_name_debug(pos):
	return shape_engine.get_biome(pos, shape_engine.get_land_value(pos))["biome"]
func _spatial_register(n):
	var c = Vector2i(n.global_position/1000.0); if not _spatial_hash.has(c): _spatial_hash[c]=[]
	_spatial_hash[c].append(n)
func _spatial_unregister(n):
	var c = Vector2i(n.global_position/1000.0); if _spatial_hash.has(c): _spatial_hash[c].erase(n)

func _load_entmap_data(path: String) -> Dictionary:
	var result = {"image": null, "snapshot": []}
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return result
	
	var json_str = f.get_as_text()
	f.close()
	
	var json = JSON.new()
	if json.parse(json_str) == OK:
		var data = json.data
		result["snapshot"] = data.get("biomes_snapshot", [])
		if data.has("pixel_data") and data.pixel_data is String:
			var buffer = Marshalls.base64_to_raw(data.pixel_data)
			var img = Image.new()
			if img.load_png_from_buffer(buffer) == OK:
				result["image"] = img
	return result
