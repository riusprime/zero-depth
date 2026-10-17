extends GutTest
## v0.8.0 BP (owner O27, O38; PLAN step BP): boss damage set by hits to kill the base hero at loop 1 (the data's
## damage: small orbs and shots 4-5 hits, medium strikes 3-4, big attacks 2; the floor and loop factors scale it on
## top), a punish window after every big attack (no follow-up, a 0.6-0.9 s recovery), faster javelins and jumps, and
## one or two slow readable attacks kept per boss. The evidence table: docs/roadmap/v0.8.0/evidence/BOSS_PACE.md.

## The attacks with no hit class of their own: the meltdown's burning ground (a hazard). v0.8.0 N2 (owner O27, D36
## superseded): The Fallen's attacks are classed too (its own hits outside its mimic windows).
const UNCLASSED := [&"meltdown"]
## Per boss, the slow readable attacks BP left as they were: [id, telegraph seconds].
const KEPT_SLOW := {
	&"gatekeeper": [[&"rock_rings", 0.8], [&"shock_lanes", 1.6]],
	&"warlord": [[&"shield_wall", 0.8], [&"spear_lines", 1.6]],
	&"brood_mother": [[&"egg_storm", 1.6], [&"burrow", 1.0]],
	&"hive_lens": [[&"prism_spiral", 0.9], [&"gaze", 0.8]],
	&"siege_engine": [[&"turret_cross", 0.9], [&"mortar_grid", 1.6]],
	&"foundry": [[&"slag_fountain", 1.0], [&"molten_flood", 1.6]],
	&"colossus": [[&"spike_chase", 0.9], [&"fist_combo", 0.8]],
	&"prism": [[&"cross_ring", 1.0]],
}
## Per boss, the attacks BP sped up: [id, telegraph seconds before BP, after].
const SPED_UP := {
	&"gatekeeper":
	[[&"fist_slam", 1.6, 1.1], [&"fist_slam_2", 1.6, 1.1], [&"fist_slam_3", 1.6, 1.1]],
	&"warlord":
	[[&"javelin_fan", 0.6, 0.45], [&"javelin_fan_fast", 0.6, 0.45], [&"lunge_dash", 1.4, 1.0]],
	&"brood_mother": [[&"leap", 1.6, 1.0], [&"leap_chain", 1.4, 1.0], [&"pounce_chain", 1.2, 0.95]],
	&"hive_lens": [[&"dive", 1.4, 1.0], [&"focus_beam", 1.6, 1.1], [&"focus_beam_3", 1.6, 1.1]],
	&"siege_engine": [[&"rail", 1.5, 1.1], [&"rail_3", 1.5, 1.1], [&"shockwave", 1.2, 0.9]],
	&"foundry":
	[[&"vent_blast", 0.8, 0.6], [&"bomb_launch", 1.0, 0.7], [&"bomb_launch_3", 1.0, 0.7]],
	&"colossus":
	[[&"leap_slam", 0.9, 0.7], [&"leap_slam_2", 0.9, 0.7], [&"boulder_throw", 1.0, 0.75]],
}


func _bodies(repo: ContentRepository) -> Array[BossDefinition]:
	var out: Array[BossDefinition] = []
	for d: BossDefinition in repo.all_of(&"bosses"):
		out.append(d)
	for id: StringName in [&"colossus", &"prism", &"nemesis"]:
		out.append(repo.get_def(&"final_bosses", id))
	return out


func _hp(repo: ContentRepository) -> int:
	return (repo.get_def(&"player", &"runner") as PlayerDefinition).hp


func test_every_boss_hit_kills_the_base_hero_in_its_class_hits() -> void:
	var repo := ContentRepository.load_all()
	var hp := _hp(repo)
	assert_eq(hp, 100, "the base hero (data/player/runner.tres)")
	var seen := 0
	for def in _bodies(repo):
		for atk in def.attacks:
			var where := "%s %s" % [def.id, atk.id]
			if UNCLASSED.has(atk.id):
				assert_eq(atk.hit_class, &"", where + ": no class of its own")
				continue
			assert_true(BossSchemas.HIT_CLASSES.has(atk.hit_class), where + ": classed")
			var band: Array = BossSchemas.HIT_CLASSES.get(atk.hit_class, [0, 0])
			var n := BossSchemas.hits_to_kill(hp, atk.damage)
			assert_between(
				n, int(band[0]), int(band[1]), "%s: %d hits (%s)" % [where, n, atk.hit_class]
			)
			if atk.orb_damage > 0:
				var orbs := BossSchemas.hits_to_kill(hp, atk.orb_damage)
				assert_between(orbs, 4, 5, where + ": its orbs are small hits")
			seen += 1
	assert_eq(
		seen,
		82,
		"every classed attack of the six bosses and the final boss's three bodies (N2: 4 new, The Fallen's 9)"
	)


func test_loop_scaling_still_applies_on_top() -> void:
	var repo := ContentRepository.load_all()
	var run := RunState.start(7, ContentCompiler.compile_run(repo.get_def(&"run", &"three_floors")))
	run.floor_index = 2
	var base := ContentCompiler.compile_bosses(repo)
	var one := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(one)
	run.loop = 2
	var two := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(two)
	for b in base.size():
		for k in base[b].attacks.size():
			var a0 := base[b].attacks[k]
			var a1 := one[b].attacks[k]
			var a2 := two[b].attacks[k]
			assert_eq(a1.damage, a0.damage * 1200 / 1000, "%s floor 2: ×1.2" % a0.id)
			assert_eq(a2.damage, a0.damage * 1440 / 1000, "%s loop 2: ×1.2 more (O11)" % a0.id)
			assert_eq(a2.orb_damage, a0.orb_damage * 1440 / 1000, "%s: its orbs too" % a0.id)


func test_a_big_attack_is_followed_by_its_punish_window() -> void:
	var repo := ContentRepository.load_all()
	var bigs := 0
	for def in _bodies(repo):
		var t := ContentCompiler.compile_boss(def, repo)
		for k in def.attacks.size():
			var atk := def.attacks[k]
			if atk.hit_class != &"big":
				continue
			bigs += 1
			var where := "%s %s" % [def.id, atk.id]
			assert_eq(String(atk.follow_up), "", where + ": no follow-up skips the window")
			assert_true(atk.opens_weak_point, where + ": its window opens the weak point")
			var rec := t.attacks[k].recover_ticks
			assert_between(rec, BossSchemas.PUNISH_MIN_TICKS, BossSchemas.PUNISH_MAX_TICKS, where)
	assert_eq(bigs, 17, "N2: the Colossus's leap_slam_3, The Fallen's three card casts")


func test_the_javelins_come_and_go_faster() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"warlord")
	var t := ContentCompiler.compile_boss(def, repo)
	for id: StringName in [&"javelin_fan", &"javelin_fan_fast"]:
		var atk := t.attacks[t.attack_index(id)]
		assert_eq(atk.windup_ticks, 27, "%s winds up 0.45 s (was 0.6)" % id)
		assert_eq(atk.recall_ticks, 30, "%s: stuck 0.5 s before they fly back (was 1.0)" % id)
	var fan: BulletPatternDefinition = repo.get_def(&"bullet_patterns", &"warlord_javelin_fan")
	var fast: BulletPatternDefinition = repo.get_def(
		&"bullet_patterns", &"warlord_javelin_fan_fast"
	)
	assert_almost_eq(fan.speed_mps, 6.5, 0.001, "out and back at 6.5 m/s (was 4.5)")
	assert_almost_eq(fast.speed_mps, 7.0, 0.001, "phase 3: 7.0 m/s (was 5.0), the slow-shot cap")
	assert_almost_eq(fan.wave_gap_seconds, 0.25, 0.001)
	assert_almost_eq(fast.wave_gap_seconds, 0.22, 0.001)


func test_each_boss_is_faster_in_places_and_keeps_slow_readable_attacks() -> void:
	var repo := ContentRepository.load_all()
	for def in _bodies(repo):
		if def.id == &"nemesis":
			continue
		assert_true(KEPT_SLOW.has(def.id), String(def.id))
		for pair: Array in KEPT_SLOW.get(def.id, []):
			var atk := def.attack(pair[0])
			assert_almost_eq(atk.telegraph_seconds, float(pair[1]), 0.001, "%s kept" % pair[0])
		for row: Array in SPED_UP.get(def.id, []):
			var atk := def.attack(row[0])
			assert_lt(float(row[2]), float(row[1]), String(row[0]))
			assert_almost_eq(atk.telegraph_seconds, float(row[2]), 0.001, "%s sped up" % row[0])
			if atk.lock_seconds > 0.0:  # owner N15 "Track, then lock 0.8 s" (the Colossus's 0.5): the lock stays
				assert_almost_eq(
					atk.lock_seconds,
					0.5 if def.id == &"colossus" else 0.8,
					0.001,
					"%s keeps its dodge window" % row[0]
				)


func test_bad_hit_classes_and_windows_are_errors() -> void:
	var d := (load("res://data/bosses/warlord.tres") as BossDefinition).duplicate(true)
	assert_eq(d.validate(), [])
	d.attack(&"shield_bash").hit_class = &"huge"
	assert_has(_codes(d), &"range", "an unknown class")
	d.attack(&"shield_bash").hit_class = &"medium"
	d.attack(&"lunge_dash").follow_up = &"shield_bash"
	assert_has(_codes(d), &"punish", "a big attack can't chain past its window")
	d.attack(&"lunge_dash").follow_up = &""
	d.attack(&"lunge_dash").recovery_seconds = 0.5
	assert_has(_codes(d), &"punish", "a window of 0.3 s is too short")
	d.attack(&"lunge_dash").recovery_seconds = 1.3
	d.attack(&"lunge_dash").orb_damage = 22
	assert_has(_codes(d), &"range", "orb_damage needs a pattern")
	d.attack(&"lunge_dash").orb_damage = 0
	assert_eq(d.validate(), [])


func _codes(d: BossDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
