extends GutTest
## v0.11.0 O13c (ENEMIES.md R5-R8; owner Q22): the Red Canyon's and the Frozen Shore's signature enemies (CanyonShore).
## Each one's behaviour, its tell and its answer: the Kiln Beetle's burst comes 1 s after it dies, hurts the hero and
## the enemies in it, and erupts a vent it fell on; the Cinder Priest's vent erupts on a 3 s rhythm, warned by its
## pulse, and stops when the priest dies; the Frost Spitter's arc marks the landing and its slick slides the hero,
## never an enemy; the Glacier Turtle's shell blocks hits from the front but not the back, and broken, its chunks hurt
## enemies. And the same seed gives the same floor.

const KIND := ActorStore.Kind
const LONG := 1 << 24

var _tables: Array[EnemyTable] = []


func before_all() -> void:
	_tables = CombatLab.tables()


## A wall-less world, the hero at the origin (invulnerable unless `hurt`).
func _world(hurt := false) -> World:
	var w := World.new(11, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	if not hurt:
		w.actors.invuln[0] = LONG
	return w


func _enemy(w: World, kind: int, at: Vector2) -> int:
	w.add_enemy(kind, at)
	var i := w.actors.size() - 1
	w.actors.invuln[i] = 0
	return i


func _steps(w: World, n: int, f: InputFrame = InputFrame.new()) -> void:
	for _k in n:
		w.step(f)


## Kills actor i outright (from its own spot: no armour, no shell).
func _kill(w: World, i: int) -> void:
	Damage.hit(w, i, 99999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))


## The DAMAGE events with `effect` over the next n ticks, as [tick, target id] each; the hero held at `hold` when given.
func _hits(w: World, effect: StringName, n: int, hold := Vector2.INF) -> Array:
	var out := []
	for _t in n:
		var seq := w.last_event_seq()
		w.step(InputFrame.new())
		if hold != Vector2.INF:
			w.actors.set_pos(0, hold)
			w.vel = Vector2.ZERO
		for e in w.events_since(seq):
			if e.kind == SimEvent.Kind.DAMAGE and e.effect_id == effect:
				out.append([e.tick, e.target_id])
	return out


# --- R5 Kiln Beetle ------------------------------------------------------------------------------------------------
func test_the_kiln_beetles_burst_comes_a_second_after_it_dies_and_hurts_everyone_in_it() -> void:
	var w := _world(true)
	var t := w.enemy_table(KIND.KILN_BEETLE)
	assert_eq(t.burst_delay_ticks, 60, "1 s")
	assert_eq(t.burst_radius_m, 2.5)
	var b := _enemy(w, KIND.KILN_BEETLE, Vector2(1.5, 0))
	w.actors.invuln[0] = LONG  # (its slam meanwhile)
	var near := w.actors.ids[_enemy(w, KIND.CINDER_PRIEST, Vector2(2.5, 1.0))]  # (no attack of its own)
	var far := w.actors.ids[_enemy(w, KIND.CINDER_PRIEST, Vector2(9.0, 0))]
	_steps(w, SimTick.SPAWN_IN_TICKS + 2)
	_kill(w, b)
	_steps(w, 1)  # it leaves in phase 9: its burst stands where it fell
	assert_eq(w.canyon_shore.burst_count(), 1, "the burst waits")
	w.actors.invuln[0] = 0
	var hits := _hits(w, CanyonShore.BURST_EFFECT, 70, Vector2.ZERO)
	var ids := hits.map(func(h: Array) -> int: return h[1])
	assert_has(ids, w.actors.ids[0], "the hero in it is hurt")
	assert_has(ids, near, "so is an enemy in it")
	assert_does_not_have(ids, far, "not one outside it")
	var fell := w.tick - 70 - 1
	for h: Array in hits:
		assert_gte(int(h[0]) - fell, 59, "never before its second (its circle: the warning)")
	assert_eq(w.canyon_shore.burst_count(), 0)


func test_the_beetles_burst_erupts_the_vent_it_fell_on() -> void:
	var w := _world()
	var p := w.enemy_table(KIND.CINDER_PRIEST)
	w.canyon_shore.add_vent(Vector2(4, 4), p.vent_radius_m, 999, -1, 180, 45, 10)
	w.canyon_shore.vent_until[0] = w.tick + 100000  # a cooling vent: no rhythm of its own
	var b := _enemy(w, KIND.KILN_BEETLE, Vector2(4.2, 4))
	_steps(w, SimTick.SPAWN_IN_TICKS + 2)
	_kill(w, b)
	_steps(w, 30)
	assert_eq(w.canyon_shore.vent_last[0], -1, "not yet")
	_steps(w, 40)
	assert_gt(w.canyon_shore.vent_last[0], 0, "the burst erupted the vent under it")


func test_a_death_by_the_burst_names_it() -> void:
	var w := _world(true)
	w.canyon_shore.add_burst(Vector2.ZERO, 2.5, w.tick, w.tick + 60, 999, 1)
	_steps(w, 61)
	assert_true(w.player_dead())
	assert_eq(BossCauses.key(w), CanyonShore.CAUSE_BURST)
	assert_ne(tr(CanyonShore.CAUSE_BURST), String(CanyonShore.CAUSE_BURST), "its recap line exists")


# --- R6 Cinder Priest ----------------------------------------------------------------------------------------------
func test_the_cinder_priest_plants_a_vent_that_erupts_every_3_s_until_it_dies() -> void:
	var w := _world(true)
	var t := w.enemy_table(KIND.CINDER_PRIEST)
	assert_eq(t.vent_period_ticks, 180, "3 s")
	assert_gte(
		t.vent_warn_ticks, SimTick.MIN_TELEGRAPH_TICKS, "its pulse shows the telegraph minimum"
	)
	var i := _enemy(w, KIND.CINDER_PRIEST, Vector2(6, 0))
	var id := w.actors.ids[i]
	CombatLab.until(w, func(_w: World) -> bool: return w.canyon_shore.vent_of(id) >= 0, 400)
	var k := w.canyon_shore.vent_of(id)
	assert_gte(k, 0, "it planted a vent (no vent near)")
	var vent := w.canyon_shore.vent_pos(k)
	assert_lt(Kin.length(vent), Kin.length(w.actors.pos(i)), "between it and the hero")
	# The hero stands in the column: each eruption hurts it, 180 ticks apart, each after the pulse.
	w.actors.invuln[0] = 0
	var pulses := 0
	var hits := []
	for _t in 560:
		var seq := w.last_event_seq()
		w.step(InputFrame.new())
		w.actors.set_pos(0, vent)
		w.vel = Vector2.ZERO
		w.actors.hp[0] = w.actors.max_hp[0]
		if CanyonShore.vent_pulse(w, w.canyon_shore.vent_of(id)) > 0:
			pulses += 1
		for e in w.events_since(seq):
			if e.kind == SimEvent.Kind.DAMAGE and e.effect_id == CanyonShore.VENT_EFFECT:
				hits.append(e.tick)
	assert_eq(hits.size(), 3, "three eruptions in 560 ticks")
	assert_eq(hits[1] - hits[0], 180)
	assert_eq(hits[2] - hits[1], 180)
	assert_gte(pulses, 3 * (t.vent_warn_ticks - 1), "each one pulsed first")
	# The priest dies: the rhythm stops; the vent cools and goes.
	_kill(w, w.actors.index_of(id))
	var after := _hits(w, CanyonShore.VENT_EFFECT, 400, vent)
	assert_eq(after, [], "no eruption once the priest is dead")
	_steps(w, t.vent_linger_ticks)
	assert_eq(w.canyon_shore.vent_count(), 0, "the temporary vent goes")


func test_a_priest_takes_a_cooling_vent_near_it() -> void:
	var w := _world()
	w.canyon_shore.add_vent(Vector2(4, 0), 1.0, 999, -1, 180, 45, 10)
	w.canyon_shore.vent_until[0] = w.tick + 100000
	var i := _enemy(w, KIND.CINDER_PRIEST, Vector2(6, 0))
	var id := w.actors.ids[i]
	CombatLab.until(w, func(_w: World) -> bool: return w.canyon_shore.vent_of(id) >= 0, 400)
	assert_eq(w.canyon_shore.vent_count(), 1, "no new vent")
	assert_eq(w.canyon_shore.vent_of(id), 0, "it keeps the old one")


func test_the_priest_never_attacks() -> void:
	var w := _world()
	var i := _enemy(w, KIND.CINDER_PRIEST, Vector2(3, 0))
	for _t in 600:
		w.step(InputFrame.new())
		assert_ne(w.actors.state[i], EnemyAi.State.WINDUP, "no windup of its own")


# --- R7 Frost Spitter ----------------------------------------------------------------------------------------------
func test_the_frost_spitters_arc_marks_the_landing_and_leaves_a_slick_there() -> void:
	var w := _world()
	var i := _enemy(w, KIND.FROST_SPITTER, Vector2(6.5, 0))
	var t := w.enemy_table(KIND.FROST_SPITTER)
	CombatLab.until(
		w, func(_w: World) -> bool: return w.actors.state[i] == EnemyAi.State.WINDUP, 600
	)
	var tg := EnemyAi.telegraph(w, i)
	assert_eq(tg.get("shape"), &"ice_arc", "the blue arc")
	assert_eq(tg["to"], w.player_pos(), "to where the hero stands")
	assert_gte(t.windup_ticks, SimTick.MIN_TELEGRAPH_TICKS)
	CombatLab.until(w, func(_w: World) -> bool: return w.canyon_shore.blob_count() > 0, 120)
	var land := Vector2(w.canyon_shore.blob_tx[0], w.canyon_shore.blob_ty[0])
	assert_eq(land, Vector2(tg["to"]), "it lands where the arc marked (the hero stood still)")
	_steps(w, t.flight_ticks + 1)
	assert_eq(w.canyon_shore.blob_count(), 0, "landed")
	assert_gt(Variants.slick_at(w, land), 0, "a slick there")
	var k := w.variants.trail_count() - 1
	assert_eq(w.variants.trail_until[k] - w.variants.trail_born[k], 360, "6 s")
	assert_eq(w.variants.trail_r[k], 1.0, "2 m across")
	assert_eq(w.actors.hp[0], w.player.hp, "the blob hurts nobody")


## The hero runs right for 40 ticks, then pushes left for 10: its x velocity then (on a spitter's slick or not).
func _turn_velocity(slick: bool) -> float:
	var w := _world()
	if slick:
		var s := w.canyon_shore
		var t := w.enemy_table(KIND.FROST_SPITTER)
		s.add_blob(Vector2(5, 0), Vector2(1, 0), 30.0, 0, 1, 999, 100000, t.slick_permille)
	_steps(w, 40, InputFrame.make(Vector2i(SimTick.MOVE_MAX, 0), 0, 0, 0, 0))
	_steps(w, 10, InputFrame.make(Vector2i(-SimTick.MOVE_MAX, 0), 0, 0, 0, 0))
	return w.vel.x


func test_the_spitters_slick_slides_the_hero_and_not_the_enemies() -> void:
	assert_lt(_turn_velocity(false), 0.0, "on dry ground the hero has turned round")
	assert_gt(_turn_velocity(true), 0.0, "on the slick it still slides the old way")
	var runs := []
	for slick in [false, true]:
		var w := _world()
		if slick:
			w.canyon_shore.add_blob(Vector2(5, 0), Vector2(4, 0), 30.0, 0, 1, 999, 100000, 40)
		var e := _enemy(w, KIND.WARDEN, Vector2(8, 0))
		_steps(w, 90)
		runs.append(w.actors.pos(e))
	assert_eq(runs[0], runs[1], "an enemy walks the slick as ground")


# --- R8 Glacier Turtle ---------------------------------------------------------------------------------------------
## A turtle at (3, 0) facing the hero (west), risen.
func _turtle(w: World) -> int:
	var i := _enemy(w, KIND.GLACIER_TURTLE, Vector2(3, 0))
	_steps(w, SimTick.SPAWN_IN_TICKS + 2)
	w.actors.facing[i] = Kin.angle_of(Vector2(-1, 0))
	return i


func _shoot(w: World, i: int, from: Vector2, amount: int) -> int:
	var hero := w.actors.ids[0]
	var seq := w.last_event_seq()
	Damage.hit(
		w, i, amount, hero, hero, w.take_root(), SimEvent.TAG_PROJECTILE, from, w.actors.pos(i)
	)
	var tags := 0
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.HIT:
			tags |= e.tags
	return tags


func test_the_turtles_shell_blocks_shots_from_the_front_and_not_the_back() -> void:
	var w := _world()
	var i := _turtle(w)
	var hp := w.actors.hp[i]
	var tags := _shoot(w, i, Vector2(2, 0), 10)
	assert_true(tags & SimEvent.TAG_BLOCKED != 0, "a front shot sparks off the shell")
	assert_eq(w.actors.hp[i], hp, "the turtle takes nothing")
	var t := w.enemy_table(KIND.GLACIER_TURTLE)
	assert_eq(
		w.canyon_shore.shell_of(w.actors.ids[i], t.shell_hp), t.shell_hp - 10, "the shell does"
	)
	_shoot(w, i, Vector2(4, 0), 10)
	assert_lt(w.actors.hp[i], hp, "a shot in the back lands")
	assert_true(CanyonShore.shell_on(w, i))


func test_the_turtle_turns_slowly_to_face_the_hero() -> void:
	var w := _world()
	var i := _turtle(w)
	w.actors.facing[i] = Kin.angle_of(Vector2(1, 0))  # its back to the hero
	_steps(w, 10)
	var off := Kin.angle_diff(w.actors.facing[i], Kin.angle_of(w.player_pos() - w.actors.pos(i)))
	assert_gt(off, 1024, "after 10 ticks it is still far from facing the hero")
	_steps(w, 300)
	off = Kin.angle_diff(w.actors.facing[i], Kin.angle_of(w.player_pos() - w.actors.pos(i)))
	assert_lt(off, 341, "in time it faces the hero (within 30 degrees; its slam holds its facing)")


func test_the_broken_shell_bursts_into_3_chunks_that_hurt_enemies() -> void:
	var w := _world()
	var i := _turtle(w)
	var t := w.enemy_table(KIND.GLACIER_TURTLE)
	var behind := w.actors.ids[_enemy(w, KIND.CHARGER, Vector2(6.0, 0.2))]
	var hp := w.actors.hp[i]
	_shoot(w, i, Vector2(2, 0), t.shell_hp)
	assert_false(CanyonShore.shell_on(w, i), "broken")
	assert_eq(w.actors.hp[i], hp, "the breaking hit is the shell's")
	assert_eq(w.canyon_shore.chunk_count(), 3, "three chunks")
	for k in 3:
		assert_gt(w.canyon_shore.chunk_vx[k], 0.0, "each slides away from the hit")
	var hits := _hits(w, CanyonShore.CHUNK_EFFECT, 80)
	var ids := hits.map(func(h: Array) -> int: return h[1])
	assert_has(ids, behind, "a chunk hurt the enemy behind it")
	assert_does_not_have(ids, w.actors.ids[i], "never the turtle itself")
	assert_lte(ids.count(behind), 3, "each chunk hurts it once at most")
	_shoot(w, i, Vector2(2, 0), 10)
	assert_lt(w.actors.hp[i], hp, "with the shell gone, a front shot lands")


# --- Determinism -----------------------------------------------------------------------------------------------
func _scene_hash(seed_value: int) -> String:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	w.actors.invuln[0] = LONG
	for k in [KIND.KILN_BEETLE, KIND.CINDER_PRIEST, KIND.FROST_SPITTER, KIND.GLACIER_TURTLE]:
		_enemy(w, k, Kin.dir(k * 700) * 6.0)
	for t in 900:
		w.step(InputFrame.make(Vector2i(SimTick.MOVE_MAX / 2, 0), t * 13 % 4096, 0, 0, 0))
		if t == 400:
			for j in range(1, w.actors.size()):
				_kill(w, j)
	assert_true(w.canyon_shore.touched, "they left something")
	return w.state_hash()


func test_the_same_seed_gives_the_same_floor() -> void:
	assert_eq(_scene_hash(5), _scene_hash(5))
