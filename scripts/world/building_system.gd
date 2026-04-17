# scripts/world/building_system.gd
# Module quản lý việc xây dựng, footprint và ghost preview
extends Node2D

# ═══════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════
var building_roots: Dictionary = {}
var occupied_tiles: Dictionary = {}
var selected_building: String = ""

# Ghost Visuals
var ghost_sprite: Sprite2D
var ghost_shadow: Sprite2D
var preview_outline: Line2D

# Tham chiếu từ Orchestrator
var temp_layer: TileMapLayer
var camera: Camera2D

# Textures (cần được Orchestrator truyền vào hoặc tự load)
var windmill_tex: Texture2D
var camfire_tex: Texture2D
var core_tex: Texture2D

# ═══════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════
func setup(_temp_layer, _camera, _windmill, _camfire, _core):
	temp_layer = _temp_layer
	camera = _camera
	windmill_tex = _windmill
	camfire_tex = _camfire
	core_tex = _core
	
	_create_ghost_nodes()

func _create_ghost_nodes():
	ghost_sprite = Sprite2D.new()
	ghost_sprite.modulate = Color(1, 1, 1, 0.4)
	ghost_sprite.z_index = 100
	ghost_sprite.visible = false
	add_child(ghost_sprite)

	ghost_shadow = Sprite2D.new()
	ghost_shadow.modulate = Color(1, 1, 1, 0.3)
	ghost_shadow.z_index = 99
	ghost_shadow.visible = false
	add_child(ghost_shadow)

	preview_outline = Line2D.new()
	preview_outline.width = 2.0
	preview_outline.default_color = Color(1, 1, 1, 0.8)
	preview_outline.z_index = 98
	preview_outline.visible = false
	preview_outline.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	add_child(preview_outline)

# ═══════════════════════════════════════════════════════════════
# LOGIC
# ═══════════════════════════════════════════════════════════════
func select_building(type: String):
	if selected_building == type:
		cancel_building()
		return
		
	selected_building = type
	ghost_sprite.visible = true
	preview_outline.visible = true
	
	match type:
		"windmill":
			ghost_sprite.texture = windmill_tex
			ghost_sprite.scale = Vector2(0.3, 0.3)
			ghost_shadow.visible = true
		"camfire":
			ghost_sprite.texture = camfire_tex
			ghost_sprite.scale = Vector2(0.3, 0.3)
			ghost_shadow.visible = false
		"core":
			ghost_sprite.texture = core_tex
			ghost_sprite.scale = Vector2(0.3, 0.3)
			ghost_shadow.visible = true

func cancel_building():
	selected_building = ""
	ghost_sprite.visible = false
	ghost_shadow.visible = false
	preview_outline.visible = false

func update_ghost(m_pos: Vector2, s2d: float, off_x: float, off_y: float):
	if not temp_layer or selected_building == "": return
	
	var t_pos = temp_layer.local_to_map(temp_layer.to_local(m_pos))
	var b_size = Vector2i(2, 2) if selected_building == "windmill" else Vector2i(1, 1)
	var footprint = generate_footprint(t_pos, b_size.x, b_size.y)
	var snapped_center = get_geometric_center(temp_layer, footprint)
	
	ghost_sprite.position = snapped_center
	if ghost_sprite.texture:
		var h = ghost_sprite.texture.get_height()
		ghost_sprite.position.y -= (h * s2d) / 2.0
	
	ghost_sprite.position.x += off_x
	ghost_sprite.position.y += off_y
	ghost_sprite.scale = Vector2(s2d, s2d)
	
	var occupied = is_footprint_occupied(footprint)
	preview_outline.default_color = Color(1, 0, 0, 0.8) if occupied else Color(1, 1, 1, 0.8)
	
	var offset_w = 250.0 * b_size.x
	var offset_h = 125.0 * b_size.y
	var p_top = snapped_center + Vector2(0, -offset_h)
	var p_right = snapped_center + Vector2(offset_w, 0)
	var p_bottom = snapped_center + Vector2(0, offset_h)
	var p_left = snapped_center + Vector2(-offset_w, 0)
	preview_outline.points = PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top])

func build_at_mouse(m_pos: Vector2) -> Dictionary:
	var t_pos = temp_layer.local_to_map(temp_layer.to_local(m_pos))
	if building_roots.has(t_pos): return {}
	
	var b_size = Vector2i(2, 2) if selected_building == "windmill" else Vector2i(1, 1)
	var footprint = generate_footprint(t_pos, b_size.x, b_size.y)
	
	if is_footprint_occupied(footprint):
		return {}
		
	building_roots[t_pos] = {"type": selected_building, "size": b_size}
	for t in footprint: 
		occupied_tiles[t] = true
		
	return {"tile_pos": t_pos, "type": selected_building, "size": b_size, "footprint": footprint}

# ═══════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════
func generate_footprint(root: Vector2i, w: int, h: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for i in range(w):
		for j in range(h):
			tiles.append(root + Vector2i(i, j))
	return tiles

func get_geometric_center(layer: TileMapLayer, footprint: Array[Vector2i]) -> Vector2:
	if footprint.is_empty(): return Vector2.ZERO
	var sum_p = Vector2.ZERO
	for tile in footprint: sum_p += layer.map_to_local(tile)
	return sum_p / float(footprint.size())

func is_footprint_occupied(footprint: Array[Vector2i]) -> bool:
	for t in footprint:
		if occupied_tiles.has(t): return true
	return false
