class_name HudStyle
extends RefCounted
## The HUD's look (v0.3.5 F15, owner: "the HUD is fine but no so cyberpunk let's make it a bit more minimalistic"):
## one place for its colours, type and framing. The v0.3.0 techno/echo look (ghost copies, glitches, scanlines,
## brackets, end caps) is gone: plain type, thin lines, few elements, colour only where it carries state.
##
## Three calm directions were shown to the owner as G2 mockups (docs/roadmap/v0.3.5/evidence/hud_mockups.png):
##   LINE  - no plates; each group sits over one hairline;
##   BARE  - no plates and no lines: type and bars straight on the game (shipped: owner pick, 2026-10-07);
##   SLATE - flat, square, translucent dark plates; no lines.
## v0.5.5 A5 (owner pick, 2026-10-08: "ingame UI, heat, health and minimap from B"; mockup
## docs/roadmap/v0.5.5/evidence/ui_mockups/hud_b.png) adds the fourth, shipped:
##   EMBER - "Ember stone": chipped dark stone slabs with a warm ember line and glow along the bottom of the
##           important plates (HP, the top plate, heat); warm type. The minimap has no plate (owner: "we should
##           remove the black background"): it floats over the game with a dark halo under its lines.
## Swapping is one line: DEFAULT below (or set `HudStyle.current` before the HUD is built).
##
## Shared helpers for other HUD pieces:
##   HudStyle.style_label(label, size, bold)  - the style's font, size, colour and soft outline on a Label;
##   HudStyle.label(size, bold)                - a new Label styled that way (translated text is set by the caller);
##   HudStyle.font(bold)                       - the style's FontVariation (built on the bundled Atkinson TTFs);
##   HudStyle.accent() / text_color() / dim() / panel_bg() / line() / warn_color() - the colour tokens;
##   HudStyle.danger_color(heat)               - cool (0) to hot (1), for meters that heat up;
##   HudFrame.new()                            - a PanelContainer drawn as the style's plate (a hairline, or nothing);
##   HudBar.new()                              - a thin fill bar with a damage echo and a warn pulse;
##   HudStyle.draw_plate(ci, rect, ember, edge) - EMBER's stone slab drawn on any CanvasItem (the heat meter, the
##                                               ability slots and the boss bar draw their own).
## No outcome depends on any of this (EI-07): it only draws what WorldReader says.

enum Style { LINE, BARE, SLATE, EMBER }

## The shipped style (owner picks from the G2 mockups; one constant to swap). BARE was the v0.3.5 pick.
const DEFAULT := Style.EMBER
## Low-HP warning (L24): below this share of max HP the HP bar pulses red (starting value).
const LOW_HP_PERCENT := 30
## Warning pulses per second (starting value).
const PULSE_HZ := 2.0
const FONT_REGULAR := "res://assets/fonts/AtkinsonHyperlegible-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/AtkinsonHyperlegible-Bold.ttf"
const WARN := Color("#F0444A")
## Out-of-combat regen's pulse on the HP bar (v0.3.0 L25).
const REGEN := Color("#5BE38A")
## Cool to hot, for the danger meter: a muted steel blue, sand, orange, red.
const HEAT := [Color("#8FC3D6"), Color("#E8CB72"), Color("#EC8E4C"), Color("#F0444A")]
const TEXT := Color("#E9EDF0")
const ACCENT := Color("#9ED9E6")
## EMBER's tokens (starting values, from the B mockup): the stone's fill and edges, the warm type, the ember line,
## the HUD HP bar's red ("HP is a red bar") and the chamfer cut at a slab's corners (px).
const STONE := Color(0.105, 0.09, 0.082, 0.9)
const STONE_EDGE := Color(0.03, 0.025, 0.022, 0.95)
const STONE_LIGHT := Color(1.0, 0.92, 0.82, 0.07)
const EMBER_TEXT := Color("#F3E9DD")
const EMBER := Color("#F28A3A")
const EMBER_ACCENT := Color("#F7A65A")
const HP_RED := Color("#E0503F")
## The low-HP pulse on the red bar: toward a hot pale tone, so the warning reads on a bar that is already red.
const HP_WARN_HOT := Color("#FFD9C9")
const CHAMFER := 6.0
## The ember glow's height over the ember line (px).
const EMBER_GLOW := 14.0

## The style the HUD builds with.
static var current: Style = DEFAULT
## Calm mode: pulses hold steady. Set from the options (ViewPrefs.reduced_motion); read every frame.
static var reduced_motion := false
static var _fonts := {}


static func accent(s: Style = current) -> Color:
	return EMBER_ACCENT if s == Style.EMBER else ACCENT


static func text_color(s: Style = current) -> Color:
	return EMBER_TEXT if s == Style.EMBER else TEXT


## Secondary text and unlit parts.
static func dim(_s: Style = current) -> Color:
	return Color(TEXT, 0.3)


## A plate's fill (SLATE and EMBER draw plates).
static func panel_bg(s: Style = current) -> Color:
	return STONE if s == Style.EMBER else Color(0.03, 0.035, 0.045, 0.5)


## The HUD HP bar's fill: EMBER's red, else the player's bar token.
static func hp_color(s: Style = current) -> Color:
	return HP_RED if s == Style.EMBER else ThemePalette.color(&"player_bar")


## The colour a warned bar pulses toward (the low-HP warning).
static func warn_pulse(s: Style = current) -> Color:
	return HP_WARN_HOT if s == Style.EMBER else WARN


## The hairline under a group (LINE) and a bar's track edge.
static func line(_s: Style = current) -> Color:
	return Color(TEXT, 0.28)


static func warn_color() -> Color:
	return WARN


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


## The style's font: the bundled Atkinson Hyperlegible (OFL, assets/fonts/OFL.txt), plain: no tracking, no slant.
static func font(bold: bool = false, s: Style = current) -> FontVariation:
	var key := "%d_%s" % [s, bold]
	if _fonts.has(key):
		return _fonts[key]
	var v := FontVariation.new()
	v.base_font = load(FONT_BOLD if bold else FONT_REGULAR)
	_fonts[key] = v
	return v


## The style's type on a label: font, size, colour and a soft outline for legibility over the floor.
static func style_label(l: Label, size: int, bold: bool = false, s: Style = current) -> void:
	l.add_theme_font_override("font", font(bold, s))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", text_color(s))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.72))
	l.add_theme_constant_override("outline_size", 4 if size < 30 else 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.uppercase = false


## A plain HUD label in the style (it shows the text it is given; auto-translation is off, callers pass tr()).
static func label(size: int, bold: bool = false, s: Style = current) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(l, size, bold, s)
	return l


## The chamfered outline of a stone slab in `r` (corners cut unevenly, so the slabs read as chipped stone).
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


## A HUD side panel's box (v0.6.0 UP: the shrine stats, the threat panel): in EMBER an empty box (the panel draws
## its slab with draw_side_panel) padded by `margin`; the older styles keep the flat dark box with an `accent` top.
static func side_panel_box(margin: Vector2, accent: Color, s: Style = current) -> StyleBox:
	var box: StyleBox
	if s == Style.EMBER:
		box = StyleBoxEmpty.new()
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.03, 0.04, 0.07, 0.8)
		flat.border_color = Color(accent, 0.65)
		flat.border_width_top = 2
		box = flat
	box.content_margin_left = margin.x
	box.content_margin_right = margin.x
	box.content_margin_top = margin.y
	box.content_margin_bottom = margin.y
	return box


## EMBER: a side panel's stone slab over its whole rect, with its `accent` (the shrine's or the curses' colour) as a
## short line along the top, the way an ability slot carries its colour.
static func draw_side_panel(c: Control, accent: Color, s: Style = current) -> void:
	if s != Style.EMBER:
		return
	draw_plate(c, Rect2(Vector2.ZERO, c.size))
	c.draw_rect(
		Rect2(Vector2(CHAMFER + 4.0, 2.0), Vector2(c.size.x * 0.4, 2.0)), Color(accent, 0.9)
	)


## EMBER's stone slab on `ci` in `r`: the stone fill, a faint lit top edge, a dark rim (`edge` tints it, for the
## low-HP warning) and, when `ember`, the warm ember line with its glow along the bottom.
static func draw_plate(
	ci: CanvasItem, r: Rect2, ember: bool = false, edge: Color = STONE_EDGE, fill: Color = STONE
) -> void:
	var pts := plate_points(r)
	ci.draw_colored_polygon(pts, fill)
	ci.draw_line(pts[0] + Vector2(0, 1.5), pts[1] + Vector2(0, 1.5), STONE_LIGHT, 1.0)
	if ember:
		var inset := minf(14.0, r.size.x * 0.08)
		var y := r.end.y - 3.0
		var glow := minf(EMBER_GLOW, r.size.y * 0.6)
		var a := Vector2(r.position.x + inset, y)
		var b := Vector2(r.end.x - inset, y)
		var cols := PackedColorArray(
			[Color(EMBER, 0.0), Color(EMBER, 0.0), Color(EMBER, 0.26), Color(EMBER, 0.26)]
		)
		ci.draw_polygon(
			PackedVector2Array([a - Vector2(0, glow), b - Vector2(0, glow), b, a]), cols
		)
		ci.draw_line(a, b, Color(EMBER, 0.95), 2.0)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, edge, 1.5, true)
