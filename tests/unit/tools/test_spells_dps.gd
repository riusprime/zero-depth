extends GutTest
## v0.11.0 O12: scripts/balance/spells_dps.gd runs (a short window): a spell next to the plain orbs deals damage, the
## orbs too, and the same numbers come back on a second run (seeded, deterministic). O12b: the wand-only column leaves
## out the element cards' own damage (Storm Core's jumps), and the moving and dying scenes run the same twice (the
## dying stream kills).

const SCRIPT := preload("res://scripts/balance/spells_dps.gd")


func test_the_spells_dps_script_measures_a_spell_and_the_wand_the_same_twice() -> void:
	var s: Object = SCRIPT.new()
	s.set("_window", 120)
	var at: Array = SCRIPT._far()["single"]
	var a: Array = s.call("_measure", "orbs", [Spells.FIREBALL], 1, [at])
	var b: Array = s.call("_measure", "orbs", [Spells.FIREBALL], 1, [at])
	s.free()
	assert_gt(a[0], 0, "the Fireball hits")
	assert_gt(a[1], 0, "the orbs hit")
	assert_eq(a, b, "deterministic")


func test_wand_only_leaves_out_storm_cores_jumps() -> void:
	var s: Object = SCRIPT.new()
	s.set("_window", 240)
	var at: Array = SCRIPT._far()["line"]
	var r: Array = s.call("_measure", "orbs", [Spells.SKY_STRIKE], 1, [at])
	s.free()
	assert_gt(r[1], r[2], "Storm Core's jumps are in wand all, not in wand only")
	assert_gt(r[2], 0, "the orbs' own hits stay in wand only")


func test_the_moving_and_dying_scenes_run_the_same_twice() -> void:
	var s: Object = SCRIPT.new()
	s.set("_window", 600)
	var dyn: Dictionary = SCRIPT._new_scenes("orbs")
	var m1: Array = s.call("_measure", "orbs", [Spells.FIREBALL], 1, dyn["moving"])
	var m2: Array = s.call("_measure", "orbs", [Spells.FIREBALL], 1, dyn["moving"])
	var d1: Array = s.call("_measure", "orbs", [Spells.FIREBALL], 1, dyn["dying"])
	var d2: Array = s.call("_measure", "orbs", [Spells.FIREBALL], 1, dyn["dying"])
	s.free()
	assert_gt(m1[2], 0, "the orbs hit the moving pack")
	assert_eq(m1, m2, "moving: deterministic")
	assert_gt(d1[3], 0, "the dying stream's dummies die")
	assert_eq(d1, d2, "dying: deterministic")
