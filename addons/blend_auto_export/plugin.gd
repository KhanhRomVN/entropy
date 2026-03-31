@tool
extends EditorPlugin

# ======================================================
# SỬA ĐƯỜNG DẪN NÀY cho đúng máy bạn
const BLENDER_PATH = "blender" # Ubuntu config
# ======================================================

const ASSETS_DIR = "res://assets"

const EXPORT_SCRIPT = """
import bpy, sys, os
blend_file = sys.argv[sys.argv.index('--') + 1]
output_glb  = sys.argv[sys.argv.index('--') + 2]
bpy.ops.wm.open_mainfile(filepath=blend_file)
bpy.ops.export_scene.gltf(
    filepath=output_glb,
    export_format='GLB',
    export_apply=True,
    export_yup=True,
)
"""

func _enter_tree():
	# Hook vào sự kiện Play button
	get_editor_interface().get_editor_main_screen()
	EditorInterface.get_editor_main_screen()
	# Dùng signal của EditorInterface
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)
	
	# Hook Play button
	var play_btn = _find_play_button()
	if play_btn:
		play_btn.pressed.connect(_on_play_pressed)
	else:
		push_warning("BlendAutoExport: Không tìm thấy Play button, dùng fallback.")
		# Fallback: export 1 lần khi plugin load
		_export_all_blends()

func _find_play_button() -> Button:
	# Tìm nút Play trong EditorToolbar
	var base = EditorInterface.get_base_control()
	return _find_button_by_tooltip(base, "Play the project.")

func _find_button_by_tooltip(node: Node, tooltip: String) -> Button:
	if node is Button and node.tooltip_text == tooltip:
		return node
	for child in node.get_children():
		var result = _find_button_by_tooltip(child, tooltip)
		if result:
			return result
	return null

func _on_play_pressed():
	print("[BlendAutoExport] Phát hiện Play → Bắt đầu export .blend...")
	_export_all_blends()

func _export_all_blends():
	var abs_assets = ProjectSettings.globalize_path(ASSETS_DIR)
	var blend_files = _find_blend_files(abs_assets)
	
	if blend_files.is_empty():
		print("[BlendAutoExport] Không tìm thấy .blend nào.")
		return
	
	print("[BlendAutoExport] Tìm thấy %d file .blend" % blend_files.size())
	
	# Ghi temp Python script
	var tmp_script_path = ProjectSettings.globalize_path("res://") + "__blend_export_tmp__.py"
	var f = FileAccess.open("res://__blend_export_tmp__.py", FileAccess.WRITE)
	f.store_string(EXPORT_SCRIPT)
	f.close()
	
	var success = 0
	var fail = 0
	
	for blend_path in blend_files:
		var glb_path = blend_path.get_basename() + ".glb"
		
		# Xóa .glb cũ
		if FileAccess.file_exists(glb_path):
			DirAccess.remove_absolute(glb_path)
			print("  [DEL] %s" % glb_path.get_file())
		
		# Gọi Blender CLI
		var output = []
		var exit_code = OS.execute(BLENDER_PATH, [
			"--background",
			"--python", tmp_script_path,
			"--",
			blend_path,
			glb_path,
		], output, true)
		
		if exit_code == 0 and FileAccess.file_exists(glb_path):
			print("  [OK]  %s" % glb_path.get_file())
			success += 1
		else:
			push_error("  [ERR] Thất bại: %s" % blend_path.get_file())
			fail += 1
	
	# Xóa temp script
	DirAccess.remove_absolute(tmp_script_path)
	
	# Rescan filesystem để Godot nhận .glb mới
	EditorInterface.get_resource_filesystem().scan()
	
	print("[BlendAutoExport] Xong! OK: %d | Fail: %d" % [success, fail])

func _find_blend_files(dir_path: String) -> Array:
	var result = []
	var dir = DirAccess.open(dir_path)
	if not dir:
		return result
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		var full = dir_path + "/" + fname
		if dir.current_is_dir() and fname != "." and fname != "..":
			result.append_array(_find_blend_files(full))
		elif fname.ends_with(".blend"):
			result.append(full)
		fname = dir.get_next()
	return result

func _exit_tree():
	pass

func _on_filesystem_changed():
	pass
