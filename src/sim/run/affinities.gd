class_name Affinities
extends RefCounted
## v0.9.0 RB (owner, PLAN "Owner decisions" RB; docs/roadmap/v0.9.0/AFFINITIES.md A0-A5): the run's rune affinity in
## play. FloorPlan builds World.affinity from the run's locked choice (RunState.affinity) on every floor; None builds
## nothing (World.affinity stays null), so every hook here is a no-op and the world hashes as before RB.
## - A1 Ember: the burns the hero applies last burn_duration_permille of their duration (burn_ticks).
## - A2 Storm: the dash shocks each enemy within dash_shock_radius_m of its path once (dash_shock; it needs a shock
##   card on the wand, Engines.add_shock); the longer cooldown is in the compiled PlayerTable (FloorPlan).
## - A3 Venom: a poisoned enemy that dies passes its stacks to the nearest enemy within poison_jump_m (on_poison_kill).
## - A4 Astral: no sim effect (the presentation reads secret_sense_m and map_secrets).
## - A5 Guardian: a ward blocks the next hit that would damage the hero (ward_blocks), ward_charges a floor; the run
##   shards picked up (kills, containers, the Overrun's bonus) times shard_permille (shards).
## Offers: each card's weight times its card_permille (ItemPool.card_weight).

const EFFECT_WARD := &"guardian_ward"
const EFFECT_DASH_SHOCK := &"storm_dash"
const EFFECT_JUMP := &"venom_jump"
## ProcLedger code of a poison jump (after Venom's spread, 70).
const CODE_JUMP := 71


## The floor's affinity state from `table` (null: None, no state).
static func setup(w: World, table: AffinityTable) -> void:
	if table == null:
		w.affinity = null
		return
	var s := AffinityState.new()
	s.table = table
	s.ward = table.ward_charges
	w.affinity = s


## A1 Ember: a burn's duration in ticks.
static func burn_ticks(w: World, base: int) -> int:
	if w.affinity == null or w.affinity.table.burn_duration_permille == 1000:
		return base
	return base * w.affinity.table.burn_duration_permille / 1000


## Offers: item `idx`'s weight per mille (1000 without an affinity).
static func card_permille(w: World, idx: int) -> int:
	if w.affinity == null:
		return 1000
	var p := w.affinity.table.card_permille
	return p[idx] if idx < p.size() else 1000


## A2 Storm, tick phase 6 (after Kinetic Dash): the dash swept from `before` to the hero's position this tick; each
## enemy within the reach of that path gains the stacks, once a dash.
static func dash_shock(w: World, before: Vector2) -> void:
	var s := w.affinity
	if s == null or s.table.dash_shock_radius_m <= 0.0 or not w.is_dashing() or w.player_dead():
		return
	if w.dash_ticks_left == w.player.dash_ticks:  # the dash began this tick
		s.dash_tick = w.tick
		s.dash_shocked = PackedInt32Array()
	var a := w.actors
	var now := w.player_pos()
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1 or s.dash_shocked.has(a.ids[i]):
			continue
		if (
			Collide.sweep_vs_circle(before, now, s.table.dash_shock_radius_m, a.pos(i), a.radius[i])
			< 0.0
		):
			continue
		s.dash_shocked.append(a.ids[i])
		if w.item_mods.shock_threshold <= 0:
			continue  # no shock on the wand: the crackle has nothing to hold it
		if w.dash_root == 0:
			w.dash_root = w.take_root()
		s.shocks += 1
		Engines.add_shock(w, i, s.table.dash_shock_stacks, w.dash_root)


## A3 Venom: enemy `i` died poisoned with `n` stacks under root `root` (Venom.on_kill): the stacks jump to the nearest
## living enemy within poison_jump_m (the lower index on a tie).
static func on_poison_kill(w: World, i: int, n: int, root: int) -> void:
	var s := w.affinity
	if s == null or s.table.poison_jump_m <= 0.0 or n <= 0:
		return
	var a := w.actors
	var at := a.pos(i)
	var best := -1
	var best_d := 0.0
	for j in w.enemies_near(at, s.table.poison_jump_m):
		if j == i:
			continue
		var d := (a.pos(j) - at).length_squared()
		if best < 0 or d < best_d or (d == best_d and j < best):
			best = j
			best_d = d
	if best < 0 or not w.proc_ledger.try_mark(root, CODE_JUMP, a.ids[best], w.tick):
		return
	s.jumps += 1
	Venom.add(w, best, n, root)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[best], a.pos(best))
	e.root_id = root
	e.amount = n
	e.effect_id = EFFECT_JUMP


## A5 Guardian (Damage.hit): a hit about to damage the hero. True when a ward took it (spent, its event emitted).
static func ward_blocks(w: World) -> bool:
	var s := w.affinity
	if s == null or s.ward <= 0:
		return false
	s.ward -= 1
	s.ward_tick = w.tick
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, pid, pid, pid, w.player_pos())
	e.effect_id = EFFECT_WARD
	return true


## A5 Guardian: `amount` run shards picked up, times shard_permille (rounded half up; unchanged without one).
static func shards(w: World, amount: int) -> int:
	if w.affinity == null or w.affinity.table.shard_permille == 1000 or amount <= 0:
		return amount
	return (amount * w.affinity.table.shard_permille + 500) / 1000
