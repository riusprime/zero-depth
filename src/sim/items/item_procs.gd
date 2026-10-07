class_name ItemProcs
extends RefCounted
## What the second eight items do (v0.2.0 PLAN L16, step J). Same rules as ItemEffects: plain hooks until the
## full Trigger → Condition → Payoff queue (SIM_CONTRACTS §8) arrives. Every payoff carries its provenance
## (root, effect id); none fires from a DoT tick; each fires at most once per root chain where it could repeat.
## Every hook is a no-op when its item isn't owned, so scenarios without items keep their behaviour.

const EFFECT_VAMPIRIC_CORE := &"vampiric_core"
const EFFECT_STATIC_CHAIN := &"static_chain"
const EFFECT_FROST_CORE := &"frost_core"
const EFFECT_THORN_MANTLE := &"thorn_mantle"
const EFFECT_PHASE_STRIKE := &"phase_strike"


# --- Vampiric Core ------------------------------------------------------------------------------------------
## A kill the player owns (`kill` is its KILL event): heal heal_per_kill, within the per-window cap (a small
## CapLedger, SIM_CONTRACTS §8). The window opens at the first kill after the last one ran out. Only HP actually
## gained spends the cap. HEAL logs the request (amount) and what was applied; a LIMIT follows when the cap clipped.
static func on_kill(w: World, kill: SimEvent) -> void:
	var m := w.item_mods
	if m.heal_per_kill <= 0 or w.player_dead():
		return
	if w.heal_window_start < 0 or w.tick - w.heal_window_start >= m.heal_window_ticks:
		w.heal_window_start = w.tick
		w.heal_window_used = 0
	var a := w.actors
	var cap_left := m.heal_cap - w.heal_window_used
	var applied := maxi(0, mini(m.heal_per_kill, mini(cap_left, a.max_hp[0] - a.hp[0])))
	a.hp[0] += applied
	w.heal_window_used += applied
	if applied > 0:
		w.heal_tick = w.tick
	var h := w.emit_event(SimEvent.Kind.HEAL, a.ids[0], a.ids[0], a.ids[0], w.player_pos())
	h.root_id = kill.root_id
	h.parent_seq = kill.seq
	h.depth = kill.depth + 1
	h.amount = m.heal_per_kill
	h.amount_applied = applied
	h.effect_id = EFFECT_VAMPIRIC_CORE
	if cap_left < m.heal_per_kill:
		var lim := w.emit_event(SimEvent.Kind.LIMIT, a.ids[0], a.ids[0], a.ids[0], w.player_pos())
		lim.root_id = kill.root_id
		lim.parent_seq = h.seq
		lim.depth = h.depth
		lim.amount = m.heal_per_kill
		lim.amount_applied = maxi(cap_left, 0)
		lim.effect_id = EFFECT_VAMPIRIC_CORE


## HP Vampiric Core can still heal in the current window.
static func heal_cap_left(w: World) -> int:
	var m := w.item_mods
	if m.heal_per_kill <= 0:
		return 0
	if w.heal_window_start < 0 or w.tick - w.heal_window_start >= m.heal_window_ticks:
		return m.heal_cap
	return maxi(0, m.heal_cap - w.heal_window_used)


# --- Bolt hits: Static Chain and Frost Core -----------------------------------------------------------------
## Projectile `pi` hit actor `i` at `at`, removing `got` HP. Only the player's bolts count, and only landed hits
## (got > 0: a hit on a spawning enemy doesn't count). DoT never reaches here.
static func on_bolt_hit(w: World, i: int, pi: int, got: int, at: Vector2) -> void:
	if w.projectiles.team[pi] != ActorStore.TEAM_PLAYER or got <= 0:
		return
	var root := w.projectiles.root_id[pi]
	_frost(w, i, root)
	_chain(w, i, root, at)


## Frost Core: slow the enemy for slow_ticks (refreshed by each hit, never stacked).
static func _frost(w: World, i: int, root: int) -> void:
	var m := w.item_mods
	var a := w.actors
	if m.slow_ticks <= 0 or a.dead[i] == 1:
		return
	a.slow_t[i] = m.slow_ticks
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[i], a.pos(i))
	e.root_id = root
	e.amount = m.slow_permille
	e.effect_id = EFFECT_FROST_CORE


## Static Chain: every chain_every-th landed bolt jumps to the nearest other living enemy (centre within
## chain_range_m of the hit point; ties go to the lower index). At most once per root chain. If nothing is in
## range the charge is spent anyway.
static func _chain(w: World, i: int, root: int, at: Vector2) -> void:
	var m := w.item_mods
	if m.chain_every <= 0:
		return
	w.chain_count += 1
	if w.chain_count % m.chain_every != 0 or w.chain_root == root:
		return
	var a := w.actors
	var best := -1
	var best_d := m.chain_range_m
	for j in range(1, a.size()):
		if j == i or a.teams[j] == ActorStore.TEAM_PLAYER or a.dead[j] == 1:
			continue
		var d := Kin.length(a.pos(j) - at)
		if d <= best_d and (best < 0 or d < best_d):
			best = j
			best_d = d
	if best < 0:
		return
	w.chain_root = root
	w.chain_tick = w.tick
	w.chain_from = at
	w.chain_to = a.pos(best)
	Damage.hit(
		w,
		best,
		m.chain_damage,
		a.ids[0],
		a.ids[0],
		root,
		SimEvent.TAG_CHAIN,
		at,
		a.pos(best),
		EFFECT_STATIC_CHAIN
	)


## The next landed bolt will chain.
static func chain_ready(w: World) -> bool:
	var every := w.item_mods.chain_every
	return every > 0 and (w.chain_count + 1) % every == 0


## The effect id a projectile's hit carries: Thorn Mantle bolts name it, plain bolts don't.
static func bolt_effect(tags: int) -> StringName:
	if tags & SimEvent.TAG_ABILITY:  # v0.4.0 BS: a drone's bolt is the ability's, not a shot
		return Abilities.EFFECT_DRONE
	return EFFECT_THORN_MANTLE if tags & SimEvent.TAG_THORN else &""


## Frost Core: the move-speed factor for actor i (1.0 unless slowed). EnemyAi.move multiplies its speeds by it.
static func slow_factor(w: World, i: int) -> float:
	if w.actors.frozen_t[i] > 0:  # Engines: a frozen enemy doesn't move.
		return 0.0
	if w.actors.slow_t[i] <= 0:
		return 1.0
	return w.item_mods.slow_permille / 1000.0


## Phase 8: slows run down.
static func tick_slows(w: World) -> void:
	var a := w.actors
	for i in a.size():
		if a.slow_t[i] > 0:
			a.slow_t[i] -= 1


# --- Momentum -----------------------------------------------------------------------------------------------
## A dash just ended: the next swing within the window is empowered.
static func on_dash_end(w: World) -> void:
	if w.item_mods.momentum_window_ticks > 0:
		w.momentum_t = w.item_mods.momentum_window_ticks


## A swing starts: it takes the Momentum charge if one is waiting (the charge is spent even if it misses).
static func on_swing_start(w: World) -> void:
	w.swing_momentum = w.momentum_t > 0
	if w.swing_momentum:
		w.momentum_t = 0


## End of PlayerKit.advance: the window runs down (so a swing on any of its ticks qualifies).
static func advance_momentum(w: World) -> void:
	if w.momentum_t > 0:
		w.momentum_t -= 1


## A swing's damage with Momentum applied.
static func momentum_damage(w: World, dmg: int) -> int:
	if not w.swing_momentum:
		return dmg
	return dmg * (1000 + w.item_mods.momentum_bonus_permille) / 1000


# --- Thorn Mantle -------------------------------------------------------------------------------------------
## The player took damage: release a ring of thorn_bolts bolts (the player's bolt speed, size and range), the
## first one along the facing. They spawn in phase 9 like every projectile; each is its own root chain.
static func on_player_hurt(w: World) -> void:
	if w.item_mods.thorn_bolts <= 0 or w.player_dead():
		return
	thorn_ring(w)


## The Thorn Mantle ring itself (also released by Spiked Phase).
static func thorn_ring(w: World) -> void:
	var m := w.item_mods
	w.thorn_tick = w.tick
	var t := w.player
	var from := w.player_pos()
	for k in m.thorn_bolts:
		var dir := Kin.dir(w.actors.facing[0] + k * SimTick.ANGLE_UNITS / m.thorn_bolts)
		w.queue_projectile(
			w.actors.ids[0],
			ActorStore.TEAM_PLAYER,
			from + dir * (t.radius_m + t.bolt_radius_m + 0.05),
			dir * t.bolt_speed,
			m.thorn_damage,
			t.bolt_radius_m,
			t.bolt_life_ticks,
			SimEvent.TAG_PROJECTILE | SimEvent.TAG_THORN
		)


# --- Executioner --------------------------------------------------------------------------------------------
## The attacker multiplier (per mille) for a hit owned by `owner_id` on actor `target`: Executioner's bonus when
## the player hits an enemy below the threshold share of its max HP (checked before the hit lands).
static func execute_mult(w: World, target: int, owner_id: int) -> int:
	var m := w.item_mods
	var a := w.actors
	if m.execute_bonus_permille <= 0 or target == 0 or owner_id != a.ids[0]:
		return 1000
	if a.teams[target] == ActorStore.TEAM_PLAYER or not in_execute_range(w, target):
		return 1000
	return 1000 + m.execute_bonus_permille


## Actor i is below Executioner's threshold (false without the item).
static func in_execute_range(w: World, i: int) -> bool:
	var th := w.item_mods.execute_threshold_permille
	var a := w.actors
	return th > 0 and a.hp[i] * 1000 < a.max_hp[i] * th


# --- Swift Feet ---------------------------------------------------------------------------------------------
## The player's top speed in metres per tick (Swift Feet applied).
static func move_speed(w: World) -> float:
	var bonus := w.item_mods.move_speed_bonus_permille + Gamble.move_speed_bonus_permille(w)
	return w.player.move_speed * (1000 + bonus) / 1000.0 * Stats.move_permille(w) / 1000.0  # v0.4.0


## The dash cooldown in ticks (Swift Feet applied, never under 1).
static func dash_cooldown_ticks(w: World) -> int:
	var cut := mini(
		w.item_mods.dash_cooldown_cut_permille + Gamble.dash_cooldown_cut_permille(w), 900
	)
	return Stats.cooldown(w, maxi(1, w.player.dash_cooldown_ticks * (1000 - cut) / 1000))  # v0.4.0


# --- Phase Strike -------------------------------------------------------------------------------------------
## A blink just landed.
static func on_blink(w: World) -> void:
	if w.item_mods.phase_damage > 0:
		discharge(w)


## The guard reduced a hit: the first one in each window discharges.
static func on_guard_block(w: World) -> void:
	var m := w.item_mods
	if m.phase_damage <= 0 or w.player_dead() or w.tick < w.phase_guard_next:
		return
	w.phase_guard_next = w.tick + m.phase_guard_window_ticks
	discharge(w)


## phase_damage to every enemy touching the phase_radius_m disc around the player, as one new root chain.
static func discharge(w: World) -> void:
	var m := w.item_mods
	var a := w.actors
	var center := w.player_pos()
	var root := w.take_root()
	w.phase_tick = w.tick
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		if not AttackShapes.disc_touches(center, m.phase_radius_m, a.pos(i), a.radius[i]):
			continue
		Damage.hit(
			w,
			i,
			m.phase_damage,
			a.ids[0],
			a.ids[0],
			root,
			SimEvent.TAG_AREA,
			center,
			a.pos(i),
			EFFECT_PHASE_STRIKE
		)
	Engines.on_phase(w, root)  # Engines: Spiked Phase.
