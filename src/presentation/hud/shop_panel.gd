class_name ShopPanel
extends ModalPanel
## The shop panel (v0.5.0 SH): while the sim waits on the open shop, the stock (the pick's cards, PickSlot, in the
## current CardStyle, with a price and the shard icon under each), the heal and the reroll (v0.10.5 W3-O9, owner
## 2026-11-04: nothing else; the salvage list and the curse lift are gone). It shows what the sim offers and sends the
## player's choice as input (`picked` → InputLatch.note_pick → InputFrame.pick); it decides nothing.
## A card you can't afford or can't use, a spent heal and an unaffordable reroll are dimmed and send nothing.
## v0.5.5 EC (owner S2, S3): a line under the title shows how many cards you can still buy on this floor; at the limit
## it turns red and says so, the unsold cards and the reroll dim and send nothing. A reroll with every slot sold
## dims too ("Nothing left to reroll"): rerolls redraw only the unsold slots.
## - Mouse: hover focuses, a click acts.
## - Keyboard: arrows move the focus (left / right along a row, up / down between rows), 1-4 jump to a card, Enter
##   buys, Esc leaves.
## - Pad: d-pad or left stick moves the focus, A (Cross) acts, B (Circle) leaves.
## Space (dash) never confirms: the panel doesn't use ui_accept.
## v0.6.1 R1: the services are plaques (ShopTile); v0.8.0 MU: the plaques and the stock's cards are carved Ember
## stone (PlaqueBox, StoneCard).
## v0.10.5 W3-O16 (owner 2026-11-04: "Yes, go on"; the shop's layout A, W3_O9_SHOP_G2.md, in the Astral style,
## W3_O13_UI_STYLE_G2.md): one store window (AstralChrome.veil: an ink veil between two fading hairlines). Its header
## holds the sigil and the letter-spaced title at the left, the buys left (the line and one diamond pip per buy) and
## the wallet (Astral's shard, the shards in large Cinzel) at the right, over a rule; then the 4 cards in a row, each
## with its price tag hung under it (the shard and the price between short fading hairlines); then the heal and the
## reroll as wide Astral plates, the price big at their right; the hint line between hairlines closes the window.

## Key repeats (PanelInput.Echo): only the arrows repeat; a held Enter acts once.
const ECHO := PanelInput.Echo.ARROWS
## v0.5.5 A4: the stock's cards are drawn a little smaller than the pick's, so the services fit under them at 1080p.
const CARD_SCALE := 0.92
const POOR := AstralCardArt.POOR
## v0.10.5 W3-O16: the window's padding, the gap between cards and between the two plates, a plate's width (px).
const PAD := Vector2(64, 32)
const CARD_GAP := 24
const PLATE_GAP := 64
const PLATE_W := 512.0
const PRICE_SIZE := 24

var heal_tile := ShopTile.new("ShopHeal", PLATE_W)
var reroll_tile := ShopTile.new("ShopReroll", PLATE_W)
var _dim := ColorRect.new()
var _heading := AstralChrome.Heading.new(30)
var _shards := Label.new()
var _wallet_icon := ShardIcon.new(30.0, true)
var _buys := Label.new()
var _pips := AstralChrome.Pips.new()
var _hint := AstralChrome.Hint.new(200.0)
var _window := PanelContainer.new()
var _cards := HBoxContainer.new()
## Focusable entries in reading order: {value, enabled, row, focus (Callable), node}.
var _entries: Array[Dictionary] = []
var _sig := ""
var _shards_cache := 0
var _limit := false
## Audit P-12: one action per sim answer (the swap panel's latch, ModalPanel._sent). Set when an action is sent;
## cleared once the sim has stepped past the tick it was sent on (the pick read, answered or refused) or on a close.
var _sent_tick := 0
var _tick := 0


func _init() -> void:
	name = "ShopPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_dim(_dim, 0.55)
	_dim.color = Color(AstralChrome.INK, 0.55)  # v0.10.5 W3-O16: Astral's ink, not black
	var outer := _centred_column(VBoxContainer.new(), 0)
	_window.name = "ShopWindow"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil := StyleBoxEmpty.new()
	veil.content_margin_left = PAD.x
	veil.content_margin_right = PAD.x
	veil.content_margin_top = PAD.y
	veil.content_margin_bottom = PAD.y
	_window.add_theme_stylebox_override("panel", veil)
	_window.draw.connect(
		func() -> void: AstralChrome.veil(_window, Rect2(Vector2.ZERO, _window.size))
	)
	outer.add_child(_window)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 16)
	_window.add_child(col)
	col.add_child(_header())
	col.add_child(AstralChrome.Rule.new())
	_cards.name = "ShopCards"
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.add_theme_constant_override("separation", CARD_GAP)
	col.add_child(_cards)
	var services := HBoxContainer.new()
	services.name = "ShopServices"
	services.alignment = BoxContainer.ALIGNMENT_CENTER
	services.mouse_filter = Control.MOUSE_FILTER_IGNORE
	services.add_theme_constant_override("separation", PLATE_GAP)
	heal_tile.icon_kind = &"heal"
	reroll_tile.icon_kind = &"reroll"
	services.add_child(heal_tile)
	services.add_child(reroll_tile)
	var services_gap := Control.new()
	services_gap.custom_minimum_size = Vector2(0, 8)
	services_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(services_gap)
	col.add_child(services)
	var hint_gap := Control.new()
	hint_gap.custom_minimum_size = Vector2(0, 8)
	hint_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint_gap)
	col.add_child(_hint)
	visible = false


## The header: the sigil and the title at the left; the buys left, their pips, a hairline and the wallet at the right.
func _header() -> Control:
	var head := HBoxContainer.new()
	head.name = "ShopHeader"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 16)
	head.add_child(_heading)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(fill)
	_buys.name = "ShopBuys"
	_buys.add_theme_font_override("font", HudStyle.font(false))
	_buys.add_theme_font_size_override("font_size", 16)
	_buys.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_buys.size_flags_vertical = Control.SIZE_FILL
	head.add_child(_buys)
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_pips)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(17, 40)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(
		func() -> void: AstralChrome.vline(bar, 8, 0, bar.size.y, Color(AstralCardArt.LINE, 0.8))
	)
	head.add_child(bar)
	_wallet_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_wallet_icon)
	_shards.name = "ShopWallet"
	_shards.add_theme_font_override("font", AstralCardArt.serif(600, 1))
	_shards.add_theme_font_size_override("font_size", 34)
	_shards.add_theme_color_override("font_color", AstralCardArt.TEXT)
	_shards.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shards.size_flags_vertical = Control.SIZE_FILL
	head.add_child(_shards)
	for l: Label in [_buys, _shards]:
		l.add_theme_color_override("font_outline_color", Color(AstralChrome.INK, 0.6))
		l.add_theme_constant_override("outline_size", 4)
	style_labels([_shards, _buys])
	return head


## Opens, refreshes or closes from the sim's state.
func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	if _sent and _tick > _sent_tick:
		_sent = false
	if _closed(reader.has_shop() and reader.shop_open()):
		return
	var s := reader.shop()
	var sig := var_to_str(
		[
			s["stock"],
			s["heal_used"],
			s["heal_amount"],
			s["reroll_price"],
			s["buys_left"],
			reader.shards(),
			TranslationServer.get_locale()
		]
	)
	if _open and sig == _sig:
		return
	var first := not _open
	_open = true
	_sig = sig
	visible = true
	_render(reader, s)
	_set_focus(0 if first else clampi(_focus, 0, _entries.size() - 1))


func _on_closed() -> void:
	_sig = ""


## The focused entry's pick value (InputFrame.PICK_*), or PICK_NONE.
func focused_value() -> int:
	return int(_entries[_focus]["value"]) if _focus < _entries.size() else InputFrame.PICK_NONE


## Entry k: {value, enabled, row, node}.
func entry(k: int) -> Dictionary:
	return _entries[k]


## The index of the entry that sends `value`, or -1.
func index_of_value(value: int) -> int:
	for k in _entries.size():
		if int(_entries[k]["value"]) == value:
			return k
	return -1


func card_slot(k: int) -> PickSlot:
	return _cards.get_child(k).get_child(0) as PickSlot


func card_price_text(k: int) -> String:
	return (_cards.get_child(k).get_child(1).get_child(1) as Label).text


func title_text() -> String:
	return _heading.full_text()


## v0.5.5 EC (S3): the buys line ("Cards you can still buy on this floor: 3", or the limit's message).
func buys_text() -> String:
	return _buys.text


func buys_at_limit() -> bool:
	return _limit


func _render(reader: WorldReader, s: Dictionary) -> void:
	_entries.clear()
	for c in _cards.get_children():
		c.get_parent().remove_child(c)
		c.free()  # now, not at the frame's end: the panel re-renders from the tick, never from a child's signal
	_heading.set_text(tr("SHOP_TITLE"))
	_shards_cache = reader.shards()
	_shards.text = str(_shards_cache)
	_hint.label.text = tr("SHOP_HINT")
	var left := int(s["buys_left"])
	_limit = left == 0
	_buys.visible = left >= 0
	_pips.visible = left >= 0 and int(s.get("max_buys", 0)) > 0
	_pips.show_pips(maxi(left, 0), int(s.get("max_buys", 0)))
	if _limit:
		_buys.text = tr("SHOP_BUYS_DONE") % [int(s["bought"]), int(s["max_buys"])]
	else:
		_buys.text = tr("SHOP_BUYS_LEFT") % left
	_buys.add_theme_color_override("font_color", POOR if _limit else AstralCardArt.DIM)
	var stock: Array = s["stock"]
	for k in stock.size():
		_add_card(reader, k, stock[k])
	_render_services(s)
	for e in _entries:
		var node: Control = e["node"]
		for c in node.find_children("*", "Control", true, false):
			if not c is PickSlot and not c is ShopTile:
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _add_card(reader: WorldReader, k: int, c: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.name = "ShopCard%d" % (k + 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	var slot := PickSlot.new(k, CARD_SCALE)
	box.add_child(slot)
	# v0.10.5 W3-O16: the price tag hung under the card: Astral's shard and the price, short hairlines either side.
	var row := HBoxContainer.new()
	row.name = "PriceTag"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 8)
	var icon := ShardIcon.new(22.0, true)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var price := Label.new()
	price.add_theme_font_override("font", AstralCardArt.serif(600, 1))
	price.add_theme_font_size_override("font_size", PRICE_SIZE)
	price.add_theme_color_override("font_outline_color", Color(AstralChrome.INK, 0.6))
	price.add_theme_constant_override("outline_size", 3)
	price.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(icon)
	row.add_child(price)
	row.draw.connect(_draw_tag.bind(row))
	box.add_child(row)
	_cards.add_child(box)
	var sold: bool = c["sold"]
	var ok: bool = not sold and c["can_apply"] and c["affordable"] and not _limit
	if sold:
		slot.show_card(
			{
				"id": &"",
				"title": tr("SHOP_SOLD"),
				"sentence": "",
				"color": CardStyle.EDGE,
				"tier": 0,
				"tier_text": ""
			}
		)
		price.text = tr("SHOP_SOLD")
		icon.visible = false
	else:
		slot.show_card(PickPanel.card_face(self, reader, int(c["code"])))
		price.text = str(c["price"]) if c["can_apply"] else tr("SHOP_CANT_USE")
		icon.visible = c["can_apply"]
	var poor: bool = not sold and c["can_apply"] and not c["affordable"]
	price.add_theme_color_override("font_color", POOR if poor else AstralCardArt.TEXT)
	icon.tint = POOR if poor else AstralCardArt.ACCENT
	slot.modulate = Color(1, 1, 1, 1.0 if ok else 0.45)
	slot.set_meta(GameCursor.META_INVALID, not ok)  # v0.9.5 MC2: INVALID over a card you can't buy
	var at := _entries.size()
	slot.hovered.connect(func(_i: int) -> void: _set_focus(at))
	slot.clicked.connect(func(_i: int) -> void: _act(at))
	_entries.append(
		{"value": k + 1, "enabled": ok, "row": 0, "focus": slot.set_focused, "node": box}
	)


func _render_services(s: Dictionary) -> void:
	var heal_ok: bool = (
		not s["heal_used"] and int(s["heal_amount"]) > 0 and _shards_now() >= int(s["heal_price"])
	)
	var heal_detail := tr("SHOP_HEAL_USED") if s["heal_used"] else ""
	if not s["heal_used"] and int(s["heal_amount"]) <= 0:
		heal_detail = tr("SHOP_HEAL_FULL")
	heal_tile.show_tile(
		tr("SHOP_HEAL") % int(s["heal_amount"]),
		heal_detail,
		0 if s["heal_used"] else int(s["heal_price"]),
		heal_ok,
		_shards_now() < int(s["heal_price"]),
		false,
		Color("#9CF29C"),
		Plaques.of_use(&"shop_heal")
	)
	var any_left := int(s["unsold"]) > 0  # v0.5.5 EC (S2): only unsold slots reroll
	var reroll_ok := _shards_now() >= int(s["reroll_price"]) and any_left and not _limit
	reroll_tile.show_tile(
		tr("SHOP_REROLL"),
		"" if any_left else tr("SHOP_REROLL_NONE"),
		int(s["reroll_price"]),
		reroll_ok,
		_shards_now() < int(s["reroll_price"]),
		false,
		ShardIcon.MID,
		Plaques.of_use(&"shop_reroll")
	)
	for t: ShopTile in [heal_tile, reroll_tile]:
		for sig: Signal in [t.hovered, t.clicked]:
			for conn in sig.get_connections():
				sig.disconnect(conn["callable"])
	var h := _entries.size()
	heal_tile.hovered.connect(func() -> void: _set_focus(h))
	heal_tile.clicked.connect(func() -> void: _act(h))
	_entries.append(
		{
			"value": InputFrame.PICK_SHOP_HEAL,
			"enabled": heal_ok,
			"row": 1,
			"focus": heal_tile.set_focused,
			"node": heal_tile
		}
	)
	var r := _entries.size()
	reroll_tile.hovered.connect(func() -> void: _set_focus(r))
	reroll_tile.clicked.connect(func() -> void: _act(r))
	_entries.append(
		{
			"value": InputFrame.PICK_SHOP_REROLL,
			"enabled": reroll_ok,
			"row": 1,
			"focus": reroll_tile.set_focused,
			"node": reroll_tile
		}
	)


func _shards_now() -> int:
	return _shards_cache


func _input(event: InputEvent) -> void:
	if not _open or not input_enabled or _entries.is_empty():
		return
	var d := PanelInput.decode(event, 4, ECHO)
	match d.kind:
		PanelInput.Kind.SWALLOW:
			pass
		PanelInput.Kind.DIGIT:
			if d.digit < _cards.get_child_count():
				_set_focus(d.digit)
		PanelInput.Kind.CONFIRM:
			_act(_focus)
		PanelInput.Kind.CANCEL:
			_send(InputFrame.PICK_CANCEL)
		PanelInput.Kind.STEP:
			if d.step.x != 0:
				_set_focus(clampi(_focus + d.step.x, 0, _entries.size() - 1))
			else:
				_set_focus(_vertical(d.step.y))
		_:
			return
	get_viewport().set_input_as_handled()


## The entry in the next row up or down nearest the focused one's place in its row.
func _vertical(dir: int) -> int:
	var row := int(_entries[_focus]["row"])
	var col := _focus - _row_start(row)
	var target := row + dir
	var start := _row_start(target)
	if start < 0:
		return _focus
	var end := start
	while end + 1 < _entries.size() and int(_entries[end + 1]["row"]) == target:
		end += 1
	return mini(start + col, end)


func _row_start(row: int) -> int:
	for k in _entries.size():
		if int(_entries[k]["row"]) == row:
			return k
	return -1


func _set_focus(k: int) -> void:
	if k < 0 or k >= _entries.size():
		return
	_focus = k
	for i in _entries.size():
		(_entries[i]["focus"] as Callable).call(i == k)
	for box in _cards.get_children():
		(box.get_child(1) as Control).queue_redraw()  # v0.10.5 W3-O16: the focused card's price tag lights


## v0.10.5 W3-O16: a card's price tag: short hairlines fading out either side, brighter under the focused card.
func _draw_tag(row: Control) -> void:
	var slot := row.get_parent().get_child(0) as PickSlot
	var lit := slot != null and slot.focused
	var col := Color(AstralCardArt.LINE_HI if lit else AstralCardArt.METAL, 0.8 if lit else 0.45)
	var y := roundf(row.size.y * 0.5)
	AstralChrome.rule1(row, -12.0, y, -56.0, col)
	AstralChrome.rule1(row, row.size.x + 12.0, y, 56.0, col)
	AstralChrome.dia(row, Vector2(-8.5, y + 0.5), 2.0, col, col)
	AstralChrome.dia(row, Vector2(roundf(row.size.x) + 8.5, y + 0.5), 2.0, col, col)


func _act(k: int) -> void:
	if not _open or not input_enabled or k < 0 or k >= _entries.size():
		return
	_set_focus(k)
	if _entries[k]["enabled"]:
		_send(int(_entries[k]["value"]))


## Sends one action as input, then waits for the sim to step past it before sending another (P-12).
func _send(value: int) -> void:
	if _sent:
		return
	_sent = true
	_sent_tick = _tick
	picked.emit(value)
