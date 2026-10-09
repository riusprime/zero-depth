class_name InputFrame
extends RefCounted
## One tick of player input, already quantized (SIM_CONTRACTS §3). Bits are appended, never renumbered.

const PRIMARY := 1
const UTILITY := 2
const DASH := 4
const INTERACT := 8
## Shooting (held), separate from the melee PRIMARY (owner, 2026-10-07).
const SHOOT := 16
## v0.3.5 K: the Vent button (owner F1) and the Skill button (owner F18).
const VENT := 32
const SKILL := 64
## `pick` values (v0.3.0 E): no pick this tick, or cancel the open altar/chest choice. 1..3 take that card.
const PICK_NONE := 0
const PICK_CANCEL := -1
## v0.5.0 SH, while the shop is open: 1..4 buy that card, the heal, the reroll, or sell entry PICK_SHOP_SELL + n of
## the salvage list (Shop.sell_list); PICK_CANCEL closes the shop.
const PICK_SHOP_HEAL := 20
const PICK_SHOP_REROLL := 21
## v0.5.0 EV: while the shop is open and a curse is held, pay to lift the latest curse (Shop.cleanse).
const PICK_SHOP_CLEANSE := 22
const PICK_SHOP_SELL := 100
## v0.6.0 MX2 (BuildSlots): while a swap choice is open (a modifier offered with the six slots full), replace held
## modifier slot n (PICK_SWAP_BASE + n, n = 0..5), or skip it.
const PICK_SWAP_BASE := 30
const PICK_SWAP_SKIP := 39

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
## The 3-card pick (v0.3.0 E): PICK_NONE, 1..3 (take that card), or PICK_CANCEL. Delivered once, like a press.
var pick := PICK_NONE


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
		and pick == o.pick
	)


func to_array() -> Array[int]:
	return [move.x, move.y, aim_angle, aim_dist_cm, held, pressed, pick]
