class_name ShopPanel
extends Control
## The shop panel (v0.5.0 SH): while the sim waits on the open shop, the stock (the pick's cards, PickSlot, in the
## current CardStyle, with a price and the shard icon under each), the heal and the reroll, and the salvage list
## (every mod, stat card and ability but the weapon you can sell, with its refund). It shows what the sim offers and
## sends the player's choice as input (`picked` → InputLatch.note_pick → InputFrame.pick); it decides nothing.
## A card you can't afford or can't use, a spent heal and an unaffordable reroll are dimmed and send nothing.
## v0.5.5 EC (owner S2, S3): a line under the title shows how many cards you can still buy on this floor; at the limit
## it turns red and says so, the unsold cards and the reroll dim and send nothing. A reroll with every slot sold
## dims too ("Nothing left to reroll"): rerolls redraw only the unsold slots.
## - Mouse: hover focuses, a click acts.
## - Keyboard: arrows move the focus (left / right along a row, up / down between rows), 1-4 jump to a card, Enter
##   buys or sells, Esc leaves.
## - Pad: d-pad or left stick moves the focus, A (Cross) acts, B (Circle) leaves.
## Space (dash) never confirms: the panel doesn't use ui_accept.

signal picked(value: int)

const SALVAGE_COLUMNS := 4
## v0.5.5 A4: the stock's crystal cards are drawn a little smaller than the pick's, so the services and the salvage
## list still fit under them at 1080p.
const CARD_SCALE := 0.92
const POOR := Color("#FF5A4D")

## Off while a menu sits over the panel.
var input_enabled := true
var heal_tile := ShopTile.new("ShopHeal", 220.0)
var reroll_tile := ShopTile.new("ShopReroll", 220.0)
## v0.5.0 EV: lift your latest curse (shown only while you hold one).
var cleanse_tile := ShopTile.new("ShopCleanse", 260.0)
var _dim := ColorRect.new()
var _title := Label.new()
var _shards := Label.new()
var _buys := Label.new()
var _hint := Label.new()
var _salvage_title := Label.new()
var _salvage_none := Label.new()
var _cards := HBoxContainer.new()
var _salvage := GridContainer.new()
## Focusable entries in reading order: {value, enabled, row, focus (Callable), node}.
var _entries: Array[Dictionary] = []
var _focus := 0
var _open := false
var _sig := ""
var _shards_cache := 0
var _limit := false


func _init() -> void:
	name = "ShopPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	centre.add_child(col)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	head.add_child(_title)
	var icon := ShardIcon.new(26.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	head.add_child(_shards)
	col.add_child(head)
	_buys.name = "ShopBuys"
	col.add_child(_buys)
	_cards.name = "ShopCards"
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.add_theme_constant_override("separation", 16)
	col.add_child(_cards)
	var services := HBoxContainer.new()
	services.alignment = BoxContainer.ALIGNMENT_CENTER
	services.mouse_filter = Control.MOUSE_FILTER_IGNORE
	services.add_theme_constant_override("separation", 16)
	services.add_child(heal_tile)
	services.add_child(reroll_tile)
	services.add_child(cleanse_tile)
	col.add_child(services)
	col.add_child(_salvage_title)
	_salvage.name = "ShopSalvage"
	_salvage.columns = SALVAGE_COLUMNS
	_salvage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_salvage.add_theme_constant_override("h_separation", 12)
	_salvage.add_theme_constant_override("v_separation", 10)
	_salvage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_salvage)
	col.add_child(_salvage_none)
	col.add_child(_hint)
	HudStyle.style_label(_title, 26, true)
	HudStyle.style_label(_shards, 24, true)
	HudStyle.style_label(_salvage_title, 19, true)
	HudStyle.style_label(_salvage_none, 15)
	HudStyle.style_label(_hint, 15)
	HudStyle.style_label(_buys, 16)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_salvage_none.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	for l: Label in [_title, _shards, _buys, _hint, _salvage_title, _salvage_none]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Opens, refreshes or closes from the sim's state.
func sync(reader: WorldReader) -> void:
	if not reader.has_shop() or not reader.shop_open():
		if _open:
			_open = false
			_sig = ""
			visible = false
		return
	var s := reader.shop()
	var sig := var_to_str(
		[
			s["stock"],
			s["sell"],
			s["heal_used"],
			s["heal_amount"],
			s["reroll_price"],
			s["cleanse_curse"],
			s["cleanse_price"],
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


func is_open() -> bool:
	return _open


func focus_index() -> int:
	return _focus


## The focused entry's pick value (InputFrame.PICK_*), or PICK_NONE.
func focused_value() -> int:
	return int(_entries[_focus]["value"]) if _focus < _entries.size() else InputFrame.PICK_NONE


func entry_count() -> int:
	return _entries.size()


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


func salvage_count() -> int:
	return _salvage.get_child_count()


func salvage_tile(n: int) -> ShopTile:
	return _salvage.get_child(n) as ShopTile


func title_text() -> String:
	return _title.text


## v0.5.5 EC (S3): the buys line ("Cards you can still buy on this floor: 3", or the limit's message).
func buys_text() -> String:
	return _buys.text


func buys_at_limit() -> bool:
	return _limit


func _render(reader: WorldReader, s: Dictionary) -> void:
	_entries.clear()
	for c in _cards.get_children() + _salvage.get_children():
		c.get_parent().remove_child(c)
		c.free()  # now, not at the frame's end: the panel re-renders from the tick, never from a child's signal
	_title.text = tr("SHOP_TITLE")
	_shards_cache = reader.shards()
	_shards.text = str(_shards_cache)
	_hint.text = tr("SHOP_HINT")
	var left := int(s["buys_left"])
	_limit = left == 0
	_buys.visible = left >= 0
	if _limit:
		_buys.text = tr("SHOP_BUYS_DONE") % [int(s["bought"]), int(s["max_buys"])]
	else:
		_buys.text = tr("SHOP_BUYS_LEFT") % left
	_buys.add_theme_color_override("font_color", POOR if _limit else Color(1, 1, 1, 0.8))
	var stock: Array = s["stock"]
	for k in stock.size():
		_add_card(reader, k, stock[k])
	_render_services(s)
	_salvage_title.text = tr("SHOP_SALVAGE")
	var sells: Array = s["sell"]
	_salvage_none.text = tr("SHOP_SALVAGE_NONE")
	_salvage_none.visible = sells.is_empty()
	_salvage.columns = clampi(sells.size(), 1, SALVAGE_COLUMNS)
	for n in sells.size():
		_add_sell(reader, n, sells[n])
	for e in _entries:
		var node: Control = e["node"]
		for c in node.find_children("*", "Control", true, false):
			if not c is PickSlot and not c is ShopTile:
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _add_card(reader: WorldReader, k: int, c: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.name = "ShopCard%d" % (k + 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	var slot := PickSlot.new(k, CARD_SCALE)
	box.add_child(slot)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var icon := ShardIcon.new(20.0)
	var price := HudStyle.label(18, true)
	price.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(icon)
	row.add_child(price)
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
	price.add_theme_color_override(
		"font_color", POOR if not sold and c["can_apply"] and not c["affordable"] else Color.WHITE
	)
	slot.modulate = Color(1, 1, 1, 1.0 if ok else 0.45)
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
		Color("#9CF29C")
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
		ShardIcon.MID
	)
	for t: ShopTile in [heal_tile, reroll_tile, cleanse_tile]:
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
	_render_cleanse(s)


## v0.5.0 EV: the paid cleanse, while a curse is held (its name on the tile; Shop.cleanse lifts the latest).
func _render_cleanse(s: Dictionary) -> void:
	var curse := int(s["cleanse_curse"])
	cleanse_tile.visible = curse >= 0
	if curse < 0:
		return
	var ok := _shards_now() >= int(s["cleanse_price"])
	cleanse_tile.show_tile(
		tr("SHOP_CLEANSE"),
		tr(s["cleanse_name_key"]),
		int(s["cleanse_price"]),
		ok,
		not ok,
		false,
		CurseLook.COLOR
	)
	var c := _entries.size()
	cleanse_tile.hovered.connect(func() -> void: _set_focus(c))
	cleanse_tile.clicked.connect(func() -> void: _act(c))
	_entries.append(
		{
			"value": InputFrame.PICK_SHOP_CLEANSE,
			"enabled": ok,
			"row": 1,
			"focus": cleanse_tile.set_focused,
			"node": cleanse_tile
		}
	)


func _add_sell(reader: WorldReader, n: int, e: Dictionary) -> void:
	var code := int(e["code"])
	var face := PickPanel.card_face(self, reader, code)
	var info := reader.card_info(code)
	var detail := ""
	match int(e["kind"]):
		WorldReader.SHOP_SELL_MOD:
			detail = tr("UI_CARD_MOD")
		WorldReader.SHOP_SELL_STAT:
			var rarity: String = tr(
				["RARITY_COMMON", "RARITY_RARE", "RARITY_EPIC", "RARITY_LEGENDARY"][int(
					info["rarity"]
				)]
			)
			detail = tr("SHOP_SELL_STAT") % [rarity, int(e["ref"])]
		WorldReader.SHOP_SELL_ABILITY:
			var lvl := int(reader.abilities()[int(e["ref"])]["level"])
			detail = tr("SHOP_SELL_ABILITY") % lvl
	var tile := ShopTile.new("ShopSell%d" % (n + 1), 200.0)
	tile.show_tile(face["title"], detail, int(e["refund"]), true, false, true, face["color"])
	_salvage.add_child(tile)
	var at := _entries.size()
	tile.hovered.connect(func() -> void: _set_focus(at))
	tile.clicked.connect(func() -> void: _act(at))
	_entries.append(
		{
			"value": InputFrame.PICK_SHOP_SELL + n,
			"enabled": true,
			"row": 2 + n / SALVAGE_COLUMNS,
			"focus": tile.set_focused,
			"node": tile
		}
	)


func _shards_now() -> int:
	return _shards_cache


func _input(event: InputEvent) -> void:
	if not _open or not input_enabled or _entries.is_empty():
		return
	var step := Vector2i.ZERO
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				var k: int = event.physical_keycode - KEY_1
				if k < _cards.get_child_count():
					_set_focus(k)
			KEY_ENTER, KEY_KP_ENTER:
				_act(_focus)
			KEY_ESCAPE:
				picked.emit(InputFrame.PICK_CANCEL)
			KEY_LEFT:
				step = Vector2i(-1, 0)
			KEY_RIGHT:
				step = Vector2i(1, 0)
			KEY_UP:
				step = Vector2i(0, -1)
			KEY_DOWN:
				step = Vector2i(0, 1)
			_:
				return
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				_act(_focus)
			JOY_BUTTON_B:
				picked.emit(InputFrame.PICK_CANCEL)
			JOY_BUTTON_DPAD_LEFT:
				step = Vector2i(-1, 0)
			JOY_BUTTON_DPAD_RIGHT:
				step = Vector2i(1, 0)
			JOY_BUTTON_DPAD_UP:
				step = Vector2i(0, -1)
			JOY_BUTTON_DPAD_DOWN:
				step = Vector2i(0, 1)
			_:
				return
	elif event is InputEventJoypadMotion:
		if event.is_action_pressed(&"ui_left"):
			step = Vector2i(-1, 0)
		elif event.is_action_pressed(&"ui_right"):
			step = Vector2i(1, 0)
		elif event.is_action_pressed(&"ui_up"):
			step = Vector2i(0, -1)
		elif event.is_action_pressed(&"ui_down"):
			step = Vector2i(0, 1)
		else:
			return
	else:
		return
	if step.x != 0:
		_set_focus(clampi(_focus + step.x, 0, _entries.size() - 1))
	elif step.y != 0:
		_set_focus(_vertical(step.y))
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


func _act(k: int) -> void:
	if not _open or not input_enabled or k < 0 or k >= _entries.size():
		return
	_set_focus(k)
	if _entries[k]["enabled"]:
		picked.emit(int(_entries[k]["value"]))
