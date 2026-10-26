class_name GameCursor
extends Node
## v0.9.5 MC (owner L16): the game's own mouse cursor. A rune reticle during a run and a rune-tipped arrow in the
## menus, the hub, the pause and the death screen. Both are drawn once into an Image in code (4x4 coverage per pixel,
## so the edges are smooth) and set through the hardware cursor API only when the context changes. Drop
## assets/ui/cursor_reticle.png / cursor_arrow.png to replace them (hotspots: the centre / the tip).
## When a pad was the last device used, the cursor is hidden during a run and comes back on mouse motion.

const RETICLE_PATH := "res://assets/ui/cursor_reticle.png"
const ARROW_PATH := "res://assets/ui/cursor_arrow.png"
const BASE := 32
const TALL_HEIGHT := 1440
const TALL_SCALE := 1.5
const LIGHT := Color("#E8EAEE")
const DARK := Color("#1A1A22")
const VIOLET := Color("#9B6BFF")
const SAMPLES := 4

## Whether the game is in a run right now. The default asks the parent (Main): a driver that is not paused (a menu,
## the pause and the dev panel pause it) and no end panel. Tests set their own.
var in_run: Callable = _parent_in_run
var reticle_path := RETICLE_PATH
var arrow_path := ARROW_PATH
var pad_active := false

var _scale := 0.0
var _reticle: Texture2D
var _arrow: Texture2D
var _reticle_hot := Vector2i.ZERO
var _arrow_hot := Vector2i.ZERO
var _context := -1  # 0 menu, 1 run, -1 none yet


func _init() -> void:
	name = "GameCursor"
	pad_active = not Input.get_connected_joypads().is_empty()


func _ready() -> void:
	setup(get_window().size.y)
	get_window().size_changed.connect(func() -> void: setup(get_window().size.y))


func _input(event: InputEvent) -> void:
	var was := pad_active
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pad_active = false
	elif (
		event is InputEventJoypadButton
		or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3)
	):
		pad_active = true
	if pad_active != was and _context >= 0:
		_apply_visibility()


## Only compares the context; the cursor itself is set when it changes.
func _process(_delta: float) -> void:
	var run := in_run.is_valid() and bool(in_run.call())
	if int(run) != _context:
		set_context(run)


## Builds the textures for a window of this height (again only when its size class changes).
func setup(height: int) -> void:
	var s := TALL_SCALE if height >= TALL_HEIGHT else 1.0
	if is_equal_approx(s, _scale):
		return
	_scale = s
	_reticle = _override(reticle_path)
	_reticle_hot = Vector2i(_reticle.get_size() / 2.0) if _reticle != null else Vector2i.ZERO
	if _reticle == null:
		_reticle = ImageTexture.create_from_image(draw_reticle(s))
		_reticle_hot = Vector2i(roundi(BASE * s / 2.0), roundi(BASE * s / 2.0))
	_arrow = _override(arrow_path)
	_arrow_hot = Vector2i.ZERO
	if _arrow == null:
		_arrow = ImageTexture.create_from_image(draw_arrow(s))
		_arrow_hot = Vector2i(roundi(s), roundi(s))
	if _context >= 0:
		_apply(_context == 1)


func set_context(run: bool) -> void:
	if int(run) == _context:
		return
	_context = int(run)
	_apply(run)


func reticle() -> Texture2D:
	return _reticle


func arrow() -> Texture2D:
	return _arrow


func _parent_in_run() -> bool:
	var m := get_parent()
	if m == null:
		return false
	var d: Object = m.get("driver")
	return d != null and not bool(d.get("paused")) and m.get("_end") == null


func _apply(run: bool) -> void:
	if _reticle == null:
		return
	if run:
		Input.set_custom_mouse_cursor(_reticle, Input.CURSOR_ARROW, _reticle_hot)
	else:
		Input.set_custom_mouse_cursor(_arrow, Input.CURSOR_ARROW, _arrow_hot)
	_apply_visibility()


func _apply_visibility() -> void:
	var hide := _context == 1 and pad_active
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hide else Input.MOUSE_MODE_VISIBLE


func _override(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## The reticle: a dark-outlined light ring, four ticks outside it and a violet diamond at the centre.
static func draw_reticle(k: float) -> Image:
	return _render(
		roundi(BASE * k),
		func(p: Vector2) -> Color:
			var c := Vector2.ONE * BASE * k / 2.0
			var d := p - c
			var r := d.length()
			if absf(d.x) + absf(d.y) <= 2.0 * k:
				return VIOLET
			var ax := maxf(absf(d.x), absf(d.y))
			var off := minf(absf(d.x), absf(d.y))
			if absf(r - 11.0 * k) <= 1.0 * k or (ax >= 13.5 * k and off <= 0.5 * k):
				return Color(LIGHT, 0.85)
			if absf(r - 11.0 * k) <= 2.0 * k or (ax >= 13.0 * k and off <= 1.0 * k):
				return DARK
			return Color(0, 0, 0, 0)
	)


## The arrow: a classic pointer, dark outline, light fill, a violet diamond near the tip. Hotspot (k, k).
static func draw_arrow(k: float) -> Image:
	var pts := PackedVector2Array(
		[
			Vector2(1, 1),
			Vector2(1, 23),
			Vector2(6, 18),
			Vector2(9.5, 26),
			Vector2(12.5, 24.5),
			Vector2(9, 17),
			Vector2(16, 17)
		]
	)
	for i in pts.size():
		pts[i] *= k
	return _render(
		roundi(BASE * k),
		func(p: Vector2) -> Color:
			var dist := 1e9
			for i in pts.size():
				var a := pts[i]
				var b := pts[(i + 1) % pts.size()]
				dist = minf(dist, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
			if Geometry2D.is_point_in_polygon(p, pts):
				var q := p - Vector2(4.5, 8.5) * k
				if absf(q.x) + absf(q.y) <= 2.0 * k:
					return VIOLET
				return DARK if dist <= 1.0 * k else LIGHT
			return DARK if dist <= 0.5 * k else Color(0, 0, 0, 0)
	)


static func _render(size: int, shade: Callable) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var n := float(SAMPLES * SAMPLES)
	for y in size:
		for x in size:
			var sum := Color(0, 0, 0, 0)
			for sy in SAMPLES:
				for sx in SAMPLES:
					var c: Color = shade.call(
						Vector2(x + (sx + 0.5) / SAMPLES, y + (sy + 0.5) / SAMPLES)
					)
					sum += Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a)
			var a := sum.a / n
			if a > 0.0:
				img.set_pixel(x, y, Color(sum.r / n / a, sum.g / n / a, sum.b / n / a, a))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img
