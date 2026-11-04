extends "res://scripts/shots/mock_ui/ui_paint.gd"
## v0.10.5 W3-O13 G2 mockups (scripts/shots/mock_ui_styles.gd): one screen of one style (the shop in layout A's
## shape, the card pick, the pause menu, the HUD), drawn whole in _draw with ui_paint.gd's kit.


func _draw() -> void:
	glass.clear()
	match kind:
		"hud":
			_hud()
		"shop":
			_shop()
		"pause":
			_pause()
		"pick":
			_pick()


# --- The shop (layout A's shape) ----------------------------------------------------------------------------
func _shop() -> void:
	var frame := Rect2(Vector2(280, 200), Vector2(1360, 680))
	_panel(frame)
	var x0 := frame.position.x + 40
	var y0 := frame.position.y + 26
	var title := String(d["shop_title"]).to_upper()
	var hc: Color = (
		p["text"] if style == "veil" else (p["line"] if style == "obsidian" else p["line"])
	)
	var hfs := 34 if style != "obsidian" else 38
	_t(title, Vector2(x0, y0), hfs, hc, true, HORIZONTAL_ALIGNMENT_LEFT, -1, _track(true))
	if style == "sigil":
		_runes(
			title,
			Vector2(x0 + _tw(title, hfs, true, _track(true)) + 18, y0 + 10),
			22,
			Color(p["line"], 0.55)
		)
	elif style == "veil":
		draw_line(Vector2(x0, y0 + 46), Vector2(x0 + 60, y0 + 46), p["line2"], 2.0)
	var wal := Rect2(Vector2(frame.end.x - 40 - 180, y0 - 4), Vector2(180, 52))
	_wallet(wal, 30)
	_pips(Vector2(wal.position.x - 28, wal.get_center().y), 18)
	var ly := y0 + 66
	match style:
		"obsidian":
			draw_line(Vector2(x0, ly), Vector2(frame.end.x - 40, ly), Color(p["line"], 0.6), 1.5)
			var dm := _diamond(Vector2(frame.get_center().x, ly), 6)
			draw_colored_polygon(dm, p["line"])
		"veil":
			draw_polygon(
				PackedVector2Array(
					[
						Vector2(x0, ly),
						Vector2(frame.end.x - 40, ly),
						Vector2(frame.end.x - 40, ly + 1.5),
						Vector2(x0, ly + 1.5)
					]
				),
				PackedColorArray(
					[
						Color(p["line"], 0.0),
						Color(p["line2"], 0.0),
						Color(p["line2"], 0.6),
						Color(p["line"], 0.6)
					]
				)
			)
	var faces: Array = d["faces"]
	var cw := 250.0
	var ch := 350.0
	var gap := 36.0
	var total := cw * 4 + gap * 3
	var cx := frame.get_center().x - total * 0.5
	var cy := ly + 30
	for k in faces.size():
		var r := Rect2(Vector2(cx + k * (cw + gap), cy), Vector2(cw, ch))
		_card(r, faces[k], k == 0)
		var tc := Vector2(r.get_center().x, r.end.y + 34)
		_tag(tc, int(d["prices"][k]), bool(d["ok"][k]))
		_t(str(k + 1), Vector2(r.position.x + 6, r.end.y + 22), 16, Color(p["dim"], 0.8), true)
	var by := cy + ch + 82
	var bw := 600.0
	var bh := 76.0
	var bx := frame.get_center().x - bw - 20
	_button(
		Rect2(bx, by, bw, bh),
		"X",
		Color("#6FA8FF"),
		d["heal_text"],
		int(d["heal_price"]),
		p["good"],
		false
	)
	_button(
		Rect2(bx + bw + 40, by, bw, bh),
		"Y",
		Color("#FFD35A"),
		d["reroll_text"],
		int(d["reroll_price"]),
		ShardIcon.MID,
		false
	)
	_t(
		d["shop_hint"],
		Vector2(frame.position.x, frame.end.y - 40),
		17,
		p["dim"],
		false,
		HORIZONTAL_ALIGNMENT_CENTER,
		frame.size.x
	)


# --- The card pick ------------------------------------------------------------------------------------------
func _pick() -> void:
	var title: String = d["pick_title"]
	var tfs := 40
	var tc: Color = p["line"] if style != "veil" else p["text"]
	_t(
		title.to_upper(),
		Vector2(0, 170),
		tfs,
		tc,
		true,
		HORIZONTAL_ALIGNMENT_CENTER,
		VIEW.x,
		_track(true)
	)
	match style:
		"veil":
			var w := 220.0
			draw_line(
				Vector2(960 - w, 232), Vector2(960 + w, 232), Color(p["line2"], 0.7), 2.0, true
			)
		"obsidian":
			var w := _tw(title.to_upper(), tfs, true, 1) * 0.5 + 30
			for k in [-1.0, 1.0]:
				var a := Vector2(960 + k * w, 196)
				draw_line(a, a + Vector2(k * 160, 0), p["line"], 2.0)
				draw_colored_polygon(_diamond(a + Vector2(k * 170, 0), 7), p["line"])
		_:
			_runes(
				title,
				Vector2(960 - _runes(title, Vector2(-10000, 0), 20, Color.WHITE) * 0.5, 230),
				20,
				Color(p["line"], 0.5)
			)
	var faces: Array = d["faces"]
	var cw := 330.0
	var ch := 470.0
	var gap := 70.0
	var x0 := 960 - (cw * 3 + gap * 2) * 0.5
	for k in 3:
		_card(Rect2(Vector2(x0 + k * (cw + gap), 300), Vector2(cw, ch)), faces[k], k == 0)
		_pad(str(k + 1), Vector2(x0 + k * (cw + gap) + cw * 0.5, 300 + ch + 46), 15, p["dim"])
	_t(d["pick_hint"], Vector2(0, 880), 18, p["dim"], false, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x)


# --- The pause menu -----------------------------------------------------------------------------------------
func _pause() -> void:
	var items: Array = d["pause_items"]
	var w := 560.0
	var bh := 58.0
	var gap := 14.0
	var h := 190 + items.size() * (bh + gap) + 60
	var r := Rect2(Vector2(960 - w * 0.5, 540 - h * 0.5), Vector2(w, h))
	if style == "sigil":
		# A halo over the title: a rune ring round the hourglass rune (dagaz).
		var hc := Vector2(960, r.position.y - 40)
		_ring(hc, 44, Color(p["line"], 0.5), 1.2)
		_rune_ring(hc, 58, d["paused"], 14, Color(p["line"], 0.6))
		_ring(hc, 72, Color(p["line"], 0.25), 1.0, 0.5)
		_rune(22, hc - Vector2(10, 20), 40, p["focus"], 2.2)
	else:
		_panel(r)
	var title: String = String(d["paused"])
	_t(
		title,
		Vector2(r.position.x, r.position.y + 44),
		44,
		p["line"] if style != "veil" else p["text"],
		true,
		HORIZONTAL_ALIGNMENT_CENTER,
		w,
		_track(true) + 4
	)
	_t(
		d["run_line"],
		Vector2(r.position.x, r.position.y + 112),
		17,
		p["dim"],
		false,
		HORIZONTAL_ALIGNMENT_CENTER,
		w
	)
	var y := r.position.y + 170
	if style == "sigil":  # the spine the menu items hang on
		var sx := 960.0 - 130.0
		_glow(
			PackedVector2Array([Vector2(sx, y - 10), Vector2(sx, y + items.size() * (bh + gap))]),
			Color(p["line"], 0.5),
			1.2,
			0.6
		)
	for k in items.size():
		var br := Rect2(Vector2(r.position.x + 50, y), Vector2(w - 100, bh))
		if style == "sigil":  # a narrower column, centred on its spine
			br = Rect2(Vector2(960 - 150, y), Vector2(380, bh))
		_menu_button(br, String(items[k]), k == 0)
		y += bh + gap
	_t(
		d["pause_hint"],
		Vector2(r.position.x, r.end.y - 50),
		16,
		p["dim"],
		false,
		HORIZONTAL_ALIGNMENT_CENTER,
		w
	)


func _menu_button(r: Rect2, s: String, focused: bool) -> void:
	var tc: Color = p["text"]
	var fs := 24
	match style:
		"veil":
			var pts := _rrect(r, r.size.y * 0.5, 8)
			if focused:
				draw_colored_polygon(pts, Color(p["focus"], 0.22))
				_glow(_closed(pts), p["focus"], 2.5, 1.8)
				draw_circle(Vector2(r.position.x + 28, r.get_center().y), 5, p["focus"])
			else:
				draw_colored_polygon(pts, Color(1, 1, 1, 0.05))
				draw_polyline(_closed(pts), Color(p["line"], 0.35), 1.2, true)
			_t(
				s.to_upper(),
				Vector2(r.position.x, r.get_center().y - 14),
				22,
				tc if focused else Color(tc, 0.85),
				true,
				HORIZONTAL_ALIGNMENT_CENTER,
				r.size.x,
				3
			)
			return
		"obsidian":
			var pts := _cham(r, 12)
			if focused:
				_poly_grad(pts, p["line2"], p["line"])
				tc = Color("#120E08")
				for k in [-1.0, 1.0]:
					var c := Vector2(r.get_center().x + k * (r.size.x * 0.5 + 22), r.get_center().y)
					draw_colored_polygon(
						PackedVector2Array(
							[
								c + Vector2(k * 10, 0),
								c + Vector2(-k * 4, -10),
								c + Vector2(-k * 4, 10)
							]
						),
						p["line2"]
					)
			else:
				_poly_grad(pts, Color("#211D28"), Color("#0F0D13"))
			draw_polyline(_closed(pts), p["line"], 2.0, true)
			_t(
				s.to_upper(),
				Vector2(r.position.x, r.get_center().y - 15),
				fs,
				tc,
				true,
				HORIZONTAL_ALIGNMENT_CENTER,
				r.size.x,
				1
			)
			return
	var node := Vector2(r.position.x + 20, r.get_center().y)
	if focused:
		_ring(node, 14, p["focus"], 2.0, 2.0)
		draw_circle(node, 6, p["focus"])
		draw_polygon(
			PackedVector2Array(
				[
					Vector2(node.x + 24, r.position.y + 4),
					Vector2(r.end.x, r.position.y + 4),
					Vector2(r.end.x, r.end.y - 4),
					Vector2(node.x + 24, r.end.y - 4)
				]
			),
			PackedColorArray(
				[
					Color(p["line"], 0.22),
					Color(p["line"], 0.0),
					Color(p["line"], 0.0),
					Color(p["line"], 0.22)
				]
			)
		)
		_glow(
			PackedVector2Array(
				[Vector2(node.x + 24, r.end.y - 4), Vector2(r.end.x - 60, r.end.y - 4)]
			),
			p["line"],
			1.4,
			1.2
		)
	else:
		draw_colored_polygon(_diamond(node, 6), Color(p["line"], 0.6))
	_t(
		s,
		Vector2(node.x + 44, r.get_center().y - 15),
		26 if focused else 24,
		p["focus"] if focused else Color(p["text"], 0.75),
		focused
	)


# --- The HUD ------------------------------------------------------------------------------------------------
func _hud() -> void:
	if style == "sigil":
		_hud_sigil()
		return
	var hp := int(d["hp"])
	var mx := int(d["max_hp"])
	# Top centre: floor, time, kills; the danger bar under it.
	var top := Rect2(Vector2(680, 16), Vector2(560, 92))
	_panel(top, true)
	_t(
		d["floor_text"],
		Vector2(top.position.x, top.position.y + 10),
		18,
		p["dim"],
		false,
		HORIZONTAL_ALIGNMENT_CENTER,
		top.size.x,
		1
	)
	_t(d["time_text"], Vector2(top.position.x + 26, top.position.y + 34), 26, p["text"], true)
	var kt: String = d["kills_text"]
	_t(kt, Vector2(top.end.x - 26 - _tw(kt, 18), top.position.y + 40), 18, p["dim"])
	var db := Rect2(Vector2(top.position.x + 130, top.position.y + 44), Vector2(260, 14))
	_bar(db, 0.62, Color("#FFB04A"), 4)
	_t(d["danger_text"], Vector2(db.end.x + 10, db.position.y - 6), 18, Color("#FFB04A"), true)
	_t(
		d["calm_text"],
		Vector2(db.position.x, db.end.y + 6),
		14,
		p["dim"],
		false,
		HORIZONTAL_ALIGNMENT_CENTER,
		db.size.x
	)
	# Top right: the wallet and the minimap frame.
	_wallet(Rect2(Vector2(1700, 18), Vector2(196, 54)), 30)
	_minimap(Rect2(Vector2(1590, 88), Vector2(306, 232)))
	# Bottom left: the weapon and the HP.
	var hpr := Rect2(Vector2(28, 962), Vector2(440, 90))
	_panel(hpr, true)
	_t(
		d["weapon_text"],
		Vector2(hpr.position.x + 22, hpr.position.y + 12),
		16,
		p["dim"],
		true,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		2
	)
	var ht: String = d["hp_text"]
	_t(ht, Vector2(hpr.end.x - 22 - _tw(ht, 20, true), hpr.position.y + 8), 20, p["text"], true)
	_bar(
		Rect2(hpr.position + Vector2(22, 46), Vector2(hpr.size.x - 44, 24)),
		float(hp) / maxf(1, mx),
		p["hp"],
		10
	)
	# Bottom centre: the heat.
	var hr := Rect2(Vector2(740, 990), Vector2(440, 62))
	_panel(hr, true)
	_t(
		d["heat_text"],
		Vector2(hr.position.x + 20, hr.position.y + 8),
		15,
		p["heat"],
		true,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		3
	)
	var vt: String = d["vent_text"]
	_t(vt, Vector2(hr.end.x - 20 - _tw(vt, 14, true), hr.position.y + 9), 14, p["dim"], true)
	_bar(Rect2(hr.position + Vector2(20, 34), Vector2(hr.size.x - 40, 14)), 0.46, p["heat"], 8)
	# Bottom right: the three slots.
	var slots: Array = d["slots"]
	for k in slots.size():
		var sr := Rect2(Vector2(1620 + k * 98, 968), Vector2(84, 84))
		_slot(sr, slots[k], k == 1)


## A meter: track, fill, ticks (veil: a thin light line; obsidian: segmented blocks).
func _bar(r: Rect2, f: float, col: Color, segs: int) -> void:
	match style:
		"veil":
			var pts := _rrect(r, r.size.y * 0.5, 6)
			draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
			var fr := Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * f), r.size.y))
			var fp := _rrect(fr, r.size.y * 0.5, 6)
			draw_colored_polygon(fp, col)
			_vgrad(
				Rect2(
					fr.position + Vector2(r.size.y * 0.5, 2),
					Vector2(fr.size.x - r.size.y, fr.size.y * 0.35)
				),
				Color(1, 1, 1, 0.45),
				Color(1, 1, 1, 0.0)
			)
			_glow(_closed(fp), col, 1.0, 0.8)
			draw_polyline(_closed(pts), Color(p["line"], 0.4), 1.0, true)
		_:
			var gap := 3.0
			var sw := (r.size.x - gap * (segs - 1)) / segs
			for k in segs:
				var sr := Rect2(
					Vector2(r.position.x + k * (sw + gap), r.position.y), Vector2(sw, r.size.y)
				)
				var share := clampf(f * segs - k, 0.0, 1.0)
				draw_rect(sr, Color(0, 0, 0, 0.7))
				if share > 0.0:
					var fr := Rect2(sr.position, Vector2(sr.size.x * share, sr.size.y))
					_vgrad(fr, col.lightened(0.25), col.darkened(0.25))
				draw_rect(sr, Color(p["deep"], 0.9), false, 1.0)
			draw_rect(r.grow(2), p["line"], false, 1.5)


func _slot(r: Rect2, s: Array, cooling: bool) -> void:
	var icon: StringName = s[0]
	var key: String = s[1]
	match style:
		"veil":
			glass.append([r, 14.0])
			var pts := _rrect(r, 14)
			draw_colored_polygon(pts, p["fill"])
			_glow(
				_closed(pts),
				Color(p["line"], 0.35 if cooling else 0.85),
				1.5,
				0.4 if cooling else 1.0
			)
			AbilitySquareIcons.draw(
				self, icon, r.grow(-22), Color(p["text"], 0.5 if cooling else 1.0)
			)
			if cooling:
				draw_arc(
					r.get_center(), 30, -PI * 0.5, -PI * 0.5 + TAU * 0.6, 40, p["line2"], 3.0, true
				)
				_t(
					"2.4",
					Vector2(r.position.x, r.get_center().y - 13),
					20,
					p["text"],
					true,
					HORIZONTAL_ALIGNMENT_CENTER,
					r.size.x
				)
			var kw := _tw(key, 13, true) + 16
			var kr := Rect2(Vector2(r.get_center().x - kw * 0.5, r.end.y - 10), Vector2(kw, 22))
			draw_colored_polygon(_rrect(kr, 11, 4), Color("#0A1322"))
			draw_polyline(_closed(_rrect(kr, 11, 4)), Color(p["line"], 0.6), 1.0, true)
			_t(
				key,
				kr.position + Vector2(0, 2),
				13,
				p["text"],
				true,
				HORIZONTAL_ALIGNMENT_CENTER,
				kw
			)
		_:
			var c := r.get_center()
			var dm := _diamond(c, r.size.x * 0.58)
			draw_colored_polygon(dm, p["fill"])
			draw_polyline(
				_closed(dm), p["line"] if not cooling else Color(p["line"], 0.45), 2.5, true
			)
			draw_polyline(_closed(_diamond(c, r.size.x * 0.5)), Color(p["line"], 0.3), 1.0, true)
			AbilitySquareIcons.draw(
				self, icon, r.grow(-24), Color(p["text"], 0.45 if cooling else 1.0)
			)
			if cooling:
				_t(
					"2.4",
					Vector2(r.position.x, c.y - 14),
					22,
					p["line2"],
					true,
					HORIZONTAL_ALIGNMENT_CENTER,
					r.size.x
				)
			var kw := _tw(key, 13, true) + 14
			var kr := Rect2(Vector2(c.x - kw * 0.5, r.end.y + 8), Vector2(kw, 20))
			draw_colored_polygon(_cham(kr, 5), Color(0, 0, 0, 0.85))
			draw_polyline(_closed(_cham(kr, 5)), p["line"], 1.0, true)
			_t(
				key,
				kr.position + Vector2(0, 1),
				13,
				p["line2"],
				true,
				HORIZONTAL_ALIGNMENT_CENTER,
				kw
			)


## The minimap frame with a sketch of rooms (iso diamonds) in it; the real map would draw inside the frame.
func _minimap(r: Rect2) -> void:
	var lc: Color = p["line"]
	match style:
		"veil":
			_panel(r, true)
		"obsidian":
			var pts := _cham(r, 16)
			draw_colored_polygon(pts, Color(p["fill"], 0.85))
			draw_polyline(_closed(pts), p["line"], 2.0, true)
			_runes(
				String(d["biome_text"]),
				Vector2(r.position.x + 16, r.end.y - 22),
				12,
				Color(p["line"], 0.5),
				1.0
			)
			for corner in [
				r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)
			]:
				var sx := 1.0 if corner.x < r.get_center().x else -1.0
				var sy := 1.0 if corner.y < r.get_center().y else -1.0
				var o: Vector2 = corner + Vector2(-sx, -sy) * 5.0
				draw_polyline(
					PackedVector2Array([o + Vector2(0, sy * 26), o, o + Vector2(sx * 26, 0)]),
					p["line2"],
					2.5,
					true
				)
		_:
			lc = p["line"]
	var c := r.get_center() + Vector2(0, -6)
	var rooms := [
		Vector2(0, 0), Vector2(1, 0), Vector2(1, -1), Vector2(0, 1), Vector2(-1, 1), Vector2(2, -1)
	]
	var u := 30.0 if style != "sigil" else 24.0
	var iso := func(q: Vector2) -> Vector2:
		return c + Vector2((q.x - q.y) * u * 1.2, (q.x + q.y) * u * 0.6)
	for k in rooms.size() - 1:
		draw_line(iso.call(rooms[k]), iso.call(rooms[k + 1]), Color(lc, 0.45), 2.0, true)
	for k in rooms.size():
		var q: Vector2 = iso.call(rooms[k])
		var dm := PackedVector2Array(
			[
				q + Vector2(0, -u * 0.42),
				q + Vector2(u * 0.8, 0),
				q + Vector2(0, u * 0.42),
				q + Vector2(-u * 0.8, 0)
			]
		)
		draw_colored_polygon(dm, Color(lc, 0.5 if k == 0 else 0.16))
		draw_polyline(_closed(dm), Color(lc, 0.9 if k == 0 else 0.5), 1.4, true)
	draw_circle(iso.call(rooms[0]), 4, Color("#2BC4E2"))


## The sigil HUD: no plates. HP is a ring gauge, heat an arc under it, the danger a row of runes that light by
## tier, the slots rings, the minimap inside a rune ring.
func _hud_sigil() -> void:
	var hp := int(d["hp"])
	var mx := int(d["max_hp"])
	var lc: Color = p["line"]
	# Top centre: floor and time as text; danger as five runes (two lit) on a light line.
	_t(d["floor_text"], Vector2(0, 18), 18, p["dim"], false, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 2)
	_t(d["time_text"], Vector2(0, 42), 28, p["text"], true, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x)
	var kt: String = d["kills_text"]
	_t(kt, Vector2(960 + 80, 50), 17, p["dim"])
	_glow(PackedVector2Array([Vector2(760, 96), Vector2(1160, 96)]), Color(lc, 0.4), 1.0, 0.5)
	var fill := 0.62
	draw_line(Vector2(760, 96), Vector2(760 + 400 * fill, 96), Color("#FFB04A"), 3.0, true)
	draw_line(Vector2(760, 96), Vector2(760 + 400 * fill, 96), Color("#FFB04A", 0.2), 10.0, true)
	for k in 5:
		var at := Vector2(800 + k * 80, 106)
		var lit := k < 2
		_rune(
			[16, 8, 1, 3, 23][k],
			at - Vector2(5, 0),
			22,
			Color("#FFB04A") if lit else Color(lc, 0.3),
			2.0 if lit else 1.2
		)
	_t(d["danger_text"], Vector2(1176, 82), 22, Color("#FFB04A"), true)
	# Top right: wallet and the minimap in a rune ring.
	_wallet(Rect2(Vector2(1660, 22), Vector2(200, 52)), 30)
	var mc := Vector2(1760, 220)
	_ring(mc, 112, Color(lc, 0.7), 1.2, 0.7)
	_rune_ring(mc, 126, String(d["biome_text"]), 14, Color(lc, 0.45))
	_minimap(Rect2(mc - Vector2(110, 100), Vector2(220, 200)))
	# Bottom left: HP ring gauge with the number inside, the weapon's name on an arc line beside it.
	var hc := Vector2(130, 940)
	var rr := 86.0
	draw_arc(hc, rr, PI * 0.75, PI * 2.25, 96, Color(p["hp"], 0.15), 12, true)
	var f := float(hp) / maxf(1, mx)
	draw_arc(hc, rr, PI * 0.75, PI * 0.75 + PI * 1.5 * f, 96, Color(p["hp"], 0.25), 26, true)
	draw_arc(hc, rr, PI * 0.75, PI * 0.75 + PI * 1.5 * f, 96, p["hp"], 10, true)
	_ring(hc, rr - 20, Color(lc, 0.5), 1.0, 0.5)
	_t(
		str(hp),
		Vector2(hc.x - 80, hc.y - 30),
		42,
		p["text"],
		true,
		HORIZONTAL_ALIGNMENT_CENTER,
		160
	)
	_t(
		"/ %d" % mx,
		Vector2(hc.x - 80, hc.y + 16),
		16,
		p["dim"],
		false,
		HORIZONTAL_ALIGNMENT_CENTER,
		160
	)
	_t(
		d["weapon_text"],
		Vector2(hc.x + 112, hc.y + 36),
		18,
		p["dim"],
		true,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		2
	)
	_glow(
		PackedVector2Array([Vector2(hc.x + 112, hc.y + 64), Vector2(hc.x + 340, hc.y + 64)]),
		Color(lc, 0.5),
		1.0,
		0.5
	)
	# Bottom centre: heat as a wide shallow arc of light with three tick runes.
	var ac := Vector2(960, 1500)
	var ar := 500.0
	var a0 := -PI * 0.5 - 0.42
	var a1 := -PI * 0.5 + 0.42
	draw_arc(ac, ar, a0, a1, 96, Color(p["heat"], 0.18), 8, true)
	draw_arc(ac, ar, a0, a0 + (a1 - a0) * 0.46, 96, Color(p["heat"], 0.25), 22, true)
	draw_arc(ac, ar, a0, a0 + (a1 - a0) * 0.46, 96, p["heat"], 6, true)
	for k in 3:
		var a: float = a0 + (a1 - a0) * [0.55, 0.75, 0.95][k]
		_rune(
			10,
			ac + Vector2(cos(a), sin(a)) * (ar + 12) - Vector2(4, 16),
			16,
			Color(p["heat"], 0.6),
			1.4
		)
	_t(
		d["heat_text"],
		Vector2(0, 1022),
		16,
		p["heat"],
		true,
		HORIZONTAL_ALIGNMENT_CENTER,
		VIEW.x,
		3
	)
	_t(d["vent_text"], Vector2(0, 1046), 13, p["dim"], true, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 1)
	# Bottom right: slots as rings.
	var slots: Array = d["slots"]
	for k in slots.size():
		var c := Vector2(1640 + k * 100, 990)
		var cooling := k == 1
		var s: Array = slots[k]
		_ring(c, 38, lc if not cooling else Color(lc, 0.35), 1.6, 0.5 if cooling else 1.2)
		if cooling:
			draw_arc(c, 38, -PI * 0.5, -PI * 0.5 + TAU * 0.6, 48, p["line2"], 3.0, true)
			_t(
				"2.4",
				Vector2(c.x - 40, c.y - 14),
				22,
				p["text"],
				true,
				HORIZONTAL_ALIGNMENT_CENTER,
				80
			)
		AbilitySquareIcons.draw(
			self,
			s[0],
			Rect2(c - Vector2(20, 20), Vector2(40, 40)),
			Color(p["text"], 0.4 if cooling else 1.0)
		)
		_t(
			s[1],
			Vector2(c.x - 40, c.y + 44),
			13,
			p["dim"],
			true,
			HORIZONTAL_ALIGNMENT_CENTER,
			80,
			1
		)
