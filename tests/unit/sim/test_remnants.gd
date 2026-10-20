extends GutTest
## v0.8.0 RM (owner O91: "Expand interactions through reusable mechanics … Build reusable remnants, connections and
## events—not hardcoded modifier-pair scripts. Define inheritance, lifetimes, hit intervals and activation limits";
## docs/roadmap/v0.8.0/BALANCE_PASS.md "RM"): the remnant store (Remnants) and each card's rule. The store's caps (each
## card's, per kind, in all; the oldest replaced), lifetimes, hit gaps, charges, the activation cap and its one LIMIT
## event, the lineage and depth guards; Threadline, Faultline, Gravity Stitch, Stress Mark, Fracture Bank, Double
## Exposure, Grand Finale (left of it, same trigger section), Dodge Imprint; determinism and a snapshot taken while
## remnants stand. Mechanics only: no bot, no balance (owner P1).

const W := preload("res://tests/support/mx4_world.gd")
const K := RemnantRule.Kind
const A := RemnantRule.Activate


func _hook(s: AttackSpec, id: StringName) -> AttackHook:
	return W.hook_of(s, id)


func _ctx(w: World, at: Vector2, angle: int, dmg: int, depth: int = 0) -> AttackContext:
	var c := AttackContext.make(at, angle, dmg, w.take_root(), SimEvent.TAG_MELEE, &"")
	c.depth = depth
	c.proc_pct = maxi(1, 100 >> depth)
	return c


## The events of `kind` whose effect is `card`, since the log began.
func _ev(w: World, kind: int, card: StringName) -> Array[SimEvent]:
	return W.events(w, kind, card)


# --- The cards compile into remnant hooks ---------------------------------------------------------------------------
func test_each_card_compiles_a_remnant_hook_with_its_rule() -> void:
	var gun := W.world(&"gun", [&"gun_threadline", &"shared_faultline", &"shared_gravity_stitch"])
	var bolt := Modifiers.bolt(gun)
	var thread := _hook(bolt, &"gun_threadline")
	assert_not_null(thread, "Threadline rides the bolt")
	assert_eq(
		[thread.trigger, thread.remnant.kind, thread.remnant.spawn, thread.remnant.activate],
		[AttackSpec.Trigger.ON_REMNANT, K.SEGMENT, RemnantRule.Spawn.LINK, A.ENEMY_CROSS]
	)
	assert_eq(
		[thread.remnant.life_ticks, thread.remnant.max_alive, thread.remnant.gap_ticks], [30, 6, 15]
	)
	assert_eq(thread.damage_permille, 250, "25 % of a bolt")
	var crack := _hook(bolt, &"shared_faultline")
	assert_eq([crack.trigger, crack.remnant.kind], [AttackSpec.Trigger.ON_HIT, K.SEGMENT])
	assert_eq([crack.remnant.life_ticks, crack.remnant.charges], [180, 1])
	assert_almost_eq(crack.child.radius_m, 1.2, 0.001, "a 1.2 m eruption")
	var anchor := _hook(bolt, &"shared_gravity_stitch")
	assert_eq([anchor.remnant.kind, anchor.remnant.activate], [K.ANCHOR, A.PULL])
	assert_eq([anchor.remnant.life_ticks, anchor.remnant.max_alive], [72, 4])
	assert_eq([thread.slot, crack.slot, anchor.slot], [0, 1, 2], "their wand slots")
	assert_eq([thread.section, crack.section, anchor.section], [0, 0, 0], "no trigger: one section")


func test_levels_grow_caps_lives_and_shares() -> void:
	var w := W.world(&"gun", [&"gun_threadline", &"shared_faultline", &"shared_gravity_stitch"])
	for id: StringName in [&"gun_threadline", &"shared_faultline", &"shared_gravity_stitch"]:
		Offers.apply(w, W.item(w, id))
		Offers.apply(w, W.item(w, id))
	var bolt := Modifiers.bolt(w)
	assert_eq(_hook(bolt, &"gun_threadline").remnant.max_alive, 10, "level 3: 6 + 2 + 2 threads")
	assert_eq(_hook(bolt, &"shared_faultline").remnant.max_alive, 8, "level 3: 6 + 1 + 1 cracks")
	assert_eq(_hook(bolt, &"shared_faultline").damage_permille, 1000, "80 % + 10 % a level")
	var st := _hook(bolt, &"shared_gravity_stitch").remnant
	assert_eq([st.life_ticks, st.max_alive], [72 + 36, 6], "+0.3 s and +1 anchor a level")


func test_fracture_bank_lodges_on_combo_steps_and_extracts_on_the_finisher() -> void:
	var w := W.world(&"blade", [&"finisher_plus"])
	var n := w.player.combo.size()
	for k in n:
		var h := _hook(Modifiers.step(w, k), &"finisher_plus")
		assert_not_null(h, "step %d carries it" % k)
		assert_eq(h.extract, k == n - 1, "step %d: only the finisher extracts" % k)
		assert_eq(h.remnant.kind, K.FRAGMENT)
		assert_eq(h.damage_permille, 400, "40 % a fragment")
	assert_eq(_hook(Modifiers.step(w, 0), &"finisher_plus").remnant.stack_max, 4)


func test_the_cards_to_the_right_shape_the_cast() -> void:
	var w := W.world(&"blade", [&"shared_faultline"])
	var mods: Array[ModifierTable] = [WandLab.card(&"shared_faultline"), WandLab.big()]
	var b := Modifiers.compile_for(w, mods)
	var k := _hook(b.spec(Modifiers.step_id(0)), &"shared_faultline")
	assert_almost_eq(k.child.radius_m, 2.4, 0.001, "Big right of it doubles the eruption")
	var left: Array[ModifierTable] = [WandLab.big(), WandLab.card(&"shared_faultline")]
	var k2 := _hook(Modifiers.compile_for(w, left).spec(Modifiers.step_id(0)), &"shared_faultline")
	assert_almost_eq(k2.child.radius_m, 1.2, 0.001, "left of it, Big doesn't reach the cast")
	assert_null(_hook(k.child, &"shared_faultline"), "lineage: its cast never leaves a crack")


# --- The store --------------------------------------------------------------------------------------------------------
func test_each_card_cap_replaces_the_oldest() -> void:
	var w := W.world(&"blade", [&"shared_faultline"], [[Vector2(2.0, 0.0), 100000]])
	var k := _hook(Modifiers.step(w, 0), &"shared_faultline")
	var first := -1
	for n in 7:
		Remnants.on_hook(w, k, _ctx(w, Vector2.ZERO, 0, 10), Vector2(2.0, 0.1 * n), 1)
		if n == 0:
			first = w.mx.rem_uid[0]
	assert_eq(w.mx.rem_uid.size(), 6, "6 cracks at most")
	assert_false(w.mx.rem_uid.has(first), "the oldest was replaced")
	var ends := _ev(w, SimEvent.Kind.REMNANT_END, &"shared_faultline")
	assert_eq(ends.size(), 1)
	assert_eq(ends[0].amount, Remnants.END_REPLACED)
	assert_eq(_ev(w, SimEvent.Kind.REMNANT_SPAWN, &"shared_faultline").size(), 7)


func test_the_kind_cap_and_the_total_cap_hold() -> void:
	var w := W.world(&"blade", [&"shared_faultline"], [[Vector2(2.0, 0.0), 100000]])
	w.wand_table = WandTable.new()
	w.wand_table.remnant_kind_max = PackedInt32Array([3, 16, 48, 48])
	var k := _hook(Modifiers.step(w, 0), &"shared_faultline")
	for n in 5:
		Remnants.on_hook(w, k, _ctx(w, Vector2.ZERO, 0, 10), Vector2(2.0, 0.1 * n), 1)
	assert_eq(w.mx.rem_uid.size(), 3, "3 segments at most")
	w.wand_table.remnant_kind_max = PackedInt32Array([48, 16, 48, 48])
	w.wand_table.remnant_max = 2
	Remnants.on_hook(w, k, _ctx(w, Vector2.ZERO, 0, 10), Vector2(2.0, 1.0), 1)
	assert_eq(w.mx.rem_uid.size(), 2, "2 in all")


func test_a_remnant_lasts_its_life() -> void:
	var w := W.world(&"blade", [&"shared_faultline"], [[Vector2(2.0, 0.0), 100000]])
	var k := _hook(Modifiers.step(w, 0), &"shared_faultline")
	Remnants.on_hook(w, k, _ctx(w, Vector2.ZERO, 0, 10), Vector2(2.0, 0.0), 1)
	W.run(w, 180)
	assert_eq(w.mx.rem_uid.size(), 1, "3 s: 180 ticks")
	W.run(w, 1)
	assert_eq(w.mx.rem_uid.size(), 0)
	var ends := _ev(w, SimEvent.Kind.REMNANT_END, &"shared_faultline")
	assert_eq(ends[ends.size() - 1].amount, Remnants.END_EXPIRED)


func test_a_thread_hits_an_enemy_once_each_gap() -> void:
	var w := W.world(&"gun", [&"gun_threadline"], [[Vector2(3.0, 0.0), 100000]])
	var k := Remnants.link_of(Modifiers.bolt(w))
	var n := Remnants._add(w, k, Remnants._ctx_of(w, k, w.take_root(), 20), 20)
	Remnants._set_line(w, n, Vector2(3.0, -1.0), Vector2(3.0, 1.0), 1024)
	W.run(w, 40)
	var hits := W.damage(w, &"gun_threadline")
	assert_eq(hits.size(), 2, "0.5 s across the enemy, once each 0.25 s: twice")
	assert_eq(hits[0].amount, 5, "25 % of the bolt's 20")
	assert_eq(_ev(w, SimEvent.Kind.REMNANT_ACTIVATE, &"gun_threadline").size(), 2)
	assert_eq(w.mx.gap_uid.size(), 0, "its gaps went with it")


func test_the_activation_cap_leaves_one_limit_event() -> void:
	var w := W.world(&"gun", [&"gun_threadline"])
	w.wand_table = WandTable.new()
	w.wand_table.remnant_activations_max = 2
	assert_true(Remnants._room(w))
	assert_true(Remnants._room(w))
	assert_false(Remnants._room(w), "the third this tick doesn't fit")
	assert_false(Remnants._room(w))
	var lim := W.events(w, SimEvent.Kind.LIMIT, Remnants.EFFECT_LIMIT)
	assert_eq(lim.size(), 1, "one LIMIT event")
	assert_eq(lim[0].amount, 2, "naming the cap")
	W.run(w, 1)
	assert_true(Remnants._room(w), "the next tick starts again")


func test_the_lineage_and_depth_guards() -> void:
	var w := W.world(&"blade", [&"shared_faultline"], [[Vector2(2.0, 0.0), 100000]])
	var k := _hook(Modifiers.step(w, 0), &"shared_faultline")
	Remnants.on_hook(w, k, _ctx(w, Vector2.ZERO, 0, 10, 2), Vector2(2.0, 0.0), 1)
	assert_eq(w.mx.rem_uid.size(), 0, "an attack at the deepest level leaves none")
	w.hook_chain.append("shared_faultline")
	Remnants.on_hook(w, k, _ctx(w, Vector2.ZERO, 0, 10), Vector2(2.0, 0.0), 1)
	w.hook_chain.clear()
	assert_eq(w.mx.rem_uid.size(), 0, "its own cast never leaves the same remnant")
	Remnants.on_hook(w, k, _ctx(w, Vector2.ZERO, 0, 10, 1), Vector2(2.0, 0.0), 1)
	assert_eq(w.mx.rem_uid.size(), 1)
	assert_eq(w.mx.rem_depth[0], 2, "its activation is a child: one level deeper")
	assert_eq(w.mx.rem_proc[0], 25, "at half the proc")
