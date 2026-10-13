class_name AchievementIcon
extends Control
## v0.7.5 AC: an achievement's glyph (AchievementGlyphs) in a small diamond-cut badge: warm gold when unlocked, a dark
## silhouette when locked, a "?" badge when hidden and locked. Draws only.

const GOLD := Color("#F2C46A")
const LOCKED := Color(0.36, 0.4, 0.46)

var glyph := &"star"
var unlocked := false
var hidden_locked := false
## Shapes drawn the last time (tests).
var drawn := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_glyph(g: StringName, p_unlocked: bool, p_hidden: bool = false) -> void:
	glyph = g
	unlocked = p_unlocked
	hidden_locked = p_hidden
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := GOLD if unlocked else LOCKED
	var ring := HudStyle.plate_points(r.grow(-1.0), minf(size.x, size.y) * 0.22)
	draw_colored_polygon(ring, Color(c, 0.14 if unlocked else 0.08))
	var loop := ring.duplicate()
	loop.append(ring[0])
	draw_polyline(loop, Color(c, 0.85 if unlocked else 0.4), 1.5, true)
	if hidden_locked:
		var font := HudStyle.font(true)
		var fs := int(size.y * 0.55)
		var at := Vector2(0, (size.y + fs * 0.7) * 0.5)
		draw_string(font, at, "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(c, 0.8))
		drawn = 1
		return
	drawn = AchievementGlyphs.draw(self, glyph, r.grow(-size.x * 0.18), c)
