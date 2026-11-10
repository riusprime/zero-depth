class_name StepSlider
extends HSlider
## A volume slider that left / right (arrows, d-pad, stick) always step, instead of moving focus away:
## Godot 4.7's slider let the d-pad's ui_left leave it, so a pad couldn't change a volume.
## `astral` draws it in Astral (AstralMenu's theme leaves the built-in track and grabber empty): a
## 1 px hairline track, the filled part a 3 px accent line, a diamond knob with a lit core. Focused or hovered (one
## rule): the knob turns moonlight with a second contour round it at 25 %, and the track brightens a little.

const KNOB := 7.0

var astral := false:
	set(v):
		astral = v
		queue_redraw()
var _hover := false


func _init() -> void:
	mouse_entered.connect(func() -> void: _set_hover(true))
	mouse_exited.connect(func() -> void: _set_hover(false))


func _set_hover(on: bool) -> void:
	_hover = on
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left", true):
		value -= step
		accept_event()
	elif event.is_action_pressed(&"ui_right", true):
		value += step
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


## Where the knob's centre sits (x, px in the slider), as the built-in grabber would (its 16 px icon's room).
func knob_x() -> float:
	var g := 16.0
	var span := maxf(max_value - min_value, 0.0001)
	return roundf(g * 0.5 + (size.x - g) * (value - min_value) / span)


## Lit: focused or hovered (the look's one focus rule).
func is_lit() -> bool:
	return editable and (has_focus() or _hover)


func _draw() -> void:
	if not astral:
		return
	var lit := is_lit()
	var y := roundf(size.y * 0.5)
	var kx := knob_x()
	AstralChrome.hline(self, 8.0, size.x - 8.0, y, Color(AstralCardArt.METAL, 0.5 if lit else 0.35))
	AstralChrome.hline(self, 8.0, kx, y - 1.0, AstralCardArt.ACCENT, 3.0)
	var kc := Vector2(kx + 0.5, y + 0.5)
	var line := AstralCardArt.LINE_HI if lit else AstralCardArt.METAL
	if lit:
		AstralChrome.dia(self, kc, KNOB + 5.0, Color(AstralCardArt.LINE_HI, 0.3))
	AstralChrome.dia(self, kc, KNOB, line, AstralChrome.INK, 1.4 if lit else 1.0)
	draw_circle(kc, 2.0, line)
