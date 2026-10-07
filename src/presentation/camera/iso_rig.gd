class_name IsoRig
extends Node3D
## Fixed orthographic iso camera (PRESENTATION_CONTRACTS §1): yaw +45°, a pitch picked at the v0.0.1 gate,
## following a target with a dead zone. It moves in _process, so physics interpolation is off for it.

const YAW_DEG := 45.0

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
	camera.far = 200.0
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
	if _shake > 0.0:
		var a := float(_shake_seed) * 2.399
		camera.h_offset = cos(a) * _shake * 0.35
		camera.v_offset = sin(a * 1.7) * _shake * 0.35
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## Adds shake (0..1). Does nothing when shake is off.
func shake(amount: float) -> void:
	if shake_enabled:
		_shake = minf(1.0, _shake + amount)


func shake_level() -> float:
	return _shake


## Horizontal direction on the sim plane from a point toward the camera.
## The yaw is fixed, so this is exact and needs no scene tree.
func toward_camera_on_plane() -> Vector2:
	var yaw := deg_to_rad(YAW_DEG)
	return SimPlane.to_sim(Vector3(sin(yaw), 0, cos(yaw))).normalized()
