extends SceneTree
## v0.10.5 S7 (owner 2026-11-01: "10 to 15% more loot"): over many run seeds, the average free altars and chests on
## floors 1-3 (the real floor build, SaveLab.build_floor). Check only. Prints and writes build/reward_count.txt.
##   godot --headless --path . -s scripts/checks/reward_count.gd -- seeds=200

var seeds := 200


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2 and kv[0] == "seeds":
			seeds = int(kv[1])
	var repo := ContentRepository.load_all()
	var lines := PackedStringArray()
	for fl in [1, 2, 3]:
		var altars := 0
		var chests := 0
		var lo_a := 99
		var hi_a := 0
		var lo_c := 99
		var hi_c := 0
		for s in range(1, seeds + 1):
			var run := SaveLab.run_state(s, fl, &"blade", 0, repo)
			var w := SaveLab.build_floor(run, &"", repo)
			var a := 0
			var c := 0
			for i in w.rewards.ids.size():
				if w.rewards.kind[i] == RewardStore.Kind.ALTAR:
					a += 1
				elif w.rewards.kind[i] == RewardStore.Kind.CHEST:
					c += 1
			altars += a
			chests += c
			lo_a = mini(lo_a, a)
			hi_a = maxi(hi_a, a)
			lo_c = mini(lo_c, c)
			hi_c = maxi(hi_c, c)
		lines.append(
			(
				"floor %d: altars avg %.3f (%d..%d), chests avg %.3f (%d..%d), seeds=%d"
				% [fl, float(altars) / seeds, lo_a, hi_a, float(chests) / seeds, lo_c, hi_c, seeds]
			)
		)
	DirAccess.make_dir_recursive_absolute("res://build")
	var out := FileAccess.open("res://build/reward_count.txt", FileAccess.WRITE)
	for l in lines:
		print(l)
		out.store_line(l)
	quit(0)
