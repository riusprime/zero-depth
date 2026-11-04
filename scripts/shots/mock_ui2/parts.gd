extends "res://scripts/shots/mock_ui2/kit.gd"
## v0.10.5 W3-O13b G2, round 2 (scripts/shots/mock_ui_refs.gd): the interactive parts of the four UI styles on top
## of the kit (kit.gd): plates (wide buttons), menu lines, the HP and heat bars, the slider, the toggle, the tooltip
## and the ability medallions. A prototype, not game code.


# --- Plates (wide buttons) ----------------------------------------------------------------------------------
## A plate's icon: "heal" (a cross), "reroll" (two turning arrows), "back" (a left chevron), else a dot.
func _plate_icon(icon: String, c: Vector2, sz: float, col: Color) -> void:
	match icon:
		"heal":
			_h(c.x - sz, c.x + sz + 1, c.y, col, 2.0)
			_v(c.x, c.y - sz, c.y + sz + 1, col, 2.0)
			_dia(c + Vector2(0.5, 1), 2.5, Color(0, 0, 0, 0), p["ink"])
		"reroll":
			_arc(c, sz, -PI * 0.95, -PI * 0.15, col, 1.6)
			_arc(c, sz, PI * 0.05, PI * 0.85, col, 1.6)
			var t1 := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * sz
			draw_colored_polygon(
				PackedVector2Array([t1 + Vector2(-5, -3), t1 + Vector2(4, -3), t1 + Vector2(1, 5)]),
				col
			)
			var t2 := c + Vector2(cos(PI * 0.85), sin(PI * 0.85)) * sz
			draw_colored_polygon(
				PackedVector2Array([t2 + Vector2(5, 3), t2 + Vector2(-4, 3), t2 + Vector2(-1, -5)]),
				col
			)
		"back":
			_ln(c + Vector2(sz * 0.4, -sz), c + Vector2(-sz * 0.5, 0), col, 1.6)
			_ln(c + Vector2(-sz * 0.5, 0), c + Vector2(sz * 0.4, sz), col, 1.6)
		_:
			_dia(c, sz * 0.5, col, col)


## A long slim plate: icon at the left, the label, the price at the right (price < 0: none). `state` is "normal",
## "focus", "primary" or "disabled".
func _plate(
	r: Rect2, icon: String, label: String, price := -1, state := "normal", ok := true
) -> void:
	var focus := state == "focus" or state == "primary"
	var off := state == "disabled"
	var line: Color = p["line_hi"] if focus else (p["faint"] if off else p["line"])
	var txt: Color = p["text"] if not off else Color(p["dim"], 0.55)
	var cy := r.get_center().y
	var icon_x := r.position.x + r.size.y * 0.62
	match style:
		"slate":
			draw_rect(r, p["fill_hi"] if focus else Color(p["fill"], 0.8 if off else 0.9))
			if state == "primary":
				draw_rect(r.grow(-1), Color(p["accent"], 0.22))
			_inset(r, 4, 0.25)
			_frame(r, line)
			if icon != "":
				_v(r.position.x + r.size.y, r.position.y + 8, r.end.y - 8, Color(line, 0.6))
			icon_x = r.position.x + r.size.y * 0.5
		"eclipse":
			var tip := r.size.y * 0.42
			var pts := _hexplate(_px(r), tip)
			_stone_fill(pts, p["fill_hi"] if focus else p["fill"])
			_bevel(pts, 2.5, Color(1, 1, 1, 0.12), Color(0, 0, 0, 0.6))
			if state == "primary":
				draw_colored_polygon(_contour(pts, -3.0), Color(p["metal"], 0.28))
			_poly(pts, line, 1.6 if focus else 1.0)
			if focus:
				_poly(_contour(pts, 4.0), Color(p["line_hi"], 0.28))
			icon_x = r.position.x + tip + 18
		"astral":
			var tip := r.size.y * 0.75
			var pts := _hexplate(_px(r), tip)
			draw_colored_polygon(pts, p["fill_hi"] if focus else Color(p["fill"], 0.8))
			if state == "primary":
				draw_colored_polygon(_contour(pts, -3.0), Color(p["accent"], 0.2))
			_poly(_contour(pts, -4.0), Color(line, 0.3))
			_poly(pts, line, 1.3 if focus else 1.0)
			for sx in [-1.0, 1.0]:
				var tipc := Vector2(r.get_center().x + sx * (r.size.x * 0.5 + 9), cy)
				_star4(tipc, 5.0, Color(line, 0.9 if focus else 0.5), 0.2)
			icon_x = r.position.x + tip + 4
		_:
			var tip := r.size.y * 0.5
			var o := _px(r)
			var pts := _hexplate(o, tip)
			draw_colored_polygon(pts, p["fill_hi"] if focus else Color(p["fill"], 0.85))
			if state == "primary":
				draw_colored_polygon(_contour(pts, -4.0), Color(p["accent"], 0.18))
			_poly(pts, line)
			_poly(_contour(pts, -4.0), Color(line, 0.45))
			for sx in [-1.0, 1.0]:
				_dia(
					Vector2(r.get_center().x + sx * (r.size.x * 0.5 + 8), cy),
					3.5,
					Color(line, 0.8),
					p["ink"]
				)
			icon_x = r.position.x + tip + 14
	var isz := roundf(r.size.y * 0.2)
	if icon != "":
		if style == "observatory" or style == "astral":
			draw_circle(Vector2(icon_x, cy), isz + 9, Color(p["ink"], 0.7))
			_arc(Vector2(icon_x, cy), isz + 9, 0, TAU, Color(line, 0.8))
		_plate_icon(icon, Vector2(roundf(icon_x), roundf(cy)), isz, txt if focus else p["metal"])
	var fs := int(clampf(r.size.y * 0.29, 12, 17))
	var lf := _serif(600, int(fs * 0.3))
	var lx := icon_x + isz + 20 if icon != "" else r.get_center().x
	var la := 0 if icon != "" else 1
	if price < 0 and icon != "":
		lx = (icon_x + isz + r.end.x) * 0.5
		la = 1
	var lw := r.size.x - (lx - r.position.x) - (90 if price >= 0 else 30)
	fs = _fit(lf, label.to_upper(), fs, lw, 10)
	_text(lf, label.to_upper(), lx, cy + fs * 0.36, fs, txt, la)
	if price >= 0:
		var pr := r.end.x - (r.size.y * 0.75 if style != "slate" else 22.0)
		var pfs := int(fs * 1.3)
		_price(price, pr - _price_w(price, pfs), cy + fs * 0.45, pfs, ok, 0)


# --- Menu ---------------------------------------------------------------------------------------------------
## A pause-menu line; the focused one is lit and marked.
func _menu_item(x: float, cy: float, w: float, label: String, focused: bool) -> void:
	var fs := 21
	var col: Color = p["text"] if focused else p["dim"]
	var tx := x + 44
	match style:
		"slate":
			if focused:
				draw_rect(Rect2(x, cy - 22, w, 44), Color(p["fill_hi"], 0.9))
				_rule1(x, cy - 22, w, Color(p["line_hi"], 0.25))
				_rule1(x, cy + 21, w, Color(p["line_hi"], 0.25))
				draw_rect(Rect2(x, cy - 22, 3, 44), p["accent"])
		"eclipse":
			if focused:
				for k in 2:
					var ox := x + 6 + k * 7
					_ln(
						Vector2(ox, cy - 11),
						Vector2(ox + 12, cy),
						Color(p["line_hi"], 1.0 - k * 0.5),
						1.6
					)
					_ln(
						Vector2(ox + 12, cy),
						Vector2(ox, cy + 11),
						Color(p["line_hi"], 1.0 - k * 0.5),
						1.6
					)
				_rule1(tx, cy + 17, w * 0.75, Color(p["line_hi"], 0.55))
		"astral":
			if focused:
				_star4(Vector2(x + 18, cy), 10.0, p["line_hi"], 0.16)
				var pts := _hexplate(Rect2(tx - 14, cy + 15, w * 0.62, 3), 60)
				draw_colored_polygon(pts, Color(p["line_hi"], 0.45))
			else:
				_dia(Vector2(x + 18, cy), 2.0, Color(p["line"], 0.8), Color(p["line"], 0.8))
		_:
			if focused:
				draw_rect(Rect2(x + 30, cy - 20, w - 30, 40), Color(p["fill_hi"], 0.75))
				_rule1(x + 30, cy - 20, w - 30, Color(p["line_hi"], 0.5))
				_rule1(x + 30, cy + 19, w - 30, Color(p["line_hi"], 0.5))
				_arc(Vector2(x + 14, cy), 10, 0, TAU, Color(p["line_hi"], 0.7))
				_dia(Vector2(x + 14, cy), 5.0, p["line_hi"], p["accent"])
			else:
				_star4(Vector2(x + 14, cy), 4.0, Color(p["metal"], 0.55), 0.25)
	_cap(label, tx, cy + fs * 0.36, fs, col, 6, 0, 600 if focused else 500)


# --- Bars ---------------------------------------------------------------------------------------------------
## The HP medallion at the bar's left end.
func _hp_medal(c: Vector2, r: float) -> void:
	match style:
		"slate":
			var pts := _dia_pts(c, r)
			draw_colored_polygon(pts, Color(p["ink"], 0.75))
			_poly(pts, p["metal"])
			_poly(_dia_pts(c, r - 5), Color(p["metal"], 0.3))
			_rune(HP_RUNE, c, r * 0.9, p["hp"], 1.6)
		"eclipse":
			var pts := _carve(Rect2(c - Vector2.ONE * r, Vector2.ONE * r * 2), 8.0, 3)
			_stone_fill(pts, p["fill"])
			_bevel(pts, 2.0, Color(1, 1, 1, 0.14), Color(0, 0, 0, 0.6))
			_poly(pts, p["metal"])
			_rune(HP_RUNE, c, r * 0.95, p["line_hi"], 1.8)
		"astral":
			draw_circle(c, r, Color(p["ink"], 0.7))
			_arc(c, r, 0, TAU, p["metal"])
			_arc(c, r + 5, -PI * 0.9, -PI * 0.1, Color(p["metal"], 0.5))
			_star4(c, r * 0.8, p["line_hi"], 0.14)
			_rune(HP_RUNE, c + Vector2(0, 1), r * 0.5, p["ink"], 1.4)
		_:
			draw_circle(c, r, Color(p["ink"], 0.75))
			_arc(c, r, 0, TAU, p["metal"])
			_arc(c, r - 5, 0, TAU, Color(p["metal"], 0.35))
			_ticks(c, r + 2, r + 5, 32, Color(p["metal"], 0.45))
			_compass(c, r * 0.82, p["line_hi"])


## The continuous HP bar: the medallion at `c`, the bar running `length` to the right, one unbroken fill.
func _hp_bar(
	c: Vector2, r: float, length: float, frac: float, label: String, value: String
) -> void:
	var x0 := roundf(c.x + r + 6)
	var x1 := roundf(c.x + r + 6 + length)
	var y := roundf(c.y)
	var fx := roundf(x0 + (x1 - x0) * clampf(frac, 0.0, 1.0))
	# the track: an ink bed with a hairline frame, a joint to the medallion and an end cap
	draw_rect(Rect2(x0, y - 4, x1 - x0, 9), Color(p["ink"], 0.65))
	_frame(Rect2(x0, y - 5, x1 - x0, 11), Color(p["metal"], 0.4))
	_h(c.x + r, x0, y, Color(p["metal"], 0.8))
	draw_rect(Rect2(x0 + 2, y - 3, fx - x0 - 2, 7), p["hp"])
	_h(x0 + 2, fx, y - 3, p["hp"].lightened(0.5))
	_h(x0 + 2, fx, y + 3, p["hp"].darkened(0.3))
	_v(fx, y - 8, y + 9, p["line_hi"])
	match style:
		"slate":
			_v(x1 + 4, y - 6, y + 7, Color(p["metal"], 0.7))
		"eclipse":
			_dia(Vector2(x1 + 8, y + 0.5), 4.0, p["metal"], p["ink"])
		"astral":
			_star4(Vector2(x1 + 10, y + 0.5), 7.0, Color(p["metal"], 0.9), 0.16)
		_:
			_dia(Vector2(x1 + 8, y + 0.5), 4.5, p["metal"], p["ink"])
			_h(x1 + 14, x1 + 22, y, Color(p["metal"], 0.6))
	_hp_medal(c, r)
	if label != "":
		_cap(label, x0 + 2, y - 16, 14, p["text"], 4, 0, 600, true)
	_text(_sans(true, 1), value, x1, y - 16, 16, p["text"], 2, true)


## A slim meter (heat): `length` long from (x0, y), 2 px fill on a hairline bed.
func _slim_bar(x0: float, y: float, length: float, frac: float, col: Color) -> void:
	draw_rect(Rect2(x0, y - 2, length, 5), Color(p["ink"], 0.55))
	_frame(Rect2(x0, y - 3, length, 7), Color(p["metal"], 0.3))
	draw_rect(Rect2(x0 + 2, y - 1, roundf(length * frac) - 2, 3), col)
	_v(x0 + roundf(length * frac), y - 5, y + 6, col.lightened(0.4))


# --- Controls -----------------------------------------------------------------------------------------------
## A slider: the track from x0 to x1 at y, filled to `v`, its knob, and the value at the right.
func _slider(x0: float, x1: float, y: float, v: float, focused := false) -> void:
	var kx := roundf(x0 + (x1 - x0) * v)
	_h(x0, x1, y, Color(p["metal"], 0.35))
	if style == "observatory":
		for k in 11:
			var tx := x0 + (x1 - x0) * k / 10.0
			_v(tx, y + 4, y + (9 if k % 5 == 0 else 7), Color(p["metal"], 0.3))
	_h(x0, kx, y - 1, p["accent"], 3.0)
	var kc := Vector2(kx + 0.5, y + 0.5)
	var lit: Color = p["line_hi"] if focused else p["metal"]
	match style:
		"slate":
			draw_rect(Rect2(kx - 3, y - 9, 7, 19), p["ink"])
			_frame(Rect2(kx - 3, y - 9, 7, 19), lit)
		"eclipse":
			_dia(kc, 8.0, lit, p["fill_hi"])
			_dia(kc, 3.0, Color(0, 0, 0, 0), lit)
		"astral":
			_dia(kc, 7.0, lit, p["ink"])
			draw_circle(kc, 2.0, lit)
		_:
			_dia(kc, 8.0, lit, p["ink"])
			_dia(kc, 3.5, Color(0, 0, 0, 0), p["accent"])
	_text(_sans(true, 1), "%d %%" % roundi(v * 100), x1 + 64, y + 5, 14, p["text"], 2)


## A toggle (on), its left edge at `x`, centred on y.
func _toggle(x: float, y: float, on := true) -> void:
	var r := Rect2(x, y - 10, 48, 20)
	var kx := r.end.x - 13 if on else r.position.x + 13
	match style:
		"slate":
			draw_rect(r, Color(p["accent"], 0.3) if on else Color(p["ink"], 0.7))
			_frame(r, p["line_hi"] if on else p["line"])
			draw_rect(Rect2(kx - 6, y - 6, 12, 12), p["line_hi"] if on else p["dim"])
		_:
			var pts := _hexplate(_px(r), 10.0)
			draw_colored_polygon(pts, Color(p["accent"], 0.28) if on else Color(p["ink"], 0.7))
			_poly(pts, p["line_hi"] if on else p["line"])
			_dia(Vector2(kx, y + 0.5), 7.0, p["ink"], p["line_hi"] if on else p["dim"])


## A tooltip: a small framed panel with a title, a line and a pointer notch at its bottom left.
func _tooltip(r: Rect2, title: String, line: String) -> void:
	match style:
		"slate":
			draw_rect(r, p["fill_hi"])
			_frame(r, p["line"])
		"eclipse":
			var pts := _carve(r, 9.0, 5)
			_stone_fill(pts, p["fill_hi"])
			_bevel(pts, 2.0, Color(1, 1, 1, 0.1), Color(0, 0, 0, 0.5))
			_poly(pts, p["metal"])
		"astral":
			var pts := _cut(_px(r), 8.0)
			draw_colored_polygon(pts, p["fill_hi"])
			_poly(pts, p["line"])
			_poly(_contour(pts, -4.0), Color(p["line"], 0.3))
		_:
			var pts := _cut(_px(r), 8.0)
			draw_colored_polygon(pts, p["fill_hi"])
			_poly(pts, p["line"])
			_poly(_cut(_px(r).grow(-4), 5.0), Color(p["line"], 0.45))
	var n := Vector2(roundf(r.position.x + 30) + 0.5, roundf(r.end.y) - 0.5)
	draw_colored_polygon(
		PackedVector2Array([n + Vector2(-8, 0), n + Vector2(8, 0), n + Vector2(0, 9)]),
		Color(p["fill_hi"], 1.0)
	)
	_ln(n + Vector2(-8, 0), n + Vector2(0, 9), p["line"])
	_ln(n + Vector2(0, 9), n + Vector2(8, 0), p["line"])
	_cap(title, r.position.x + 18, r.position.y + 30, 15, p["text"], 4)
	_body(line, r.position.x + 18, r.position.y + 58, 15, p["dim"])


## An ability medallion with its key below; `cool` (0..1) is the cooldown left (0: ready).
func _ability(c: Vector2, r: float, icon: StringName, key: String, cool: float) -> void:
	var ready := cool <= 0.0
	var icol: Color = p["text"] if ready else Color(p["metal"], 0.22)
	match style:
		"slate":
			var b := Rect2(c - Vector2.ONE * r, Vector2.ONE * r * 2)
			draw_rect(b, Color(p["fill"], 0.9))
			_inset(b, 5, 0.35)
			_frame(b, p["line"] if not ready else Color(p["line_hi"], 0.6))
			if not ready:
				draw_rect(
					Rect2(b.position + Vector2(1, 1), Vector2(b.size.x - 2, (b.size.y - 2) * cool)),
					Color(p["ink"], 0.55)
				)
				_h(
					b.position.x + 1,
					b.end.x - 1,
					b.position.y + 1 + (b.size.y - 2) * cool,
					p["accent"]
				)
		"eclipse":
			draw_circle(c, r, Color(p["ink"], 0.5))
			_ln(c + Vector2(-r * 0.55, r + 6), c + Vector2(0, r + 13), Color(p["metal"], 0.7), 1.4)
			_ln(c + Vector2(0, r + 13), c + Vector2(r * 0.55, r + 6), Color(p["metal"], 0.7), 1.4)
			_arc(c, r, 0, TAU, Color(p["metal"], 0.25))
		"astral":
			draw_circle(c, r, Color(p["ink"], 0.6))
			_arc(c, r, 0, TAU, p["metal"] if ready else Color(p["metal"], 0.5))
			_arc(c, r - 4, 0, TAU, Color(p["metal"], 0.18))
		_:
			draw_circle(c, r, Color(p["ink"], 0.65))
			_arc(c, r, 0, TAU, p["metal"] if ready else Color(p["metal"], 0.55))
			_arc(c, r - 5, 0, TAU, Color(p["metal"], 0.3))
			_ticks(c, r + 1, r + 4, 40, Color(p["metal"], 0.3))
	if not ready and style != "slate":
		var a0 := -PI * 0.5
		_arc(c, r + 6, a0 + TAU * (1.0 - cool), a0 + TAU, p["accent"], 2.0)
		_arc(c, r + 6, a0, a0 + TAU * (1.0 - cool), Color(p["metal"], 0.15), 1.0)
		var e := a0 + TAU * (1.0 - cool)
		_dia(c + Vector2(cos(e), sin(e)) * (r + 6), 3.0, p["line_hi"], p["line_hi"])
	var ir := r * 0.52
	AbilitySquareIcons.draw(self, icon, Rect2(c - Vector2.ONE * ir, Vector2.ONE * ir * 2), icol)
	if not ready:
		_text(_serif(700, 0), "2.4", c.x, c.y + 8, 22, p["text"], 1, true)
	_key(key, c + Vector2(0, r + (30 if style == "eclipse" else 22)))
