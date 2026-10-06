class_name PlayerInput
extends Node
## Samples the player's devices once per tick for SimDriver (ARCHITECTURE §7):
## - move: the move actions as a screen vector (y up);
## - aim: with a gamepad, the right stick (screen-relative); otherwise, the mouse ray on the ground plane.
## The device tracker switches between them on the last device used.

enum Device { MOUSE_KEYBOARD, GAMEPAD }

const STICK_AIM_MIN := 0.3
const STICK_AIM_DIST_M := 4.0

var device := Device.MOUSE_KEYBOARD
var _rig: IsoRig
var _reader: WorldReader
var _mouse := Vector2.ZERO
var _last_aim := Vector2.RIGHT
var _last_dist := 4.0


func _init(rig: IsoRig, reader: WorldReader) -> void:
	_rig = rig
	_reader = reader


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		device = Device.MOUSE_KEYBOARD
		_mouse = event.position
	elif event is InputEventKey:
		device = Device.MOUSE_KEYBOARD
	elif (
		event is InputEventJoypadButton
		or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3)
	):
		device = Device.GAMEPAD


## [move_screen: Vector2, aim_world: Vector2, aim_dist_m: float], the shape SimDriver.input_source expects.
func sample() -> Array:
	var move := Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up")
	if device == Device.GAMEPAD:
		var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_down", &"aim_up")
		if stick.length() >= STICK_AIM_MIN:
			_last_aim = InputLatch.screen_to_sim(stick)
			_last_dist = STICK_AIM_DIST_M * minf(stick.length(), 1.0)
	else:
		var hit: Variant = mouse_world(_mouse)
		if hit != null:
			var d: Vector2 = hit - _reader.player_pos()
			if d.length() > 0.01:
				_last_aim = d
				_last_dist = d.length()
	return [move, _last_aim, _last_dist]


## Where a screen position's camera ray meets the plane at core height (sim coordinates), or null.
func mouse_world(screen_pos: Vector2) -> Variant:
	var cam := _rig.camera
	var origin := cam.project_ray_origin(screen_pos)
	var normal := cam.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, SimPlane.CORE_HEIGHT).intersects_ray(origin, normal)
	return SimPlane.to_sim(hit) if hit != null else null
