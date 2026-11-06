extends SceneTree
## v0.10.5 O7a (P6): shards a minute from a steady 1 kill/s of a Charger on each floor, minutes 1-8, with the
## shard tier capped at the peak (shipped) and uncapped. Writes build/shard_taper.txt.
##   godot --headless --path . -s scripts/checks/shard_taper.gd


func _initialize() -> void:
	var out := PackedStringArray()
	var repo := ContentRepository.load_all()
	for floor_n in [1, 2]:
		var lab := RunLab.new(repo, 78, &"gun")
		lab.run.floor_index = floor_n
		var w := lab.floor_world()
		var c := w.spawner.curve
		out.append("floor %d peak tick %d" % [floor_n, c.starts[c.phase_count() - 1]])
		for capped in [false, true]:
			w.reward_table.shard_tier_caps_at_peak = capped
			var row := PackedStringArray()
			for minute in range(8):
				var sum := 0
				for s in range(60):
					w.run_ticks = (minute * 60 + s) * 60
					sum += Rewards.shards_for_kill(w, ActorStore.Kind.CHARGER)
				row.append(str(sum))
			out.append("  %s: %s" % ["after " if capped else "before", " ".join(row)])
	DirAccess.make_dir_recursive_absolute("res://build")
	var f := FileAccess.open("res://build/shard_taper.txt", FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	print("\n".join(out))
	quit()
