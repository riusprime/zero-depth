class_name ElementAbilities
extends RefCounted
## Arc Field, Frost Nova and Flame Trail (v0.4.0 AB, PLAN "Abilities"): three auto abilities that feed the v0.3.0
## status engines (Engines): shock stacks discharge at the threshold, frost stacks freeze, burn stacks tick as DoT.
## Each borrows its engine's numbers (threshold, how long stacks last, the discharge, the freeze, the burn) from an
## item (AbilityTable.engine): fold_engines folds them into World.item_mods, the stronger value winning, so an owned
## item of the same engine still counts and the engine code stays the one place a status works.
## - Arc Field: every cooldown_at(level) ticks, if an enemy is within range_m, lightning strikes count(level) of them
##   (distinct, picked at random from the `ability` stream; all of them when fewer) for damage x level_damage and
##   extra(level) shock stacks each.
## - Frost Nova: every cooldown_at(level) ticks, if an enemy is in it, a nova of radius_m x level_radius (area applied)
##   around the player: damage and extra(level) frost stacks to every enemy in it.
## - Flame Trail: while the player moves, a fire patch every period_ticks at least TRAIL_SPACING_M from the last one;
##   it burns for duration_ticks x level_rate. An enemy touching fire takes damage x level_damage and extra(level) burn
##   stacks, at most once every hit_ticks (whatever patch it stands in). Napalm Drone's patches (AbilityCombos) burn
##   the same way.
## Every hit is the player's (TAG_ABILITY: stats and crit apply, never heat); each cast or fire hit is its own root.

const EFFECT_ARC := &"arc_field"
const EFFECT_NOVA := &"frost_nova"
const EFFECT_FLAME := &"flame_trail"
## Fire patch kinds (AbilityState.fire_kind).
const FIRE_TRAIL := 0
const FIRE_NAPALM := 1
## A trail patch falls once the player is this far from the last one.
const TRAIL_SPACING_M := 0.8
## The most patches burning at once (the oldest goes out first).
const FIRE_CAP := 48
## Ticks between fire hits on one enemy when Flame Trail isn't owned (Napalm Drone always comes with it).
const FIRE_HIT_TICKS := 30


## World.item_mods after the items: the engine numbers each owned ability borrows (ItemMods.fold_engine).
static func fold_engines(w: World, m: ItemMods) -> void:
	for idx in w.ability_owned:
		if idx < w.ability_tables.size() and w.ability_tables[idx].engine != null:
			ItemMods.fold_engine(m, w.ability_tables[idx].engine)


## Tick phase 6 (Abilities.advance), slot `s` holding auto ability `t` at `level`.
static func advance_slot(w: World, s: int, t: AbilityTable, level: int) -> void:
	var cd := w.ab.cd
	if cd[s] > 0:
		cd[s] -= 1
	match t.kind:
		AbilityTable.Kind.ARC_FIELD:
			if cd[s] == 0 and _arc(w, t, level):
				cd[s] = Stats.auto_cooldown(w, t.cooldown_at(level))  # Fast Hands applies
		AbilityTable.Kind.FROST_NOVA:
			if cd[s] == 0 and _nova(w, t, level):
				cd[s] = Stats.auto_cooldown(w, t.cooldown_at(level))  # Fast Hands applies
		AbilityTable.Kind.FLAME_TRAIL:
			if cd[s] == 0 and _trail(w, t, level):
				cd[s] = Stats.auto_cooldown(w, t.period_ticks)
	w.ab.cd = cd


# --- Arc Field ----------------------------------------------------------------------------------------------------
## The enemies (alive, not spawning in) an Arc Field strike from `from` may pick, ascending.
static func arc_candidates(w: World, from: Vector2, range_m: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w.enemies_near(from, range_m):
		if w.actors.invuln[i] == 0:
			out.append(i)
	out.sort()
	return out


static func _arc(w: World, t: AbilityTable, level: int) -> bool:
	var a := w.actors
	var from := w.player_pos()
	var cands := arc_candidates(w, from, t.range_m)
	if cands.is_empty():
		return false
	var n := mini(t.count(level), cands.size())
	for k in n:  # a partial shuffle from the ability stream: n distinct targets
		var j := w.rng_ability.range_int(k, cands.size() - 1)
		var swap := cands[k]
		cands[k] = cands[j]
		cands[j] = swap
	var root := w.take_root()
	var dmg := Abilities.damage_at(t, level)
	var s := w.ab
	s.arc_tick = w.tick
	s.arc_from = from
	s.arc_to = PackedVector2Array()
	s.arc_super = 0
	var pid := a.ids[0]
	for k in n:
		var i := cands[k]
		var at := a.pos(i)
		s.arc_to.append(at)
		var hit := AbilityCombos.arc_damage(w, i, dmg)  # Superconductor
		var effect := EFFECT_ARC if hit == dmg else AbilityCombos.EFFECT_SUPER
		if hit != dmg:
			s.arc_super = 1
		if Damage.hit(w, i, hit, pid, pid, root, SimEvent.TAG_ABILITY, from, at, effect) > 0:
			Engines.add_shock(w, i, t.extra(level), root)
	return true


# --- Frost Nova ---------------------------------------------------------------------------------------------------
## The nova's radius at `level` (area applied): the same number the hits and the view use (EI-07).
static func nova_radius(w: World, t: AbilityTable, level: int) -> float:
	return Stats.area(w, t.radius_m * t.radius_permille(level) / 1000.0)


static func _nova(w: World, t: AbilityTable, level: int) -> bool:
	var a := w.actors
	var center := w.player_pos()
	var r := nova_radius(w, t, level)
	var hits := PackedInt32Array()
	for i in w.enemies_near(center, r):
		if a.invuln[i] == 0:
			hits.append(i)
	if hits.is_empty():
		return false
	var root := w.take_root()
	var dmg := Abilities.damage_at(t, level)
	var pid := a.ids[0]
	var tags := SimEvent.TAG_AREA | SimEvent.TAG_ABILITY
	w.ab.nova_tick = w.tick
	w.ab.nova_pos = center
	w.ab.nova_r = r
	for i in hits:
		if Damage.hit(w, i, dmg, pid, pid, root, tags, center, a.pos(i), EFFECT_NOVA) > 0:
			Engines.add_frost(w, i, t.extra(level), root, EFFECT_NOVA)
	return true


# --- Flame Trail and the fire -------------------------------------------------------------------------------------
## A trail patch's radius at `level` (area applied).
static func trail_radius(w: World, t: AbilityTable, level: int) -> float:
	return Stats.area(w, t.radius_m * t.radius_permille(level) / 1000.0)


## How long a trail patch burns at `level`, in ticks.
static func trail_ticks(t: AbilityTable, level: int) -> int:
	return maxi(1, t.duration_ticks * t.rate_permille(level) / 1000)


## Drops a patch when the player has moved TRAIL_SPACING_M from the last one. The first call on a floor only marks
## where the player stands. True when a patch fell.
static func _trail(w: World, t: AbilityTable, level: int) -> bool:
	var s := w.ab
	var p := w.player_pos()
	if s.trail_tick < 0:
		s.trail_tick = w.tick
		s.trail_at = p
		return false
	if Kin.length(p - s.trail_at) < TRAIL_SPACING_M:
		return false
	s.trail_tick = w.tick
	s.trail_at = p
	var dmg := Abilities.damage_at(t, level)
	var r := trail_radius(w, t, level)
	add_fire(w, p, r, w.tick + trail_ticks(t, level), dmg, t.extra(level), FIRE_TRAIL)
	return true


## Lights a fire patch (Flame Trail, Napalm Drone); past FIRE_CAP the oldest goes out.
static func add_fire(
	w: World, at: Vector2, r: float, end_tick: int, dmg: int, stacks: int, kind: int
) -> void:
	var s := w.ab
	if s.fire_pos.size() >= FIRE_CAP:
		_remove_fire(s, 0)
	s.fire_pos.append(at)
	s.fire_r.append(r)
	s.fire_end.append(end_tick)
	s.fire_dmg.append(dmg)
	s.fire_stacks.append(stacks)
	s.fire_kind.append(kind)


static func _remove_fire(s: AbilityState, k: int) -> void:
	s.fire_pos.remove_at(k)
	s.fire_r.remove_at(k)
	s.fire_end.remove_at(k)
	s.fire_dmg.remove_at(k)
	s.fire_stacks.remove_at(k)
	s.fire_kind.remove_at(k)


## Tick phase 6, after the slots: patches go out, then each burns the enemies touching it (oldest patch first; an
## enemy is hit once per fire_hit_ticks whatever patch it stands in).
static func advance_fire(w: World) -> void:
	var s := w.ab
	if s.fire_pos.is_empty() and s.fire_ids.is_empty():
		return
	for k in range(s.fire_pos.size() - 1, -1, -1):
		if s.fire_end[k] <= w.tick:
			_remove_fire(s, k)
	for k in range(s.fire_ids.size() - 1, -1, -1):
		if s.fire_next[k] <= w.tick:
			s.fire_ids.remove_at(k)
			s.fire_next.remove_at(k)
	var a := w.actors
	var pid := a.ids[0]
	var gap := fire_hit_ticks(w)
	var tags := SimEvent.TAG_AREA | SimEvent.TAG_ABILITY
	for k in s.fire_pos.size():
		var at := s.fire_pos[k]
		var effect := EFFECT_FLAME if s.fire_kind[k] == FIRE_TRAIL else AbilityCombos.EFFECT_NAPALM
		for i in w.enemies_near(at, s.fire_r[k]):
			if a.invuln[i] > 0 or a.dead[i] == 1 or s.fire_ids.has(a.ids[i]):
				continue
			s.fire_ids.append(a.ids[i])
			s.fire_next.append(w.tick + gap)
			var root := w.take_root()
			if Damage.hit(w, i, s.fire_dmg[k], pid, pid, root, tags, at, a.pos(i), effect) > 0:
				Engines.add_burn(w, i, s.fire_stacks[k], root, effect)


## Ticks between two fire hits on one enemy: Flame Trail's hit_ticks.
static func fire_hit_ticks(w: World) -> int:
	var t := Abilities.owned_of_kind(w, AbilityTable.Kind.FLAME_TRAIL)
	return t.hit_ticks if t != null and t.hit_ticks > 0 else FIRE_HIT_TICKS


# --- Reads --------------------------------------------------------------------------------------------------------
## What the views draw (WorldReader.element_fx): the last arc strike, the last nova, the fire patches (with how much
## of their life is left, 0..1000) and the combos' last moments.
static func fx(w: World) -> Dictionary:
	var s := w.ab
	var left := PackedInt32Array()
	for k in s.fire_pos.size():
		left.append(clampi((s.fire_end[k] - w.tick) * 1000 / maxi(1, _fire_life(w, k)), 0, 1000))
	return {
		"arc_tick": s.arc_tick,
		"arc_from": s.arc_from,
		"arc_to": s.arc_to,
		"arc_super": s.arc_super == 1,
		"nova_tick": s.nova_tick,
		"nova_pos": s.nova_pos,
		"nova_r": s.nova_r,
		"fire_pos": s.fire_pos,
		"fire_r": s.fire_r,
		"fire_kind": s.fire_kind,
		"fire_left": left,
		"storm_tick": s.storm_tick,
		"storm_from": s.storm_from,
		"storm_to": s.storm_to,
		"ward_tick": s.ward_tick,
		"ward_pos": s.ward_pos,
		"ward_r": s.ward_r,
		"charge_tick": s.charge_tick,
		"charge_pos": s.charge_pos,
		"glacier_tick": s.glacier_tick,
		"wing_tick": s.wing_tick,
		"dancing": AbilityCombos.dancing(w),
		"glacier": Engines.has_combo(w, ComboTable.Effect.GLACIER_RING),
	}


## A patch's full life (for the fade): the trail's or Napalm Drone's.
static func _fire_life(w: World, k: int) -> int:
	if w.ab.fire_kind[k] == FIRE_NAPALM:
		var c := Engines.combo(w, ComboTable.Effect.NAPALM_DRONE)
		return c.window_ticks if c != null else 1
	var t := Abilities.owned_of_kind(w, AbilityTable.Kind.FLAME_TRAIL)
	return (
		trail_ticks(t, Abilities.level_of_kind(w, AbilityTable.Kind.FLAME_TRAIL))
		if t != null
		else 1
	)
