class_name PlaqueBox
extends StoneBox
## A wide stone plaque (Plaques) as a style box (v0.6.1 R1 as the owner's crystal plaques; v0.8.0 MU, owner O14, a
## carved Ember stone slab, StoneBox): chipped edges, the ember glow under it, and a glowing inlay groove along its
## foot in the plaque's colour (a family's, CardFrames), with a gold rim inlay on the gold plaque (an epic card, the
## banner). It fits any width and height; its content margins put the text inside, clear of the groove. `focused`
## lights it (the glow grows, the lower edge lights up); an unfocused plaque is drawn a little dimmer.
## v0.10.5 W3-O19 (owner 2026-11-04 night: "remake every single UI element into this new style"; Astral,
## W3_O13_UI_STYLE_G2.md round 2): drawn in the Astral style now, the stone's fields kept as its data (the plaque's
## colour, focus, dim): an ink fill, a 1 px contour with 6 px cut corners and an inner contour 6 px in at 28 %, a small
## diamond on each side's middle; the gold plaque's contour in the pale gold. A plaque that takes focus (an event's
## choice: set_focused was called) shows Astral's focus when focused: the contour brightens (1.4 px), a second contour
## sits 6 px outside at 25 %, a faint accent wash, two sparks at its corners. A plaque that never takes focus (a
## banner, an item card) stays calm. Every line is on whole pixels; only the corner cuts are antialiased.
## Presentation only (EI-07).

## Margins as shares of the plaque's height: the sides, the top, and the foot (which holds the groove).
const SIDE := 0.2
const TOP := 0.16
const FOOT := 0.22
## The groove's height above the foot, as a share of the height.
const GROOVE := 0.11

var plaque := &"amber"
## The plaque's height (px); its margins follow it.
var height := 100.0
var pad := 0.0
var focused := true
## True once set_focused was called (a plaque you choose); only such a plaque draws the focus ring.
var interactive := false


func _init(p_plaque: StringName = &"amber", p_height: float = 100.0, p_pad: float = 0.0) -> void:
	height = p_height
	pad = p_pad
	cut = clampf(p_height * 0.14, 6.0, 16.0)
	chip = clampf(p_height * 0.03, 1.5, 3.5)
	pattern = int(p_height * 13.0) % 97
	cracks = 2
	_margins()
	set_plaque(p_plaque)
	_apply()


func set_plaque(p: StringName) -> void:
	plaque = p
	inlay = Plaques.tint(p)
	inlay_y = height * GROOVE
	rim = EmberStone.GOLD if p == &"gold" else Color(0, 0, 0, 0)


func set_focused(on: bool) -> void:
	if not interactive:
		interactive = true
		emit_changed()
	if on == focused:
		return
	focused = on
	_apply()


## The face's brightness now (1 focused, Plaques.IDLE otherwise).
func tint() -> float:
	return dim


## The smallest a host should be (px): wide enough for the cut corners and the groove.
func natural_size() -> Vector2:
	return Vector2(height * 2.0, height)


## The content margins of a plaque `h` px tall with `p` px of extra side padding: left, top, right, bottom.
static func margins(h: float, p: float = 0.0) -> Vector4:
	return Vector4(h * SIDE + p, h * TOP, h * SIDE + p, h * FOOT)


func _apply() -> void:
	focus = 1.0 if focused else 0.0
	under = 0.3
	dim = 1.0 if focused else Plaques.IDLE


func _margins() -> void:
	var m := margins(height, pad)
	content_margin_left = m.x
	content_margin_top = m.y
	content_margin_right = m.z
	content_margin_bottom = m.w


## The Astral plaque (see the header); nothing is drawn past the rect but the focus ring and sparks.
func _draw(to: RID, rect: Rect2) -> void:
	var o := AstralChrome.px(rect)
	var cut := 6.0
	var pts := PackedVector2Array(
		[
			o.position + Vector2(cut, 0),
			Vector2(o.end.x - cut, o.position.y),
			Vector2(o.end.x, o.position.y + cut),
			o.end - Vector2(0, cut),
			o.end - Vector2(cut, 0),
			Vector2(o.position.x + cut, o.end.y),
			Vector2(o.position.x, o.end.y - cut),
			o.position + Vector2(0, cut),
		]
	)
	var lit := focused and interactive
	var line := AstralCardArt.LINE_HI if lit else AstralCardArt.LINE
	if plaque == &"gold":
		line = AstralCardArt.rarity(4) if not lit else AstralCardArt.LINE_HI
	line.a *= clampf(dim, 0.0, 1.0)
	var rs := RenderingServer
	rs.canvas_item_add_polygon(
		to, pts, PackedColorArray([AstralChrome.FILL_HI if lit else AstralChrome.FILL])
	)
	if lit:
		rs.canvas_item_add_polygon(
			to,
			AstralChrome.contour(pts, -3.0),
			PackedColorArray([Color(AstralCardArt.ACCENT, 0.08)])
		)
		_loop(to, AstralChrome.contour(pts, 6.0), Color(AstralCardArt.LINE_HI, 0.25), 1.0)
	_loop(to, AstralChrome.contour(pts, -6.0), Color(line, 0.28), 1.0)
	_loop(to, pts, line, 1.4 if lit else 1.0)
	var cy := roundf(o.get_center().y) + 0.5
	for x: float in [o.position.x, o.end.x]:
		AstralUi.diamond(
			to, Vector2(x, cy), 4.0 if lit else 3.5, line, line if lit else AstralChrome.INK
		)
	if lit:  # two sparks off the sides, past the outer contour
		for sx: float in [-1.0, 1.0]:
			var x: float = (o.position.x - 16.0) if sx < 0.0 else (o.end.x + 16.0)
			AstralUi.star(to, Vector2(roundf(x) + 0.5, cy), 6.0, AstralCardArt.LINE_HI, 0.2)


func _loop(to: RID, pts: PackedVector2Array, col: Color, w: float) -> void:
	var out := pts.duplicate()
	out.append(pts[0])
	RenderingServer.canvas_item_add_polyline(to, out, PackedColorArray([col]), w, true)
