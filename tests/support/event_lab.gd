class_name EventLab
extends RefCounted
## Real floors with event rooms (v0.5.0 EV), built the way Main builds one (the run's floor seed, scaling, boss
## arena, rewards, the gamble shrine, the shop, abilities, stat cards, the Overrun rules, heat, then
## EventCompiler.setup), and helpers that put a
## chosen event on a pedestal. Test-side only: the setters here are labelled test setup, never gameplay.

static var _repo: ContentRepository


static func repo() -> ContentRepository:
	if _repo == null:
		_repo = ContentRepository.load_all()
	return _repo


## Floor `floor_index` of run `run_seed` for `build`; `curses` (curse ids) are held from the start (as a carry).
static func world(
	run_seed: int, floor_index: int = 1, build: StringName = &"blade", curses: Array = []
) -> World:
	var r := repo()
	var run := RunState.start(
		run_seed, ContentCompiler.compile_run(r.get_def(&"run", &"three_floors")), build
	)
	run.floor_index = floor_index
	if not curses.is_empty():
		var owned := PackedInt32Array()
		var ids := curse_ids()
		for c: StringName in curses:
			owned.append(ids.find(c))
		run.carry = {&"curses_owned": owned, &"threat_peak": owned.size()}
	var table := ContentCompiler.compile_player(r.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(table, r.get_def(&"build", build))
	var enemies := ContentCompiler.compile_enemies(r)
	run.scale_enemies(enemies)
	var bosses := ContentCompiler.compile_bosses(r)
	run.scale_bosses(bosses)
	var boss := run.pick_boss(ContentCompiler.compile_boss_pool(r, floor_index))
	var arena := (
		BossArenaSpec.make(bosses[boss].arena_cells, bosses[boss].arena_template, boss)
		if boss >= 0
		else null
	)
	var w := FloorScenario.build(
		run.floor_seed(),
		table,
		enemies,
		ContentCompiler.compile_spawning(r.get_def(&"spawning", &"floor_1"), r),
		ContentCompiler.compile_items(r),
		ContentCompiler.compile_rewards(r.get_def(&"rewards", &"floor")),
		floor_index,
		arena,
		run,
		ContentCompiler.compile_combos(r),
		ContentCompiler.compile_gamble(r.get_def(&"gamble", &"shrine"))
	)
	FloorScenario.add_shop(w, ContentCompiler.compile_shop(r.get_def(&"shop", &"terminal")))  # as Main
	w.set_boss_tables(bosses)
	w.ability_tables = ContentCompiler.compile_abilities(r)
	w.stat_tables = ContentCompiler.compile_stat_cards(r)
	w.overrun_table = ContentCompiler.compile_overrun(r.get_def(&"overrun", &"overrun"))
	w.legendary_table = RunContentCompiler.compile_legendary(
		r.get_def(&"legendary", &"boss"), w.stat_tables, w.item_tables  # v0.6.0 CU: as Main (boss cores)
	)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	Heat.enable(w, ContentCompiler.compile_heat(r.get_def(&"heat", &"overclock")))
	EventCompiler.setup(w, r)
	return w


static func curse_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for c in EventCompiler.compile_curses(repo()):
		out.append(c.id)
	return out


static func curse_index(w: World, id: StringName) -> int:
	for c in w.ev.curses.size():
		if w.ev.curses[c].id == id:
			return c
	return -1


static func event_index(w: World, id: StringName) -> int:
	for e in w.ev.events.size():
		if w.ev.events[e].id == id:
			return e
	return -1


## TEST SETUP: pedestal 0 becomes event `id`, unrolled and ready (so one floor can test every event).
static func set_event(w: World, id: StringName, k: int = 0) -> void:
	w.ev.event[k] = event_index(w, id)
	w.ev.state[k] = Events.State.READY
	w.ev.rolled[k] = 0


## Stands the player at pedestal k and presses interact (two ticks: the press, then the open).
static func open(w: World, k: int = 0) -> void:
	w.actors.set_pos(0, w.ev.pos(k))
	w.vel = Vector2.ZERO
	var f := InputFrame.new()
	f.pressed = InputFrame.INTERACT
	w.step(f)


## One tick with a pick (1..n, or InputFrame.PICK_CANCEL).
static func pick(w: World, value: int) -> void:
	var f := InputFrame.new()
	f.pick = value
	w.step(f)


static func idle(w: World, ticks: int) -> void:
	for t in ticks:
		w.step(InputFrame.new())
