extends GutTest
## v0.8.0 GF1 (owner O18: "make it a little bit bigger, maybe like 25% bigger, and the gun should shoot less bullets
## per second, but do the enough more damage to be able to maintain the DPS. So we lower the speed a bit"): the Gun's
## basic shot in data/player/runner.tres, compiled: 25 % bigger (0.16 -> 0.2 m), x0.75 the fire rate (7 -> 9 ticks:
## 9.33 rounded to whole ticks), x4/3 the damage rounded to a whole point (4 -> 5), x0.9 the flight speed
## (18 -> 16.2 m/s) and the range kept (36 -> 40 ticks of life: 10.8 m both). The DPS on one dummy is unchanged
## within that rounding (measured here by a fight, not computed), and the Gun cards keep their multipliers on top.

const OLD := {"period": 7, "damage": 4, "speed": 18.0 / 60.0, "radius": 0.16, "life": 36}


func _table() -> PlayerTable:
	return ContentCompiler.compile_player(
		ContentRepository.load_all().get_def(&"player", &"runner")
	)


func test_the_shot_is_bigger_slower_to_fire_harder_hitting_and_a_little_slower() -> void:
	var t := _table()
	assert_almost_eq(t.bolt_radius_m, 0.2, 1e-6, "25 % bigger: 0.16 -> 0.2 m")
	assert_almost_eq(t.bolt_radius_m / OLD["radius"], 1.25, 1e-5)
	assert_eq(t.shot_period_ticks, 9, "x0.75 the rate: 7 / 0.75 = 9.33 ticks, 9 whole ticks")
	assert_eq(t.bolt_damage, 5, "x4/3 the damage: 4 x 4/3 = 5.33, 5 whole points")
	assert_almost_eq(t.bolt_speed, 16.2 / 60.0, 1e-6, "x0.9 the speed: 18 -> 16.2 m/s")
	assert_almost_eq(t.bolt_speed / OLD["speed"], 0.9, 1e-5)
	assert_eq(t.bolt_life_ticks, 40, "a longer life ...")
	assert_almost_eq(
		t.bolt_speed * t.bolt_life_ticks, OLD["speed"] * OLD["life"], 1e-4, "... so the range stays"
	)


func test_the_kernel_starting_values_match_the_data() -> void:
	var t := _table()
	var k := PlayerTable.starting_values()
	assert_eq(
		[k.shot_period_ticks, k.bolt_damage, k.bolt_life_ticks],
		[t.shot_period_ticks, t.bolt_damage, t.bolt_life_ticks]
	)
	assert_almost_eq(k.bolt_speed, t.bolt_speed, 1e-6)
	assert_almost_eq(k.bolt_radius_m, t.bolt_radius_m, 1e-6)


## Holds Shoot at one dummy 4 m out for `ticks` and returns the damage it took (no crits).
func _damage_on_one_dummy(t: PlayerTable, ticks: int) -> int:
	var repo := ContentRepository.load_all()
	ContentCompiler.apply_build(t, repo.get_def(&"build", &"gun"))
	t.crit_chance_permille = 0
	var w := World.new(11, t)
	w.dummy_speed = 0.0
	var id := w.add_dummy(Vector2(4, 0), 0.35, 1 << 24)
	var hp0 := w.actors.hp[w.actors.index_of(id)]
	var f := InputFrame.make(Vector2i.ZERO, 0, 400, InputFrame.SHOOT, InputFrame.SHOOT)
	for k in ticks:
		w.step(f)
		f = InputFrame.make(Vector2i.ZERO, 0, 400, InputFrame.SHOOT, 0)
	return hp0 - w.actors.hp[w.actors.index_of(id)]


func test_the_dps_on_one_dummy_is_unchanged_within_the_rounding() -> void:
	var ticks := 60 * 30
	var now := _damage_on_one_dummy(_table(), ticks)
	var old := _table()
	old.shot_period_ticks = OLD["period"]
	old.bolt_damage = OLD["damage"]
	old.bolt_speed = OLD["speed"]
	old.bolt_radius_m = OLD["radius"]
	old.bolt_life_ticks = OLD["life"]
	var before := _damage_on_one_dummy(old, ticks)
	assert_gt(before, 0, "the old shot lands")
	var ratio := float(now) / float(before)
	# 5 / 9 over 4 / 7 = 0.972: whole ticks and whole points can't make 4/3 x 0.75 exactly.
	assert_between(
		ratio, 0.95, 1.0, "the DPS is kept within the rounding (%d vs %d)" % [now, before]
	)
	assert_lt(_shots(_table(), ticks), _shots(old, ticks), "fewer shots a second")


func _shots(t: PlayerTable, ticks: int) -> int:
	return int(ceil(float(ticks) / t.shot_period_ticks))


func test_the_gun_cards_scale_the_new_shot() -> void:
	var w := WandLab.world(&"gun")
	var base := Modifiers.bolt(w)
	assert_almost_eq(base.radius_m, 0.2, 1e-6)
	assert_eq(base.damage, 5)
	var big := _compiled(w, &"gun_big_shot")
	assert_almost_eq(big.radius_m, 0.44, 1e-5, "Big Shot: x2.2 size")  # v0.9.5 CLV: Big Shot 2.2 size
	assert_almost_eq(big.speed, base.speed * 0.75, 1e-6, "-25 % speed")
	var rapid := _compiled(w, &"gun_rapid_fire")
	# v0.8.0 MR (O91): sustained fire: x0.7 size, +30 % rate, ramping while held (test_mr_modifiers.gd)
	assert_almost_eq(rapid.radius_m, 0.14, 1e-5, "Rapid Fire: x0.7 size")
	assert_eq(rapid.rate_bonus_permille, 300, "+30 % fire rate")


func _compiled(w: World, card: StringName) -> AttackSpec:
	var mods: Array[ModifierTable] = [WandLab.card(card)]
	return Modifiers.compile_for(w, mods).spec(Modifiers.GUN_BOLT)
