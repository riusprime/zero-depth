class_name KitView
extends Node3D
## The player's primary as the view shows it (PLAN v0.1.0 Step 2): the swing fan, drawn from the same numbers
## PlayerKit hits with (WorldReader.swing_shape), and a charge ring that fills and brightens at full charge.

const FAN_STEPS := 16

var _fan := MeshInstance3D.new()
var _fan_mat := StandardMaterial3D.new()
var _ring := MeshInstance3D.new()
var _ring_mat := StandardMaterial3D.new()
var _shape_key := []


func _ready() -> void:
	var cyan := ThemePalette.color(&"player_core")
	for m: StandardMaterial3D in [_fan_mat, _ring_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(cyan, 0.55)
	_fan.material_override = _fan_mat
	_fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fan.visible = false
	add_child(_fan)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.6
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


func sync(reader: WorldReader) -> void:
	var at := SimPlane.to_3d(reader.player_pos(), 0.04)
	var shape := reader.swing_shape()
	if shape != _shape_key:
		_shape_key = shape
		_fan.mesh = fan_mesh(shape[0], shape[2], shape[1])
	var t := reader.swing_tick()
	var was_visible := _fan.visible
	_fan.visible = t > 0 and not reader.player_dead()
	if _fan.visible:
		_fan.position = at
		_fan.rotation = Vector3(0, SimPlane.yaw_of(reader.swing_angle()), 0)
		var left := 1.0 - float(t) / float(reader.swing_ticks() + 1)
		_fan_mat.albedo_color.a = 0.15 + 0.5 * left
		if not was_visible:
			_fan.reset_physics_interpolation()
	var c := reader.charge_permille()
	var ring_was := _ring.visible
	_ring.visible = reader.charging() and not reader.player_dead()
	if _ring.visible:
		_ring.position = at
		var s := 0.6 + 0.6 * c / 1000.0
		_ring.scale = Vector3(s, 0.08, s)
		_ring_mat.albedo_color.a = 0.35 + 0.5 * c / 1000.0
		_ring_mat.emission_enabled = c >= 1000
		_ring_mat.emission = ThemePalette.color(&"player_core")
		if not ring_was:
			_ring.reset_physics_interpolation()


## A flat fan facing +X (sim angle 0): from the cube's edge out to edge + reach, across +-half_arc.
static func fan_mesh(half_arc: int, own_r: float, reach: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var half := TAU * half_arc / 4096.0
	for k in FAN_STEPS:
		var a0 := -half + 2.0 * half * k / FAN_STEPS
		var a1 := -half + 2.0 * half * (k + 1) / FAN_STEPS
		var i0 := Vector3(cos(a0), 0, -sin(a0)) * own_r
		var i1 := Vector3(cos(a1), 0, -sin(a1)) * own_r
		var o0 := Vector3(cos(a0), 0, -sin(a0)) * (own_r + reach)
		var o1 := Vector3(cos(a1), 0, -sin(a1)) * (own_r + reach)
		verts.append_array([i0, o0, o1, i0, o1, i1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
