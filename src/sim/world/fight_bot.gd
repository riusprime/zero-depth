class_name FightBot
extends RefCounted
## A seeded scripted player that fights (v0.3.0 O), for the readable-cause check and the bench, like ScriptedInput
## but aimed: it walks at the nearest enemy, swings when close, shoots otherwise, strafes, dashes and uses its
## utility now and then. It reads the world only to choose its input; the choices come from its own stream.

## How close (m) it swings instead of shooting.
const SWING_RANGE := 2.4

var _rng: RngStream
var _strafe := 1


func _init(seed_value: int) -> void:
	_rng = RngStream.derive(seed_value, "fight_bot")


## The nearest living enemy's index, or -1.
static func nearest_enemy(w: World) -> int:
	var best := -1
	var best_d := 0.0
	var p := w.player_pos()
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 1 or w.actors.teams[i] != ActorStore.TEAM_ENEMY:
			continue
		var d := Kin.length(w.actors.pos(i) - p)
		if best < 0 or d < best_d:
			best = i
			best_d = d
	return best


## This tick's input for world w.
func frame(w: World) -> InputFrame:
	if w.tick % 90 == 0:
		_strafe = -_strafe
	var target := nearest_enemy(w)
	if target < 0:
		var wander := Vector2i(_rng.range_int(-127, 127), _rng.range_int(-127, 127))
		return InputFrame.make(wander, (w.tick * 9) & 4095, 600, 0, 0)
	var to := w.actors.pos(target) - w.player_pos()
	var dist := Kin.length(to)
	var dir := to / dist if dist > 0.0 else Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x) * _strafe
	var move := dir
	if dist < SWING_RANGE * 0.6:
		move = side
	elif dist < 7.0 and _rng.chance_permille(400):
		move = (dir + side) * 0.7071
	var held := 0
	var pressed := 0
	if dist <= SWING_RANGE:
		if w.tick % 6 == 0:
			pressed |= InputFrame.PRIMARY
	else:
		held |= InputFrame.SHOOT
	if _rng.chance_permille(12):
		pressed |= InputFrame.DASH
	if _rng.chance_permille(25):
		pressed |= InputFrame.UTILITY
		held |= InputFrame.UTILITY
	var mv := Vector2i(int(move.x * 127.0), int(move.y * 127.0))
	return InputFrame.make(mv, Kin.angle_of(to), int(dist * 100.0), held, pressed)
