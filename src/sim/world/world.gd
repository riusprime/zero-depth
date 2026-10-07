# gdlint: disable=max-public-methods
class_name World
extends RefCounted
## The whole simulation state, mutated in place one tick at a time (SIM_CONTRACTS §2).
## Determinism: the same (seed, content, loadout, InputFrame log) gives the same state_hash() at every tick.

const EVENT_LOG_CAP := 4096
const BUTTON_BITS: Array[int] = [
	InputFrame.PRIMARY, InputFrame.UTILITY, InputFrame.DASH, InputFrame.INTERACT
]
const DASH_SLOT := 2

var tick := 0
var freeze_ticks := 0
var seed_value := 0

var rng_map: RngStream
var rng_loot: RngStream
var rng_combat: RngStream
var rng_ai: RngStream

var player: PlayerTable
var actors := ActorStore.new()
var projectiles := ProjectileStore.new()
var walls: Array[Obb] = []

## Player state.
var aim_angle := 0
var aim_dist_cm := 0
var move_intent := Vector2i.ZERO
var dash_ticks_left := 0
var dash_cooldown_left := 0
var dash_dir := Vector2.ZERO
## Player velocity in metres per tick (eases toward the move target).
var vel := Vector2.ZERO
## Buttons held this tick (InputFrame bits).
var held_buttons := 0
## Attacks (PlayerKit): swing tick (0 = none), its locked angle and root, combo step and window, shot cooldown.
var swing_t := 0
var swing_angle := 0
var swing_root := 0
var combo_step := 0
var combo_window := 0
var shot_cd := 0
## Utility: blink cooldown, and the last blink (tick and start point) for the view.
var blink_cd := 0
var blink_tick := -1
var blink_from := Vector2.ZERO
## Remaining ticks per button slot (BUTTON_BITS order) for buffered presses.
var input_buffer := PackedInt32Array([0, 0, 0, 0])

## Dummy movers (kernel scenario): speed in metres per tick, shot period and life in ticks.
var dummy_speed := 3.0 / SimTick.TICKS_PER_SECOND
var dummy_fire_period := 0
var projectile_speed := 10.0 / SimTick.TICKS_PER_SECOND
var projectile_life := 120
var projectile_radius := 0.1
## Bench knobs (0 = off, the golden's behaviour): movers hold this distance from the player, and shots
## get up to this much random aim error (1/4096 turns, from the ai stream).
var dummy_keep_distance := 0.0
var dummy_aim_spread := 0
## Damage of a dummy's shot: 0 keeps the kernel scenario harmless.
var dummy_shot_damage := 0

## Compiled enemy kinds (ActorStore.Kind -> EnemyTable), part of the loadout like the player table.
var enemy_tables := {}
## The encounter (null in the kernel scenario), its spawn slots, and the run's progress: the last wave spawned
## (-1 before the first), ticks until the next wave (-1 = waiting for a clear), cleared, and who killed the player.
var encounter: EncounterTable
var spawn_points := PackedVector2Array()
var wave_index := -1
var wave_timer := -1
var cleared := false
var killer_kind := -1
var killer_tags := 0
## Continuous spawning (null = off): the compiled director, run ticks counted while the player lives, ticks
## until the next spawn, and enemies killed this run.
var spawner: SpawnTable
## The generated floor this world runs on (null in the arena and kernel scenarios). Static: not hashed.
var floor_layout: FloorLayout
var run_ticks := 0
var spawn_cd := 0
var kills := 0
## Enemy pathing: a flow field toward the player, rebuilt every NavField.PERIOD ticks (derived, not hashed).
var nav := NavField.new()

# --- Items (v0.2.0 E) ---------------------------------------------------------------------------------------
## Compiled items (part of the loadout, like enemy_tables); items_owned and pickups hold indices into it.
var item_tables: Array[ItemTable] = []
## Items the player holds, in pickup order (indices into item_tables, no duplicates).
var items_owned := PackedInt32Array()
## The owned items folded into modifiers (derived from items_owned, so not hashed).
var item_mods := ItemMods.new()
## Item pickups lying on the floor.
var pickups := PickupStore.new()
## Twin Arc: ticks until the pending echo (0 = none), its angle, combo step (its shape), root and damage, and the
## tick it last swung.
var echo_t := 0
var echo_angle := 0
var echo_step := 0
var echo_root := 0
var echo_damage := 0
var echo_tick := -1
## Overcharge: swings started while it is owned, whether the current swing is the Nth, the tick it last fired.
var swing_count := 0
var swing_overcharged := false
var overcharge_tick := -1
## Kinetic Dash: this dash's root (0 until its first hit), the ids it already hit, the tick it last hit.
var dash_root := 0
var dash_hit_ids := PackedInt32Array()
var dash_hit_tick := -1
# Items, the second eight (v0.2.0 J; ItemProcs).
## Vampiric Core: the heal cap's window (start tick, -1 = none; HP healed in it) and the tick it last healed.
var heal_window_start := -1
var heal_window_used := 0
var heal_tick := -1
## Static Chain: landed player bolts counted, the root that last chained, and the last jump (tick, from, to).
var chain_count := 0
var chain_root := 0
var chain_tick := -1
var chain_from := Vector2.ZERO
var chain_to := Vector2.ZERO
## Momentum: ticks left to start an empowered swing (0 = none), and whether the current swing took it.
var momentum_t := 0
var swing_momentum := false
## Thorn Mantle: the tick the last ring was released.
var thorn_tick := -1
## Phase Strike: the tick it last discharged, and the first tick a guard block may discharge it again.
var phase_tick := -1
var phase_guard_next := 0
# --- end Items ---------------------------------------------------------------------------------------------

# --- Engines and combos (v0.3.0 G; Engines). Hashed when the loadout has items (_hash_engines). --------------
## Compiled combos (part of the loadout, like item_tables); combos_owned holds indices into it, in unlock order.
var combo_tables: Array[ComboTable] = []
var combos_owned := PackedInt32Array()
## Bit (1 << ComboTable.Effect) per owned combo (derived from combos_owned, so not hashed).
var combo_mask := 0
## Bulwark: guard charges stored, and how many the current swing took.
var guard_charges := 0
var swing_charges := 0
## Landed player bolts counted by the bolt feeders (Cinder Shot, Static Chain, Barbed Bolts, Frost Core).
var engine_bolt_hits := 0
## Which effects already fired in which root chain.
var proc_ledger := ProcLedger.new()
## Twin Arc's pending echo comes from an Overcharge swing, and that swing's shockwave damage (Resonance).
var echo_overcharged := false
var echo_wave := 0
## Slipstream: the first tick it may refund the dash again.
var slipstream_next := 0
## The last of each payoff, for the views: shock discharge (tick, from, jump ends), Plasma Arc (tick, from, to),
## Shatter Dash, bleed burst, Wildfire and Blood Harvest (tick, where), Resonance, Shrapnel Storm, Spiked Phase,
## Slipstream and Frozen Bastion (tick).
var discharge_tick := -1
var discharge_from := Vector2.ZERO
var discharge_to := PackedVector2Array()
var plasma_tick := -1
var plasma_from := Vector2.ZERO
var plasma_to := Vector2.ZERO
var shatter_tick := -1
var shatter_pos := Vector2.ZERO
var burst_tick := -1
var burst_pos := Vector2.ZERO
var wildfire_tick := -1
var wildfire_pos := Vector2.ZERO
var harvest_tick := -1
var harvest_pos := Vector2.ZERO
var resonance_tick := -1
var shrapnel_tick := -1
var spiked_tick := -1
var slipstream_tick := -1
var bastion_tick := -1
## Transient within a tick (not hashed): the payoff effects running right now (the ancestry), and the event seq when
## this tick began (the watchdog's per-tick count).
var engine_chain := PackedStringArray()
var tick_seq0 := 0
# --- end Engines -------------------------------------------------------------------------------------------
# --- Run flow (v0.3.0 B) -----------------------------------------------------------------------------------
## The floor's boss room, door and portal (null in the arena and kernel scenarios), this floor's number in the run
## (1-based) and the run's floor count (RunState sets both), and the boss's actor id (0 = none; BossStub).
var boss_flow: BossFlow
var floor_index := 1
var floor_count := 1
var boss_id := 0
# --- end Run flow ------------------------------------------------------------------------------------------

var _next_id := 1
var _event_seq := 0
var _events: Array[SimEvent] = []
var _wall_grid := UniformGrid.new()
var _actor_grid := UniformGrid.new()
## Run flow: a wall prepared for adding in play, and its flow field (prepare_wall).
var _wall_next: Obb
var _nav_next: NavField
## Projectile spawns wait until phase 9 of the tick: [owner, team, pos, vel, damage, radius, life, tags, bounces].
var _pending_projectiles: Array[Array] = []


func _init(p_seed: int, p_player: PlayerTable, player_pos: Vector2 = Vector2.ZERO) -> void:
	seed_value = p_seed
	rng_map = RngStream.derive(p_seed, "map")
	rng_loot = RngStream.derive(p_seed, "loot")
	rng_combat = RngStream.derive(p_seed, "combat")
	rng_ai = RngStream.derive(p_seed, "ai")
	player = p_player
	var id := _take_id()
	actors.add(
		id,
		ActorStore.Kind.PLAYER,
		ActorStore.TEAM_PLAYER,
		player_pos,
		player.radius_m,
		player.hp,
		0
	)


## Static walls; call before the first step.
func set_walls(p_walls: Array[Obb]) -> void:
	walls = p_walls
	nav.build(walls)
	_wall_grid.clear()
	for i in walls.size():
		_wall_grid.insert_rect(i, walls[i].bounds())


## Adds a dummy mover immediately (setup only; during a tick, spawns are queued).
func add_dummy(p: Vector2, radius_m: float, hp: int) -> int:
	var id := _take_id()
	var first_shot := dummy_fire_period + (id % maxi(dummy_fire_period, 1))
	actors.add(id, ActorStore.Kind.DUMMY, ActorStore.TEAM_ENEMY, p, radius_m, hp, first_shot)
	emit_event(SimEvent.Kind.SPAWN, id, id, id, p)
	return id


## Queues a projectile for phase 9 of this tick. `bounces`: wall bounces (Ricochet Core).
func queue_projectile(
	owner_id: int,
	team: int,
	at: Vector2,
	vel: Vector2,
	damage: int,
	radius_m: float,
	life: int,
	tags: int,
	bounces: int = 0
) -> void:
	_pending_projectiles.append([owner_id, team, at, vel, damage, radius_m, life, tags, bounces])


## Advances exactly one tick. The phase order is part of the contract (SIM_CONTRACTS §2).
func step(frame: InputFrame) -> void:
	# 1. Freeze check: hit-stop holds everything except buffering new presses.
	if freeze_ticks > 0:
		freeze_ticks -= 1
		_buffer_presses(frame.pressed)
		tick += 1
		return
	tick_seq0 = _event_seq  # Engines: the watchdog counts this tick's events.
	if boss_flow != null and boss_flow.exited():  # Run flow: the floor is over; nothing moves.
		tick += 1
		return
	# 2. Input (a dead player's input is ignored).
	_age_buffer()
	if player_dead():
		frame = InputFrame.new()
	_buffer_presses(frame.pressed)
	move_intent = frame.move
	aim_angle = frame.aim_angle
	aim_dist_cm = frame.aim_dist_cm
	held_buttons = frame.held
	actors.facing[0] = aim_angle
	# 3. AI (the flow field refreshes on fixed ticks).
	if tick % NavField.PERIOD == 0 and not enemy_tables.is_empty():
		nav.flood(player_pos())
	_run_ai()
	# 4. Action states.
	_advance_actions()
	# 5. Move and collide.
	var before_move := player_pos()  # Items: the Kinetic Dash sweep starts here.
	_move_and_collide()
	# 6. Hits: enemy attacks, then projectile sweeps.
	for i in range(1, actors.size()):
		if EnemyAi.is_enemy_kind(actors.kinds[i]) and actors.dead[i] == 0:
			EnemyAi.resolve(self, i)
	_projectile_hits()
	ItemEffects.dash_hits(self, before_move)  # Items: Kinetic Dash.
	# 7. The effect queue arrives with the engine work. 8. Statuses: Ember Edge burns (Items).
	ItemEffects.tick_burns(self)
	ItemProcs.tick_slows(self)  # Items: Frost Core slows run down.
	Engines.tick_statuses(self)  # Engines: shock, bleed, frost, freezes.
	# 9. Deaths and spawns (the wave director adds enemies here).
	_remove_dead()
	ItemEffects.collect_pickups(self)  # Items: walking over a pickup takes it.
	WaveDirector.advance(self)
	if spawner != null:
		if boss_flow == null or boss_flow.spawns_open():
			SpawnDirector.advance(self)
		else:
			boss_flow.count_time(self)  # Run flow: the sealed boss room stops spawns, not the clock.
	if boss_flow != null:
		boss_flow.advance(self)
	_apply_spawns()
	# 10. Cues are already in the event log. 11. Hashing is on demand (state_hash).
	tick += 1


func add_freeze(ticks: int) -> void:
	freeze_ticks = mini(freeze_ticks + ticks, SimTick.FREEZE_CAP_TICKS)


func player_pos() -> Vector2:
	return actors.pos(0)


func player_dead() -> bool:
	return actors.dead[0] == 1


## The player's guard is up: guard chosen, the utility button held, not dashing, alive.
func guarding() -> bool:
	return (
		player.utility == PlayerTable.Utility.GUARD
		and (held_buttons & InputFrame.UTILITY) != 0
		and dash_ticks_left == 0
		and not player_dead()
	)


## Compiled numbers for an enemy kind; null for kinds without a table (the kernel's dummies).
func enemy_table(kind: int) -> EnemyTable:
	return enemy_tables.get(kind)


func set_enemy_tables(tables: Array[EnemyTable]) -> void:
	for t in tables:
		enemy_tables[t.kind] = t


## Adds an enemy now (setup, or the wave director in phase 9). It spawns in: no acting, no damage, for
## SPAWN_IN_TICKS.
func add_enemy(kind: int, p: Vector2) -> int:
	var t := enemy_table(kind)
	var id := _take_id()
	var i := actors.add(id, kind, ActorStore.TEAM_ENEMY, p, t.radius_m, t.hp, 0)
	actors.invuln[i] = SimTick.SPAWN_IN_TICKS
	actors.facing[i] = Kin.angle_of(player_pos() - p)
	emit_event(SimEvent.Kind.SPAWN, id, id, id, p)
	return id


# --- Items (v0.2.0 E) ---------------------------------------------------------------------------------------
## The compiled items, in the order the indices in items_owned and pickups refer to.
func set_item_tables(tables: Array[ItemTable]) -> void:
	item_tables = tables
	item_mods = ItemMods.build(item_tables, items_owned)


## Gives the player item `item_index`. Returns false (and changes nothing) if it is already owned.
func add_item(item_index: int) -> bool:
	if items_owned.has(item_index):
		return false
	items_owned.append(item_index)
	item_mods = ItemMods.build(item_tables, items_owned)
	_refresh_combos(true)
	return true


## The compiled combos (v0.3.0 G), in the order combos_owned refers to. Combos already earned by the items owned
## are owned at once, without an event.
func set_combo_tables(tables: Array[ComboTable]) -> void:
	combo_tables = tables
	_refresh_combos(false)


## Sets the items owned (carrying a run's items to a new floor): modifiers and combos follow, no events.
func set_items_owned(owned: PackedInt32Array) -> void:
	items_owned = owned.duplicate()
	item_mods = ItemMods.build(item_tables, items_owned)
	_refresh_combos(false)


## Owns every combo whose two items are owned (new ones appended in combo order); `announce` emits COMBO_UNLOCKED
## for each new one (amount = its combo index).
func _refresh_combos(announce: bool) -> void:
	for c in Engines.combos_for(combo_tables, items_owned):
		if combos_owned.has(c):
			continue
		combos_owned.append(c)
		if announce:
			var pid := actors.ids[0]
			var e := emit_event(SimEvent.Kind.COMBO_UNLOCKED, pid, pid, pid, player_pos())
			e.amount = c
			e.effect_id = combo_tables[c].id
	combo_mask = 0
	for c in combos_owned:
		combo_mask |= 1 << combo_tables[c].effect


## Puts a pickup for item `item_index` on the floor at `pos` (setup, or a spawner in phase 9). Returns its id.
func add_pickup(item_index: int, pos: Vector2) -> int:
	var id := _take_id()
	pickups.add(id, pos, item_index)
	emit_event(SimEvent.Kind.SPAWN, id, id, id, pos)
	return id


# --- end Items ---------------------------------------------------------------------------------------------


# --- Run flow (v0.3.0 B) -----------------------------------------------------------------------------------
## The boss contract (C implements it; BossStub stands in until then): spawns boss `boss_table_index` at `pos` and
## returns its actor id.
func spawn_boss(boss_table_index: int, pos: Vector2) -> int:
	return BossStub.spawn(self, boss_table_index, pos)


## True while the floor's boss lives (C implements it; BossStub stands in until then).
func boss_alive() -> bool:
	return BossStub.alive(self)


## Whether a blink from `from` may land at `at`: the boss room's door rules (BossFlow.blink_may_land).
func blink_may_land(from: Vector2, at: Vector2) -> bool:
	return boss_flow == null or boss_flow.blink_may_land(self, from, at)


## Builds, at setup, the flow field for the walls plus `o`, so adding `o` in play (the boss door sealing) never
## rebuilds the whole field mid-fight (about 0.1 s on a floor).
func prepare_wall(o: Obb) -> void:
	var next: Array[Obb] = walls.duplicate()
	next.append(o)
	_wall_next = o
	_nav_next = NavField.new()
	_nav_next.build(next)


## Adds a wall during play. The flow field swaps to the one prepare_wall built (or is rebuilt if there is none) and
## floods from the player at once, so enemies path around the new wall from this tick.
func add_wall_now(o: Obb) -> void:
	walls.append(o)
	_wall_grid.insert_rect(walls.size() - 1, o.bounds())
	if o == _wall_next and _nav_next != null:
		nav = _nav_next
	else:
		nav.build(walls)
	_wall_next = null
	_nav_next = null
	nav.flood(player_pos())


# --- end Run flow ------------------------------------------------------------------------------------------


func dash_iframes_active() -> bool:
	return dash_ticks_left > 0 and player.dash_ticks - dash_ticks_left < player.dash_iframe_ticks


func is_dashing() -> bool:
	return dash_ticks_left > 0


func buffered(bit: int) -> int:
	return input_buffer[BUTTON_BITS.find(bit)]


func last_event_seq() -> int:
	return _event_seq


## Events with seq > after_seq, oldest first. The log keeps the most recent EVENT_LOG_CAP events.
func events_since(after_seq: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in _events:
		if e.seq > after_seq:
			out.append(e)
	return out


func state_hash() -> String:
	var h := StateHasher.new()
	h.add_int(tick)
	h.add_int(freeze_ticks)
	h.add_int(seed_value)
	h.add_int(_next_id)
	h.add_int(_event_seq)
	for s in [rng_map, rng_loot, rng_combat, rng_ai]:
		h.add_int(s.state)
	h.add_int(aim_angle)
	h.add_int(aim_dist_cm)
	h.add_int(move_intent.x)
	h.add_int(move_intent.y)
	h.add_int(dash_ticks_left)
	h.add_int(dash_cooldown_left)
	h.add_f32(dash_dir.x)
	h.add_f32(dash_dir.y)
	h.add_f32(vel.x)
	h.add_f32(vel.y)
	h.add_ints(input_buffer)
	for v in [held_buttons, swing_t, swing_angle, swing_root, combo_step, combo_window, shot_cd]:
		h.add_int(v)
	for v in [wave_index, wave_timer, 1 if cleared else 0, killer_kind, killer_tags]:
		h.add_int(v)
	for v in [1 if spawner != null else 0, run_ticks, spawn_cd, kills]:
		h.add_int(v)
	h.add_int(blink_cd)
	h.add_int(blink_tick)
	h.add_f32(blink_from.x)
	h.add_f32(blink_from.y)
	# Items (v0.2.0 E).
	h.add_ints(items_owned)
	pickups.hash_into(h)
	for v in [echo_t, echo_angle, echo_step, echo_root, echo_damage, echo_tick, swing_count]:
		h.add_int(v)
	h.add_int(1 if swing_overcharged else 0)
	for v in [overcharge_tick, dash_root, dash_hit_tick]:
		h.add_int(v)
	h.add_ints(dash_hit_ids)
	# Items, the second eight (v0.2.0 J).
	for v in [heal_window_start, heal_window_used, heal_tick, chain_count, chain_root, chain_tick]:
		h.add_int(v)
	for v in [chain_from.x, chain_from.y, chain_to.x, chain_to.y]:
		h.add_f32(v)
	for v in [momentum_t, 1 if swing_momentum else 0, thorn_tick, phase_tick, phase_guard_next]:
		h.add_int(v)
	if not item_tables.is_empty():
		_hash_engines(h)
	if boss_flow != null:  # Run flow (v0.3.0 B): only floors with a boss room carry it.
		boss_flow.hash_into(h)
		for v in [floor_index, floor_count, boss_id]:
			h.add_int(v)
	actors.hash_into(h)
	projectiles.hash_into(h)
	h.add_int(walls.size())
	for w in walls:
		h.add_f32(w.center.x)
		h.add_f32(w.center.y)
		h.add_f32(w.half.x)
		h.add_f32(w.half.y)
		h.add_int(w.angle)
	return h.finish_hex()


## Engines and combos (v0.3.0 G), in a fixed order. Only worlds whose loadout has items hash them: their fields
## stay at their defaults otherwise, and leaving them out keeps the item-free goldens' hashes.
func _hash_engines(h: StateHasher) -> void:
	h.add_ints(combos_owned)
	for v in [
		guard_charges, swing_charges, engine_bolt_hits, 1 if echo_overcharged else 0, echo_wave
	]:
		h.add_int(v)
	h.add_int(slipstream_next)
	proc_ledger.hash_into(h)
	actors.hash_statuses(h)
	for v in [discharge_tick, plasma_tick, shatter_tick, burst_tick, wildfire_tick, harvest_tick]:
		h.add_int(v)
	for v in [resonance_tick, shrapnel_tick, spiked_tick, slipstream_tick, bastion_tick]:
		h.add_int(v)
	for p: Vector2 in [
		discharge_from, plasma_from, plasma_to, shatter_pos, burst_pos, wildfire_pos
	]:
		h.add_f32(p.x)
		h.add_f32(p.y)
	h.add_f32(harvest_pos.x)
	h.add_f32(harvest_pos.y)
	h.add_int(discharge_to.size())
	for p in discharge_to:
		h.add_f32(p.x)
		h.add_f32(p.y)


## Plain-data copy for inspectors and desync diffs; never used for gameplay.
func snapshot() -> Dictionary:
	return {
		"tick": tick,
		"freeze_ticks": freeze_ticks,
		"next_id": _next_id,
		"event_seq": _event_seq,
		"rng": [rng_map.state, rng_loot.state, rng_combat.state, rng_ai.state],
		"player":
		{"aim": aim_angle, "dash_ticks_left": dash_ticks_left, "dash_cd": dash_cooldown_left},
		"actors": {"ids": actors.ids, "x": actors.pos_x, "y": actors.pos_y, "hp": actors.hp},
		"projectiles": {"ids": projectiles.ids, "x": projectiles.pos_x, "y": projectiles.pos_y},
	}


## A fresh root id for a new chain (a player action or an enemy attack).
func take_root() -> int:
	return _take_id()


func _take_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


func emit_event(kind: SimEvent.Kind, source: int, owner: int, target: int, at: Vector2) -> SimEvent:
	_event_seq += 1
	var e := SimEvent.new()
	e.seq = _event_seq
	e.tick = tick
	e.kind = kind
	e.root_id = source
	e.source_id = source
	e.owner_id = owner
	e.target_id = target
	e.pos = at
	_events.append(e)
	if _events.size() > EVENT_LOG_CAP * 2:
		_events = _events.slice(_events.size() - EVENT_LOG_CAP)
	return e


func _age_buffer() -> void:
	for i in input_buffer.size():
		if input_buffer[i] > 0:
			input_buffer[i] -= 1


func _buffer_presses(pressed: int) -> void:
	for i in BUTTON_BITS.size():
		if pressed & BUTTON_BITS[i]:
			input_buffer[i] = SimTick.INPUT_BUFFER_TICKS


func _run_ai() -> void:
	var target := player_pos()
	for i in range(1, actors.size()):
		if EnemyAi.is_enemy_kind(actors.kinds[i]):
			EnemyAi.think(self, i)
			continue
		if actors.kinds[i] != ActorStore.Kind.DUMMY:
			continue
		var id := actors.ids[i]
		if (tick + id) % SimTick.AI_HEAVY_PERIOD == 0:
			actors.jitter_x[i] = rng_ai.range_int(-300, 300) / 100.0
			actors.jitter_y[i] = rng_ai.range_int(-300, 300) / 100.0
		if dummy_fire_period > 0:
			actors.fire_cd[i] -= 1
			if actors.fire_cd[i] <= 0:
				actors.fire_cd[i] = dummy_fire_period
				var from := actors.pos(i)
				var shot_angle := Kin.angle_of(target - from)
				if dummy_aim_spread > 0:
					shot_angle += rng_ai.range_int(-dummy_aim_spread, dummy_aim_spread)
				var dir := Kin.dir(shot_angle)
				var muzzle := from + dir * (actors.radius[i] + projectile_radius + 0.05)
				queue_projectile(
					id,
					ActorStore.TEAM_ENEMY,
					muzzle,
					dir * projectile_speed,
					dummy_shot_damage,
					projectile_radius,
					projectile_life,
					SimEvent.TAG_PROJECTILE
				)


func _advance_actions() -> void:
	for i in actors.size():
		if actors.invuln[i] > 0:
			actors.invuln[i] -= 1
	if player_dead():
		dash_ticks_left = 0
		swing_t = 0
		shot_cd = 0
		return
	PlayerKit.advance_utility(self)
	PlayerKit.advance(self)
	if dash_cooldown_left > 0:
		dash_cooldown_left -= 1
	if dash_ticks_left > 0:
		dash_ticks_left -= 1
		if dash_ticks_left == 0:
			ItemProcs.on_dash_end(self)  # Items: Momentum.
		return
	if input_buffer[DASH_SLOT] > 0 and dash_cooldown_left == 0:
		input_buffer[DASH_SLOT] = 0
		dash_dir = PlayerKit.move_or_aim(self)
		dash_root = 0  # Items: a new dash may hit every enemy once again.
		dash_hit_ids = PackedInt32Array()
		dash_ticks_left = player.dash_ticks
		dash_cooldown_left = ItemProcs.dash_cooldown_ticks(self)  # Items: Swift Feet.


func _move_and_collide() -> void:
	# Player.
	var p := player_pos()
	if player_dead():
		vel = Vector2.ZERO
	elif dash_ticks_left > 0:
		p += dash_dir * (player.dash_distance_m / player.dash_ticks)
	else:
		var target := Vector2.ZERO
		if move_intent != Vector2i.ZERO:
			var mv := Vector2(move_intent.x, move_intent.y) / float(SimTick.MOVE_MAX)
			var len := Kin.length(mv)
			if len > 1.0:
				mv /= len
			var speed := ItemProcs.move_speed(self)  # Items: Swift Feet.
			if guarding():
				speed = speed * player.guard_move_permille / 1000.0
			target = mv * speed
		var k := (
			player.accel_permille if Kin.length(target) > Kin.length(vel) else player.decel_permille
		)
		vel += (target - vel) * (k / 1000.0)
		if Kin.length(vel - target) < 0.0001:
			vel = target
		p += vel + PlayerKit.lunge_offset(self)  # a combo step's forward step (v0.3.0 L11)
	actors.set_pos(0, p)
	# Dummies steer toward the player plus their jitter.
	var target := p
	for i in range(1, actors.size()):
		if EnemyAi.is_enemy_kind(actors.kinds[i]):
			EnemyAi.move(self, i)
			continue
		var at := actors.pos(i)
		var goal := target + Vector2(actors.jitter_x[i], actors.jitter_y[i])
		if dummy_keep_distance > 0.0:
			var away := at - target
			var away_len := Kin.length(away)
			if away_len > 0.0:
				goal += away * (dummy_keep_distance / away_len)
		var to := goal - at
		var dist := Kin.length(to)
		if dist > dummy_speed:
			at += to * (dummy_speed / dist)
		actors.set_pos(i, at)
	# Resolve: walls first, then actor pairs in ascending index order.
	for _iter in SimTick.COLLIDE_ITERS:
		for i in actors.size():
			var ap := actors.pos(i)
			var r := actors.radius[i]
			for w in _wall_grid.query_rect(Rect2(ap.x - r, ap.y - r, r * 2.0, r * 2.0)):
				ap += Collide.circle_vs_obb(ap, r, walls[w])
			actors.set_pos(i, ap)
		_actor_grid.clear()
		for i in actors.size():
			var r := actors.radius[i]
			_actor_grid.insert_rect(
				i, Rect2(actors.pos_x[i] - r, actors.pos_y[i] - r, r * 2.0, r * 2.0)
			)
		for a in actors.size():
			var ra := actors.radius[a]
			var pa := actors.pos(a)
			for b in _actor_grid.query_rect(Rect2(pa.x - ra, pa.y - ra, ra * 2.0, ra * 2.0)):
				if b <= a:
					continue
				var push := Collide.circle_vs_circle(
					actors.pos(a), ra, actors.pos(b), actors.radius[b]
				)
				if push != Vector2.ZERO:
					actors.set_pos(a, actors.pos(a) + push)
					actors.set_pos(b, actors.pos(b) - push)


func _projectile_hits() -> void:
	var dead := PackedInt32Array()
	for i in projectiles.size():
		var a := Vector2(projectiles.pos_x[i], projectiles.pos_y[i])
		var v := Vector2(projectiles.vel_x[i], projectiles.vel_y[i])
		var b := a + v
		var r := projectiles.radius[i]
		# Walls and actors are inserted with their full extent, so the segment only grows by its own radius.
		var span := Rect2(a, Vector2.ZERO).expand(b).grow(r)
		var best_t := 2.0
		var best_actor := -1
		var best_wall := -1
		for w in _wall_grid.query_rect(span):
			var t := Collide.sweep_vs_obb(a, b, r, walls[w])
			if t >= 0.0 and t < best_t:
				best_t = t
				best_actor = -1
				best_wall = w
		for k in _actor_grid.query_rect(span):
			if actors.teams[k] == projectiles.team[i] or actors.dead[k] == 1:
				continue
			var t := Collide.sweep_vs_circle(a, b, r, actors.pos(k), actors.radius[k])
			if t >= 0.0 and (t < best_t or (t == best_t and best_actor >= 0 and k < best_actor)):
				best_t = t
				best_actor = k
		if best_t <= 1.0:
			if best_actor >= 0:
				var got := Damage.hit(
					self,
					best_actor,
					projectiles.damage[i],
					projectiles.ids[i],
					projectiles.owner[i],
					projectiles.root_id[i],
					projectiles.tags[i],
					a,
					a + v * best_t,
					ItemProcs.bolt_effect(projectiles.tags[i])
				)
				# Items: Frost Core and Static Chain react to the player's landed bolts.
				ItemProcs.on_bolt_hit(self, best_actor, i, got, a + v * best_t)
			elif projectiles.bounces[i] > 0:
				# Items: Ricochet Core reflects the bolt off the wall instead of ending it.
				ItemEffects.bounce(self, i, a + v * best_t, walls[best_wall])
				projectiles.life[i] -= 1
				if projectiles.life[i] <= 0:
					dead.append(i)
				continue
			dead.append(i)
			continue
		projectiles.pos_x[i] = b.x
		projectiles.pos_y[i] = b.y
		projectiles.life[i] -= 1
		if projectiles.life[i] <= 0:
			dead.append(i)
	projectiles.remove_sorted(dead)


func _remove_dead() -> void:
	var gone := PackedInt32Array()
	for i in range(1, actors.size()):
		if actors.dead[i] == 1:
			gone.append(i)
			if EnemyAi.is_enemy_kind(actors.kinds[i]):
				kills += 1
	actors.remove_sorted(gone)


func _apply_spawns() -> void:
	for s in _pending_projectiles:
		var id := _take_id()
		projectiles.add(id, s[0], s[1], s[2], s[3], s[5], s[6], s[4], s[7], s[8])
		emit_event(SimEvent.Kind.SPAWN, id, s[0], id, s[2])
	_pending_projectiles.clear()
