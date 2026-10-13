class_name PlaygroundSession
extends Node
## v0.7.5 PG (owner N19, docs/tools/PLAYGROUND.md): the Playground while it runs. It holds the commands
## (PlaygroundApi, which SimDriver applies), the DPS meter on the UI layer, and the F1 panel: F1 opens and closes it
## (Esc closes it too), and while it is open the sim waits (Main.sync_pause). Main builds the room and its view and
## answers the panel's biome and weapon requests.

signal biome_requested(id: StringName)
signal weapon_requested

var api: PlaygroundApi
var driver: SimDriver
var meter := DpsMeter.new()
## "F1: Playground panel", bottom left while the panel is shut.
var hint := Label.new()
var panel: PlaygroundPanel
## Screen position -> sim point, or null (the view's PlayerInput.mouse_world; Main sets it with each view).
var pick_world: Callable
## The biomes as [{id, name_key}], and the room's now.
var biomes: Array = []
var biome_id := &""
## Called when the panel opens or closes, so the owner of the pause (Main) can hold or release the sim.
var on_pause_change: Callable
var _ui: Node


func _init(
	p_driver: SimDriver, p_ui: Node, p_biomes: Array, p_biome: StringName, names: Dictionary
) -> void:
	name = "Playground"
	driver = p_driver
	api = PlaygroundApi.new(driver.world)
	driver.playground = api
	_ui = p_ui
	biomes = p_biomes
	biome_id = p_biome
	meter.names = names


func _ready() -> void:
	_ui.add_child(meter)
	_ui.move_child(meter, 0)
	hint.name = "PlaygroundHint"
	hint.text = "UI_PG_F1_HINT"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.modulate = Color(1, 1, 1, 0.75)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(16, -40)
	_ui.add_child(hint)
	driver.ticked.connect(_on_tick)
	driver.edited.connect(_on_edited)
	meter.sync(driver.reader)


func _exit_tree() -> void:
	for n: Node in [meter, hint, panel]:
		if n != null and is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.queue_free()
	panel = null


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		toggle_panel()
	elif panel != null and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close_panel()


func is_panel_open() -> bool:
	return panel != null


func toggle_panel() -> void:
	if panel != null:
		close_panel()
	else:
		open_panel()


func open_panel() -> void:
	if panel != null:
		return
	panel = PlaygroundPanel.new(api, pick_world, biomes, biome_id)
	panel.biome_requested.connect(func(id: StringName) -> void: biome_requested.emit(id))
	panel.weapon_requested.connect(func() -> void: weapon_requested.emit())
	panel.dps_reset_requested.connect(func() -> void: meter.reset(driver.reader))
	panel.dps_shown.connect(func(on: bool) -> void: meter.visible = on)
	panel.close_requested.connect(close_panel)
	_ui.add_child(panel)
	hint.visible = false
	_pause_changed()


func close_panel() -> void:
	if panel == null:
		return
	panel.get_parent().remove_child(panel)
	panel.queue_free()
	panel = null
	hint.visible = true
	driver.latch.drop_presses()  # a click on the panel or the floor is not a swing once the game runs
	_pause_changed()


## The room's biome changed (Main redrew it).
func set_biome(id: StringName, p_pick_world: Callable) -> void:
	biome_id = id
	pick_world = p_pick_world
	if panel != null:
		panel.set_biome(id)
		panel.pick_world = p_pick_world


func _pause_changed() -> void:
	if on_pause_change.is_valid():
		on_pause_change.call()


func _on_tick() -> void:
	meter.sync(driver.reader)


func _on_edited() -> void:
	meter.sync(driver.reader)
	if panel != null:
		panel.refresh()
