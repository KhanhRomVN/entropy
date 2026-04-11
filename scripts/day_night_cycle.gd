extends DirectionalLight2D

signal hour_changed(hour: int)

@export var current_hour: int = 1
@export var is_paused: bool = true 

var clock_label: Label
var sun_dot: Control
var alt_label: Label

func _ready():
	print("[SYSTEM] --- DayNightCycle _ready() ---")
	
	var ui = get_tree().get_first_node_in_group("ui")
	if not ui:
		ui = get_parent().get_node_or_null("UI")
		
	if ui:
		clock_label = ui.get_node_or_null("ClockLabel")
		var compass = ui.get_node_or_null("SunCompass")
		if compass:
			sun_dot = compass.get_node_or_null("SunDot")
			if sun_dot:
				alt_label = sun_dot.get_node_or_null("AltLabel")
		
		var prev_btn = ui.get_node_or_null("PrevButton")
		var next_btn = ui.get_node_or_null("NextButton")
		
		if prev_btn:
			prev_btn.pressed.connect(func(): change_hour(-1))
		if next_btn:
			next_btn.pressed.connect(func(): change_hour(1))
			
	_update_sun()
	hour_changed.emit(current_hour)

func change_hour(delta: int):
	current_hour = (current_hour + delta + 24) % 24
	_update_sun()
	hour_changed.emit(current_hour)

func _update_sun():
	var hour_f = float(current_hour)
	var angle_per_hour = TAU / 24.0
	
	# 6:00 sáng là 0 độ (Phải/Đông)
	var angle = (hour_f - 6.0) * angle_per_hour
	
	# Godot 2D: 0 (Phải/Đông), 90 (Dưới/Nam), 180 (Trái/Tây), 270 (Trên/Bắc)
	rotation = angle 
	
	# Cường độ sáng dịu (Max 0.8)
	if hour_f >= 6.0 and hour_f <= 18.0:
		energy = lerp(0.2, 0.8, 1.0 - abs(hour_f - 12.0) / 6.0)
		visible = true
	else:
		energy = 0.1
		visible = true
		
	if clock_label:
		clock_label.text = "Giờ: %02d:00" % current_hour
		
	_update_compass_ui(angle)

func _update_compass_ui(angle: float):
	if not sun_dot:
		return
		
	# Bán kính vòng tròn la bàn (Compass Container là 100x100)
	var radius = 40.0
	var center = Vector2(50 - 4, 50 - 4) # Trừ đi nửa kích thước chấm đỏ (8x8)
	
	# Tính toán vị trí chấm đỏ trên vòng tròn
	var pos_x = cos(angle) * radius
	var pos_y = sin(angle) * radius
	
	sun_dot.position = center + Vector2(pos_x, pos_y)
	
	# Tính toán độ cao (Altitude): Cao nhất lúc 12:00 trưa (90 độ)
	# 6:00 (angle 0) -> 0 độ
	# 12:00 (angle PI/2) -> 90 độ
	# 18:00 (angle PI) -> 0 độ
	var altitude = 0.0
	if angle >= 0 and angle <= PI:
		altitude = sin(angle) * 90.0
	elif angle > PI:
		# Ban đêm, độ cao âm
		altitude = sin(angle) * 90.0
		
	if alt_label:
		alt_label.text = "Alt: %.1f°" % altitude
		
		# Đổi màu nhãn độ cao: Đêm thì màu xám, ngày thì màu đỏ/vàng
		if altitude > 0:
			alt_label.add_theme_color_override("font_color", Color(1, 0.8, 0)) # Vàng lúc ngày
		else:
			alt_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5)) # Xám lúc đêm
