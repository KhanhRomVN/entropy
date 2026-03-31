extends Node3D

@export var chunk_size: int = 16
var render_distance: int = 2 # Sẽ được tính toán động
const MAX_RENDER_DISTANCE: int = 8
@export var block_size: float = 2.0
@export var prop_scale_multiplier: float = 2.5
@export var move_speed: float = 20.0
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 2.0
@export var max_zoom: float = 100.0

# Assets
var tile_scenes: Dictionary = {}
var prop_scenes: Dictionary = {}

var loaded_chunks: Dictionary = {}       # {Vector2: bool}
var loaded_chunk_nodes: Dictionary = {}  # {Vector2: Node3D}

@export var player_path: NodePath 
var player: Node3D 

var props_grid_map: GridMap
var mesh_library: MeshLibrary

# Noise
var noise: FastNoiseLite
var prop_noise: FastNoiseLite

# IDs
enum TileID { GRASS = 0, WATER = 1 }
enum PropID { AUTUMN_TREE = 10, GREEN_TREE = 11, ROCK = 12, SNOW_TREE = 13, PILLAR = 14 }

# UI State
var loading_ui_layer: CanvasLayer
var fps_label: Label
var initial_chunks_loaded: int = 0
var total_initial_chunks: int = 0
var game_ready: bool = false

var active_generation_count: int = 0
const MAX_PARALLEL_CHUNKS: int = 8
const MAX_CHUNKS_PER_FRAME: int = 4
var chunks_applied_this_frame: int = 0

var generation_queue: Array = []
var pending_apply_queue: Array = []  # [{data, c_pos}]
var _ground_backdrop: MeshInstance3D

class TerrainChunk extends Node3D:
	func build(chunk_data: Array, mesh_lib: MeshLibrary, b_size: float):
		var tile_counts = {}
		for item in chunk_data:
			if item.id < 10:
				tile_counts[item.id] = tile_counts.get(item.id, 0) + 1
				
		var mmi_dict = {}
		for t_id in tile_counts.keys():
			var mmi = MultiMeshInstance3D.new()
			var mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.instance_count = tile_counts[t_id]
			mm.mesh = mesh_lib.get_item_mesh(t_id)
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			mmi_dict[t_id] = { "node": mmi, "idx": 0 }
			
		for item in chunk_data:
			if item.id < 10:
				var data = mmi_dict[item.id]
				var t = mesh_lib.get_item_mesh_transform(item.id)
				# Sử dụng tọa độ Local so với tâm Chunk
				var local_pos = Vector3(item.pos.x * b_size - global_position.x, item.pos.y * b_size, item.pos.z * b_size - global_position.z)
				t.origin += local_pos
				data["node"].multimesh.set_instance_transform(data["idx"], t)
				data["idx"] += 1
		
		# Gán AABB tùy chỉnh để tránh bị ẩn nhầm (Frustum Culling)
		var c_world_size = 16 * b_size # chunk_size * block_size
		for id in mmi_dict.keys():
			var mmi = mmi_dict[id]["node"]
			mmi.custom_aabb = AABB(Vector3(0, -5, 0), Vector3(c_world_size, 10, c_world_size))
		
		# Log thống kê nạp chunk (Moved here)
		var log_str = "Entropy: Built Chunk Tiles: "
		for t_id in tile_counts.keys():
			log_str += "ID_%d=%d " % [t_id, tile_counts[t_id]]
		print(log_str)

func _ready():
	# Mở toàn màn hình ngay khi khởi động
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	_create_ui()
	_load_assets()
	_setup_noise()
	setup_grid_map()
	_create_ground_backdrop()
	
	# Đặt màu nền toàn hệ thống thành Nâu Đất để triệt tiêu vực thẳm màu xám
	RenderingServer.set_default_clear_color(Color(0.4, 0.25, 0.1))
	
	if has_node(player_path):
		player = get_node(player_path)
	elif get_viewport().get_camera_3d():
		player = get_viewport().get_camera_3d()

	if player is Camera3D:
		player.near = 0.01
		player.far = 4000.0
		_log_camera_state("STARTUP")

	# Tắt shadow DirectionalLight để tăng performance
	for child in get_children():
		if child is DirectionalLight3D:
			child.shadow_enabled = false
		
	total_initial_chunks = (render_distance * 2 + 1) * (render_distance * 2 + 1)

func _create_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	fps_label = Label.new()
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.text = "FPS: 0"
	fps_label.position = Vector2(-20, 20)
	fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	canvas.add_child(fps_label)
	
	loading_ui_layer = CanvasLayer.new()
	loading_ui_layer.layer = 100
	add_child(loading_ui_layer)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.1, 0.1, 1.0)
	loading_ui_layer.add_child(bg)
	
	var load_lbl = Label.new()
	load_lbl.text = "GENERATING WORLD...\nPlease wait."
	load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	load_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_ui_layer.add_child(load_lbl)

func _load_assets():
	tile_scenes[TileID.GRASS] = load("res://assets/environment/tiles/grass_block/grass_block.glb")
	tile_scenes[TileID.WATER] = load("res://assets/environment/tiles/water_block/water_block.glb")
	
	prop_scenes[PropID.AUTUMN_TREE]  = load("res://assets/environment/props/autumn_yellow_tree/autumn_yellow_tree.glb")
	prop_scenes[PropID.GREEN_TREE]   = load("res://assets/environment/props/green_leaf_tree/green_leaf_tree.glb")
	prop_scenes[PropID.ROCK]         = load("res://assets/environment/props/rock_cluster/rock_cluster.glb")
	prop_scenes[PropID.SNOW_TREE]    = load("res://assets/environment/props/snow_covered_tree/snow_covered_tree.glb")
	prop_scenes[PropID.PILLAR]       = load("res://assets/environment/props/spawnpoint_pillar/spawnpoint_pillar.glb")

func _setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05
	
	prop_noise = FastNoiseLite.new()
	prop_noise.seed = randi() + 1
	prop_noise.frequency = 0.1

func setup_grid_map():
	block_size = 2.0
	
	props_grid_map = GridMap.new()
	props_grid_map.cell_size = Vector3(block_size, block_size, block_size)
	add_child(props_grid_map)
	
	mesh_library = MeshLibrary.new()
	
	for id in tile_scenes.keys():
		var scene = tile_scenes[id]
		var asset_name = scene.resource_path.get_file().get_basename()
		_add_mesh_to_library(asset_name, scene, id)
	
	for id in prop_scenes.keys():
		var scene = prop_scenes[id]
		var asset_name = scene.resource_path.get_file().get_basename()
		_add_mesh_to_library(asset_name, scene, id)
		
	props_grid_map.mesh_library = mesh_library

func _add_mesh_to_library(asset_name: String, scene: PackedScene, id: int):
	if not scene: 
		push_error("Entropy: Missing scene for ID: " + asset_name)
		return
		
	var instance = scene.instantiate()
	var mesh_node = _find_mesh_node_recursive(instance)
	
	if mesh_node:
		var mesh = mesh_node.mesh
		var mesh_transform = instance.transform * mesh_node.transform
		var aabb = mesh.get_aabb()
		
		var is_block = asset_name.ends_with("_block") or asset_name.contains("block")
		
		# Tính toán tỷ lệ (Scale) - Đồng nhất cho tất cả: chỉ ép chiều ngang, chiều cao tự phóng theo tỉ lệ
		var max_h_dim = max(aabb.size.x, aabb.size.z)
		if max_h_dim > 0:
			var multiplier = prop_scale_multiplier if not is_block else 1.0
			var scale_factor = (block_size * multiplier) / max_h_dim
			mesh_transform = mesh_transform.scaled(Vector3(scale_factor, scale_factor, scale_factor))
		
		# Tính toán vị trí tâm sau khi đã scale (Center Correction)
		# CHUẨN HÓA: Căn đáy tại y=0 và căn tâm ngang tại (1, 1) 
		var local_center = aabb.position + aabb.size / 2.0
		var local_bottom = Vector3(local_center.x, aabb.position.y, local_center.z)
		
		var current_center = mesh_transform * local_center
		var current_bottom = mesh_transform * local_bottom
		
		# Target: Tâm X/Z là 1.0 (nửa block), Đáy Y là 0.0
		var target_pos = Vector3(block_size / 2.0, 0.0, block_size / 2.0)
		var offset = Vector3(target_pos.x - current_bottom.x, -current_bottom.y, target_pos.z - current_bottom.z)
		
		# Thêm offset nhỏ cho nước để tránh Z-fighting với địa hình đất
		if asset_name == "water_block":
			offset.y -= 0.05
			
		mesh_transform.origin += offset
		
		# Log siêu chi tiết để debug Z-fighting
		var final_scale = mesh_transform.basis.get_scale()
		var final_origin = mesh_transform.origin
		print("Entropy: Asset %s (ID: %d) | AABB_Local: %s | Scale: %s | Offset: %s" % [asset_name, id, str(aabb), str(final_scale), str(final_origin)])
		
		mesh_library.create_item(id)
		mesh_library.set_item_name(id, asset_name)
		mesh_library.set_item_mesh(id, mesh)
		mesh_library.set_item_mesh_transform(id, mesh_transform)
	else:
		push_error("Entropy: Không tìm thấy MeshInstance3D trong file của: " + asset_name)
	
	instance.queue_free()

func _find_mesh_node_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var m = _find_mesh_node_recursive(child)
		if m: return m
	return null

func _find_mesh_recursive(node: Node) -> Mesh:
	var m_node = _find_mesh_node_recursive(node)
	return m_node.mesh if m_node else null

func _process(delta):
	_handle_movement(delta)
	
	if player is Camera3D:
		if is_instance_valid(fps_label):
			fps_label.text = "FPS: " + str(Engine.get_frames_per_second())
		
		# Tự động sửa lỗi Near-Plane Clipping cho Camera Ortho
		if player.projection == Camera3D.PROJECTION_ORTHOGONAL:
			# Công thức tính độ cao an toàn tối thiểu: (size/2) * cos(pitch) + buffer
			var pitch_rad = abs(player.rotation.x)
			var min_safe_y = (player.size * 0.5) * cos(pitch_rad) + 2.0
			if player.global_position.y < min_safe_y:
				player.global_position.y = min_safe_y
		
		if is_instance_valid(_ground_backdrop):
			var focus = _get_camera_focus_point()
			_ground_backdrop.global_position = Vector3(focus.x, -2.0, focus.z)
	
	chunks_applied_this_frame = 0
	_process_pending_apply_queue()
	
	if player:
		update_chunks()
	
	while not generation_queue.is_empty() and active_generation_count < MAX_PARALLEL_CHUNKS:
		process_generation_queue()

func _process_pending_apply_queue():
	while not pending_apply_queue.is_empty() and chunks_applied_this_frame < MAX_CHUNKS_PER_FRAME:
		var item = pending_apply_queue.pop_front()
		_apply_chunk_data(item.data, item.c_pos)

func get_chunk_pos(pos: Vector3) -> Vector2:
	return Vector2(floor(pos.x / (chunk_size * block_size)), floor(pos.z / (chunk_size * block_size)))



func update_chunks():
	var active_chunks = _get_visible_chunks()
	
	for c_pos in active_chunks:
		if not loaded_chunks.has(c_pos):
			if not c_pos in generation_queue:
				generation_queue.push_back(c_pos)
			loaded_chunks[c_pos] = true

	var to_remove = []
	for c_pos in loaded_chunks.keys():
		if not c_pos in active_chunks:
			to_remove.append(c_pos)
	
	for c in to_remove:
		unload_chunk(c)
		loaded_chunks.erase(c)

func process_generation_queue():
	active_generation_count += 1
	var c_pos = generation_queue.pop_front()
	
	WorkerThreadPool.add_task(func():
		var data = _generate_chunk_data(c_pos)
		call_deferred("_enqueue_apply", data, c_pos)
	)

func _generate_chunk_data(c_pos: Vector2) -> Array:
	var data = []
	var start_x = int(c_pos.x * chunk_size)
	var start_z = int(c_pos.y * chunk_size)
	
	for x in range(chunk_size):
		for z in range(chunk_size):
			var world_x = start_x + x
			var world_z = start_z + z
			var val = noise.get_noise_2d(world_x, world_z)
			
			var tile_id = TileID.GRASS
			if val < -0.2:
				tile_id = TileID.WATER
			elif val > 0.4:
				tile_id = TileID.GRASS
			
			data.append({"pos": Vector3i(world_x, 0, world_z), "id": tile_id})
			
			var p_val = prop_noise.get_noise_2d(world_x, world_z)
			
			if world_x == 0 and world_z == 0:
				data.append({"pos": Vector3i(world_x, 1, world_z), "id": PropID.PILLAR})
				continue

			if tile_id == TileID.GRASS:
				if val > 0.4:
					if p_val > 0.5:
						data.append({"pos": Vector3i(world_x, 1, world_z), "id": PropID.SNOW_TREE})
				else:
					if p_val > 0.45:
						var prop_id = PropID.GREEN_TREE
						if p_val > 0.65: prop_id = PropID.AUTUMN_TREE
						data.append({"pos": Vector3i(world_x, 1, world_z), "id": prop_id})
					elif p_val < -0.6:
						data.append({"pos": Vector3i(world_x, 1, world_z), "id": PropID.ROCK})
	return data

func _enqueue_apply(data: Array, c_pos: Vector2):
	print("Entropy: Chunk %s data generated successfully." % str(c_pos))
	pending_apply_queue.append({"data": data, "c_pos": c_pos})
	active_generation_count -= 1

func _apply_chunk_data(data: Array, c_pos: Vector2):
	# Kiểm tra nếu chunk này đã bị hủy trong khi đang chờ nạp
	if not loaded_chunks.has(c_pos):
		return
		
	chunks_applied_this_frame += 1
	
	# Nếu đã có node cũ (có thể do nạp lại nhanh) thì dọn dẹp trước khi gán node mới
	if loaded_chunk_nodes.has(c_pos):
		var old_node = loaded_chunk_nodes[c_pos]
		if is_instance_valid(old_node):
			old_node.queue_free()
		loaded_chunk_nodes.erase(c_pos)
		
	var chunk_node = TerrainChunk.new()
	add_child(chunk_node)
	chunk_node.name = "Chunk_" + str(c_pos)
	
	# Đặt Chunk Node tại đúng tọa độ thế giới
	chunk_node.global_position = Vector3(c_pos.x * chunk_size * block_size, 0, c_pos.y * chunk_size * block_size)
	
	chunk_node.build(data, mesh_library, block_size)
	loaded_chunk_nodes[c_pos] = chunk_node
	print("Entropy: Applied Chunk %s to scene (NodeID: %d)" % [str(c_pos), chunk_node.get_instance_id()])
	
	for item in data:
		if item.id >= 10:
			props_grid_map.set_cell_item(item.pos, item.id)
	
	if not game_ready:
		initial_chunks_loaded += 1
		if initial_chunks_loaded >= total_initial_chunks:
			game_ready = true
			if is_instance_valid(loading_ui_layer):
				loading_ui_layer.queue_free()

func unload_chunk(c_pos: Vector2):
	if loaded_chunk_nodes.has(c_pos):
		print("Entropy: Unloading Chunk %s" % str(c_pos))
		loaded_chunk_nodes[c_pos].queue_free()
		loaded_chunk_nodes.erase(c_pos)
		
	var start_x = int(c_pos.x * chunk_size)
	var start_z = int(c_pos.y * chunk_size)
	
	for x in range(chunk_size):
		for z in range(chunk_size):
			props_grid_map.set_cell_item(Vector3i(start_x + x, 1, start_z + z), -1)

func _create_ground_backdrop():
	var mi = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	# Giảm size xuống 500 (vừa đủ bao quát mà không gây sai số Depth)
	mesh.size = Vector3(500, 0.1, 500)
	mi.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	# Màu nâu đất để ngụy trang Z-fighting với vách đá
	mat.albedo_color = Color(0.4, 0.25, 0.1)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Đặt tại y=-1.0 để tạo khoảng cách an toàn tuyệt đối tránh Z-fighting
	mi.position = Vector3(0, -1.0, 0)
	add_child(mi)
	_ground_backdrop = mi

func _handle_movement(delta):
	if not player: return
	
	# Đảm bảo Near Plane luôn ở mức thấp nhất để không bị lỗi 1 FPS và clipping
	if player is Camera3D and player.near > 0.1:
		player.near = 0.01
	
	var input_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
	
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		
		# Tính toán hướng di chuyển dựa trên hướng nhìn của Camera
		var forward = -player.global_transform.basis.z
		var right = player.global_transform.basis.x
		
		# Chỉ lấy hướng trên mặt phẳng XZ (không cho camera bay lên/xuống)
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
		
		var move_dir = (forward * -input_dir.z) + (right * input_dir.x)
		player.global_position += move_dir * move_speed * delta

func _input(event):
	if not player: return
	
	# Thoát game nhanh
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
		
	# Bật/Tắt Toàn màn hình (F11)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			
	# Hệ thống Chẩn đoán (F3)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_dump_debug_info()
	
	# Chỉ xử lý Zoom khi giữ Ctrl và cuộn chuột
	if event is InputEventMouseButton and (event.ctrl_pressed or Input.is_key_pressed(KEY_CTRL)):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(zoom_speed)

func _zoom_camera(amount: float):
	if player is Camera3D:
		if player.projection == Camera3D.PROJECTION_ORTHOGONAL:
			player.size = clamp(player.size + amount, min_zoom, max_zoom)
			print("Entropy: [ZOOM] Ortho Size: %.1f" % player.size)
		else:
			player.fov = clamp(player.fov + amount, 20, 120)
			print("Entropy: [ZOOM] FOV: %.1f" % player.fov)
		_log_camera_state("ZOOM")

func _dump_debug_info():
	print("\n=== ENTROPY SELF-DIAGNOSIS REPORT ===")
	print("Time: %f" % Time.get_unix_time_from_system())
	print("FPS: %d" % Engine.get_frames_per_second())
	print("Active Chunks: %d" % loaded_chunk_nodes.size())
	print("Parallel Thread Count: %d / %d" % [active_generation_count, MAX_PARALLEL_CHUNKS])
	
	if player is Camera3D:
		print("Camera Position: %s" % str(player.global_position))
		print("Camera Near: %f, Far: %f" % [player.near, player.far])
		print("Camera Projection: %d" % player.projection)
		if player.projection == Camera3D.PROJECTION_ORTHOGONAL:
			print("Camera Size: %f" % player.size)
			
	if is_instance_valid(_ground_backdrop):
		print("Backdrop Position: %s" % str(_ground_backdrop.global_position))
		print("Backdrop Size: (500, 0.1, 500)")
		
	# Kiểm tra rò rỉ node (Orphaned nodes check)
	var total_nodes = get_tree().get_node_count()
	print("Total Nodes in Scene tree: %d" % total_nodes)
	print("Static Memory Usage: %.2f MB" % (OS.get_static_memory_usage() / 1024.0 / 1024.0))
	print("VRAM Usage (Estimate): %.2f MB" % (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1024.0 / 1024.0))
	print("Video Objects: %d" % Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	print("===================================\n")

func _log_camera_state(label: String):
	if not (player is Camera3D): return
	var rot = player.rotation_degrees
	var pos = player.global_position
	var proj = "Orthogonal" if player.projection == Camera3D.PROJECTION_ORTHOGONAL else "Perspective"
	print("Entropy: [CAM_%s] Pos: %s | RotDeg: %s | Proj: %s | Near: %.2f | Far: %.1f" % [
		label, str(pos), str(rot), proj, player.near, player.far
	])
	if rot.x > -30.0:
		print("Entropy: [CAM_WARN] rotation.x = %.1f deg — Camera quá ngang! Nên từ -45 đến -90 để nhìn xuống." % rot.x)
	if pos.y < 5.0:
		print("Entropy: [CAM_WARN] Camera Y = %.1f — Camera quá thấp! Nên >= 10.0 cho top-down view." % pos.y)

func _get_camera_focus_point() -> Vector3:
	if not player: return Vector3.ZERO
	if not (player is Camera3D): return player.global_position
	var forward = -player.global_transform.basis.z
	if abs(forward.y) < 0.1:
		return player.global_position + forward * 50.0
	var t = -player.global_position.y / forward.y
	t = clamp(t, 0.0, 200.0)
	return player.global_position + forward * t

func _get_visible_chunks() -> Array:
	if not (player is Camera3D): return []
	
	var viewport_size = get_viewport().get_visible_rect().size
	var corners = [
		Vector2(0, 0),
		Vector2(viewport_size.x, 0),
		Vector2(viewport_size.x, viewport_size.y),
		Vector2(0, viewport_size.y),
		Vector2(viewport_size.x / 2.0, viewport_size.y / 2.0)
	]
	
	var min_c = Vector2(1e6, 1e6)
	var max_c = Vector2(-1e6, -1e6)
	var has_data = false
	
	for corner in corners:
		var ray_origin = player.project_ray_origin(corner)
		var ray_normal = player.project_ray_normal(corner)
		
		if abs(ray_normal.y) > 0.01:
			var t = -ray_origin.y / ray_normal.y
			# Ngay cả khi t < 0 (giao điểm sau lưng), vẫn lấy vị trí đó để nạp gạch gối đầu
			var world_pos = ray_origin + ray_normal * t
			var c_pos = get_chunk_pos(world_pos)
			min_c.x = min(min_c.x, c_pos.x)
			min_c.y = min(min_c.y, c_pos.y)
			max_c.x = max(max_c.x, c_pos.x)
			max_c.y = max(max_c.y, c_pos.y)
			has_data = true
	
	var result = []
	if not has_data: return result
	
	# Luôn nạp ít nhất một vùng an toàn
	for x in range(int(min_c.x) - 2, int(max_c.x) + 3):
		for z in range(int(min_c.y) - 2, int(max_c.y) + 3):
			result.append(Vector2(x, z))
	
	return result
