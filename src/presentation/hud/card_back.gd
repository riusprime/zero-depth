class_name CardBack
extends Control
## v0.8.0 N8 (owner O62, "paint the whole card"): a reward card's back, face down while the cards are dealt: the
## same carved stone slab (StoneBox) painted in the card's rarity colour, its frame in that colour, a carved ember
## diamond in the middle with a ring round it, and for an Epic or Legendary card waiting to flip a glow in its colour
## round the slab (`glow`). It draws what it is given; it decides nothing (EI-07).

var tier := 0
var color := Color.WHITE
## 0..1: the waiting high card's glow.
var glow := 0.0:
	set(v):
		if not is_equal_approx(glow, v):
			glow = v
			_box.under = 0.2 + 1.4 * v
			_box.focus = 0.9 * v
			queue_redraw()
## v0.10.5 W3-S13 (owner 2026-11-04: his carved card backs): an Astral back wears his carved slate back (one of four,
## the same variant as the card's front, its focused twin while the card is focused) instead of the stone slab, with
## the rarity as a small gem at the medallion. `variant` is set by the card (AstralCardArt.variant_of its id).
var astral := false
var variant := 1:
	set(v):
		variant = clampi(v, 1, AstralCardArt.STARBOUND)  # v0.10.5 W3-P10b: the gold Starbound back too
		_sync_art()
var focused := false:
	set(v):
		focused = v
		_sync_art()
var _art: NinePatchRect
var _box := StoneBox.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.cut = 18.0
	_box.chip = 3.5
	_box.cracks = 2
	_box.pattern = 401


## Turns the Astral look on: the carved back replaces the stone slab.
func set_astral(on: bool) -> void:
	astral = on
	if on and _art == null:
		_art = NinePatchRect.new()
		_art.name = "Art"
		_art.show_behind_parent = true  # the tier gem (this control's own draw) lies over the carved art
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.patch_margin_left = AstralCardArt.MARGIN_X
		_art.patch_margin_right = AstralCardArt.MARGIN_X
		_art.patch_margin_top = AstralCardArt.MARGIN_Y
		_art.patch_margin_bottom = AstralCardArt.MARGIN_Y
		add_child(_art)
	if _art != null:
		_art.visible = on
	_sync_art()
	queue_redraw()


## The carved back's texture now (null when not Astral): tests read it.
func art_texture() -> Texture2D:
	return _art.texture if astral and _art != null else null


func _sync_art() -> void:
	if _art == null:
		return
	_art.texture = AstralCardArt.back(variant, focused)
	var k := size.x / AstralCardArt.BODY_W
	if k > 0.0:  # the same scale and padding as the front's frame, so a back and a front line up
		_art.scale = Vector2(k, k)
		_art.position = -AstralCardArt.PAD * k
		_art.size = size / k + AstralCardArt.PAD * 2.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_art()


## Paints the back for tier `p_tier` (PickSlot.TIERS) in its colour.
func paint(p_tier: int, c: Color) -> void:
	tier = p_tier
	color = c
	_box.fill = CardPaint.face(c)
	_box.edge = c
	_box.glow_color = c
	_box.rim = EmberStone.GOLD if CardDeal.high(p_tier) else Color(0, 0, 0, 0)
	queue_redraw()


func box() -> StoneBox:
	return _box


func _draw() -> void:
	var c := size * 0.5
	if astral:  # the carved back is the art; the rarity is a small gem at its medallion
		var g := minf(size.x, size.y) * 0.05
		var gem := PackedVector2Array(
			[
				c + Vector2(0, -g),
				c + Vector2(g * 0.7, 0),
				c + Vector2(0, g),
				c + Vector2(-g * 0.7, 0)
			]
		)
		draw_colored_polygon(gem, Color(color.lerp(Color.WHITE, 0.25), 0.55 + 0.4 * glow))
		draw_polyline(
			PackedVector2Array([gem[0], gem[1], gem[2], gem[3], gem[0]]),
			Color(AstralCardArt.LINE_HI, 0.5),
			1.5,
			true
		)
		if glow > 0.0:
			draw_circle(c, g * 2.2, Color(color, 0.18 * glow))
		return
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(_box, r)
	var s := minf(size.x, size.y) * 0.2
	var ring := PackedVector2Array()
	for k in 33:
		var a := k * TAU / 32.0
		ring.append(c + Vector2(cos(a), sin(a)) * s * 1.35)
	draw_polyline(ring, Color(color, 0.75), 2.5, true)
	draw_polyline(ring, Color(color, 0.18 + 0.3 * glow), 9.0, true)
	var diamond := PackedVector2Array(
		[c + Vector2(0, -s), c + Vector2(s * 0.62, 0), c + Vector2(0, s), c + Vector2(-s * 0.62, 0)]
	)
	draw_colored_polygon(diamond, Color(EmberStone.GROOVE, 0.9))
	var inner := PackedVector2Array()
	for p in diamond:
		inner.append(c + (p - c) * 0.62)
	draw_colored_polygon(inner, color.lerp(EmberStone.EMBER, 0.35).lightened(0.15 + 0.3 * glow))
	for k in 4:  # the carved notches at the corners of the diamond's frame
		var a := k * TAU / 4.0 + TAU / 8.0
		var p := c + Vector2(cos(a), sin(a)) * s * 1.75
		draw_circle(p, 3.0, Color(color, 0.6))
