class_name AstralMedallion
extends Control
## The Astral card's icon medallion (W3_O13_UI_STYLE_G2.md round 2, Astral): a 1 px contour with a
## dotted inner ring, holding the owner's painted icon (AstralCardArt.icon, icon_unknown when the card has none).
## Focus: the contour brightens and four small four-point stars ring it. It draws; it takes no input (EI-07).

const DOTS := 36
## The icon's size as a share of the medallion (the painted icons carry their own soft glow round them).
const ICON_SHARE := 1.18

var icon := TextureRect.new()
var focused := false:
	set(v):
		focused = v
		queue_redraw()
## Card px → screen px (line widths and star sizes).
var k := 1.0


func _init() -> void:
	name = "Medallion"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icon)
	resized.connect(fit)


## Shows card `id`'s icon (the fallback when it has none; nothing for an empty card, `id` &"").
func show_card(id: StringName) -> void:
	icon.texture = AstralCardArt.icon(id) if id != &"" else null
	icon.visible = id != &""
	queue_redraw()


func icon_texture() -> Texture2D:
	return icon.texture if icon.visible else null


## Sizes the icon to the medallion (StoneCard calls it after a layout made before the card is in the tree).
func fit() -> void:
	var s := size * ICON_SHARE
	icon.size = s
	icon.position = (size - s) * 0.5


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var line := AstralCardArt.LINE_HI if focused else AstralCardArt.LINE
	draw_circle(c, r, Color(0.02, 0.03, 0.07, 0.35))
	draw_arc(
		c,
		r,
		0.0,
		TAU,
		72,
		Color(line, 0.9 if focused else 0.55),
		(1.4 if focused else 1.0) * k,
		true
	)
	var dot := Color(AstralCardArt.METAL, 0.5 if focused else 0.3)
	for i in DOTS:
		var a := i * TAU / DOTS
		draw_circle(c + Vector2(cos(a), sin(a)) * (r - 6.0 * k), 0.9 * k, dot)
	if not focused:
		return
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		_star(c + Vector2(cos(a), sin(a)) * (r + 7.0 * k), 4.5 * k, AstralCardArt.LINE_HI)


## A four-point star at `p`, `r` px to its tips.
func _star(p: Vector2, r: float, col: Color) -> void:
	var w := r * 0.28
	draw_colored_polygon(
		PackedVector2Array(
			[
				p + Vector2(0, -r),
				p + Vector2(w, -w),
				p + Vector2(r, 0),
				p + Vector2(w, w),
				p + Vector2(0, r),
				p + Vector2(-w, w),
				p + Vector2(-r, 0),
				p + Vector2(-w, -w),
			]
		),
		col
	)
