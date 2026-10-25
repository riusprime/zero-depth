class_name ArchiveTile
extends Button
## v0.9.0 CL (COLLECTIBLES.md P4): one collectible's niche on the Rune Archive's shelves (ArchivePage). Found: its gem
## in its own colour, drawn in layers (a soft glow behind, the faceted stone with a lit and a shaded side, a white-hot
## glint, a ring of light under it); not found: a dark silhouette of the same stone with a "?". It changes nothing.

const SIZE := Vector2(112, 112)

## The collectible (CollectibleDefinition) and whether the profile has found it.
var def: CollectibleDefinition
var found := false


func _init() -> void:
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	flat = true
	text = ""
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mouse_entered.connect(grab_focus)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func show_entry(p_def: CollectibleDefinition, p_found: bool) -> void:
	def = p_def
	found = p_found
	name = "Tile_%s" % def.id
	queue_redraw()


func _draw() -> void:
	var c := SIZE * 0.5
	var focus := has_focus()
	var col := def.color if def != null and found else Color(0.16, 0.17, 0.2)
	draw_style_box(MenuStyle.tile_slab(col, focus, not found), Rect2(Vector2.ZERO, SIZE))
	if found:  # the glow behind: wide and faint, then tight and bright
		for k in 6:
			var r := 46.0 - k * 6.0
			draw_circle(c, r, Color(col.r, col.g, col.b, 0.05 + k * 0.03))
		draw_arc(c + Vector2(0, 30), 26.0, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.5), 3.0)
	var top := c + Vector2(0, -32)
	var bot := c + Vector2(0, 30)
	var l := c + Vector2(-24, -4)
	var r2 := c + Vector2(24, -4)
	var mid := c + Vector2(0, -6)
	var lit := col.lerp(Color.WHITE, 0.35) if found else col.lerp(Color.WHITE, 0.08)
	var shade := col.darkened(0.35)
	draw_colored_polygon(PackedVector2Array([top, l, mid]), lit)
	draw_colored_polygon(PackedVector2Array([top, mid, r2]), col)
	draw_colored_polygon(PackedVector2Array([l, bot, mid]), col.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([mid, bot, r2]), shade)
	var edge := Color(1, 1, 1, 0.55) if found else Color(0.4, 0.42, 0.48, 0.6)
	draw_polyline(PackedVector2Array([top, r2, bot, l, top]), edge, 1.5, true)
	if found:
		draw_circle(top.lerp(l, 0.4) + Vector2(4, 4), 3.5, Color(1, 1, 1, 0.9))
	else:
		var font := HudStyle.font(true)
		draw_string(
			font, c + Vector2(-10, 12), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 34, MenuStyle.DIM
		)
	if focus:
		draw_rect(Rect2(Vector2(2, 2), SIZE - Vector2(4, 4)), MenuStyle.EMBER, false, 2.0)
