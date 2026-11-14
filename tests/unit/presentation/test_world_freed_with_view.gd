extends GutTest
## v0.10.5 W3-O14 (W3-O12's finding: each Effects-gallery page kept ~680 objects, ~80 MB, of Worlds whose views were
## gone): a World is freed with its view. The view's build queue (ViewBuildQueue) kept its jobs after they ran, and a
## job binds the queue itself (WorldViewRoot's pack warm-up, StageKit's kit) and the view's reader: a RefCounted cycle
## (queue -> job -> queue) that held the reader, so the whole World, after the view was freed. Built in one call
## (setup) and in slices (step, as a load builds a floor's view).


func _world() -> World:
	var repo := SharedContent.repo()
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	var w := PlaygroundScenario.build(repo, &"gun", biome, Vector2i(2, 2), false)
	w.step(InputFrame.new())
	return w


func _view() -> WorldViewRoot:
	var biome: BiomeDefinition = SharedContent.repo().get_def(&"biomes", &"ruins")
	var v := WorldViewRoot.new()
	v.stage.prop_style = biome.id
	v.stage.mood = biome.mood
	v.stage.look = biome.look
	add_child(v)
	return v


func _gone_after_free(v: WorldViewRoot, wr: WeakRef) -> bool:
	v.queue_free()
	for k in 4:
		await get_tree().process_frame
	return wr.get_ref() == null


func test_a_world_is_freed_with_its_view_built_in_one_call() -> void:
	var w := _world()
	var wr: WeakRef = weakref(w)
	var v := _view()
	var biome: BiomeDefinition = SharedContent.repo().get_def(&"biomes", &"ruins")
	v.setup(WorldReader.new(w), biome.palette, 12.0)
	v.sync()
	w = null
	assert_not_null(wr.get_ref(), "the view keeps its World while it lives")
	assert_true(await _gone_after_free(v, wr), "the World is freed with its view")


func test_a_world_is_freed_with_its_view_built_in_slices() -> void:
	var w := _world()
	var wr: WeakRef = weakref(w)
	var v := _view()
	var biome: BiomeDefinition = SharedContent.repo().get_def(&"biomes", &"ruins")
	var q := ViewBuildQueue.new()
	v.queue_setup(q, WorldReader.new(w), biome.palette, 12.0)
	var frames := 0
	while not q.step(8.0) and frames < 100000:
		frames += 1
		await get_tree().process_frame
	assert_true(q.done(), "the view is built (%d frames, %d jobs)" % [frames, q.size()])
	var jobs := q.size()
	assert_gt(jobs, 10, "the jobs are still counted once dropped")
	q = null
	w = null
	assert_true(await _gone_after_free(v, wr), "the World is freed with its view")


func test_a_finished_queue_drops_its_jobs() -> void:
	var q := ViewBuildQueue.new()
	var held := RefCounted.new()
	var wr: WeakRef = weakref(held)
	q.add("a", func() -> void: held.get_reference_count())
	q.add("b", (func(_x: ViewBuildQueue) -> void: pass).bind(q))
	held = null
	assert_not_null(wr.get_ref(), "a queued job holds what it binds")
	q.run_all()
	assert_true(q.done())
	assert_eq(q.size(), 2, "both jobs counted")
	assert_null(wr.get_ref(), "a job that ran is dropped, and what it held with it")
