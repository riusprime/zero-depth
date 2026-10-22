extends GutTest
## v0.8.0 N12 (owner O70: "the loading screens still freeze the game … never stop moving or freezing";
## docs/roadmap/v0.8.0/evidence/LOADS_NO_FREEZE.md): the view's build queue. Its jobs run in order, a job's added
## follow-ups right after it, a worker job off the main thread while the frames go on, and a budget spreads them over
## frames. A floor's view built in slices (step, a few ms a frame, as a load does it) is the view built in one call
## (setup): the same nodes, in the same places, and the sim untouched.

var _log: Array[String] = []
## Engine-made names ("@MeshInstance3D@123") count up across the whole run: compared without their numbers.
var _auto := RegEx.create_from_string("@\\d+")


func _note(s: String) -> void:
	_log.append(s)


func test_jobs_run_in_order_with_follow_ups_right_after_their_job() -> void:
	_log.clear()
	var q := ViewBuildQueue.new()
	q.add("a", _note.bind("a"))
	q.add(
		"b",
		func() -> void:
			_note("b")
			q.add_next("b1", _note.bind("b1"))
			q.add_next("b2", _note.bind("b2"))
	)
	q.add("c", _note.bind("c"))
	q.run_all()
	assert_eq(_log, ["a", "b", "b1", "b2", "c"] as Array[String])
	assert_true(q.done())
	assert_true(q.ms.has("b1"), "each job timed")


func test_a_worker_job_runs_off_the_main_thread_and_the_next_job_waits_for_it() -> void:
	_log.clear()
	var main_id := OS.get_thread_caller_id()
	var seen := {"id": main_id}
	var q := ViewBuildQueue.new()
	q.add("a", _note.bind("a"))
	q.add_worker(
		"w",
		func() -> void:
			seen["id"] = OS.get_thread_caller_id()
			OS.delay_msec(30)
	)
	q.add("c", _note.bind("c"))
	var frames := 0
	while not q.step(4.0):
		frames += 1
		await get_tree().process_frame
		assert_lt(frames, 100000, "the queue finishes")
		if frames >= 100000:
			return
	assert_ne(seen["id"], main_id, "the worker job ran on another thread")
	assert_eq(_log, ["a", "c"] as Array[String])
	assert_gt(frames, 0, "and the frames went on while it ran")


func test_a_budget_spreads_the_jobs_over_frames() -> void:
	var q := ViewBuildQueue.new()
	for k in 6:
		q.add("slow", Callable(OS, "delay_msec").bind(5))
	var steps := 0
	while not q.step(4.0):
		steps += 1
	assert_eq(steps, 5, "one 5 ms job a frame against a 4 ms budget: six frames")
	assert_gte(q.longest_ms, 5.0)


func _paths(n: Node, base: Node, out: PackedStringArray) -> void:
	for c in n.get_children():
		var line := "%s %s" % [_auto.sub(str(base.get_path_to(c)), "@", true), c.get_class()]
		# v0.8.0 GX: the atmosphere's fog layer and dust follow whichever camera is current when they turn on, not the
		# floor, so only their place in the tree is compared.
		if (
			c is Node3D
			and not (c.get_parent() is StageAtmosphere and c.name in [&"FogLayer", &"Dust"])
		):
			line += " %s" % str((c as Node3D).transform)
		out.append(line)
		_paths(c, base, out)


func _view(biome: BiomeDefinition) -> WorldViewRoot:
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	v.stage.prop_style = biome.id
	v.stage.look = biome.look
	v.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(v)
	return v


func test_a_view_built_in_slices_is_the_view_built_in_one_call() -> void:
	var repo := ContentRepository.load_all()
	for c: Array in [[&"ruins", 7, 1], [&"night_rocks", 11, 2]]:
		var biome: BiomeDefinition = repo.get_def(&"biomes", c[0])
		var w := SaveLab.floor_world(c[1], c[2])
		var reader := WorldReader.new(w)
		var before := reader.state_hash()
		var one := _view(biome)
		one.setup(reader, biome.palette, 60.0)
		var sliced := _view(biome)
		var q := ViewBuildQueue.new()
		sliced.queue_setup(q, reader, biome.palette, 60.0)
		var frames := 0
		while not q.step(4.0):
			frames += 1
			await get_tree().process_frame
		assert_gt(frames, 3, "%s: the build took several frames" % c[0])
		var a := PackedStringArray()
		var b := PackedStringArray()
		_paths(one, one, a)
		_paths(sliced, sliced, b)
		assert_gt(a.size(), 100, "%s: a dressed floor" % c[0])
		assert_eq(b.size(), a.size(), "%s: the same number of nodes" % c[0])
		assert_eq(b, a, "%s: the same nodes, names and places" % c[0])
		assert_eq(reader.state_hash(), before, "%s: the sim untouched" % c[0])
		one.queue_free()
		sliced.queue_free()


## v0.8.0 LD (owner O70): a load makes the view's parts a few a frame (WorldViewRoot.prebuild) before the view; the
## view takes every one of them, and built from them it is the view made in one call.
func test_a_view_made_from_parts_made_ahead_is_the_same_view() -> void:
	var repo := ContentRepository.load_all()
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	var w := SaveLab.floor_world(7, 1)
	var reader := WorldReader.new(w)
	var one := _view(biome)
	one.setup(reader, biome.palette, 60.0)
	var slices := 1
	while not WorldViewRoot.prebuild(2.0):
		slices += 1
	assert_gt(slices, 1, "the parts are made over several slices")
	assert_eq(WorldViewRoot._made.size(), WorldViewRoot.parts.size(), "every part made ahead")
	var ahead := _view(biome)
	assert_eq(WorldViewRoot._made.size(), 0, "the view took every part made ahead")
	ahead.setup(reader, biome.palette, 60.0)
	var a := PackedStringArray()
	var b := PackedStringArray()
	_paths(one, one, a)
	_paths(ahead, ahead, b)
	assert_gt(a.size(), 100, "a dressed floor")
	assert_eq(b, a, "the same nodes, names and places")
	WorldViewRoot.drop_prebuilt()
	one.queue_free()
	ahead.queue_free()
