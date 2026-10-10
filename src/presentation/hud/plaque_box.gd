class_name PlaqueBox
extends StyleBox
## One of the owner's crystal plaques (Plaques) as a style box (v0.6.1 R1): a nine-slice drawn at `scale_factor`
## (plaque px → screen px). The four corners and the crystal end-clusters keep their shape at that scale; the top and
## bottom edges and the plain middle stretch across, and the band in the middle of the dark panel stretches down
## when the content is taller than the plaque. Its content margins put the text inside the dark panel
## (Plaques.CONTENT). A host sets its own minimum size to at least natural_size() so the crystals never squash (a
## container adds a style box's minimum size to its content, so the box itself asks for no more than its margins).
## `focused` draws it at full brightness, otherwise a little dimmer. Presentation only (EI-07).

var plaque := &"amber"
var texture: Texture2D
var scale_factor := 0.5
var focused := true
var pad := 0.0


func _init(p_plaque: StringName = &"amber", p_scale: float = 0.5, p_pad: float = 0.0) -> void:
	scale_factor = p_scale
	pad = p_pad
	set_plaque(p_plaque)
	_margins()


func set_plaque(p: StringName) -> void:
	if p == plaque and texture != null:
		return
	plaque = p
	texture = Plaques.texture(p)
	emit_changed()


func set_focused(on: bool) -> void:
	if on == focused:
		return
	focused = on
	emit_changed()


## The colour the plaque is drawn with.
func tint() -> Color:
	return Color.WHITE if focused else Plaques.IDLE


## The nine-slice margins on screen (px): left, top, right, bottom.
func slice_margins() -> Vector4:
	var s := scale_factor
	return Vector4(
		Plaques.SLICE_LEFT * s,
		Plaques.SLICE_TOP * s,
		Plaques.SLICE_RIGHT * s,
		Plaques.SLICE_BOTTOM * s
	)


## The nine pieces for `rect`: [destination, source] pairs, row by row (tests read them).
func pieces(rect: Rect2) -> Array:
	var w := Plaques.SIZE.x
	var h := Plaques.SIZE.y
	var m := slice_margins()
	# A rect narrower or shorter than the two margins shrinks them together (never happens at the minimum size).
	var kx := minf(1.0, rect.size.x / maxf(1.0, m.x + m.z))
	var ky := minf(1.0, rect.size.y / maxf(1.0, m.y + m.w))
	var sx := [0.0, Plaques.SLICE_LEFT, w - Plaques.SLICE_RIGHT, w]
	var sy := [0.0, Plaques.SLICE_TOP, h - Plaques.SLICE_BOTTOM, h]
	var dx := [rect.position.x, rect.position.x + m.x * kx, rect.end.x - m.z * kx, rect.end.x]
	var dy := [rect.position.y, rect.position.y + m.y * ky, rect.end.y - m.w * ky, rect.end.y]
	var out := []
	for j in 3:
		for i in 3:
			var dst := Rect2(dx[i], dy[j], dx[i + 1] - dx[i], dy[j + 1] - dy[j])
			var src := Rect2(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j])
			out.append([dst, src])
	return out


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if texture == null:
		return
	var rid := texture.get_rid()
	var c := tint()
	for p: Array in pieces(rect):
		var dst: Rect2 = p[0]
		if dst.size.x > 0.0 and dst.size.y > 0.0:
			RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, dst, rid, p[1], c)


## The plaque's natural size at its scale (px): the smallest a host should be.
func natural_size() -> Vector2:
	return Plaques.SIZE * scale_factor


func _margins() -> void:
	var s := scale_factor
	var c := Plaques.CONTENT
	content_margin_left = c.position.x * s + pad
	content_margin_top = c.position.y * s
	content_margin_right = (Plaques.SIZE.x - c.end.x) * s + pad
	content_margin_bottom = (Plaques.SIZE.y - c.end.y) * s
