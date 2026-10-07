class_name KitView
extends Node3D
## The player's melee as the view shows it (PLAN v0.1.0 Steps 2, 7e): a faint fan on the ground, drawn from the
## same numbers PlayerKit hits with (WorldReader.swing_shape), and a bright slash ribbon that sweeps across that
## arc at body height in the swing's first ticks, alternating direction each combo hit, like a blade's trail
## without drawing a blade (owner, 2026-10-07).

const FAN_STEPS := 16
## The slash: how many ticks the sweep takes, its angular width (radians), and its trail.
const SWEEP_TICKS := 5
const SLASH_WIDTH := 0.55
const TRAIL := [0.0, 0.22, 0.44]
const TRAIL_ALPHA := [0.95, 0.55, 0.25]

var _fan := MeshInstance3D.new()
var _fan_mat := StandardMaterial3D.new()
var _shape_key := []
var _slash: Array[MeshInstance3D] = []
var _slash_mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	var cyan := ThemePalette.color(&"player_core")
	for m: StandardMaterial3D in [_fan_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(cyan, 0.55)
	_fan_mat.albedo_color = Color(cyan, 0.25)
	_fan.material_override = _fan_mat
	for k in TRAIL.size():
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(cyan.lightened(0.8 if k == 0 else 0.45), TRAIL_ALPHA[k])
		var n := MeshInstance3D.new()
		n.material_override = m
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.visible = false
		add_child(n)
		_slash.append(n)
		_slash_mats.append(m)
	_fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fan.visible = false
	add_child(_fan)


func sync(reader: WorldReader) -> void:
	var at := SimPlane.to_3d(reader.player_pos(), 0.04)
	var shape := reader.swing_shape()
	if shape != _shape_key:
		_shape_key = shape
		_fan.mesh = fan_mesh(shape[0], shape[2], shape[1])
		var slash := band_mesh(SLASH_WIDTH, shape[2] + shape[1] * 0.45, shape[2] + shape[1])
		for n in _slash:
			n.mesh = slash
	var t := reader.swing_tick()
	var was_visible := _fan.visible
	_fan.visible = t > 0 and not reader.player_dead()
	if _fan.visible:
		_fan.position = at
		_fan.rotation = Vector3(0, SimPlane.yaw_of(reader.swing_angle()), 0)
		var left := 1.0 - float(t) / float(reader.swing_ticks() + 1)
		_fan_mat.albedo_color.a = 0.08 + 0.2 * left
		if not was_visible:
			_fan.reset_physics_interpolation()
	_sync_slash(reader, at, t)


func _sync_slash(reader: WorldReader, at: Vector3, t: int) -> void:
	var on := t > 0 and not reader.player_dead() and t <= reader.swing_ticks() - 2
	var half: float = TAU * reader.swing_shape()[0] / 4096.0
	# Alternate the sweep direction each combo hit; the finisher sweeps wider and brighter.
	var dir := 1.0 if reader.combo_step() % 2 == 0 else -1.0
	var p := clampf(float(t - 1) / SWEEP_TICKS, 0.0, 1.0)
	p = 1.0 - (1.0 - p) * (1.0 - p)
	var fade := clampf(
		1.0 - float(t - SWEEP_TICKS) / float(reader.swing_ticks() - SWEEP_TICKS), 0.0, 1.0
	)
	var big := 1.15 if reader.combo_step() == 2 else 1.0
	for k in _slash.size():
		var n := _slash[k]
		var was := n.visible
		n.visible = on
		if not on:
			continue
		var lead: float = (-half + 2.0 * half * p) * dir
		var ang: float = lead - TRAIL[k] * dir * (1.0 - 0.6 * p)
		n.position = at + Vector3(0, 0.42, 0)
		n.rotation = Vector3(0, SimPlane.yaw_of(reader.swing_angle()) + ang, 0)
		n.scale = Vector3(big, 1, big)
		_slash_mats[k].albedo_color.a = TRAIL_ALPHA[k] * fade
		if not was:
			n.reset_physics_interpolation()


## A flat curved band facing +X, `width` radians wide, between radii r0 and r1 (the slash ribbon).
static func band_mesh(width: float, r0: float, r1: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var steps := 8
	for k in steps:
		var a0 := -width * 0.5 + width * k / steps
		var a1 := -width * 0.5 + width * (k + 1) / steps
		var i0 := Vector3(cos(a0), 0, -sin(a0)) * r0
		var i1 := Vector3(cos(a1), 0, -sin(a1)) * r0
		var o0 := Vector3(cos(a0), 0, -sin(a0)) * r1
		var o1 := Vector3(cos(a1), 0, -sin(a1)) * r1
		verts.append_array([i0, o0, o1, i0, o1, i1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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
