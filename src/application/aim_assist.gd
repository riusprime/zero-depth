class_name AimAssist
extends RefCounted
## Aim assist: the tick's aim bends a little toward the nearest enemy inside a narrow cone around it. It runs where
## the tick's aim is built, before the aim is quantized into the InputFrame, so the recorded frame holds the final aim
## and a replay needs none of this (EI-04); the sim never knows it exists.
## A pull, never a snap: at strength 1 the aim would point straight at the target, at 0.1 it turns a tenth of the
## way. Only the direction turns: the aim's length (where a ground-targeted ability lands) is the player's own.
## The numbers are content (data/tuning/aim_assist.tres), read every tick, so a dev panel edit lands as play resumes.

## The profile setting ("on" / "off") that turns it off for a player who doesn't want it.
const SETTING := "aim_assist"
const DEF_ID := &"aim_assist"

var _def: AimAssistDefinition
var _profile: ProfileStore


## The assist with the content's numbers (repo null or without the file: the definition's own defaults) and the
## profile's switch (null: always on).
static func make(repo: ContentRepository, profile: ProfileStore) -> AimAssist:
	var a := AimAssist.new()
	var def: Variant = repo.get_def(&"tuning", DEF_ID) if repo != null else null
	a._def = def if def is AimAssistDefinition else AimAssistDefinition.new()
	a._profile = profile
	return a


func enabled() -> bool:
	return _profile == null or GameSettings.get_value(_profile, SETTING) == "on"


## `aim` (a direction on the sim plane, any length) bent toward the target `reader`'s world offers, or `aim`.
func assisted(aim: Vector2, reader: WorldReader) -> Vector2:
	if not enabled() or _def.strength_percent <= 0:
		return aim
	return pull(
		aim,
		targets(reader, _def.range_m),
		_def.strength_percent / 100.0,
		_def.cone_degrees,
		_def.range_m
	)


## Actor i is something the aim may bend to: a living enemy-team actor that can be hit now (the homing shots' rule,
## Seekers.target and Wisps.target), bosses and elites included; not a horde critter (a surge of them would tug the
## aim about) nor a Wire Weaver's post (a prop of its cable, not a foe).
static func is_target(reader: WorldReader, i: int) -> bool:
	if reader.actor_team(i) != WorldReader.TEAM_ENEMY or reader.actor_dead(i):
		return false
	var kind := reader.actor_kind(i)
	if kind == WorldReader.KIND_WIRE_POST or WorldReader.is_critter_kind(kind):
		return false
	return not reader.actor_invulnerable(i)


## The targets within `range_m` of the hero (to their edge), as offsets from the hero.
static func targets(reader: WorldReader, range_m: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var hero := reader.player_pos()
	for i in range(1, reader.actor_count()):
		if not is_target(reader, i):
			continue
		var d := reader.actor_pos(i) - hero
		if d.length() <= range_m + reader.actor_radius(i):
			out.append(d)
	return out


## The pull itself: `aim` turned by `strength` (0..1) of its angle to the offset nearest it by angle (a tie: the
## nearer one) among `offsets` (from the hero) inside `cone_deg` either side of it and within `range_m`. None:
## `aim` as it is. The length is kept.
static func pull(
	aim: Vector2,
	offsets: PackedVector2Array,
	strength: float,
	cone_deg: float,
	range_m: float = INF
) -> Vector2:
	if aim == Vector2.ZERO or strength <= 0.0:
		return aim
	var cone := deg_to_rad(cone_deg)
	var best_turn := 0.0
	var best_abs := INF
	var best_d := INF
	for t in offsets:
		var d := t.length()
		if d == 0.0 or d > range_m:
			continue
		var turn := aim.angle_to(t)
		var a := absf(turn)
		if a > cone:
			continue
		if a < best_abs or (a == best_abs and d < best_d):
			best_turn = turn
			best_abs = a
			best_d = d
	if best_abs == INF:
		return aim
	return aim.rotated(best_turn * minf(strength, 1.0))
