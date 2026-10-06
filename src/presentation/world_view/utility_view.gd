class_name UtilityView
extends Node3D
## Guard: a cyan shield arc in front of the cube while it's up, as wide as the arc Damage checks. Blink: a brief
## streak from where the cube left to where it landed.

const BLINK_FRAMES := 12

var _shield := MeshInstance3D.new()
var _streak := MeshInstance3D.new()
var _streak_mat := StandardMaterial3D.new()
var _last_blink := -1
var _streak_left := 0


func _ready() -> void:
	var cyan := ThemePalette.color(&"player_core")
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(cyan, 0.7)
	_shield.material_override = m
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield.visible = false
	add_child(_shield)
	_streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak_mat.albedo_color = Color(cyan, 0.6)
	var box := BoxMesh.new()
	box.size = Vector3(1, 0.05, 0.25)
	_streak.mesh = box
	_streak.material_override = _streak_mat
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streak.visible = false
	add_child(_streak)


func sync(reader: WorldReader) -> void:
	if _shield.mesh == null and reader.has_guard():
		var r := reader.player_radius()
		_shield.mesh = KitView.fan_mesh(reader.guard_half_arc(), r + 0.15, 0.2)
	var was := _shield.visible
	_shield.visible = reader.guarding()
	if _shield.visible:
		_shield.position = SimPlane.to_3d(reader.player_pos(), 0.3)
		_shield.rotation = Vector3(0, SimPlane.yaw_of(reader.aim_angle()), 0)
		_shield.scale = Vector3(1, 1, 1)
		if not was:
			_shield.reset_physics_interpolation()
	if reader.blink_tick() != _last_blink and reader.blink_tick() >= 0:
		_last_blink = reader.blink_tick()
		var a := reader.blink_from()
		var b := reader.player_pos()
		var mid := (a + b) * 0.5
		_streak.position = SimPlane.to_3d(mid, 0.3)
		_streak.rotation = Vector3(0, SimPlane.yaw_of(Kin.angle_of(b - a)), 0)
		_streak.scale = Vector3(maxf((b - a).length(), 0.1), 1, 1)
		_streak.reset_physics_interpolation()
		_streak_left = BLINK_FRAMES
	_streak.visible = _streak_left > 0


func _process(_delta: float) -> void:
	if _streak_left > 0:
		_streak_left -= 1
		_streak_mat.albedo_color.a = 0.6 * _streak_left / BLINK_FRAMES
