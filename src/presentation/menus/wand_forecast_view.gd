class_name WandForecastView
extends Control
## v0.10.5 O13, v0.11.0 F11 (owner, G2 F10 "option A but simpler, use the icons from the cards"): the wand
## forecast under the wand's row on the Build page and the Swap panel. One row of the cards' own icons
## (AstralMedallion.show_card, what the cards draw) in firing order: what fires and in what order, with a thin arrow
## after each trigger card, which is lit. A card that does nothing where it sits (Wand.flags, through
## WorldReader.wand_flags) is dim and struck through. No words, so nothing to translate. It shows a wand read (or a
## preview: WorldReader.wand_moved, wand_swapped) and decides nothing (EI-07). A long wand shrinks to fit.

## An icon's size, the gap between icons, the room an arrow takes, and the smallest an icon may shrink to (px at the
## 1920 x 1080 base).
const ICON := 56.0
const GAP := 10.0
const ARROW := 38.0
const MIN_ICON := 28.0

var _icons: Array[AstralMedallion] = []
var _ids: Array[StringName] = []
var _dead: Array[bool] = []
var _cuts: Array[bool] = []
## Each shown icon's rectangle, for the arrows and the strikes.
var _rects: Array[Rect2] = []
var _marks := Control.new()


func _init() -> void:
	name = "Forecast"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in WorldReader.MOD_SLOTS + 1:  # as many as the row can hold: the Swap's new card placed in a full wand
		var m := AstralMedallion.new()
		m.name = "ForecastIcon%d" % (k + 1)
		m.visible = false
		add_child(m)
		_icons.append(m)
	_marks.name = "Arrows"
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)


## Shows the cards of `wand` (a wand read; {} hides the row) in firing order. The width it may take is its
## custom_minimum_size.x (the page sets it).
func show_forecast(wand: Dictionary) -> void:
	var cards: Array = wand.get("cards", [])
	var flags: Array[StringName] = []
	if not cards.is_empty():
		flags = WorldReader.wand_flags(wand)
	_ids.clear()
	_dead.clear()
	_cuts.clear()
	for k in cards.size():
		var c: Dictionary = cards[k]
		_ids.append(c["id"])
		_dead.append(k < flags.size() and flags[k] != &"")
		_cuts.append(int(c["trigger"]) >= 0 and k < cards.size() - 1)
	visible = not _ids.is_empty()
	_lay_out()


## The card ids of the icons shown, in firing order (tests).
func icon_ids() -> Array[StringName]:
	return _ids.duplicate()


## The texture icon `k` draws (tests: the card's own icon).
func icon_texture(k: int) -> Texture2D:
	return _icons[k].icon_texture()


## Whether icon `k` is struck through (a card that does nothing where it sits) and whether an arrow follows it.
func is_dead(k: int) -> bool:
	return _dead[k]


func arrow_after(k: int) -> bool:
	return _cuts[k]


## The icons' extent on screen (tests: it stays on screen at 8 slots).
func icons_rect() -> Rect2:
	var r := Rect2(global_position, Vector2.ZERO)
	for k in _rects.size():
		r = r.merge(Rect2(global_position + _rects[k].position, _rects[k].size))
	return r


func _lay_out() -> void:
	var n := _ids.size()
	var arrows := _cuts.count(true)
	var whole := n * ICON + maxi(n - 1 - arrows, 0) * GAP + arrows * ARROW
	var limit := custom_minimum_size.x if custom_minimum_size.x > 0.0 else whole
	var share := clampf(limit / maxf(whole, 1.0), MIN_ICON / ICON, 1.0)
	var side := roundf(ICON * share)
	var x := 0.0
	_rects.clear()
	for k in _icons.size():
		var m := _icons[k]
		m.visible = k < n
		if k >= n:
			continue
		m.position = Vector2(x, 0.0)
		m.size = Vector2(side, side)
		m.k = share
		m.fit()
		m.show_card(_ids[k])
		m.focused = _cuts[k]
		m.modulate = Color(1, 1, 1, 0.38) if _dead[k] else Color.WHITE
		_rects.append(Rect2(m.position, m.size))
		x += side + (ARROW * share if _cuts[k] else GAP * share)
	custom_minimum_size.y = side
	_marks.queue_redraw()


## The thin arrows after the trigger cards, and the strike over a card that does nothing.
func _draw_marks() -> void:
	for k in _rects.size():
		var r := _rects[k]
		if _dead[k]:
			_marks.draw_line(r.position, r.end, Color(0.86, 0.45, 0.42), 2.0, true)
		if not _cuts[k]:
			continue
		var y := r.get_center().y
		var a := Vector2(r.end.x + 5.0, y)
		var b := Vector2(_rects[k + 1].position.x - 5.0, y)
		var line := Color(AstralCardArt.ACCENT, 0.9)
		_marks.draw_line(a, b, line, 1.0, true)
		_marks.draw_line(b, b + Vector2(-6.0, -5.0), line, 1.0, true)
		_marks.draw_line(b, b + Vector2(-6.0, 5.0), line, 1.0, true)
