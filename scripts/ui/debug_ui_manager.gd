# scripts/ui/debug_ui_manager.gd
# Module quản lý giao diện Debug, Menu Pause và HUD
extends Node

# ═══════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════
var ui_layer: CanvasLayer
var pause_menu_layer: CanvasLayer
var settings_menu: CanvasLayer
var world_map_instance: CanvasLayer

# UI Labels
var ui_fps: Label
var ui_zoom: Label
var ui_statics: Label
var ui_lighting: Label
var ui_flicker_time: Label
var ui_chunk_time: Label
var ui_queue_lbl: Label

# Profiler Labels
var ui_prof_noise: Label
var ui_prof_tiles: Label
var ui_prof_objects: Label
var ui_prof_physics: Label

# Sliders & Buttons (References for values)
var show_2d_checkbox: CheckBox
var scale_slider: HSlider
var x_slider: HSlider
var y_slider: HSlider

# Tham chiếu Orchestrator
var orchestrator = null

# ═══════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════
func setup(_orchestrator):
	orchestrator = _orchestrator
	_setup_debug_ui()
	_setup_pause_menu()
	_setup_settings_menu()
	_setup_world_map()

func _setup_debug_ui():
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	ui_layer.layer = 100
	ui_layer.visible = false

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.8)
	style.corner_radius_top_left = 12; style.corner_radius_bottom_left = 12
	style.corner_radius_top_right = 12; style.corner_radius_bottom_right = 12
	style.set_content_margin_all(15)
	style.border_width_left = 2
	style.border_color = Color(0.3, 0.5, 0.8, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(340, 0)
	ui_layer.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# World Info
	var lbl_world = Label.new()
	lbl_world.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	lbl_world.add_theme_font_size_override("font_size", 11)
	vbox.add_child(lbl_world)
	_update_world_info_label(lbl_world)

	# V-Sync
	var vsync_check = CheckBox.new()
	vsync_check.text = "V-Sync"
	vsync_check.toggled.connect(func(t):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if t else DisplayServer.VSYNC_DISABLED)
	)
	vbox.add_child(vsync_check)

	vbox.add_child(HSeparator.new())

	# 2D Controls
	var lbl_2d = Label.new(); lbl_2d.text = "--- [2D BUILDING VISUALS] ---"
	lbl_2d.add_theme_color_override("font_color", Color(0, 1.0, 0.4))
	vbox.add_child(lbl_2d)

	scale_slider = HSlider.new(); scale_slider.min_value = 0.1; scale_slider.max_value = 4.0; scale_slider.value = 1.0; scale_slider.step = 0.01; vbox.add_child(scale_slider)
	show_2d_checkbox = CheckBox.new(); show_2d_checkbox.text = "Hiện 2D Sprite"; show_2d_checkbox.button_pressed = true; vbox.add_child(show_2d_checkbox)
	x_slider = HSlider.new(); x_slider.min_value = -500.0; x_slider.max_value = 500.0; x_slider.value = 0.0; vbox.add_child(x_slider)
	y_slider = HSlider.new(); y_slider.min_value = -500.0; y_slider.max_value = 500.0; y_slider.value = 0.0; vbox.add_child(y_slider)

	vbox.add_child(HSeparator.new())

	# Performance
	ui_fps = Label.new(); ui_fps.add_theme_color_override("font_color", Color.YELLOW); vbox.add_child(ui_fps)
	ui_zoom = Label.new(); ui_zoom.add_theme_color_override("font_color", Color.CYAN); vbox.add_child(ui_zoom)
	ui_statics = Label.new(); vbox.add_child(ui_statics)
	ui_lighting = Label.new(); vbox.add_child(ui_lighting)
	ui_flicker_time = Label.new(); vbox.add_child(ui_flicker_time)
	ui_chunk_time = Label.new(); vbox.add_child(ui_chunk_time)
	ui_queue_lbl = Label.new(); ui_queue_lbl.add_theme_color_override("font_color", Color.ORANGE); vbox.add_child(ui_queue_lbl)

	vbox.add_child(HSeparator.new())
	
	# Profiler
	var lbl_prof = Label.new(); lbl_prof.text = "--- [PROFILER] ---"; vbox.add_child(lbl_prof)
	ui_prof_noise = Label.new(); vbox.add_child(ui_prof_noise)
	ui_prof_tiles = Label.new(); vbox.add_child(ui_prof_tiles)
	ui_prof_objects = Label.new(); vbox.add_child(ui_prof_objects)
	ui_prof_physics = Label.new(); vbox.add_child(ui_prof_physics)

	vbox.add_child(HSeparator.new())
	
	# Teleport Menu
	var lbl_tp = Label.new(); lbl_tp.text = "--- [TELEPORT TO BIOME] ---"; lbl_tp.add_theme_color_override("font_color", Color.VIOLET); vbox.add_child(lbl_tp)
	var hf_tp = FlowContainer.new(); vbox.add_child(hf_tp)
	var biomes = ["Desert", "Jungle", "Tundra", "Taiga", "Plains", "Volcano", "Forest", "Bamboo"]
	for b_type in biomes:
		var btn = Button.new()
		btn.text = b_type
		btn.pressed.connect(func(): orchestrator.teleport_to_nearest_biome(b_type.to_lower()))
		hf_tp.add_child(btn)

func _update_world_info_label(lbl: Label):
	if not orchestrator.shape_engine: return
	lbl.add_theme_color_override("font_color", Color.GREEN)
	lbl.text = "Seed: %d | Template: %s\nStatus: Stable World" % [orchestrator.world_seed, orchestrator.active_continent_type]

func _setup_pause_menu():
	pause_menu_layer = CanvasLayer.new(); pause_menu_layer.layer = 110
	add_child(pause_menu_layer); pause_menu_layer.visible = false
	
	var blur_rect = ColorRect.new()
	blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat = ShaderMaterial.new(); mat.shader = load("res://shaders/screen_blur.gdshader")
	blur_rect.material = mat; pause_menu_layer.add_child(blur_rect)
	
	var pause_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.7); style.corner_radius_top_left = 20; style.corner_radius_bottom_left = 20; style.corner_radius_top_right = 20; style.corner_radius_bottom_right = 20; style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2; style.border_color = Color(0.4, 1.0, 0.6, 0.4); style.set_content_margin_all(40)
	pause_panel.add_theme_stylebox_override("panel", style)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_menu_layer.add_child(pause_panel)
	
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 20); pause_panel.add_child(vbox)
	var lbl_title = Label.new(); lbl_title.text = "GAME ĐÃ TẠM DỪNG"; lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lbl_title.add_theme_font_size_override("font_size", 32); lbl_title.add_theme_color_override("font_color", Color(0.4,1.0,0.8)); vbox.add_child(lbl_title)
	
	# Vùng thông tin World Failure đã bị gỡ bỏ vì hệ thống không còn được sử dụng

	vbox.add_child(HSeparator.new())
	var btn_resume = Button.new(); btn_resume.text = "TIẾP TỤC"; btn_resume.custom_minimum_size = Vector2(250, 60); btn_resume.pressed.connect(func(): toggle_pause_menu(false)); vbox.add_child(btn_resume)
	var btn_settings = Button.new(); btn_settings.text = "CÀI ĐẶT"; btn_settings.custom_minimum_size = Vector2(250, 60); btn_settings.pressed.connect(func(): pause_panel.visible = false; settings_menu.visible = true); vbox.add_child(btn_settings)
	var btn_quit = Button.new(); btn_quit.text = "THOÁT GAME"; btn_quit.custom_minimum_size = Vector2(250, 60); btn_quit.pressed.connect(func(): get_tree().quit()); vbox.add_child(btn_quit)

func _setup_settings_menu():
	var settings_scene = load("res://scenes/ui/settings_menu.tscn")
	if settings_scene:
		settings_menu = settings_scene.instantiate()
		add_child(settings_menu); settings_menu.visible = false
		var pause_panel = pause_menu_layer.get_child(1) # PanelContainer
		settings_menu.closed.connect(func(): pause_panel.visible = true)

func _setup_world_map():
	var wm_scene = load("res://scenes/ui/world_map.tscn")
	if wm_scene:
		world_map_instance = wm_scene.instantiate()
		world_map_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(world_map_instance)
		world_map_instance.visible = false
		var map_root = world_map_instance.get_node("Root")
		map_root.teleport_requested.connect(orchestrator._on_map_teleport_requested)

# ═══════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════
func toggle_pause_menu(active: bool):
	pause_menu_layer.visible = active
	get_tree().paused = active
	if active:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		pause_menu_layer.get_child(1).visible = true # PanelContainer
		if settings_menu: settings_menu.visible = false

func toggle_world_map(active: bool):
	world_map_instance.visible = active
	get_tree().paused = active
	
	# Đồng bộ ẩn/hiện HUD và các UI khác chuyên sâu hơn
	var scene_root = get_tree().current_scene
	if scene_root:
		# Tìm và ẩn HUD
		var hud = scene_root.find_child("HUD", true, false)
		if hud: hud.visible = !active
		
		# Tìm và ẩn các Layer UI khác (như đồng hồ, hotbar)
		var ui = scene_root.find_child("UI", true, false)
		if ui: ui.visible = !active

	if active:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		var cp = orchestrator.camera.global_position if orchestrator.camera else Vector2.ZERO
		
		# BYPASS TileMap transformation: map world pixels back to raw Cartesian indices 
		# This ensures view_center exactly matches the generation grid
		var map_root = world_map_instance.get_node("Root")
		var target_idx = orchestrator.local_to_cartesian_idx(cp)
		
		map_root.view_center = target_idx
		map_root.view_zoom = 1.0
		map_root.player_node = orchestrator.player if orchestrator.player else orchestrator.camera
		map_root.orchestrator = orchestrator
		map_root.setup_blueprint(orchestrator.shape_engine, orchestrator.active_continent_type, orchestrator.detail_noise, orchestrator.forest_noise, orchestrator.river_noise, orchestrator.warp_noise, orchestrator.map_size / 2, orchestrator.world_seed, orchestrator.override_biome_map)

func update_debug_labels(fps: float, t_noise: int, t_tiles: int, t_objects: int, t_physics: int, statics: int, lighting: int, queue_gen: int, queue_rem: int):
	if ui_fps:
		ui_fps.text = "FPS: %d (%.1f ms)" % [fps, 1000.0/fps if fps > 0 else 0]
		ui_fps.add_theme_color_override("font_color", Color.YELLOW if fps > 45 else Color.RED)
	if ui_zoom and orchestrator.camera:
		ui_zoom.text = "Zoom: %.2f x %.2f" % [orchestrator.camera.zoom.x, orchestrator.camera.zoom.y]
	if ui_statics: ui_statics.text = "Static objects: %d" % statics
	if ui_prof_noise: ui_prof_noise.text = "Noise: %.2f ms" % (t_noise / 1000.0)
	if ui_prof_tiles: ui_prof_tiles.text = "Tiles: %.2f ms" % (t_tiles / 1000.0)
	if ui_prof_objects: ui_prof_objects.text = "Objects: %.2f ms" % (t_objects / 1000.0)
	if ui_prof_physics: ui_prof_physics.text = "Physics: %.2f ms" % (t_physics / 1000.0)
	if ui_lighting: ui_lighting.text = "Lighting: %d" % lighting
	if ui_queue_lbl: ui_queue_lbl.text = "Queue (Gen/Del): %d / %d" % [queue_gen, queue_rem]
	
	if orchestrator.camera and ui_chunk_time:
		var cp = orchestrator.camera.global_position
		var tp = orchestrator.temp_layer.local_to_map(orchestrator.temp_layer.to_local(cp))
		var chunk_p = Vector2i(floorf(tp.x / 16.0), floorf(tp.y / 16.0))
		var b_name = orchestrator._get_biome_name_debug(Vector2(tp.x, tp.y))
		ui_chunk_time.text = "Coord: %.0f, %.0f | Tile: %d,%d | Chunk: %d,%d\nBiome: %s" % [cp.x, cp.y, tp.x, tp.y, chunk_p.x, chunk_p.y, b_name]
