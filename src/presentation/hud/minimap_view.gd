class_name MinimapView
extends Control
## One picture of the minimap (PLAN v0.3.0 MM), drawn in a single _draw() and redrawn only when the map changes or
## the player moves a pixel or turns: no nodes per room. The corner map is a window that scrolls with you at a fixed
## scale; the full map fits the whole floor in the middle of the screen, with a legend. Both turn with the iso camera
## (up on the map is up on screen). Reads WorldReader and a MinimapState; writes neither.

const C45 := 0.70710678118654752
## Door sides: direction from room .x to room .y for door angles 0, 1024, 2048, 3072.
const SIDES: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
## Legend rows: [icon, locale key].
const LEGEND: Array = [
	[&"player", "MAP_LEGEND_YOU"],
	[&"room", "MAP_LEGEND_ROOM"],
	[&"unexplored", "MAP_LEGEND_UNEXPLORED"],
	[&"altar", "MAP_LEGEND_ALTAR"],
	[&"chest", "MAP_LEGEND_CHEST"],
	[&"boss", "MAP_LEGEND_BOSS"],
	[&"portal", "MAP_LEGEND_PORTAL"],
	[&"shrine", "MAP_LEGEND_SHRINE"],
	[&"overrun", "MAP_LEGEND_OVERRUN"],  # v0.4.0 AB
]

## True for the full map.
var full := false
var reader: WorldReader
var state: MinimapState

## The sim point drawn at _origin, the pixels per metre, and the pixel the centre lands on.
var _centre := Vector2.ZERO
var _scale := MinimapStyle.CORNER_PX_PER_M
var _origin := Vector2.ZERO
var _drawn_revision := -1
var _drawn_player := Vector2.INF
var _drawn_aim := -1
var _drawn_size := Vector2.ZERO
var _draws := 0


func _init(p_full: bool = false) -> void:
	full = p_full
	name = "FullMap" if full else "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if full:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		visible = false
	else:
		clip_contents = true
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		custom_minimum_size = MinimapStyle.CORNER_SIZE
		size = MinimapStyle.CORNER_SIZE
		offset_left = -MinimapStyle.CORNER_RIGHT - MinimapStyle.CORNER_SIZE.x
		offset_right = -MinimapStyle.CORNER_RIGHT
		offset_top = MinimapStyle.CORNER_TOP
		offset_bottom = MinimapStyle.CORNER_TOP + MinimapStyle.CORNER_SIZE.y


## Redraws when the picture would change: the map's revision, the player's pixel or facing, or the view's size.
func refresh() -> void:
	if reader == null or state == null or not is_visible_in_tree():
		return
	var px := (reader.player_pos() * _scale).round()
	if (
		state.revision != _drawn_revision
		or px != _drawn_player
		or reader.aim_angle() != _drawn_aim
		or size != _drawn_size
	):
		_drawn_revision = state.revision
		_drawn_player = px
		_drawn_aim = reader.aim_angle()
		_drawn_size = size
		queue_redraw()


## How many times it has drawn (tests check it doesn't redraw every frame for nothing).
func draw_count() -> int:
	return _draws


## Where sim point p lands in this view's pixels.
func to_map(p: Vector2) -> Vector2:
	return _origin + _turn(p - _centre) * _scale


## A sim-plane offset turned to the screen's axes, as the iso camera shows it (IsoRig: yaw +45 degrees about +Y,
## sim (x, y) is 3D (x, -y)): screen right is sim (+1, +1) / sqrt 2 and screen up (away from the camera) is
## sim (-1, +1) / sqrt 2. v0.3.5 F14: the vertical used to be (y - x), which mirrored the map top to bottom.
static func turn(v: Vector2) -> Vector2:
	return Vector2((v.x + v.y) * C45, (v.x - v.y) * C45 * MinimapStyle.SQUASH)


func _turn(v: Vector2) -> Vector2:
	return turn(v)


func _draw() -> void:
	_draws += 1
	if reader == null or state == null or not reader.has_floor():
		return
	var map_rect := _place()
	var panel := StyleBoxFlat.new()
	panel.bg_color = MinimapStyle.PANEL
	panel.border_color = MinimapStyle.PANEL_EDGE
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(MinimapStyle.CORNER_RADIUS)
	if full:
		draw_rect(Rect2(Vector2.ZERO, size), MinimapStyle.BACKDROP)
		var whole := map_rect.grow(24)
		whole.size.x += MinimapStyle.LEGEND_WIDTH
		draw_style_box(panel, whole)
	else:
		draw_style_box(panel, Rect2(Vector2.ZERO, size))
	_draw_rooms()
	_draw_doors()
	_draw_icons()
	_draw_player()
	if full:
		_draw_legend(Vector2(map_rect.end.x + 40, map_rect.position.y))


## Sets the centre, scale and origin; returns the rect the floor is drawn in.
func _place() -> Rect2:
	if not full:
		_scale = MinimapStyle.CORNER_PX_PER_M
		_centre = reader.player_pos()
		_origin = size * 0.5
		return Rect2(Vector2.ZERO, size)
	# The whole floor (every room, known or not, so the scale never jumps) fits the screen's share, legend beside.
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for r in reader.floor_room_count():
		for c in _corners(reader.floor_room(r)):
			var t := _turn(c)
			lo = lo.min(t)
			hi = hi.max(t)
	var avail := size * MinimapStyle.FULL_SHARE - Vector2(MinimapStyle.LEGEND_WIDTH, 0)
	var extent := (hi - lo).max(Vector2.ONE)
	_scale = minf(avail.x / extent.x, avail.y / extent.y)
	var drawn := extent * _scale
	var top_left := (size - drawn - Vector2(MinimapStyle.LEGEND_WIDTH, 0)) * 0.5
	_centre = Vector2.ZERO
	_origin = top_left - lo * _scale
	return Rect2(top_left, drawn)


func _corners(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	)


func _poly(r: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for c in _corners(r):
		out.append(to_map(c))
	return out


func _draw_rooms() -> void:
	for r in reader.floor_room_count():
		if not state.is_discovered(r) or r == state.current:
			continue
		draw_colored_polygon(_poly(reader.floor_room(r)), MinimapStyle.ROOM_FILL)
		_outline(r, MinimapStyle.ROOM_EDGE, MinimapStyle.LINE)
	if state.is_discovered(state.current):
		draw_colored_polygon(_poly(reader.floor_room(state.current)), MinimapStyle.CURRENT_FILL)
		_outline(state.current, MinimapStyle.CURRENT_EDGE, 2.0)


## A room's four walls, broken where its doorways open.
func _outline(room: int, col: Color, width: float) -> void:
	var r := reader.floor_room(room)
	var cs := _corners(r)
	for side in 4:
		# Corners in order: (lo, lo), (hi, lo), (hi, hi), (lo, hi); edge k runs from corner k to corner k + 1.
		var a := cs[side]
		var b := cs[(side + 1) % 4]
		var along := (b - a).normalized()
		var cuts: Array[Vector2] = []
		for i in reader.floor_door_count():
			var d := reader.floor_door_rooms(i)
			if d.x != room and d.y != room:
				continue
			var dr := reader.floor_door_rect(i).grow(0.05)
			if not _touches(dr, a, b):
				continue
			var t0 := (dr.position - a).dot(along)
			var t1 := (dr.end - a).dot(along)
			cuts.append(Vector2(minf(t0, t1), maxf(t0, t1)))
		cuts.sort_custom(func(u: Vector2, v: Vector2) -> bool: return u.x < v.x)
		var t := 0.0
		var length := a.distance_to(b)
		for c in cuts:
			if c.x > t:
				MinimapStyle.glow_line(
					self, to_map(a + along * t), to_map(a + along * c.x), col, width
				)
			t = maxf(t, c.y)
		if t < length:
			MinimapStyle.glow_line(self, to_map(a + along * t), to_map(b), col, width)


## Door rect dr meets the wall face from a to b (an axis-aligned segment).
func _touches(dr: Rect2, a: Vector2, b: Vector2) -> bool:
	var seg := Rect2(a, Vector2.ZERO).expand(b)
	return dr.intersects(seg.grow(0.01), true)


## Known doorways: the passage through the wall, its two sides; one into an unexplored room gets a stub and an
## arrowhead past it.
func _draw_doors() -> void:
	var boss_door := reader.floor_boss_door()
	var over: Dictionary = reader.overrun()  # v0.4.0 AB: the Overrun room's doorways in red
	var over_doors: PackedInt32Array = over["doors"] if over["active"] else PackedInt32Array()
	for i in reader.floor_door_count():
		if not state.door_known(reader, i):
			continue
		var rect := reader.floor_door_rect(i)
		var side := SIDES[(reader.floor_door_angle(i) / 1024) % 4]
		var d := reader.floor_door_rooms(i)
		draw_colored_polygon(_poly(rect), MinimapStyle.ROOM_FILL)
		var half := rect.size * 0.5
		var across := Vector2(side.y, side.x).abs() * half
		var depth := side.abs() * half
		var c := rect.get_center()
		for s: float in [-1.0, 1.0]:
			var e := c + across * s
			MinimapStyle.glow_line(
				self, to_map(e - depth), to_map(e + depth), MinimapStyle.ROOM_EDGE
			)
		var boss := i == boss_door
		if boss or over_doors.has(i):
			_draw_boss_door(rect, side, MinimapStyle.BOSS if boss else MinimapStyle.OVERRUN)
		if not state.door_to_unknown(reader, i):
			continue
		var into := side if state.is_discovered(d.x) else -side
		var from := c + into * absf(depth.dot(side))
		var a := to_map(from)
		var b := to_map(from + into * MinimapStyle.STUB_M)
		var px := clampf(a.distance_to(b), MinimapStyle.STUB_MIN_PX, MinimapStyle.STUB_MAX_PX)
		b = a + (b - a).normalized() * px
		var col := MinimapStyle.BOSS if boss else MinimapStyle.UNEXPLORED
		_arrow(
			a, b, col, minf(MinimapStyle.STUB_HEAD_M * _scale, MinimapStyle.STUB_MAX_PX * 0.4), 2.5
		)


func _draw_boss_door(rect: Rect2, side: Vector2, col: Color = MinimapStyle.BOSS) -> void:
	var across := Vector2(side.y, side.x).abs() * rect.size * 0.5
	var c := rect.get_center()
	var w := 3.0 if full else 2.5
	MinimapStyle.glow_line(self, to_map(c - across), to_map(c + across), col, w)


func _arrow(a: Vector2, b: Vector2, col: Color, head: float, width: float = 2.0) -> void:
	MinimapStyle.glow_line(self, a, b, col, width)
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	var h := maxf(head, 5.0)
	var tri := PackedVector2Array(
		[b + dir * h * 0.6, b - dir * h * 0.4 + n * h * 0.5, b - dir * h * 0.4 - n * h * 0.5]
	)
	draw_colored_polygon(tri, col)


func _icon_scale() -> float:
	return 1.4 if full else 1.0


func _draw_icons() -> void:
	var k := _icon_scale()
	for i in state.visible_rewards(reader):
		var p := to_map(reader.reward_pos(i))
		if reader.reward_kind(i) == WorldReader.REWARD_ALTAR:
			draw_icon(&"altar", p, k)
		else:
			draw_icon(&"chest" if reader.reward_affordable(i) else &"chest_poor", p, k)
	if reader.has_gamble() and state.is_discovered(reader.floor_room_of(reader.gamble_pos())):
		draw_icon(&"shrine", to_map(reader.gamble_pos()), k)  # v0.3.0 L19: the gamble shrine
	var over := reader.overrun()  # v0.4.0 AB: the Overrun room, once seen (dim once cleared)
	if over["active"] and state.is_discovered(over["room"]):
		draw_icon(&"overrun_cleared" if over["cleared"] else &"overrun", to_map(over["center"]), k)
	if state.is_discovered(reader.floor_portal_room()):
		draw_icon(
			&"portal" if reader.portal_active() else &"portal_sealed",
			to_map(reader.portal_pos()),
			k
		)


func _draw_player() -> void:
	var a := float(reader.aim_angle()) * TAU / 4096.0
	var dir := _turn(Vector2(cos(a), sin(a))).normalized()
	_draw_player_arrow(to_map(reader.player_pos()), dir, _icon_scale())


func _draw_player_arrow(p: Vector2, dir: Vector2, k: float) -> void:
	var s := MinimapStyle.PLAYER_ICON * k
	var n := Vector2(-dir.y, dir.x)
	var tri := PackedVector2Array(
		[
			p + dir * s,
			p - dir * s * 0.6 + n * s * 0.65,
			p - dir * s * 0.3,
			p - dir * s * 0.6 - n * s * 0.65
		]
	)
	draw_circle(p, s * 1.3, Color(MinimapStyle.PLAYER, 0.18))
	draw_colored_polygon(tri, MinimapStyle.PLAYER)


## One legend or map icon at p, `k` times the corner size.
func draw_icon(kind: StringName, p: Vector2, k: float = 1.0) -> void:
	var s := MinimapStyle.ICON * k
	match kind:
		&"player":
			_draw_player_arrow(p, Vector2(0, -1), k)
		&"room":
			var r := Rect2(p - Vector2(s * 1.6, s), Vector2(s * 3.2, s * 2))
			draw_rect(r, MinimapStyle.ROOM_FILL)
			draw_rect(r, MinimapStyle.ROOM_EDGE, false, MinimapStyle.LINE)
		&"unexplored":
			_arrow(p - Vector2(s * 1.6, 0), p + Vector2(s * 0.8, 0), MinimapStyle.UNEXPLORED, s)
		&"altar":
			var dia := PackedVector2Array(
				[p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]
			)
			draw_circle(p, s * 1.5, Color(MinimapStyle.ALTAR, MinimapStyle.GLOW_ALPHA))
			draw_colored_polygon(dia, MinimapStyle.ALTAR)
		&"chest":
			draw_circle(p, s * 1.5, Color(MinimapStyle.CHEST, MinimapStyle.GLOW_ALPHA))
			draw_rect(Rect2(p - Vector2(s, s * 0.75), Vector2(s * 2, s * 1.5)), MinimapStyle.CHEST)
		&"chest_poor":
			draw_rect(
				Rect2(p - Vector2(s, s * 0.75), Vector2(s * 2, s * 1.5)),
				MinimapStyle.CHEST_POOR,
				false,
				1.5
			)
		&"boss":
			MinimapStyle.glow_line(
				self, p - Vector2(s * 1.6, 0), p + Vector2(s * 1.6, 0), MinimapStyle.BOSS, 3.0
			)
		&"portal":
			draw_circle(p, s * 1.9, Color(MinimapStyle.PORTAL_OPEN, 0.25))
			draw_arc(p, s * 1.1, 0.0, TAU, 20, MinimapStyle.PORTAL_OPEN, 2.0, true)
			draw_circle(p, s * 0.55, MinimapStyle.PORTAL_OPEN)
		&"shrine":
			var tri := PackedVector2Array(
				[p + Vector2(0, -s * 1.2), p + Vector2(s, s * 0.8), p + Vector2(-s, s * 0.8)]
			)
			draw_circle(p, s * 1.5, Color(MinimapStyle.SHRINE, MinimapStyle.GLOW_ALPHA))
			draw_colored_polygon(tri, MinimapStyle.SHRINE)
		&"overrun", &"overrun_cleared":  # v0.4.0 AB: a red crossed-swords mark in a square
			var col := MinimapStyle.OVERRUN if kind == &"overrun" else MinimapStyle.PORTAL_SEALED
			if kind == &"overrun":
				draw_circle(p, s * 1.6, Color(col, MinimapStyle.GLOW_ALPHA))
			draw_rect(Rect2(p - Vector2(s, s), Vector2(s * 2, s * 2)), col, false, 2.0)
			draw_line(p - Vector2(s, s) * 0.7, p + Vector2(s, s) * 0.7, col, 2.0)
			draw_line(p + Vector2(-s, s) * 0.7, p + Vector2(s, -s) * 0.7, col, 2.0)
		&"portal_sealed":
			draw_arc(p, s * 1.1, 0.0, TAU, 20, MinimapStyle.PORTAL_SEALED, 1.5, true)


func _draw_legend(at: Vector2) -> void:
	var font := get_theme_default_font()
	draw_string(
		font,
		at + Vector2(0, MinimapStyle.TITLE_SIZE),
		tr("MAP_TITLE"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		MinimapStyle.TITLE_SIZE,
		MinimapStyle.TEXT
	)
	var y := at.y + MinimapStyle.TITLE_SIZE + 30
	for row: Array in LEGEND:
		draw_icon(row[0], Vector2(at.x + 16, y), 1.4)
		draw_string(
			font,
			Vector2(at.x + 44, y + MinimapStyle.FONT_SIZE * 0.35),
			tr(row[1]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			MinimapStyle.FONT_SIZE,
			MinimapStyle.TEXT_DIM
		)
		y += 38
	draw_string(
		font,
		Vector2(at.x, y + 18),
		tr("MAP_ROOMS") % [state.discovered_count(), reader.floor_room_count()],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		MinimapStyle.FONT_SIZE,
		MinimapStyle.TEXT
	)
