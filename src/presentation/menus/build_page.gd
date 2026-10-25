class_name BuildPage
extends Control
## The pause menu's Build page (v0.6.5 WN2; docs/design/WAND.md rule 4: "Moving cards between slots is free and
## immediate"). Ember stone (MenuStyle, v0.8.0 MU) over the blurred game: the title, the wand as a row of slots
## (WandRow: each card's frame colour, icon, name and level, the trigger cards cutting the row with "cast on hit →"),
## and under it the plain-words read-back (Wand.describe / render through WorldReader, en + es). Moving a card:
## - keyboard: ←/→ (↑/↓) or 1–8 choose a card, Enter picks it up, ←/→ carry it, Enter puts it down (Esc puts it back);
## - mouse: drag a card onto a slot, or click a card then click its new slot;
## - pad: d-pad (or the left stick) chooses, A picks up, the d-pad carries, A drops (B puts it back).
## Esc, pad B or Start with nothing held goes back to the pause menu.
## The pause menu stops the sim, so this page moves a preview only: every move runs the sim's own rule
## (WorldReader.wand_moved → Wand.moved_read, EI-07) and the read-back follows live. On Back, Main turns the change
## into the fewest wand moves (planned_moves → Wand.plan_moves) and queues them as input (InputLatch); they reach the
## sim one per tick once the game runs again (EI-03, EI-04; WAND_2.md "How a move reaches the sim").

signal back_pressed

## The read-back's width at most (px at the 1920 x 1080 base) and its type size.
## Key repeats (PanelInput.Echo): Enter and Esc don't repeat; the arrows carry on.
const ECHO := PanelInput.Echo.CONFIRM_ONCE
const READ_W := 1180.0
const READ_SIZE := 22

var row := WandRow.new()
## v0.9.0 AS2 (G2 AS = B): the slot categories' pips over the wand.
var pips := SlotPips.new()
var _title := Label.new()
var _note := Label.new()
var _read_back := Label.new()
var _hint: Label
var _back := Button.new()
var _read := {}
var _start := PackedInt32Array()
var _slots := 0
var _held_from := -1


func _init() -> void:
	name = "BuildPage"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuStyle.apply(self)
	add_child(MenuBackdrop.new())
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
	_title.add_theme_font_override("font", HudStyle.font(true))
	_title.add_theme_font_size_override("font_size", MenuStyle.TITLE_SIZE)
	_title.add_theme_constant_override("outline_size", 6)
	col.add_child(_title)
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_note.add_theme_font_size_override("font_size", MenuStyle.NOTE_SIZE)
	_note.add_theme_color_override("font_color", MenuStyle.DIM)
	col.add_child(_note)
	col.add_child(pips)
	col.add_child(row)
	_read_back.name = "ReadBack"
	_read_back.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_read_back.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_read_back.custom_minimum_size = Vector2(READ_W, 0)
	_read_back.add_theme_font_size_override("font_size", READ_SIZE)
	_read_back.add_theme_color_override("font_color", MenuStyle.TEXT)
	col.add_child(_read_back)
	_hint = MenuStyle.hint("UI_BUILD_HINT")
	col.add_child(_hint)
	_back.name = "Back"
	_back.text = "UI_BACK"
	_back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_back.focus_mode = Control.FOCUS_NONE  # the page owns the keys and the pad; Back is the mouse's way out
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.add_theme_font_size_override("font_size", MenuStyle.BUTTON_SIZE)
	_back.pressed.connect(func() -> void: back_pressed.emit())
	col.add_child(_back)
	row.tile_clicked.connect(_on_click)
	row.tile_dropped.connect(_on_drop)
	row.tile_hovered.connect(_on_hover)


## Shows `wand` (WorldReader.wand(), with any moves still waiting for a tick applied) over its `slots`.
func open(wand: Dictionary, slots: int) -> void:
	_read = wand
	_slots = slots
	_start = order()
	row.held = -1
	row.focus = 0 if card_count() > 0 else -1
	_held_from = -1
	_refresh()


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


func read_back_text() -> String:
	return _read_back.text


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
	row.show_wand(_read, _slots)
	_note.text = tr("UI_BUILD_SLOTS") % [card_count(), _slots]
	pips.show_wand(_read)  # v0.9.0 AS2 (G2 AS = B; was A's counts in the note)
	var lines := WorldReader.wand_describe(_read)
	_read_back.text = WorldReader.wand_render(lines, func(k: StringName) -> String: return tr(k))
	_read_back.custom_minimum_size.x = maxf(READ_W, row.row_width())


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
	row.held = k
	row.focus = k
	_held_from = k
	row.refresh_marks()


func _drop() -> void:
	row.held = -1
	_held_from = -1
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
		_move(row.held, _held_from)
		row.focus = _held_from
		_drop()
		return
	back_pressed.emit()


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
	if from >= card_count():
		return
	var at := clampi(to, 0, card_count() - 1)
	_move(from, at)
	row.focus = at
	_drop()


func _on_hover(k: int) -> void:
	if row.held >= 0 or k >= card_count():
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
