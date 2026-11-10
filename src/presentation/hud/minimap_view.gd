class_name MinimapView
extends Control
## One picture of the minimap (PLAN v0.3.0 MM), drawn in a single _draw() and redrawn only when the map changes or
## the player moves a pixel or turns: no nodes per room. The corner map is a window that scrolls with you at a fixed
## scale; the full map fits the whole floor in the middle of the screen, with a legend. Both turn with the iso camera
## (up on the map is up on screen). Reads WorldReader and a MinimapState; writes neither.
## v0.10.5 W3-V3 (DRAW_GROWTH: ~470 drawn objects per room found, 85-88 % of a late floor's frame): the rooms, doors,
## icons (and the full map's backdrop, panel and legend) are drawn once into a texture, a SubViewport rendered once
## (UPDATE_ONCE) each time MinimapState.revision, the view's size, its screen scale or the language changes. Each
## frame draws that texture (one object; the corner scrolls it under the hero, snapped to whole screen pixels) and,
## live, the hero's arrow and the corner ticks. The texture is rendered at the screen's own pixel density, so it is
## never scaled; it holds premultiplied colour and is drawn with a premultiplied-alpha blend, which composites exactly
## as drawing the shapes straight onto the screen did. A floor too big for a texture falls back to the direct draw.

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
	[&"portal_deep", "MAP_LEGEND_PORTAL_DEEP"],
	[&"shrine", "MAP_LEGEND_SHRINE"],
	[&"event", "MAP_LEGEND_EVENT"],
	[&"overrun", "MAP_LEGEND_OVERRUN"],  # v0.4.0 AB
	[&"arena", "MAP_LEGEND_ARENA"],  # v0.5.5 AR
	[&"shop", "MAP_LEGEND_SHOP"],
]
## v0.9.0 RB: A4 Astral's secret mark (the void violet) and its legend row, shown only with Astral.
const SECRET := Color("#A982FF")
const LEGEND_SECRET: Array = [&"secret", "MAP_LEGEND_SECRET"]
## W3-V3: the corner layer's margin around the floor's rooms (px at the corner's scale): the stubs (34 px at most),
## their heads, the glow and the icons' halos all fit inside it.
const LAYER_MARGIN := 48.0
## W3-V3: the largest texture side the layer uses; a bigger floor draws directly, as before.
const LAYER_MAX_PX := 8192

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
var _drawn_move := Vector2i.ZERO
## The arrow's last direction in the sim plane: the walk direction, else the last one, else the aim (W3-S8).
var _arrow_dir := Vector2.ZERO
var _drawn_size := Vector2.ZERO
var _draws := 0

## W3-V3: where the draw calls go (this view, or the layer while it is rendered).
var _ci: CanvasItem
## The layer: a SubViewport holding one Node2D that draws the map's static part; the image shows its texture.
var _layer_vp := SubViewport.new()
var _layer := MapLayer.new()
var _image := Control.new()
## The layer is in use (false: drawn directly); what it was rendered for; how many times it was rendered.
var _cached := false
var _layer_key := ""
var _layer_draws := 0
## The layer's extent in this view's units (the corner: map units with the sim origin at 0; the full map: the view),
## and the screen pixels per unit it was rendered at.
var _layer_frame := Rect2()
var _layer_px := 1.0
## The sub-pixel phase (screen px) the layer was rendered at.
var _layer_sub := Vector2.ZERO
var _locale_gen := 0


## W3-V3: the Node2D inside the layer's SubViewport; its draw is the view's static part.
class MapLayer:
	extends Node2D
	var view: MinimapView

	func _draw() -> void:
		if view != null:
			view.draw_layer(self)


func _init(p_full: bool = false) -> void:
	full = p_full
	name = "FullMap" if full else "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ci = self
	_layer_vp.name = "MapLayerViewport"
	_layer_vp.transparent_bg = true
	_layer_vp.disable_3d = true
	_layer_vp.size = Vector2i.ONE
	_layer_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_layer_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_layer.view = self
	_layer_vp.add_child(_layer)
	add_child(_layer_vp)
	_image.name = "MapLayerImage"
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.show_behind_parent = true  # under the arrow and ticks this view draws itself
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # one texel per screen pixel
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_image.material = mat
	_image.draw.connect(_draw_image)
	add_child(_image)
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
	arrow_dir()
	var rendered := _sync_layer()
	if (
		rendered
		or state.revision != _drawn_revision
		or px != _drawn_player
		or reader.aim_angle() != _drawn_aim
		or reader.move_intent() != _drawn_move
		or size != _drawn_size
	):
		_drawn_revision = state.revision
		_drawn_player = px
		_drawn_aim = reader.aim_angle()
		_drawn_move = reader.move_intent()
		_drawn_size = size
		queue_redraw()
		_image.queue_redraw()


## How many times it has drawn (tests check it doesn't redraw every frame for nothing).
func draw_count() -> int:
	return _draws


## W3-V3: how many times the map's static layer was rendered (once per change of the map, not per step).
func layer_draw_count() -> int:
	return _layer_draws


## W3-V3: the static layer is in use (false: the floor is drawn directly, as before).
func layer_cached() -> bool:
	return _cached


## W3-V3: screen pixels per unit of this view (the window's stretch and every parent's scale).
func _screen_xf() -> Transform2D:
	return get_viewport().get_final_transform() * get_global_transform_with_canvas()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_locale_gen += 1  # the full map's legend is in the layer


## W3-V3: renders the layer again when what it shows changed. True when it did.
func _sync_layer() -> bool:
	if not reader.has_floor():
		return false
	var s := absf(_screen_xf().get_scale().x)
	var key := "%d|%s|%s|%d" % [state.revision, size, s, _locale_gen]
	if key == _layer_key:
		return false
	_layer_key = key
	var frame := Rect2(Vector2.ZERO, size)
	if not full:
		var lo := Vector2.INF
		var hi := -Vector2.INF
		for r in reader.floor_room_count():
			for c in _corners(reader.floor_room(r)):
				var t := _turn(c) * MinimapStyle.CORNER_PX_PER_M
				lo = lo.min(t)
				hi = hi.max(t)
		frame = Rect2(lo, hi - lo).grow(LAYER_MARGIN)
	var px := Vector2i((frame.size * s).ceil())
	_cached = (
		s > 0.0
		and not (not full and draws_backdrop())  # a corner panel would scroll with the map: draw directly
		and px.x >= 1
		and px.y >= 1
		and px.x <= LAYER_MAX_PX
		and px.y <= LAYER_MAX_PX
	)
	if not _cached:
		return true
	_layer_frame = frame
	_layer_px = s
	_layer_vp.size = px
	_layer_sub = _layer_screen_at()
	_layer_sub -= _layer_sub.floor()
	_layer_vp.canvas_transform = Transform2D(
		0.0, Vector2(s, s), 0.0, _layer_sub - frame.position * s
	)
	if "oversampling_override" in _layer_vp:  # the legend's text rasterised at the screen's density
		_layer_vp.set(&"oversampling_override", s)
	_layer.queue_redraw()
	_layer_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	return true


## W3-V3: where the layer's top-left corner falls this frame, in screen pixels (not rounded): the corner scrolls
## the map under the hero (the sim origin at size / 2 - turn(hero)), the full map holds it still.
func _layer_screen_at() -> Vector2:
	var at := _layer_frame.position
	if not full:
		at += size * 0.5 - _turn(reader.player_pos()) * MinimapStyle.CORNER_PX_PER_M
	return get_viewport().get_final_transform() * _image.get_global_transform_with_canvas() * at


## W3-V3: the layer's texture, placed on whole screen pixels so its pixels land 1:1 on the screen's. The layer was
## rendered shifted by the sub-pixel phase the map had then (_layer_sub), so while the hero stands where it was
## rendered the map sits exactly where the direct draw put it; walking, it is within half a pixel, as the direct
## draw's own redraw-per-pixel was.
func _draw_image() -> void:
	if not _cached or reader == null or state == null or not reader.has_floor():
		return
	var xf := get_viewport().get_final_transform() * _image.get_global_transform_with_canvas()
	var at := xf.affine_inverse() * (_layer_screen_at() - _layer_sub).round()
	_image.draw_texture_rect(
		_layer_vp.get_texture(), Rect2(at, Vector2(_layer_vp.size) / _layer_px), false
	)


## W3-V3: the static part, drawn into the layer `ci` (MapLayer._draw): in the corner, at the corner's scale with the
## sim origin at 0; the full map as the view lays it out.
func draw_layer(ci: CanvasItem) -> void:
	if reader == null or state == null or not reader.has_floor():
		return
	_layer_draws += 1
	_ci = ci
	if full:
		var map_rect := _place()
		_draw_full_panel(map_rect)
		_draw_rooms()
		_draw_doors()
		_draw_icons()
		_draw_legend(Vector2(map_rect.end.x + 40, map_rect.position.y))
	else:
		_scale = MinimapStyle.CORNER_PX_PER_M
		_centre = Vector2.ZERO
		_origin = Vector2.ZERO
		_draw_rooms()
		_draw_doors()
		_draw_icons()
		_place()  # back to the live frame (to_map for the hero)
	_ci = self


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
	if not _cached:  # W3-V3: else the layer (drawn behind this view by _image) holds all of this
		if full:
			_draw_full_panel(map_rect)
		elif draws_backdrop():
			draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
		_draw_rooms()
		_draw_doors()
		_draw_icons()
	_draw_player()
	if full:
		if not _cached:
			_draw_legend(Vector2(map_rect.end.x + 40, map_rect.position.y))
	else:
		_draw_corner_ticks()


func _panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = MinimapStyle.PANEL
	panel.border_color = MinimapStyle.PANEL_EDGE
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(MinimapStyle.CORNER_RADIUS)
	return panel


## The full map's dimmed backdrop and its panel around the floor and the legend.
func _draw_full_panel(map_rect: Rect2) -> void:
	_ci.draw_rect(Rect2(Vector2.ZERO, size), MinimapStyle.BACKDROP)
	var whole := map_rect.grow(24)
	whole.size.x += MinimapStyle.LEGEND_WIDTH
	_ci.draw_style_box(_panel(), whole)


## True when this view draws a dark panel behind the map: the full map only (v0.5.5 A5: the corner map floats).
func draws_backdrop() -> bool:
	return full or MinimapStyle.CORNER_PANEL


## v0.5.5 A5: small L-ticks at the corner map's corners, over a dark halo, so its window reads without a
## panel.
func _draw_corner_ticks() -> void:
	_draw_astral_ticks(MinimapStyle.TICK_ARM)  # v0.10.5 W3-O17: Astral's frame (1 px lines, small ornaments)


## v0.10.5 W3-O17: the corner window in Astral: at each corner a 1 px silver L over a dark halo, a fainter inner L 4 px
## in, and a small diamond on the corner; a four-point star under the window's foot and a diamond over its head.
func _draw_astral_ticks(arm: float) -> void:
	var w := roundf(size.x)
	var h := roundf(size.y)
	var halo := Color(MinimapStyle.SHADOW, 0.6)
	for c: Array in [
		[0.0, 0.0, 1.0, 1.0],
		[w - 1.0, 0.0, -1.0, 1.0],
		[w - 1.0, h - 1.0, -1.0, -1.0],
		[0.0, h - 1.0, 1.0, -1.0]
	]:
		var x: float = c[0]
		var y: float = c[1]
		var sx: float = c[2]
		var sy: float = c[3]
		for k: Array in [
			[0.0, MinimapStyle.TICK, arm], [4.0, Color(MinimapStyle.TICK, 0.3), arm * 0.5]
		]:
			var d: float = k[0]
			var col: Color = k[1]
			var a: float = k[2]
			var px := x + sx * d
			var py := y + sy * d
			if d == 0.0:
				_ci.draw_rect(Rect2(minf(px, px + sx * a) - 1.0, py - 1.0, a + 2.0, 3.0), halo)
				_ci.draw_rect(Rect2(px - 1.0, minf(py, py + sy * a) - 1.0, 3.0, a + 2.0), halo)
			AstralChrome.hline(self, px, px + sx * a, py, col)
			AstralChrome.vline(self, px, py, py + sy * a, col)
		AstralChrome.dia(self, Vector2(x + 0.5, y + 0.5), 3.0, MinimapStyle.TICK, HudStyle.A_INK)
	AstralChrome.star4(self, Vector2(roundf(w * 0.5) + 0.5, h + 8.5), 6.0, MinimapStyle.TICK, 0.18)
	AstralChrome.dia(
		self, Vector2(roundf(w * 0.5) + 0.5, -5.5), 2.5, MinimapStyle.TICK, HudStyle.A_INK
	)


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
		if state.hidden.has(r):  # v0.9.0 TD: fitted without the hidden rooms (their size gives nothing away)
			continue
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
		if not draws_backdrop():
			_ci.draw_colored_polygon(_poly(reader.floor_room(r)), MinimapStyle.ROOM_WASH)
		_ci.draw_colored_polygon(_poly(reader.floor_room(r)), MinimapStyle.ROOM_FILL)
		_outline(r, MinimapStyle.ROOM_EDGE, MinimapStyle.LINE)
	if state.is_discovered(state.current):
		if not draws_backdrop():
			_ci.draw_colored_polygon(
				_poly(reader.floor_room(state.current)), MinimapStyle.ROOM_WASH
			)
		_ci.draw_colored_polygon(_poly(reader.floor_room(state.current)), MinimapStyle.CURRENT_FILL)
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
			if (d.x != room and d.y != room) or state.door_hidden(reader, i):  # v0.9.0 TD: a plain wall
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
					_ci, to_map(a + along * t), to_map(a + along * c.x), col, width
				)
			t = maxf(t, c.y)
		if t < length:
			MinimapStyle.glow_line(_ci, to_map(a + along * t), to_map(b), col, width)


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
	var arena_doors := _arena_doors()  # v0.5.5 AR: an arena's doorways in amber (dim once cleared)
	for i in reader.floor_door_count():
		if not state.door_known(reader, i):
			continue
		var rect := reader.floor_door_rect(i)
		var side := SIDES[(reader.floor_door_angle(i) / 1024) % 4]
		var d := reader.floor_door_rooms(i)
		_ci.draw_colored_polygon(_poly(rect), MinimapStyle.ROOM_FILL)
		var half := rect.size * 0.5
		var across := Vector2(side.y, side.x).abs() * half
		var depth := side.abs() * half
		var c := rect.get_center()
		for s: float in [-1.0, 1.0]:
			var e := c + across * s
			MinimapStyle.glow_line(
				_ci, to_map(e - depth), to_map(e + depth), MinimapStyle.ROOM_EDGE
			)
		var boss := i == boss_door
		if boss or over_doors.has(i):
			var shut := MinimapStyle.BOSS_OPEN if reader.portal_active() else MinimapStyle.BOSS  # PB
			_draw_boss_door(rect, side, shut if boss else MinimapStyle.OVERRUN)
		elif arena_doors.has(i):
			_draw_boss_door(rect, side, arena_doors[i])
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


## v0.5.5 AR: doorway -> colour for the discovered regular arenas' doorways (amber; dim once cleared).
func _arena_doors() -> Dictionary:
	var out := {}
	var a := reader.arenas()
	if not a["active"]:
		return out
	var cleared: PackedInt32Array = a["cleared"]
	for i in reader.floor_door_count():
		var d := reader.floor_door_rooms(i)
		for room: int in a["rooms"]:
			if room != a["overrun"] and (d.x == room or d.y == room) and state.is_discovered(room):
				out[i] = (MinimapStyle.PORTAL_SEALED if cleared.has(room) else MinimapStyle.ARENA)
	return out


func _draw_boss_door(rect: Rect2, side: Vector2, col: Color = MinimapStyle.BOSS) -> void:
	var across := Vector2(side.y, side.x).abs() * rect.size * 0.5
	var c := rect.get_center()
	var w := 3.0 if full else 2.5
	MinimapStyle.glow_line(_ci, to_map(c - across), to_map(c + across), col, w)


func _arrow(a: Vector2, b: Vector2, col: Color, head: float, width: float = 2.0) -> void:
	MinimapStyle.glow_line(_ci, a, b, col, width)
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	var h := maxf(head, 5.0)
	var tri := PackedVector2Array(
		[b + dir * h * 0.6, b - dir * h * 0.4 + n * h * 0.5, b - dir * h * 0.4 - n * h * 0.5]
	)
	_ci.draw_colored_polygon(tri, col)


func _icon_scale() -> float:
	return 1.4 if full else 1.0


func _draw_icons() -> void:
	var k := _icon_scale()
	for i in state.visible_rewards(reader):
		var p := to_map(reader.reward_pos(i))
		if reader.reward_kind(i) in [WorldReader.REWARD_ALTAR, WorldReader.REWARD_DROP]:
			draw_icon(&"altar", p, k)
		else:
			draw_icon(&"chest" if reader.reward_affordable(i) else &"chest_poor", p, k)
	# v0.3.0 L19: the gamble shrine; v0.9.0 SH: any shrine kind (Fortune, Blood, Chaos)
	if reader.has_shrine_site() and state.is_discovered(reader.floor_room_of(reader.gamble_pos())):
		draw_icon(&"shrine", to_map(reader.gamble_pos()), k)
	for e in reader.event_count():  # v0.5.0 EV: event pedestals in rooms you have seen
		if state.is_discovered(reader.event_room(e)):
			var spent := reader.event_state(e) == WorldReader.EVENT_DONE
			draw_icon(&"event_spent" if spent else &"event", to_map(reader.event_pos(e)), k)
	var over := reader.overrun()  # v0.4.0 AB: the Overrun room, once seen (dim once cleared)
	if over["active"] and state.is_discovered(over["room"]):
		draw_icon(&"overrun_cleared" if over["cleared"] else &"overrun", to_map(over["center"]), k)
	var ar := reader.arenas()  # v0.5.5 AR: each arena, once seen (dim once cleared)
	if ar["active"]:
		for room: int in ar["rooms"]:
			if room != ar["overrun"] and state.is_discovered(room):
				var done := (ar["cleared"] as PackedInt32Array).has(room)
				draw_icon(
					&"arena_cleared" if done else &"arena",
					to_map(reader.floor_room(room).get_center()),
					k
				)
	if reader.has_shop() and state.is_discovered(reader.shop_room()):
		draw_icon(&"shop", to_map(reader.shop_pos()), k)  # v0.5.0 SH: the shop terminal
	if state.is_discovered(reader.floor_portal_room()):
		draw_icon(
			&"portal" if reader.portal_active() else &"portal_sealed",
			to_map(reader.portal_pos()),
			k
		)
		if reader.has_deep_portal():  # v0.5.0 RT
			draw_icon(
				&"portal_deep" if reader.gate_open(WorldReader.ROUTE_DEEP) else &"portal_sealed",
				to_map(reader.deep_portal_pos()),
				k
			)
	if reader.affinity_maps_secrets():  # v0.9.0 RB: A4 Astral marks a room holding a secret once entered
		for s: Dictionary in reader.secret_spots():
			var room := int(s["room"])
			if state.is_discovered(room) and not bool(s["found"]):
				var at := to_map(reader.floor_room(room).get_center()) + Vector2(9, -9) * k
				draw_icon(&"secret", at, k)


## The arrow's direction in the sim plane. W3-S8 (owner): it follows where the player walks, not only the aim;
## standing still keeps the last walk direction, and a fresh view with no walk shows the aim.
func arrow_dir() -> Vector2:
	if reader == null:
		return _arrow_dir
	var mv := Vector2(reader.move_intent())
	if mv.length() > 0.1:
		_arrow_dir = mv.normalized()
	elif _arrow_dir == Vector2.ZERO:
		var a := float(reader.aim_angle()) * TAU / 4096.0
		_arrow_dir = Vector2(cos(a), sin(a))
	return _arrow_dir


func _draw_player() -> void:
	var dir := _turn(arrow_dir()).normalized()
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
	_ci.draw_circle(p, s * 1.3, Color(MinimapStyle.PLAYER, 0.18))
	var halo := tri.duplicate()
	halo.append(tri[0])
	_ci.draw_polyline(halo, MinimapStyle.SHADOW, MinimapStyle.SHADOW_WIDTH, true)  # v0.5.5 A5
	_ci.draw_colored_polygon(tri, MinimapStyle.PLAYER)


## One legend or map icon at p, `k` times the corner size.
func draw_icon(kind: StringName, p: Vector2, k: float = 1.0) -> void:
	var s := MinimapStyle.ICON * k
	match kind:
		&"player":
			_draw_player_arrow(p, Vector2(0, -1), k)
		&"room":
			var r := Rect2(p - Vector2(s * 1.6, s), Vector2(s * 3.2, s * 2))
			_ci.draw_rect(r, MinimapStyle.ROOM_FILL)
			_ci.draw_rect(r, MinimapStyle.ROOM_EDGE, false, MinimapStyle.LINE)
		&"unexplored":
			_arrow(p - Vector2(s * 1.6, 0), p + Vector2(s * 0.8, 0), MinimapStyle.UNEXPLORED, s)
		&"altar":
			var dia := PackedVector2Array(
				[p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]
			)
			_ci.draw_circle(p, s * 1.5, Color(MinimapStyle.ALTAR, MinimapStyle.GLOW_ALPHA))
			_ci.draw_colored_polygon(dia, MinimapStyle.ALTAR)
		&"chest":
			_ci.draw_circle(p, s * 1.5, Color(MinimapStyle.CHEST, MinimapStyle.GLOW_ALPHA))
			_ci.draw_rect(
				Rect2(p - Vector2(s, s * 0.75), Vector2(s * 2, s * 1.5)), MinimapStyle.CHEST
			)
		&"chest_poor":
			_ci.draw_rect(
				Rect2(p - Vector2(s, s * 0.75), Vector2(s * 2, s * 1.5)),
				MinimapStyle.CHEST_POOR,
				false,
				1.5
			)
		&"boss":
			MinimapStyle.glow_line(
				_ci, p - Vector2(s * 1.6, 0), p + Vector2(s * 1.6, 0), MinimapStyle.BOSS, 3.0
			)
		&"portal":
			_ci.draw_circle(p, s * 1.9, Color(MinimapStyle.PORTAL_OPEN, 0.25))
			_ci.draw_arc(p, s * 1.1, 0.0, TAU, 20, MinimapStyle.PORTAL_OPEN, 2.0, true)
			_ci.draw_circle(p, s * 0.55, MinimapStyle.PORTAL_OPEN)
		&"shrine":
			var tri := PackedVector2Array(
				[p + Vector2(0, -s * 1.2), p + Vector2(s, s * 0.8), p + Vector2(-s, s * 0.8)]
			)
			_ci.draw_circle(p, s * 1.5, Color(MinimapStyle.SHRINE, MinimapStyle.GLOW_ALPHA))
			_ci.draw_colored_polygon(tri, MinimapStyle.SHRINE)
		&"portal_deep":
			_ci.draw_circle(p, s * 1.9, Color(MinimapStyle.PORTAL_DEEP, 0.25))
			_ci.draw_arc(p, s * 1.1, 0.0, TAU, 20, MinimapStyle.PORTAL_DEEP_RIM, 2.0, true)
			_ci.draw_circle(p, s * 0.55, MinimapStyle.PORTAL_DEEP)
		&"event", &"event_spent":
			var hexa := PackedVector2Array()
			for j in 6:
				hexa.append(p + Vector2(cos(TAU * j / 6.0), sin(TAU * j / 6.0)) * s * 1.1)
			var col := MinimapStyle.EVENT if kind == &"event" else Color(MinimapStyle.EVENT, 0.35)
			if kind == &"event":
				_ci.draw_circle(p, s * 1.6, Color(MinimapStyle.EVENT, MinimapStyle.GLOW_ALPHA))
			_ci.draw_colored_polygon(hexa, col)
			_ci.draw_circle(p, s * 0.35, Color(0.05, 0.05, 0.08, 0.9))
		&"overrun", &"overrun_cleared":  # v0.4.0 AB: a red crossed-swords mark in a square
			var col := MinimapStyle.OVERRUN if kind == &"overrun" else MinimapStyle.PORTAL_SEALED
			if kind == &"overrun":
				_ci.draw_circle(p, s * 1.6, Color(col, MinimapStyle.GLOW_ALPHA))
			_ci.draw_rect(Rect2(p - Vector2(s, s), Vector2(s * 2, s * 2)), col, false, 2.0)
			_ci.draw_line(p - Vector2(s, s) * 0.7, p + Vector2(s, s) * 0.7, col, 2.0)
			_ci.draw_line(p + Vector2(-s, s) * 0.7, p + Vector2(s, -s) * 0.7, col, 2.0)
		&"arena", &"arena_cleared":  # v0.5.5 AR: an amber square with a bar across its doors' line
			var col := MinimapStyle.ARENA if kind == &"arena" else MinimapStyle.PORTAL_SEALED
			if kind == &"arena":
				_ci.draw_circle(p, s * 1.6, Color(col, MinimapStyle.GLOW_ALPHA))
			_ci.draw_rect(Rect2(p - Vector2(s, s), Vector2(s * 2, s * 2)), col, false, 2.0)
			_ci.draw_rect(Rect2(p - Vector2(s * 0.45, s * 0.45), Vector2(s * 0.9, s * 0.9)), col)
		&"shop":  # v0.5.0 SH: a storefront (a box under a roof), in the shards' violet
			var house := PackedVector2Array(
				[
					p + Vector2(0, -s * 1.3),
					p + Vector2(s * 1.1, -s * 0.3),
					p + Vector2(s * 0.9, s * 0.9),
					p + Vector2(-s * 0.9, s * 0.9),
					p + Vector2(-s * 1.1, -s * 0.3)
				]
			)
			_ci.draw_circle(p, s * 1.6, Color(MinimapStyle.SHOP, MinimapStyle.GLOW_ALPHA))
			_ci.draw_colored_polygon(house, MinimapStyle.SHOP)
			_ci.draw_rect(
				Rect2(p + Vector2(-s * 0.3, s * 0.1), Vector2(s * 0.6, s * 0.8)), MinimapStyle.PANEL
			)
		&"portal_sealed":
			_ci.draw_arc(p, s * 1.1, 0.0, TAU, 20, MinimapStyle.PORTAL_SEALED, 1.5, true)
		&"secret":  # v0.9.0 RB: A4 Astral's mark, a violet four-point star in a glow
			var star := PackedVector2Array()
			for j in 8:
				var rr := s * (1.3 if j % 2 == 0 else 0.4)
				star.append(p + Vector2(cos(TAU * j / 8.0), sin(TAU * j / 8.0)) * rr)
			_ci.draw_circle(p, s * 1.7, Color(SECRET, MinimapStyle.GLOW_ALPHA))
			_ci.draw_colored_polygon(star, SECRET)


func _draw_legend(at: Vector2) -> void:
	var font := get_theme_default_font()
	_ci.draw_string(
		font,
		at + Vector2(0, MinimapStyle.TITLE_SIZE),
		tr("MAP_TITLE"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		MinimapStyle.TITLE_SIZE,
		MinimapStyle.TEXT
	)
	var y := at.y + MinimapStyle.TITLE_SIZE + 30
	var rows := LEGEND.duplicate()
	if reader.affinity_maps_secrets():
		rows.append(LEGEND_SECRET)
	for row: Array in rows:
		draw_icon(row[0], Vector2(at.x + 16, y), 1.4)
		_ci.draw_string(
			font,
			Vector2(at.x + 44, y + MinimapStyle.FONT_SIZE * 0.35),
			tr(row[1]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			MinimapStyle.FONT_SIZE,
			MinimapStyle.TEXT_DIM
		)
		y += 38
	_ci.draw_string(
		font,
		Vector2(at.x, y + 18),
		tr("MAP_ROOMS") % [state.discovered_count(), reader.floor_room_count()],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		MinimapStyle.FONT_SIZE,
		MinimapStyle.TEXT
	)
