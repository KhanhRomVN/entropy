extends SceneTree

func _init():
	print("--- STARTING CHECK ---")
	var scene = load("res://assets/environment/props/autumn_yellow_tree/autumn_yellow_tree.blend")
	if scene == null:
		print("Failed to load scene")
		quit()
		return
		
	var inst = scene.instantiate()
	print_tree_transforms(inst, "")
	print("--- ENDING CHECK ---")
	quit()
	
func print_tree_transforms(node: Node, indent: String):
	var text = indent + node.name + " (" + node.get_class() + ")"
	if node is Node3D:
		text += " Scale: " + str(node.scale)
		if node is MeshInstance3D and node.mesh:
			var aabb = node.mesh.get_aabb()
			text += ", AABB: " + str(aabb)
	print(text)
	for child in node.get_children():
		print_tree_transforms(child, indent + "  ")
