class_name HitStop
extends RefCounted
## v0.8.0 GF3 (owner O22: "for the blade and flinch we add a 2 frame or so freeze to make the hit feel better"): on a
## Blade hit the hero's swing (its model's pose, the laser blade and its trail) and each struck enemy (its model's
## pose, held at its flinch's peak, and its white flash) hold still for HOLD_SECONDS of frame time (2 frames at 60 fps),
## with a tiny camera kick along the swing (IsoRig.kick; none with shake off or reduced motion).
## - In the view only (EI-03, EI-07): it holds the views' own frame-time animation; the sim keeps its 60 Hz clock, the
##   input stays live, and nothing in src/sim or the input reads it. Each held view drops the held share of its frame
##   time and runs on from where it stopped, so nothing pops when it ends.
## - Shared: every hit of one swing (the same swing start tick, or the same tick) joins the freeze running (a struck
##   enemy is held for what is left of it); a freeze is never stacked or lengthened.
## - Rate-limited: a new freeze starts only MIN_GAP_TICKS of sim time after the last one began, so fast swings
##   (Flurry) don't stutter.
## - Off with the Options "Hit-stop" off or reduced motion on (ViewPrefs.hit_stop_on).
## The sim's own hit-stop (World.freeze_ticks, from the step's hitstop_ticks) is unchanged and separate.
## Starting values.

const HOLD_SECONDS := 2.0 / 60.0
const MIN_GAP_TICKS := 9
const KICK_M := 0.06
const FINISHER_KICK_M := 0.1

## Counts (tests and the probe): freezes started, hits that joined one, hits a freeze was refused for (too soon).
var freezes := 0
var joined := 0
var limited := 0
## The views it holds: set by HitFeel's owner (WorldViewRoot); a null one is skipped.
var actors: ActorViews
var rig: IsoRig
var kit: KitView
## Frame seconds left of the freeze running (0: none).
var _left := 0.0
var _start_tick := -1000000
var _swing_key := -1
var _held: Array[int] = []


## The freeze now (tests): frame seconds left, and whether actor `id` is held by it.
func left() -> float:
	return _left


func holding() -> bool:
	return _left > 0.0


func holds(id: int) -> bool:
	return holding() and _held.has(id)


## A Blade hit (a DAMAGE event of the player's melee on enemy `target_id`) at sim tick `tick`, from the swing that
## began at `swing_key` (its start tick; -1 when no swing runs), `dir` the swing's direction in 3D (the camera kick).
## Starts a freeze, joins the running one, or is refused (too soon after the last). True when the views are held.
func on_blade_hit(
	target_id: int, tick: int, swing_key: int, dir: Vector3, finisher: bool, hero_id: int
) -> bool:
	if not ViewPrefs.hit_stop_on():
		return false
	var same := (swing_key >= 0 and swing_key == _swing_key) or tick == _start_tick
	if same:
		if not holding():
			return false  # this swing's freeze is over: shared, never a second one
		joined += 1
		_hold_target(target_id, _left)
		return true
	if tick - _start_tick < MIN_GAP_TICKS:
		limited += 1
		return false
	freezes += 1
	_start_tick = tick
	_swing_key = swing_key
	_left = HOLD_SECONDS
	_held.clear()
	_hold_target(target_id, HOLD_SECONDS)
	if actors != null:
		var hero := actors.actor_node(hero_id)
		if hero != null and hero.has_meta(&"avatar"):
			(hero.get_meta(&"avatar") as AvatarBase).hold(HOLD_SECONDS)
	if kit != null:
		kit.hold(HOLD_SECONDS)
	if rig != null:
		rig.kick(dir, FINISHER_KICK_M if finisher else KICK_M)
	return true


## Counts the freeze down by `delta` seconds of frame time (HitFeel's _process).
func advance(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(0.0, _left - maxf(delta, 0.0))
	if _left <= 0.0:
		_held.clear()


func _hold_target(id: int, seconds: float) -> void:
	if seconds <= 0.0 or _held.has(id):
		return
	_held.append(id)
	if actors == null:
		return
	actors.hold_flash(id, seconds)
	var node := actors.actor_node(id)
	if node != null and node.has_meta(&"enemy_avatar"):
		var av: Object = node.get_meta(&"enemy_avatar")
		if av.has_method(&"hold"):
			av.call(&"hold", seconds)
