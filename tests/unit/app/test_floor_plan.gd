extends GutTest
## v0.8.0 N12 (owner O70: "the loading screens still freeze the game … never stop moving or freezing";
## docs/roadmap/v0.8.0/evidence/LOADS_NO_FREEZE.md): a floor built on a WorkerThreadPool task behind the loading cover
## (FloorPlan.build, as Main runs it) is the floor the main thread builds from the same inputs: the same state hash
## when built and after two seconds of ticks, for several run seeds, both builds, a later floor and the last floor.

const TICKS := 120


func _plan(seed_value: int, build: StringName) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.mode = FloorPlan.Mode.NEW_RUN
	plan.stage_seed = seed_value
	plan.build_id = build
	return plan


## The run's floor `floor_index` of a run started from `seed_value` (FLOOR mode, as a portal builds it).
func _floor_plan(seed_value: int, floor_index: int) -> FloorPlan:
	var first := _plan(seed_value, &"gun")
	first.build()
	var plan := FloorPlan.new()
	plan.repo = first.repo
	plan.run = first.run
	plan.run_biomes = first.run_biomes
	plan.run.floor_index = floor_index
	return plan


func _on_worker(plan: FloorPlan) -> void:
	var id := WorkerThreadPool.add_task(plan.build, true, "test_floor_plan")
	while not WorkerThreadPool.is_task_completed(id):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(id)


func _hashes(w: World) -> Array[String]:
	var out: Array[String] = [w.state_hash()]
	for k in TICKS:
		w.step(InputFrame.new())
	out.append(w.state_hash())
	return out


func test_a_new_run_built_on_a_worker_is_the_main_thread_build() -> void:
	for c: Array in [[20261006, &"blade"], [7, &"gun"], [424242, &"blade"]]:
		var main_plan := _plan(c[0], c[1])
		main_plan.build()
		var threaded := _plan(c[0], c[1])
		await _on_worker(threaded)
		assert_eq(threaded.err, "", "seed %d built" % c[0])
		assert_not_null(threaded.world, "seed %d has a world" % c[0])
		if threaded.world == null:
			continue
		assert_eq(threaded.run_biomes, main_plan.run_biomes, "seed %d: the same biome order" % c[0])
		assert_eq(
			_hashes(threaded.world),
			_hashes(main_plan.world),
			"seed %d: the same world, built and stepped" % c[0]
		)


func test_a_later_floor_and_the_last_floor_built_on_a_worker_are_the_main_thread_builds() -> void:
	for floor_index in [2, 3]:
		var main_plan := _floor_plan(31337, floor_index)
		main_plan.build()
		var threaded := _floor_plan(31337, floor_index)
		await _on_worker(threaded)
		assert_not_null(threaded.world, "floor %d has a world" % floor_index)
		if threaded.world == null:
			continue
		assert_eq(threaded.world.floor_index, floor_index)
		assert_eq(
			_hashes(threaded.world),
			_hashes(main_plan.world),
			"floor %d: the same world" % floor_index
		)
