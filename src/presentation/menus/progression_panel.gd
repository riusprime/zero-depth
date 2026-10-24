class_name ProgressionPanel
extends MenuPanel
## v0.9.0 MP (PLAN W44, W49-W52; LOCKED_DECISIONS PD-06: sideways only): the hub Progression Station's panel. The
## profile's Rune Fragments, one row per robe they buy (its colour, its name, its price or "owned"), a line on the Void
## form's unlock (travel through a Purple Portal), a status line, and Back. Pressing a row asks to buy it
## (`buy_requested`); HubSession buys through MetaProgress and calls `show_state` back. Nothing here is a stat.
## Keyboard, mouse and pad through the focus, as every menu; Esc or pad B closes it.

signal buy_requested(id: StringName)
signal back_pressed

const SWATCH := 26

var balance: Label
var intro: Label
var void_line: Label
var status: Label
## The robe rows, in Wardrobe order (each Button's meta `robe` is its id).
var rows: Array[Button] = []
var _wares: Array = []
var _owned: Array[bool] = []
var _fragments := 0
var _void_open := false
var _status_key := &""
var _status_arg := ""


func _init(wares: Array, owned: Array[bool], fragments: int, void_open: bool) -> void:
	super()
	name = "ProgressionPanel"
	_wares = wares
	add_backdrop()
	add_title("HUB_PROGRESSION").name = "Title"
	balance = _label("Balance", MenuStyle.BUTTON_SIZE, MenuStyle.TEXT)
	intro = _label("Intro", MenuStyle.NOTE_SIZE + 2, MenuStyle.DIM)
	for r: RobeDefinition in wares:
		var b := add_button("", _on_row.bind(r.id))
		b.name = "Robe_%s" % r.id
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.set_meta(&"robe", r.id)
		b.icon = _swatch(r.cloak)
		rows.append(b)
	void_line = _label("VoidLine", MenuStyle.NOTE_SIZE + 2, MenuStyle.DIM)
	status = _label("Status", MenuStyle.NOTE_SIZE + 2, MenuStyle.TEXT)
	add_button("UI_BACK", func() -> void: back_pressed.emit()).name = "Back"
	add_hint("UI_MENU_HINT")
	show_state(owned, fragments, void_open)


func _label(node_name: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(MenuStyle.LIST_W + 60, 0)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	box.add_child(l)
	return l


static func _swatch(c: Color) -> ImageTexture:
	var img := Image.create(SWATCH, SWATCH, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


## The rows' owned flags, the balance and the Void's unlock, shown again (after a buy).
func show_state(owned: Array[bool], fragments: int, void_open: bool) -> void:
	_owned = owned
	_fragments = fragments
	_void_open = void_open
	_refresh()


## The status line: `key` (a translation key with one %s, or none) and its argument (a robe's name key).
func show_status(key: StringName, arg: String = "") -> void:
	_status_key = key
	_status_arg = arg
	_refresh()


func _refresh() -> void:
	balance.text = tr("PROGRESSION_BALANCE") % _fragments
	intro.text = tr("PROGRESSION_ROBES_INTRO")
	for k in rows.size():
		var r: RobeDefinition = _wares[k]
		var own := k < _owned.size() and _owned[k]
		var tail := tr("PROGRESSION_OWNED") if own else tr("PROGRESSION_PRICE") % r.price
		rows[k].text = "%s  ·  %s" % [tr(r.name_key), tail]
	void_line.text = tr("PROGRESSION_VOID_OPEN" if _void_open else "PROGRESSION_VOID_LOCKED")
	var s := tr(_status_key) if _status_key != &"" else ""
	if s.contains("%s"):
		s = s % tr(_status_arg)
	status.text = s
	status.visible = not s.is_empty()


func _on_row(id: StringName) -> void:
	buy_requested.emit(id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and balance != null:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()
