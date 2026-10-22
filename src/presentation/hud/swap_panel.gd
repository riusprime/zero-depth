class_name SwapPanel
extends ModalPanel
## The Swap choice (v0.6.0 MX2; owner B7: "you have a swap button for the next you get and you can decide which one
## to swap"). While the sim waits on a swap (a new modifier offered with every wand slot full; WorldReader.swapping),
## it shows the incoming card, the wand (WandRow: its cards in slot order, the trigger cuts) and Skip. It sends the
## player's answer as input (`picked` → InputLatch.note_pick → InputFrame.pick: PICK_SWAP_BASE + n replaces slot n,
## PICK_SWAP_SKIP skips) and its reorders as wand moves (`moved` → InputLatch.queue_wand_move); it decides nothing
## (EI-07): the row and the read-back under it preview with the sim's own rules (WorldReader.wand_moved /
## wand_swapped).
## v0.6.5 WN2 (docs/design/WAND.md rule 4), rebuilt for up to 8 slots inside the 1920 x 1080 base (so 1280 x 720):
## - Replace: 1–8 or ←/→ choose a card, Enter swaps it (mouse: click it; pad: d-pad, A). Esc / B skips.
## - Insert: I (pad X; mouse: drag the new card onto a slot) puts the new card in the row; ←/→ choose where, Enter;
##   then choose the card that leaves, Enter (Esc / B steps back).
## - Reorder: R (pad Y) picks up the chosen card, ←/→ carry it, R / Enter put it down (mouse: drag a card onto a
##   slot). The moves reach the sim while the panel is open (the sim ticks while it waits).
## It sits over the pick panel and the shop (their input waits while it is open).
## v0.6.0 UP: a modal choice, so it wears the menus' look (v0.8.0 MU: Ember stone, MenuStyle): the game blurred and
## sunk into the warm dark behind (MenuBackdrop), warm type, stone tablets with their family's colour as the glowing
## groove at the foot, the focused tile ember-lit. The incoming card keeps the pick cards' look (StoneCard).

signal moved(value: int)

enum Mode { CHOOSE, CARRY, PLACE, LEAVE }

## Key repeats (PanelInput.Echo): only the arrows repeat.
const ECHO := PanelInput.Echo.ARROWS

## A held card's tile (the row's) and the Skip tile.
const TILE := WandRow.TILE
const SKIP_TILE := Vector2(140, 52)
## The Skip tile's index (past the held slots; the wand has up to WorldReader.MOD_SLOTS = 8).
const SKIP := WorldReader.MOD_SLOTS

var row := WandRow.new()
var _dim := MenuBackdrop.new()
var _title := Label.new()
var _hint := Label.new()
var _hint2 := Label.new()
var _read_back := Label.new()
var _card: PickSlot
var _col := VBoxContainer.new()
var _skip := PanelContainer.new()
var _skip_key: Label
var _skip_name: Label
## The reader last shown (read only), so a language switch words the open panel again (v0.6.0 UP).
var _reader: WorldReader
## The wand as the panel shows it: the sim's read with this panel's reorders applied (they reach the sim a tick later).
var _wand := {}
var _count := 0
var _mode := Mode.CHOOSE
## CARRY: where the card was picked up; PLACE / LEAVE: where the new card sits in the row (0.._count).
var _from := -1
var _place := -1
var _code := -1
var _drag_card := false


func _init() -> void:
	name = "SwapPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP  # the game under it takes no clicks
	add_child(_dim)
	_col.name = "Column"
	_col.alignment = BoxContainer.ALIGNMENT_CENTER
	var col := _centred_column(_col, 12)
	_title.add_theme_font_override("font", HudStyle.font(true))
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", MenuStyle.TEXT)
	for l: Label in [_hint, _hint2]:
		l.add_theme_font_size_override("font_size", MenuStyle.HINT_SIZE)
		l.add_theme_color_override("font_color", MenuStyle.HINT)
	_read_back.name = "ReadBack"
	_read_back.add_theme_font_size_override("font_size", 18)
	_read_back.add_theme_color_override("font_color", MenuStyle.DIM)
	_read_back.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_read_back.custom_minimum_size = Vector2(1100, 0)
	for l: Label in [_title, _hint, _hint2, _read_back]:  # the menus' soft outline, readable over the blurred game
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("outline_size", 4)
	style_labels([_title, _hint, _hint2, _read_back])
	col.add_child(_title)
	var card_box := CenterContainer.new()
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PickSlot.new(0, 0.8)
	_card.name = "SwapCard"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP  # v0.6.5 WN2: drag it onto a slot to insert it there
	_card.set_key_visible(false)  # v0.6.0 UP: the incoming card has no number key here
	_card.gui_input.connect(_on_card_input)
	card_box.add_child(_card)
	col.add_child(card_box)
	var row_box := CenterContainer.new()
	row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_box.add_child(row)
	col.add_child(row_box)
	col.add_child(_read_back)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override("separation", 18)
	_make_skip()
	foot.add_child(_skip)
	var hints := VBoxContainer.new()
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.add_child(_hint)
	hints.add_child(_hint2)
	foot.add_child(hints)
	col.add_child(foot)
	row.tile_clicked.connect(_on_click)
	row.tile_dropped.connect(_on_drop)
	row.tile_hovered.connect(_on_hover)
	visible = false


func _make_skip() -> void:
	_skip.name = "SwapSkip"
	_skip.custom_minimum_size = SKIP_TILE
	_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip.add_child(box)
	_skip_key = WandRow.make_label(13, false, MenuStyle.DIM)
	_skip_key.text = tr("UI_SWAP_SKIP_KEY")
	_skip_name = WandRow.make_label(15, true, MenuStyle.TEXT)
	_skip_name.text = tr("UI_SWAP_SKIP")
	box.add_child(_skip_key)
	box.add_child(_skip_name)
	_skip.gui_input.connect(_on_skip_input)
	_skip.mouse_entered.connect(_on_skip_hover)


## Opens, refreshes or closes from the sim's state.
func sync(reader: WorldReader) -> void:
	_reader = reader
	if _closed(reader.swapping()):
		return
	var b := reader.build()
	var code := int(b["swap_code"])
	if _open and code == _code:
		return
	_open = true
	_sent = false
	_code = code
	visible = true
	_card.show_card(PickPanel.card_face(self, reader, code))
	_wand = reader.wand()
	_count = (_wand["cards"] as Array).size()
	_mode = Mode.CHOOSE
	_from = -1
	_place = -1
	_set_focus(0)


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or _skip_name == null:
		return
	_skip_key.text = tr("UI_SWAP_SKIP_KEY")
	_skip_name.text = tr("UI_SWAP_SKIP")
	if _open:
		_refresh()


## The Skip tile's name (tests).
func skip_text() -> String:
	return _skip_name.text


func slot_count() -> int:
	return _count


func mode() -> int:
	return _mode


## The tile of held slot k (SKIP: the Skip tile), for tests.
func tile(k: int) -> PanelContainer:
	return _skip if k == SKIP else row.tile(k)


func read_back_text() -> String:
	return _read_back.text


## The panel's content rect on screen (tests: it fits the 1920 x 1080 base at 8 slots).
func content_rect() -> Rect2:
	return _col.get_global_rect()


## The wand the row shows now (the preview: a reorder, a placed new card, the card that leaves).
func _shown() -> Dictionary:
	match _mode:
		Mode.PLACE, Mode.LEAVE:
			return _placed(_place)
	return _wand


## The row with the new card put in at `p` (0.._count): _count + 1 cards (the preview before one leaves).
func _placed(p: int) -> Dictionary:
	var cards: Array[Dictionary] = []
	for c: Dictionary in _wand["cards"]:
		cards.append(c)
	cards.insert(clampi(p, 0, cards.size()), _wand["incoming"])
	var out := _wand.duplicate()
	out["cards"] = cards
	return out


## The (leave, at) answer of LEAVE with the card at row index `r` (of the _count + 1 shown) leaving.
func _answer_of(r: int) -> Vector2i:
	var leave := r if r < _place else r - 1
	var at := _place if r > _place else _place - 1
	return Vector2i(leave, at)


func _refresh() -> void:
	if _wand.is_empty():  # not opened yet: only the Skip tile's look
		_style_skip(_focus == SKIP)
		return
	var shown := _shown()
	var n := (shown["cards"] as Array).size()
	row.fresh = _place if _mode in [Mode.PLACE, Mode.LEAVE] else -1
	row.held = _focus if _mode in [Mode.CARRY, Mode.PLACE] else -1
	row.focus = _focus if _focus != SKIP else -1
	row.leaving = _focus if _mode == Mode.LEAVE and _focus != _place else -1
	row.show_wand(shown, n)
	# The read-back of what the answer gives now (a forecast with the sim's rules, EI-07).
	var outcome := _wand
	match _mode:
		Mode.CHOOSE:
			if _focus != SKIP:
				outcome = WorldReader.wand_swapped(_wand, _focus, _focus)
		Mode.LEAVE:
			if _focus != _place:
				var a := _answer_of(_focus)
				outcome = WorldReader.wand_swapped(_wand, a.x, a.y)
	var lines := WorldReader.wand_describe(outcome)
	_read_back.text = WorldReader.wand_render(lines, func(k: StringName) -> String: return tr(k))
	var title_key := "UI_SWAP_TITLE"
	match _mode:
		Mode.PLACE:
			title_key = "UI_SWAP_PLACE"
		Mode.LEAVE:
			title_key = "UI_SWAP_LEAVE"
		Mode.CARRY:
			title_key = "UI_SWAP_CARRY"
	_title.text = tr(title_key) % _count if title_key == "UI_SWAP_TITLE" else tr(title_key)
	_hint.text = tr("UI_SWAP_HINT")
	_hint2.text = tr("UI_SWAP_HINT_MORE")
	_style_skip(_focus == SKIP)


func _input(event: InputEvent) -> void:
	if not _open or not input_enabled or _sent:
		return
	var d := PanelInput.decode(event, WorldReader.MOD_SLOTS, ECHO)
	match d.kind:
		PanelInput.Kind.SWALLOW:
			pass
		PanelInput.Kind.DIGIT:
			if _mode == Mode.CHOOSE:
				_set_focus(d.digit)
		PanelInput.Kind.CONFIRM:
			_confirm()
		PanelInput.Kind.CANCEL:
			_back()
		PanelInput.Kind.STEP:
			_step(d.line())
		PanelInput.Kind.KEY:
			match d.code:
				KEY_R:
					_carry_toggle()
				KEY_I:
					_start_place()
				_:
					return
		PanelInput.Kind.BUTTON:
			match d.code:
				JOY_BUTTON_Y:
					_carry_toggle()
				JOY_BUTTON_X:
					_start_place()
				_:
					return
		_:
			return
	# The pick panel and the shop below don't see what the swap answered.
	get_viewport().set_input_as_handled()


func _step(step: int) -> void:
	match _mode:
		Mode.CHOOSE:
			_set_focus(_step_from(_focus, step))
		Mode.CARRY:
			var to := clampi(_focus + step, 0, _count - 1)
			_reorder(_focus, to)
			_focus = to
			_refresh()
		Mode.PLACE:
			_place = clampi(_place + step, 0, _count)
			_focus = _place
			_refresh()
		Mode.LEAVE:
			var f := clampi(_focus + step, 0, _count)
			if f == _place:
				f = clampi(f + step, 0, _count)
			if f != _place:
				_focus = f
				_refresh()


## The next focus from `k` by `step` over the held slots then Skip.
func _step_from(k: int, step: int) -> int:
	var order: Array[int] = []
	for n in _count:
		order.append(n)
	order.append(SKIP)
	var at := maxi(0, order.find(k))
	return order[clampi(at + step, 0, order.size() - 1)]


func _set_focus(k: int) -> void:
	if k != SKIP and (k < 0 or k >= _count):
		return
	_focus = k
	_refresh()


func _style_skip(on: bool) -> void:
	_skip.add_theme_stylebox_override(
		"panel", MenuStyle.tile_slab(MenuStyle.EMBER, on, false, 41, Vector2(8, 6))
	)


## Enter / A: answer (CHOOSE: replace the focused card; LEAVE: the focused card leaves), put a carried card down, or
## fix where the new card goes.
func _confirm() -> void:
	match _mode:
		Mode.CHOOSE:
			_answer(_focus)
		Mode.CARRY:
			_mode = Mode.CHOOSE
			_refresh()
		Mode.PLACE:
			_mode = Mode.LEAVE
			_focus = 0 if _place != 0 else 1
			_refresh()
		Mode.LEAVE:
			_leave(_focus)


## Esc / B: skip, or step back (a carried card goes back where it was; the new card comes out of the row).
func _back() -> void:
	match _mode:
		Mode.CHOOSE:
			_answer(SKIP)
		Mode.CARRY:
			_reorder(_focus, _from)
			_focus = _from
			_mode = Mode.CHOOSE
			_refresh()
		Mode.PLACE:
			_mode = Mode.CHOOSE
			_focus = clampi(_place, 0, _count - 1)
			_place = -1
			_refresh()
		Mode.LEAVE:
			_mode = Mode.PLACE
			_focus = _place
			_refresh()


func _carry_toggle() -> void:
	if _mode == Mode.CHOOSE and _focus != SKIP:
		_mode = Mode.CARRY
		_from = _focus
		_refresh()
	elif _mode == Mode.CARRY:
		_mode = Mode.CHOOSE
		_refresh()


func _start_place(at: int = -1) -> void:
	if _mode != Mode.CHOOSE and _mode != Mode.PLACE:
		return
	_mode = Mode.PLACE
	_place = clampi(at if at >= 0 else (_focus if _focus != SKIP else _count), 0, _count)
	_focus = _place
	_refresh()


## A reorder of the held cards: the preview follows at once (the sim's rule), the move goes to the sim as input.
func _reorder(from: int, to: int) -> void:
	if not WorldReader.wand_can_move(_count, from, to):
		return
	_wand = WorldReader.wand_moved(_wand, from, to)
	moved.emit(InputFrame.wand_move(from, to))


func _leave(r: int) -> void:
	if r == _place or r < 0 or r > _count:
		return
	var a := _answer_of(r)
	_send_picks(WorldReader.wand_swap_picks(a.x, a.y))


func _on_click(k: int) -> void:
	if not _open or not input_enabled or _sent:
		return
	match _mode:
		Mode.CHOOSE:
			_set_focus(k)
			_answer(k)
		Mode.CARRY:
			var to := clampi(k, 0, _count - 1)
			_reorder(_focus, to)
			_focus = to
			_mode = Mode.CHOOSE
			_refresh()
		Mode.PLACE:
			_place = clampi(k, 0, _count)
			_confirm()
		Mode.LEAVE:
			_leave(k)


func _on_drop(from: int, to: int) -> void:
	if not _open or not input_enabled or _sent or _mode != Mode.CHOOSE:
		return
	if from < _count:
		var at := clampi(to, 0, _count - 1)
		_reorder(from, at)
		_focus = at
		_refresh()


func _on_hover(k: int) -> void:
	if _mode == Mode.CHOOSE and k < _count:
		_set_focus(k)
	elif _mode == Mode.LEAVE and k != _place and k <= _count:
		_focus = k
		_refresh()


## The incoming card: a click puts it in the row (Insert); a drag onto a slot puts it there and asks which card leaves.
func _on_card_input(event: InputEvent) -> void:
	if not _open or not input_enabled or _sent:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_card.accept_event()
	if event.pressed:
		_drag_card = true
		return
	if not _drag_card:
		return
	_drag_card = false
	var at := row.slot_at(_card.get_global_rect().position + event.position)
	if at >= 0 and _mode == Mode.CHOOSE:
		_start_place(at)
		_confirm()
	elif at < 0:
		_start_place()


func _on_skip_hover() -> void:
	if _mode == Mode.CHOOSE:
		_set_focus(SKIP)


func _on_skip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _mode == Mode.CHOOSE:
			_answer(SKIP)


func _answer(k: int) -> void:
	if not _open or not input_enabled or _sent:
		return
	if k != SKIP and (k < 0 or k >= _count):
		return
	if k == SKIP:
		_send_picks(PackedInt32Array([WorldReader.PICK_SWAP_SKIP]))
	else:
		_send_picks(WorldReader.wand_swap_picks(k, k))


## Sends the answer (then the new card's move, for an insert) as input, in order.
func _send_picks(picks: PackedInt32Array) -> void:
	_sent = true
	picked.emit(picks[0])
	for k in range(1, picks.size()):
		moved.emit(picks[k])
