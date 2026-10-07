class_name BuildCard
extends Button
## One card of the build screen (v0.3.0 L15): a weapon silhouette, the build's name, its one-line description and
## its damage factor, all drawn by the card so its echo trail and glitch can redraw the whole face. A Button, so
## focus, hover, click, Enter and pad A work like every menu.
## Appear: after `delay` the card rises into place with an ease-out, trailing echo copies of its frame (cyan and
## magenta, fading), then lands with a short glitch (offset slices and a colour split).

const SIZE := Vector2(340, 470)
const APPEAR_S := 0.55
const GLITCH_S := 0.3
const RISE_PX := 220.0
const ECHOES := 5
const CYAN := Color("#2BC4E2")
const MAGENTA := Color("#E23A8F")
const FACE := Color("#10151C")
const EDGE := Color("#3A4655")
const TEXT := Color("#F2F2F2")
const TEXT_DIM := Color(0.95, 0.95, 0.95, 0.72)

## BuildDefinition.Weapon: which silhouette to draw.
var weapon := 0
var title_key := &""
var desc_key := &""
var damage_permille := 1000
var delay := 0.0
var _t := 0.0
var _focus_glow := 0.0
var _slices: Array[Vector3] = []
var _slice_seed := 0


func _init(
	p_weapon: int, p_name_key: StringName, p_desc_key: StringName, p_damage: int, p_delay: float
) -> void:
	weapon = p_weapon
	title_key = p_name_key
	desc_key = p_desc_key
	damage_permille = p_damage
	delay = p_delay
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	flat = true
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	mouse_entered.connect(grab_focus)


## 0 before the card starts, 1 once it has landed.
func appear() -> float:
	return clampf((_t - delay) / APPEAR_S, 0.0, 1.0)


## Skips the animation (screenshots of the settled screen, reduced motion later).
func settle() -> void:
	seek(delay + APPEAR_S + GLITCH_S + 0.01)


## Sets the animation clock (seconds since the screen opened); the screenshot tool scrubs with it.
func seek(t: float) -> void:
	_t = t
	_focus_glow = 1.0 if has_focus() else 0.0
	var since_land := _t - delay - APPEAR_S
	_slices = (
		_glitch_slices(int(since_land * 30.0))
		if since_land >= 0.0 and since_land < GLITCH_S
		else ([] as Array[Vector3])
	)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_focus_glow = move_toward(_focus_glow, 1.0 if has_focus() else 0.0, delta * 6.0)
	var since_land := _t - delay - APPEAR_S
	if since_land >= 0.0 and since_land < GLITCH_S:
		var step := int(since_land * 30.0)
		if step != _slice_seed or _slices.is_empty():
			_slice_seed = step
			_slices = _glitch_slices(step)
	elif not _slices.is_empty():
		_slices = []
	queue_redraw()


func _draw() -> void:
	var p := appear()
	if p <= 0.0:
		return
	var e := 1.0 - pow(1.0 - p, 3.0)
	var lift := -10.0 * _focus_glow
	var off := Vector2(0, RISE_PX * (1.0 - e) + lift)
	# Echo trail: copies of the frame below the card, fading, while it rises.
	if p < 1.0:
		for k in range(ECHOES, 0, -1):
			var lag := float(k) / ECHOES
			var ep := clampf(e - lag * 0.35, 0.0, 1.0)
			var eo := Vector2((k % 2) * 6.0 - 3.0, RISE_PX * (1.0 - ep))
			var col := CYAN if k % 2 == 0 else MAGENTA
			col.a = 0.32 * (1.0 - lag) * (1.0 - p * 0.6)
			draw_rect(Rect2(eo, SIZE), col, false, 2.0)
	var alpha := clampf(p * 1.6, 0.0, 1.0)
	if not _slices.is_empty():
		# Landing glitch: the face split in colour, then drawn in shifted bands.
		_face(off + Vector2(-5, 0), alpha * 0.45, MAGENTA)
		_face(off + Vector2(5, 0), alpha * 0.45, CYAN)
	_face(off, alpha * (0.72 + 0.28 * _focus_glow), Color.WHITE)
	for sl in _slices:
		var band := Rect2(off + Vector2(sl.z, sl.x), Vector2(SIZE.x, sl.y))
		draw_rect(band, Color(CYAN, 0.18))


func _face(off: Vector2, alpha: float, tint: Color) -> void:
	var r := Rect2(off, SIZE)
	var glow := _focus_glow
	var face := FACE
	face.a = 0.92 * alpha
	draw_rect(r, face)
	# Focus glow: a soft outer halo.
	if glow > 0.0:
		for k in 4:
			var g := r.grow(3.0 + k * 3.0)
			draw_rect(g, Color(CYAN, 0.10 * glow * alpha * (1.0 - k / 4.0)), false, 3.0)
	var edge := EDGE.lerp(CYAN, glow) * tint
	edge.a = alpha
	draw_rect(r, edge, false, 2.0 + glow)
	_corners(r, Color(CYAN * tint, alpha * (0.5 + 0.5 * glow)))
	# Scanlines on the face.
	for y in range(int(r.position.y) + 6, int(r.end.y), 6):
		draw_line(
			Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y), Color(1, 1, 1, 0.025 * alpha)
		)
	# The emblem: a ring with the weapon's silhouette.
	var c := r.position + Vector2(SIZE.x * 0.5, 165)
	draw_circle(c, 112, Color(CYAN, (0.06 + 0.08 * glow) * alpha))
	draw_arc(c, 112, 0, TAU, 64, Color(CYAN * tint, (0.35 + 0.4 * glow) * alpha), 2.0)
	draw_arc(c, 98, -0.6, 2.2, 32, Color(CYAN * tint, 0.25 * alpha), 1.0)
	var sil := Color(TEXT * tint, alpha)
	if weapon == 0:
		_blade(c, sil)
	else:
		_gun(c, sil)
	var font := get_theme_default_font()
	var name_text := tr(title_key)
	var y := r.position.y + 330
	draw_string(
		font,
		Vector2(r.position.x, y),
		name_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		SIZE.x,
		40,
		Color(TEXT * tint, alpha)
	)
	draw_line(
		Vector2(r.position.x + 110, y + 16),
		Vector2(r.end.x - 110, y + 16),
		Color(CYAN * tint, 0.7 * alpha),
		2.0
	)
	draw_multiline_string(
		font,
		Vector2(r.position.x + 26, y + 50),
		tr(desc_key),
		HORIZONTAL_ALIGNMENT_CENTER,
		SIZE.x - 52,
		19,
		3,
		Color(TEXT_DIM * tint, alpha)
	)
	draw_string(
		font,
		Vector2(r.position.x, r.end.y - 22),
		tr("BUILD_DAMAGE") % damage_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		SIZE.x,
		18,
		Color(CYAN * tint, 0.9 * alpha)
	)


## "+15 %" / "-15 %" from the data's per mille.
func damage_text() -> String:
	var pct := int(round((damage_permille - 1000) / 10.0))
	return ("+%d %%" % pct) if pct >= 0 else ("-%d %%" % -pct)


func _corners(r: Rect2, col: Color) -> void:
	var l := 18.0
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if c.x == r.position.x else -1.0
		var sy := 1.0 if c.y == r.position.y else -1.0
		draw_line(c, c + Vector2(l * sx, 0), col, 3.0)
		draw_line(c, c + Vector2(0, l * sy), col, 3.0)


## A long blade, tilted, with its guard and hilt.
func _blade(c: Vector2, col: Color) -> void:
	var rot := -PI / 4.0
	var k := 1.15
	var pts := PackedVector2Array(
		[Vector2(0, -92), Vector2(13, -70), Vector2(11, 34), Vector2(-11, 34), Vector2(-13, -70)]
	)
	draw_colored_polygon(_xf(pts, c, rot, k), col)
	draw_line(
		_xf1(Vector2(0, -80), c, rot, k),
		_xf1(Vector2(0, 28), c, rot, k),
		Color(CYAN, col.a * 0.8),
		2.0
	)
	var guard := PackedVector2Array(
		[Vector2(-34, 34), Vector2(34, 34), Vector2(28, 44), Vector2(-28, 44)]
	)
	draw_colored_polygon(_xf(guard, c, rot, k), Color(CYAN, col.a))
	var hilt := PackedVector2Array(
		[Vector2(-6, 44), Vector2(6, 44), Vector2(6, 74), Vector2(-6, 74)]
	)
	draw_colored_polygon(_xf(hilt, c, rot, k), col)
	draw_circle(_xf1(Vector2(0, 80), c, rot, k), 8, Color(CYAN, col.a))


## A blocky sidearm: slide, muzzle, angled grip, trigger guard and a glowing coil.
func _gun(c: Vector2, col: Color) -> void:
	var o := c + Vector2(-11, -13)
	var slide := PackedVector2Array(
		[Vector2(-70, -34), Vector2(62, -34), Vector2(70, -26), Vector2(70, -6), Vector2(-70, -6)]
	)
	draw_colored_polygon(_xf(slide, o, 0.0), col)
	var muzzle := PackedVector2Array(
		[Vector2(70, -26), Vector2(88, -26), Vector2(88, -12), Vector2(70, -12)]
	)
	draw_colored_polygon(_xf(muzzle, o, 0.0), col)
	var frame := PackedVector2Array(
		[Vector2(-60, -6), Vector2(34, -6), Vector2(34, 4), Vector2(-60, 4)]
	)
	draw_colored_polygon(_xf(frame, o, 0.0), Color(col, col.a * 0.85))
	var grip := PackedVector2Array(
		[Vector2(-60, 4), Vector2(-30, 4), Vector2(-40, 62), Vector2(-72, 62)]
	)
	draw_colored_polygon(_xf(grip, o, 0.0), col)
	draw_polyline(
		_xf(
			PackedVector2Array([Vector2(-30, 4), Vector2(-22, 24), Vector2(4, 24), Vector2(10, 4)]),
			o,
			0.0
		),
		col,
		4.0
	)
	for i in 4:
		draw_rect(Rect2(o + Vector2(-46 + i * 22, -28), Vector2(12, 14)), Color(CYAN, col.a))
	draw_line(o + Vector2(-56, 14), o + Vector2(-60, 54), Color(FACE, 0.6 * col.a), 3.0)
	draw_circle(o + Vector2(98, -19), 6, Color(CYAN, col.a * 0.9))
	draw_circle(o + Vector2(98, -19), 11, Color(CYAN, col.a * 0.25))


static func _xf(
	pts: PackedVector2Array, c: Vector2, rot: float, k: float = 1.0
) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_xf1(p, c, rot, k))
	return out


static func _xf1(p: Vector2, c: Vector2, rot: float, k: float = 1.0) -> Vector2:
	return c + (p * k).rotated(rot)


## Three bands across the card: [y, height, x shift].
static func _glitch_slices(step: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var h := (step * 7919 + 13) % 997
	for k in 3:
		h = (h * 1103 + 12345) % 9973
		var y := float(h % int(SIZE.y - 30))
		var tall := 6.0 + float(h % 22)
		var shift := float((h % 31) - 15)
		out.append(Vector3(y, tall, shift))
	return out
