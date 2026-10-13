extends GutTest
## v0.6.5 WN1 (docs/design/WAND.md rules 2–3; SIM_CONTRACTS §8e): the wand compiles left to right. Each card rewrites
## the spell built so far, a hook's child is built where its card sits (the cards to its right reach it, the ones to
## its left don't), and a trigger ends the spell: the cards to its right build the child spell (a small copy of the
## basic attack) it casts on its trigger, nesting once more (depth ≤ 2). Order sensitivity is proved on the compiled
## specs here and in a scripted fight's events in test_wand_order_fight.gd.

const FORM := AttackSpec.Form
const TRIGGER := AttackSpec.Trigger


func _book(weapon: StringName, mods: Array) -> AttackBook:
	var typed: Array[ModifierTable] = []
	for m: ModifierTable in mods:
		typed.append(m)
	return Modifiers.compile_for(WandLab.world(weapon), typed)


func _bolt(mods: Array) -> AttackSpec:
	return _book(&"gun", mods).spec(Modifiers.GUN_BOLT)


func _hook(s: AttackSpec, id: StringName) -> AttackHook:
	for k in s.hooks:
		if k.id == id:
			return k
	return null


# --- Order matters -------------------------------------------------------------------------------------------------
func test_big_then_split_is_one_big_shot_whose_splits_are_normal() -> void:
	var w := WandLab.world(&"gun")
	var plain := w.player.bolt_radius_m
	var s := _bolt([WandLab.big(), WandLab.card(&"split_shot")])
	assert_almost_eq(s.radius_m, plain * 2.0, 1e-5, "the shot is big")
	var k := _hook(s, &"split_shot")
	assert_not_null(k, "it splits")
	assert_eq(k.child.count, 3)
	assert_almost_eq(
		k.child.radius_m, 0.08, 1e-5, "the splits are the card's normal size (half the bolt)"
	)


func test_split_then_big_makes_the_splits_big_too() -> void:
	var w := WandLab.world(&"gun")
	var s := _bolt([WandLab.card(&"split_shot"), WandLab.big()])
	assert_almost_eq(s.radius_m, w.player.bolt_radius_m * 2.0, 1e-5, "the shot is big")
	var k := _hook(s, &"split_shot")
	assert_almost_eq(k.child.radius_m, 0.16, 1e-5, "Big reaches the splits built to its left")
	assert_eq(k.child.damage_mul_permille, 1600, "and their damage weight")


func test_big_split_and_split_big_compile_to_different_specs() -> void:
	var a := _book(&"gun", [WandLab.big(), WandLab.card(&"split_shot")])
	var b := _book(&"gun", [WandLab.card(&"split_shot"), WandLab.big()])
	assert_ne(a.digest, b.digest, "Big·Split ≠ Split·Big")
	assert_eq(a.modifier_ids, PackedStringArray(["big", "split_shot"]))
	assert_eq(b.modifier_ids, PackedStringArray(["split_shot", "big"]))


func test_shipped_cards_are_order_sensitive_too() -> void:
	# Short Fuse (×0.6 range, ×1.4 damage on every attack) and Split Shot: the splits fly short only when Short Fuse
	# sits to their right.
	var a := _bolt([WandLab.card(&"short_fuse"), WandLab.card(&"split_shot")])
	var b := _bolt([WandLab.card(&"split_shot"), WandLab.card(&"short_fuse")])
	var ca := _hook(a, &"split_shot").child
	var cb := _hook(b, &"split_shot").child
	assert_eq(a.life_ticks, b.life_ticks, "the shot itself flies short either way")
	assert_lt(cb.life_ticks, ca.life_ticks, "only Split·Short Fuse shortens the splits")


func test_inside_one_card_the_ops_keep_their_stage_order() -> void:
	# Halo Shot: count × 3, a circle, range × 0.5, listed out of stage order in a synthetic copy.
	var halo := WandLab.card(&"halo_shot")
	var rev: Array[ModifierOp] = []
	for k in range(halo.ops.size() - 1, -1, -1):
		rev.append(halo.ops[k])
	var flipped := WandLab.mod(&"halo_flipped", ["projectile"], rev)
	var a := _bolt([halo])
	var b := _bolt([flipped])
	assert_eq([a.count, a.directions, a.life_ticks], [b.count, b.directions, b.life_ticks])
	assert_eq(a.count, 3, "×3 of one shot")


# --- Triggers -------------------------------------------------------------------------------------------------------
func test_fire_before_on_hit_burns_the_shot_and_not_the_child() -> void:
	var s := _bolt([WandLab.fire(), WandLab.card(&"trigger_on_hit"), WandLab.shock()])
	assert_true(s.has_status(&"burn"), "the shot burns")
	assert_false(s.has_status(&"shock"), "the cards right of the trigger don't touch the shot")
	var k := _hook(s, &"trigger_on_hit")
	assert_not_null(k, "the trigger cuts")
	assert_eq(k.trigger, TRIGGER.ON_HIT)
	assert_false(k.child.has_status(&"burn"), "the child starts as the plain basic attack")
	assert_true(k.child.has_status(&"shock"), "the cards to its right build it")
	assert_eq(k.child.depth, 1)


func test_on_hit_before_fire_burns_only_the_child() -> void:
	var s := _bolt([WandLab.card(&"trigger_on_hit"), WandLab.fire(), WandLab.shock()])
	assert_false(s.has_status(&"burn"))
	assert_false(s.has_status(&"shock"))
	var c := _hook(s, &"trigger_on_hit").child
	assert_true(c.has_status(&"burn") and c.has_status(&"shock"))
	assert_eq(c.elements, PackedStringArray(["ember", "storm"]))


func test_fire_on_hit_x_and_on_hit_fire_x_compile_differently() -> void:
	var x := WandLab.card(&"split_shot")
	var a := _book(&"gun", [WandLab.fire(), WandLab.card(&"trigger_on_hit"), x])
	var b := _book(&"gun", [WandLab.card(&"trigger_on_hit"), WandLab.fire(), x])
	assert_ne(a.digest, b.digest, "Fire·ON_HIT·X ≠ ON_HIT·Fire·X")


func test_the_child_is_a_small_copy_of_the_basic_attack() -> void:
	var w := WandLab.world(&"gun")
	var t := w.wand_table
	var c := _hook(_bolt([WandLab.card(&"trigger_on_hit")]), &"trigger_on_hit")
	assert_eq(c.child.form, FORM.BOLT, "the Gun's child is a bolt")
	assert_almost_eq(
		c.child.radius_m, w.player.bolt_radius_m * t.child_size_permille / 1000.0, 1e-5, "smaller"
	)
	assert_eq(
		c.child.life_ticks, w.player.bolt_life_ticks * t.child_range_permille / 1000, "shorter"
	)
	assert_eq(c.damage_permille, t.child_damage_permille, "a share of the hit's damage")
	assert_true(c.child.has_tag(&"hook") and c.child.has_tag(&"weapon"))
	var bw := WandLab.world(&"blade")
	var arc := (
		_book(&"blade", [WandLab.card(&"trigger_on_hit")]).spec(&"blade_step_0").hooks[0].child
	)
	assert_eq(arc.form, FORM.ARC, "the Blade's child is a slash")
	assert_almost_eq(arc.reach_m, bw.player.combo[0].reach_m * t.child_size_permille / 1000.0, 1e-5)


func test_each_trigger_casts_on_its_own_trigger() -> void:
	for pair: Array in [
		[&"trigger_on_hit", TRIGGER.ON_HIT],
		[&"trigger_on_kill", TRIGGER.ON_KILL],
		[&"trigger_on_end", TRIGGER.ON_END],
	]:
		var k := _hook(_bolt([WandLab.card(pair[0])]), pair[0])
		assert_eq(k.trigger, pair[1], String(pair[0]))
	# T4: the Gun's crit; the Blade's finisher, the combo's last step only.
	assert_eq(
		_hook(_bolt([WandLab.card(&"trigger_on_finisher")]), &"trigger_on_finisher").trigger,
		TRIGGER.ON_CRIT
	)
	var b := _book(&"blade", [WandLab.card(&"trigger_on_finisher"), WandLab.fire()])
	var n := WandLab.world(&"blade").player.combo.size()
	for k in n:
		var s := b.spec(Modifiers.step_id(k))
		var h := _hook(s, &"trigger_on_finisher")
		if k == n - 1:
			assert_not_null(h, "the last step finishes")
			assert_eq(h.trigger, TRIGGER.ON_HIT, "on its hits")
			assert_true(h.child.has_status(&"burn"))
		else:
			assert_null(h, "step %d doesn't" % k)
		assert_false(s.has_status(&"burn"), "step %d: Fire is the finisher's" % k)


func test_a_second_trigger_nests_once_and_a_third_casts_nothing() -> void:
	var s := _bolt(
		[
			WandLab.card(&"trigger_on_hit"),
			WandLab.fire(),
			WandLab.card(&"trigger_on_kill"),
			WandLab.shock(),
			WandLab.card(&"trigger_on_end"),
			WandLab.big(),
		]
	)
	var one := _hook(s, &"trigger_on_hit").child
	assert_eq(one.depth, 1)
	assert_true(one.has_status(&"burn") and not one.has_status(&"shock"))
	var two := _hook(one, &"trigger_on_kill").child
	assert_eq(two.depth, 2)
	assert_true(two.has_status(&"shock") and not two.has_status(&"burn"))
	assert_null(
		_hook(two, &"trigger_on_end"), "depth 2 is the deepest: the third trigger casts nothing"
	)
	assert_eq(two.damage_mul_permille, 1000, "and the cards past it reach nothing")


func test_a_trigger_reaches_the_splits_built_to_its_left() -> void:
	var s := _bolt([WandLab.card(&"split_shot"), WandLab.card(&"trigger_on_hit"), WandLab.fire()])
	var split := _hook(s, &"split_shot").child
	var k := _hook(split, &"trigger_on_hit")
	assert_not_null(k, "each split casts on its hits too")
	assert_eq(k.child.depth, 2)
	assert_true(k.child.has_status(&"burn"))
	assert_false(split.has_status(&"burn"), "the splits are the spell you fire: no Fire")


func test_moments_read_past_a_trigger() -> void:
	var b := _book(&"gun", [WandLab.card(&"trigger_on_hit"), WandLab.card(&"phase_dash")])
	assert_eq(
		b.spec(Modifiers.DASH).intangible,
		1,
		"a dash card right of a trigger still rewrites the dash"
	)
	assert_true(b.spec(Modifiers.DASH).hooks.size() > 0)


func test_the_compile_is_deterministic() -> void:
	var mods := [
		WandLab.card(&"split_shot"), WandLab.card(&"trigger_on_hit"), WandLab.fire(), WandLab.big()
	]
	assert_eq(_book(&"gun", mods).digest, _book(&"gun", mods).digest)
