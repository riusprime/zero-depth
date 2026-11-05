class_name AstralUi
extends RefCounted
## v0.10.5 W3-O19 (owner 2026-11-04 night: "remake every single UI element into this new style even the main menu, all
## UI style components have to be remade"; the style Astral, W3_O13_UI_STYLE_G2.md round 2): the Astral look for the
## full-screen pages and panels that are Controls (the Build page, the Codex, the event panel, the hub's stations), as
## one Theme and a few style boxes. Thin crisp lines on whole pixels (only diagonals and curves antialiased), no rounded
## boxes, no glow, no warm colour; Astral's palette only (AstralCardArt's tokens, AstralChrome's ink):
## - Theme: body text in Atkinson, buttons in letter-spaced Cinzel; a plain row is type only, the focused one (keys,
##   pad) a RowBox: a four-point star at its left and a tapered streak of moonlight under the text, over a faint
##   wash fading rightwards; a hovered one (mouse) the same at half. Panels a PanelBox, separators a hairline,
##   scroll bars a 1 px groove with a slim silver grabber.
## - PanelBox: a veil, no border: ink fading in at its sides between two hairlines fading out from a small star.
## - RowBox: the focused row (above).
## - TabBox: a page tab: the page shown underlined by a hairline with a diamond at its middle; focus as a row's.
## - PlateBox: AstralChrome's plate (the slim lozenge button) as a style box, for the pages' Back buttons.
## - TileBox: AstralChrome.FrameBox with a medallion ring (a 1 px ring and a dotted inner ring) round a picture.
## - LeftRule: a hairline under a left-aligned title, from a small star fading out rightwards.
## - Sigil: AstralChrome's heading sigil as a Control (before a page's title).
## `dress(panel)` puts a MenuPanel (the hub's station panels) in this look: the theme, the veil slab, the title in
## Cinzel over a LeftRule; the ember marker is hidden (the focused row's star does its work).
## It only draws: nothing here changes an outcome (EI-07).

## The type scale (W3_O13_UI_STYLE_G2.md: Cinzel 44 / 34 / 21 / 15 / 13 / 11; Atkinson 16 / 15 / 14 / 13 / 12).
const TITLE_SIZE := 44
const PANEL_TITLE_SIZE := 34
const MENU_SIZE := 21
const TAB_SIZE := 15
const LABEL_SIZE := 13
const BODY_SIZE := 16
const HINT_SIZE := 15
## A row's padding: the left one clears the focus star.
const ROW_PAD := Vector4(32, 8, 18, 8)
## The secondary text (a dimmer cool grey than DIM for key hints).
const HINT := Color("#7C82A4")

static var _theme: Theme


## The Astral Theme on a page's root control (its children inherit it).
static func apply(c: Control) -> void:
	c.theme = theme()


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = HudStyle.font(false)
	t.default_font_size = 18
	var normal := StyleBoxEmpty.new()
	_pad(normal)
	var lit := RowBox.new(1.0)
	var hover := RowBox.new(0.5)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", lit)
	t.set_stylebox("hover_pressed", "Button", lit)
	t.set_stylebox("disabled", "Button", normal)
	t.set_stylebox("focus", "Button", lit)
	t.set_font("font", "Button", serif(600, MENU_SIZE))
	t.set_font_size("font_size", "Button", MENU_SIZE)
	t.set_color("font_color", "Button", AstralCardArt.DIM)
	t.set_color("font_hover_color", "Button", AstralCardArt.TEXT)
	t.set_color("font_focus_color", "Button", AstralCardArt.TEXT)
	t.set_color("font_pressed_color", "Button", AstralCardArt.LINE_HI)
	t.set_color("font_hover_pressed_color", "Button", AstralCardArt.LINE_HI)
	t.set_color("font_disabled_color", "Button", Color(AstralCardArt.DIM, 0.35))
	t.set_color("font_outline_color", "Button", Color(AstralChrome.INK, 0.6))
	t.set_constant("outline_size", "Button", 4)
	t.set_constant("h_separation", "Button", 12)
	t.set_color("font_color", "Label", AstralCardArt.TEXT)
	t.set_color("font_outline_color", "Label", Color(AstralChrome.INK, 0.6))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_color("default_color", "RichTextLabel", Color(AstralCardArt.TEXT, 0.9))
	t.set_stylebox("panel", "PanelContainer", PanelBox.new())
	var sep := StyleBoxLine.new()
	sep.color = Color(AstralCardArt.LINE, 0.45)
	sep.thickness = 1
	var vsep := sep.duplicate() as StyleBoxLine
	vsep.vertical = true
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("separator", "VSeparator", vsep)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(AstralCardArt.LINE, 0.18)
	groove.content_margin_left = 1
	groove.content_margin_right = 1
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(AstralCardArt.METAL, 0.45)
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	var grab_lit := grab.duplicate() as StyleBoxFlat
	grab_lit.bg_color = Color(AstralCardArt.LINE_HI, 0.85)
	t.set_stylebox("scroll", "VScrollBar", groove)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_lit)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_lit)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(AstralCardArt.LINE, 0.4)
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = AstralCardArt.ACCENT
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_stylebox("panel", "TooltipPanel", AstralChrome.FrameBox.new(0.0, 1.0, Vector2(12, 8)))
	t.set_color("font_color", "TooltipLabel", AstralCardArt.TEXT)
	_theme = t
	return t


## Cinzel at weight `wght`, letter-spaced for its size (about 0.2 em; titles 0.3 em).
static func serif(wght: int, px: int, title := false) -> FontVariation:
	return AstralCardArt.serif(wght, int(roundf(px * (0.3 if title else 0.2))))


## A title: letter-spaced Cinzel capitals at `px`.
static func title(l: Label, px: int = TITLE_SIZE, col: Color = AstralCardArt.TEXT) -> void:
	l.uppercase = true
	l.add_theme_font_override("font", serif(600, px, true))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(AstralChrome.INK, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))


## A small-caps label (a section's head, a field's name): Cinzel capitals at `px`, dim.
static func caps(l: Label, px: int = LABEL_SIZE, col: Color = AstralCardArt.DIM) -> void:
	l.uppercase = true
	l.add_theme_font_override("font", serif(600, px))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(AstralChrome.INK, 0.6))
	l.add_theme_constant_override("outline_size", 4)


## Body text: Atkinson at `px` in `col`.
static func body(l: Label, px: int = BODY_SIZE, col: Color = AstralCardArt.TEXT) -> void:
	l.add_theme_font_override("font", HudStyle.font(false))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(AstralChrome.INK, 0.6))
	l.add_theme_constant_override("outline_size", 4)


## A key hint line: Atkinson 15 in the hint grey.
static func hint(key: String) -> Label:
	var l := Label.new()
	l.name = "Hint"
	l.text = key
	body(l, HINT_SIZE, HINT)
	return l


## Makes `b` a plate (the slim lozenge button) with its text in Cinzel; `width` its least width (px).
static func plate_button(b: Button, width: float = 220.0, px: int = 17) -> void:
	var h := 44.0
	b.custom_minimum_size = Vector2(width, h)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_override("font", serif(600, px))
	b.add_theme_font_size_override("font_size", px)
	var idle := PlateBox.new(0.0)
	var half := PlateBox.new(0.5)
	var lit := PlateBox.new(1.0)
	for s: String in ["normal", "disabled"]:
		b.add_theme_stylebox_override(s, idle)
	b.add_theme_stylebox_override("hover", half)
	for s: String in ["focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, lit)


## Puts a MenuPanel (a hub station's) in the Astral look: the theme, the veil slab, the title in Cinzel over a
## LeftRule, its notes and hints in Astral's greys; the ember marker hidden (the focused row's star marks it).
static func dress(panel: MenuPanel) -> void:
	apply(panel)
	var pad: Vector2 = MenuStyle.SLAB_PAD
	panel.slab.add_theme_stylebox_override("panel", PanelBox.new(Vector2(pad.x + 16.0, pad.y), 0.8))
	panel.marker.self_modulate = Color(1, 1, 1, 0)
	var under_title := false
	for c in panel.box.get_children():
		if c is Label and not under_title and c.get_index() == 0:
			title(c as Label, PANEL_TITLE_SIZE)
			under_title = true
		elif c is MenuPanel.TitleGroove:
			var rule := LeftRule.new()
			rule.name = "TitleRule"
			panel.box.add_child(rule)
			panel.box.move_child(rule, c.get_index())
			panel.box.remove_child(c)
			c.queue_free()
	for c in panel.get_children():
		if c is MenuBackdrop:
			(c as MenuBackdrop).astral = true
	for l: Label in panel.slab.find_children("*", "Label", true, false):
		var px := l.get_theme_font_size("font_size")
		var row := l.get_parent() as HBoxContainer
		if row != null and l.get_index() == 0 and not l.has_theme_color_override("font_color"):
			caps(l, 15)  # a field's name before its cycler
			continue
		if not l.has_theme_color_override("font_color"):
			continue
		var col := l.get_theme_color("font_color")
		if col == MenuStyle.HINT:
			body(l, HINT_SIZE, HINT)
		elif col == MenuStyle.DIM:
			body(l, px, AstralCardArt.DIM)
		elif col == MenuStyle.TEXT:
			body(l, px, AstralCardArt.TEXT)


static func _pad(b: StyleBox) -> void:
	b.content_margin_left = ROW_PAD.x
	b.content_margin_top = ROW_PAD.y
	b.content_margin_right = ROW_PAD.z
	b.content_margin_bottom = ROW_PAD.w


## A 1 px rect frame on whole pixels.
static func frame(to: RID, r: Rect2, col: Color) -> void:
	var rs := RenderingServer
	rs.canvas_item_add_rect(to, Rect2(r.position, Vector2(r.size.x, 1)), col)
	rs.canvas_item_add_rect(to, Rect2(r.position.x, r.end.y - 1, r.size.x, 1), col)
	rs.canvas_item_add_rect(to, Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), col)
	rs.canvas_item_add_rect(to, Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), col)


## A hairline fading out both ways from `cx` (six steps), leaving `gap` clear in the middle.
static func rule(to: RID, cx: float, y: float, half: float, col: Color, gap := 0.0) -> void:
	for k in 6:
		var a := col.a * (1.0 - k / 6.0)
		var c0 := roundf(gap + (half - gap) * k / 6.0)
		var c1 := roundf(gap + (half - gap) * (k + 1) / 6.0)
		var y0 := roundf(y)
		RenderingServer.canvas_item_add_rect(
			to, Rect2(roundf(cx) - c1, y0, c1 - c0, 1), Color(col, a)
		)
		RenderingServer.canvas_item_add_rect(
			to, Rect2(roundf(cx) + c0, y0, c1 - c0, 1), Color(col, a)
		)


## A four-point star on a canvas item RID.
static func star(to: RID, c: Vector2, r: float, col: Color, inner := 0.22) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var a := -PI * 0.5 + PI * 0.25 * k
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * inner))
	RenderingServer.canvas_item_add_polygon(to, pts, PackedColorArray([col]))


## A diamond on a canvas item RID, filled `fill`, outlined `col` (alpha 0: none).
static func diamond(to: RID, c: Vector2, r: float, col: Color, fill: Color) -> void:
	var d := AstralChrome.dia_pts(c, r)
	if fill.a > 0.0:
		RenderingServer.canvas_item_add_polygon(to, d, PackedColorArray([fill]))
	if col.a > 0.0:
		var out := d.duplicate()
		out.append(d[0])
		RenderingServer.canvas_item_add_polyline(to, out, PackedColorArray([col]), 1.0, true)


## A horizontal band from `x0` to `x1`, its colour going from `a` to `b`.
static func band(to: RID, x0: float, x1: float, y0: float, y1: float, a: Color, b: Color) -> void:
	RenderingServer.canvas_item_add_polygon(
		to,
		PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		PackedColorArray([a, b, b, a])
	)


## The veil panel: no border; ink fading in over `FADE` px at its sides, a hairline along its top and its foot fading
## out from the middle, a small star on the top one. `ink` its darkness.
class PanelBox:
	extends StyleBox

	const FADE := 32.0
	var ink := 0.72
	var stars := true

	func _init(margin: Vector2 = Vector2(24, 24), p_ink: float = 0.72) -> void:
		ink = p_ink
		content_margin_left = margin.x
		content_margin_right = margin.x
		content_margin_top = margin.y
		content_margin_bottom = margin.y

	func _draw(to: RID, rect: Rect2) -> void:
		var o := Rect2(rect.position.round(), rect.size.round())
		var fill := Color(AstralChrome.INK, ink)
		var clear := Color(AstralChrome.INK, 0.0)
		var f := minf(FADE, o.size.x * 0.2)
		RenderingServer.canvas_item_add_rect(
			to, Rect2(o.position.x + f, o.position.y, o.size.x - f * 2.0, o.size.y), fill
		)
		AstralUi.band(to, o.position.x, o.position.x + f, o.position.y, o.end.y, clear, fill)
		AstralUi.band(to, o.end.x - f, o.end.x, o.position.y, o.end.y, fill, clear)
		var cx := o.get_center().x
		var half := o.size.x * 0.5
		AstralUi.rule(to, cx, o.position.y, half, Color(AstralCardArt.LINE, 0.95))
		AstralUi.rule(to, cx, o.end.y - 1.0, half, Color(AstralCardArt.LINE, 0.6))
		if stars:
			AstralUi.diamond(
				to,
				Vector2(roundf(cx) + 0.5, o.position.y + 0.5),
				3.5,
				AstralCardArt.METAL,
				AstralChrome.INK
			)


## The focused (1) or hovered (0.5) row: a four-point star at its left, a faint wash fading rightwards, and a tapered
## streak of moonlight under the text.
class RowBox:
	extends StyleBox

	var lit := 1.0

	func _init(p_lit: float = 1.0) -> void:
		lit = p_lit
		AstralUi._pad(self)

	func _draw(to: RID, rect: Rect2) -> void:
		var o := Rect2(rect.position.round(), rect.size.round())
		var x0 := o.position.x
		var x1 := o.end.x
		var wash := Color(AstralCardArt.ACCENT, 0.12 * lit)
		AstralUi.band(to, x0, x1, o.position.y, o.end.y, wash, Color(wash, 0.0))
		var y := o.end.y - 3.0
		var w := (x1 - x0) * 0.85
		var hi := Color(AstralCardArt.LINE_HI, 0.9 * lit)
		(
			RenderingServer
			. canvas_item_add_polygon(
				to,
				PackedVector2Array(
					[
						Vector2(x0 + 8, y - 1.0),
						Vector2(x0 + 8 + w, y),
						Vector2(x0 + 8 + w, y + 1.0),
						Vector2(x0 + 8, y + 1.0),
					]
				),
				PackedColorArray([hi, Color(hi, 0.0), Color(hi, 0.0), hi])
			)
		)
		var c := Vector2(x0 + 14.5, roundf(o.get_center().y) + 0.5)
		AstralUi.star(to, c, 8.0 if lit >= 1.0 else 6.0, Color(AstralCardArt.LINE_HI, lit), 0.18)
		if lit >= 1.0:
			RenderingServer.canvas_item_add_rect(
				to, Rect2(x0, o.position.y + 4, 1, o.size.y - 8), Color(AstralCardArt.LINE_HI, 0.5)
			)


## A page tab: the page shown (`current`) underlined by a hairline with a diamond at its middle; `lit` (focus 1,
## hover 0.5) adds a row's wash and a brighter line.
class TabBox:
	extends StyleBox

	var current := false
	var lit := 0.0

	func _init(p_current: bool = false, p_lit: float = 0.0) -> void:
		current = p_current
		lit = p_lit
		content_margin_left = 16
		content_margin_right = 16
		content_margin_top = 8
		content_margin_bottom = 10

	func _draw(to: RID, rect: Rect2) -> void:
		var o := Rect2(rect.position.round(), rect.size.round())
		if lit > 0.0:
			var wash := Color(AstralCardArt.ACCENT, 0.12 * lit)
			AstralUi.band(to, o.position.x, o.end.x, o.position.y, o.end.y, Color(wash, 0.0), wash)
			RenderingServer.canvas_item_add_rect(
				to,
				Rect2(o.position.x, o.position.y, o.size.x, 1),
				Color(AstralCardArt.LINE_HI, 0.3 * lit)
			)
		var y := o.end.y - 2.0
		var cx := o.get_center().x
		if current or lit > 0.0:
			var col := AstralCardArt.LINE_HI if lit >= 1.0 else AstralCardArt.ACCENT
			AstralUi.rule(
				to, cx, y, o.size.x * 0.5, Color(col, 0.95 if current else 0.6 * lit), 5.0
			)
			AstralUi.diamond(
				to,
				Vector2(roundf(cx) + 0.5, y + 0.5),
				3.5,
				col,
				col if current else AstralChrome.INK
			)
		else:
			RenderingServer.canvas_item_add_rect(
				to, Rect2(o.position.x, y, o.size.x, 1), Color(AstralCardArt.LINE, 0.3)
			)


## The plate (AstralChrome.plate, the slim lozenge button) as a style box; `lit` 1 focused, 0.5 hovered, 0 idle.
class PlateBox:
	extends StyleBox

	var lit := 0.0

	func _init(p_lit: float = 0.0) -> void:
		lit = p_lit
		content_margin_left = 30
		content_margin_right = 30
		content_margin_top = 6
		content_margin_bottom = 6

	func _draw(to: RID, rect: Rect2) -> void:
		var o := AstralChrome.px(rect)
		var tip := roundf(rect.size.y * AstralChrome.TIP * 0.5)
		var pts := AstralChrome.lozenge(o, tip)
		var on := lit >= 1.0
		var line := AstralCardArt.LINE.lerp(AstralCardArt.LINE_HI, lit)
		var rs := RenderingServer
		rs.canvas_item_add_polygon(
			to, pts, PackedColorArray([AstralChrome.FILL_HI if on else AstralChrome.FILL])
		)
		if lit > 0.0:
			rs.canvas_item_add_polygon(
				to,
				AstralChrome.contour(pts, -3.0),
				PackedColorArray([Color(AstralCardArt.ACCENT, 0.1 * lit)])
			)
		if on:
			_loop(to, AstralChrome.contour(pts, 6.0), Color(AstralCardArt.LINE_HI, 0.25), 1.0)
		_loop(to, AstralChrome.contour(pts, -5.0), Color(line, 0.3), 1.0)
		_loop(to, pts, line, 1.4 if on else 1.0)
		var cy := roundf(o.get_center().y) + 0.5
		for sx: float in [-1.0, 1.0]:
			var x: float = o.get_center().x + sx * (o.size.x * 0.5 + (14.0 if on else 9.0))
			AstralUi.star(
				to,
				Vector2(roundf(x) + 0.5, cy),
				5.0 if on else 4.0,
				Color(line, 0.95 if on else 0.5)
			)

	func _loop(to: RID, pts: PackedVector2Array, col: Color, w: float) -> void:
		var out := pts.duplicate()
		out.append(pts[0])
		RenderingServer.canvas_item_add_polyline(to, out, PackedColorArray([col]), w, true)


## A tile (AstralChrome.FrameBox) with a medallion ring round `ring` (relative to the tile's top left; size 0: none):
## a 1 px ring and a dotted inner ring, brighter on focus; `ring_color` (alpha > 0) tints the ring.
class TileBox:
	extends AstralChrome.FrameBox

	const DOTS := 28
	var ring := Rect2()
	var ring_color := Color(0, 0, 0, 0)

	func _init(p_focus: float = 0.0, p_dim: float = 1.0, margins := Vector2(6, 6)) -> void:
		super(p_focus, p_dim, margins)

	func _draw(to: RID, rect: Rect2) -> void:
		super(to, rect)
		if ring.size.x <= 0.0:
			return
		var c := rect.position.floor() + ring.get_center()
		var r := ring.size.x * 0.5
		var lit := focus > 0.5
		var col := ring_color if ring_color.a > 0.0 else AstralCardArt.LINE
		col = (AstralCardArt.LINE_HI if lit else col)
		col.a *= dim
		var rs := RenderingServer
		rs.canvas_item_add_circle(to, c, r, Color(AstralChrome.INK, 0.45 * dim))
		var ring_pts := PackedVector2Array()
		for k in 65:
			ring_pts.append(c + Vector2(cos(TAU * k / 64.0), sin(TAU * k / 64.0)) * r)
		rs.canvas_item_add_polyline(
			to, ring_pts, PackedColorArray([Color(col, 0.95 if lit else 0.6 * dim)]), 1.0, true
		)
		for k in DOTS:
			var a := TAU * k / DOTS
			rs.canvas_item_add_circle(
				to, c + Vector2(cos(a), sin(a)) * (r - 4.0), 0.7, Color(col, 0.55 if lit else 0.3)
			)
		if lit:
			for k in 4:
				var a := PI * 0.25 + PI * 0.5 * k
				AstralUi.star(
					to, c + Vector2(cos(a), sin(a)) * (r + 5.0), 3.5, AstralCardArt.LINE_HI, 0.2
				)


## A hairline under a left-aligned title: a small star at its start, the line fading out rightwards over `length` px.
class LeftRule:
	extends Control

	var length := 320.0

	func _init(p_length: float = 320.0) -> void:
		name = "LeftRule"
		length = p_length
		custom_minimum_size = Vector2(0, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := roundf(size.y * 0.5)
		AstralChrome.star4(self, Vector2(6.5, y + 0.5), 6.0, Color(AstralCardArt.METAL, 0.9), 0.2)
		AstralChrome.rule1(
			self, 16.0, y, minf(length, size.x - 16.0), Color(AstralCardArt.METAL, 0.6)
		)


## AstralChrome's heading sigil (a ring, a four-point star through it, a crescent over it) as a Control.
class Sigil:
	extends Control

	var radius := 12.0

	func _init(p_radius: float = 12.0) -> void:
		name = "Sigil"
		radius = p_radius
		custom_minimum_size = Vector2(roundf(p_radius * 3.2), roundf(p_radius * 4.2))
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(roundf(size.x * 0.5) + 0.5, roundf(size.y * 0.6) + 0.5)
		AstralChrome.sigil(self, c, radius, AstralCardArt.METAL)
