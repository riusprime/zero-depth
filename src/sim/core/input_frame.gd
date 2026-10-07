class_name InputFrame
extends RefCounted
## One tick of player input, already quantized (SIM_CONTRACTS §3). Bits are appended, never renumbered.

const PRIMARY := 1
const UTILITY := 2
const DASH := 4
const INTERACT := 8
## Shooting (held), separate from the melee PRIMARY (owner, 2026-10-07).
const SHOOT := 16

## World-plane move, -127..127 per axis, deadzone applied.
var move := Vector2i.ZERO
## Aim angle in 1/4096 turns.
var aim_angle := 0
## Distance from the player to the aim point in centimetres.
var aim_dist_cm := 0
## Buttons held this tick.
var held := 0
## Buttons pressed since the previous tick (each delivered once).
var pressed := 0


static func make(
	p_move: Vector2i, p_aim: int, p_dist: int, p_held: int, p_pressed: int
) -> InputFrame:
	var f := InputFrame.new()
	f.move = p_move
	f.aim_angle = p_aim & 4095
	f.aim_dist_cm = clampi(p_dist, 0, SimTick.AIM_DIST_MAX_CM)
	f.held = p_held
	f.pressed = p_pressed
	return f


func equals(o: InputFrame) -> bool:
	return (
		move == o.move
		and aim_angle == o.aim_angle
		and aim_dist_cm == o.aim_dist_cm
		and held == o.held
		and pressed == o.pressed
	)


func to_array() -> Array[int]:
	return [move.x, move.y, aim_angle, aim_dist_cm, held, pressed]
