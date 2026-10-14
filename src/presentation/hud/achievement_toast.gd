class_name AchievementToast
extends Control
## v0.7.5 AC (owner N7: "a toast when one unlocks"): a small carved Ember stone slab (StoneBox, v0.8.0 MU: with a gold
## rim inlay and a gold groove, like an achievement row) under the corner minimap:
## "Achievement unlocked", the glyph, the achievement's name and sentence. It slides in, stays SHOW_S and fades; more
## unlocks wait their turn. It never takes the mouse, the focus or input (non-blocking), and it lives on the UI
## layer outside the HUD, so a toast for a floor's last moment carries over into the next floor. Its clock is the
## screen's (a look, never an outcome: EI-03).

const W := 460.0
const PAD := Vector2(16, 12)
const ICON := 52.0
const TOP := 404.0
const RIGHT := 28.0
const SHOW_S := 4.0
const FADE_IN_S := 0.25
const FADE_OUT_S := 0.45
const SLIDE_PX := 24.0
const TEXT_W := W - PAD.x * 2.0 - ICON - 14.0

var icon := AchievementIcon.new()
var header := HudStyle.label(14, true)
var name_label := HudStyle.label(21, true)
var desc_label := HudStyle.label(17)
var _queue: Array[Dictionary] = []
var _current := {}
var _t := 0.0
var _box := StoneBox.new()


func _init() -> void:
	name = "AchievementToast"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	custom_minimum_size = Vector2(W, 0)
	offset_left = -RIGHT - W
	offset_right = -RIGHT
	offset_top = TOP
	visible = false
	_box.pattern = 61
	_box.cut = 12.0
	_box.under = 0.4
	_box.rim = Color(EmberStone.GOLD, 0.75)
	_box.inlay = AchievementIcon.GOLD
	_box.inlay_y = 7.0
	var row := HBoxContainer.new()
	row.name = "Row"
	row.position = PAD
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	header.name = "Header"
	header.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	header.add_theme_color_override("font_color", HudStyle.EMBER_ACCENT)
	name_label.name = "Name"
	desc_label.name = "Desc"
	for l: Label in [name_label, desc_label]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.max_lines_visible = 3
	for l: Label in [header, name_label, desc_label]:
		l.custom_minimum_size = Vector2(TEXT_W, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)


## Queues achievement `a` (AchievementBook's dictionary); it shows when the one before it has gone.
func push(a: Dictionary) -> void:
	_queue.append(a)
	if _current.is_empty():
		_next()


func _next() -> void:
	_current = {} if _queue.is_empty() else _queue.pop_front()
	_t = 0.0
	visible = not _current.is_empty()
	if _current.is_empty():
		return
	icon.show_glyph(_current["glyph"], true)
	_word()
	modulate.a = 0.0


func _word() -> void:
	if _current.is_empty():
		return
	header.text = tr("UI_ACH_TOAST")
	name_label.text = AchievementsPage.title_of(self, _current)
	desc_label.text = AchievementsPage.desc_of(self, _current)
	_fit.call_deferred()


func _fit() -> void:
	var row := get_node("Row") as Control
	row.reset_size()
	size = Vector2(W, row.get_combined_minimum_size().y + PAD.y * 2.0)
	queue_redraw()


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	_t += delta
	var left := SHOW_S - _t
	if left <= 0.0:
		_next()
		return
	var a := minf(1.0, _t / FADE_IN_S) if _t < FADE_IN_S else minf(1.0, left / FADE_OUT_S)
	modulate.a = a
	var slide := (1.0 - minf(1.0, _t / FADE_IN_S)) * SLIDE_PX
	if HudStyle.reduced_motion:  # v0.7.5 SM (accessibility pass): a fade, no slide
		slide = 0.0
	offset_left = -RIGHT - W + slide
	offset_right = -RIGHT + slide


func _draw() -> void:
	_box.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))


## v0.8.0 MU: the toast's stone slab (tests).
func slab() -> StoneBox:
	return _box


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_word()


## The toast is up (fading in, holding or fading out).
func showing() -> bool:
	return not _current.is_empty()


## The achievement shown now (&"" when none).
func current_id() -> StringName:
	return _current.get("id", &"")


## The achievements waiting their turn.
func queued_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for a in _queue:
		out.append(a["id"])
	return out


## Drops the one shown and shows the next now (tests, and a screen that wants the corner clear).
func skip() -> void:
	_next()
