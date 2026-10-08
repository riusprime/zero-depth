# gdlint: disable=max-returns
class_name RunBot
extends RefCounted
## The "expected build" bot (v0.4.0 TU; SCORECARD §3 `competent` movement, best-score picks): it plays a whole
## floor the way a careful player does, and only through an InputFrame per tick.
## - Explore: walks (its own flow field over the floor's walls) to the nearest target by path: a room it hasn't been
##   in, a free altar, or a chest it can afford; opens each reward and takes the best-scoring card (score_card).
##   Never the boss room or the optional Overrun room while exploring.
## - Farm: while a chest is left that it can't afford yet, it tours the rooms again (fighting on the way) until it
##   can, so a floor lasts as long as buying every reward takes.
## - Then the boss: when nothing is left (or after max_explore_ticks), it walks through the boss door, fights the
##   boss and walks into the portal.
## - Fighting (both builds): the nearest living enemy in line of sight. Blade closes in and swings (Lunge Cleave
##   when in reach); Gun keeps 4–7 m and holds fire, shooting on the move while it explores. Below 35 % HP it backs
##   off. It dodges a visible telegraph within 10 m after reaction_ticks with dodge_permille (the `average` preset),
##   vents when crowded, and uses its utility now and then. Every random choice comes from its own stream.
## Reads the world only to choose its input (a player sees the same: the map, enemies, telegraphs, cards).

## SCORECARD §3 skill presets (starting values): reaction ticks and dodge chance, novice / average / expert.
const PRESETS := {"novice": [24, 300], "average": [14, 650], "expert": [8, 900]}
const DODGE_RANGE_M := 10.0
const BLADE_ENGAGE_M := 4.5
const GUN_ENGAGE_M := 9.0
const SWING_RANGE := 2.2
const REWARD_REACH_M := 1.0
const ROOM_VISIT_M := 2.0
## A room or reward not reached in this long (40 s) is given up.
const GOAL_TICKS := 40 * 60
## A careful player's floor budget before heading to the boss (M-FLOOR's top, 15 min).
const MAX_EXPLORE_TICKS := 15 * 60 * 60

## Card scores: abilities first (a new slot, then levels), then stats by id (× rarity; survival stats × 2 while
## under 60 % HP), then mods.
const STAT_SCORE := {
	&"damage": 50,
	&"attack_speed": 42,
	&"crit_chance": 38,
	&"max_hp": 34,
	&"cooldowns": 32,
	&"crit_damage": 30,
	&"armour": 30,
	&"area": 28,
	&"onrush": 26,
	&"overkill": 26,
	&"fast_hands": 26,
	&"regen": 22,
	&"glass_cannon": 18,
	&"move_speed": 16,
	&"shard_gain": 12,
	&"hoarder": 8,
	&"pickup_range": 6,
}
const RARITY_PERMILLE: Array[int] = [1000, 1700, 2600]
## Stats a hurt bot values twice as much.
const SURVIVAL: Array[StringName] = [&"max_hp", &"regen", &"armour"]

var max_explore_ticks := MAX_EXPLORE_TICKS
var reaction_ticks := 14
var dodge_permille := 650
var gun := false
var cards_taken := 0
## Picks as [tick, card code, score].
var picks: Array = []

var _rng: RngStream
var _nav := NavField.new()
var _walls_built := -1
var _goal := Vector2.INF
var _goal_kind := ""
var _goal_reward := -1
var _visited := {}
var _skipped := {}
var _strafe := 1
var _seen_tel := {}
var _last_pos := Vector2.ZERO
var _last_check := 0
var _wiggle := 0
var _wiggle_dir := Vector2.ZERO
var _floor_start := 0
var _goal_tick := 0
var _tick := 0


func _init(seed_value: int, preset: String = "average") -> void:
	_rng = RngStream.derive(seed_value, "run_bot")
	reaction_ticks = PRESETS[preset][0]
	dodge_permille = PRESETS[preset][1]


## A fresh floor: forget the map state.
func start_floor(w: World) -> void:
	_walls_built = -1
	_goal = Vector2.INF
	_goal_kind = ""
	_visited = {}
	_skipped = {}
	_seen_tel = {}
	_floor_start = w.tick
	gun = PlayerBuild.has_gun(w)


## The score of card `code` in world w (higher is better).
static func score_card(w: World, code: int) -> int:
	var info := Offers.info(w, code)
	match int(info["type"]):
		Offers.ABILITY:
			return 100 if int(info["level"]) == 1 else 55 + 5 * int(info["level"])
		Offers.STAT:
			var base: int = STAT_SCORE.get(info["id"], 20)
			# Hurt (under 60 % HP): staying alive first, as a player would pick.
			if w.actors.hp[0] * 1000 < w.actors.max_hp[0] * 600 and SURVIVAL.has(info["id"]):
				base *= 2
			return base * RARITY_PERMILLE[clampi(int(info["rarity"]), 0, 2)] / 1000
	return 40 if int(info["rarity"]) == 1 else 30


## The index (0-based) of the best card in reward i's offer.
static func best_pick(w: World, i: int) -> int:
	var offer := w.rewards.offer_of(i)
	var best := 0
	for k in offer.size():
		if score_card(w, offer[k]) > score_card(w, offer[best]):
			best = k
	return best


func frame(w: World) -> InputFrame:
	if w.choosing >= 0:
		var i := w.rewards.index_of(w.choosing)
		var f := InputFrame.new()
		if i < 0 or w.rewards.offer_of(i).is_empty():
			f.pick = InputFrame.PICK_CANCEL
			return f
		var k := best_pick(w, i)
		var code := w.rewards.offer_of(i)[k]
		picks.append([w.tick, code, score_card(w, code)])
		cards_taken += 1
		f.pick = k + 1
		return f
	if w.player_dead() or (w.boss_flow != null and w.boss_flow.holds_world()):
		return InputFrame.new()
	if w.tick % 90 == 0:
		_strafe = -_strafe
	_tick = w.tick
	_ensure_nav(w)
	_mark_room(w)
	_update_goal(w)
	return _act(w)


func _ensure_nav(w: World) -> void:
	if _walls_built == w.walls.size():
		return
	_walls_built = w.walls.size()
	_nav.build(w.walls)
	_goal = Vector2.INF  # re-flood toward the goal on the new walls


func _mark_room(w: World) -> void:
	var f := w.floor_layout
	if f == null:
		return
	var r := f.room_of(w.player_pos())
	if r >= 0 and Kin.length(w.player_pos() - _free(f.rooms[r].get_center())) <= ROOM_VISIT_M:
		_visited[r] = true
	# A goal not reached in GOAL_TICKS (blocked, or always in a fight on the way): given up.
	if _goal_kind in ["room", "reward"] and w.tick - _goal_tick > GOAL_TICKS:
		if _goal_kind == "room":
			_visited[_goal_reward] = true
		else:
			_skipped[_goal_reward] = true
		_goal_kind = ""


## Candidate targets while exploring: [position, kind, reward index].
func _targets(w: World) -> Array:
	var out := []
	var f := w.floor_layout
	for i in w.rewards.size():
		var id := w.rewards.ids[i]
		if _skipped.has(id):
			continue
		if f != null and f.room_of(w.rewards.pos(i)) == f.overrun_room:
			continue
		if Rewards.can_afford(w, i):
			out.append([w.rewards.pos(i), "reward", id])
	if f != null:
		for r in f.room_count():
			if _visited.has(r) or r == f.boss_room or r == f.overrun_room:
				continue
			out.append([_free(f.rooms[r].get_center()), "room", r])
	return out


func _update_goal(w: World) -> void:
	var f := w.floor_layout
	if f == null:
		return
	var bf := w.boss_flow
	if bf != null and bf.portal_active():
		_set_goal(f.portal_front_point(), "portal", -1)
		return
	if bf != null and bf.door_sealed():
		_goal_kind = "boss"
		return
	if _goal_kind == "reward" and _reward_index(w, _goal_reward) >= 0:
		return  # keep walking to it
	if _goal_kind == "room" and not _visited.has(_goal_reward):
		return
	if _goal_kind == "door":
		return
	var exploring := w.tick - _floor_start < max_explore_ticks and f.boss_room >= 0
	var targets := _targets(w) if exploring else []
	if targets.is_empty() and exploring and _chests_left(w):
		_visited = {}  # chests it can't afford yet: tour the rooms again, fighting, until it can
		var here := f.room_of(w.player_pos())
		if here >= 0:
			_visited[here] = true
		targets = _targets(w)
	if targets.is_empty():
		_set_goal(f.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2), "door", -1)
		return
	_nav.flood(_free(w.player_pos()))
	var best := -1
	var best_d := NavField.UNREACHED
	for k in targets.size():
		var c := _nav.cell_of(_free(targets[k][0]))
		var d := _nav.dist[c.y * _nav.size.x + c.x] if _nav.inside(c) else NavField.UNREACHED
		if d < best_d:
			best = k
			best_d = d
	if best < 0:  # nothing reachable: mark them and go on
		for t: Array in targets:
			if t[1] == "room":
				_visited[t[2]] = true
			else:
				_skipped[t[2]] = true
		_set_goal(f.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2), "door", -1)
		return
	_set_goal(targets[best][0], targets[best][1], targets[best][2])


## A chest still on the floor that the bot hasn't given up on (outside the Overrun room).
func _chests_left(w: World) -> bool:
	var f := w.floor_layout
	for i in w.rewards.size():
		if w.rewards.kind[i] == RewardStore.Kind.CHEST and not _skipped.has(w.rewards.ids[i]):
			if f == null or f.room_of(w.rewards.pos(i)) != f.overrun_room:
				return true
	return false


func _set_goal(at: Vector2, kind: String, ref: int) -> void:
	if at == _goal and kind == _goal_kind:
		return
	_goal = at
	_goal_kind = kind
	_goal_reward = ref
	_goal_tick = _tick
	_nav.flood(_free(at))


## The centre of the free flow-field cell nearest p (p itself when none is within 12 cells, 6 m): a flood from a
## blocked cell (a room's centre on a pillar, the player brushing a wall) reaches nothing.
func _free(p: Vector2) -> Vector2:
	var c := _nav.cell_of(p)
	for r in 13:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if _nav.inside(n) and _nav.blocked[n.y * _nav.size.x + n.x] == 0:
					return _nav.center(n)
	return p


static func _reward_index(w: World, id: int) -> int:
	return w.rewards.index_of(id) if id >= 0 else -1


func _act(w: World) -> InputFrame:
	var p := w.player_pos()
	var held := 0
	var pressed := 0
	var move := Vector2.ZERO
	var aim := w.aim_angle
	var aim_d := 600
	# The goal's direction (flow field, straight in when close).
	var to_goal := Vector2.ZERO
	if _goal != Vector2.INF and _goal_kind != "boss":
		var g := _goal - p
		to_goal = g.normalized() if Kin.length(g) < 1.5 else _nav.direction(p)
		if to_goal == Vector2.ZERO and Kin.length(g) > 0.01:
			to_goal = g.normalized()
	# A reward in reach: open it (or give up on a chest it can no longer afford).
	if _goal_kind == "reward":
		var i := _reward_index(w, _goal_reward)
		if i >= 0 and Kin.length(w.rewards.pos(i) - p) <= REWARD_REACH_M:
			if not Rewards.can_afford(w, i):
				_skipped[_goal_reward] = true
				_goal_kind = ""
			elif w.tick % 4 == 0:
				pressed |= InputFrame.INTERACT
	var target := _target(w)
	var hp_low := w.actors.hp[0] * 1000 < w.actors.max_hp[0] * 350
	if target >= 0:
		var to := w.actors.pos(target) - p
		var dist := Kin.length(to)
		var dir := to / dist if dist > 0.0 else Vector2.RIGHT
		var side := Vector2(-dir.y, dir.x) * _strafe
		aim = Kin.angle_of(to)
		aim_d = int(dist * 100.0)
		var fighting := (
			_goal_kind == "boss" or dist <= (GUN_ENGAGE_M if gun else BLADE_ENGAGE_M) or hp_low
		)
		if gun:
			held |= InputFrame.SHOOT
			if dist < 5.0 and _rng.chance_permille(30):
				pressed |= InputFrame.SKILL
			if hp_low or dist < 4.0:
				move = (-dir + side * 0.6).normalized()
			elif _goal_kind == "boss" and dist > 7.0:
				move = dir
			elif _goal_kind == "boss" or to_goal == Vector2.ZERO:
				move = side
			else:
				move = to_goal
		elif fighting:
			if hp_low and dist < 3.5:
				move = (-dir + side * 0.6).normalized()
			elif dist < SWING_RANGE * 0.6:
				move = side
			elif _telegraphing(w, target) and dist > SWING_RANGE:
				move = side  # don't walk into its swing or its run
			elif dist < 7.0 and _rng.chance_permille(300):
				move = (dir + side) * 0.7071
			else:
				move = dir
			if dist <= SWING_RANGE and w.tick % 6 == 0:
				pressed |= InputFrame.PRIMARY
			if dist <= 4.0 and _rng.chance_permille(25):
				pressed |= InputFrame.SKILL
		else:
			move = to_goal
		if _crowd(w, p, 3.0) >= 3 and _rng.chance_permille(40):
			pressed |= InputFrame.VENT
		if dist < 6.0 and _rng.chance_permille(15):
			pressed |= InputFrame.UTILITY
			held |= InputFrame.UTILITY
		var dodge := _dodge(w, p)
		if dodge[0] != Vector2.ZERO:
			move = dodge[0]
			if dodge[1]:
				pressed |= InputFrame.DASH
	else:
		move = to_goal
		var b := w.actors.index_of(w.boss_id) if w.boss_id >= 0 else -1
		if _goal_kind == "boss" and b >= 0 and w.actors.dead[b] == 0:
			move = (w.actors.pos(b) - p).normalized()
		if move != Vector2.ZERO:
			aim = Kin.angle_of(move)
	move = _unstick(w, p, move)
	var mv := Vector2i(int(move.x * 127.0), int(move.y * 127.0))
	return InputFrame.make(mv, aim, aim_d, held, pressed)


## The nearest living enemy (or boss) in line of sight within 12 m, or -1.
func _target(w: World) -> int:
	var p := w.player_pos()
	var best := -1
	var best_d := 12.0
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 1 or w.actors.teams[i] != ActorStore.TEAM_ENEMY:
			continue
		var d := Kin.length(w.actors.pos(i) - p)
		if d < best_d and _sight(w, p, w.actors.pos(i)):
			best = i
			best_d = d
	return best


static func _sight(w: World, a: Vector2, b: Vector2) -> bool:
	for k in w.walls_along(a, b, 0.1):
		if Collide.sweep_vs_obb(a, b, 0.1, w.walls[k]) >= 0.0:
			return false
	return true


static func _crowd(w: World, p: Vector2, r: float) -> int:
	var n := 0
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0 and w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			if Kin.length(w.actors.pos(i) - p) <= r:
				n += 1
	return n


## The way out of the telegraphs the player stands in (with a 0.6 m margin): [direction, dash now]. Each telegraph
## is noticed after reaction_ticks and then dodged with dodge_permille (one roll per telegraph); a dodged one is
## walked out of for as long as the player is in it, with a dash at the moment it is noticed. A lane (a Charger's
## run, a Sniper's line, a Needle's burst) is left sideways, a disc (a slam, a rune, a swipe) straight away.
func _dodge(w: World, p: Vector2) -> Array:
	var out := Vector2.ZERO
	var dash := false
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 1 or w.actors.teams[i] != ActorStore.TEAM_ENEMY:
			continue
		var id := w.actors.ids[i]
		if Kin.length(p - w.actors.pos(i)) > DODGE_RANGE_M:
			_seen_tel.erase(id)
			continue
		var tel := EnemyAi.telegraph(w, i)
		if tel.is_empty():
			_seen_tel.erase(id)
			continue
		var away := _out_of(tel, p)
		var n: int = _seen_tel.get(id, 0)
		if n >= 0 and away != Vector2.ZERO:
			n += 1
			if n >= reaction_ticks:
				n = -1 if _rng.chance_permille(dodge_permille) else -2  # -1 dodging, -2 missed it
				dash = dash or n == -1
		_seen_tel[id] = n
		if n == -1 and away != Vector2.ZERO:
			out = away
	return [out, dash]


## True while enemy i shows a telegraph (the Blade waits it out instead of walking into it).
static func _telegraphing(w: World, i: int) -> bool:
	return not EnemyAi.telegraph(w, i).is_empty()


## The way out of telegraph `tel` from p (unit), or ZERO when p is clear of it.
static func _out_of(tel: Dictionary, p: Vector2) -> Vector2:
	match tel.get("shape", &""):
		&"lane":
			return _out_of_lane(tel["obb"], p)
		&"lanes":
			for o: Obb in tel["obbs"]:
				var d := _out_of_lane(o, p)
				if d != Vector2.ZERO:
					return d
		&"disc":
			var to: Vector2 = p - tel["center"]
			if Kin.length(to) <= float(tel["radius"]) + 0.6:
				return to.normalized() if Kin.length(to) > 0.01 else Vector2.RIGHT
	return Vector2.ZERO


static func _out_of_lane(o: Obb, p: Vector2) -> Vector2:
	if o == null or Collide.circle_vs_obb(p, 0.6, o) == Vector2.ZERO:
		return Vector2.ZERO
	var side := (p - o.center).dot(o.axis_v)
	return o.axis_v if side >= 0.0 else -o.axis_v


## Stuck against a wall for 2 s while trying to move: wiggle sideways for half a second.
func _unstick(w: World, p: Vector2, move: Vector2) -> Vector2:
	if _wiggle > 0:
		_wiggle -= 1
		return _wiggle_dir
	if w.tick - _last_check >= 120:
		if move != Vector2.ZERO and Kin.length(p - _last_pos) < 0.5:
			_wiggle = 30
			var a := _rng.range_int(0, 4095)
			_wiggle_dir = Kin.dir(a)
		_last_pos = p
		_last_check = w.tick
	return move
