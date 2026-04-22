# V2.0 - Using WorldShapeEngine to render map precisely
# Map now displays correct continent shapes from polygon template
extends Control

# ---------------------------------------------------------------
# BLUEPRINT REFERENCES (set from infinite_map_generator)
# ---------------------------------------------------------------
var shape_engine: WorldShapeEngine = null
var continent_type: String = "pangaea"

# Detailed Noise (needed for rivers, forest)
var noise_detail: FastNoiseLite
var noise_forest: FastNoiseLite
var noise_river: FastNoiseLite
var noise_warp: FastNoiseLite

# Compat with old code
var noise_terrain: FastNoiseLite
var noise_temp: FastNoiseLite
var noise_moisture: FastNoiseLite
var noise_biome: FastNoiseLite
var noise_scatter: FastNoiseLite
var noise_giant: FastNoiseLite
var noise_filter: FastNoiseLite
var noise_fault: FastNoiseLite

var world_limit: int = 1000
var continent_radius: float = 0.55
var player_node: Node2D
var orchestrator: Node2D
var world_seed: int = 0
var _current_override_path: String = ""

const STATIC_BIOMES: Array = [
	{"id": "plains", "name": "Đồng bằng", "color": Color("#7ab648"), "desc": "Cỏ xanh mượt", "climate": "temperate"},
	{"id": "tundra", "name": "Vùng tuyết", "color": Color("#8aabb8"), "desc": "Băng giá vĩnh cửu", "climate": "polar"},
	{"id": "desert", "name": "Sa mạc", "color": Color("#d4ac0d"), "desc": "Cát vàng mênh mông", "climate": "arid"},
	{"id": "salt_desert", "name": "Sa mạc muối", "color": Color("#ddeef8"), "desc": "Cánh đồng muối trắng", "climate": "arid"},
	{"id": "volcano", "name": "Vùng núi lửa", "color": Color("#9a3020"), "desc": "Lava nóng bỏng", "climate": "special"},
	{"id": "deep_sea", "name": "Deep Sea", "color": Color("#1a3a6b"), "desc": "Đại dương xanh thẳm", "climate": "special"},
	{"id": "beach", "name": "Biển/Hồ", "color": Color("#2a6896"), "desc": "Hồ nước hiền hòa", "climate": "special"},
	{"id": "coal", "name": "Than đá", "color": Color("#2b2b2b"), "desc": "Mỏ than trù phú", "climate": "special"},
	{"id": "bamboo", "name": "Cà phê", "color": Color("#5c3a2a"), "desc": "Rừng cà phê thơm", "climate": "tropical"},
	{"id": "forest", "name": "Rừng phong", "color": Color("#3a7a45"), "desc": "Rừng phong đỏ thắm", "climate": "temperate"},
	{"id": "jungle", "name": "Rừng sồi", "color": Color("#1e5c30"), "desc": "Rừng sồi già cỗi", "climate": "temperate"},
	{"id": "taiga", "name": "Rừng thông", "color": Color("#4d6d5d"), "desc": "Rừng thông bạt ngàn", "climate": "polar"},
]

signal teleport_requested(target_tile_pos: Vector2, expected_biome_name: String)

var _context_menu: PopupMenu
var _last_click_tile: Vector2

@onready var texture_rect: TextureRect = $Storage/MapContainer/MapTexture
@onready var coords_label: Label = $CoordsLabel # Keep for compat but will hide

# Minimap Nodes
@onready var minimap_texture: TextureRect = $Storage/MinimapWrap/MinimapTexture
@onready var viewport_box: ReferenceRect = $Storage/MinimapWrap/ViewportBox
@onready var player_marker: Panel = $Storage/MapContainer/MapTexture/PlayerMarker

var map_size: Vector2i = Vector2i(1030, 720) # MapArea size (1280 - 250 sidebar)
var render_size: Vector2i = Vector2i(1024, 1024) # Will be dynamically set to world_limit*2
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
var active_biomes_snapshot: Array = []
var _render_pending: bool = false
var _sync_audit_pending: bool = false
var _last_render_time: float = 0.0
var _render_cooldown: float = 0.1 # Limit render up to 10 FPS

# --- NEW PRO UI NODES ---
var pro_root: VBoxContainer
var pro_topbar: PanelContainer
var pro_sidebar: PanelContainer
var pro_statusbar: PanelContainer
var pro_map_area: Control

# Controls & Labels
var st_tool: Label
var st_biome: Label
var st_seed: Label
var st_file: Label
var st_res: Label
var st_coords: Label
var cur_tool_pro: String = "pan"
var pro_tool_btns: Dictionary = {}

# Layout helpers
var side: float = 720.0
var scaled_size: Vector2 = Vector2(720, 720)

var pro_val_player_coords: Label
var _is_panning: bool = false
var _pan_start: Vector2
var _view_start_cart: Vector2 # Cartesian start for Panning

# -- CACHE VERSION --
const MAP_CACHE_VERSION = "v22_iso_revo"

var pro_legend_list: Container
var pro_val_x: Label
var pro_val_y: Label
var pro_val_bio: Label

# Appearance
var sb_dark_bar: StyleBoxFlat
var sb_glass_sidebar: StyleBoxFlat
var sb_glass_card: StyleBoxFlat

func setup_blueprint(
	_shape_engine: WorldShapeEngine,
	_continent_type: String,
	_detail: FastNoiseLite,
	_forest: FastNoiseLite,
	_river: FastNoiseLite,
	_warp: FastNoiseLite,
	_world_limit: int,
	_world_seed: int,
	_override_path: String = ""
):
	shape_engine   = _shape_engine
	continent_type = _continent_type
	noise_detail   = _detail
	noise_forest   = _forest
	noise_river    = _river
	noise_warp     = _warp
	world_seed     = _world_seed
	world_limit    = _world_limit
	
	# Set 1:1 resolution (1 pixel per tile)
	var res_val = world_limit * 2
	# Safety cap at 4096px
	if res_val > 4096: res_val = 4096
	render_size = Vector2i(res_val, res_val)
	print("[MAP-UI] Resolution set to 1:1 scale: ", render_size)
	
	# If override_path changed vs old cache then force re-render
	var old_cache = _get_cache_path()
	_current_override_path = _override_path
	var new_cache = _get_cache_path()
	
	if old_cache != new_cache:
		_is_fully_rendered = false

	print("[MAP-UI] setup_blueprint called | Template: ", continent_type, " | Seed: ", world_seed)
	
	if orchestrator and orchestrator.player:
		view_center = local_to_cartesian_idx(orchestrator.player.global_position)
	else:
		view_center = Vector2.ZERO # Global origin

	_sync_audit_pending = true # Trigger audit next process frame
	if _override_path.ends_with(".entmap"):
		var f = FileAccess.open(_override_path, FileAccess.READ)
		if f:
			var json = JSON.new()
			if json.parse(f.get_as_text()) == OK:
				active_biomes_snapshot = json.data.get("biomes_snapshot", [])
			f.close()

	if st_file:
		var fname = _current_override_path.get_file() if !_current_override_path.is_empty() else "New Map"
		st_file.text = "File: " + fname
	if st_res:
		st_res.text = "Res: %dx%d" % [world_limit*2, world_limit*2]
	if st_seed:
		st_seed.text = "Seed: " + str(world_seed)

	_populate_legend()
	
	if texture_rect:
		texture_rect.texture_filter = TEXTURE_FILTER_NEAREST
	
	_render_map()
	# Minimap will be rendered first time along with main map on thread

# Compat with old setup
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
	_init_pro_styles()
	_setup_professional_ui()
	
	_render_thread = Thread.new()
	_render_thread.start(_thread_render_loop)

	if texture_rect:
		texture_rect.texture_filter = TEXTURE_FILTER_NEAREST
	
	_context_menu = PopupMenu.new()
	add_child(_context_menu)
	_context_menu.add_item("Teleport here", 100)
	_context_menu.id_pressed.connect(_on_menu_item_selected)

	#Navigation Buttons
	var btn_in = get_node_or_null("HBox/MapArea/Navigation/BtnIn")
	if btn_in: btn_in.pressed.connect(_adjust_zoom.bind(0.8))
	var btn_out = get_node_or_null("HBox/MapArea/Navigation/BtnOut")
	if btn_out: btn_out.pressed.connect(_adjust_zoom.bind(1.25))
	var btn_home = get_node_or_null("HBox/MapArea/Navigation/BtnHome")
	if btn_home: btn_home.pressed.connect(func(): view_center = Vector2.ZERO; view_zoom = 1.0; _update_static_transform())

	# Initialize cache dir
	DirAccess.make_dir_recursive_absolute("user://map_cache/")

func _init_pro_styles():
	sb_dark_bar = StyleBoxFlat.new()
	sb_dark_bar.bg_color = Color("#0e1219")
	sb_dark_bar.border_width_bottom = 1
	sb_dark_bar.border_color = Color("#1a2030")
	
	sb_glass_sidebar = StyleBoxFlat.new()
	sb_glass_sidebar.bg_color = Color("#0e1219")
	sb_glass_sidebar.border_width_left = 1
	sb_glass_sidebar.border_color = Color("#1a2030")
	
	sb_glass_card = StyleBoxFlat.new()
	sb_glass_card.bg_color = Color(1, 1, 1, 0.03)
	sb_glass_card.set_corner_radius_all(8)
	sb_glass_card.border_width_left = 1; sb_glass_card.border_width_top = 1
	sb_glass_card.border_width_right = 1; sb_glass_card.border_width_bottom = 1
	sb_glass_card.border_color = Color(1, 1, 1, 0.05)

func _setup_professional_ui():
	# 1. Hide legacy UI
	var old_hbox = get_node_or_null("HBox")
	if old_hbox: old_hbox.visible = false
	if coords_label: coords_label.visible = false
	
	# 2. Create new Root
	pro_root = VBoxContainer.new()
	pro_root.name = "ProLayout"
	pro_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pro_root.add_theme_constant_override("separation", 0)
	add_child(pro_root)
	
	# --- TOPBAR ---
	pro_topbar = PanelContainer.new()
	pro_topbar.custom_minimum_size.y = 38
	pro_topbar.add_theme_stylebox_override("panel", sb_dark_bar)
	pro_root.add_child(pro_topbar)
	
	var tb_hbox = HBoxContainer.new()
	tb_hbox.add_theme_constant_override("separation", 10)
	pro_topbar.add_child(tb_hbox)
	
	var title_margin = MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 12)
	tb_hbox.add_child(title_margin)
	
	var title_lab = Label.new()
	title_lab.text = "MapTool"
	title_lab.add_theme_font_size_override("font_size", 11)
	title_lab.add_theme_color_override("font_color", Color("#c0c6d8"))
	title_margin.add_child(title_lab)
	
	# Spacer to right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(spacer)
	
	var right_margin = Control.new()
	right_margin.custom_minimum_size.x = 12
	tb_hbox.add_child(right_margin)
	
	_set_tool_pro("pan")
	
	# --- MAIN CONTENT ---
	var main_hbox = HBoxContainer.new()
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 0)
	pro_root.add_child(main_hbox)
	
	# SIDEBAR (LEFT)
	pro_sidebar = PanelContainer.new()
	pro_sidebar.custom_minimum_size = Vector2(360, 0)
	pro_sidebar.add_theme_stylebox_override("panel", sb_glass_sidebar)
	main_hbox.add_child(pro_sidebar)
	
	var side_vbox = VBoxContainer.new()
	side_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pro_sidebar.add_child(side_vbox)
	
	var side_margin = MarginContainer.new()
	side_margin.add_theme_constant_override("margin_left", 12)
	side_margin.add_theme_constant_override("margin_top", 12)
	side_margin.add_theme_constant_override("margin_right", 12)
	side_margin.add_theme_constant_override("margin_bottom", 12)
	side_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_vbox.add_child(side_margin)
	
	var side_content = VBoxContainer.new()
	side_content.add_theme_constant_override("separation", 20)
	side_margin.add_child(side_content)
	
	# Legend Section
	var legend_box = VBoxContainer.new()
	side_content.add_child(legend_box)
	legend_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var lg_hdr = Label.new()
	lg_hdr.text = "BIOMES (LEGEND)"
	lg_hdr.add_theme_font_size_override("font_size", 9)
	lg_hdr.add_theme_color_override("font_color", Color("#2c3448"))
	legend_box.add_child(lg_hdr)
	
	var lg_scroll = ScrollContainer.new()
	lg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lg_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lg_scroll.custom_minimum_size.y = 500
	legend_box.add_child(lg_scroll)
	
	pro_legend_list = VBoxContainer.new()
	pro_legend_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lg_scroll.add_child(pro_legend_list)
	
	# MAP AREA
	pro_map_area = Control.new()
	pro_map_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pro_map_area.clip_contents = true # Critical to prevent overflow
	main_hbox.add_child(pro_map_area)
	
	# INFINITE OCEAN/VOID BACKGROUND (To show map boundary)
	var bg_void = ColorRect.new()
	bg_void.color = Color("#06090e")
	bg_void.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pro_map_area.add_child(bg_void)
	
	# Reparent MapContainer to pro_map_area
	var map_container = get_node_or_null("Storage/MapContainer")
	if map_container:
		map_container.get_parent().remove_child(map_container)
		pro_map_area.add_child(map_container)
		
		# Add a subtle border to the map island/square
		var map_border = ReferenceRect.new()
		map_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		map_border.border_color = Color(1, 1, 1, 0.08)
		map_border.editor_only = false
		map_container.add_child(map_border)
	
	_populate_legend()
	
	if map_container:
		map_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Update map_size based on actual map_area size
		_on_map_area_resized()
		pro_map_area.resized.connect(_on_map_area_resized)
		
	# --- MAP OVERLAYS ---
	var overlays = Control.new()
	overlays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pro_map_area.add_child(overlays)
	
	# Zoom Stack (Bottom Left)
	var z_stack = VBoxContainer.new()
	z_stack.add_theme_constant_override("separation", 4)
	z_stack.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	z_stack.position += Vector2(20, -70)
	overlays.add_child(z_stack)
	
	var zb_in = _create_tool_btn("+", null)
	zb_in.custom_minimum_size = Vector2(28, 28)
	zb_in.flat = false
	var zb_style = sb_dark_bar.duplicate()
	zb_style.bg_color = Color("#0e1219")
	zb_style.border_width_bottom = 0
	zb_in.add_theme_stylebox_override("normal", zb_style)
	zb_in.add_theme_color_override("font_color", Color("#1a73e8"))
	zb_in.pressed.connect(_adjust_zoom.bind(0.8))
	z_stack.add_child(zb_in)
	
	var zb_out = _create_tool_btn("-", null)
	zb_out.custom_minimum_size = Vector2(28, 28)
	zb_out.flat = false
	zb_out.add_theme_stylebox_override("normal", zb_style)
	zb_out.add_theme_color_override("font_color", Color("#1a73e8"))
	zb_out.pressed.connect(_adjust_zoom.bind(1.25))
	z_stack.add_child(zb_out)

	# Minimap Wrap (Reparent to overlays, Bottom Right)
	var mm_wrap = get_node_or_null("Storage/MinimapWrap")
	if mm_wrap:
		mm_wrap.get_parent().remove_child(mm_wrap)
		overlays.add_child(mm_wrap)
		mm_wrap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		mm_wrap.position += Vector2(-12, -12)
		
		var mm_border = ReferenceRect.new()
		mm_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mm_border.border_color = Color("#2189db")
		mm_border.border_width = 2.0
		mm_border.editor_only = false
		mm_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mm_wrap.add_child(mm_border)

		if viewport_box:
			viewport_box.visible = false
			viewport_box.mouse_filter = Control.MOUSE_FILTER_IGNORE



	# --- STATUSBAR ---
	pro_statusbar = PanelContainer.new()
	pro_statusbar.custom_minimum_size.y = 22
	var sb_style = sb_dark_bar.duplicate()
	sb_style.bg_color = Color("#0a0d13")
	sb_style.border_width_bottom = 0
	sb_style.border_width_top = 1
	pro_statusbar.add_theme_stylebox_override("panel", sb_style)
	pro_root.add_child(pro_statusbar)
	
	var st_hbox = HBoxContainer.new()
	st_hbox.add_theme_constant_override("separation", 10)
	pro_statusbar.add_child(st_hbox)
	
	var st_margin = MarginContainer.new()
	st_margin.add_theme_constant_override("margin_left", 8)
	st_hbox.add_child(st_margin)
	
	var st_bio_lbl = Label.new()
	st_bio_lbl.text = "Biome:"
	st_bio_lbl.add_theme_font_size_override("font_size", 9)
	st_bio_lbl.add_theme_color_override("font_color", Color("#46506a"))
	st_hbox.add_child(st_bio_lbl)

	# BIOME INFO (Moved from sidebar)
	pro_val_bio = Label.new()
	pro_val_bio.text = "---"
	pro_val_bio.add_theme_font_size_override("font_size", 10)
	pro_val_bio.add_theme_color_override("font_color", Color("#7c6cbc"))
	st_hbox.add_child(pro_val_bio)
	
	var st_sep = Label.new()
	st_sep.text = "|"
	st_sep.add_theme_color_override("font_color", Color("#1e2433"))
	st_hbox.add_child(st_sep)
	
	# POSITION INFO (Moved from sidebar)
	var pos_hbox = HBoxContainer.new()
	pos_hbox.add_theme_constant_override("separation", 10)
	st_hbox.add_child(pos_hbox)
	
	pro_val_x = Label.new()
	pro_val_x.text = "X: ---"
	pro_val_x.add_theme_font_size_override("font_size", 9)
	pro_val_x.add_theme_color_override("font_color", Color("#46506a"))
	pos_hbox.add_child(pro_val_x)
	
	pro_val_y = Label.new()
	pro_val_y.text = "Y: ---"
	pro_val_y.add_theme_font_size_override("font_size", 9)
	pro_val_y.add_theme_color_override("font_color", Color("#46506a"))
	pos_hbox.add_child(pro_val_y)
	
	var st_spacer = Control.new()
	st_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_hbox.add_child(st_spacer)
	
	st_file = Label.new()
	var fname = _current_override_path.get_file() if !_current_override_path.is_empty() else "New Map"
	st_file.text = "File: " + fname
	st_file.add_theme_font_size_override("font_size", 9)
	st_file.add_theme_color_override("font_color", Color("#46506a"))
	st_hbox.add_child(st_file)
	
	st_res = Label.new()
	st_res.text = "Res: %dx%d" % [world_limit*2, world_limit*2]
	st_res.add_theme_font_size_override("font_size", 9)
	st_res.add_theme_color_override("font_color", Color("#46506a"))
	st_hbox.add_child(st_res)
	
	st_seed = Label.new()
	st_seed.text = "Seed: " + str(world_seed)
	st_seed.add_theme_font_size_override("font_size", 9)
	st_seed.add_theme_color_override("font_color", Color("#3d4e68"))
	st_hbox.add_child(st_seed)
	
	# PLAYER POS INFO
	var st_player_lbl = Label.new()
	st_player_lbl.text = "Player:"
	st_player_lbl.add_theme_font_size_override("font_size", 9)
	st_player_lbl.add_theme_color_override("font_color", Color("#46506a"))
	st_hbox.add_child(st_player_lbl)
	
	pro_val_player_coords = Label.new()
	pro_val_player_coords.text = "---"
	pro_val_player_coords.add_theme_font_size_override("font_size", 10)
	pro_val_player_coords.add_theme_color_override("font_color", Color("#1a73e8"))
	st_hbox.add_child(pro_val_player_coords)

	var st_rmargin = Control.new()
	st_rmargin.custom_minimum_size.x = 8
	st_hbox.add_child(st_rmargin)
	
	# Initialize Legend
	_populate_legend()

func _add_layer_row(parent: Control, lname: String, color: Color, is_on: bool):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	
	var dot = Panel.new()
	dot.custom_minimum_size = Vector2(7, 7)
	var ds = StyleBoxFlat.new()
	ds.bg_color = color
	ds.set_corner_radius_all(100)
	dot.add_theme_stylebox_override("panel", ds)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	
	var lab = Label.new()
	lab.text = lname
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", Color("#a0aac0") if is_on else Color("#48546e"))
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)
	
	var tog = Button.new() # Simplified toggle
	tog.custom_minimum_size = Vector2(24, 13)
	tog.flat = true
	# Placeholder cho toggle
	row.add_child(tog)

func _create_tool_btn(tname: String, icon: Texture2D) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(28, 28)
	btn.flat = true
	btn.icon = icon
	btn.expand_icon = true
	btn.tooltip_text = tname
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn

func _on_map_area_resized():
	map_size = Vector2i(pro_map_area.size)
	_update_static_transform()

func _populate_legend():
	if !pro_legend_list: return
	for child in pro_legend_list.get_children(): child.queue_free()
	
	var biomes_to_show = STATIC_BIOMES
	if !active_biomes_snapshot.is_empty():
		biomes_to_show = active_biomes_snapshot
	
	var categories = ["polar", "temperate", "tropical", "arid", "special"]
	var cat_names = {
		"polar": "VÙNG LẠNH / CỰC",
		"temperate": "VÙNG ÔN ĐỚI",
		"tropical": "VÙNG NHIỆT ĐỚI",
		"arid": "VÙNG KHÔ HẠN",
		"special": "ĐẶC BIỆT & NƯỚC"
	}
	
	var grouped = {}
	for cat in categories:
		var cat_biomes = []
		for b in biomes_to_show:
			var climate = b.get("climate", "special")
			if climate == cat:
				cat_biomes.append(b)
		grouped[cat] = cat_biomes
		
	for cat in categories:
		if grouped[cat].is_empty(): continue
		
		var title_label = Label.new()
		title_label.text = cat_names[cat]
		title_label.add_theme_font_size_override("font_size", 9)
		title_label.add_theme_color_override("font_color", Color(0.3, 0.35, 0.45))
		if pro_legend_list.get_child_count() > 0:
			var spacer = Control.new()
			spacer.custom_minimum_size.y = 8
			pro_legend_list.add_child(spacer)
		pro_legend_list.add_child(title_label)
		
		var grid = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.custom_minimum_size.y = 60 # Tối thiểu 1 hàng card
		pro_legend_list.add_child(grid)
		
		for b in grouped[cat]:
			var b_color = b.color
			if b_color is String: # If from JSON snapshot
				var c_plain = b_color.replace("(", "").replace(")", "").replace(" ", "")
				var parts = c_plain.split(",")
				if parts.size() >= 3:
					b_color = Color(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]) if parts.size() > 3 else 1.0)
				else:
					b_color = Color.WHITE
			
			var card = _build_biome_card(b, b_color)
			grid.add_child(card)

func _build_biome_card(b: Dictionary, b_color: Color) -> PanelContainer:
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(165, 52)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_stylebox_override("panel", sb_glass_card)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	container.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)
	
	# Color Badge
	var badge_box = CenterContainer.new()
	badge_box.custom_minimum_size = Vector2(16, 16)
	hbox.add_child(badge_box)
	
	var dot = Panel.new()
	dot.custom_minimum_size = Vector2(12, 12)
	var ds = StyleBoxFlat.new()
	ds.bg_color = b_color
	ds.set_corner_radius_all(3)
	dot.add_theme_stylebox_override("panel", ds)
	badge_box.add_child(dot)
	
	var label_vbox = VBoxContainer.new()
	label_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_vbox.add_theme_constant_override("separation", -2)
	hbox.add_child(label_vbox)
	
	var name_lab = Label.new()
	name_lab.text = b.name
	name_lab.add_theme_font_size_override("font_size", 11)
	name_lab.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label_vbox.add_child(name_lab)
	
	var desc_lab = Label.new()
	desc_lab.text = b.get("desc", "")
	desc_lab.add_theme_font_size_override("font_size", 8)
	desc_lab.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	desc_lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label_vbox.add_child(desc_lab)
	
	return container


func _exit_tree():
	_exit_thread = true
	_render_semaphore.post()
	if _render_thread: _render_thread.wait_to_finish()
	

func _process(delta):
	if !visible: return

	if player_node and is_instance_valid(player_node):
		var tp: Vector2
		if orchestrator:
			tp = orchestrator.local_to_cartesian_idx(player_node.global_position)
		else:
			# Shared formula fallback
			var px = player_node.global_position.x; var py = player_node.global_position.y
			tp.x = (px / 250.0 + py / 125.0) / 2.0
			tp.y = (py / 125.0 - px / 250.0) / 2.0

		world_player_pos = tp # CRITICAL FIX: Update the marker's source variable

		if pro_val_player_coords:
			pro_val_player_coords.text = "%d : %d" % [int(tp.x), int(tp.y)]
		
		# --- SYNC AUDIT (When Opening Map) ---
		if _sync_audit_pending:
			_sync_audit_pending = false
			var map_pos = view_center
			var game_pos = tp
			var dist = map_pos.distance_to(game_pos)
			print(">>>> [SYNC-AUDIT] WorldMap vs Game Engine <<<<")
			print("  Map Center: %s" % map_pos)
			print("  Game Player: %s" % game_pos)
			print("  Precision:  %s" % ("100% PERFECT" if dist < 0.01 else "OFFSET DETECTED: %.4f tiles" % dist))
			print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")

	# NAVIGATION: Move view_center and update static transform
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
	
	# Force square aspect ratio (1:1) based on viewport height
	side = float(map_size.y)
	scaled_size = Vector2(side, side) / view_zoom
	texture_rect.size = scaled_size
	
	# Purged [MAP-TRANSFORM] noise
	
	# Math for positioning:
	# 1. Pixels per tile index
	var pixels_per_tile = scaled_size.x / float(world_limit * 2)
	
	# 2. Position of view_center relative to texture top-left
	var texture_center = Vector2(scaled_size) / 2.0
	var offset_from_origin = view_center * pixels_per_tile
	var view_pos_on_texture = texture_center + offset_from_origin
	
	# 3. UI position of the TextureRect to center the view_center
	var ui_center = Vector2(map_size) / 2.0
	texture_rect.position = ui_center - view_pos_on_texture
	
	# Purged [VIEW-TRACE] noise
	
	# Update Player Marker
	if player_marker and is_instance_valid(player_marker):
		# Marker stays at its fixed Cartesian spot on the texture
		# center (0,0) is at texture_center
		var marker_offset = world_player_pos * pixels_per_tile
		var local_pos = texture_center + marker_offset
		
		player_marker.position = local_pos - player_marker.pivot_offset

# Throttle render requests to avoid spam
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
	# Get mouse coords ON TextureRect
	var local_m = texture_rect.get_local_mouse_position()
	
	# Pixels per tile index
	var pixels_per_tile = scaled_size.x / float(world_limit * 2)
	
	# Back-project from local mouse to tiles
	var offset_from_center_ui = local_m - (Vector2(scaled_size) / 2.0)
	var offset_tiles = offset_from_center_ui / pixels_per_tile
	
	var target_tile = view_center + offset_tiles
	var cur_gx = target_tile.x
	var cur_gy = target_tile.y

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

	if pro_val_x: pro_val_x.text = "X: " + str(int(cur_gx))
	if pro_val_y: pro_val_y.text = "Y: " + str(int(cur_gy))
	if pro_val_bio: pro_val_bio.text = b_name.capitalize()

func _input(event):
	if !visible: return
	var ctrl = Input.is_key_pressed(KEY_CTRL)
	if event is InputEventMouseButton:
		# Zoom using wheel
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: 
			_adjust_zoom(0.8 if ctrl else 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: 
			_adjust_zoom(1.25 if ctrl else 1.1)
			
		# Panning START
		if (event.button_index == MOUSE_BUTTON_MIDDLE) or (event.button_index == MOUSE_BUTTON_LEFT and cur_tool_pro == "pan"):
			if event.pressed:
				_is_panning = true
				_pan_start = event.position
				_view_start_cart = view_center
			else:
				_is_panning = false
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL: _adjust_zoom(0.8)
		elif event.keycode == KEY_MINUS: _adjust_zoom(1.2)
		elif event.keycode == KEY_F5: 
			print("[MAP-UI] Refresh requested (F5)")
			_refresh_map()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var local_m = texture_rect.get_local_mouse_position()
		var pixels_per_tile = scaled_size.x / float(world_limit * 2)
		
		# Back-project click to tiles
		var offset_from_center_ui = local_m - (Vector2(scaled_size) / 2.0)
		var offset_tiles = offset_from_center_ui / pixels_per_tile
		
		_last_click_tile = view_center + offset_tiles

		if _last_rendered_img:
			print("[MAP-DEBUG] Click: ViewCenter:%s | Tile:%s" % [view_center, _last_click_tile])
		
		_context_menu.position = get_screen_transform() * event.position
		_context_menu.popup()

	if event is InputEventMouseMotion and _is_fully_rendered:
		if _is_panning:
			var delta_p = event.position - _pan_start
			var pixels_per_tile = scaled_size.x / float(world_limit * 2)
			
			# New view center in tiles
			view_center = _view_start_cart - (delta_p / pixels_per_tile)
			_update_static_transform()

func _refresh_map():
	# Delete current cache and re-render
	var path = _get_cache_path()
	print("[MAP-UI] Deleting cache: ", path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_is_fully_rendered = false
	_render_map()

func _adjust_zoom(factor: float):
	view_zoom = clamp(view_zoom * factor, 0.01, 2.0) # Zoom out to 0.01 to see whole world
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
	# Standardized world size (Radius 1000 -> Width 2000)
	var world_size = float(world_limit * 2)
	
	# Match the main map's viewable area
	# Standardized world size (Radius 1000 -> Width 2000 is legacy, now world_limit*2)
	var viewport_w = (map_size.x / side * (world_limit * 2.0) * view_zoom / world_size) * mm_size.x
	var viewport_h = (map_size.y / side * (world_limit * 2.0) * view_zoom / world_size) * mm_size.y
	
	# Center view_center in the world
	var vx = ((view_center.x + world_limit) / world_size) * mm_size.x - (viewport_w / 2.0)
	var vy = ((view_center.y + world_limit) / world_size) * mm_size.y - (viewport_h / 2.0)
	
	viewport_box.size = Vector2(viewport_w, viewport_h)
	viewport_box.position = Vector2(vx, vy)

func _thread_render_loop():
	while true:
		_render_semaphore.wait()
		if _exit_thread: break
		
		# Clear queue if many requests pile up
		while _render_semaphore.try_wait(): pass
		
		# Render Full World
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
			
			# Debug log for center point
			if x == res / 2 and y == res / 2:
				printerr("[DEBUG-SDF] Center Sample | Pos:%v | Land:%f" % [gpos, engine.get_land_value(gpos)])
			
			var land_base = engine.get_land_value(gpos)
			var land_noisy = land_base + (noise_detail.get_noise_2d(gx * 0.1, gy * 0.1) * 0.05 if noise_detail else 0.0)
			
			var col: Color
			if land_noisy > engine.OCEAN_THRESHOLD: 
				col = Color("#0b2e46")        # Deep sea
			else:
				var bd = engine.get_biome(gpos, land_noisy)
				# Skip drawing rivers on map to remove blue artifacts
				col = _get_color_blueprint(land_noisy, bd["biome"], 1.0, 0.0, 0.5, gpos)
			
			img.set_pixel(x, y, col)
	
	_last_rendered_img = img
	# Save cache
	img.save_png(path)
	print("[MAP-CACHE] Saved new cache: %s" % path)
	print("[MAP-RENDER] Full world render COMPLETED at: ", Time.get_ticks_msec())
	call_deferred("_finish_full_render", img)

func _get_cache_path() -> String:
	# If there is an override path, add hash to cache name
	var suffix = ""
	if !_current_override_path.is_empty():
		suffix = "_" + str(_current_override_path.hash())
	
	# Bump version to v22 to force mandatory Isometric re-render
	return "user://map_cache/%s_%s%s_%s.png" % [continent_type.replace(" ", "_"), world_seed, suffix, MAP_CACHE_VERSION]

func _finish_full_render(img: Image):
	var tex = ImageTexture.create_from_image(img)
	if texture_rect:
		texture_rect.texture = tex
	_is_fully_rendered = true
	_update_static_transform()
	# Render Minimap too
	_render_minimap_worker()

# ---------------------------------------------------------------
# RENDER WORKER - Optimized low-res render to speed up
# ---------------------------------------------------------------
func _render_worker(center: Vector2, zoom: float):
	var img = Image.create(render_size.x, render_size.y, false, Image.FORMAT_RGBA8)
	
	# Cache local refs for faster access in loop
	var engine = shape_engine
	var n_river = noise_river
	var n_forest = noise_forest
	
	var r_w = render_size.x
	var r_h = render_size.y
	
	# Calculate bounding box of view to optimize world pos calculation
	# Standardize: Zoom 1.0 = full world (world_limit * 2.0)
	# Calculate Isometric center in Pixels
	var center_pixels = cartesian_idx_to_local(center)
	
	# World pixel step per render pixel (Isometric perspective)
	# Square viewport of pixels to match game perspective
	var world_w_px = float(world_limit) * 500.0
	var step_p = (world_w_px * zoom) / float(r_w)

	for y in range(r_h):
		if _exit_thread: return
		var py = center_pixels.y + (y - r_h/2.0) * step_p
		
		for x in range(r_w):
			var px = center_pixels.x + (x - r_w/2.0) * step_p
			
			# Back-project World-Pixel (px, py) to Cartesian Index (gpos)
			var gpos = local_to_cartesian_idx(Vector2(px, py))
			var gx = gpos.x; var gy = gpos.y
			
			var pixel_color: Color

			if engine:
				# --- PATH: shape_engine ---
				var land = engine.get_land_value(gpos)
				
				# Simplified sea/land (Threshold > 0.1 is water)
				if land > 0.1:
					pixel_color = Color("#0b2e46")
					img.set_pixel(x, y, pixel_color)
					continue
				
				var bd = engine.get_biome(gpos, land)

				# River logic
				var r_val = 1.0
				if land > 0.15 and noise_river:
					var flow = noise_river.get_noise_2d(gx, gy)
					if abs(flow) < 0.038: r_val = 0.0
					elif abs(flow) < 0.055: r_val = 0.5

				var f_val = 0.0
				if land > 0.15 and noise_forest:
					f_val = noise_forest.get_noise_2d(gx, gy)
				
				var s_val = 0.5
				pixel_color = _get_color_blueprint(land, bd["biome"], r_val, f_val, s_val, gpos)
			else:
				# --- FALLBACK LEGACY PATH ---
				pixel_color = _get_color_legacy(gx, gy)

			img.set_pixel(x, y, pixel_color)

	call_deferred("_update_at_main_thread", img)

# ---------------------------------------------------------------
# MINIMAP WORKER - Threaded
# ---------------------------------------------------------------
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
			if land > 0.1:
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

# ---------------------------------------------------------------
# COLOR MAPPING - Blueprint path
# ---------------------------------------------------------------
func _get_color_blueprint(land: float, biome: String, r_val: float, f_val: float, s_val: float, gpos: Vector2) -> Color:
	# Sea (Threshold > 0.1 is water)
	if land > 0.1: return Color("#0b2e46")

	# River (Disabled blue color here to avoid borders)
	# if r_val < 0.3: return Color("#2e86c1")
	# if r_val < 0.7: return Color("#1a5276").lerp(Color("#2ecc71"), 0.5)

	# Biome (Synced with Biome Painter)
	match biome:
		"tundra":      return Color("#8aabb8")
		"taiga":       return Color("#4d6d5d")
		"desert":      return Color("#d4ac0d")
		"salt_desert": return Color("#ddeef8")
		"savannah":    return Color("#f7dc6f")
		"jungle":      return Color("#1e5c30")
		"forest":      return Color("#3a7a45")
		"plains":      return Color("#7ab648")
		"bamboo":      return Color("#5c3a2a")
		"volcano":
			if land > 0.6: return Color("#1a1a1a")
			return Color("#9a3020")
		"beach":       return Color("#2a6896")
		"deep_sea":    return Color("#1a3a6b")
		"coal":        return Color("#2b2b2b")
		_:             return Color("#2ecc71")

# ---------------------------------------------------------------
# HOVER BIOME NAME
# ---------------------------------------------------------------
func _get_biome_name_legacy(gx: float, gy: float) -> String:
	if not noise_terrain: return "N/A"
	var n = noise_terrain.get_noise_2d(gx, gy) - 0.1
	if n < -0.4: return "Deep Sea (legacy)"
	if n < -0.32: return "Beach (legacy)"
	return "Plains (legacy)"

func _get_biome_name(land: float, biome: String) -> String:
	match biome:
		"deep_sea":  return "Deep Sea"
		"beach":     return "Beach"
		"tundra":    return "Tundra"
		"taiga":     return "Taiga"
		"desert":    return "Desert"
		"salt_desert": return "Salt Desert"
		"jungle":    return "Jungle"
		"forest":    return "Forest"
		"savannah":  return "Savannah"
		"plains":    return "Plains"
		"bamboo":    return "Bamboo"
		"volcano":   return "Volcano"
		"coal":      return "Coal"
		_: return biome

# ---------------------------------------------------------------
# LEGACY COLOR (Fallback when no shape_engine)
# ---------------------------------------------------------------
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

func _set_tool_pro(t: String):
	cur_tool_pro = t
	if st_tool: st_tool.text = "Tool: " + t.capitalize()
	
	# Highlight active button
	for k in pro_tool_btns:
		var btn = pro_tool_btns[k]
		if k == t:
			btn.self_modulate = Color(0.3, 0.5, 0.9) # Blueish
		else:
			btn.self_modulate = Color.WHITE

func local_to_cartesian_idx(world_pos: Vector2) -> Vector2:
	# Isometric Math for 500x250 tiles (MUST MATCH ORCHESTRATOR)
	var px = world_pos.x; var py = world_pos.y
	var ix = (px / 250.0 + py / 125.0) / 2.0
	var iy = (py / 125.0 - px / 250.0) / 2.0
	return Vector2(ix, iy)

func cartesian_idx_to_local(idx: Vector2) -> Vector2:
	# px = (ix - iy) * 250
	# py = (ix + iy) * 125
	return Vector2((idx.x - idx.y) * 250.0, (idx.x + idx.y) * 125.0)
