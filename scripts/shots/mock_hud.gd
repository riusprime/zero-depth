extends SceneTree
## v0.9.5 HM (G2, docs/process/OWNER_GATES.md §3; owner Q9 and the "UI for spells" line): three mockups of the four
## ability squares (bottom right: Attack RT, Skill LT, Dash RB, Blink LB) and the HP plate 15 % bigger, in English and
## Spanish, at 1920 x 1080. The backdrop is a real frame: a Gun run (World seed 11, the data's runner + Gun build, the
## Overclock heat at 55) on the Ruins stage with four Chargers, drawn by WorldViewRoot and the real Hud; the old blue
## pips, the old ability row and the Skill pip are hidden and the mockup squares are drawn over it (built here, not
## shipped). The four states at once: Attack ready; Skill 3.2 s left of 6; Dash 7.4 s left of 10; Blink ready, 2
## charges; a small inset shows the "just became ready" flash.
## - A: a Risk of Rain row; the cooldown is a dark cover that shrinks downward, with big seconds.
## - B: the cooldown is a clockwise radial sweep and the border is a progress ring in the ability's accent.
## - C: the cooldown is a tinted fill from the bottom; the heat meter becomes a thin bar over the squares and Vent a
##   fifth, smaller square.
## A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --resolution 1920x1080 -s scripts/shots/mock_hud.gd
## Writes build/shots/v0.9.5/hm/<a|b|c>_<en|es>.png. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.9.5/hm/"
const VARIANTS := ["a", "b", "c"]
const LANGS := ["en", "es"]
const SETTLE := 10
## [id, pad glyph key, accent, seconds left, seconds total, charges]; the four states shown at once.
const SQUARES := [
	[&"attack", "MOCK_PAD_RT", Color("#E8EAEE"), 0.0, 1.0, 0],
	[&"skill", "MOCK_PAD_LT", Color("#F2B33D"), 3.2, 6.0, 0],
	[&"dash", "MOCK_PAD_RB", Color("#4FC3F7"), 7.4, 10.0, 0],
	[&"blink", "MOCK_PAD_LB", Color("#B388FF"), 0.0, 1.0, 2],
]
const TEXTS := {
	"en":
	{
		"MOCK_CAP_A": "A — Risk of Rain row: a dark cover that shrinks down, big seconds",
		"MOCK_CAP_B": "B — Radial: a clockwise sweep and an accent progress ring",
		"MOCK_CAP_C":
		"C — Tinted fill: fills from the bottom; heat bar on top, Vent a fifth square",
		"MOCK_READY": "JUST READY",
		"MOCK_PAD_RT": "RT",
		"MOCK_PAD_LT": "LT",
		"MOCK_PAD_RB": "RB",
		"MOCK_PAD_LB": "LB",
		"MOCK_PAD_B": "B",
	},
	"es":
	{
		"MOCK_CAP_A": "A — Fila Risk of Rain: una cubierta oscura que baja, segundos grandes",
		"MOCK_CAP_B": "B — Radial: un barrido horario y un anillo de progreso de color",
		"MOCK_CAP_C":
		"C — Relleno teñido: sube desde abajo; barra de calor arriba, Vent un quinto cuadro",
		"MOCK_READY": "RECIÉN LISTA",
		"MOCK_PAD_RT": "RT",
		"MOCK_PAD_LT": "LT",
		"MOCK_PAD_RB": "RB",
		"MOCK_PAD_LB": "LB",
		"MOCK_PAD_B": "B",
	},
}

var _w: World
var _reader: WorldReader
var _view: WorldViewRoot
var _hud: Hud
var _mock: HudMock
var _frame := 0
var _shots: Array = []
var _at := -1
var _wait := 0


## The squares, drawn over the HUD in one canvas item.
class HudMock:
	extends Control
	var variant := "a"
	var heat := 0.55

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED

	func _side() -> float:
		return {"a": 76.0, "b": 72.0, "c": 68.0}[variant]

	func _gap() -> float:
		return 6.0

	## The top-left of square k (bottom right, 24 px from the edges).
	func _origin(k: int) -> Vector2:
		var s := _side()
		var total := 4.0 * s + 3.0 * _gap()
		if variant == "c":
			total += 10.0 + 48.0
		return Vector2(size.x - 24.0 - total + k * (s + _gap()), size.y - 24.0 - s)

	func _draw() -> void:
		var s := _side()
		for k in SQUARES.size():
			_square(Rect2(_origin(k), Vector2(s, s)), SQUARES[k], false)
		# The "just became ready" flash, a small inset left of the row (a Dash that just came back).
		var inset := Rect2(_origin(0) + Vector2(-110.0, s - 44.0), Vector2(44, 44))
		_square(inset, [&"dash", "MOCK_PAD_RB", SQUARES[2][2], 0.0, 1.0, 0], true)
		_text(tr("MOCK_READY"), inset.position + Vector2(-43, -20), 13, Color(1, 1, 1, 0.8), 130)
		if variant == "c":
			_heat_and_vent()

	func _text(t: String, at: Vector2, fs: int, col: Color, w: float, outline := 3) -> void:
		var f := HudStyle.font(true)
		if outline > 0:
			draw_string_outline(
				f,
				at + Vector2(0, fs),
				t,
				HORIZONTAL_ALIGNMENT_CENTER,
				w,
				fs,
				outline,
				Color(0, 0, 0, 0.85)
			)
		draw_string(f, at + Vector2(0, fs), t, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)

	func _plate(r: Rect2, border: Color, bw := 2) -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("#1A1D24", 0.88)
		box.border_color = border
		box.set_border_width_all(bw)
		box.set_corner_radius_all(4)
		draw_style_box(box, r)

	func _square(r: Rect2, sq: Array, flash: bool) -> void:
		var accent: Color = sq[2]
		var total: float = sq[4]
		var left: float = 0.0 if flash else sq[3]
		var share := clampf(left / total, 0.0, 1.0)
		var cooling := share > 0.0
		var ring := variant == "b"
		var lit := Color("#E8EAEE") if not cooling else Color("#C8CCD4", 0.30)
		_plate(r, Color("#C8CCD4", 0.30) if ring else lit)
		var inner := r.grow(-2.0)
		var icon_c := Color("#E8EAEE")
		if variant != "a":
			icon_c = accent if not cooling else accent.darkened(0.15)
		if variant == "c" and cooling:
			icon_c = Color(0.55, 0.57, 0.6)
		var icon_r := r.grow(-r.size.x * 0.24)
		if variant == "b":
			icon_r = Rect2(icon_r.position + Vector2(0, -r.size.y * 0.05), icon_r.size)
		match variant:
			"b":
				if cooling:
					_wedge(inner, share)
				_ring(r.grow(-1.0), 1.0 - share if cooling else 1.0, accent)
			"c":
				if cooling:
					var fh := inner.size.y * (1.0 - share)
					draw_rect(
						Rect2(
							inner.position + Vector2(0, inner.size.y - fh),
							Vector2(inner.size.x, fh)
						),
						Color(accent, 0.35)
					)
		_icon(sq[0], icon_r, icon_c)
		if variant == "a" and cooling:
			draw_rect(
				Rect2(inner.position, Vector2(inner.size.x, inner.size.y * share)),
				Color(0, 0, 0, 0.65)
			)
			_text(
				"%.1f" % left,
				r.position + Vector2(0, r.size.y * 0.5 - 18.0),
				30,
				Color.WHITE,
				r.size.x,
				3
			)
		if variant == "b" and cooling:
			_text(
				"%.1f" % left,
				r.position + Vector2(0, r.size.y - 24.0),
				18,
				Color.WHITE,
				r.size.x,
				3
			)
		if variant == "c" and cooling:
			_text("%.1f" % left, r.position + Vector2(0, 3.0), 20, Color.WHITE, r.size.x, 3)
		if flash:
			draw_rect(r.grow(5.0), Color(1, 1, 1, 0.18), false, 3.0)
			draw_rect(r, Color(1, 1, 1, 0.45))
			draw_rect(r, Color.WHITE, false, 2.0)
		elif not cooling and variant == "a":
			draw_rect(r.grow(1.0), Color(1, 1, 1, 0.16), false, 2.0)
		# The pad glyph, a dark pill at the bottom-left corner; the charge count at the top right.
		_pill(tr(sq[1]), r.position + Vector2(-5.0, r.size.y - 17.0))
		var ch: int = sq[5]
		if ch > 0:
			var c := r.position + Vector2(r.size.x - 13.0, 13.0)
			draw_circle(c, 11.0, Color(0, 0, 0, 0.85))
			draw_arc(c, 11.0, 0.0, TAU, 24, Color(accent, 0.9), 1.5)
			_text(str(ch), c - Vector2(11, 12), 16, Color.WHITE, 22, 0)

	func _pill(t: String, at: Vector2) -> void:
		var f := HudStyle.font(true)
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.03, 0.03, 0.05, 0.92)
		box.border_color = Color(1, 1, 1, 0.35)
		box.set_border_width_all(1)
		box.set_corner_radius_all(10)
		draw_style_box(box, Rect2(at, Vector2(w, 20)))
		_text(t, at + Vector2(0, 1), 13, Color.WHITE, w, 0)

	## The share still cooling as a clockwise wedge from twelve o'clock, clipped to the square.
	func _wedge(r: Rect2, share: float) -> void:
		var c := r.get_center()
		var rad := r.size.length() * 0.5
		var pts := PackedVector2Array([c])
		var steps := maxi(2, int(ceil(share * 32.0)))
		for k in steps + 1:
			var a := -PI * 0.5 + TAU * minf(share, 0.995) * k / steps
			var p := c + Vector2(cos(a), sin(a)) * rad
			pts.append(
				Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
			)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.60))

	## A progress ring around the square's edge, clockwise from the top middle.
	func _ring(r: Rect2, progress: float, col: Color) -> void:
		var corners := [
			Vector2(r.get_center().x, r.position.y),
			Vector2(r.end.x, r.position.y),
			r.end,
			Vector2(r.position.x, r.end.y),
			r.position,
			Vector2(r.get_center().x, r.position.y),
		]
		var budget := (r.size.x + r.size.y) * 2.0 * clampf(progress, 0.0, 1.0)
		var pts := PackedVector2Array([corners[0]])
		for k in range(1, corners.size()):
			var seg: float = (corners[k] - corners[k - 1]).length()
			if budget >= seg:
				pts.append(corners[k])
				budget -= seg
			else:
				pts.append(corners[k - 1].lerp(corners[k], budget / seg))
				break
		if pts.size() >= 2:
			draw_polyline(pts, col, 3.0)

	func _icon(id: StringName, r: Rect2, col: Color) -> void:
		AbilitySquareIcons.draw(self, &"pulse_gun" if id == &"attack" else id, r, col)

	## C: the thin heat bar over the four squares, and Vent as a fifth, smaller square at the right end.
	func _heat_and_vent() -> void:
		var s := _side()
		var x0 := _origin(0).x
		var w := 4.0 * s + 3.0 * _gap()
		var y := _origin(0).y - 14.0
		draw_rect(Rect2(x0, y, w, 6), Color("#1A1D24", 0.88))
		draw_rect(Rect2(x0, y, w * heat, 6), HudStyle.HEAT[1])
		draw_rect(Rect2(x0 - 1, y - 1, w + 2, 8), Color("#C8CCD4", 0.30), false, 1.0)
		var v := Rect2(Vector2(x0 + w + 10.0, size.y - 24.0 - 48.0), Vector2(48, 48))
		_plate(v, Color("#E8EAEE"))
		_icon(&"vent", v.grow(-14.0), HudStyle.HEAT[1])
		_text(tr("HUD_VENT"), v.position + Vector2(0, 2), 12, Color.WHITE, v.size.x, 2)
		_pill(tr("MOCK_PAD_B"), v.position + Vector2(-5.0, v.size.y - 17.0))


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("hm: renderer=%s" % RenderingServer.get_current_rendering_method())
	for lang in LANGS:
		var t := Translation.new()
		t.locale = lang
		for key: String in TEXTS[lang]:
			t.add_message(key, TEXTS[lang][key])
		TranslationServer.add_translation(t)
	_w = _world()
	_reader = WorldReader.new(_w)
	_view = WorldViewRoot.new()
	_view.rig.view_size = 8.0
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	var repo := ContentRepository.load_all()
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	_view.setup(_reader, biome.palette, 12.0)
	_view.rig.snap_to(SimPlane.to_3d(Vector2(2.0, 0.0), 0.6))
	var layer := CanvasLayer.new()
	root.add_child(layer)
	InputDefaults.apply()
	_hud = Hud.new()
	layer.add_child(_hud)
	_mock = HudMock.new()
	layer.add_child(_mock)
	for k in 6:
		_tick()
	for v in VARIANTS:
		for lang in LANGS:
			_shots.append([v, lang])


func _world() -> World:
	var repo := ContentRepository.load_all()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, repo.get_def(&"build", &"gun"))
	var w := World.new(11, t)
	var enemies := ContentCompiler.compile_enemies(repo)
	for e in enemies:
		e.speed = 0.0
	w.set_enemy_tables(enemies)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	for at: Vector2 in [
		Vector2(4.6, 0.6), Vector2(5.0, -1.4), Vector2(2.6, -1.8), Vector2(3.0, 1.8)
	]:
		w.add_enemy(ActorStore.Kind.CHARGER, at)
	for i in range(1, w.actors.size()):
		w.actors.state[i] = EnemyAi.State.MOVE
		w.actors.cd[i] = 1 << 30
		w.actors.invuln[i] = 0
		w.actors.hp[i] = 9999
		w.actors.max_hp[i] = 9999
	w.heat.milli = 55 * HeatTable.MILLI
	return w


func _tick() -> void:
	_w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0))
	_view.sync()
	_hud.sync(_reader)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 3000:
		print("hm: gave up")
		quit(1)
		return true
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_grab()
		return false
	_at += 1
	if _at >= _shots.size():
		print("hm: done")
		quit(0)
		return true
	_show(_shots[_at])
	_wait = SETTLE
	return false


func _show(shot: Array) -> void:
	TranslationServer.set_locale(shot[1])
	_tick()
	var v: String = shot[0]
	# The real squares (v0.9.5 HU) are hidden; the mockup's are drawn over the HUD, which keeps its real HP plate.
	_hud.ability_squares.visible = false
	if v == "c":  # the heat meter and the Vent plate move into the squares' row
		_hud.heat_meter.visible = false
		(_hud.kit_hud.find_child("VentPlate", true, false) as Control).visible = false
	_mock.variant = v
	_mock.queue_redraw()
	var cap := Label.new()
	cap.name = "Caption"
	cap.text = tr("MOCK_CAP_" + v.to_upper())
	cap.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	cap.add_theme_font_size_override("font_size", 17)
	cap.add_theme_color_override("font_color", Color(1, 0.85, 0.6))
	cap.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cap.add_theme_constant_override("outline_size", 4)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cap.position = Vector2(1896 - 900, 1080 - 25)
	cap.size = Vector2(900, 22)
	_mock.add_child(cap)


func _grab() -> void:
	var shot: Array = _shots[_at]
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s_%s.png" % shot
	img.save_png(path)
	print("hm: ", path, " ", img.get_size())
	var cap := _mock.get_node_or_null("Caption")
	if cap != null:
		cap.free()
	_hud.heat_meter.visible = true
	(_hud.kit_hud.find_child("VentPlate", true, false) as Control).visible = true
