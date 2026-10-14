extends GutTest
## v0.6.5 WN4 (docs/design/WAND.md, the Blade pool B1–B16; owner W5: "the slash becomes a spell"): each Blade card
## rewrites the slash's spec the way its row says, and the change shows in a scripted Blade fight (AttackScenario: a
## melee press every 9 ticks, a dash every 97, dummies that move and shoot). Mechanics only: no bot, no balance (P1).

const TICKS := 600
const MOTION := SwingStep.Motion


## The fight's counts: the player's HITs by effect id, their total and the damage dealt, and the most of what
## BladeForms.read showed at once (cut shots, pushed enemies, orbiting blades, fissure cracks) and the marks by kind.
func _run(w: World, ticks: int = TICKS) -> Dictionary:
	var seen := 0
	var effects := {}
	var hits := 0
	var dealt := 0
	var most := {"knocked": 0, "blades": 0, "cracks": 0}
	var marks := {}
	var pid := w.actors.ids[0]
	for t in ticks:
		w.step(AttackScenario.frame(t))
		for e in w.events_since(seen):
			seen = e.seq
			if e.owner_id != pid or e.target_id == pid:
				continue
			if e.kind == SimEvent.Kind.HIT:
				hits += 1
				effects[e.effect_id] = int(effects.get(e.effect_id, 0)) + 1
			elif e.kind == SimEvent.Kind.DAMAGE:
				dealt += e.amount_applied
		var r := BladeForms.read(w)
		most["knocked"] = maxi(most["knocked"], r["knocked"])
		most["blades"] = maxi(most["blades"], (r["blades"] as PackedVector2Array).size())
		most["cracks"] = maxi(most["cracks"], (r["cracks"] as Array).size())
		for f: Dictionary in r["fx"]:
			marks["%d/%d" % [f["kind"], f["tick"]]] = f["kind"]
	var by_kind := {}
	for k: int in marks.values():
		by_kind[k] = int(by_kind.get(k, 0)) + 1
	return {
		"effects": effects,
		"hits": hits,
		"dealt": dealt,
		"most": most,
		"marks": by_kind,
		"parried": w.blade.parried,
		"hash": w.state_hash(),
	}


func _fight(ids: Array) -> World:
	return WandLab.fight(&"blade", ids)


func _step(w: World, k: int = 0) -> AttackSpec:
	return Modifiers.step(w, k)


func _hook(s: AttackSpec, id: StringName) -> AttackHook:
	for k in s.hooks:
		if k.id == id:
			return k
	return null


func _units(deg: float) -> int:
	return ContentCompiler.degrees_to_units(deg)


# --- B1–B16: the rewrite and its effect in the fight -------------------------------------------------------------
func test_b1_wide_arc_sweeps_wider_and_farther() -> void:
	var plain := _fight([])
	var w := _fight([&"wide_arc"])
	assert_eq(
		_step(w).half_arc, _step(plain).half_arc + _units(30.0), "+60° of arc (half each side)"
	)
	assert_eq(_step(w).reach_bonus_permille, 300, "+30 % reach")
	assert_almost_eq(
		Attacks.arc_reach_m(w, _step(w)), Attacks.arc_reach_m(plain, _step(plain)) * 1.3, 0.001
	)
	assert_eq(
		Modifiers.bolt(w).radius_m, Modifiers.bolt(plain).radius_m, "Blade-only now: the bolt stays"
	)
	assert_gt(_run(w)["hits"], _run(plain)["hits"], "a huge sweep hits more")


func test_b2_wave_throws_a_flying_crescent() -> void:
	var w := _fight([&"echo_slash"])
	var k := _hook(_step(w), &"echo_slash")
	assert_not_null(k, "the slash casts a crescent as it launches")
	assert_eq(k.child.form, AttackSpec.Form.BOLT)
	assert_true(k.child.has_tag(&"wave"), "a flying slash (Split Wave's target)")
	assert_eq(k.child.half_arc, _step(w).half_arc, "as wide as the arc")
	assert_gt(int(_run(w)["effects"].get(&"echo_slash", 0)), 0, "the crescents land")


func test_b3_split_wave_needs_a_flying_slash_and_splits_it() -> void:
	var alone := _fight([&"split_wave"])
	assert_null(_hook(_step(alone), &"split_wave"), "no flying slash: nothing to split")
	var w := _fight([&"echo_slash", &"split_wave"])
	var crescent := _hook(_step(w), &"echo_slash").child
	var split := _hook(crescent, &"split_wave")
	assert_not_null(split, "the crescent splits on hit")
	assert_eq(split.trigger, AttackSpec.Trigger.ON_HIT)
	assert_eq(split.child.count, 3, "into 3")
	assert_gt(split.child.half_arc, 0, "small crescents")
	assert_lt(split.child.radius_m, crescent.radius_m)
	assert_gt(int(_run(w)["effects"].get(&"split_wave", 0)), 0, "the small crescents land")


func test_b4_whirl_spins_every_slash() -> void:
	var plain := _fight([])
	var w := _fight([&"whirl"])
	for k in w.player.combo.size():
		assert_eq(_step(w, k).directions, AttackSpec.DIR_CIRCLE, "step %d: all round" % k)
		assert_eq(_step(w, k).half_arc, SpecForms.FULL_HALF_ARC)
		assert_eq(BladeForms.step(w, k).motion, MOTION.SPIN, "step %d: the swing is a spin" % k)
	assert_eq(BladeForms.step(plain, 0).motion, MOTION.SLASH_RIGHT_TO_LEFT)
	assert_gt(_run(w)["hits"], _run(plain)["hits"], "a full spin hits all round")


func test_b5_double_slash_repeats_mirrored() -> void:
	var w := _fight([&"double_slash"])
	assert_eq(_step(w).repeat_delay_ticks, 9, "0.15 s later")
	assert_eq(_step(w).repeat_damage_permille, 700, "v0.8.0 BL (B1): each repeat 70 %")
	assert_eq(_step(w).repeats, 1, "level 1: one repeat (B1: +1 a level, test_blade_combos.gd)")
	assert_eq(_step(w).echo_mirror, 1, "mirrored")
	var r := _run(w)
	assert_gt(int(r["effects"].get(ItemEffects.EFFECT_TWIN_ARC, 0)), 0, "the repeat lands")
	assert_gt(int(r["marks"].get(BladeForms.FX_ARC_MIRROR, 0)), 0, "the view's criss-cross")


func test_b6_thrust_is_a_long_narrow_stab() -> void:
	var plain := _fight([])
	var w := _fight([&"thrust"])
	assert_almost_eq(_step(w).reach_m, _step(plain).reach_m * 2.0, 0.001, "reach × 2")
	assert_eq(_step(w).half_arc, _step(plain).half_arc * 400 / 1000, "arc × 0.4")
	assert_eq(_step(w).damage, _step(plain).damage * 1300 / 1000, "+30 % damage")
	assert_eq(BladeForms.step(w, 0).motion, MOTION.THRUST, "the swing is a stab")
	assert_gt(_run(w)["hits"], 0, "the stab lands")


func test_b7_heavy_is_slow_and_crushing() -> void:
	var plain := _fight([])
	var w := _fight([&"heavy"])
	assert_eq(_step(w).damage, _step(plain).damage * 1700 / 1000, "× 1.7 damage")
	assert_gt(BladeForms.step(w, 0).ticks, BladeForms.step(plain, 0).ticks, "a slower swing")
	assert_almost_eq(_step(w).knockback_m, 1.5, 0.001)
	var r := _run(w)
	assert_gt(r["most"]["knocked"], 0, "the hits knock enemies back")
	var r0 := _run(plain)
	assert_gt(
		float(r["dealt"]) / maxi(1, r["hits"]),
		float(r0["dealt"]) / maxi(1, r0["hits"]),
		"heavier hits"
	)


func test_b8_flurry_swings_faster_for_less() -> void:
	var plain := _fight([])
	var w := _fight([&"flurry"])
	assert_lt(BladeForms.step(w, 0).ticks, BladeForms.step(plain, 0).ticks, "a faster swing")
	assert_eq(_step(w).damage, _step(plain).damage * 750 / 1000, "−25 % damage")
	assert_gt(_run(w)["hits"], _run(plain)["hits"], "more slashes land")


func test_b9_fissure_cracks_then_erupts_in_a_line() -> void:
	var w := _fight([&"fissure"])
	var k := _hook(_step(w), &"fissure")
	assert_not_null(k)
	assert_eq(k.trigger, AttackSpec.Trigger.ON_END, "from where the slash ends")
	assert_eq(k.delay_ticks, 18, "the crack waits 0.3 s")
	assert_almost_eq(k.child.line_m, 4.0, 0.001, "a 4 m line")
	var r := _run(w)
	assert_gt(r["most"]["cracks"], 0, "the crack shows before it erupts")
	assert_gt(int(r["marks"].get(BladeForms.FX_LINE, 0)), 0, "the eruption")
	assert_gt(int(r["effects"].get(&"fissure", 0)), 0, "the line hits")


func test_b10_chain_cut_leaps_to_the_next_enemy() -> void:
	var w := _fight([&"chain_cut"])
	var k := _hook(_step(w), &"chain_cut")
	assert_eq(k.child.form, AttackSpec.Form.BEAM)
	assert_true(k.child.seek, "a jump to the nearest other enemy")
	assert_almost_eq(k.child.reach_m, 4.0, 0.001, "within 4 m")
	assert_gt(int(_run(w)["effects"].get(&"chain_cut", 0)), 0, "the cut jumps")


func test_b11_parry_edge_cuts_enemy_shots() -> void:
	var plain := _fight([])
	var w := _fight([&"parry_edge"])
	assert_eq(_step(w).parry, 1)
	assert_eq(_run(plain)["parried"], 0)
	var r := _run(w, 900)
	assert_gt(r["parried"], 0, "the slashes cut the dummies' shots")
	assert_gt(int(r["marks"].get(BladeForms.FX_PARRY, 0)), 0, "sparks where they were cut")


func test_b12_afterimage_repeats_the_last_slash_on_a_dash() -> void:
	var w := _fight([&"long_shadow"])
	var k := _hook(Modifiers.dash(w), &"long_shadow")
	assert_not_null(k, "the dash leaves a copy")
	assert_eq(k.child.form, AttackSpec.Form.WEAPON, "of your last slash")
	var r := _run(w)
	assert_gt(int(r["effects"].get(&"long_shadow", 0)), 0, "the ghost slash lands")
	assert_gt(int(r["marks"].get(BladeForms.FX_ARC, 0)), 0, "the view's ghost slash")


func test_b13_lunge_step_drives_you_forward() -> void:
	var still := func(t: int) -> InputFrame:
		return InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY if t == 0 else 0)
	var moved := []
	for ids: Array in [[], [&"lunge_step"]]:
		var w := _fight(ids)
		var from := w.player_pos()
		for t in 20:
			w.step(still.call(t))
		moved.append(Kin.length(w.player_pos() - from))
	assert_almost_eq(float(moved[1]) - float(moved[0]), 1.0, 0.05, "1 m farther per slash")
	assert_almost_eq(_step(_fight([&"lunge_step"])).step_m, 1.0, 0.001)


func test_b14_finisher_plus_shockwave_carries_every_card() -> void:
	var w := _fight([&"finisher_plus", &"ember_edge"])
	var last := w.player.combo.size() - 1
	assert_null(_hook(_step(w, 0), &"finisher_plus"), "only the 4th hit")
	var k := _hook(_step(w, last), &"finisher_plus")
	assert_not_null(k, "the finisher's shockwave")
	assert_eq(k.child.form, AttackSpec.Form.BURST)
	assert_almost_eq(k.child.radius_m, 3.0, 0.001, "a big one")
	assert_eq(k.damage_permille, 2000, "doubled")
	assert_true(
		k.child.has_status(&"burn"),
		"Ember Edge sits right of it and still burns the shockwave (carry)"
	)
	assert_gt(int(_run(w)["effects"].get(&"finisher_plus", 0)), 0, "the shockwave lands")


func test_b15_orbit_blades_circle_you() -> void:
	var w := _fight([&"blade_orbit"])
	var k := _hook(_step(w), &"blade_orbit")
	assert_eq(k.child.form, AttackSpec.Form.ORBITER)
	assert_eq(k.child.orbit_ticks, 180, "for 3 s")
	var r := _run(w)
	assert_gt(r["most"]["blades"], 1, "blades orbit you")
	assert_lte(r["most"]["blades"], w.blade_table.orbit_max)
	assert_gt(int(r["effects"].get(&"blade_orbit", 0)), 0, "they hit")


func test_b16_counter_after_a_dash_doubles_and_flies() -> void:
	var w := _fight([&"counter"])
	assert_eq(_step(w).counter_ticks, 30, "0.5 s")
	assert_eq(_step(w).counter_permille, 2000)
	var k := _hook(_step(w), &"counter")
	assert_eq(k.when, AttackHook.WHEN_COUNTER, "the wave only on a counter")
	assert_true(k.child.has_tag(&"wave"))
	var r := _run(w)
	assert_gt(int(r["effects"].get(&"counter", 0)), 0, "a dash, a slash: the wave lands")
	assert_gt(int(r["marks"].get(BladeForms.FX_COUNTER, 0)), 0, "the counter's flash")
	var plain := _fight([])
	assert_eq(int(_run(plain)["effects"].get(&"counter", 0)), 0)
