class_name InteractPrompt
extends Control
## v0.9.5 PR (owner L15, Q10 a): the one interaction prompt every interactable shows. It sits under the hero (40 px
## below the feet at 1080p, scaled with the viewport height), one line, centred: the interact button drawn in code
## for the device last used, then a short verb, then a cost only when there is one ("[X] Open", "[X] Open · 40 ◆").
## A string key's text splits at its first " · ": the verb before, the cost (or other short tail) after it.
## Fades in 0.12 s when shown, out when hidden. Reads only (WorldReader); the press goes out as input.
## The device follows the last event as AbilitySquares tracks it (AbilitySquares.pad_after).

const ACTION := &"interact"
const FADE_S := 0.12
## Below the hero's feet at 1080p, and the text size at 1080p.
const BELOW_PX := 40.0
const FONT_PX := 18
const GLYPH_PX := 26.0
const REF_H := 1080.0
const SEP := " · "
const POOR := Color(1.0, 0.45, 0.4)
## The Xbox face buttons (index -> letter, colour) and the PlayStation ones (index -> shape, colour).
const XBOX := {
	JOY_BUTTON_A: ["A", Color(0.35, 0.78, 0.38)],
	JOY_BUTTON_B: ["B", Color(0.9, 0.3, 0.3)],
	JOY_BUTTON_X: ["X", Color(0.3, 0.55, 0.95)],
	JOY_BUTTON_Y: ["Y", Color(0.97, 0.8, 0.25)],
}
const PLAYSTATION := {
	JOY_BUTTON_A: [&"cross", Color(0.4, 0.6, 1.0)],
	JOY_BUTTON_B: [&"circle", Color(0.95, 0.38, 0.38)],
	JOY_BUTTON_X: [&"square", Color(0.95, 0.55, 0.8)],
	JOY_BUTTON_Y: [&"triangle", Color(0.4, 0.85, 0.55)],
}

## True while the last device used was a gamepad (tests set it).
var pad_active := false
## The pad's name (Input.get_joy_name(0)); tests set it.
var joy_name := ""

var _glyph := GlyphView.new()
var _verb := Label.new()
var _cost := Label.new()
var _row := HBoxContainer.new()
var _shown := false
var _text := ""
var _alpha := 0.0
var _hero_sim := Vector2.ZERO
var _has_hero := false


func _init() -> void:
	name = "InteractPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 8)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_row)
	_row.add_child(_glyph)
	for l: Label in [_verb, _cost]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		HudStyle.style_label(l, FONT_PX, true)
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_row.add_child(l)
	pad_active = not Input.get_connected_joypads().is_empty()
	joy_name = Input.get_joy_name(0) if pad_active else ""
	visible = false
	modulate.a = 0.0


func _input(event: InputEvent) -> void:
	var was := pad_active
	pad_active = AbilitySquares.pad_after(event, pad_active)
	if pad_active != was:
		joy_name = Input.get_joy_name(0) if pad_active else joy_name
		_refresh_glyph()


func _process(delta: float) -> void:
	var goal := 1.0 if _shown else 0.0
	if _alpha != goal:
		_alpha = move_toward(_alpha, goal, delta / FADE_S)
		modulate.a = _alpha
		visible = _alpha > 0.0 or _shown
	if visible:
		_place(null)


## Shows `text` ("Verb" or "Verb · cost") under the hero; `poor` reddens it; `glyph` false hides the button (a
## state with nothing to press, "Spent").
func show_prompt(
	reader: WorldReader, text: String, poor := false, tint := Color.WHITE, glyph := true
) -> void:
	if (reader != null and reader.player_dead()) or text == "":
		hide_prompt()
		return
	_shown = true
	_text = text
	var cut := text.find(SEP)
	_verb.text = text if cut < 0 else text.substr(0, cut)
	_cost.text = "" if cut < 0 else text.substr(cut + SEP.length())
	_cost.visible = cut >= 0
	var col := POOR if poor else tint
	_verb.add_theme_color_override("font_color", col)
	_cost.add_theme_color_override("font_color", col if poor else col.darkened(0.12))
	_glyph.visible = glyph
	_refresh_glyph()
	visible = true
	_place(reader)


func hide_prompt() -> void:
	_shown = false
	_text = ""
	if _alpha <= 0.0:
		visible = false


## The plain text shown now ("" when none), without the button.
func text() -> String:
	return _text if _shown else ""


func is_poor() -> bool:
	return _verb.get_theme_color(&"font_color") == POOR


func glyph() -> GlyphView:
	return _glyph


## The glyph's look for `action` on the device in use: {style: &"key"|&"xbox"|&"ps", label, shape, color}.
static func glyph_spec(action: StringName, pad: bool, pad_name: String) -> Dictionary:
	var spec := KitHud.key_spec_for(action, pad)
	var style := &"key"
	if pad:
		style = &"ps" if is_playstation(pad_name) else &"xbox"
	var out := {"style": style, "label": "", "shape": &"", "color": Color(0.85, 0.85, 0.85)}
	if not spec.is_empty() and spec[0] == &"button":
		var b := int(spec[1])
		if style == &"ps" and PLAYSTATION.has(b):
			out["shape"] = PLAYSTATION[b][0]
			out["color"] = PLAYSTATION[b][1]
			return out
		if style == &"xbox" and XBOX.has(b):
			out["label"] = XBOX[b][0]
			out["color"] = XBOX[b][1]
			return out
	var t := InputLabels.short_text(spec)
	if style == &"ps" and AbilitySquares.PS_NAMES.has(t):
		t = AbilitySquares.PS_NAMES[t]
	out["label"] = t
	return out


## Whether a pad's name reads as a PlayStation pad ("PS", DualSense, DualShock, Sony, Wireless Controller).
static func is_playstation(pad_name: String) -> bool:
	var n := pad_name.to_lower()
	if AbilitySquares.is_playstation(n) or n.contains("wireless controller"):
		return true
	for w in n.split(" ", false):
		if w == "ps" or w.begins_with("ps(") or w.begins_with("ps-"):
			return true
	return false


## Where the prompt's top-left sits for a hero whose feet are at `feet` on a screen `view_h` px tall.
static func top_left_for(feet: Vector2, content: Vector2, view_h: float) -> Vector2:
	return feet + Vector2(-content.x * 0.5, BELOW_PX * view_h / REF_H)


func _refresh_glyph() -> void:
	_glyph.spec = glyph_spec(ACTION, pad_active, joy_name)
	_glyph.update_minimum_size()
	_glyph.queue_redraw()


func _place(reader: WorldReader) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var rect := vp.get_visible_rect()
	var k := rect.size.y / REF_H
	_verb.add_theme_font_size_override("font_size", roundi(FONT_PX * k))
	_cost.add_theme_font_size_override("font_size", roundi(FONT_PX * k))
	_glyph.custom_minimum_size = Vector2(GLYPH_PX, GLYPH_PX) * k
	if reader != null:
		_hero_sim = reader.player_pos()
		_has_hero = true
	var feet := rect.size * 0.5
	var cam := vp.get_camera_3d()
	if cam != null and _has_hero:
		feet = cam.unproject_position(SimPlane.to_3d(_hero_sim))
	_row.size = _row.get_combined_minimum_size()
	size = _row.size
	position = top_left_for(feet, size, rect.size.y)


## The button, drawn in code: a key cap, an Xbox colour disc with its letter, or a PlayStation shape.
class GlyphView:
	extends Control
	var spec := {"style": &"key", "label": "", "shape": &"", "color": Color.WHITE}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(GLYPH_PX, GLYPH_PX)

	func _get_minimum_size() -> Vector2:
		if spec["style"] == &"key":
			var f := get_theme_default_font()
			var h := custom_minimum_size.y
			var w := (
				f
				. get_string_size(
					String(spec["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.5)
				)
				. x
			)
			return Vector2(maxf(h, w + 14.0), h)
		return Vector2(custom_minimum_size.y, custom_minimum_size.y)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var c := r.get_center()
		var rad := minf(r.size.x, r.size.y) * 0.5
		var fnt := get_theme_default_font()
		var col: Color = spec["color"]
		if spec["style"] == &"key":
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.14, 0.15, 0.18, 0.95)
			sb.border_color = Color(0.85, 0.87, 0.92)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(int(rad * 0.3))
			draw_style_box(sb, r.grow(-1.0))
			_centered(fnt, String(spec["label"]), c, int(rad * 1.0), Color(0.95, 0.96, 1.0))
			return
		draw_circle(c, rad, Color(0.1, 0.1, 0.13, 0.95))
		draw_arc(c, rad - 1.0, 0.0, TAU, 28, col, 2.0)
		var s: StringName = spec["shape"]
		var w := rad * 0.12 + 1.5
		var q := rad * 0.45
		if s == &"":
			_centered(fnt, String(spec["label"]), c, int(rad * 1.1), col)
		elif s == &"cross":
			draw_line(c + Vector2(-q, -q), c + Vector2(q, q), col, w, true)
			draw_line(c + Vector2(-q, q), c + Vector2(q, -q), col, w, true)
		elif s == &"circle":
			draw_arc(c, q * 1.05, 0.0, TAU, 24, col, w, true)
		elif s == &"square":
			draw_rect(Rect2(c - Vector2(q, q) * 0.95, Vector2(q, q) * 1.9), col, false, w)
		else:
			var tri := PackedVector2Array(
				[
					c + Vector2(0, -q * 1.1),
					c + Vector2(q * 1.05, q * 0.8),
					c + Vector2(-q * 1.05, q * 0.8),
				]
			)
			tri.append(tri[0])
			draw_polyline(tri, col, w, true)

	func _centered(f: Font, t: String, c: Vector2, fs: int, col: Color) -> void:
		var sz := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var at := c + Vector2(-sz.x * 0.5, f.get_ascent(fs) - sz.y * 0.5)
		draw_string(f, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
