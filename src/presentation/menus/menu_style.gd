class_name MenuStyle
extends RefCounted
## The menus' look: "Ember stone" (v0.8.0 MU, owner O14: "we're just throwing away the shard cards we're gonna be
## using a different style that matches more the game"; G2 pick "menu style B", docs/roadmap/v0.8.0/evidence/
## MENU_G2.md; it replaces v0.5.5 A5's "Cold glass"). Dark carved stone slabs lit from below by warm embers
## (StoneBox, EmberStone): a menu's list sits on a slab; the focused row is a small ember-lit slab with a glowing
## groove and an ember diamond beside it (MenuPanel's EmberMarker), so focus reads the same for the mouse, the keys
## and the pad; warm type; the game (or, with nothing behind, an ember-lit stone scene) behind with sparks rising
## (MenuBackdrop). One Theme for every full-screen menu (main menu, pause, options, credits, the Codex, the run recap,
## the build picker, the Build page): `MenuStyle.apply(control)` sets it on a menu's root.
## Presentation only (EI-07): nothing here decides an outcome.

## The ember accent and the type (EmberStone's tokens).
const EMBER := EmberStone.EMBER
const TEXT := EmberStone.TEXT
const DIM := EmberStone.DIM
const HINT := EmberStone.HINT
## A row's or a tile's dark fill where a flat box is still wanted (a dimmed empty slot).
const PANEL := Color(0.05, 0.04, 0.035, 0.7)
## Type sizes.
const TITLE_SIZE := 56
const BUTTON_SIZE := 26
const HINT_SIZE := 15
const NOTE_SIZE := 17
## A menu list's left edge (px at the 1920 x 1080 base) and its width.
const LIST_LEFT := 180.0
const LIST_W := 460.0
## The slab a menu's list sits on: its padding round the list.
const SLAB_PAD := Vector2(38, 44)

static var _theme: Theme


## Puts the Ember stone Theme on a menu's root control (its children inherit it).
static func apply(c: Control) -> void:
	c.theme = theme()


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = HudStyle.font(false)
	t.default_font_size = 20
	var bold := HudStyle.font(true)
	# Buttons: plain type on the stone; the focused or pressed row is an ember-lit slab, a hovered one half lit.
	var normal := StyleBoxEmpty.new()
	_margins(normal)
	var lit := row_slab(1.0)
	var hover := row_slab(0.45)
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
	t.set_color("font_pressed_color", "Button", EMBER.lerp(Color.WHITE, 0.55))
	t.set_color("font_hover_pressed_color", "Button", EMBER.lerp(Color.WHITE, 0.55))
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.3))
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Button", 4)
	# Labels: warm type with a soft outline, readable over the stone and the blurred game.
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.3))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_color("default_color", "RichTextLabel", Color(TEXT, 0.88))
	# Panels (Options, credits, the Codex's detail): a stone slab.
	t.set_stylebox("panel", "PanelContainer", stone_panel())
	var sep := StyleBoxLine.new()
	sep.color = Color(EMBER, 0.28)
	sep.thickness = 1
	var vsep := sep.duplicate() as StyleBoxLine
	vsep.vertical = true
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("separator", "VSeparator", vsep)
	# Sliders (volumes): a dark carved track, the filled part glowing ember.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(EmberStone.GROOVE, 0.9)
	track.border_color = Color(1, 0.92, 0.82, 0.08)
	track.border_width_bottom = 1
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(EMBER, 0.85)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	# Scroll bars (the Codex, the credits): a thin carved groove, the grabber ember.
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(EmberStone.GROOVE, 0.6)
	groove.content_margin_left = 3
	groove.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(EMBER, 0.55)
	var grab_lit := grab.duplicate() as StyleBoxFlat
	grab_lit.bg_color = Color(EMBER, 0.9)
	t.set_stylebox("scroll", "VScrollBar", groove)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_lit)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_lit)
	_theme = t
	return t


## A stone slab panel (Options, the credits, the Codex's detail, and in the pause menu the shrine stats and threat
## panels); `margin` (left / right, top / bottom) pads its content.
static func stone_panel(margin: Vector2 = Vector2.ZERO, pattern: int = 3) -> StoneBox:
	var b := StoneBox.make(margin, pattern)
	b.under = 0.28
	b.cut = 16.0
	b.cracks = 3
	return b


## A menu row's slab at `lit` (1 focused or pressed, less when hovered): a small ember-lit slab with a glowing groove
## along its foot.
static func row_slab(lit: float) -> StoneBox:
	var b := StoneBox.make()
	_margins(b)
	b.pattern = 11
	b.cut = 8.0
	b.chip = 2.0
	b.cracks = 1
	b.under = 0.3 * lit
	b.focus = lit
	b.dim = lerpf(0.9, 1.05, lit)
	b.inlay = Color(EMBER, lit)
	b.inlay_y = 5.0
	b.shadow = lit >= 1.0
	return b


## A tile's slab (the Codex's tiles, the wand's slots, the achievement rows): its family's or page's colour as the
## glowing groove along its foot (or `ring` round its picture), lit when focused, dimmed when locked or empty.
static func tile_slab(
	tint: Color,
	focused: bool,
	quiet: bool = false,
	pattern: int = 0,
	margin: Vector2 = Vector2(4, 4)
) -> StoneBox:
	var b := StoneBox.make(margin, pattern)
	b.cut = 9.0
	b.chip = 2.2
	b.cracks = 1
	b.under = 0.12 if quiet else 0.22
	b.focus = 1.0 if focused else 0.0
	b.dim = 1.08 if focused else (0.62 if quiet else 0.86)
	b.inlay = Color(tint, 0.35 if quiet else 0.95)
	b.inlay_y = 6.0
	return b


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
