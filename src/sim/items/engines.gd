# gdlint: disable=max-public-methods
class_name Engines
extends RefCounted
## Engines and named combos (v0.3.0 PLAN L8, step G; BLUEPRINT §D). Statuses that stack and come back every fight:
## burn (Ember Edge, Cinder Shot, Wildfire), shock (Static Chain, Overcharge, Conductor: at the threshold it
## discharges a chain and resets), bleed (Serrated Edge, Barbed Bolts: a DoT; a dash through the enemy bursts every
## stack), frost (Frost Core, Glacial Edge, Cold Snap: at the threshold it freezes, never a freeze-immune actor) and
## guard charges (Bulwark: guard blocks store charges, the next swing spends them). Owning both items of a combo
## (ComboTable) adds its effect.
##
## The loop rules (SIM_CONTRACTS §7–§8), all enforced here:
## - DoT never procs: tick_dot emits DAMAGE only, and on_hit ignores DOT; payoff hits (PAYOFFS) never add stacks.
## - Each effect fires at most once per root chain (ProcLedger; per target for status payoffs, like Ember Edge).
## - Ancestry: a payoff runs between begin() and end(); begin() refuses an effect already in the running chain.
## - Watchdog: a chain deeper than MAX_DEPTH, or a tick past MAX_EVENTS_PER_TICK events, stops with one LIMIT event.
## Every hook is a no-op when no owned item feeds it, so worlds without these items keep their behaviour.

const MAX_DEPTH := 8
const MAX_EVENTS_PER_TICK := 512

const EFFECT_CINDER_SHOT := &"cinder_shot"
const EFFECT_WILDFIRE := &"wildfire"
const EFFECT_SHOCK := &"shock"
const EFFECT_DISCHARGE := &"shock_discharge"
const EFFECT_BLEED := &"bleed"
const EFFECT_BLEED_BURST := &"bleed_burst"
const EFFECT_FROST := &"frost"
const EFFECT_FREEZE := &"freeze"
const EFFECT_COLD_SNAP := &"cold_snap"
const EFFECT_BULWARK := &"bulwark"
const EFFECT_PLASMA_ARC := &"plasma_arc"
const EFFECT_SHATTER_DASH := &"shatter_dash"
const EFFECT_RESONANCE := &"resonance"
const EFFECT_SHRAPNEL_STORM := &"shrapnel_storm"
const EFFECT_BLOOD_HARVEST := &"blood_harvest"
const EFFECT_SPIKED_PHASE := &"spiked_phase"
const EFFECT_SLIPSTREAM := &"slipstream"
const EFFECT_FROZEN_BASTION := &"frozen_bastion"

## Payoff hits: they never add stacks (so no engine feeds itself or another through its own payoff).
const PAYOFFS: Array[StringName] = [
	EFFECT_DISCHARGE,
	EFFECT_BLEED_BURST,
	EFFECT_PLASMA_ARC,
	EFFECT_SHATTER_DASH,
	EFFECT_BLOOD_HARVEST,
	&"heat_vent",  # Heat.EFFECT_VENT (v0.3.0 L18)
	&"meltdown",  # Heat.EFFECT_MELTDOWN
]

## ProcLedger codes (appended, never renumbered: they are hashed). Stack feeds use CODE_FEED + source.
const CODE_FEED_BURN := 0
const CODE_FEED_SHOCK := 8
const CODE_FEED_BLEED := 16
const CODE_FEED_FROST := 24
const CODE_DISCHARGE := 32
const CODE_PLASMA := 33
const CODE_SHATTER := 34
const CODE_BURST := 35
const CODE_WILDFIRE := 36
const CODE_RESONANCE := 37
const CODE_SHRAPNEL := 38
const CODE_BLOOD := 39
const CODE_SPIKED := 40

## What made a hit (on_hit): a swing (or its echo), a landed bolt, a Static Chain jump, a shockwave.
const SRC_NONE := 0
const SRC_MELEE := 1
const SRC_BOLT := 2
const SRC_CHAIN := 3
const SRC_WAVE := 4
## v0.5.0 CP: an Orbit Blades touch (Razor Orbit feeds bleed from it).
const SRC_ORBIT := 5


# --- Combos ---------------------------------------------------------------------------------------------------
## The combo with this ComboTable.Effect is unlocked.
static func has_combo(w: World, effect: int) -> bool:
	return (w.combo_mask & (1 << effect)) != 0


## The unlocked combo with this effect (null if none).
static func combo(w: World, effect: int) -> ComboTable:
	for c in w.combos_owned:
		if w.combo_tables[c].effect == effect:
			return w.combo_tables[c]
	return null


## Combos whose two items are both owned, in combo-table order.
static func combos_for(tables: Array[ComboTable], owned: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in tables.size():
		if tables[c].item_a < 0:  # v0.4.0 AB: an ability combo (AbilityCombos.earned)
			continue
		if owned.has(tables[c].item_a) and owned.has(tables[c].item_b):
			out.append(c)
	return out


# --- Ancestry and the watchdog --------------------------------------------------------------------------------
## Opens a payoff of `effect` in the running chain. False (and the payoff must not run) if `effect` is already in
## the chain (ancestry), or the watchdog trips: then one LIMIT event names the effect (amount = the chain depth).
static func begin(w: World, effect: StringName) -> bool:
	if effect in w.engine_chain:
		return false
	var deep := w.engine_chain.size() >= MAX_DEPTH
	if deep or w.last_event_seq() - w.tick_seq0 >= MAX_EVENTS_PER_TICK:
		var pid := w.actors.ids[0]
		var lim := w.emit_event(SimEvent.Kind.LIMIT, pid, pid, pid, w.player_pos())
		lim.effect_id = effect
		lim.depth = w.engine_chain.size()
		lim.amount = w.engine_chain.size() if deep else MAX_EVENTS_PER_TICK
		lim.ancestry = w.engine_chain.duplicate()
		return false
	w.engine_chain.append(effect)
	return true


static func end(w: World) -> void:
	w.engine_chain.remove_at(w.engine_chain.size() - 1)


# --- Feeding the statuses -------------------------------------------------------------------------------------
## A player hit landed on enemy `i` (Damage.hit, got > 0). Adds the stacks its source feeds, once per
## (root, status, source, target). v0.6.0 MX1: a melee hit feeds the current combo step spec's statuses (shock,
## bleed, frost; its burn is ItemEffects.on_melee_hit's), a projectile hit the bolt spec's (each every N landed
## bolts); the other sources keep their items' numbers.
static func on_hit(w: World, i: int, root: int, tags: int, effect_id: StringName) -> void:
	var a := w.actors
	if a.dead[i] == 1 or tags & SimEvent.TAG_DOT or effect_id in PAYOFFS:
		return
	var m := w.item_mods
	var src := source_of(tags, effect_id)
	var burn := 0
	var shock := 0
	var bleed := 0
	var frost := 0
	match src:
		SRC_MELEE:
			var sp := Modifiers.step(w, w.combo_step)
			shock = sp.stacks_of(&"shock")
			bleed = sp.stacks_of(&"bleed")
			frost = sp.stacks_of(&"frost")
		SRC_BOLT:
			var b := Modifiers.bolt(w)
			var fed := 0
			for st: StringName in [&"burn", &"shock", &"bleed", &"frost"]:
				fed += b.stacks_of(st)
			if fed > 0:
				w.engine_bolt_hits += 1
				var n := w.engine_bolt_hits
				burn = b.stacks_of(&"burn") if _every(n, b.every_of(&"burn")) else 0
				shock = b.stacks_of(&"shock") if _every(n, b.every_of(&"shock")) else 0
				bleed = b.stacks_of(&"bleed") if _every(n, b.every_of(&"bleed")) else 0
				frost = b.stacks_of(&"frost") if _every(n, b.every_of(&"frost")) else 0
		SRC_CHAIN:
			shock = m.shock_chain
		SRC_WAVE:
			shock = m.shock_wave
		SRC_ORBIT:
			bleed = m.bleed_orbit
	var id := a.ids[i]
	if burn > 0 and w.proc_ledger.try_mark(root, CODE_FEED_BURN + src, id, w.tick):
		add_burn(w, i, burn, root, EFFECT_CINDER_SHOT)
	if bleed > 0 and w.proc_ledger.try_mark(root, CODE_FEED_BLEED + src, id, w.tick):
		add_bleed(w, i, bleed, root)
	if frost > 0 and w.proc_ledger.try_mark(root, CODE_FEED_FROST + src, id, w.tick):
		add_frost(w, i, frost, root, EFFECT_FROST)
	if shock > 0 and w.proc_ledger.try_mark(root, CODE_FEED_SHOCK + src, id, w.tick):
		add_shock(w, i, shock, root)


static func source_of(tags: int, effect_id: StringName) -> int:
	if tags & SimEvent.TAG_DASH:
		return SRC_NONE
	if tags & SimEvent.TAG_CHAIN:
		return SRC_CHAIN
	if effect_id == ItemEffects.EFFECT_OVERCHARGE or effect_id == EFFECT_RESONANCE:
		return SRC_WAVE
	if effect_id == Abilities.EFFECT_ORBIT:
		return SRC_ORBIT
	if tags & SimEvent.TAG_MELEE:
		return SRC_MELEE
	if tags & SimEvent.TAG_PROJECTILE:
		return SRC_BOLT
	return SRC_NONE


## The n-th landed bolt applies a status fed every `every` bolts (0: every bolt; v0.5's feeders all had one).
static func _every(n: int, every: int) -> bool:
	return every <= 0 or n % every == 0


## Adds burn stacks (capped, the burn refreshed); the Ember Edge DoT ticks them (ItemEffects.tick_burns).
static func add_burn(w: World, i: int, n: int, root: int, effect: StringName) -> void:
	var a := w.actors
	var m := w.item_mods
	if m.burn_max_stacks <= 0 or a.dead[i] == 1 or n <= 0:
		return
	if a.burn_stacks[i] == 0:
		a.burn_cd[i] = m.burn_period_ticks
	a.burn_stacks[i] = mini(a.burn_stacks[i] + n, m.burn_max_stacks)
	a.burn_t[i] = m.burn_duration_ticks
	_status(w, i, root, a.burn_stacks[i], effect)


## Adds shock stacks (capped at the threshold, refreshed). Plasma Arc: shocking a burning enemy arcs. At the
## threshold the enemy discharges.
static func add_shock(w: World, i: int, n: int, root: int) -> void:
	var a := w.actors
	var m := w.item_mods
	if m.shock_threshold <= 0 or a.dead[i] == 1 or n <= 0:
		return
	a.shock_stacks[i] = mini(a.shock_stacks[i] + n, m.shock_threshold)
	a.shock_t[i] = m.shock_ticks
	_status(w, i, root, a.shock_stacks[i], EFFECT_SHOCK)
	if a.burn_stacks[i] > 0 and has_combo(w, ComboTable.Effect.PLASMA_ARC):
		plasma_arc(w, i, root)
	if a.shock_stacks[i] >= m.shock_threshold:
		discharge(w, i, root)


## Shock at the threshold: the enemy takes shock_damage and the charge jumps to up to shock_jumps other enemies
## (nearest first) within shock_range_m of it, shock_damage each; its stacks reset. Once per root per enemy (if
## spent, the stacks wait at the threshold for the next feed).
static func discharge(w: World, i: int, root: int) -> void:
	var a := w.actors
	var m := w.item_mods
	if not w.proc_ledger.try_mark(root, CODE_DISCHARGE, a.ids[i], w.tick):
		return
	if not begin(w, EFFECT_DISCHARGE):
		return
	a.shock_stacks[i] = 0
	a.shock_t[i] = 0
	var at := a.pos(i)
	var jumps := nearest_enemies(w, i, at, m.shock_range_m, m.shock_jumps)
	w.discharge_tick = w.tick
	w.discharge_from = at
	w.discharge_to = PackedVector2Array()
	for j in jumps:
		w.discharge_to.append(a.pos(j))
	var pid := a.ids[0]
	Damage.hit(w, i, m.shock_damage, pid, pid, root, SimEvent.TAG_CHAIN, at, at, EFFECT_DISCHARGE)
	for j in jumps:
		Damage.hit(
			w, j, m.shock_damage, pid, pid, root, SimEvent.TAG_CHAIN, at, a.pos(j), EFFECT_DISCHARGE
		)
	end(w)


## Adds bleed stacks (capped, refreshed); tick_statuses deals the DoT.
static func add_bleed(w: World, i: int, n: int, root: int) -> void:
	var a := w.actors
	var m := w.item_mods
	if m.bleed_max_stacks <= 0 or a.dead[i] == 1 or n <= 0:
		return
	if a.bleed_stacks[i] == 0:
		a.bleed_cd[i] = m.bleed_period_ticks
	a.bleed_stacks[i] = mini(a.bleed_stacks[i] + n, m.bleed_max_stacks)
	a.bleed_t[i] = m.bleed_ticks
	_status(w, i, root, a.bleed_stacks[i], EFFECT_BLEED)


## Adds frost stacks (refreshed; each one also chills: the slow runs). No stacks build while frozen. At the
## threshold the enemy freezes for freeze_ticks and its stacks reset, unless it is freeze-immune (a boss): then
## its stacks stop one short and it stays slowed.
static func add_frost(w: World, i: int, n: int, root: int, effect: StringName) -> void:
	var a := w.actors
	var m := w.item_mods
	if m.frost_threshold <= 0 or a.dead[i] == 1 or n <= 0 or a.frozen_t[i] > 0:
		return
	a.frost_stacks[i] += n
	a.frost_t[i] = m.frost_ticks
	if m.slow_ticks > 0:
		a.slow_t[i] = maxi(a.slow_t[i], m.slow_ticks)
	if a.frost_stacks[i] >= m.frost_threshold:
		if freeze_immune(w, i):
			a.frost_stacks[i] = m.frost_threshold - 1
		else:
			a.frost_stacks[i] = 0
			a.frost_t[i] = 0
			a.frozen_t[i] = m.freeze_ticks
			_status(w, i, root, m.freeze_ticks, EFFECT_FREEZE)
			return
	_status(w, i, root, a.frost_stacks[i], effect)


## Actor i is frozen (EnemyAi skips it; ItemProcs.slow_factor is 0).
static func frozen(w: World, i: int) -> bool:
	return w.actors.frozen_t[i] > 0


## Actor i never freezes (frost only slows it). Bosses set ActorStore.freeze_immune when they are added.
static func freeze_immune(w: World, i: int) -> bool:
	return w.actors.freeze_immune[i] == 1


static func _status(w: World, i: int, root: int, amount: int, effect: StringName) -> void:
	var a := w.actors
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[i], a.pos(i))
	e.root_id = root
	e.amount = amount
	e.effect_id = effect
	e.depth = w.engine_chain.size()
	e.ancestry = w.engine_chain.duplicate()


## Tick phase 8: shock and frost fade when not renewed, bleed ticks its DoT (its own root, proc 0), freezes run
## down; old ledger records go.
static func tick_statuses(w: World) -> void:
	var a := w.actors
	var m := w.item_mods
	for i in range(1, a.size()):
		if a.shock_stacks[i] > 0:
			a.shock_t[i] -= 1
			if a.shock_t[i] <= 0:
				a.shock_stacks[i] = 0
		if a.bleed_stacks[i] > 0:
			a.bleed_t[i] -= 1
			a.bleed_cd[i] -= 1
			if a.bleed_cd[i] <= 0:
				a.bleed_cd[i] = m.bleed_period_ticks
				Damage.tick_dot(
					w, i, m.bleed_damage * a.bleed_stacks[i], a.ids[0], a.ids[0], EFFECT_BLEED
				)
			if a.bleed_t[i] <= 0:
				a.bleed_stacks[i] = 0
				a.bleed_cd[i] = 0
		if a.frost_stacks[i] > 0:
			a.frost_t[i] -= 1
			if a.frost_t[i] <= 0:
				a.frost_stacks[i] = 0
		if a.frozen_t[i] > 0:
			a.frozen_t[i] -= 1
	w.proc_ledger.prune(w.tick)


## Up to `n` living enemies other than `skip` whose centre is within `reach` of `at`, nearest first (ties go to the
## lower index).
static func nearest_enemies(
	w: World, skip: int, at: Vector2, reach: float, n: int
) -> PackedInt32Array:
	var a := w.actors
	var picked := PackedInt32Array()
	var dists := PackedFloat32Array()
	for j in range(1, a.size()):
		if j == skip or a.teams[j] == ActorStore.TEAM_PLAYER or a.dead[j] == 1:
			continue
		var d := Kin.length(a.pos(j) - at)
		if d > reach:
			continue
		var k := 0
		while k < picked.size() and dists[k] <= d:
			k += 1
		picked.insert(k, j)
		dists.insert(k, d)
	return picked.slice(0, n)


# --- Damage modifiers -----------------------------------------------------------------------------------------
## Cold Snap's attacker multiplier (per mille) for the player's hit on enemy `target`: frozen, chilled (frost
## stacks) or neither.
static func attacker_mult(w: World, target: int, owner_id: int) -> int:
	var m := w.item_mods
	var a := w.actors
	if m.chill_bonus_permille <= 0 or target == 0 or owner_id != a.ids[0]:
		return 1000
	if a.frozen_t[target] > 0:
		return 1000 + m.frozen_bonus_permille
	if a.frost_stacks[target] > 0:
		return 1000 + m.chill_bonus_permille
	return 1000


# --- Guard charges (Bulwark) ----------------------------------------------------------------------------------
## The guard reduced a hit from `owner_id` (root `root`): store a charge; Frozen Bastion chills the attacker.
static func on_guard_block(w: World, owner_id: int, root: int) -> void:
	var a := w.actors
	if w.player_dead():
		return
	var cap := Abilities.charge_max(w)  # v0.4.0 BS: Aegis stores charges like Bulwark
	if cap > 0 and w.guard_charges < cap:
		w.guard_charges += 1
		_status(w, 0, root, w.guard_charges, EFFECT_BULWARK)
	AbilityCombos.on_guard_block(w, root)  # v0.4.0 AB: Ember Ward
	var c := combo(w, ComboTable.Effect.FROZEN_BASTION)
	var k := a.index_of(owner_id)
	if c == null or k <= 0 or a.dead[k] == 1 or a.teams[k] == ActorStore.TEAM_PLAYER:
		return
	if Kin.length(a.pos(k) - w.player_pos()) > c.radius_m:
		return
	if begin(w, EFFECT_FROZEN_BASTION):
		w.bastion_tick = w.tick
		add_frost(w, k, c.stacks, root, EFFECT_FROZEN_BASTION)
		end(w)


## A swing starts: it takes every stored guard charge.
static func on_swing_start(w: World) -> void:
	w.swing_charges = w.guard_charges
	w.guard_charges = 0


## A swing's damage with the guard charges it took: × (1 + charges × bonus / 1000).
static func charged_damage(w: World, dmg: int) -> int:
	if w.swing_charges <= 0:
		return dmg
	return dmg * (1000 + w.swing_charges * Abilities.charge_bonus(w)) / 1000


# --- Dash passes (bleed burst, Cold Snap, Shatter Dash) -------------------------------------------------------
## A dash through enemies matters to some owned item (ItemEffects.dash_hits then tracks passes without Kinetic Dash).
static func dash_wants(w: World) -> bool:
	var m := w.item_mods
	return m.bleed_burst_per_stack > 0 or m.frost_dash > 0


## The dash (root w.dash_root) went through enemy `i` (once per dash), after Kinetic Dash's hit: Shatter Dash breaks
## a frozen enemy, a bleeding enemy bursts every stack, Cold Snap chills it.
static func on_dash_pass(w: World, i: int) -> void:
	var a := w.actors
	var m := w.item_mods
	var root := w.dash_root
	var pid := a.ids[0]
	var c := combo(w, ComboTable.Effect.SHATTER_DASH)
	if c != null and a.dead[i] == 0 and a.frozen_t[i] > 0:
		if w.proc_ledger.try_mark(root, CODE_SHATTER, a.ids[i], w.tick):
			if begin(w, EFFECT_SHATTER_DASH):
				a.frozen_t[i] = 0
				w.shatter_tick = w.tick
				w.shatter_pos = a.pos(i)
				var tags := SimEvent.TAG_DASH | SimEvent.TAG_AREA
				Damage.hit(
					w, i, c.damage, pid, pid, root, tags, a.pos(i), a.pos(i), EFFECT_SHATTER_DASH
				)
				end(w)
	if m.bleed_burst_per_stack > 0 and a.dead[i] == 0 and a.bleed_stacks[i] > 0:
		if w.proc_ledger.try_mark(root, CODE_BURST, a.ids[i], w.tick):
			if begin(w, EFFECT_BLEED_BURST):
				var dmg := a.bleed_stacks[i] * m.bleed_burst_per_stack
				a.bleed_stacks[i] = 0
				a.bleed_t[i] = 0
				a.bleed_cd[i] = 0
				w.burst_tick = w.tick
				w.burst_pos = a.pos(i)
				Damage.hit(
					w,
					i,
					dmg,
					pid,
					pid,
					root,
					SimEvent.TAG_DASH,
					a.pos(i),
					a.pos(i),
					EFFECT_BLEED_BURST
				)
				end(w)
	if m.frost_dash > 0 and a.dead[i] == 0:
		if w.proc_ledger.try_mark(root, CODE_FEED_FROST + SRC_NONE, a.ids[i], w.tick):
			add_frost(w, i, m.frost_dash, root, EFFECT_COLD_SNAP)


# --- Kills (Wildfire, Blood Harvest) --------------------------------------------------------------------------
## The player killed enemy `i` (`kill` is its KILL event, `tags` the killing hit's): Wildfire spreads burn from it;
## Blood Harvest turns an Executioner kill into a blood nova that heals.
static func on_kill(w: World, kill: SimEvent, i: int, tags: int) -> void:
	var m := w.item_mods
	var a := w.actors
	var root := kill.root_id
	if m.wildfire_stacks > 0 and w.proc_ledger.try_mark(root, CODE_WILDFIRE, a.ids[i], w.tick):
		if begin(w, EFFECT_WILDFIRE):
			var n := m.wildfire_stacks + a.burn_stacks[i] / 2
			var at := a.pos(i)
			w.wildfire_tick = w.tick
			w.wildfire_pos = at
			for j in range(1, a.size()):
				if j == i or a.teams[j] == ActorStore.TEAM_PLAYER or a.dead[j] == 1:
					continue
				if AttackShapes.disc_touches(at, m.wildfire_radius_m, a.pos(j), a.radius[j]):
					add_burn(w, j, n, root, EFFECT_WILDFIRE)
			end(w)
	var c := combo(w, ComboTable.Effect.BLOOD_HARVEST)
	if c == null or not tags & SimEvent.TAG_EXECUTE:
		return
	if (
		not w.proc_ledger.try_mark(root, CODE_BLOOD, 0, w.tick)
		or not begin(w, EFFECT_BLOOD_HARVEST)
	):
		return
	var center := a.pos(i)
	var pid := a.ids[0]
	w.harvest_tick = w.tick
	w.harvest_pos = center
	for j in range(1, a.size()):
		if j == i or a.teams[j] == ActorStore.TEAM_PLAYER or a.dead[j] == 1:
			continue
		if AttackShapes.disc_touches(center, c.radius_m, a.pos(j), a.radius[j]):
			Damage.hit(
				w,
				j,
				c.damage,
				pid,
				pid,
				root,
				SimEvent.TAG_AREA,
				center,
				a.pos(j),
				EFFECT_BLOOD_HARVEST
			)
	_harvest_heal(w, c.heal, kill)
	end(w)


## Blood Harvest's heal, inside Vampiric Core's per-window cap (the same ledger as its kill heal). The HEAL event
## logs the request and what was applied.
static func _harvest_heal(w: World, heal: int, kill: SimEvent) -> void:
	var m := w.item_mods
	var a := w.actors
	if w.player_dead():
		return
	if w.heal_window_start < 0 or w.tick - w.heal_window_start >= m.heal_window_ticks:
		w.heal_window_start = w.tick
		w.heal_window_used = 0
	var cap_left := maxi(0, m.heal_cap - w.heal_window_used)
	var applied := maxi(0, mini(heal, mini(cap_left, a.max_hp[0] - a.hp[0])))
	a.hp[0] += applied
	w.heal_window_used += applied
	if applied > 0:
		w.heal_tick = w.tick
	var h := w.emit_event(SimEvent.Kind.HEAL, a.ids[0], a.ids[0], a.ids[0], w.player_pos())
	h.root_id = kill.root_id
	h.parent_seq = kill.seq
	h.depth = kill.depth + 1
	h.amount = heal
	h.amount_applied = applied
	h.effect_id = EFFECT_BLOOD_HARVEST
	h.ancestry = w.engine_chain.duplicate()


# --- Combo payoffs on other items' moments --------------------------------------------------------------------
## Plasma Arc: shocking burning enemy `i` arcs to the nearest other enemy within reach: damage and burn stacks.
static func plasma_arc(w: World, i: int, root: int) -> void:
	var a := w.actors
	var c := combo(w, ComboTable.Effect.PLASMA_ARC)
	if not w.proc_ledger.try_mark(root, CODE_PLASMA, a.ids[i], w.tick):
		return
	var to := nearest_enemies(w, i, a.pos(i), c.radius_m, 1)
	if to.is_empty() or not begin(w, EFFECT_PLASMA_ARC):
		return
	var j := to[0]
	var pid := a.ids[0]
	w.plasma_tick = w.tick
	w.plasma_from = a.pos(i)
	w.plasma_to = a.pos(j)
	Damage.hit(
		w, j, c.damage, pid, pid, root, SimEvent.TAG_CHAIN, a.pos(i), a.pos(j), EFFECT_PLASMA_ARC
	)
	add_burn(w, j, c.stacks, root, EFFECT_PLASMA_ARC)
	end(w)


## Resonance: the Twin Arc echo of an Overcharge swing (root `root`) sends a second shockwave.
static func on_echo(w: World, root: int) -> void:
	var c := combo(w, ComboTable.Effect.RESONANCE)
	if c == null or not w.echo_overcharged:
		return
	if not w.proc_ledger.try_mark(root, CODE_RESONANCE, 0, w.tick):
		return
	if begin(w, EFFECT_RESONANCE):
		w.resonance_tick = w.tick
		var dmg := maxi(1, w.echo_wave * c.share_permille / 1000)
		ItemEffects.shockwave(w, dmg, root, EFFECT_RESONANCE)
		end(w)


## Shrapnel Storm: player bolt `pi` just bounced: it bursts into `count` shards fanned around its new heading
## (once per bolt; shards never burst again and never bounce).
static func on_bounce(w: World, pi: int) -> void:
	var p := w.projectiles
	var c := combo(w, ComboTable.Effect.SHRAPNEL_STORM)
	if c == null or p.team[pi] != ActorStore.TEAM_PLAYER or p.tags[pi] & SimEvent.TAG_SHRAPNEL:
		return
	if not w.proc_ledger.try_mark(p.root_id[pi], CODE_SHRAPNEL, 0, w.tick):
		return
	if not begin(w, EFFECT_SHRAPNEL_STORM):
		return
	var v := Vector2(p.vel_x[pi], p.vel_y[pi])
	var speed := Kin.length(v)
	var heading := Kin.angle_of(v)
	var at := Vector2(p.pos_x[pi], p.pos_y[pi])
	var dmg := maxi(1, p.damage[pi] * c.share_permille / 1000)
	var half := c.spread / 2
	w.shrapnel_tick = w.tick
	for k in c.count:
		var off := 0 if c.count == 1 else -half + 2 * half * k / (c.count - 1)
		w.queue_projectile(
			p.owner[pi],
			ActorStore.TEAM_PLAYER,
			at,
			Kin.dir(heading + off) * speed,
			dmg,
			p.radius[pi],
			maxi(1, w.player.bolt_life_ticks / 2),
			SimEvent.TAG_PROJECTILE | SimEvent.TAG_SHRAPNEL
		)
	end(w)


## Spiked Phase: a Phase Strike discharge (root `root`) also releases the Thorn Mantle ring.
static func on_phase(w: World, root: int) -> void:
	var c := combo(w, ComboTable.Effect.SPIKED_PHASE)
	if c == null or w.item_mods.thorn_bolts <= 0:
		return
	if w.proc_ledger.try_mark(root, CODE_SPIKED, 0, w.tick) and begin(w, EFFECT_SPIKED_PHASE):
		w.spiked_tick = w.tick
		ItemProcs.thorn_ring(w)
		end(w)


## Slipstream: a Momentum swing that landed refunds the dash at once, at most once per window.
static func after_swing(w: World, landed: bool) -> void:
	var c := combo(w, ComboTable.Effect.SLIPSTREAM)
	if c == null or not landed or not w.swing_momentum or w.tick < w.slipstream_next:
		return
	w.dash_cooldown_left = 0
	w.slipstream_next = w.tick + c.window_ticks
	w.slipstream_tick = w.tick
	_status(w, 0, w.swing_root, c.window_ticks, EFFECT_SLIPSTREAM)
