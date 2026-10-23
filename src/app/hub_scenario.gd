class_name HubScenario
extends RefCounted
## v0.9.0 HB (owner Q27, HUB_MOCKUPS option A): the hub's World. The hero walks it on the run's own rules (the same
## World, movement, dash and walls, stepped by a SimDriver at 60 Hz: EI-02, EI-03), in the hub's walls (HubLayout)
## and nothing else: no enemies, spawns, floor, rewards, save or Codex. The hub never touches a run's save: Main
## builds this World apart from any run (RunSaver never sees it).

const SEED := 9090


static func build(repo: ContentRepository, layout: HubLayout, build_id: StringName) -> World:
	var table := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	var b := repo.get_def(&"build", build_id)
	if b != null:
		ContentCompiler.apply_build(table, b)
	var w := World.new(SEED, table, layout.spawn())
	w.set_walls(layout.walls())
	w.tuning = RunContentCompiler.compile_sim_tuning(repo.get_def(&"tuning", &"sim"))
	return w
