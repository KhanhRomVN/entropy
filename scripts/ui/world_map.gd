extends Control

var noise_terrain: FastNoiseLite
var noise_forest: FastNoiseLite
var noise_river: FastNoiseLite
var noise_temp: FastNoiseLite
var noise_moisture: FastNoiseLite
var noise_biome: FastNoiseLite
var noise_scatter: FastNoiseLite
var player_node: Node2D # Tham chiếu trực tiếp để cập nhật thời gian thực

signal teleport_requested(target_tile_pos: Vector2, expected_biome_name: String)
var _context_menu: PopupMenu
var _last_click_tile: Vector2

@onready var texture_rect: TextureRect = $MapContainer/MapTexture
@onready var player_marker: ColorRect = $MapContainer/PlayerMarker
@onready var coords_label: Label = $CoordsLabel

# THÔNG SỐ BẢN ĐỒ (1280x720 cho độ chính xác cao)
var map_size: Vector2i = Vector2i(1280, 720) 
var view_center: Vector2 = Vector2.ZERO
var view_zoom: float = 1.0 
var move_speed: float = 400.0 
var _last_rendered_img: Image = null # Cache để lấy màu pixel

# CÁC BIẾN QUẢN LÝ ĐA LUỒNG
var _render_thread: Thread
var _render_semaphore: Semaphore = Semaphore.new()
var _render_mutex: Mutex = Mutex.new()
var _exit_thread: bool = false
var _is_rendering: bool = false

# Dữ liệu chia sẻ giữa các luồng
var _thread_view_center: Vector2
var _thread_view_zoom: float

func _ready():
	_render_thread = Thread.new()
	_render_thread.start(_thread_render_loop)
	
	# Cài đặt Player Marker quy mô "To và Đỏ"
	if player_marker:
		player_marker.color = Color.RED
		player_marker.custom_minimum_size = Vector2(16, 16)
		player_marker.pivot_offset = Vector2(8, 8)
		_setup_pulsing_animation()
		
	# Khởi tạo Menu chuột phải
	_context_menu = PopupMenu.new()
	add_child(_context_menu)
	_context_menu.add_item("Dịch chuyển tới đây", 100)
	_context_menu.id_pressed.connect(_on_menu_item_selected)

func _exit_tree():
	_exit_thread = true
	_render_semaphore.post() # Đánh thức để thoát
	if _render_thread:
		_render_thread.wait_to_finish()

func setup(n_t: FastNoiseLite, n_f: FastNoiseLite, n_r: FastNoiseLite, n_temp: FastNoiseLite, n_moist: FastNoiseLite, n_bio: FastNoiseLite, n_scat: FastNoiseLite):
	noise_terrain = n_t
	noise_forest = n_f
	noise_river = n_r
	noise_temp = n_temp
	noise_moisture = n_moist
	noise_biome = n_bio
	noise_scatter = n_scat
	
	# Đảm bảo Texture hiển thị sắc nét khi scale lên
	if texture_rect:
		texture_rect.texture_filter = TEXTURE_FILTER_NEAREST
	
	_render_map()

func _process(delta):
	if !visible: return
	
	# CẬP NHẬT VỊ TRÍ PLAYER THỜI GIAN THỰC
	if player_node and is_instance_valid(player_node):
		# Giả định world_map_manager sẽ gán player_node khi mở map
		# Vì map thường dùng tọa độ ô (Tile), ta convert global_pos sang tile
		var tp = Vector2(player_node.global_position.x / 16.0, player_node.global_position.y / 16.0)
		set_player_pos(tp)
	
	var move_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): move_vec.y -= 1
	if Input.is_key_pressed(KEY_S): move_vec.y += 1
	if Input.is_key_pressed(KEY_A): move_vec.x -= 1
	if Input.is_key_pressed(KEY_D): move_vec.x += 1
	
	if move_vec != Vector2.ZERO:
		view_center += move_vec.normalized() * move_speed * view_zoom * delta
		_render_map()
	
	# CẬP NHẬT THÔNG TIN HOVER BIOME
	_update_hover_info()

func _update_hover_info():
	if !texture_rect or !noise_terrain: return
	
	var m_pos = texture_rect.get_local_mouse_position()
	# Chỉ xử lý nếu chuột nằm trong vùng texture
	if m_pos.x < 0 or m_pos.y < 0 or m_pos.x > texture_rect.size.x or m_pos.y > texture_rect.size.y:
		return
		
	# Chuyển đổi tọa độ chuột -> Tọa độ World (Tile)
	var x_ratio = m_pos.x / texture_rect.size.x
	var y_ratio = m_pos.y / texture_rect.size.y
	
	var start_x = view_center.x - (map_size.x / 2.0) * view_zoom
	var start_y = view_center.y - (map_size.y / 2.0) * view_zoom
	
	var gx = start_x + (x_ratio * map_size.x * view_zoom)
	var gy = start_y + (y_ratio * map_size.y * view_zoom)
	
	# Lấy mẫu Noise
	var n = noise_terrain.get_noise_2d(gx, gy) - 0.1
	var t = noise_temp.get_noise_2d(gx, gy)
	var m = noise_moisture.get_noise_2d(gx, gy)
	var b = (noise_biome.get_noise_2d(gx, gy) + 1.0) / 2.0
	
	var b_name = _get_biome_name(n, t, m, b)
	coords_label.text = "Center: %d, %d | Zoom: %.2f\n[Hover] Tile: (%d, %d) | Biome: %s" % [view_center.x, view_center.y, view_zoom, int(gx), int(gy), b_name]

func _get_biome_name(n_val, t_val, m_val, b_val):
	if n_val < -0.4: return "Biển sâu (Deep Sea)"
	if n_val < -0.32: return "Bờ biển (Beach)"
	
	var is_hot = t_val > 0.3
	var is_dry = m_val < -0.1
	var is_moist = m_val > 0.2
	
	if is_hot:
		if is_dry: return "Sa mạc (Desert)"
		if is_moist: return "Rừng nhiệt đới (Tropical Jungle)"
		return "Savanna"
	else:
		if is_dry: return "Đồng cỏ khô (Dry Steppe)"
		if is_moist: return "Rừng ôn đới (Temperate Forest)"
		if b_val > 0.7: return "Rừng hoa (Flowery Field)"
		return "Đồng cỏ (Plains)"

func _input(event):
	if !visible: return
	
	var ctrl = Input.is_key_pressed(KEY_CTRL)
	
	if event is InputEventMouseButton and ctrl:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_zoom(1.1)
			
	if event is InputEventKey and event.pressed and ctrl:
		if event.keycode == KEY_EQUAL:
			_adjust_zoom(0.8)
		elif event.keycode == KEY_MINUS:
			_adjust_zoom(1.2)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# TÍNH TOÁN TỌA ĐỘ TILE CHÍNH XÁC (Xử lý scale của TextureRect)
		var local_mouse = texture_rect.get_local_mouse_position()
		var texture_scale = texture_rect.size / Vector2(map_size)
		var image_px = local_mouse / texture_scale
		
		# Kẹp trong phạm vi ảnh
		image_px.x = clamp(image_px.x, 0, map_size.x - 1)
		image_px.y = clamp(image_px.y, 0, map_size.y - 1)
		
		var center_px = Vector2(map_size) / 2.0
		var diff_px = image_px - center_px
		
		_last_click_tile = view_center + (diff_px * view_zoom)
		
		# DEBUG: Lấy màu pixel thực tế tại đó
		if _last_rendered_img:
			var pixel_color = _last_rendered_img.get_pixelv(Vector2i(image_px))
			print("[MAP-DEBUG] Right Click at ImgPx: ", Vector2i(image_px), " | Color: ", pixel_color.to_html())
		
		print("[MAP-DEBUG] Calculated Tile: ", _last_click_tile)
		
		_context_menu.position = get_screen_transform() * event.position
		_context_menu.popup()

	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		# Sửa lỗi Drag speed: event.relative cần được scale ngược lại
		var texture_scale = texture_rect.size / Vector2(map_size)
		view_center -= (event.relative / texture_scale) * view_zoom
		_render_map()

func _adjust_zoom(factor: float):
	view_zoom = clamp(view_zoom * factor, 0.1, 100.0)
	_render_map()

# KÍCH HOẠT VẼ (Gửi tín hiệu cho luồng phụ)
func _render_map():
	if !noise_terrain: return
	
	_render_mutex.lock()
	_thread_view_center = view_center
	_thread_view_zoom = view_zoom
	_render_mutex.unlock()
	
	_render_semaphore.post() # Đánh thức worker
	
	# Cập nhật UI ngay lập tức (không lag)
	coords_label.text = "Center: %d, %d | Zoom: %.2f" % [view_center.x, view_center.y, view_zoom]
	_update_player_marker()

# VÒNG LẶP XỬ LÝ TRÊN LUỒNG PHỤ
func _thread_render_loop():
	while true:
		_render_semaphore.wait() # Chờ tín hiệu đầu tiên
		if _exit_thread: break
		
		while _render_semaphore.try_wait():
			pass 
			
		# KHÔNG render nếu Noise chưa được setup (Tránh race condition)
		if noise_terrain == null:
			continue
			
		# Lấy thông số render mới nhất từ Main Thread
		_render_mutex.lock()
		var center = _thread_view_center
		var zoom = _thread_view_zoom
		_render_mutex.unlock()
		
		_render_worker(center, zoom)

func _render_worker(center: Vector2, zoom: float):
	var img = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	var start_x = center.x - (map_size.x / 2.0) * zoom
	var start_y = center.y - (map_size.y / 2.0) * zoom
	
	for y in range(map_size.y):
		if _exit_thread: return # Thoát nhanh nếu game đóng
		for x in range(map_size.x):
			var gx = start_x + (x * zoom)
			var gy = start_y + (y * zoom)
			
			var n_val = noise_terrain.get_noise_2d(gx, gy) - 0.1
			var t_val = noise_temp.get_noise_2d(gx, gy)
			var m_val = noise_moisture.get_noise_2d(gx, gy)
			var b_val = (noise_biome.get_noise_2d(gx, gy) + 1.0) / 2.0
			var f_val = noise_forest.get_noise_2d(gx, gy)
			var s_val = (noise_scatter.get_noise_2d(gx, gy) + 1.0) / 2.0
			
			# River Masking (Sông thưa thớt)
			# Ta dùng noise_biome làm r_mask tạm thời nếu không có noise_river_mask riêng biệt
			var r_mask_val = b_val 
			var watershed_factor = smoothstep(0.4, 0.7, r_mask_val)
			
			var r_noise_val = noise_river.get_noise_2d(gx, gy)
			var coastal_mask = clamp(1.2 - n_val * 4.0, 0.0, 1.0)
			var river_moist_factor = clamp(m_val + 0.5, 0.0, 1.2)
			var river_threshold = (0.02 + (s_val * 0.03)) * coastal_mask * river_moist_factor * watershed_factor
			
			var r_val = 1.0
			if watershed_factor > 0.01 and abs(r_noise_val) < river_threshold and n_val > -0.4:
				r_val = 0.0 # Có sông
			
			img.set_pixel(x, y, _get_color_for_biome(n_val, f_val, r_val, t_val, m_val, b_val, s_val))
	
	# Gửi hình ảnh đã vẽ xong về Main Thread để hiển thị
	call_deferred("_update_at_main_thread", img)

func _update_at_main_thread(img: Image):
	_last_rendered_img = img # Lưu cache cho debug
	var tex = ImageTexture.create_from_image(img)
	texture_rect.texture = tex
	_update_player_marker()

func _get_color_for_biome(n_val: float, f_val: float, r_val: float, t_val: float, m_val: float, b_val: float, s_val: float) -> Color:
	# 1. ĐẠI DƯƠNG & BỜ BIỂN (Sâu -> Cạn -> Cát/Đá)
	if n_val < -0.4:
		return Color("#0b2e46") # Deep Sea
	if n_val < -0.32:
		return Color("#edbb99") # Coast Sand (Cát vàng)
	
	# 2. SÔNG NGÒI
	if r_val == 0.0:
		return Color("#2e86c1") # Fresh Water
		
	# 3. VÙNG ĐẶC BIỆT (Priority High)
	if b_val > 0.95: 
		if n_val < -0.2: return Color("#e67e22") # Lava Orange
		return Color("#424949") # Stone/Volcano Peaks
	if b_val < 0.05: # Tương đương b_val < -0.95 nếu không chuẩn hóa
		return Color("#a9dfbf") # Bamboo Forest
	
	# 4. MA TRẬN KHÍ HẬU (Grass, Forest, Desert)
	var is_hot = t_val > 0.3
	var is_dry = m_val < -0.2
	var is_wet = m_val > 0.3
	
	if is_hot:
		if is_dry: return Color("#d4ac0d") # Desert
		return Color("#145a32") # Jungle (Xanh thẫm)
	else:
		if is_wet: return Color("#1e8449") # Forest
		if is_dry: return Color("#82e0aa") # Savannah
		return Color("#2ecc71") # Plains (Xanh cỏ sáng)
	
	return Color("#2ecc71")

var world_player_pos: Vector2 = Vector2.ZERO

func _update_player_marker():
	if !player_marker: return
	
	player_marker.visible = true
	
	# Tính toán vị trí tương đối của Player so với view_center (đơn vị: Tile)
	var diff = world_player_pos - view_center
	
	# Chuyển đổi từ Tile sang Pixel trên bản đồ (dựa trên view_zoom)
	# map_size mặc định là 640x360. 
	var center_offset = Vector2(map_size) / 2.0
	var screen_pos = center_offset + (diff / view_zoom)
	
	# Cập nhật vị trí UI (Do Anchor là Center nên ta cần căn chỉnh lại position)
	player_marker.position = screen_pos - center_offset
	
	# Kiểm tra xem có nằm ngoài vùng hiển thị của TextureRect không
	if screen_pos.x < 0 or screen_pos.x > map_size.x or screen_pos.y < 0 or screen_pos.y > map_size.y:
		player_marker.visible = false
	else:
		player_marker.visible = true

func _on_menu_item_selected(id: int):
	print("[MAP-DEBUG] Menu Item Selected ID: ", id)
	if id == 100: # Teleport
		# Tính toán Biome dự kiến từ Map trước khi dịch chuyển
		var n = noise_terrain.get_noise_2d(_last_click_tile.x, _last_click_tile.y) - 0.1
		var t = noise_temp.get_noise_2d(_last_click_tile.x, _last_click_tile.y)
		var m = noise_moisture.get_noise_2d(_last_click_tile.x, _last_click_tile.y)
		var b = (noise_biome.get_noise_2d(_last_click_tile.x, _last_click_tile.y) + 1.0) / 2.0
		var b_name = _get_biome_name(n, t, m, b)
		
		print("[MAP-DEBUG] Emitting teleport_requested to: ", _last_click_tile, " | Biome: ", b_name)
		teleport_requested.emit(_last_click_tile, b_name)

func set_player_pos(world_pos: Vector2):
	world_player_pos = world_pos
	_update_player_marker()

func _setup_pulsing_animation():
	var tween = create_tween().set_loops()
	tween.tween_property(player_marker, "scale", Vector2(1.5, 1.5), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(player_marker, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
	
	# Chấm đỏ hiện tại đang là ColorRect, hiệu ứng Pulse Scale đã đủ để gây ấn tượng.
	
	# Nếu nó là ColorRect, ta có thể đổi node type hoặc vẽ thêm.
	# Để đơn giản và "Wow", tôi sẽ dùng draw_circle nếu player_marker là Control
