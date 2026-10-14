class_name StoneBox
extends StyleBox
## v0.8.0 MU (owner O14, G2 "menu style B"): one carved slab of the Ember stone look (EmberStone) as a style box, so
## any Control can wear it (a menu's panel and focused row, a card, a plaque, a tile). Drawn in code from polygons:
## - the shape: a box with its corners cut by `cut`, its edges chipped unevenly (a stable pattern per `pattern`);
## - a soft drop shadow, and the ember glow rising under it (`under`, stronger with `focus`), mostly at the foot;
## - the face: the stone colour lit warm toward the foot, multiplied by the shared grain, with a few carved cracks;
## - the bevel: the lower edges lit by the embers (bright on focus), the upper edges faintly cool, a dark rim;
## - optional inlays: a glowing groove line `inlay_y` px above the foot in `inlay`'s colour, a glowing ring round
##   `ring` (an icon's socket) in `ring_color`, and a gold rim inlay (`rim`) on epic and legendary things.
## `dim` darkens an unfocused slab. Everything outside the rect (shadow, glow) is drawn past its edges; content
## margins are the caller's. Presentation only (EI-07).

## The outline's step between chips (px) and the shadow's offset.
const STEP := 9.0
const SHADOW := Vector2(2, 7)

var pattern := 0:
	set(v):
		pattern = v
		emit_changed()
var cut := 12.0:
	set(v):
		cut = v
		emit_changed()
## How deep the chips bite (px).
var chip := 3.0:
	set(v):
		chip = v
		emit_changed()
## The ember glow under the slab (0..1) and the focus (0..1: the glow grows, the lower bevel lights up).
var under := 0.3:
	set(v):
		under = v
		emit_changed()
var focus := 0.0:
	set(v):
		focus = v
		emit_changed()
## The groove line's colour (alpha 0: none) and its height above the slab's foot (px; < 0: none).
var inlay := Color(0, 0, 0, 0):
	set(v):
		inlay = v
		emit_changed()
var inlay_y := -1.0:
	set(v):
		inlay_y = v
		emit_changed()
## A glowing ring (an icon's socket) in this rect, relative to the slab's top left (size 0: none), and its colour.
var ring := Rect2():
	set(v):
		ring = v
		emit_changed()
var ring_color := Color(0, 0, 0, 0):
	set(v):
		ring_color = v
		emit_changed()
## The rim inlay's colour (alpha 0: none): EmberStone.GOLD on an epic or legendary thing.
var rim := Color(0, 0, 0, 0):
	set(v):
		rim = v
		emit_changed()
## The face's brightness (an unfocused card is a little dimmer).
var dim := 1.0:
	set(v):
		dim = v
		emit_changed()
var cracks := 2:
	set(v):
		cracks = v
		emit_changed()
var shadow := true:
	set(v):
		shadow = v
		emit_changed()
var fill := EmberStone.STONE:
	set(v):
		fill = v
		emit_changed()


## A slab with these content margins (left / right, top / bottom px).
static func make(margin: Vector2 = Vector2.ZERO, p_pattern: int = 0) -> StoneBox:
	var b := StoneBox.new()
	b.pattern = p_pattern
	b.content_margin_left = margin.x
	b.content_margin_right = margin.x
	b.content_margin_top = margin.y
	b.content_margin_bottom = margin.y
	return b


## The chipped outline of a slab over `rect`: [points, outward normals] (closed, clockwise from the top left).
func outline(rect: Rect2) -> Array:
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.3)
	var p := rect.position
	var e := rect.end
	var corners := PackedVector2Array(
		[
			Vector2(p.x + c, p.y),
			Vector2(e.x - c * 0.6, p.y),
			Vector2(e.x, p.y + c * 0.6),
			Vector2(e.x, e.y - c),
			Vector2(e.x - c, e.y),
			Vector2(p.x + c * 0.7, e.y),
			Vector2(p.x, e.y - c * 0.7),
			Vector2(p.x, p.y + c),
		]
	)
	var depth := minf(chip, minf(rect.size.x, rect.size.y) * 0.06)
	var pts := PackedVector2Array()
	var nrm := PackedVector2Array()
	var n := 0
	for k in corners.size():
		var a := corners[k]
		var b := corners[(k + 1) % corners.size()]
		var along := b - a
		var seg := along.length()
		if seg < 0.01:
			continue
		var out := Vector2(along.y, -along.x) / seg  # clockwise in screen space: the outward side
		var steps := maxi(1, int(seg / STEP))
		for s in steps:
			var t := float(s) / steps
			var q := a + along * t
			var bite := 0.0
			if s > 0:
				bite = depth * EmberStone.hash01(pattern, n)
				if EmberStone.hash01(pattern + 97, n) > 0.9:
					bite += depth * 1.8
			pts.append(q - out * bite)
			nrm.append(out)
			n += 1
	return [pts, nrm]


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x < 4.0 or rect.size.y < 4.0:
		return
	var shape := outline(rect)
	var pts: PackedVector2Array = shape[0]
	var nrm: PackedVector2Array = shape[1]
	var k := clampf(minf(rect.size.x, rect.size.y) / 110.0, 0.45, 1.3)
	var rs := RenderingServer
	if shadow:
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + SHADOW * k)
		_fan(to_canvas_item, sh, rect.get_center() + SHADOW * k, Color(0, 0, 0, 0.42))
		_halo(to_canvas_item, sh, nrm, 9.0 * k, Color(0, 0, 0, 0.42), false)
	var glow := clampf(under * 0.55 + focus * 0.9, 0.0, 1.4)
	if glow > 0.01:
		_halo(
			to_canvas_item,
			pts,
			nrm,
			(8.0 + 14.0 * glow) * k,
			EmberStone.ember(focus, 0.5 * glow),
			true
		)
	_face(to_canvas_item, rect, pts)
	_cracks(to_canvas_item, rect, pts, nrm, k)
	if inlay.a > 0.0 and inlay_y >= 0.0:
		_inlay_line(to_canvas_item, rect, k)
	if ring_color.a > 0.0 and ring.size.x > 0.0:
		_ring(to_canvas_item, Rect2(rect.position + ring.position, ring.size), k)
	if rim.a > 0.0:
		var inset := PackedVector2Array()
		for i in pts.size():
			inset.append(pts[i] - nrm[i] * 8.0 * k)
		inset.append(inset[0])
		rs.canvas_item_add_polyline(
			to_canvas_item, inset, PackedColorArray([Color(rim, 0.2 * rim.a)]), 5.0 * k, true
		)
		rs.canvas_item_add_polyline(
			to_canvas_item, inset, PackedColorArray([Color(rim, 0.9 * rim.a)]), 1.6 * k, true
		)
	_bevel(to_canvas_item, pts, nrm, k)


## The face: a fan from the centre, lit warm toward the foot, over the grain.
func _face(ci: RID, rect: Rect2, pts: PackedVector2Array) -> void:
	var centre := rect.get_center()
	var all := PackedVector2Array([centre])
	all.append_array(pts)
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var span := maxf(EmberStone.GRAIN_PX, maxf(rect.size.x, rect.size.y)) / 0.7
	var off := Vector2(EmberStone.hash01(pattern, 7), EmberStone.hash01(pattern, 11)) * 0.3
	for p in all:
		var t := clampf((p.y - rect.position.y) / rect.size.y, 0.0, 1.0)
		var c := Color(fill.r, fill.g, fill.b) * lerpf(0.8, 1.12, t) * (1.45 * dim)
		var warm := pow(t, 4.0) * (0.03 + 0.1 * under + 0.2 * focus)
		c += Color(EmberStone.EMBER.r, EmberStone.EMBER.g, EmberStone.EMBER.b) * warm * 1.6
		c.a = fill.a
		cols.append(c)
		uvs.append(off + (p - rect.position) / span)
	var idx := PackedInt32Array()
	for i in pts.size():
		idx.append_array([0, 1 + i, 1 + (i + 1) % pts.size()])
	RenderingServer.canvas_item_add_triangle_array(
		ci,
		idx,
		all,
		cols,
		uvs,
		PackedInt32Array(),
		PackedFloat32Array(),
		EmberStone.grain().get_rid()
	)


## A few carved cracks running in from the edges (stable per pattern).
func _cracks(
	ci: RID, rect: Rect2, pts: PackedVector2Array, nrm: PackedVector2Array, k: float
) -> void:
	var reach := minf(rect.size.x, rect.size.y) * 0.34
	for j in cracks:
		var at := int(EmberStone.hash01(pattern + 31, j) * pts.size()) % pts.size()
		var p := pts[at] - nrm[at] * 2.0
		var dir := -nrm[at]
		var line := PackedVector2Array([p])
		var walked := 0.0
		var s := 0
		while walked < reach and s < 8:
			var turn := (EmberStone.hash01(pattern + 53 + j, s) - 0.5) * 1.1
			dir = dir.rotated(turn).normalized()
			var step := reach * (0.12 + 0.1 * EmberStone.hash01(pattern + 71 + j, s))
			p += dir * step
			if not rect.grow(-3.0).has_point(p):
				break
			line.append(p)
			walked += step
			s += 1
		if line.size() < 2:
			continue
		var lit := PackedVector2Array()
		for q in line:
			lit.append(q + Vector2(0, 1.0))
		RenderingServer.canvas_item_add_polyline(
			ci, lit, PackedColorArray([Color(1, 0.9, 0.8, 0.05)]), 1.0 * k, true
		)
		RenderingServer.canvas_item_add_polyline(
			ci, line, PackedColorArray([Color(EmberStone.GROOVE, 0.55)]), 1.3 * k, true
		)


## The bevel: warm light on the lower edges, faint cool light on the upper ones, and the dark outer rim.
func _bevel(ci: RID, pts: PackedVector2Array, nrm: PackedVector2Array, k: float) -> void:
	var inner := PackedVector2Array()
	var cols := PackedColorArray()
	for i in pts.size():
		inner.append(pts[i] - nrm[i] * 2.0 * k)
		var ny := nrm[i].y
		if ny > 0.0:
			cols.append(EmberStone.ember(focus, ny * (0.16 + 0.7 * focus + 0.12 * under)))
		else:
			cols.append(Color(1.0, 0.95, 0.88, 0.1 * -ny + 0.02))
	inner.append(inner[0])
	cols.append(cols[0])
	RenderingServer.canvas_item_add_polyline(ci, inner, cols, 2.6 * k, true)
	var loop := pts.duplicate()
	loop.append(pts[0])
	RenderingServer.canvas_item_add_polyline(
		ci, loop, PackedColorArray([Color(EmberStone.GROOVE, 0.92)]), 1.6, true
	)


## A soft band outside the outline (`width` px), `col` at the edge fading to nothing; `foot` keeps it to the lower
## edges (the ember glow rises from below).
func _halo(
	ci: RID, pts: PackedVector2Array, nrm: PackedVector2Array, width: float, col: Color, foot: bool
) -> void:
	var points := PackedVector2Array()
	var cols := PackedColorArray()
	for i in pts.size():
		var a := col.a
		if foot:
			a *= clampf(nrm[i].y * 0.85 + 0.35, 0.0, 1.0)
		points.append(pts[i])
		points.append(pts[i] + nrm[i] * width)
		cols.append(Color(col, a))
		cols.append(Color(col, 0.0))
	var idx := PackedInt32Array()
	var n := pts.size()
	for i in n:
		var a := i * 2
		var b := ((i + 1) % n) * 2
		idx.append_array([a, a + 1, b + 1, a, b + 1, b])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, points, cols)


## A plain fan of one colour (the shadow).
func _fan(ci: RID, pts: PackedVector2Array, centre: Vector2, col: Color) -> void:
	var all := PackedVector2Array([centre])
	all.append_array(pts)
	var idx := PackedInt32Array()
	for i in pts.size():
		idx.append_array([0, 1 + i, 1 + (i + 1) % pts.size()])
	var cols := PackedColorArray()
	cols.resize(all.size())
	cols.fill(col)
	RenderingServer.canvas_item_add_triangle_array(ci, idx, all, cols)


## The inlay groove line, fading at both ends, with its glow.
func _inlay_line(ci: RID, rect: Rect2, k: float) -> void:
	var y := rect.end.y - inlay_y
	var x0 := rect.position.x + maxf(cut, rect.size.x * 0.1)
	var x1 := rect.end.x - maxf(cut, rect.size.x * 0.1)
	if x1 <= x0:
		return
	var line := PackedVector2Array()
	var cols := PackedColorArray()
	var glow := PackedColorArray()
	for i in 7:
		var t := i / 6.0
		line.append(Vector2(lerpf(x0, x1, t), y))
		var a := inlay.a * sin(t * PI)
		cols.append(Color(inlay.lightened(0.2), a * 0.95))
		glow.append(Color(inlay, a * 0.22))
	RenderingServer.canvas_item_add_polyline(ci, line, glow, 7.0 * k, true)
	RenderingServer.canvas_item_add_polyline(ci, line, cols, 1.8 * k, true)


## A round socket with its glowing inlay ring.
func _ring(ci: RID, r: Rect2, k: float) -> void:
	InlaySocket.draw_socket(
		ci, r.get_center(), minf(r.size.x, r.size.y) * 0.5, ring_color, focus, k
	)
