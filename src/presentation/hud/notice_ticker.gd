class_name NoticeTicker
extends VBoxContainer
## A boxless stack of
## short lines under the top plate, each an icon and a name. A pickup, a combo and an element pair each add one; it
## holds about HOLD seconds (an element pair PAIR_HOLD), fades and is gone. At most MAX_LINES; a new one past that
## pushes the oldest out in PUSH_OUT seconds. Reduced motion: no slide, the line appears and fades. It shows what it
## is told (already translated) and decides nothing (EI-07); `advance` runs on the view's clock, not the sim's (EI-03).

const MAX_LINES := 3
const HOLD := 3.0
const PAIR_HOLD := 4.0
const FADE_IN := 0.18
const FADE_OUT := 0.45
const PUSH_OUT := 0.15
const SLIDE := 6.0
const ICON := 22
const FONT_SIZE := 17
const INK := Color("#070913")
const SPARK := Color("#FFF1C8")
const PIP_OFF := Color("#8A90A8", 0.5)


## One line: a wrapper the stack lays out, with the content (icon, name, pips) a child that can slide.
class Line:
	extends Control
	var age := 0.0
	var hold := HOLD
	## Fast fade-out clock (>= 0: pushed out); -1 not leaving.
	var leaving := -1.0
	var content := HBoxContainer.new()
	var label := HudStyle.label(FONT_SIZE, true)

	func _init(p_text: String, p_color: Color) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 7)
		label.text = p_text
		label.name = "Text"
		label.add_theme_color_override("font_color", p_color)
		label.add_theme_constant_override("outline_size", 5)
		label.add_theme_color_override("font_outline_color", Color(INK, 0.9))
		add_child(content)

	func lay_out() -> void:
		content.size = content.get_combined_minimum_size()
		custom_minimum_size = Vector2(content.size.x, ICON + 4)


## The element pair's level pips.
class _Pips:
	extends Control
	var level := 1

	func _init(p_level: int) -> void:
		level = p_level
		custom_minimum_size = Vector2(maxi(1, p_level) * 9.0 + 2.0, ICON)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for k in maxi(1, level):
			draw_circle(Vector2(5.0 + k * 9.0, ICON * 0.5), 3.0, SPARK)


var _lines: Array[Line] = []


func _init() -> void:
	name = "NoticeTicker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 2)


## A picked-up item (or ability or stat card): its icon and name.
func add_item(id: StringName, color: Color, title: String) -> void:
	var icon := ItemIconView.new()
	icon.set_item(id, color)
	_add(_make(icon, title, color, 1, HOLD))


## A combo that unlocked: its two items' icons and its name.
func add_combo(id: StringName, a: StringName, b: StringName, title: String) -> void:
	var col := ItemLooks.combo_color(id)
	_add(_make(ComboIconView.new(a, b, col), title, col, 0, HOLD))


## An element pair that turned on: its two overlapped element icons, its name and level pips.
func add_pair(id: StringName, a: StringName, b: StringName, title: String, level: int) -> void:
	var col := ItemLooks.combo_color(id)
	_add(_make(ComboIconView.new(a, b, col), title, col, level, PAIR_HOLD))


func _make(icon: Control, title: String, color: Color, pips: int, hold: float) -> Line:
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := Line.new(title, HudStyle.tone(color).lightened(0.25))
	line.hold = hold
	line.content.add_child(icon)
	line.content.add_child(line.label)
	if pips > 0 and hold == PAIR_HOLD:
		var p := _Pips.new(pips)
		p.name = "Pips"
		line.content.add_child(p)
	line.modulate.a = 0.0
	return line


func _add(line: Line) -> void:
	var live := _live()
	while live.size() >= MAX_LINES:  # push the oldest out, quickly
		live[0].leaving = 0.0
		live.remove_at(0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lines.append(line)
	add_child(line)
	line.lay_out()


## The lines not on their way out (what "at most three" counts).
func _live() -> Array[Line]:
	var out: Array[Line] = []
	for l in _lines:
		if l.leaving < 0.0:
			out.append(l)
	return out


func line_count() -> int:
	return _live().size()


## All the lines' texts, oldest first (tests read it).
func texts() -> PackedStringArray:
	var out := PackedStringArray()
	for l in _live():
		out.append(l.label.text)
	return out


func is_empty() -> bool:
	return _lines.is_empty()


## The height the stack takes now (0 when empty): what the phase line stacks under.
func stack_height() -> float:
	return 0.0 if _lines.is_empty() else get_combined_minimum_size().y


## `delta` seconds of the view's clock: fade in, hold, fade out, go.
func advance(delta: float) -> void:
	var slide := not ViewPrefs.reduced_motion
	for l: Line in _lines.duplicate():
		var a := 1.0
		if l.leaving >= 0.0:
			l.leaving += delta
			a = 1.0 - l.leaving / PUSH_OUT
		else:
			l.age += delta
			var out_at: float = l.hold
			if l.age < FADE_IN:
				a = l.age / FADE_IN
			elif l.age > out_at:
				a = 1.0 - (l.age - out_at) / FADE_OUT
		if a <= 0.0 and (l.leaving >= 0.0 or l.age > l.hold):
			_lines.erase(l)
			remove_child(l)
			l.queue_free()
			continue
		l.modulate.a = clampf(a, 0.0, 1.0)
		var y := 0.0
		if slide and l.age < FADE_IN and l.leaving < 0.0:
			y = SLIDE * (1.0 - l.age / FADE_IN)
		l.content.position.y = 2.0 + y


func clear() -> void:
	for l in _lines:
		remove_child(l)
		l.queue_free()
	_lines.clear()
