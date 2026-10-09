class_name CoreTheft
extends RefCounted
## Core theft (v0.6.0 CU, PLAN v0.5.5 X2; docs/design/SIGNATURE.md "Core theft"). Elites and bosses carry a visible
## core: one card from the pool, drawn when they become an elite or rise (`ai:elite`, so no older map or loot draw
## moves). Stagger one and a steal window opens; kill it while the window is open and the core drops as a free pick
## (grant: a one-card drop, RewardStore.Kind.DROP, opened like an altar through the normal pick panel). Killed with
## the window shut, it gives only its normal drops (shards; a boss's legendary altar comes either way).
## - An elite's core: a mod still in the pool (each weighs rules.core_mod_weight) or a rare stat card under its cap
##   (its card weight). A boss's core: a card of the legendary tier (LegendaryTable: a legendary stat card or a pool
##   mod, by the tier's [stat, mod] weights).
## - An elite staggers once it took rules.core_stagger_permille of its max HP in direct damage (never DoT) since its
##   last stagger: it stands for rules.core_stagger_ticks (its attack is cancelled, it doesn't move) and the meter
##   resets. A boss staggers by its own meter (BossAi, read here, never changed). A stagger that the hit also kills
##   opens nothing: the window needs the target alive.
## - The window lasts rules.core_window_ticks from the stagger (a new stagger restarts it).
## - A core whose card no longer applies when it drops (a mod you took meanwhile, a stat at its cap) is redrawn
##   from the same pool on `loot:event`.
## - Marked (C8): a killed elite also drops a free rare card (loot:event), stolen or not.
## Cores exist only in worlds with the event rules (World.ev.rng_elite), so older worlds keep their hashes.

const EFFECT_STAGGER := &"core_stagger"
const EFFECT_STEAL := &"core_steal"


static func enabled(w: World) -> bool:
	return w.ev.rng_elite != null


## Curses.make_elite: elite actor i takes a core.
static func on_elite(w: World, i: int) -> void:
	if not enabled(w) or w.cores.ids.has(w.actors.ids[i]):
		return
	var code := draw_card(w, w.ev.rng_elite, Stats.Rarity.RARE)
	if code >= 0:
		w.cores.add(w.actors.ids[i], code, false)


## World.spawn_boss: the boss takes a legendary core (none without the legendary tier).
static func on_boss(w: World, i: int) -> void:
	if not enabled(w) or w.legendary_table == null:
		return
	var code := draw_legendary(w, w.ev.rng_elite)
	if code >= 0:
		w.cores.add(w.actors.ids[i], code, true)


## A card for a core or a drop at `rarity` (a stat card's rarity): a mod in the pool or a stat under its cap, one
## draw on `rng`; -1 when the pool is empty.
static func draw_card(w: World, rng: RngStream, rarity: int) -> int:
	var codes := PackedInt32Array()
	var weights := PackedInt32Array()
	for idx in ItemPool.available(w):
		codes.append(idx)
		weights.append(w.ev.rules.core_mod_weight)
	for s in w.stat_tables.size():
		var t := w.stat_tables[s]
		if t == null or t.weight <= 0 or Stats.at_cap(w, s):
			continue
		codes.append(Offers.stat_code(s, rarity))
		weights.append(t.weight)
	var k := Offers.pick(rng, weights)
	return codes[k] if k >= 0 else -1


## A legendary-tier card (a boss core), one or two draws on `rng`; -1 when the tier has nothing left.
static func draw_legendary(w: World, rng: RngStream) -> int:
	var t := w.legendary_table
	var stats := PackedInt32Array()
	var mods := PackedInt32Array()
	for s in t.stats:
		var st := w.stat_tables[s] if s < w.stat_tables.size() else null
		if st != null and not Stats.at_cap(w, s) and st.amounts.size() > Offers.LEGENDARY:
			stats.append(s)
	var pool := ItemPool.available(w, true)  # v0.6.0 MX4: the tier's legendary modifiers too
	for idx in t.mods:
		if pool.has(idx):
			mods.append(idx)
	var kind := Offers.pick(
		rng,
		PackedInt32Array(
			[
				t.weights[0] if not stats.is_empty() else 0,
				t.weights[1] if not mods.is_empty() else 0
			]
		)
	)
	if kind < 0:
		return -1
	if kind == 0:
		return Offers.stat_code(stats[rng.range_int(0, stats.size() - 1)], Offers.LEGENDARY)
	return mods[rng.range_int(0, mods.size() - 1)]


## The core entry of actor `id`, or -1.
static func entry_of(w: World, id: int) -> int:
	return w.cores.ids.find(id) if not w.cores.ids.is_empty() else -1


## Actor i carries a core.
static func has_core(w: World, i: int) -> bool:
	return entry_of(w, w.actors.ids[i]) >= 0


## Elite actor i stands staggered (EnemyAi skips its thinking and moving).
static func staggered(w: World, i: int) -> bool:
	var k := entry_of(w, w.actors.ids[i])
	return k >= 0 and w.cores.stagger_t[k] > 0


## Actor i's steal window is open.
static func window_open(w: World, i: int) -> bool:
	var k := entry_of(w, w.actors.ids[i])
	return k >= 0 and w.cores.window_t[k] > 0


## Damage._apply, after the boss's own stagger meter (BossAi.on_damage): direct damage on a core carrier fills an
## elite's meter, and a fresh stagger (an elite's, or a boss's) opens the steal window while it lives.
static func on_damage(w: World, target: int, applied: int, tags: int) -> void:
	if w.cores.ids.is_empty() or tags & SimEvent.TAG_DOT or applied <= 0:
		return
	var a := w.actors
	var k := entry_of(w, a.ids[target])
	if k < 0 or a.dead[target] == 1:
		return
	var s := w.cores
	if s.boss[k] == 1:
		var b := w.bosses.index_of(a.ids[target])
		if b >= 0 and w.bosses.stagger_t[b] == BossAi.table_of(w, target).stagger_ticks:
			_open(w, k, target)
		return
	if s.stagger_t[k] > 0:
		return
	s.meter[k] += applied
	if s.meter[k] * 1000 < a.max_hp[target] * w.ev.rules.core_stagger_permille:
		return
	s.meter[k] = 0
	s.stagger_t[k] = w.ev.rules.core_stagger_ticks
	a.state[target] = EnemyAi.State.MOVE  # the attack it was making is cancelled
	a.state_t[target] = 0
	a.lock_len[target] = 0.0
	var e := w.emit_event(
		SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[target], a.pos(target)
	)
	e.effect_id = EFFECT_STAGGER
	e.amount = s.stagger_t[k]
	_open(w, k, target)


static func _open(w: World, k: int, target: int) -> void:
	w.cores.window_t[k] = w.ev.rules.core_window_ticks
	w.cores.window_tick = w.tick
	w.cores.window_id = w.actors.ids[target]


## World._remove_dead (tick phase 9), as actor i leaves: inside its window its core drops (grant); Marked drops a
## rare card from any elite.
static func on_death(w: World, i: int) -> void:
	if not enabled(w):
		return
	var a := w.actors
	var k := entry_of(w, a.ids[i])
	if k >= 0 and w.cores.window_t[k] > 0:
		var code := w.cores.card[k]
		var boss := w.cores.boss[k] == 1
		if not applies(w, code):
			code = (
				draw_legendary(w, w.ev.rng) if boss else draw_card(w, w.ev.rng, Stats.Rarity.RARE)
			)
		if code >= 0:
			grant(w, code, a.pos(i), CoreState.Drop.BOSS_CORE if boss else CoreState.Drop.CORE)
			w.cores.steal_tick = w.tick
			w.cores.steal_card = code
			var e := w.emit_event(
				SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[0], a.pos(i)
			)
			e.effect_id = EFFECT_STEAL
			e.amount = code
	if Curses.is_elite(w, a.ids[i]) and Curses.elite_drops(w):
		var rare := draw_card(w, w.ev.rng, Stats.Rarity.RARE)
		if rare >= 0:
			grant(w, rare, a.pos(i), CoreState.Drop.ELITE_CARD)


## A card would still do something (a mod you don't hold, a stat under its cap).
static func applies(w: World, code: int) -> bool:
	match Offers.type_of(code):
		Offers.STAT:
			return not Stats.at_cap(w, Offers.stat_of(code))
		Offers.MOD:
			return not w.items_owned.has(code)
	return true


## THE grant (one function, so Step MX's 6-slot Swap replaces only this): a free one-card drop of `code` near `at`
## (each further drop at the same spot rules.drop_offset_m along x), opened like an altar through the pick panel.
## v0.6.0 MX2: so a stolen modifier with the six slots full asks for the Swap there (Rewards.choose, BuildSlots).
## Returns its reward id.
static func grant(w: World, code: int, at: Vector2, kind: int) -> int:
	var spot := at
	for k in w.rewards.size():
		if Kin.length(w.rewards.pos(k) - spot) < w.ev.rules.drop_offset_m * 0.5:
			spot += Vector2(w.ev.rules.drop_offset_m, 0.0)
	var id := w.add_reward(RewardStore.Kind.DROP, spot, 0)
	var r := w.rewards.index_of(id)
	w.rewards.set_offer(r, PackedInt32Array([code]))
	w.cores.drop_ids.append(id)
	w.cores.drop_kind.append(kind)
	return id


## The Drop kind of reward `id`, or -1 when it isn't a drop.
static func drop_kind(w: World, id: int) -> int:
	var k := w.cores.drop_ids.find(id)
	return w.cores.drop_kind[k] if k >= 0 else -1


## Tick phase 9, after the dead left (World.step): the gone carriers' entries go, the staggers and windows run down,
## and the drops taken leave the list.
static func advance(w: World) -> void:
	var s := w.cores
	if s.ids.is_empty() and s.drop_ids.is_empty():
		return
	for k in range(s.size() - 1, -1, -1):
		if w.actors.index_of(s.ids[k]) < 0:
			s.remove_at(k)
			continue
		if s.stagger_t[k] > 0:
			s.stagger_t[k] -= 1
		if s.window_t[k] > 0:
			s.window_t[k] -= 1
	for k in range(s.drop_ids.size() - 1, -1, -1):
		if w.rewards.index_of(s.drop_ids[k]) < 0:
			s.drop_ids.remove_at(k)
			s.drop_kind.remove_at(k)
