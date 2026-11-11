class_name Hud
extends Control
## The fight's HUD (PLAN v0.1.0 Step 5): health (bottom left; the ability squares bottom right), wave and enemies left
## (top centre); on a floor, the carried-item icons (bottom right) and the item card (bottom centre). It never
## takes mouse input, so clicks reach the game. v0.3.0 UI, calmer in v0.3.5: drawn in the
## HudStyle look (plain type, thin bars, a hairline per group); the top group shows floor, biome, time and a visual
## danger meter (no numbers); below 30 % HP the HP bar and the screen edge pulse red.
## v0.10.5 W3-O17 (owner, 2026-11-04: "and what about the rest of the UI? it should match the new style"; ASTRAL,
## W3_O13_UI_STYLE_G2.md round 2): unboxed, over a faint ink wash at the top and the bottom. Bottom left: the HP
## medallion (a ring, a four-point star, the HP rune) joined to one continuous HP bar in a hairline frame, the weapon's
## name in Cinzel over its left end and "HP n / max" over its right. Top centre: the floor line in letter-spaced Cinzel
## between two stars and fading hairlines, the time in Cinzel, the danger bar, the kills in small caps. Top right: the
## Astral shard and the wallet in Cinzel. The floor-title card is Cinzel over a star rule, on an ink veil.

## The HP plate's bar and type, 1.15 x the old 300 x 10 and 14 pt.
const BAR := Vector2(345, 12)
const HP_FONT := 16
## The carried-item row sits this far above the bottom edge: clear of the ability squares and the
## spell squares over them (px).
const ITEMS_LIFT := AbilitySquares.MARGIN_BOTTOM + AbilitySquares.SIDE + 12.0 + SpellSquares.BAND
## The plate bottom and the ability squares share one line this far above the screen bottom (owner, 2026-10-26).
const BOTTOM_LINE := AbilitySquares.MARGIN_BOTTOM
## The top plate's width (px).
const TOP_W := 540.0
## Floor (PLAN v0.2.0 F, K): a row of icons for the items you carry, a compact item card (as a
## preview while you stand by a pedestal; a pickup is a NoticeTicker line), the sealed-gate note.
## Standing this close to a pedestal (m) previews its item.
const PREVIEW_M := 2.0
const ROW_ICON := 40.0
## Rewards: the shard counter (top right) pulses this long when it grows.
const SHARD_PULSE_S := 0.3
const POOR := Color("#FF5A4D")
## The gap between the top centre's stacked lines (px).
const STACK_GAP := 6.0

## A combo's badges sit in a row above the item icons (its unlock is a NoticeTicker line).
const COMBO_BADGE := 44.0
## Each badge sits in a small stone plaque this tall (the combo's nearest colour).
const COMBO_PLAQUE_H := 96.0
## Run flow: the floor-title card stays this long (s), fading over the last FLOOR_CARD_FADE; the boss
## warning shows within BOSS_WARN_M of the boss door, on the near side, until it seals.
const FLOOR_CARD_SECONDS := 2.6
const FLOOR_CARD_FADE := 0.7
## A Deep floor's label colour (a light violet, readable on the HUD plate).
const DEEP_TEXT := Color("#C9A2FF")
const BOSS_WARN_M := 6.0
## ASTRAL: the HP bar's mid-line this far above the HP plate's foot (the medallion's centre).
const ASTRAL_BAR_FOOT := 40.0

## The boss bar, shown while a boss is alive.
var boss_bar := BossBar.new()
## Overclock heat: the heat meter, bottom centre (hidden without heat).
var heat_meter := HeatMeter.new()
## The gamble shrine's prompt, result card and stats.
var gamble := GambleHud.new()
## The minimap: the corner map, and the full map while Tab / pad Select is held.
var minimap := Minimap.new()
## The vent hint beside the heat meter.
var kit_hud := KitHud.new()
## The four ability squares (Attack, Skill, Dash, Blink), bottom right.
var ability_squares := AbilitySquares.new()
## The four spell squares, just above the ability squares.
var spell_squares := SpellSquares.new()
## The depths' answer (the floor's catch-up m), under the top plate's right end; hidden at ×1.
var depths_tag := DepthsTag.new()
## Pickups, combos and element pairs as short lines under the top plate.
var notices := NoticeTicker.new()
## The event prompt, status and panel, and threat T with the curses held.
var events := EventHud.new()
var constellation := ConstellationPanel.new()  # A new loop's Constellation pick
## The Overrun room's banner (its kills, then what clearing it paid).
var overrun_hud := OverrunHud.new()
## The Lockdown banner (sealed: its formations and enemies left; then the exits open).
var lockdown_hud := LockdownHud.new()
## v0.9.0 SH, HF: the Blood and Chaos shrines' and the fountain's result lines (the Chaos challenge's enemies left).
var shrine_hud := ShrineHud.new()
## The difficulty phase's name, and the line announcing a new phase or a new enemy kind.
var phase_hud := PhaseHud.new()
var starbound_hud := StarboundHud.new()  # The Starbound buff row, above the combo row
## The shop's prompt and panel.
var shop := ShopHud.new()
## The boss door's interact prompt.
var boss_door := BossDoorHud.new()
## The shared interactables' one prompt (the FA pylons, the timed doors' switches).
var interact := InteractPromptHud.new()
## The boss hint arrow and ping (MetaHooks sets its gate: MechanicHints).
var objective_hints := ObjectiveHints.new()
## The weapon, the utility and the six modifier slot pips; the Swap choice (over the pick and the shop).
var build_hud := BuildHud.new()
## The picked cards' icons fly over everything to their HUD slots.
var flights := CardFlights.new()
## Draws the parts below from a texture while they do not change (HudStill).
var still := HudStill.new()
var swap := SwapPanel.new()
var _hp_bar := HudBar.new()
var _hp_text := HudStyle.label(HP_FONT, true)
var _regen := RegenPulse.new()  # Green pulse on the HP bar while regenerating.
var _wave := HudStyle.label(22, true)
var _left := HudStyle.label(14)
var _items := HBoxContainer.new()
var _card := ItemCard.new()
var _gate := Label.new()
## What the card shows: &"preview" (a nearby pedestal's item) or &"".
var _card_mode := &""
var _preview_item := -1
var _last_seq := 0
var _items_shown := -1
# Rewards: the shard counter, the interact prompt by an altar or chest, the 3-card pick.
var _shards := Label.new()
var _shard_box := HBoxContainer.new()
var _shard_pulse := 0.0
var _shards_shown := -1
var _prompt := InteractPrompt.new()
var _pick := PickPanel.new()
var _combos := HBoxContainer.new()
var _combo_pending := -1
## An element pair that just turned on (its X index; -1 none): its name shows on the combo card.
var _pair_pending := -1
## That pair's new level (1-3), and the pair badges' signature (mask and levels) they were built from.
var _pair_level_pending := 3
var _pair_sig := -1
var _combos_shown := -1
# Run flow.
var _floor := HudStyle.label(16)
var _floor_card := VBoxContainer.new()
var _floor_card_title := HudStyle.label(56, true)
var _floor_card_biome := HudStyle.label(22)
var _floor_card_shards := HudStyle.label(18)  # v0.5.5 EC (Q-S4)
var _floor_card_hp := HudStyle.label(18)  # "Max HP +15" on a floor the hero grew into
var _floor_card_rule := HudStyle.label(22)  # "New rule: Quickened" on a loop's first floor
var _floor_card_left := 0.0
var _biome_key := ""
## The floor card's [floor, deep, shards lost, loop, max HP gained], so a language switch can word it again.
var _floor_card_args := []
## The hero is still arriving (the last sync): the HUD stays hidden and the floor card waits.
var _landing := false
# The danger meter, the low-HP edge glow and the groups' frames.
var _danger := DangerMeter.new()
var _vignette := LowHpVignette.new()
## ASTRAL's ink wash, the HP medallion, the weapon's name on the HP row and the floor line's stars.
var _wash := AstralHudParts.Wash.new()
var _hp_medal := AstralHudParts.HpMedal.new()
var _weapon_name := Label.new()
var _floor_marks := AstralHudParts.FloorMarks.new()
var _top_frame := HudFrame.new(Vector2(20, 8))
var _hp_frame := HudFrame.new(Vector2(16, 10))
var _corner := VBoxContainer.new()
var _shard_plate := HudFrame.new(Vector2(14, 5))
var _t := 0.0
## P-7: what each per-tick label last rendered from (slot -> value), so an unchanged one skips its format and its
## theme override; cleared on a language switch.
var _shown := {}
var _shown_locale := ""
var _reader: WorldReader  # The last sync's (a picked card's flight reads where it landed)


func _init() -> void:
	name = "Hud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wash)
	add_child(_vignette)
	add_child(objective_hints)  # Under every panel and plate
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
	_items.offset_top = -ITEMS_LIFT
	_items.offset_bottom = -ITEMS_LIFT
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
	_combos.offset_top = -ITEMS_LIFT - ROW_ICON - 12
	_combos.offset_bottom = -ITEMS_LIFT - ROW_ICON - 12
	add_child(starbound_hud)  # It places itself (StarboundHud.LIFT)
	add_child(notices)  # The ticker under the top plate
	_gate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_gate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate.custom_minimum_size = Vector2(900, 0)
	_gate.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	HudStyle.style_label(_gate, 22, true)
	HudStyle.serif_label(_gate, 22, 3)
	add_child(_gate)
	_gate.position = Vector2(-450, -150)
	_build_floor_card()
	add_child(boss_bar)
	add_child(heat_meter)
	add_child(minimap)
	_build_rewards()
	add_child(gamble)
	add_child(kit_hud)  # v0.3.5 K
	kit_hud.heat_anchor = heat_meter
	add_child(ability_squares)  # v0.9.5 HU
	add_child(spell_squares)  # v0.11.0 O10
	add_child(overrun_hud)  # v0.4.0 AB
	add_child(lockdown_hud)  # v0.9.0 LK
	add_child(shrine_hud)  # v0.9.0 SH, HF
	add_child(phase_hud)  # v0.4.0 TU
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pick)  # after the loop: the pick takes mouse input
	add_child(events)  # So do the event panel's cards; a choice is input, like a pick
	events.panel.picked.connect(_pick.picked.emit)
	add_child(constellation)  # v0.10.5 W3-P10c
	add_child(shop)  # So does the shop panel
	add_child(boss_door)  # v0.8.0 BD
	add_child(interact)  # v0.9.0 IX
	add_child(build_hud)  # v0.6.0 MX2
	build_hud.anchor = _hp_frame
	add_child(swap)  # Last, over the pick and the shop; its answer is input
	flights.squares = ability_squares  # Where a picked card's icon flies
	flights.build = build_hud
	flights.items = _items
	flights.plate = _hp_frame
	add_child(flights)
	add_child(still)
	# deferred: the HUD's slots sync after the pick panel
	_pick.card_taken.connect(
		func(code: int, from: Rect2) -> void: flights.launch.call_deferred(_reader, code, from)
	)


func _ready() -> void:
	# The run's lasting parts; panels that come and go (the pick, the shop, the swap) draw directly.
	for part: CanvasItem in [
		_corner,
		_top_frame,
		_shard_plate,
		_items,
		_combos,
		starbound_hud,
		depths_tag,
		boss_bar,
		heat_meter,
		minimap.corner,  # the map scrolls under the hero: still only while the hero stands
		minimap.ticks,  # its frame never moves
		spell_squares,
		build_hud,
	]:
		still.add_part(part)
	still.add_part(ability_squares, ability_squares.drawn_rect)  # a full-screen Control that draws in a corner


## Redraws every item of the HUD (a setting changed how they draw: the palette, reduced motion).
func redraw_all() -> void:
	for c in find_children("*", "CanvasItem", true, false):
		(c as CanvasItem).queue_redraw()


func sync(reader: WorldReader) -> void:
	_reader = reader
	if _landing != reader.arriving():  # Hidden until the hero lands, then shown
		_landing = reader.arriving()
		visible = not _landing
	var locale := TranslationServer.get_locale()
	if locale != _shown_locale:  # P-7: words again in a new language
		_shown_locale = locale
		_shown.clear()
	# Each part's cost goes to its own PerfMarks bucket "hud.<part>" (the perf log's `bd` column). Off, each
	# is one bool check. The calls keep their order.
	var t := PerfMarks.start()
	_sync_hp(reader)
	PerfMarks.add(&"hud.hp", t)
	t = PerfMarks.start()
	if reader.has_floor():
		var secs := int(reader.run_seconds())
		if _changed(&"wave", [&"HUD_TIME", secs]):
			_wave.text = tr("HUD_TIME") % [secs / 60, secs % 60]
		_danger.set_danger(reader.tier(), reader.tier_progress())
		PerfMarks.add(&"hud.danger", t)
		t = PerfMarks.start()
		depths_tag.set_multiplier(reader.catch_up_permille())
		PerfMarks.add(&"hud.depths", t)
		t = PerfMarks.start()
		var kills := reader.kills()
		if _changed(&"left", [&"HUD_KILLS", kills]):
			_left.text = tr("HUD_KILLS") % kills
		PerfMarks.add(&"hud.danger", t)
		t = PerfMarks.start()
		_sync_items(reader)
		_sync_combos(reader)
		starbound_hud.sync(reader)  # v0.10.5 W3-P10b
		PerfMarks.add(&"hud.pickups", t)
	else:
		var wave := [&"HUD_WAVE", maxi(reader.wave_number(), 1), reader.wave_count()]
		if _changed(&"wave", wave):
			_wave.text = tr("HUD_WAVE") % [wave[1], wave[2]]
		var alive := reader.enemies_alive()
		if _changed(&"left", [&"HUD_ENEMIES", alive]):
			_left.text = tr("HUD_ENEMIES") % alive
		PerfMarks.add(&"hud.danger", t)
	t = PerfMarks.start()
	_danger.visible = reader.has_floor()
	if not reader.has_floor():
		depths_tag.visible = false
	elif depths_tag.visible:
		_place_depths_tag()
	PerfMarks.add(&"hud.depths", t)
	t = PerfMarks.start()
	_sync_floor_lines(reader)
	boss_bar.sync(reader)
	heat_meter.sync(reader)
	PerfMarks.add(&"hud.top", t)
	t = PerfMarks.start()
	minimap.sync(reader)
	PerfMarks.add(&"hud.minimap", t)
	t = PerfMarks.start()
	_sync_rewards(reader)
	gamble.sync(reader)
	PerfMarks.add(&"hud.rewards", t)
	t = PerfMarks.start()
	kit_hud.sync(reader)  # v0.3.5 K
	ability_squares.sync(reader)  # v0.9.5 HU
	spell_squares.sync(reader)  # v0.11.0 O10
	PerfMarks.add(&"hud.kit", t)
	t = PerfMarks.start()
	events.sync(reader)  # v0.5.0 EV
	PerfMarks.add(&"hud.events", t)
	t = PerfMarks.start()
	overrun_hud.sync(reader)  # v0.4.0 AB
	lockdown_hud.sync(reader)  # v0.9.0 LK
	shrine_hud.sync(reader)  # v0.9.0 SH, HF
	phase_hud.sync(reader)  # v0.4.0 TU
	_stack_top_centre()  # v0.10.5 W3-O20
	PerfMarks.add(&"hud.rooms", t)
	t = PerfMarks.start()
	shop.sync(reader)  # v0.5.0 SH
	PerfMarks.add(&"hud.shop", t)
	t = PerfMarks.start()
	boss_door.sync(reader)  # v0.8.0 BD
	interact.sync(reader)  # v0.9.0 IX
	objective_hints.sync(reader)  # v0.11.0 O2
	PerfMarks.add(&"hud.prompts", t)
	t = PerfMarks.start()
	build_hud.sync(reader)  # v0.6.0 MX2
	PerfMarks.add(&"hud.build", t)
	t = PerfMarks.start()
	swap.sync(reader)
	swap.input_enabled = not _landing  # v0.8.0 N11 fix: no answer to a Swap hidden under the arrival (it would be lost)
	shop.panel.input_enabled = not reader.swapping()  # the shop waits under the swap
	PerfMarks.add(&"hud.swap", t)


## The HP bar, its text, the low-HP warning and the regen pulse.
func _sync_hp(reader: WorldReader) -> void:
	var hp := reader.player_hp()
	var mx := maxi(1, reader.player_max_hp())
	_hp_bar.set_fraction(float(hp) / mx)
	var low := HudStyle.low_hp(hp, mx)
	_hp_bar.warn = low
	_vignette.active = low
	var hp_color := HudStyle.warn() if low else HudStyle.text_color()
	if _changed(&"hp", [hp, mx, hp_color]):
		_hp_text.text = tr("HUD_HP") % [hp, mx]
		_hp_text.add_theme_color_override("font_color", hp_color)
	_regen.sync(reader, Vector2(_hp_bar.size.x * _hp_bar.shown_fraction(), _hp_bar.size.y))
	var weapon := reader.weapon_id()
	if _changed(&"weapon", weapon):
		_weapon_name.text = ""
		for a: Dictionary in reader.abilities():
			if a["id"] == weapon:
				_weapon_name.text = tr(a["name_key"])


## The gate note at the bottom and the floor line at the top.
func _sync_floor_lines(reader: WorldReader) -> void:
	_gate.text = _gate_note(reader)
	_floor.visible = reader.has_boss_room()
	if not _floor.visible:
		return
	var deep := reader.floor_is_deep()  # A Deep floor says so, in the Deep gate's violet
	var floor_index := reader.floor_index()
	var loop := reader.loop()
	if _changed(&"floor", [floor_index, deep, _biome_key, loop]):
		_floor.text = (
			loop_prefix(self, loop)
			+ tr("HUD_FLOOR_DEEP" if deep else "HUD_FLOOR") % [floor_index, tr(_biome_key)]
		)  # "Loop 2 · Floor 1 · <biome>" past the first loop
		if deep:
			_floor.add_theme_color_override("font_color", DEEP_TEXT)
		_floor_marks.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_hp_medal.warn = HudStyle.pulse(_t) if _hp_bar.warn else 0.0
	notices.advance(delta)  # v0.11.0 F12
	if _floor_card_left > 0.0 and not _landing:  # The card shows once the hero landed
		_floor_card_left -= delta
		_floor_card.modulate.a = clampf(_floor_card_left / FLOOR_CARD_FADE, 0.0, 1.0)
		_floor_card.visible = _floor_card_left > 0.0
	if _shard_pulse > 0.0:  # P-7: at rest the box keeps scale 1 (the last step of a pulse writes it)
		_shard_pulse = maxf(0.0, _shard_pulse - delta)
		_shard_box.scale = Vector2.ONE * (1.0 + 0.25 * _shard_pulse / SHARD_PULSE_S)


## Run flow: names the floor's biome (a locale key) and shows the floor-title card ("Floor 2 · Deep" on a Deep
## floor, v0.5.0 RT). `shards_lost` > 0 adds a line that the portal kept half your shards.
## `loop` > 1 puts "Loop N · " before the card's title.
func show_floor(
	floor_index: int,
	biome_key: String,
	deep: bool = false,
	shards_lost: int = 0,
	loop: int = 1,
	hp_gained: int = 0,
	rule: StringName = &""
) -> void:
	_biome_key = biome_key
	_floor_card_args = [floor_index, deep, shards_lost, loop, hp_gained, rule]
	_word_floor_card()
	_floor_card_shards.visible = shards_lost > 0
	_floor_card_hp.visible = hp_gained > 0  # v0.9.0 SV
	_floor_card_rule.visible = rule != &""  # v0.10.5 O5b
	_floor_card_left = FLOOR_CARD_SECONDS
	_floor_card.modulate.a = 1.0
	_floor_card.visible = true
	if _reader != null:  # The floor line names the biome now (the sim waits for the cover to open)
		sync(_reader)


## The floor-title card's words in the language now (again on a language switch while it shows).
func _word_floor_card() -> void:
	if _floor_card_args.is_empty():
		return
	var floor_index: int = _floor_card_args[0]
	var shards_lost: int = _floor_card_args[2]
	var card_key := "HUD_FLOOR_CARD_DEEP" if _floor_card_args[1] else "HUD_FLOOR_CARD"
	_floor_card_title.text = loop_prefix(self, _floor_card_args[3]) + tr(card_key) % floor_index
	_floor_card_biome.text = tr(_biome_key)
	_floor_card_shards.text = tr("HUD_SHARDS_HALVED") % shards_lost if shards_lost > 0 else ""
	var hp_gained: int = _floor_card_args[4]
	_floor_card_hp.text = tr("HUD_MAX_HP_GROWN") % hp_gained if hp_gained > 0 else ""
	var rule: StringName = _floor_card_args[5]  # The loop's new rule, and what it does
	_floor_card_rule.text = (
		(
			(tr("HUD_LOOP_NEW_RULE") % tr("LOOP_RULE_%s_NAME" % String(rule).to_upper()))
			+ "\n"
			+ tr("LOOP_RULE_%s_DESC" % String(rule).to_upper())
		)
		if rule != &""
		else ""
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_shown.clear()
		_word_floor_card()


## "Loop N · " (translated through `ci`) past the first loop; "" on loop 1, so a run that never ascended
## reads as before.
static func loop_prefix(ci: Object, loop: int) -> String:
	return ci.tr("HUD_LOOP") % loop + " · " if loop > 1 else ""


## P-7: true (and remembered) when `value` differs from what label `slot` last rendered from.
func _changed(slot: StringName, value: Variant) -> bool:
	if _shown.has(slot) and typeof(_shown[slot]) == typeof(value) and _shown[slot] == value:
		return false
	_shown[slot] = value
	return true


func floor_card_showing() -> bool:
	return _floor_card.visible


## The card's title and biome, then (v0.5.5 EC, Q-S4) the shard line when the portal left shards behind and (v0.9.0
## SV) the max HP line when the hero grew.
func floor_card_text() -> String:
	var out := "%s %s" % [_floor_card_title.text, _floor_card_biome.text]
	if _floor_card_shards.visible:
		out += " " + _floor_card_shards.text
	if _floor_card_rule.visible:  # v0.10.5 O5b
		out += " " + _floor_card_rule.text.replace("\n", " ")
	return out + " " + _floor_card_hp.text if _floor_card_hp.visible else out


func floor_text() -> String:
	return _floor.text


## The danger meter (tests read its tier; its fill, colour and blink).
func danger_meter() -> DangerMeter:
	return _danger


## The low-HP warning is on (the HP bar pulses red and the screen edge glows).
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
		out.append((l as Label).text)
	return out


func _build_corner() -> void:
	var corner := _corner
	corner.name = "HpCorner"
	corner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	corner.position = Vector2(28, -BOTTOM_LINE)  # The plate's bottom on the squares' line
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(corner)
	_hp_frame.name = "HpPlate"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	_hp_frame.add_child(col)
	# The medallion at the bar's left end; the weapon's name and the HP over the bar
	corner.position.x = 20.0
	var row := HBoxContainer.new()
	row.name = "HpRow"
	row.add_theme_constant_override("separation", 0)
	corner.add_child(row)
	row.add_child(_hp_medal)
	row.add_child(_hp_frame)
	_hp_frame.size_flags_vertical = Control.SIZE_SHRINK_END
	AstralHudParts.set_margins(_hp_frame, 0, 26, 0, ASTRAL_BAR_FOOT - BAR.y * 0.5)
	_hp_medal.bar_y = ASTRAL_BAR_FOOT
	col.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.name = "HpLine"
	col.add_child(top)
	_weapon_name.name = "WeaponName"
	_weapon_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_weapon_name.clip_text = true
	HudStyle.serif_label(_weapon_name, 15, 4, HudStyle.A_TEXT)
	top.add_child(_weapon_name)
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	top.add_child(_hp_text)
	_hp_bar.name = "HpBar"
	_hp_bar.color = HudStyle.hp_color()
	_hp_bar.custom_minimum_size = BAR
	col.add_child(_hp_bar)
	_hp_bar.add_child(_regen)


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
	_left.add_theme_color_override("font_color", Color(HudStyle.text_color(), 0.85))
	row.add_child(_left)
	add_child(depths_tag)
	# Cinzel, letter-spaced; the floor line between two stars
	AstralHudParts.set_margins(_top_frame, 20, 20, 2, 6)
	col.add_theme_constant_override("separation", 6)
	row.add_theme_constant_override("separation", 18)
	HudStyle.serif_label(_floor, 15, 5, HudStyle.A_TEXT)
	_floor_marks.label = _floor
	_floor.add_child(_floor_marks)
	_floor.resized.connect(_floor_marks.queue_redraw)
	HudStyle.serif_label(_wave, 22, 2, HudStyle.A_TEXT)
	HudStyle.serif_label(_left, 13, 3, HudStyle.A_DIM)


## G2 pick C: the tag hangs just under the top plate, right-aligned to its inner edge.
func _place_depths_tag() -> void:
	var tag_size := depths_tag.get_combined_minimum_size()
	depths_tag.size = tag_size
	depths_tag.position = Vector2(
		_top_frame.position.x + _top_frame.size.x - tag_size.x - 18.0,
		_top_frame.position.y + _top_frame.size.y + 3.0
	)


func gate_text() -> String:
	return _gate.text


## The note at the bottom: the sealed gate, the boss warning near the boss door, the open portal (in the boss room
## after the boss; none outside it). PB's second line ("explore the
## rest of the floor") and, on a loop's last floor, the Ascension portal's and the Loop device's lines are gone: no note
## there at all.
func _gate_note(reader: WorldReader) -> String:
	if not reader.has_floor():
		return ""
	if reader.has_boss_room():
		if reader.portal_active():
			if reader.floor_room_of(reader.player_pos()) != reader.boss_room():
				return ""
			if reader.ascension_floor():  # The Ascension portal and the Loop device speak for themselves
				return ""
			return tr("HUD_PORTALS_OPEN" if reader.has_deep_portal() else "HUD_PORTAL_OPEN")
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
	_floor_card_title.add_theme_constant_override("outline_size", 6)
	_floor_card.add_child(_floor_card_title)
	# Cinzel over a star rule, on an ink veil
	HudStyle.serif_label(_floor_card_title, 48, 8, HudStyle.A_TEXT)
	_floor_card.add_child(AstralChrome.Rule.new(220.0))
	_floor_card.draw.connect(_draw_floor_card_veil)
	var plate := HudFrame.new(Vector2(28, 4))
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_floor_card.add_child(plate)
	_floor_card_biome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_card_biome.add_theme_color_override("font_color", HudStyle.accent())
	HudStyle.serif_label(_floor_card_biome, 22, 6, HudStyle.A_ACCENT)
	plate.add_child(_floor_card_biome)
	_floor_card_shards.name = "FloorCardShards"
	_floor_card_shards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_card_shards.add_theme_color_override("font_color", HudStyle.A_ACCENT)
	_floor_card_shards.add_theme_constant_override("outline_size", 4)
	_floor_card_shards.visible = false
	_floor_card.add_child(_floor_card_shards)
	_floor_card_hp.name = "FloorCardHp"
	_floor_card_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_card_hp.add_theme_color_override("font_color", HudStyle.heal())
	_floor_card_hp.add_theme_constant_override("outline_size", 4)
	_floor_card_hp.visible = false
	_floor_card.add_child(_floor_card_hp)
	_floor_card_rule.name = "FloorCardRule"  # The loop's new rule, in the Loop device's violet
	_floor_card_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_card_rule.add_theme_color_override("font_color", DEEP_TEXT)
	_floor_card_rule.add_theme_constant_override("outline_size", 6)
	_floor_card_rule.visible = false
	_floor_card.add_child(_floor_card_rule)
	_floor_card.mouse_filter = Control.MOUSE_FILTER_IGNORE


## The floor-title card's veil (AstralChrome's store window: ink fading at its sides, two hairlines).
func _draw_floor_card_veil() -> void:
	var r := Rect2(Vector2(80, -18), Vector2(_floor_card.size.x - 160, _floor_card.size.y + 36))
	AstralChrome.veil(_floor_card, r, 160.0)


# --- Rewards -------------------------------------------------------------------------------------
## The 3-card pick panel (the app connects its `picked` signal to the input latch).
func pick_panel() -> PickPanel:
	return _pick


func shard_text() -> String:
	return _shards.text


## The interact prompt by an altar or chest ("" when none), and whether it shows the can't-afford colour.
func prompt_text() -> String:
	return _prompt.text()


func prompt_poor() -> bool:
	return _prompt.is_poor()


func _build_rewards() -> void:
	var plate := _shard_plate
	plate.name = "Shards"
	plate.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	plate.offset_left = -28
	plate.offset_right = -28
	plate.offset_top = 20
	_shard_box.add_theme_constant_override("separation", 10)
	_shard_box.add_child(ShardIcon.new(26.0, true))
	_shards.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	HudStyle.style_label(_shards, 22, true)
	_shards.add_theme_color_override("font_color", ShardIcon.LIGHT)
	# The wallet in Cinzel by the Astral shard
	HudStyle.serif_label(_shards, 26, 1, HudStyle.A_TEXT)
	(_shard_box.get_child(0) as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shard_box.add_child(_shards)
	plate.add_child(_shard_box)
	add_child(plate)
	_shard_box.pivot_offset = Vector2(20, 20)
	_prompt.name = "RewardPrompt"
	add_child(_prompt)


func _sync_rewards(reader: WorldReader) -> void:
	var n := reader.shards()
	if n != _shards_shown:
		if _shards_shown >= 0 and n > _shards_shown:
			_shard_pulse = SHARD_PULSE_S
		_shards_shown = n
		_shards.text = str(n)
	var i := reader.reward_in_reach() if not reader.choosing() else -1
	if i >= 0:
		var price := reader.reward_price(i)
		var line := ""
		if reader.reward_is_epic(i):  # v0.5.0 RT
			line = tr("REWARD_OPEN_EPIC_ALTAR")
		elif reader.reward_kind(i) == WorldReader.REWARD_DROP:  # A free card drop
			line = tr("REWARD_OPEN_DROP")
		elif reader.reward_kind(i) == WorldReader.REWARD_ALTAR:
			line = tr("REWARD_OPEN_ALTAR")
		else:  # The price shows red when you cannot pay it
			line = tr("REWARD_OPEN_CHEST") % price
		_prompt.show_prompt(reader, line, not reader.reward_affordable(i))
	else:
		_prompt.hide_prompt()
	_pick.sync(reader)
	constellation.sync(reader)  # v0.10.5 W3-P10c


## The item card (tests and shot scripts read it).
func card() -> ItemCard:
	return _card


## &"pickup" while the card shows an item just taken, &"preview" while it shows a nearby pedestal's, else &"".
func card_mode() -> StringName:
	return _card_mode


## The number of item icons in the carried row.
func item_icon_count() -> int:
	return _items.get_child_count()


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
			var face := PickPanel.card_face(self, reader, e.amount)  # A ticker line, no card
			notices.add_item(face["id"], face["color"], face["title"])
		elif e.kind == SimEvent.Kind.COMBO_UNLOCKED:
			_combo_pending = e.amount
		elif e.kind == SimEvent.Kind.PAIR_ON:  # An element pair turned on
			_pair_pending = e.amount
			_pair_level_pending = 3 if e.amount_applied <= 0 else e.amount_applied
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
		_items.remove_child(c)  # out of the row now: queue_free alone leaves it drawn and laid out this frame
		c.queue_free()
	for idx in owned:
		var id := reader.item_id(idx)
		var icon := ItemIconView.new(id, ItemLooks.color_of_id(id), true)
		icon.custom_minimum_size = Vector2(ROW_ICON, ROW_ICON)
		_items.add_child(icon)


## `idx` is a card code (an item, an ability or a stat card; PickPanel.card_face).
func _show_card(reader: WorldReader, idx: int, caption: String) -> void:
	var face := PickPanel.card_face(self, reader, idx)
	var type := int(face.get("type", -1))
	var plaque := Plaques.of_card(
		face["id"], type, int(face["tier"]), type == WorldReader.CARD_CURSE
	)
	var sentence: String = face["sentence"]
	if face.has("form_line"):  # What the card does on the form held, under the sentence
		sentence += "\n" + String(face["form_line"])
	_card.show_item(face["id"], face["title"], sentence, face["color"], caption, plaque)


## The number of combo badges in the row.
func combo_badge_count() -> int:
	var n := 0
	for c in _combos.get_children():
		if not String(c.name).begins_with("PairBadge"):
			n += 1
	return n


## A combo that just unlocked adds a ticker line; the badge row follows the combos owned.
func _sync_combos(reader: WorldReader) -> void:
	if _combo_pending >= 0:
		var c := _combo_pending
		_combo_pending = -1
		var pair := reader.combo_item_ids(c)
		notices.add_combo(reader.combo_id(c), pair[0], pair[1], tr(reader.combo_name_key(c)))
	if _pair_pending >= 0:  # An element pair: a ticker line, the two element icons, its name and level
		var x := _pair_pending
		_pair_pending = -1
		var cards := reader.pair_card_ids(x)
		notices.add_pair(
			reader.pair_id(x), cards[0], cards[1], tr(reader.pair_name_key(x)), _pair_level_pending
		)
	_sync_pair_badges(reader)
	var owned := reader.combos_owned()
	if owned.size() == _combos_shown:
		return
	_combos_shown = owned.size()
	for c in _combos.get_children():
		_combos.remove_child(c)
		c.queue_free()
	_pair_sig = -1  # the pair badges follow the combo badges in the row
	for c in owned:
		var pair := reader.combo_item_ids(c)
		var col := ItemLooks.combo_color(reader.combo_id(c))
		var plate := PanelContainer.new()
		plate.name = "ComboBadge%d" % c
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		plate.add_theme_stylebox_override(
			"panel", Plaques.box(Plaques.nearest(col), COMBO_PLAQUE_H)
		)
		var badge := ComboIconView.new(pair[0], pair[1], col, false)
		badge.custom_minimum_size = Vector2(COMBO_BADGE, COMBO_BADGE)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plate.add_child(badge)
		_combos.add_child(plate)
	_sync_pair_badges(reader)


## One badge per pair that is on (PairBadge<X>: its two element icons and "Lv N"), after the combo badges;
## rebuilt when the mask or any level changes.
func _sync_pair_badges(reader: WorldReader) -> void:
	var sig := reader.pair_mask()
	for x in reader.pair_count():
		sig = sig * 4 + reader.pair_level(x) if (sig >> x) & 1 == 1 else sig * 4
	if sig == _pair_sig:
		return
	_pair_sig = sig
	for c in _combos.get_children():
		if String(c.name).begins_with("PairBadge"):
			_combos.remove_child(c)
			c.queue_free()
	var mask := reader.pair_mask()
	for x in reader.pair_count():
		if (mask >> x) & 1 == 0:
			continue
		var cards := reader.pair_card_ids(x)
		var col := ItemLooks.combo_color(reader.pair_id(x))
		var plate := PanelContainer.new()
		plate.name = "PairBadge%d" % x
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		plate.add_theme_stylebox_override(
			"panel", Plaques.box(Plaques.nearest(col), COMBO_PLAQUE_H)
		)
		var col_box := VBoxContainer.new()
		col_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col_box.alignment = BoxContainer.ALIGNMENT_CENTER
		var badge := ComboIconView.new(cards[0], cards[1], col, false)
		badge.custom_minimum_size = Vector2(COMBO_BADGE, COMBO_BADGE)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col_box.add_child(badge)
		var lv := HudStyle.label(14, true)
		lv.name = "Level"
		lv.text = tr("UI_WAND_LEVEL") % reader.pair_level(x)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col_box.add_child(lv)
		plate.add_child(col_box)
		_combos.add_child(plate)


## v0.10.5 W3-O20 (the W3-O17 boss shot: the phase line drew over the boss bar's lines, the tips over the phase's
## announcement): the top centre's lines stack. The phase line (PhaseHud, its announcement under it) sits under
## whichever of the boss bar and the room banners (arena, Lockdown, shrine) is shown, PhaseHud.TOP at the least; the
## first-run tips (OnboardingHints.stack_under) sit under the phase's lines in turn. A look only (EI-07).
func _stack_top_centre() -> void:
	var y := PhaseHud.TOP
	var under := -1.0  # the lowest bottom of the boss bar and the room banners (-1: none shown)
	if boss_bar.visible:
		under = boss_bar.bottom() + STACK_GAP
	for b: Control in [overrun_hud, lockdown_hud, shrine_hud]:
		if b.visible:
			under = maxf(under, b.offset_top + b.get_combined_minimum_size().y + STACK_GAP)
	y = maxf(y, under)
	# The notice ticker hangs under the top plate, or under those banners; the phase line goes under it.
	var top := _top_frame.position.y + _top_frame.size.y + 3.0
	if under > 0.0:
		top = maxf(top, under)
	if notices.position.x != _top_frame.position.x or notices.position.y != top:
		notices.position = Vector2(_top_frame.position.x, top)
	notices.size = Vector2(TOP_W, notices.get_combined_minimum_size().y)
	if not notices.is_empty():
		y = maxf(y, top + notices.stack_height() + STACK_GAP)
	if phase_hud.offset_top != y:
		phase_hud.offset_top = y
