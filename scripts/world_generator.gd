extends Node2D

const CHUNK_SIZE = 16
const MAX_HEIGHT = 4

@export var render_distance_base: int = 4
@export var tileset: TileSet
@export var noise_seed: int = 42
@export var noise_frequency: float = 0.05

var noise: FastNoiseLite
var chunks: Dictionary = {}
var camera: Camera2D
var fps_label: Label

func _ready():
	if not tileset:
		tileset = load("res://resources/tilesets/main_tileset.tres")
	
	# Setup UI and Camera
	fps_label = get_node("%FPSLabel")
	camera = get_viewport().get_camera_2d()
	if camera and camera.has_signal("view_changed"):
		camera.view_changed.connect(_on_view_changed)
	
	# Setup Noise
	noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	# Initial Gen
	update_chunks()

func _process(_delta):
	# Update FPS
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
	# Regularly check for chunks around camera
	update_chunks()

func _on_view_changed(_pos, _zoom):
	update_chunks()

func update_chunks():
	if not camera: return
	
	var cam_local = to_local(camera.global_position)
	var tile_pos = Vector2i(cam_local.x / 256, cam_local.y / 128)
	var chunk_pos = Vector2i(floor(tile_pos.x / float(CHUNK_SIZE)), floor(tile_pos.y / float(CHUNK_SIZE)))
	
	# Calculate dynamic render distance based on zoom
	var render_dist = floor(render_distance_base / max(camera.zoom.x, 0.1))
	render_dist = clamp(render_dist, 2, 10) # Safety limits
	
	# Load missing chunks
	for x in range(chunk_pos.x - render_dist, chunk_pos.x + render_dist + 1):
		for y in range(chunk_pos.y - render_dist, chunk_pos.y + render_dist + 1):
			var cpos = Vector2i(x, y)
			if not chunks.has(cpos):
				create_chunk(cpos)
	
	# Unload far chunks
	var to_remove = []
	for c in chunks.keys():
		if abs(c.x - chunk_pos.x) > render_dist + 1 or abs(c.y - chunk_pos.y) > render_dist + 1:
			to_remove.append(c)
	
	for c in to_remove:
		chunks[c].queue_free()
		chunks.erase(c)

func create_chunk(cpos: Vector2i):
	var ChunkScript = load("res://scripts/chunk.gd")
	var chunk_node = Node2D.new()
	chunk_node.set_script(ChunkScript)
	
	add_child(chunk_node)
	chunks[cpos] = chunk_node
	
	chunk_node.setup(cpos, tileset)
	
	update_chunk_tiles(cpos)

func update_chunk_tiles(cpos: Vector2i):
	var chunk = chunks[cpos]
	var start_x = cpos.x * CHUNK_SIZE
	var start_y = cpos.y * CHUNK_SIZE
	
	for lx in range(CHUNK_SIZE):
		for ly in range(CHUNK_SIZE):
			var gx = start_x + lx
			var gy = start_y + ly
			
			var n_val = noise.get_noise_2d(gx, gy)
			var height = floor((n_val + 1.0) / 2.0 * MAX_HEIGHT)
			
			chunk.set_tile_height(gx, gy, height)
