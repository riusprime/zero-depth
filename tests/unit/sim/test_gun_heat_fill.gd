extends GutTest
## v0.9.5 HT (owner Q12 a: "Heat per second of firing, the same for every form (~14 s to full); cools 1.0 s after you
## stop at 25/s; Vent needs >= 40 heat, 6 s cooldown"): a Gun run's heat fills by the time the primary attack is held
## and armed, whatever the form, the attack speed or the hits; it cools 1.0 s after the last firing tick; Vent is
## refused under 40 heat and for 6 s after it went; the cooldown is saved and restored.

const W := preload("res://tests/support/mx4_world.gd")
const M := HeatTable.MILLI
const FILL_TICKS := 840
const FAR := [[Vector2(6.0, 0.0), 1000000]]


func _world(items: Array = [], enemies: Array = FAR) -> World:
	return W.world(&"gun", items, enemies, [], true)


## Ticks of held fire until the meter first reads `target` milli-points or more (-1: not within `cap` ticks).
func _ticks_to(w: World, target: int, cap: int = 1200) -> int:
	for k in cap:
		w.step(W.frame(0, W.S))
		if w.heat.milli >= target or Heat.stalled(w):
			return k + 1
	return -1


func test_holding_fire_14_seconds_fills_the_meter_with_orbs_bomb_and_laser() -> void:
	for form: StringName in [&"", &"gun_bomb", &"gun_laser"]:
		var w := _world([] if form == &"" else [form])
		var n := _ticks_to(w, 100 * M)
		assert_between(n, FILL_TICKS - 1, FILL_TICKS + 1, "%s: 14 s to full (%d ticks)" % [form, n])
		assert_true(Heat.stalled(w), "%s: full heat overheats" % form)


func test_attack_speed_changes_nothing() -> void:
	var plain := _world()
	var base_period := ItemEffects.shot_period_ticks(plain)
	var fast := _world([&"gun_rapid_fire"])
	fast.heat.milli = 0
	assert_lt(ItemEffects.shot_period_ticks(fast), base_period, "the build really shoots faster")
	var n := _ticks_to(fast, 100 * M)
	assert_between(
		n, FILL_TICKS - 1, FILL_TICKS + 1, "a faster gun fills in the same 14 s (%d)" % n
	)
	var bomb := _world([&"gun_bomb", &"gun_rapid_fire"])
	n = _ticks_to(bomb, 100 * M)
	assert_between(n, FILL_TICKS - 1, FILL_TICKS + 1, "and so does a faster Bomb (%d)" % n)
	var hits := _world([&"gun_rapid_fire", &"gun_twin"], [[Vector2(2.0, 0.0), 1000000]])
	W.run(hits, 120, 0, W.S)
	assert_between(
		hits.heat.milli,
		120 * 119,
		120 * 119 + M,
		"landed hits add nothing: 120 ticks, 120 firing ticks"
	)


func test_no_gain_while_not_firing_and_cooling_starts_1_second_after_the_last_firing_tick() -> void:
	var w := _world()
	W.run(w, 60)
	assert_eq(w.heat.milli, 0, "idle: no gain")
	W.run(w, 300, 0, W.S)
	var held := w.heat.milli
	assert_between(held, 119 * 300 - 1, 100000 * 300 / FILL_TICKS + 1, "300 firing ticks")
	W.run(w, 60)
	assert_eq(w.heat.milli, held, "1 s of waiting: no change")
	W.run(w, 1)
	assert_eq(w.heat.milli, held - w.heat.table.cool_per_tick, "then it cools")
	W.run(w, 59)
	assert_eq(w.heat.milli, held - 60 * w.heat.table.cool_per_tick, "25 a second (417 per tick)")
	assert_between(w.heat.table.cool_per_tick * 60, 25000, 25100, "25 heat a second")


func test_a_blade_run_keeps_its_per_hit_heat() -> void:
	var w := W.world(&"blade", [], [[Vector2(1.2, 0.0), 1000000]], [], true)
	W.run(w, 1, W.P)
	W.run(w, 40)
	assert_eq(w.heat.milli, 2500, "the swing adds 2.5 as before")


func test_vent_is_refused_under_40_and_during_its_cooldown_and_accepted_after() -> void:
	var w := _world([], [[Vector2(1.5, 0.0), 1000000]])
	w.heat.milli = 39 * M
	w.step(W.frame(W.V))
	assert_eq(w.heat.milli, 39 * M, "under 40: refused, heat kept")
	assert_eq(w.kit.vent_cd, 0, "and no cooldown starts")
	assert_eq(W.events(w, SimEvent.Kind.VENT).size(), 0, "no vent happened")
	assert_eq(W.events(w, SimEvent.Kind.HIT, Heat.EFFECT_VENT).size(), 0, "no blast")
	assert_false(Heat.vent_ready(w))
	w.heat.milli = 60 * M
	assert_true(Heat.vent_ready(w))
	w.step(W.frame(W.V))
	assert_eq(w.heat.milli, 0, "40 or more: vented")
	assert_eq(w.kit.vent_cd, 360 - 0, "the 6 s cooldown starts")
	w.heat.milli = 80 * M
	assert_false(Heat.vent_ready(w), "on cooldown the prompt is off")
	for k in 359:
		w.step(W.frame(W.V if k % 30 == 0 else 0))
	assert_eq(W.events(w, SimEvent.Kind.VENT).size(), 1, "presses during the cooldown do nothing")
	assert_gt(w.kit.vent_cd, 0)
	W.run(w, 2)
	assert_eq(w.kit.vent_cd, 0, "the cooldown is over after 6 s")
	w.heat.milli = 80 * M
	assert_true(Heat.vent_ready(w))
	w.step(W.frame(W.V))
	assert_eq(w.heat.milli, 0, "and the next vent goes")


func test_the_vent_cooldown_is_saved_and_restored() -> void:
	var w := _world([], [[Vector2(1.5, 0.0), 1000000]])
	w.heat.milli = 60 * M
	w.step(W.frame(W.V))
	W.run(w, 100)
	assert_gt(w.kit.vent_cd, 0)
	var before := w.state_hash()
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray(), "every object is classified")
	var back := World.from_snapshot(
		bytes_to_var(var_to_bytes(snap)), _world([], [[Vector2(1.5, 0.0), 1000000]])
	)
	assert_not_null(back, "the snapshot fits its base")
	assert_eq(back.kit.vent_cd, w.kit.vent_cd, "restored")
	assert_eq(back.state_hash(), before, "and hashed the same")
	var other := _world([], [[Vector2(1.5, 0.0), 1000000]])
	other.heat.milli = 60 * M
	other.step(W.frame(W.V))
	W.run(other, 99)
	assert_ne(other.state_hash(), before, "the cooldown is in the hash")


## Every form runs at Hot and Overclock without error, and the player's hits on it carry Overclock's tag where it
## applies (printed per form for the evidence; v0.9.5 HT lists which bonuses reach which form).
func test_hot_and_overclock_are_safe_on_every_form() -> void:
	var forms: Array = [
		&"",
		&"gun_laser",
		&"gun_bomb",
		&"gun_void",
		&"gun_lance",
		&"gun_rune_explosion",
		&"gun_glaive",
		&"gun_seekers",
		&"gun_wave",
		&"gun_wisps"
	]  # gdlint: ignore=max-line-length
	for form: StringName in forms:
		var row := []
		for level in [0, 45, 80]:
			var w := W.world(
				&"gun",
				[] if form == &"" else [form],
				[
					[Vector2(2.0, 0.0), 1000000],
					[Vector2(3.4, 0.0), 1000000],
					[Vector2(4.8, 0.0), 1000000]
				],
				[],
				true
			)
			var hits := 0
			var oc := 0
			for k in 210:  # 150 ticks held, then released (the Lance fires on release)
				w.heat.milli = maxi(w.heat.milli, level * M)
				w.step(W.frame(0, W.S if k < 150 else 0))
			for e in W.events(w, SimEvent.Kind.HIT):
				if e.owner_id == w.actors.ids[0] and e.target_id != w.actors.ids[0]:
					hits += 1
					oc += 1 if (e.tags & SimEvent.TAG_OVERCLOCK) != 0 else 0
			row.append([level, hits, oc])
		gut.p(
			"%s: [heat, hits, overclock-tagged hits] %s" % [form if form != &"" else &"orbs", row]
		)
		assert_gt(row[0][1], 0, "%s hits at all" % form)


## v0.9.5 (owner Q12: heat for every form): Overclock raises a Gun form's own area hits too (Bomb, Void, Rune
## Explosion), never a status tick, a chain jump, shrapnel or an effect's payoff.
func test_overclock_counts_the_area_forms_own_hits_only() -> void:
	var form_area := SimEvent.TAG_AREA | SimEvent.TAG_PROJECTILE
	assert_true(Heat.overclock_counts(form_area, &""), "a bomb, void or rune burst hit")
	assert_true(Heat.overclock_counts(SimEvent.TAG_PROJECTILE, &""), "a bolt, as before")
	assert_true(Heat.overclock_counts(SimEvent.TAG_MELEE, &""), "a swing, as before")
	assert_false(
		Heat.overclock_counts(SimEvent.TAG_AREA, &""),
		"an area that isn't a form's (no projectile tag)"
	)
	assert_false(Heat.overclock_counts(form_area | SimEvent.TAG_DOT, &""), "a burn tick")
	assert_false(Heat.overclock_counts(form_area | SimEvent.TAG_CHAIN, &""), "a chain jump")
	assert_false(Heat.overclock_counts(form_area | SimEvent.TAG_SHRAPNEL, &""), "shrapnel")
	assert_false(
		Heat.overclock_counts(form_area, &"overclock_heat"), "an effect's payoff (the Vent blast)"
	)
