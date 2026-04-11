extends CanvasLayer

@onready var health_bar = $Panel/Margin/VBox/Health/VBox/HealthBar
@onready var stamina_bar = $Panel/Margin/VBox/Stamina/VBox/StaminaBar
@onready var hunger_bar = $Panel/Margin/VBox/Hunger/VBox/HungerBar
@onready var thirst_bar = $Panel/Margin/VBox/Thirst/VBox/ThirstBar
@onready var mental_bar = $Panel/Margin/VBox/Mental/VBox/MentalBar

@onready var health_label = $Panel/Margin/VBox/Health/VBox/Label/HealthLabel
@onready var stamina_label = $Panel/Margin/VBox/Stamina/VBox/Label/StaminaLabel
@onready var hunger_label = $Panel/Margin/VBox/Hunger/VBox/Label/HungerLabel
@onready var thirst_label = $Panel/Margin/VBox/Thirst/VBox/Label/ThirstLabel
@onready var mental_label = $Panel/Margin/VBox/Mental/VBox/Label/MentalLabel

var target_values = {}

func _ready():
	# Connect to player stats if player exists
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.stat_changed.connect(_on_player_stat_changed)
		
	# Initial targets
	target_values = {
		"health": 100.0,
		"stamina": 100.0,
		"hunger": 100.0,
		"thirst": 100.0,
		"mental": 100.0
	}

func _process(delta):
	# Smoothly interpolate bars
	_update_bar(health_bar, "health", delta)
	_update_bar(stamina_bar, "stamina", delta)
	_update_bar(hunger_bar, "hunger", delta)
	_update_bar(thirst_bar, "thirst", delta)
	_update_bar(mental_bar, "mental", delta)

func _update_bar(bar, key, delta):
	if not target_values.has(key): return
	bar.value = lerp(bar.value, target_values[key], 10.0 * delta)

func _on_player_stat_changed(stat_name: String, current: float, max_val: float):
	target_values[stat_name] = (current / max_val) * 100.0
	
	match stat_name:
		"health": health_label.text = "%d / %d" % [current, max_val]
		"stamina": stamina_label.text = "%d / %d" % [current, max_val]
		"hunger": hunger_label.text = "%d / %d" % [current, max_val]
		"thirst": thirst_label.text = "%d / %d" % [current, max_val]
		"mental": mental_label.text = "%d / %d" % [current, max_val]
