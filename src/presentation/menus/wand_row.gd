# gdlint: disable=max-public-methods
class_name WandRow
extends Control
## The wand as a row of slots (v0.6.5 WN2; docs/design/WAND.md rule 4), shared by the pause menu's Build page and the
## Swap panel. Each held card is a tile with its icon, its name and its level; an empty slot is a dim tile. A trigger
## card cuts the row: a line stands after it, and under the row a bracket per part of the wand says what it is
## ("the shot you fire", then "cast on hit →" under the cards the trigger casts). a Form,
## Pattern, Secondary or Element card's tile adds its slot tag to its level line ("Lv 2 · Pattern"). It draws a wand
## read (WorldReader.wand(), or a preview from WorldReader.wand_moved) and the page's marks (focus, the card held, a
## card leaving, a new card); it decides nothing (EI-07). Mouse: a press on a tile and a release on another is a drag
## (`tile_dropped`); a press and release on the same tile is a click (`tile_clicked`); hovering a tile reports it
## (`tile_hovered`). The pages turn those into moves.
## A card being carried (`carry_from`, on the Build page) is shown
## lifted and tilted over the slot it would land in, a dashed ghost stays where it came from, and a bar and an arrow
## show exactly where it lands; the cards beside the bar slide apart. Tiles glide to where they belong (ANIM_S, instant
## under reduced motion). Nothing here decides anything: the moves are the page's. The mouse is read by one layer over
## the row against each slot's resting place, so a click lands on the slot it was aimed at while the tiles are moving.

signal tile_clicked(k: int)
signal tile_dropped(from: int, to: int)
signal tile_hovered(k: int)
## A press on a tile became a drag; the drag was released away from every slot.
signal tile_drag_started(k: int)
signal tile_drag_cancelled

## A tile's size, the gap between tiles, the extra room a cut takes (its divider), and the bracket band under the row
## (px at the 1920 x 1080 base; 8 slots and 3 cuts: about 1,300 px).
const TILE := Vector2(140, 150)
const GAP := 10.0
const CUT := 34.0
const LIFT := 14.0
const BRACKET_H := 52.0
const NAME_SIZE := 15
## The icon's socket (px).
const SOCKET := 48.0
const SMALL_SIZE := 13
const BRACKET_SIZE := 14
## A press that moves this far (px) before its release is a drag.
const DRAG_PX := 8.0
## How long a tile takes to reach its place (s), how far a carried card rises and tilts and grows, and how
## far the cards beside the landing bar move apart (px at the 1920 x 1080 base).
const ANIM_S := 0.15
const CARRY_RISE := 44.0
const CARRY_TILT := -0.055
const CARRY_GROW := 1.06
const OPEN := 14.0
## How far the mouse layer reaches above the row while a card is carried (the lifted card is clickable).
const CARRY_REACH := 64.0
## The bracket label of a part cast by each trigger (WorldReader.WAND_ON_*), and of the shot you fire.
const CUT_KEYS := {
	WorldReader.WAND_ON_HIT: "UI_WAND_CUT_ON_HIT",
	WorldReader.WAND_ON_KILL: "UI_WAND_CUT_ON_KILL",
	WorldReader.WAND_ON_END: "UI_WAND_CUT_ON_END",
	WorldReader.WAND_ON_FINISHER: "UI_WAND_CUT_ON_FINISHER",
	WorldReader.WAND_ON_CRIT: "UI_WAND_CUT_ON_CRIT",
}
## The order mark of each order kind (WorldReader.WAND_ORDER_*; a plain card has none).
const ORDER_KEYS := {
	WorldReader.WAND_ORDER_SHAPE: "UI_WAND_ORDER_SHAPE",
	WorldReader.WAND_ORDER_COUNT: "UI_WAND_ORDER_COUNT",
	WorldReader.WAND_ORDER_MOTION: "UI_WAND_ORDER_MOTION",
}
## The compile's nesting depth (a third trigger casts nothing; WAND.md rule 3).
const MAX_DEPTH := 2

## The marks the page sets (slot indices, -1 for none): the focused tile, the card held (lifted), a card that leaves
## (the Swap's replace), and the new card (the Swap's incoming card placed in the row).
var focus := -1
var held := -1
var leaving := -1
var fresh := -1
## The slot a carried card came from (-1: none). The row then shows the wand as it was picked up (the
## page's preview is the forecast), `held` is the slot the card would land in, and that is where it is drawn.
var carry_from := -1
## The slot category a limited Swap chooses in (WorldReader.SLOT_*; 0: any): the
## other cards' tiles are dimmed and can't be chosen (selectable).
var only_slot := 0
## Astral tiles (AstralChrome.FrameBox: a 1 px frame,
## an inner frame, Astral's focus) and type, the cuts and brackets as thin accent lines.
## Astral is the default (the Build page's too).
## v0.11.1 Step 13 (owner: Astral the only style): the Ember stone tiles are gone; every row is Astral.

var _wand := {}
var _slots := 0
var _tiles: Array[PanelContainer] = []
## The tiles' icons: the card's painted icon in an Astral medallion.
var _medals: Array[AstralMedallion] = []
var _keys: Array[Label] = []
var _names: Array[Label] = []
var _levels: Array[Label] = []
var _brackets: Array[Label] = []
## Why each card can't act where it sits (Wand.flags: a translation key, or &"").
var _dead: Array[StringName] = []
## Each tile's x (left edge) and the dividers' x, from the last layout.
var _xs: Array[float] = []
var _cut_xs: Array[float] = []
## [from_x, to_x, depth] per bracket, for _draw.
var _spans: Array = []
var _press := -1
var _press_at := Vector2.ZERO
var _dragging := false
## Each tile's pose (position, tilt, size) and where it is heading.
var _poses: Array[Pose] = []
var _hover := -1
## The layer that reads the mouse, the marks over the tiles (ghost frame, bar, arrow), and the ghost's icon.
var _hit := Control.new()
var _marks := Control.new()
var _ghost := AstralMedallion.new()


## A tile's place on screen, and the glide to its goal (the view's own clock; it decides nothing).
class Pose:
	extends RefCounted
	var at := Vector2.ZERO
	var turn := 0.0
	var grow := 1.0
	var from_at := Vector2.ZERO
	var from_turn := 0.0
	var from_grow := 1.0
	var to_at := Vector2.ZERO
	var to_turn := 0.0
	var to_grow := 1.0
	var left := 0.0

	func aim(goal_at: Vector2, goal_turn: float, goal_grow: float, instant: bool) -> void:
		if instant:
			at = goal_at
			turn = goal_turn
			grow = goal_grow
			left = 0.0
		elif at != goal_at or turn != goal_turn or grow != goal_grow:
			if left <= 0.0 or to_at != goal_at or to_turn != goal_turn or to_grow != goal_grow:
				from_at = at
				from_turn = turn
				from_grow = grow
				left = ANIM_S
		to_at = goal_at
		to_turn = goal_turn
		to_grow = goal_grow

	func advance(delta: float) -> void:
		left = maxf(left - delta, 0.0)
		var u := 1.0 - left / ANIM_S
		var eased := 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u)
		at = from_at.lerp(to_at, eased)
		turn = lerpf(from_turn, to_turn, eased)
		grow = lerpf(from_grow, to_grow, eased)


func _init() -> void:
	name = "WandRow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in WorldReader.MOD_SLOTS + 1:  # one more than the wand holds: the Swap's new card placed in a full row
		_make_tile(k)
	for k in WorldReader.MOD_SLOTS + 2:
		var b := make_label(BRACKET_SIZE, false, AstralCardArt.DIM)
		b.name = "Bracket%d" % k
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.max_lines_visible = 2
		add_child(b)
		_brackets.append(b)
	for k in _tiles.size():  # every tile wears its look from the start
		_style(k)
	_ghost.name = "Ghost"
	_ghost.custom_minimum_size = Vector2(SOCKET, SOCKET)
	_ghost.size = Vector2(SOCKET, SOCKET)
	_ghost.modulate = Color(1, 1, 1, 0.3)
	_ghost.visible = false
	add_child(_ghost)
	_marks.name = "CarryMarks"
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.z_index = 2
	_marks.draw.connect(_draw_carry)
	add_child(_marks)
	_hit.name = "MouseLayer"
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_hit.gui_input.connect(_on_mouse)
	_hit.mouse_exited.connect(func() -> void: _hover = -1)
	add_child(_hit)
	set_process(false)


func _make_tile(k: int) -> void:
	var t := PanelContainer.new()
	t.name = "WandSlot%d" % (k + 1)
	t.custom_minimum_size = TILE
	t.size = TILE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE  # The mouse layer reads the slots
	t.pivot_offset = TILE * 0.5
	t.clip_contents = true
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(box)
	var key := make_label(SMALL_SIZE, false, AstralCardArt.DIM)
	key.text = str(k + 1)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(key)
	var medal := AstralMedallion.new()  # v0.10.5 W3-O19
	medal.custom_minimum_size = Vector2(SOCKET, SOCKET)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	medal.visible = false
	box.add_child(medal)
	_medals.append(medal)
	var nm := make_label(NAME_SIZE, true, AstralCardArt.TEXT)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	nm.custom_minimum_size = Vector2(TILE.x - 16, 0)
	box.add_child(nm)
	var lv := make_label(SMALL_SIZE, false, AstralCardArt.DIM)
	lv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # A flagged card's reason takes two lines
	lv.max_lines_visible = 2
	lv.custom_minimum_size = Vector2(TILE.x - 16, 0)
	box.add_child(lv)
	add_child(t)
	_tiles.append(t)
	_poses.append(Pose.new())
	_keys.append(key)
	_names.append(nm)
	_levels.append(lv)


static func make_label(px: int, bold: bool, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", HudStyle.font(bold))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Shows `wand` (a wand read: its cards in slot order with their triggers) over `slots` slots (at least the cards).
func show_wand(wand: Dictionary, slots: int) -> void:
	var before := _card_poses()
	_wand = wand
	_slots = clampi(maxi(slots, card_count()), 0, _tiles.size())
	_refresh(before)


## Every tile on its place now, no glide (a page opening).
func settle() -> void:
	for k in _slots:
		_aim(k, true)
	set_process(false)


func card_count() -> int:
	return (_wand.get("cards", []) as Array).size()


## Card k may be chosen (a held card, of only_slot's category when it is set).
func selectable(k: int) -> bool:
	if k < 0 or k >= card_count():
		return false
	return only_slot == 0 or int((_wand["cards"][k] as Dictionary).get("slot", 0)) == only_slot


func slot_count() -> int:
	return _slots


func wand() -> Dictionary:
	return _wand


## The tile of slot k (tests and the pages' mouse checks).
func tile(k: int) -> PanelContainer:
	return _tiles[k]


func card_name(k: int) -> String:
	return _names[k].text


## The font size tile `k`'s name is drawn at (NAME_SIZE, or smaller for a word too long for the tile).
func name_size(k: int) -> int:
	return _names[k].get_theme_font_size("font_size")


func level_text(k: int) -> String:
	return _levels[k].text


## Why the card in slot `k` can't act where it sits (a translation key; &"": it acts). Its tile
## is dimmed and shows the reason in place of its level.
## Tile `k`'s slot tag (WorldReader.SLOT_*; NONE for a card without one, or an empty slot).
func slot_of(k: int) -> int:
	var cards: Array = _wand.get("cards", [])
	return (
		int((cards[k] as Dictionary).get("slot", 0)) if k < cards.size() else WorldReader.SLOT_NONE
	)


func dead_reason(k: int) -> StringName:
	return _dead[k] if k < _dead.size() else &""


## The bracket labels shown, left to right (tests).
func bracket_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for b in _brackets:
		if b.visible:
			out.append(b.text)
	return out


## The dividers' x (tests: one after each trigger card).
func cut_positions() -> Array[float]:
	return _cut_xs.duplicate()


## The row's width now (tests: it fits the screen at 8 slots).
func row_width() -> float:
	return custom_minimum_size.x


## Restyles the marks only (focus, held, leaving, new) after the page changes them.
## A tile's top line, its slot number and,
## on a card that changes what is left of it (Wand.order_of: a shape, a count or a motion), that mark.
func key_text(k: int, order: int) -> String:
	var key: String = ORDER_KEYS.get(order, "")
	return str(k + 1) if key == "" else "%d · %s" % [k + 1, tr(key)]


func refresh_marks() -> void:
	var instant := ViewPrefs.reduced_motion or not is_visible_in_tree()
	for k in _tiles.size():
		_tiles[k].z_index = 1 if k == lifted_tile() else 0
		if k < _slots:
			_style(k)
			_aim(k, instant)
	_ghost.visible = carry_from >= 0 and carry_from < _slots
	if _ghost.visible:
		_ghost.show_card(_card_id(carry_from))
		_ghost.position = _rest(carry_from) + Vector2((TILE.x - SOCKET) * 0.5, 30.0)
	_fit_mouse_layer()
	_marks.queue_redraw()
	queue_redraw()  # An Astral row draws the focus contour itself


## The tile drawn lifted (the carried card's tile; on the Swap, the held card's).
func lifted_tile() -> int:
	return carry_from if carry_from >= 0 else held


## The slot the ghost marks and the slot the carried card lands in (-1: nothing is carried).
func ghost_slot() -> int:
	return carry_from


func marker_slot() -> int:
	return held if carry_from >= 0 else -1


## The landing bar on screen (empty when nothing moves: not carrying, or over its own place).
func marker_rect() -> Rect2:
	if carry_from < 0 or held == carry_from:
		return Rect2()
	return Rect2(global_position + Vector2(_bar_x() - 2.0, LIFT - 8.0), Vector2(4.0, TILE.y + 16.0))


## The id of the card the ghost shows (&"": no ghost; tests).
func ghost_card() -> StringName:
	return _card_id(carry_from) if _ghost.visible else &""


## Whether any tile is still gliding (tests).
func animating() -> bool:
	for p in _poses:
		if p.left > 0.0:
			return true
	return false


## Where slot `k` rests on screen, whatever its tile is doing (the mouse's slot; tests click its centre).
func slot_rect(k: int) -> Rect2:
	return Rect2(global_position + Vector2(_xs[k], LIFT), TILE)


func _card_id(k: int) -> StringName:
	var cards: Array = _wand.get("cards", [])
	return (cards[k] as Dictionary)["id"] if k >= 0 and k < cards.size() else &""


## Each shown card's code and pose now (copies): where its tile glides from when the row is drawn again.
func _card_poses() -> Array:
	var out := []
	var cards: Array = _wand.get("cards", [])
	for k in mini(cards.size(), _poses.size()):
		var p := _poses[k]
		out.append([int((cards[k] as Dictionary).get("code", -1)), p.at, p.turn, p.grow])
	return out


## After the row is drawn again: each card's tile starts where that card was (two cards of one code look the same); a
## card that wasn't there, or an empty slot, starts on its place.
func _start_from(before: Array) -> void:
	var cards: Array = _wand.get("cards", [])
	var used := {}
	for k in mini(_slots, cards.size()):
		var code := int((cards[k] as Dictionary).get("code", -1))
		if k < before.size() and int(before[k][0]) == code:
			used[k] = true  # the same card on the same tile: its glide goes on
	for k in _slots:
		if used.has(k):
			continue
		var from := -1
		if k < cards.size():
			var code := int((cards[k] as Dictionary).get("code", -1))
			for j in before.size():
				if not used.has(j) and int(before[j][0]) == code:
					from = j
					break
		if from >= 0:
			used[from] = true
			var p := _poses[k]
			p.at = before[from][1]
			p.turn = before[from][2]
			p.grow = before[from][3]
			p.left = 0.0
		else:
			_aim(k, true)


## The place tile `k` should be: its slot, with the cards beside the landing bar apart.
func _rest(k: int) -> Vector2:
	return Vector2(_xs[k] + _opened(k), LIFT)


func _opened(k: int) -> float:
	if carry_from < 0 or held == carry_from:
		return 0.0
	var right_of := k >= held if held < carry_from else k > held
	return OPEN if right_of else -OPEN


func _aim(k: int, instant: bool) -> void:
	var at := Vector2(_xs[k], 0.0 if k == held else LIFT)
	var turn := 0.0
	var grow := 1.0
	if carry_from >= 0:
		at = _rest(k)
		if k == carry_from:  # the card in the air, over the slot it would land in
			at = _rest(clampi(held, 0, _slots - 1)) - Vector2(0.0, CARRY_RISE)
			turn = CARRY_TILT
			grow = CARRY_GROW
	_poses[k].aim(at, turn, grow, instant)
	_apply(k)
	if not instant and _poses[k].left > 0.0:
		set_process(true)


func _apply(k: int) -> void:
	var t := _tiles[k]
	var p := _poses[k]
	t.position = p.at
	t.rotation = p.turn
	t.scale = Vector2(p.grow, p.grow)


func _process(delta: float) -> void:
	var busy := false
	for k in _slots:
		if _poses[k].left > 0.0:
			_poses[k].advance(delta)
			_apply(k)
			busy = busy or _poses[k].left > 0.0
	if not busy:
		set_process(false)
	queue_redraw()


## The mouse layer covers the row, and the air over it while a card is carried.
func _fit_mouse_layer() -> void:
	var reach := CARRY_REACH if carry_from >= 0 else 0.0
	_hit.position = Vector2(-OPEN, LIFT - reach)
	_hit.size = Vector2(custom_minimum_size.x + OPEN * 2.0, TILE.y + reach)


## The landing bar's x (row px): in the gap on the side of the target the card comes in from.
func _bar_x() -> float:
	var t := clampi(held, 0, _slots - 1)
	if held < carry_from:
		var left_of := _rest(t).x
		return left_of - 10.0 if t == 0 else (_rest(t - 1).x + TILE.x + left_of) * 0.5
	var right_end := _rest(t).x + TILE.x
	return right_end + 10.0 if t == _slots - 1 else (right_end + _rest(t + 1).x) * 0.5


## The carry's marks, over the tiles: the ghost's dashed frame, then the landing bar and the arrow to it.
func _draw_carry() -> void:
	if carry_from < 0 or carry_from >= _slots:
		return
	var accent := AstralCardArt.ACCENT
	var r := Rect2(_rest(carry_from), TILE).grow(-1.0)
	var corners := [
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)
	]
	for i in corners.size():
		_marks.draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], accent, 1.5, 7.0)
	if held == carry_from:
		return
	var x := _bar_x()
	var top := LIFT - 8.0
	var bottom := LIFT + TILE.y + 8.0
	_marks.draw_line(Vector2(x, top), Vector2(x, bottom), accent, 3.0)
	for y: float in [top, bottom]:
		var s := 1.0 if y == top else -1.0
		_marks.draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(x, y + 7.0 * s),
					Vector2(x - 7.0, y - 3.0 * s),
					Vector2(x + 7.0, y - 3.0 * s)
				]
			),
			accent
		)
	var a := _rest(carry_from) + Vector2(TILE.x * 0.5, 0.0)
	var b := Vector2(x, top - 8.0)
	var c := (a + b) * 0.5 - Vector2(0.0, 74.0)
	var pts := PackedVector2Array()
	for i in 25:
		var u := i / 24.0
		pts.append(a.lerp(c, u).lerp(c.lerp(b, u), u))
	_marks.draw_polyline(pts, accent, 2.0, true)
	var dir := (b - pts[22]).normalized()
	var side := Vector2(-dir.y, dir.x)
	_marks.draw_colored_polygon(
		PackedVector2Array([b + dir * 6.0, b - dir * 9.0 + side * 7.0, b - dir * 9.0 - side * 7.0]),
		accent
	)


func _refresh(before: Array = []) -> void:
	var cards: Array = _wand.get("cards", [])
	_dead = WorldReader.wand_flags(_wand)  # v0.8.0 MR
	var x := 0.0
	_xs.clear()
	_cut_xs.clear()
	_spans.clear()
	var seg_from := 0.0
	var depth := 0
	var seg_keys: Array[String] = ["UI_WAND_CUT_FIRE"]
	for k in _tiles.size():
		var t := _tiles[k]
		t.visible = k < _slots
		if k >= _slots:
			continue
		_xs.append(x)
		if k < cards.size():
			var c: Dictionary = cards[k]
			var id: StringName = c["id"]
			_names[k].text = tr(c["name_key"])
			_keys[k].text = key_text(k, int(c.get("order", 0)))
			var ability := int(c["type"]) == WorldReader.CARD_ABILITY
			var levels := ability or bool(c.get("wand", false))  # A wand card shows its level too
			var cap := int(c.get("max_level", 5))
			if levels and cap <= 1 and not ability:  # A card that doesn't level shows none
				_levels[k].text = ""
			elif levels and cap < 5 and not ability:  # "Lv 2/3"
				_levels[k].text = tr("UI_WAND_LEVEL_OF") % [int(c["level"]), cap]
			else:
				_levels[k].text = tr("UI_WAND_LEVEL") % int(c["level"]) if levels else ""
			var slot := int(c.get("slot", WorldReader.SLOT_NONE))  # The slot tag
			if slot != WorldReader.SLOT_NONE:
				var tag := tr(WorldReader.SLOT_TAG_KEYS[slot])
				_levels[k].text = (
					tag if _levels[k].text == "" else "%s · %s" % [_levels[k].text, tag]
				)
			if k == fresh:
				_levels[k].text = tr("UI_WAND_NEW")
			elif dead_reason(k) != &"":  # It does nothing here; the tile says why
				_levels[k].text = tr(dead_reason(k))
			_medals[k].show_card(id)  # The painted icon on an Astral row
			_medals[k].visible = true
			t.set_meta(&"empty", false)
		else:
			_names[k].text = tr("UI_WAND_EMPTY")
			_keys[k].text = str(k + 1)
			_levels[k].text = ""
			_medals[k].visible = false
			t.set_meta(&"empty", true)
		TextFit.fit_label_words(_names[k], TILE.x - 16.0, NAME_SIZE)  # A long word shrinks
		x += TILE.x
		var trig := int(cards[k]["trigger"]) if k < cards.size() else -1
		if trig >= 0 and k < _slots - 1:
			_spans.append([seg_from, x, depth])
			depth += 1
			var key: String = CUT_KEYS.get(trig, "UI_WAND_CUT_ON_HIT")
			seg_keys.append(key if depth <= MAX_DEPTH else "UI_WAND_CUT_UNUSED")
			_cut_xs.append(x + CUT * 0.5)
			x += CUT
			seg_from = x
		elif k < _slots - 1:
			x += GAP
	_spans.append([seg_from, x, depth])
	for b in _brackets.size():
		var l := _brackets[b]
		l.visible = b < _spans.size() and _slots > 0
		if not l.visible:
			continue
		var span: Array = _spans[b]
		var w := maxf(float(span[1]) - float(span[0]), TILE.x)
		l.text = tr(seg_keys[b])
		l.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER if b == 0 else HORIZONTAL_ALIGNMENT_LEFT
		)
		l.position = Vector2(float(span[0]), LIFT + TILE.y + 14.0)
		l.size = Vector2(w, BRACKET_H - 14.0)
		l.add_theme_color_override(
			"font_color", AstralCardArt.DIM if b == 0 else Color(AstralCardArt.ACCENT, 0.95)
		)
	custom_minimum_size = Vector2(maxf(x, 0.0), LIFT + TILE.y + BRACKET_H)
	size = custom_minimum_size
	_start_from(before)
	refresh_marks()
	queue_redraw()


func _style(k: int) -> void:
	var t := _tiles[k]
	var empty: bool = t.get_meta(&"empty", false)
	var lifted := k == lifted_tile()
	var lit := lifted or (k == focus and carry_from < 0)
	# An Astral tile; a held card's frame in the accent, the new card's in moonlight
	var fb := AstralChrome.FrameBox.new(1.0 if lit else 0.0, 0.55 if empty else 1.0)
	if lifted:
		fb.rim = AstralCardArt.ACCENT
		fb.backing = true
	if k == fresh:
		fb.rim = AstralCardArt.RARITY[3]
	t.add_theme_stylebox_override("panel", fb)
	_medals[k].focused = lit
	t.modulate = Color(1, 1, 1, 0.42) if k == leaving else Color.WHITE
	if k != leaving and dead_reason(k) != &"":  # A card that can't act here is dimmed
		t.modulate = Color(0.62, 0.6, 0.58, 0.78)
	if only_slot != 0 and k < card_count() and k != fresh and not selectable(k):  # Not a choice
		t.modulate = Color(0.5, 0.47, 0.45, 0.5)


## A tile's box (tests: the look, the focus).
func astral_box(k: int) -> AstralChrome.FrameBox:
	return _tiles[k].get_theme_stylebox("panel") as AstralChrome.FrameBox


func _draw() -> void:
	_draw_astral()


## The slot under `global` (a point on screen), or -1. by where each slot rests (a tile on its way
## somewhere does not move its slot), up to the middle of the gaps, and through the air over the row while carrying.
func slot_at(global: Vector2) -> int:
	var p := global - global_position
	var reach := CARRY_REACH if carry_from >= 0 else 0.0
	if p.y < LIFT - reach or p.y >= LIFT + TILE.y:
		return -1
	for k in _slots:
		var left := (_xs[k - 1] + TILE.x + _xs[k]) * 0.5 if k > 0 else _xs[k] - OPEN
		var right := (
			(_xs[k] + TILE.x + _xs[k + 1]) * 0.5 if k < _slots - 1 else _xs[k] + TILE.x + OPEN
		)
		if p.x >= left and p.x < right:
			return k
	return -1


## The mouse, against the slots' resting places: a press and release is a click, a press that travels is
## a drag (`tile_drag_started` once, `tile_dropped` on a slot, `tile_drag_cancelled` away from them).
func _on_mouse(event: InputEvent) -> void:
	if not (event is InputEventMouse):
		return
	var at: Vector2 = _hit.global_position + event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = slot_at(at)
			_press_at = at
			_dragging = false
		elif _press >= 0:
			var from := _press
			var dragged := _dragging
			end_press()
			var to := slot_at(at)
			if dragged and to >= 0 and to != from:
				tile_dropped.emit(from, to)
			elif to == from or not dragged:
				tile_clicked.emit(from)
			else:
				tile_drag_cancelled.emit()
		_hit.accept_event()
	elif event is InputEventMouseMotion:
		if _press >= 0 and not _dragging and at.distance_to(_press_at) > DRAG_PX:
			_dragging = true
			tile_drag_started.emit(_press)
		var over := slot_at(at)
		if over >= 0 and over != _hover:
			_hover = over
			tile_hovered.emit(over)


## Forgets a press under way (the page put the card back while the button was down).
func end_press() -> void:
	_press = -1
	_dragging = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _wand.is_empty():
		_refresh()


## The Astral row's marks: the focused tile's outer contour (6 px outside, 25 %), each cut a 1 px
## accent line with an open chevron, the brackets as 1 px lines (dim under the shot you fire, accent under a cast).
func _draw_astral() -> void:
	var top := LIFT
	var bottom := LIFT + TILE.y
	var accent := AstralCardArt.ACCENT
	if carry_from < 0 and focus >= 0 and focus < _tiles.size() and _tiles[focus].visible:
		var t := _tiles[focus]
		var r := Rect2(t.position.floor(), t.size.floor()).grow(6)
		draw_rect(r.grow(-0.5), Color(AstralCardArt.LINE_HI, 0.25), false, 1.0)
	for cx in _cut_xs:
		var x := roundf(cx)
		AstralChrome.vline(self, x, top - 4.0, bottom + 4.0, Color(accent, 0.85))
		var mid := roundf((top + bottom) * 0.5) + 0.5
		var chev := PackedVector2Array(
			[Vector2(x - 5.0, mid - 9.0), Vector2(x + 7.5, mid), Vector2(x - 5.0, mid + 9.0)]
		)
		draw_colored_polygon(
			PackedVector2Array([chev[0], chev[1], chev[2], Vector2(x + 0.5, mid)]), AstralChrome.INK
		)
		draw_polyline(chev, accent, 1.4, true)
	for span: Array in _spans:
		var a := roundf(float(span[0]) + 4.0)
		var b := roundf(float(span[1]) - 4.0)
		if b <= a:
			continue
		var y := roundf(bottom + 8.0)
		var c := Color(AstralCardArt.DIM, 0.8) if int(span[2]) == 0 else Color(accent, 0.75)
		AstralChrome.vline(self, a, y - 5.0, y + 1.0, c)
		AstralChrome.hline(self, a, b + 1.0, y, c)
		AstralChrome.vline(self, b, y - 5.0, y + 1.0, c)
