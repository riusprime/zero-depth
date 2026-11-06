class_name RunLab
extends RefCounted
## Whole runs for the tuning sims (v0.4.0 TU): each floor built the way Main._start_floor builds it (the run's
## floor seed, build, scaling, boss pool and arena, spawning, rewards, items, combos, gamble shrine, abilities, stat
## cards, Overrun, heat, v0.5.0's shop and events), with the carry from the floor before. No view: test-side and
## script-side only.

var repo: ContentRepository
var run: RunState


func _init(p_repo: ContentRepository, run_seed: int, build: StringName) -> void:
	repo = p_repo
	run = RunState.start(
		run_seed, ContentCompiler.compile_run(repo.get_def(&"run", RunSaver.RUN_ID)), build
	)


## The run's current floor as a fresh World (as Main builds it; no arrival hold, so the sim starts at once).
func floor_world() -> World:
	var table := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(table, repo.get_def(&"build", run.build_id))
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	var boss := FloorShape.boss(
		run, RunContentCompiler.compile_boss_pools(repo, run.table.floors), run.floor_index
	)
	var arena := RunSaver.boss_arena(run, bosses, boss)  # v0.7.5 BF1 (N18): an older save's room
	var w := FloorScenario.build(
		run.floor_seed(),
		table,
		enemies,
		ContentCompiler.compile_floor_spawning(repo, run.floor_index),
		ContentCompiler.compile_items(repo),
		ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor")),
		run.floor_index,
		arena,
		run,
		ContentCompiler.compile_combos(repo),
		ContentCompiler.compile_gamble(repo.get_def(&"gamble", &"shrine"))
	)
	FloorScenario.add_shop(w, ContentCompiler.compile_shop(repo.get_def(&"shop", &"terminal")))
	w.set_boss_tables(bosses)
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	w.overrun_table = ContentCompiler.compile_overrun(repo.get_def(&"overrun", &"overrun"))
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	# v0.5.0 EV, as Main (N17, N19; v0.9.0 EL)
	EventCompiler.setup(
		w,
		repo,
		FloorScenario.curse_room_rules_of(run),
		FloorScenario.retired_events_of(run),
		FloorScenario.rare_events_of(run)
	)
	return w


## The portal was taken: carry over to the next floor.
func next_floor(w: World) -> void:
	run.finish_floor(w)
