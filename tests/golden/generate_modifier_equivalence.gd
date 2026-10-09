extends SceneTree
## v0.6.0 MX1: regenerates tests/golden/fixtures/modifier_equivalence.json, the outcome digest of every
## AttackScenario case. Recorded once on the v0.5 attack code (before the modifier engine), so the equivalence test
## proves the engine changes no outcome. On purpose only, named in PROGRESS. v0.6.0 MX2 re-ran it: only blade_all and
## gun_all (the cases with abilities, which MX2 turned into weapon modifiers) changed.
##   godot --headless --path . -s tests/golden/generate_modifier_equivalence.gd

const OUT := "res://tests/golden/fixtures/modifier_equivalence.json"


func _initialize() -> void:
	var out := {}
	for c: Array in AttackScenario.CASES:
		var w := AttackScenario.world(c[1], c[2], c[3], c[4])
		var r := AttackScenario.run(w)
		out[c[0]] = r
		print(
			(
				"GOLD| %s %s hits=%d damage=%d kills=%d"
				% [c[0], r["digest"], r["hits"], r["damage"], r["kills"]]
			)
		)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", true) + "\n")
	f.close()
	quit(0)
