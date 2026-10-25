extends GutTest
## v0.6.5 WN5a (docs/design/WAND.md rules 2–3, "Order matters": Fire · ON HIT · Shock versus ON HIT · Fire · Shock):
## the shared cards and the trigger cards in slot order, on both weapons, with the shipped cards: what the spell and
## the child spell carry, which enemy burns in a scripted scene, the fight's events, and the triggers offered for
## real with their final faces. The cast marks the views draw (WandCasts). Mechanics only: no bot, no balance (P1).

const W := preload("res://tests/support/mx4_world.gd")
const FORM := AttackSpec.Form
const WEAPONS: Array[StringName] = [&"blade", &"gun"]
const FIRE_FIRST: Array[StringName] = [&"ember_core", &"trigger_on_hit", &"storm_core"]
const HIT_FIRST: Array[StringName] = [&"trigger_on_hit", &"ember_core", &"storm_core"]


func _spell(w: World, weapon: StringName) -> AttackSpec:
	return Modifiers.step(w, 0) if weapon == &"blade" else Modifiers.bolt(w)


func _attack(w: World, weapon: StringName, after: int = 30) -> void:
	if weapon == &"blade":
		W.run(w, 1, W.P)
	else:
		W.run(w, 1, 0, W.S)
	W.run(w, after)


## Enemy A where the spell hits, and enemy B where only the ON HIT child reaches: the Gun's child bolt flies on past
## A along the line; the Blade's child slash sweeps on from A, past the first slash's reach.
func _scene(weapon: StringName, ids: Array[StringName]) -> World:
	var probe := W.world(weapon, ids)
	var a := Vector2(2.5, 0.0)
	var b := a + Vector2(1.5, 0.0)
	if weapon == &"blade":  # each one's edge 0.15 m inside its slash's reach
		var r := probe.player.radius_m
		var root := Modifiers.step(probe, 0)
		var child := W.hook_of(root, &"trigger_on_hit").child
		a = Vector2(r + Attacks.arc_reach_m(probe, root) + 0.2, 0.0)
		b = a + Vector2(r + Attacks.arc_reach_m(probe, child) + 0.2, 0.0)
		assert_false(
			Attacks.arc_touches(probe, root, Vector2.ZERO, 0, b, 0.35), "B is past the slash"
		)
		assert_true(Attacks.arc_touches(probe, child, a, 0, b, 0.35), "the child reaches B")
	return W.world(weapon, ids, [[a, 5000], [b, 5000]])


# --- Fire · ON HIT · Lightning versus ON HIT · Fire · Lightning ---------------------------------------------
func test_fire_left_of_on_hit_burns_the_spell_and_not_the_child() -> void:
	for weapon in WEAPONS:
		var s := _spell(W.world(weapon, FIRE_FIRST), weapon)
		assert_true(s.has_status(&"burn"), "%s: the spell burns" % weapon)
		assert_has(s.elements, "ember", "%s: an ember core" % weapon)
		assert_null(W.hook_of(s, &"storm_core"), "%s: Lightning is right of the cut" % weapon)
		var c := W.hook_of(s, &"trigger_on_hit").child
		assert_false(c.has_status(&"burn"), "%s: the child doesn't burn" % weapon)
		assert_not_null(W.hook_of(c, &"storm_core"), "%s: the child chains lightning" % weapon)
		assert_eq(c.elements, PackedStringArray(["storm"]), "%s: a storm child" % weapon)


func test_on_hit_left_of_fire_burns_only_the_child() -> void:
	for weapon in WEAPONS:
		var s := _spell(W.world(weapon, HIT_FIRST), weapon)
		assert_false(s.has_status(&"burn"), "%s: the spell doesn't burn (no rider)" % weapon)
		assert_eq(s.elements, PackedStringArray(), "%s: a plain spell" % weapon)
		var c := W.hook_of(s, &"trigger_on_hit").child
		assert_true(c.has_status(&"burn"), "%s: the child burns" % weapon)
		assert_eq(
			c.elements, PackedStringArray(["ember", "storm"]), "%s: ember, then storm" % weapon
		)
		assert_not_null(W.hook_of(c, &"storm_core"), "%s: and chains lightning" % weapon)


func test_the_order_decides_which_enemy_burns() -> void:
	for weapon in WEAPONS:
		var one := _scene(weapon, FIRE_FIRST)
		var two := _scene(weapon, HIT_FIRST)
		for w: World in [one, two]:
			_attack(w, weapon, 20)
		assert_gt(
			one.actors.burn_stacks[1], 0, "%s, Fire · ON HIT: A (the spell's hit) burns" % weapon
		)
		assert_eq(
			one.actors.burn_stacks[2], 0, "%s, Fire · ON HIT: B (the child's) doesn't" % weapon
		)
		assert_gt(
			two.actors.burn_stacks[2], 0, "%s, ON HIT · Fire: B (the child's hit) burns" % weapon
		)
		if weapon == &"gun":  # the Blade's child slash, cast at A, sweeps A too (WN1: it starts on the hit)
			assert_eq(
				two.actors.burn_stacks[1], 0, "gun, ON HIT · Fire: A (the bolt's hit) doesn't burn"
			)
		for w: World in [one, two]:
			assert_gt(W.damage(w, &"trigger_on_hit").size(), 0, "%s: the child spell hits" % weapon)
			assert_gt(W.damage(w, &"storm_core").size(), 0, "%s: and its lightning arcs" % weapon)


func test_the_two_orders_fight_differently_and_each_replays() -> void:
	for weapon in WEAPONS:
		var a := WandLab.run(WandLab.fight(weapon, FIRE_FIRST), 240)
		var b := WandLab.run(WandLab.fight(weapon, HIT_FIRST), 240)
		var again := WandLab.run(WandLab.fight(weapon, HIT_FIRST), 240)
		assert_ne(a["digest"], b["digest"], "%s: the order changes the fight" % weapon)
		assert_eq(b["digest"], again["digest"], "%s: the same order replays" % weapon)
		assert_eq(b["hash"], again["hash"])


func test_explosive_left_or_right_of_on_end() -> void:
	for weapon in WEAPONS:
		var left := _spell(W.world(weapon, [&"shared_explosive", &"trigger_on_end"]), weapon)
		var right := _spell(W.world(weapon, [&"trigger_on_end", &"shared_explosive"]), weapon)
		assert_not_null(W.hook_of(left, &"shared_explosive"), "%s: the spell explodes" % weapon)
		assert_null(
			W.hook_of(W.hook_of(left, &"trigger_on_end").child, &"shared_explosive"),
			"%s: its child doesn't" % weapon
		)
		assert_null(W.hook_of(right, &"shared_explosive"), "%s: the spell doesn't" % weapon)
		assert_not_null(
			W.hook_of(W.hook_of(right, &"trigger_on_end").child, &"shared_explosive"),
			"%s: the child explodes where it ends" % weapon
		)


# --- What the cut changed besides the compile ----------------------------------------------------------------
func test_a_wand_card_right_of_a_trigger_brings_no_rider_but_a_v05_engine_still_does() -> void:
	var w := W.world(&"blade", [&"trigger_on_hit", &"ember_core"])
	assert_false(Modifiers.step(w, 0).has_status(&"burn"), "Fire right of ON HIT: no burn rider")
	var g := W.world(&"gun", [&"trigger_on_hit", &"frost_core"])
	assert_false(Modifiers.bolt(g).has_status(&"slow"), "Frost right of ON HIT: no slow rider")
	var v := W.world(&"blade", [&"trigger_on_hit", &"ember_core", &"wildfire"])
	assert_true(Modifiers.step(v, 0).has_status(&"burn"), "Wildfire (v0.5) still burns the slash")


func test_a_child_slash_feeds_only_its_own_statuses() -> void:
	var w := _scene(&"blade", [&"venom_core", &"trigger_on_hit"])
	_attack(w, &"blade", 6)
	assert_gt(W.damage(w, &"trigger_on_hit").size(), 0, "the child slash hits B")
	assert_gt(w.actors.poison_stacks[1], 0, "A, hit by the slash, is poisoned")
	assert_eq(w.actors.poison_stacks[2], 0, "B, hit by the plain child slash only, is not")


# --- The casts the views draw ----------------------------------------------------------------------------------
func test_each_trigger_cast_leaves_a_mark_where_it_fires() -> void:
	for weapon in WEAPONS:
		var w := _scene(weapon, [&"trigger_on_hit", &"shared_explosive"])
		_attack(w, weapon, 20)
		var casts := []
		var blasts := []
		for m: Dictionary in WandCasts.read(w):
			var s := Modifiers.book(w).find(m["key"])
			if m["cast"]:
				casts.append(m)
				assert_true(s.has_tag(WandCasts.TAG_CAST), "%s: a cast's spec is tagged" % weapon)
				assert_eq(s.depth, 1, "%s: the child spell" % weapon)
			elif s.form == FORM.BURST:
				blasts.append(m)
		assert_gt(casts.size(), 0, "%s: the child spell is cast" % weapon)
		assert_gt(blasts.size(), 0, "%s: and explodes where it ends" % weapon)
		if not casts.is_empty():
			var at: Vector2 = casts[0]["pos"]
			assert_lt(at.distance_to(w.actors.pos(1)), 0.7, "%s: cast at the hit" % weapon)


func test_the_marks_stay_bounded_and_out_of_the_hash() -> void:
	var w := W.world(&"gun", [&"trigger_on_end"])
	var h := w.state_hash()
	W.run(w, 400, 0, W.S)
	assert_lte(WandCasts.read(w).size(), WandCasts.MAX, "at most MAX marks")
	assert_gt(WandCasts.read(w).size(), 0)
	var copy := w.mx.cast_tick.duplicate()
	w.mx.cast_tick = PackedInt32Array()
	var before := w.state_hash()
	w.mx.cast_tick = copy
	assert_eq(w.state_hash(), before, "view data: not hashed")
	assert_ne(h, before)
