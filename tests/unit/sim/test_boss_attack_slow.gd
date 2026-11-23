extends GutTest
## The attack speed a boss takes from the hero (BossSlow): the Gun's period, the Blade's swing and the Laser's and the
## Lance's periods slow by the whole cut; the auto abilities' periods and the spells' cooldowns do not; it comes back
## in parts; it multiplies with Heavy Hands; it ends with its boss, with the hero's death and outside the arena; the
## snapshot keeps it and the same seed gives the same hash.

const W := preload("res://tests/support/mx4_world.gd")
const LONG := 1 << 20
## A hit pauses the world for a few ticks (the hero's hit-stop); the fight's clean-up runs on the first tick after it.
const HIT_STOP := 10
## TEST HELPER: a boss id for worlds without bosses (their tick never runs BossSlow.advance, so the cut stays).
const SOME_BOSS := 777777


func _fight(seed_value := 11) -> Array:
	var w := BossLab.world(seed_value)
	var i := BossLab.ready_boss(w, &"clockwork_judge", Vector2(-30, -30))
	w.actors.set_pos(0, Vector2(30, 30))
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	# TEST HELPER: held staggered, so it never attacks.
	w.actors.state[i] = BossAi.STAGGERED
	w.bosses.stagger_t[BossAi.entry_of(w, i)] = LONG
	return [w, w.actors.ids[i]]


func _step(w: World, n: int) -> void:
	for k in n:
		w.step(InputFrame.new())


## The ticks (counted from 1) on which a new hero's projectile appeared, holding fire for n ticks.
func _launch_ticks(w: World, n: int) -> Array:
	var seen := {}
	var out := []
	for k in n:
		w.step(W.frame(W.S if k == 0 else 0, W.S))
		var p := w.projectiles
		for i in p.size():
			if p.team[i] == ActorStore.TEAM_PLAYER and not seen.has(p.ids[i]):
				seen[p.ids[i]] = true
				if out.is_empty() or out[-1] != k + 1:
					out.append(k + 1)
	return out


func test_the_cut_multiplies_the_rate_and_comes_back_in_parts() -> void:
	var w := W.world(&"gun")
	assert_eq(BossSlow.cut(w), 0)
	assert_eq(AttackRate.rate(w, 0), 1000)
	BossSlow.apply(w, SOME_BOSS, 750)
	assert_eq(BossSlow.cut(w), 750)
	assert_eq(WorldReader.new(w).boss_attack_slow(), 750, "the view's read")
	assert_eq(AttackRate.rate(w, 0), 250, "a quarter of the rate")
	assert_eq(BossSlow.give_back(w, 250), 250)
	assert_eq(AttackRate.rate(w, 0), 500)
	assert_eq(BossSlow.give_back(w, 250), 250)
	assert_eq(AttackRate.rate(w, 0), 750)
	assert_eq(w.bosses.aslow_boss, SOME_BOSS, "still held")
	assert_eq(BossSlow.give_back(w, 400), 250, "only what is left comes back")
	assert_eq(AttackRate.rate(w, 0), 1000)
	assert_eq(w.bosses.aslow_boss, -1, "the last part ends it")
	assert_eq(BossSlow.give_back(w, 250), 0, "nothing to return")


func test_a_second_cut_keeps_the_larger_and_never_takes_everything() -> void:
	var w := W.world(&"gun")
	BossSlow.apply(w, SOME_BOSS, 750)
	BossSlow.give_back(w, 250)
	BossSlow.apply(w, SOME_BOSS, 300)
	assert_eq(BossSlow.cut(w), 500, "a smaller one changes nothing")
	BossSlow.apply(w, SOME_BOSS, 750)
	assert_eq(BossSlow.cut(w), 750, "the wave again: back to its whole")
	BossSlow.apply(w, SOME_BOSS, 5000)
	assert_eq(BossSlow.cut(w), BossSlow.MAX_CUT)
	assert_gt(AttackRate.rate(w, 0), 0)


func test_the_gun_fires_four_times_slower_under_three_quarters() -> void:
	var w := W.world(&"gun")
	var base := Modifiers.bolt(w).period_ticks
	assert_eq(ItemEffects.shot_period_ticks(w), base)
	var free := _launch_ticks(W.world(&"gun"), base * 3 + 2)
	assert_gte(free.size(), 3)
	assert_eq(free[1] - free[0], base, "unslowed: one shot a period")
	BossSlow.apply(w, SOME_BOSS, 750)
	assert_eq(ItemEffects.shot_period_ticks(w), base * 4, "the period at a quarter of the rate")
	var slow := _launch_ticks(w, base * 12 + 2)
	assert_gte(slow.size(), 3)
	assert_eq(slow[1] - slow[0], base * 4, "the shots come four periods apart")
	assert_eq(slow[2] - slow[1], base * 4)
	BossSlow.give_back(w, 250)
	assert_eq(ItemEffects.shot_period_ticks(w), base * 2, "one part back: half the rate")
	BossSlow.give_back(w, 500)
	assert_eq(ItemEffects.shot_period_ticks(w), base, "all back")


func test_the_blade_swings_four_times_slower() -> void:
	var w := W.world(&"blade")
	var base: SwingStep = w.player.combo[0]
	BossSlow.apply(w, SOME_BOSS, 750)
	assert_eq(AttackRate.rate(w, 0), 250)
	var s := BladeForms.step(w, 0)
	assert_eq(s.active_tick, base.active_tick * 4, "the hit tick")
	assert_eq(s.ticks, base.ticks * 4, "the whole swing")
	w.step(W.frame(InputFrame.PRIMARY))
	var n := 1
	while w.swing_t > 0 and n < 2000:
		w.step(W.frame())
		n += 1
	assert_eq(n, s.ticks + 1, "the swing lasts its slowed ticks")
	BossSlow.clear(w)
	assert_eq(BladeForms.step(w, 0).ticks, base.ticks, "and its own again")


func test_the_laser_and_the_lance_lose_the_whole_cut() -> void:
	for id: StringName in [&"gun_laser", &"gun_lance"]:
		var w := W.world(&"gun", [id])
		var spec := Modifiers.bolt(w)
		var own := ItemEffects.shot_period_milli_of(w, spec)
		BossSlow.apply(w, SOME_BOSS, 750)
		assert_eq(
			AttackRate.shot_rate(w, spec, spec.rate_bonus_permille),
			250,
			"%s: a quarter of its rate, whatever share of attack speed the form counts" % id
		)
		assert_eq(ItemEffects.shot_period_milli_of(w, spec), own * 4, "%s: its period" % id)
		BossSlow.give_back(w, 250)
		assert_eq(ItemEffects.shot_period_milli_of(w, spec), own * 2, "%s: one part back" % id)


func test_the_auto_abilities_and_the_spells_are_spared() -> void:
	assert_true(BossSlow.WEAPON_ONLY, "the decision this test pins")
	var w := W.world(&"gun")
	var auto := [Stats.period(w, 100), Stats.auto_period(w, 100), Stats.auto_cooldown(w, 100)]
	var cool := Stats.cooldown(w, 100)
	BossSlow.apply(w, SOME_BOSS, 750)
	assert_eq(AttackRate.auto_rate(w), 1000)
	assert_eq(
		[Stats.period(w, 100), Stats.auto_period(w, 100), Stats.auto_cooldown(w, 100)],
		auto,
		"the auto abilities' periods and cooldowns"
	)
	assert_eq(Stats.cooldown(w, 100), cool, "the cooldowns stat")


func test_it_multiplies_with_heavy_hands() -> void:
	var w := EventLab.world(4242, 1, &"gun", [&"heavy_hands"])
	var heavy := AttackRate.rate(w, 0)
	assert_eq(heavy, 800, "Heavy Hands alone: -20 %")
	BossSlow.apply(w, SOME_BOSS, 750)
	assert_eq(AttackRate.rate(w, 0), 200, "800 x 25 %")
	assert_eq(AttackRate.own_rate_at(w, Stats.value(w, Stats.Stat.ATTACK_SPEED), 0), heavy)
	BossSlow.give_back(w, 750)
	assert_eq(AttackRate.rate(w, 0), heavy, "the curse stays when the boss's cut is back")


func test_it_ends_with_its_boss() -> void:
	var s := _fight()
	var w: World = s[0]
	BossSlow.apply(w, s[1], 750)
	_step(w, 30)
	assert_eq(BossSlow.cut(w), 750, "it holds while the boss lives")
	BossSignatures.on_boss_gone(w, s[1])
	assert_eq(BossSlow.cut(w), 0)
	assert_eq(w.bosses.aslow_boss, -1)
	BossSlow.apply(w, SOME_BOSS, 750)  # A boss that is not in the world
	_step(w, 1)
	assert_eq(BossSlow.cut(w), 0, "no boss behind it: gone on the next tick")


func test_another_boss_leaving_does_not_return_it() -> void:
	var s := _fight()
	var w: World = s[0]
	BossSlow.apply(w, s[1], 750)
	BossSignatures.on_boss_gone(w, SOME_BOSS)
	assert_eq(BossSlow.cut(w), 750)


func test_it_ends_when_the_hero_dies() -> void:
	var s := _fight()
	var w: World = s[0]
	BossSlow.apply(w, s[1], 750)
	_step(w, 2)
	assert_eq(BossSlow.cut(w), 750)
	w.actors.invuln[0] = 0
	var p := w.player_pos()
	Damage.hit(w, 0, LONG * 4, s[1], s[1], w.take_root(), 0, p, p)
	_step(w, HIT_STOP + 1)
	assert_true(w.player_dead())
	assert_eq(BossSlow.cut(w), 0)


func test_it_ends_when_the_hero_is_outside_the_arena() -> void:
	var s := _fight()
	var w: World = s[0]
	w.bosses.arena = Rect2(-40, -40, 80, 80)
	BossSlow.apply(w, s[1], 750)
	_step(w, 5)
	assert_eq(BossSlow.cut(w), 750, "inside: it holds")
	w.actors.set_pos(0, Vector2(60, 0))
	_step(w, 1)
	assert_eq(BossSlow.cut(w), 0)


func test_a_snapshot_keeps_it() -> void:
	var s := _fight()
	var w: World = s[0]
	BossSlow.apply(w, s[1], 750)
	BossSlow.give_back(w, 250)
	_step(w, 10)
	var hash_a := w.state_hash()
	var snap := WorldSnapshot.take(w)
	var back := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), BossLab.world(11))
	assert_not_null(back, "restores")
	if back == null:
		return
	assert_eq(BossSlow.cut(back), 500)
	assert_eq(back.state_hash(), hash_a, "the restored world hashes the same")
	_step(w, 60)
	_step(back, 60)
	assert_eq(back.state_hash(), w.state_hash(), "and runs on the same")


func test_the_hash_reads_it_only_while_held() -> void:
	var s := _fight()
	var w: World = s[0]
	var clean := w.state_hash()
	BossSlow.apply(w, s[1], 750)
	var held := w.state_hash()
	assert_ne(held, clean, "the cut is state")
	BossSlow.give_back(w, 250)
	assert_ne(w.state_hash(), held, "and so is its size")
	BossSlow.clear(w)
	assert_eq(w.state_hash(), clean, "a world no boss slows hashes as before")


func test_same_seed_same_hash() -> void:
	var run := func(seed_value: int) -> String:
		var s := _fight(seed_value)
		var w: World = s[0]
		_step(w, 20)
		BossSlow.apply(w, s[1], 750)
		_step(w, 40)
		BossSlow.give_back(w, 250)
		_step(w, 40)
		return w.state_hash()
	assert_eq(run.call(21), run.call(21))
