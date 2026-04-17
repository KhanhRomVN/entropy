# world_blueprint.gd
# Định nghĩa tất cả template lục địa, biome zones và cấu hình thế giới cố định
# KHÔNG có random thuần túy — mọi thứ đều có cấu trúc định sẵn
class_name WorldBlueprint

# ═══════════════════════════════════════════════════════════════
# CONTINENT TEMPLATES
# Tọa độ chuẩn hóa trong [-1.0, 1.0]
# Polygon theo chiều kim đồng hồ
# ═══════════════════════════════════════════════════════════════
const CONTINENT_TEMPLATES: Dictionary = {

	# Lục địa lớn dạng Pangaea — chiếm ~60% map
	"pangaea": {
		"polygon": [
			Vector2( 0.00, -0.95), # Cực Bắc
			Vector2( 0.25, -0.90),
			Vector2( 0.45, -0.85), # Bán đảo Đông Bắc
			Vector2( 0.60, -0.70),
			Vector2( 0.72, -0.50),
			Vector2( 0.85, -0.35), # Mũi Đông Bắc nhọn
			Vector2( 0.75, -0.15), 
			Vector2( 0.65,  0.00), # Vịnh nhỏ phía Đông
			Vector2( 0.75,  0.15),
			Vector2( 0.90,  0.40), # Mũi phía Đông
			Vector2( 0.82,  0.60),
			Vector2( 0.68,  0.78), # Bán đảo Đông Nam
			Vector2( 0.45,  0.92), # Mũi phía Nam
			Vector2( 0.20,  0.88),
			Vector2( 0.00,  0.95), # Cực Nam
			Vector2(-0.25,  0.90),
			Vector2(-0.48,  0.92), # Bán đảo Tây Nam
			Vector2(-0.65,  0.75),
			Vector2(-0.80,  0.50), # Mũi phía Tây (Dưới)
			Vector2(-0.65,  0.30),
			Vector2(-0.42,  0.15), # LƯNG VỊNH TÂY (Cực sâu)
			Vector2(-0.35, -0.05),
			Vector2(-0.45, -0.25),
			Vector2(-0.70, -0.42), # Mũi Tây Bắc (Nhọn)
			Vector2(-0.82, -0.65),
			Vector2(-0.68, -0.85),
			Vector2(-0.45, -0.92),
			Vector2(-0.25, -0.88),
		],
		"lakes": [
			{"pos": Vector2(-0.40, 0.05), "radius": 0.14}, # Hồ lớn phía Tây (Vịnh khép kín)
			{"pos": Vector2(0.12, -0.28), "radius": 0.07}, # Hồ trung tâm nhỏ
			{"pos": Vector2(-0.68, 0.12), "radius": 0.04}, # Hồ nhỏ phía Tây
		],
		"archipelagos": [
			{"pos": Vector2(0.85, 0.10),  "count": 22, "spread": 0.28, "radius_range": Vector2(0.012, 0.048)}, # Chuỗi đảo Đông
			{"pos": Vector2(-0.92, 0.55), "count": 6,  "spread": 0.15, "radius_range": Vector2(0.02, 0.035)},  # Đảo lẻ Tây Nam
			{"pos": Vector2(0.10, -0.95),  "count": 4,  "spread": 0.10, "radius_range": Vector2(0.015, 0.03)},  # Đảo nhỏ Cực Bắc
		],
		"coast_width": 0.045,      
		"warp_strength": 0.12,    # Giảm warp để bám sát hình vẽ mask hơn
		"mask_path": "res://assets/world/continent_mask.png",
		"description": "Siêu lục địa Pangaea Mask-Based — Hình dạng được định nghĩa bởi file ảnh"
	},

	# Template này để bạn tự vẽ hình dạng tùy thích bằng file ảnh
	# Màu TRẮNG = Đất, Màu ĐEN = Nước
	"custom_map": {
		"use_mask": true,
		"mask_path": "res://assets/world/custom_mask.png", # Bạn vẽ ảnh này và lưu vào đây
		"coast_width": 0.05,
		"warp_strength": 0.1,
		"description": "Bản đồ tùy chỉnh — vẽ bằng tay qua file ảnh custom_mask.png"
	},

	# Lục địa nhỏ hình lưỡi liềm — thế giới khắc nghiệt
	"crescent": {
		"polygon": [
			Vector2(0.55, -0.55),
			Vector2(0.72, -0.30),
			Vector2(0.78,  0.00),
			Vector2(0.70,  0.30),
			Vector2(0.50,  0.52),
			Vector2(0.25,  0.60),
			Vector2(0.00,  0.55),
			Vector2(-0.18, 0.38),
			Vector2(-0.15, 0.10),
			Vector2(0.02, -0.10),
			Vector2(0.25, -0.25),
			Vector2(0.20, -0.48),
			Vector2(0.35, -0.60),
		],
		"coast_width": 0.05,
		"warp_strength": 0.08,
		"description": "Lục địa hình lưỡi liềm — bao quanh vịnh trung tâm"
	},

	# Hai lục địa tách biệt — khoảng cách lớn, cần thuyền
	"twin_continents": {
		# Lục địa Tây
		"polygon": [
			Vector2(-0.50,-0.55),
			Vector2(-0.30,-0.62),
			Vector2(-0.10,-0.55),
			Vector2( 0.00,-0.35),
			Vector2( 0.02,-0.10),
			Vector2(-0.08, 0.12),
			Vector2(-0.25, 0.30),
			Vector2(-0.45, 0.40),
			Vector2(-0.62, 0.32),
			Vector2(-0.70, 0.10),
			Vector2(-0.68,-0.15),
			Vector2(-0.60,-0.38),
		],
		# Lục địa Đông (polygon thứ 2 — xử lý riêng)
		"polygon_b": [
			Vector2(0.30, -0.45),
			Vector2(0.50, -0.55),
			Vector2(0.68, -0.42),
			Vector2(0.75, -0.18),
			Vector2(0.72,  0.10),
			Vector2(0.60,  0.35),
			Vector2(0.40,  0.50),
			Vector2(0.22,  0.45),
			Vector2(0.12,  0.22),
			Vector2(0.15, -0.05),
			Vector2(0.22, -0.28),
		],
		"coast_width": 0.055,
		"warp_strength": 0.09,
		"description": "Hai lục địa tách đôi — Đông và Tây"
	},

	# Lục địa hình chữ nhật to — nhiều đất, ít biển
	"laurasia": {
		"polygon": [
			Vector2(-0.62,-0.42),
			Vector2(-0.30,-0.65),
			Vector2( 0.00,-0.70),
			Vector2( 0.30,-0.62),
			Vector2( 0.58,-0.45),
			Vector2( 0.72,-0.15),
			Vector2( 0.70, 0.18),
			Vector2( 0.55, 0.45),
			Vector2( 0.25, 0.62),
			Vector2(-0.05, 0.68),
			Vector2(-0.35, 0.58),
			Vector2(-0.58, 0.38),
			Vector2(-0.70, 0.10),
			Vector2(-0.68,-0.18),
		],
		"coast_width": 0.05,
		"warp_strength": 0.06,
		"description": "Laurasia — lục địa bắc rộng lớn"
	},

	# Lục địa nhỏ bị cô lập — thế giới đảo nhỏ
	"isolated_isle": {
		"polygon": [
			Vector2( 0.00,-0.45),
			Vector2( 0.22,-0.38),
			Vector2( 0.38,-0.18),
			Vector2( 0.40, 0.05),
			Vector2( 0.30, 0.28),
			Vector2( 0.10, 0.42),
			Vector2(-0.12, 0.40),
			Vector2(-0.28, 0.22),
			Vector2(-0.32,-0.02),
			Vector2(-0.22,-0.28),
			Vector2(-0.05,-0.42),
		],
		"coast_width": 0.07,
		"warp_strength": 0.10,
		"description": "Đảo lục địa nhỏ — sinh tồn khắc nghiệt"
	},
}

# ═══════════════════════════════════════════════════════════════
# BIOME ZONE DEFINITIONS
# Mỗi template có layout biome riêng
# pos: Vector2 chuẩn hóa [-1,1] trong không gian lục địa
# radius: bán kính ảnh hưởng (chuẩn hóa)
# priority: 1-10, cao hơn = đè biome khác
# blend: độ mờ biên giới (0=cứng, 1=mượt)
# ═══════════════════════════════════════════════════════════════
const BIOME_LAYOUTS: Dictionary = {

	"pangaea": [
		# [NW] Vùng Tây Bắc — Tuyết lạnh & Rừng thông
		{"type": "tundra",   "pos": Vector2(-0.55, -0.55), "radius": 0.35, "priority": 9,  "blend": 0.8},
		{"type": "taiga",    "pos": Vector2(-0.45, -0.30), "radius": 0.25, "priority": 7,  "blend": 0.75},
		
		# [SE] Vùng Đông Nam — Sa mạc nóng & Sa mạc muối
		{"type": "desert",      "pos": Vector2(0.55, 0.45), "radius": 0.28, "priority": 8,  "blend": 0.7},
		{"type": "salt_desert", "pos": Vector2(0.40, 0.35), "radius": 0.18, "priority": 9,  "blend": 0.6},
		{"type": "savannah",    "pos": Vector2(0.35, 0.15), "radius": 0.22, "priority": 6,  "blend": 0.8},
		
		# [NE] Vùng Đông Bắc — Núi lửa
		{"type": "volcano",  "pos": Vector2(0.40, -0.45), "radius": 0.30, "priority": 10, "blend": 0.55},
		
		# [SW & Center] Vùng Trung tâm & Tây Nam — Rừng rậm & Đồng cỏ trù phú
		{"type": "forest",   "pos": Vector2(-0.35, 0.15), "radius": 0.28, "priority": 6,  "blend": 0.8},
		{"type": "jungle",   "pos": Vector2(-0.50, 0.45), "radius": 0.25, "priority": 8,  "blend": 0.75},
		{"type": "plains",   "pos": Vector2(-0.05, 0.05), "radius": 0.35, "priority": 4,  "blend": 1.0},
		{"type": "plains",   "pos": Vector2(0.10, 0.45),  "radius": 0.25, "priority": 5,  "blend": 0.9},
		
		# Rừng tre & Các tiểu vùng đặc biệt
		{"type": "bamboo",   "pos": Vector2(-0.15, -0.35), "radius": 0.15, "priority": 7,  "blend": 0.7},
	],

	"custom_map": [
		{"type": "plains",   "pos": Vector2(0.00, 0.00),  "radius": 0.50, "priority": 1, "blend": 1.0},
		{"type": "forest",   "pos": Vector2(-0.25, -0.25), "radius": 0.30, "priority": 5, "blend": 0.8},
		{"type": "desert",   "pos": Vector2(0.25, 0.25),  "radius": 0.30, "priority": 5, "blend": 0.8},
	],

	"crescent": [
		{"type": "tundra",   "pos": Vector2( 0.55,-0.42), "radius": 0.22, "priority": 9,  "blend": 0.75},
		{"type": "desert",   "pos": Vector2( 0.65, 0.10), "radius": 0.20, "priority": 8,  "blend": 0.7},
		{"type": "jungle",   "pos": Vector2( 0.40, 0.48), "radius": 0.22, "priority": 8,  "blend": 0.75},
		{"type": "plains",   "pos": Vector2( 0.12, 0.30), "radius": 0.28, "priority": 4,  "blend": 1.0},
		{"type": "forest",   "pos": Vector2(-0.05, 0.08), "radius": 0.20, "priority": 6,  "blend": 0.8},
		{"type": "volcano",  "pos": Vector2( 0.30,-0.38), "radius": 0.10, "priority": 10, "blend": 0.5},
	],

	"twin_continents": [
		# Lục địa Tây
		{"type": "tundra",   "pos": Vector2(-0.45,-0.40), "radius": 0.22, "priority": 9, "blend": 0.75},
		{"type": "forest",   "pos": Vector2(-0.42, 0.15), "radius": 0.20, "priority": 6, "blend": 0.8},
		{"type": "plains",   "pos": Vector2(-0.25, 0.00), "radius": 0.25, "priority": 4, "blend": 1.0},
		{"type": "volcano",  "pos": Vector2(-0.12,-0.30), "radius": 0.10, "priority": 10,"blend": 0.5},
		# Lục địa Đông
		{"type": "desert",   "pos": Vector2( 0.58,-0.28), "radius": 0.20, "priority": 8, "blend": 0.7},
		{"type": "jungle",   "pos": Vector2( 0.42, 0.35), "radius": 0.22, "priority": 8, "blend": 0.75},
		{"type": "plains",   "pos": Vector2( 0.35,-0.05), "radius": 0.22, "priority": 4, "blend": 1.0},
		{"type": "bamboo",   "pos": Vector2( 0.20, 0.40), "radius": 0.14, "priority": 7, "blend": 0.65},
	],

	"laurasia": [
		{"type": "tundra",   "pos": Vector2(-0.10,-0.55), "radius": 0.28, "priority": 9,  "blend": 0.75},
		{"type": "taiga",    "pos": Vector2( 0.40,-0.38), "radius": 0.22, "priority": 7,  "blend": 0.7},
		{"type": "desert",   "pos": Vector2( 0.55, 0.05), "radius": 0.20, "priority": 8,  "blend": 0.7},
		{"type": "jungle",   "pos": Vector2( 0.30, 0.48), "radius": 0.22, "priority": 8,  "blend": 0.75},
		{"type": "plains",   "pos": Vector2( 0.00, 0.10), "radius": 0.35, "priority": 3,  "blend": 1.0},
		{"type": "forest",   "pos": Vector2(-0.40, 0.25), "radius": 0.22, "priority": 6,  "blend": 0.8},
		{"type": "savannah", "pos": Vector2(-0.02, 0.50), "radius": 0.20, "priority": 6,  "blend": 0.85},
		{"type": "volcano",  "pos": Vector2( 0.18,-0.20), "radius": 0.12, "priority": 10, "blend": 0.5},
		{"type": "bamboo",   "pos": Vector2(-0.55,-0.10), "radius": 0.15, "priority": 7,  "blend": 0.65},
	],

	"isolated_isle": [
		{"type": "tundra",   "pos": Vector2( 0.02,-0.35), "radius": 0.18, "priority": 9, "blend": 0.7},
		{"type": "forest",   "pos": Vector2(-0.20, 0.10), "radius": 0.18, "priority": 6, "blend": 0.8},
		{"type": "desert",   "pos": Vector2( 0.28, 0.05), "radius": 0.15, "priority": 8, "blend": 0.7},
		{"type": "jungle",   "pos": Vector2( 0.08, 0.32), "radius": 0.15, "priority": 8, "blend": 0.75},
		{"type": "plains",   "pos": Vector2(-0.05,-0.02), "radius": 0.22, "priority": 3, "blend": 1.0},
		{"type": "volcano",  "pos": Vector2( 0.20,-0.20), "radius": 0.10, "priority": 10,"blend": 0.5},
	],
}

# ═══════════════════════════════════════════════════════════════
# RESOURCE DEPOSIT DEFINITIONS
# Vị trí quặng và tài nguyên quan trọng — CỐ ĐỊNH theo template
# ═══════════════════════════════════════════════════════════════
const RESOURCE_DEPOSITS: Dictionary = {
	"pangaea": [
		{"type": "gold",   "pos": Vector2( 0.28,-0.10), "density": 0.92, "spread": 0.08},
		{"type": "gold",   "pos": Vector2(-0.35, 0.30), "density": 0.90, "spread": 0.07},
		{"type": "iron",   "pos": Vector2( 0.15,-0.35), "density": 0.80, "spread": 0.12},
		{"type": "iron",   "pos": Vector2(-0.20, 0.10), "density": 0.80, "spread": 0.10},
		{"type": "copper", "pos": Vector2( 0.55,-0.10), "density": 0.75, "spread": 0.15},
		{"type": "silver", "pos": Vector2(-0.55, 0.40), "density": 0.88, "spread": 0.09},
	],
	"crescent": [
		{"type": "gold",   "pos": Vector2( 0.45,-0.10), "density": 0.93, "spread": 0.07},
		{"type": "iron",   "pos": Vector2( 0.10, 0.20), "density": 0.78, "spread": 0.11},
		{"type": "copper", "pos": Vector2( 0.60, 0.35), "density": 0.72, "spread": 0.14},
	],
	"twin_continents": [
		{"type": "gold",   "pos": Vector2(-0.35,-0.15), "density": 0.91, "spread": 0.08},
		{"type": "gold",   "pos": Vector2( 0.48, 0.10), "density": 0.91, "spread": 0.08},
		{"type": "iron",   "pos": Vector2(-0.20, 0.28), "density": 0.79, "spread": 0.11},
		{"type": "silver", "pos": Vector2( 0.32,-0.35), "density": 0.87, "spread": 0.09},
		{"type": "copper", "pos": Vector2( 0.55, 0.28), "density": 0.74, "spread": 0.13},
	],
	"laurasia": [
		{"type": "gold",   "pos": Vector2( 0.25,-0.08), "density": 0.91, "spread": 0.08},
		{"type": "gold",   "pos": Vector2(-0.48, 0.12), "density": 0.89, "spread": 0.08},
		{"type": "iron",   "pos": Vector2( 0.00,-0.40), "density": 0.82, "spread": 0.13},
		{"type": "copper", "pos": Vector2( 0.50, 0.30), "density": 0.73, "spread": 0.15},
		{"type": "silver", "pos": Vector2(-0.30, 0.45), "density": 0.86, "spread": 0.10},
	],
	"isolated_isle": [
		{"type": "gold",   "pos": Vector2( 0.15,-0.05), "density": 0.95, "spread": 0.06},
		{"type": "iron",   "pos": Vector2(-0.18, 0.20), "density": 0.85, "spread": 0.10},
		{"type": "copper", "pos": Vector2( 0.22, 0.28), "density": 0.78, "spread": 0.12},
	],
}

# ═══════════════════════════════════════════════════════════════
# CLIMATE BIOME TABLE
# Trục X: humidity  0=khô → 4=ướt
# Trục Y: temperature  0=lạnh → 4=nóng
# Kết quả: tên biome
# ═══════════════════════════════════════════════════════════════
const CLIMATE_TABLE: Array = [
	# humid=0      humid=1     humid=2     humid=3     humid=4
	["tundra",   "tundra",   "taiga",    "taiga",    "taiga"   ],  # temp=0 (cực lạnh)
	["tundra",   "taiga",    "taiga",    "forest",   "forest"  ],  # temp=1 (lạnh)
	["desert",   "plains",   "plains",   "forest",   "forest"  ],  # temp=2 (ôn đới)
	["desert",   "savannah", "plains",   "jungle",   "jungle"  ],  # temp=3 (ấm)
	["desert",   "savannah", "savannah", "jungle",   "jungle"  ],  # temp=4 (nóng)
]

# Override zones: Vùng đặc biệt đè lên climate table
# type, pos, radius, priority — giống cũ nhưng chỉ dùng cho special biomes
const SPECIAL_ZONES: Dictionary = {
	"pangaea": [
		{"type": "volcano",     "pos": Vector2(0.40, -0.45),  "radius": 0.22, "priority": 10},
		{"type": "bamboo",      "pos": Vector2(-0.15, -0.35), "radius": 0.14, "priority": 8 },
		{"type": "salt_desert", "pos": Vector2(0.40, 0.35),   "radius": 0.15, "priority": 9 },
	],
	"crescent": [
		{"type": "volcano",     "pos": Vector2(0.30, -0.38),  "radius": 0.10, "priority": 10},
	],
	"twin_continents": [
		{"type": "volcano",     "pos": Vector2(-0.12, -0.30), "radius": 0.10, "priority": 10},
		{"type": "bamboo",      "pos": Vector2(0.20, 0.40),   "radius": 0.12, "priority": 8 },
	],
	"laurasia": [
		{"type": "volcano",     "pos": Vector2(0.18, -0.20),  "radius": 0.12, "priority": 10},
		{"type": "bamboo",      "pos": Vector2(-0.55, -0.10), "radius": 0.13, "priority": 8 },
	],
	"isolated_isle": [
		{"type": "volcano",     "pos": Vector2(0.20, -0.20),  "radius": 0.10, "priority": 10},
	],
}

# River source points — vùng cao sinh ra sông
# pos: chuẩn hóa [-1,1], strength: lưu lượng ban đầu
const RIVER_SOURCES: Dictionary = {
	"pangaea": [
		{"pos": Vector2( 0.38, -0.48), "strength": 1.0},  # Núi lửa Đông Bắc
		{"pos": Vector2(-0.52, -0.52), "strength": 0.8},  # Tây Bắc tuyết
		{"pos": Vector2(-0.30,  0.42), "strength": 0.7},  # Rừng Tây Nam
		{"pos": Vector2( 0.55,  0.40), "strength": 0.6},  # Sa mạc Đông Nam
	],

	"custom_map": [
		{"pos": Vector2(0.0, 0.0), "strength": 1.0},
	],

	"crescent": [
		{"pos": Vector2(0.55, -0.42), "strength": 0.9},
		{"pos": Vector2(0.65,  0.10), "strength": 0.6},
	],
	"twin_continents": [
		{"pos": Vector2(-0.42, -0.35), "strength": 0.8},
		{"pos": Vector2( 0.55, -0.25), "strength": 0.8},
	],
	"laurasia": [
		{"pos": Vector2(-0.10, -0.52), "strength": 1.0},
		{"pos": Vector2(0.42, -0.35), "strength": 0.7},
		{"pos": Vector2(-0.40,  0.20), "strength": 0.6},
	],
	"isolated_isle": [
		{"pos": Vector2(0.02, -0.32), "strength": 0.9},
	],
}
