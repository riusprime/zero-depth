class_name IsoRig
extends Node3D
## Fixed orthographic iso camera (PRESENTATION_CONTRACTS §1): yaw +45°, a pitch picked at the v0.0.1 gate,
## following a target with a dead zone. It moves in _process, so physics interpolation is off for it.

const YAW_DEG := 45.0
## v0.8.0 GF3 (owner O22): the hit-stop's tiny camera kick: an offset (screen metres: h, v) along the swing, easing
## back over KICK_SECONDS. Off with shake off or reduced motion, like the shake.
const KICK_SECONDS := 0.09

@export var pitch_deg := 35.26
## Vertical extent of the view in metres (ortho size).
@export var view_size := 17.0
@export var dead_zone_m := 1.5
@export var smoothing := 8.0

var camera: Camera3D
var target := Vector3.ZERO
## Screen shake (PRESENTATION §1, §6): off means none at all.
var shake_enabled := true
var _shake := 0.0
var _shake_seed := 0
## v0.8.0 GF3: the kick (see KICK_SECONDS).
var _kick := Vector2.ZERO
var _kick_t := 0.0
var _pitch: Node3D


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	rotation_degrees = Vector3(0, YAW_DEG, 0)
	_pitch = Node3D.new()
	add_child(_pitch)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = view_size
	camera.near = 0.1
	# The directional shadow of an orthographic camera covers near..far, so a long far plane spreads the shadow
	# map thin and the edges stair-step (v0.2.0 L2). At the default size and pitch the ground is 48-72 m away.
	camera.far = 100.0
	camera.position = Vector3(0, 0, 60)
	_pitch.add_child(camera)
	set_pitch(pitch_deg)


func set_pitch(deg: float) -> void:
	pitch_deg = deg
	_pitch.rotation_degrees = Vector3(-deg, 0, 0)


func snap_to(p: Vector3) -> void:
	target = p
	position = p


func _process(delta: float) -> void:
	var offset := target - position
	offset.y = 0.0
	var dist := offset.length()
	if dist > dead_zone_m:
		var want := position + offset * ((dist - dead_zone_m) / dist)
		position = position.lerp(want, clampf(delta * smoothing, 0.0, 1.0))
	camera.size = view_size
	_shake = maxf(0.0, _shake - delta * 2.5)
	_shake_seed += 1
	var off := kick_offset()
	_kick_t = maxf(0.0, _kick_t - delta)
	if _shake > 0.0:
		var a := float(_shake_seed) * 2.399
		camera.h_offset = cos(a) * _shake * 0.35 + off.x
		camera.v_offset = sin(a * 1.7) * _shake * 0.35 + off.y
	else:
		camera.h_offset = off.x
		camera.v_offset = off.y


## v0.8.0 GF3: a tiny kick of the view along `dir` (a direction in 3D, flat), `metres` at its start. Does nothing when
## shake is off or reduced motion is on. A kick replaces the last one (never stacked).
func kick(dir: Vector3, metres: float) -> void:
	if not shake_enabled or ViewPrefs.reduced_motion:
		return
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 1e-6:
		return
	d = d.normalized()
	var yaw := deg_to_rad(YAW_DEG)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var back := Vector3(sin(yaw), 0.0, cos(yaw))  # toward the camera on the ground
	_kick = Vector2(d.dot(right), -d.dot(back) * sin(deg_to_rad(pitch_deg))) * metres
	_kick_t = KICK_SECONDS


## v0.8.0 GF3: the kick's offset now (screen metres), easing out to zero.
func kick_offset() -> Vector2:
	if _kick_t <= 0.0:
		return Vector2.ZERO
	var u := _kick_t / KICK_SECONDS
	return _kick * u * u


## Adds shake (0..1). Does nothing when shake is off or reduced motion is on (ViewPrefs, v0.3.0 O).
func shake(amount: float) -> void:
	if shake_enabled and not ViewPrefs.reduced_motion:
		_shake = minf(1.0, _shake + amount)


func shake_level() -> float:
	return _shake


## Horizontal direction on the sim plane from a point toward the camera.
## The yaw is fixed, so this is exact and needs no scene tree.
func toward_camera_on_plane() -> Vector2:
	var yaw := deg_to_rad(YAW_DEG)
	return SimPlane.to_sim(Vector3(sin(yaw), 0, cos(yaw))).normalized()
