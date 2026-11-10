class_name Main
extends Node
## Composition root (ARCHITECTURE §2): input map, profile, settings, then menus and stage; only app/ wires layers.

const STAGE_SEED := 20261006
const END_PANEL_DELAY_TICKS := 45
## Run flow: the run's data; the fade-in when a floor starts is the loading cover's.
const RUN_ID := RunSaver.RUN_ID  # Five floors
const FADE_SECONDS := 0.45
## A portal's cover opens on the new floor over this long (CoverLoads).
const PORTAL_UNVEIL_SECONDS := 0.55
## The Codex profile page the Ascension counters live on (_record_ascension; not a Codex page you browse).
const ASCENSION_PAGE := &"runs"

## How a new run's seed is picked (RunSeeds: random in the game; RunSeeds.AUTO resolves at boot;
## a seed >= 0 fixes the order on purpose: E2e.boot sets it before main.tscn boots).
static var fixed_seed := RunSeeds.AUTO
## A test-only switch, false in the game (E2e.boot sets it; nothing in src/
## does): Play opens the build pick (no hub), the pick starts the run at once, and floor 1's arrival runs in one frame.
static var quick_start := false

var profile: ProfileStore
var driver: SimDriver
var view: WorldViewRoot
var ui := CanvasLayer.new()
var fps_counter := FpsCounter.new()
## The run in progress (null outside one): floors, biome order, carry, totals. _stage_seed is its run seed.
var run: RunState
## Sounds, ambience and captions; it outlives floors so the ambience can crossfade.
var audio := AudioDirector.new()
## The run save (room entries, close, Continue).
var saves: RunSaver
## The Codex's counters (in the profile) and the recorder that reads each floor's ticks into them.
var codex: CodexStore
var codex_recorder: CodexRecorder
## The achievements (in the profile), the tracker that unlocks them from each floor's ticks and the Codex,
## and the toast that shows an unlock (on the UI layer, so it outlives a floor).
var achievements: AchievementStore
var achievement_tracker: AchievementTracker
var toast := AchievementToast.new()
## The first-run hints (seen ones in the profile's hints section), on the UI layer like the toast.
var hint_store: HintStore
var hints := OnboardingHints.new()
## Every floor load runs behind the loading cover (CoverLoads; it took over the fade-in).
var loads := CoverLoads.new()
## The Playground while it runs (null otherwise).
var playground: PlaygroundSession
## The hub while it runs (null otherwise: the menu, a run, the Playground).
var hub: HubSession
## The hub's Training Room while it runs (null otherwise).
var training: TrainingSession
## The play recorder (`-- --perf-log` or `--perf-log=light`, docs/process/PERF_LOG.md); null without the flag.
var perf: PerfRecorder
## The dev panel's tuning (docs/tools/DEV_PANEL.md): the owner's saved overrides, put in the content before compiling.
## A build with the panel locked (DevGate) ignores any tuning file left on the PC.
var tuning := DevTuning.load_saved() if DevGate.enabled() else DevTuning.new()
var _menu: Control
var _pause: PauseMenu
## Options opened from the pause menu, over the paused stage.
var _pause_options: OptionsMenu
## The Build page opened from the pause menu, over the paused stage.
var _pause_build: BuildPage
## The Codex opened from the pause menu, and its catalog (from the content, built on first use).
var _pause_codex: CodexView
var _codex_catalog: CodexCatalog
var _achievement_book: AchievementBook
var _dev: DevPanel
## God, ticked in the dev panel, carried to the run's next floor (owner, 2026-11-10: "until you untick it").
var _god_kept := false
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
var _seeds: RunSeeds
var _run_biomes: Array[StringName] = []
var _pg_build := &"gun"  # The Playground weapon and biome (kept across Restart)
var _pg_biome := &"ruins"


func _ready() -> void:
	UserDirMigration.run_for_user_dir()  # Carry the saves over from the pre-name folder
	get_tree().set_auto_accept_quit(false)
	_seeds = RunSeeds.new(RunSeeds.resolve(fixed_seed, STAGE_SEED))  # v0.8.0 N1
	_stage_seed = _seeds.mode if _seeds.mode >= 0 else STAGE_SEED
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
	ViewPrefs.apply_settings(profile)  # Reduced motion, colour-blind palette
	ui.name = "UI"
	add_child(ui)
	ui.add_child(loads.cover)  # v0.8.0 N3
	ui.add_child(toast)  # v0.7.5 AC
	# A toast waits while a load's cover is shut; and through the floor's arrival.
	toast.hold = func() -> bool:
		return loads.cover.shut() or (driver != null and driver.reader.arriving())
	hint_store = HintStore.new(profile)  # v0.7.5 SM
	hints.setup(hint_store)
	ui.add_child(hints)
	add_child(GameCursor.new())  # The cursor
	add_child(fps_counter)
	fps_counter.apply(profile)
	PackFxSessionWarm.start(self)  # v0.10.0 VX-W: the VFX pack warms up behind the menu
	show_main_menu()
	var perf_mode := PerfRecorder.mode_of(OS.get_cmdline_user_args())
	if perf_mode != "":
		perf = PerfRecorder.attach(self, perf_mode == "full")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		saves.close()  # The last room entry is on disk
		profile.save_file()
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	# Not while a load builds a floor behind the cover.
	if (  # the master dev panel (docs/tools/DEV_PANEL.md): every build, anywhere
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_F10
		and DevGate.enabled()
		and not loads.busy()
	):  # One switch locks it for a public release (ROADMAP §0.4)
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
		and not driver.reader.event_open()  # So does an event panel's
		and not driver.reader.shop_open()  # So does the shop's
		and not driver.reader.swapping()  # So does the swap's skip
		and not (training != null and training.is_panel_open())  # The terminal's own
		and event.is_action_pressed(&"pause")
	):
		get_viewport().set_input_as_handled()
		if _pause == null:
			open_pause()
		else:
			close_pause()


func is_playing() -> bool:
	return driver != null


## The small menu: Continue (the saved run, straight in), Play (the hub), Options, Quit.
func show_main_menu() -> void:
	saves.close()  # Leaving a run (pause -> Main menu) keeps its last room entry
	_end_stage()
	_end_hub()
	loads.cover.unveil(FADE_SECONDS)  # A cover left up by a run that was left (none: nothing)
	audio.set_ambience(&"")
	var m := MainMenu.new(GameVersion.label(), not saves.usable().is_empty(), saves.take_refused())
	m.continue_pressed.connect(
		func() -> void: loads.behind(get_tree(), ui, _covered_continue, FADE_SECONDS)  # v0.8.0 N3
	)
	m.play_pressed.connect(show_build_picker if quick_start else _show_hub)  # Tests only
	m.options_pressed.connect(show_options)
	m.credits_pressed.connect(show_credits)  # The Credits moved from the hub to the menu
	m.quit_pressed.connect(
		func() -> void: get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	)
	_set_menu(m)


## The hub, from Play, the end panel or the pause menu (HubFlow.open).
func _show_hub() -> void:
	HubFlow.open(self)


func _close_station() -> void:
	_set_menu(null)


func _end_hub() -> void:
	if hub != null:
		_drop(hub)
		hub = null


## The hub's Portal Machine -> pick the build (Blade or Gun) -> the run. The pick is
## remembered in the profile; the build is the run's (RunState.build_id) and holds on every floor. no
## utility pick; Blink and Aegis are ability cards found in the run.
func show_build_picker() -> void:
	var defs := ContentRepository.load_all().all_of(&"build")
	var last := Wardrobe.build_of(profile)  # The Gun while the Blade is locked
	var p := BuildPicker.new(defs, last, SwordLock.locked_builds(profile))
	p.picked.connect(
		func(id: StringName) -> void:
			profile.section("loadout")["build"] = String(id)
			_stage_seed = _seeds.next()  # Every new run its own seed
			var go := func() -> void: loads.behind(get_tree(), ui, _covered_start, FADE_SECONDS)  # N3
			if hub == null:
				go.call()
			else:  # The hero walks up the machine's steps into the portal first
				hub.walk_into_portal(go, _set_menu.bind(null))
	)
	p.back_pressed.connect(_close_station if hub != null else show_main_menu)
	_set_menu(p)


## Options from the main menu, or from the hub's pause: `back` (null: the main menu).
func show_options(back: Callable = Callable()) -> void:
	var o := OptionsMenu.new(profile)
	o.back_pressed.connect(
		func() -> void:
			_set_menu(null)
			(back if back.is_valid() else show_main_menu).call()
	)
	o.setting_changed.connect(_on_setting_changed)
	_set_menu(o)


## Options from the pause menu: the pause menu hides under it and comes back on Back.
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
	fps_counter.apply(profile)
	ViewPrefs.apply_settings(profile)
	if hub != null:  # Options from the hub's pause
		hub.apply_settings(profile)
	if view != null:
		view.rig.shake_enabled = GameSettings.get_value(profile, "shake") == "on"
		view.ink.set_style(InkPass.style_from_setting(GameSettings.get_value(profile, "outline")))
		view.stage.set_lighting(GameSettings.get_value(profile, "lighting"))


func show_credits() -> void:
	var repo := ContentRepository.load_all()
	var credits: CreditsDefinition = repo.get_def(&"credits", &"main")
	var c := CreditsView.new(credits, repo.get_def(&"licences", &"generated"))  # With the licence list
	c.back_pressed.connect(_close_station if hub != null else show_main_menu)  # The Credits stone
	_set_menu(c)


## The Codex; with the Achievements page. from the hub's Rune Archive (`page` empty)
## and its Trophy Area (`page` the Achievements); Back returns to the hub (the main menu when no hub runs: the tools).
func show_codex(page: StringName = &"") -> void:
	var c := CodexView.new(codex_catalog(), codex, _achievements_book())
	c.back_pressed.connect(_close_station if hub != null else show_main_menu)
	if page != &"":
		c.start_on(page)
	_set_menu(c)


## The Codex's entries, read from the shipped content once (CodexCatalog).
func codex_catalog(repo: ContentRepository = null) -> CodexCatalog:
	if _codex_catalog == null:
		_codex_catalog = CodexCatalog.build(repo if repo != null else ContentRepository.load_all())
	return _codex_catalog


## Every achievement (the content's definitions, the Codex's per-boss and per-biome entries), built once.
func _achievements_book(repo: ContentRepository = null) -> AchievementBook:
	if _achievement_book == null:
		if repo == null:
			repo = ContentRepository.load_all()
		_achievement_book = AchievementBook.build(repo, achievements, codex, codex_catalog(repo))
	return _achievement_book


func show_gallery() -> void:
	_close_master_panel()
	_end_hub()
	_set_menu(null)
	var g := Gallery.new()
	g.name = "Gallery"
	add_child(g)
	g.setup(&"ruins", 35.26, true)


## Starts a run with the run seed _stage_seed, on its first floor, all in this frame (the tools and the
## tests; the game's Play builds it behind the cover over frames: _covered_start).
func start_stage() -> void:
	_end_hub()
	_set_menu(null)
	var plan := _new_run_plan()
	plan.repo = _content()
	plan.build()
	_adopt_run(plan)
	_open_floor_now(plan)


## Continue resumes the saved run at its last room entry. A save that doesn't fit is set aside.
func continue_run() -> void:
	var save := _usable_save()
	if save.is_empty():
		return
	_end_hub()
	_set_menu(null)
	var plan := FloorPlan.continued(RUN_ID, save, ViewPrefs.reduced_motion)
	plan.repo = _content()
	plan.build()
	_adopt_run(plan)
	if plan.err != "":
		saves.refuse(plan.err)
		show_main_menu()
		return
	_open_floor_now(plan)


## Builds the run's current floor: its seed, biome and enemy scaling from the run, the carry applied. `resume`: a
## save's payload, whose world snapshot is then written into the fresh floor; returns why it didn't fit. All
## in this frame (the dev panel's Restart floor, the tools); a portal builds the next floor over frames (_next_floor).
func _start_floor(repo: ContentRepository = null, resume: Dictionary = {}) -> String:
	var plan := FloorPlan.next_floor(run, _run_biomes, resume, ViewPrefs.reduced_motion)
	plan.repo = repo if repo != null else _content()
	plan.build()
	if plan.err != "":
		return plan.err
	_open_floor_now(plan)
	return ""


## The loads
## behind the cover. The World is built on a worker thread (FloorPlan.build, CoverLoads.on_worker) and the view in
## slices of a few milliseconds a frame (CoverLoads.build_view), so the cover and its mark move on every frame;
## the same FloorPlan and the same view jobs as the one-frame build above, so the floor is the same. Play, Continue
## and Restart run it through _covered_start / _covered_continue / _covered_restart, a portal through _next_floor.
## The plan built on a worker, then the floor's nodes over frames; returns why a save didn't fit.
func _load_plan(plan: FloorPlan) -> String:
	tuning.apply()  # the dev panel's overrides written into the content here, on the main thread (_content)
	await loads.on_worker(get_tree(), plan.build, "world")
	if plan.mode != FloorPlan.Mode.FLOOR:
		_adopt_run(plan)
	if plan.err != "":
		return plan.err
	await loads.prebuild_view(get_tree())  # The view's parts a few a frame, so its frame holds none
	var nodes := _floor_nodes(plan)
	await loads.build_view(get_tree(), nodes["queue"])
	_floor_live(nodes)
	return ""


func _usable_save() -> Dictionary:
	var save := saves.usable()
	if save.is_empty():  # None, or refused: the menu says so
		show_main_menu()
	return save


func _new_run_plan() -> FloorPlan:
	return FloorPlan.of_profile(RUN_ID, _stage_seed, profile, ViewPrefs.reduced_motion)  # v0.9.0 RB


## A new or continued run's plan made the run: it is Main's now.
func _adopt_run(plan: FloorPlan) -> void:
	run = plan.run
	_run_biomes = plan.run_biomes
	_stage_seed = plan.stage_seed


func _open_floor_now(plan: FloorPlan) -> void:
	var nodes := _floor_nodes(plan)
	(nodes["queue"] as ViewBuildQueue).run_all()
	_floor_live(nodes)


## The floor's first half on the main thread: the save's room entry, the Codex's visit, the driver (not stepping
## yet) and the view, added but not processing, its build queued (ViewBuildQueue).
func _floor_nodes(plan: FloorPlan) -> Dictionary:
	var repo := plan.repo
	if codex_recorder == null:  # Built on the first floor, from the content already loaded
		codex_recorder = CodexRecorder.new(codex, codex_catalog(repo))
	if achievement_tracker == null:  # Before the biome's visit, so its Codex write is heard
		achievement_tracker = AchievementTracker.new(_achievements_book(repo))
		achievement_tracker.achieved.connect(toast.push)
	var world := plan.world
	var biome := plan.biome
	var resume := plan.resume
	saves.begin_floor(world, run, _stage_seed, resume.get("rooms", PackedByteArray()))
	_tweaked_run_check()
	if resume.is_empty() and plan.arena_def == null:  # The final arena isn't a Codex biome
		codex_recorder.enter_biome(biome.id)  # A visit (not when Continue resumes the floor)
	var d := SimDriver.new()
	d.name = "SimDriver"
	d.setup(world)
	if _god_kept:  # God, ticked on an earlier floor of this run, carries on
		d.debug = DebugApi.new(world)
		d.debug.god = true
		d.debug.reseed_requested.connect(_reseed)
	d.hold = loads.cover.showing  # The arrival starts once the loading cover opened
	d.rush_arrival = quick_start and plan.mode == FloorPlan.Mode.NEW_RUN  # Tests only
	var v := WorldViewRoot.new()
	v.name = "WorldView"
	v.stage.prop_style = biome.id
	v.stage.mood = biome.mood  # The biome's lighting mood
	v.stage.look = biome.look  # The biome's own dressing and edge (null: the hand-written look)
	if biome.look != null:
		v.actors.enemy_tint = biome.look.enemy_tint
	v.actors.hero_look = Wardrobe.hero_look(repo, profile, run.affinity)  # Robe and locked rune
	v.heart_lines = repo.get_def(&"runic_lines", &"main") as RunicLinesDefinition  # The heart room's runes
	_biome_path = biome.resource_path
	v.stage.lighting = GameSettings.get_value(profile, "lighting")
	v.process_mode = Node.PROCESS_MODE_DISABLED  # Nothing in it runs until it is built (_floor_live),
	v.visible = false  # and the renderer draws none of it under the closed cover
	add_child(v)
	# The boss room makes the floor's bounds lopsided; props scatter over a square centred on the origin.
	var b := d.reader.floor_bounds()
	var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
	var q := ViewBuildQueue.new()
	v.queue_setup(q, d.reader, biome.palette, half + 4.0)
	return {"plan": plan, "driver": d, "view": v, "queue": q, "biome": biome}


## The floor's second half, once its view is built: the driver steps, input, the HUD, the cover opens.
func _floor_live(nodes: Dictionary) -> void:
	var plan: FloorPlan = nodes["plan"]
	var biome: BiomeDefinition = nodes["biome"]
	var resume := plan.resume
	driver = nodes["driver"]
	view = nodes["view"]
	add_child(driver)
	move_child(driver, view.get_index())  # before the view, as when both were added in one frame
	view.process_mode = Node.PROCESS_MODE_INHERIT
	view.visible = true
	view.rig.shake_enabled = GameSettings.get_value(profile, "shake") == "on"
	view.ink.set_style(InkPass.style_from_setting(GameSettings.get_value(profile, "outline")))
	var player_input := PlayerInput.new(view.rig, driver.reader, AimAssist.make(plan.repo, profile))
	player_input.name = "PlayerInput"
	view.add_child(player_input)
	driver.input_source = player_input.sample
	driver.frame_ticked.connect(view.sync)  # The views sync once a frame, on the latest tick
	driver.ticked.connect(view.note_tick)  # and keep what lasts one tick (ViewTickNotes)
	codex_recorder.attach(driver.reader)  # The Codex reads every tick (after the save's entry check)
	achievement_tracker.attach(driver.reader)  # And the achievements
	audio.attach(driver.reader, biome.id)
	driver.ticked.connect(audio.sync.bind(driver.reader))
	_hud = Hud.new()
	_hud.minimap.state.preset = saves.rooms.duplicate()  # The rooms already entered
	ui.add_child(_hud)
	ui.move_child(_hud, 0)
	hints.stack_under = _hud.phase_hud  # A top hint sits under the phase lines
	# Rewards: a pick is input; so is a shop action, a swap answer, a Constellation (W3-P10c)
	for p: ModalPanel in [_hud.pick_panel(), _hud.shop.panel, _hud.swap, _hud.constellation]:
		p.picked.connect(driver.latch.note_pick)
	_hud.swap.moved.connect(driver.latch.queue_wand_move)  # And its reorders and inserts.
	_hud.sync(driver.reader)
	_hud.show_floor(
		run.floor_index,
		String(biome.name_key),
		run.is_deep(),  # "Floor 2 · Deep"
		driver.reader.shards_left_behind() if resume.is_empty() else 0,  # v0.5.5 EC (Q-S4)
		run.loop,  # "Loop 2 · Floor 1"
		RunCarry.hp_grown(run) if resume.is_empty() else 0,  # "Max HP +15"
		LoopRules.newest(run) if resume.is_empty() else &""  # "New rule: …"
	)
	_ended_ticks = 0
	driver.ticked.connect(_on_tick.bind(driver))
	driver.frame_ticked.connect(_on_frame.bind(driver))  # The HUD reads once a frame
	if not loads.cover.showing():  # The cover that hid the load fades or opens on the new floor
		loads.cover.cover_now(LoadingCover.Style.BLACK)
	var portal := loads.cover.style != LoadingCover.Style.BLACK
	loads.cover.unveil(PORTAL_UNVEIL_SECONDS if portal else FADE_SECONDS)
	ui.move_child(loads.cover, ui.get_child_count() - 1)
	ui.move_child(hints, ui.get_child_count() - 1)  # The hints read over the fade-in too
	ui.move_child(toast, ui.get_child_count() - 1)  # A toast reads over the fade-in
	hints.begin_floor(run.floor_index, driver.reader)  # v0.7.5 SM


## Once a rendered frame that ran a tick (SimDriver.frame_ticked), after the views: the HUD reads the
## latest tick (its pickups and DPS read the event log from their own cursors, so nothing between frames is lost).
func _on_frame(from: SimDriver) -> void:
	if from != driver or _hud == null:
		return
	_hud.sync(driver.reader)


func _on_tick(from: SimDriver) -> void:
	if from != driver or _hud == null:
		return  # a stage that already ended, ticking once more before it's freed
	saves.after_tick(driver.world, run, _stage_seed)  # A first entry into a room saves
	codex_recorder.observe(driver.reader)  # v0.7.5 CX
	MetaHooks.observe(self)  # The achievements; the collectibles taken, into the profile
	hints.observe(driver.reader)  # v0.7.5 SM
	var outcome := driver.reader.outcome()
	if _end == null:
		loads.closing(driver.reader)  # The portal's iris closes as the hero goes in
	if outcome == 3 and _end == null:
		loads.portal(get_tree(), ui, driver, _next_floor, func() -> bool: return driver != null)
		return
	if outcome == 0 or _end != null:
		return
	if _ended_ticks == 0:
		saves.discard()  # A death or a win ends the run's save
	_ended_ticks += 1
	if _ended_ticks >= END_PANEL_DELAY_TICKS:
		show_end_panel(outcome == 1)


## The run's portal was taken: carry over, then the next floor (with its card and a fade-in). through the
## Loop device (v0.8.0 P2; the Ascension portal's Ascend before it) the next floor is the next loop's first, and the
## Codex counts it (_record_ascension).
func _next_floor() -> void:
	var looped := driver.reader.ascension_choice() == WorldReader.ASCEND_LOOP
	MetaHooks.finish_floor(self)  # RunState.finish_floor, then the Purple Portal's unlock
	if looped:
		_record_ascension(run.loop)
	var from := Time.get_ticks_usec()
	_end_floor()
	loads.phases["end_floor"] = (Time.get_ticks_usec() - from) / 1000.0
	# Built over frames, the cover moving.
	await _load_plan(FloorPlan.next_floor(run, _run_biomes, {}, ViewPrefs.reduced_motion))


## The Ascension counters for the achievements (AC) in the Codex's profile section, through its counter API
## (docs/roadmap/v0.7.5/evidence/ASCENSION.md): `runs` / `ascended` / `times` counts every Ascend (every
## Loop device taken), `runs` / `loop` / `best` keeps the highest loop reached. A tweaked run (the dev panel's balance
## edits) records nothing, as the Codex.
func _record_ascension(loop: int) -> void:
	if codex == null or (codex_recorder != null and not codex_recorder.enabled):
		return
	codex.add(ASCENSION_PAGE, &"ascended", &"times")
	codex.raise_to(ASCENSION_PAGE, &"loop", &"best", loop)
	MetaHooks.record_loop(self, loop)  # v0.7.5 AC's count; loop achievements, records, robes


func show_end_panel(won: bool) -> void:
	close_pause()
	hints.set_covered(true)  # The recap is over the game
	_end = EndPanel.new(
		won, driver.reader.killer_kind(), driver.reader.killer_cause_key(), MetaHooks.recap(self)
	)
	_end.restart_pressed.connect(restart)
	_end.hub_pressed.connect(_show_hub)  # Restart in one press, or the hub
	ui.add_child(_end)
	_end.focus_first()


## The run recap's numbers (EndPanel; RunRecap).
func run_recap() -> Dictionary:
	return RunRecap.of(run, driver)


## The current floor's biome id.
func run_biome_id() -> StringName:
	return _run_biomes[run.biome_of()] if run != null else &""


## A new run with a new seed (random, or the next under a fixed mode), the same build, behind the cover.
func restart() -> void:
	if training != null:  # The Training Room's Restart resets the room
		TrainingFlow.reset(self, training.build_id)
		return
	if playground != null:  # The pause menu's Restart rebuilds the room
		_end_stage()
		_start_playground(_pg_build, _pg_biome)
		return
	close_pause()
	if driver != null:
		driver.paused = true  # the old run holds while the cover is up
	loads.behind(get_tree(), ui, _covered_restart, FADE_SECONDS)


## The loads CoverLoads runs behind its cover (Play, Continue, Restart).
func _covered_start() -> void:
	_end_hub()  # The Portal Machine's run starts behind the cover
	_set_menu(null)
	await _load_plan(_new_run_plan())


func _covered_continue() -> void:
	var save := _usable_save()
	if save.is_empty():
		return
	_end_hub()
	_set_menu(null)
	var err := await _load_plan(FloorPlan.continued(RUN_ID, save, ViewPrefs.reduced_motion))
	if err != "":
		saves.refuse(err)
		show_main_menu()


func _covered_restart() -> void:
	_stage_seed = _seeds.next()
	_end_stage()
	await _covered_start()


func toggle_dev_panel() -> void:
	if _dev != null:
		_dev.queue_free()
		_dev = null
		if driver.debug.god:  # God lasts until it is unticked (owner, 2026-11-10), not until the panel closes
			driver.debug.release()
		else:
			driver.debug = null
		return
	if driver.debug == null:  # else God is still on from an earlier visit: the panel shows it
		driver.debug = DebugApi.new(driver.world)
		driver.debug.reseed_requested.connect(_reseed)
	_dev = DevPanel.new(driver.debug)
	ui.add_child(_dev)


## Opens or closes the master dev panel. In a run it pauses the sim and carries the debug tools.
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
	_devm = DevMasterPanel.new(tuning, tools, driver == null)  # Playground off a run only
	_devm.changed.connect(_on_tuning_changed)
	_devm.playground_requested.connect(_open_playground_from_panel)
	_devm.galleries_requested.connect(show_gallery)  # Off the main menu, onto F10 (off a run)
	_devm.effects_gallery_requested.connect(EffectsGallery.open.bind(self))  # v0.10.5 W3-O12
	_devm.restart_requested.connect(_restart_floor)
	_devm.close_requested.connect(_close_master_panel)
	ui.add_child(_devm)
	_sync_pause()  # The hub holds under it


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
		codex_recorder.enabled = not tweaked  # A tweaked run fills no Codex
	if achievement_tracker != null:
		achievement_tracker.enabled = not tweaked  # And unlocks no achievement
	if _dev_mark == null:
		_dev_mark = DevMasterPanel.mark_label()
		ui.add_child(_dev_mark)
	_dev_mark.visible = tweaked


## A dev panel edit: live where it can be (docs/tools/DEV_PANEL.md Steps 3-4), else at the next spawns or floor restart.
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
	hints.set_covered(true)  # A hint waits under the pause menu
	_pause = PauseMenu.new(playground == null)  # A run leaves to the hub, the Playground to the menu
	_pause.resume_pressed.connect(close_pause)
	_pause.options_pressed.connect(open_pause_options)
	_pause.build_pressed.connect(_open_pause_build)
	_pause.codex_pressed.connect(_open_pause_codex)
	_pause.restart_pressed.connect(restart)
	_pause.main_menu_pressed.connect(show_main_menu)
	_pause.hub_pressed.connect(_show_hub)  # The run stays saved; Continue resumes it
	var recap := run_recap()  # The run's line under the pause list; the loop rules
	_pause.show_recap(recap, driver.reader)  # And the depths' answer, in one sentence (above ×1)
	if driver.reader.has_gamble():  # The stats won at the gamble shrine.
		var stats := GambleStatsPanel.new()
		_pause.add_child(stats)
		stats.place_top_right(84)
		stats.sync(driver.reader)
	if driver.reader.threat_peak() > 0:  # Threat T and the curses held
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
		driver.latch.drop_presses()  # A click in a menu is not a swing once the game runs
		driver.paused = false
		_sync_pause()  # the master dev panel and the Playground's panel keep the run paused behind it
	if _end == null:
		hints.set_covered(false)  # v0.7.5 SM


## The Build page (the wand's order) from the pause menu; the pause menu hides under it and comes back on
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
	_pause_build.open(wand, int(wand["slots"]), driver.reader)


func _close_pause_build() -> void:
	if _pause_build != null:
		_queue_build_moves()
		_pause_build.queue_free()
		_pause_build = null
	if _pause != null:
		_pause.visible = true
		(_pause.box.get_node("Build") as Button).grab_focus()


## The Codex from the pause menu, over the paused stage; the pause menu hides under it and comes back on
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
	if hub != null:  # v0.9.0 HB
		hub.set_held(_menu != null or _devm != null)
	if driver != null:
		driver.paused = (
			_pause != null
			or _devm != null
			or (playground != null and playground.is_panel_open())
			or (training != null and training.is_panel_open())
		)  # v0.10.5 O17


# --- v0.7.5 PG: the Playground (owner N20, docs/tools/PLAYGROUND.md) ------------------------------------------------


## F10's Playground button (off a run only)
## shuts the panel and opens the Playground's weapon pick.
func _open_playground_from_panel() -> void:
	_close_master_panel()
	if driver == null:
		_show_playground_picker()


## F10 -> Playground -> pick the weapon (as Play) -> the room.
func _show_playground_picker() -> void:
	var p := BuildPicker.new(ContentRepository.load_all().all_of(&"build"), _pg_build)
	p.picked.connect(func(id: StringName) -> void: _start_playground(id, _pg_biome))
	p.back_pressed.connect(show_main_menu)
	_set_menu(p)


## The Playground's room with weapon `build_id` in biome `biome_id`: no run, save, Codex, achievements or hints.
func _start_playground(build_id: StringName, biome_id: StringName) -> void:
	_end_hub()
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
		driver, ui, PlaygroundScenario.biomes(repo), biome_id, PlaygroundScenario.source_names(repo)
	)
	playground.on_pause_change = _sync_pause
	var run_table := PlaygroundScenario.final_run(repo)  # The final boss's summon
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
	driver.frame_ticked.connect(_on_playground_tick)  # The HUD reads once a frame
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
	driver.frame_ticked.disconnect(view.sync)
	driver.ticked.disconnect(view.note_tick)
	driver.edited.disconnect(view.sync)
	_drop(view)
	_playground_view(biome)


func _playground_view(biome: BiomeDefinition) -> void:
	var player_input := TrainingFlow.room_view(self, biome)
	playground.set_biome(biome.id, player_input.mouse_world)


func _on_playground_tick() -> void:
	if _hud != null and driver != null:
		_hud.sync(driver.reader)


func _set_menu(m: Control) -> void:
	if _menu != null:
		_menu.queue_free()
	_menu = m
	if m != null:
		ui.add_child(m)
		if m.has_method("focus_first"):
			m.call("focus_first")
	_sync_pause()  # The hub holds while a panel or menu is over it


func _end_stage() -> void:
	_end_floor()
	_god_kept = false  # a new run starts without it
	run = null


## Frees one floor's nodes (driver, view, HUD, panels); the run itself stays.
func _end_floor() -> void:
	_god_kept = driver != null and driver.debug != null and driver.debug.god
	close_pause()
	audio.detach()
	if codex_recorder != null:
		codex_recorder.detach()
	hints.end_floor()  # v0.7.5 SM
	hints.set_covered(false)
	if hint_store.dirty:  # The hints seen reach the file
		hint_store.dirty = not (profile.save_file() or profile.path.is_empty())
	if achievement_tracker != null:
		achievement_tracker.detach()
	if codex.dirty or achievements.dirty:  # v0.7.5 CX, AC: the floor's counts and unlocks reach the file
		var kept := profile.save_file() or profile.path.is_empty()
		codex.dirty = not kept
		achievements.dirty = not kept
	for n in [_hud, _end, _dev, _devm, playground, training, driver, get_node_or_null("Gallery")]:
		_drop(n)
	if view != null and loads.busy():  # Behind the cover, the old view is freed over frames
		view.get_parent().remove_child(view)
		loads.free_slowly(get_tree(), view)
	else:
		_drop(view)
	playground = null
	training = null
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
