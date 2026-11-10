extends GutTest
## v0.10.5 O5b (owner P13; docs/roadmap/v0.10.5/O5_LOOPS.md M1-M5): each loop past the first adds one rule, drawn on a
## named stream of the run seed without repeats, saved with the run, set on each floor's world, and changing what it
## names (speed, heal orbs, elite rooms, a guarded front, ranged enemies). The HP step a loop is ×3.5.


func _run_table() -> RunTable:
	return ContentCompiler.compile_run(SharedContent.repo().get_def(&"run", SaveLab.RUN_ID))


func _loop_two_run(run_seed: int) -> RunState:
	var run := SaveLab.run_state(run_seed, SaveLab.floors())
	var w := SaveLab.build_floor(run)
	w.boss_flow.ascend_choice = Ascension.Choice.LOOP
	run.finish_floor(w)
	return run


func test_the_content_has_five_rules_and_the_lower_hp_step() -> void:
	assert_eq(RunDefinition.LOOP_RULE_IDS, LoopRules.POOL, "content's list matches the sim's pool")
	for id: StringName in [&"five_floors", &"three_floors"]:
		var def: RunDefinition = SharedContent.repo().get_def(&"run", id)
		assert_eq(def.loop_rules, LoopRules.POOL, "%s: the five rules" % id)
		assert_eq(def.loop_enemy_hp_permille, 3500, "%s: enemies ×3.5 a loop (was ×6)" % id)
		assert_eq(def.loop_boss_hp_permille, 3500, "%s: bosses ×3.5 a loop" % id)
		assert_eq(def.validate().size(), 0)
	var bad := RunDefinition.new()
	bad.loop_rules = [&"nope"] as Array[StringName]
	assert_gt(bad.validate().size(), 0, "an unknown rule fails validation")


func test_one_rule_a_loop_without_repeats_and_the_same_for_a_seed() -> void:
	var draws := []
	for pass_n in 2:
		var run := RunState.start(4242, _run_table())
		var got: Array[StringName] = []
		for loop in range(2, 8):
			run.loop = loop
			got.append(LoopRules.draw(run))
		draws.append(got)
		assert_eq(got.slice(5), [&""] as Array[StringName], "the pool is spent after five loops")
		var five := got.slice(0, 5)
		for id in LoopRules.POOL:
			assert_true(five.has(id), "every rule once: %s" % id)
		assert_eq(run.loop_rules, five as Array[StringName], "held in the order drawn")
	assert_eq(draws[0], draws[1], "a seed always draws the same rules")
	var firsts := {}
	for s in 24:
		var run := RunState.start(1000 + s, _run_table())
		run.loop = 2
		firsts[LoopRules.draw(run)] = true
	assert_gt(firsts.size(), 1, "different seeds, different rules")


func test_the_loop_device_draws_the_rule_and_the_floor_holds_it() -> void:
	var run := _loop_two_run(321)
	assert_eq(run.loop, 2)
	assert_eq(run.loop_rules.size(), 1, "loop 2: one rule")
	assert_eq(LoopRules.newest(run), run.loop_rules[0], "the floor card's rule")
	var w := SaveLab.build_floor(run)
	assert_eq(w.loop_rules, LoopRules.indices(run.loop_rules))
	assert_eq(WorldReader.new(w).loop_rules(), run.loop_rules, "the reader names it")
	assert_eq(RunRecap.rule_keys(run), PackedStringArray([LoopRules.name_key(run.loop_rules[0])]))


func test_the_rules_round_trip_and_an_older_payload_has_none() -> void:
	var run := _loop_two_run(321)
	var w := SaveLab.build_floor(run)
	CombatLab.idle(w, 30)
	var p := RunSaver.payload_of(w, run, 99, PackedByteArray([1]))
	var got := RunSaveStore.decode(RunSaveStore.encode(p))
	var q: Dictionary = (got[0] as Dictionary)["payload"]
	var back := RunSaver.run_from(q, _run_table())
	assert_eq(back.loop_rules, run.loop_rules, "the rules come back")
	assert_eq(LoopRules.newest(back), LoopRules.newest(run), "and the loop that drew the newest")
	var w2 := SaveLab.build_floor(back)
	assert_eq(WorldSnapshot.apply(w2, q["world"]), "", "the snapshot fits")
	assert_eq(w2.state_hash(), w.state_hash(), "Continue resumes the same state")
	# A payload written before O5b: no rule keys, no world fields.
	(p["run"] as Dictionary).erase("loop_rules")
	(p["run"] as Dictionary).erase("loop_rule_loop")
	var snap: Dictionary = p["world"]["world"]
	for f in [&"loop_rules", &"loop_shield_permille", &"loop_shield_half_arc"]:
		snap.erase(f)
	var old := RunSaver.run_from(p, _run_table())
	assert_true(old.loop_rules.is_empty(), "an older run holds no rule")
	assert_eq(LoopRules.newest(old), &"", "and announces none")
	var w3 := SaveLab.build_floor(old)
	assert_eq(WorldSnapshot.apply(w3, p["world"]), "", "its snapshot restores")
	assert_true(w3.loop_rules.is_empty())


func test_a_loop_one_world_hashes_as_before() -> void:
	var run := SaveLab.run_state(55, SaveLab.floors())
	var w := SaveLab.build_floor(run)
	assert_true(w.loop_rules.is_empty(), "loop 1: no rules")
	assert_eq(w.loop_shield_half_arc, 0)


func _scaled(rules: Array[StringName]) -> Array[EnemyTable]:
	var run := RunState.start(9, _run_table())
	run.loop = 2
	run.loop_rules = rules
	var t := CombatLab.tables()
	run.scale_enemies(t)
	return t


func test_swift_and_point_blank_change_the_enemy_tables() -> void:
	var plain := _scaled([] as Array[StringName])
	var swift := _scaled([&"swift"] as Array[StringName])
	var close := _scaled([&"point_blank"] as Array[StringName])
	var table := _run_table()
	var ranged := 0
	for k in plain.size():
		assert_almost_eq(
			swift[k].speed, plain[k].speed * table.loop_swift_permille / 1000.0, 0.0001
		)
		assert_almost_eq(
			swift[k].charge_speed,
			plain[k].charge_speed * table.loop_swift_permille / 1000.0,
			0.0001
		)
		assert_eq(swift[k].hp, plain[k].hp, "a rule, not more HP")
		if plain[k].bolt_speed > 0.0 or plain[k].spread_speed > 0.0:
			ranged += 1
			assert_almost_eq(
				close[k].bolt_speed, plain[k].bolt_speed * table.loop_bolt_permille / 1000.0, 0.0001
			)
			assert_almost_eq(
				close[k].keep_distance_m,
				plain[k].keep_distance_m * table.loop_keep_permille / 1000.0,
				0.0001
			)
		else:
			assert_eq(close[k].keep_distance_m, plain[k].keep_distance_m, "melee kinds unchanged")
	assert_gt(ranged, 0, "some ranged kinds")


func test_lean_mending_makes_orbs_rarer_and_stronger() -> void:
	var base := ContentCompiler.compile_rewards(SharedContent.repo().get_def(&"rewards", &"floor"))
	var run := _loop_two_run(321)
	run.loop_rules = [&"lean_mending"] as Array[StringName]
	var w := SaveLab.build_floor(run)
	assert_eq(w.reward_table.heal_orb_meter, base.heal_orb_meter * 2, "v0.11.0 F3: twice the kills")
	assert_eq(w.reward_table.heal_orb_heal_permille, base.heal_orb_heal_permille * 2000 / 1000)


func test_elite_hunt_uses_the_last_floors_rate() -> void:
	var run := RunState.start(3, _run_table())
	run.loop = 2
	assert_eq(LoopRules.elite_floor(run), 1, "without the rule: its own floor")
	run.loop_rules = [&"elite_hunt"] as Array[StringName]
	assert_eq(LoopRules.elite_floor(run), run.table.floors, "with it: the loop's last floor")


func test_shielded_guards_every_normal_enemys_front() -> void:
	var w := CombatLab.world()
	var i := w.actors.ids.find(w.add_enemy(ActorStore.Kind.CHARGER, w.player_pos() + Vector2(3, 0)))
	w.actors.facing[i] = Kin.angle_of(Vector2(-1, 0))  # facing the hero
	var front := w.actors.pos(i) + Vector2(-1, 0)
	var back := w.actors.pos(i) + Vector2(1, 0)
	assert_eq(Damage.target_mult(w, i, front)[0], 1000, "no rule: no guard")
	w.loop_shield_permille = 600
	w.loop_shield_half_arc = ContentCompiler.degrees_to_units(45.0)
	assert_eq(
		Damage.target_mult(w, i, front), [600, SimEvent.TAG_ARMOURED] as Array[int], "front: 60 %"
	)
	assert_eq(Damage.target_mult(w, i, back)[0], 1000, "from behind: full")
	var side := w.actors.pos(i) + Vector2(0, 1)
	assert_eq(Damage.target_mult(w, i, side)[0], 1000, "from the side: full")
