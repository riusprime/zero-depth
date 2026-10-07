class_name UtilityView
extends Node3D
## Guard: a cyan shield arc in front of the cube while it's up, as wide as the arc Damage checks. Blink (a
## teleport): a ring bursts outward where the cube vanished and closes in where it appeared.

const BLINK_FRAMES := 12

var _shield := MeshInstance3D.new()
var _vanish := MeshInstance3D.new()
var _appear := MeshInstance3D.new()
var _vanish_mat := StandardMaterial3D.new()
var _appear_mat := StandardMaterial3D.new()
var _last_blink := -1
var _burst_left := 0


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
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.55
	for pair: Array in [[_vanish, _vanish_mat], [_appear, _appear_mat]]:
		var n: MeshInstance3D = pair[0]
		var mat: StandardMaterial3D = pair[1]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(cyan.lightened(0.4), 0.0)
		n.mesh = torus
		n.material_override = mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		n.visible = false
		add_child(n)


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
		_vanish.position = SimPlane.to_3d(reader.blink_from(), 0.3)
		_appear.position = SimPlane.to_3d(reader.player_pos(), 0.3)
		_burst_left = BLINK_FRAMES
	_vanish.visible = _burst_left > 0
	_appear.visible = _burst_left > 0


func _process(_delta: float) -> void:
	if _burst_left <= 0:
		return
	_burst_left -= 1
	var p := 1.0 - float(_burst_left) / BLINK_FRAMES
	_vanish.scale = Vector3.ONE * (0.6 + 1.4 * p) * Vector3(1, 0.15, 1)
	_vanish_mat.albedo_color.a = 0.8 * (1.0 - p)
	_appear.scale = Vector3.ONE * (1.8 - 1.2 * p) * Vector3(1, 0.15, 1)
	_appear_mat.albedo_color.a = 0.8 * (1.0 - p)
	if _burst_left == 0:
		_vanish.visible = false
		_appear.visible = false
