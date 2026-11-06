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


## v0.9.0 XP (owner Q11: "I don't want to have the enemies exploding after they die"; "Burning ground on kill"):
## Fire's kill blast is gone; a kill by a Fire hit (a burning enemy) leaves a burning patch (1.2 m, 2 s) that burns
## the enemies standing in it, then goes out.
func test_m2_ember_core_burns_and_a_burning_kill_leaves_burning_ground() -> void:
	var w := W.world(&"gun", [&"ember_core"], [[Vector2(2.5, 0.0), 6], [Vector2(2.8, 0.7), 100000]])
	var bolt := Modifiers.bolt(w)
	assert_true(bolt.has_status(&"burn") and bolt.elements.has("ember"))
	var k := W.hook_of(bolt, &"ember_core")
	assert_eq(
		[k.trigger, k.child.form, k.child.alive_max, k.child.life_ticks],
		[TRIG.ON_KILL, FORM.ZONE, 12, 120],
		"a patch on a kill, at most 12, 2 s"
	)
	assert_almost_eq(k.child.radius_m, 1.2, 0.001)
	assert_true(k.child.has_status(&"burn"), "the patch burns")
	assert_true(
		Modifiers.step(w, 0).has_status(&"burn"), "every attack, the Skill and the steps too"
	)
	var key := k.child.key
	var a := w.actors
	var first := a.ids[1]
	var second := a.ids[2]
	var lit := -1
	var out := -1
	var burnt := 0
	for t in 300:
		var i1 := a.index_of(first)
		w.step(W.frame(0, W.S if i1 >= 0 and a.dead[i1] == 0 else 0))
		var on := Array(w.ab.fire_spec).has(key)
		if lit < 0 and on:
			lit = w.tick
		if lit >= 0 and out < 0 and not on:
			out = w.tick
		var i2 := a.index_of(second)
		if on and i2 >= 0:
			burnt = maxi(burnt, a.burn_stacks[i2])
	var gone := a.index_of(first)
	assert_true(gone < 0 or a.dead[gone] == 1, "the first enemy died")
	assert_gt(lit, -1, "its death left a burning patch")
	assert_gt(burnt, 0, "the enemy standing in it burns")
	assert_almost_eq(out - lit, 120, 2, "it goes out after 2 s")
	assert_eq(w.actors.hp[0], w.actors.max_hp[0], "the patch never hurts the hero")
	assert_gt(w.item_mods.burn_max_stacks, 0, "the card brings the burn engine's numbers")


## v0.9.0 XP: Fire's patches are capped (12 alive); one lit within a patch's radius merges into it (renewing it).
func test_m2_fire_patches_cap_at_twelve_and_merge_when_close() -> void:
	var w := W.world(&"gun", [&"ember_core"])
	var child := W.hook_of(Modifiers.bolt(w), &"ember_core").child
	var r := Attacks.area_radius(w, child)
	var seq := w.last_event_seq()
	for n in 16:
		var at := Vector2(n * 3.0, 20.0)
		var ctx := AttackContext.make(at, 0, 5, w.take_root(), 0, &"ember_core")
		ElementAbilities.add_zone(w, at, r, child.life_ticks, child, ctx)
	assert_eq(Array(w.ab.fire_spec).count(child.key), 12, "at most 12 alive")
	var limits := 0
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.LIMIT and e.effect_id == Attacks.EFFECT_ALIVE_CAP:
			limits += 1
	assert_eq(limits, 4, "each one past the cap: a LIMIT, not lit")
	var end0 := w.ab.fire_end[0]
	w.tick += 30
	var near := Vector2(0.5, 20.0)
	var c2 := AttackContext.make(near, 0, 5, w.take_root(), 0, &"ember_core")
	ElementAbilities.add_zone(w, near, r, child.life_ticks, child, c2)
	assert_eq(Array(w.ab.fire_spec).count(child.key), 12, "a close one merges")
	assert_eq(w.ab.fire_end[0], end0 + 30, "into the patch there, renewed")


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


func test_m8_halo_shot_fires_all_round_four_times_the_count_at_half_range() -> void:  # v0.9.5 CLV: Lv 1 = 4
	var plain := Modifiers.bolt(W.world(&"gun"))
	var w := W.world(&"gun", [&"halo_shot"])
	var bolt := Modifiers.bolt(w)
	assert_eq([bolt.count, bolt.directions], [plain.count * 4, AttackSpec.DIR_CIRCLE])
	assert_eq(bolt.life_ticks, plain.life_ticks / 2)
	assert_eq(Attacks.shot_offsets(bolt), PackedInt32Array([0, 1024, 2048, 3072]))
	W.run(w, 2, 0, W.S)
	assert_eq(W.projectiles_of(w, Modifiers.GUN_BOLT), 4, "four bolts round the player")


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


func test_m11_split_shot_splits_in_two_and_the_splits_never_split() -> void:  # v0.9.5 CLV: Lv 1 = 2
	var w := W.world(&"gun", [&"split_shot"], [[Vector2(2.0, 0.0), 2000]])
	var k := W.hook_of(Modifiers.bolt(w), &"split_shot")
	assert_eq([k.trigger, k.child.form, k.child.count], [TRIG.ON_HIT, FORM.BOLT, 2])
	assert_null(W.hook_of(k.child, &"split_shot"), "lineage: its own child carries no split")
	assert_true(k.child.lineage.has("split_shot"))
	W.run(w, 1, 0, W.S)
	var seen := 0
	for t in 20:
		w.step(W.frame())
		seen = maxi(seen, W.projectiles_of(w, &"split_shot"))
	assert_eq(seen, 2, "two splits leave the hit")


## v0.6.5 WN4: Wide Arc is the Blade pool's B1 (WAND.md): +60° and +30 % reach on the slash, the Gun untouched
## (test_wand_blade.gd has its fight).
func test_m14_wide_arc_widens_arcs_and_grows_projectiles() -> void:
	var plain := W.world(&"blade")
	var w := W.world(&"blade", [&"wide_arc"])
	var a := Modifiers.step(plain, 0)
	var b := Modifiers.step(w, 0)
	assert_eq(b.half_arc - a.half_arc, ContentCompiler.degrees_to_units(30.0), "+60° wide")
	assert_eq(b.reach_bonus_permille, 300, "+30 % reach")
	assert_almost_eq(Modifiers.bolt(w).radius_m, Modifiers.bolt(plain).radius_m, 1e-5, "Blade-only")
