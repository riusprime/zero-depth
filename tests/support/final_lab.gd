class_name FinalLab
extends RefCounted
## v0.8.0 FB1: the final arena's world for the tests, built the way Main._start_floor builds it after End the run (the
## run on its last floor with final_fight set, the floors' bosses then the final boss's bodies scaled for that floor,
## FinalArenaScenario, the loadout, the fight begun). The same call with the same arguments gives the same world (the
## base a snapshot is restored into). Test-side only.


## A run of `run_seed` at its last floor of loop `loop`, after End the run (final_fight set).
static func run_state(run_seed: int, build: StringName = &"blade", loop: int = 1) -> RunState:
	var run := SaveLab.run_state(run_seed, 3, build)
	run.loop = loop
	run.loop_floors = 3 * (loop - 1)
	while run.routes.size() < run.run_floor():
		run.routes.append(Routes.Route.NORMAL)
	run.final_fight = true
	return run


## The final arena of `run` (its fight begun: the Colossus rising at the centre), fresh (tick 0). With `begin` false
## the fight's bodies wait (a base for a snapshot that holds its own). v0.9.0 FA: with `approach` the run's way in,
## the final approach (the causeway, the pylons; FloorPlan's build): no fight until its buildup ends.
static func arena(run: RunState, begin: bool = true, approach: bool = false) -> World:
	var repo := ContentRepository.load_all()
	var table := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(table, repo.get_def(&"build", run.build_id))
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	var finals := ContentCompiler.compile_final_bosses(repo, run.table)
	run.scale_bosses(finals)
	var def: FinalArenaDefinition = repo.get_def(&"final_arena", run.table.final_arena)
	var w := FinalArenaScenario.build(
		run,
		def,
		table,
		enemies,
		ContentCompiler.compile_items(repo),
		ContentCompiler.compile_combos(repo),
		bosses,
		finals,
		approach
	)
	w.wand_table = WandCompiler.from_repo(repo)
	w.blade_table = BladeCompiler.from_repo(repo)
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	w.overrun_table = ContentCompiler.compile_overrun(repo.get_def(&"overrun", &"overrun"))
	w.legendary_table = RunContentCompiler.compile_legendary(
		repo.get_def(&"legendary", &"boss"), w.stat_tables, w.item_tables
	)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	w.boss_flow.set_transit(false, false)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	EventCompiler.setup(w, repo)
	w.catch_up_table = ContentCompiler.compile_catch_up(repo.get_def(&"scaling", &"catch_up"))
	CatchUp.start_floor(w)
	w.tuning = RunContentCompiler.compile_sim_tuning(repo.get_def(&"tuning", &"sim"))
	if begin and not approach:
		FinalArenaScenario.begin(w, run, finals.size())
	return w


## v0.9.0 FA: the final approach of `run`, fresh (tick 0), as the Ascension portal opens it.
static func approach(run: RunState) -> World:
	return arena(run, false, true)


## The body fighting now (its actor index), -1 without one.
static func body(w: World) -> int:
	return FinalBoss.body_index(w)


## Steps until the current body is past its rise (acting, hittable), at most `limit` ticks.
static func past_rise(w: World, limit: int = 240) -> void:
	for k in limit:
		var i := body(w)
		if i >= 0 and w.actors.state[i] != EnemyAi.State.SPAWN:
			return
		w.step(InputFrame.new())


## The world's own hit (owner 0, as the dev panel's Kill boss) of `amount` on the current body.
static func hit(w: World, amount: int) -> void:
	var i := body(w)
	w.actors.invuln[i] = 0
	var at := w.actors.pos(i)
	Damage.hit(w, i, amount, 0, 0, w.take_root(), 0, at, at)


## Takes the current body to its segment's end (the dev panel's Kill boss: ten times its HP) and steps one tick.
static func end_segment(w: World) -> void:
	hit(w, w.actors.hp[body(w)] * 10)
	w.step(InputFrame.new())


## Steps through the shatter and the next body's rise.
static func through_shatter(w: World) -> void:
	for k in w.final_fight.shatter_ticks + 2:
		if not FinalBoss.shattering(w):
			break
		w.step(InputFrame.new())
	past_rise(w)


## A frame that walks toward `to` (full speed), no buttons.
static func walk(w: World, to: Vector2) -> InputFrame:
	var f := InputFrame.new()
	var d := to - w.player_pos()
	if d.length() > 0.05:
		d = d.normalized()
		f.move = Vector2i(roundi(d.x * SimTick.MOVE_MAX), roundi(d.y * SimTick.MOVE_MAX))
	return f
