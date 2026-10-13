extends GutTest
## v0.6.5 WN1 (docs/design/WAND.md "Order matters"): the slot order changes what happens in a fight, not only the
## compiled specs. The AttackScenario script (shooting, swings, a dash, the Skill, a vent, a walk) runs with the same
## cards in two orders; the events differ, each order replays exactly, and each trigger casts its child spell in the
## fight (its hits carry the trigger card's effect id). Mechanics only: no bot, no balance (owner P1).

const TICKS := 600


func _with_book(weapon: StringName, mods: Array) -> World:
	var w := WandLab.fight(weapon, [])
	var typed: Array[ModifierTable] = []
	for m: ModifierTable in mods:
		typed.append(m)
	w.attack_book = Modifiers.compile_for(w, typed)  # synthetic cards (WN3 ships Big Shot)
	return w


func test_big_split_and_split_big_fight_differently() -> void:
	var split := WandLab.card(&"split_shot")
	var a := WandLab.run(_with_book(&"gun", [WandLab.big(), split]), TICKS)
	var b := WandLab.run(_with_book(&"gun", [split, WandLab.big()]), TICKS)
	assert_ne(a["digest"], b["digest"], "Big·Split ≠ Split·Big in the fight's events")
	for r: Dictionary in [a, b]:
		assert_gt(
			int((r["hits_by_effect"] as Dictionary).get(&"split_shot", 0)), 0, "the splits land"
		)
	var again := WandLab.run(_with_book(&"gun", [WandLab.big(), split]), TICKS)
	assert_eq([again["digest"], again["hash"]], [a["digest"], a["hash"]], "replays")


func test_fire_on_hit_x_and_on_hit_fire_x_fight_differently() -> void:
	var first := [&"ember_core", &"trigger_on_hit", &"split_shot"]
	var second := [&"trigger_on_hit", &"ember_core", &"split_shot"]
	var wa := WandLab.fight(&"gun", first)
	var wb := WandLab.fight(&"gun", second)
	assert_true(Modifiers.bolt(wa).has_status(&"burn"), "Fire left of the trigger: the shot burns")
	assert_false(Modifiers.bolt(wb).has_status(&"burn"), "Fire right of it: the shot doesn't")
	var a := WandLab.run(wa, TICKS)
	var b := WandLab.run(wb, TICKS)
	assert_ne(a["digest"], b["digest"], "Fire·ON_HIT·X ≠ ON_HIT·Fire·X in the fight's events")
	for r: Dictionary in [a, b]:
		assert_gt(
			int((r["hits_by_effect"] as Dictionary).get(&"trigger_on_hit", 0)),
			0,
			"the child spell lands where hits land"
		)
	var again := WandLab.run(WandLab.fight(&"gun", second), TICKS)
	assert_eq([again["digest"], again["hash"]], [b["digest"], b["hash"]], "replays")


func test_every_trigger_casts_in_a_fight() -> void:
	for case: Array in [
		[&"gun", &"trigger_on_hit"],
		[&"gun", &"trigger_on_end"],
		[&"gun", &"trigger_on_finisher"],  # the Gun's crit (5 % base, the crit stream)
		[&"blade", &"trigger_on_hit"],
		[&"blade", &"trigger_on_kill"],
		[&"blade", &"trigger_on_end"],
		[&"blade", &"trigger_on_finisher"],  # the combo's last step
	]:
		var r := WandLab.run(WandLab.fight(case[0], [case[1]]), 900)
		assert_gt(
			int((r["hits_by_effect"] as Dictionary).get(case[1], 0)),
			0,
			"%s + %s: the child spell lands" % [case[0], case[1]]
		)


func test_a_trigger_child_hits_at_the_lower_proc_coefficient() -> void:
	var w := WandLab.fight(&"gun", [&"trigger_on_hit", &"trigger_on_kill"])
	var seen := 0
	var procs := {}
	for t in TICKS:
		w.step(AttackScenario.frame(t))
		for e in w.events_since(seen):
			seen = e.seq
			if e.kind == SimEvent.Kind.HIT and e.effect_id == &"trigger_on_hit":
				procs[e.proc_pct] = true
	assert_true(procs.has(50), "a trigger's child hits at proc 50 (depth 1)")
	assert_false(procs.has(100), "never at a root attack's 100")
