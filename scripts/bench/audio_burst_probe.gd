extends SceneTree
## The cost of a burst of sounds in one frame (the AudioDirector's play path): a director is booted as Main boots
## it, then N distinct world cues are played at once the first time any of them plays (a fight's first hit of each
## kind), then the same N again once they have ended, then 200 plays spread over cues and frames. Prints the time of
## each burst, the boot and warm-up time, and how many nodes the plays created. Headless runs on the Dummy audio
## driver: this times the director's own work (loading, nodes, players), not the mixing. Writes nothing.
##   godot --headless --path . -s scripts/bench/audio_burst_probe.gd [-- --n=48]

var _added := 0
var _done := false


## Runs on the first frame, when the root is in the tree (players only start inside it).
func _process(_delta: float) -> bool:
	if not _done:
		_done = true
		_run()
	return false


func _run() -> void:
	var args := ScriptArgs.parse()
	var n := int(args.get("--n", 48))
	node_added.connect(_on_node_added)
	var t0 := Time.get_ticks_usec()
	var d := AudioDirector.new()
	d.captions_forced = 0
	root.add_child(d)
	var boot_us := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	if d.has_method(&"finish_warm"):
		d.call(&"finish_warm")
	var warm_us := Time.get_ticks_usec() - t0
	var ids: Array[StringName] = []
	for id: StringName in d.cues:
		var c: AudioCueDefinition = d.cues[id]
		if c.kind == &"sfx" and c.bus == &"sfx":
			ids.append(id)
	ids.sort()
	ids.resize(mini(n, ids.size()))
	print("in tree: %s" % d.is_inside_tree())
	print("audio_burst_probe: %d cues, burst of %d sfx cues" % [d.cues.size(), ids.size()])
	print(
		(
			"boot (new + add_child) %.2f ms, warm-up finish %.2f ms"
			% [boot_us / 1000.0, warm_us / 1000.0]
		)
	)
	_burst(d, ids, "first plays")
	d.advance(5.0)
	_burst(d, ids, "again")
	d.advance(5.0)
	_added = 0
	var worst := 0
	var t_all := Time.get_ticks_usec()
	for k in 200:
		var ts := Time.get_ticks_usec()
		d.play(ids[k % ids.size()], Vector2(k % 7, k % 5))
		d.play(&"ui_move")
		worst = maxi(worst, Time.get_ticks_usec() - ts)
		d.advance(0.05)
	print(
		(
			"200 plays over 200 frames: %.2f ms in all, worst frame %.3f ms, nodes created %d"
			% [(Time.get_ticks_usec() - t_all) / 1000.0, worst / 1000.0, _added]
		)
	)
	d.free()
	quit(0)


func _burst(d: AudioDirector, ids: Array[StringName], label: String) -> void:
	_added = 0
	var t0 := Time.get_ticks_usec()
	var allowed := 0
	for k in ids.size():
		if d.play(ids[k], Vector2(k, -k)):
			allowed += 1
	var us := Time.get_ticks_usec() - t0
	print(
		(
			"burst (%s): %d played in one frame, %.2f ms, nodes created %d"
			% [label, allowed, us / 1000.0, _added]
		)
	)


func _on_node_added(_n: Node) -> void:
	_added += 1
