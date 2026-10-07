class_name InputLatch
extends RefCounted
## Turns device input between ticks into one InputFrame per tick (SIM_CONTRACTS §3).
## Presses are latched, so a press and release inside one frame still reaches the sim, exactly once.

## The camera rig's fixed yaw: screen-relative input rotates +45° into the sim plane.
const C45 := 0.70710678118654752
## A stick reaches full speed at this much of its travel past the dead zone (keys are always full speed).
const FULL_TILT := 0.85

var _pressed := 0
var _held := 0


## Records a press edge (from an input event); it is delivered on the next frame only.
func note_pressed(bit: int) -> void:
	_pressed |= bit
	_held |= bit


func note_released(bit: int) -> void:
	_held &= ~bit


## Builds this tick's frame and clears the latched presses.
## move_screen: x right, y up, each -1..1. aim_world: the aim direction already on the sim plane.
func close_frame(move_screen: Vector2, aim_world: Vector2, aim_dist_m: float) -> InputFrame:
	var f := InputFrame.make(
		quantize_move(screen_to_sim(move_screen)),
		Kin.angle_of(aim_world) if aim_world != Vector2.ZERO else 0,
		int(round(aim_dist_m * 100.0)),
		_held,
		_pressed
	)
	_pressed = 0
	return f


## Rotates a screen vector (y up) by +45° into the sim plane. W (0, 1) -> (-0.707, 0.707): sim angle 1536.
static func screen_to_sim(v: Vector2) -> Vector2:
	return Vector2((v.x - v.y) * C45, (v.x + v.y) * C45)


## Scales to -127..127 per axis. The dead zone is already applied by the input actions (Input.get_vector
## rescales past it); a second one here made ~36% of a stick's travel dead (owner fight check, 2026-10-07).
## Lengths at or above FULL_TILT move at full speed, like keys.
static func quantize_move(v: Vector2) -> Vector2i:
	var len := v.length()
	if len < 0.001:
		return Vector2i.ZERO
	v = v / len * minf(1.0, len / FULL_TILT)
	return Vector2i(
		clampi(int(round(v.x * SimTick.MOVE_MAX)), -SimTick.MOVE_MAX, SimTick.MOVE_MAX),
		clampi(int(round(v.y * SimTick.MOVE_MAX)), -SimTick.MOVE_MAX, SimTick.MOVE_MAX)
	)
