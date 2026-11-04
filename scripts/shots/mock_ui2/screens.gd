extends "res://scripts/shots/mock_ui2/parts.gd"
## v0.10.5 W3-O13b G2, round 2 (scripts/shots/mock_ui_refs.gd): the screens of the four UI styles, laid out on an
## 8 px grid with the kit (kit.gd): the shop (layout A), the in-run HUD, the pause menu with its options panel, the
## altar's pick of three, and the component strip. A prototype, not game code.

## Shot setup (as round 1): the heat and danger shown on the HUD.
const HEAT := 0.46
const DANGER := 0.62


func _draw() -> void:
	glass.clear()
	match kind:
		"shop":
			_shop()
		"pause":
			_pause()
		"pick":
			_pick()
		"comp":
			_comp()
		_:
			_hud()


# --- Shop (layout A) ----------------------------------------------------------------------------------------
func _shop() -> void:
	var r := Rect2(232, 136, 1456, 808)
	_panel(r)
	var cx := r.get_center().x
	var hy := r.position.y + 68.0
	_heading(String(d["shop_title"]), r.position.x + 56, hy, 34)
	# The wallet at the right, the buys left before it.
	var wfs := 30
	var wx := r.end.x - 56 - _price_w(int(d["wallet"]), wfs)
	_price(int(d["wallet"]), wx, hy, wfs, true, 0)
	_v(wx - 32, hy - 30, hy + 6, Color(p["line"], 0.8))
	var px := wx - 64.0
	for k in range(int(d["max_buys"]) - 1, -1, -1):
		var on := k < int(d["buys_left"])
		_dia(Vector2(px, hy - 11), 5.0, p["metal"], p["accent"] if on else p["ink"])
		px -= 20
	_body(String(d["buys_text"]), px - 6, hy - 4, 16, p["dim"], 2)
	_sep(cx, r.position.y + 104, r.size.x * 0.5 - 48, Color(p["metal"], 0.55))
	# Four cards, the first focused.
	var cw := 300.0
	var gap := 32.0
	var x0 := cx - (cw * 4 + gap * 3) * 0.5
	var faces: Array = d["faces"]
	for k in faces.size():
		var cr := Rect2(x0 + k * (cw + gap), r.position.y + 152, cw, 420)
		if (faces[k] as Dictionary).is_empty():
			continue
		_card(cr, faces[k], k == 0, int(d["prices"][k]), bool(d["ok"][k]))
	# Heal and Reroll plates.
	var pw := 520.0
	var py := r.position.y + 624
	var pl := cx - pw - 24
	_plate(Rect2(pl, py, pw, 60), "heal", String(d["heal_text"]), int(d["heal_price"]))
	_plate(Rect2(cx + 24, py, pw, 60), "reroll", String(d["reroll_text"]), int(d["reroll_price"]))
	# The hint line.
	var hint := String(d["shop_hint"])
	var hw := _body(hint, cx, r.end.y - 48, 15, p["dim"], 1)
	_rule1(cx - hw * 0.5 - 20, r.end.y - 53, -120, Color(p["metal"], 0.5))
	_rule1(cx + hw * 0.5 + 20, r.end.y - 53, 120, Color(p["metal"], 0.5))


# --- Altar pick ---------------------------------------------------------------------------------------------
func _pick() -> void:
	var parts := String(d["pick_title"]).split(" · ")
	var title := parts[0]
	var sub := parts[1] if parts.size() > 1 else ""
	var cx := 960.0
	if style == "observatory":
		_altar_rings(Vector2(cx, 800))
	_heading(title, cx, 196, 40, sub, 1)
	_sep(cx, 236, 380, Color(p["metal"], 0.6))
	var cw := 340.0
	var gap := 48.0
	var x0 := cx - (cw * 3 + gap * 2) * 0.5
	var faces: Array = d["faces"]
	for k in 3:
		_card(Rect2(x0 + k * (cw + gap), 312, cw, 440), faces[k], k == 0)
	var hint := String(d["pick_hint"])
	var hw := _body(hint, cx, 912, 16, p["text"], 1, false, true)
	_rule1(cx - hw * 0.5 - 24, 907, -160, Color(p["metal"], 0.6))
	_rule1(cx + hw * 0.5 + 24, 907, 160, Color(p["metal"], 0.6))


## The observatory's engraved floor ring under the altar's cards.
func _altar_rings(c: Vector2) -> void:
	var col := Color(p["metal"], 0.22)
	for k in 3:
		var rx := 420.0 + k * 70.0
		var pts := PackedVector2Array()
		for j in 97:
			var a := TAU * j / 96.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * rx * 0.16))
		draw_polyline(pts, col if k != 1 else Color(col, 0.12), 1.0, true)
	for j in 72:
		var a := TAU * j / 72.0
		var u := Vector2(cos(a), sin(a) * 0.16)
		_ln(c + u * 490.0, c + u * (500.0 if j % 6 else 520.0), col)


# --- Pause and options --------------------------------------------------------------------------------------
func _pause() -> void:
	var lx := 200.0
	_scrim(Rect2(0, 0, 760, 1080), 0.6, 0.0, true)
	if style == "astral":
		_arc(Vector2(lx + 150, 300), 120.0, PI * 1.08, PI * 1.62, Color(p["metal"], 0.45))
		_star4(
			Vector2(lx + 150, 300) + Vector2(cos(PI * 1.62), sin(PI * 1.62)) * 120.0,
			5.0,
			p["metal"]
		)
	_heading(String(d["paused"]), lx, 296, 44)
	_rule1(lx, 328, 420, Color(p["metal"], 0.6))
	var items: Array = d["pause_items"]
	for k in items.size():
		_menu_item(lx, 392 + k * 56, 400, String(items[k]), k == 0)
	_rule1(lx, 740, 420, Color(p["metal"], 0.35))
	_body(String(d["run_line"]), lx, 772, 15, p["dim"], 0, false, true)
	# The options panel.
	var r := Rect2(760, 216, 880, 616)
	_panel(r, style == "observatory")
	var x0 := r.position.x + 56
	var x1 := r.end.x - 120
	_heading(String(d["options"]), x0, r.position.y + 64, 26)
	var tabs: Array = d["tabs"]
	var tw := (x1 + 64 - x0) / tabs.size()
	var ty := r.position.y + 124
	for k in tabs.size():
		var tcx := x0 + tw * (k + 0.5)
		_cap(
			String(tabs[k]),
			tcx,
			ty,
			15,
			p["text"] if k == 0 else p["dim"],
			5,
			1,
			600 if k == 0 else 500
		)
		if k == 0:
			_h(tcx - 52, tcx + 52, ty + 14, p["accent"], 2.0)
			_dia(Vector2(tcx + 0.5, ty + 15), 3.5, p["line_hi"], p["ink"])
	_h(x0, x1 + 64, ty + 15, Color(p["line"], 0.9))
	var rows: Array = d["opt_rows"]
	var y := ty + 72
	for k in rows.size():
		var row: Array = rows[k]
		_cap(String(row[0]), x0, y, 13, p["dim"], 3, 0, 600)
		_slider(x0, x1, y + 24, float(row[1]), k == 0)
		y += 76
	_cap(String(d["shake"]), x0, y + 6, 13, p["dim"], 3, 0, 600)
	_toggle(x1 - 48, y + 1)
	_text(_sans(true, 1), String(d["on"]), x1 + 64, y + 6, 14, p["text"], 2)
	_plate(Rect2(r.get_center().x - 140, r.end.y - 84, 280, 48), "back", String(d["back"]))


# --- HUD ----------------------------------------------------------------------------------------------------
func _hud() -> void:
	var cx := 960.0
	_scrim(Rect2(0, 0, 1920, 120), 0.5, 0.0)
	_scrim(Rect2(0, 900, 1920, 180), 0.0, 0.55)
	# Top centre: the floor line between ornaments, the timer, the danger line, the kills.
	var floor_s := String(d["floor_text"]).to_upper()
	var ff := _serif(600, 5)
	var fw := _width(ff, floor_s, 15)
	_text(ff, floor_s, cx, 36, 15, p["text"], 1, true)
	for sx in [-1.0, 1.0]:
		var ox: float = cx + sx * (fw * 0.5 + 22)
		_star4(Vector2(ox, 31), 6.0, p["metal"], 0.2)
		_rule1(ox + sx * 12, 31, sx * 56, Color(p["metal"], 0.6))
	var ly := 66.0
	_text(_serif(600, 2), String(d["time_text"]), cx - 132, ly + 8, 22, p["text"], 2, true)
	var dx0 := cx - 104
	var dx1 := cx + 104
	_h(dx0, dx1, ly, Color(p["metal"], 0.4))
	_h(dx0, dx0 + (dx1 - dx0) * DANGER, ly - 1, Color(p["metal"], 0.9), 2.0)
	_dia(Vector2(roundf(dx0 + (dx1 - dx0) * DANGER) + 0.5, ly + 0.5), 4.5, p["line_hi"], p["ink"])
	_v(dx0, ly - 4, ly + 5, Color(p["metal"], 0.6))
	_v(dx1, ly - 4, ly + 5, Color(p["metal"], 0.6))
	_text(_serif(700, 1), String(d["danger_text"]), dx1 + 16, ly + 7, 18, p["text"], 0, true)
	_cap(String(d["calm_text"]), cx, ly + 26, 11, p["dim"], 4, 1, 600, true)
	_cap(String(d["kills_text"]), cx + 260, ly + 6, 13, p["dim"], 3, 0, 600, true)
	# Top right: the wallet over the minimap frame.
	var wfs := 26
	_price(int(d["wallet"]), 1884 - _price_w(int(d["wallet"]), wfs), 48, wfs, true, 0)
	_minimap(Rect2(1636, 72, 248, 184))
	# Bottom left: the weapon and the continuous HP bar with its medallion; the heat bar after it.
	var hp := float(d["hp"]) / maxf(1.0, float(d["max_hp"]))
	_hp_bar(Vector2(88, 996), 34, 420, hp, String(d["weapon_text"]), String(d["hp_text"]))
	var hx := 640.0
	_cap(String(d["heat_text"]), hx, 986, 12, p["text"], 5, 0, 600, true)
	_cap(String(d["vent_text"]), hx + 240, 986, 11, p["dim"], 3, 2, 600, true)
	_slim_bar(hx, 1000, 240, HEAT, p["heat"])
	# Bottom right: the three ability medallions, the middle one cooling.
	var slots: Array = d["slots"]
	for k in slots.size():
		var sl: Array = slots[k]
		_ability(
			Vector2(1652 + k * 96, 976),
			32,
			StringName(sl[0]),
			String(sl[1]),
			0.6 if k == 1 else 0.0
		)


## The minimap's thin frame with a sketch of rooms (the real map would draw inside it).
func _minimap(r: Rect2) -> void:
	match style:
		"slate":
			draw_rect(r, Color(p["fill"], 0.85))
			_frame(r, p["line"])
		"eclipse":
			var pts := _carve(r, 12.0, 11)
			draw_colored_polygon(pts, Color(p["ink"], 0.72))
			_poly(pts, Color(p["metal"], 0.6))
			_bevel(pts, 2.0, Color(1, 1, 1, 0.08), Color(0, 0, 0, 0.4))
		"astral":
			draw_colored_polygon(
				_dia_pts(r.get_center(), r.size.x * 0.5, r.size.y * 0.5), Color(p["ink"], 0.7)
			)
			_poly(_dia_pts(r.get_center(), r.size.x * 0.5, r.size.y * 0.5), Color(p["metal"], 0.55))
			_star4(Vector2(r.get_center().x, r.end.y + 10), 7.0, Color(p["metal"], 0.7), 0.18)
		_:
			var o := _px(r)
			draw_colored_polygon(_cut(o, 8.0), Color(p["ink"], 0.72))
			_poly(_cut(o, 8.0), Color(p["metal"], 0.55))
			_poly(_cut(o.grow(-4), 5.0), Color(p["metal"], 0.2))
			_compass(Vector2(o.end.x - 18, o.position.y + 18), 9.0, Color(p["metal"], 0.7))
	var c := r.get_center() + Vector2(0, 4)
	var rooms := [
		Vector2(0, 0), Vector2(1, 0), Vector2(1, -1), Vector2(0, 1), Vector2(-1, 1), Vector2(2, -1)
	]
	var u := 24.0
	var iso := func(q: Vector2) -> Vector2:
		return (c + Vector2((q.x - q.y) * u * 1.2, (q.x + q.y) * u * 0.6)).round()
	var lc: Color = p["metal"]
	for k in rooms.size() - 1:
		_ln(iso.call(rooms[k]), iso.call(rooms[k + 1]), Color(lc, 0.4))
	for k in rooms.size():
		var q: Vector2 = iso.call(rooms[k])
		var dm := _dia_pts(q, u * 0.72, u * 0.36)
		draw_colored_polygon(dm, Color(p["accent"], 0.35) if k == 0 else Color(lc, 0.1))
		_poly(dm, Color(p["line_hi"], 0.9) if k == 0 else Color(lc, 0.45))
	draw_circle(iso.call(rooms[0]), 2.5, p["line_hi"])


# --- Component strip ----------------------------------------------------------------------------------------
## The style's parts in one band (200 px, cropped by the driver), left to right: the HP bar, the buttons (primary,
## secondary, focus, disabled), the ability medallions (ready, cooling, ready), a tooltip, a slider, a toggle, and
## a card's top-left corner at 2.2×.
func _comp() -> void:
	draw_rect(Rect2(0, 0, 1920, 200), Color(p["ink"], 0.96))
	_h(0, 1920, 0, Color(p["metal"], 0.4))
	_h(0, 1920, 199, Color(p["metal"], 0.4))
	var cy := 104.0
	var div := func(x: float) -> void: _v(x, 36, 172, Color(p["line"], 0.7))
	_hp_bar(Vector2(56, cy + 8), 24, 236, 0.5, String(d["weapon_text"]), String(d["hp_text"]))
	div.call(376)
	var labels: Array = d["comp_buttons"]
	var states := ["primary", "normal", "focus", "disabled"]
	for k in 4:
		_plate(Rect2(400 + k * 136, cy - 20, 124, 40), "", String(labels[k]), -1, states[k])
	div.call(952)
	var slots: Array = d["slots"]
	for k in 3:
		var sl: Array = slots[k]
		_ability(
			Vector2(1000 + k * 76, cy - 10),
			24,
			StringName(sl[0]),
			String(sl[1]),
			0.6 if k == 1 else 0.0
		)
	div.call(1176)
	_tooltip(Rect2(1200, cy - 46, 236, 80), String(d["heal_text"]), String(d["heal_full"]))
	div.call(1460)
	_slider(1480, 1600, cy, 0.8, true)
	div.call(1688)
	_toggle(1708, cy)
	div.call(1776)
	draw_set_transform(Vector2(1800, 40), 0.0, Vector2(2.2, 2.2))
	_card_frame(Rect2(0, 0, 300, 440), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
