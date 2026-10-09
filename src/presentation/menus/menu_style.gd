class_name MenuStyle
extends RefCounted
## The menus' look (v0.5.5 A5, owner pick: "Menu from C (we don't need to have those crystal those there, or what is
## the purpose?"; mockup docs/roadmap/v0.6.0/evidence/ui_mockups/pause_c.png): "Cold glass". The game blurred and
## dimmed behind (MenuBackdrop), a left-aligned title and list, plain type, a thin cold-glass highlight on the
## focused row (a cyan wash that fades to the right over a bright hairline, with a small glass diamond beside it,
## GlassMarker), the key hints small. No build cards beside the menu (the owner: not needed).
## One Theme for every full-screen menu (main menu, pause, options, credits, the run recap, the build picker's
## buttons): `MenuStyle.apply(control)` sets it on a menu's root, so the HUD and the pick cards keep their own looks.
## Presentation only (EI-07): nothing here decides an outcome.

## The cold glass accent and the type (starting values, from the C mockup).
const GLASS := Color("#7FE3F2")
const TEXT := Color("#EEF3F6")
const DIM := Color(0.86, 0.9, 0.93, 0.62)
const HINT := Color(0.86, 0.9, 0.93, 0.5)
## A glass panel's fill (Options, the credits): dark, translucent.
const PANEL := Color(0.02, 0.03, 0.045, 0.62)
## Type sizes.
const TITLE_SIZE := 56
const BUTTON_SIZE := 26
const HINT_SIZE := 15
const NOTE_SIZE := 17
## A menu list's left edge (px at the 1920 x 1080 base) and its width.
const LIST_LEFT := 180.0
const LIST_W := 460.0

static var _theme: Theme
static var _highlight: Texture2D


## Puts the cold glass Theme on a menu's root control (its children inherit it).
static func apply(c: Control) -> void:
	c.theme = theme()


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = HudStyle.font(false)
	t.default_font_size = 20
	var bold := HudStyle.font(true)
	# Buttons: plain type on nothing; the focused or hovered row gets the glass highlight.
	var normal := StyleBoxEmpty.new()
	_margins(normal)
	var lit := StyleBoxTexture.new()
	lit.texture = highlight_texture()
	lit.texture_margin_left = 4
	lit.texture_margin_right = 4
	lit.texture_margin_top = 2
	lit.texture_margin_bottom = 4
	_margins(lit)
	var hover := lit.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1, 1, 1, 0.6)
	var none := StyleBoxEmpty.new()
	_margins(none)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", lit)
	t.set_stylebox("hover_pressed", "Button", lit)
	t.set_stylebox("disabled", "Button", none)
	t.set_stylebox("focus", "Button", lit)
	t.set_font("font", "Button", bold)
	t.set_color("font_color", "Button", DIM)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", GLASS.lerp(Color.WHITE, 0.6))
	t.set_color("font_hover_pressed_color", "Button", GLASS.lerp(Color.WHITE, 0.6))
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.3))
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.55))
	t.set_constant("outline_size", "Button", 4)
	# Labels: plain type with a soft outline, readable over the blurred game.
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.3))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_color("default_color", "RichTextLabel", Color(TEXT, 0.85))
	# Panels (Options, credits): dark glass with a thin cold top edge.
	t.set_stylebox("panel", "PanelContainer", glass_panel())
	var sep := StyleBoxLine.new()
	sep.color = Color(GLASS, 0.22)
	sep.thickness = 1
	var vsep := sep.duplicate() as StyleBoxLine
	vsep.vertical = true
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("separator", "VSeparator", vsep)
	# Sliders (volumes): a thin track, the filled part in glass.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(GLASS, 0.8)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	_theme = t
	return t


## A dark glass panel with a thin cold top edge (Options, the credits, and v0.6.0 UP the shrine stats and threat
## panels shown in the pause menu); `margin` (left / right, top / bottom) pads its content.
static func glass_panel(margin: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.border_width_top = 1
	panel.border_color = Color(GLASS, 0.55)
	if margin == Vector2.ZERO:
		return panel  # the menus' own panels pad themselves
	panel.content_margin_left = margin.x
	panel.content_margin_right = margin.x
	panel.content_margin_top = margin.y
	panel.content_margin_bottom = margin.y
	return panel


## The focused row's highlight: a cold cyan wash fading to the right, a bright hairline along the bottom that fades
## the same way, and a short glass edge on the left. Built once in code (no image asset).
static func highlight_texture() -> Texture2D:
	if _highlight != null:
		return _highlight
	var w := 256
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		var u := float(x) / (w - 1)
		var wash := 0.2 * (1.0 - u) * (1.0 - u)
		var line := 0.95 * (1.0 - u)
		for y in h:
			var a := wash
			if y >= h - 2:
				a = line
			if x < 3:
				a = maxf(a, 0.75)
			img.set_pixel(x, y, Color(GLASS, a))
	_highlight = ImageTexture.create_from_image(img)
	return _highlight


## A small key-hint label (translated text is set by the caller or auto-translated from a key).
static func hint(key: String) -> Label:
	var l := Label.new()
	l.name = "Hint"
	l.text = key
	l.add_theme_font_size_override("font_size", HINT_SIZE)
	l.add_theme_color_override("font_color", HINT)
	return l


static func _margins(b: StyleBox) -> void:
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 8
	b.content_margin_bottom = 8
