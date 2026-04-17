# scripts/tools/biome_painter.gd
extends Control

# ═══════════════════════════════════════════════════════════════
# CONSTANTS & BIOMES
# ═══════════════════════════════════════════════════════════════
const CANVAS_SIZE = Vector2i(1024, 1024)
const SAVE_PATH = "res://assets/world/custom_biomes.png"

const BIOMES = [
	{"id": "deep_sea", "name": "Ocean", "sub": "Deep sea", "color": Color("#1a3a6b"), "dot": Color("#1e4d8c")},
	{"id": "beach", "name": "Shallow Water", "sub": "Coast / reef", "color": Color("#2a6896"), "dot": Color("#3490c0")},
	{"id": "beach_sand", "name": "Beach", "sub": "Sandy shore", "color": Color("#e8d5a0"), "dot": Color("#d4b872")},
	{"id": "plains", "name": "Grassland", "sub": "Plains & savanna", "color": Color("#7ab648"), "dot": Color("#5a9e2f")},
	{"id": "forest", "name": "Temperate Forest", "sub": "Deciduous trees", "color": Color("#3a7a45"), "dot": Color("#2d6236")},
	{"id": "jungle", "name": "Rainforest", "sub": "Tropical jungle", "color": Color("#1e5c30"), "dot": Color("#164523")},
	{"id": "desert", "name": "Desert", "sub": "Arid sands", "color": Color("#c8a050"), "dot": Color("#b07d2a")},
	{"id": "savannah", "name": "Savanna", "sub": "Dry woodland", "color": Color("#9aaf50"), "dot": Color("#7a8f30")},
	{"id": "tundra", "name": "Tundra", "sub": "Cold plains", "color": Color("#8aabb8"), "dot": Color("#6090a0")},
	{"id": "salt_desert", "name": "Snow / Ice", "sub": "Polar & alpine", "color": Color("#ddeef8"), "dot": Color("#b8d8ee")},
	{"id": "volcano", "name": "Volcano", "sub": "Lava & ash", "color": Color("#9a3020"), "dot": Color("#b84010")},
	{"id": "bamboo", "name": "Bamboo Forest", "sub": "Asian woodland", "color": Color("#5c7a3a"), "dot": Color("#4a6a2a")},
]

const CANVAS_OFFSET = Vector2(2000, 2000)

# ═══════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════
# Workspace Management
var workspaces: Array = []
var current_workspace_idx: int = -1

# Shorthand references (Updated on switch)
var canvas_image: Image
var canvas_texture: ImageTexture
var undo_stack: Array[Image] = []
var canvas_zoom: float = 1.0
var canvas_scroll: Vector2 = Vector2(2000, 2000) # Precise float-based scroll

# Mouse / Interaction State (Global or Workspace-specific)
var current_tool: String = "brush"
var current_biome_idx: int = 0
var is_drawing: bool = false
var brush_size: int = 22

# Workspace Viewport State
var is_zooming: bool = false
var is_panning: bool = false
var zoom_start_pos: Vector2
var zoom_pivot_pos: Vector2
var zoom_start_val: float
var pan_start_pos: Vector2
var canvas_start_pos: Vector2
var last_draw_pos: Vector2
var is_resizing_brush: bool = false
var resize_start_pos: Vector2
var resize_start_size: int
var zoom_start_mouse_v: Vector2

var pipette_cursor: Texture2D
var selection_start: Vector2 = Vector2.ZERO
var has_selection: bool = false

@onready var workspace_dock = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/WorkspaceDock
@onready var workspace_padding = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/WorkspaceDock/WorkspacePadding
@onready var canvas_content = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/WorkspaceDock/WorkspacePadding/CanvasContent
@onready var texture_rect = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/WorkspaceDock/WorkspacePadding/CanvasContent/TextureRect
@onready var selection_overlay = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/WorkspaceDock/WorkspacePadding/CanvasContent/SelectionOverlay
@onready var biome_list_container = $AppFrame/MainVerticalLayout/MainContentLayout/Sidebar/VBox/ListMargin/Scroll/VBoxContainer
@onready var tools_container = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarRight/VBox/ToolsMargin/Tools
@onready var brush_cursor = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/BrushCursor

@onready var tabs_bar = $AppFrame/MainVerticalLayout/Topbar/Margin/HBox/Tabs
@onready var modal_new_file = $OverlayLayer/NewFileModal
@onready var input_name = $OverlayLayer/NewFileModal/Center/Panel/Margin/VBox/Grid/InputName
@onready var input_w = $OverlayLayer/NewFileModal/Center/Panel/Margin/VBox/Grid/HBox/InputW
@onready var input_h = $OverlayLayer/NewFileModal/Center/Panel/Margin/VBox/Grid/HBox/InputH
@onready var btn_create = $OverlayLayer/NewFileModal/Center/Panel/Margin/VBox/Buttons/BtnCreate
@onready var btn_cancel = $OverlayLayer/NewFileModal/Center/Panel/Margin/VBox/Buttons/BtnCancel

@onready var st_tool = $AppFrame/MainVerticalLayout/StatusBar/Margin/HBox/ToolStatus
@onready var st_biome = $AppFrame/MainVerticalLayout/StatusBar/Margin/HBox/BiomeStatus
@onready var st_coord = $AppFrame/MainVerticalLayout/StatusBar/Margin/HBox/CoordStatus

# ═══════════════════════════════════════════════════════════════
# INIT
# ═══════════════════════════════════════════════════════════════

func _ready():
	_setup_initial_workspace()
	_build_biome_list()
	_connect_ui()
	_update_tool_ui()
	_update_brush_cursor_size()
	
	# Initial offsets & Guards
	canvas_content.position = CANVAS_OFFSET
	workspace_padding.layout_mode = 0 # Explicit Position mode
	workspace_padding.position = -canvas_scroll
	
	texture_rect.grow_horizontal = Control.GROW_DIRECTION_END
	texture_rect.grow_vertical = Control.GROW_DIRECTION_END
	canvas_content.grow_horizontal = Control.GROW_DIRECTION_END
	canvas_content.grow_vertical = Control.GROW_DIRECTION_END
	workspace_padding.grow_horizontal = Control.GROW_DIRECTION_END
	workspace_padding.grow_vertical = Control.GROW_DIRECTION_END
	
	# Initial centering
	_center_canvas.call_deferred()
	
	if ResourceLoader.exists("res://assets/ui/icons/pipette.svg"):
		pipette_cursor = load("res://assets/ui/icons/pipette.svg")

func _setup_initial_workspace():
	tabs_bar.tab_count = 0
	_create_workspace("Untitled-1", CANVAS_SIZE)
	tabs_bar.add_tab("Untitled-1")
	_switch_workspace(0)

func _create_workspace(ws_name: String, size: Vector2i):
	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(BIOMES[0].color) # Default color
	var tex = ImageTexture.create_from_image(img)
	
	var undo: Array[Image] = []
	var ws = {
		"name": ws_name,
		"image": img,
		"texture": tex,
		"undo_stack": undo,
		"zoom": 1.0,
		"scroll": Vector2(2000, 2000)
	}
	workspaces.append(ws)

func _switch_workspace(idx: int):
	# 1. Save old state
	if current_workspace_idx >= 0 and current_workspace_idx < workspaces.size():
		var old_ws = workspaces[current_workspace_idx]
		old_ws.zoom = canvas_zoom
		old_ws.scroll = canvas_scroll
		old_ws.undo_stack = undo_stack.duplicate()
	
	# 2. Load new state
	current_workspace_idx = idx
	var ws = workspaces[idx]
	
	canvas_image = ws.image
	canvas_texture = ws.texture
	undo_stack.assign(ws.undo_stack)
	canvas_zoom = ws.zoom
	canvas_scroll = ws.scroll
	
	# 3. Update Visuals
	texture_rect.texture = canvas_texture
	texture_rect.custom_minimum_size = ws.image.get_size()
	_update_zoom()
	
	workspace_padding.position = -canvas_scroll
	_update_custom_scrollbars()
	
	print("[WORKSPACE] Switched to: ", ws.name)

func _connect_ui():
	var btn_brush = tools_container.get_node("Brush")
	var btn_rect = tools_container.get_node("Rect")
	var btn_wand = tools_container.get_node("Wand")
	var btn_eraser = tools_container.get_node("Eraser")
	
	# Load Icons
	_setup_button_icon(btn_brush, "res://assets/ui/icons/brush.svg")
	_setup_button_icon(btn_rect, "res://assets/ui/icons/rect.svg")
	_setup_button_icon(btn_wand, "res://assets/ui/icons/wand.svg")
	_setup_button_icon(btn_eraser, "res://assets/ui/icons/eraser.svg")

	btn_brush.pressed.connect(set_tool.bind("brush"))
	btn_rect.pressed.connect(set_tool.bind("rect"))
	btn_wand.pressed.connect(set_tool.bind("wand"))
	btn_eraser.pressed.connect(set_tool.bind("eraser"))
	_on_brush_size_changed(brush_size)
	
	texture_rect.gui_input.connect(_on_canvas_gui_input)
	
	# Modal Connections
	btn_create.pressed.connect(_on_create_tab_pressed)
	btn_cancel.pressed.connect(_on_cancel_tab_pressed)
	tabs_bar.tab_changed.connect(_on_tab_changed)
	tabs_bar.tab_close_pressed.connect(_on_tab_close_pressed)

func _setup_button_icon(btn: Button, path: String):
	btn.text = "" 
	if ResourceLoader.exists(path):
		var tex = load(path)
		btn.icon = tex
	
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 20)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Force bright icons
	btn.self_modulate = Color(1.2, 1.2, 1.2, 1.0)

func _build_biome_list():
	for i in range(BIOMES.size()):
		var b = BIOMES[i]
		var container = PanelContainer.new()
		container.name = "Biome_" + str(i)
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Style for the item
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.set_bg_color(Color(1,1,1,0))
		container.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		container.add_child(hbox)
		
		# Margin for padding
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		hbox.add_child(margin)
		
		var inner_hbox = HBoxContainer.new()
		inner_hbox.add_theme_constant_override("separation", 12)
		margin.add_child(inner_hbox)
		
		# Color Dot (Square)
		var dot_container = CenterContainer.new()
		dot_container.custom_minimum_size = Vector2(40, 0)
		inner_hbox.add_child(dot_container)
		
		var dot = Panel.new()
		dot.custom_minimum_size = Vector2(28, 28)
		var dot_style = StyleBoxFlat.new()
		dot_style.bg_color = b.dot
		dot_style.set_corner_radius_all(6)
		dot.add_theme_stylebox_override("panel", dot_style)
		dot_container.add_child(dot)
		
		# Info
		var info = VBoxContainer.new()
		info.add_theme_constant_override("separation", -1)
		inner_hbox.add_child(info)
		
		var name_lab = Label.new()
		name_lab.text = b.name
		name_lab.add_theme_font_size_override("font_size", 13)
		name_lab.add_theme_color_override("font_color", Color("#eeeeee"))
		info.add_child(name_lab)
		
		var sub_lab = Label.new()
		sub_lab.text = b.sub
		sub_lab.add_theme_font_size_override("font_size", 11)
		sub_lab.add_theme_color_override("font_color", Color("#999999"))
		info.add_child(sub_lab)
		
		container.gui_input.connect(_on_biome_item_input.bind(i))
		biome_list_container.add_child(container)
	
	_update_biome_ui()

func _update_brush_cursor_position():
	if modal_new_file.visible:
		brush_cursor.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	var mouse_pos = get_global_mouse_position()
	var real_rect = _get_texture_real_rect()
	
	var is_over = real_rect.has_point(mouse_pos)
	var is_inside_viewport = workspace_dock.get_global_rect().has_point(mouse_pos)
	var is_alt_pick = Input.is_key_pressed(KEY_ALT) and current_tool == "brush"
	
	var show_preview = (is_over and is_inside_viewport or is_resizing_brush) and (current_tool == "brush" or current_tool == "eraser")
	
	if is_alt_pick and is_over and is_inside_viewport:
		brush_cursor.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if pipette_cursor:
			Input.set_custom_mouse_cursor(pipette_cursor, Input.CURSOR_ARROW, Vector2(0, 24))
		return
	else:
		Input.set_custom_mouse_cursor(null)
	
	brush_cursor.visible = show_preview
	
	if show_preview:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		if brush_cursor.size.x == 0:
			_update_brush_cursor_size()
		brush_cursor.global_position = mouse_pos - brush_cursor.size / 2
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _update_brush_cursor_size():
	# Screen-Relative Size: The brush always looks like N pixels on YOUR screen
	var d = brush_size
	brush_cursor.custom_minimum_size = Vector2(d, d)
	brush_cursor.size = Vector2(d, d)
	
	var style = brush_cursor.get_theme_stylebox("panel").duplicate()
	style.set_corner_radius_all(d / 2.0)
	style.border_color = Color.WHITE
	brush_cursor.add_theme_stylebox_override("panel", style)

func _process(_delta):
	_update_brush_cursor_position()

# ═══════════════════════════════════════════════════════════════
# DRAWING LOGIC
# ═══════════════════════════════════════════════════════════════

func _get_texture_real_rect() -> Rect2:
	return texture_rect.get_global_rect()

func _on_canvas_gui_input(event):
	var local_pos = _get_canvas_local_pos(event.global_position)
	st_coord.text = "X: %d Y: %d" % [int(local_pos.x), int(local_pos.y)]
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.alt_pressed and current_tool == "brush":
					_pick_biome_at_pos(local_pos)
					return
				_prepare_undo()
				is_drawing = true
				last_draw_pos = local_pos
				_apply_tool(local_pos)
			else:
				is_drawing = false
				_finalize_rect_tool(local_pos)
				
	elif event is InputEventMouseMotion and is_drawing:
		if current_tool == "brush" or current_tool == "eraser":
			_interpolate_draw(local_pos)
		else:
			_apply_tool(local_pos)

func _interpolate_draw(pos: Vector2):
	var dist = last_draw_pos.distance_to(pos)
	# Use small steps based on brush size to ensure continuity without performance hit
	var step = max(1.0, brush_size * 0.25)
	
	if dist > step:
		var steps = ceili(dist / step)
		for i in range(1, steps + 1):
			var p = last_draw_pos.lerp(pos, float(i) / steps)
			_apply_tool(p)
	else:
		_apply_tool(pos)
	
	last_draw_pos = pos

func _pick_biome_at_pos(pos: Vector2):
	var p = Vector2i(pos)
	var img_size = canvas_image.get_size()
	if p.x < 0 or p.x >= img_size.x or p.y < 0 or p.y >= img_size.y: return
	
	var color = canvas_image.get_pixel(p.x, p.y)
	for i in range(BIOMES.size()):
		if BIOMES[i].color.is_equal_approx(color):
			current_biome_idx = i
			_update_biome_ui()
			return


func _update_zoom():
	# Update size of the canvas sheet
	var img_size = canvas_image.get_size()
	var new_size = Vector2(img_size) * canvas_zoom
	canvas_content.custom_minimum_size = new_size
	canvas_content.size = new_size
	canvas_content.position = CANVAS_OFFSET
	# Crucial: Don't let min_size be larger than zoomed size
	texture_rect.custom_minimum_size = new_size 
	
	# Update parent content size to include padding
	workspace_padding.custom_minimum_size = new_size + CANVAS_OFFSET * 2
	
	_update_custom_scrollbars()
	_update_brush_cursor_size()

func _update_custom_scrollbars():
	pass # Minimalist UI: No scrollbars

func _perform_wheel_zoom(factor: float):
	var old_zoom = canvas_zoom
	var new_zoom = clamp(canvas_zoom * factor, 0.1, 10.0)
	if is_equal_approx(old_zoom, new_zoom): return
	
	var g_mouse = get_global_mouse_position()
	var g_sc = workspace_dock.global_position
	var g_tex = texture_rect.global_position
	
	var pivot_pixel = (g_mouse - g_tex) / old_zoom
	
	canvas_zoom = new_zoom
	_update_zoom()
	
	var target_g_tex = g_mouse - pivot_pixel * canvas_zoom
	canvas_scroll.x = g_sc.x + CANVAS_OFFSET.x - target_g_tex.x
	canvas_scroll.y = g_sc.y + CANVAS_OFFSET.y - target_g_tex.y
	
	workspace_padding.position = -canvas_scroll

func _input(event):
	# Panning Logic (Global override - bypasses node blocking)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if event.button_index == MOUSE_BUTTON_RIGHT and event.alt_pressed:
					is_resizing_brush = true
					resize_start_pos = event.position
					resize_start_size = brush_size
				else:
					is_panning = true
					pan_start_pos = event.position
					canvas_start_pos = canvas_scroll
				get_viewport().set_input_as_handled() 
			else:
				is_panning = false
				is_resizing_brush = false
	elif event is InputEventMouseMotion:
		if is_panning:
			var diff = event.position - pan_start_pos
			canvas_scroll = canvas_start_pos - diff
			workspace_padding.position = -canvas_scroll
			get_viewport().set_input_as_handled()
		elif is_resizing_brush:
			var diff = event.position.x - resize_start_pos.x
			var new_size = clamp(resize_start_size + int(diff * 0.5), 1, 100)
			if new_size != brush_size:
				_on_brush_size_changed(new_size)
			get_viewport().set_input_as_handled()

func _unhandled_input(event):
	# Global Shortcuts
	if event is InputEventKey and event.pressed:
		if event.ctrl_pressed and event.keycode == KEY_N:
			show_new_file_modal()
			get_viewport().set_input_as_handled()
			return

	# Mouse Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_perform_wheel_zoom(1.2)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_perform_wheel_zoom(0.8)
			get_viewport().set_input_as_handled()
	
	# Scrubby Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_Z):
			if event.pressed:
				is_zooming = true
				zoom_start_pos = event.position
				zoom_start_val = canvas_zoom
				
				var m_v = workspace_dock.get_local_mouse_position()
				var m_c = workspace_padding.get_local_mouse_position()
				zoom_pivot_pos = (m_c - CANVAS_OFFSET) / canvas_zoom 
				zoom_start_mouse_v = m_v 
			else:
				is_zooming = false
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_zooming:
		var diff = event.position.x - zoom_start_pos.x
		var zoom_mult = 1.0 + (diff / 200.0)
		var new_zoom = clamp(zoom_start_val * zoom_mult, 0.1, 10.0)
		
		if new_zoom != canvas_zoom:
			canvas_zoom = new_zoom
			_update_zoom()
			
			var m_v = zoom_start_mouse_v
			canvas_scroll.x = CANVAS_OFFSET.x + zoom_pivot_pos.x * canvas_zoom - m_v.x
			canvas_scroll.y = CANVAS_OFFSET.y + zoom_pivot_pos.y * canvas_zoom - m_v.y
			workspace_padding.position = -canvas_scroll
			
		get_viewport().set_input_as_handled()

	# Keyboard Shortcuts
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_B: set_tool("brush")
			KEY_M: set_tool("rect")
			KEY_W: set_tool("wand")
			KEY_E: set_tool("eraser")
			KEY_Z: if event.ctrl_pressed: undo()
			KEY_S: if event.ctrl_pressed: export_image()
			KEY_0: 
				if event.ctrl_pressed:
					canvas_zoom = 1.0
					_update_zoom()
					_center_canvas()

	# Pan with Space bar
	if event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not is_panning:
			is_panning = true
			pan_start_pos = get_viewport().get_mouse_position()
			canvas_start_pos = canvas_scroll
		elif not event.pressed:
			is_panning = false
	
func _on_workspace_dock_resized():
	pass # Disabled centering as it conflicts with zoom

func _center_canvas():
	var v_size = workspace_dock.size
	var img_size = Vector2(CANVAS_SIZE)
	
	canvas_scroll.x = CANVAS_OFFSET.x + (img_size.x * canvas_zoom - v_size.x) / 2
	canvas_scroll.y = CANVAS_OFFSET.y + (img_size.y * canvas_zoom - v_size.y) / 2
	workspace_padding.position = -canvas_scroll
	_update_custom_scrollbars()

func _get_canvas_local_pos(_global_pos: Vector2) -> Vector2:
	# Using Global coordinate transform to remain absolute and avoid hierarchy drift
	return (get_global_mouse_position() - texture_rect.global_position) / canvas_zoom

func _apply_tool(pos: Vector2, force_erase: bool = false):
	var color = BIOMES[0].color if (current_tool == "eraser" or force_erase) else BIOMES[current_biome_idx].color
	var p = Vector2i(pos)
	
	# Mapping Screen-Space brush size to World-Space radius
	# actual_radius = (diameter/2) / zoom
	var actual_radius = (brush_size / 2.0) / canvas_zoom
	
	match current_tool:
		"brush", "eraser": _draw_brush(p, int(actual_radius), color)
		"rect": _update_selection_preview(pos)
		"wand":
			if is_drawing: 
				_flood_fill(p, color)
				is_drawing = false
	_update_texture()

func _draw_brush(center: Vector2i, radius: int, color: Color):
	var r = radius
	if r <= 0:
		if _is_pos_valid(center): canvas_image.set_pixelv(center, color)
		return
		
	# Optimization: Scanline fill using C++ backend fill_rect
	# reducing complexity from R^2 to R
	var img_size = canvas_image.get_size()
	for y in range(-r, r + 1):
		var target_y = center.y + y
		if target_y < 0 or target_y >= img_size.y: continue
		
		# Solve x for x^2 + y^2 <= r^2
		var dx = int(sqrt(r*r - y*y))
		var x_start = max(0, center.x - dx)
		var x_end = min(img_size.x - 1, center.x + dx)
		
		if x_start <= x_end:
			var rect = Rect2i(x_start, target_y, x_end - x_start + 1, 1)
			canvas_image.fill_rect(rect, color)

func _finalize_rect_tool(pos: Vector2):
	if current_tool != "rect": return
	var p1 = Vector2i(selection_start); var p2 = Vector2i(pos)
	var rect = Rect2i(p1, p2 - p1).abs()
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if _is_pos_valid(Vector2i(x, y)):
				canvas_image.set_pixel(x, y, BIOMES[current_biome_idx].color)
	selection_overlay.visible = false
	_update_texture()

func _flood_fill(start_pos: Vector2i, new_color: Color):
	if not _is_pos_valid(start_pos): return
	var old_color = canvas_image.get_pixelv(start_pos)
	if old_color.is_equal_approx(new_color): return
	var stack = [start_pos]; var visited = {}; var count = 0
	while stack.size() > 0 and count < 150000:
		var p = stack.pop_back()
		if visited.has(p): continue
		visited[p] = true
		if canvas_image.get_pixelv(p).is_equal_approx(old_color):
			canvas_image.set_pixelv(p, new_color); count += 1
			for n in [Vector2i(p.x+1, p.y), Vector2i(p.x-1, p.y), Vector2i(p.x, p.y+1), Vector2i(p.x, p.y-1)]:
				if _is_pos_valid(n): stack.push_back(n)

# ═══════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════

func _is_pos_valid(p: Vector2i) -> bool:
	var img_size = canvas_image.get_size()
	return p.x >= 0 and p.y >= 0 and p.x < img_size.x and p.y < img_size.y

func _update_texture(): canvas_texture.update(canvas_image)

func _prepare_undo():
	undo_stack.push_back(canvas_image.duplicate())
	if undo_stack.size() > 30: undo_stack.pop_front()

func _update_selection_preview(pos: Vector2):
	if not selection_overlay.visible:
		selection_start = pos; selection_overlay.visible = true
	var p1 = selection_start; var p2 = pos
	var size = (p2 - p1).abs(); var origin = Vector2(min(p1.x, p2.x), min(p1.y, p2.y))
	var img_size = canvas_image.get_size()
	var canvas_to_overlay = selection_overlay.get_parent().size / Vector2(img_size)
	selection_overlay.position = origin * canvas_to_overlay
	selection_overlay.size = size * canvas_to_overlay

# ═══════════════════════════════════════════════════════════════
# UI UPDATES
# ═══════════════════════════════════════════════════════════════

func set_tool(tool_name: String):
	current_tool = tool_name
	_update_tool_ui()

func _on_biome_item_input(event, idx):
	if event is InputEventMouseButton and event.pressed:
		current_biome_idx = idx
		_update_biome_ui()

func _on_brush_size_changed(value: float):
	brush_size = int(value)
	_update_brush_cursor_size()

func _update_tool_ui():
	for child in tools_container.get_children():
		if child is Button:
			var is_active = (child.name.to_lower() == current_tool.to_lower())
			if is_active:
				var active_style = child.get_theme_stylebox("pressed")
				child.add_theme_stylebox_override("normal", active_style)
				child.add_theme_color_override("icon_normal_color", Color("#378ADD"))
			else:
				child.remove_theme_stylebox_override("normal")
				child.add_theme_color_override("icon_normal_color", Color.WHITE)
				
	st_tool.text = "Tool: " + current_tool.capitalize()

func _update_biome_ui():
	for i in range(biome_list_container.get_child_count()):
		var item = biome_list_container.get_child(i)
		var style = item.get_theme_stylebox("panel").duplicate()
		if i == current_biome_idx:
			style.bg_color = Color("#264f78") 
			style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
			style.border_color = Color("#378ADD")
		else:
			style.bg_color = Color(1,1,1,0)
			style.border_width_left = 0; style.border_width_top = 0; style.border_width_right = 0; style.border_width_bottom = 0
		item.add_theme_stylebox_override("panel", style)
	st_biome.text = "Biome: " + BIOMES[current_biome_idx].name

func undo():
	if undo_stack.is_empty(): return
	canvas_image = undo_stack.pop_back()
	_update_texture()

func export_image():
	var err = canvas_image.save_png(SAVE_PATH)
	if err == OK: print("[PAINTER] Saved to ", SAVE_PATH)

# ═══════════════════════════════════════════════════════════════
# WORKSPACE & MODAL
# ═══════════════════════════════════════════════════════════════

func show_new_file_modal():
	modal_new_file.show()
	input_name.grab_focus()
	input_name.select_all()

func _on_create_tab_pressed():
	var f_name = input_name.text.strip_edges()
	if f_name == "": f_name = "Untitled"
	
	var w = input_w.text.to_int()
	var h = input_h.text.to_int()
	if w <= 0: w = 1024
	if h <= 0: h = 1024
	
	# Create Data
	_create_workspace(f_name, Vector2i(w, h))
	
	# Update UI
	tabs_bar.add_tab(f_name)
	tabs_bar.current_tab = tabs_bar.tab_count - 1
	# Switch is triggered by signal tab_changed, which we'll handle
	
	modal_new_file.hide()
	print("[WORKSPACE] Created: ", f_name, " Size: ", w, "x", h)

func _on_cancel_tab_pressed():
	modal_new_file.hide()

func _on_tab_changed(idx: int):
	if idx >= 0 and idx < workspaces.size():
		_switch_workspace(idx)

func _on_tab_close_pressed(idx: int):
	if workspaces.size() <= 1:
		# Không cho đóng tab cuối cùng, hoặc hiện modal chọn mới
		show_new_file_modal()
		return
		
	workspaces.remove_at(idx)
	tabs_bar.remove_tab(idx)
	
	# Nếu đóng tab đang active, chuyển sang tab lân cận
	if current_workspace_idx == idx:
		var new_idx = clamp(idx, 0, workspaces.size() - 1)
		_switch_workspace(new_idx)
	elif current_workspace_idx > idx:
		current_workspace_idx -= 1
