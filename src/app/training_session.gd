class_name TrainingSession
extends Node
## v0.10.5 O17 (owner P17: "let's add a new room at the hub that serves this purpose, at the bottom that is empty, make
## it a bit smaller"): the Training Room while it runs. Main builds its World (TrainingScenario) and view and answers
## its weapon, reset and leave requests; this node holds the room's commands (PlaygroundApi, applied by SimDriver
## between ticks), the endless dummy in the middle, the DPS meter (the last 5 s), the prompt at the terminal and the
## exit pad (HubHud), and the terminal's panel (TrainingPanel; the sim waits while it, or the Build page from it, is
## open: Main.sync_pause). What the terminal offers is what the Codex has met (TrainingRoom). Nothing here is
## recorded: Main never attaches the run's Codex recorder, achievement tracker or save to this World.

signal leave_requested
signal weapon_requested(build_id: StringName)
signal reset_requested

var api: PlaygroundApi
var driver: SimDriver
var meter := DpsMeter.new()
var hud := HubHud.new()
var panel: TrainingPanel
var build_page: BuildPage
## The room's pieces in the view (Main sets them with the view).
var props: TrainingProps
var room: Rect2
var build_id := &""
## The hero stands at the terminal now.
var at_terminal := false
## Called when the panel opens or closes, so the owner of the pause (Main) can hold or release the sim.
var on_pause_change: Callable
var _codex: CodexStore
var _catalog: CodexCatalog
var _weapons: Array = []
var _ui: Node
var _leaving := false


## `weapons` [{id, name_key}] the builds the player may pick; `names` the DPS meter's source names.
func _init(
	p_driver: SimDriver,
	p_ui: Node,
	p_build: StringName,
	weapons: Array,
	codex: CodexStore,
	catalog: CodexCatalog,
	names: Dictionary
) -> void:
	name = "TrainingRoom"
	driver = p_driver
	_ui = p_ui
	build_id = p_build
	_weapons = weapons
	_codex = codex
	_catalog = catalog
	api = PlaygroundApi.new(driver.world)
	driver.playground = api
	room = TrainingScenario.room_of(driver.world)
	api.place_dummy_now(TrainingRoom.dummy_point(room))
	meter.names = names


func _ready() -> void:
	_ui.add_child(meter)
	_ui.move_child(meter, 0)
	hud.name = "TrainingHud"
	_ui.add_child(hud)
	var hint := hud.get_node("Hint") as Label
	hint.text = "UI_TRAINING_HINT"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(28, -44)
	driver.ticked.connect(_on_tick)
	driver.edited.connect(_on_edited)
	meter.sync(driver.reader)
	_on_tick()


func _exit_tree() -> void:
	for v: Variant in [meter, hud, panel, build_page]:
		if v != null and is_instance_valid(v):
			var n := v as Node
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.queue_free()
	panel = null
	build_page = null


func _unhandled_input(event: InputEvent) -> void:
	if build_page != null:
		return  # the Build page takes its own keys (its Back closes it)
	if panel != null:
		if event.is_action_pressed(&"pause"):
			get_viewport().set_input_as_handled()
			close_panel()
		return
	if at_terminal and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		open_panel()


func is_panel_open() -> bool:
	return panel != null or build_page != null


## The terminal's panel, from what the Codex has met.
func open_panel() -> void:
	if panel != null:
		return
	var enemies := TrainingRoom.known_enemies(api.enemy_choices(), _codex, _catalog)
	var cards := TrainingRoom.known_cards(api, _codex)
	panel = TrainingPanel.new(
		enemies, TrainingRoom.COUNTS, _weapons, build_id, cards, CardLevels.MAX_LEVEL
	)
	panel.spawn_requested.connect(spawn)
	panel.clear_requested.connect(clear)
	panel.weapon_picked.connect(func(id: StringName) -> void: weapon_requested.emit(id))
	panel.card_requested.connect(grant)
	panel.remove_card_requested.connect(remove_last_card)
	panel.order_requested.connect(open_build_page)
	panel.reset_requested.connect(func() -> void: reset_requested.emit())
	panel.back_pressed.connect(close_panel)
	_ui.add_child(panel)
	panel.focus_first()
	hud.visible = false
	_pause_changed()


func close_panel() -> void:
	if panel == null:
		return
	panel.get_parent().remove_child(panel)
	panel.queue_free()
	panel = null
	hud.visible = true
	driver.latch.drop_presses()  # a press on the panel is not a swing once the room runs
	_pause_changed()


## `count` enemies of `kind` on the ring round the dummy (a spot a wall takes is skipped).
func spawn(kind: int, count: int) -> void:
	api.queue(
		func() -> void:
			var n := 0
			for p in TrainingRoom.spawn_points(room, count):
				if api.place_enemy_now(kind, p):
					n += 1
			_status("UI_TRAINING_SPAWNED", str(n))
	)


func clear() -> void:
	api.queue(
		func() -> void:
			api.clear_now(false)
			_status("UI_TRAINING_CLEARED")
	)


## Wand card `code` at `level`; a full wand says so (remove a card first: no Swap here, as in the Playground).
func grant(code: int, level: int) -> void:
	api.queue(
		func() -> void:
			var key := &""
			for e in api.catalog():
				if int(e["code"]) == code:
					key = e["name_key"]
			if api.grant_now(code, level):
				_status("UI_TRAINING_CARD_ADDED", String(key))
			else:
				_status("UI_TRAINING_WAND_FULL")
	)


func remove_last_card() -> void:
	api.queue(
		func() -> void:
			var code := TrainingRoom.last_wand_card(api)
			if code >= 0 and api.remove_card_now(code):
				_status("UI_TRAINING_CARD_REMOVED")
			else:
				_status("UI_TRAINING_NO_CARD")
	)


## The Build page (the wand's order, as from the pause menu) over the room; its Back returns to the panel and the
## moves reach the sim as input once the room runs again (EI-04).
func open_build_page() -> void:
	if build_page != null:
		return
	if panel != null:
		panel.visible = false
	var wand := driver.reader.wand()
	for v in driver.latch.pending_picks():
		var n := v - WorldReader.PICK_WAND_MOVE_BASE
		if n >= 0 and n < WorldReader.WAND_MOVE_STRIDE * WorldReader.WAND_MOVE_STRIDE:
			wand = WorldReader.wand_moved(
				wand, n / WorldReader.WAND_MOVE_STRIDE, n % WorldReader.WAND_MOVE_STRIDE
			)
	build_page = BuildPage.new()
	build_page.back_pressed.connect(close_build_page)
	_ui.add_child(build_page)
	build_page.open(wand, int(wand["slots"]))
	_pause_changed()


func close_build_page() -> void:
	if build_page == null:
		return
	for v in build_page.planned_moves():
		driver.latch.queue_wand_move(v)
	build_page.get_parent().remove_child(build_page)
	build_page.queue_free()
	build_page = null
	if panel != null:
		panel.visible = true
		(panel.box.get_node("Order") as Button).grab_focus()
	_pause_changed()


func _status(key: String, arg: String = "") -> void:
	if panel != null:
		panel.show_status(key, arg)


func _pause_changed() -> void:
	if on_pause_change.is_valid():
		on_pause_change.call()


func _on_tick() -> void:
	meter.sync(driver.reader)
	var pos := driver.reader.player_pos()
	at_terminal = TrainingRoom.at_terminal(room, pos)
	if props != null:
		props.focus(at_terminal)
	if at_terminal:
		hud.show_station(&"UI_TRAINING_TERMINAL", &"UI_TRAINING_PROMPT_TERMINAL", driver.reader)
	elif pos.distance_to(TrainingRoom.exit_point(room)) < TrainingRoom.EXIT_REACH_M + 1.6:
		hud.show_station(&"UI_TRAINING_EXIT", &"")
	else:
		hud.show_station(&"", &"")
	if not _leaving and TrainingRoom.at_exit(room, pos):
		_leaving = true
		leave_requested.emit()


func _on_edited() -> void:
	meter.sync(driver.reader)
