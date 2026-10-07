extends GutTest
## v0.2.0 J: the second eight items, with the shipped data's numbers. Aim angle 0 = +x.

const P := InputFrame.PRIMARY
const S := InputFrame.SHOOT
const U := InputFrame.UTILITY
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
func _world(
	kinds: Array = [],
	enemies: Array = [Vector2(1.2, 0)],
	utility: int = PlayerTable.Utility.NONE,
	seed_value: int = 3
) -> World:
	var t := PlayerTable.starting_values()
	t.utility = utility
	var w := World.new(seed_value, t)
	w.dummy_speed = 0.0
	w.set_item_tables(_tables)
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


func _events(w: World, kind: SimEvent.Kind, tag: int = 0, after: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(after):
		if e.kind == kind and (tag == 0 or e.tags & tag):
			out.append(e)
	return out


func _amounts(events: Array[SimEvent]) -> Array:
	return events.map(func(e: SimEvent) -> int: return e.amount)


func _swing(w: World, aim: int = 0) -> void:
	w.step(_f(0, P, aim))
	_idle(w, w.player.step(w.combo_step).ticks + 2, 0, aim)


## The player kills actor i outright with a melee hit (a fresh root).
func _kill(w: World, i: int) -> void:
	var a := w.actors
	Damage.hit(
		w, i, 9999, a.ids[0], a.ids[0], w.take_root(), SimEvent.TAG_MELEE, a.pos(0), a.pos(i)
	)


func test_the_data_has_distinct_kinds() -> void:
	assert_eq(_tables.size(), 24, "16 + the 8 engine items (v0.3.0 G)")
	var kinds := {}
	for t in _tables:
		kinds[t.kind] = true
	assert_eq(kinds.size(), 24)
	for k in range(K.VAMPIRIC_CORE, K.PHASE_STRIKE + 1):
		assert_ne(_index(k), -1, "kind %d is shipped" % k)


# --- Vampiric Core ------------------------------------------------------------------------------------------
func test_vampiric_core_heals_three_per_kill_up_to_fifteen_per_five_seconds() -> void:
	var spots := []
	for k in 8:
		spots.append(Vector2(10 + k, 10))
	var w := _world([K.VAMPIRIC_CORE], spots)
	var r := WorldReader.new(w)
	w.actors.hp[0] = 50
	assert_eq(r.heal_cap_left(), 15)
	for i in range(1, 7):
		_kill(w, i)
	assert_eq(w.actors.hp[0], 65, "5 kills x 3, then the cap")
	var heals := _events(w, SimEvent.Kind.HEAL)
	assert_eq(heals.size(), 6, "every request is logged")
	assert_eq(heals.map(func(e: SimEvent) -> int: return e.amount_applied), [3, 3, 3, 3, 3, 0])
	assert_eq(_amounts(heals), [3, 3, 3, 3, 3, 3], "amount is the request")
	var kills := _events(w, SimEvent.Kind.KILL)
	for k in heals.size():
		assert_eq(heals[k].parent_seq, kills[k].seq, "a heal is the kill's child")
		assert_eq(heals[k].root_id, kills[k].root_id)
		assert_eq(heals[k].depth, kills[k].depth + 1)
		assert_eq(heals[k].effect_id, &"vampiric_core")
		assert_eq(heals[k].target_id, w.actors.ids[0])
	var limits := _events(w, SimEvent.Kind.LIMIT)
	assert_eq(limits.size(), 1, "the clipped request logs a LIMIT")
	assert_eq(limits[0].amount_applied, 0)
	assert_eq(r.heal_cap_left(), 0)
	assert_eq(r.heal_tick(), heals[4].tick)
	_idle(w, 300)
	assert_eq(r.heal_cap_left(), 15, "a new window after 5 s")
	_kill(w, 1)
	assert_eq(w.actors.hp[0], 68)


func test_vampiric_core_never_overheals_and_needs_a_player_kill() -> void:
	var w := _world([K.VAMPIRIC_CORE], [Vector2(10, 0), Vector2(12, 0), Vector2(14, 0)])
	w.actors.hp[0] = 99
	_kill(w, 1)
	assert_eq(w.actors.hp[0], 100, "never above max")
	assert_eq(_events(w, SimEvent.Kind.HEAL)[0].amount_applied, 1)
	assert_eq(WorldReader.new(w).heal_cap_left(), 14, "only HP gained spends the cap")
	w.actors.hp[0] = 50
	var a := w.actors
	Damage.hit(w, 2, 9999, a.ids[3], a.ids[3], w.take_root(), 0, a.pos(3), a.pos(2))
	assert_eq(a.dead[2], 1)
	assert_eq(w.actors.hp[0], 50, "an enemy's kill heals nobody")
	var plain := _world([], [Vector2(10, 0)])
	plain.actors.hp[0] = 50
	_kill(plain, 1)
	assert_eq(plain.actors.hp[0], 50, "no item, no heal")
	assert_eq(_events(plain, SimEvent.Kind.HEAL).size(), 0)


# --- Static Chain -------------------------------------------------------------------------------------------
## Holds SHOOT for `shots` bolts (one every 7 ticks), then lets them land.
func _shoot(w: World, shots: int, aim: int = 0) -> void:
	for t in (shots - 1) * w.player.shot_period_ticks + 1:
		w.step(_f(S, 0, aim))
	_idle(w, 20, 0, aim)


func test_static_chain_every_third_bolt_jumps_to_the_nearest_other_enemy() -> void:
	var w := _world([K.STATIC_CHAIN], [Vector2(2, 0), Vector2(2, 3.0), Vector2(2, -1.5)])
	var r := WorldReader.new(w)
	_shoot(w, 2)
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_CHAIN).size(), 0)
	assert_true(r.chain_ready())
	_shoot(w, 1)
	var bolts := _events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_PROJECTILE)
	assert_eq(_amounts(bolts), [4, 4, 4])
	var chains := _events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_CHAIN)
	assert_eq(_amounts(chains), [5], "the third bolt chains for 5")
	assert_eq(chains[0].target_id, w.actors.ids[3], "to the nearest (1.5 m, not 3 m)")
	assert_eq(chains[0].root_id, bolts[2].root_id, "inside the bolt's chain")
	assert_eq(chains[0].effect_id, &"static_chain")
	assert_eq(r.chain_tick(), chains[0].tick)
	assert_almost_eq(r.chain_to().y, -1.5, 1e-5)
	assert_false(r.chain_ready())
	_shoot(w, 3)
	assert_eq(
		_events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_CHAIN).size(), 2, "and every third after"
	)


func test_static_chain_needs_a_target_within_four_metres() -> void:
	var w := _world([K.STATIC_CHAIN], [Vector2(2, 0), Vector2(2, 4.5)])
	_shoot(w, 3)
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_PROJECTILE).size(), 3)
	assert_eq(
		_events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_CHAIN).size(), 0, "4.5 m is out of range"
	)


func test_static_chain_fires_once_per_root_and_never_from_dot() -> void:
	var w := _world([K.STATIC_CHAIN, K.EMBER_EDGE], [Vector2(1.2, 0), Vector2(1.2, 1.5)])
	_swing(w)
	_idle(w, 200)
	assert_gt(_events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_DOT).size(), 0, "the burn ticked")
	assert_eq(w.chain_count, 0, "melee and DoT never count")
	# Two landed hits of the same bolt (same root) with a chain due each time: only the first chains.
	w.item_mods.chain_every = 1
	w.projectiles.add(
		900, w.actors.ids[0], ActorStore.TEAM_PLAYER, Vector2.ZERO, Vector2.ZERO, 0.1, 10, 4
	)
	ItemProcs.on_bolt_hit(w, 1, 0, 4, w.actors.pos(1))
	ItemProcs.on_bolt_hit(w, 1, 0, 4, w.actors.pos(1))
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_CHAIN).size(), 1)
	ItemProcs.on_bolt_hit(w, 1, 0, 0, w.actors.pos(1))
	assert_eq(w.chain_count, 2, "a hit that dealt nothing doesn't count")


# --- Momentum -----------------------------------------------------------------------------------------------
## Dashes 4 m toward -x (aim 2048) and returns the ticks until the dash ends.
func _dash_back(w: World) -> int:
	w.step(_f(0, InputFrame.DASH, 2048))
	var n := 1
	while w.is_dashing():
		w.step(_f(0, 0, 2048))
		n += 1
	return n


func test_momentum_empowers_the_next_swing_after_a_dash() -> void:
	var w := _world([K.MOMENTUM], [Vector2(-5.2, 0)])
	var r := WorldReader.new(w)
	assert_false(r.momentum_ready())
	_dash_back(w)
	assert_true(r.momentum_ready())
	_swing(w, 2048)
	assert_false(r.momentum_ready(), "the swing spent it")
	_swing(w, 2048)
	assert_eq(_amounts(_events(w, SimEvent.Kind.DAMAGE)), [16, 10], "10 x 1.6, then a plain swing")
	var plain := _world([], [Vector2(-5.2, 0)])
	_dash_back(plain)
	_swing(plain, 2048)
	assert_eq(_amounts(_events(plain, SimEvent.Kind.DAMAGE)), [10])


func test_momentum_lasts_one_second() -> void:
	var w := _world([K.MOMENTUM], [Vector2(-5.2, 0)])
	var r := WorldReader.new(w)
	_dash_back(w)
	var n := 0
	while r.momentum_ready():
		w.step(_f(0, 0, 2048))
		n += 1
	assert_eq(n, 60, "60 ticks to start the swing")
	_swing(w, 2048)
	assert_eq(_amounts(_events(w, SimEvent.Kind.DAMAGE)), [10], "too late")


# --- Frost Core ---------------------------------------------------------------------------------------------
func test_frost_core_slows_on_bolt_hits_refreshing_never_stacking() -> void:
	var w := _world([K.FROST_CORE], [Vector2(2, 0)])
	var r := WorldReader.new(w)
	w.step(_f(S))
	_idle(w, 8)
	assert_true(r.actor_slowed(1))
	var applies := _events(w, SimEvent.Kind.STATUS_APPLY)
	assert_eq(applies.size(), 1)
	assert_eq(applies[0].effect_id, &"frost_core")
	assert_eq(applies[0].amount, 700)
	assert_almost_eq(ItemProcs.slow_factor(w, 1), 0.7, 1e-6)
	var hit_tick := applies[0].tick
	_shoot(w, 1)
	var second := _events(w, SimEvent.Kind.STATUS_APPLY)[1]
	assert_eq(w.actors.slow_t[1], 90 - (w.tick - second.tick), "refreshed to 1.5 s, not added")
	assert_almost_eq(ItemProcs.slow_factor(w, 1), 0.7, 1e-6, "no stacking")
	assert_gt(second.tick, hit_tick)
	_idle(w, 90)
	assert_false(r.actor_slowed(1), "it wears off")
	assert_almost_eq(ItemProcs.slow_factor(w, 1), 1.0, 1e-6)


func test_frost_core_slows_a_real_enemy_walk() -> void:
	var w := CombatLab.world()
	w.set_item_tables(_tables)
	w.add_item(_index(K.FROST_CORE))
	w.add_enemy(ActorStore.Kind.CHARGER, Vector2(10, 0))
	CombatLab.until(w, func(x: World) -> bool: return x.actors.state[1] == EnemyAi.State.MOVE)
	var before := w.actors.pos(1)
	w.step(InputFrame.new())
	var plain_step := Kin.length(w.actors.pos(1) - before)
	assert_almost_eq(plain_step, 3.0 / 60.0, 1e-4)
	w.actors.slow_t[1] = 30
	before = w.actors.pos(1)
	w.step(InputFrame.new())
	assert_almost_eq(Kin.length(w.actors.pos(1) - before), plain_step * 0.7, 1e-4, "70% speed")


# --- Thorn Mantle -------------------------------------------------------------------------------------------
func test_thorn_mantle_releases_six_bolts_when_hurt() -> void:
	var w := _world([K.THORN_MANTLE], [Vector2(2.5, 0)])
	var r := WorldReader.new(w)
	var a := w.actors
	Damage.hit(w, 0, 10, a.ids[1], a.ids[1], w.take_root(), SimEvent.TAG_MELEE, a.pos(1), a.pos(0))
	Damage.hit(w, 0, 10, a.ids[1], a.ids[1], w.take_root(), SimEvent.TAG_MELEE, a.pos(1), a.pos(0))
	assert_eq(r.thorn_tick(), 0)
	_idle(w, 1)
	assert_eq(w.projectiles.size(), 0, "they wait out the hit-stop with everything else")
	_idle(w, 5)
	assert_eq(w.projectiles.size(), 6, "one ring: the second hit met the hurt i-frames")
	var angles := []
	for k in 6:
		assert_eq(w.projectiles.damage[k], 4)
		assert_eq(w.projectiles.team[k], ActorStore.TEAM_PLAYER)
		assert_ne(w.projectiles.tags[k] & SimEvent.TAG_THORN, 0)
		angles.append(Kin.angle_of(Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k])))
	angles.sort()
	for k in 6:
		assert_almost_eq(angles[k], k * 4096 / 6, 2, "evenly spaced")
	_idle(w, 10)
	var d := _events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_THORN)
	assert_eq(_amounts(d), [4], "the bolt along the facing hits the dummy")
	assert_eq(d[0].effect_id, &"thorn_mantle")


func test_no_thorns_without_the_item_or_without_damage() -> void:
	var plain := _world([], [Vector2(2.5, 0)])
	var a := plain.actors
	Damage.hit(plain, 0, 10, a.ids[1], a.ids[1], 7, 0, a.pos(1), a.pos(0))
	_idle(plain, 8)
	assert_eq(plain.projectiles.size(), 0)
	var w := _world([K.THORN_MANTLE], [Vector2(2.5, 0)])
	a = w.actors
	Damage.hit(w, 0, 0, a.ids[1], a.ids[1], 7, 0, a.pos(1), a.pos(0))
	_idle(w, 8)
	assert_eq(w.projectiles.size(), 0, "a harmless hit releases nothing")


# --- Executioner --------------------------------------------------------------------------------------------
func test_executioner_adds_half_below_thirty_percent() -> void:
	var w := _world([K.EXECUTIONER])
	var r := WorldReader.new(w)
	w.actors.hp[1] = 150
	assert_false(r.in_execute_range(1), "exactly 30% is not below")
	_swing(w)
	assert_true(r.in_execute_range(1))
	_swing(w)
	var d := _events(w, SimEvent.Kind.DAMAGE)
	assert_eq(_amounts(d), [10, 15], "10, then 10 x 1.5 on a 140/500 enemy")
	assert_eq(d[0].tags & SimEvent.TAG_EXECUTE, 0)
	assert_ne(d[1].tags & SimEvent.TAG_EXECUTE, 0)
	var dot := Damage.tick_dot(w, 1, 2, w.actors.ids[0], w.actors.ids[0], &"ember_edge")
	assert_eq(dot, 2, "DoT isn't a hit: no bonus")
	w.actors.hp[0] = 10
	var a := w.actors
	Damage.hit(w, 0, 5, a.ids[1], a.ids[1], 7, 0, a.pos(1), a.pos(0))
	assert_eq(a.hp[0], 5, "enemies don't execute you")


# --- Swift Feet ---------------------------------------------------------------------------------------------
func test_swift_feet_moves_faster_and_dashes_sooner() -> void:
	var w := _world([K.SWIFT_FEET], [])
	var plain := _world([], [])
	var r := WorldReader.new(w)
	assert_eq(r.dash_cooldown_total(), 38, "48 ticks x 0.8")
	assert_eq(WorldReader.new(plain).dash_cooldown_total(), 48)
	assert_almost_eq(r.move_speed_mps(), 6.9, 1e-4)
	for i in 40:
		w.step(_f(0, 0, 0, Vector2i(SimTick.MOVE_MAX, 0)))
		plain.step(_f(0, 0, 0, Vector2i(SimTick.MOVE_MAX, 0)))
	assert_almost_eq(Kin.length(w.vel), 6.9 / 60.0, 1e-4)
	assert_almost_eq(Kin.length(plain.vel), 6.0 / 60.0, 1e-4)
	w.step(_f(0, InputFrame.DASH))
	assert_eq(w.dash_cooldown_left, 38)


# --- Phase Strike -------------------------------------------------------------------------------------------
func test_phase_strike_discharges_on_blink_arrival() -> void:
	var w := _world([K.PHASE_STRIKE], [Vector2(6, 0), Vector2(0, 1.0)], PlayerTable.Utility.BLINK)
	w.step(_f(0, U))
	assert_almost_eq(w.player_pos().x, 5.0, 0.01)
	var d := _events(w, SimEvent.Kind.DAMAGE)
	assert_eq(_amounts(d), [12], "the ring hits around the arrival only")
	assert_eq(d[0].target_id, w.actors.ids[1])
	assert_eq(d[0].effect_id, &"phase_strike")
	assert_ne(d[0].tags & SimEvent.TAG_AREA, 0)
	var r := WorldReader.new(w)
	assert_eq(r.phase_tick(), d[0].tick)
	assert_almost_eq(r.phase_radius_m(), 1.5, 1e-6)


func test_phase_strike_on_the_first_guard_block_in_each_two_seconds() -> void:
	var w := _world([K.PHASE_STRIKE], [Vector2(1.0, 0)], PlayerTable.Utility.GUARD)
	var a := w.actors
	w.step(_f(U))
	assert_true(w.guarding())
	var front := Vector2(3, 0)
	Damage.hit(w, 0, 50, a.ids[1], a.ids[1], 7, 0, front, a.pos(0))
	assert_eq(_amounts(_events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_AREA)), [12])
	a.invuln[0] = 0
	Damage.hit(w, 0, 50, a.ids[1], a.ids[1], 8, 0, front, a.pos(0))
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_AREA).size(), 1, "once per 2 s")
	_idle(w, 120, U)
	a.invuln[0] = 0
	Damage.hit(w, 0, 50, a.ids[1], a.ids[1], 9, 0, Vector2(-3, 0), a.pos(0))
	assert_eq(
		_events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_AREA).size(),
		1,
		"a hit from behind isn't blocked"
	)
	a.invuln[0] = 0
	Damage.hit(w, 0, 50, a.ids[1], a.ids[1], 10, 0, front, a.pos(0))
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, SimEvent.TAG_AREA).size(), 2, "ready again")


# --- All together -------------------------------------------------------------------------------------------
func test_new_item_state_is_hashed_and_deterministic() -> void:
	var kinds := []
	for k in range(K.VAMPIRIC_CORE, K.PHASE_STRIKE + 1):
		kinds.append(k)
	var spots := [Vector2(2, 0), Vector2(2, 1.5), Vector2(-2, 0), Vector2(0, 2)]
	var a := _world(kinds, spots, PlayerTable.Utility.BLINK)
	var b := _world(kinds, spots, PlayerTable.Utility.BLINK)
	a.dummy_fire_period = 40
	b.dummy_fire_period = 40
	a.dummy_shot_damage = 3
	b.dummy_shot_damage = 3
	for t in 300:
		var held := S if t % 60 > 30 else 0
		var pressed := P if t % 25 == 0 else 0
		if t % 90 == 45:
			pressed = InputFrame.DASH
		if t % 150 == 100:
			pressed = U
		var f := _f(held, pressed, (t * 37) % 4096)
		a.step(f)
		b.step(f)
		assert_eq(a.state_hash(), b.state_hash(), "tick %d" % t)
	assert_gt(_events(a, SimEvent.Kind.DAMAGE).size(), 0, "the script did something")
	var h := a.state_hash()
	a.chain_count += 1
	assert_ne(a.state_hash(), h, "the chain counter is hashed")
	h = a.state_hash()
	a.actors.slow_t[0] += 1
	assert_ne(a.state_hash(), h, "slows are hashed")
	h = a.state_hash()
	a.momentum_t += 1
	assert_ne(a.state_hash(), h, "momentum is hashed")
	h = a.state_hash()
	a.heal_window_used += 1
	assert_ne(a.state_hash(), h, "the heal cap is hashed")
	h = a.state_hash()
	a.phase_guard_next += 1
	assert_ne(a.state_hash(), h, "the phase window is hashed")


func test_the_pool_draws_every_item_without_repeats() -> void:
	var w := _world([K.MOMENTUM], [])
	var all := ItemPool.draw(w, 99)
	assert_eq(all.size(), 23, "everything but the owned one")
	var seen := {}
	for i in all:
		seen[i] = true
		w.add_pickup(i, Vector2(5, 5))
	assert_eq(seen.size(), 23)
	assert_false(seen.has(_index(K.MOMENTUM)))
	assert_eq(ItemPool.draw(w, 3).size(), 0, "all placed: nothing left to draw")
