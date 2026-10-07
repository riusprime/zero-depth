extends GutTest
## The three v0.1.0 behaviours (owner Q3): states, attacks, the Warden's armour, spacing.

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


func test_the_warden_slams_and_hits_from_the_front_still_land() -> void:
	var w := CombatLab.world()
	var t := w.enemy_table(ActorStore.Kind.WARDEN)
	var id := w.add_enemy(ActorStore.Kind.WARDEN, Vector2(1.6, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 30)
	var i := w.actors.index_of(id)
	assert_eq(
		Damage.hit(w, i, 30, 1, 1, 1, 0, Vector2.ZERO, w.actors.pos(i)),
		30 * t.front_mult_permille / 1000,
		"a hit from the front lands, softened (no block)"
	)
	var behind := w.actors.pos(i) + Vector2(3, 0)
	assert_eq(
		Damage.hit(w, i, 30, 1, 1, 1, 0, behind, w.actors.pos(i)),
		30 * t.rear_mult_permille / 1000,
		"from behind it lands harder"
	)
	CombatLab.until(w, func(x: World) -> bool: return CombatLab.player_damage(x).size() > 0)
	assert_eq(CombatLab.player_damage(w), [t.damage], "the slam lands")


## A Warden out of reach, past its spawn-in, facing +x (angle 0), so a hit's direction is set by `from` alone.
func _armour_lab() -> Array:
	var w := CombatLab.world()
	var id := w.add_enemy(ActorStore.Kind.WARDEN, Vector2(9, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 1)
	var i := w.actors.index_of(id)
	w.actors.facing[i] = 0
	return [w, i]


func _last_hit_tags(w: World) -> int:
	var tags := -1
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.HIT:
			tags = e.tags
	return tags


func test_the_warden_armour_data_is_the_owner_rule() -> void:
	var t := CombatLab.world().enemy_table(ActorStore.Kind.WARDEN)
	assert_eq(t.front_mult_permille, 800, "20 % less from the front")
	assert_eq(t.rear_mult_permille, 1100, "10 % more from behind")
	assert_eq(t.front_half_arc, 683, "a 120 degree front arc")
	assert_eq(t.rear_half_arc, 683, "a 120 degree rear arc")


func test_a_front_hit_takes_80_percent_and_is_tagged_armoured() -> void:
	var lab := _armour_lab()
	var w: World = lab[0]
	var i: int = lab[1]
	var front := w.actors.pos(i) + Vector2(2, 0.5)
	var hp := w.actors.hp[i]
	assert_eq(Damage.hit(w, i, 37, 1, 1, 1, 0, front, w.actors.pos(i)), 29, "37 * 800 / 1000 = 29")
	assert_eq(w.actors.hp[i], hp - 29)
	assert_eq(Damage.target_mult(w, i, front), [800, SimEvent.TAG_ARMOURED])
	assert_ne(_last_hit_tags(w) & SimEvent.TAG_ARMOURED, 0, "presentation can tell")
	assert_eq(_last_hit_tags(w) & SimEvent.TAG_BLOCKED, 0, "never blocked")


func test_a_back_hit_takes_110_percent_and_is_tagged_weak_spot() -> void:
	var lab := _armour_lab()
	var w: World = lab[0]
	var i: int = lab[1]
	var back := w.actors.pos(i) + Vector2(-2, -0.5)
	assert_eq(Damage.hit(w, i, 37, 1, 1, 1, 0, back, w.actors.pos(i)), 40, "37 * 1100 / 1000 = 40")
	assert_eq(Damage.target_mult(w, i, back), [1100, SimEvent.TAG_WEAK_SPOT])
	assert_ne(_last_hit_tags(w) & SimEvent.TAG_WEAK_SPOT, 0)


func test_a_side_hit_takes_full_damage_untagged() -> void:
	var lab := _armour_lab()
	var w: World = lab[0]
	var i: int = lab[1]
	for side in [Vector2(0, 2), Vector2(0, -2)]:
		var from: Vector2 = w.actors.pos(i) + side
		assert_eq(Damage.target_mult(w, i, from), [1000, 0], "side %s" % side)
	var hit := Damage.hit(w, i, 37, 1, 1, 1, 0, w.actors.pos(i) + Vector2(0, 2), w.actors.pos(i))
	assert_eq(hit, 37)
	var armour := SimEvent.TAG_ARMOURED | SimEvent.TAG_WEAK_SPOT
	assert_eq(_last_hit_tags(w) & armour, 0)


func test_the_arc_edges_follow_the_half_arcs() -> void:
	var lab := _armour_lab()
	var w: World = lab[0]
	var i: int = lab[1]
	var p := w.actors.pos(i)
	# 59 degrees off the nose is inside the 60 degree half-arc; 61 is outside. Same from the tail.
	assert_eq(Damage.target_mult(w, i, p + Kin.dir(671) * 2)[0], 800)
	assert_eq(Damage.target_mult(w, i, p + Kin.dir(694) * 2)[0], 1000)
	assert_eq(Damage.target_mult(w, i, p + Kin.dir(2048 - 671) * 2)[0], 1100)
	assert_eq(Damage.target_mult(w, i, p + Kin.dir(2048 - 694) * 2)[0], 1000)


func test_a_warden_can_be_killed_from_the_front() -> void:
	var lab := _armour_lab()
	var w: World = lab[0]
	var i: int = lab[1]
	var front := w.actors.pos(i) + Vector2(2, 0)
	var hits := 0
	while w.actors.dead[i] == 0 and hits < 20:
		Damage.hit(w, i, 30, 1, 1, 1, 0, front, w.actors.pos(i))
		hits += 1
	assert_eq(w.actors.dead[i], 1, "front hits alone kill it")
	assert_eq(hits, ceili(100.0 / 24.0), "100 HP at 24 a hit")
	var kills := 0
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.KILL and e.target_id == w.actors.ids[i]:
			kills += 1
	assert_eq(kills, 1)


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
