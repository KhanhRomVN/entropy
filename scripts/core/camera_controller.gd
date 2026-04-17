extends Camera2D

signal view_changed(center_pos: Vector2, zoom_level: float)

@export var move_speed: float = 1000.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.25
@export var max_zoom: float = 1.0

var _cached_player: CharacterBody2D = null

func _ready():
	_on_settings_updated()
	Config.settings_changed.connect(_on_settings_updated)
	# Cache player reference sau khi scene tree sẵn sàng
	_cached_player = get_tree().get_first_node_in_group("player")

func _on_settings_updated():
	move_speed = Config.move_speed
	zoom_speed = Config.zoom_speed

func _process(delta):
	# Tái cache nếu không còn hợp lệ
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	
	if _cached_player:
		# Bám theo người chơi mượt mà (Lerp)
		global_position = global_position.lerp(_cached_player.global_position, 10.0 * delta)
		view_changed.emit(global_position, zoom.x)
	else:
		# Điều khiển thủ công nếu không có player
		var move_vec = Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move_vec.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move_vec.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move_vec.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move_vec.x += 1
		
		if move_vec != Vector2.ZERO:
			position += move_vec.normalized() * move_speed * delta / zoom.x
			view_changed.emit(global_position, zoom.x)

func _unhandled_input(event):
	# Ctrl + Scroll hoặc Ctrl + Phím +/- để Zooming
	if event.ctrl_pressed:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
		elif event is InputEventKey and event.pressed:
			if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD: # KEY_EQUAL là phím có dấu +
				zoom_in()
			elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
				zoom_out()

func zoom_in():
	zoom = (zoom + Vector2(zoom_speed, zoom_speed)).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	view_changed.emit(global_position, zoom.x)

func zoom_out():
	zoom = (zoom - Vector2(zoom_speed, zoom_speed)).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	view_changed.emit(global_position, zoom.x)
