extends GutTest
## v0.8.0 P3 (owner O35, "Reduce the difficulty of this specific combination (second loop + Purple Portal) by
## approximately 10%"): a Deep floor (the Purple Portal's route) past loop 1 eases its enemies' and bosses' HP and
## damage by RunTable.loop_deep_ease_permille (900 in the data); loop 2 on a normal floor and a Deep floor on loop 1
## keep their scaling exactly.


func _run_table() -> RunTable:
	return ContentCompiler.compile_run(
		ContentRepository.load_all().get_def(&"run", &"three_floors")
	)


## A run on floor 2 of `loop`, its route into floor 2 `route` (Routes.Route).
func _run(loop: int, route: int) -> RunState:
	var r := RunState.start(1, _run_table())
	r.loop = loop
	r.loop_floors = 3 * (loop - 1)
	r.floor_index = 2
	r.routes.resize(r.run_floor())
	for k in r.routes.size():
		r.routes[k] = Routes.Route.NORMAL
	r.routes[r.run_floor() - 1] = route
	return r


func _enemies(r: RunState) -> Array[EnemyTable]:
	var t := CombatLab.tables()
	r.scale_enemies(t)
	return t


func _bosses(r: RunState) -> Array[BossTable]:
	var t := ContentCompiler.compile_bosses(ContentRepository.load_all())
	r.scale_bosses(t)
	return t


func test_the_data_eases_the_combination_by_ten_percent() -> void:
	assert_eq(_run_table().loop_deep_ease_permille, 900)


func test_only_loop_2_plus_deep_is_eased() -> void:
	assert_eq(_run(1, Routes.Route.NORMAL)._loop_deep_ease(), 1000, "loop 1, normal")
	assert_eq(_run(1, Routes.Route.DEEP)._loop_deep_ease(), 1000, "loop 1, Deep: unchanged")
	assert_eq(_run(2, Routes.Route.NORMAL)._loop_deep_ease(), 1000, "loop 2, normal: unchanged")
	assert_eq(_run(2, Routes.Route.DEEP)._loop_deep_ease(), 900, "loop 2 + Deep: eased")
	assert_eq(_run(3, Routes.Route.DEEP)._loop_deep_ease(), 900, "loop 3 + Deep: eased too")


## Loop 2's Deep floor: every enemy's HP and damage are 90 % of what the same floor's numbers were before the ease
## (the floor's, the Deep and the loop factors, then x0.9 in the same per-mille step, rounded once).
func test_loop_2_deep_enemies_are_ten_percent_weaker() -> void:
	var base := CombatLab.tables()
	var eased := _enemies(_run(2, Routes.Route.DEEP))
	var t := _run_table()
	var hp_pm := SpawnTable.scale(SpawnTable.per_floor(t.enemy_hp_floor_permille, 2), 1250)
	var dmg_pm := SpawnTable.scale(SpawnTable.per_floor(t.enemy_damage_floor_permille, 2), 1250)
	hp_pm = SpawnTable.scale(hp_pm, 6000)
	dmg_pm = SpawnTable.scale(dmg_pm, 1200)
	var plain_hp := hp_pm
	var plain_dmg := dmg_pm
	hp_pm = SpawnTable.scale(hp_pm, 900)
	dmg_pm = SpawnTable.scale(dmg_pm, 900)
	for k in base.size():
		assert_eq(eased[k].hp, maxi(1, SpawnTable.scale(base[k].hp, hp_pm)), "HP %d" % k)
		assert_eq(eased[k].damage, SpawnTable.scale(base[k].damage, dmg_pm), "damage %d" % k)
	var ratio_hp := float(hp_pm) / float(plain_hp)
	var ratio_dmg := float(dmg_pm) / float(plain_dmg)
	assert_almost_eq(ratio_hp, 0.9, 0.001, "HP factor x0.9")
	assert_almost_eq(ratio_dmg, 0.9, 0.001, "damage factor x0.9")


## Loop 2 alone and the Deep floor alone: the same numbers as with no ease at all (the ease set to 1000).
func test_loop_2_alone_and_deep_alone_are_unchanged() -> void:
	for c: Array in [[2, Routes.Route.NORMAL], [1, Routes.Route.DEEP]]:
		var shipped := _run(c[0], c[1])
		var none := _run(c[0], c[1])
		none.table.loop_deep_ease_permille = 1000
		var a := _enemies(shipped)
		var b := _enemies(none)
		for k in a.size():
			assert_eq(a[k].hp, b[k].hp, "loop %d route %d enemy HP %d" % [c[0], c[1], k])
			assert_eq(a[k].damage, b[k].damage, "loop %d route %d enemy dmg %d" % [c[0], c[1], k])
		var ba := _bosses(shipped)
		var bb := _bosses(none)
		for k in ba.size():
			assert_eq(ba[k].hp, bb[k].hp, "loop %d route %d boss HP %d" % [c[0], c[1], k])


## Loop 2's Deep floor boss: HP and every attack's damage x0.9 of the uneased numbers (integer per mille, so within
## one point of rounding).
func test_loop_2_deep_bosses_are_ten_percent_weaker() -> void:
	var eased := _bosses(_run(2, Routes.Route.DEEP))
	var none_run := _run(2, Routes.Route.DEEP)
	none_run.table.loop_deep_ease_permille = 1000
	var plain := _bosses(none_run)
	for k in plain.size():
		if plain[k].mimic:
			continue
		assert_almost_eq(float(eased[k].hp), plain[k].hp * 0.9, plain[k].hp * 0.002 + 1.0)
		for a in plain[k].attacks.size():
			var d := plain[k].attacks[a].damage
			assert_almost_eq(float(eased[k].attacks[a].damage), d * 0.9, d * 0.002 + 1.0)
	assert_lt(eased[0].hp, plain[0].hp, "the boss is weaker")
