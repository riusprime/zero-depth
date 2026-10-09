extends GutTest
## v0.6.0 MX4 (PLAN v0.5.5 M1–M15; docs/design/MODIFIER_ENGINE.md): each modifier's rewrite of the specs and its
## effect in a scripted scenario (standing dummies, scripted input, crit off). Mechanics only: no bot, no balance
## (owner P1). M16–M30, the ability mods and the legendaries: test_mx4_modifiers_2.gd.

const W := preload("res://tests/support/mx4_world.gd")
const FORM := AttackSpec.Form
const TRIG := AttackSpec.Trigger


func test_m1_storm_core_chains_lightning_to_two_more_enemies() -> void:
	var w := W.world(
		&"gun",
		[&"storm_core"],
		[[Vector2(3.0, 0.0), 500], [Vector2(3.0, 1.6), 500], [Vector2(3.0, -1.6), 500]]
	)
	var bolt := Modifiers.bolt(w)
	assert_true(bolt.elements.has("storm"), "storm element")
	var k := W.hook_of(bolt, &"storm_core")
	assert_not_null(k, "an ON_HIT chain")
	if k == null:
		return
	assert_eq(
		[k.trigger, k.child.form, k.child.chains, k.damage_permille],
		[TRIG.ON_HIT, FORM.BEAM, 1, 500]
	)
	W.run(w, 30, 0, W.S)
	var jumps := W.damage(w, &"storm_core")
	assert_eq(W.targets(jumps).size(), 2, "each landed bolt chains to the 2 others")


func test_m2_ember_core_burns_and_kills_explode() -> void:
	var w := W.world(&"gun", [&"ember_core"], [[Vector2(2.5, 0.0), 6], [Vector2(3.4, 0.6), 400]])
	var bolt := Modifiers.bolt(w)
	assert_true(bolt.has_status(&"burn") and bolt.elements.has("ember"))
	var k := W.hook_of(bolt, &"ember_core")
	assert_eq([k.trigger, k.child.form], [TRIG.ON_KILL, FORM.BURST])
	assert_true(
		Modifiers.step(w, 0).has_status(&"burn"), "every attack, the Skill and the steps too"
	)
	W.run(w, 40, 0, W.S)
	assert_gt(W.damage(w, &"ember_core").size(), 0, "the kill burst")
	assert_gt(w.item_mods.burn_max_stacks, 0, "the card brings the burn engine's numbers")


func test_m3_frost_core_freezes_on_the_third_hit_on_a_slowed_enemy() -> void:
	var w := W.world(&"blade", [&"frost_core"], [[Vector2(1.0, 0.0), 2000]])
	var s := Modifiers.step(w, 0)
	assert_eq([s.stacks_of(&"frost"), s.every_of(&"frost")], [1, 0], "a frost stack on every hit")
	assert_eq(w.item_mods.frost_threshold, 3)
	assert_eq(w.item_mods.freeze_ticks, 60, "1 s")
	var frozen_at := -1
	for n in 3:
		W.run(w, 1, W.P)
		for t in 30:
			w.step(W.frame())
			if frozen_at < 0 and w.actors.frozen_t[1] > 0:
				frozen_at = n
	assert_eq(frozen_at, 2, "frozen by the 3rd hit, slowed before it")


func test_m4_venom_core_poisons_and_spreads_on_death() -> void:
	var w := W.world(&"gun", [&"venom_core"], [[Vector2(2.5, 0.0), 30], [Vector2(3.6, 0.0), 2000]])
	assert_true(Modifiers.bolt(w).has_status(&"poison"))
	W.run(w, 20, 0, W.S)
	assert_gt(w.actors.poison_stacks[1], 0, "the bolt's hits stack poison")
	W.run(w, 200, 0, W.S)
	assert_gt(W.damage(w, Venom.EFFECT_POISON).size(), 0, "poison ticks as DoT")
	var spread := false
	for e in W.events(w, SimEvent.Kind.STATUS_APPLY, Venom.EFFECT_POISON):
		spread = spread or e.target_id == w.actors.ids[w.actors.size() - 1]
	assert_true(spread, "the second enemy is poisoned")


func test_m5_echo_slash_throws_a_crescent_as_wide_as_the_arc() -> void:
	var w := W.world(&"blade", [&"echo_slash"], [[Vector2(5.0, 0.0), 500]])
	var step := Modifiers.step(w, 0)
	var k := W.hook_of(step, &"echo_slash")
	assert_eq([k.trigger, k.child.form], [TRIG.ON_LAUNCH, FORM.BOLT])
	assert_eq(k.child.half_arc, step.half_arc, "a crescent of the arc's width")
	assert_true(k.child.has_tag(&"projectile"))
	W.run(w, 40, W.P)
	assert_gt(
		W.damage(w, &"echo_slash").size(), 0, "the crescent hits an enemy past the blade's reach"
	)


func test_m6_edge_rounds_pierce_once_and_slash_where_they_hit() -> void:
	var w := W.world(&"gun", [&"edge_rounds"], [[Vector2(2.0, 0.0), 500], [Vector2(3.5, 0.0), 500]])
	var bolt := Modifiers.bolt(w)
	assert_eq(bolt.pierce, 1)
	assert_eq(W.hook_of(bolt, &"edge_rounds").child.form, FORM.ARC)
	W.run(w, 2, 0, W.S)
	W.run(w, 20)
	var hits := W.events(w, SimEvent.Kind.HIT, &"")
	var on := []
	for e in hits:
		if e.owner_id == w.actors.ids[0] and not on.has(e.target_id):
			on.append(e.target_id)
	assert_eq(on.size(), 2, "the first bolt goes through the first dummy into the second")
	assert_gt(W.damage(w, &"edge_rounds").size(), 0, "a short slash where it hit")


func test_m7_shock_circles_turn_shots_into_rings_at_half_range() -> void:
	var plain := W.world(&"gun")
	var range_m := SpecForms.range_of(Modifiers.bolt(plain))
	var w := W.world(&"gun", [&"shock_circles"], [[Vector2(2.0, 0.5), 500]])
	var bolt := Modifiers.bolt(w)
	assert_eq(bolt.form, FORM.RING)
	assert_almost_eq(bolt.radius_m, clampf(range_m * 0.5, 1.5, 6.0), 1e-4, "half the shot's range")
	assert_true(bolt.has_status(&"shock") and bolt.elements.has("storm"))
	W.run(w, 3, 0, W.S)
	assert_gt(w.ab.ring_pos.size(), 0, "a ring grows from the player")
	W.run(w, 30, 0, W.S)
	var shocked := W.events(w, SimEvent.Kind.STATUS_APPLY, Engines.EFFECT_SHOCK)
	assert_gt(shocked.size(), 0, "the ring shocks what it passes")


func test_m8_halo_shot_fires_all_round_three_times_the_count_at_half_range() -> void:
	var plain := Modifiers.bolt(W.world(&"gun"))
	var w := W.world(&"gun", [&"halo_shot"])
	var bolt := Modifiers.bolt(w)
	assert_eq([bolt.count, bolt.directions], [plain.count * 3, AttackSpec.DIR_CIRCLE])
	assert_eq(bolt.life_ticks, plain.life_ticks / 2)
	assert_eq(Attacks.shot_offsets(bolt), PackedInt32Array([0, 1365, 2730]))
	W.run(w, 2, 0, W.S)
	assert_eq(W.projectiles_of(w, Modifiers.GUN_BOLT), 3, "three bolts round the player")


func test_m9_boomerang_projectiles_come_back() -> void:
	var w := W.world(&"gun", [&"boomerang"])
	assert_eq(Modifiers.bolt(w).returns, 1)
	W.run(w, 1, 0, W.S)
	W.run(w, 1)
	var p := w.projectiles
	assert_eq(p.ret[0], 1, "flying out")
	var far := 0.0
	var back := false
	for t in Modifiers.bolt(w).life_ticks:
		w.step(W.frame())
		if p.size() == 0:
			break
		var d := Kin.length(Vector2(p.pos_x[0], p.pos_y[0]) - w.player_pos())
		far = maxf(far, d)
		back = back or (p.ret[0] == 2 and d < far - 1.0)
	assert_true(back, "it turns back at half its life and heads for the player")


func test_m10_orbit_rounds_circle_the_player_before_they_fly() -> void:
	var w := W.world(&"gun", [&"orbit_rounds"])
	assert_eq(Modifiers.bolt(w).orbit_ticks, 30)
	W.run(w, 1, 0, W.S)
	W.run(w, 1)
	var near := true
	for t in 25:
		w.step(W.frame())
		var d := Kin.length(
			Vector2(w.projectiles.pos_x[0], w.projectiles.pos_y[0]) - w.player_pos()
		)
		near = near and d < ProjectileMoves.ORBIT_R_M + 0.3
	assert_true(near, "it stays on the ring round the player while it orbits")
	W.run(w, 20)
	var d := Kin.length(Vector2(w.projectiles.pos_x[0], w.projectiles.pos_y[0]) - w.player_pos())
	assert_gt(d, ProjectileMoves.ORBIT_R_M + 1.0, "then it leaves")


func test_m11_split_shot_splits_in_three_and_the_splits_never_split() -> void:
	var w := W.world(&"gun", [&"split_shot"], [[Vector2(2.0, 0.0), 2000]])
	var k := W.hook_of(Modifiers.bolt(w), &"split_shot")
	assert_eq([k.trigger, k.child.form, k.child.count], [TRIG.ON_HIT, FORM.BOLT, 3])
	assert_null(W.hook_of(k.child, &"split_shot"), "lineage: its own child carries no split")
	assert_true(k.child.lineage.has("split_shot"))
	W.run(w, 1, 0, W.S)
	var seen := 0
	for t in 20:
		w.step(W.frame())
		seen = maxi(seen, W.projectiles_of(w, &"split_shot"))
	assert_eq(seen, 3, "three splits leave the hit")


func test_m12_twin_cast_repeats_a_shot_and_rides_the_blade_echo() -> void:
	var w := W.world(&"gun", [&"twin_cast"])
	var bolt := Modifiers.bolt(w)
	assert_eq([bolt.repeat_delay_ticks, bolt.repeat_damage_permille], [12, 500])
	W.run(w, 1, 0, W.S)
	assert_eq(w.mx.q_key.size(), 1, "the repeat waits")
	W.run(w, 13)
	var spawned := 0
	for e in W.events(w, SimEvent.Kind.SPAWN):
		if w.projectiles.ids.has(e.target_id) or e.owner_id == w.actors.ids[0]:
			spawned += 1
	assert_gte(spawned, 2, "the shot, then its repeat")
	assert_eq(w.mx.q_key.size(), 0)
	var b := W.world(&"blade", [&"twin_cast"], [[Vector2(1.0, 0.0), 2000]])
	assert_eq(Modifiers.step(b, 0).repeat_delay_ticks, 12)
	W.run(b, 30, W.P)
	assert_eq(b.mx.q_key.size(), 0, "a combo step repeats through its Twin Arc echo, not the queue")
	assert_gt(b.echo_tick, -1, "the echo swung")


func test_m13_rearguard_fires_back_at_sixty_percent() -> void:
	var w := W.world(&"gun", [&"rearguard"], [[Vector2(-2.0, 0.0), 2000]])
	assert_eq(Modifiers.bolt(w).back_permille, 600)
	W.run(w, 1, 0, W.S)
	W.run(w, 1)
	assert_eq(W.projectiles_of(w, Modifiers.GUN_BOLT), 2)
	var back := false
	for i in w.projectiles.size():
		back = back or w.projectiles.vel_x[i] < 0.0
	assert_true(back, "one bolt flies back")
	W.run(w, 20)
	var hit := W.damage(w, &"")
	assert_gt(hit.size(), 0, "the enemy behind is hit")


func test_m14_wide_arc_widens_arcs_and_grows_projectiles() -> void:
	var plain := W.world(&"blade")
	var w := W.world(&"blade", [&"wide_arc"])
	var a := Modifiers.step(plain, 0)
	var b := Modifiers.step(w, 0)
	assert_eq(b.half_arc - a.half_arc, ContentCompiler.degrees_to_units(20.0), "+40° wide")
	assert_almost_eq(Modifiers.bolt(w).radius_m, Modifiers.bolt(plain).radius_m * 1.3, 1e-5)


func test_m15_gravity_well_pulls_enemies_toward_the_hit() -> void:
	var w := W.world(
		&"gun", [&"gravity_well"], [[Vector2(2.0, 0.0), 2000], [Vector2(2.0, 2.0), 2000]]
	)
	var k := W.hook_of(Modifiers.bolt(w), &"gravity_well")
	assert_almost_eq(k.child.pull_m, 0.8, 1e-6)
	var before := w.actors.pos(2)
	W.run(w, 1, 0, W.S)
	W.run(w, 12)
	assert_lt(w.actors.pos(2).y, before.y - 0.3, "the side enemy is pulled toward the hit")
