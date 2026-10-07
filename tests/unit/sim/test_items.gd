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
	_idle(w, w.player.swing_ticks + 2)


func test_the_first_eight_kinds_are_shipped() -> void:
	for k in range(K.LONG_EDGE, K.OVERCHARGE + 1):
		assert_ne(_index(k), -1, "kind %d is shipped" % k)


func test_long_edge_hits_where_a_plain_swing_misses() -> void:
	var far := [Vector2(2.4, 0)]
	var plain := _world([], far)
	_swing(plain)
	assert_eq(_damage(plain).size(), 0, "plain reach 1.6 m misses an enemy edge 2.05 m out")
	var w := _world([K.LONG_EDGE], far)
	_swing(w)
	assert_eq(_amounts(_damage(w)), [10], "Long Edge reaches 2.16 m")
	var r := WorldReader.new(w)
	assert_almost_eq(r.swing_reach_m(), 1.6 * 1.35, 1e-5)
	assert_eq(r.swing_shape()[1], r.swing_reach_m(), "the drawn blade is the hit reach")


func test_twin_arc_echoes_once_at_half_damage_six_ticks_later() -> void:
	var w := _world([K.TWIN_ARC])
	_swing(w)
	var d := _damage(w)
	assert_eq(_amounts(d), [10, 5])
	assert_eq(d[1].tick - d[0].tick, 6 + w.player.swing_hitstop_ticks, "0.1 s plus the hit-stop")
	assert_eq(d[1].root_id, d[0].root_id, "the echo belongs to the swing's chain")
	assert_eq(d[1].effect_id, &"twin_arc")
	assert_true(d[1].tags & SimEvent.TAG_MELEE != 0)
	assert_eq(WorldReader.new(w).echo_tick(), d[1].tick)


func test_twin_arc_echo_rechecks_the_arc() -> void:
	var w := _world([K.TWIN_ARC])
	w.step(_f(0, P))
	_idle(w, 2)
	w.actors.set_pos(1, Vector2(-3, 0))  # leaves the arc before the echo
	_idle(w, 20)
	assert_eq(_amounts(_damage(w)), [10])


func test_ember_burns_as_dot_six_ticks_of_two() -> void:
	var w := _world([K.EMBER_EDGE])
	_swing(w)
	assert_eq(w.actors.burn_stacks[1], 1)
	_idle(w, 200)
	var dots := _damage(w, SimEvent.TAG_DOT)
	assert_eq(_amounts(dots), [2, 2, 2, 2, 2, 2], "2 every 0.5 s for 3 s")
	for k in range(1, dots.size()):
		assert_eq(dots[k].tick - dots[k - 1].tick, 30)
	for e in dots:
		assert_eq(e.proc_pct, 0)
		assert_eq(e.parent_seq, -1, "no HIT before a DoT tick")
		assert_eq(e.effect_id, &"ember_edge")
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.HIT:
			assert_eq(e.tags & SimEvent.TAG_DOT, 0, "DoT never emits a HIT")
	assert_eq(w.actors.burn_stacks[1], 0, "the burn ran out")
	assert_eq(_count_kind(w, SimEvent.Kind.STATUS_APPLY), 1, "DoT ticks never re-apply the burn")


func test_ember_stacks_cap_at_five_and_scale_the_tick() -> void:
	var w := _world([K.EMBER_EDGE])
	for i in 7:
		_swing(w)
	assert_eq(w.actors.burn_stacks[1], 5)
	assert_eq(WorldReader.new(w).burn_stacks(1), 5)
	var after := w.last_event_seq()
	_idle(w, 31)
	var dots := w.events_since(after).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.DAMAGE
	)
	assert_eq(dots.size(), 1)
	assert_eq(dots[0].amount, 10, "5 stacks x 2")


func test_ember_with_twin_arc_burns_once_per_chain() -> void:
	var w := _world([K.EMBER_EDGE, K.TWIN_ARC])
	_swing(w)
	assert_eq(_amounts(_damage(w, SimEvent.TAG_MELEE)), [10, 5], "swing and echo both land")
	assert_eq(w.actors.burn_stacks[1], 1, "one stack per root chain per target")


func test_splinter_fires_three_bolts_in_a_fan_at_sixty_percent() -> void:
	var w := _world([K.SPLINTER_SHOT], [])
	w.step(_f(InputFrame.SHOOT))
	assert_eq(w.projectiles.size(), 3)
	var angles := []
	for k in 3:
		assert_eq(w.projectiles.damage[k], 2, "4 x 0.6 = 2.4, rounded down")
		var a := Kin.angle_of(Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k]))
		angles.append(a if a < 2048 else a - 4096)
	angles.sort()
	assert_almost_eq(angles[0], -68, 1)
	assert_almost_eq(angles[1], 0, 1)
	assert_almost_eq(angles[2], 68, 1, "a 12 degree fan is 137 units wide")


func test_rapid_coil_shortens_the_shot_period() -> void:
	var plain := _world([], [])
	var w := _world([K.RAPID_COIL], [])
	for i in 25:
		plain.step(_f(InputFrame.SHOOT))
		w.step(_f(InputFrame.SHOOT))
	assert_eq(plain.projectiles.size(), 4, "every 7 ticks")
	assert_eq(w.projectiles.size(), 5, "every 5 ticks: 7 / 1.4")
	assert_eq(WorldReader.new(w).shot_period_ticks(), 5)


func _walled(kinds: Array) -> World:
	var w := _world(kinds, [])
	var walls: Array[Obb] = [
		Obb.make(Vector2(3.5, 0), Vector2(0.5, 5), 0),
		Obb.make(Vector2(-3.5, 0), Vector2(0.5, 5), 0)
	]
	w.set_walls(walls)
	return w


func test_ricochet_bounces_once_then_dies_on_the_next_wall() -> void:
	var plain := _walled([])
	plain.step(_f(InputFrame.SHOOT))
	_idle(plain, 14)
	assert_eq(plain.projectiles.size(), 0, "a plain bolt ends at the wall")
	var w := _walled([K.RICOCHET_CORE])
	w.step(_f(InputFrame.SHOOT))
	assert_eq(w.projectiles.bounces[0], 1)
	_idle(w, 14)
	assert_eq(w.projectiles.size(), 1, "it bounced")
	assert_lt(w.projectiles.vel_x[0], 0.0, "heading back")
	assert_almost_eq(w.projectiles.vel_y[0], 0.0, 1e-6)
	assert_eq(w.projectiles.bounces[0], 0)
	assert_gt(WorldReader.new(w).projectile_bounce_tick(0), 0)
	_idle(w, 18)
	assert_eq(w.projectiles.size(), 0, "the second wall ends it before its life runs out")


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
	w.step(_f(0, InputFrame.DASH, back))
	_idle(w, 20)
	assert_eq(_amounts(_damage(w, SimEvent.TAG_DASH)), [12, 12], "the next dash hits it again")


func test_overcharge_every_fourth_swing_doubles_and_shockwaves() -> void:
	var w := _world([K.OVERCHARGE], [Vector2(1.2, 0), Vector2(-1.5, 0)])
	var r := WorldReader.new(w)
	for i in 3:
		assert_false(r.overcharge_ready(), "swing %d" % (i + 1))
		_swing(w)
	assert_true(r.overcharge_ready())
	_swing(w)
	assert_false(r.overcharge_ready())
	var d := _damage(w)
	assert_eq(
		_amounts(d),
		[10, 10, 18, 20, 5, 5],
		"the combo, then 10 x 2 and a 5-damage shockwave on both"
	)
	assert_eq(d[4].tags & SimEvent.TAG_AREA, SimEvent.TAG_AREA)
	assert_eq(d[5].target_id, w.actors.ids[2], "the shockwave reaches behind the player")
	assert_eq(d[4].root_id, d[3].root_id)
	assert_eq(r.overcharge_tick(), d[3].tick)


func test_items_stack() -> void:
	var w := _world([K.SPLINTER_SHOT, K.RICOCHET_CORE, K.RAPID_COIL], [])
	w.step(_f(InputFrame.SHOOT))
	_idle(w, 1)
	assert_eq(w.projectiles.size(), 3)
	for k in 3:
		assert_eq(w.projectiles.bounces[k], 1)
	assert_eq(ItemEffects.shot_period_ticks(w), 5)
	var r := WorldReader.new(w)
	assert_eq(r.item_count(), 3)
	assert_true(r.has_item_kind(WorldReader.ITEM_RICOCHET_CORE))
	assert_false(r.has_item_kind(WorldReader.ITEM_OVERCHARGE))
	assert_false(w.add_item(_index(K.RAPID_COIL)), "no duplicates")


func _count_kind(w: World, kind: SimEvent.Kind) -> int:
	return w.events_since(0).filter(func(e: SimEvent) -> bool: return e.kind == kind).size()


func test_walking_over_a_pickup_takes_it() -> void:
	var w := _world([], [])
	var idx := _index(K.LONG_EDGE)
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
	assert_almost_eq(r.swing_reach_m(), 1.6 * 1.35, 1e-5, "the item works at once")


func test_the_pool_never_repeats_and_skips_owned_and_placed() -> void:
	var w := _world([], [])
	var all := ItemPool.draw(w, 20)
	assert_eq(all.size(), 16)
	var seen := {}
	for i in all:
		seen[i] = true
	assert_eq(seen.size(), 16, "no repeats")
	var v := _world([], [])
	v.add_item(0)
	v.add_pickup(1, Vector2(5, 5))
	var some := ItemPool.draw(v, 3)
	assert_eq(some.size(), 3)
	for i in some:
		assert_false(i in [0, 1])
		v.add_pickup(i, Vector2(5, 5))
	var rest := ItemPool.draw(v, 16)
	assert_eq(rest.size(), 11, "16 - owned - 4 placed")
	for i in rest:
		assert_false(i in some or i in [0, 1])


func test_pool_draws_are_deterministic_by_seed() -> void:
	var a := ItemPool.draw(_world([], [], 41), 8)
	var b := ItemPool.draw(_world([], [], 41), 8)
	assert_eq(a, b)
	var c := _world([], [], 41)
	var before := c.rng_loot.state
	ItemPool.draw(c, 2)
	assert_ne(c.rng_loot.state, before, "draws use the loot stream")


func test_item_state_is_hashed_and_deterministic() -> void:
	var kinds := [K.TWIN_ARC, K.EMBER_EDGE, K.KINETIC_DASH, K.OVERCHARGE, K.SPLINTER_SHOT]
	var a := _world(kinds)
	var b := _world(kinds)
	a.add_pickup(_index(K.LONG_EDGE), Vector2(-4, 0))
	b.add_pickup(_index(K.LONG_EDGE), Vector2(-4, 0))
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
	c.add_item(_index(K.LONG_EDGE))
	assert_ne(c.state_hash(), h, "owning an item changes the hash")
	h = c.state_hash()
	c.add_pickup(_index(K.RAPID_COIL), Vector2(1, 1))
	assert_ne(c.state_hash(), h, "pickups are hashed")
