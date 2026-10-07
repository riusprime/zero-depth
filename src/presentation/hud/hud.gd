class_name Hud
extends Control
## The fight's HUD (PLAN v0.1.0 Step 5): health, dash and utility readiness (bottom left), wave and enemies left
## (top centre); on a floor, the carried-item icons (bottom right) and the item card (bottom centre). It never
## takes mouse input, so clicks reach the game. v0.3.0 UI (L21, L23, L24): drawn in the HudStyle look (techno/echo
## type, plates and bars; values echo when they change); the top plate shows floor, biome, time and a visual danger
## meter (no numbers); below 30 % HP the HP bar and the screen edge pulse red.

const BAR := Vector2(320, 18)
## The top plate's width (px).
const TOP_W := 540.0
## Floor (PLAN v0.2.0 F, K): a row of icons for the items you carry, a compact item card (on pickup, and as a
## preview while you stand by a pedestal), the sealed-gate note.
const CARD_SECONDS := 3.0
## Standing this close to a pedestal (m) previews its item.
const PREVIEW_M := 2.0
const ROW_ICON := 40.0
## Rewards (v0.3.0 E): the shard counter (top right) pulses this long when it grows.
const SHARD_PULSE_S := 0.3
const POOR := Color("#FF5A4D")

## v0.3.0 G: a combo's card stays this long, above the item card; its badges sit in a row above the item icons.
const COMBO_CARD_SECONDS := 4.0
const COMBO_BADGE := 44.0
## Run flow (v0.3.0 B): the floor-title card stays this long (s), fading over the last FLOOR_CARD_FADE; the boss
## warning shows within BOSS_WARN_M of the boss door, on the near side, until it seals.
const FLOOR_CARD_SECONDS := 2.6
const FLOOR_CARD_FADE := 0.7
const BOSS_WARN_M := 6.0

## The boss bar (v0.3.0 C), shown while a boss is alive.
var boss_bar := BossBar.new()
## Overclock heat (v0.3.0 L18): the heat meter, bottom centre (hidden without heat).
var heat_meter := HeatMeter.new()
## The gamble shrine's prompt, result card and stats (v0.3.0 L19).
var gamble := GambleHud.new()
## The minimap (v0.3.0 MM): the corner map, and the full map while Tab / pad Select is held.
var minimap := Minimap.new()
var _hp_bar := HudBar.new()
var _hp_text := EchoLabel.new(15, true)
var _dash := _pip("HUD_DASH")
var _util := _pip("HUD_UTILITY")
var _wave := EchoLabel.new(26, true)
var _left := EchoLabel.new(13)
var _items := HBoxContainer.new()
var _card := ItemCard.new()
var _gate := Label.new()
var _card_left := 0.0
## What the card shows: &"pickup", &"preview" or &"".
var _card_mode := &""
var _preview_item := -1
var _last_seq := 0
var _items_shown := -1
# Rewards (v0.3.0 E): the shard counter, the interact prompt by an altar or chest, the 3-card pick.
var _shards := Label.new()
var _shard_box := HBoxContainer.new()
var _shard_pulse := 0.0
var _shards_shown := -1
var _prompt := Label.new()
var _pick := PickPanel.new()
var _combos := HBoxContainer.new()
var _combo_card := ComboCard.new()
var _combo_left := 0.0
var _combo_pending := -1
var _combos_shown := -1
# Run flow (v0.3.0 B).
var _floor := EchoLabel.new(18, true)
var _floor_card := VBoxContainer.new()
var _floor_card_title := EchoLabel.new(76, true)
var _floor_card_biome := EchoLabel.new(28)
var _floor_card_left := 0.0
var _biome_key := ""
# v0.3.0 UI: the danger meter (L23), the low-HP edge glow (L24) and the style's plates.
var _danger := DangerMeter.new()
var _vignette := LowHpVignette.new()
var _top_frame := HudFrame.new(Vector2(18, 6))
var _hp_frame := HudFrame.new(Vector2(14, 8))
var _t := 0.0


func _init() -> void:
	name = "Hud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	_build_corner()
	_build_top()
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
	_combos.name = "ComboBadges"
	_combos.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_combos.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_combos.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_combos.alignment = BoxContainer.ALIGNMENT_END
	_combos.add_theme_constant_override("separation", 8)
	add_child(_combos)
	_combos.offset_left = -28
	_combos.offset_right = -28
	_combos.offset_top = -28 - ROW_ICON - 12
	_combos.offset_bottom = -28 - ROW_ICON - 12
	add_child(_combo_card)
	_combo_card.place_bottom_centre(-300)
	_gate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_gate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate.custom_minimum_size = Vector2(900, 0)
	_gate.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	HudStyle.style_label(_gate, 22, true)
	add_child(_gate)
	_gate.position = Vector2(-450, -150)
	_build_floor_card()
	add_child(boss_bar)
	add_child(heat_meter)
	add_child(minimap)
	_build_rewards()
	add_child(gamble)
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pick)  # after the loop: the pick takes mouse input


func sync(reader: WorldReader) -> void:
	var hp := reader.player_hp()
	var mx := maxi(1, reader.player_max_hp())
	_hp_bar.set_fraction(float(hp) / mx)
	_hp_text.text = tr("HUD_HP") % [hp, mx]
	var low := HudStyle.low_hp(hp, mx)
	_hp_bar.warn = low
	_vignette.active = low
	_hp_text.add_theme_color_override("font_color", HudStyle.WARN if low else HudStyle.text_color())
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
		_wave.text = tr("HUD_TIME") % [secs / 60, secs % 60]
		_danger.set_danger(reader.tier(), reader.tier_progress())
		_left.text = tr("HUD_KILLS") % reader.kills()
		_sync_items(reader)
		_sync_combos(reader)
	else:
		_wave.text = tr("HUD_WAVE") % [maxi(reader.wave_number(), 1), reader.wave_count()]
		_left.text = tr("HUD_ENEMIES") % reader.enemies_alive()
	_danger.visible = reader.has_floor()
	_gate.text = _gate_note(reader)
	_floor.visible = reader.has_boss_room()
	if _floor.visible:
		_floor.text = tr("HUD_FLOOR") % [reader.floor_index(), tr(_biome_key)]
	boss_bar.sync(reader)
	heat_meter.sync(reader)
	minimap.sync(reader)
	_sync_rewards(reader)
	gamble.sync(reader)


func _process(delta: float) -> void:
	_t += delta
	_hp_frame.tint = (
		Color.WHITE.lerp(HudStyle.WARN, HudStyle.pulse(_t)) if _hp_bar.warn else Color.WHITE
	)
	if _card_left > 0.0:
		_card_left -= delta
	if _combo_left > 0.0:
		_combo_left -= delta
	if _floor_card_left > 0.0:
		_floor_card_left -= delta
		_floor_card.modulate.a = clampf(_floor_card_left / FLOOR_CARD_FADE, 0.0, 1.0)
		_floor_card.visible = _floor_card_left > 0.0
	if _shard_pulse > 0.0:
		_shard_pulse = maxf(0.0, _shard_pulse - delta)
	_shard_box.scale = Vector2.ONE * (1.0 + 0.25 * _shard_pulse / SHARD_PULSE_S)


## Run flow: names the floor's biome (a locale key) and shows the floor-title card.
func show_floor(floor_index: int, biome_key: String) -> void:
	_biome_key = biome_key
	_floor_card_title.text = ""  # a fresh card always echoes in
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


## v0.3.0 UI: the danger meter (tests read its tier, lit chevrons and segments).
func danger_meter() -> DangerMeter:
	return _danger


## v0.3.0 UI: the low-HP warning is on (the HP bar pulses red and the screen edge glows).
func low_hp_warning() -> bool:
	return _hp_bar.warn and _vignette.active


func hp_bar() -> HudBar:
	return _hp_bar


func vignette() -> LowHpVignette:
	return _vignette


## The top plate's text, all of it (tests: the danger meter adds no digits).
func top_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for l in _top_frame.find_children("*", "Label", true, false):
		if not l.get_parent() is EchoLabel:  # an echo's ghosts repeat its text
			out.append((l as Label).text)
	return out


func _build_corner() -> void:
	var corner := VBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	corner.position = Vector2(28, -160)
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(corner)
	_hp_frame.name = "HpPlate"
	corner.add_child(_hp_frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	_hp_frame.add_child(col)
	col.add_child(_hp_text)
	_hp_bar.name = "HpBar"
	_hp_bar.color = ThemePalette.color(&"player_bar")
	_hp_bar.custom_minimum_size = BAR
	col.add_child(_hp_bar)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 18)
	pips.add_child(_dash)
	pips.add_child(_util)
	col.add_child(pips)


## The top plate: "FLOOR 01 // RUINS" over the run time, the danger meter and the kills.
func _build_top() -> void:
	_top_frame.name = "TopPlate"
	_top_frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_top_frame.position = Vector2(-TOP_W * 0.5, 10)
	_top_frame.custom_minimum_size = Vector2(TOP_W, 0)
	add_child(_top_frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_top_frame.add_child(col)
	_floor.name = "FloorLabel"
	_floor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor.add_theme_color_override("font_color", HudStyle.accent())
	col.add_child(_floor)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	_wave.name = "TimeLabel"
	_wave.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_wave)
	_danger.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_danger)
	_left.name = "KillsLabel"
	_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_left.add_theme_color_override("font_color", Color(HudStyle.text_color(), 0.7))
	row.add_child(_left)


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
	_floor_card.position = Vector2(-400, -200)
	_floor_card.add_theme_constant_override("separation", 4)
	_floor_card.visible = false
	add_child(_floor_card)
	_floor_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_card_title.add_theme_constant_override("outline_size", 10)
	_floor_card.add_child(_floor_card_title)
	var plate := HudFrame.new(Vector2(28, 4))
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_floor_card.add_child(plate)
	_floor_card_biome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_card_biome.add_theme_color_override("font_color", HudStyle.accent())
	plate.add_child(_floor_card_biome)
	_floor_card.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Rewards (v0.3.0 E) -------------------------------------------------------------------------------------
## The 3-card pick panel (the app connects its `picked` signal to the input latch).
func pick_panel() -> PickPanel:
	return _pick


func shard_text() -> String:
	return _shards.text


## The interact prompt by an altar or chest ("" when none), and whether it shows the can't-afford colour.
func prompt_text() -> String:
	return _prompt.text if _prompt.visible else ""


func prompt_poor() -> bool:
	return _prompt.get_theme_color(&"font_color") == POOR


func _build_rewards() -> void:
	var plate := HudFrame.new(Vector2(14, 5))
	plate.name = "Shards"
	plate.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	plate.offset_left = -28
	plate.offset_right = -28
	plate.offset_top = 20
	_shard_box.add_theme_constant_override("separation", 10)
	_shard_box.add_child(ShardIcon.new(30.0))
	_shards.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	HudStyle.style_label(_shards, 26, true)
	_shards.add_theme_color_override("font_color", ShardIcon.LIGHT)
	_shard_box.add_child(_shards)
	plate.add_child(_shard_box)
	add_child(plate)
	_shard_box.pivot_offset = Vector2(20, 20)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.custom_minimum_size = Vector2(900, 0)
	_prompt.position = Vector2(-450, -112)
	_prompt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	HudStyle.style_label(_prompt, 22, true)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_prompt)


func _sync_rewards(reader: WorldReader) -> void:
	var n := reader.shards()
	if n != _shards_shown:
		if _shards_shown >= 0 and n > _shards_shown:
			_shard_pulse = SHARD_PULSE_S
		_shards_shown = n
		_shards.text = str(n)
	var i := reader.reward_in_reach() if not reader.choosing() else -1
	_prompt.visible = i >= 0
	if i >= 0:
		var price := reader.reward_price(i)
		if reader.reward_kind(i) == WorldReader.REWARD_ALTAR:
			_prompt.text = tr("REWARD_OPEN_ALTAR")
		elif reader.reward_affordable(i):
			_prompt.text = tr("REWARD_OPEN_CHEST") % price
		else:
			_prompt.text = tr("REWARD_TOO_POOR") % [reader.shards(), price]
		_prompt.add_theme_color_override(
			"font_color", HudStyle.text_color() if reader.reward_affordable(i) else POOR
		)
	_pick.sync(reader)


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
		elif e.kind == SimEvent.Kind.COMBO_UNLOCKED:
			_combo_pending = e.amount
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


## The combo card (tests and shot scripts read it).
func combo_card() -> ComboCard:
	return _combo_card


## The number of combo badges in the row.
func combo_badge_count() -> int:
	var n := 0
	for c in _combos.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


## v0.3.0 G: a combo that just unlocked shows its card; the badge row follows the combos owned.
func _sync_combos(reader: WorldReader) -> void:
	if _combo_pending >= 0:
		var c := _combo_pending
		_combo_pending = -1
		var pair := reader.combo_item_ids(c)
		_combo_card.show_combo(
			reader.combo_id(c),
			pair[0],
			pair[1],
			tr(reader.combo_name_key(c)),
			tr(reader.combo_desc_key(c)),
			tr("UI_COMBO_UNLOCKED")
		)
		_combo_left = COMBO_CARD_SECONDS
	if _combo_left <= 0.0 and _combo_card.is_showing():
		_combo_card.hide_card()
	var owned := reader.combos_owned()
	if owned.size() == _combos_shown:
		return
	_combos_shown = owned.size()
	for c in _combos.get_children():
		c.queue_free()
	for c in owned:
		var pair := reader.combo_item_ids(c)
		var badge := ComboIconView.new(
			pair[0], pair[1], ItemLooks.combo_color(reader.combo_id(c)), true
		)
		badge.custom_minimum_size = Vector2(COMBO_BADGE, COMBO_BADGE)
		_combos.add_child(badge)


## A small square that fills as the cooldown runs out, with a label.
func _pip(key: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var sq := ColorRect.new()
	sq.custom_minimum_size = Vector2(22, 22)
	sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sq.color = HudStyle.dim()
	var fill := ColorRect.new()
	fill.color = ThemePalette.color(&"player_core")
	fill.size = Vector2(22, 22)
	sq.add_child(fill)
	box.add_child(sq)
	var l := Label.new()
	l.text = key
	HudStyle.style_label(l, 14, true)
	box.add_child(l)
	return box


func _set_pip(pip: HBoxContainer, left: int, total: int, active: bool = false) -> void:
	var fill: ColorRect = pip.get_child(0).get_child(0)
	var ready := 1.0 - clampf(float(left) / maxf(1.0, total), 0.0, 1.0)
	fill.size = Vector2(22, 22 * ready)
	fill.position = Vector2(0, 22 * (1.0 - ready))
	fill.color = ThemePalette.color(&"player_core").lightened(0.4 if active else 0.0)
