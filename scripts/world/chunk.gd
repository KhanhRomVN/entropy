extends Node2D

const CHUNK_SIZE = 16
# LƯU Ý: MAX_HEIGHT hiện tại chỉ dùng 1 lớp cho Terrain và 1 lớp cho Props để tối ưu
const MAX_HEIGHT = 2 

var chunk_pos: Vector2i
var tileset: TileSet
var height_layers: Array[TileMapLayer] = []
var prop_layer: TileMapLayer # Lớp chứa cây cối, đá, v.v.
var fluid_layer: TileMapLayer # Lớp nước/chất lỏng với shader động

func setup(_pos: Vector2i, _tileset: TileSet):
	chunk_pos = _pos
	tileset = _tileset
	name = "Chunk_%d_%d" % [chunk_pos.x, chunk_pos.y]
	
	# Layer 0: Ground (Đất & Nước) - TẤT CẢ TRONG MỘT LỚP ĐỂ Y-SORT ĐÚNG
	var terrain = TileMapLayer.new()
	terrain.tile_set = tileset
	terrain.y_sort_enabled = true
	terrain.z_index = -1
	
	# Temporarily disabled shader as per user request to test visual accuracy
	# var mat = ShaderMaterial.new()
	# mat.shader = load("res://assets/tiles/fluids/water_salt_block/water_salt_block.gdshader")
	# terrain.material = mat
	
	add_child(terrain)
	height_layers.append(terrain)
	fluid_layer = terrain # Map fluid_layer to the same node for compatibility
	
	# Layer 1: Props (Cây cối)
	prop_layer = TileMapLayer.new()
	prop_layer.tile_set = tileset
	prop_layer.y_sort_enabled = true
	add_child(prop_layer)
	height_layers.append(prop_layer)


func set_tile_height(local_x: int, local_y: int, height: int):
	# Chỉ vẽ 1 lần duy nhất vào layer terrain
	if height >= 0 and height_layers.size() > 0:
		height_layers[0].set_cell(Vector2i(local_x, local_y), 0, Vector2i(0, 0))
