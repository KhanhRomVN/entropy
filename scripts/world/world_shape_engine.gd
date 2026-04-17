# world_shape_engine.gd
# Engine tính toán hình dạng lục địa (SDF), climate-based biome và river data
# Thread-safe: tất cả method đều pure function
class_name WorldShapeEngine

# ═══════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════
var continent_polygon_a: PackedVector2Array
var continent_polygon_b: PackedVector2Array
var has_polygon_b: bool = false

var aabb_a: Rect2
var aabb_b: Rect2

var special_zones: Array = []
var resource_deposits: Array = []
var island_circles: Array = []
var lake_circles: Array = []
var river_sources: Array = []
var mask_image: Image = null
var biome_mask: Image = null
var has_mask: bool = false
var has_biome_mask: bool = false
var mask_size: Vector2 = Vector2.ZERO

var map_scale: float = 1000.0
var coast_width: float = 0.06
var warp_noise: FastNoiseLite = null
var detail_noise: FastNoiseLite = null

# Climate noises — tính toán temperature & humidity
var climate_temp_noise: FastNoiseLite = null    # Biến động nhiệt độ địa phương
var climate_humid_noise: FastNoiseLite = null   # Độ ẩm

var continent_type: String = "pangaea"

# ═══════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════
func setup(
	world_seed: int,
	_continent_type: String,
	_map_size: float,
	_warp_noise: FastNoiseLite,
	_detail_noise: FastNoiseLite,
	_mask_image: Image = null,
	_biome_mask: Image = null
):
	mask_image = _mask_image
	biome_mask = _biome_mask
	has_mask = mask_image != null
	has_biome_mask = biome_mask != null
	if has_mask:
		mask_size = Vector2(mask_image.get_width(), mask_image.get_height())
	continent_type = _continent_type
	map_scale = _map_size * 0.5
	warp_noise = _warp_noise
	detail_noise = _detail_noise

	# Tạo climate noises
	climate_temp_noise  = _make_noise(world_seed + 2222, FastNoiseLite.TYPE_PERLIN, 0.0008, 3)
	climate_humid_noise = _make_noise(world_seed + 3333, FastNoiseLite.TYPE_PERLIN, 0.0006, 3)

	var blueprint = WorldBlueprint
	var template = blueprint.CONTINENT_TEMPLATES.get(_continent_type, blueprint.CONTINENT_TEMPLATES["pangaea"])
	coast_width = template.get("coast_width", 0.06)

	continent_polygon_a = _build_polygon(template["polygon"], world_seed, template.get("warp_strength", 0.07))
	aabb_a = _calculate_aabb(continent_polygon_a)

	if template.has("polygon_b"):
		continent_polygon_b = _build_polygon(template["polygon_b"], world_seed + 999, template.get("warp_strength", 0.07))
		has_polygon_b = true
		aabb_b = _calculate_aabb(continent_polygon_b)
	else:
		has_polygon_b = false

	# Special zones
	var raw_special = blueprint.SPECIAL_ZONES.get(_continent_type, [])
	special_zones = _process_special_zones(raw_special, world_seed)

	# Resources
	var raw_deposits = blueprint.RESOURCE_DEPOSITS.get(_continent_type, [])
	resource_deposits = _process_resource_deposits(raw_deposits)

	# Lakes
	lake_circles = []
	if template.has("lakes"):
		for l in template["lakes"]:
			var l_pos = l["pos"] as Vector2
			var l_rad = l["radius"] as float
			lake_circles.append({
				"pos": l_pos,
				"radius": l_rad,
				"r_eff_sq": pow(l_rad + coast_width, 2)
			})

	# Islands
	island_circles = _process_archipelagos(template.get("archipelagos", []), world_seed)

	# River sources
	var raw_rivers = blueprint.RIVER_SOURCES.get(_continent_type, [])
	river_sources = _process_river_sources(raw_rivers)

	print("[SHAPE-ENGINE] Setup | Template: %s | Islands: %d | Mask: %s" % [
		_continent_type, island_circles.size(), "YES" if has_mask else "NO"
	])

func _make_noise(s, t, f, o) -> FastNoiseLite:
	var n = FastNoiseLite.new()
	n.seed = s; n.noise_type = t; n.frequency = f; n.fractal_octaves = o
	return n

func _build_polygon(template_points: Array, seed: int, warp_str: float) -> PackedVector2Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed ^ 0xCAFE_BABE
	var subdivided: Array = []
	var n = template_points.size()
	for i in range(n):
		var a = template_points[i] as Vector2
		var b = template_points[(i + 1) % n] as Vector2
		subdivided.append(a)
		for t_val in [0.25, 0.5, 0.75]:
			var mid = a.lerp(b, t_val)
			var jitter = Vector2(rng.randf_range(-warp_str, warp_str), rng.randf_range(-warp_str, warp_str))
			subdivided.append(mid + jitter)
	var result = PackedVector2Array()
	for p in subdivided:
		result.append(p as Vector2)
	return result

func _process_special_zones(raw: Array, seed: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed ^ 0xDEAD_BEEF
	var result = []
	for zone in raw:
		var z = zone.duplicate()
		z["pos"] = (z["pos"] as Vector2) + Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
		result.append(z)
	return result

func _process_resource_deposits(raw: Array) -> Array:
	var result = []
	for dep in raw:
		if dep["density"] > 0.05:
			result.append(dep.duplicate())
	return result

func _process_archipelagos(raw: Array, seed: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed ^ 0x1515_9999
	var result = []
	for group in raw:
		var base_pos = group["pos"] as Vector2
		for i in range(group["count"] as int):
			var angle = rng.randf() * TAU
			var dist = sqrt(rng.randf()) * (group["spread"] as float)
			var island_pos = base_pos + Vector2(cos(angle), sin(angle)) * dist
			var r_range = group["radius_range"] as Vector2
			var r = rng.randf_range(r_range.x, r_range.y)
			var r_eff = r + coast_width * 1.5
			result.append({"pos": island_pos, "radius": r, "r_sq": r * r, "r_eff_sq": r_eff * r_eff})
	return result

func _process_river_sources(raw: Array) -> Array:
	var result = []
	for src in raw:
		result.append({
			"pos": src["pos"] as Vector2,
			"strength": src["strength"] as float,
			"world_pos": (src["pos"] as Vector2) * map_scale
		})
	return result

func _calculate_aabb(polygon: PackedVector2Array) -> Rect2:
	if polygon.size() == 0: return Rect2()
	var min_p = polygon[0]; var max_p = polygon[0]
	for p in polygon:
		min_p.x = min(min_p.x, p.x); min_p.y = min(min_p.y, p.y)
		max_p.x = max(max_p.x, p.x); max_p.y = max(max_p.y, p.y)
	return Rect2(min_p, max_p - min_p)

func polygon_sdf(norm_pos: Vector2, polygon: PackedVector2Array, aabb: Rect2) -> float:
	var margin = 0.2
	if not aabb.grow(margin).has_point(norm_pos):
		var q = (norm_pos - aabb.get_center()).abs() - aabb.size / 2.0
		return Vector2(max(q.x, 0.0), max(q.y, 0.0)).length() + min(max(q.x, q.y), 0.0)
	var d = INF
	var inside = false
	var n = polygon.size()
	for i in range(n):
		var a = polygon[i]; var b = polygon[(i + 1) % n]
		var pa = norm_pos - a; var ba = b - a
		var h = clamp(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
		d = min(d, (pa - ba * h).length())
		if (a.y <= norm_pos.y and b.y > norm_pos.y) or (b.y <= norm_pos.y and a.y > norm_pos.y):
			if norm_pos.x < a.x + (norm_pos.y - a.y) / (b.y - a.y) * (b.x - a.x):
				inside = !inside
	return d * (-1.0 if inside else 1.0)

func get_land_value(tile_pos: Vector2) -> float:
	if is_nan(tile_pos.x) or is_nan(tile_pos.y): return 0.0
	var norm = tile_pos / map_scale
	if warp_noise:
		var wx1 = warp_noise.get_noise_2d(tile_pos.x * 0.004, tile_pos.y * 0.004)
		var wy1 = warp_noise.get_noise_2d(tile_pos.y * 0.004, tile_pos.x * 0.004 + 100.0)
		var warp1 = Vector2(wx1, wy1) * 0.15
		var wx2 = warp_noise.get_noise_2d(tile_pos.x * 0.015 + 300.0, tile_pos.y * 0.015)
		var wy2 = warp_noise.get_noise_2d(tile_pos.y * 0.015 + 300.0, tile_pos.x * 0.015)
		var warp2 = Vector2(wx2, wy2) * 0.05
		var wx3 = detail_noise.get_noise_2d(tile_pos.x * 0.05, tile_pos.y * 0.05)
		var wy3 = detail_noise.get_noise_2d(tile_pos.y * 0.05 + 500.0, tile_pos.x * 0.05)
		var warp3 = Vector2(wx3, wy3) * 0.02
		norm += warp1 + warp2 + warp3
	var sdf: float = 1.0
	if has_mask:
		# Warp UV để bờ biển ảnh mask không bị thẳng tắp
		var uv = (norm * 0.5) + Vector2(0.5, 0.5)
		
		if uv.x >= 0.0 and uv.x < 1.0 and uv.y >= 0.0 and uv.y < 1.0:
			var px = int(uv.x * (mask_size.x - 1))
			var py = int(uv.y * (mask_size.y - 1))
			var pixel_v = mask_image.get_pixel(px, py).v
			
			# Chuyển đổi Brightness (0->1) thành SDF (-0.1 -> 0.1)
			# 1.0 (Trắng) -> -0.1 (Trong đất)
			# 0.0 (Đen)   ->  0.1 (Ngoài biển)
			sdf = (0.5 - pixel_v) * 0.25
		else:
			# Ngoài phạm vi ảnh mask coi như là biển sâu
			sdf = 0.5
	else:
		var sdf_a = polygon_sdf(norm, continent_polygon_a, aabb_a)
		sdf = sdf_a
		if has_polygon_b:
			sdf = min(sdf_a, polygon_sdf(norm, continent_polygon_b, aabb_b))
	for island in island_circles:
		var d_sq = norm.distance_squared_to(island["pos"])
		if d_sq <= island["r_eff_sq"]:
			sdf = min(sdf, sqrt(d_sq) - island["radius"])
	for lake in lake_circles:
		var d_sq = norm.distance_squared_to(lake["pos"])
		if d_sq <= lake["r_eff_sq"]:
			sdf = max(sdf, -(sqrt(d_sq) - lake["radius"]))
	return smoothstep(coast_width, -coast_width * 0.5, sdf)

func get_climate(tile_pos: Vector2, land_value: float) -> Dictionary:
	var norm_y = clamp((tile_pos.y / map_scale + 1.0) * 0.5, 0.0, 1.0)
	var temperature = clamp(norm_y + climate_temp_noise.get_noise_2d(tile_pos.x, tile_pos.y) * 0.20 - max(0.0, (land_value - 0.65) * 0.6), 0.0, 1.0)
	var humidity = clamp((climate_humid_noise.get_noise_2d(tile_pos.x, tile_pos.y) + 1.0) * 0.5 * 0.7 + smoothstep(0.5, 0.1, land_value) * 0.4 + 0.15, 0.0, 1.0)
	return {"temperature": temperature, "humidity": humidity}

func get_biome(tile_pos: Vector2, land_value: float) -> Dictionary:
	if land_value <= 0.0: return {"biome": "deep_sea", "strength": 1.0}
	
	if has_biome_mask:
		var norm = tile_pos / map_scale
		var uv = (norm * 0.5) + Vector2(0.5, 0.5)
		if uv.x >= 0.0 and uv.x < 1.0 and uv.y >= 0.0 and uv.y < 1.0:
			var px = int(uv.x * (biome_mask.get_width() - 1))
			var py = int(uv.y * (biome_mask.get_height() - 1))
			var color = biome_mask.get_pixel(px, py)
			
			# Map color back to biome ID
			# Chúng ta so sánh màu sắc (nên dùng Delta E hoặc đơn giản là khoảng cách màu)
			var best_biome = "plains"
			var min_dist = 100.0
			
			# Danh sách màu sắc tương ứng (nên đồng bộ với Tool)
			var colors = {
				"deep_sea": Color("#1a3a6b"), "beach": Color("#2a6896"), "plains": Color("#7ab648"),
				"forest": Color("#3a7a45"), "jungle": Color("#1e5c30"), "desert": Color("#c8a050"),
				"savannah": Color("#9aaf50"), "tundra": Color("#8aabb8"), "taiga": Color("#4d6d5d"),
				"volcano": Color("#9a3020"), "salt_desert": Color("#ddeef8"), "bamboo": Color("#5c7a3a")
			}
			
			for b_id in colors:
				var d = _color_dist(color, colors[b_id])
				if d < min_dist:
					min_dist = d
					best_biome = b_id
			
			if min_dist < 0.1: # Nếu khớp màu tốt
				return {"biome": best_biome, "strength": 1.0}

	return {"biome": "plains", "strength": 1.0}

func _color_dist(c1: Color, c2: Color) -> float:
	return abs(c1.r - c2.r) + abs(c1.g - c2.g) + abs(c1.b - c2.b)

func get_river_value(tile_pos: Vector2, land_value: float) -> float:
	if land_value < 0.18 or land_value > 0.92: return 1.0
	var closest_dist = INF; var closest_strength = 0.0
	for src in river_sources:
		var d = tile_pos.distance_to(src["world_pos"])
		if d < closest_dist: closest_dist = d; closest_strength = src["strength"]
	if closest_dist > map_scale * 1.5: return 1.0
	var grad_x = detail_noise.get_noise_2d(tile_pos.x + 5.0, tile_pos.y) - detail_noise.get_noise_2d(tile_pos.x - 5.0, tile_pos.y)
	var grad_y = detail_noise.get_noise_2d(tile_pos.y + 5.0, tile_pos.x) - detail_noise.get_noise_2d(tile_pos.y - 5.0, tile_pos.x)
	var warped_pos = tile_pos + Vector2(grad_x, grad_y) * 200.0
	var river_n = detail_noise.get_noise_2d(warped_pos.x * 0.003, warped_pos.y * 0.003)
	var width = lerp(0.04, 0.12, clamp(closest_dist / (map_scale * 0.8), 0.0, 1.0)) * closest_strength
	if abs(river_n) < width: return smoothstep(0.0, width, abs(river_n))
	return 1.0

func get_resource_at(tile_pos: Vector2, scatter_val: float) -> String:
	var norm = tile_pos / map_scale
	for dep in resource_deposits:
		var dist = norm.distance_to(dep["pos"] as Vector2)
		if dist < (dep["spread"] as float):
			if scatter_val > (1.0 - (dep["density"] as float) * smoothstep(dep["spread"] as float, 0.0, dist)): return dep["type"]
	return ""

func debug_info(tile_pos: Vector2) -> String:
	var land = get_land_value(tile_pos); var biome = get_biome(tile_pos, land); var climate = get_climate(tile_pos, land)
	return "Land:%.2f | Biome:%s | Temp:%.2f | Humid:%.2f" % [land, biome["biome"], climate["temperature"], climate["humidity"]]
