extends SubViewport
class_name ShadowProxyGenerator

@onready var _windmill_model = $ShadowScene/WindmillModel
@onready var _sun_light = $ShadowScene/DirectionalLight3D
@onready var _camera = $ShadowScene/Camera3D

var model_scale: float = 30.0
var camera_size: float = 146.0
var model_offset: Vector3 = Vector3.ZERO
var model_rotation_y: float = 45.0
var sun_altitude_deg: float = -45.0
var sun_azimuth_deg: float = -135.0
var shadow_opacity: float = 0.7
var shadow_blur: float = 0.5
var shadow_normal_bias: float = 0.5

@onready var _catcher = $ShadowScene/ShadowCatcher

func _ready():
	transparent_bg = true
	if _windmill_model:
		_set_shadows_only(_windmill_model)

func _set_shadows_only(node: Node):
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY # CHỈ ĐỔ BÓNG, KHÔNG HIỆN THÂN
	for child in node.get_children():
		_set_shadows_only(child)

func set_model_visible(is_visible: bool):
	if _windmill_model:
		# Chỉ đặt cast_shadow nếu nút gốc bản thân nó là một GeometryInstance3D
		if _windmill_model is GeometryInstance3D:
			if is_visible:
				_windmill_model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			else:
				_windmill_model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				
		# Duyệt qua tất cả các mesh con bên trong model (GLB thường có nhiều mesh)
		for child in _windmill_model.find_children("", "GeometryInstance3D", true):
			if is_visible:
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			else:
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func update_proxy():
	if not _sun_light or not _camera or not _windmill_model:
		return
		
	# CẬP NHẬT THEO BIẾN ĐIỀU CHỈNH
	_windmill_model.scale = Vector3(model_scale, model_scale, model_scale)
	_windmill_model.position = model_offset
	_windmill_model.rotation.y = deg_to_rad(model_rotation_y)
	_camera.size = camera_size
	
	# ĐỒNG BỘ GÓC NHÌN ISOMETRIC CỐ ĐỊNH (CHUẨN 2:1 TILE)
	_camera.position = Vector3(500, 500, 500)
	_camera.rotation_degrees = Vector3(-35.264, 45, 0)
	
	# ĐỒNG BỘ ÁNH SÁNG THEO HỆ THỐNG
	# Thêm 180 độ để đồng bộ hướng sáng mặt và hướng đổ bóng (Lệch pha Godot 4)
	_sun_light.rotation_degrees.x = sun_altitude_deg
	_sun_light.rotation_degrees.y = sun_azimuth_deg + 180.0
	_sun_light.shadow_blur = shadow_blur
	_sun_light.shadow_normal_bias = shadow_normal_bias
	
	# CẬP NHẬT ĐỘ MỜ BÓNG (CHỈ ẢNH HƯỞNG ĐẾN MẶT PHẲNG HỨNG BÓNG)
	if _catcher and _catcher.material_override:
		_catcher.material_override.set_shader_parameter("shadow_opacity", shadow_opacity)
