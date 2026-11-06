extends GutTest
## v0.2.0 E: the first eight items (the second eight: test_items_j.gd), pickups and the item pool, with the
## shipped data's numbers. Aim angle 0 = +x.

const P := InputFrame.PRIMARY
const K := ItemTable.Kind

var _tables: Array[ItemTable] = []


func before_all() -> void:
	_tables = ContentCompiler.compile_items(ContentRepository.load_all())


func _index(kind: int) -> int:
	for i in _tables.size():
		if _tables[i].kind == kind:
			return i
	return -1


## A world with the item tables, the given item kinds owned, and still dummies (hp 500) at `enemies`.
func _world(kinds: Array = [], enemies: Array = [Vector2(1.2, 0)], seed_value: int = 3) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.dummy_speed = 0.0
	w.set_item_tables(_tables)
	for k: int in kinds:
		assert_true(w.add_item(_index(k)), "added kind %d" % k)
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, 500)
	return w


func _f(held: int = 0, pressed: int = 0, aim: int = 0, move := Vector2i.ZERO) -> InputFrame:
	return InputFrame.make(move, aim, 300, held, pressed)


func _idle(w: World, n: int) -> void:
	for i in n:
		w.step(_f())


func _damage(w: World, tag: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.DAMAGE and (tag == 0 or e.tags & tag):
			out.append(e)
	return out


func _amounts(events: Array[SimEvent]) -> Array:
	return events.map(func(e: SimEvent) -> int: return e.amount)


func _swing(w: World, aim: int = 0) -> void:
	w.step(_f(0, P, aim))
	_idle(w, w.player.step(w.combo_step).ticks + 2)


func _walled(kinds: Array) -> World:
	var w := _world(kinds, [])
	var walls: Array[Obb] = [
		Obb.make(Vector2(3.5, 0), Vector2(0.5, 5), 0),
		Obb.make(Vector2(-3.5, 0), Vector2(0.5, 5), 0)
	]
	w.set_walls(walls)
	return w


func test_ricochet_reflects_off_an_angled_face() -> void:
	var box := Obb.make(Vector2(0, 0), Vector2(1, 1), 512)  # rotated 45 degrees
	var n := ItemEffects.wall_normal(box.center + box.axis_u * 1.1, 0.1, box)
	assert_almost_eq(n.x, box.axis_u.x, 1e-6)
	assert_almost_eq(n.y, box.axis_u.y, 1e-6)


func test_kinetic_dash_hits_each_enemy_once_per_dash() -> void:
	var plain := _world([], [Vector2(2, 0)])
	plain.step(_f(0, InputFrame.DASH))
	_idle(plain, 20)
	assert_eq(_damage(plain).size(), 0, "a plain dash deals nothing")
	var w := _world([K.KINETIC_DASH], [Vector2(2, 0)])
	w.step(_f(0, InputFrame.DASH))
	_idle(w, 20)
	var d := _damage(w, SimEvent.TAG_DASH)
	assert_eq(_amounts(d), [12], "once, for 12")
	assert_eq(d[0].effect_id, &"kinetic_dash")
	assert_eq(WorldReader.new(w).dash_hit_tick(), d[0].tick)
	_idle(w, 60)
	var back := Kin.angle_of(w.actors.pos(1) - w.player_pos())
	w.dash_cooldown_left = 0  # this test is about hits per dash, not the 10 s recharge
	w.step(_f(0, InputFrame.DASH, back))
	_idle(w, 20)
	assert_eq(_amounts(_damage(w, SimEvent.TAG_DASH)), [12, 12], "the next dash hits it again")


func _until_swing_ends(w: World) -> void:
	while w.swing_t > 0:
		w.step(_f())


func test_items_stack() -> void:
	var w := _world([K.MOMENTUM, K.EXECUTIONER, K.SWIFT_FEET], [])
	var r := WorldReader.new(w)
	assert_eq(r.item_count(), 3)
	assert_false(w.add_item(_index(K.EXECUTIONER)), "no duplicates")


func _count_kind(w: World, kind: SimEvent.Kind) -> int:
	return w.events_since(0).filter(func(e: SimEvent) -> bool: return e.kind == kind).size()


func test_walking_over_a_pickup_takes_it() -> void:
	var w := _world([], [])
	var idx := _index(K.KINETIC_DASH)
	var id := w.add_pickup(idx, Vector2(3, 0))
	var r := WorldReader.new(w)
	assert_eq(r.pickup_count(), 1)
	assert_eq(r.pickup_id(0), id)
	assert_eq(r.pickup_item(0), idx)
	_idle(w, 10)
	assert_eq(r.item_count(), 0, "not from afar")
	for i in 60:
		w.step(_f(0, 0, 0, Vector2i(SimTick.MOVE_MAX, 0)))
		if r.pickup_count() == 0:
			break
	assert_eq(r.pickup_count(), 0)
	assert_eq(Array(r.items_owned()), [idx])
	assert_lte(Kin.length(w.player_pos() - Vector2(3, 0)), ItemEffects.PICKUP_RADIUS_M + 0.11)
	var picks := w.events_since(0).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.PICKUP
	)
	assert_eq(picks.size(), 1)
	assert_eq(picks[0].amount, idx)
	assert_eq(picks[0].source_id, id)


func test_the_pool_never_repeats_and_skips_owned_and_placed() -> void:
	var w := _world([], [])
	w.player.utility = PlayerTable.Utility.GUARD  # v0.3.0 E: Bulwark is drawn only with the guard.
	var all := ItemPool.draw(w, 100)
	assert_eq(all.size(), 59, "the pool: every usable item here (retired cards are never drawn)")
	var seen := {}
	for i in all:
		seen[i] = true
	assert_eq(seen.size(), 59, "no repeats")
	var v := _world([], [])
	v.player.utility = PlayerTable.Utility.GUARD
	var first := ItemPool.available(v)  # v0.5.0 CP: index 0 may be an ability mod, never drawn here
	var held := [first[0], first[1]]
	v.add_item(held[0])
	v.add_pickup(held[1], Vector2(5, 5))
	var some := ItemPool.draw(v, 3)
	assert_eq(some.size(), 3)
	for i in some:
		assert_false(i in held)
		v.add_pickup(i, Vector2(5, 5))
	var rest := ItemPool.draw(v, 100)
	assert_eq(rest.size(), 54, "59 - owned - 4 placed")
	for i in rest:
		assert_false(i in some or i in held)


func test_pool_draws_are_deterministic_by_seed() -> void:
	var a := ItemPool.draw(_world([], [], 41), 8)
	var b := ItemPool.draw(_world([], [], 41), 8)
	assert_eq(a, b)
	var c := _world([], [], 41)
	var before := c.rng_loot.state
	ItemPool.draw(c, 2)
	assert_ne(c.rng_loot.state, before, "draws use the loot stream")


func test_item_state_is_hashed_and_deterministic() -> void:
	var kinds := [K.MOMENTUM, K.EXECUTIONER, K.KINETIC_DASH, K.SWIFT_FEET]
	var a := _world(kinds)
	var b := _world(kinds)
	a.add_pickup(_index(K.THORN_MANTLE), Vector2(-4, 0))
	b.add_pickup(_index(K.THORN_MANTLE), Vector2(-4, 0))
	for t in 240:
		var f := _f(
			InputFrame.SHOOT if t % 50 > 30 else 0, P if t % 20 == 0 else 0, (t * 37) % 4096
		)
		if t == 100:
			f = _f(0, InputFrame.DASH, 2048)
		a.step(f)
		b.step(f)
		assert_eq(a.state_hash(), b.state_hash(), "tick %d" % t)
	var c := _world(kinds)
	var h := c.state_hash()
	c.add_item(_index(K.THORN_MANTLE))
	assert_ne(c.state_hash(), h, "owning an item changes the hash")
	h = c.state_hash()
	c.add_pickup(_index(K.VAMPIRIC_CORE), Vector2(1, 1))
	assert_ne(c.state_hash(), h, "pickups are hashed")
