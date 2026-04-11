extends Node2D

@export var map_size: int = 50

var grass_path = "res://assets/tiles/block/grass_block/grass_block.png"
var stone_path = "res://assets/tiles/block/stone_block/stone_block.png"
var windmill_shadow_path = "res://assets/tiles/building/windmill/windmill_shadow.png"
var half: int = 25

# Quản lý xây dựng
var occupied_tiles: Dictionary = {} 
var current_layer: TileMapLayer
var ghost_sprite: Sprite2D
var preview_outline: Line2D
var selected_slot: int = -1 # -1 nghĩa là không chọn ô nào

var hotbar_items = [
	{"name": "Windmill", "path": "res://assets/tiles/building/windmill/windmill.png", "source_id": 1, "z": 10},
	{"name": "Shadow", "path": "res://assets/tiles/building/windmill/windmill_shadow.png", "source_id": -1, "z": 10},
	null, null, null, null
]

func _ready():
	print("MapGenerator: Starting Reconstruction...")
	generate_map()

func generate_map():
	# 1. DỌN DEP TRIỆT ĐỂ
	for child in get_children():
		child.queue_free()
	
	# Đợi 1 frame để Engine dọn dẹp các node cũ
	await get_tree().process_frame
	
	# 2. NẠP TILESET GỐC TỪ DỰ ÁN (Đảm bảo đồng bộ 100% với Editor)
	var ts = load("res://resources/tilesets/main_tileset.tres")
	if not ts:
		printerr("MapGenerator: Cannot load main_tileset.tres!")
		return
	
	# 3. TẠO LỚP GẠCH
	current_layer = TileMapLayer.new()
	current_layer.name = "FloorLayer"
	current_layer.tile_set = ts
	current_layer.y_sort_enabled = true
	add_child(current_layer)
	
	half = map_size / 2 # 25
	
	# --- CÀI ĐẶT THẾ GIỚI VÔ TẬN STONE ---
	for y in range(-50, 51):
		for x in range(-50, 51):
			current_layer.set_cell(Vector2i(x, y), 4, Vector2i(0, 0)) # Stone
	
	# --- CÀI ĐẶT 24 CỤM CÔNG TRÌNH TẠI TÂM (0,0) ---
	var count_x = 6
	var count_y = 4
	var step_x = 7
	var step_y = 10
	var start_x = -17 # Bắt đầu từ tọa độ âm để tâm lưới nằm tại (0,0)
	var start_y = -15
	
	for cx in range(count_x):
		for cy in range(count_y):
			var rx = start_x + (cx * step_x)
			var ry = start_y + (cy * step_y)
			var root_pos = Vector2i(rx, ry)
			
			# 4.1.1. Đặt 2x2 Grass
			var footprint = [
				root_pos,
				Vector2i(root_pos.x - 1, root_pos.y - 1),
				Vector2i(root_pos.x, root_pos.y - 1),
				Vector2i(root_pos.x, root_pos.y - 2)
			]
			for tile in footprint:
				current_layer.set_cell(tile, 0, Vector2i(0, 0)) # Grass
				
			# 4.1.2. Đặt Windmill Shadow
			_add_building(root_pos, windmill_shadow_path, current_layer, "Shadow", 10)
	
	# 5. KHỞI TẠO PREVIEW HỆ THỐNG
	_setup_preview_nodes()
	_update_hotbar_ui()
	
	# 6. SINH VẬT THỂ MẶC ĐỊNH
	# (Đã gỡ bỏ ShadowDisplay - Đổ bóng đã bị vô hiệu hóa hoàn toàn)
	
	# 7. CAMERA (Tập trung toàn cảnh)
	var camera = get_parent().get_node_or_null("Camera2D")
	if camera:
		camera.global_position = current_layer.map_to_local(Vector2i(half, half))
		camera.zoom = Vector2(0.3, 0.3) # Thu nhỏ để thấy 24 cụm

func _setup_preview_nodes():
	ghost_sprite = Sprite2D.new()
	ghost_sprite.modulate = Color(1, 1, 1, 0.5) # Trong suốt 50%
	add_child(ghost_sprite)
	
	preview_outline = Line2D.new()
	preview_outline.width = 3.0
	preview_outline.default_color = Color(0, 1, 0, 0.8) # Xanh lá
	preview_outline.closed = true
	add_child(preview_outline)

func _process(_delta):
	if not current_layer: return
	
	var mouse_pos = get_global_mouse_position()
	var map_pos = current_layer.local_to_map(mouse_pos)
	
	# Preview dựa trên Slot đang chọn
	# 1. ẨN PREVIEW NẾU KHÔNG CHỌN Ô NÀO
	if selected_slot == -1:
		ghost_sprite.visible = false
		preview_outline.visible = false
		return
		
	var item = hotbar_items[selected_slot]
	
	# Cập nhật Tọa độ ở UI
	var coord_label = get_parent().find_child("CoordLabel", true, false)
	if coord_label:
		var rel_x = map_pos.x - half
		var rel_y = map_pos.y - half
		coord_label.text = "Tọa độ: (%d, %d)" % [rel_x, rel_y]
	
	if item == null:
		ghost_sprite.visible = false
		preview_outline.visible = false
		return
	
	ghost_sprite.visible = true
	preview_outline.visible = true
	
	# Tính toán 4 ô Diamond
	var footprint = [
		map_pos,
		Vector2i(map_pos.x - 1, map_pos.y - 1),
		Vector2i(map_pos.x, map_pos.y - 1),
		Vector2i(map_pos.x, map_pos.y - 2)
	]
	
	# Cập nhật Outline
	var points = PackedVector2Array()
	# Dùng tọa độ đỉnh của các ô để vẽ outline kim cương
	var p_top = current_layer.map_to_local(footprint[3]) + Vector2(0, -125)
	var p_right = current_layer.map_to_local(footprint[2]) + Vector2(250, 0)
	var p_bottom = current_layer.map_to_local(footprint[0]) + Vector2(0, 125)
	var p_left = current_layer.map_to_local(footprint[1]) + Vector2(-250, 0)
	points.append(p_top); points.append(p_right); points.append(p_bottom); points.append(p_left)
	preview_outline.points = points
	
	# Kiểm tra va chạm
	var is_free = true
	for tile in footprint:
		if occupied_tiles.has(tile):
			is_free = false
			break
	
	preview_outline.default_color = Color(0, 1, 0, 0.8) if is_free else Color(1, 0, 0, 0.8)	# Đồng bộ với Editor: Căn Ghost vào Tâm Ô Gạch (Cell Center) thay vì Junction
	ghost_sprite.position = current_layer.map_to_local(map_pos)
	ghost_sprite.position.y -= 2375
	ghost_sprite.centered = true

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var new_slot = event.keycode - KEY_1
			# Nếu nhấn lại ô đang chọn -> Hủy chọn (-1)
			if selected_slot == new_slot:
				selected_slot = -1
			else:
				selected_slot = new_slot
			_update_hotbar_ui()
		elif event.keycode == KEY_0:
			selected_slot = -1
			_update_hotbar_ui()
	
	# Đặt công trình
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_slot != -1:
			var item = hotbar_items[selected_slot]
			if item:
				var mouse_pos = get_global_mouse_position()
				var root_pos = current_layer.local_to_map(mouse_pos)
				
				# Kiểm tra va chạm trước khi đặt
				var footprint = [root_pos, Vector2i(root_pos.x-1, root_pos.y-1), Vector2i(root_pos.x, root_pos.y-1), Vector2i(root_pos.x, root_pos.y-2)]
				var is_free = true
				for tile in footprint:
					if occupied_tiles.has(tile): is_free = false; break
				
				if is_free:
					_add_building(root_pos, item.path, current_layer, item.name, item.z)

func _update_hotbar_ui():
	var ui = get_parent().get_node_or_null("UI/HotbarContainer/HBox")
	if not ui: return
	
	var slot_nodes = ui.get_children()
	
	for i in range(slot_nodes.size()):
		var slot = slot_nodes[i]
		if i == selected_slot:
			slot.add_theme_stylebox_override("panel", load("res://scenes/maps/test1.tscn::StyleBoxFlat_slot_active"))
		else:
			# Cách đơn giản nhất để demo Active: Modulate
			slot.modulate = Color(1.5, 1.5, 1.5, 1.0) if i == selected_slot else Color(1.0, 1.0, 1.0, 1.0)

func _add_atlas_to_tileset(ts: TileSet, id: int, path: String, region_size: Vector2i, origin: Vector2i):
	var tex = load(path)
	if not tex:
		printerr("MapGenerator: Cannot load texture ", path)
		return
		
	var source = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = region_size
	source.create_tile(Vector2i(0, 0))
	source.get_tile_data(Vector2i(0, 0), 0).texture_origin = origin
	ts.add_source(source, id)

func _add_building(root_pos: Vector2i, path: String, layer: TileMapLayer, b_name: String, z: int) -> Node:
	# 1. Xác định 4 ô của khối Diamond (Staggered)
	var footprint = [
		root_pos,
		Vector2i(root_pos.x - 1, root_pos.y - 1),
		Vector2i(root_pos.x, root_pos.y - 1),
		Vector2i(root_pos.x, root_pos.y - 2)
	]
	
	# 2. Đánh dấu chiếm dụng (Occupancy)
	for tile in footprint:
		occupied_tiles[tile] = b_name
		print("Occupied tile: ", tile, " by ", b_name)

	# 3. ĐỒNG BỘ VỚI EDITOR: Dùng set_cell nếu vật phẩm có source_id
	var item_data = null
	for item in hotbar_items:
		if item and item.name == b_name:
			item_data = item
			break
			
	if item_data and item_data.source_id != -1:
		# Sử dụng source_id chính thức từ TileSet
		layer.set_cell(root_pos, item_data.source_id, Vector2i(0, 0))
		print("MapGenerator: Synchronized placement with Editor at ", root_pos)
		return null # Đã đặt bằng cell, không cần node Sprite
		
	# 4. Dự phòng: Dùng Sprite2D nếu không có trong TileSet (vd: ShadowDisplay)
	var sprite = Sprite2D.new()
	sprite.name = b_name
	
	var global_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img = Image.load_from_file(global_path)
		if img:
			sprite.texture = ImageTexture.create_from_image(img)
	
	layer.add_child(sprite)
	
	# Căn Sprite theo Tâm Ô Gạch để đồng bộ với Editor
	sprite.position = layer.map_to_local(root_pos)
	sprite.position.y -= 2375
	sprite.centered = true
	sprite.offset = Vector2(0, 0)
	sprite.z_index = z
	
	# 5. DIAGNOSTIC OUTLINES (Vẽ khung chẩn đoán)
	for i in range(footprint.size()):
		var color = Color(1, 0, 0, 0.8) if i == 0 else Color(1, 1, 0, 0.8) # Red for Root, Yellow for Others
		_draw_diagnostic_diamond(footprint[i], color, 6 if i == 0 else 4)
	
	print("MapGenerator: Added fallback building ", b_name, " at ", sprite.position)
	return sprite

func _draw_diagnostic_diamond(map_pos: Vector2i, color: Color, width: float):
	var line = Line2D.new()
	line.width = width
	line.default_color = color
	line.z_index = 20 # Luôn trên cùng
	
	var center = current_layer.map_to_local(map_pos)
	var points = [
		center + Vector2(0, -125),
		center + Vector2(250, 0),
		center + Vector2(0, 125),
		center + Vector2(-250, 0),
		center + Vector2(0, -125)
	]
	line.points = points
	current_layer.add_child(line)
