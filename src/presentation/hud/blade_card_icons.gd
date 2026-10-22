class_name BladeCardIcons
extends RefCounted
## v0.8.0 BL (docs/roadmap/v0.8.0/BLADE_AUDIT.md B4): the symbols of the two Blade multiplier cards, in the item
## icons' style (ItemIcons: shapes in a unit box, y down, drawn with CanvasItem calls, no external art).
## ItemIcons.shapes falls through to these, so a card, the wand row and the Codex show them.
## - Blade Storm: two spinning blades flying out on a loop that comes back.
## - Riposte Chain: a slash, and its cut leaping on to two more marks.

const IDS: Array[StringName] = [&"blade_storm", &"riposte_chain"]


static func has_icon(id: StringName) -> bool:
	return id in IDS


static func shapes(id: StringName) -> Array:
	match id:
		&"blade_storm":
			return [
				ItemIcons._arc(Vector2(0.5, 0.5), 0.36, 200.0, 520.0, 0.05),
				_blade(Vector2(0.24, 0.3), 0.0),
				_blade(Vector2(0.76, 0.7), 180.0),
				ItemIcons._circle(Vector2(0.5, 0.5), 0.08, 0.0),
			]
		&"riposte_chain":
			return [
				ItemIcons._line([Vector2(0.12, 0.86), Vector2(0.44, 0.38)], 0.09),
				ItemIcons._line(
					[Vector2(0.44, 0.38), Vector2(0.66, 0.58), Vector2(0.86, 0.16)], 0.05
				),
				ItemIcons._circle(Vector2(0.66, 0.58), 0.07, 0.0),
				ItemIcons._circle(Vector2(0.86, 0.16), 0.07, 0.0),
			]
	return ItemIcons.gem()


## A small curved blade at `c`, turned by `deg` (a filled crescent).
static func _blade(c: Vector2, deg: float) -> Dictionary:
	var pts := []
	for k in 7:
		var a := deg_to_rad(deg - 60.0 + 20.0 * k)
		pts.append(c + Vector2(cos(a), sin(a)) * 0.18)
	for k in 7:
		var a := deg_to_rad(deg + 60.0 - 20.0 * k)
		pts.append(
			(
				c
				+ Vector2(cos(a), sin(a)) * 0.1
				+ Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * 0.05
			)
		)
	return ItemIcons._poly(pts)
