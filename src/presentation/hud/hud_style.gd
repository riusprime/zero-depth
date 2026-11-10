class_name HudStyle
extends RefCounted
## The HUD's look: one place for its colours, type and framing. No outcome depends on any of this (EI-07): it only
## draws what WorldReader says.
##
## v0.10.5 W3-O17 (owner, 2026-11-04: "and what about the rest of the UI? it should match the new style"; the UI style
## Astral, W3_O13_UI_STYLE_G2.md round 2; the HP bar after ref 04: "a continuous bar not split in parts"): Astral, the
## HUD's one style (v0.11.1 Step 12, owner 2026-11-10: "Astral current one live should be the only HUD style for all
## elements throughout the game"; the older LINE, BARE, SLATE and EMBER looks are gone):
##   unboxed: no slabs; thin crisp 1 px lines in lilac-tinted silver, four-point stars, diamonds and crescents
##   (AstralChrome, AstralHudParts); Cinzel for titles and numbers, Atkinson for small text; a faint ink wash under the
##   top and bottom rows; one moon-blue accent, heat the only warm colour (a muted amber).
##
## Shared helpers for other HUD pieces:
##   HudStyle.style_label(label, size, bold)  - the HUD's font, size, colour and soft outline on a Label;
##   HudStyle.serif_label(label, size, ...)   - the same in Astral's title type (Cinzel);
##   HudStyle.label(size, bold)                - a new Label styled that way (translated text is set by the caller);
##   HudStyle.font(bold)                       - the HUD's FontVariation (built on the bundled Atkinson TTFs);
##   HudStyle.accent() / text_color() / dim() / warn() / heal() - the colour tokens (the A_ constants);
##   HudFrame.new()                            - a PanelContainer that pads a group (it draws nothing);
##   HudBar.new()                              - a thin fill bar with a damage echo and a warn pulse.

## Low-HP warning (L24): below this share of max HP the HP bar pulses red (starting value).
const LOW_HP_PERCENT := 30
## Warning pulses per second (starting value).
const PULSE_HZ := 2.0
const FONT_REGULAR := "res://assets/fonts/AtkinsonHyperlegible-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/AtkinsonHyperlegible-Bold.ttf"
## A bright warning red (the event pedestal's "away" line).
const WARN := Color("#F0444A")
## Cool to hot, for the danger meter: a muted steel blue, sand, orange, red.
const HEAT := [Color("#8FC3D6"), Color("#E8CB72"), Color("#EC8E4C"), Color("#F0444A")]
## The default corner cut of plate_points (px).
const CHAMFER := 6.0
## ASTRAL's tokens (W3_O13_UI_STYLE_G2.md round 2, Astral; AstralCardArt holds the same): text / dim, contour /
## focused contour, the moon-blue accent, the silver of the ornaments, the HP bar, the heat's muted amber, the ink under
## the lines, and the warning (low HP, the full danger bar): a muted rose-red, the palette's "too poor" deepened.
const A_TEXT := Color("#ECEEFA")
const A_DIM := Color("#9095B4")
const A_LINE := Color("#6E76A0")
const A_LINE_HI := Color("#E4E6FF")
const A_ACCENT := Color("#B5BDF0")
const A_METAL := Color("#C9CCE6")
const A_HP := Color("#B4BFF0")
const A_HEAT := Color("#D6A878")
const A_INK := Color("#070913")
const A_WARN := Color("#E0566C")
## ASTRAL's heal: a pale moon-green (the gain line's family, no mint), for the regen pulse and the max-HP line.
const A_HEAL := Color("#A8DCC4")
## v0.10.5 W3-O20: ASTRAL's water (a shrine's cleanse): a cold moon-blue, apart from the lilac accent.
const A_WATER := Color("#9CC8E8")
## v0.10.5 W3-O20 (owner 2026-11-04 night: every UI element Astral; the 720p shots read 13 px labels as ~9 px): the
## smallest HUD type (px at the 1920 x 1080 base). The HUD's label helpers raise a smaller size to it, so no HUD text
## draws under 11 px at 1280 x 720 (17 x 2/3 = 11.3).
const MIN_LABEL := 17

## Calm mode: pulses hold steady. Set from the options (ViewPrefs.reduced_motion); read every frame.
static var reduced_motion := false
static var _fonts := {}


static func accent() -> Color:
	return A_ACCENT


static func text_color() -> Color:
	return A_TEXT


## Secondary text and unlit parts.
static func dim() -> Color:
	return A_DIM


## The warning colour (low HP, a full danger bar): Astral's muted rose-red.
static func warn() -> Color:
	return A_WARN


## The heal colour (the regen pulse, the max-HP line): Astral's pale moon-green.
static func heal() -> Color:
	return A_HEAL


## P-7: sets a label's font colour override only when it differs (an override invalidates the label's theme cache and
## re-shapes its text, so a per-tick sync of an unchanged colour costs a re-layout for nothing).
static func font_color(l: Control, c: Color) -> void:
	if l.has_theme_color_override(&"font_color") and l.get_theme_color(&"font_color") == c:
		return
	l.add_theme_color_override(&"font_color", c)


## The HUD HP bar's fill.
static func hp_color() -> Color:
	return A_HP


## The colour a warned bar pulses toward (the low-HP warning).
static func warn_pulse() -> Color:
	return A_WARN


## 0 (cool) .. 1 (hot), through HEAT.
static func danger_color(heat: float) -> Color:
	var h := clampf(heat, 0.0, 1.0) * (HEAT.size() - 1)
	var i := mini(int(h), HEAT.size() - 2)
	return (HEAT[i] as Color).lerp(HEAT[i + 1], h - i)


## True below LOW_HP_PERCENT of max HP (integer maths; a dead player is not "low", the recap takes over).
static func low_hp(hp: int, max_hp: int) -> bool:
	return hp > 0 and hp * 100 < maxi(1, max_hp) * LOW_HP_PERCENT


## A 0..1 pulse at PULSE_HZ for time `t` (s); steady 1 in calm mode.
static func pulse(t: float) -> float:
	if reduced_motion:
		return 1.0
	return 0.5 + 0.5 * cos(t * TAU * PULSE_HZ)


## The HUD's font: the bundled Atkinson Hyperlegible (OFL, assets/fonts/OFL.txt), plain: no tracking, no slant.
static func font(bold: bool = false) -> FontVariation:
	if _fonts.has(bold):
		return _fonts[bold]
	var v := FontVariation.new()
	v.base_font = load(FONT_BOLD if bold else FONT_REGULAR)
	_fonts[bold] = v
	return v


## ASTRAL's title type: Cinzel (its lowercase are small capitals, so a label needs no uppercase) at weight `wght`,
## letter-spaced `track` px (AstralCardArt.serif: the cards' and the menus' face).
static func serif(wght: int = 600, track: int = 2) -> FontVariation:
	return AstralCardArt.serif(wght, track)


## A label in Astral's title type: Cinzel at `size`, tracked, in `col`, with a thin dark outline for the floor.
static func serif_label(
	l: Label, size: int, track: int = 2, col: Color = A_TEXT, wght := 600
) -> void:
	size = maxi(size, MIN_LABEL)  # v0.10.5 W3-O20
	l.add_theme_font_override("font", serif(wght, track))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(A_INK, 0.8))
	l.add_theme_constant_override("outline_size", 4 if size < 30 else 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)


## The HUD's type on a label: font, size, colour and a soft outline for legibility over the floor.
static func style_label(l: Label, size: int, bold: bool = false) -> void:
	size = maxi(size, MIN_LABEL)  # v0.10.5 W3-O20
	l.add_theme_font_override("font", font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", A_TEXT)
	l.add_theme_color_override("font_outline_color", Color(A_INK, 0.8))
	l.add_theme_constant_override("outline_size", 4 if size < 30 else 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.uppercase = false


## A plain HUD label in the HUD's type (it shows the text it is given; auto-translation is off, callers pass tr()).
static func label(size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(l, size, bold)
	return l


## v0.10.5 W3-O20: an icon's or a name's own colour `c` (an item's family, a stat) toned toward Astral's silver, so it
## keeps its hue but sits in the palette.
static func tone(c: Color) -> Color:
	return Color(c.lerp(A_METAL, 0.45), c.a)


## v0.10.5 W3-O20: a small icon tile (GambleIconView, ItemIconView, ComboIconView): AstralChrome.FrameBox
## (ink, a 1 px frame, an inner frame, a small diamond on top), its frame tinted by the icon's `c`.
static func draw_astral_tile(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var box := AstralChrome.FrameBox.new()
	box.rim = Color(A_LINE.lerp(c, 0.4), 0.95)
	ci.draw_style_box(box, r)


## v0.10.5 W3-O20: a top banner (Lockdown, the arena, a shrine): its `title` in letter-spaced Cinzel, its `line` in
## Atkinson, and a fading hairline with a small star between them (AstralChrome.Rule) in `box`.
static func astral_banner(box: BoxContainer, title: Label, line: Label) -> void:
	serif_label(title, 28, 6, A_TEXT)
	style_label(line, 18, false)
	var rule := AstralChrome.Rule.new(150.0)
	rule.name = "BannerRule"
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	box.move_child(rule, title.get_index() + 1)
	box.add_theme_constant_override("separation", 0)


## A chamfered outline in `r`, its corners cut unevenly (AchievementIcon's badge).
static func plate_points(r: Rect2, cut: float = CHAMFER) -> PackedVector2Array:
	var c := minf(cut, minf(r.size.x, r.size.y) * 0.3)
	var p := r.position
	var e := r.end
	return PackedVector2Array(
		[
			Vector2(p.x + c, p.y),
			Vector2(e.x - c * 0.5, p.y),
			Vector2(e.x, p.y + c * 0.5),
			Vector2(e.x, e.y - c),
			Vector2(e.x - c, e.y),
			Vector2(p.x + c * 0.5, e.y),
			Vector2(p.x, e.y - c * 0.5),
			Vector2(p.x, p.y + c),
		]
	)


## A HUD side panel's box (v0.6.0 UP: the shrine stats, the threat panel, the DPS meter): an empty box padded by
## `margin` (v0.10.5 W3-O17: the panel draws itself, draw_side_panel).
static func side_panel_box(margin: Vector2) -> StyleBox:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = margin.x
	box.content_margin_right = margin.x
	box.content_margin_top = margin.y
	box.content_margin_bottom = margin.y
	return box


## v0.10.5 W3-O17: a side panel over `c`'s whole rect: Astral's ink panel, a contour, an inner contour, and its `accent`
## (the shrine's or the curses' colour) as a short line on its top.
static func draw_side_panel(c: Control, accent: Color) -> void:
	var r := Rect2(Vector2.ZERO, c.size.round())
	c.draw_rect(r, AstralChrome.FILL)
	AstralHudParts.frame(c, r, Color(A_LINE, 0.95))
	AstralHudParts.frame(c, r.grow(-6.0), Color(A_LINE, 0.25))
	AstralChrome.hline(c, 12.0, 12.0 + roundf(r.size.x * 0.3), 3.0, Color(accent, 0.85))
