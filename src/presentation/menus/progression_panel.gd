class_name ProgressionPanel
extends MenuPanel
## v0.9.0 MP (PLAN W44, W49-W52; LOCKED_DECISIONS PD-06: sideways only): the hub Progression Station's panel. The
## profile's Rune Fragments, one row per robe they buy (its colour, its name, its price or "owned"), a line on the Void
## form's unlock (travel through a Purple Portal), a status line, and Back. Pressing a row asks to buy it
## (`buy_requested`); HubSession buys through MetaProgress and calls `show_state` back. Nothing here is a stat.
## MP2 (owner, PLAN "Owner decisions" MP2): each row shows its price now (`prices`, MetaProgress.price_of: the four
## robes 75, 100, 125, 150 in the order bought, so every unbought robe shows the next price; the epic robes 250, tagged
## "epic"); a hidden robe not bought yet is "???" with a hooded silhouette for its swatch until it is bought.
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
var _prices: Array[int] = []
var _fragments := 0
var _void_open := false
var _status_key := &""
var _status_arg := ""


func _init(
	wares: Array, owned: Array[bool], fragments: int, void_open: bool, prices: Array[int] = []
) -> void:
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
		rows.append(b)
	void_line = _label("VoidLine", MenuStyle.NOTE_SIZE + 2, MenuStyle.DIM)
	status = _label("Status", MenuStyle.NOTE_SIZE + 2, MenuStyle.TEXT)
	add_button("UI_BACK", func() -> void: back_pressed.emit()).name = "Back"
	add_hint("UI_MENU_HINT")
	show_state(owned, fragments, void_open, prices)


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


## A robe's swatch: its colour (an epic robe framed in its trim: The Fallen's violet, the divine gold).
static func _swatch(c: Color, frame: Color = Color(0, 0, 0, 0)) -> ImageTexture:
	var img := Image.create(SWATCH, SWATCH, false, Image.FORMAT_RGBA8)
	img.fill(c)
	if frame.a > 0.0:
		for y in SWATCH:
			for x in SWATCH:
				if mini(mini(x, y), mini(SWATCH - 1 - x, SWATCH - 1 - y)) < 3:
					img.set_pixel(x, y, frame)
	return ImageTexture.create_from_image(img)


## MP2: the "???" robe's swatch: a hooded figure's dark silhouette with a faint violet edge, on nothing.
static func silhouette() -> ImageTexture:
	var img := Image.create(SWATCH, SWATCH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var edge := Color("#6E4A9E")
	for y in SWATCH:
		for x in SWATCH:
			var d := _figure(float(x) + 0.5, float(y) + 0.5)
			if d <= 0.0:
				img.set_pixel(x, y, Color("#141118"))
			elif d <= 1.2:
				img.set_pixel(x, y, edge)
	return ImageTexture.create_from_image(img)


## The silhouette's signed distance (pixels, < 0 inside): a hood (a circle) over a cloak (a trapezoid widening down).
static func _figure(x: float, y: float) -> float:
	var s := float(SWATCH)
	var head := Vector2(x - s * 0.5, y - s * 0.3).length() - s * 0.2
	var t := clampf((y - s * 0.38) / (s * 0.58), 0.0, 1.0)
	var half := lerpf(s * 0.16, s * 0.42, t)
	var body := maxf(absf(x - s * 0.5) - half, maxf(s * 0.38 - y, y - s * 0.96))
	return minf(head, body)


static func _trim(r: RobeDefinition) -> Color:
	match r.style:
		&"fallen":
			return Color("#8E3BD9")
		&"divine":
			return Color("#E0B04A")
	return Color(0, 0, 0, 0)


## The rows' owned flags, the balance and the Void's unlock, shown again (after a buy).
func show_state(
	owned: Array[bool], fragments: int, void_open: bool, prices: Array[int] = []
) -> void:
	_owned = owned
	_prices = prices
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
		var tail := tr("PROGRESSION_OWNED") if own else tr("PROGRESSION_PRICE") % price(k)
		if r.epic:
			tail = "%s  ·  %s" % [tr("ROBE_EPIC_TAG"), tail]
		var masked := r.hidden and not own
		var shown := Wardrobe.HIDDEN_NAME if masked else r.name_key
		rows[k].text = "%s  ·  %s" % [tr(shown), tail]
		rows[k].set_meta(&"masked", masked)
		rows[k].icon = silhouette() if masked else _swatch(r.cloak, _trim(r))
	void_line.text = tr("PROGRESSION_VOID_OPEN" if _void_open else "PROGRESSION_VOID_LOCKED")
	var s := tr(_status_key) if _status_key != &"" else ""
	if s.contains("%s"):
		s = s % tr(_status_arg)
	status.text = s
	status.visible = not s.is_empty()


## Row `k`'s price now (the station's `prices`; without them the robe's own first price).
func price(k: int) -> int:
	return _prices[k] if k < _prices.size() else int((_wares[k] as RobeDefinition).price)


func _on_row(id: StringName) -> void:
	buy_requested.emit(id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and balance != null:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()
