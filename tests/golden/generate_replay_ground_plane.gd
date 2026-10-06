extends SceneTree
## Regenerates tests/golden/fixtures/replay_ground_plane.json. On purpose only: name the change in PROGRESS
## ("Goldens changed on purpose") with the old and new final hash.
##   godot --headless --path . -s tests/golden/generate_replay_ground_plane.gd

const OUT := "res://tests/golden/fixtures/replay_ground_plane.json"


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var doc := ReplayRunner.run(20261006, 10000, 60)
	doc["hashes"] = Array(doc["hashes"])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t") + "\n")
	f.close()
	print(
		(
			"GOLD| final=%s checkpoints=%d (%d ms)"
			% [doc["final"], doc["hashes"].size(), Time.get_ticks_msec() - t0]
		)
	)
	quit(0)
