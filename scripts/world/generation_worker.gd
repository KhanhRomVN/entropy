# scripts/world/generation_worker.gd
# Module quản lý việc tính toán noise ở background và cache dữ liệu
extends Node

const CHUNK_SIZE = 16

# ═══════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════
var noise_cache: Dictionary = {}
var pending_tasks: Dictionary = {}
var mutex: Mutex

# Tham chiếu từ Orchestrator
var shape_engine = null
var map_size: int = 2000

# Noise instances
var detail_noise: FastNoiseLite
var forest_noise: FastNoiseLite
var river_noise: FastNoiseLite
var river_mask_noise: FastNoiseLite
var scatter_noise: FastNoiseLite

const MAX_CONCURRENT_TASKS: int = 4

func _init():
	mutex = Mutex.new()

func setup(
	_shape_engine,
	_m_size: int,
	_d_noise,
	_f_noise,
	_r_noise,
	_rm_noise,
	_s_noise
):
	shape_engine = _shape_engine
	map_size = _m_size
	detail_noise = _d_noise
	forest_noise = _f_noise
	river_noise = _r_noise
	river_mask_noise = _rm_noise
	scatter_noise = _s_noise

func trigger_task(cpos: Vector2i):
	mutex.lock()
	if noise_cache.has(cpos) or pending_tasks.has(cpos):
		mutex.unlock()
		return
	if pending_tasks.size() >= MAX_CONCURRENT_TASKS:
		mutex.unlock()
		return
	pending_tasks[cpos] = true
	mutex.unlock()

	WorkerThreadPool.add_task(_thread_generate_noise.bind(cpos))

func get_cached_data(cpos: Vector2i):
	mutex.lock()
	var data = noise_cache.get(cpos)
	mutex.unlock()
	return data

func erase_cache(cpos: Vector2i):
	mutex.lock()
	noise_cache.erase(cpos)
	mutex.unlock()

func _thread_generate_noise(cpos: Vector2i):
	var s = cpos * CHUNK_SIZE
	var total = CHUNK_SIZE * CHUNK_SIZE

	var land_data     = PackedFloat32Array(); land_data.resize(total)
	var biome_data    = PackedByteArray();    biome_data.resize(total)
	var forest_data   = PackedFloat32Array(); forest_data.resize(total)
	var river_data    = PackedFloat32Array(); river_data.resize(total)
	var riv_mask_data = PackedFloat32Array(); riv_mask_data.resize(total)
	var scatter_data  = PackedFloat32Array(); scatter_data.resize(total)
	var resource_data = PackedByteArray();    resource_data.resize(total)

	const BIOME_INDEX = {
		"deep_sea": 0, "beach": 1, "plains": 2, "forest": 3,
		"jungle": 4, "desert": 5, "tundra": 6, "taiga": 7,
		"savannah": 8, "volcano": 9, "bamboo": 10, "salt_desert": 11,
	}
	const RESOURCE_INDEX = {
		"": 0, "gold": 1, "iron": 2, "copper": 3, "silver": 4, "tin": 5
	}

	var river_density_mult = 1.0

	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var gx = s.x + lx
			var gy = s.y + ly
			var gpos = Vector2(gx, gy)
			var idx = ly * CHUNK_SIZE + lx

			if abs(gx) > map_size or abs(gy) > map_size:
				land_data[idx]  = 0.0
				biome_data[idx] = 0
				forest_data[idx]  = 0.0
				river_data[idx]   = 1.0
				riv_mask_data[idx]= 0.0
				scatter_data[idx] = 0.0
				resource_data[idx]= 0
				continue

			if !shape_engine:
				land_data[idx] = 0.0
				biome_data[idx] = 0
				continue
				
			var land_val = shape_engine.get_land_value(gpos)
			land_data[idx] = land_val

			var biome_result = shape_engine.get_biome(gpos, land_val)
			var biome_str = biome_result["biome"] as String
			biome_data[idx] = BIOME_INDEX.get(biome_str, 2)

			forest_data[idx]   = forest_noise.get_noise_2d(gx, gy)
			riv_mask_data[idx] = river_mask_noise.get_noise_2d(gx, gy)
			var scatter_raw    = (scatter_noise.get_noise_2d(gx, gy) + 1.0) / 2.0
			scatter_data[idx]  = scatter_raw

			var river_val = shape_engine.get_river_value(gpos, land_val)
			river_data[idx] = river_val

			var res_str = shape_engine.get_resource_at(gpos, scatter_raw)
			resource_data[idx] = RESOURCE_INDEX.get(res_str, 0)

	mutex.lock()
	noise_cache[cpos] = {
		"land":     land_data,
		"biome":    biome_data,
		"forest":   forest_data,
		"river":    river_data,
		"riv_mask": riv_mask_data,
		"scatter":  scatter_data,
		"resource": resource_data,
	}
	pending_tasks.erase(cpos)
	mutex.unlock()
