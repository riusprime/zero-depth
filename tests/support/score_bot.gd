# gdlint: disable=max-returns
class_name ScoreBot
extends RefCounted
## The scorecard's bot policies (v0.5.0 SCD; SCORECARD §3). One bot plays a whole run through an InputFrame per tick,
## exactly like the player, and reads the world only to choose its input (the map, enemies, telegraphs, the cards
## and the shop a player sees). Every random choice comes from its own stream (`score_bot`, derived from the run
## seed only, so every policy on a seed starts from the same draws: paired seeds, SCORECARD §1.5).
## Movement and exploration are adapted from v0.4.0 TU's expected-build bot (RunBot, WIP 6ff13c6), kept separate so
## the two steps never edit one file; the policies, skill knobs, card biases, shop use and exploits are new here.
##
## Policies (POLICIES; a name is "<policy>" or "<policy>:<build>"):
## - `idle`: stands still, never picks (a floor reference).
## - `novice`: walks straight at the nearest enemy and attacks, never backs off, dodges with the novice preset, takes
##   a random card, never shops.
## - `competent` (the Generalist): explores the floor, kites (Gun) or closes and swings (Blade), backs off when hurt,
##   dodges telegraphs after its reaction time, vents when crowded, uses its skill and utility; takes the
##   best-scoring card with no build bias (score_card); shops (heal when hurt, then the best card it can afford).
## - specialists `<focus>` (`element`, `ordnance`, `guard`): `competent` movement, cards biased to the focus
##   (FOCUS_*), on a fixed build (`blade_element` ... `gun_guard`). `guard` also holds the Aegis when a telegraph is
##   near. SCORECARD §3's `guard` is `*_guard`; `element` is the Combo/Engine archetype (the shock, frost and burn
##   engines through Arc Field, Frost Nova, Flame Trail and their mods); `ordnance` is Aggro/Burst (Bomb Lobber,
##   Drone Buddy, Orbit Blades and their mods). The bleed engine has no ability of its own yet, so no `bleed` bot.
## - `+t` suffix (`competent+t`): also takes every floor's optional Overrun room (the threat branch, M-THREAT).
## - `exploit:salvage`: `competent`, but at every shop it buys each card it can and sells it straight back (and
##   salvages a bought ability), logging [card, spent, returned] for M-LOOP.
## - `exploit:chain`: `competent`, but every floor starts with every named combo's items (ScoreRun grants them, a
##   test-side write like the bench's stress scene) so the proc chains run as long as possible (M-LIMIT, M-LOOP).

## SCORECARD §3 skill presets (starting values): reaction ticks, aim error (degrees), dodge chance, greed.
const PRESETS := {
	"novice": {"reaction_ticks": 24, "aim_error_deg": 10, "dodge_permille": 300, "greed": 200},
	"average": {"reaction_ticks": 14, "aim_error_deg": 5, "dodge_permille": 650, "greed": 500},
	"expert": {"reaction_ticks": 8, "aim_error_deg": 2, "dodge_permille": 900, "greed": 800},
}
const FOCUSES: Array[String] = ["element", "ordnance", "guard"]
## The abilities each focus wants, the mod tags it wants and the stat cards it wants.
const FOCUS_ABILITIES := {
	"element": [&"arc_field", &"frost_nova", &"flame_trail"],
	"ordnance": [&"bomb_lobber", &"drone_buddy", &"orbit_blades"],
	"guard": [&"aegis"],
}
const FOCUS_MOD_TAGS := {
	"element": ["fire", "shock", "frost"],
	"ordnance": ["ability"],
	"guard": ["guard"],
}
const FOCUS_STATS := {
	"element": [&"area", &"fast_hands", &"cooldowns"],
	"ordnance": [&"fast_hands", &"cooldowns", &"area"],
	"guard": [&"armour", &"max_hp", &"regen"],
}
## A focus card's score bonus, and the penalty on a new ability outside the focus (so a specialist keeps its slots).
const FOCUS_BONUS := 80
const OFF_FOCUS_ABILITY := -40

const DODGE_RANGE_M := 10.0
const BLADE_ENGAGE_M := 4.5
const GUN_ENGAGE_M := 9.0
const SWING_RANGE := 2.2
const REWARD_REACH_M := 1.0
const ROOM_VISIT_M := 2.0
## A room or reward not reached in this long (40 s) is given up.
const GOAL_TICKS := 40 * 60
## After this long on one goal (8 s) the bot stops fighting the crowd around it and walks on, attacking in passing.
const PRESS_ON_TICKS := 8 * 60
## A floor's exploring budget before heading to the boss: M-FLOOR's top (15 min). ScoreRun reports every floor
## that used it all, so the cap never hides a long floor.
const MAX_EXPLORE_TICKS := 15 * 60 * 60
## The shop is worth a visit with this many shards (the cheapest card on floor 1).
const SHOP_MIN_SHARDS := 30
## Card scores (no bias): a new ability first, then levels, then stats by id (x rarity), then mods.
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
## A shop card is bought only at or above this score.
const SHOP_MIN_SCORE := 30

## Mod tags by id (mod_tags), read once from the data.
static var _tags_cache := {}

var policy := "competent"
var moves := "competent"
var picks_mode := "best"
var focus := ""
var threat := false
var exploit := ""
var preset := "average"
var reaction_ticks := 14
var aim_error := 0
var dodge_permille := 650
var greed := 500
var gun := false
var cards_taken := 0
## Every card taken: {tick, code, source ("reward" or "shop")}.
var picks: Array = []
## exploit:salvage's ledger: [card code, spent, returned].
var salvage_log: Array = []
## Floors whose exploring ran out of budget (MAX_EXPLORE_TICKS).
var explore_capped := 0

var _rng: RngStream
var _nav := NavField.new()
var _walls_built := -1
var _goal := Vector2.INF
var _goal_kind := ""
var _goal_ref := -1
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
var _shop_blocked := false
var _shop_visits := 0
var _shop_pending_sell := -1
var _capped_now := false


## `policy_name`: a POLICIES name without the build ("competent", "element", "competent+t", "exploit:salvage" ...).
func _init(seed_value: int, policy_name: String, skill: String = "average") -> void:
	_rng = RngStream.derive(seed_value, "score_bot")
	policy = policy_name
	var base := policy_name
	if base.ends_with("+t"):
		threat = true
		base = base.trim_suffix("+t")
	if base.begins_with("exploit:"):
		exploit = base.trim_prefix("exploit:")
		base = "competent"
	match base:
		"idle":
			moves = "idle"
			picks_mode = "none"
		"novice":
			moves = "novice"
			picks_mode = "random"
			skill = "novice"
		"competent":
			pass
		_:
			assert(FOCUSES.has(base), "unknown policy %s" % policy_name)
			focus = base
	preset = skill
	var p: Dictionary = PRESETS[skill]
	reaction_ticks = p["reaction_ticks"]
	aim_error = int(p["aim_error_deg"]) * 4096 / 360
	dodge_permille = p["dodge_permille"]
	greed = p["greed"]


## A fresh floor: forget the map state.
func start_floor(w: World) -> void:
	_walls_built = -1
	_goal = Vector2.INF
	_goal_kind = ""
	_visited = {}
	_skipped = {}
	_seen_tel = {}
	_floor_start = w.tick
	_shop_blocked = false
	_shop_visits = 0
	_shop_pending_sell = -1
	_capped_now = false
	gun = PlayerBuild.has_gun(w)


# --- Cards ------------------------------------------------------------------------------------------------------
## The unbiased score of card `code` in world w (higher is better): the `competent` pick.
static func base_score(w: World, code: int) -> int:
	var info := Offers.info(w, code)
	match int(info["type"]):
		Offers.ABILITY:
			return 100 if int(info["level"]) == 1 else 55 + 5 * int(info["level"])
		Offers.STAT:
			var base: int = STAT_SCORE.get(info["id"], 20)
			return base * RARITY_PERMILLE[clampi(int(info["rarity"]), 0, 2)] / 1000
	return 40 if int(info["rarity"]) == 1 else 30


## True when card `code` belongs to focus `f` (an ability, mod tag or stat card the focus wants).
static func in_focus(w: World, code: int, f: String) -> bool:
	if f.is_empty():
		return false
	var info := Offers.info(w, code)
	match int(info["type"]):
		Offers.ABILITY:
			return (FOCUS_ABILITIES[f] as Array).has(info["id"])
		Offers.STAT:
			return (FOCUS_STATS[f] as Array).has(info["id"])
	var it := w.item_tables[code]
	for tag in FOCUS_MOD_TAGS[f]:
		if mod_tags(it.id).has(tag):
			return true
	return false


## The score of card `code` for this bot's focus (the unbiased score when it has none).
func score_card(w: World, code: int) -> int:
	var s := base_score(w, code)
	if focus.is_empty():
		return s
	if in_focus(w, code, focus):
		return s + FOCUS_BONUS
	var info := Offers.info(w, code)
	if int(info["type"]) == Offers.ABILITY and int(info["level"]) == 1:
		return s + OFF_FOCUS_ABILITY
	return s


## The index (0-based) of the card this bot takes from `offer`.
func choose_card(w: World, offer: PackedInt32Array) -> int:
	if picks_mode == "random":
		return _rng.range_int(0, offer.size() - 1)
	var best := 0
	for k in offer.size():
		if score_card(w, offer[k]) > score_card(w, offer[best]):
			best = k
	return best


## A mod's tags (ItemDefinition.tags), read once from the data.
static func mod_tags(id: StringName) -> PackedStringArray:
	if _tags_cache.is_empty():
		for def: ItemDefinition in ContentRepository.load_all().all_of(&"items"):
			_tags_cache[def.id] = def.tags
	return _tags_cache.get(id, PackedStringArray())


# --- The tick ---------------------------------------------------------------------------------------------------
func frame(w: World) -> InputFrame:
	if moves == "idle":
		return InputFrame.new()
	if w.choosing >= 0:
		return _pick_frame(w)
	if w.shop.open:
		return _shop_frame(w)
	if w.player_dead() or (w.boss_flow != null and w.boss_flow.holds_world()):
		return InputFrame.new()
	if w.tick % 90 == 0:
		_strafe = -_strafe
	_tick = w.tick
	_ensure_nav(w)
	_mark_room(w)
	_update_goal(w)
	return _act(w)


func _pick_frame(w: World) -> InputFrame:
	var i := w.rewards.index_of(w.choosing)
	var f := InputFrame.new()
	if i < 0 or w.rewards.offer_of(i).is_empty() or picks_mode == "none":
		f.pick = InputFrame.PICK_CANCEL
		return f
	var offer := w.rewards.offer_of(i)
	var k := choose_card(w, offer)
	picks.append({"tick": w.tick, "code": offer[k], "source": "reward"})
	cards_taken += 1
	f.pick = k + 1
	return f


## One shop action a tick: heal when hurt, then the best card it can afford (exploit:salvage: every card, each sold
## straight back), then close.
func _shop_frame(w: World) -> InputFrame:
	var f := InputFrame.new()
	if _shop_pending_sell >= 0:
		var n := _sell_index(w, _shop_pending_sell)
		_shop_pending_sell = -1
		if n >= 0:
			f.pick = InputFrame.PICK_SHOP_SELL + n
			return f
	var hurt := w.actors.hp[0] * 1000 < w.actors.max_hp[0] * 600
	if hurt and not w.shop.heal_used and Shop.heal_amount(w) > 0:
		if w.shards >= Shop.heal_price(w):
			f.pick = InputFrame.PICK_SHOP_HEAL
			return f
	var best := -1
	var best_s := SHOP_MIN_SCORE - 1
	for k in w.shop.offer.size():
		var code := w.shop.offer[k]
		if code < 0 or not Shop.can_apply(w, code) or w.shards < Shop.price(w, code):
			continue
		var s := score_card(w, code)
		if exploit == "salvage" or s > best_s:
			best = k
			best_s = s
			if exploit == "salvage":
				break
	if best >= 0:
		var code := w.shop.offer[best]
		var price := Shop.price(w, code)
		picks.append({"tick": w.tick, "code": code, "source": "shop"})
		cards_taken += 1
		if exploit == "salvage":
			_shop_pending_sell = code
			salvage_log.append([code, price, 0])
		f.pick = best + 1
		return f
	_shop_visits += 1
	if _goal_kind == "shop":
		_goal_kind = ""
	f.pick = InputFrame.PICK_CANCEL
	return f


## The sell_list entry for card `code` (the last one), noting the refund in the salvage log.
func _sell_index(w: World, code: int) -> int:
	var list := Shop.sell_list(w)
	for n in range(list.size() - 1, -1, -1):
		if list[n][2] == code:
			if not salvage_log.is_empty():
				salvage_log[-1][2] = list[n][3]
			return n
	return -1


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
	if _goal_kind in ["room", "reward", "shop"] and w.tick - _goal_tick > GOAL_TICKS:
		match _goal_kind:
			"room":
				_visited[_goal_ref] = true
			"reward":
				_skipped[_goal_ref] = true
			"shop":
				_shop_blocked = true
		_goal_kind = ""


func _overrun_open(w: World) -> bool:
	return Overrun.enabled(w) and not w.overrun.cleared()


## Candidate targets while exploring: [position, kind, ref].
func _targets(w: World) -> Array:
	var out := []
	var f := w.floor_layout
	var avoid := -1 if threat else f.overrun_room
	for i in w.rewards.size():
		var id := w.rewards.ids[i]
		if _skipped.has(id) or picks_mode == "none":
			continue
		if avoid >= 0 and f.room_of(w.rewards.pos(i)) == avoid and _overrun_open(w):
			continue
		if Rewards.can_afford(w, i):
			out.append([w.rewards.pos(i), "reward", id])
	if _wants_shop(w):
		out.append([w.shop.pos, "shop", -1])
	for r in f.room_count():
		if _visited.has(r) or r == f.boss_room:
			continue
		if r == f.overrun_room and not threat:
			continue
		out.append([_free(f.rooms[r].get_center()), "room", r])
	return out


## The shop is a target: never visited and the bot has a card's worth of shards, or a card it saw there (or the heal,
## when hurt) is worth buying and affordable now. A shop it couldn't reach in GOAL_TICKS is dropped for the floor.
func _wants_shop(w: World) -> bool:
	if moves != "competent" or _shop_blocked or not Shop.present(w) or w.shop_table == null:
		return false
	if not w.shop.rolled:
		return w.shards >= SHOP_MIN_SHARDS * maxi(1, w.floor_index)
	if exploit == "salvage" and _shop_visits > 0:
		return false
	var hurt := w.actors.hp[0] * 1000 < w.actors.max_hp[0] * 600
	if hurt and not w.shop.heal_used and w.shards >= Shop.heal_price(w):
		return true
	for code in w.shop.offer:
		if code >= 0 and Shop.can_apply(w, code) and w.shards >= Shop.price(w, code):
			if score_card(w, code) >= SHOP_MIN_SCORE:
				return true
	return false


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
	if threat and w.overrun.inside and not w.overrun.cleared():
		_goal_kind = "overrun"  # stay and fight until the room clears
		return
	if _goal_kind == "reward" and _reward_index(w, _goal_ref) >= 0:
		return
	if _goal_kind == "room" and not _visited.has(_goal_ref):
		return
	if _goal_kind == "shop":
		return
	if _goal_kind == "door":
		return
	var exploring := w.tick - _floor_start < MAX_EXPLORE_TICKS and f.boss_room >= 0
	if not exploring and not _capped_now and f.boss_room >= 0:
		_capped_now = true
		explore_capped += 1
	var targets := _targets(w) if exploring else []
	if targets.is_empty() and exploring and _chests_left(w) and moves == "competent":
		_visited = {}  # a chest it can't afford yet: tour the rooms again, fighting, until it can
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
			match t[1]:
				"room":
					_visited[t[2]] = true
				"reward":
					_skipped[t[2]] = true
				"shop":
					_shop_blocked = true
		_set_goal(f.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2), "door", -1)
		return
	_set_goal(targets[best][0], targets[best][1], targets[best][2])


func _chests_left(w: World) -> bool:
	var f := w.floor_layout
	for i in w.rewards.size():
		if w.rewards.kind[i] == RewardStore.Kind.CHEST and not _skipped.has(w.rewards.ids[i]):
			if threat or f == null or f.room_of(w.rewards.pos(i)) != f.overrun_room:
				return true
	return false


func _set_goal(at: Vector2, kind: String, ref: int) -> void:
	if at == _goal and kind == _goal_kind:
		return
	_goal = at
	_goal_kind = kind
	_goal_ref = ref
	_goal_tick = _tick
	_nav.flood(_free(at))


## The centre of the free flow-field cell nearest p (p itself when none is within 6 m).
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


# --- Acting -----------------------------------------------------------------------------------------------------
func _act(w: World) -> InputFrame:
	var p := w.player_pos()
	var held := 0
	var pressed := 0
	var move := Vector2.ZERO
	var aim := w.aim_angle
	var aim_d := 600
	var to_goal := Vector2.ZERO
	if _goal != Vector2.INF and _goal_kind not in ["boss", "overrun"]:
		var g := _goal - p
		to_goal = g.normalized() if Kin.length(g) < 1.5 else _nav.direction(p)
		if to_goal == Vector2.ZERO and Kin.length(g) > 0.01:
			to_goal = g.normalized()
	pressed |= _interact(w, p)
	var target := _target(w)
	var hp_low := w.actors.hp[0] * 1000 < w.actors.max_hp[0] * 350
	if target >= 0:
		var to := w.actors.pos(target) - p
		var dist := Kin.length(to)
		var dir := to / dist if dist > 0.0 else Vector2.RIGHT
		var side := Vector2(-dir.y, dir.x) * _strafe
		aim = (Kin.angle_of(to) + _aim_noise()) & 4095
		aim_d = int(dist * 100.0)
		if moves == "novice":
			move = dir if dist > SWING_RANGE * 0.6 else side
			if gun:
				held |= InputFrame.SHOOT
			elif dist <= SWING_RANGE and w.tick % 6 == 0:
				pressed |= InputFrame.PRIMARY
		else:
			var r := _fight(w, target, dist, dir, side, to_goal, hp_low)
			move = r[0]
			held |= r[1]
			pressed |= r[2]
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
		elif _goal_kind == "overrun":
			move = _toward_room_centre(w, p)
		if move != Vector2.ZERO:
			aim = Kin.angle_of(move)
	move = _unstick(w, p, move)
	var mv := Vector2i(int(move.x * 127.0), int(move.y * 127.0))
	return InputFrame.make(mv, aim, aim_d, held, pressed)


## The interact press when a goal reward or the shop is in reach (or giving up on a chest it can't afford).
func _interact(w: World, p: Vector2) -> int:
	if _goal_kind == "reward":
		var i := _reward_index(w, _goal_ref)
		if i >= 0 and Kin.length(w.rewards.pos(i) - p) <= REWARD_REACH_M:
			if not Rewards.can_afford(w, i):
				_skipped[_goal_ref] = true
				_goal_kind = ""
			elif w.tick % 4 == 0:
				return InputFrame.INTERACT
	elif _goal_kind == "shop" and Shop.in_reach(w) and w.tick % 4 == 0:
		return InputFrame.INTERACT
	return 0


## `competent` fighting: [move, held, pressed].
func _fight(
	w: World, target: int, dist: float, dir: Vector2, side: Vector2, to_goal: Vector2, hp_low: bool
) -> Array:
	var p := w.player_pos()
	var held := 0
	var pressed := 0
	var move := Vector2.ZERO
	var staying := _goal_kind in ["boss", "overrun"]
	var fighting := staying or dist <= (GUN_ENGAGE_M if gun else BLADE_ENGAGE_M) or hp_low
	# Pressing on: a goal held this long is walked to through the crowd, attacking in passing (a horde never ends).
	if (
		not staying
		and to_goal != Vector2.ZERO
		and w.tick - _goal_tick >= PRESS_ON_TICKS
		and not hp_low
	):
		move = to_goal if dist >= 1.0 else (to_goal + side).normalized()
		if gun:
			held |= InputFrame.SHOOT
		elif dist <= SWING_RANGE and w.tick % 6 == 0:
			pressed |= InputFrame.PRIMARY
		return [move, held, pressed]
	if gun:
		held |= InputFrame.SHOOT
		if dist < 5.0 and _rng.chance_permille(30):
			pressed |= InputFrame.SKILL
		if hp_low or dist < 4.0:
			move = (-dir + side * 0.6).normalized()
		elif staying and dist > 7.0:
			move = dir
		elif staying or to_goal == Vector2.ZERO:
			move = side
		else:
			move = to_goal
	elif fighting:
		if hp_low and dist < 3.5:
			move = (-dir + side * 0.6).normalized()
		elif dist < SWING_RANGE * 0.6:
			move = side
		elif not EnemyAi.telegraph(w, target).is_empty() and dist > SWING_RANGE:
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
	if Abilities.utility(w) == PlayerTable.Utility.GUARD and focus == "guard":
		if _near_telegraph(w, p, 6.0):
			held |= InputFrame.UTILITY
	elif dist < 6.0 and _rng.chance_permille(15):
		pressed |= InputFrame.UTILITY
		held |= InputFrame.UTILITY
	return [move, held, pressed]


func _toward_room_centre(w: World, p: Vector2) -> Vector2:
	var f := w.floor_layout
	var r := f.room_of(p)
	if r < 0:
		return Vector2.ZERO
	var c := f.rooms[r].get_center() - p
	return c.normalized() if Kin.length(c) > 1.5 else Vector2(-c.y, c.x).normalized() * 0.5


## Aim error: a triangular draw over ±aim_error (1/4096 turns) from the bot's stream.
func _aim_noise() -> int:
	if aim_error <= 0:
		return 0
	return (_rng.range_int(-aim_error, aim_error) + _rng.range_int(-aim_error, aim_error)) / 2


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


static func _near_telegraph(w: World, p: Vector2, r: float) -> bool:
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0 and w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			if Kin.length(w.actors.pos(i) - p) <= r and not EnemyAi.telegraph(w, i).is_empty():
				return true
	return false


## The way out of the telegraphs the player stands in (with a 0.6 m margin): [direction, dash now]. Each telegraph
## is noticed after reaction_ticks and then dodged with dodge_permille (one roll per telegraph).
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
			_wiggle_dir = Kin.dir(_rng.range_int(0, 4095))
		_last_pos = p
		_last_check = w.tick
	return move
