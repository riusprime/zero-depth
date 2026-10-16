extends GutTest
## v0.8.0 N1 (owner O53: "everytime I run a git pull it feels like I play the same run with same start, and same
## object … every run should run a random seed for it before the game starts"): every new run of the real game draws
## a fresh seed, the first run of a session too; a set seed (the tests', `--seed=N`) is honoured in order. Driven
## through main.tscn with Input.parse_input_event only (TEST_MATRIX T-E2E).


func after_each() -> void:
	Main.fixed_seed = RunSeeds.AUTO


## Pause -> Down (Build) -> Down (Restart run) -> Enter.
func _restart(e: E2e) -> void:
	await e.tap(KEY_ESCAPE)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_DOWN)
	await e.tap(KEY_ENTER)
	await e.frames(3)


func test_the_first_run_of_two_launches_differs() -> void:
	var seeds: Array[int] = []
	for launch in 2:
		var e := E2e.new(self)
		var main: Main = await e.boot(null, null, RunSeeds.RANDOM)
		await e.start_from_menu()
		await e.frames(3)
		assert_not_null(main.run, "launch %d: the run started" % launch)
		seeds.append(main.run.run_seed)
		main.queue_free()
		await e.frames(2)
	gut.p("first-run seeds of two launches: %s" % str(seeds))
	assert_ne(seeds[0], seeds[1], "each launch's first run has its own seed")
	for s in seeds:
		assert_between(s, 1, 0x7FFFFFFF, "a positive 31-bit seed")


func test_restart_and_the_next_run_draw_new_seeds() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, RunSeeds.RANDOM)
	await e.start_from_menu()
	await e.frames(3)
	var seeds: Array[int] = [main.run.run_seed]
	for k in 3:
		await _restart(e)
		assert_not_null(main.run, "restart %d: a run" % k)
		seeds.append(main.run.run_seed)
	gut.p("seeds of four runs in one launch: %s" % str(seeds))
	var unique := {}
	for s in seeds:
		unique[s] = true
	assert_eq(unique.size(), seeds.size(), "every new run has a new seed")


func test_a_set_seed_is_honoured_in_order() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot(null, null, 4242)
	await e.start_from_menu()
	await e.frames(3)
	assert_eq(main.run.run_seed, 4242, "the set seed starts the first run")
	await _restart(e)
	assert_eq(main.run.run_seed, 4243, "the next run takes the next seed")


func test_the_tests_keep_the_fixed_seed() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(3)
	assert_eq(main.run.run_seed, Main.STAGE_SEED, "E2e.boot keeps STAGE_SEED on purpose")


func test_a_tool_run_resolves_to_the_fixed_seed() -> void:
	assert_eq(
		RunSeeds.resolve(RunSeeds.AUTO, Main.STAGE_SEED),
		Main.STAGE_SEED,
		"godot -s (GUT, shots, checks) keeps STAGE_SEED"
	)
	assert_eq(RunSeeds.resolve(77, Main.STAGE_SEED), 77, "a set seed wins")
	assert_eq(RunSeeds.resolve(RunSeeds.RANDOM, Main.STAGE_SEED), RunSeeds.RANDOM)
	var fixed := RunSeeds.new(500)
	assert_eq([fixed.next(), fixed.next(), fixed.next()], [500, 501, 502], "a fixed order")
	var rnd := RunSeeds.new(RunSeeds.RANDOM)
	var seen := {}
	for k in 50:
		var s := rnd.next()
		assert_between(s, 1, 0x7FFFFFFF)
		seen[s] = true
	assert_eq(seen.size(), 50, "50 random seeds, all different")
