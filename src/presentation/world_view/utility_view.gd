class_name UtilityView
extends Node3D
## Guard: a cyan shield arc in front of the cube while it's up, as wide as the arc Damage checks. Blink (a
## teleport, PLAN v0.2.0 L12): a blue flash of light (BlinkFlash: a column, sparks and a light) where the wanderer
## vanished and where it appeared. Dash: a white motion trail (DashTrail) on every dash.

var dash_trail := DashTrail.new()
var vanish := BlinkFlash.new()
var appear := BlinkFlash.new()
var _shield := MeshInstance3D.new()
var _last_blink := -1


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
	add_child(dash_trail)
	add_child(vanish)
	add_child(appear)


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
		vanish.play(SimPlane.to_3d(reader.blink_from()))
		appear.play(SimPlane.to_3d(reader.player_pos()))
	dash_trail.sync(reader)
