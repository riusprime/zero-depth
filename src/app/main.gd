class_name Main
extends Node
## Composition root (ARCHITECTURE §2): boots the input map, profile and settings, then runs the menus and the
## stage. Only app/ may wire layers together.

const STAGE_SEED := 20261006
const END_PANEL_DELAY_TICKS := 45
## Run flow (v0.3.0 B): the run's data, and the fade-in from black when a floor starts.
const RUN_ID := &"three_floors"
const FADE_SECONDS := 0.45
## v0.3.5 PT: a floor that opens on the arrival column fades in faster, so the column shows.
const ARRIVAL_FADE_SECONDS := 0.2
## v0.7.5 AP: the Codex profile page the Ascension counters live on (_record_ascension; not a Codex page you browse).
const ASCENSION_PAGE := &"runs"

var profile: ProfileStore
var driver: SimDriver
var view: WorldViewRoot
var ui := CanvasLayer.new()
## The run in progress (null outside one): floors, biome order, carry, totals. _stage_seed is its run seed.
var run: RunState
## Sounds, ambience and captions (v0.3.0 AU); it outlives floors so the ambience can crossfade.
var audio := AudioDirector.new()
## v0.4.0 SV: the run save (room entries, close, Continue).
var saves: RunSaver
## v0.7.5 CX: the Codex's counters (in the profile) and the recorder that reads each floor's ticks into them.
var codex: CodexStore
var codex_recorder: CodexRecorder
## v0.7.5 AC: the achievements (in the profile), the tracker that unlocks them from each floor's ticks and the Codex,
## and the toast that shows an unlock (on the UI layer, so it outlives a floor).
var achievements: AchievementStore
var achievement_tracker: AchievementTracker
var toast := AchievementToast.new()
## v0.7.5 SM (N8): the first-run hints (seen ones in the profile's hints section), on the UI layer like the toast.
var hint_store: HintStore
var hints := OnboardingHints.new()
## v0.7.5 PG (owner N20, docs/tools/PLAYGROUND.md): the Playground while it runs (null otherwise).
var playground: PlaygroundSession

## The dev panel's tuning (docs/tools/DEV_PANEL.md): the owner's saved overrides, written into the content before
## every run and floor is compiled.
## v0.7.5 SM: a build with the panel locked (DevGate) ignores any tuning file left on the PC.
var tuning := DevTuning.load_saved() if DevGate.enabled() else DevTuning.new()
var _menu: Control
var _pause: PauseMenu
## Options opened from the pause menu (v0.3.0 O), over the paused stage.
var _pause_options: OptionsMenu
## v0.6.5 WN2: the Build page opened from the pause menu, over the paused stage.
var _pause_build: BuildPage
## v0.7.5 CX: the Codex opened from the pause menu, and its catalog (from the content, built on first use).
var _pause_codex: CodexView
var _codex_catalog: CodexCatalog
var _achievement_book: AchievementBook
var _dev: DevPanel
var _devm: DevMasterPanel
## The current floor's biome file (the dev panel's lighting edits re-read its mood).
var _biome_path := ""
## A balance edit waits to go into the running World until the panel closes (the run is paused while it is open).
var _balance_pending := false
var _dev_mark: Label
var _hud: Hud
var _end: EndPanel
## Ticks since the fight ended; the end panel waits a moment so the last hit reads.
var _ended_ticks := 0
var _stage_seed := STAGE_SEED
var _run_biomes: Array[StringName] = []
var _fade := ColorRect.new()
var _fade_left := 0.0
var _fade_len := FADE_SECONDS
## v0.7.5 PG: the Playground's weapon and biome (kept across Restart and Change weapon).
var _pg_build := &"gun"
var _pg_biome := &"ruins"


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_window().theme = load(ThemePalette.UI_THEME)
	InputDefaults.apply()
	profile = ProfileStore.shared()
	codex = CodexStore.new(profile)
	achievements = AchievementStore.new(profile)  # v0.7.5 AC
	saves = RunSaver.new(RunSaveStore.shared())
	InputRemap.apply(profile)
	GameSettings.apply_all(profile)
	audio.setup(profile)
	add_child(audio)
	ViewPrefs.apply_settings(profile)  # v0.3.0 O: reduced motion, colour-blind palette
	ui.name = "UI"
	add_child(ui)
	_fade.name = "Fade"
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	ui.add_child(_fade)
	ui.add_child(toast)  # v0.7.5 AC
	hint_store = HintStore.new(profile)  # v0.7.5 SM
	hints.setup(hint_store)
	ui.add_child(hints)
	show_main_menu()


func _process(delta: float) -> void:
	if _fade_left > 0.0:
		_fade_left = maxf(0.0, _fade_left - delta)
		_fade.color.a = _fade_left / _fade_len
		_fade.visible = _fade_left > 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		saves.close()  # v0.4.0 SV: the last room entry is on disk
		profile.save_file()
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if (  # the master dev panel (docs/tools/DEV_PANEL.md): every build, anywhere
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_F10
		and DevGate.enabled()
	):  # v0.7.5 SM: one switch locks it for a public release (ROADMAP §0.4)
		get_viewport().set_input_as_handled()
		_toggle_master_panel()
		return
	if (
		driver != null
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_QUOTELEFT
		and DevPanel.unlocked()
		and DevGate.enabled()
	):
		get_viewport().set_input_as_handled()
		toggle_dev_panel()
		return
	if (
		driver != null
		and _end == null
		and not driver.reader.choosing()  # Rewards: the pick's own cancel comes first.
		and not driver.reader.event_open()  # v0.5.0 EV: so does an event panel's
		and not driver.reader.shop_open()  # v0.5.0 SH: so does the shop's
		and not driver.reader.swapping()  # v0.6.0 MX2: so does the swap's skip
		and not driver.reader.ascension_open()  # v0.7.5 AP: so does the Ascension portal's Not yet
		and event.is_action_pressed(&"pause")
	):
		get_viewport().set_input_as_handled()
		if _pause == null:
			open_pause()
		else:
			close_pause()


func is_playing() -> bool:
	return driver != null


func show_main_menu() -> void:
	saves.close()  # v0.4.0 SV: leaving a run (pause -> Main menu) keeps its last room entry
	_end_stage()
	audio.set_ambience(&"")
	var m := MainMenu.new(
		GameVersion.label(), OS.is_debug_build(), saves.store.has_save(), DevGate.enabled()
	)
	m.continue_pressed.connect(continue_run)
	m.play_pressed.connect(show_build_picker)
	m.options_pressed.connect(show_options)
	m.credits_pressed.connect(show_credits)
	m.codex_pressed.connect(show_codex)
	m.playground_pressed.connect(_show_playground_picker)  # v0.7.5 PG
	m.galleries_pressed.connect(show_gallery)
	m.quit_pressed.connect(
		func() -> void: get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	)
	_set_menu(m)


## Play -> pick the build (v0.3.0 L15: Blade or Gun) -> the run. The pick is remembered in the profile; the build is
## the run's (RunState.build_id) and holds on every floor. v0.4.0 BS (owner F11, PD-01 flipped): there is no utility
## pick any more; Blink and Aegis are ability cards found in the run.
func show_build_picker() -> void:
	var defs := ContentRepository.load_all().all_of(&"build")
	var last := StringName(profile.section("loadout").get("build", "blade"))
	var p := BuildPicker.new(defs, last)
	p.picked.connect(
		func(id: StringName) -> void:
			profile.section("loadout")["build"] = String(id)
			start_stage()
	)
	p.back_pressed.connect(show_main_menu)
	_set_menu(p)


func show_options() -> void:
	var o := OptionsMenu.new(profile)
	o.back_pressed.connect(show_main_menu)
	o.setting_changed.connect(_on_setting_changed)
	_set_menu(o)


## Options from the pause menu (v0.3.0 O): the pause menu hides under it and comes back on Back.
func open_pause_options() -> void:
	if _pause == null or _pause_options != null:
		return
	_pause.visible = false
	_pause_options = OptionsMenu.new(profile, OptionsMenu.Layout.SIDEBAR, true)
	_pause_options.setting_changed.connect(_on_setting_changed)
	_pause_options.back_pressed.connect(close_pause_options)
	ui.add_child(_pause_options)
	_pause_options.focus_first()


func close_pause_options() -> void:
	if _pause_options != null:
		_pause_options.queue_free()
		_pause_options = null
	if _pause != null:
		_pause.visible = true
		(_pause.box.get_node("Options") as Button).grab_focus()


## A setting changed in Options: what lives in the view follows at once (GameSettings already applied the engine's).
func _on_setting_changed(_key: String) -> void:
	ViewPrefs.apply_settings(profile)
	if view != null:
		view.rig.shake_enabled = GameSettings.get_value(profile, "shake") == "on"
		view.ink.set_style(InkPass.style_from_setting(GameSettings.get_value(profile, "outline")))
		view.stage.set_lighting(GameSettings.get_value(profile, "lighting"))


func show_credits() -> void:
	var repo := ContentRepository.load_all()
	var credits: CreditsDefinition = repo.get_def(&"credits", &"main")
	var c := CreditsView.new(credits, repo.get_def(&"licences", &"generated"))  # v0.7.5 SM: with the licence list
	c.back_pressed.connect(show_main_menu)
	_set_menu(c)


## v0.7.5 CX: the Codex from the main menu; Back returns to the menu with the Codex row focused. v0.7.5 AC: with the
## Achievements page.
func show_codex() -> void:
	var c := CodexView.new(codex_catalog(), codex, _achievements_book())
	c.back_pressed.connect(
		func() -> void:
			show_main_menu()
			(_menu as MainMenu).box.get_node("Codex").grab_focus()
	)
	_set_menu(c)


## The Codex's entries, read from the shipped content once (CodexCatalog).
func codex_catalog(repo: ContentRepository = null) -> CodexCatalog:
	if _codex_catalog == null:
		_codex_catalog = CodexCatalog.build(repo if repo != null else ContentRepository.load_all())
	return _codex_catalog


## v0.7.5 AC: every achievement (the content's definitions, the Codex's entries for the per-boss and per-biome
## ones), built once.
func _achievements_book(repo: ContentRepository = null) -> AchievementBook:
	if _achievement_book == null:
		if repo == null:
			repo = ContentRepository.load_all()
		_achievement_book = AchievementBook.build(repo, achievements, codex, codex_catalog(repo))
	return _achievement_book


func show_gallery() -> void:
	_set_menu(null)
	var g := Gallery.new()
	g.name = "Gallery"
	add_child(g)
	g.setup(&"ruins", 35.26, &"xray", true)


## Starts a run (v0.3.0 B) with the run seed _stage_seed, on its first floor.
func start_stage() -> void:
	_set_menu(null)
	var repo := _content()
	var run_def: RunDefinition = repo.get_def(&"run", RUN_ID)
	_run_biomes = run_def.biomes.duplicate()
	var build := StringName(profile.section("loadout").get("build", "blade"))
	run = RunState.start(_stage_seed, ContentCompiler.compile_run(run_def), build)
	_start_floor(repo)


## v0.4.0 SV: Continue resumes the saved run at its last room entry. A save that doesn't fit is set aside.
func continue_run() -> void:
	var save := saves.store.read()
	if not RunSaver.is_usable(save):
		if not save.is_empty():
			saves.store.reject("payload version %s" % str(save.get("version")))
		show_main_menu()
		return
	_set_menu(null)
	var repo := _content()
	var run_def: RunDefinition = repo.get_def(&"run", RUN_ID)
	_run_biomes = run_def.biomes.duplicate()
	_stage_seed = int(save["run"]["stage_seed"])
	run = RunSaver.run_from(save, ContentCompiler.compile_run(run_def))
	var err := _start_floor(repo, save)
	if err != "":
		saves.store.reject(err)
		show_main_menu()


## Builds the run's current floor: its seed, biome and enemy scaling from the run, the carry applied. `resume`: a
## save's payload (v0.4.0 SV), whose world snapshot is then written into the fresh floor; returns why it didn't fit.
func _start_floor(repo: ContentRepository = null, resume: Dictionary = {}) -> String:
	if repo == null:
		repo = _content()
	if codex_recorder == null:  # v0.7.5 CX: built on the first floor, from the content already loaded
		codex_recorder = CodexRecorder.new(codex, codex_catalog(repo))
	if achievement_tracker == null:  # v0.7.5 AC: before the biome's visit, so its Codex write is heard
		achievement_tracker = AchievementTracker.new(_achievements_book(repo))
		achievement_tracker.achieved.connect(toast.push)
	var def: PlayerDefinition = repo.get_def(&"player", &"runner")
	var biome: BiomeDefinition = repo.get_def(&"biomes", _run_biomes[run.biome_of()])
	var arena_def: FinalArenaDefinition = null  # v0.8.0 FB1: the final arena (End the run), its own biome
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
	var world: World
	if arena_def != null:  # v0.8.0 FB1 (F1, F2): End the run brought the hero to the final arena
		world = FinalArenaScenario.build(
			run,
			arena_def,
			table,
			enemies,
			ContentCompiler.compile_items(repo),
			ContentCompiler.compile_combos(repo),
			bosses,
			finals
		)
	else:
		world = _floor_world(repo, run, table, enemies, bosses)
		IcePatches.place(world, BiomeCompiler.compile_surface(biome))  # v0.7.5 NB1/NB2: ice or starglow
		world.set_boss_tables(bosses)  # Bosses (v0.3.0 C), scaled for the floor like the enemies.
	world.wand_table = WandCompiler.from_repo(repo)  # v0.6.5 WN1: the wand grows 4 → 6 → 8 (before the slots migrate)
	world.blade_table = BladeCompiler.from_repo(repo)  # v0.6.5 WN4: the Blade pool's runner numbers
	world.ability_tables = ContentCompiler.compile_abilities(repo)  # v0.4.0 BS: the four slots,
	world.stat_tables = ContentCompiler.compile_stat_cards(repo)  # the stat cards,
	world.overrun_table = ContentCompiler.compile_overrun(repo.get_def(&"overrun", &"overrun"))  # v0.4.0 AB
	world.legendary_table = RunContentCompiler.compile_legendary(
		repo.get_def(&"legendary", &"boss"), world.stat_tables, world.item_tables
	)
	Abilities.grant_start(world)  # slot 1 = the build's weapon (floor 1; later floors carry it)
	Abilities.start_floor(world)
	if world.boss_flow != null:  # v0.3.5 PT: the portal's way in, and the arrival on floors after the first.
		world.boss_flow.set_transit(ViewPrefs.reduced_motion, run.run_floor() > 1)  # AP: every loop
	Heat.enable(world, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))  # v0.3.0 L18
	EventCompiler.setup(world, repo)  # v0.5.0 EV: event rooms and curses, after the carry and the heat
	# v0.5.5 DS (D4): the hidden catch-up, read from the whole build once everything above is set up.
	world.catch_up_table = ContentCompiler.compile_catch_up(repo.get_def(&"scaling", &"catch_up"))
	CatchUp.start_floor(world)
	world.tuning = RunContentCompiler.compile_sim_tuning(repo.get_def(&"tuning", &"sim"))  # dev panel Step 6
	if arena_def != null:  # v0.8.0 FB1: the first body rises (after the loadout: its hidden catch-up counts)
		FinalArenaScenario.begin(world, run, finals.size())
	if not resume.is_empty():  # v0.4.0 SV: back to the saved room entry
		var err := WorldSnapshot.apply(world, resume["world"])
		if err != "":
			return err
		WandMigration.run(world)  # v0.6.5 WN5b: a save that still holds retired v0.6 cards
	saves.begin_floor(world, run, _stage_seed, resume.get("rooms", PackedByteArray()))
	_tweaked_run_check()
	if resume.is_empty() and arena_def == null:  # v0.8.0 FB1: the final arena isn't a Codex biome
		codex_recorder.enter_biome(biome.id)  # v0.7.5 CX: a visit (not when Continue resumes the floor)
	driver = SimDriver.new()
	driver.name = "SimDriver"
	driver.setup(world)
	add_child(driver)
	view = WorldViewRoot.new()
	view.name = "WorldView"
	view.stage.prop_style = biome.id
	view.stage.mood = biome.mood  # v0.5.9: the biome's lighting mood
	view.stage.look = biome.look  # v0.7.5 NB1: the biome's own dressing and edge (null: the hand-written look)
	if biome.look != null:
		view.actors.enemy_tint = biome.look.enemy_tint
	_biome_path = biome.resource_path
	view.stage.lighting = GameSettings.get_value(profile, "lighting")
	add_child(view)
	# The boss room makes the floor's bounds lopsided; props scatter over a square centred on the origin.
	var b := driver.reader.floor_bounds()
	var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
	view.setup(driver.reader, biome.palette, half + 4.0)
	view.rig.shake_enabled = GameSettings.get_value(profile, "shake") == "on"
	view.ink.set_style(InkPass.style_from_setting(GameSettings.get_value(profile, "outline")))
	var player_input := PlayerInput.new(view.rig, driver.reader)
	player_input.name = "PlayerInput"
	view.add_child(player_input)
	driver.input_source = player_input.sample
	driver.ticked.connect(view.sync)
	codex_recorder.attach(driver.reader)  # v0.7.5 CX: the Codex reads every tick (after the save's entry check)
	achievement_tracker.attach(driver.reader)  # v0.7.5 AC: and the achievements
	audio.attach(driver.reader, biome.id)
	driver.ticked.connect(audio.sync.bind(driver.reader))
	_hud = Hud.new()
	_hud.minimap.state.preset = saves.rooms.duplicate()  # v0.4.0 SV: the rooms already entered
	ui.add_child(_hud)
	ui.move_child(_hud, 0)
	_hud.pick_panel().picked.connect(driver.latch.note_pick)  # Rewards: a pick is input.
	_hud.shop.panel.picked.connect(driver.latch.note_pick)  # v0.5.0 SH: so is a shop action.
	_hud.swap.picked.connect(driver.latch.note_pick)  # v0.6.0 MX2: so is a swap answer.
	_hud.swap.moved.connect(driver.latch.queue_wand_move)  # v0.6.5 WN2: and its reorders and inserts.
	_hud.sync(driver.reader)
	_hud.show_floor(
		run.floor_index,
		String(biome.name_key),
		run.is_deep(),  # v0.5.0 RT: "Floor 2 · Deep"
		driver.reader.shards_left_behind() if resume.is_empty() else 0,  # v0.5.5 EC (Q-S4)
		run.loop  # v0.7.5 AP: "Loop 2 · Floor 1"
	)
	_ended_ticks = 0
	driver.ticked.connect(_on_tick.bind(driver))
	_fade_len = FADE_SECONDS if run.run_floor() == 1 else ARRIVAL_FADE_SECONDS
	_fade_left = _fade_len
	_fade.color.a = 1.0
	_fade.visible = true
	ui.move_child(_fade, ui.get_child_count() - 1)
	ui.move_child(hints, ui.get_child_count() - 1)  # v0.7.5 SM: the hints read over the fade-in too
	ui.move_child(toast, ui.get_child_count() - 1)  # v0.7.5 AC: a toast reads over the fade-in
	hints.begin_floor(run.floor_index, driver.reader)  # v0.7.5 SM
	return ""


func _on_tick(from: SimDriver) -> void:
	if from != driver or _hud == null:
		return  # a stage that already ended, ticking once more before it's freed
	saves.after_tick(driver.world, run, _stage_seed)  # v0.4.0 SV: a first entry into a room saves
	codex_recorder.observe(driver.reader)  # v0.7.5 CX
	achievement_tracker.observe(driver.reader)  # v0.7.5 AC
	_hud.sync(driver.reader)
	hints.observe(driver.reader)  # v0.7.5 SM
	var outcome := driver.reader.outcome()
	if outcome == 3 and _end == null:
		_next_floor()
		return
	if outcome == 0 or _end != null:
		return
	if _ended_ticks == 0:
		saves.discard()  # v0.4.0 SV: a death or a win ends the run's save
	_ended_ticks += 1
	if _ended_ticks >= END_PANEL_DELAY_TICKS:
		show_end_panel(outcome == 1)


## The run's portal was taken: carry over, then the next floor (with its card and a fade-in). v0.7.5 AP: through the
## Ascension portal's Ascend the next floor is the next loop's first, and the Codex counts it (_record_ascension).
func _next_floor() -> void:
	var ascended := driver.reader.ascension_choice() == WorldReader.ASCEND_ASCEND
	run.finish_floor(driver.world)
	if ascended:
		_record_ascension(run.loop)
	_end_floor()
	_start_floor()


## A floor of the run (FloorScenario): its boss drawn from the floor's pool, its room, the floor's tables and its shop.
func _floor_world(
	repo: ContentRepository,
	p_run: RunState,
	table: PlayerTable,
	enemies: Array[EnemyTable],
	bosses: Array[BossTable]
) -> World:
	var boss := p_run.pick_boss(ContentCompiler.compile_boss_pool(repo, p_run.floor_index))
	var arena := RunSaver.boss_arena(p_run, bosses, boss)  # v0.7.5 BF1 (N18): an older save's room
	var rules := RunSaver.floor_tables(p_run, repo)  # v0.7.5 MG: map, arenas, shop (v0.7.0's on an old save's)
	var world := FloorScenario.build(
		p_run.floor_seed(),
		table,
		enemies,
		ContentCompiler.compile_floor_spawning(repo, p_run.floor_index),  # v0.4.0 TU: with the floor's curve
		ContentCompiler.compile_items(repo),
		ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor")),  # v0.3.0 E: altars, chests, shards.
		p_run.floor_index,
		arena,
		p_run,
		ContentCompiler.compile_combos(repo),  # v0.3.0 G: named combos.
		ContentCompiler.compile_gamble(repo.get_def(&"gamble", &"shrine")),  # v0.3.0 L19: the gamble shrine.
		rules[&"arena"],  # v0.5.5 AR: the sealed arenas
		rules[&"map"]  # v0.7.5 MG: rooms, footprints (N9)
	)
	FloorScenario.add_shop(world, rules[&"shop"])  # v0.5.0 SH; v0.7.5 MG: every two floors (N12)
	return world


## v0.7.5 AP: the Ascension counters for the achievements (AC) in the Codex's profile section, through its counter API
## (docs/roadmap/v0.7.5/evidence/ASCENSION.md): `runs` / `ascended` / `times` counts every Ascend, `runs` / `loop` /
## `best` keeps the highest loop reached. A tweaked run (the dev panel's balance edits) records nothing, as the Codex.
func _record_ascension(loop: int) -> void:
	if codex == null or (codex_recorder != null and not codex_recorder.enabled):
		return
	codex.add(ASCENSION_PAGE, &"ascended", &"times")
	codex.raise_to(ASCENSION_PAGE, &"loop", &"best", loop)
	if achievement_tracker != null:  # v0.7.5 AC: the Ascension achievements count each Ascend
		achievement_tracker.report(&"runs:ascended")


func show_end_panel(won: bool) -> void:
	close_pause()
	hints.set_covered(true)  # v0.7.5 SM: the recap is over the game
	_end = EndPanel.new(
		won, driver.reader.killer_kind(), driver.reader.killer_cause_key(), run_recap()
	)
	_end.restart_pressed.connect(restart)
	_end.main_menu_pressed.connect(show_main_menu)
	ui.add_child(_end)
	_end.focus_first()


## The run recap's numbers (EndPanel): floor reached, run time and kills over every floor, shards when the world
## counts them, and the items held.
func run_recap() -> Dictionary:
	if run == null or driver == null:
		return {}
	var w := driver.world
	var names: Array[String] = []
	for idx in driver.reader.items_owned():
		names.append(String(driver.reader.item_name_key(idx)))
	var out := {
		"floor": run.floor_index,
		"floors": run.table.floors,
		"seconds": float(run.total_ticks(w)) / SimTick.TICKS_PER_SECOND,
		"kills": run.total_kills(w),
		"items": names,
		"routes": run.routes.duplicate(),  # v0.5.0 RT: the route of each floor reached
		"loop": run.loop,  # v0.7.5 AP: the loop reached and the loops cleared
		"loops_cleared": run.loops_cleared(w),
		"true_ending": run.final_fight and driver.reader.final_won(),  # v0.8.0 FB1: the final boss beaten
		"final_reached": run.final_fight,
	}
	if &"shards" in w:
		out["shards"] = int(w.get(&"shards"))
	out["threat"] = driver.reader.threat()  # v0.5.0 EV: threat T now, and the run's peak
	out["threat_peak"] = driver.reader.threat_peak()
	return out


## The current floor's biome id.
func run_biome_id() -> StringName:
	return _run_biomes[run.biome_of()] if run != null else &""


## A new run with the next seed and the same build.
func restart() -> void:
	if playground != null:  # v0.7.5 PG: the pause menu's Restart rebuilds the room
		_end_stage()
		_start_playground(_pg_build, _pg_biome)
		return
	_stage_seed += 1
	_end_stage()
	start_stage()


func toggle_dev_panel() -> void:
	if _dev != null:
		_dev.queue_free()
		_dev = null
		driver.debug = null
		return
	driver.debug = DebugApi.new(driver.world)
	driver.debug.reseed_requested.connect(_reseed)
	_dev = DevPanel.new(driver.debug)
	ui.add_child(_dev)


## Opens or closes the master dev panel (F10). In a run it pauses the sim and carries the debug tools.
func _toggle_master_panel() -> void:
	if _devm != null:
		_close_master_panel()
		return
	var tools: Control = null
	if driver != null:
		if driver.debug == null:
			driver.debug = DebugApi.new(driver.world)
			driver.debug.reseed_requested.connect(_reseed)
		tools = DevPanel.new(driver.debug)
		driver.paused = true
	_devm = DevMasterPanel.new(tuning, tools)
	_devm.changed.connect(_on_tuning_changed)
	_devm.restart_requested.connect(_restart_floor)
	_devm.close_requested.connect(_close_master_panel)
	ui.add_child(_devm)


func _close_master_panel() -> void:
	if _devm != null:
		_drop(_devm)
		_devm = null
	if _balance_pending and driver != null and run != null:  # Step 4: balance edits go live as the run resumes
		LiveTuning.apply(driver.world, run, _content())
	_balance_pending = false
	_tweaked_run_check()
	_sync_pause()


## Rebuilds the run's current floor from the (tweaked) content: the dev panel's Restart floor.
func _restart_floor() -> void:
	if run == null:
		return
	_balance_pending = false  # the rebuilt floor reads everything anyway
	_close_master_panel()
	_end_floor()
	_start_floor()


## Step 5 (owner: tweaked runs don't count): while any balance value is off the shipped game the run has no save
## (Continue can't resume it) and a DEV mark shows. Unlocks and records, when they come, check tuning the same way.
func _tweaked_run_check() -> void:
	var tweaked := tuning.balance_tweaked()
	if tweaked and run != null:
		saves.discard()
	if codex_recorder != null:
		codex_recorder.enabled = not tweaked  # v0.7.5 CX: a tweaked run fills no Codex
	if achievement_tracker != null:
		achievement_tracker.enabled = not tweaked  # v0.7.5 AC: and unlocks no achievement
	if _dev_mark == null:
		_dev_mark = Label.new()
		_dev_mark.name = "DevMark"
		_dev_mark.text = "UI_DEVM_MARK"
		_dev_mark.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
		_dev_mark.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_dev_mark.position.y = 4
		_dev_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(_dev_mark)
	_dev_mark.visible = tweaked


## A dev panel edit: applied live where it can be (Steps 3-4 of docs/tools/DEV_PANEL.md); the rest waits for the
## next spawns or Restart floor.
func _on_tuning_changed(key: String) -> void:
	if DevTuning.is_lighting(key) and view != null and _biome_path != "":  # Step 3: live
		# The store writes into the loaded biome it holds; the stage takes that biome's mood and re-applies it.
		view.stage.mood = (load(_biome_path) as BiomeDefinition).mood
		view.stage.apply_mood()
		view.actors.retune_hero_light(view.stage.mood)
	elif not DevTuning.is_lighting(key):
		_balance_pending = true


func is_dev_panel_open() -> bool:
	return _dev != null


func _reseed(seed_value: int) -> void:
	_stage_seed = seed_value
	_end_stage()
	start_stage()


func open_pause() -> void:
	driver.paused = true
	hints.set_covered(true)  # v0.7.5 SM: a hint waits under the pause menu
	_pause = PauseMenu.new()
	_pause.resume_pressed.connect(close_pause)
	_pause.options_pressed.connect(open_pause_options)
	_pause.build_pressed.connect(_open_pause_build)
	_pause.codex_pressed.connect(_open_pause_codex)
	_pause.restart_pressed.connect(restart)
	_pause.main_menu_pressed.connect(show_main_menu)
	var recap := run_recap()  # v0.5.5 A5: the run's line under the pause list
	if not recap.is_empty():
		_pause.show_run(
			recap["floor"],
			recap["seconds"],
			recap["kills"],
			int(recap.get("shards", 0)),
			int(recap.get("loop", 1))  # v0.7.5 AP
		)
	if driver.reader.has_gamble():  # v0.3.0 L19: the stats won at the gamble shrine.
		var stats := GambleStatsPanel.new()
		_pause.add_child(stats)
		stats.place_top_right(84)
		stats.sync(driver.reader)
	if driver.reader.threat_peak() > 0:  # v0.5.0 EV: threat T and the curses held
		var threat := ThreatPanel.new()
		_pause.add_child(threat)
		threat.place_top_left(84)
		threat.sync(driver.reader)
	ui.add_child(_pause)
	_pause.focus_first()


func close_pause() -> void:
	if _pause_options != null:
		_pause_options.queue_free()
		_pause_options = null
	if _pause_build != null:
		_queue_build_moves()
		_pause_build.queue_free()
		_pause_build = null
	if _pause_codex != null:
		_pause_codex.queue_free()
		_pause_codex = null
	if _pause != null:
		_pause.queue_free()
		_pause = null
	if driver != null:
		driver.latch.drop_presses()  # v0.6.5 WN2: a click in a menu is not a swing once the game runs
		driver.paused = false
		_sync_pause()  # the master dev panel (F10) and the Playground's panel keep the run paused behind it
	if _end == null:
		hints.set_covered(false)  # v0.7.5 SM


## v0.6.5 WN2: the Build page (the wand's order) from the pause menu; the pause menu hides under it and comes back on
## Back. The page starts from the sim's wand with the moves still waiting in the latch applied (the page may open
## twice in one pause), and the sim gets its change as input when the page closes (_queue_build_moves).
func _open_pause_build() -> void:
	if _pause == null or _pause_build != null:
		return
	_pause.visible = false
	var wand := driver.reader.wand()
	for v in driver.latch.pending_picks():
		var n := v - WorldReader.PICK_WAND_MOVE_BASE
		if n >= 0 and n < WorldReader.WAND_MOVE_STRIDE * WorldReader.WAND_MOVE_STRIDE:
			wand = WorldReader.wand_moved(
				wand, n / WorldReader.WAND_MOVE_STRIDE, n % WorldReader.WAND_MOVE_STRIDE
			)
	_pause_build = BuildPage.new()
	_pause_build.back_pressed.connect(_close_pause_build)
	ui.add_child(_pause_build)
	_pause_build.open(wand, int(wand["slots"]))


func _close_pause_build() -> void:
	if _pause_build != null:
		_queue_build_moves()
		_pause_build.queue_free()
		_pause_build = null
	if _pause != null:
		_pause.visible = true
		(_pause.box.get_node("Build") as Button).grab_focus()


## v0.7.5 CX: the Codex from the pause menu, over the paused stage; the pause menu hides under it and comes back on
## Back. What this run has met is already in it (the recorder writes as the run goes).
func _open_pause_codex() -> void:
	if _pause == null or _pause_codex != null:
		return
	_pause.visible = false
	_pause_codex = CodexView.new(codex_catalog(), codex, _achievements_book())
	_pause_codex.back_pressed.connect(_close_pause_codex)
	ui.add_child(_pause_codex)
	_pause_codex.focus_first()


func _close_pause_codex() -> void:
	if _pause_codex != null:
		_pause_codex.queue_free()
		_pause_codex = null
	if _pause != null:
		_pause.visible = true
		(_pause.box.get_node("Codex") as Button).grab_focus()


## The Build page's change as wand moves, queued as input: the pause stops the ticks, so they reach the sim one per
## tick when the game runs again (EI-03, EI-04).
func _queue_build_moves() -> void:
	if driver == null or _pause_build == null:
		return
	for v in _pause_build.planned_moves():
		driver.latch.queue_wand_move(v)


## Holds the sim while a menu or panel is over it (the pause menu, F10, the Playground's panel), else lets it run.
func _sync_pause() -> void:
	if driver != null:
		driver.paused = (
			_pause != null or _devm != null or (playground != null and playground.is_panel_open())
		)


# --- v0.7.5 PG: the Playground (owner N20, docs/tools/PLAYGROUND.md) ------------------------------------------------


## Playground -> pick the weapon (as Play) -> the room.
func _show_playground_picker() -> void:
	var p := BuildPicker.new(ContentRepository.load_all().all_of(&"build"), _pg_build)
	p.picked.connect(func(id: StringName) -> void: _start_playground(id, _pg_biome))
	p.back_pressed.connect(show_main_menu)
	_set_menu(p)


## The Playground's room with weapon `build_id` in biome `biome_id`: no run, save, Codex, achievements or hints.
func _start_playground(build_id: StringName, biome_id: StringName) -> void:
	_set_menu(null)
	_end_stage()
	_pg_build = build_id
	_pg_biome = biome_id
	var repo := _content()
	var biome: BiomeDefinition = repo.get_def(&"biomes", biome_id)
	driver = SimDriver.new()
	driver.name = "SimDriver"
	driver.setup(PlaygroundScenario.build(repo, build_id, biome))
	add_child(driver)
	playground = PlaygroundSession.new(
		driver, ui, _playground_biomes(repo), biome_id, _playground_names(repo)
	)
	playground.on_pause_change = _sync_pause
	var run_table := PlaygroundScenario.final_run(repo)  # v0.8.0 FB1: the final boss's summon
	playground.api.final_shatter_ticks = run_table.final_shatter_ticks
	playground.api.final_name_key = run_table.final_name_key
	playground.biome_requested.connect(_set_playground_biome)
	playground.weapon_requested.connect(
		func() -> void:
			_end_stage()
			_show_playground_picker()
	)
	add_child(playground)
	_playground_view(biome)
	_hud = Hud.new()
	ui.add_child(_hud)
	ui.move_child(_hud, 0)
	_hud.sync(driver.reader)
	driver.ticked.connect(_on_playground_tick)
	driver.edited.connect(_on_playground_tick)
	_tweaked_run_check()


## Redraws the room in biome `id` (its look, light and sounds) and lays its ice or starglow; the build, the dummies
## and the spawns stay. The sim waits for this between ticks (the panel holds it, or it runs on the main thread).
func _set_playground_biome(id: StringName) -> void:
	if playground == null:
		return
	var biome: BiomeDefinition = _content().get_def(&"biomes", id)
	_pg_biome = id
	PlaygroundScenario.lay_surface(driver.world, biome)
	driver.ticked.disconnect(view.sync)
	driver.edited.disconnect(view.sync)
	_drop(view)
	_playground_view(biome)


func _playground_view(biome: BiomeDefinition) -> void:
	view = WorldViewRoot.new()
	view.name = "WorldView"
	view.stage.prop_style = biome.id
	view.stage.mood = biome.mood
	view.stage.look = biome.look
	if biome.look != null:
		view.actors.enemy_tint = biome.look.enemy_tint
	_biome_path = biome.resource_path
	view.stage.lighting = GameSettings.get_value(profile, "lighting")
	add_child(view)
	var b := driver.reader.floor_bounds()
	var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
	view.setup(driver.reader, biome.palette, half + 4.0)
	view.rig.shake_enabled = GameSettings.get_value(profile, "shake") == "on"
	view.ink.set_style(InkPass.style_from_setting(GameSettings.get_value(profile, "outline")))
	var player_input := PlayerInput.new(view.rig, driver.reader)
	player_input.name = "PlayerInput"
	view.add_child(player_input)
	driver.input_source = player_input.sample
	driver.ticked.connect(view.sync)
	driver.edited.connect(view.sync)
	audio.detach()
	audio.attach(driver.reader, biome.id)
	playground.set_biome(biome.id, player_input.mouse_world)


func _on_playground_tick() -> void:
	if _hud != null and driver != null:
		_hud.sync(driver.reader)


## The biomes the Playground offers: the run's, in its order, with their names.
func _playground_biomes(repo: ContentRepository) -> Array:
	var out := []
	var run_def: RunDefinition = repo.get_def(&"run", RUN_ID)
	for id: StringName in run_def.biomes:
		out.append(
			{"id": id, "name_key": (repo.get_def(&"biomes", id) as BiomeDefinition).name_key}
		)
	return out


## The DPS meter's source names: an effect id -> the name key of the card, ability, combo or curse with that id, and
## the statuses' own names.
static func _playground_names(repo: ContentRepository) -> Dictionary:
	var out := {
		&"bleed": &"UI_PG_SRC_BLEED",
		&"bleed_burst": &"UI_PG_SRC_BLEED",
		&"shock": &"UI_PG_SRC_SHOCK",
		&"frost": &"UI_PG_SRC_FROST",
		&"venom": &"UI_PG_SRC_POISON",
	}
	for cat: StringName in [&"items", &"ability", &"combos", &"curses"]:
		for d: Resource in repo.all_of(cat):
			if &"id" in d and &"name_key" in d and not out.has(d.get(&"id")):
				out[d.get(&"id")] = d.get(&"name_key")
	return out


func _set_menu(m: Control) -> void:
	if _menu != null:
		_menu.queue_free()
	_menu = m
	if m != null:
		ui.add_child(m)
		if m.has_method("focus_first"):
			m.call("focus_first")


func _end_stage() -> void:
	_end_floor()
	run = null


## Frees one floor's nodes (driver, view, HUD, panels); the run itself stays.
func _end_floor() -> void:
	close_pause()
	audio.detach()
	if codex_recorder != null:
		codex_recorder.detach()
	hints.end_floor()  # v0.7.5 SM
	hints.set_covered(false)
	if hint_store.dirty:  # v0.7.5 SM: the hints seen reach the file
		hint_store.dirty = not (profile.save_file() or profile.path.is_empty())
	if achievement_tracker != null:
		achievement_tracker.detach()
	if codex.dirty or achievements.dirty:  # v0.7.5 CX, AC: the floor's counts and unlocks reach the file
		var kept := profile.save_file() or profile.path.is_empty()
		codex.dirty = not kept
		achievements.dirty = not kept
	for n in [_hud, _end, _dev, _devm, playground, driver, view, get_node_or_null("Gallery")]:
		_drop(n)
	playground = null
	_hud = null
	_end = null
	_dev = null
	_devm = null
	driver = null
	view = null


## Takes a node out of the tree now and frees it at the end of the frame, so the next floor's nodes get their plain
## names (UI/Hud, SimDriver, WorldView) in the same frame.
static func _drop(n: Node) -> void:
	if n == null:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.queue_free()


## The content with the dev panel's overrides written in (none: the shipped game).
func _content() -> ContentRepository:
	tuning.apply()
	return ContentRepository.load_all()
