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


func test_wildfire_spreads_burn_from_a_kill() -> void:
	var w := _world([K.WILDFIRE, K.EMBER_EDGE], [Vector2(1.2, 0), Vector2(2.5, 0), Vector2(8, 0)])
	var a := w.actors
	a.burn_stacks[1] = 4
	a.burn_t[1] = 100
	_hit(w, 1, SimEvent.TAG_MELEE, 9999)
	assert_eq(a.burn_stacks[2], 3, "1 + half the victim's 4 stacks")
	assert_eq(a.burn_stacks[3], 0, "8 m away: out of the 2.5 m spread")
	assert_eq(_events(w, SimEvent.Kind.STATUS_APPLY, &"wildfire").size(), 1)


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
func test_ancestry_and_the_watchdog() -> void:
	var w := _world([K.CONDUCTOR])
	assert_true(Engines.begin(w, &"shock_discharge"))
	assert_false(Engines.begin(w, &"shock_discharge"), "an effect never re-enters its own chain")
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
