class_name BuildPage
extends Control
## The pause menu's Build page (v0.6.5 WN2; docs/design/WAND.md rule 4: "Moving cards between slots is free and
## immediate"). Ember stone (MenuStyle, v0.8.0 MU) over the blurred game: the title, the wand as a row of slots
## (WandRow: each card's frame colour, icon, name and level, the trigger cards cutting the row with "cast on hit →"),
## and under it the forecast, the cards' icons in firing order. Moving a card:
## - keyboard: ←/→ (↑/↓) or 1–8 choose a card, Enter picks it up, ←/→ carry it, Enter puts it down (Esc puts it back);
## - mouse: drag a card onto a slot, or click a card then click its new slot;
## - pad: d-pad (or the left stick) chooses, A picks up, the d-pad carries, A drops (B puts it back).
## Esc, pad B or Start with nothing held goes back to the pause menu.
## The pause menu stops the sim, so this page moves a preview only: every move runs the sim's own rule
## (WorldReader.wand_moved → Wand.moved_read, EI-07) and the forecast follows live. On Back, Main turns the change
## into the fewest wand moves (planned_moves → Wand.plan_moves) and queues them as input (InputLatch); they reach the
## sim one per tick once the game runs again (EI-03, EI-04; WAND_2.md "How a move reaches the sim").
## v0.10.5 O13 (owner P10): the wand forecast (WandForecastView) under the row, following every move live.
## v0.10.5 W3-O19 (owner 2026-11-04 night: every UI element in Astral): the page in the Astral style (AstralUi): the
## game blurred under Astral's cool ink, a sigil and the title in Cinzel over a rule, the wand row, its pips and its
## forecast in Astral (their default now), Back an Astral plate.
## v0.11.0 F11 (owner, G2 F10 "option A but simpler"): no instructions and no read-back on the page; the forecast is
## the cards' icons. While a card is carried the row holds the wand as it was picked up and shows where the card will
## land (WandRow.carry_from); the order and the forecast are the preview, as before.

signal back_pressed

## Key repeats (PanelInput.Echo): Enter and Esc don't repeat; the arrows carry on.
const ECHO := PanelInput.Echo.CONFIRM_ONCE
## The forecast's width at least (px at the 1920 x 1080 base); it follows the row when that is wider.
const FORECAST_W := 620.0

var row := WandRow.new()
## v0.10.5 O13: the forecast of the order on the page.
var forecast := WandForecastView.new()
## v0.9.0 AS2 (G2 AS = B): the slot categories' pips over the wand.
var pips := SlotPips.new()
var _title := Label.new()
var _note := Label.new()
## v0.10.5 W3-P10c: the held Constellations ("Constellation: Prism ×2 · Glass Sky"; hidden while none).
var _stars := Label.new()
var _back := Button.new()
var _read := {}
var _start := PackedInt32Array()
var _slots := 0
var _held_from := -1
## v0.11.0 F11: the wand as it was when the card in the air was picked up (what the row shows meanwhile).
var _carried := {}


func _init() -> void:
	name = "BuildPage"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AstralUi.apply(self)
	var backdrop := MenuBackdrop.new()
	backdrop.astral = true  # v0.10.5 W3-O19: the game blurred under Astral's cool ink
	add_child(backdrop)
	var outer := VBoxContainer.new()  # the column sits on the left like the menus' list, centred top to bottom
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = MenuStyle.LIST_LEFT
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	var col := VBoxContainer.new()
	col.name = "Column"
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", 18)
	outer.add_child(col)
	_title.text = "UI_BUILD_TITLE"
	_title.name = "Title"
	AstralUi.title(_title)
	var head := HBoxContainer.new()  # v0.10.5 W3-O19: a sigil, the title, the slots note beside it
	head.name = "Head"
	head.add_theme_constant_override("separation", 16)
	head.add_child(AstralUi.Sigil.new(13.0))
	head.add_child(_title)
	col.add_child(head)
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	AstralUi.caps(_note, 15)
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_note)
	col.add_child(AstralUi.LeftRule.new(560.0))
	_stars.name = "Constellations"
	_stars.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	AstralUi.caps(_stars, 15, AstralCardArt.ACCENT)
	_stars.visible = false
	col.add_child(_stars)
	col.add_child(pips)
	col.add_child(row)
	col.add_child(forecast)
	_back.name = "Back"
	_back.text = "UI_BACK"
	_back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_back.focus_mode = Control.FOCUS_NONE  # the page owns the keys and the pad; Back is the mouse's way out
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	AstralUi.plate_button(_back)  # v0.10.5 W3-O19: an Astral plate
	_back.pressed.connect(func() -> void: back_pressed.emit())
	col.add_child(_back)
	row.tile_clicked.connect(_on_click)
	row.tile_dropped.connect(_on_drop)
	row.tile_hovered.connect(_on_hover)
	row.tile_drag_started.connect(_on_drag_start)
	row.tile_drag_cancelled.connect(_put_back)


## Shows `wand` (WorldReader.wand(), with any moves still waiting for a tick applied) over its `slots`; `reader`
## gives the held Constellations.
func open(wand: Dictionary, slots: int, reader: WorldReader = null) -> void:
	_read = wand
	_slots = slots
	_start = order()
	row.held = -1
	row.carry_from = -1
	row.focus = 0 if card_count() > 0 else -1
	_held_from = -1
	_show_constellations(reader.constellations() if reader != null else PackedInt32Array())
	_refresh()
	row.settle()


## v0.10.5 W3-P10c: the held Constellations line (`held`: ids in pick order; Prism held twice reads "Prism ×2").
func _show_constellations(held: PackedInt32Array) -> void:
	var names := PackedStringArray()
	var seen := PackedInt32Array()
	for id in held:
		if seen.has(id):
			continue
		seen.append(id)
		var n := held.count(id)
		names.append(tr(WorldReader.constellation_name_key(id)) + (" ×%d" % n if n > 1 else ""))
	_stars.text = tr("CONSTELLATION_KIND") + ": " + " · ".join(names)
	_stars.visible = not names.is_empty()


## The held Constellations line ("" while none): tests.
func constellations_text() -> String:
	return _stars.text if _stars.visible else ""


func card_count() -> int:
	return (_read.get("cards", []) as Array).size()


## The card codes in the page's order now.
func order() -> PackedInt32Array:
	var out := PackedInt32Array()
	for c: Dictionary in _read.get("cards", []):
		out.append(int(c["code"]))
	return out


## The wand moves (pick values) that turn the order the page opened with into its order now: what Main queues.
func planned_moves() -> PackedInt32Array:
	return WorldReader.wand_plan_moves(_start, order())


## v0.11.0 F11: the card ids the forecast shows, in firing order.
func forecast_ids() -> Array[StringName]:
	return forecast.icon_ids()


func focus_index() -> int:
	return row.focus


func held_index() -> int:
	return row.held


## The Back button (tests: the mouse's way out).
func back_button() -> Button:
	return _back


## The page's content on screen (tests: it fits the 1920 x 1080 base at 8 slots).
func content_rect() -> Rect2:
	return _back.get_parent().get_global_rect() if _back.get_parent() != null else Rect2()


func _refresh() -> void:
	row.show_wand(_carried if row.held >= 0 else _read, _slots)
	_note.text = tr("UI_BUILD_SLOTS") % [card_count(), _slots]
	pips.show_wand(_read)  # v0.9.0 AS2 (G2 AS = B; was A's counts in the note)
	forecast.custom_minimum_size.x = maxf(FORECAST_W, row.row_width())
	forecast.show_forecast(_read)


func note_text() -> String:
	return _note.text


## Moves the card in slot `from` to slot `to` in the preview (the sim's rule), true if it moved.
func _move(from: int, to: int) -> bool:
	if not WorldReader.wand_can_move(card_count(), from, to):
		return false
	_read = WorldReader.wand_moved(_read, from, to)
	return true


func _pick_up(k: int) -> void:
	if k < 0 or k >= card_count():
		return
	_carried = _read
	row.carry_from = k
	row.held = k
	row.focus = k
	_held_from = k
	_refresh()


func _drop() -> void:
	row.held = -1
	row.carry_from = -1
	_held_from = -1
	row.end_press()
	_refresh()


func _carry(step: int) -> void:
	var n := card_count()
	if row.held >= 0:
		var to := clampi(row.held + step, 0, n - 1)
		if _move(row.held, to):
			row.held = to
			row.focus = to
			_refresh()
		return
	if n > 0:
		row.focus = clampi(row.focus + step, 0, n - 1)
		row.refresh_marks()


func _cancel_or_back() -> void:
	if row.held >= 0:
		_put_back()
		return
	back_pressed.emit()


## The card in the air goes back where it was picked up (Esc, pad B, a drag released away from the slots).
func _put_back() -> void:
	if row.held < 0:
		return
	_move(row.held, _held_from)
	row.focus = _held_from
	_drop()


func _toggle_hold() -> void:
	if row.held >= 0:
		_drop()
	else:
		_pick_up(row.focus)


func _on_click(k: int) -> void:
	if row.held < 0:
		_pick_up(k)
		return
	var to := clampi(k, 0, card_count() - 1)
	_move(row.held, to)
	row.focus = to
	_drop()


func _on_drop(from: int, to: int) -> void:
	if row.held < 0 and from >= card_count():
		return
	var at := clampi(to, 0, card_count() - 1)
	_move(row.held if row.held >= 0 else from, at)  # the card in the air sits at `held` in the preview
	row.focus = at
	_drop()


func _on_drag_start(k: int) -> void:
	if row.held < 0:
		_pick_up(k)


## With a card in the air, the slot under the mouse is where it would land (an empty slot: after the last card).
func _on_hover(k: int) -> void:
	if row.held >= 0:
		var to := clampi(k, 0, card_count() - 1)
		if _move(row.held, to):
			row.held = to
			row.focus = to
			_refresh()
		return
	if k >= card_count():
		return
	row.focus = k
	row.refresh_marks()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var d := PanelInput.decode(event, 8, ECHO)
	match d.kind:
		PanelInput.Kind.SWALLOW:
			pass
		PanelInput.Kind.STEP:
			_carry(d.line())
		PanelInput.Kind.CONFIRM:
			_toggle_hold()
		PanelInput.Kind.CANCEL:
			_cancel_or_back()
		PanelInput.Kind.DIGIT:
			if row.held < 0 and d.digit < card_count():
				row.focus = d.digit
				row.refresh_marks()
		PanelInput.Kind.BUTTON:
			if d.code != JOY_BUTTON_START:
				return
			_cancel_or_back()
		_:
			return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _read.is_empty():
		_refresh()
