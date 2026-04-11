extends Node2D
## MultiMeshTreeRenderer — Industry-standard technique: 1 draw call cho toàn bộ cây cùng loại
## Thay vì 500 Sprite2D riêng biệt = 500 draw calls
## → MultiMeshInstance2D: 500 cây = 1 draw call per tree type = 7 draw calls tổng

# === CẤU HÌNH ===
const INITIAL_POOL_SIZE := 512  # Số instance pre-allocated per tree type
const GROW_STEP         := 256  # Tự mở rộng khi hết slot

# === DỮ LIỆU NỘI BỘ ===
# Mỗi loại cây có một MultiMeshInstance2D riêng
var _renderers: Dictionary = {}  # {type_name: MultiMeshInstance2D}
var _meshes:    Dictionary = {}  # {type_name: MultiMesh}

# Theo dõi instance slots: {type_name: {chunk_pos: [slot_indices]}}
var _chunk_slots: Dictionary = {}

# Free slot pool: {type_name: Array[int]}
var _free_slots: Dictionary = {}

# Texture map để tạo renderer
var _textures: Dictionary = {}

# Dùng để sort instances theo Y (giả lập Y-sort cho MultiMesh)
var _dirty_types: Dictionary = {}  # {type_name: true} — cần rebuild

# === THIẾT LẬP ===
func setup(texture_map: Dictionary):
	_textures = texture_map
	for type_name in texture_map:
		_init_renderer(type_name, texture_map[type_name])

func _init_renderer(type_name: String, texture: Texture2D):
	if not texture:
		push_warning("[MultiMeshRenderer] Null texture for type: " + type_name)
		return
	
	# Tạo MultiMesh với QuadMesh
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data  = false
	mm.instance_count   = INITIAL_POOL_SIZE
	
	# QuadMesh với kích thước texture
	var quad = QuadMesh.new()
	var tex_size = texture.get_size()
	quad.size = tex_size
	mm.mesh = quad
	
	# MultiMeshInstance2D
	var mmi = MultiMeshInstance2D.new()
	mmi.name          = "MMRenderer_" + type_name
	mmi.multimesh     = mm
	mmi.texture       = texture
	mmi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Đẩy tất cả instances ra ngoài màn hình (ẩn ban đầu bằng visible_instance_count)
	mm.visible_instance_count = 0
	add_child(mmi)
	
	_renderers[type_name] = mmi
	_meshes[type_name]    = mm
	_free_slots[type_name] = []
	
	# Pre-fill free slots: Ưu tiên slot thấp trước để visible_instance_count cực nhỏ
	for i in range(INITIAL_POOL_SIZE - 1, -1, -1):
		_free_slots[type_name].append(i)
		# Đặt instance ra ngoài vùng nhìn (về 0,0 để tránh float precision issues ở cực xa)
		mm.set_instance_transform_2d(i, Transform2D(0, Vector2(-99999, -99999)))

# === API CÔNG KHAI ===

## Thêm cây tại vị trí world_pos, trả về slot index (dùng để xóa sau)
func add_tree(type_name: String, world_pos: Vector2, scale_val: float, y_offset: float, chunk_pos: Vector2i) -> int:
	if not _renderers.has(type_name):
		push_warning("[MultiMeshRenderer] Không tìm thấy renderer cho: " + type_name)
		return -1
	
	var mm  = _meshes[type_name]
	var mmi = _renderers[type_name]
	
	# Lấy slot trống
	if _free_slots[type_name].is_empty():
		_grow_pool(type_name)
	var slot = _free_slots[type_name].pop_back()
	
	# Tính toán transform: position + scale
	# Y offset để gốc cây ở đúng vị trí tile
	var tex_h = mmi.texture.get_height() * scale_val if mmi.texture else 0.0
	var actual_pos = world_pos + Vector2(0, y_offset * scale_val)
	
	var xf = Transform2D()
	xf = xf.scaled(Vector2(scale_val, scale_val))
	xf.origin = actual_pos
	mm.set_instance_transform_2d(slot, xf)
	
	# Cập nhật visible count
	var current_visible = mm.visible_instance_count
	mm.visible_instance_count = max(current_visible, slot + 1)
	
	# Đăng ký slot vào chunk
	if not _chunk_slots.has(chunk_pos):
		_chunk_slots[chunk_pos] = {}
	if not _chunk_slots[chunk_pos].has(type_name):
		_chunk_slots[chunk_pos][type_name] = []
	_chunk_slots[chunk_pos][type_name].append(slot)
	
	return slot

## Xóa TẤT CẢ cây của một chunk khi chunk bị unload
func remove_chunk(chunk_pos: Vector2i):
	if not _chunk_slots.has(chunk_pos):
		return
	
	for type_name in _chunk_slots[chunk_pos]:
		var slots = _chunk_slots[chunk_pos][type_name]
		var mm = _meshes.get(type_name)
		if not mm: continue
		
		for slot in slots:
			# Ẩn instance bằng cách đặt ra ngoài màn hình
			mm.set_instance_transform_2d(slot, Transform2D(0, Vector2(-999999, -999999)))
			# Trả slot vào pool để dùng lại
			_free_slots[type_name].append(slot)
	
	_chunk_slots.erase(chunk_pos)

## Kiểm tra loại cây có được hỗ trợ không
func has_type(type_name: String) -> bool:
	return _renderers.has(type_name)

# === NỘI BỘ ===

func _grow_pool(type_name: String):
	var mm = _meshes[type_name]
	var old_count = mm.instance_count
	var new_count = old_count + GROW_STEP
	
	# Cần resize — Godot yêu cầu set instance_count lại (reset visible_instance_count)
	var old_visible = mm.visible_instance_count
	# Lưu lại toàn bộ transforms hiện tại
	var saved_transforms = []
	for i in old_count:
		saved_transforms.append(mm.get_instance_transform_2d(i))
	
	mm.instance_count = new_count
	
	# Khôi phục transforms cũ
	for i in old_count:
		mm.set_instance_transform_2d(i, saved_transforms[i])
	
	# Khởi tạo slots mới
	for i in range(old_count, new_count):
		mm.set_instance_transform_2d(i, Transform2D(0, Vector2(-999999, -999999)))
		_free_slots[type_name].append(i)
	
	mm.visible_instance_count = new_count  # Godot sẽ tự cull nếu transform nằm ngoài frustum
	print("[MultiMeshRenderer] Mở rộng pool %s: %d → %d" % [type_name, old_count, new_count])
