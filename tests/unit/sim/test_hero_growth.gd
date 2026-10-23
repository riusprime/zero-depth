extends GutTest
## v0.9.0 SV (PLAN "Owner decisions" EL, SV: "enemies almost oneshot you because the scaling per floor, but you hp or
## resistance doeasnt stack … I am not able to get to the finall boss due to dying way too fast"; then "Hero grows each
## floor"; "A bit safer, never a must"): each floor cleared gives the hero +15 max HP (100 -> 160 on floor 5 and in the
## final arena; the loops keep growing it), the new max HP arrives filled, it stacks with the max HP stat cards and
## Fortune's max HP, and the heal between floors is 60 %. The v0.8.0 run shape (three_floors) keeps no growth and 40 %.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _table(id: StringName = RunSaver.RUN_ID) -> RunTable:
	return ContentCompiler.compile_run(_repo.get_def(&"run", id))


## The portal taken on `w` (as Main: the run's carry), the next floor's world built.
func _next(lab: RunLab, w: World) -> World:
	lab.next_floor(w)
	return lab.floor_world()


func test_the_data_grows_15_a_floor_and_heals_60_percent() -> void:
	var t := _table()
	assert_eq(t.max_hp_per_floor, 15)
	assert_eq(t.max_hp_floor_cap, 0, "no cap: the loops keep growing it")
	assert_eq(t.heal_permille, 600)
	var old := _table(&"three_floors")
	assert_eq(old.max_hp_per_floor, 0, "the v0.8.0 shape keeps no growth")
	assert_eq(old.heal_permille, 400)


func test_the_bonus_by_the_run_s_floor_and_its_cap() -> void:
	var t := _table()
	var want := [0, 15, 30, 45, 60, 75, 90]
	for f in range(1, 8):
		assert_eq(RunCarry.floor_hp_bonus(t, f), want[f - 1], "run floor %d" % f)
	t.max_hp_floor_cap = 40
	assert_eq(RunCarry.floor_hp_bonus(t, 5), 40, "at most the cap")
	assert_eq(RunCarry.floor_hp_bonus(_table(&"three_floors"), 3), 0)


## Floors 1-5 at 100, 115, 130, 145, 160 max HP, and the final arena at 160; each floor arrives with the growth filled
## on top of the 60 % heal.
func test_a_run_grows_100_to_160_and_each_floor_arrives_healed() -> void:
	var lab := RunLab.new(_repo, 77, &"blade")
	var w := lab.floor_world()
	for f in range(1, 6):
		assert_eq(w.actors.max_hp[0], 100 + 15 * (f - 1), "floor %d max HP" % f)
		assert_eq(w.floor_hp_bonus, 15 * (f - 1))
		if f == 5:
			break
		var mx := w.actors.max_hp[0]
		w.actors.hp[0] = 10
		w = _next(lab, w)
		assert_eq(
			w.actors.hp[0],
			10 + mx * 600 / 1000 + 15,
			"floor %d: 60 %% heal, then the 15 filled" % (f + 1)
		)
	lab.run.final_fight = true  # (floor 5's Ascension portal: the final arena, no floor change)
	var arena := FinalLab.arena(lab.run, false)
	assert_eq(arena.actors.max_hp[0], 160, "the final fight at floor 5's 160")


func test_the_growth_reaches_full_hp_at_most() -> void:
	var lab := RunLab.new(_repo, 78, &"gun")
	var w := lab.floor_world()
	w = _next(lab, w)
	assert_eq(w.actors.max_hp[0], 115)
	assert_eq(w.actors.hp[0], 115, "a full hero arrives full")


## The max HP stat cards multiply the base and the growth together, and so does a Fortune max HP win (a stat win).
func test_it_stacks_with_the_max_hp_cards_and_fortune() -> void:
	var lab := RunLab.new(_repo, 79, &"blade")
	var w := lab.floor_world()
	Stats.add_card(w, Stats.Stat.MAX_HP, Stats.Rarity.EPIC)
	var v := Stats.value(w, Stats.Stat.MAX_HP)
	assert_gt(v, 1000, "the card raised the stat")
	w = _next(lab, w)
	assert_eq(w.actors.max_hp[0], ((100 + 15) * v + 500) / 1000, "the card x (base + growth)")
	# Fortune's max HP win (in a run with stat cards: the max HP stat, by the shrine's amount) stacks the same way.
	assert_not_null(w.gamble_table, "the floor has the shrine's table")
	Gamble.grant(w, GambleTable.Stat.MAX_HP)
	var v2 := Stats.value(w, Stats.Stat.MAX_HP)
	assert_gt(v2, v, "the win raised the stat")
	assert_eq(w.actors.max_hp[0], ((100 + 15) * v2 + 500) / 1000, "Fortune x (base + growth)")
	w = _next(lab, w)
	# (Stats.max_hp, not actors.max_hp: RunCarry.apply sets the max HP before the stat tables arrive, so a Fortune
	# max HP win also counts flat there until the next recompute; that is older than SV and not this test's.)
	assert_eq(Stats.max_hp(w), ((100 + 30) * v2 + 500) / 1000, "and both carry to floor 3")


func test_the_growth_is_derived_again_on_a_resumed_floor() -> void:
	var lab := RunLab.new(_repo, 80, &"blade")
	var w := lab.floor_world()
	w = _next(lab, w)
	w = _next(lab, w)
	assert_eq(w.actors.max_hp[0], 130)
	var p := RunSaver.payload_of(w, lab.run, 5, PackedByteArray([1]))
	var back := RunSaver.run_from(bytes_to_var(var_to_bytes(p)), lab.run.table)
	assert_eq(back.floor_index, 3)
	var saved := SaveLab.build_floor(back)  # (the save tests' floor, so the base matches it)
	assert_eq(saved.actors.max_hp[0], 130)
	var snap: Dictionary = bytes_to_var(var_to_bytes(saved.to_snapshot()))
	var base := SaveLab.build_floor(RunSaver.run_from(bytes_to_var(var_to_bytes(p)), lab.run.table))
	assert_eq(base.floor_hp_bonus, 30, "RunState.prepare derives it from the floor")
	assert_not_null(World.from_snapshot(snap, base))
	assert_eq(base.floor_hp_bonus, 30, "not taken from the snapshot")
	assert_eq(base.actors.max_hp[0], 130)
	assert_eq(Stats.max_hp(base), 130, "a recompute keeps it")


## An old save's run (the v0.8.0 three_floors shape) never grows; a v0.9.0 five-floor save from before SV (its carry
## holds no growth) resumes with the growth of its floor.
func test_old_saves_load_and_three_floors_never_grows() -> void:
	var t := _table(&"three_floors")
	var run := RunState.start(81, t, &"blade")
	run.floor_index = 3
	run.routes.append_array([Routes.Route.NORMAL, Routes.Route.NORMAL])
	var w := SaveLab.build_floor(run)
	assert_eq(w.floor_hp_bonus, 0)
	assert_eq(w.actors.max_hp[0], 100)
	var five := SaveLab.run_state(82, 4)
	five.carry = {RunCarry.HP: 70}  # a carry from before SV: its HP only
	var w5 := SaveLab.build_floor(five)
	assert_eq(w5.actors.max_hp[0], 145, "floor 4's growth, derived")
	assert_eq(w5.actors.hp[0], 70, "the saved HP as it was")


func test_the_final_arena_card_shows_no_growth() -> void:
	var run := FinalLab.run_state(83)
	assert_eq(RunCarry.hp_grown(run), 0, "the final arena: no new floor")
	run.final_fight = false
	assert_eq(RunCarry.hp_grown(run), 15, "floor 5 arrived with +15")
	run.floor_index = 1
	run.loop_floors = 0
	assert_eq(RunCarry.hp_grown(run), 0, "the run's first floor")
