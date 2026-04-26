# scripts/tools/biome_painter.gd
extends Control

# ═══════════════════════════════════════════════════════════════
# CONSTANTS & BIOMES
# ═══════════════════════════════════════════════════════════════
const CANVAS_SIZE = Vector2i(1024, 1024)
const SAVE_PATH = "res://assets/world/custom_biomes.png"

var TILES: Array = []
var STATIC_BIOMES: Array = [
	{"id": "plains", "name": "Đồng bằng", "color": Color("#7ab648"), "desc": "Bản đồ cỏ xanh mượt", "climate": "temperate"},
	{"id": "tundra", "name": "Vùng tuyết", "color": Color("#8aabb8"), "desc": "Nơi băng giá vĩnh cửu", "climate": "polar"},
	{"id": "desert", "name": "Sa mạc", "color": Color("#d4ac0d"), "desc": "Cát vàng mênh mông", "climate": "arid"},
	{"id": "salt_desert", "name": "Sa mạc muối", "color": Color("#ddeef8"), "desc": "Cánh đồng muối trắng xóa", "climate": "arid"},
	{"id": "volcano", "name": "Vùng núi lửa", "color": Color("#9a3020"), "desc": "Dòng lava nóng bỏng", "climate": "special"},
	{"id": "deep_sea", "name": "Vùng đại dương", "color": Color("#1a3a6b"), "desc": "Đại dương xanh thẳm", "climate": "special"},
	{"id": "beach", "name": "Vùng sông, hồ", "color": Color("#2a6896"), "desc": "Hồ nước ngọt hiền hòa", "climate": "special"},
	{"id": "coal", "name": "Vùng than đá", "color": Color("#2b2b2b"), "desc": "Mỏ than đá trù phú", "climate": "special"},
	{"id": "bamboo", "name": "Vùng rừng cây cà phê", "color": Color("#5c3a2a"), "desc": "Rừng cà phê thơm ngát", "climate": "tropical"},
	{"id": "forest", "name": "Vùng rừng cây maple", "color": Color("#3a7a45"), "desc": "Rừng phong đỏ thắm", "climate": "temperate"},
	{"id": "jungle", "name": "Vùng rừng cây oak", "color": Color("#1e5c30"), "desc": "Rừng sồi già cỗi", "climate": "temperate"},
	{"id": "taiga", "name": "Vùng rừng cây pine", "color": Color("#4d6d5d"), "desc": "Rừng thông bạt ngàn", "climate": "polar"},
]
var current_sidebar_view = "tiles"

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
var brush_size: int = 1
var brush_shape: BrushShape = BrushShape.ROUND

# Workspace Viewport State
var is_zooming: bool = false
var is_panning: bool = false
var zoom_start_pos: Vector2
var zoom_pivot_pos: Vector2
var zoom_start_val: float
var pan_start_pos: Vector2
var canvas_start_pos: Vector2
var last_draw_pos: Vector2
var last_click_pos: Vector2 = Vector2(-1, -1)
var current_save_path: String = ""
enum SelectionMode { REPLACE, ADD, SUBTRACT, INTERSECT }
enum BrushShape { ROUND, SQUARE }
var current_selection_mode = SelectionMode.REPLACE
var selection_mask: BitMap
var poly_points: Array[Vector2] = []
var poly_line: Line2D

# Inspector State
var inspected_biome_id: String = ""
var inspected_pixels: int = 0
var inspected_mask: ImageTexture

var wand_cursor_tex: Texture2D
var zoom_start_mouse_v: Vector2

var pipette_cursor: Texture2D
var selection_start: Vector2 = Vector2.ZERO
var has_selection: bool = false

# Move Tool State
var is_moving_ref: bool = false
var move_drag_start_canvas_pos: Vector2
var move_drag_start_ref_pos: Vector2

@onready var workspace_dock = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/WorkspaceContainer/WorkspaceDock
@onready var workspace_padding = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/WorkspaceContainer/WorkspaceDock/WorkspacePadding
@onready var canvas_content = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/WorkspaceContainer/WorkspaceDock/WorkspacePadding/CanvasContent
@onready var texture_rect = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/WorkspaceContainer/WorkspaceDock/WorkspacePadding/CanvasContent/TextureRect
@onready var selection_overlay = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/WorkspaceContainer/WorkspaceDock/WorkspacePadding/CanvasContent/SelectionOverlay
@onready var biome_list_container = $AppFrame/MainVerticalLayout/MainContentLayout/Sidebar/VBox/ListMargin/Scroll/SectionsContainer
@onready var tools_container = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarRight/VBox/ToolsMargin/Tools
@onready var brush_cursor = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/BrushCursor
@onready var sidebar_left = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarLeft
@onready var btn_terrain = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarLeft/VBox/TerrainMargin/TerrainTools/BtnTerrain
@onready var btn_biomes = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarLeft/VBox/TerrainMargin/TerrainTools/BtnBiomes
@onready var btn_inspect = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarLeft/VBox/TerrainMargin/TerrainTools/BtnInspect
@onready var inspector_panel = $AppFrame/MainVerticalLayout/MainContentLayout/Sidebar/VBox/ListMargin/InspectorPanel
@onready var biome_scroll = $AppFrame/MainVerticalLayout/MainContentLayout/Sidebar/VBox/ListMargin/Scroll
@onready var inspector_overlay = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/WorkspaceContainer/WorkspaceDock/WorkspacePadding/CanvasContent/InspectorOverlay

@onready var tabs_bar = $AppFrame/MainVerticalLayout/Topbar/Margin/HBox/Tabs
@onready var modal_new_file = $OverlayLayer/NewFileModal
@onready var save_dialog = $SaveDialog
@onready var open_dialog = $OpenDialog

# Tool Options UI
@onready var tool_options_bar = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar
@onready var selection_mask_buffer = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/WorkspaceContainer/WorkspaceDock/WorkspacePadding/CanvasContent/SelectionMaskBuffer
@onready var selection_options = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/ModeGroup
@onready var mode_btns = {
	SelectionMode.REPLACE: $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/ModeGroup/BtnReplace,
	SelectionMode.ADD: $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/ModeGroup/BtnAdd,
	SelectionMode.SUBTRACT: $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/ModeGroup/BtnSub,
	SelectionMode.INTERSECT: $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/ModeGroup/BtnIntersect
}

@onready var brush_options = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/BrushOptions
@onready var brush_shape_round = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/BrushOptions/ShapeGroup/BtnShapeRound
@onready var brush_shape_square = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/BrushOptions/ShapeGroup/BtnShapeSquare
@onready var brush_size_input = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/BrushOptions/SizeInput

@onready var eraser_options = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/EraserOptions
@onready var eraser_shape_round = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/EraserOptions/ShapeGroup/BtnShapeRound
@onready var eraser_shape_square = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/EraserOptions/ShapeGroup/BtnShapeSquare
@onready var eraser_size_input = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/EraserOptions/SizeInput

@onready var reference_options = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/ReferenceOptions
@onready var btn_load_ref = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/ToolOptionsBar/Margin/ReferenceOptions/BtnLoad
@onready var reference_opacity_input = %OpacityInput
@onready var reference_overlay = $AppFrame/MainVerticalLayout/MainContentLayout/CanvasArea/VBox/WorkspaceContainer/WorkspaceDock/WorkspacePadding/CanvasContent/ReferenceOverlay
@onready var reference_transform = %ReferenceTransform
@onready var reference_dialog = $ReferenceDialog

var is_transforming_ref = false
var dragging_handle = ""
var is_dragging_ref = false
var drag_start_pos = Vector2.ZERO
var ref_start_rect = Rect2()
var ref_aspect_ratio = 1.0
var current_ref_path = ""

@onready var btn_move = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarRight/VBox/ToolsMargin/Tools/Move
@onready var btn_brush = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarRight/VBox/ToolsMargin/Tools/Brush
@onready var btn_rect = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarRight/VBox/ToolsMargin/Tools/Rect
@onready var btn_wand = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarRight/VBox/ToolsMargin/Tools/Wand
@onready var btn_eraser = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarRight/VBox/ToolsMargin/Tools/Eraser
@onready var btn_inspector = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarRight/VBox/ToolsMargin/Tools/Inspector
@onready var btn_reference = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarRight/VBox/ToolsMargin/Tools/Reference
@onready var btn_poly = $AppFrame/MainVerticalLayout/MainContentLayout/SidebarRight/VBox/ToolsMargin/Tools/PolyLasso

@onready var input_name = $OverlayLayer/NewFileModal/Center/Panel/Margin/VBox/Grid/InputName
@onready var input_w = $OverlayLayer/NewFileModal/Center/Panel/Margin/VBox/Grid/HBox/InputW
@onready var input_h = $OverlayLayer/NewFileModal/Center/Panel/Margin/VBox/Grid/HBox/InputH
@onready var btn_create = $OverlayLayer/NewFileModal/Center/Panel/Margin/VBox/Buttons/BtnCreate
@onready var btn_cancel = $OverlayLayer/NewFileModal/Center/Panel/Margin/VBox/Buttons/BtnCancel

@onready var st_tool = $AppFrame/MainVerticalLayout/StatusBar/Margin/HBox/ToolStatus
@onready var st_biome = $AppFrame/MainVerticalLayout/StatusBar/Margin/HBox/BiomeStatus
@onready var st_coord = $AppFrame/MainVerticalLayout/StatusBar/Margin/HBox/CoordStatus

@onready var style_active: StyleBoxFlat = _create_active_style()
@onready var style_normal: StyleBoxEmpty = StyleBoxEmpty.new()

# Card Styles
var card_style_normal: StyleBoxFlat
var card_style_hover: StyleBoxFlat
var card_style_active: StyleBoxFlat

func _init_card_styles():
	card_style_normal = StyleBoxFlat.new()
	card_style_normal.set_bg_color(Color(1, 1, 1, 0.03))
	card_style_normal.set_corner_radius_all(8)
	card_style_normal.border_width_left = 1
	card_style_normal.border_width_top = 1
	card_style_normal.border_width_right = 1
	card_style_normal.border_width_bottom = 1
	card_style_normal.border_color = Color(1, 1, 1, 0.05)

	card_style_hover = card_style_normal.duplicate()
	card_style_hover.set_bg_color(Color(1, 1, 1, 0.08))
	card_style_hover.border_color = Color(1, 1, 1, 0.15)

	card_style_active = card_style_normal.duplicate()
	card_style_active.set_bg_color(Color(0.2, 0.45, 0.85, 0.15))
	card_style_active.border_color = Color(0.2, 0.45, 0.85, 0.6)

func _create_active_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.35, 0.6) # Deep blue
	s.set_corner_radius_all(4)
	return s

# ═══════════════════════════════════════════════════════════════
# INIT
# ═══════════════════════════════════════════════════════════════

func _ready():
	_init_card_styles()
	_load_tiles_from_disk()
	_setup_initial_workspace()
	_build_biome_list() 
	_connect_ui()
	_setup_poly_tool()
	_update_tool_ui()
	_update_tool_options_visibility()
	_update_brush_cursor_size()
	_load_sidebar_icons()
	_update_sidebar_buttons()
	
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
	if ResourceLoader.exists("res://assets/ui/icons/wand_cursor.svg"):
		wand_cursor_tex = load("res://assets/ui/icons/wand_cursor.svg")
	
	_setup_button_icon(btn_terrain, "res://assets/ui/icons/terrain_tile.svg", 22)
	
	_setup_selection_ui()
	
	# Register Input Actions via Script
	if not InputMap.has_action("ui_ref_transform"):
		InputMap.add_action("ui_ref_transform")
		var ev = InputEventKey.new()
		ev.ctrl_pressed = true
		ev.keycode = KEY_T
		InputMap.action_add_event("ui_ref_transform", ev)

	# Automatically load world1.entmap
	_perform_load("res://assets/world/world1.entmap")

func _setup_poly_tool():
	_setup_button_icon(btn_move, "res://assets/ui/icons/move.svg", 20)
	_setup_button_icon(btn_poly, "res://assets/ui/icons/pencil_line.svg", 18)
	
	poly_line = Line2D.new()
	poly_line.width = 1.0 / canvas_zoom
	poly_line.default_color = Color.WHITE
	poly_line.closed = false
	canvas_content.add_child(poly_line)
	poly_line.hide()

func _setup_initial_workspace():
	tabs_bar.tab_count = 0
	_switch_workspace(-1)

func _create_workspace(ws_name: String, size: Vector2i):
	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var fill_color = Color.BLACK
	# Default to Deep Sea biome color for initialization
	for b in STATIC_BIOMES:
		if b.id == "deep_sea":
			fill_color = b.color
			break
	
	if fill_color == Color.BLACK:
		fill_color = STATIC_BIOMES[0].color
		
	img.fill(fill_color)
	var tex = ImageTexture.create_from_image(img)
	
	var undo: Array[Image] = []
	var mask = BitMap.new()
	mask.create(size)
	
	var ws = {
		"name": ws_name,
		"image": img,
		"texture": tex,
		"undo_stack": undo,
		"selection_mask": mask,
		"zoom": 1.0,
		"scroll": Vector2(2000, 2000),
		"save_path": "",
		"ref_path": "",
		"ref_pos": Vector2.ZERO,
		"ref_size": Vector2(512, 512),
		"ref_opacity": 0.5
	}
	workspaces.append(ws)

func _switch_workspace(idx: int):
	# 1. Save old state
	if current_workspace_idx >= 0 and current_workspace_idx < workspaces.size():
		var old_ws = workspaces[current_workspace_idx]
		old_ws.zoom = canvas_zoom
		old_ws.scroll = canvas_scroll
		old_ws.save_path = current_save_path
		old_ws.undo_stack = undo_stack.duplicate()
		# Store Logical (unzoomed) coordinates
		old_ws.ref_pos = reference_overlay.position / canvas_zoom
		old_ws.ref_size = reference_overlay.size / canvas_zoom
		old_ws.ref_opacity = reference_overlay.modulate.a
	
	# 2. Handle Empty State
	if idx < 0 or workspaces.is_empty():
		current_workspace_idx = -1
		workspace_dock.visible = false
		tool_options_bar.visible = false
		print("[WORKSPACE] Entering Empty State")
		return
		
	# 3. Load new state
	workspace_dock.visible = true
	tool_options_bar.visible = true
	current_workspace_idx = idx
	var ws = workspaces[idx]
	
	canvas_image = ws.image
	canvas_texture = ws.texture
	undo_stack.assign(ws.undo_stack)
	selection_mask = ws.selection_mask
	canvas_zoom = ws.zoom
	canvas_scroll = ws.scroll
	current_save_path = ws.save_path
	
	# 4. Update Visuals
	texture_rect.texture = canvas_texture
	texture_rect.custom_minimum_size = ws.image.get_size()
	_update_zoom()
	
	workspace_padding.position = -canvas_scroll
	_update_custom_scrollbars()
	_update_selection_visual()
	_apply_workspace_reference(ws)
	
	print("[WORKSPACE] Switched to: ", ws.name)

func _connect_ui():
	btn_biomes.pressed.connect(_on_btn_biomes_pressed)
	btn_terrain.pressed.connect(_on_btn_tiles_pressed)
	btn_inspect.pressed.connect(_on_btn_inspect_pressed)
	
	var btn_brush = tools_container.get_node("Brush")
	var btn_rect = tools_container.get_node("Rect")
	var btn_wand = tools_container.get_node("Wand")
	var btn_eraser = tools_container.get_node("Eraser")
	var btn_inspector = tools_container.get_node("Inspector")
	
	# Load Icons
	_setup_button_icon(btn_brush, "res://assets/ui/icons/brush.svg", 18)
	_setup_button_icon(btn_rect, "res://assets/ui/icons/rect.svg", 18)
	_setup_button_icon(btn_wand, "res://assets/ui/icons/wand.svg", 18)
	_setup_button_icon(btn_eraser, "res://assets/ui/icons/eraser.svg", 18)
	_setup_button_icon(btn_inspector, "res://assets/ui/icons/inspector.svg", 18)

	btn_brush.pressed.connect(set_tool.bind("brush"))
	btn_rect.pressed.connect(set_tool.bind("rect"))
	btn_wand.pressed.connect(set_tool.bind("wand"))
	btn_eraser.pressed.connect(set_tool.bind("eraser"))
	btn_inspector.pressed.connect(set_tool.bind("inspector"))
	_on_brush_size_changed(brush_size)
	
	texture_rect.gui_input.connect(_on_canvas_gui_input)
	
	# Modal Connections
	btn_create.pressed.connect(_on_create_tab_pressed)
	btn_cancel.pressed.connect(_on_cancel_tab_pressed)
	input_name.text_changed.connect(_on_new_file_name_changed)
	tabs_bar.tab_changed.connect(_on_tab_changed)
	tabs_bar.tab_close_pressed.connect(_on_tab_close_pressed)

	save_dialog.file_selected.connect(_on_save_dialog_file_selected)
	open_dialog.file_selected.connect(_on_open_dialog_file_selected)
	reference_dialog.file_selected.connect(_on_ref_dialog_file_selected)
	
	btn_brush.pressed.connect(func(): set_tool("brush"))
	btn_rect.pressed.connect(func(): set_tool("rect"))
	btn_wand.pressed.connect(func(): set_tool("wand"))
	btn_eraser.pressed.connect(func(): set_tool("eraser"))
	btn_inspector.pressed.connect(func(): set_tool("inspector"))
	btn_reference.pressed.connect(func(): set_tool("reference"))
	btn_poly.pressed.connect(func(): set_tool("poly_lasso"))
	btn_move.pressed.connect(func(): set_tool("move"))
	
	btn_load_ref.pressed.connect(_on_load_reference_pressed)
	reference_opacity_input.text_submitted.connect(_on_opacity_input_submitted)
	reference_opacity_input.focus_exited.connect(func(): _on_opacity_input_submitted(reference_opacity_input.text))

	# Reference Transform Connect
	for handle in reference_transform.get_children():
		handle.gui_input.connect(_on_handle_gui_input.bind(handle.name))
	reference_transform.gui_input.connect(_on_transform_gui_input)

	# Brush/Eraser Options Connect
	_setup_button_icon(brush_shape_round, "res://assets/ui/icons/brush_round.svg", 14)
	_setup_button_icon(brush_shape_square, "res://assets/ui/icons/brush_square.svg", 14)
	_setup_button_icon(eraser_shape_round, "res://assets/ui/icons/brush_round.svg", 14)
	_setup_button_icon(eraser_shape_square, "res://assets/ui/icons/brush_square.svg", 14)
	
	brush_shape_round.pressed.connect(_set_brush_shape.bind(BrushShape.ROUND))
	brush_shape_square.pressed.connect(_set_brush_shape.bind(BrushShape.SQUARE))
	brush_size_input.text_submitted.connect(_on_brush_size_submitted)
	brush_size_input.focus_exited.connect(func(): _on_brush_size_submitted(brush_size_input.text))
	
	eraser_shape_round.pressed.connect(_set_brush_shape.bind(BrushShape.ROUND))
	eraser_shape_square.pressed.connect(_set_brush_shape.bind(BrushShape.SQUARE))
	eraser_size_input.text_submitted.connect(_on_eraser_size_submitted)
	eraser_size_input.focus_exited.connect(func(): _on_eraser_size_submitted(eraser_size_input.text))
	
	_update_tool_options_ui()

func _set_brush_shape(shape: BrushShape):
	brush_shape = shape
	_update_tool_options_ui()
	_update_brush_cursor_shape()

func _on_brush_size_submitted(new_text: String):
	var val = new_text.to_int()
	if val > 0: _on_brush_size_changed(val)

func _on_eraser_size_submitted(new_text: String):
	var val = new_text.to_int()
	if val > 0: _on_brush_size_changed(val)

func _update_brush_cursor_shape():
	var sb = brush_cursor.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.corner_radius_top_left = 0 if brush_shape == BrushShape.SQUARE else 1024
		sb.corner_radius_top_right = 0 if brush_shape == BrushShape.SQUARE else 1024
		sb.corner_radius_bottom_left = 0 if brush_shape == BrushShape.SQUARE else 1024
		sb.corner_radius_bottom_right = 0 if brush_shape == BrushShape.SQUARE else 1024

func _update_tool_options_ui():
	brush_size_input.text = str(brush_size)
	eraser_size_input.text = str(brush_size)
	
	var is_square = (brush_shape == BrushShape.SQUARE)
	brush_shape_round.set_pressed_no_signal(!is_square)
	brush_shape_square.set_pressed_no_signal(is_square)
	eraser_shape_round.set_pressed_no_signal(!is_square)
	eraser_shape_square.set_pressed_no_signal(is_square)
	
	# Set icons for toggles
	_setup_button_icon(brush_shape_round, "res://assets/ui/icons/brush_round.svg", 18)
	_setup_button_icon(brush_shape_square, "res://assets/ui/icons/brush_square.svg", 18)
	_setup_button_icon(eraser_shape_round, "res://assets/ui/icons/brush_round.svg", 18)
	_setup_button_icon(eraser_shape_square, "res://assets/ui/icons/brush_square.svg", 18)
	
	_update_brush_cursor_shape()

func _setup_button_icon(btn: Button, path: String, max_w: int = 24):
	btn.text = "" 
	if ResourceLoader.exists(path):
		var tex = load(path)
		btn.icon = tex
	
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", max_w)
	btn.add_theme_color_override("icon_normal_color", Color.WHITE)
	btn.add_theme_color_override("icon_hover_color", Color.WHITE)
	btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
	btn.add_theme_color_override("icon_focus_color", Color.WHITE)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	
	# Clear previous background overrides as new icons have their own frames
	btn.add_theme_stylebox_override("normal", style_normal)
	
	btn.self_modulate = Color(1, 1, 1, 1)

func _setup_selection_ui():
	var icons = {
		SelectionMode.REPLACE: "res://assets/ui/icons/sel_replace.svg",
		SelectionMode.ADD: "res://assets/ui/icons/sel_add.svg",
		SelectionMode.SUBTRACT: "res://assets/ui/icons/sel_sub.svg",
		SelectionMode.INTERSECT: "res://assets/ui/icons/sel_intersect.svg"
	}
	
	for mode in mode_btns:
		var btn = mode_btns[mode]
		_setup_button_icon(btn, icons[mode], 26)
		btn.pressed.connect(_set_selection_mode.bind(mode))
	
	_update_selection_mode_ui()

func _build_biome_list():
	for child in biome_list_container.get_children():
		child.queue_free()
	
	if current_sidebar_view == "biomes":
		_build_static_biome_view()
	else:
		_build_tile_sections_view()

func _build_static_biome_view():
	var categories = ["polar", "temperate", "tropical", "arid", "special"]
	var cat_names = {
		"polar": "VÙNG LẠNH / CỰC",
		"temperate": "VÙNG ÔN ĐỚI",
		"tropical": "VÙNG NHIỆT ĐỚI",
		"arid": "VÙNG KHÔ HẠN",
		"special": "ĐẶC BIỆT & NƯỚC"
	}
	
	var grouped = {}
	for cat in categories: grouped[cat] = []
	
	for i in range(STATIC_BIOMES.size()):
		var b = STATIC_BIOMES[i].duplicate()
		b["index"] = i
		var c = b.get("climate", "temperate")
		if grouped.has(c):
			grouped[c].append(b)
	
	for cat in categories:
		if grouped[cat].is_empty(): continue
		
		# Title label
		var title_label = Label.new()
		title_label.text = cat_names[cat]
		title_label.add_theme_font_size_override("font_size", 10)
		title_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		
		# Thêm margin phía trên cho tiêu đề trừ nhóm đầu tiên
		if biome_list_container.get_child_count() > 0:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 12)
			biome_list_container.add_child(spacer)
			
		biome_list_container.add_child(title_label)
		
		var grid = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		biome_list_container.add_child(grid)
		
		for b in grouped[cat]:
			var card = _build_tile_card(b, true) # color_mode = true
			grid.add_child(card)
	
	_update_biome_ui()

func _build_tile_sections_view():
	var categories = ["grounds", "fluids", "overlays"]
	var grouped = { "grounds": [], "fluids": [], "overlays": [] }
	
	for i in range(TILES.size()):
		var t = TILES[i].duplicate()
		t["index"] = i
		if grouped.has(t.category):
			grouped[t.category].append(t)
	
	for cat in categories:
		if grouped[cat].is_empty(): continue
		var title_label = Label.new()
		title_label.text = cat.capitalize()
		title_label.add_theme_font_size_override("font_size", 10)
		title_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		biome_list_container.add_child(title_label)
		
		var grid = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		biome_list_container.add_child(grid)
		
		for t in grouped[cat]:
			var card = _build_tile_card(t)
			grid.add_child(card)
	
	_update_biome_ui()

func _build_tile_card(t: Dictionary, force_color: bool = false) -> PanelContainer:
	var container = PanelContainer.new()
	container.name = "Item_" + str(t.index)
	container.custom_minimum_size = Vector2(0, 52)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.add_theme_stylebox_override("panel", card_style_normal)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	container.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)
	
	# Badge (Căn lề trên để khớp với dòng chữ đầu tiên)
	var badge_wrap = VBoxContainer.new()
	hbox.add_child(badge_wrap)
	
	# Spacer nhỏ bên trên badge để nó ngang hàng với text name
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 2)
	badge_wrap.add_child(top_spacer)
	
	var badge_box = CenterContainer.new()
	badge_box.custom_minimum_size = Vector2(20, 20)
	badge_wrap.add_child(badge_box)
	
	if force_color:
		var dot = Panel.new()
		dot.custom_minimum_size = Vector2(14, 14)
		var ds = StyleBoxFlat.new()
		ds.bg_color = t.color
		ds.set_corner_radius_all(4)
		dot.add_theme_stylebox_override("panel", ds)
		badge_box.add_child(dot)
	else:
		var empty = Control.new()
		empty.custom_minimum_size = Vector2(20, 20)
		badge_box.add_child(empty)
		
	var label_vbox = VBoxContainer.new()
	label_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_vbox.add_theme_constant_override("separation", -1)
	hbox.add_child(label_vbox)
	
	var name_lab = Label.new()
	name_lab.text = t.name
	name_lab.add_theme_font_size_override("font_size", 12)
	name_lab.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label_vbox.add_child(name_lab)
	
	if t.has("desc"):
		var desc_lab = Label.new()
		desc_lab.text = t.desc
		desc_lab.add_theme_font_size_override("font_size", 9)
		desc_lab.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.5))
		desc_lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label_vbox.add_child(desc_lab)
	
	# Interactive logic
	container.focus_mode = Control.FOCUS_ALL
	container.mouse_entered.connect(func(): if current_biome_idx != t.index: container.add_theme_stylebox_override("panel", card_style_hover))
	container.mouse_exited.connect(func(): if current_biome_idx != t.index: container.add_theme_stylebox_override("panel", card_style_normal))
	container.focus_entered.connect(func(): if current_biome_idx != t.index: container.add_theme_stylebox_override("panel", card_style_hover))
	container.focus_exited.connect(func(): if current_biome_idx != t.index: container.add_theme_stylebox_override("panel", card_style_normal))
	container.gui_input.connect(_on_biome_item_input.bind(t.index))
	
	return container

func _on_btn_biomes_pressed():
	current_sidebar_view = "biomes"
	_update_sidebar_buttons()
	_update_sidebar_view()

func _on_btn_tiles_pressed():
	current_sidebar_view = "tiles"
	_update_sidebar_buttons()
	_update_sidebar_view()

func _on_btn_inspect_pressed():
	current_sidebar_view = "inspect"
	_update_sidebar_buttons()
	_update_sidebar_view()

func _update_sidebar_view():
	biome_scroll.visible = (current_sidebar_view != "inspect")
	inspector_panel.visible = (current_sidebar_view == "inspect")
	if current_sidebar_view != "inspect":
		_build_biome_list()

func _update_sidebar_buttons():
	btn_biomes.add_theme_stylebox_override("normal", style_active if current_sidebar_view == "biomes" else style_normal)
	btn_terrain.add_theme_stylebox_override("normal", style_active if current_sidebar_view == "tiles" else style_normal)
	btn_inspect.add_theme_stylebox_override("normal", style_active if current_sidebar_view == "inspect" else style_normal)

func _load_sidebar_icons():
	var terrain_icon = btn_terrain.get_node_or_null("Margin/Icon")
	if terrain_icon: terrain_icon.texture = load("res://assets/ui/icons/terrain_tile.svg")
	
	var biomes_icon = btn_biomes.get_node_or_null("Margin/Icon")
	if biomes_icon: biomes_icon.texture = load("res://assets/ui/icons/biomes.svg")
	
	var inspect_icon = btn_inspect.get_node_or_null("Margin/Icon")
	if inspect_icon: inspect_icon.texture = load("res://assets/ui/icons/land_plot.svg")
	
	# Disable manual interaction for Inspect tab in SidebarLeft
	btn_inspect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _get_active_list() -> Array:
	return STATIC_BIOMES if current_sidebar_view == "biomes" else TILES

func _load_tiles_from_disk():
	TILES.clear()
	var categories = ["grounds", "fluids", "overlays"]
	
	for cat in categories:
		var base_path = "res://assets/tiles/" + cat
		var dir = DirAccess.open(base_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if dir.current_is_dir() and not file_name.begins_with("."):
					var full_path = base_path + "/" + file_name
					_add_tile_from_disk(full_path, file_name, cat)
				file_name = dir.get_next()
	
	if TILES.is_empty():
		TILES = [{"id": "fallback", "name": "Standard Tile", "color": Color("#5a8a2a"), "category": "grounds", "icon_path": ""}]

func _add_tile_from_disk(path: String, id: String, category: String):
	var tile = {
		"id": id,
		"name": id.replace("_", " ").capitalize(),
		"category": category,
		"color": _generate_tile_color(id),
		"icon_path": path + "/" + id + "_item.png"
	}
	
	var info_path = path + "/info.json"
	if FileAccess.file_exists(info_path):
		var file = FileAccess.open(info_path, FileAccess.READ)
		var json = JSON.parse_string(file.get_as_text())
		if json:
			tile["name"] = json.get("display_name", tile["name"])
	
	TILES.append(tile)

func _generate_tile_color(id_str: String) -> Color:
	var h = abs(id_str.hash()) % 360 / 360.0
	return Color.from_hsv(h, 0.65, 0.8)

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
	var is_wand_tool = current_tool == "wand"
	
	var show_preview = (is_over and is_inside_viewport) and (current_tool == "brush" or current_tool == "eraser")
	
	if is_alt_pick and is_over and is_inside_viewport:
		brush_cursor.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if pipette_cursor:
			Input.set_custom_mouse_cursor(pipette_cursor, Input.CURSOR_ARROW, Vector2(0, 24))
		return
	elif is_wand_tool and is_over and is_inside_viewport:
		brush_cursor.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if wand_cursor_tex:
			Input.set_custom_mouse_cursor(wand_cursor_tex, Input.CURSOR_ARROW, Vector2(12, 12))
		return
	else:
		Input.set_custom_mouse_cursor(null)
	
	brush_cursor.visible = show_preview
	
	if show_preview:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		if brush_cursor.size.x == 0:
			_update_brush_cursor_size()
		
		# Pixel Snapping: Calculate the snapped global position
		var local_pos = _get_canvas_local_pos(mouse_pos)
		var snapped_local = _get_snapped_pos(local_pos, brush_size)
		var snapped_global = _canvas_to_global_pos(snapped_local)
		
		brush_cursor.global_position = snapped_global - brush_cursor.size / 2
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _canvas_to_global_pos(canvas_pos: Vector2) -> Vector2:
	return canvas_pos * canvas_zoom + texture_rect.global_position

func _update_brush_cursor_size():
	# Canvas-Relative Size: The brush size is in canvas pixels,
	# so on screen it scales with zoom.
	var d = brush_size * canvas_zoom
	brush_cursor.custom_minimum_size = Vector2(d, d)
	brush_cursor.size = Vector2(d, d)
	
	var style = brush_cursor.get_theme_stylebox("panel").duplicate()
	if brush_shape == BrushShape.SQUARE:
		style.set_corner_radius_all(0)
	else:
		style.set_corner_radius_all(d / 2.0)
	style.border_color = Color.WHITE
	brush_cursor.add_theme_stylebox_override("panel", style)

func _get_snapped_pos(pos: Vector2, size: int) -> Vector2:
	if size % 2 == 0:
		# Even size: Snap to the corner where pixels meet (integers)
		return pos.round()
	else:
		# Odd size: Snap to the center of a pixel
		return pos.floor() + Vector2(0.5, 0.5)

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
				if event.double_click and current_tool == "poly_lasso":
					_finalize_poly_tool()
					return

				if event.alt_pressed and current_tool == "brush":
					_pick_biome_at_pos(local_pos)
					return
				
				if current_tool == "wand":
					_apply_wand_selection(local_pos)
					return

				_prepare_undo()
				is_drawing = true
				
				if event.shift_pressed and last_click_pos.x >= 0:
					last_draw_pos = last_click_pos
					_interpolate_draw(local_pos)
				else:
					_apply_tool(local_pos)
					last_draw_pos = local_pos
				
				last_click_pos = local_pos
			else:
				is_drawing = false
				if current_tool == "rect":
					_finalize_rect_tool(local_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if current_tool == "poly_lasso":
					if poly_points.size() > 0:
						poly_points.pop_back()
						_update_poly_preview()
					else:
						set_tool("brush") # Cancel tool if no points
		
	elif event is InputEventMouseMotion:
		if is_drawing:
			if current_tool == "brush" or current_tool == "eraser":
				_interpolate_draw(local_pos)
			else:
				_apply_tool(local_pos)
		
		if current_tool == "poly_lasso":
			_update_poly_preview()

func _on_poly_lasso_input(local_pos: Vector2):
	var p = local_pos
	if poly_points.size() > 2:
		# Check if near start point (10 pixel radius in canvas space)
		if p.distance_to(poly_points[0]) < 10.0 / canvas_zoom:
			_finalize_poly_tool()
			return
	
	poly_points.append(p)
	_update_poly_preview()

func _update_poly_preview():
	if current_tool != "poly_lasso" or poly_points.is_empty():
		poly_line.hide()
		return
	
	poly_line.show()
	poly_line.width = 2.0 / canvas_zoom
	
	var points = poly_points.duplicate()
	var mouse_pos = _get_canvas_local_pos(get_global_mouse_position())
	points.append(mouse_pos)
	
	# Scale points to match the zoomed canvas_content size
	for i in range(points.size()):
		points[i] *= canvas_zoom
	
	poly_line.points = points

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
	var list = _get_active_list()
	for i in range(list.size()):
		if list[i].color.is_equal_approx(color):
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
	_update_brush_cursor_size()
	
	# Update parent content size to include padding
	workspace_padding.custom_minimum_size = new_size + CANVAS_OFFSET * 2
	
	_update_custom_scrollbars()
	_update_brush_cursor_size()
	
	if current_workspace_idx >= 0:
		_apply_workspace_reference(workspaces[current_workspace_idx])

func _update_custom_scrollbars():
	pass # Minimalist UI: No scrollbars

func _perform_wheel_zoom(factor: float):
	var old_zoom = canvas_zoom
	var new_zoom = clamp(canvas_zoom * factor, 0.1, 50.0)
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

func _is_mouse_over_workspace() -> bool:
	var mouse_pos = get_global_mouse_position()
	# Check if mouse is within the workspace dock AND not over modal
	if modal_new_file.visible: return false
	return workspace_dock.get_global_rect().has_point(mouse_pos)

func _input(event):
	# Global Shortcuts (Highest Priority - bypasses UI focus)
	if event is InputEventKey and event.pressed:
		var ctrl = event.ctrl_pressed
		var shift = event.shift_pressed
		
		# Ctrl + T: Transform Toggle
		if ctrl and not shift and event.keycode == KEY_T:
			if current_tool == "reference":
				_toggle_reference_transform()
				get_viewport().set_input_as_handled()
				return
			
		# Ctrl + Shortcuts
		if ctrl:
			match event.keycode:
				KEY_N:
					show_new_file_modal()
					get_viewport().set_input_as_handled()
					return
				KEY_O:
					import_image()
					get_viewport().set_input_as_handled()
					return
				KEY_D:
					_clear_selection()
					get_viewport().set_input_as_handled()
					return
				KEY_S:
					if shift:
						save_dialog.current_file = workspaces[current_workspace_idx].name + ".entmap"
						save_dialog.popup_centered()
					else:
						save_map()
					get_viewport().set_input_as_handled()
					return
				KEY_Z:
					undo()
					get_viewport().set_input_as_handled()
					return
				KEY_0:
					canvas_zoom = 1.0
					_update_zoom()
					_center_canvas()
					get_viewport().set_input_as_handled()
					return

	# Panning Logic (Global override - bypasses node blocking)
	if event is InputEventMouseButton:
		# Auto-release focus when clicking on workspace
		if event.pressed and _is_mouse_over_workspace():
			var focus_node = get_viewport().gui_get_focus_owner()
			if focus_node is LineEdit:
				focus_node.release_focus()

		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if not _is_mouse_over_workspace(): return
				is_panning = true
				pan_start_pos = event.position
				canvas_start_pos = canvas_scroll
				get_viewport().set_input_as_handled() 
			else:
				is_panning = false
	elif event is InputEventMouseMotion:
		if is_panning:
			var diff = event.position - pan_start_pos
			canvas_scroll = canvas_start_pos - diff
			workspace_padding.position = -canvas_scroll
			get_viewport().set_input_as_handled()

func _unhandled_input(event):
	# Mouse Wheel: Zoom or Brush Size
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not _is_mouse_over_workspace(): return
			get_viewport().set_input_as_handled()
			if event.ctrl_pressed:
				_on_brush_size_changed(brush_size + 1)
			else:
				_perform_wheel_zoom(1.2)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not _is_mouse_over_workspace(): return
			get_viewport().set_input_as_handled()
			if event.ctrl_pressed:
				_on_brush_size_changed(brush_size - 1)
			else:
				_perform_wheel_zoom(0.8)
			return
	
	# Scrubby Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_Z):
			if event.pressed:
				if not _is_mouse_over_workspace(): return
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
		var new_zoom = clamp(zoom_start_val * zoom_mult, 0.1, 50.0)
		
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
			KEY_I: set_tool("inspector")
			KEY_R: set_tool("reference")
			KEY_L: set_tool("poly_lasso")
			KEY_V: set_tool("move")

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
	var list = _get_active_list()
	var color = list[0].color if (current_tool == "eraser" or force_erase) else list[current_biome_idx].color
	
	# Apply Snapping to the drawing position as well!
	var snapped_pos = _get_snapped_pos(pos, brush_size)
	var p = Vector2i(snapped_pos)
	
	# Mapping Screen-Space brush size to World-Space radius
	# actual_radius = (diameter/2) / zoom
	var actual_radius = brush_size / 2.0
	
	match current_tool:
		"brush", "eraser": _draw_brush(p, brush_size, color)
		"rect": _update_selection_preview(pos)
		"poly_lasso": _on_poly_lasso_input(pos)
		"move": _on_move_input(pos)
		"wand":
			if is_drawing: 
				_flood_fill(p, color)
				is_drawing = false
		"inspector":
			_apply_inspector(p)
			is_drawing = false
	_update_texture()

func _draw_brush(center: Vector2i, size: int, color: Color):
	if size <= 1:
		if _is_pos_valid(center):
			if not has_selection or (selection_mask and selection_mask.get_bitv(center)):
				canvas_image.set_pixelv(center, color)
		return
	
	var offset = size / 2 # Integer division: 2->1, 3->1, 4->2
	var img_size = canvas_image.get_size()
	
	for y in range(size):
		var ty = center.y - offset + y
		if ty < 0 or ty >= img_size.y: continue
		
		var dx = size / 2.0
		var x_start = center.x - offset
		var x_end = x_start + size - 1
		
		if brush_shape == BrushShape.ROUND:
			# Circle algorithm using diameter
			var r = size / 2.0
			var dy = abs((y + 0.5) - r)
			var row_width = sqrt(max(0, r*r - dy*dy)) * 2.0
			var row_offset = (size - row_width) / 2.0
			x_start = center.x - offset + int(row_offset)
			x_end = center.x - offset + size - 1 - int(row_offset)

		x_start = max(0, x_start)
		x_end = min(img_size.x - 1, x_end)
		
		if x_start <= x_end:
			if has_selection and selection_mask:
				for x in range(x_start, x_end + 1):
					if selection_mask.get_bit(x, ty):
						canvas_image.set_pixel(x, ty, color)
			else:
				canvas_image.fill_rect(Rect2i(x_start, ty, x_end - x_start + 1, 1), color)

func _finalize_rect_tool(pos: Vector2):
	if current_tool != "rect": return
	var p1 = Vector2i(selection_start); var p2 = Vector2i(pos)
	var rect = Rect2i(p1, p2 - p1).abs()
	
	var new_mask = BitMap.new()
	new_mask.create(canvas_image.get_size())
	
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var p = Vector2i(x, y)
			if _is_pos_valid(p):
				new_mask.set_bitv(p, true)
	
	_merge_selection(new_mask)
	selection_overlay.visible = false

func _finalize_poly_tool():
	if poly_points.size() < 3:
		poly_points.clear()
		_update_poly_preview()
		return
	
	_prepare_undo()
	
	var list = _get_active_list()
	var color = list[current_biome_idx].color
	
	# Calculate bounding box
	var min_x = poly_points[0].x
	var min_y = poly_points[0].y
	var max_x = poly_points[0].x
	var max_y = poly_points[0].y
	
	for p in poly_points:
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	
	var rect = Rect2i(int(min_x), int(min_y), int(max_x - min_x) + 1, int(max_y - min_y) + 1)
	var img_size = canvas_image.get_size()
	
	# Clamp to image size
	rect.position.x = max(0, rect.position.x)
	rect.position.y = max(0, rect.position.y)
	rect.size.x = min(img_size.x - rect.position.x, rect.size.x)
	rect.size.y = min(img_size.y - rect.position.y, rect.size.y)
	
	# Fill polygon mask
	var new_mask = BitMap.new()
	new_mask.create(img_size)
	
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var p = Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, poly_points):
				new_mask.set_bit(x, y, true)
	
	_merge_selection(new_mask)
	
	poly_points.clear()
	_update_poly_preview()

func _clear_selection():
	if selection_mask:
		selection_mask.create(canvas_image.get_size())
	has_selection = false
	_update_selection_visual()
	# Update workspace data if needed
	if current_workspace_idx >= 0:
		workspaces[current_workspace_idx].selection_mask = selection_mask

func _apply_wand_selection(pos: Vector2):
	var p = Vector2i(pos)
	if not _is_pos_valid(p): return
	_merge_selection(_flood_select(p))

func _merge_selection(new_mask: BitMap):
	if not selection_mask:
		selection_mask = BitMap.new()
		selection_mask.create(canvas_image.get_size())

	match current_selection_mode:
		SelectionMode.REPLACE:
			selection_mask = new_mask
		SelectionMode.ADD:
			for x in range(selection_mask.get_size().x):
				for y in range(selection_mask.get_size().y):
					if new_mask.get_bit(x, y): selection_mask.set_bit(x, y, true)
		SelectionMode.SUBTRACT:
			for x in range(selection_mask.get_size().x):
				for y in range(selection_mask.get_size().y):
					if new_mask.get_bit(x, y): selection_mask.set_bit(x, y, false)
		SelectionMode.INTERSECT:
			var intersect_mask = BitMap.new()
			intersect_mask.create(selection_mask.get_size())
			for x in range(selection_mask.get_size().x):
				for y in range(selection_mask.get_size().y):
					if selection_mask.get_bit(x, y) and new_mask.get_bit(x, y):
						intersect_mask.set_bit(x, y, true)
			selection_mask = intersect_mask
	
	# Update workspace data
	if current_workspace_idx >= 0:
		workspaces[current_workspace_idx].selection_mask = selection_mask
	
	_update_selection_visual()

func _flood_select(start_pos: Vector2i) -> BitMap:
	var mask = BitMap.new()
	mask.create(canvas_image.get_size())
	
	var target_color = canvas_image.get_pixelv(start_pos)
	var stack = [start_pos]
	var visited = {}
	
	var count = 0
	var max_pixels = canvas_image.get_size().x * canvas_image.get_size().y
	
	while stack.size() > 0 and count < max_pixels:
		var p = stack.pop_back()
		if visited.has(p): continue
		visited[p] = true
		
		if canvas_image.get_pixelv(p).is_equal_approx(target_color):
			mask.set_bitv(p, true)
			count += 1
			for n in [Vector2i(p.x+1, p.y), Vector2i(p.x-1, p.y), Vector2i(p.x, p.y+1), Vector2i(p.x, p.y-1)]:
				if _is_pos_valid(n) and not visited.has(n):
					stack.push_back(n)
	return mask

func _on_move_input(pos: Vector2):
	if not is_drawing:
		is_moving_ref = false
		return
	
	if not is_moving_ref:
		# Check if clicking on reference image
		if reference_overlay.visible and reference_overlay.texture:
			var ref_rect = Rect2(reference_overlay.position / canvas_zoom, reference_overlay.size / canvas_zoom)
			if ref_rect.has_point(pos):
				is_moving_ref = true
				move_drag_start_canvas_pos = pos
				move_drag_start_ref_pos = reference_overlay.position / canvas_zoom
				_prepare_undo() # Optional: move could be undoable too
		return
	
	if is_moving_ref:
		var diff = pos - move_drag_start_canvas_pos
		var new_pos = move_drag_start_ref_pos + diff
		reference_overlay.position = new_pos * canvas_zoom
		if current_workspace_idx >= 0:
			workspaces[current_workspace_idx].ref_pos = new_pos

func _update_selection_visual():
	if not selection_mask or not has_selection:
		selection_mask_buffer.texture = null
		selection_mask_buffer.visible = false
		has_selection = false
		return
	
	# Create an image from BitMap. This is a bit slow in GDScript for 1M pixels, 
	# but for limited size it's acceptable. Optimization would use PackedByteArray.
	var size = selection_mask.get_size()
	var img = Image.create(size.x, size.y, false, Image.FORMAT_L8)
	
	var has_any = false
	for y in range(size.y):
		for x in range(size.x):
			if selection_mask.get_bit(x, y):
				img.set_pixel(x, y, Color(1, 1, 1, 1))
				has_any = true
	
	if not has_any:
		selection_mask_buffer.texture = null
		has_selection = false
		return

	var tex = ImageTexture.create_from_image(img)
	selection_mask_buffer.texture = tex
	
	# Apply Shader if not already present
	if selection_mask_buffer.material == null:
		var mat = ShaderMaterial.new()
		var shader = Shader.new()
		shader.code = """
shader_type canvas_item;
void fragment() {
	float m = texture(TEXTURE, UV).r;
	
	// Edge detection for outward outline
	vec2 ps = 1.0 / vec2(textureSize(TEXTURE, 0));
	float edge = 0.0;
	
	if (m < 0.1) {
		if (texture(TEXTURE, UV + vec2(ps.x, 0)).r > 0.9 || 
			texture(TEXTURE, UV + vec2(-ps.x, 0)).r > 0.9 ||
			texture(TEXTURE, UV + vec2(0, ps.y)).r > 0.9 ||
			texture(TEXTURE, UV + vec2(0, -ps.y)).r > 0.9) {
			edge = 1.0;
		}
		
		if (edge > 0.5) {
			float dash = step(0.5, fract(TIME * 3.0 + (UV.x + UV.y) * 150.0));
			if (dash > 0.5) {
				COLOR = vec4(1, 1, 1, 1);
			} else {
				discard;
			}
		} else {
			discard;
		}
	} else {
		COLOR = vec4(0.2, 0.5, 1.0, 0.3);
	}
}
"""
		mat.shader = shader
		selection_mask_buffer.material = mat
	
	selection_mask_buffer.visible = true
	has_selection = true

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

func _update_tool_ui():
	for child in tools_container.get_children():
		if child is Button:
			var is_active = (child.name.to_lower() == current_tool.to_lower())
			if is_active:
				var active_style = child.get_theme_stylebox("pressed")
				child.add_theme_stylebox_override("normal", active_style)
				child.add_theme_color_override("icon_normal_color", Color("#378ADD"))
			else:
				child.add_theme_stylebox_override("normal", style_normal)
				child.add_theme_color_override("icon_normal_color", Color.WHITE)
				
	st_tool.text = "Tool: " + current_tool.capitalize()

func set_tool(tool_name: String):
	current_tool = tool_name
	
	# Visibility of overlays
	if tool_name != "inspector":
		inspector_overlay.visible = false
	
	_update_tool_ui()
	_update_brush_cursor_position()
	_update_tool_options_visibility()
	
	if tool_name != "poly_lasso":
		poly_points.clear()
		_update_poly_preview()

func _update_tool_options_visibility():
	brush_options.visible = (current_tool == "brush")
	selection_options.visible = (current_tool == "rect" or current_tool == "wand" or current_tool == "poly_lasso")
	eraser_options.visible = (current_tool == "eraser")
	reference_options.visible = (current_tool == "reference")
	
	# Only show ToolOptionsBar if it has content
	tool_options_bar.visible = (brush_options.visible or 
								selection_options.visible or 
								eraser_options.visible or 
								reference_options.visible)

func _set_selection_mode(mode: int):
	current_selection_mode = mode
	_update_selection_mode_ui()

func _update_selection_mode_ui():
	for mode in mode_btns:
		mode_btns[mode].button_pressed = (mode == current_selection_mode)

func _on_biome_item_input(event, idx):
	if event is InputEventMouseButton and event.pressed:
		current_biome_idx = idx
		_update_biome_ui()


func _on_brush_size_changed(value: float):
	brush_size = int(max(1, value))
	_update_brush_cursor_size()
	if brush_size_input: brush_size_input.text = str(brush_size)
	if eraser_size_input: eraser_size_input.text = str(brush_size)

func _on_load_reference_pressed():
	reference_dialog.popup_centered()

func _on_ref_dialog_file_selected(path: String):
	var img = Image.load_from_file(path)
	if img:
		reference_overlay.texture = ImageTexture.create_from_image(img)
		reference_overlay.show()
		current_ref_path = path # Correct tracking
		if current_workspace_idx >= 0:
			var ws = workspaces[current_workspace_idx]
			ws.ref_path = path
			ws.ref_pos = reference_overlay.position / canvas_zoom
			ws.ref_size = reference_overlay.size / canvas_zoom
		print("[REFERENCE] Loaded image: ", path)

func _on_opacity_input_submitted(new_text: String):
	var value = new_text.to_float()
	if value > 100.0: value = 100.0
	if value < 0.0: value = 0.0
	
	# If input is like 0.5, treat as 50%
	if value <= 1.0 and ("." in new_text):
		value *= 100.0
		
	reference_overlay.modulate.a = value / 100.0
	reference_opacity_input.text = str(int(value))
	if current_workspace_idx >= 0:
		workspaces[current_workspace_idx].ref_opacity = reference_overlay.modulate.a
	
	reference_opacity_input.release_focus()

func _toggle_reference_transform():
	if not reference_overlay.texture: return
	
	is_transforming_ref = !is_transforming_ref
	reference_transform.visible = is_transforming_ref
	reference_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if is_transforming_ref else Control.MOUSE_FILTER_IGNORE
	
	if is_transforming_ref:
		ref_aspect_ratio = reference_overlay.texture.get_size().x / reference_overlay.texture.get_size().y
		# Improve handle visibility via StyleBox
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color("#3498db") # Bright Blue
		sb.set_border_width_all(2)
		sb.border_color = Color.WHITE
		sb.set_corner_radius_all(2)
		
		for handle in reference_transform.get_children():
			if handle is Control:
				handle.add_theme_stylebox_override("panel", sb)
				handle.custom_minimum_size = Vector2(12, 12)
				# Re-center offsets for 12x12
				handle.offset_left = -6
				handle.offset_top = -6
				handle.offset_right = 6
				handle.offset_bottom = 6
		print("[REFERENCE] Transform mode ENABLED")
	else:
		print("[REFERENCE] Transform mode DISABLED")

func _on_handle_gui_input(event: InputEvent, handle_name: String):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging_handle = handle_name
				drag_start_pos = get_global_mouse_position()
				ref_start_rect = Rect2(reference_overlay.position, reference_overlay.size)
			else:
				dragging_handle = ""
				
	if event is InputEventMouseMotion and dragging_handle != "":
		_handle_resize(handle_name)

func _on_transform_gui_input(event: InputEvent):
	if dragging_handle != "": return # Let handle logic rule
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging_ref = true
				drag_start_pos = get_global_mouse_position()
				ref_start_rect = Rect2(reference_overlay.position, reference_overlay.size)
			else:
				is_dragging_ref = false
				
	if event is InputEventMouseMotion and is_dragging_ref:
			# Update POSITION (Move logic)
			var delta = event.relative
			reference_overlay.position += delta
			# Store adjusted logical pos back to workspace immediately for zoom consistency
			if current_workspace_idx >= 0:
				workspaces[current_workspace_idx].ref_pos = reference_overlay.position / canvas_zoom

func _handle_resize(handle_name: String):
	var mouse_pos = get_global_mouse_position()
	var delta = mouse_pos - drag_start_pos
	var new_rect = ref_start_rect
	
	var shift = Input.is_key_pressed(KEY_SHIFT)
	
	# Handles: TL, TC, TR, ML, MR, BL, BC, BR
	if "L" in handle_name:
		new_rect.position.x += delta.x
		new_rect.size.x -= delta.x
	if "R" in handle_name:
		new_rect.size.x += delta.x
	if "T" in handle_name:
		new_rect.position.y += delta.y
		new_rect.size.y -= delta.y
	if "B" in handle_name:
		new_rect.size.y += delta.y

	# Min size
	if new_rect.size.x < 10: 
		new_rect.size.x = 10
		new_rect.position.x = ref_start_rect.end.x - 10 if "L" in handle_name else ref_start_rect.position.x
	if new_rect.size.y < 10: 
		new_rect.size.y = 10
		new_rect.position.y = ref_start_rect.end.y - 10 if "T" in handle_name else ref_start_rect.position.y

	if shift:
		# Maintain aspect ratio
		if handle_name in ["HandleTL", "HandleTR", "HandleBL", "HandleBR"]:
			var current_ratio = new_rect.size.x / new_rect.size.y
			if current_ratio > ref_aspect_ratio:
				new_rect.size.x = new_rect.size.y * ref_aspect_ratio
				if "L" in handle_name: new_rect.position.x = ref_start_rect.end.x - new_rect.size.x
			else:
				new_rect.size.y = new_rect.size.x / ref_aspect_ratio
				if "T" in handle_name: new_rect.position.y = ref_start_rect.end.y - new_rect.size.y

	reference_overlay.position = new_rect.position
	reference_overlay.size = new_rect.size
	
	if current_workspace_idx >= 0:
		workspaces[current_workspace_idx].ref_pos = reference_overlay.position / canvas_zoom
		workspaces[current_workspace_idx].ref_size = reference_overlay.size / canvas_zoom

func _update_biome_ui():
	var all_items = []
	for child in biome_list_container.get_children():
		if child is GridContainer:
			all_items.append_array(child.get_children())
		elif child is PanelContainer and child.name.begins_with("Item_"):
			all_items.append(child)
			
	for item in all_items:
		var idx = int(item.name.replace("Item_", ""))
		if idx == current_biome_idx:
			item.add_theme_stylebox_override("panel", card_style_active)
		else:
			item.add_theme_stylebox_override("panel", card_style_normal)
			
	var list = _get_active_list()
	st_biome.text = (current_sidebar_view.capitalize()) + ": " + list[current_biome_idx].name

func undo():
	if undo_stack.is_empty(): return
	canvas_image = undo_stack.pop_back()
	_update_texture()

func export_image():
	save_map()

func save_map():
	if current_save_path.is_empty():
		save_dialog.current_file = workspaces[current_workspace_idx].name + ".entmap"
		save_dialog.popup_centered()
	else:
		_perform_save(current_save_path)

func import_image():
	open_dialog.popup_centered()

func _on_save_dialog_file_selected(path: String):
	current_save_path = path
	var f_name = path.get_file().get_basename()
	workspaces[current_workspace_idx].name = f_name
	tabs_bar.set_tab_title(current_workspace_idx, f_name)
	_perform_save(path)

func _on_open_dialog_file_selected(path: String):
	_perform_load(path)

func _perform_save(path: String):
	# 0. Sync current UI state to workspace dictionary
	if current_workspace_idx >= 0:
		var ws = workspaces[current_workspace_idx]
		ws.zoom = canvas_zoom
		ws.scroll = canvas_scroll
		# Ensure opacity is flushed from input even if focus wasn't lost
		_on_opacity_input_submitted(reference_opacity_input.text)
		
		ws.ref_pos = reference_overlay.position / canvas_zoom
		ws.ref_size = reference_overlay.size / canvas_zoom
		ws.ref_opacity = reference_overlay.modulate.a

	# 1. Prepare Image Data as Base64
	var buffer = canvas_image.save_png_to_buffer()
	var b64_data = Marshalls.raw_to_base64(buffer)
	
	# 2. Package everything into Metadata
	var project_data = {
		"version": "1.0",
		"name": workspaces[current_workspace_idx].name,
		"size": {"w": canvas_image.get_width(), "h": canvas_image.get_height()},
		"biomes_snapshot": STATIC_BIOMES,
		"pixel_data": b64_data,
		"reference": {
			"path": workspaces[current_workspace_idx].ref_path,
			"pos": {"x": workspaces[current_workspace_idx].ref_pos.x, "y": workspaces[current_workspace_idx].ref_pos.y},
			"size": {"x": workspaces[current_workspace_idx].ref_size.x, "y": workspaces[current_workspace_idx].ref_size.y},
			"opacity": workspaces[current_workspace_idx].ref_opacity
		},
		"created_at": Time.get_datetime_string_from_system()
	}
	
	# 3. Save to Single File (.entmap)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(project_data, "\t"))
		f.close()
		print("[PAINTER] Project saved to: ", path)
	else:
		print("[PAINTER] Failed to open file for writing: ", path)

func _perform_load(path: String):
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		print("[PAINTER] Failed to open file for reading: ", path)
		return
		
	var json_str = f.get_as_text()
	f.close()
	
	var json = JSON.new()
	var parse_err = json.parse(json_str)
	if parse_err != OK:
		print("[PAINTER] JSON Parse Error: ", json.get_error_message())
		return
		
	var data = json.data
	if not data.has("pixel_data"):
		print("[PAINTER] Invalid project file: missing pixel_data")
		return
		
	# 1. Decode Image
	var buffer = Marshalls.base64_to_raw(data.pixel_data)
	var img = Image.new()
	var err = img.load_png_from_buffer(buffer)
	if err != OK:
		print("[PAINTER] Error decoding PNG from project: ", err)
		return
		
	# 2. Setup Workspace (Always create NEW for "Open")
	var ws_name = data.get("name", path.get_file().get_basename())
	var img_size = img.get_size()
	
	_create_workspace(ws_name, img_size)
	var ws_idx = workspaces.size() - 1
	var ws = workspaces[ws_idx]
	
	ws.image = img
	ws.texture = ImageTexture.create_from_image(img)
	ws.save_path = path
	current_save_path = path
	
	if data.has("reference"):
		var ref = data.reference
		ws.ref_path = ref.get("path", "")
		if ref.has("pos"): ws.ref_pos = Vector2(ref.pos.x, ref.pos.y)
		if ref.has("size"): ws.ref_size = Vector2(ref.size.x, ref.size.y)
		ws.ref_opacity = ref.get("opacity", 0.5)
		
	_apply_workspace_reference(ws)

	# 3. Update UI
	tabs_bar.add_tab(ws_name)
	tabs_bar.current_tab = ws_idx
	# Signal 'tab_changed' will trigger _switch_workspace(ws_idx)
	
	print("[PAINTER] Project loaded into new tab: ", ws_name)

func _apply_workspace_reference(ws: Dictionary):
	if ws.ref_path != "":
		# Only load if image is different
		if reference_overlay.texture == null or current_ref_path != ws.ref_path:
			var img = Image.load_from_file(ws.ref_path)
			if img:
				var tex = ImageTexture.create_from_image(img)
				reference_overlay.texture = tex
				current_ref_path = ws.ref_path 
		
		# Apply transform WITH ZOOM
		reference_overlay.position = ws.ref_pos * canvas_zoom
		reference_overlay.size = ws.ref_size * canvas_zoom
		var opacity = ws.get("ref_opacity", 0.5)
		reference_overlay.modulate.a = opacity
		reference_overlay.show()
		reference_opacity_input.text = str(int(opacity * 100))
	else:
		reference_overlay.texture = null
		reference_overlay.hide()
		current_ref_path = ""
		is_transforming_ref = false
		reference_transform.hide()

# ═══════════════════════════════════════════════════════════════
# INSPECTOR LOGIC
# ═══════════════════════════════════════════════════════════════

func _apply_inspector(pos: Vector2i):
	var img_size = canvas_image.get_size()
	if pos.x < 0 or pos.x >= img_size.x or pos.y < 0 or pos.y >= img_size.y: return
	
	var target_color = canvas_image.get_pixelv(pos)
	var mask_data = _find_connected_biome(pos, target_color)
	
	inspected_pixels = mask_data.count
	var mask_img = mask_data.image
	inspected_mask = ImageTexture.create_from_image(mask_img)
	
	# Identify Biome Name
	inspected_biome_id = "Unknown"
	var list = STATIC_BIOMES
	
	# More robust color matching
	var best_match = "Unknown"
	var min_dist = 0.3 # Increased threshold
	
	print("[INSPECT] pos=", pos, " target_color=", target_color, " (", target_color.to_html(false), ")")
	for b in list:
		var c1 = Vector3(b.color.r, b.color.g, b.color.b)
		var c2 = Vector3(target_color.r, target_color.g, target_color.b)
		var d = c1.distance_to(c2)
		if d < min_dist:
			min_dist = d
			best_match = b.name
	
	print("[INSPECT] Final Result: ", best_match)
	inspected_biome_id = best_match
			
	_update_inspector_ui()
	_update_inspector_overlay()
	
	# Switch to inspector view automatically
	_on_btn_inspect_pressed()

func _find_connected_biome(start_pos: Vector2i, color: Color) -> Dictionary:
	var img_size = canvas_image.get_size()
	var mask = Image.create(img_size.x, img_size.y, false, Image.FORMAT_L8)
	var visited = BitMap.new()
	visited.create(img_size)
	
	var queue = [start_pos]
	visited.set_bitv(start_pos, true)
	var count = 0
	
	while not queue.is_empty():
		var p = queue.pop_front()
		mask.set_pixel(p.x, p.y, Color.WHITE)
		count += 1
		
		for neighbor in [Vector2i(p.x+1, p.y), Vector2i(p.x-1, p.y), Vector2i(p.x, p.y+1), Vector2i(p.x, p.y-1)]:
			if neighbor.x >= 0 and neighbor.x < img_size.x and neighbor.y >= 0 and neighbor.y < img_size.y:
				if not visited.get_bitv(neighbor) and canvas_image.get_pixelv(neighbor).is_equal_approx(color):
					visited.set_bitv(neighbor, true)
					queue.append(neighbor)
	
	return {"image": mask, "count": count}

func _update_inspector_ui():
	# 1. Clear old content
	var stats_node = inspector_panel.get_node("Stats")
	for child in stats_node.get_children():
		child.queue_free()
	
	# 2. Section: STATISTICS
	_add_inspector_header(stats_node, "BIOME STATISTICS")
	
	var main_info = VBoxContainer.new()
	main_info.add_theme_constant_override("separation", 2)
	stats_node.add_child(main_info)
	
	var biome_lab = Label.new()
	biome_lab.text = "Biome: " + inspected_biome_id
	biome_lab.add_theme_font_size_override("font_size", 14)
	main_info.add_child(biome_lab)
	
	var area_lab = Label.new()
	area_lab.text = "Area: %d px" % inspected_pixels
	area_lab.add_theme_font_size_override("font_size", 11)
	area_lab.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main_info.add_child(area_lab)
	
	_add_custom_divider(stats_node)
	
	# 3. Section: BIOME CONFIGURATION
	_add_inspector_header(stats_node, "BIOME CONFIGURATION")
	
	var categories = ["Tiles", "Props", "Actors"]
	for cat in categories:
		var cat_header = PanelContainer.new()
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(1, 1, 1, 0.05)
		cs.set_corner_radius_all(4)
		cs.content_margin_left = 8
		cs.content_margin_top = 4
		cs.content_margin_bottom = 4
		cat_header.add_theme_stylebox_override("panel", cs)
		stats_node.add_child(cat_header)
		
		var cl = Label.new()
		cl.text = cat.to_upper()
		cl.add_theme_font_size_override("font_size", 11)
		cl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		cat_header.add_child(cl)
		
		var cat_container = VBoxContainer.new()
		cat_container.name = "Cat_" + cat
		cat_container.add_theme_constant_override("separation", 12)
		var cat_margin = MarginContainer.new()
		cat_margin.add_theme_constant_override("margin_left", 8)
		cat_margin.add_child(cat_container)
		stats_node.add_child(cat_margin)
		
		if cat == "Actors":
			cat_header.modulate.a = 0.4
			cat_margin.modulate.a = 0.4
		elif cat == "Tiles":
			_build_tiles_inspector_subsections(cat_container)
		elif cat == "Props":
			_build_props_inspector_subsections(cat_container)
			
		stats_node.add_child(Control.new()) # Spacer

func _add_inspector_header(parent: Control, title: String):
	var l = Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
	parent.add_child(l)

func _add_custom_divider(parent: Control):
	var sep = HSeparator.new()
	var style = StyleBoxLine.new()
	style.color = Color(0.2, 0.25, 0.3) # Darker, MapTool-friendly color
	style.grow_begin = 0
	style.grow_end = 0
	sep.add_theme_stylebox_override("separator", style)
	parent.add_child(sep)

func _build_tiles_inspector_subsections(parent: VBoxContainer):
	var sub_cats = ["Grounds", "Fluids", "Overlays"]
	for sub in sub_cats:
		var sub_lab = Label.new()
		sub_lab.text = sub
		sub_lab.add_theme_font_size_override("font_size", 10)
		sub_lab.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		parent.add_child(sub_lab)
		
		var items_box = VBoxContainer.new()
		items_box.add_theme_constant_override("separation", 4)
		parent.add_child(items_box)
		
		# Fill with specific items based on biome
		var biome_lower = inspected_biome_id.to_lower()
		if biome_lower.contains("sa mạc") or biome_lower.contains("desert"):
			if sub == "Grounds":
				_add_inspector_scrollbar_item(items_box, "sand_block", "grounds", 100)
			elif sub == "Fluids":
				_add_inspector_scrollbar_item(items_box, "oil_block", "fluids", 20)
				_add_inspector_scrollbar_item(items_box, "water_block", "fluids", 10)
				_add_inspector_scrollbar_item(items_box, "lava_block", "fluids", 5)
		else:
			# Default mockup for other biomes
			if sub == "Grounds":
				_add_inspector_scrollbar_item(items_box, "default_ground", "grounds", 100)

func _build_props_inspector_subsections(parent: VBoxContainer):
	var biome_lower = inspected_biome_id.to_lower()
	if biome_lower.contains("sa mạc") or biome_lower.contains("desert"):
		_add_inspector_scrollbar_item(parent, "cactus", "props/plants/trees", 15)

func _add_inspector_scrollbar_item(parent: Control, item_id: String, sub_path: String, value: int):
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)
	
	var display_name = _get_item_display_name(item_id, sub_path)
	
	var label = Label.new()
	label.text = display_name
	label.custom_minimum_size = Vector2(110, 0)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hbox.add_child(label)
	
	# ScrollbarUI (implemented as ProgressBar)
	var progress = ProgressBar.new()
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.custom_minimum_size = Vector2(0, 14)
	progress.value = value
	progress.show_percentage = true
	
	# Style
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.12, 0.12, 0.12)
	sb_bg.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("background", sb_bg)
	
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.2, 0.45, 0.85)
	sb_fill.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("fill", sb_fill)
	
	progress.add_theme_font_size_override("font_size", 8)
	hbox.add_child(progress)

func _get_item_display_name(id: String, sub_path: String) -> String:
	var info_path = "res://assets/" + sub_path + "/" + id + "/info.json"
	if FileAccess.file_exists(info_path):
		var f = FileAccess.open(info_path, FileAccess.READ)
		var json = JSON.parse_string(f.get_as_text())
		if json and json.has("display_name"):
			return json["display_name"]
	
	return id.replace("_", " ").capitalize()

func _get_mock_ores_for_biome(_b_name: String) -> Array:
	return [] # Deprecated but keeping for compatibility if called elsewhere

func _update_inspector_overlay():
	inspector_overlay.visible = true
	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/inspector_overlay.gdshader")
	mat.set_shader_parameter("mask", inspected_mask)
	inspector_overlay.material = mat


func show_new_file_modal():
	input_name.text = ""
	_validate_new_file_name("")
	modal_new_file.show()
	input_name.grab_focus()

func _on_new_file_name_changed(new_text: String):
	_validate_new_file_name(new_text)

func _validate_new_file_name(text: String):
	var is_valid = true
	var current_text = text.strip_edges()
	
	if current_text.length() == 0:
		is_valid = false
	
	for ws in workspaces:
		if ws.name == current_text:
			is_valid = false
			break
			
	btn_create.disabled = !is_valid

func _on_create_tab_pressed():
	var f_name = input_name.text.strip_edges()
	
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
	workspaces.remove_at(idx)
	tabs_bar.remove_tab(idx)
	
	if workspaces.is_empty():
		_switch_workspace(-1)
		return
		
	# Nếu đóng tab đang active, chuyển sang tab lân cận
	if current_workspace_idx == idx:
		var new_idx = clamp(idx, 0, workspaces.size() - 1)
		_switch_workspace(new_idx)
	elif current_workspace_idx > idx:
		current_workspace_idx -= 1
