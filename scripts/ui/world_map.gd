extends Control

var noise_terrain: FastNoiseLite
var noise_forest: FastNoiseLite
var noise_river: FastNoiseLite
var noise_temp: FastNoiseLite
var noise_moisture: FastNoiseLite
var noise_biome: FastNoiseLite
var noise_scatter: FastNoiseLite

@onready var texture_rect: TextureRect = $MapContainer/MapTexture
@onready var player_marker: ColorRect = $MapContainer/PlayerMarker
@onready var coords_label: Label = $CoordsLabel

# THÔNG SỐ BẢN ĐỒ
var map_size: Vector2i = Vector2i(640, 360) 
var view_center: Vector2 = Vector2.ZERO
var view_zoom: float = 1.0 
var move_speed: float = 300.0

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
	_render_map()

func _process(delta):
	if !visible: return
	
	var move_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): move_vec.y -= 1
	if Input.is_key_pressed(KEY_S): move_vec.y += 1
	if Input.is_key_pressed(KEY_A): move_vec.x -= 1
	if Input.is_key_pressed(KEY_D): move_vec.x += 1
	
	if move_vec != Vector2.ZERO:
		view_center += move_vec.normalized() * move_speed * view_zoom * delta
		_render_map()

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

	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		view_center -= event.relative * view_zoom
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
		_render_semaphore.wait() # Chờ tín hiệu
		if _exit_thread: break
		
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
			
			var n_val = noise_terrain.get_noise_2d(gx, gy) - 0.35
			var f_val = noise_forest.get_noise_2d(gx, gy)
			
			var t_val = noise_temp.get_noise_2d(gx, gy)
			var m_val = noise_moisture.get_noise_2d(gx, gy)
			var b_val = noise_biome.get_noise_2d(gx, gy)
			var s_val = (noise_scatter.get_noise_2d(gx, gy) + 1.0) / 2.0
			
			var r_noise_val = noise_river.get_noise_2d(gx, gy)
			var coastal_mask = clamp(1.0 - n_val * 2.5, 0.0, 1.0)
			var river_moist_factor = clamp(m_val + 0.4, 0.0, 1.0)
			var river_threshold = (0.03 + (s_val * 0.04)) * coastal_mask * river_moist_factor
			
			var r_val = 1.0
			if abs(r_noise_val) < river_threshold and n_val > -0.4:
				r_val = 0.0
			
			img.set_pixel(x, y, _get_color_for_biome(n_val, f_val, r_val, t_val, m_val, b_val, s_val))
	
	# Gửi hình ảnh đã vẽ xong về Main Thread để hiển thị
	call_deferred("_update_at_main_thread", img)

func _update_at_main_thread(img: Image):
	var tex = ImageTexture.create_from_image(img)
	texture_rect.texture = tex
	_update_player_marker()

func _get_color_for_biome(n_val: float, f_val: float, r_val: float, t_val: float, m_val: float, b_val: float, s_val: float) -> Color:
	# 1. ĐẠI DƯƠNG & BỜ BIỂN
	if n_val < -0.4:
		return Color("#0b2e46") # Deep Sea (Cực thẫm)
	if n_val < -0.32:
		return Color("#edbb99") # Coast Sand
	
	# 2. SÔNG NGÒI (Natural Rivers)
	var river_moist_factor = clamp(m_val + 0.4, 0.0, 1.0)
	var river_width_base = 0.03 + (s_val * 0.04)
	var dynamic_river_threshold = river_width_base * river_moist_factor
	
	if abs(r_val) < dynamic_river_threshold and n_val > -0.4:
		return Color("#2e86c1") # Fresh Water
	
	# 3. MA TRẬN KHÍ HẬU
	var is_cold = t_val < -0.2
	var is_hot = t_val > 0.3
	var is_dry = m_val < -0.2
	var is_wet = m_val > 0.3
	
	if is_cold:
		if is_dry: return Color("#f7f9f9") # Snow
		return Color("#1d8348") # Taiga
	elif is_hot:
		if is_dry: return Color("#d4ac0d") # Desert
		return Color("#145a32") # Jungle
	else:
		if is_wet: return Color("#1e8449") # Forest
		if is_dry: return Color("#82e0aa") # Savannah
		return Color("#2ecc71") # Plains
	
	# 4. ĐỊA HÌNH ĐẶC BIỆT
	if b_val > 0.95: 
		if n_val < -0.2: return Color("#e67e22") # Lava Orange
		return Color("#424949") # Stone/Volcano
	if b_val < -0.95: return Color("#a9dfbf") # Bamboo
	
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

func set_player_pos(world_pos: Vector2):
	world_player_pos = world_pos
	_update_player_marker()
