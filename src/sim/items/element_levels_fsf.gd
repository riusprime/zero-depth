class_name ElementLevelsFsf
extends RefCounted
## v0.9.5 EE2 (ELEMENTS.md E3-E5; the owner: "each element should have its own reward system for levelling"): what the
## Fire, Lightning and Frost cards (Gun) do at their levels. Lv 1 is the card as it was (nothing here changes it). Fire
## Lv 2, Wildfire: the burning ground its kills leave is el_patch_wide_permille wider and lasts el_patch_extra_ticks
## longer (the patch already burns what stands in it); Lv 3, Heat sync: a burning enemy takes el_heat_permille more from
## every hit of the hero (an attacker multiplier like Overclock's; burn ticks never come through a hit). Lightning Lv 2,
## Fork: the chain has el_fork_chains more jumps and el_fork_range_m more reach; Lv 3, Overcharge: every
## el_strike_every-th hit that can chain calls a strike on the enemy it hit (el_strike_radius_m, el_strike_permille of
## the hit's damage, TAG_AREA: it never chains), at most el_strikes_per_second a second. Frost Lv 2, Frostbite: a frozen
## enemy takes el_frostbite_permille more; Lv 3, Shatter: a hit on an enemy frozen before it breaks the freeze and fires
## el_shard_count shards at the nearest others within el_shard_range_m (el_shard_permille of the hit, a short slow,
## TAG_SHRAPNEL: they never chain or shatter again), at most el_shatters_per_second a second. Integers and the sim clock
## only; the numbers are the card's (ItemDefinition el_*). The strike and shatter budgets and the chain-hit count
## (World.el_*) are saved and hashed only while Lightning or Frost runs at Lv 3.

const FIRE := 0
const STORM := 1
const FROST := 2
const LV_2 := 2
const LV_3 := 3
const STORM_ID := &"storm_core"
const FIRE_ID := &"ember_core"
const WINDOW := 60  # a budget's "second", in ticks


## The index of the owned wand card of `which` (FIRE, STORM, FROST), or -1.
static func _find(w: World, which: int) -> int:
	for idx in w.items_owned:
		var t := w.item_tables[idx]
		var mine := false
		match which:
			FIRE:
				mine = t.el_heat_permille > 0
			STORM:
				mine = t.el_strike_every > 0
			_:
				mine = t.el_frostbite_permille > 0
		if mine and CardLevels.is_card(w, idx):
			return idx
	return -1


## The held card's level, 1 without one.
static func level(w: World, which: int) -> int:
	var idx := _find(w, which)
	return CardLevels.level(w, idx) if idx >= 0 else 1


## The held card's table, or null.
static func card(w: World, which: int) -> ItemTable:
	var idx := _find(w, which)
	return w.item_tables[idx] if idx >= 0 else null


# --- Fire ---------------------------------------------------------------------------------------------------------
## Wildfire: a burning patch of `spec` of radius `r`, now (the card's, at Lv 2 or more).
static func patch_radius(w: World, spec: AttackSpec, r: float) -> float:
	if spec.effect_id != FIRE_ID or level(w, FIRE) < LV_2:
		return r
	return r * (1000 + card(w, FIRE).el_patch_wide_permille) / 1000.0


## Wildfire: the ticks a patch of `spec` lasts longer.
static func patch_extra_ticks(w: World, spec: AttackSpec) -> int:
	if spec.effect_id != FIRE_ID or level(w, FIRE) < LV_2:
		return 0
	return card(w, FIRE).el_patch_extra_ticks


# --- Lightning ----------------------------------------------------------------------------------------------------
## Fork: the reach of a Lightning chain beam (`spec.reach_m`, longer at Lv 2 or more).
static func fork_reach(w: World, spec: AttackSpec) -> float:
	if spec.effect_id != STORM_ID or level(w, STORM) < LV_2:
		return spec.reach_m
	return spec.reach_m + card(w, STORM).el_fork_range_m


## Fork: the jumps of a Lightning chain beam (`spec.chains`, one more at Lv 2 or more).
static func fork_chains(w: World, spec: AttackSpec) -> int:
	if spec.effect_id != STORM_ID or level(w, STORM) < LV_2:
		return spec.chains
	return spec.chains + card(w, STORM).el_fork_chains


## Overcharge (Attacks.run_hook, after hook `k` launched): `k` was a Lightning chain hook fired by a hit of `parent`'s
## on enemy `hit`. The el_strike_every-th such hit calls a strike on that enemy.
static func overcharge(w: World, k: AttackHook, parent: AttackContext, hit: int) -> void:
	if hit < 0 or k.child.effect_id != STORM_ID:
		return
	var t := card(w, STORM)
	if t == null or level(w, STORM) < LV_3:
		return
	w.el_chain_hits += 1
	if w.el_chain_hits % t.el_strike_every != 0 or not _room(w, true, t.el_strikes_per_second):
		return
	var a := w.actors
	var pid := a.ids[0]
	var at := a.pos(hit)
	var root := w.take_root()
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, pid, pid, a.ids[hit], at)
	e.root_id = root
	e.amount = roundi(t.el_strike_radius_m * 1000.0)
	e.effect_id = SimEvent.EFFECT_STORM_STRIKE
	var dmg := maxi(1, parent.base_damage * t.el_strike_permille / 1000)
	for j in w.enemies_near(at, t.el_strike_radius_m):
		Damage.hit(
			w,
			j,
			dmg,
			pid,
			pid,
			root,
			SimEvent.TAG_AREA,
			at,
			a.pos(j),
			SimEvent.EFFECT_STORM_STRIKE,
			50
		)


# --- Hits ---------------------------------------------------------------------------------------------------------
## The hero's hit on enemy `target`: Heat sync (it burns) and Frostbite (it is frozen), per mille, 1000 for neither.
static func attacker_mult(w: World, target: int, owner_id: int) -> int:
	var a := w.actors
	if target == 0 or owner_id != a.ids[0]:
		return 1000
	var m := 1000
	if a.burn_stacks[target] > 0 and level(w, FIRE) >= LV_3:
		m = m * (1000 + card(w, FIRE).el_heat_permille) / 1000
	if a.frozen_t[target] > 0 and level(w, FROST) >= LV_2:
		m = m * (1000 + card(w, FROST).el_frostbite_permille) / 1000
	return m


## Shatter (Damage.hit, after a landed hero hit that found `target` frozen): the hit's `dmg` (tags, effect). The
## freeze breaks and up to el_shard_count of the nearest other enemies within reach take a shard each.
static func shatter(w: World, target: int, dmg: int, tags: int, effect_id: StringName) -> void:
	var a := w.actors
	if (
		tags & (SimEvent.TAG_SHRAPNEL | SimEvent.TAG_DOT)
		or effect_id == SimEvent.EFFECT_FROST_SHARD
	):
		return
	if level(w, FROST) < LV_3:
		return
	var t := card(w, FROST)
	if not _room(w, false, t.el_shatters_per_second):
		return
	a.frozen_t[target] = 0
	var pid := a.ids[0]
	var from := a.pos(target)
	var root := w.take_root()
	var picked := Engines.nearest_enemies(w, target, from, t.el_shard_range_m, t.el_shard_count)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, pid, pid, a.ids[target], from)
	e.root_id = root
	e.amount = picked.size()
	e.effect_id = SimEvent.EFFECT_FROST_SHATTER
	var shard := maxi(1, dmg * t.el_shard_permille / 1000)
	for j in picked:
		var s := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[target], pid, a.ids[j], a.pos(j))
		s.root_id = root
		s.amount = shard
		s.effect_id = SimEvent.EFFECT_FROST_SHARD
		Damage.hit(
			w,
			j,
			shard,
			pid,
			pid,
			w.take_root(),
			SimEvent.TAG_SHRAPNEL,
			from,
			a.pos(j),
			SimEvent.EFFECT_FROST_SHARD,
			50
		)
		if a.dead[j] == 0:
			a.slow_t[j] = maxi(a.slow_t[j], t.el_shard_slow_ticks)


## One more strike (or shatter) fits in the last second: the budget's log forgets older ones; true (and counted) if it
## held fewer than `per_second`.
static func _room(w: World, strike: bool, per_second: int) -> bool:
	var log := w.el_strike_log if strike else w.el_shatter_log
	while not log.is_empty() and log[0] <= w.tick - WINDOW:
		log.remove_at(0)
	var ok := log.size() < per_second
	if ok:
		log.append(w.tick)
	if strike:
		w.el_strike_log = log
	else:
		w.el_shatter_log = log
	return ok


## The counts and budgets (ModifierRuntime.hash_into): hashed only while Lightning or Frost runs at Lv 3.
static func hash_into(w: World, h: StateHasher) -> void:
	if level(w, STORM) >= LV_3 or level(w, FROST) >= LV_3:
		h.add_int(w.el_chain_hits)
		h.add_ints(w.el_strike_log)
		h.add_ints(w.el_shatter_log)
