extends SceneTree

func _init():
	var file = FileAccess.open("res://grass_log.txt", FileAccess.WRITE)
	file.store_line("--- MEASURING GRASS BLOCK ---")
	
	var scene = load("res://assets/environment/tiles/grass_block/grass_block.blend")
	if scene == null:
		file.store_line("Failed to load grass_block")
		quit()
		return
		
	var inst = scene.instantiate()
	var mesh_node = find_mesh(inst)
	if mesh_node:
		var aabb = mesh_node.mesh.get_aabb()
		var global_scale = mesh_node.global_transform.basis.get_scale()
		
		file.store_line("AABB size: " + str(aabb.size))
		file.store_line("Global scale: " + str(global_scale))
		
		# Current root_scale is 2.0 (from previous script). 
		# If aabb.size.x is what it is under root_scale=2.0, the true size is aabb.size.x / 2.0
		# The required scale to make true size = 1.0 is 1.0 / true_size
		
		var true_size_x = aabb.size.x / 2.0
		var required_scale = 1.0 / true_size_x
		file.store_line("REQUIRED ROOT_SCALE TO BE 1.0 UNIT WIDE: " + str(required_scale))
		
		var required_scale_for_2 = 2.0 / true_size_x
		file.store_line("REQUIRED ROOT_SCALE TO BE 2.0 UNIT WIDE: " + str(required_scale_for_2))
	else:
		file.store_line("No mesh found!")
	
	file.close()
	quit()

func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = find_mesh(child)
		if found: return found
	return null
