class_name SaveLab
extends RefCounted
## Real run floors for the save tests (v0.4.0 SV), built the way Main._start_floor builds one: the run's floor seed,
## enemy and boss scaling, boss pool and arena, spawning, items, rewards, combos, gamble shrine, abilities, stat cards
## and heat. The same call with the same arguments gives the same world: the base a snapshot is restored into.
## Test-side only.

const RUN_ID := &"three_floors"


## `route` (v0.5.0 RT): the route taken into every floor after the first (Routes.Route; DEEP makes them Deep floors).
static func run_state(
	run_seed: int, floor_index: int, build: StringName = &"blade", route: int = 0
) -> RunState:
	var repo := ContentRepository.load_all()
	var run := RunState.start(
		run_seed, ContentCompiler.compile_run(repo.get_def(&"run", RUN_ID)), build
	)
	run.floor_index = floor_index
	for f in range(2, floor_index + 1):
		run.routes.append(route)
	return run


## Floor `floor_index` of the run `run_seed` with build `build`, fresh (tick 0), as Main starts it.
static func floor_world(run_seed: int, floor_index: int, build: StringName = &"blade") -> World:
	return build_floor(run_state(run_seed, floor_index, build))


static func build_floor(run: RunState) -> World:
	var repo := ContentRepository.load_all()
	var table := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(table, repo.get_def(&"build", run.build_id))
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	var boss := run.pick_boss(ContentCompiler.compile_boss_pool(repo, run.floor_index))
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
		run.floor_index,
		arena,
		run,
		ContentCompiler.compile_combos(repo),
		ContentCompiler.compile_gamble(repo.get_def(&"gamble", &"shrine"))
	)
	FloorScenario.add_shop(w, ContentCompiler.compile_shop(repo.get_def(&"shop", &"terminal")))  # v0.5.0 SH, as Main
	w.set_boss_tables(bosses)
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	w.overrun_table = ContentCompiler.compile_overrun(repo.get_def(&"overrun", &"overrun"))  # v0.4.0 AB, as Main
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	if w.boss_flow != null:
		w.boss_flow.set_transit(false, run.floor_index > 1)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	EventCompiler.setup(w, repo)  # v0.5.0 EV, as Main: event rooms and curses after the heat
	return w


## Grants the ability of each kind in `kinds` (AbilityTable.Kind), levelled to `level`.
static func grant_abilities(w: World, kinds: Array, level: int = 1) -> void:
	for kind: int in kinds:
		var idx := Abilities.index_of_kind(w, kind)
		if idx < 0:
			for k in w.ability_tables.size():
				if w.ability_tables[k].kind == kind:
					idx = k
		if idx >= 0:
			for i in level:
				Abilities.grant(w, idx)


## One card of each stat in `stats` (Stats.Stat) at `rarity`.
static func add_stats(w: World, stats: Array, rarity: int = 1) -> void:
	for s: int in stats:
		Stats.add_card(w, s, rarity)


## FightBot's input for `w`, plus the kit's buttons now and then (Skill every 150 ticks, Vent every 240), so the kit
## and heat state move too.
static func frame(w: World, bot: FightBot) -> InputFrame:
	var f := bot.frame(w)
	if w.tick % 150 == 75:
		f.pressed |= InputFrame.SKILL
	if w.tick % 240 == 120:
		f.pressed |= InputFrame.VENT
	return f


## Steps `w` `n` ticks with `bot` (frame above); the bot takes the world's input only from its own stream.
static func run(w: World, bot: FightBot, n: int) -> void:
	for i in n:
		w.step(frame(w, bot))
