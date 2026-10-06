extends SceneTree
## Regenerates tests/golden/fixtures/export_smoke_hash.txt: the hash the export smoke expects after 600 ticks.
## On purpose only, named in PROGRESS.  godot --headless --path . -s tests/golden/generate_export_smoke_hash.gd

const OUT := "res://tests/golden/fixtures/export_smoke_hash.txt"


func _initialize() -> void:
	var w := KernelScenario.golden(1)
	var input := ScriptedInput.new(1)
	for t in 600:
		w.step(input.frame(t))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(w.state_hash() + "\n")
	f.close()
	print("GOLD| export_smoke_hash=", w.state_hash())
	quit(0)
