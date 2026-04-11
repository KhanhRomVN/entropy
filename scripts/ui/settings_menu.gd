extends CanvasLayer

signal closed

@onready var graphics_vbox = $Panel/VBox/Tabs/Graphics/Margin/VBox
@onready var game_vbox = $Panel/VBox/Tabs/Game/Margin/VBox

func _ready():
	_setup_ui()
	_load_values()

func _setup_ui():
	# Đặt tên tab hiển thị
	$Panel/VBox/Tabs.set_tab_title(0, "Đồ họa")
	$Panel/VBox/Tabs.set_tab_title(1, "Trò chơi")
	
	# Connect signals for Graphics
	var rd_slider = graphics_vbox.get_node("RD/RenderDistanceSlider")
	rd_slider.value_changed.connect(_on_render_distance_changed)
	
	var vsync_check = graphics_vbox.get_node("VSync/VSyncCheckBox")
	vsync_check.toggled.connect(_on_vsync_toggled)
	
	var fps_slider = graphics_vbox.get_node("FPS/MaxFPSSlider")
	fps_slider.value_changed.connect(_on_max_fps_changed)
	
	var fs_check = graphics_vbox.get_node("FS/FullscreenCheckBox")
	fs_check.toggled.connect(_on_fullscreen_toggled)
	
	# Connect signals for Game
	var move_slider = game_vbox.get_node("Speed/MoveSpeedSlider")
	move_slider.value_changed.connect(_on_move_speed_changed)
	
	var debug_check = game_vbox.get_node("Debug/DebugCheckBox")
	debug_check.toggled.connect(_on_debug_toggled)
	
	# Done button
	$Panel/VBox/DoneButton.pressed.connect(_on_done_pressed)

func _load_values():
	var rd_slider = graphics_vbox.get_node("RD/RenderDistanceSlider")
	var rd_label = graphics_vbox.get_node("RD/RenderDistanceLabel")
	rd_slider.value = Config.render_distance
	rd_label.text = str(Config.render_distance) + " chunks"
	
	graphics_vbox.get_node("VSync/VSyncCheckBox").button_pressed = Config.vsync
	
	var fps_slider = graphics_vbox.get_node("FPS/MaxFPSSlider")
	fps_slider.value = Config.max_fps
	_update_fps_label(Config.max_fps)
	
	graphics_vbox.get_node("FS/FullscreenCheckBox").button_pressed = Config.fullscreen
	
	var move_slider = game_vbox.get_node("Speed/MoveSpeedSlider")
	var move_label = game_vbox.get_node("Speed/MoveSpeedLabel")
	move_slider.value = Config.move_speed
	move_label.text = str(int(Config.move_speed))
	
	game_vbox.get_node("Debug/DebugCheckBox").button_pressed = Config.show_debug

func _on_render_distance_changed(value):
	Config.render_distance = int(value)
	graphics_vbox.get_node("RD/RenderDistanceLabel").text = str(int(value)) + " chunks"
	Config.save_settings()
	Config.settings_changed.emit()

func _on_vsync_toggled(button_pressed):
	Config.vsync = button_pressed
	Config.apply_all()
	Config.save_settings()

func _on_max_fps_changed(value):
	Config.max_fps = int(value)
	_update_fps_label(int(value))
	Config.apply_all()
	Config.save_settings()

func _update_fps_label(value):
	var fps_label = graphics_vbox.get_node("FPS/MaxFPSLabel")
	if value == 0:
		fps_label.text = "Unlimited"
	else:
		fps_label.text = str(value)

func _on_fullscreen_toggled(button_pressed):
	Config.fullscreen = button_pressed
	Config.apply_all()
	Config.save_settings()

func _on_move_speed_changed(value):
	Config.move_speed = value
	game_vbox.get_node("Speed/MoveSpeedLabel").text = str(int(value))
	Config.save_settings()
	Config.settings_changed.emit()

func _on_debug_toggled(button_pressed):
	Config.show_debug = button_pressed
	Config.save_settings()
	Config.settings_changed.emit()

func _on_done_pressed():
	visible = false
	closed.emit()
