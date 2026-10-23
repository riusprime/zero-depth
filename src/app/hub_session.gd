class_name HubSession
extends Node
## v0.9.0 HB (owner Q27; HUB_MOCKUPS option A, the Rune Ring): the hub while it runs. The hero walks it with the normal
## controls on the run's own World rules (HubScenario, HubDriver: a deterministic World stepped at 60 Hz, walls and
## dash and all, no combat), HubView draws it, and this node tells which station the hero stands at (HubLayout) and
## sends the interact there. Why a World and not a scene of its own: the hero's walk, dash, collision and feel are the
## run's, from the one movement code, and the World is pure and holds nothing of a run; the stations are presentation
## reading the hero's position. The hub never touches a run's save (RunSaver never sees this World) and reads the
## profile only (HubFlags).
## The stations whose panels Main owns (the Portal Machine's build pick, the Codex, the achievements, the credits) go
## out as `station_used`; the stand-in panels (the Wardrobe, the Progression Station) and the hub's pause menu (Esc /
## Start: Resume, Options, Main menu) are this node's own (`overlay`).

signal station_used(id: StringName, panel: StringName)
signal options_requested
signal main_menu_requested

const HUB_ID := &"rune_ring"
## The light the hub is drawn in (its biome's mood and palette).
const BIOME := &"ruins"
## The stations whose panels are this node's own: the Wardrobe's (v0.9.0 RB, WardrobePanel) and the stand-in MP
## replaces.
const STAND_INS: Array[StringName] = [&"wardrobe", &"progression"]

var hub: HubDefinition
var layout: HubLayout
var flags: HubFlags
var driver: HubDriver
var view: HubView
var hud: HubHud
var ui: CanvasLayer
var player_input: PlayerInput
## The station the hero stands at now (&"": none).
var at := &""
## A panel or menu of Main's is over the hub (Main sets it), or one of this node's (`overlay`).
var held := false
var overlay: MenuPanel
## v0.9.0 HB2: the hero is walking into the portal (the hub holds; input is ignored but for a press that skips it).
var walking := false
## v0.9.0 RB: the content and the profile the Wardrobe reads and writes (its robe and affinity).
var repo: ContentRepository
var profile: ProfileStore
var _after_walk: Callable


## Builds the hub from the content and the profile (read only): `stores` = [CodexStore, AchievementStore,
## CodexCatalog].
func setup(
	p_repo: ContentRepository, p_profile: ProfileStore, stores: Array, p_ui: CanvasLayer
) -> void:
	name = "Hub"
	ui = p_ui
	repo = p_repo
	profile = p_profile
	hub = repo.get_def(&"hub", HUB_ID)
	flags = HubFlags.new(profile, stores[0], stores[1])
	var states := flags.states(hub)
	layout = HubLayout.new(hub, bool(states.get(&"gate_open", false)))
	driver = HubDriver.new()
	driver.name = "HubDriver"
	var build_id := StringName(profile.section("loadout").get("build", "blade"))
	driver.setup(HubScenario.build(repo, layout, build_id))
	add_child(driver)
	var bosses := (stores[2] as CodexCatalog).section_entries(&"bosses", &"bosses").map(
		func(e: Dictionary) -> StringName: return e["id"]
	)
	var biome: BiomeDefinition = repo.get_def(&"biomes", BIOME)
	view = HubView.new()
	add_child(view)
	var lighting := String(GameSettings.get_value(profile, "lighting"))
	view.setup(
		driver.reader,
		layout,
		states,
		flags.boss_trophies(bosses),
		biome.mood,
		biome.palette,
		lighting
	)
	view.set_look(look())  # v0.9.0 RB: the hero wears the Wardrobe's choice
	apply_settings(profile)
	player_input = PlayerInput.new(view.rig, driver.reader)
	player_input.name = "PlayerInput"
	view.add_child(player_input)
	driver.input_source = player_input.sample
	driver.ticked.connect(_on_tick)
	hud = HubHud.new()
	ui.add_child(hud)
	ui.move_child(hud, 0)
	_on_tick()


## The view's settings (the outline style and the lighting tier) from the profile, as Options changes them.
func apply_settings(profile: ProfileStore) -> void:
	view.ink.set_style(InkPass.style_from_setting(GameSettings.get_value(profile, "outline")))
	view.stage.set_lighting(GameSettings.get_value(profile, "lighting"))


func _on_tick() -> void:
	view.sync()
	at = layout.station_at(driver.reader.player_pos())
	view.focus(at)
	var keys := layout.keys_of(at)
	hud.show_station(keys[0], keys[1])


func _unhandled_input(event: InputEvent) -> void:
	if walking:  # v0.9.0 HB2: every input is the walk's; a press of interact or accept skips it
		get_viewport().set_input_as_handled()
		if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
			view.finish_walk()
		return
	if held or overlay != null:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		open_pause()
	elif at != &"" and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		var panel := layout.panel_of(at)
		if at in STAND_INS:
			_open_stand_in(at)
		else:
			station_used.emit(at, panel)


## v0.9.0 HB2 (owner: "click, choose weapon and then the character walks upstairs towards the portal and crosses it"):
## the weapon is picked; `before` (Main's: the build pick closes) runs, the hero walks up the machine's steps and
## through its ring (HubView.walk_into_portal, about 2-3 s, a press skips it), then `done` (Main's: the run's load
## behind the cover, as before). The hub holds through it all (the World doesn't step). Returns the walk's length (s).
func walk_into_portal(done: Callable, before: Callable = Callable()) -> float:
	walking = true
	_after_walk = done
	_sync_hold()
	if before.is_valid():
		before.call()
	view.walk_finished.connect(func() -> void: _after_walk.call(), CONNECT_ONE_SHOT)
	return view.walk_into_portal()


## Main's panel or menu over the hub (true) or gone; the hero holds while anything is over it.
func set_held(on: bool) -> void:
	held = on
	_sync_hold()


## The hub's pause menu: Resume, Options (Main's; its Back reopens this), Main menu.
func open_pause() -> void:
	var m := HubPauseMenu.new()
	m.resume_pressed.connect(close_overlay)
	m.options_pressed.connect(
		func() -> void:
			close_overlay()
			options_requested.emit()
	)
	m.main_menu_pressed.connect(func() -> void: main_menu_requested.emit())
	_show_overlay(m)


## v0.9.0 RB: the hero's look from the profile's Wardrobe choice (Wardrobe.look).
func look() -> Dictionary:
	return Wardrobe.look(
		repo, Wardrobe.worn_robe(repo, profile), Wardrobe.chosen_affinity(repo, profile)
	)


## v0.9.0 RB: the Wardrobe's panel; each pick is worn at once and kept in the profile (written when it closes).
func open_wardrobe() -> void:
	var robes := Wardrobe.robes(repo)
	var unlocked: Array[bool] = []
	for r: RobeDefinition in robes:
		unlocked.append(Wardrobe.robe_unlocked(profile, r))
	var p := WardrobePanel.new(
		robes,
		unlocked,
		Wardrobe.worn_robe(repo, profile).id,
		Wardrobe.affinities(repo),
		Wardrobe.chosen_affinity(repo, profile)
	)
	p.picked.connect(
		func(robe: StringName, affinity: StringName) -> void:
			Wardrobe.set_robe(profile, robe)
			Wardrobe.set_affinity(profile, affinity)
			view.set_look(look())
	)
	p.back_pressed.connect(
		func() -> void:
			profile.save_file()
			close_overlay()
	)
	_show_overlay(p)


## A stand-in station's panel (the Progression Station until MP; v0.9.0 RB: the Wardrobe has its own).
func _open_stand_in(id: StringName) -> void:
	if id == &"wardrobe":
		open_wardrobe()
		return
	var keys := layout.keys_of(id)
	var p := HubStationPanel.new(id, String(keys[0]), "HUB_%s_SOON" % String(id).to_upper())
	p.back_pressed.connect(close_overlay)
	_show_overlay(p)


func _show_overlay(m: MenuPanel) -> void:
	close_overlay()
	overlay = m
	ui.add_child(m)
	m.focus_first()
	_sync_hold()


func close_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null
	_sync_hold()


func _sync_hold() -> void:
	var on := held or overlay != null or walking
	driver.paused = on
	driver.latch.drop_presses()
	hud.visible = not on


## Frees what the hub put on the UI layer with it.
func _exit_tree() -> void:
	for n: Node in [hud, overlay]:
		if n != null and is_instance_valid(n):
			n.queue_free()
