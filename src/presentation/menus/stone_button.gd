class_name StoneButton
extends Button
## v0.9.5 MM (owner, 2026-10-26: "make the main menu look closer to this", docs/art/reference/v0.9.5_main_menu.webp):
## the main menu's button, drawn in code: a dark cracked-stone plate with angled (hexagonal) ends, a thin bevelled
## light rim, a few hairline cracks and small crystal shards jutting from its right end. The focused or hovered one is
## rimmed and lit in electric blue (a soft glow round the plate, bigger shards at both ends); a press flashes it
## brighter; a disabled one (Continue with no save) is dimmed with no blue. The label is drawn thin, uppercase and
## widely letter-spaced (about 0.2 em). It stays a Button (BaseButton hover and disabled states, focus, keyboard and pad
## all work as for any button; the cursor reads the same states). A mouse hover also takes the focus, so the mouse, the
## keys and the pad move one focus. Presentation only (EI-07): a look, never an outcome.

const PLATE := Vector2(294, 59)
## The room left and right of the plate for the shards (so the control is PLATE.x + 2 * SIDE wide).
const SIDE := 11.0
## How far the hexagonal ends point in.
const CUT := 21.0
const LABEL_SIZE := 17
const LABEL_SPACING := 0.2
const LABEL_PAD := 43.0
const BLUE := Color("#2E7BFF")
const BLUE_LIGHT := Color("#8FC4FF")
const BLUE_DARK := Color("#1A4FD0")
const RIM := Color("#8D93A3")
const TEXT := Color("#E9EAF0")
const GLOW_RATE := 9.0
const FLASH_RATE := 4.5
const DIM := 0.42

static var _stone: Texture2D
static var _font: FontVariation

## 0..1: how lit it is now (eases toward 1 while focused or hovered, never while disabled), and the press flash.
var glow := 0.0
var flash := 0.0
## The row's place in the column (the cracks and shards are drawn from it, the same every time).
var index := 0

var _plate := PackedVector2Array()
var _inner := PackedVector2Array()
var _halo: Array[PackedVector2Array] = []
var _cracks: Array[PackedVector2Array] = []
var _shards_right: Array[Dictionary] = []
var _shards_left: Array[Dictionary] = []


func _init(p_index: int = 0) -> void:
	index = p_index
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(PLATE.x + SIDE * 2.0, PLATE.y)
	focus_mode = Control.FOCUS_ALL
	var none := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(s, none)
	for c in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_hover_pressed_color",
		"font_disabled_color",
		"font_outline_color"
	]:
		add_theme_color_override(c, Color(0, 0, 0, 0))  # the label is drawn below, not by the Button
	add_theme_constant_override("outline_size", 0)
	mouse_entered.connect(_on_mouse_entered)
	button_down.connect(func() -> void: flash = 1.0)
	resized.connect(_rebuild)
	_rebuild()


## Lit: focused or hovered, and not disabled (the blue rim, the glow and the big shards).
func is_lit() -> bool:
	return not disabled and (has_focus() or is_hovered())


func _on_mouse_entered() -> void:
	if not disabled and is_inside_tree() and focus_mode != Control.FOCUS_NONE:
		grab_focus()


func _process(delta: float) -> void:
	var want := 1.0 if is_lit() else 0.0
	var g := move_toward(glow, want, delta * GLOW_RATE)
	var f := move_toward(flash, 0.0, delta * FLASH_RATE)
	if g != glow or f != flash:
		glow = g
		flash = f
		queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT, NOTIFICATION_MOUSE_EXIT, NOTIFICATION_TRANSLATION_CHANGED:
			queue_redraw()
		NOTIFICATION_DISABLED, NOTIFICATION_ENABLED:
			queue_redraw()


## The type: the UI font, thin and letter-spaced about 0.2 em (shared).
static func label_font() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = HudStyle.font(false)
		_font.spacing_glyph = int(round(LABEL_SIZE * LABEL_SPACING))
	return _font


## The dark stone: a small value-noise texture made once in code (static, shared by every plate).
static func stone_texture() -> Texture2D:
	if _stone != null:
		return _stone
	var w := 256
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var grid := []
	for octave in 3:
		var n := 4 << octave
		var cells := []
		for i in (n + 1) * (n + 1):
			cells.append(rng.randf())
		grid.append(cells)
	for y in h:
		for x in w:
			var v := 0.0
			var amp := 0.55
			for octave in 3:
				var n := 4 << octave
				var fx := float(x) / w * n
				var fy := float(y) / h * n
				var ix := int(fx)
				var iy := int(fy)
				var tx := smoothstep(0.0, 1.0, fx - ix)
				var ty := smoothstep(0.0, 1.0, fy - iy)
				var cells: Array = grid[octave]
				var a := lerpf(cells[iy * (n + 1) + ix], cells[iy * (n + 1) + ix + 1], tx)
				var b := lerpf(
					cells[(iy + 1) * (n + 1) + ix], cells[(iy + 1) * (n + 1) + ix + 1], tx
				)
				v += lerpf(a, b, ty) * amp
				amp *= 0.5
			var g := 0.1 + v * 0.2
			img.set_pixel(x, y, Color(g * 0.95, g, g * 1.1))
	_stone = ImageTexture.create_from_image(img)
	return _stone


func _rebuild() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var l := SIDE
	var r := w - SIDE
	_plate = PackedVector2Array(
		[
			Vector2(l + CUT, 0),
			Vector2(r - CUT, 0),
			Vector2(r, h * 0.5),
			Vector2(r - CUT, h),
			Vector2(l + CUT, h),
			Vector2(l, h * 0.5)
		]
	)
	var inner := Geometry2D.offset_polygon(_plate, -3.0, Geometry2D.JOIN_MITER)
	_inner = inner[0] if not inner.is_empty() else _plate
	_halo.clear()
	for d in [2.0, 4.0, 6.0, 9.0, 13.0]:
		var o := Geometry2D.offset_polygon(_plate, d, Geometry2D.JOIN_ROUND)
		_halo.append(o[0] if not o.is_empty() else _plate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (index + 3)
	_cracks.clear()
	for k in 2 + index % 3:
		var p := Vector2(rng.randf_range(l + w * 0.2, r - w * 0.1), 0.0 if k % 2 == 0 else h)
		var pts := PackedVector2Array([p])
		var steps := rng.randi_range(4, 6)
		for s in steps:
			p += Vector2(rng.randf_range(-18.0, 8.0), (1.0 if k % 2 == 0 else -1.0) * h / steps)
			pts.append(Vector2(clampf(p.x, l + 6, r - 6), clampf(p.y, 0, h)))
		_cracks.append(pts)
	_shards_right = _make_shards(rng, Vector2(r - 6.0, h * 0.5), 1.0)
	_shards_left = _make_shards(rng, Vector2(l + 6.0, h * 0.5), -1.0)
	queue_redraw()


## Crystal shards at one end of the plate: {"at", "dir", "len", "wid", "big"} each (dir: radians, up is negative).
func _make_shards(rng: RandomNumberGenerator, end: Vector2, side: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n := 3
	for k in n:
		var up := -1.0 if k % 2 == 0 else 1.0
		var ang := (-0.9 if up < 0.0 else 0.7) + rng.randf_range(-0.25, 0.25)
		out.append(
			{
				"at":
				end + Vector2(side * rng.randf_range(-7.0, 6.0), up * rng.randf_range(11.0, 24.0)),
				"dir": ang if side > 0.0 else PI - ang,
				"len": rng.randf_range(15.0, 27.0),
				"wid": rng.randf_range(5.0, 8.0),
				"big": k == 0
			}
		)
	return out


func _draw() -> void:
	if _plate.is_empty():
		return
	var dim := DIM if disabled else 1.0
	var g := glow
	var f := flash
	# The soft glow round the plate.
	for i in _halo.size():
		var a := (0.2 - 0.035 * i) * g
		if a > 0.0:
			var ring := _halo[i].duplicate()
			ring.append(ring[0])
			draw_polyline(ring, Color(BLUE, a + 0.1 * f * g), 3.0 + i, true)
	# The stone: noise-textured, with a lighter top and a darker foot.
	var uv := PackedVector2Array()
	for p in _plate:
		uv.append(Vector2(p.x / size.x, p.y / size.y))
	draw_colored_polygon(
		_plate, Color(0.78, 0.78, 0.82).darkened(0.55 if disabled else 0.0), uv, stone_texture()
	)
	var top := PackedVector2Array(
		[
			_plate[0],
			_plate[1],
			_plate[1].lerp(_plate[2], 0.5) + Vector2(0, 8),
			Vector2(_plate[5].x + CUT * 0.5, size.y * 0.5 - 6)
		]
	)
	draw_colored_polygon(top, Color(1, 1, 1, 0.045 * dim))
	var foot := PackedVector2Array(
		[_plate[5], _plate[4], _plate[3], Vector2(_plate[2].x - CUT * 0.5, size.y * 0.55)]
	)
	draw_colored_polygon(foot, Color(0, 0, 0, 0.22))
	if g > 0.0:
		draw_colored_polygon(_inner, Color(BLUE, 0.08 * g + 0.12 * f))
	if dim < 1.0:
		draw_colored_polygon(_plate, Color(0, 0, 0, 0.35))
	# Cracks.
	for c in _cracks:
		draw_polyline(c, Color(0, 0, 0, 0.7 * dim), 1.6, true)
		draw_polyline(c, Color(0.6, 0.66, 0.8, 0.14 * dim), 1.0, true)
	# The rim: light grey and bevelled, or electric blue when lit.
	var rim := RIM.darkened(0.15 if disabled else 0.0).lerp(BLUE, g).lerp(BLUE_LIGHT, f * g)
	var closed := _plate.duplicate()
	closed.append(_plate[0])
	draw_polyline(closed, Color(rim, 1.0 if not disabled else 0.55), 1.8 + 1.0 * g, true)
	var bev := _inner.duplicate()
	bev.append(_inner[0])
	draw_polyline(bev, Color(rim.lightened(0.25), 0.22 + 0.4 * g), 1.0, true)
	# Crystal shards: faint blue at the right end; big and bright at both ends when lit.
	var tint := Color(0.3, 0.42, 0.75, 0.55) if disabled else Color(BLUE, 0.4 + 0.6 * g)
	for s in _shards_right:
		_shard(s, tint, g, 0.55 + 0.45 * g)
	if g > 0.02:
		for s in _shards_left:
			_shard(s, tint, g, g)
	# The label.
	var font := label_font()
	var text := tr(text_key()).to_upper()
	var ascent := font.get_ascent(LABEL_SIZE)
	var descent := font.get_descent(LABEL_SIZE)
	var col := Color(TEXT, 0.9).lerp(Color.WHITE, g * 0.4)
	if disabled:
		col = Color(TEXT, 0.3)
	draw_string(
		font,
		Vector2(SIDE + LABEL_PAD, (size.y + ascent - descent) * 0.5),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LABEL_SIZE,
		col
	)


func text_key() -> String:
	return text


func _shard(s: Dictionary, tint: Color, g: float, grow: float) -> void:
	var at: Vector2 = s["at"]
	var ang: float = s["dir"]
	var shard_len: float = s["len"] * grow * (1.0 + 0.5 * g if s["big"] else 1.0)
	var wid: float = s["wid"] * grow * (1.0 + 0.35 * g if s["big"] else 1.0)
	var d := Vector2.from_angle(ang)
	var n := d.orthogonal()
	var tip := at + d * shard_len
	var a := at - n * wid
	var b := at + n * wid
	var ridge := at + d * shard_len * 0.55
	var light := Color(BLUE_LIGHT, tint.a).lerp(tint, 0.35)
	var dark := Color(BLUE_DARK, tint.a).lerp(tint, 0.4)
	draw_colored_polygon(PackedVector2Array([a, tip, ridge]), light)
	draw_colored_polygon(PackedVector2Array([b, tip, ridge]), dark)
	draw_colored_polygon(PackedVector2Array([a, ridge, b]), Color(dark, tint.a * 0.8))
