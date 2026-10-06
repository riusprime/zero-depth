extends GutTest
## The three v0.1.0 behaviours (owner Q3): states, attacks, shields, spacing.

const S := EnemyAi.State


func _state(w: World, id: int) -> int:
	return w.actors.state[w.actors.index_of(id)]


func test_enemies_spawn_in_untouchable() -> void:
	var w := CombatLab.world()
	var id := w.add_enemy(ActorStore.Kind.CHARGER, Vector2(9, 0))
	assert_eq(_state(w, id), S.SPAWN)
	assert_eq(
		Damage.hit(w, 1, 10, 1, 1, 1, 0, Vector2.ZERO, Vector2(9, 0)), 0, "no damage while spawning"
	)
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 1)
	assert_ne(_state(w, id), S.SPAWN)


func test_the_charger_telegraphs_charges_hits_once_then_is_dazed() -> void:
	var w := CombatLab.world()
	var t := w.enemy_table(ActorStore.Kind.CHARGER)
	var id := w.add_enemy(ActorStore.Kind.CHARGER, Vector2(5, 0))
	var waited := CombatLab.until(w, func(x: World) -> bool: return _state(x, id) == S.WINDUP)
	assert_gt(waited, 0)
	assert_false(
		EnemyAi.telegraph(w, w.actors.index_of(id)).is_empty(), "the lane shows during the windup"
	)
	assert_eq(CombatLab.player_damage(w), [])
	CombatLab.until(w, func(x: World) -> bool: return _state(x, id) == S.RECOVER)
	assert_eq(CombatLab.player_damage(w), [t.damage], "one hit per charge")
	var at := w.actors.pos(w.actors.index_of(id))
	CombatLab.idle(w, t.recover_ticks - 2)
	assert_eq(w.actors.pos(w.actors.index_of(id)), at, "dazed: it doesn't move")


func test_the_charge_stops_at_a_wall() -> void:
	var w := CombatLab.world()
	var walls: Array[Obb] = [Obb.make(Vector2(-3, 0), Vector2(0.3, 4), 0)]
	w.set_walls(walls)
	var id := w.add_enemy(ActorStore.Kind.CHARGER, Vector2(4, 0))
	CombatLab.until(w, func(x: World) -> bool: return _state(x, id) == S.WINDUP)
	var i := w.actors.index_of(id)
	assert_lt(w.actors.lock_len[i], 7.0 - 0.5, "the lane is cut at the wall")


func test_the_warden_slams_and_its_shield_blocks_the_front() -> void:
	var w := CombatLab.world()
	var t := w.enemy_table(ActorStore.Kind.WARDEN)
	var id := w.add_enemy(ActorStore.Kind.WARDEN, Vector2(1.6, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 30)
	var i := w.actors.index_of(id)
	assert_eq(
		Damage.hit(w, i, 30, 1, 1, 1, 0, Vector2.ZERO, w.actors.pos(i)),
		0,
		"a hit from the front is blocked"
	)
	var behind := w.actors.pos(i) + Vector2(3, 0)
	assert_eq(Damage.hit(w, i, 30, 1, 1, 1, 0, behind, w.actors.pos(i)), 30, "from behind it lands")
	CombatLab.until(w, func(x: World) -> bool: return CombatLab.player_damage(x).size() > 0)
	assert_eq(CombatLab.player_damage(w), [t.damage], "the slam lands")


func test_the_needle_keeps_its_distance_and_fires_a_burst() -> void:
	var w := CombatLab.world()
	var t := w.enemy_table(ActorStore.Kind.NEEDLE)
	var id := w.add_enemy(ActorStore.Kind.NEEDLE, Vector2(3, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 40)
	var i := w.actors.index_of(id)
	assert_gt(Kin.length(w.actors.pos(i)), 3.5, "backed off")
	var shots := 0
	CombatLab.idle(w, 300)
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.SPAWN and e.owner_id == id and e.source_id != id:
			shots += 1
	assert_gt(shots, 0)
	assert_eq(shots % t.burst_count, 0, "bolts come in bursts of %d" % t.burst_count)


func test_a_dead_player_is_left_alone() -> void:
	var w := CombatLab.world()
	w.add_enemy(ActorStore.Kind.CHARGER, Vector2(5, 0))
	Damage.hit(w, 0, 1000, 1, 1, 1, 0, Vector2(5, 0), Vector2.ZERO)
	var seq := w.last_event_seq()
	CombatLab.idle(w, 300)
	var hits := w.events_since(seq).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.HIT
	)
	assert_eq(hits.size(), 0, "no attacks on a dead player")
