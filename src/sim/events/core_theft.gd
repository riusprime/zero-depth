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
## - v0.9.5 BH1 (owner Q3): a boss never staggers. Its window opens at each phase change instead (BossGates.begin: the
##   boss kneels), and lasts rules.core_window_ticks (3 s) from that tick; the window needs the target alive.
## - v0.9.0 EL (owner Q25: "you have a 30% chance of dropping the core"; "no stagger window"): an elite (an archetype,
##   Elites) no longer staggers and has no window: killed, it drops its core's card with the elite rules' chance
##   (Elites.on_death). Marked (C8) and its rare card are gone with the curse.
## - A core whose card no longer applies when it drops (a mod you took meanwhile, a stat at its cap; v0.8.0 FL: a
##   wand card that reached the floor's level ceiling meanwhile, Shop.can_apply) is redrawn from the same pool on
##   `loot:event`. v0.8.0 FL: an elite's mod weighs core_mod_weight × the floor stage's category multiplier.
## Cores exist only in worlds with the event rules (World.ev.rng_elite), so older worlds keep their hashes.

const EFFECT_STAGGER := &"core_stagger"
const EFFECT_STEAL := &"core_steal"


static func enabled(w: World) -> bool:
	return w.ev.rng_elite != null


## Elites.spawn (v0.9.0 EL): elite actor i takes a core.
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
	var paced := w.loot_pacing != null  # v0.8.0 FL: × the floor stage's category multiplier (per mille)
	var stat_scale := 1000 if paced else 1
	for idx in ItemPool.available(w):
		codes.append(idx)
		var base := w.ev.rules.core_mod_weight
		weights.append(LootPacing.weigh(w, idx, base * 1000) if paced else base)
	for s in w.stat_tables.size():
		var t := w.stat_tables[s]
		if t == null or t.weight <= 0 or Stats.at_cap(w, s):
			continue
		codes.append(Offers.stat_code(s, rarity))
		weights.append(t.weight * stat_scale)
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


## v0.9.0 EL (old saves, WorldSnapshot.apply): a core on an actor that is neither a boss nor an elite archetype (a
## ×2 HP elite of a save made before EL: a normal enemy now, its extra HP kept) is dropped, with its stagger and window.
static func drop_plain(w: World) -> void:
	var s := w.cores
	for k in range(s.size() - 1, -1, -1):
		var i := w.actors.index_of(s.ids[k])
		if s.boss[k] == 0 and (i < 0 or not EliteAi.is_elite_kind(w.actors.kinds[i])):
			s.remove_at(k)


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


## v0.9.5 BH1 (H1, Q3): BossGates.begin, as boss `target` kneels at a phase change: its core's steal window opens for
## rules.core_window_ticks (3.0 s as shipped) from this tick. A boss without a core opens nothing. (Before BH1 a
## stagger opened it; bosses no longer stagger.) An elite's core has no window (v0.9.0 EL, Q25).
static func on_phase_change(w: World, target: int) -> void:
	if w.cores.ids.is_empty():
		return
	var k := entry_of(w, w.actors.ids[target])
	if k < 0 or w.actors.dead[target] == 1 or w.cores.boss[k] == 0:
		return
	_open(w, k, target)


static func _open(w: World, k: int, target: int) -> void:
	w.cores.window_t[k] = w.ev.rules.core_window_ticks
	w.cores.window_tick = w.tick
	w.cores.window_id = w.actors.ids[target]


## World._remove_dead (tick phase 9), as actor i leaves: inside its window a boss's core drops (grant). v0.9.0 EL:
## an elite's chance is Elites.on_death's.
static func on_death(w: World, i: int) -> void:
	if not enabled(w):
		return
	var a := w.actors
	var k := entry_of(w, a.ids[i])
	if k >= 0 and w.cores.window_t[k] > 0:
		var code := w.cores.card[k]
		var boss := w.cores.boss[k] == 1
		if not Shop.can_apply(w, code):  # the shop's rule, the one rule (audit G-6)
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
