class_name TrainingPanel
extends MenuPanel
## v0.10.5 O17 (owner P17): the Training Room's terminal. One column over the room (no blur: the dummy and what was
## spawned stay in sight): pick an enemy kind the Codex has met and a count (1, 3 or 8), Spawn;
## Clear enemies; the weapon (Blade or Gun: the room is rebuilt with it); a wand card the Codex has seen and its level
## (1-5), Add card, Remove last card, and the wand's order (the Build page, as from the pause menu); Reset room; Back.
## Each choice is an OptionCycler (left / right, or press to step), so keyboard, mouse and pad work through the focus.
## It only asks: the Training Room (TrainingSession) runs every request on its World and answers with a status line.
## v0.11.1 Step 13 (owner: Astral the only style): in Astral (MenuPanel): the column on an Astral veil (the room stays
## in sight behind it), each choice an Options-style field row, the actions Astral rows.

signal spawn_requested(kind: int, count: int)
signal clear_requested
signal weapon_picked(build_id: StringName)
signal card_requested(code: int, level: int)
signal remove_card_requested
signal order_requested
signal reset_requested
signal back_pressed

const ROW_H := 40
const ROW_FONT := 22

var enemy_cycler: OptionCycler
var count_cycler: OptionCycler
var weapon_cycler: OptionCycler
var card_cycler: OptionCycler
var level_cycler: OptionCycler
var status: Label
var _enemies: Array = []
var _cards: Array = []


## `enemies` [{kind, name_key}], `counts` the spawn counts, `weapons` [{id, name_key}] and the one held now, `cards`
## [{code, name_key}], `max_level` the cards' top level.
func _init(
	enemies: Array, counts: Array, weapons: Array, weapon: StringName, cards: Array, max_level: int
) -> void:
	super()
	name = "TrainingPanel"
	_enemies = enemies
	_cards = cards
	slab.add_theme_stylebox_override("panel", AstralMenu.VeilBox.new(Vector2(40, 32), 0.72))
	slab.offset_left = AstralMenu.LEFT - 40.0
	add_title("UI_TRAINING_TERMINAL").name = "Title"
	if enemies.is_empty():
		_note("UI_TRAINING_NO_ENEMIES").name = "NoEnemies"
	else:
		var ids: Array = []
		var keys: Array = []
		for k in enemies.size():
			ids.append(str(k))
			keys.append(String(enemies[k]["name_key"]))
		enemy_cycler = _cycler("Enemy", "UI_TRAINING_ENEMY", ids, keys, "0")
		var cs: Array = []
		for c: int in counts:
			cs.append(str(c))
		count_cycler = _cycler("Count", "UI_TRAINING_COUNT", cs, cs, cs[0])
		_button("Spawn", "UI_TRAINING_SPAWN", _spawn)
	_button("Clear", "UI_TRAINING_CLEAR", func() -> void: clear_requested.emit())
	var wids: Array = []
	var wkeys: Array = []
	for w: Dictionary in weapons:
		wids.append(String(w["id"]))
		wkeys.append(String(w["name_key"]))
	weapon_cycler = _cycler("Weapon", "UI_TRAINING_WEAPON", wids, wkeys, String(weapon))
	weapon_cycler.changed.connect(func(id: String) -> void: weapon_picked.emit(StringName(id)))
	if cards.is_empty():
		_note("UI_TRAINING_NO_CARDS").name = "NoCards"
	else:
		var cids: Array = []
		var ckeys: Array = []
		for k in cards.size():
			cids.append(str(k))
			ckeys.append(String(cards[k]["name_key"]))
		card_cycler = _cycler("Card", "UI_TRAINING_CARD", cids, ckeys, "0")
		var lv: Array = []
		for k in range(1, max_level + 1):
			lv.append(str(k))
		level_cycler = _cycler("Level", "UI_TRAINING_LEVEL", lv, lv, "1")
		_button("AddCard", "UI_TRAINING_ADD_CARD", _add_card)
	_button("RemoveCard", "UI_TRAINING_REMOVE_CARD", func() -> void: remove_card_requested.emit())
	_button("Order", "UI_TRAINING_ORDER", func() -> void: order_requested.emit())
	_button("Reset", "UI_TRAINING_RESET", func() -> void: reset_requested.emit())
	_button("Back", "UI_BACK", func() -> void: back_pressed.emit())
	status = add_note("")
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(AstralMenu.LIST_W, 0)
	status.add_theme_color_override("font_color", AstralCardArt.TEXT)
	add_hint("UI_MENU_HINT")


## The line under the list (a translation key, its argument put in when the line has a %s).
func show_status(key: String, arg: String = "") -> void:
	var line := tr(key)
	status.text = line % tr(arg) if line.contains("%s") else line


func focus_first() -> void:
	var first: Control = enemy_cycler if enemy_cycler != null else box.get_node("Clear")
	first.grab_focus()


## The enemy picked ({kind, name_key}; empty without one) and the count.
func picked_enemy() -> Dictionary:
	return _enemies[enemy_cycler.index] if enemy_cycler != null else {}


func picked_count() -> int:
	return int(count_cycler.value()) if count_cycler != null else 0


func picked_card() -> Dictionary:
	return _cards[card_cycler.index] if card_cycler != null else {}


func picked_level() -> int:
	return int(level_cycler.value()) if level_cycler != null else 1


func _spawn() -> void:
	var e := picked_enemy()
	if not e.is_empty():
		spawn_requested.emit(int(e["kind"]), picked_count())


func _add_card() -> void:
	var c := picked_card()
	if not c.is_empty():
		card_requested.emit(int(c["code"]), picked_level())


func _cycler(
	n: String, label_key: String, ids: Array, keys: Array, current: String
) -> OptionCycler:
	var row := AstralMenu.field_row(box, label_key, 150.0)
	row.name = n + "Row"
	row.custom_minimum_size = Vector2(0, ROW_H)
	var c := OptionCycler.new(ids, keys, current)
	c.name = n
	c.astral = true  # v0.10.5 W3-O20: Astral's chevrons and hairline (OptionCycler), as in Options
	c.custom_minimum_size = Vector2(300, ROW_H)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_font_size_override("font_size", ROW_FONT)
	row.add_child(c)
	AstralMenu.light(row, c)
	return c


func _button(n: String, key: String, on_press: Callable) -> Button:
	var b := add_button(key, on_press)
	b.name = n  # an Astral row: it sizes itself (AstralButton)
	return b


func _note(key: String) -> Label:
	var l := Label.new()
	l.text = key
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(AstralMenu.LIST_W, 0)
	AstralMenu.body(l, AstralMenu.NOTE_SIZE, AstralCardArt.DIM)
	box.add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()
