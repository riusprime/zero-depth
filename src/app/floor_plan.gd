class_name FloorPlan
extends RefCounted
## v0.8.0 N12 (owner O70: "the loading screens still freeze the game … it should be like a surely animation where
## things move and then open it, but never stop moving or freezing"; docs/roadmap/v0.8.0/evidence/LOADS_NO_FREEZE.md):
## one floor's World, built from the run and the content with no node, no file written and nothing a frame reads, so
## Main can run build() on a WorkerThreadPool task behind the loading cover (CoverLoads.on_worker) while the cover
## keeps moving. The tools, the tests and the dev panel's Restart floor run it on the main thread (Main._start_floor):
## the same inputs give the same World either way (test_floor_plan: a threaded build hashes as a main-thread one).
## Thread rule: while build() runs on a worker, the main thread runs no sim (the old floor is gone or held, the new
## floor has no driver yet) and builds no World, so the sim's few shared scratch buffers (NavField's) and lazy tables
## are only ever used by one thread at a time. Main sets the dev panel's overrides into the content (DevTuning.apply)
## on the main thread before the build starts.

## FLOOR: the run's current floor (`run` set). NEW_RUN: a new run first (RunState.start from `stage_seed` and
## `build_id`). CONTINUE: the saved run first (RunSaver.run_from `resume`, the save's payload), at its room entry.
enum Mode { FLOOR, NEW_RUN, CONTINUE }

## v0.9.0 DX: the SecretsDefinition numbers copied into SecretRules (same names).
const RULE_FIELDS: Array[String] = [
	"crack_permille",
	"crack_hits",
	"containers_max",
	"container_drop_permille",
	"container_heal_permille",
	"container_shards_min",
	"container_shards_max",
	"barrel_room_permille",
	"barrels_max",
	"barrel_fuse_ticks",
	"barrel_radius_m",
	"barrel_damage",
	"barrel_hero_damage",
]

var mode := Mode.FLOOR
## The content (null: build() reads it, ContentRepository.load_all).
var repo: ContentRepository
var run_id := RunSaver.RUN_ID
var run: RunState
var run_biomes: Array[StringName] = []
var stage_seed := 0
var build_id := &"blade"
## A save's payload (CONTINUE, or a FLOOR resumed from a save): its world snapshot is written into the fresh floor.
var resume := {}
## ViewPrefs.reduced_motion, read on the main thread (the portal's way in and the arrival).
var calm := false

## Out: the World (null when `err` says why the save didn't fit), the floor's biome (the final arena's on that floor)
## and the final arena's definition (null elsewhere).
var world: World
var biome: BiomeDefinition
var arena_def: FinalArenaDefinition
var err := ""


## A new run's first floor.
static func new_run(
	p_run_id: StringName, seed_value: int, p_build: StringName, p_calm: bool
) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.mode = Mode.NEW_RUN
	plan.run_id = p_run_id
	plan.stage_seed = seed_value
	plan.build_id = p_build
	plan.calm = p_calm
	return plan


## The saved run `save` (a RunSaver payload) at its room entry.
static func continued(p_run_id: StringName, save: Dictionary, p_calm: bool) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.mode = Mode.CONTINUE
	plan.run_id = p_run_id
	plan.resume = save
	plan.calm = p_calm
	return plan


## The run's current floor (`p_resume`: a save's payload to resume it at, or {}).
static func next_floor(
	p_run: RunState, biomes: Array[StringName], p_resume: Dictionary, p_calm: bool
) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.run = p_run
	plan.run_biomes = biomes
	plan.resume = p_resume
	plan.calm = p_calm
	return plan


func build() -> void:
	if repo == null:
		repo = ContentRepository.load_all()
	if mode == Mode.CONTINUE and repo.get_def(&"run", RunSaver.saved_run_id(resume)) != null:
		run_id = RunSaver.saved_run_id(resume)  # v0.9.0 FV: the save's own run shape (a v0.8.0 run: 3 floors)
	if mode != Mode.FLOOR:
		var run_def: RunDefinition = repo.get_def(&"run", run_id)
		run_biomes = run_def.biomes.duplicate()
		if mode == Mode.NEW_RUN:
			run = RunState.start(stage_seed, ContentCompiler.compile_run(run_def), build_id)
		else:
			stage_seed = int(resume["run"]["stage_seed"])
			run = RunSaver.run_from(resume, ContentCompiler.compile_run(run_def))
	_build_world()


func _build_world() -> void:
	var def: PlayerDefinition = repo.get_def(&"player", &"runner")
	biome = repo.get_def(&"biomes", run_biomes[run.biome_of()])
	arena_def = null  # v0.8.0 FB1: the final arena (P2: the Ascension portal), its own biome
	if run.final_fight:
		arena_def = repo.get_def(&"final_arena", run.table.final_arena)
		if arena_def != null:
			biome = arena_def
	var table := ContentCompiler.compile_player(def)  # v0.4.0 BS (F11): no utility at the start
	ContentCompiler.apply_build(table, repo.get_def(&"build", run.build_id))  # v0.3.0 L15: the run's build.
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	# The floor's boss (v0.3.0 C): drawn from its floor's pool, scaled like the enemies; its arena sizes the room.
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	var finals := ContentCompiler.compile_final_bosses(repo, run.table)  # v0.8.0 FB1: the final boss's bodies
	run.scale_bosses(finals)
	var w: World
	if arena_def != null:  # FB1 (F1, F2); P2: the Ascension portal brought the hero here
		w = FinalArenaScenario.build(
			run,
			arena_def,
			table,
			enemies,
			ContentCompiler.compile_items(repo),
			ContentCompiler.compile_combos(repo),
			bosses,
			finals,
			approach_of(resume)  # v0.9.0 FA: the final approach first
		)
	else:
		w = _floor_world(table, enemies, bosses, biome.id)
		IcePatches.place(w, BiomeCompiler.compile_surface(biome))  # v0.7.5 NB1/NB2: ice or starglow
		w.set_boss_tables(bosses)  # Bosses (v0.3.0 C), scaled for the floor like the enemies.
	w.wand_table = WandCompiler.for_run(repo, run.table)  # v0.6.5 WN1; v0.9.0 FV: 4 → 8 over five floors
	w.blade_table = BladeCompiler.from_repo(repo)  # v0.6.5 WN4: the Blade pool's runner numbers
	w.slot_table = WandCompiler.slots(repo, w.item_tables)  # v0.9.0 AS: slot limits, caps, compatibility
	w.ability_tables = ContentCompiler.compile_abilities(repo)  # v0.4.0 BS: the four slots,
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)  # the stat cards,
	w.overrun_table = ContentCompiler.compile_overrun(repo.get_def(&"overrun", &"overrun"))  # v0.4.0 AB
	w.legendary_table = RunContentCompiler.compile_legendary(
		repo.get_def(&"legendary", &"boss"), w.stat_tables, w.item_tables
	)
	# v0.8.0 FL: floor-paced loot (LootPacing)
	w.loot_pacing = RunContentCompiler.compile_loot_pacing(repo.get_def(&"loot_pacing", &"pacing"))
	Abilities.grant_start(w)  # slot 1 = the build's weapon (floor 1; later floors carry it)
	Abilities.start_floor(w)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))  # v0.3.0 L18
	# v0.5.0 EV: event rooms and curses, after the carry and the heat; v0.8.0 N17, N19: an old save keeps its rooms
	EventCompiler.setup(w, repo, FloorScenario.curse_room_rules_of(run))
	if arena_def == null:
		add_secrets(w, repo, run, table.move_speed)  # v0.9.0 TD, RA, DX
	# v0.5.5 DS (D4): the hidden catch-up, read from the whole build once everything above is set up.
	w.catch_up_table = ContentCompiler.compile_catch_up(repo.get_def(&"scaling", &"catch_up"))
	CatchUp.start_floor(w)
	w.tuning = RunContentCompiler.compile_sim_tuning(repo.get_def(&"tuning", &"sim"))  # dev panel Step 6
	if w.boss_flow != null:  # v0.3.5 PT: the portal's way in; v0.8.0 N11 (O69): every floor's arrival (data)
		w.boss_flow.set_transit(
			calm, true, BossFlow.arrival_length(w.tuning, calm, run.run_floor() == 1)  # AP: run_floor() counts across loops
		)
	if arena_def != null and w.approach == null:  # v0.8.0 FB1: the first body rises (after the loadout: its hidden
		FinalArenaScenario.begin(w, run, finals.size())  # catch-up counts); v0.9.0 FA: the approach begins it later
	if not resume.is_empty():  # v0.4.0 SV: back to the saved room entry
		err = WorldSnapshot.apply(w, resume["world"])
		if err != "":
			return
		WandMigration.run(w)  # v0.6.5 WN5b: a save that still holds retired v0.6 cards
		AttackSlots.trim(w)  # v0.9.0 AS: a save from before the slot categories (AttackSlots.trim)
	world = w


## v0.9.0 TD, RA, DX: a floor's secrets, after every room kind (the save lab builds floors with it too). TD: a floor
## saved before TD (floor rules 1-9) has no timed door; RA, DX: one saved before them (1-10) has no rune puzzle and no
## destructibles. The rune puzzle comes after the timed door, the destructibles after both (never their rooms).
## v0.9.0 DP: the purple-rune room comes last (never a secret's room; one saved before DP, rules 1-11, has none).
static func add_secrets(
	w: World, repo: ContentRepository, run: RunState, move_speed: float
) -> void:
	if run.floor_rules > RunState.FLOOR_RULES_V080_BD:
		var map := RunContentCompiler.compile_map(repo.get_def(&"map", &"floor"))
		TimedDoor.setup(w, map.timed_door_permille, map.timed_door_ticks, move_speed)
	if run.floor_rules > RunState.FLOOR_RULES_V090_TD:
		var secrets: SecretsDefinition = repo.get_def(&"secrets", &"secrets")
		RuneAlignment.setup(w, secrets.rune_permille if secrets != null else 0)
		Breakables.setup(w, secret_rules(secrets))
	if run.floor_rules > RunState.FLOOR_RULES_V090_RA:  # v0.9.0 DP (owner Q26b): last, never a secret's room
		var secrets: SecretsDefinition = repo.get_def(&"secrets", &"secrets")
		var chances := secrets.purple_floor_permille if secrets != null else PackedInt32Array()
		PurpleRunes.setup(w, PurpleRunes.chance(run, chances))


## v0.9.0 DX: the destructibles' numbers from the data (SecretRules' defaults without it).
static func secret_rules(def: SecretsDefinition) -> SecretRules:
	var r := SecretRules.new()
	if def == null:
		return r
	for f in RULE_FIELDS:
		r.set(f, def.get(f))
	return r


## v0.9.0 FA: whether the final arena opens on the final approach: a fresh arrival, or a save made on the approach or
## in its fight (its world holds `approach`). A save made in the final arena before FA holds none: its ring arena and
## its fight are rebuilt bare, as they were.
static func approach_of(save: Dictionary) -> bool:
	if save.is_empty():
		return true
	var world: Variant = (save.get("world", {}) as Dictionary).get("world", {})
	if not world is Dictionary:
		return true
	var d := world as Dictionary
	return d.get(&"approach", d.get("approach")) != null


## A floor of the run (FloorScenario): its boss drawn from the floor's pool, its room, the floor's tables and its shop.
func _floor_world(
	table: PlayerTable, enemies: Array[EnemyTable], bosses: Array[BossTable], biome_id: StringName
) -> World:
	# v0.9.0 FV: floors 4-5 draw a boss not yet met
	var boss := FloorShape.boss(
		run, RunContentCompiler.compile_boss_pools(repo, run.table.floors), run.floor_index
	)
	var arena := RunSaver.boss_arena(run, bosses, boss)  # v0.7.5 BF1 (N18): an older save's room
	var rules := RunSaver.floor_tables(run, repo)  # v0.7.5 MG: map, arenas, shop (v0.7.0's on an old save's)
	var w := FloorScenario.build(
		run.floor_seed(),
		table,
		enemies,
		ContentCompiler.compile_floor_spawning(repo, run.floor_index),  # v0.4.0 TU: with the floor's curve
		ContentCompiler.compile_items(repo),
		ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor")),  # v0.3.0 E: altars, chests, shards.
		run.floor_index,
		arena,
		run,
		ContentCompiler.compile_combos(repo),  # v0.3.0 G: named combos.
		ContentCompiler.compile_gamble(repo.get_def(&"gamble", &"shrine")),  # v0.3.0 L19: the gamble shrine.
		rules[&"arena"],  # v0.5.5 AR: the sealed arenas
		rules[&"map"]  # v0.7.5 MG: rooms, footprints (N9)
	)
	# v0.5.0 SH; v0.7.5 MG: every two floors (N12); v0.8.0 SR: in the biome's shop room (O13)
	FloorScenario.add_shop(w, rules[&"shop"], biome_id, rules[&"map"])
	return w
