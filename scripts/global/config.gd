extends Node

const SETTINGS_FILE = "user://settings.cfg"

signal settings_changed

# Default Settings
var render_distance: int = 3
var vsync: bool = false
var max_fps: int = 0
var fullscreen: bool = false
var move_speed: float = 1000.0
var zoom_speed: float = 0.1
var show_debug: bool = false

func _ready():
	load_settings()
	apply_all()

func apply_all():
	# Graphics
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
	Engine.max_fps = max_fps
	
	settings_changed.emit()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("graphics", "render_distance", render_distance)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("graphics", "max_fps", max_fps)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("game", "move_speed", move_speed)
	config.set_value("game", "zoom_speed", zoom_speed)
	config.set_value("game", "show_debug", show_debug)
	var err = config.save(SETTINGS_FILE)
	if err == OK:
		print("[CONFIG] Settings saved to ", SETTINGS_FILE)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err != OK: 
		print("[CONFIG] No settings file found, using defaults.")
		return
	
	render_distance = config.get_value("graphics", "render_distance", render_distance)
	vsync = config.get_value("graphics", "vsync", vsync)
	max_fps = config.get_value("graphics", "max_fps", max_fps)
	fullscreen = config.get_value("graphics", "fullscreen", fullscreen)
	move_speed = config.get_value("game", "move_speed", move_speed)
	zoom_speed = config.get_value("game", "zoom_speed", zoom_speed)
	show_debug = config.get_value("game", "show_debug", show_debug)
	print("[CONFIG] Settings loaded from ", SETTINGS_FILE)
