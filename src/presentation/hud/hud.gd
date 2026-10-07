class_name Hud
extends Control
## The fight's HUD (PLAN v0.1.0 Step 5): health, dash and utility readiness (bottom left), wave and enemies left
## (top centre); on a floor, the carried-item icons (bottom right) and the item card (bottom centre). It never
## takes mouse input, so clicks reach the game.

const BAR := Vector2(320, 22)
## Floor (PLAN v0.2.0 F, K): a row of icons for the items you carry, a compact item card (on pickup, and as a
## preview while you stand by a pedestal), the sealed-gate note.
const CARD_SECONDS := 3.0
## Standing this close to a pedestal (m) previews its item.
const PREVIEW_M := 2.0
const ROW_ICON := 40.0
## Run flow (v0.3.0 B): the floor-title card stays this long (s), fading over the last FLOOR_CARD_FADE; the boss
## warning shows within BOSS_WARN_M of the boss door, on the near side, until it seals.
const FLOOR_CARD_SECONDS := 2.6
const FLOOR_CARD_FADE := 0.7
const BOSS_WARN_M := 6.0

var _hp_fill := ColorRect.new()
var _hp_text := Label.new()
var _dash := _pip("HUD_DASH")
var _util := _pip("HUD_UTILITY")
var _wave := Label.new()
var _left := Label.new()
var _items := HBoxContainer.new()
var _card := ItemCard.new()
var _gate := Label.new()
var _card_left := 0.0
## What the card shows: &"pickup", &"preview" or &"".
var _card_mode := &""
var _preview_item := -1
var _last_seq := 0
var _items_shown := -1
# Run flow (v0.3.0 B).
var _floor := Label.new()
var _floor_card := VBoxContainer.new()
var _floor_card_title := Label.new()
var _floor_card_biome := Label.new()
var _floor_card_left := 0.0
var _biome_key := ""


func _init() -> void:
	name = "Hud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var corner := VBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	corner.position = Vector2(28, -150)
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(corner)
	_hp_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	corner.add_child(_hp_text)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.55)
	back.custom_minimum_size = BAR
	corner.add_child(back)
	_hp_fill.color = ThemePalette.color(&"player_bar")
	_hp_fill.size = BAR
	back.add_child(_hp_fill)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 18)
	pips.add_child(_dash)
	pips.add_child(_util)
	corner.add_child(pips)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-160, 18)
	top.custom_minimum_size = Vector2(320, 0)
	add_child(top)
	_floor.name = "FloorLabel"
	_floor.add_theme_font_size_override("font_size", 22)
	for l: Label in [_floor, _wave, _left]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		top.add_child(l)
	_wave.add_theme_font_size_override("font_size", 28)
	_items.name = "ItemIcons"
	# Anchored to the bottom-right corner; it grows leftward as items are added.
	_items.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_items.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_items.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_items.alignment = BoxContainer.ALIGNMENT_END
	_items.add_theme_constant_override("separation", 6)
	add_child(_items)
	_items.offset_left = -28
	_items.offset_right = -28
	_items.offset_top = -28
	_items.offset_bottom = -28
	add_child(_card)
	_card.place_bottom_centre(-196)
	_gate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_gate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate.custom_minimum_size = Vector2(900, 0)
	_gate.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_gate.add_theme_font_size_override("font_size", 24)
	add_child(_gate)
	_gate.position = Vector2(-450, -150)
	_build_floor_card()
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func sync(reader: WorldReader) -> void:
	var hp := reader.player_hp()
	var mx := maxi(1, reader.player_max_hp())
	_hp_fill.size = Vector2(BAR.x * clampf(float(hp) / mx, 0.0, 1.0), BAR.y)
	_hp_text.text = tr("HUD_HP") % [hp, mx]
	_set_pip(_dash, reader.dash_cooldown(), reader.dash_cooldown_total())
	if reader.has_blink():
		(_util.get_child(1) as Label).text = tr("UTIL_BLINK")
		_set_pip(_util, reader.blink_cooldown(), reader.blink_cooldown_total())
	elif reader.has_guard():
		(_util.get_child(1) as Label).text = tr("UTIL_GUARD")
		_set_pip(_util, 0, 1, reader.guarding())
	_util.visible = reader.has_blink() or reader.has_guard()
	if reader.has_floor():
		var secs := int(reader.run_seconds())
		_wave.text = tr("HUD_TIME_TIER") % [secs / 60, secs % 60, reader.tier() + 1]
		_left.text = tr("HUD_KILLS") % reader.kills()
		_sync_items(reader)
	else:
		_wave.text = tr("HUD_WAVE") % [maxi(reader.wave_number(), 1), reader.wave_count()]
		_left.text = tr("HUD_ENEMIES") % reader.enemies_alive()
	_gate.text = _gate_note(reader)
	_floor.visible = reader.has_boss_room()
	if _floor.visible:
		_floor.text = tr("HUD_FLOOR") % [reader.floor_index(), tr(_biome_key)]


func _process(delta: float) -> void:
	if _card_left > 0.0:
		_card_left -= delta
	if _floor_card_left > 0.0:
		_floor_card_left -= delta
		_floor_card.modulate.a = clampf(_floor_card_left / FLOOR_CARD_FADE, 0.0, 1.0)
		_floor_card.visible = _floor_card_left > 0.0


## Run flow: names the floor's biome (a locale key) and shows the floor-title card.
func show_floor(floor_index: int, biome_key: String) -> void:
	_biome_key = biome_key
	_floor_card_title.text = tr("HUD_FLOOR_CARD") % floor_index
	_floor_card_biome.text = tr(biome_key)
	_floor_card_left = FLOOR_CARD_SECONDS
	_floor_card.modulate.a = 1.0
	_floor_card.visible = true


func floor_card_showing() -> bool:
	return _floor_card.visible


func floor_card_text() -> String:
	return "%s %s" % [_floor_card_title.text, _floor_card_biome.text]


func floor_text() -> String:
	return _floor.text


func gate_text() -> String:
	return _gate.text


## The note at the bottom: the sealed gate, the boss warning near the boss door, the open portal.
func _gate_note(reader: WorldReader) -> String:
	if not reader.has_floor():
		return ""
	if reader.has_boss_room():
		if reader.portal_active():
			return tr("HUD_PORTAL_OPEN")
		if not reader.boss_door_sealed():
			var d := reader.boss_door_depth(reader.player_pos())
			var near := reader.player_pos().distance_to(reader.boss_door_center()) <= BOSS_WARN_M
			if near and d < 0.0:
				return tr("HUD_BOSS_AHEAD")
	return tr("GATE_SEALED") if reader.at_gate() else ""


func _build_floor_card() -> void:
	_floor_card.name = "FloorCard"
	_floor_card.set_anchors_preset(Control.PRESET_CENTER)
	_floor_card.custom_minimum_size = Vector2(800, 0)
	_floor_card.position = Vector2(-400, -190)
	_floor_card.visible = false
	add_child(_floor_card)
	for l: Label in [_floor_card_title, _floor_card_biome]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", 10)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_floor_card.add_child(l)
	_floor_card_title.add_theme_font_size_override("font_size", 64)
	_floor_card_biome.add_theme_font_size_override("font_size", 34)
	_floor_card.mouse_filter = Control.MOUSE_FILTER_IGNORE


## The item card (tests and shot scripts read it).
func card() -> ItemCard:
	return _card


## &"pickup" while the card shows an item just taken, &"preview" while it shows a nearby pedestal's, else &"".
func card_mode() -> StringName:
	return _card_mode


## The number of item icons in the carried row.
func item_icon_count() -> int:
	var n := 0
	for c in _items.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


## The pickup whose item to preview: the nearest pedestal within `reach_m` of the player, or -1.
static func preview_pickup(reader: WorldReader, reach_m: float = PREVIEW_M) -> int:
	var best := -1
	var best_d := reach_m
	var p := reader.player_pos()
	for i in reader.pickup_count():
		var d := reader.pickup_pos(i).distance_to(p)
		if d <= best_d:
			best = i
			best_d = d
	return best


func _sync_items(reader: WorldReader) -> void:
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.PICKUP:
			_show_card(reader, e.amount, tr("HUD_PICKED_UP"))
			_card_mode = &"pickup"
			_card_left = CARD_SECONDS
	if _card_mode == &"pickup" and _card_left <= 0.0:
		_card_mode = &""
	if _card_mode != &"pickup":
		var near := preview_pickup(reader)
		var item := reader.pickup_item(near) if near >= 0 else -1
		if item >= 0 and (_card_mode != &"preview" or item != _preview_item):
			_show_card(reader, item, "")
			_card_mode = &"preview"
		elif item < 0 and _card_mode == &"preview":
			_card_mode = &""
		_preview_item = item
	if _card_mode == &"":
		_card.hide_card()
	var owned := reader.items_owned()
	if owned.size() == _items_shown:
		return
	_items_shown = owned.size()
	for c in _items.get_children():
		c.queue_free()
	for idx in owned:
		var id := reader.item_id(idx)
		var icon := ItemIconView.new(id, ItemLooks.color_of_id(id), true)
		icon.custom_minimum_size = Vector2(ROW_ICON, ROW_ICON)
		_items.add_child(icon)


func _show_card(reader: WorldReader, idx: int, caption: String) -> void:
	var id := reader.item_id(idx)
	_card.show_item(
		id,
		tr(reader.item_name_key(idx)),
		tr(reader.item_desc_key(idx)),
		ItemLooks.color_of_id(id),
		caption
	)


## A small square that fills as the cooldown runs out, with a label.
func _pip(key: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	var sq := ColorRect.new()
	sq.custom_minimum_size = Vector2(22, 22)
	sq.color = Color(0, 0, 0, 0.55)
	var fill := ColorRect.new()
	fill.color = ThemePalette.color(&"player_core")
	fill.size = Vector2(22, 22)
	sq.add_child(fill)
	box.add_child(sq)
	var l := Label.new()
	l.text = key
	box.add_child(l)
	return box


func _set_pip(pip: HBoxContainer, left: int, total: int, active: bool = false) -> void:
	var fill: ColorRect = pip.get_child(0).get_child(0)
	var ready := 1.0 - clampf(float(left) / maxf(1.0, total), 0.0, 1.0)
	fill.size = Vector2(22, 22 * ready)
	fill.position = Vector2(0, 22 * (1.0 - ready))
	fill.color = ThemePalette.color(&"player_core").lightened(0.4 if active else 0.0)
