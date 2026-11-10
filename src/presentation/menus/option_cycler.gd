class_name OptionCycler
extends Button
## A choice that works the same on every device: it shows "‹ value ›"; left / right (arrows, d-pad, stick)
## step through the values, and pressing it (click, Enter, pad A) steps forward. No popup to get lost in on a pad.
## `astral` (Options) draws it in Astral; `text` still reads "‹ value ›", only the look is drawn:
## - an on / off choice is a switch: a slim lozenge with a diamond knob (on: right, the lozenge washed in the accent;
##   off: left, ink), its word in the value column at the right;
## - a longer choice is a field: the value centred between two thin chevrons over a hairline.
## Focused or hovered (one rule): the lines turn moonlight, a second contour sits round the switch, the chevrons light.

signal changed(value: String)

## The value column at the right of an Options row (the sliders' number sits there) and the switch's size.
const VALUE_W := 72.0
const SWITCH := Vector2(48, 24)

var values: Array = []
var index := 0
## Translation key per value (same order as values).
var label_keys: Array = []
var astral := false:
	set(v):
		astral = v
		_astral_look()


func _init(p_values: Array, p_label_keys: Array, current: String) -> void:
	values = p_values
	label_keys = p_label_keys
	index = maxi(0, values.find(current))
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	custom_minimum_size = Vector2(0, 44)
	pressed.connect(func() -> void: step(1))
	_show()


func value() -> String:
	return String(values[index])


func step(by: int) -> void:
	index = posmod(index + by, values.size())
	_show()
	changed.emit(value())


## An on / off choice (drawn as a switch in Astral).
func is_switch() -> bool:
	return values.size() == 2 and values.has("on") and values.has("off")


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		step(-1)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		step(1)
		accept_event()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			_show()
		NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT, NOTIFICATION_MOUSE_ENTER, NOTIFICATION_MOUSE_EXIT:
			queue_redraw()


func _show() -> void:
	text = "‹  %s  ›" % tr(label_keys[index])
	queue_redraw()


## The word the Astral look draws (a subclass adds to it: the Wardrobe's locked robe).
func shown_word() -> String:
	return tr(label_keys[index])


func _astral_look() -> void:
	if not astral:
		return
	var none := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(s, none)
	for c in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_hover_pressed_color",
		"font_disabled_color",
		"font_outline_color"
	]:
		add_theme_color_override(c, Color(0, 0, 0, 0))
	add_theme_constant_override("outline_size", 0)
	custom_minimum_size = Vector2(0, 40)
	queue_redraw()


func _draw() -> void:
	if not astral:
		return
	var lit := not disabled and (has_focus() or is_hovered())
	var y := roundf(size.y * 0.5)
	var line := AstralCardArt.LINE_HI if lit else AstralCardArt.LINE
	var word := shown_word()
	var font := AstralMenu.sans(true)
	var fs := 15 if is_switch() else AstralMenu.BODY_SIZE
	var ascent := font.get_ascent(fs)
	var descent := font.get_descent(fs)
	var base := roundf(y + (ascent - descent) * 0.5)
	var col := AstralCardArt.LINE_HI if lit else AstralCardArt.TEXT
	var end := size.x - VALUE_W - 8.0
	if is_switch():
		var on := value() == "on"
		var r := Rect2(end - SWITCH.x, y - SWITCH.y * 0.5, SWITCH.x, SWITCH.y)
		var o := AstralChrome.px(r)
		var pts := AstralChrome.lozenge(o, 12.0)
		draw_colored_polygon(
			pts, Color(AstralCardArt.ACCENT, 0.28) if on else Color(AstralChrome.INK, 0.7)
		)
		if lit:
			AstralChrome.poly(
				self, AstralChrome.contour(pts, 5.0), Color(AstralCardArt.LINE_HI, 0.3)
			)
		var edge := AstralCardArt.LINE_HI if on or lit else AstralCardArt.LINE
		AstralChrome.poly(self, pts, edge, 1.4 if lit else 1.0)
		var kx := o.end.x - 15.0 if on else o.position.x + 15.0
		var knob := AstralCardArt.LINE_HI if on else AstralCardArt.DIM
		AstralChrome.dia(self, Vector2(roundf(kx) + 0.5, y + 0.5), 7.0, AstralChrome.INK, knob)
		var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var wc := col if on or lit else AstralCardArt.DIM
		draw_string(font, Vector2(size.x - w, base), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, wc)
		return
	# A field: a hairline under it, the value centred between two chevrons.
	AstralChrome.hline(self, 8, end, y + 16.0, Color(line, 0.9 if lit else 0.55))
	var chev := Color(line, 1.0 if lit else 0.7)
	for side in [-1.0, 1.0]:
		var cx: float = 22.0 if side < 0.0 else end - 14.0
		var tip := Vector2(cx + side * 3.0, y)
		draw_polyline(
			PackedVector2Array(
				[tip + Vector2(-side * 6.0, -6.0), tip, tip + Vector2(-side * 6.0, 6.0)]
			),
			chev,
			1.4 if lit else 1.0,
			true
		)
	var tw := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(
		font,
		Vector2(roundf((end + 8.0 - tw) * 0.5), base),
		word,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		col
	)
