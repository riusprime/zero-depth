class_name AbilitySquareIcons
extends RefCounted
## The code-drawn symbols of the HUD's ability squares that the game's own icon set (ItemIcons) does not have
## (v0.9.5 HU; drawn first by the HM mockup): the Gun's Scatter Blast (a fan of three pellets), the Blade's Lunge
## Cleave (a slash with a forward arrow), the Dash (a double chevron) and the Vent (an upward arrow). Any other id
## is the game's own icon.


## Draws `id` in `rect` with `col` on `ci`.
static func draw(ci: CanvasItem, id: StringName, rect: Rect2, col: Color) -> void:
	match id:
		&"skill", &"scatter_blast":
			var o := rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.5)
			for a in [-0.55, 0.0, 0.55]:
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(o, o + d * rect.size.x * 0.58, Color(col, 0.55), 2.0)
				ci.draw_circle(o + d * rect.size.x * 0.74, rect.size.x * 0.1, col)
			ci.draw_circle(o, rect.size.x * 0.09, col)
		&"lunge_cleave":
			var p := rect.position
			var s := rect.size
			var from := p + Vector2(s.x * 0.1, s.y * 0.5)
			ci.draw_arc(
				from + Vector2(s.x * 0.05, 0), s.x * 0.62, -0.9, 0.9, 16, Color(col, 0.55), 3.0
			)
			ci.draw_line(from, p + Vector2(s.x * 0.85, s.y * 0.5), col, 4.0)
			ci.draw_polyline(
				PackedVector2Array(
					[
						p + Vector2(s.x * 0.62, s.y * 0.3),
						p + Vector2(s.x * 0.88, s.y * 0.5),
						p + Vector2(s.x * 0.62, s.y * 0.7)
					]
				),
				col,
				4.0
			)
		&"dash":
			for dx in [0.1, 0.45]:
				var p := rect.position + Vector2(rect.size.x * dx, 0)
				(
					ci
					. draw_polyline(
						PackedVector2Array(
							[
								p + Vector2(0, rect.size.y * 0.12),
								p + Vector2(rect.size.x * 0.35, rect.size.y * 0.5),
								p + Vector2(0, rect.size.y * 0.88),
							]
						),
						col,
						5.0
					)
				)
		&"vent":
			var c := rect.get_center()
			var tip := c + Vector2(0, -rect.size.y * 0.3)
			ci.draw_polyline(
				PackedVector2Array(
					[
						c + Vector2(-rect.size.x * 0.3, rect.size.y * 0.1),
						tip,
						c + Vector2(rect.size.x * 0.3, rect.size.y * 0.1)
					]
				),
				col,
				4.0
			)
			ci.draw_line(tip, c + Vector2(0, rect.size.y * 0.4), col, 4.0)
		_:
			ItemIcons.draw(ci, id, rect, col)
