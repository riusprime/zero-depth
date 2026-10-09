extends GutTest
## v0.3.0 G: the engines (burn, shock, bleed, frost, guard charges) with the shipped data's numbers, and the loop
## rules (DoT never procs, once per root chain, ancestry, the watchdog). Aim angle 0 = +x.

const P := InputFrame.PRIMARY
const S := InputFrame.SHOOT
const U := InputFrame.UTILITY
const K := ItemTable.Kind

var _tables: Array[ItemTable] = []
var _combos: Array[ComboTable] = []


func before_all() -> void:
	var repo := ContentRepository.load_all()
	_tables = ContentCompiler.compile_items(repo)
	_combos = ContentCompiler.compile_combos(repo)


func _index(kind: int) -> int:
	for i in _tables.size():
		if _tables[i].kind == kind:
			return i
	return -1


## A world with the item and combo tables, the given item kinds owned, and still dummies (hp 500) at `enemies`.
func _world(
	kinds: Array = [], enemies: Array = [Vector2(1.2, 0)], utility: int = PlayerTable.Utility.NONE
) -> World:
	var t := PlayerTable.starting_values()
	t.utility = utility
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	w.set_item_tables(_tables)
	w.set_combo_tables(_combos)
	for k: int in kinds:
		assert_true(w.add_item(_index(k)), "added kind %d" % k)
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, 500)
	return w


func _f(held: int = 0, pressed: int = 0, aim: int = 0, move := Vector2i.ZERO) -> InputFrame:
	return InputFrame.make(move, aim, 300, held, pressed)


func _idle(w: World, n: int, held: int = 0, aim: int = 0) -> void:
	for i in n:
		w.step(_f(held, 0, aim))


func _events(w: World, kind: SimEvent.Kind, effect := &"", after: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(after):
		if e.kind == kind and (effect == &"" or e.effect_id == effect):
			out.append(e)
	return out


func _amounts(events: Array[SimEvent]) -> Array:
	return events.map(func(e: SimEvent) -> int: return e.amount)


## A player hit on actor i with these tags (a fresh root unless one is given). Returns the root.
func _hit(w: World, i: int, tags: int, amount: int = 1, root: int = 0) -> int:
	var a := w.actors
	var r := root if root != 0 else w.take_root()
	Damage.hit(w, i, amount, a.ids[0], a.ids[0], r, tags, a.pos(0), a.pos(i))
	return r


## Presses attack and steps until the swing, its hit-stop and any Twin Arc echo are over (then 2 more ticks).
func _swing(w: World, aim: int = 0) -> void:
	w.step(_f(0, P, aim))
	for k in 120:
		if w.swing_t == 0 and w.echo_t == 0 and w.freeze_ticks == 0 and w.input_buffer[0] == 0:
			break
		w.step(_f(0, 0, aim))
	_idle(w, 2, 0, aim)


# --- Burn -----------------------------------------------------------------------------------------------------
func test_cinder_shot_burns_every_third_bolt_and_stacks_to_five() -> void:
	var w := _world([K.CINDER_SHOT])
	var a := w.actors
	_hit(w, 1, SimEvent.TAG_PROJECTILE)
	_hit(w, 1, SimEvent.TAG_PROJECTILE)
	assert_eq(a.burn_stacks[1], 0, "two bolts: no burn yet")
	_hit(w, 1, SimEvent.TAG_PROJECTILE)
	assert_eq(a.burn_stacks[1], 1, "the third bolt ignites")
	for k in 30:
		_hit(w, 1, SimEvent.TAG_PROJECTILE)
	assert_eq(a.burn_stacks[1], 5, "capped at five stacks")
	var before := w.last_event_seq()
	_idle(w, 30)
	var dot := _events(w, SimEvent.Kind.DAMAGE, &"ember_edge", before)
	assert_eq(_amounts(dot), [10], "2 per stack per 0.5 s: 5 stacks deal 10")
	assert_ne(dot[0].tags & SimEvent.TAG_DOT, 0)
	assert_eq(dot[0].proc_pct, 0)


func test_burn_runs_out_and_comes_back() -> void:
	var w := _world([K.EMBER_EDGE])
	_swing(w)
	assert_eq(w.actors.burn_stacks[1], 1)
	_idle(w, 200)
	assert_eq(w.actors.burn_stacks[1], 0, "3 s without a new stack: the burn ends")
	_swing(w)
	assert_eq(w.actors.burn_stacks[1], 1, "renewable: the next hit lights it again")


func test_wildfire_spreads_burn_from_a_kill() -> void:
	var w := _world([K.WILDFIRE, K.EMBER_EDGE], [Vector2(1.2, 0), Vector2(2.5, 0), Vector2(8, 0)])
	var a := w.actors
	a.burn_stacks[1] = 4
	a.burn_t[1] = 100
	_hit(w, 1, SimEvent.TAG_MELEE, 9999)
	assert_eq(a.burn_stacks[2], 3, "1 + half the victim's 4 stacks")
	assert_eq(a.burn_stacks[3], 0, "8 m away: out of the 2.5 m spread")
	assert_eq(_events(w, SimEvent.Kind.STATUS_APPLY, &"wildfire").size(), 1)


# --- Shock ----------------------------------------------------------------------------------------------------
func test_shock_discharges_at_five_stacks_into_two_neighbours() -> void:
	var w := _world(
		[K.CONDUCTOR],
		[Vector2(1.2, 0), Vector2(2.0, 1.0), Vector2(2.0, -2.0), Vector2(2.0, 3.0), Vector2(9, 0)]
	)
	w.item_mods.shock_jumps = 2  # Static Chain's and Overcharge's jumps; Conductor's 4 is checked below.
	var a := w.actors
	for k in 4:
		_hit(w, 1, SimEvent.TAG_MELEE)
	assert_eq(a.shock_stacks[1], 4)
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, &"shock_discharge").size(), 0)
	_hit(w, 1, SimEvent.TAG_MELEE)
	var d := _events(w, SimEvent.Kind.DAMAGE, &"shock_discharge")
	assert_eq(_amounts(d), [12, 12, 12], "the enemy and its two nearest neighbours")
	assert_eq(d.map(func(e: SimEvent) -> int: return e.target_id), [a.ids[1], a.ids[2], a.ids[3]])
	assert_eq(a.shock_stacks[1], 0, "the discharge resets the stacks")
	for j in [2, 3, 4]:
		assert_eq(a.shock_stacks[j], 0, "a discharge never adds shock (ancestry)")
	assert_eq(w.discharge_to.size(), 2)
	var hits := _events(w, SimEvent.Kind.HIT, &"shock_discharge")
	assert_eq(hits[0].ancestry, PackedStringArray(["shock_discharge"]), "the payoff's chain")
	assert_eq(hits[0].depth, 1)


func test_conductor_jumps_to_four_within_four_metres() -> void:
	var enemies := [Vector2(1.2, 0)]
	for k in 5:
		enemies.append(Vector2(1.2 + 0.7 * (k + 1), 0))
	enemies.append(Vector2(1.2, 4.5))
	var w := _world([K.CONDUCTOR], enemies)
	for k in 5:
		_hit(w, 1, SimEvent.TAG_MELEE)
	var d := _events(w, SimEvent.Kind.DAMAGE, &"shock_discharge")
	assert_eq(d.size(), 5, "itself and four jumps")
	for e in d:
		assert_ne(e.target_id, w.actors.ids[7], "4.5 m away: out of range")


func test_shock_fades_after_three_seconds_and_once_per_root() -> void:
	var w := _world([K.CONDUCTOR])
	var a := w.actors
	var root := _hit(w, 1, SimEvent.TAG_MELEE)
	_hit(w, 1, SimEvent.TAG_MELEE, 1, root)
	assert_eq(a.shock_stacks[1], 1, "the same swing feeds one stack per enemy")
	_idle(w, 181)
	assert_eq(a.shock_stacks[1], 0, "faded")
	a.shock_stacks[1] = 5
	var r := w.take_root()
	Engines.discharge(w, 1, r)
	Engines.discharge(w, 1, r)
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, &"shock_discharge").size(), 1, "once per root")


func test_static_chain_bolts_and_overcharge_waves_feed_shock() -> void:
	var w := _world([K.STATIC_CHAIN, K.OVERCHARGE])
	var a := w.actors
	_hit(w, 1, SimEvent.TAG_PROJECTILE)
	assert_eq(a.shock_stacks[1], 0)
	_hit(w, 1, SimEvent.TAG_PROJECTILE)
	assert_eq(a.shock_stacks[1], 1, "every second bolt")
	var r := w.take_root()
	ItemEffects.shockwave(w, 5, r, ItemEffects.EFFECT_OVERCHARGE)
	assert_eq(a.shock_stacks[1], 3, "a shockwave adds two")


# --- Bleed ----------------------------------------------------------------------------------------------------
func test_serrated_edge_bleeds_stacking_to_eight() -> void:
	var w := _world([K.SERRATED_EDGE])
	var a := w.actors
	for k in 12:
		_hit(w, 1, SimEvent.TAG_MELEE)
	assert_eq(a.bleed_stacks[1], 8, "capped")
	var before := w.last_event_seq()
	_idle(w, 30)
	var dot := _events(w, SimEvent.Kind.DAMAGE, &"bleed", before)
	assert_eq(_amounts(dot), [8], "1 per stack every 0.5 s")
	assert_ne(dot[0].tags & SimEvent.TAG_DOT, 0)
	assert_eq(_events(w, SimEvent.Kind.HIT, &"bleed").size(), 0, "a DoT never emits HIT")
	_idle(w, 240)
	assert_eq(a.bleed_stacks[1], 0, "4 s without a new stack: it ends")


func test_a_dash_through_a_bleeding_enemy_bursts_every_stack() -> void:
	var w := _world([K.BARBED_BOLTS], [Vector2(2.0, 0)])
	var a := w.actors
	a.bleed_stacks[1] = 6
	a.bleed_t[1] = 200
	a.bleed_cd[1] = 30
	w.step(_f(0, InputFrame.DASH, 0))
	while w.is_dashing():
		w.step(_f(0, 0, 0))
	var b := _events(w, SimEvent.Kind.DAMAGE, &"bleed_burst")
	assert_eq(_amounts(b), [30], "6 stacks × 5, without Kinetic Dash")
	assert_eq(a.bleed_stacks[1], 0)
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, &"kinetic_dash").size(), 0)


func test_barbed_bolts_bleed_every_second_bolt() -> void:
	var w := _world([K.BARBED_BOLTS])
	_hit(w, 1, SimEvent.TAG_PROJECTILE)
	assert_eq(w.actors.bleed_stacks[1], 0)
	_hit(w, 1, SimEvent.TAG_PROJECTILE)
	assert_eq(w.actors.bleed_stacks[1], 1)


# --- Frost ----------------------------------------------------------------------------------------------------
func _charger_world(kinds: Array) -> World:
	var w := CombatLab.world()
	w.set_item_tables(_tables)
	w.set_combo_tables(_combos)
	for k: int in kinds:
		w.add_item(_index(k))
	w.add_enemy(ActorStore.Kind.CHARGER, Vector2(12, 0))  # beyond its 6 m attack range
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[1] == EnemyAi.State.MOVE)
	return w


func test_four_frost_stacks_freeze_for_one_second_then_frost_comes_back() -> void:
	var w := _charger_world([K.GLACIAL_EDGE])
	var a := w.actors
	for k in 3:
		_hit(w, 1, SimEvent.TAG_MELEE)
	assert_eq(a.frost_stacks[1], 3)
	assert_gt(a.slow_t[1], 0, "frost chills: the slow runs")
	_hit(w, 1, SimEvent.TAG_MELEE)
	assert_true(Engines.frozen(w, 1), "the fourth stack freezes")
	assert_eq(a.frost_stacks[1], 0)
	assert_eq(_events(w, SimEvent.Kind.STATUS_APPLY, &"freeze").size(), 1)
	_hit(w, 1, SimEvent.TAG_MELEE)
	assert_eq(a.frost_stacks[1], 0, "no stacks build while frozen")
	var at := a.pos(1)
	var state_t := a.state_t[1]
	CombatLab.idle(w, 30)
	assert_eq(a.pos(1), at, "frozen: it doesn't move")
	assert_eq(a.state_t[1], state_t, "nor think")
	CombatLab.idle(w, 31)
	assert_false(Engines.frozen(w, 1), "a freeze lasts 1 s")
	CombatLab.idle(w, 2)
	assert_ne(a.pos(1), at, "thawed, it walks again")
	for k in 4:
		_hit(w, 1, SimEvent.TAG_MELEE)
	assert_true(Engines.frozen(w, 1), "renewable")


func test_a_freeze_immune_actor_is_only_slowed() -> void:
	var w := _charger_world([K.GLACIAL_EDGE])
	var a := w.actors
	a.freeze_immune[1] = 1
	for k in 10:
		_hit(w, 1, SimEvent.TAG_MELEE)
	assert_false(Engines.frozen(w, 1), "bosses never freeze")
	assert_eq(a.frost_stacks[1], 3, "stacks stop one short")
	assert_gt(a.slow_t[1], 0, "frost only slows it")
	assert_lt(ItemProcs.slow_factor(w, 1), 1.0)


## v0.6.0 MX4 (M3): Frost Core adds a frost stack on every hit; the 3rd freezes.
func test_frost_core_freezes_on_the_third_hit_and_cold_snap_hits_harder() -> void:
	var w := _world([K.FROST_CORE, K.COLD_SNAP])
	var a := w.actors
	for k in 2:
		_hit(w, 1, SimEvent.TAG_PROJECTILE)
	assert_eq(a.frost_stacks[1], 2, "a stack every hit")
	var before := w.last_event_seq()
	_hit(w, 1, SimEvent.TAG_MELEE, 10)
	assert_eq(_amounts(_events(w, SimEvent.Kind.DAMAGE, &"", before)), [12], "chilled: +20%")
	a.frozen_t[1] = 30
	a.frost_stacks[1] = 0
	before = w.last_event_seq()
	_hit(w, 1, SimEvent.TAG_MELEE, 10)
	assert_eq(_amounts(_events(w, SimEvent.Kind.DAMAGE, &"", before)), [16], "frozen: +60%")


func test_cold_snap_chills_what_you_dash_through() -> void:
	var w := _world([K.COLD_SNAP], [Vector2(2.0, 0)])
	w.step(_f(0, InputFrame.DASH, 0))
	while w.is_dashing():
		w.step(_f(0, 0, 0))
	assert_eq(w.actors.frost_stacks[1], 2)
	assert_eq(_events(w, SimEvent.Kind.STATUS_APPLY, &"cold_snap").size(), 1)


# --- Guard charges --------------------------------------------------------------------------------------------
func test_bulwark_stores_three_charges_and_the_next_swing_spends_them() -> void:
	var w := _world([K.BULWARK], [Vector2(1.2, 0)], PlayerTable.Utility.GUARD)
	var a := w.actors
	w.step(_f(U))
	assert_true(w.guarding())
	for k in 4:
		a.invuln[0] = 0
		Damage.hit(w, 0, 20, a.ids[1], a.ids[1], 50 + k, 0, Vector2(3, 0), a.pos(0))
	assert_eq(w.guard_charges, 3, "at most three")
	_idle(w, 30)  # the hurt hit-stops pass
	var before := w.last_event_seq()
	_swing(w)
	var dmg := _events(w, SimEvent.Kind.DAMAGE, &"", before).filter(
		func(e: SimEvent) -> bool: return e.target_id == a.ids[1]
	)
	assert_eq(_amounts(dmg), [22], "10 × (1 + 3 × 0.4)")
	assert_eq(w.guard_charges, 0, "spent")
	before = w.last_event_seq()
	_swing(w)
	var plain := _events(w, SimEvent.Kind.DAMAGE, &"", before).filter(
		func(e: SimEvent) -> bool: return e.target_id == a.ids[1]
	)
	assert_eq(_amounts(plain), [10], "no charges, no bonus")


# --- Loop rules -----------------------------------------------------------------------------------------------
func test_dot_never_feeds_an_engine() -> void:
	var w := _world([K.EMBER_EDGE, K.CONDUCTOR, K.SERRATED_EDGE, K.GLACIAL_EDGE])
	var a := w.actors
	_swing(w)
	var stacks := [a.shock_stacks[1], a.bleed_stacks[1], a.frost_stacks[1]]
	assert_eq(stacks, [1, 1, 1])
	_idle(w, 120)
	assert_gt(_events(w, SimEvent.Kind.DAMAGE, &"ember_edge").size(), 0, "the burn ticked")
	assert_gt(_events(w, SimEvent.Kind.DAMAGE, &"bleed").size(), 0, "the bleed ticked")
	assert_eq(_events(w, SimEvent.Kind.STATUS_APPLY, &"shock").size(), 1, "only the swing's")
	assert_eq(_events(w, SimEvent.Kind.STATUS_APPLY, &"bleed").size(), 1)


func test_ancestry_and_the_watchdog() -> void:
	var w := _world([K.CONDUCTOR])
	assert_true(Engines.begin(w, &"plasma_arc"))
	assert_false(Engines.begin(w, &"plasma_arc"), "an effect never re-enters its own chain")
	assert_eq(_events(w, SimEvent.Kind.LIMIT).size(), 0, "ancestry is a rule, not a limit")
	Engines.end(w)
	for k in Engines.MAX_DEPTH:
		w.engine_chain.append(StringName("fx_%d" % k))
	assert_false(Engines.begin(w, &"deep"))
	var lim := _events(w, SimEvent.Kind.LIMIT)
	assert_eq(lim.size(), 1, "one LIMIT names the guard")
	assert_eq(lim[0].effect_id, &"deep")
	assert_eq(lim[0].amount, Engines.MAX_DEPTH)


func test_engine_state_is_hashed_but_item_free_worlds_hash_as_before() -> void:
	var w := _world([K.CONDUCTOR])
	var h := w.state_hash()
	w.actors.shock_stacks[1] = 2
	assert_ne(w.state_hash(), h, "statuses are hashed")
	h = w.state_hash()
	w.guard_charges = 1
	assert_ne(w.state_hash(), h, "guard charges are hashed")
	h = w.state_hash()
	w.proc_ledger.try_mark(1, 2, 3, w.tick)
	assert_ne(w.state_hash(), h, "the root ledger is hashed")
	var plain := World.new(5, PlayerTable.starting_values())
	plain.add_dummy(Vector2(1, 0), 0.35, 10)
	var h0 := plain.state_hash()
	plain.actors.shock_stacks[1] = 3
	assert_eq(plain.state_hash(), h0, "no items in the loadout: the engine section isn't hashed")
