extends Control

var noise_terrain: FastNoiseLite
var noise_forest: FastNoiseLite
var noise_river: FastNoiseLite
var noise_temp: FastNoiseLite
var noise_moisture: FastNoiseLite
var noise_biome: FastNoiseLite
var noise_scatter: FastNoiseLite
var noise_warp: FastNoiseLite
var noise_giant: FastNoiseLite
var noise_filter: FastNoiseLite
var noise_fault: FastNoiseLite

var world_limit: int = 2000 # Kích thước map cứng
var continent_radius: float = 0.65
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

func setup(n_t: FastNoiseLite, n_f: FastNoiseLite, n_r: FastNoiseLite, n_temp: FastNoiseLite, n_moist: FastNoiseLite, n_bio: FastNoiseLite, n_scat: FastNoiseLite, n_warp: FastNoiseLite, n_giant: FastNoiseLite, n_filt: FastNoiseLite, n_fault: FastNoiseLite, limit: int = 2000, radius: float = 0.55):
	noise_terrain = n_t
	noise_forest = n_f
	noise_river = n_r
	noise_temp = n_temp
	noise_moisture = n_moist
	noise_biome = n_bio
	noise_scatter = n_scat
	noise_warp = n_warp
	noise_giant = n_giant
	noise_filter = n_filt
	noise_fault = n_fault
	
	world_limit = limit
	continent_radius = radius
	
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
	
	var cur_gx = start_x + (x_ratio * map_size.x * view_zoom)
	var cur_gy = start_y + (y_ratio * map_size.y * view_zoom)
	
	# Áp dụng logic Continental Mask V17
	var giant_val = noise_giant.get_noise_2d(cur_gx, cur_gy)
	var gpos_f = Vector2(cur_gx, cur_gy)
	var raw_d = gpos_f.length()
	var max_dist = (world_limit / 2.0) * continent_radius
	
	# Parity Fault centers
	var seed_f = float(noise_terrain.seed)
	var fault_angle_1 = fmod(seed_f * 0.618033, TAU)
	var fault_angle_2 = fault_angle_1 + PI + (fmod(seed_f * 0.333, 0.6) - 0.3)
	var fault_r1 = max_dist * (0.60 + fmod(seed_f * 0.271, 0.25))
	var fault_r2 = max_dist * (0.60 + fmod(seed_f * 0.137, 0.25))
	var fault_center_1 = Vector2(cos(fault_angle_1), sin(fault_angle_1)) * fault_r1
	var fault_center_2 = Vector2(cos(fault_angle_2), sin(fault_angle_2)) * fault_r2
	
	# Parity Island centers
	var isl_angle_1 = fault_angle_1 + (fmod(seed_f * 0.159, 0.5) - 0.25)
	var isl_dist_1  = max_dist * (0.95 + fmod(seed_f * 0.113, 0.20))
	var isl_center_1 = Vector2(cos(isl_angle_1), sin(isl_angle_1)) * isl_dist_1
	var isl_radius_1 = max_dist * 0.22
	
	var isl_angle_2 = fault_angle_2 + (fmod(seed_f * 0.271, 0.5) - 0.25)
	# [NEW] North-West to North-East Bulge & Solidifier (Parity with generator)
	var angle = atan2(cur_gy, cur_gx)
	
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
	
	var ne_target = -PI/4.0
	var ne_diff = abs(angle - ne_target)
	if ne_diff > PI: ne_diff = TAU - ne_diff
	var ne_factor = smoothstep(PI/2.5, 0.0, ne_diff) 
	
	var n_target = -PI/2.0
	var n_diff = abs(angle - n_target)
	if n_diff > PI: n_diff = TAU - n_diff
	var is_north = smoothstep(PI/1.5, 0.0, n_diff) 
	
	var ne_bulge = 1.0 + (ne_factor * 0.3)
	var se_bulge = 1.0 + (se_bias_f * 0.35)
	var east_bulge = 1.0 + (east_factor * 0.2)
	# [V20] Giảm kích thước lục địa linh hoạt (kéo SE ra xa hơn)
	var local_max_dist = max_dist * ne_bulge * se_bulge * east_bulge * 0.86

	# Warp biên độ: Phá vỡ sự mượt mà trên toàn bộ chu vi lục địa
	var warp_mult = 1.0 + (west_factor * 0.5) + (nw_bias_f * 0.45) + (ne_factor * 0.4) + (se_bias_f * 0.35) - (east_factor * 0.05)
	var wx = noise_warp.get_noise_2d(cur_gx, cur_gy) * 240.0 * warp_mult
	var wy = noise_warp.get_noise_2d(cur_gy + 500, cur_gx + 500) * 240.0 * warp_mult
	var warped_pos = Vector2(cur_gx + wx, cur_gy + wy)
	
	# Nhấp nhô macro
	var macro_warp_w = noise_warp.get_noise_2d(cur_gx * 0.002, cur_gy * 0.002) * 125.0 * west_factor
	var macro_warp_nw = noise_warp.get_noise_2d(cur_gx * 0.003, cur_gy * 0.003) * 130.0 * nw_bias_f
	var macro_warp_ne = noise_warp.get_noise_2d(cur_gx * 0.0035, cur_gy * 0.0035 + 100) * 140.0 * ne_factor
	var macro_warp_se = noise_warp.get_noise_2d(cur_gx * 0.004, cur_gy * 0.004 + 200) * 135.0 * se_bias_f
	var macro_bump = noise_warp.get_noise_2d(cur_gx * 0.005, cur_gy * 0.005) * 45.0 * is_north
	
	var global_annoyance = noise_warp.get_noise_2d(cur_gx * 0.001, cur_gy * 0.001) * 60.0
	
	var radius_distort = 1.0 + (noise_giant.get_noise_2d(cur_gx, cur_gy) * (1.2 - east_factor * 0.35))
	var dist = (warped_pos.length() + macro_bump + macro_warp_w + macro_warp_nw + macro_warp_ne + macro_warp_se + global_annoyance) * radius_distort
	dist += noise_warp.get_noise_2d(cur_gx * 2.5, cur_gy * 2.5) * 16.0 * warp_mult
	
	var falloff = 1.0
	if dist > local_max_dist * 0.55:
		falloff = smoothstep(local_max_dist, local_max_dist * 0.55, dist)
	
	var border_warp  = noise_warp.get_noise_2d(cur_gx * 0.003, cur_gy * 0.003) * local_max_dist * (0.12 + west_factor * 0.08)
	var border_warp2 = noise_giant.get_noise_2d(cur_gx * 0.0015, cur_gy * 0.0015) * local_max_dist * 0.08
	var warped_raw_dist = raw_d + border_warp + border_warp2
	var absolute_cutoff = smoothstep(local_max_dist * 1.15, local_max_dist * 0.80, warped_raw_dist)
	var base_mask = falloff * absolute_cutoff
	
	# Fault
	var shore_factor = smoothstep(0.0, 0.35, base_mask) * smoothstep(0.85, 0.45, base_mask)
	shore_factor *= (1.0 - ne_factor * 0.8)
	shore_factor *= (1.0 - east_factor * 0.6)
	shore_factor *= (1.0 - sw_bias_f * 0.4) # [V21] Giảm vỡ nát SW
	
	var d1 = gpos_f.distance_to(fault_center_1)
	var fault_noise_1 = noise_fault.get_noise_2d(cur_gx * 0.004, cur_gy * 0.004) * 0.4 + 1.0
	var fault_width_1 = local_max_dist * 0.18 * fault_noise_1
	var fault_cut_1 = smoothstep(fault_width_1, fault_width_1 * 0.1, d1) * 0.70 * shore_factor
	var d2 = gpos_f.distance_to(fault_center_2)
	var fault_noise_2 = noise_fault.get_noise_2d(cur_gx * 0.004 + 333, cur_gy * 0.004 + 333) * 0.4 + 1.0
	var fault_width_2 = local_max_dist * 0.16 * fault_noise_2
	var fault_cut_2 = smoothstep(fault_width_2, fault_width_2 * 0.1, d2) * 0.65 * shore_factor
	var combined_fault_cut = maxf(fault_cut_1, fault_cut_2)
	
	var is_outside = abs(cur_gx) > world_limit/2.0 or abs(cur_gy) > world_limit/2.0
	var n = noise_terrain.get_noise_2d(cur_gx, cur_gy)
	
	if is_outside:
		n = -1.0
	else:
		n = (n + 0.40) * base_mask - 0.95 * (1.0 - base_mask)
		n -= combined_fault_cut
		if base_mask > 0.65 and n < -0.32 and combined_fault_cut < 0.2:
			n = n + (base_mask - 0.65) * 2.0
			if n < -0.31: n = -0.31
			
	# [V21] Thêm hòn đảo siêu nhỏ rải rác xung quanh TOÀN BỘ lục địa
	var isl_contrib = 0.0
	if base_mask < 0.12:
		var tiny_isl_noise = (noise_filter.get_noise_2d(cur_gx * 0.02, cur_gy * 0.02) + 1.0) * 0.5
		if tiny_isl_noise > 0.988: 
			var tiny_h = (tiny_isl_noise - 0.988) / 0.012
			isl_contrib = maxf(isl_contrib, tiny_h * 0.75)
		
	if isl_contrib > 0.0:
		n = n + isl_contrib * 0.9
	
	# Biome Jittering V17
	var jitter_val = noise_warp.get_noise_2d(cur_gx * 4.0, cur_gy * 4.0) * 0.25
	var norm_lat = clamp(cur_gy / max_dist, -1.0, 1.0)
	var polar_factor = smoothstep(0.5, 1.0, abs(norm_lat))
	var latitude_bias = -(polar_factor * polar_factor) * 0.3 + 0.08
	
	# Khí hậu cơ bản
	var t = noise_temp.get_noise_2d(cur_gx, cur_gy) + latitude_bias + jitter_val
	
	# Áp dụng Bias Nhiệt độ & Độ ẩm
	t += se_bias_f * 0.6 # [V21] Nóng SE (Giảm nhẹ)
	t -= nw_bias_f * 0.65
	t -= sw_bias_f * 0.15
	
	var m = noise_moisture.get_noise_2d(cur_gx, cur_gy) + (jitter_val * -0.6)
	m += sw_bias_f * 0.45
	m -= (se_bias_f * 0.2) * (1.0 - m)
	m -= smoothstep(0.0, 0.35, combined_fault_cut * 0.35)
	
	# River Logic (Parity)
	var r_val = 1.0
	if n > -0.1 and n < 0.45:
		var h_right_r = noise_terrain.get_noise_2d(cur_gx + 3.0, cur_gy)
		var h_down_r  = noise_terrain.get_noise_2d(cur_gx, cur_gy + 3.0)
		var grad_x = h_right_r - noise_terrain.get_noise_2d(cur_gx, cur_gy)
		var grad_y = h_down_r  - noise_terrain.get_noise_2d(cur_gx, cur_gy)
		var flow_proj = noise_river.get_noise_2d(cur_gx + grad_x * 120.0, cur_gy + grad_y * 120.0)
		
		var t_bias_abs = abs(t)
		var climate_filter = smoothstep(0.4, 0.9, t_bias_abs)
		var river_boost = sw_bias_f * 0.45
		var r_diff = 1.0 + (climate_filter * 8.0)
		
		var m_thr = (0.038 + river_boost * 0.015) / r_diff * clamp(m + 0.8, 0.3, 1.5)
		var b_thr = (0.012 + river_boost * 0.008) / (r_diff * 1.5) * clamp(m + 0.5, 0.1, 1.0)
		
		if abs(flow_proj) < m_thr: r_val = 0.0
		elif abs(noise_river.get_noise_2d(cur_gx, cur_gy)) < b_thr: r_val = 0.5
	
	var b = (noise_biome.get_noise_2d(cur_gx, cur_gy) + 1.0) / 2.0
	
	var b_name = _get_biome_name(n, t, m, b, r_val, gpos_f)
	coords_label.text = "Center: %d, %d | Zoom: %.2f\n[Hover] Tile: (%d, %d) | Biome: %s" % [view_center.x, view_center.y, view_zoom, int(cur_gx), int(cur_gy), b_name]

func _get_biome_name(n_val, t_val, m_val, b_val, r_val = 1.0, gpos = Vector2.ZERO):
	if n_val < -0.4: return "Biển sâu (Deep Sea)"
	if n_val < -0.32: return "Bờ biển (Beach)"
	if r_val == 0.0: return "Sông (River)"
	if r_val == 0.5: return "Suối (Stream)"
	
	# 2. VÙNG ĐẶC BIỆT (Priority High)
	var v_center = Vector2(250, -250)
	var v_warp = noise_warp.get_noise_2d(gpos.x * 2.5, gpos.y * 2.5) * 80.0
	var dist_v = gpos.distance_to(v_center) + v_warp
	
	var v_mask = smoothstep(400.0, 50.0, dist_v)
	var v_final = b_val * 0.4 + v_mask * 0.7
	
	# Hồ dung nham cũng uốn lượn (Tầm nhìn nhỏ hơn: 50)
	var l_warp = noise_warp.get_noise_2d(gpos.x * 5.0, gpos.y * 5.0) * 25.0
	if (gpos.distance_to(v_center) + l_warp) < 50.0: return "Núi lửa (Volcano)" 
	
	if v_final > 0.8: return "Núi lửa (Volcano)"
	if b_val < 0.15: return "Rừng tre (Bamboo Forest)"
	var is_wet = m_val > 0.3
	
	var is_hot = t_val > 0.3
	var is_cold = t_val < -0.45
	var is_dry = m_val < -0.2
	
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
			
			# HỆ THỐNG LỤC ĐỊA TRUNG TÂM (CONTINENTAL MASK V7) - AMOEBA LANDMASS
			var giant_val = noise_giant.get_noise_2d(gx, gy)
			
			# === V17 RENDER PARITY (khớp với _thread_generate_noise) ===
			var gpos_f = Vector2(gx, gy)
			var raw_d = gpos_f.length()
			var max_dist = (world_limit / 2.0) * continent_radius
			
			# Fault centers (parity)
			var seed_f = float(noise_terrain.seed)
			var fault_angle_1 = fmod(seed_f * 0.618033, TAU)
			var fault_angle_2 = fault_angle_1 + PI + (fmod(seed_f * 0.333, 0.6) - 0.3)
			var fault_r1 = max_dist * (0.60 + fmod(seed_f * 0.271, 0.25))
			var fault_r2 = max_dist * (0.60 + fmod(seed_f * 0.137, 0.25))
			var fault_center_1 = Vector2(cos(fault_angle_1), sin(fault_angle_1)) * fault_r1
			var fault_center_2 = Vector2(cos(fault_angle_2), sin(fault_angle_2)) * fault_r2
			
			# Island centers (parity)
			var isl_angle_1 = fault_angle_1 + (fmod(seed_f * 0.159, 0.5) - 0.25)
			var isl_dist_1  = max_dist * (0.95 + fmod(seed_f * 0.113, 0.20))
			
			# [NEW] North-West to North-East Bulge & Solidifier (Parity with generator)
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
			
			var ne_target = -PI/4.0
			var ne_diff = abs(angle - ne_target)
			if ne_diff > PI: ne_diff = TAU - ne_diff
			var ne_factor = smoothstep(PI/2.5, 0.0, ne_diff) 
			
			var n_target = -PI/2.0
			var n_diff = abs(angle - n_target)
			if n_diff > PI: n_diff = TAU - n_diff
			var is_north = smoothstep(PI/1.5, 0.0, n_diff) 
			
			var ne_bulge = 1.0 + (ne_factor * 0.3)
			var se_bulge = 1.0 + (se_bias_f * 0.35)
			var east_bulge = 1.0 + (east_factor * 0.2)
			# [V20] Giảm kích thước lục địa linh hoạt (kéo SE ra xa hơn)
			var local_max_dist = max_dist * ne_bulge * se_bulge * east_bulge * 0.86

			# Warp biên độ: Phá vỡ sự mượt mà trên toàn bộ chu vi lục địa
			var warp_mult = 1.0 + (west_factor * 0.5) + (nw_bias_f * 0.45) + (ne_factor * 0.4) + (se_bias_f * 0.35) - (east_factor * 0.05)
			var wx = noise_warp.get_noise_2d(gx, gy) * 240.0 * warp_mult
			var wy = noise_warp.get_noise_2d(gy + 500, gx + 500) * 240.0 * warp_mult
			
			# Continental mask
			var warped_pos = Vector2(gx + wx, gy + wy)
			
			# Nhấp nhô macro
			var macro_warp_w = noise_warp.get_noise_2d(gx * 0.002, gy * 0.002) * 125.0 * west_factor
			var macro_warp_nw = noise_warp.get_noise_2d(gx * 0.003, gy * 0.003) * 130.0 * nw_bias_f
			var macro_warp_ne = noise_warp.get_noise_2d(gx * 0.0035, gy * 0.0035 + 100) * 140.0 * ne_factor
			var macro_warp_se = noise_warp.get_noise_2d(gx * 0.004, gy * 0.004 + 200) * 135.0 * se_bias_f
			var macro_bump = noise_warp.get_noise_2d(gx * 0.005, gy * 0.005) * 45.0 * is_north
			
			var global_annoyance = noise_warp.get_noise_2d(gx * 0.001, gy * 0.001) * 60.0
			
			var radius_distort = 1.0 + (giant_val * (1.2 - east_factor * 0.35))
			var dist = (warped_pos.length() + macro_bump + macro_warp_w + macro_warp_nw + macro_warp_ne + macro_warp_se + global_annoyance) * radius_distort
			dist += noise_warp.get_noise_2d(gx * 2.5, gy * 2.5) * 16.0 * warp_mult
			var falloff = 1.0
			if dist > local_max_dist * 0.55:
				falloff = smoothstep(local_max_dist, local_max_dist * 0.55, dist)
			
			var border_warp  = noise_warp.get_noise_2d(gx * 0.003, gy * 0.003) * local_max_dist * (0.12 + west_factor * 0.08)
			var border_warp2 = noise_giant.get_noise_2d(gx * 0.0015, gy * 0.0015) * local_max_dist * 0.08
			var warped_raw_dist = raw_d + border_warp + border_warp2
			var absolute_cutoff = smoothstep(local_max_dist * 1.15, local_max_dist * 0.80, warped_raw_dist)
			var base_mask = falloff * absolute_cutoff
			
			# Fault
			var shore_factor = smoothstep(0.0, 0.35, base_mask) * smoothstep(0.85, 0.45, base_mask)
			shore_factor *= (1.0 - ne_factor * 0.8)
			shore_factor *= (1.0 - east_factor * 0.6)
			shore_factor *= (1.0 - sw_bias_f * 0.4) # [V21] Giảm vỡ nát SW
			
			var d1 = gpos_f.distance_to(fault_center_1)
			var fault_noise_1 = noise_fault.get_noise_2d(gx * 0.004, gy * 0.004) * 0.4 + 1.0
			var fault_width_1 = local_max_dist * 0.18 * fault_noise_1
			var fault_cut_1 = smoothstep(fault_width_1, fault_width_1 * 0.1, d1) * 0.70 * shore_factor
			var d2 = gpos_f.distance_to(fault_center_2)
			var fault_noise_2 = noise_fault.get_noise_2d(gx * 0.004 + 333, gy * 0.004 + 333) * 0.4 + 1.0
			var fault_width_2 = local_max_dist * 0.16 * fault_noise_2
			var fault_cut_2 = smoothstep(fault_width_2, fault_width_2 * 0.1, d2) * 0.65 * shore_factor
			var combined_fault_cut = maxf(fault_cut_1, fault_cut_2)
			
			var is_outside = abs(gx) > world_limit/2.0 or abs(gy) > world_limit/2.0
			var n_val = noise_terrain.get_noise_2d(gx, gy)
			if is_outside:
				n_val = -1.0
			else:
				n_val = (n_val + 0.40) * base_mask - 0.95 * (1.0 - base_mask)
				n_val -= combined_fault_cut
				if base_mask > 0.65 and n_val < -0.32 and combined_fault_cut < 0.2:
					n_val = n_val + (base_mask - 0.65) * 2.0
					if n_val < -0.31: n_val = -0.31
			
			# Islands (V18: Removed large islands)
			var isl_contrib = 0.0
			
			# [V21] Thêm các hòn đảo siêu nhỏ rải rác xung quanh TOÀN BỘ lục địa
			if base_mask < 0.12:
				var tiny_isl_noise = (noise_filter.get_noise_2d(gx * 0.02, gy * 0.02) + 1.0) * 0.5
				if tiny_isl_noise > 0.988: 
					var tiny_h = (tiny_isl_noise - 0.988) / 0.012
					isl_contrib = maxf(isl_contrib, tiny_h * 0.75)
					
			if isl_contrib > 0.0:
				n_val = n_val + isl_contrib * 0.9
			
			var jitter_val = noise_warp.get_noise_2d(gx * 4.0, gy * 4.0) * 0.25
			var norm_lat = clamp(gy / max_dist, -1.0, 1.0)
			var polar_factor = smoothstep(0.5, 1.0, abs(norm_lat))
			var lat_bias = -(polar_factor * polar_factor) * 0.3 + 0.08
			var t_val = noise_temp.get_noise_2d(gx, gy) + lat_bias + jitter_val
			t_val += se_bias_f * 0.6 # [V21] Nóng SE (Giảm nhẹ)
			t_val -= nw_bias_f * 0.65
			t_val -= sw_bias_f * 0.15
			
			var m_val = noise_moisture.get_noise_2d(gx, gy) + (jitter_val * -0.6)
			m_val += sw_bias_f * 0.45
			m_val -= (se_bias_f * 0.2) * (1.0 - m_val)
			m_val -= clamp(combined_fault_cut * 0.35, 0.0, 0.35)
			
			# River Logic (Parity)
			var r_val = 1.0
			if n_val > -0.1 and n_val < 0.45:
				var h_right_m = noise_terrain.get_noise_2d(gx + 3.0, gy)
				var h_down_m  = noise_terrain.get_noise_2d(gx, gy + 3.0)
				var grad_x = h_right_m - n_val
				var grad_y = h_down_m  - n_val
				var flow_m = noise_river.get_noise_2d(gx + grad_x * 120.0, gy + grad_y * 120.0)
				
				var t_bias_abs = abs(t_val)
				var climate_filter = smoothstep(0.4, 0.9, t_bias_abs)
				var river_boost = sw_bias_f * 0.45
				var r_diff = 1.0 + (climate_filter * 8.0)
				
				var m_thr = (0.038 + river_boost * 0.015) / r_diff * clamp(m_val + 0.8, 0.3, 1.5)
				var b_thr = (0.012 + river_boost * 0.008) / (r_diff * 1.5) * clamp(m_val + 0.5, 0.1, 1.0)
				
				if abs(flow_m) < m_thr:
					r_val = 0.0 # River
				elif abs(noise_river.get_noise_2d(gx, gy)) < b_thr:
					r_val = 0.5 # Stream
			
			var b_val = (noise_biome.get_noise_2d(gx, gy) + 1.0) / 2.0
			var f_val = noise_forest.get_noise_2d(gx, gy)
			var s_val = (noise_scatter.get_noise_2d(gx, gy) + 1.0) / 2.0
			
			var pixel_color = _get_color_for_biome(n_val, f_val, r_val, t_val, m_val, b_val, s_val, Vector2(gx, gy))
			
			# Equator line đã bị tắt (gây cắt đôi lục địa)
			# if abs(gy) < (zoom * 1.5):
			# 	var eq_color = Color(1.0, 1.0, 1.0, 0.45) # Trắng mờ
			# 	pixel_color = pixel_color.lerp(eq_color, 0.35)
				
			img.set_pixel(x, y, pixel_color)
	
	# Gửi hình ảnh đã vẽ xong về Main Thread để hiển thị
	call_deferred("_update_at_main_thread", img)

func _update_at_main_thread(img: Image):
	_last_rendered_img = img # Lưu cache cho debug
	var tex = ImageTexture.create_from_image(img)
	texture_rect.texture = tex
	_update_player_marker()

func _get_color_for_biome(n_val: float, f_val: float, r_val: float, t_val: float, m_val: float, b_val: float, s_val: float, gpos: Vector2 = Vector2.ZERO) -> Color:
	# 1. ĐẠI DƯƠNG & BỜ BIỂN (Sâu -> Cạn -> Cát/Đá)
	if n_val < -0.4:
		return Color("#0b2e46") # Deep Sea
	if n_val < -0.32:
		return Color("#edbb99") # Coast Sand (Cát vàng)
	
	# 2. SÔNG NGÒI
	if r_val == 0.0:
		return Color("#2e86c1") # Fresh Water
		
	# 3. VÙNG ĐẶC BIỆT (Priority High)
	var v_center = Vector2(250, -250)
	var v_warp = noise_warp.get_noise_2d(gpos.x * 2.5, gpos.y * 2.5) * 80.0
	var dist_v = gpos.distance_to(v_center) + v_warp
	
	var v_mask = smoothstep(400.0, 50.0, dist_v)
	var v_final = b_val * 0.4 + v_mask * 0.7

	# Hồ dung nham trung tâm (Warped)
	var l_warp = noise_warp.get_noise_2d(gpos.x * 5.0, gpos.y * 5.0) * 25.0
	if (gpos.distance_to(v_center) + l_warp) < 50.0:
		return Color("#ff4500") 
		
	if v_final > 0.8: 
		if n_val < -0.15: return Color("#ff4500") # Lava Orange (Dung nham rực sáng)
		return Color("#1a1a1a") # Black Bazan (Đất đá đen núi lửa)
	if b_val < 0.15: 
		return Color("#a9dfbf") # Bamboo Forest
	
	# 4. MA TRẬN KHÍ HẬU (Snow, Grass, Forest, Desert)
	var is_hot = t_val > 0.3
	var is_cold = t_val < -0.45
	var is_dry = m_val < -0.2
	var is_wet = m_val > 0.3
	
	if is_cold:
		return Color("#ffffff") # Pure Snow White
		
	if is_hot:
		if is_dry: return Color("#c2a020") # Desert — vàng cát rõ hơn
		if is_wet: return Color("#145a32") # Jungle (Xanh thẫm)
		return Color("#8db87a")            # Savannah nhiệt đới
	else:
		if is_wet: return Color("#1e8449") # Forest
		if is_dry: return Color("#82e0aa") # Steppe khô
		return Color("#2ecc71")            # Plains
	
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
		var b_name = _get_biome_name(n, t, m, b, 1.0, _last_click_tile)
		
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
