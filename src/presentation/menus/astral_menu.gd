class_name AstralMenu
extends RefCounted
## The menus in
## Astral (W3_O13_UI_STYLE_G2.md round 2, the owner's pick; the round-2 mock's pause and options): the main menu, the
## pause menus, Options, the run recap, the credits. Nothing boxed: lists are letter-spaced Cinzel capitals, the
## focused row lit with a four-point star and a tapered streak under it (AstralButton), panels a light ink veil
## between two fading hairlines (VeilBox), buttons slim lozenge plates (AstralChrome.plate), the game blurred under
## Astral's cool ink (MenuBackdrop.astral). Crisp 1 px lines on whole pixels, an 8 px grid, Astral's palette only
## (AstralCardArt's tokens): no ember, no orange, no brown. One Theme for these menus: `AstralMenu.apply(control)`.
## v0.11.1 Step 13 (owner: "Astral current one live should be the only HUD style for all elements throughout the
## game"): the hub's station panels and the Training Room's terminal too (MenuPanel); the Ember stone menus are gone.
## Presentation only (EI-07): nothing here decides an outcome.

## The heat colour: a muted amber, the one warm colour (the depths' line in the pause menu).
const HEAT := Color("#D6A878")
## A list's left edge (the row's marker sits inside the row) and its width, and a row's height (1920 x 1080 base).
const LEFT := 200.0
const LIST_W := 440.0
const ROW_H := 56.0
## The type scale (W3_O13 round 2): screen title, panel title, menu row, plate and tab, field label; Atkinson body.
const TITLE_SIZE := 44
const PANEL_TITLE_SIZE := 34
const SECTION_SIZE := 21
const ROW_SIZE := 21
const TAB_SIZE := 15
const PLATE_SIZE := 15
const LABEL_SIZE := 13
const BODY_SIZE := 16
const NOTE_SIZE := 15

static var _theme: Theme
static var _sans := {}
static var _blank: Texture2D


## Puts the Astral menu Theme on a menu's root control (its children inherit it).
static func apply(c: Control) -> void:
	c.theme = theme()


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = sans(false)
	t.default_font_size = 18
	# Labels: Atkinson in Astral's text colour, a soft ink outline for the blurred game under them.
	t.set_color("font_color", "Label", AstralCardArt.TEXT)
	t.set_color("font_outline_color", "Label", Color(AstralChrome.INK, 0.6))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("default_color", "RichTextLabel", Color(AstralCardArt.TEXT, 0.82))
	t.set_font("normal_font", "RichTextLabel", sans(false))
	# Buttons that keep the Button's own drawing (the binding cells): a 1 px frame with an inner frame; focus and
	# hover alike (Astral's rule): the frame brightens, a second frame 6 px outside, the fill lifts.
	var margins := Vector2(12, 6)
	t.set_stylebox("normal", "Button", AstralChrome.FrameBox.new(0.0, 0.8, margins))
	t.set_stylebox("hover", "Button", AstralChrome.FrameBox.new(1.0, 1.0, margins))
	t.set_stylebox("pressed", "Button", AstralChrome.FrameBox.new(1.0, 1.0, margins))
	t.set_stylebox("hover_pressed", "Button", AstralChrome.FrameBox.new(1.0, 1.0, margins))
	t.set_stylebox("focus", "Button", AstralChrome.FrameBox.new(1.0, 1.0, margins))
	t.set_stylebox("disabled", "Button", AstralChrome.FrameBox.new(0.0, 0.35, margins))
	t.set_font("font", "Button", sans(true))
	t.set_font_size("font_size", "Button", BODY_SIZE)
	t.set_color("font_color", "Button", Color(AstralCardArt.TEXT, 0.82))
	t.set_color("font_hover_color", "Button", AstralCardArt.LINE_HI)
	t.set_color("font_focus_color", "Button", AstralCardArt.LINE_HI)
	t.set_color("font_pressed_color", "Button", AstralCardArt.LINE_HI)
	t.set_color("font_hover_pressed_color", "Button", AstralCardArt.LINE_HI)
	t.set_color("font_disabled_color", "Button", Color(AstralCardArt.DIM, 0.6))
	t.set_color("font_outline_color", "Button", Color(AstralChrome.INK, 0.6))
	t.set_constant("outline_size", "Button", 4)
	# Panels: the ink veil between two fading hairlines.
	t.set_stylebox("panel", "PanelContainer", VeilBox.new())
	var sep := StyleBoxLine.new()
	sep.color = Color(AstralCardArt.LINE, 0.45)
	sep.thickness = 1
	var vsep := sep.duplicate() as StyleBoxLine
	vsep.vertical = true
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("separator", "VSeparator", vsep)
	# Sliders draw themselves (StepSlider.astral): the built-in track and grabber are empty.
	var none := StyleBoxEmpty.new()
	for s in ["slider", "grabber_area", "grabber_area_highlight", "focus"]:
		t.set_stylebox(s, "HSlider", none)
	for i in ["grabber", "grabber_highlight", "grabber_disabled", "tick"]:
		t.set_icon(i, "HSlider", blank())
	# Scroll bars (the credits, Options' sections): a hairline, the grabber a thin accent bar.
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0, 0, 0, 0)
	groove.border_color = Color(AstralCardArt.LINE, 0.45)
	groove.border_width_left = 1
	groove.content_margin_left = 3
	groove.content_margin_right = 2
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(AstralCardArt.ACCENT, 0.5)
	var grab_lit := grab.duplicate() as StyleBoxFlat
	grab_lit.bg_color = Color(AstralCardArt.ACCENT, 0.9)
	t.set_stylebox("scroll", "VScrollBar", groove)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_lit)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_lit)
	_theme = t
	return t


## Atkinson Hyperlegible (bold or regular) with `track` px between letters.
static func sans(bold: bool, track: int = 0) -> FontVariation:
	var key := "%s_%d" % [bold, track]
	if _sans.has(key):
		return _sans[key]
	var v := FontVariation.new()
	v.base_font = HudStyle.font(bold).base_font
	v.spacing_glyph = track
	_sans[key] = v
	return v


## Cinzel for `px`-high capitals, letter-spaced about 0.3 em (titles) or `em` em.
static func serif(px: int, wght: int = 600, em: float = 0.3) -> FontVariation:
	return AstralCardArt.serif(wght, int(roundf(px * em)))


## A 16 x 16 transparent icon (the slider's grabber room: StepSlider draws the knob).
static func blank() -> Texture2D:
	if _blank == null:
		_blank = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	return _blank


## A label in letter-spaced Cinzel capitals (a field label, a column head, a section head); `key` auto-translates.
static func caps(l: Label, px: int, col: Color, wght: int = 600, em: float = 0.22) -> Label:
	l.uppercase = true
	l.add_theme_font_override("font", serif(px, wght, em))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	return l


## A body line in Atkinson (`px`, `col`).
static func body(l: Label, px: int, col: Color, bold: bool = false) -> Label:
	l.add_theme_font_override("font", sans(bold))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	return l


## A field row (Options' look: FieldRow, its label "Label" in small Cinzel capitals, `label_w` px wide) added to
## `to`; its control goes in after the label and lights the row with `light`.
static func field_row(to: Control, label_key: String, label_w: float) -> FieldRow:
	var row := FieldRow.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 48)
	var l := Label.new()
	l.name = "Label"
	l.text = label_key
	l.custom_minimum_size = Vector2(label_w, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caps(l, LABEL_SIZE, AstralCardArt.DIM, 600, 0.24)
	row.add_child(l)
	to.add_child(row)
	return row


## Lights a field row and its label while `c` (its control) has the focus (Astral: focus reads by brightness).
static func light(row: FieldRow, c: Control) -> void:
	var l := row.get_node("Label") as Label
	var lit := func(on: bool) -> void:
		l.add_theme_color_override("font_color", AstralCardArt.TEXT if on else AstralCardArt.DIM)
		row.lit = on
	c.focus_entered.connect(lit.bind(true))
	c.focus_exited.connect(lit.bind(false))


## A faint accent wash over `r`, fading out to the right (a lit row's band).
static func wash(ci: CanvasItem, r: Rect2, alpha: float) -> void:
	var a := Color(AstralCardArt.ACCENT, alpha)
	var z := Color(AstralCardArt.ACCENT, 0.0)
	ci.draw_polygon(
		PackedVector2Array(
			[r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		),
		PackedColorArray([a, z, z, a])
	)


# --- RenderingServer drawing (style boxes) --------------------------------------------------------------------------


## A hairline fading out both ways from `cx` (six steps) on whole pixels.
static func rs_rule(to: RID, cx: float, y: float, half: float, col: Color) -> void:
	var rs := RenderingServer
	for k in 6:
		var a := col.a * (1.0 - k / 6.0)
		var c0 := roundf(half * k / 6.0)
		var c1 := roundf(half * (k + 1) / 6.0)
		var c := Color(col, a)
		rs.canvas_item_add_rect(to, Rect2(roundf(cx) - c1, roundf(y), c1 - c0, 1), c)
		rs.canvas_item_add_rect(to, Rect2(roundf(cx) + c0, roundf(y), c1 - c0, 1), c)


static func rs_star(to: RID, c: Vector2, r: float, col: Color, inner: float = 0.22) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var a := -PI * 0.5 + PI * 0.25 * k
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * inner))
	RenderingServer.canvas_item_add_polygon(to, pts, PackedColorArray([col]))


## A panel as a style box: a light ink veil, a hairline fading out from the middle along its top (a small star on it)
## and its foot; no border at the sides (Astral's panels are unboxed).
class VeilBox:
	extends StyleBox

	var ink := 0.58

	func _init(margin: Vector2 = Vector2(40, 40), p_ink: float = 0.58) -> void:
		ink = p_ink
		content_margin_left = margin.x
		content_margin_right = margin.x
		content_margin_top = margin.y
		content_margin_bottom = margin.y

	func _draw(to: RID, rect: Rect2) -> void:
		var o := Rect2(rect.position.floor(), rect.size.floor())
		RenderingServer.canvas_item_add_rect(to, o, Color(AstralChrome.INK, ink))
		var cx := o.get_center().x
		AstralMenu.rs_rule(to, cx, o.position.y, o.size.x * 0.5, Color(AstralCardArt.LINE, 0.9))
		AstralMenu.rs_rule(to, cx, o.end.y - 1.0, o.size.x * 0.5, Color(AstralCardArt.LINE, 0.6))
		AstralMenu.rs_star(
			to, Vector2(roundf(cx) + 0.5, o.position.y + 0.5), 5.0, AstralCardArt.METAL, 0.2
		)


## A screen title: the Astral sigil (a ring, a four-point star through it, a crescent over it), then the title in
## letter-spaced Cinzel capitals (`label`, named "Title", its text a translation key). `arc`: a long thin arc rises
## from the sigil to a star, as in the round-2 mock's pause.
class Title:
	extends HBoxContainer

	var label := Label.new()
	var arc := false
	var _sigil := Control.new()
	var _px := 44

	func _init(px: int = 44, p_arc: bool = false) -> void:
		name = "TitleRow"
		_px = px
		arc = p_arc
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("separation", int(roundf(px * 0.3)))
		_sigil.name = "Sigil"
		_sigil.custom_minimum_size = Vector2(roundf(px * 1.1), roundf(px * 1.5))
		_sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sigil.draw.connect(_draw_sigil)
		add_child(_sigil)
		label.name = "Title"
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		AstralMenu.caps(label, px, AstralCardArt.TEXT, 600, 0.3)
		add_child(label)

	func _draw_sigil() -> void:
		var r := roundf(_px * 0.3)
		var c := Vector2(roundf(_sigil.size.x * 0.5) + 0.5, roundf(_sigil.size.y * 0.56) + 0.5)
		AstralChrome.sigil(_sigil, c, r, AstralCardArt.METAL)
		if arc:
			var ac := c + Vector2(_px * 3.4, _px * 0.2)
			var rr := _px * 2.75
			var a1 := PI * 1.6
			_sigil.draw_arc(ac, rr, PI * 1.12, a1, 48, Color(AstralCardArt.METAL, 0.4), 1.0, true)
			AstralChrome.star4(
				_sigil,
				ac + Vector2(cos(a1), sin(a1)) * rr,
				5.0,
				Color(AstralCardArt.METAL, 0.85),
				0.2
			)


## An Options row (a field label, then its control): lit while its control has the focus or the mouse (`lit`): a
## four-point star in its first 16 px (a "Mark" spacer keeps the room), a faint accent band fading out to the right
## and a hairline under it.
class FieldRow:
	extends HBoxContainer

	var lit := false:
		set(v):
			lit = v
			queue_redraw()

	func _init() -> void:
		var mark := Control.new()
		mark.name = "Mark"
		mark.custom_minimum_size = Vector2(16, 0)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mark)

	func _draw() -> void:
		if not lit:
			return
		var cy := roundf(size.y * 0.5)
		AstralMenu.wash(self, Rect2(0, 2, size.x, size.y - 4), 0.09)
		AstralChrome.rule1(self, 0, size.y - 1.0, size.x, Color(AstralCardArt.LINE_HI, 0.3))
		AstralChrome.star4(self, Vector2(8.5, cy + 0.5), 8.0, AstralCardArt.LINE_HI, 0.18)


## A hairline from a small four-point star at the left, fading out to the right (under a title, between a list and
## its notes).
class LeftRule:
	extends Control

	var alpha := 0.6

	func _init(height: float = 24.0, p_alpha: float = 0.6) -> void:
		name = "Rule"
		alpha = p_alpha
		custom_minimum_size = Vector2(0, height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := roundf(size.y * 0.5)
		var col := Color(AstralCardArt.METAL, alpha)
		AstralChrome.star4(self, Vector2(4.5, y + 0.5), 5.0, col, 0.2)
		AstralChrome.rule1(self, 14.0, y, size.x - 14.0, col)
