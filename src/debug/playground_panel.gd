class_name PlaygroundPanel
extends PanelContainer
## v0.7.5 PG (owner N19, docs/tools/PLAYGROUND.md; pick "Dev-tool style, no mockups"): the Playground's panel on the
## left of the screen, opened with F1 (the sim waits while it is open). Four tabs:
## - Build: every card the build can take, by group, with a search and a level; your build, with Remove; Change weapon.
## - Spawn: the click tool (a dummy, endless or with an HP; an enemy; a boss; delete), Clear enemies, Clear all.
## - Biome: the five biomes.
## - Player: god mode, full heal, the DPS meter's reset and visibility.
## A left click on the floor (outside the panel) uses the tool; a right click always deletes. Commands go through
## PlaygroundApi, which SimDriver applies between ticks.

signal biome_requested(id: StringName)
signal weapon_requested
signal dps_reset_requested
signal dps_shown(on: bool)
signal close_requested

enum Tool { DUMMY, DUMMY_HP, ENEMY, BOSS, DELETE }

const WIDTH := 470
const GROUP_KEYS := {
	PlaygroundApi.GROUP_WAND: "UI_PG_GROUP_WAND",
	PlaygroundApi.GROUP_ABILITY: "UI_PG_GROUP_ABILITY",
	PlaygroundApi.GROUP_ABILITY_MOD: "UI_PG_GROUP_ABILITY_MOD",
	PlaygroundApi.GROUP_PASSIVE: "UI_PG_GROUP_PASSIVE",
	PlaygroundApi.GROUP_STAT: "UI_PG_GROUP_STAT",
}
const RARITY_KEYS := ["UI_PG_RARITY_0", "UI_PG_RARITY_1", "UI_PG_RARITY_2", "UI_PG_RARITY_3"]
const TOOL_KEYS := [
	"UI_PG_TOOL_DUMMY",
	"UI_PG_TOOL_DUMMY_HP",
	"UI_PG_TOOL_ENEMY",
	"UI_PG_TOOL_BOSS",
	"UI_PG_TOOL_DELETE"
]

var api: PlaygroundApi
## Screen position -> a point on the sim plane (Vector2), or null (PlayerInput.mouse_world).
var pick_world: Callable
var tool := Tool.DUMMY
var tabs := TabContainer.new()
var level := SpinBox.new()
var search := LineEdit.new()
var catalog := Tree.new()
var held := Tree.new()
var dummy_hp := SpinBox.new()
var enemies := OptionButton.new()
var bosses := OptionButton.new()
var god := CheckBox.new()
var show_dps := CheckBox.new()
var status := Label.new()
var _tool_buttons: Array[Button] = []
var _biome_buttons := {}


## `biomes`: [{id, name_key}] in the run's order; `biome`: the room's now.
func _init(p_api: PlaygroundApi, p_pick_world: Callable, biomes: Array, biome: StringName) -> void:
	name = "PlaygroundPanel"
	api = p_api
	pick_world = p_pick_world
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_LEFT_WIDE)
	offset_left = 12
	offset_top = 12
	offset_bottom = -12
	offset_right = 12 + WIDTH
	var col := VBoxContainer.new()
	add_child(col)
	var bar := HBoxContainer.new()
	col.add_child(bar)
	var title := Label.new()
	title.text = "UI_PG_TITLE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	_button(bar, "Close", "UI_PG_CLOSE", func() -> void: close_requested.emit())
	tabs.name = "Tabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	tabs.add_child(_build_tab())
	tabs.add_child(_spawn_tab())
	tabs.add_child(_biome_tab(biomes))
	tabs.add_child(_player_tab())
	for i in tabs.get_tab_count():
		tabs.set_tab_title(i, "UI_PG_TAB_" + String(tabs.get_child(i).name).to_upper())
	status.name = "Status"
	status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.modulate = Color(1, 1, 1, 0.7)
	col.add_child(status)
	set_biome(biome)
	refresh()


# --- Tabs -----------------------------------------------------------------------------------------------------------


func _build_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "Build"
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := Label.new()
	l.text = "UI_PG_LEVEL"
	row.add_child(l)
	level.name = "Level"
	level.min_value = 1
	level.max_value = CardLevels.MAX_LEVEL
	level.value = 1
	row.add_child(level)
	search.name = "Search"
	search.placeholder_text = "UI_PG_SEARCH"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_t: String) -> void: _fill_catalog())
	row.add_child(search)
	catalog.name = "Catalog"
	catalog.hide_root = true
	catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	catalog.item_activated.connect(add_selected)
	box.add_child(catalog)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_button(actions, "Add", "UI_PG_ADD", add_selected)
	_button(actions, "Weapon", "UI_PG_WEAPON", func() -> void: weapon_requested.emit())
	var mine := Label.new()
	mine.text = "UI_PG_YOUR_BUILD"
	box.add_child(mine)
	held.name = "Held"
	held.hide_root = true
	held.custom_minimum_size = Vector2(0, 200)
	held.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	held.item_activated.connect(remove_selected)
	box.add_child(held)
	_button(box, "Remove", "UI_PG_REMOVE", remove_selected)
	return box


func _spawn_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "Spawn"
	var hint := Label.new()
	hint.text = "UI_PG_SPAWN_HINT"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)
	var group := ButtonGroup.new()
	for t in Tool.size():
		var b := Button.new()
		b.name = "Tool" + Tool.keys()[t].capitalize().replace(" ", "")
		b.text = TOOL_KEYS[t]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t == tool
		b.toggled.connect(func(on: bool) -> void: _on_tool(t, on))
		_tool_buttons.append(b)
		box.add_child(b)
		match t:
			Tool.DUMMY_HP:
				dummy_hp.name = "DummyHp"
				dummy_hp.min_value = 1
				dummy_hp.max_value = 10_000_000
				dummy_hp.step = 1
				dummy_hp.value = 10_000
				box.add_child(dummy_hp)
			Tool.ENEMY:
				enemies.name = "Enemies"
				enemies.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				for e: Dictionary in api.enemy_choices():
					enemies.add_item(tr(e["name_key"]), e["kind"])
				box.add_child(enemies)
			Tool.BOSS:
				bosses.name = "Bosses"
				bosses.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				for b2: Dictionary in api.boss_choices():
					bosses.add_item(tr(b2["name_key"]), b2["index"])
				box.add_child(bosses)
	box.add_child(HSeparator.new())
	_button(box, "ClearEnemies", "UI_PG_CLEAR_ENEMIES", func() -> void: api.clear(false))
	_button(box, "ClearAll", "UI_PG_CLEAR_ALL", func() -> void: api.clear(true))
	return box


func _biome_tab(biomes: Array) -> Control:
	var box := VBoxContainer.new()
	box.name = "Biome"
	for b: Dictionary in biomes:
		var id: StringName = b["id"]
		var btn := _button(
			box, "Biome_" + String(id), b["name_key"], func() -> void: biome_requested.emit(id)
		)
		btn.toggle_mode = true
		_biome_buttons[id] = btn
	return box


func _player_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "Player"
	god.name = "God"
	god.text = "UI_PG_GOD"
	god.button_pressed = api.god
	god.toggled.connect(func(on: bool) -> void: api.god = on)
	box.add_child(god)
	_button(box, "Heal", "UI_PG_HEAL", api.heal)
	box.add_child(HSeparator.new())
	_button(box, "ResetDps", "UI_PG_DPS_RESET", func() -> void: dps_reset_requested.emit())
	show_dps.name = "ShowDps"
	show_dps.text = "UI_PG_DPS_SHOW"
	show_dps.button_pressed = true
	show_dps.toggled.connect(func(on: bool) -> void: dps_shown.emit(on))
	box.add_child(show_dps)
	return box


func _button(parent: Control, n: String, key: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.name = n
	b.text = key
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


# --- Lists ----------------------------------------------------------------------------------------------------------


## Reads the build again (after a command landed).
func refresh() -> void:
	_fill_catalog()
	_fill_held()


func _fill_catalog() -> void:
	var keep := _selected_code(catalog)
	catalog.clear()
	var root := catalog.create_item()
	var filter := search.text.strip_edges().to_lower()
	var parents := {}
	for g in PlaygroundApi.GROUPS:
		var p := catalog.create_item(root)
		p.set_text(0, tr(GROUP_KEYS[g]))
		p.set_selectable(0, false)
		parents[g] = p
	for e: Dictionary in api.catalog():
		var label := _entry_text(e)
		if filter != "" and not label.to_lower().contains(filter):
			continue
		var it := catalog.create_item(parents[e["group"]])
		it.set_text(0, label)
		it.set_metadata(0, e["code"])
		if e["held"]:
			it.set_custom_color(0, Color(0.55, 0.85, 1.0))
		if e["code"] == keep:
			it.select(0)
	for g in parents:
		if (parents[g] as TreeItem).get_child_count() == 0:
			(parents[g] as TreeItem).free()
	var sel := catalog.get_selected()
	if sel != null:
		catalog.scroll_to_item(sel)


func _fill_held() -> void:
	held.clear()
	var root := held.create_item()
	for e: Dictionary in api.held():
		var it := held.create_item(root)
		it.set_text(0, _entry_text(e))
		it.set_metadata(0, e["code"])


func _entry_text(e: Dictionary) -> String:
	var s := tr(e["name_key"])
	if e["group"] == PlaygroundApi.GROUP_STAT:
		s += " · " + tr(RARITY_KEYS[clampi(int(e["rarity"]), 0, 3)])
	if e["levels"] and int(e["level"]) > 0:
		s += " · " + tr("UI_PG_LV") % int(e["level"])
	return s


static func _selected_code(t: Tree) -> int:
	var it := t.get_selected()
	return int(it.get_metadata(0)) if it != null and it.get_metadata(0) != null else -1


# --- Actions --------------------------------------------------------------------------------------------------------


## Grants the card selected in the list at the level set.
func add_selected() -> void:
	var code := _selected_code(catalog)
	if code < 0:
		return
	api.grant(code, int(level.value))
	status.text = tr("UI_PG_ADDED") % catalog.get_selected().get_text(0)


func remove_selected() -> void:
	var code := _selected_code(held)
	if code >= 0:
		api.remove_card(code)


func set_biome(id: StringName) -> void:
	for b: StringName in _biome_buttons:
		(_biome_buttons[b] as Button).set_pressed_no_signal(b == id)


func _on_tool(t: int, on: bool) -> void:
	if on:
		tool = t as Tool


## A click on the floor, at sim point `at`: the tool (`left`), or delete (a right click).
func use_tool(at: Vector2, left: bool = true) -> void:
	if not left or tool == Tool.DELETE:
		api.remove_at(at)
		return
	match tool:
		Tool.DUMMY:
			api.place_dummy(at)
		Tool.DUMMY_HP:
			api.place_dummy(at, int(dummy_hp.value))
		Tool.ENEMY:
			if enemies.selected >= 0:
				api.place_enemy(enemies.get_item_id(enemies.selected), at)
		Tool.BOSS:
			if bosses.selected >= 0:
				api.place_boss(bosses.get_item_id(bosses.selected), at)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or not visible:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	var at: Variant = pick_world.call(mb.position) if pick_world.is_valid() else null
	if at == null:
		return
	get_viewport().set_input_as_handled()
	use_tool(at, mb.button_index == MOUSE_BUTTON_LEFT)
