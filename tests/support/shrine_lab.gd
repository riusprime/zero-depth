class_name ShrineLab
extends RefCounted
## v0.9.0 SH, HF: run floors as Main builds them (SaveLab.build_floor's order: FloorScenario.build, the shop, the
## events, FloorPlan.add_secrets) from one content load (SaveLab loads it per floor; the placement test builds
## hundreds), and the first one holding a given shrine kind or a fountain. The hero unhurt, no arrival hold.

const LONG := 1 << 24

static var _repo: ContentRepository


static func repo() -> ContentRepository:
	if _repo == null:
		_repo = ContentRepository.load_all()
	return _repo


static func run_state(run_seed: int, floor_index: int) -> RunState:
	var run := RunState.start(
		run_seed, ContentCompiler.compile_run(repo().get_def(&"run", SaveLab.RUN_ID)), &"blade"
	)
	run.floor_index = floor_index
	for f in range(2, floor_index + 1):
		run.routes.append(0)
	return run


## Floor `run.floor_index` of `run`, fresh (tick 0).
static func build(run: RunState) -> World:
	var r := repo()
	var table := ContentCompiler.compile_player(r.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(table, r.get_def(&"build", run.build_id))
	var enemies := ContentCompiler.compile_enemies(r)
	run.scale_enemies(enemies)
	var bosses := ContentCompiler.compile_bosses(r)
	run.scale_bosses(bosses)
	var boss := FloorShape.boss(
		run, RunContentCompiler.compile_boss_pools(r, run.table.floors), run.floor_index
	)
	var arena := RunSaver.boss_arena(run, bosses, boss)
	var rules := RunSaver.floor_tables(run, r)
	var w := FloorScenario.build(
		run.floor_seed(),
		table,
		enemies,
		ContentCompiler.compile_floor_spawning(r, run.floor_index),
		ContentCompiler.compile_items(r),
		ContentCompiler.compile_rewards(r.get_def(&"rewards", &"floor")),
		run.floor_index,
		arena,
		run,
		ContentCompiler.compile_combos(r),
		ContentCompiler.compile_gamble(r.get_def(&"gamble", &"shrine")),
		rules[&"arena"],
		rules[&"map"],
		rules[&"overrun"],  # v0.9.0 CF
		rules[&"lockdown_first"]  # v0.9.0 CF2
	)
	var biome: BiomeDefinition = r.get_def(
		&"biomes", (r.get_def(&"run", run.table.id) as RunDefinition).biomes[run.biome_of()]
	)
	FloorScenario.add_shop(w, rules[&"shop"], biome.id, rules[&"map"])
	w.set_boss_tables(bosses)
	w.ability_tables = ContentCompiler.compile_abilities(r)
	w.stat_tables = ContentCompiler.compile_stat_cards(r)
	EventCompiler.setup(
		w, r, FloorScenario.curse_room_rules_of(run), FloorScenario.retired_events_of(run)
	)
	FloorPlan.add_secrets(w, r, run, table.move_speed)
	return w


static func floor_world(run_seed: int, floor_index: int) -> World:
	return build(run_state(run_seed, floor_index))


## The first floor `floor_index` from run seed `first_seed` whose shrine is `kind` (ShrineTable.Kind), started (the
## hero unhurt, one tick stepped); null within `tries`.
static func with_kind(
	kind: int, floor_index: int = 2, first_seed: int = 1, tries: int = 80
) -> World:
	for s in range(first_seed, first_seed + tries):
		var w := floor_world(s, floor_index)
		if w.gamble_id >= 0 and Shrines.kind_of(w) == kind:
			calm(w)
			return w
	return null


## The first floor with a healing fountain, started.
static func with_fountain(floor_index: int = 2, first_seed: int = 1, tries: int = 80) -> World:
	for s in range(first_seed, first_seed + tries):
		var w := floor_world(s, floor_index)
		if w.shrine != null and w.shrine.has_fountain():
			calm(w)
			return w
	return null


static func calm(w: World) -> void:
	w.actors.invuln[0] = LONG
	if w.boss_flow != null:
		w.boss_flow.arrive_left = 0
	w.step(InputFrame.new())


## Stands the hero `front` of the spot `at` (Gamble.front, toward its room's first doorway approach).
static func stand_by(w: World, at: Vector2) -> void:
	var f := w.floor_layout
	var room := f.room_of(at)
	w.actors.set_pos(0, Gamble.front(at, f.door_approaches(room, 1.0)[0]))
	w.vel = Vector2.ZERO


## One tick with the interact button pressed.
static func press(w: World) -> void:
	var f := InputFrame.new()
	f.pressed = InputFrame.INTERACT
	w.step(f)
