class_name BuildPicker
extends Control
## The start screen (v0.3.0 L15: "pick at start, have a two card screen with a cool animation of appearing that
## shows both"): one BuildCard per BuildDefinition (Blade, then Gun), staggered in with an echo trail and a landing
## glitch, under a title that glitches in too. The last pick has focus.
## - Mouse: hover focuses a card, a click picks it.
## - Keyboard: Left/Right move the focus, Enter picks, Esc goes back.
## - Pad: d-pad or left stick move the focus, A (Cross) picks, B (Circle) goes back.
## It only reports the choice (`picked`); the app starts the run with it.

signal picked(id: StringName)
signal back_pressed

const STAGGER_S := 0.16
const FIRST_DELAY_S := 0.12
const TITLE_S := 0.45

var cards: Array[BuildCard] = []
var _ids: Array[StringName] = []
var _focus_index := 0
var _title := Label.new()
var _title_echo := Label.new()
var _hint := Label.new()
var _back := Button.new()
var _t := 0.0
var _backdrop := Backdrop.new()


func _init(builds: Array, last_id: StringName) -> void:
	name = "BuildPicker"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	centre.add_child(col)
	var head := Control.new()
	head.custom_minimum_size = Vector2(0, 60)
	col.add_child(head)
	for l: Label in [_title_echo, _title]:
		l.text = "UI_CHOOSE_BUILD"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 44)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		head.add_child(l)
	_title_echo.modulate = Color(BuildCard.CYAN, 0.0)
	_title.name = "Title"
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 64)
	col.add_child(row)
	var k := 0
	for def: BuildDefinition in builds:
		var c := BuildCard.new(
			def.weapon,
			def.name_key,
			def.desc_key,
			def.damage_permille,
			FIRST_DELAY_S + STAGGER_S * k
		)
		c.name = String(def.id).capitalize()
		var id := def.id
		c.pressed.connect(func() -> void: picked.emit(id))
		row.add_child(c)
		cards.append(c)
		_ids.append(id)
		if id == last_id:
			_focus_index = k
		k += 1
	for i in cards.size():
		var c := cards[i]
		c.focus_neighbor_left = c.get_path_to(cards[maxi(0, i - 1)])
		c.focus_neighbor_right = c.get_path_to(cards[mini(cards.size() - 1, i + 1)])
		c.focus_neighbor_top = c.get_path_to(c)
	_hint.text = "BUILD_HINT"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.modulate = Color(1, 1, 1, 0.65)
	col.add_child(_hint)
	_back.text = "UI_BACK"
	_back.name = "Back"
	_back.custom_minimum_size = Vector2(220, 46)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.add_theme_font_size_override("font_size", 20)
	_back.pressed.connect(func() -> void: back_pressed.emit())
	MenuStyle.apply(_back)  # v0.5.5 A5: the Cold glass row look; the build cards keep their own
	col.add_child(_back)


func _ready() -> void:
	for c in cards:
		c.focus_neighbor_bottom = c.get_path_to(_back)
	if not cards.is_empty():
		_back.focus_neighbor_top = _back.get_path_to(cards[_focus_index])


func focus_first() -> void:
	if not cards.is_empty():
		cards[_focus_index].grab_focus()


## The id of the focused card (&"" when none has focus).
func focused_id() -> StringName:
	for i in cards.size():
		if cards[i].has_focus():
			return _ids[i]
	return &""


## Ends the appear animation at once (screenshots).
func settle() -> void:
	seek(TITLE_S + 2.0)


## Sets the animation clock of the title, the backdrop and every card (the screenshot tool scrubs with it).
func seek(t: float) -> void:
	_t = t
	for c in cards:
		c.seek(t)
	_animate()


func _process(delta: float) -> void:
	_t += delta
	_animate()


func _animate() -> void:
	_backdrop.t = _t
	_backdrop.queue_redraw()
	# The hint and Back fade in once the last card has landed.
	var last := FIRST_DELAY_S + STAGGER_S * maxi(0, cards.size() - 1) + BuildCard.APPEAR_S
	var a := clampf((_t - last) / 0.25, 0.0, 1.0)
	_hint.modulate.a = 0.65 * a
	_back.modulate.a = a
	# The title glitches in: a cyan echo that jitters and fades as the title firms up.
	var p := clampf(_t / TITLE_S, 0.0, 1.0)
	_title.modulate.a = p
	var jitter := 0.0 if p >= 1.0 else float((int(_t * 40.0) * 37) % 13 - 6)
	_title_echo.position = Vector2(jitter, 3.0 * (1.0 - p))
	_title_echo.modulate.a = 0.55 * (1.0 - p) if p < 1.0 else 0.0
	_title.position = Vector2(-jitter * 0.3, 0)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed(&"ui_cancel")
		or (
			event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B
		)
	):
		get_viewport().set_input_as_handled()
		back_pressed.emit()


## A dark field with a faint grid drifting down and a soft vignette, behind the cards.
class Backdrop:
	extends Control

	const STEP := 56.0
	var t := 0.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.03, 0.05, 0.07, 0.86))
		var line := Color(BuildCard.CYAN, 0.045)
		var drift := fmod(t * 12.0, STEP)
		var x := fmod(size.x * 0.5, STEP)
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), line, 1.0)
			x += STEP
		var y := drift - STEP
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), line, 1.0)
			y += STEP
		# Vignette: darker bands toward the edges.
		for k in 8:
			var g := 1.0 - k / 8.0
			var inset := Vector2(size.x, size.y) * (0.03 * k)
			draw_rect(
				Rect2(inset * 0.5, size - inset), Color(0, 0, 0, 0.05 * g), false, size.y * 0.03
			)
