extends CharacterBody2D

@export var speed: float = 500.0
@export var sprint_speed_multiplier: float = 1.6
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: String = "SE"
var is_sprinting: bool = false

# Survival Stats
signal stat_changed(stat_name: String, current: float, max_val: float)

@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0
@export var max_mental: float = 100.0

var health: float = 100.0
var stamina: float = 100.0
var hunger: float = 95.0
var thirst: float = 90.0
var mental: float = 100.0

var stamina_regen_rate: float = 15.0 # per second
var stamina_drain_rate: float = 25.0 # per second


# Double tap logic
var last_tap_times = {"up": -1.0, "down": -1.0, "left": -1.0, "right": -1.0}
const DOUBLE_TAP_THRESHOLD = 0.3 # seconds

func _physics_process(delta):
	var input_vec = Input.get_vector("left", "right", "up", "down")
	
	# Check for sprinting (Ctrl holding or double tap)
	_check_sprint_input()
	
	# Update Stats Logic
	_process_stats(delta)

	
	if input_vec != Vector2.ZERO:
		var current_speed = speed
		if is_sprinting:
			current_speed *= sprint_speed_multiplier
			
		velocity = input_vec.normalized() * current_speed
		
		_update_animation(input_vec)
		move_and_slide()
	else:
		is_sprinting = false # Stop sprinting when standing still
		velocity = Vector2.ZERO
		_update_idle_animation()

func _check_sprint_input():
	# 1. Ctrl key detection
	if Input.is_key_pressed(KEY_CTRL):
		is_sprinting = true
		return

	# 2. Double tap detection
	var current_time = Time.get_ticks_msec() / 1000.0
	for action in ["up", "down", "left", "right"]:
		if Input.is_action_just_pressed(action):
			if current_time - last_tap_times[action] < DOUBLE_TAP_THRESHOLD:
				is_sprinting = true
			last_tap_times[action] = current_time

func _process_stats(delta: float):
	# Stamina handling
	if is_sprinting and velocity.length() > 0:
		stamina = maxf(0.0, stamina - stamina_drain_rate * delta)
		if stamina <= 0:
			is_sprinting = false # Force stop sprinting if out of stamina
	else:
		stamina = minf(max_stamina, stamina + stamina_regen_rate * delta)
	
	# Passive decay (minimal for demo)
	hunger = maxf(0.0, hunger - 0.05 * delta)
	thirst = maxf(0.0, thirst - 0.08 * delta)
	
	# T\u1ed0I \u01afU: Ch\u1ec9 emit khi gi\u00e1 tr\u1ecb thay \u0111\u1ed5i (tr\u00e1nh HUD re-render 300 l\u1ea7n/gi\u00e2y)
	_emit_stat_if_changed("health", health, max_health)
	_emit_stat_if_changed("stamina", stamina, max_stamina)
	_emit_stat_if_changed("hunger", hunger, max_hunger)
	_emit_stat_if_changed("thirst", thirst, max_thirst)
	_emit_stat_if_changed("mental", mental, max_mental)

var _last_stat_values: Dictionary = {}

func _emit_stat_if_changed(stat_name: String, current: float, max_val: float):
	var rounded = snappedf(current, 0.1) # Làm tròn để tránh floating point noise
	if _last_stat_values.get(stat_name) != rounded:
		_last_stat_values[stat_name] = rounded
		stat_changed.emit(stat_name, current, max_val)


func _update_animation(input_vec: Vector2):
	var dir_name = _get_direction_name(input_vec)
	
	if dir_name != "":
		last_direction = dir_name
		sprite.play("walk_" + dir_name)
		# Adjust animation speed based on sprinting
		sprite.speed_scale = 1.5 if is_sprinting else 1.0

func _update_idle_animation():
	var idle_dir = last_direction
	# All 8 directions are now available

	
	sprite.play("idle_" + idle_dir)
	sprite.speed_scale = 1.0

func _get_direction_name(input_vec: Vector2) -> String:
	# 8-direction detection
	if input_vec.x < 0 and input_vec.y < 0:
		return "NW"
	elif input_vec.x > 0 and input_vec.y < 0:
		return "NE"
	elif input_vec.x < 0 and input_vec.y > 0:
		return "SW"
	elif input_vec.x > 0 and input_vec.y > 0:
		return "SE"
	elif input_vec.y < 0:
		return "N"
	elif input_vec.y > 0:
		return "S"
	elif input_vec.x < 0:
		return "W"
	elif input_vec.x > 0:
		return "E"
		
	return ""
