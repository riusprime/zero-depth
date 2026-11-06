extends SceneTree
## v0.10.5 W3-O9 G2 (owner, 2026-11-04: "The current card format is too large … The reroll cost is not clearly visible
## … the shop doesn't feel like a polished video game store"): three layout mockups of the smaller shop (heal, reroll,
## 4 cards), drawn over the real game with the real shop open, plus the current shop panel for comparison.
## A prototype for the owner to pick from, not game code: it builds throwaway Controls from the game's own pieces
## (PickSlot cards, ShardIcon, the stone plate, HudStyle) over the real panel, which it hides. Every word is an
## existing translated key; the button glyphs are drawn letters, as InteractPrompt draws them.
## Needs a renderer (not --headless); open it off screen:
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/mock_shop.gd [-- --lang=es]
## Writes build/shots/v0.10.5/w3o9/current_shop.png, mock_a.png, mock_b.png, mock_c.png (Spanish: *_es.png). The
## stage run (Main.STAGE_SEED) is the fixed seed, so the stock is the same each time.

const OUT := "res://build/shots/v0.10.5/w3o9/"
const STONE := Color(0.105, 0.09, 0.082, 0.96)
const INNER := Color(0.07, 0.06, 0.055, 0.92)
const GOLD := Color("#E8B45A")
const HEAL := Color("#9CF29C")
const POOR := Color("#FF5A4D")
const MAX_FRAMES := 3000

var _main: Main
var _frame := 0
var _mock: CanvasLayer
var _step := 0
var _suffix := ""
var _lang := "en"
var _wait := 0


## A stone slab (HudStyle.draw_plate) with an optional ember line and a coloured top accent.
class Plate:
	extends Control
	var fill := STONE
	var ember := false
	var accent := Color(0, 0, 0, 0)
	var rim := Color(0, 0, 0, 0)

	func _init(p_fill: Color = STONE, p_ember: bool = false) -> void:
		fill = p_fill
		ember = p_ember
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		HudStyle.draw_plate(self, Rect2(Vector2.ZERO, size), ember, HudStyle.STONE_EDGE, fill)
		if accent.a > 0.0:
			draw_rect(Rect2(Vector2(18, 2), Vector2(size.x * 0.35, 3)), accent)
		if rim.a > 0.0:
			draw_polyline(_closed(HudStyle.plate_points(Rect2(Vector2.ZERO, size))), rim, 2.0, true)

	func _closed(p: PackedVector2Array) -> PackedVector2Array:
		var out := p.duplicate()
		out.append(p[0])
		return out


## A pad button drawn as InteractPrompt draws it: a coloured disc with its letter.
class Glyph:
	extends Control
	var letter := "A"
	var tint := Color(0.35, 0.78, 0.38)

	func _init(p_letter: String, p_tint: Color, side: float = 30.0) -> void:
		letter = p_letter
		tint = p_tint
		custom_minimum_size = Vector2(side, side)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := size.y * 0.5
		draw_circle(size * 0.5, r, Color(0.08, 0.08, 0.1, 0.95))
		draw_arc(size * 0.5, r - 1.5, 0, TAU, 32, tint, 2.5, true)
		var f := HudStyle.font(true)
		var fs := int(size.y * 0.55)
		var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(r - w * 0.5, r + fs * 0.36), letter, 0, -1, fs, tint)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			_lang = a.trim_prefix("--lang=")
			_suffix = "" if _lang == "en" else "_" + _lang
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("mock_shop: renderer=%s" % RenderingServer.get_current_rendering_method())
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


## Waits on the game, not on frame numbers (a loaded machine runs slower): the stage run, its arrival, the setup, E by
## the shop, and once it is open the shots, 30 frames apart.
func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > MAX_FRAMES:
		push_error("mock_shop: gave up at step %d" % _step)
		quit(1)
		return false
	var d := _main.driver
	if d == null:
		if _frame == 3:
			_main.start_stage()  # the dev stage run, as card_mockups.gd starts it
		return false
	d.world.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
	_wait -= 1
	if _wait > 0:
		return false
	match _step:
		0:
			if d.reader.arriving():
				return false
			TranslationServer.set_locale(_lang)  # after Main applied the profile's language
			var w := d.world
			w.shards = 120  # shot setup: enough to afford most of the stock
			w.actors.hp[0] = w.actors.max_hp[0] / 2
			w.actors.set_pos(0, ShopPlacement.front(w.floor_layout) + Vector2(0.4, 0.4))
			_next(50)
		1:
			_tap(KEY_E)
			_next(10)
		2:
			if not d.reader.shop_open():
				_tap(KEY_E)
				_wait = 20
				return false
			_next(30)
		3:
			_shot("current_shop")
			_panel().modulate = Color(1, 1, 1, 0)
			_build(0)
			_next(30)
		4:
			_shot("mock_a")
			_build(1)
			_next(30)
		5:
			_shot("mock_b")
			_build(2)
			_next(30)
		6:
			_shot("mock_c")
			quit(0)
	return false


func _next(frames: int) -> void:
	_step += 1
	_wait = frames


func _panel() -> ShopPanel:
	return (_main.get_node("UI/Hud") as Hud).shop.panel


func _build(which: int) -> void:
	if _mock != null:
		_mock.queue_free()
	_mock = CanvasLayer.new()
	_mock.layer = 90
	root.add_child(_mock)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mock.add_child(dim)
	var reader := _main.driver.reader
	var s := reader.shop()
	match which:
		0:
			_mock_a(reader, s)
		1:
			_mock_b(reader, s)
		2:
			_mock_c(reader, s)


# --- Shared pieces -------------------------------------------------------------------------------------------------
func _label(text: String, size: int, bold: bool = false, c: Color = HudStyle.EMBER_TEXT) -> Label:
	var l := HudStyle.label(size, bold)
	l.text = text
	l.add_theme_color_override("font_color", c)
	return l


func _price(amount: int, size: int, ok: bool = true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var icon := ShardIcon.new(size * 1.1)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(_label(str(amount), size, true, Color.WHITE if ok else POOR))
	return row


func _wallet(shards: int, size: int) -> Control:
	var p := Plate.new(INNER)
	var m := _margin(18, 8)
	p.add_child(m)
	m.add_child(_price(shards, size))
	p.custom_minimum_size = Vector2(150, size + 22)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	return p


func _margin(h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, h)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, v)
	return m


func _card(reader: WorldReader, k: int, c: Dictionary, scale: float) -> PickSlot:
	var slot := PickSlot.new(k, scale)
	if c["sold"]:
		slot.show_card(
			{
				"id": &"",
				"title": root.tr("SHOP_SOLD"),
				"sentence": "",
				"color": CardStyle.EDGE,
				"tier": 0,
				"tier_text": ""
			}
		)
	else:
		slot.show_card(PickPanel.card_face(root, reader, int(c["code"])))
	slot.set_focused(k == 0)
	return slot


## Buys-left pips: one diamond per buy, the spent ones hollow.
func _pips(left: int, cap: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label(root.tr("SHOP_BUYS_LEFT") % left, 18, false, Color(1, 1, 1, 0.8)))
	for k in cap:
		var d := ShardIcon.new(18.0)
		d.modulate = Color(1, 1, 1, 1.0 if k < left else 0.25)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(d)
	return row


## A service button: glyph, name (and a detail), and the price large on the right.
func _service(
	glyph: Glyph, title: String, price: int, accent: Color, width: float, focused: bool = false
) -> Control:
	var p := Plate.new(STONE)
	p.accent = accent
	if focused:
		p.rim = Color(accent, 0.9)
	p.custom_minimum_size = Vector2(width, 74)
	var m := _margin(18, 10)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var name := _label(title, 22, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)
	var tag := _price(price, 30)
	row.add_child(tag)
	return p


# --- Mock A: the counter -------------------------------------------------------------------------------------------
## One framed store window: a header bar (title, buys-left pips, wallet), the 4 cards smaller in a row with a price
## tag hung under each, and a counter bar of two wide service buttons with their prices large (heal left, reroll
## right, each on its own pad button). Everything in one 1360 x 760 frame.
func _mock_a(reader: WorldReader, s: Dictionary) -> void:
	var frame := Plate.new(STONE, true)
	frame.rim = Color(GOLD, 0.55)
	frame.size = Vector2(1360, 650)
	frame.position = (Vector2(1920, 1080) - frame.size) * 0.5
	_mock.add_child(frame)
	var m := _margin(36, 24)
	m.size = frame.size
	frame.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	m.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	col.add_child(head)
	var title := _label(root.tr("SHOP_TITLE").to_upper(), 34, true, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var pips := _pips(int(s["buys_left"]), int(s["max_buys"]))
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pips)
	head.add_child(_wallet(reader.shards(), 28))
	var line := ColorRect.new()
	line.color = Color(GOLD, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	col.add_child(line)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 34)
	col.add_child(cards)
	var stock: Array = s["stock"]
	for k in stock.size():
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.add_child(_card(reader, k, stock[k], 0.74))
		var tag := Plate.new(INNER)
		tag.custom_minimum_size = Vector2(130, 40)
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tm := _margin(10, 4)
		tm.set_anchors_preset(Control.PRESET_FULL_RECT)
		tag.add_child(tm)
		var c: Dictionary = stock[k]
		tm.add_child(_price(int(c["price"]), 24, bool(c["affordable"])))
		box.add_child(tag)
		cards.add_child(box)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 40)
	col.add_child(bar)
	bar.add_child(
		_service(
			Glyph.new("X", Color(0.3, 0.55, 0.95)),
			root.tr("SHOP_HEAL") % int(s["heal_amount"]),
			int(s["heal_price"]),
			HEAL,
			560.0
		)
	)
	bar.add_child(
		_service(
			Glyph.new("Y", Color(0.97, 0.8, 0.25)),
			root.tr("SHOP_REROLL"),
			int(s["reroll_price"]),
			ShardIcon.MID,
			560.0
		)
	)
	var hint := _label(root.tr("SHOP_HINT"), 16, false, Color(1, 1, 1, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


# --- Mock B: the ledger --------------------------------------------------------------------------------------------
## Cards on the left as a 2 x 2 grid (smaller still, each with its price in a ribbon at its foot); a right rail holds
## the wallet at the top, then the heal and the reroll as tall buttons with the price as the biggest thing on them,
## the buys-left pips and the hint. The eye reads cards left, money and services right.
func _mock_b(reader: WorldReader, s: Dictionary) -> void:
	var frame := Plate.new(STONE, true)
	frame.rim = Color(GOLD, 0.45)
	frame.size = Vector2(1010, 830)
	frame.position = (Vector2(1920, 1080) - frame.size) * 0.5
	_mock.add_child(frame)
	var m := _margin(30, 26)
	m.size = frame.size
	frame.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	m.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 10)
	row.add_child(grid)
	var stock: Array = s["stock"]
	for k in stock.size():
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.add_child(_card(reader, k, stock[k], 0.72))
		var c: Dictionary = stock[k]
		var tag := _price(int(c["price"]), 22, bool(c["affordable"]))
		box.add_child(tag)
		grid.add_child(box)
	var sep := ColorRect.new()
	sep.color = Color(GOLD, 0.3)
	sep.custom_minimum_size = Vector2(2, 0)
	row.add_child(sep)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 22)
	rail.custom_minimum_size = Vector2(440, 0)
	row.add_child(rail)
	var title := _label(root.tr("SHOP_TITLE").to_upper(), 36, true, GOLD)
	rail.add_child(title)
	rail.add_child(_wallet(reader.shards(), 34))
	rail.add_child(_pips(int(s["buys_left"]), int(s["max_buys"])))
	for spec in [
		[
			"X",
			Color(0.3, 0.55, 0.95),
			root.tr("SHOP_HEAL") % int(s["heal_amount"]),
			"heal_price",
			HEAL
		],
		["Y", Color(0.97, 0.8, 0.25), root.tr("SHOP_REROLL"), "reroll_price", ShardIcon.MID]
	]:
		var p := Plate.new(STONE)
		p.accent = spec[4]
		p.rim = Color(spec[4], 0.5)
		p.custom_minimum_size = Vector2(0, 150)
		var pm := _margin(20, 14)
		pm.set_anchors_preset(Control.PRESET_FULL_RECT)
		p.add_child(pm)
		var pc := VBoxContainer.new()
		pc.add_theme_constant_override("separation", 6)
		pm.add_child(pc)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		top.add_child(Glyph.new(spec[0], spec[1], 34.0))
		top.add_child(_label(spec[2], 24, true))
		pc.add_child(top)
		var big := _price(int(s[spec[3]]), 44)
		big.alignment = BoxContainer.ALIGNMENT_END
		pc.add_child(big)
		rail.add_child(p)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.add_child(spacer)
	var hint := _label(root.tr("SHOP_HINT"), 15, false, Color(1, 1, 1, 0.6))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rail.add_child(hint)


# --- Mock C: the shelf ---------------------------------------------------------------------------------------------
## A storefront banner with the wallet; the 4 cards small on a lit shelf with their prices on the shelf's edge; the
## focused card's full text in a wide read-out under the shelf (so the cards can stay small); the heal and the
## reroll as two medallion buttons at the shelf's ends, price under each, on the shoulder buttons.
func _mock_c(reader: WorldReader, s: Dictionary) -> void:
	var w := 1500.0
	var frame := Plate.new(STONE, true)
	frame.rim = Color(GOLD, 0.5)
	frame.size = Vector2(w, 640)
	frame.position = (Vector2(1920, 1080) - frame.size) * 0.5
	_mock.add_child(frame)
	var m := _margin(30, 22)
	m.size = frame.size
	frame.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	m.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := _label(root.tr("SHOP_TITLE").to_upper(), 34, true, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var pips := _pips(int(s["buys_left"]), int(s["max_buys"]))
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pips)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(24, 0)
	head.add_child(gap)
	head.add_child(_wallet(reader.shards(), 28))
	var shelf_row := HBoxContainer.new()
	shelf_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shelf_row.add_theme_constant_override("separation", 26)
	col.add_child(shelf_row)
	shelf_row.add_child(
		_medallion(
			"LB", root.tr("SHOP_HEAL") % int(s["heal_amount"]), int(s["heal_price"]), HEAL, false
		)
	)
	var shelf := VBoxContainer.new()
	shelf.add_theme_constant_override("separation", 0)
	shelf_row.add_child(shelf)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	shelf.add_child(cards)
	var stock: Array = s["stock"]
	for k in stock.size():
		cards.add_child(_card(reader, k, stock[k], 0.66))
	var plank := Plate.new(Color(0.2, 0.14, 0.09, 0.98), true)
	plank.custom_minimum_size = Vector2(0, 46)
	shelf.add_child(plank)
	var tags := HBoxContainer.new()
	tags.set_anchors_preset(Control.PRESET_FULL_RECT)
	tags.add_theme_constant_override("separation", 18)
	plank.add_child(tags)
	for k in stock.size():
		var c: Dictionary = stock[k]
		var t := _price(int(c["price"]), 24, bool(c["affordable"]))
		t.custom_minimum_size = Vector2(StoneCard.SIZE.x * 0.66, 46)
		tags.add_child(t)
	shelf_row.add_child(
		_medallion("RB", root.tr("SHOP_REROLL"), int(s["reroll_price"]), ShardIcon.MID, true)
	)
	# The read-out: the focused card's title and sentence, wide, with its price and the buy button.
	var focus: Dictionary = stock[0]
	var face := PickPanel.card_face(root, reader, int(focus["code"])) if not focus["sold"] else {}
	var read := Plate.new(INNER)
	read.accent = Color(face.get("color", GOLD), 0.9)
	read.custom_minimum_size = Vector2(0, 96)
	col.add_child(read)
	var rm := _margin(26, 12)
	rm.set_anchors_preset(Control.PRESET_FULL_RECT)
	read.add_child(rm)
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 18)
	rm.add_child(rr)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rr.add_child(text)
	text.add_child(_label(String(face.get("title", "")), 24, true, face.get("color", GOLD)))
	var sentence := _label(String(face.get("sentence", "")), 18)
	sentence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(sentence)
	var buy := Glyph.new("A", Color(0.35, 0.78, 0.38), 40.0)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rr.add_child(buy)
	var bp := _price(int(focus["price"]), 34, bool(focus["affordable"]))
	rr.add_child(bp)
	var hint := _label(root.tr("SHOP_HINT"), 16, false, Color(1, 1, 1, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


## Mock C's round service button: a glyph on top, a stone disc with the service's name, its price under it.
func _medallion(glyph: String, title: String, price: int, accent: Color, focused: bool) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(170, 0)
	var g := Glyph.new(glyph, Color(0.85, 0.85, 0.9), 34.0)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(g)
	var p := Plate.new(STONE)
	p.accent = accent
	p.rim = Color(accent, 0.95 if focused else 0.45)
	p.custom_minimum_size = Vector2(170, 120)
	var pm := _margin(10, 10)
	pm.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(pm)
	var name := _label(title, 20, true, accent)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pm.add_child(name)
	box.add_child(p)
	box.add_child(_price(price, 36))
	return box


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _shot(shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := ProjectSettings.globalize_path(OUT + shot_name + _suffix + ".png")
	img.save_png(path)
	print("mock_shop: shot ", path)
