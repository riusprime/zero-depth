class_name Heat
extends RefCounted
## Overclock heat (v0.3.0 PLAN L18; docs/design/SIGNATURE.md §Overclock), the first signature system. Every hook is
## a no-op when World.heat is null (worlds without heat keep their behaviour and their hash).
## - Gain: each landed attack (a swing once, however many it hits; each bolt) adds its type's heat. Payoffs, DoT,
##   echoes, chains and dash hits never add heat. Heat waits decay_delay_ticks after the last gain, then falls.
## - Hot (>= hot_threshold): the blade reaches farther (swing_reach_m, the same reach WorldReader draws) and each
##   bolt pierces one enemy. Overclock (>= overclock_threshold): attacks deal more, leave an ember, and add burn
##   stacks when a burn item (the fire engine) is owned.
## - Overheat (reaching max_heat): a stall of stall_ticks, moving slower and unable to attack, while heat drains to
##   0. Meltdown (item): the overheat blows up as a full-heat blast instead, with no stall.
## - Vent: the Vent button (v0.3.5 K, owner F1; PlayerSkill) pressed while Hot blasts every enemy around you for
##   heat x vent_damage and resets heat. Dash and blink no longer vent. The blast is a payoff: its own root, inside
##   Engines.begin/end (ancestry), and in Engines.PAYOFFS (no stacks).

const TIER_COOL := 0
const TIER_HOT := 1
const TIER_OVERCLOCK := 2
const TIER_OVERHEAT := 3
const EFFECT_VENT := &"heat_vent"
const EFFECT_MELTDOWN := &"meltdown"
const EFFECT_OVERCLOCK := &"overclock_heat"
## ProcLedger codes (after Engines' codes; appended, never renumbered: they are hashed).
const CODE_OVERCLOCK_BURN := 48
const CODE_MELTDOWN := 49
## A pierced bolt leaves the enemy this far past its edge, so the next sweep starts clear of it.
const PIERCE_CLEARANCE_M := 0.02
## Hits that are never "an attack" for heat: statuses, dash bodies, chain jumps, thorn rings, shrapnel, areas.
const NOT_ATTACK := (
	SimEvent.TAG_DOT
	| SimEvent.TAG_DASH
	| SimEvent.TAG_CHAIN
	| SimEvent.TAG_THORN
	| SimEvent.TAG_SHRAPNEL
	| SimEvent.TAG_AREA
)


## Turns heat on for this world (the loadout's heat table; set at setup, before the first step).
static func enable(w: World, table: HeatTable) -> void:
	w.heat = HeatState.new(table) if table != null else null


static func points(w: World) -> int:
	return w.heat.milli / HeatTable.MILLI if w.heat != null else 0


## The Hot threshold in points: the table's, or Thermal Edge's lower one.
static func hot_threshold(w: World) -> int:
	var t := w.heat.table.hot_threshold
	var o := w.item_mods.heat_hot_threshold
	return mini(t, o) if o > 0 else t


static func tier_of(w: World) -> int:
	var s := w.heat
	if s == null:
		return TIER_COOL
	if s.stall > 0:
		return TIER_OVERHEAT
	if s.milli >= s.table.overclock_threshold * HeatTable.MILLI:
		return TIER_OVERCLOCK
	if s.milli >= hot_threshold(w) * HeatTable.MILLI:
		return TIER_HOT
	return TIER_COOL


## Hot or hotter (Overclock), and not overheated.
static func hot(w: World) -> bool:
	var t := tier_of(w)
	return t == TIER_HOT or t == TIER_OVERCLOCK


static func overclocked(w: World) -> bool:
	return tier_of(w) == TIER_OVERCLOCK


static func stalled(w: World) -> bool:
	return w.heat != null and w.heat.stall > 0


# --- The clock ------------------------------------------------------------------------------------------------
## Tick phase 4 (PlayerKit.advance, before the attacks): the stall runs down and drains the heat; otherwise heat
## decays once decay_delay_ticks have passed without a gain.
static func advance(w: World) -> void:
	var s := w.heat
	if s == null:
		return
	if s.stall > 0:
		s.stall -= 1
		s.milli = s.table.max_milli() * s.stall / maxi(1, s.stall_total)
	else:
		s.idle += 1
		if s.idle > s.table.decay_delay_ticks and s.milli > 0:
			s.milli = maxi(0, s.milli - s.table.decay_per_tick)
	_retier(w)


static func _retier(w: World) -> void:
	var s := w.heat
	var t := tier_of(w)
	if t != s.tier:
		s.tier = t
		s.tier_tick = w.tick


# --- Gain and the attack modifiers ------------------------------------------------------------------------------
## A hit is one of the player's own attacks (a swing or a bolt), not a payoff, a status tick or a dash body.
static func is_attack(tags: int, effect_id: StringName) -> bool:
	if effect_id != &"" or tags & NOT_ATTACK:
		return false
	return (tags & (SimEvent.TAG_MELEE | SimEvent.TAG_PROJECTILE)) != 0


## Damage.hit's attacker multiplier (per mille): Overclock raises the player's attacks on enemies.
static func attacker_mult(
	w: World, target: int, owner_id: int, tags: int, effect_id: StringName
) -> int:
	if w.heat == null or target == 0 or owner_id != w.actors.ids[0]:
		return 1000
	if not is_attack(tags, effect_id) or not overclocked(w):
		return 1000
	return 1000 + w.heat.table.overclock_damage_permille


## The player's hit on enemy `i` landed (Damage.hit, got > 0): an Overclock hit leaves an ember and feeds the fire
## engine; the attack adds its heat once per root.
static func on_hit(w: World, i: int, root: int, tags: int, effect_id: StringName) -> void:
	var s := w.heat
	if s == null or not is_attack(tags, effect_id):
		return
	var a := w.actors
	if tags & SimEvent.TAG_OVERCLOCK:
		s.ember_tick = w.tick
		s.ember_pos = a.pos(i)
		var n := s.table.overclock_burn_stacks
		if (
			n > 0
			and w.item_mods.burn_max_stacks > 0
			and a.dead[i] == 0
			and w.proc_ledger.try_mark(root, CODE_OVERCLOCK_BURN, a.ids[i], w.tick)
		):
			Engines.add_burn(w, i, n, root, EFFECT_OVERCLOCK)
	if s.stall > 0 or root == s.last_root or w.player_dead():
		return
	s.last_root = root
	var g := s.table.gain_bolt
	if tags & SimEvent.TAG_MELEE:
		g = (
			s.table.gain_finisher if PlayerKit.is_finisher(w, w.combo_step) else s.table.gain_swing
		)
	if tags & SimEvent.TAG_SKILL and w.player.skill != null:
		g = w.player.skill.heat_gain  # Kit (v0.3.5 K): a skill adds its own heat, once per use.
	add(w, g, root)


## Adds `milli` heat (from the attack with root `root`); reaching the overheat point overheats.
static func add(w: World, milli: int, root: int = 0) -> void:
	var s := w.heat
	if s == null or s.stall > 0:
		return
	# Gamble shrine (v0.3.0 L19): more heat capacity = each attack fills the same meter by less.
	var cap := 1000 + (Gamble.heat_capacity_bonus_permille(w) if w.gamble_table != null else 0)
	milli = milli * 1000 / maxi(1000, cap)
	s.milli = mini(s.milli + milli, s.table.max_milli())
	s.idle = 0
	if s.milli >= s.table.max_milli():
		_overheat(w, root)
	_retier(w)


static func _overheat(w: World, root: int) -> void:
	var s := w.heat
	s.overheat_tick = w.tick
	var melt := w.item_mods.meltdown_damage_permille
	if melt > 0:
		s.meltdown = true
		var r := root if root != 0 else w.take_root()
		if w.proc_ledger.try_mark(r, CODE_MELTDOWN, 0, w.tick):
			_blast(w, s.table.max_heat, melt, r, EFFECT_MELTDOWN)
		s.milli = 0
		return
	s.meltdown = false
	s.stall = s.table.stall_ticks
	s.stall_total = s.table.stall_ticks


## World.state_hash: heat goes into the hash only in worlds that have it.
static func hash_into(w: World, h: StateHasher) -> void:
	if w.heat != null:
		w.heat.hash_into(h)


## Swings and shots wait out the stall (PlayerKit.advance).
static func can_attack(w: World) -> bool:
	return not stalled(w)


## The stall's move-speed factor (1.0 unless overheated).
static func move_factor(w: World) -> float:
	if not stalled(w):
		return 1.0
	return w.heat.table.stall_move_permille / 1000.0


## The swing reach multiplier (per mille): Hot reaches farther (ItemEffects.swing_reach_m).
static func reach_permille(w: World) -> int:
	return 1000 + w.heat.table.hot_reach_permille if hot(w) else 1000


## Extra tags a bolt fired now carries: a Hot bolt pierces.
static func bolt_tags(w: World) -> int:
	return SimEvent.TAG_PIERCE if hot(w) else 0


## Player bolt `pi` (swept from `from`) just hit actor `k`: a piercing bolt goes on through it, once. True when it
## pierced: the bolt lives on, moved this tick to just past the enemy's far edge along its path (instead of its
## usual step, so this tick doesn't count against its life), its pierce spent.
static func pierce(w: World, pi: int, k: int, from: Vector2) -> bool:
	var p := w.projectiles
	if p.team[pi] != ActorStore.TEAM_PLAYER or not (p.tags[pi] & SimEvent.TAG_PIERCE):
		return false
	p.tags[pi] &= ~SimEvent.TAG_PIERCE
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var speed := Kin.length(v)
	if speed <= 0.0:
		return false
	var dir := v / speed
	var c := w.actors.pos(k) - from
	var along := c.dot(dir)
	var reach := w.actors.radius[k] + p.radius[pi] + PIERCE_CLEARANCE_M
	var perp2 := maxf(0.0, c.dot(c) - along * along)
	var out := from + dir * (along + sqrt(maxf(0.0, reach * reach - perp2)))
	p.pos_x[pi] = out.x
	p.pos_y[pi] = out.y
	return true


# --- Vent ---------------------------------------------------------------------------------------------------
## The Vent button (v0.3.5 K; PlayerSkill): while Hot, vent every point of heat in a blast around the player.
## Returns true if it vented (false: no heat, under Hot, overheated or dead).
static func vent(w: World) -> bool:
	var s := w.heat
	if s == null or w.player_dead() or not hot(w):
		return false
	var heat := s.milli / HeatTable.MILLI
	_blast(w, heat, 1000, w.take_root(), EFFECT_VENT)
	s.milli = 0
	s.idle = 0
	_retier(w)
	return true


## Venting now would blast (the meter's VENT prompt): Hot (or Overclock) and alive.
static func vent_ready(w: World) -> bool:
	return hot(w) and not w.player_dead()


## The blast's radius: the table's, with Heat Sink's bonus.
static func vent_radius_m(w: World) -> float:
	return w.heat.table.vent_radius_m * (1000 + w.item_mods.vent_radius_bonus_permille) / 1000.0


## The blast's damage for `heat` points at `share` per mille: heat x vent_damage, with Heat Sink's bonus.
static func vent_damage(w: World, heat: int, share: int = 1000) -> int:
	var per := (
		w.heat.table.vent_damage_permille * (1000 + w.item_mods.vent_damage_bonus_permille) / 1000
	)
	return maxi(1, heat * per / 1000 * share / 1000)


## A heat blast around the player (a vent, or a Meltdown): `heat` points' damage to every enemy in the disc.
static func _blast(w: World, heat: int, share: int, root: int, effect: StringName) -> void:
	var s := w.heat
	var a := w.actors
	var center := w.player_pos()
	var radius := vent_radius_m(w)
	if not Engines.begin(w, effect):
		return
	s.vent_tick = w.tick
	s.vent_pos = center
	s.vent_heat = heat
	s.vent_radius = radius
	var dmg := vent_damage(w, heat, share)
	var pid := a.ids[0]
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		if AttackShapes.disc_touches(center, radius, a.pos(i), a.radius[i]):
			Damage.hit(w, i, dmg, pid, pid, root, SimEvent.TAG_AREA, center, a.pos(i), effect)
	Engines.end(w)


# --- Views --------------------------------------------------------------------------------------------------
## Plain values for WorldReader.heat_state ({} without heat). "tier" is TIER_* (0 cool, 1 Hot, 2 Overclock,
## 3 overheated); heats are in points.
static func read(w: World) -> Dictionary:
	var s := w.heat
	if s == null:
		return {}
	return {
		"heat": s.milli / float(HeatTable.MILLI),
		"max": s.table.max_heat,
		"hot": hot_threshold(w),
		"overclock": s.table.overclock_threshold,
		"tier": tier_of(w),
		"tier_tick": s.tier_tick,
		"stall": s.stall,
		"stall_total": s.stall_total,
		"vent_ready": vent_ready(w),
		"overheat_tick": s.overheat_tick,
		"meltdown": s.meltdown,
		"vent_tick": s.vent_tick,
		"vent_pos": s.vent_pos,
		"vent_heat": s.vent_heat,
		"vent_radius": s.vent_radius,
		"ember_tick": s.ember_tick,
		"ember_pos": s.ember_pos,
	}
