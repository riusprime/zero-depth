extends GutTest
## v0.11.0 O12: scripts/balance/spells_dps.gd runs (a short window): a spell next to the plain orbs deals damage, the
## orbs too, and the same numbers come back on a second run (seeded, deterministic).

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
