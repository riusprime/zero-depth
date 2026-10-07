class_name FightLab
extends RefCounted
## Real run floors for the readable-cause check (v0.3.0 O). A floor is
## built the way Main builds one (the run's floor seed, scaling, boss pool and boss arena, the floor's spawning,
## rewards, items and combos). The fighting player is FightBot. Test-side only.


## Floor `floor_index` of the run with seed `run_seed`, with utility `utility` (&"guard" or &"blink"). `items`:
## indices into the compiled items the player starts with (engines and combos follow).
static func floor_world(
	run_seed: int, floor_index: int, utility: StringName = &"guard", items: Array = []
) -> World:
	var repo := ContentRepository.load_all()
	var run := RunState.start(
		run_seed, ContentCompiler.compile_run(repo.get_def(&"run", &"three_floors"))
	)
	run.floor_index = floor_index
	var table := ContentCompiler.apply_utility(
		ContentCompiler.compile_player(repo.get_def(&"player", &"runner")),
		repo.get_def(&"utility", utility)
	)
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	var boss := run.pick_boss(ContentCompiler.compile_boss_pool(repo, floor_index))
	var arena := (
		BossArenaSpec.make(bosses[boss].arena_cells, bosses[boss].arena_template, boss)
		if boss >= 0
		else null
	)
	var w := FloorScenario.build(
		run.floor_seed(),
		table,
		enemies,
		ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo),
		ContentCompiler.compile_items(repo),
		ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor")),
		floor_index,
		arena,
		run,
		ContentCompiler.compile_combos(repo)
	)
	w.set_boss_tables(bosses)
	for k in items:
		w.add_item(int(k))
	return w


## Puts the player just inside the boss room's door: the next tick seals it and spawns the boss (BossFlow).
static func enter_boss_room(w: World) -> void:
	var f := w.floor_layout
	if f != null and f.boss_room >= 0:
		w.actors.set_pos(0, f.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2))
		w.vel = Vector2.ZERO
