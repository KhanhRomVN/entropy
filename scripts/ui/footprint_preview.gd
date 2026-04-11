extends Control

# Scripts dùng để hiển thị "Chân tiếp xúc" của vật thể lên góc màn hình để kiểm chứng
# Nó sẽ vẽ lại CollisionPolygon2D của vật thể tìm được

var target_poly: CollisionPolygon2D
var draw_scale: float = 0.2 # Tỉ lệ thu nhỏ để vừa vào góc UI

func _ready():
	# Đặt kích thước cho frame preview
	custom_minimum_size = Vector2(250, 200)
	# Để ở góc trái 20px
	position = Vector2(20, 20)

func _process(_delta):
	# Thường xuyên cập nhật tìm vật thể (vì nó được spawn động)
	if not target_poly:
		var entities = get_tree().get_nodes_in_group("entities")
		if entities.size() > 0:
			target_poly = entities[0].get_node_or_null("CollisionPolygon2D")
		else:
			# Tìm kiếm thủ công nếu chưa có group
			var windmill = get_tree().root.find_child("WindmillEntity", true, false)
			if windmill:
				target_poly = windmill.get_node_or_null("CollisionPolygon2D")
	
	queue_redraw()

func _draw():
	# Vẽ nền cho preview
	draw_rect(Rect2(0, 0, 250, 180), Color(0, 0, 0, 0.5))
	var font = get_theme_font("font")
	draw_string(font, Vector2(10, 25), "FOOTPRINT DEBUG VIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.YELLOW)
	
	if target_poly:
		var poly = target_poly.polygon
		if poly.size() < 3: return
		
		# Tâm của preview
		var center = Vector2(125, 100)
		var draw_points = PackedVector2Array()
		
		for p in poly:
			# Vẽ các điểm đã được scale
			draw_points.append(center + p * draw_scale)
		
		# Vẽ hình thoi (Footprint)
		draw_colored_polygon(draw_points, Color(0, 1, 1, 0.4)) # Cyan bán trong suốt
		draw_polyline(draw_points + PackedVector2Array([draw_points[0]]), Color(0, 1, 1, 1.0), 2.0)
		
		# Thông số
		draw_string(font, Vector2(10, 170), "Entity: " + target_poly.get_parent().name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	else:
		draw_string(font, Vector2(10, 100), "Waiting for Entity...", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.GRAY)
