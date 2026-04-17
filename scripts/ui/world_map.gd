# scripts/ui/world_map.gd
# V2.0 — Dùng WorldShapeEngine để render bản đồ chính xác
# Bản đồ giờ hiển thị đúng hình dạng lục địa từ polygon template
extends Control

# ═══════════════════════════════════════════════════════════════
# BLUEPRINT REFERENCES (set từ infinite_map_generator)
# ═══════════════════════════════════════════════════════════════
var shape_engine: WorldShapeEngine = null
var continent_type: String = "pangaea"

# Noise chi tiết (vẫn cần cho river, forest trên bản đồ)
var noise_detail: FastNoiseLite
var noise_forest: FastNoiseLite
var noise_river: FastNoiseLite
var noise_warp: FastNoiseLite

# Compat với code cũ (world_map setup từ toggle_world_map cũ)
var noise_terrain: FastNoiseLite
var noise_temp: FastNoiseLite
var noise_moisture: FastNoiseLite
var noise_biome: FastNoiseLite
var noise_scatter: FastNoiseLite
var noise_giant: FastNoiseLite
var noise_filter: FastNoiseLite
var noise_fault: FastNoiseLite

var world_limit: int = 2000
var continent_radius: float = 0.55
var player_node: Node2D
var orchestrator: Node2D
var world_seed: int = 0

signal teleport_requested(target_tile_pos: Vector2, expected_biome_name: String)

var _context_menu: PopupMenu
var _last_click_tile: Vector2

@onready var texture_rect: TextureRect = $HBox/MapArea/MapContainer/MapTexture
@onready var coords_label: Label = $CoordsLabel # Giữ lại cho compat nhưng sẽ ẩn

# Sidebar Nodes
@onready var val_x: Label = $HBox/Sidebar/Margin/VBox/TileInfo/Grid/val_x
@onready var val_y: Label = $HBox/Sidebar/Margin/VBox/TileInfo/Grid/val_y
@onready var val_bio: Label = $HBox/Sidebar/Margin/VBox/TileInfo/Grid/val_bio
@onready var val_elev: Label = $HBox/Sidebar/Margin/VBox/TileInfo/Grid/val_elev
@onready var val_seed: Label = $HBox/Sidebar/Margin/VBox/WorldStats/Grid/val_seed
@onready var val_type: Label = $HBox/Sidebar/Margin/VBox/WorldStats/Grid/val_type
@onready var legend_list: VBoxContainer = $HBox/Sidebar/Margin/VBox/LegendPanel/LegendScroll/LegendList

# Minimap Nodes
@onready var minimap_texture: TextureRect = $HBox/MapArea/MinimapWrap/MinimapTexture
@onready var viewport_box: ReferenceRect = $HBox/MapArea/MinimapWrap/ViewportBox
@onready var player_marker: Panel = $HBox/MapArea/MapContainer/MapTexture/PlayerMarker

var map_size: Vector2i = Vector2i(1030, 720) # Kích thước vùng MapArea (1280 - 250 sidebar)
var render_size: Vector2i = Vector2i(512, 512) # GIẢM TIẾP (512x512) để đạt tốc độ render tức thời (< 5 giây)
var view_center: Vector2 = Vector2.ZERO
var view_zoom: float = 1.0
var move_speed: float = 600.0
var _last_rendered_img: Image = null
var _minimap_img: Image = null
var _is_fully_rendered: bool = false

var _render_thread: Thread
var _render_semaphore: Semaphore = Semaphore.new()
var _render_mutex: Mutex = Mutex.new()
var _exit_thread: bool = false

var _thread_view_center: Vector2
var _thread_view_zoom: float
var _render_pending: bool = false
var _last_render_time: float = 0.0
var _render_cooldown: float = 0.1 # Chỉ render tối đa 10 FPS

# ═══════════════════════════════════════════════════════════════
# SETUP MỚI — Nhận WorldShapeEngine
# ═══════════════════════════════════════════════════════════════
func setup_blueprint(
	_shape_engine: WorldShapeEngine,
	_continent_type: String,
	_detail: FastNoiseLite,
	_forest: FastNoiseLite,
	_river: FastNoiseLite,
	_warp: FastNoiseLite,
	_world_limit: int,
	_world_seed: int
):
	shape_engine   = _shape_engine
	continent_type = _continent_type
	noise_detail   = _detail
	noise_forest   = _forest
	noise_river    = _river
	noise_warp     = _warp
	world_seed     = _world_seed
	world_limit    = _world_limit

	print("[MAP-UI] setup_blueprint called | Template: ", continent_type, " | Seed: ", world_seed)

	if val_seed: val_seed.text = str(world_seed)
	if val_type: val_type.text = continent_type.capitalize()
	
	_populate_legend()

	if texture_rect:
		texture_rect.texture_filter = TEXTURE_FILTER_NEAREST
	
	_render_map()
	# Minimap sẽ được render lần đầu cùng lúc với bản đồ chính trên thread

# Compat với setup cũ (phòng trường hợp code toggle_world_map vẫn gọi setup)
func setup(n_t, n_f, n_r, n_temp, n_moist, n_bio, n_scat, n_warp, n_giant, n_filt, n_fault, limit=2000, radius=0.55):
	noise_terrain  = n_t; noise_forest = n_f; noise_river = n_r
	noise_temp     = n_temp; noise_moisture = n_moist; noise_biome = n_bio
	noise_scatter  = n_scat; noise_warp = n_warp; noise_giant = n_giant
	noise_filter   = n_filt; noise_fault = n_fault
	world_limit    = limit; continent_radius = radius
	noise_detail   = n_t
	if texture_rect: texture_rect.texture_filter = TEXTURE_FILTER_NEAREST
	_render_map()

func _ready():
	_render_thread = Thread.new()
	_render_thread.start(_thread_render_loop)

	if texture_rect:
		texture_rect.texture_filter = TEXTURE_FILTER_NEAREST
	# Player marker setup removed

	_context_menu = PopupMenu.new()
	add_child(_context_menu)
	_context_menu.add_item("Dịch chuyển tới đây", 100)
	_context_menu.id_pressed.connect(_on_menu_item_selected)

	# Navigation Buttons
	var btn_in = get_node_or_null("HBox/MapArea/Navigation/BtnIn")
	if btn_in: btn_in.pressed.connect(_adjust_zoom.bind(0.8))
	var btn_out = get_node_or_null("HBox/MapArea/Navigation/BtnOut")
	if btn_out: btn_out.pressed.connect(_adjust_zoom.bind(1.25))
	var btn_home = get_node_or_null("HBox/MapArea/Navigation/BtnHome")
	if btn_home: btn_home.pressed.connect(func(): view_center = Vector2.ZERO; view_zoom = 1.0; _update_static_transform())

	# Khởi tạo thư mục cache
	DirAccess.make_dir_recursive_absolute("user://map_cache/")

func _populate_legend():
	if !legend_list: return
	for child in legend_list.get_children(): child.queue_free()
	
	var biomes = ["deep_sea","beach","plains","forest","jungle","desert","tundra","taiga","savannah","volcano","bamboo","salt_desert"]
	# Bật clipping cho container để không bị tràn map
	var container = get_node_or_null("HBox/MapArea/MapContainer")
	if container: container.clip_contents = true
	
	if texture_rect:
		texture_rect.texture_filter = TEXTURE_FILTER_NEAREST
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE

func _exit_tree():
	_exit_thread = true
	_render_semaphore.post()
	if _render_thread: _render_thread.wait_to_finish()
	

func _process(delta):
	if !visible: return

	if player_node and is_instance_valid(player_node):
		var tp: Vector2
		if orchestrator and orchestrator.temp_layer:
			# Sử dụng local_to_map để lấy tọa độ Tile chính xác trong không gian Isometric
			var map_pos = orchestrator.temp_layer.local_to_map(orchestrator.temp_layer.to_local(player_node.global_position))
			tp = Vector2(map_pos.x, map_pos.y)
		else:
			# Fallback (chỉ hoạt động với Top-down 16x16)
			tp = Vector2(player_node.global_position.x / 16.0, player_node.global_position.y / 16.0)
		set_player_pos(tp)

	# NAVIGATION: Di chuyển view_center và cập nhật transform ảnh tĩnh
	var move_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): move_vec.y -= 1
	if Input.is_key_pressed(KEY_S): move_vec.y += 1
	if Input.is_key_pressed(KEY_A): move_vec.x -= 1
	if Input.is_key_pressed(KEY_D): move_vec.x += 1
	
	if move_vec != Vector2.ZERO:
		view_center += move_vec.normalized() * move_speed * view_zoom * delta
	
	_update_static_transform()
	_update_hover_info()

func _update_static_transform():
	if !texture_rect or !_is_fully_rendered: return
	
	# Scale ảnh theo zoom
	# 1.0 zoom = ảnh fit theo map_size
	# 0.5 zoom = ảnh to gấp đôi (zoom in)
	var base_size = Vector2(map_size)
	var scaled_size = base_size / view_zoom
	texture_rect.size = scaled_size
	
	# Center ảnh dựa trên view_center (tọa độ tile)
	# Tọa độ tile (0, 0) nằm ở trung tâm ảnh
	# Tọa độ pixel (0, 0) của ảnh là (-world_limit, -world_limit)
	var world_limit_f = float(world_limit)
	var offset_x = (view_center.x + world_limit_f) / (world_limit_f * 2.0)
	var offset_y = (view_center.y + world_limit_f) / (world_limit_f * 2.0)
	
	# Vị trí của TextureRect = Center_UI - Offset_Tương_Ứng * Size_Đã_Phóng_To
	texture_rect.position = base_size / 2.0 - Vector2(offset_x * scaled_size.x, offset_y * scaled_size.y)
	
	# Cập nhật Player Marker nếu có
	if player_marker and is_instance_valid(player_marker):
		var map_w_f = world_limit_f * 2.0
		var px = (world_player_pos.x + world_limit_f) / map_w_f * scaled_size.x
		var py = (world_player_pos.y + world_limit_f) / map_w_f * scaled_size.y
		
		player_marker.position = Vector2(px, py) - player_marker.pivot_offset
		# Giữ kích thước dot cố định bằng cách nghịch đảo zoom (vì dot là con của texture_rect đã bị scale)
		# Ở đây scaled_size đã bao gồm zoom, nhưng texture_rect.scale vẫn là 1,1
		# Tuy nhiên texture_rect hiển thị to ra/nhỏ lại dựa trên size. 
		# Dot là con, tọa độ (px, py) của nó đã khớp với size mới.
		# NHƯNG size của dot (20x20) vẫn là 20x20. Nó không bị biến dạng trừ khi texture_rect.scale thay đổi.
		# Vì mình dùng texture_rect.size = scaled_size, nên dot không bị méo.
		# CHỈ CẦN: Đảm bảo dot nằm đúng tọa độ tương ứng với size hiện tại của texture_rect.

# Throttle render requests để tránh spam
func _request_render_throttled():
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_render_time < _render_cooldown:
		_render_pending = true
		return
	_last_render_time = now
	_render_pending = false
	_render_map()

func _update_hover_info():
	if !texture_rect or (!shape_engine and !noise_terrain): return
	# Lấy tọa độ chuột TRÊN TextureRect (sau khi đã biến đổi scale/pos)
	var local_m = texture_rect.get_local_mouse_position()
	
	var x_ratio = local_m.x / texture_rect.size.x
	var y_ratio = local_m.y / texture_rect.size.y
	
	# Tọa độ world dựa trên giới hạn tuyệt đối
	var world_w = float(world_limit * 2)
	var cur_gx = -world_limit + (x_ratio * world_w)
	var cur_gy = -world_limit + (y_ratio * world_w)

	var b_name = "N/A"
	var land = 1.0
	if shape_engine:
		_render_mutex.lock()
		var engine = shape_engine
		_render_mutex.unlock()
		
		land = engine.get_land_value(Vector2(cur_gx, cur_gy))
		var bd = engine.get_biome(Vector2(cur_gx, cur_gy), land)
		b_name = bd["biome"]
	elif noise_terrain:
		b_name = _get_biome_name_legacy(cur_gx, cur_gy)

	if val_x: val_x.text = str(int(cur_gx))
	if val_y: val_y.text = str(int(cur_gy))
	if val_bio: val_bio.text = b_name.capitalize()
	if val_elev: val_elev.text = "%.2f m" % (land * 100.0)

func _input(event):
	if !visible: return
	var ctrl = Input.is_key_pressed(KEY_CTRL)
	if event is InputEventMouseButton and ctrl:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _adjust_zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _adjust_zoom(1.1)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL: _adjust_zoom(0.8)
		elif event.keycode == KEY_MINUS: _adjust_zoom(1.2)
		elif event.keycode == KEY_F5: 
			print("[MAP-UI] Refresh requested (F5)")
			_refresh_map()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var local_m = texture_rect.get_local_mouse_position()
		var x_ratio = local_m.x / texture_rect.size.x
		var y_ratio = local_m.y / texture_rect.size.y
		
		var world_w = float(world_limit * 2)
		_last_click_tile = Vector2(
			-world_limit + (x_ratio * world_w),
			-world_limit + (y_ratio * world_w)
		)

		if _last_rendered_img:
			# Ánh xạ tỉ lệ mouse sang tọa độ pixel của ảnh render (render_size)
			var img_px = Vector2i(
				clamp(int(x_ratio * render_size.x), 0, render_size.x - 1),
				clamp(int(y_ratio * render_size.y), 0, render_size.y - 1)
			)
			var pixel_color = _last_rendered_img.get_pixelv(img_px)
			print("[MAP-DEBUG] Right Click ImgPx: %s | Color: %s" % [img_px, pixel_color.to_html()])
		print("[MAP-DEBUG] Tile: %s" % _last_click_tile)

		_context_menu.position = get_screen_transform() * event.position
		_context_menu.popup()

func _refresh_map():
	# Xóa cache hiện tại và render lại
	var path = _get_cache_path()
	print("[MAP-UI] Deleting cache: ", path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_is_fully_rendered = false
	_render_map()

func _adjust_zoom(factor: float):
	view_zoom = clamp(view_zoom * factor, 0.01, 2.0) # Thu nhỏ xuống 0.01 để nhìn toàn cảnh
	_update_static_transform()

func _render_map():
	if !shape_engine:
		print("[MAP-UI] _render_map skipped: No shape_engine")
		return
	
	if _is_fully_rendered:
		print("[MAP-UI] _render_map skipped: Already fully rendered")
		return 
	
	print("[MAP-UI] Requesting background render...")
	_render_mutex.lock()
	_thread_view_center = view_center; _thread_view_zoom = view_zoom
	_render_pending = false
	_render_mutex.unlock()
	_render_semaphore.post()
	_update_minimap_viewport()

func _update_minimap_viewport():
	if !viewport_box or !minimap_texture: return
	var mm_size = minimap_texture.size
	# Toàn bộ thế giới có kích thước map_size * ??? -> Thực tế là world_limit
	var world_size = float(world_limit * 2)
	var viewport_w = (map_size.x * view_zoom / world_size) * mm_size.x
	var viewport_h = (map_size.y * view_zoom / world_size) * mm_size.y
	
	var vx = ((view_center.x + world_limit) / world_size) * mm_size.x - (viewport_w / 2.0)
	var vy = ((view_center.y + world_limit) / world_size) * mm_size.y - (viewport_h / 2.0)
	
	viewport_box.size = Vector2(viewport_w, viewport_h)
	viewport_box.position = Vector2(vx, vy)

func _thread_render_loop():
	while true:
		_render_semaphore.wait()
		if _exit_thread: break
		
		# Clear queue nếu có nhiều request dồn lại (không cần thiết với static render nhưng để an toàn)
		while _render_semaphore.try_wait(): pass
		
		# Render Toàn Bộ Thế Giới
		render_full_world()

func render_full_world():
	if !shape_engine: 
		print("[MAP-RENDER] Thread error: No shape_engine in render_full_world")
		return
	
	var path = _get_cache_path()
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img and img.get_size() == render_size:
			print("[MAP-CACHE] Loaded successful: %s" % path)
			_last_rendered_img = img
			call_deferred("_finish_full_render", img)
			return
		else:
			print("[MAP-CACHE] Cache invalid or wrong size, re-rendering...")
	
	print("[MAP-RENDER] Start rendering full world (512x512 optimized)...")
	var res = render_size.x
	var img = Image.create(res, res, false, Image.FORMAT_RGBA8)
	var world_w = float(world_limit * 2)
	var step = world_w / float(res)
	
	# Cache engine reference
	var engine = shape_engine
	
	for y in range(res):
		if _exit_thread: return
		var gy = -world_limit + (y * step)
		for x in range(res):
			var gx = -world_limit + (x * step)
			var gpos = Vector2(gx, gy)
			
			var land = engine.get_land_value(gpos)
			
			var col: Color
			if land < 0.2: col = Color("#0b2e46")        # Biển sâu (Tăng ngưỡng lên 0.2 để xóa sạch viền)
			else:
				var bd = engine.get_biome(gpos, land)
				# Bỏ qua vẽ sông trên bản đồ để xóa viền xanh nhầm lẫn
				col = _get_color_blueprint(land, bd["biome"], 1.0, 0.0, 0.5, gpos)
			
			img.set_pixel(x, y, col)
	
	_last_rendered_img = img
	# Lưu cache
	img.save_png(path)
	print("[MAP-CACHE] Saved new cache: %s" % path)
	print("[MAP-RENDER] Full world render COMPLETED at: ", Time.get_ticks_msec())
	call_deferred("_finish_full_render", img)

func _get_cache_path() -> String:
	# Bump version to v12_mask_system to force re-render
	return "user://map_cache/%s_%s_v12_mask_system.png" % [continent_type.replace(" ", "_"), world_seed]

func _finish_full_render(img: Image):
	var tex = ImageTexture.create_from_image(img)
	if texture_rect:
		texture_rect.texture = tex
	_is_fully_rendered = true
	_update_static_transform()
	# Vẽ Minimap luôn
	_render_minimap_worker()

# ═══════════════════════════════════════════════════════════════
# RENDER WORKER — Tối ưu hóa độ phân giải render thấp để tăng tốc
# ═══════════════════════════════════════════════════════════════
func _render_worker(center: Vector2, zoom: float):
	var img = Image.create(render_size.x, render_size.y, false, Image.FORMAT_RGBA8)
	
	# Cache các tham chiếu local để truy cập nhanh hơn trong vòng lặp
	var engine = shape_engine
	var n_river = noise_river
	var n_forest = noise_forest
	
	var r_w = render_size.x
	var r_h = render_size.y
	
	# Tính toán bounding box của view để tối ưu hóa tính toán world pos
	var half_width_world = (map_size.x / 2.0) * zoom
	var half_height_world = (map_size.y / 2.0) * zoom
	var start_x = center.x - half_width_world
	var start_y = center.y - half_height_world
	
	# Bước nhảy tọa độ world trên mỗi pixel render
	var step_x = (map_size.x * zoom) / float(r_w)
	var step_y = (map_size.y * zoom) / float(r_h)

	for y in range(r_h):
		if _exit_thread: return
		var gy = start_y + (y * step_y)
		
		for x in range(r_w):
			var gx = start_x + (x * step_x)
			var gpos = Vector2(gx, gy)
			var pixel_color: Color

			if engine:
				# ─── PATH MỚI: shape_engine ───
				var land = engine.get_land_value(gpos)
				
				# Simplified sea/land (Threshold 0.2)
				if land < 0.2:
					pixel_color = Color("#0b2e46")
					img.set_pixel(x, y, pixel_color)
					continue
				
				var bd = engine.get_biome(gpos, land)

				# Sông (chỉ tính nếu là đất liền để tiết kiệm)
				var r_val = 1.0
				if land > 0.15 and n_river:
					var flow = n_river.get_noise_2d(gx, gy)
					if abs(flow) < 0.038:
						r_val = 0.0
					elif abs(flow) < 0.055: # Giảm số lần gọi noise thứ 2
						r_val = 0.5

				var f_val = 0.0
				if land > 0.15 and n_forest: # Chỉ tính forest cho đất liền
					f_val = n_forest.get_noise_2d(gx, gy)
				var s_val = 0.5

				pixel_color = _get_color_blueprint(land, bd["biome"], r_val, f_val, s_val, gpos)
			else:
				# ─── FALLBACK LEGACY PATH ───
				pixel_color = _get_color_legacy(gx, gy)

			img.set_pixel(x, y, pixel_color)

	call_deferred("_update_at_main_thread", img)

# ═══════════════════════════════════════════════════════════════
# MINIMAP WORKER — Chạy trên thread
# ═══════════════════════════════════════════════════════════════
func _render_minimap_worker():
	if !shape_engine: return
	var mm_res = 100
	var img = Image.create(mm_res, mm_res, false, Image.FORMAT_RGBA8)
	var world_size = float(world_limit * 2)
	var step = world_size / float(mm_res)
	
	for y in range(mm_res):
		if _exit_thread: return
		var gy = -world_limit + (y * step)
		for x in range(mm_res):
			var gx = -world_limit + (x * step)
			var land = shape_engine.get_land_value(Vector2(gx, gy))
			
			var col: Color
			if land < 0.2:
				col = Color("#0b2e46")
			else:
				var bd = shape_engine.get_biome(Vector2(gx, gy), land)
				col = _get_color_blueprint(land, bd["biome"], 1.0, 0.0, 0.5, Vector2(gx, gy))
			
			img.set_pixel(x, y, col)
	
	call_deferred("_update_minimap_at_main_thread", img)

func _update_minimap_at_main_thread(img: Image):
	_minimap_img = img
	if minimap_texture:
		minimap_texture.texture = ImageTexture.create_from_image(img)

# ═══════════════════════════════════════════════════════════════
# COLOR MAPPING — Blueprint path
# ═══════════════════════════════════════════════════════════════
func _get_color_blueprint(land: float, biome: String, r_val: float, f_val: float, s_val: float, gpos: Vector2) -> Color:
	# Biển (Ngưỡng 0.2)
	if land < 0.2: return Color("#0b2e46")

	# Sông (Bị vô hiệu hóa màu xanh sông tại đây để tránh tạo viền)
	# if r_val < 0.3: return Color("#2e86c1")
	# if r_val < 0.7: return Color("#1a5276").lerp(Color("#2ecc71"), 0.5)

	# Biome
	match biome:
		"tundra":      return Color("#d6eaf8") # Tuyết xanh nhạt
		"taiga":       return Color("#21618c") # Rừng lá kim tối
		"desert":      return Color("#d4ac0d") # Cát vàng đặc
		"salt_desert": return Color("#f4f6f7") # Trắng muối
		"savannah":    return Color("#f7dc6f") # Vàng cỏ khô
		"jungle":      return Color("#186a3b") # Xanh nhiệt đới thẫm
		"forest":      return Color("#1e8449") # Xanh lá ôn đới
		"plains":      return Color("#52be80") # Xanh cỏ sáng
		"bamboo":      return Color("#a9dfbf") # Xanh tre
		"volcano":
			if land > 0.6: return Color("#1a1a1a") # Đỉnh núi đen (ash)
			return Color("#cb4335") # Lava / Red earth
		"beach":       return Color("#edbb99")
		_:             return Color("#2ecc71")

# ═══════════════════════════════════════════════════════════════
# HOVER BIOME NAME
# ═══════════════════════════════════════════════════════════════
func _get_biome_name_legacy(gx: float, gy: float) -> String:
	if not noise_terrain: return "N/A"
	var n = noise_terrain.get_noise_2d(gx, gy) - 0.1
	if n < -0.4: return "Biển sâu (Deep Sea)"
	if n < -0.32: return "Bờ biển (Beach)"
	return "Plains (legacy)"

func _get_biome_name(land: float, biome: String) -> String:
	match biome:
		"deep_sea":  return "Biển sâu (Deep Sea)"
		"beach":     return "Bờ biển (Beach)"
		"tundra":    return "Đài nguyên (Tundra)"
		"taiga":     return "Rừng lạnh (Taiga)"
		"desert":    return "Sa mạc (Desert)"
		"salt_desert": return "Sa mạc muối (Salt Desert)"
		"jungle":    return "Rừng nhiệt đới (Jungle)"
		"forest":    return "Rừng ôn đới (Forest)"
		"savannah":  return "Savannah"
		"plains":    return "Đồng cỏ (Plains)"
		"bamboo":    return "Rừng tre (Bamboo)"
		"volcano":   return "Núi lửa (Volcano)"
		_: return biome

# ═══════════════════════════════════════════════════════════════
# LEGACY COLOR (Fallback khi không có shape_engine)
# ═══════════════════════════════════════════════════════════════
func _get_color_legacy(gx: float, gy: float) -> Color:
	if not noise_terrain: return Color.BLACK
	var n_val = noise_terrain.get_noise_2d(gx, gy) - 0.1
	if n_val < -0.4: return Color("#0b2e46")
	if n_val < -0.32: return Color("#edbb99")
	return Color("#2ecc71")

func _update_at_main_thread(img: Image):
	_last_rendered_img = img
	var tex = ImageTexture.create_from_image(img)
	texture_rect.texture = tex

var world_player_pos: Vector2 = Vector2.ZERO

func _on_menu_item_selected(id: int):
	if id == 100:
		var b_name = "Unknown"
		if shape_engine:
			var land = shape_engine.get_land_value(_last_click_tile)
			var bd = shape_engine.get_biome(_last_click_tile, land)
			b_name = _get_biome_name(land, bd["biome"])
		print("[MAP-DEBUG] Teleport to: %s | Biome: %s" % [_last_click_tile, b_name])
		teleport_requested.emit(_last_click_tile, b_name)

func set_player_pos(world_pos: Vector2):
	world_player_pos = world_pos

func _setup_pulsing_animation():
	pass
