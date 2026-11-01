extends SceneTree
## v0.10.5 S15 (owner: "i've never seen in game a cracked wall"): over many run seeds, how many floors 1-3 hold a
## cracked wall (the real floor build: SaveLab.floor_world = Main's, with FloorPlan.add_secrets), and where it sits.
## Check only. Prints the report and writes build/cracked_wall_count.txt.
##   godot --headless --path . -s scripts/checks/cracked_wall_count.gd -- seeds=200

var seeds := 200


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2 and kv[0] == "seeds":
			seeds = int(kv[1])
	var repo := ContentRepository.load_all()
	var lines := PackedStringArray()
	var found := {}
	var first := {}
	var any := 0
	for fl in [1, 2, 3]:
		found[fl] = 0
	for s in range(1, seeds + 1):
		var had := false
		for fl in [1, 2, 3]:
			var run := SaveLab.run_state(s, fl, &"blade", 0, repo)
			var w := SaveLab.build_floor(run, &"", repo)
			var f := w.floor_layout
			if w.breakables == null or not w.breakables.has_crack():
				continue
			had = true
			found[fl] += 1
			if not first.has(fl):
				first[fl] = s
			var r := f.rooms[f.crack_room]
			var h := f.rooms[f.crack_host]
			(
				lines
				. append(
					(
						"seed %d floor %d: rooms=%d hidden room %d (%.0fx%.0f m) host %d, door at %s, doors in floor %d"
						% [
							s,
							fl,
							f.rooms.size(),
							f.crack_room,
							r.size.x,
							r.size.y,
							f.crack_host,
							str(f.door_centers[f.crack_door]),
							f.door_centers.size()
						]
					)
				)
			)
			h = h
		if had:
			any += 1
	lines.append("--- seeds=%d (floors 1-3 each)" % seeds)
	for fl in [1, 2, 3]:
		lines.append(
			(
				"floor %d: %d / %d floors with a cracked wall (%.1f %%), first seed %s"
				% [fl, found[fl], seeds, 100.0 * found[fl] / seeds, str(first.get(fl, "-"))]
			)
		)
	lines.append("seeds with one on any of floors 1-3: %d / %d" % [any, seeds])
	DirAccess.make_dir_recursive_absolute("res://build")
	var out := FileAccess.open("res://build/cracked_wall_count.txt", FileAccess.WRITE)
	for l in lines:
		print(l)
		out.store_line(l)
	quit(0)
