class_name HudStyle
extends RefCounted
## The HUD's look (v0.3.5 F15, owner: "the HUD is fine but no so cyberpunk let's make it a bit more minimalistic"):
## one place for its colours, type and framing. The v0.3.0 techno/echo look (ghost copies, glitches, scanlines,
## brackets, end caps) is gone: plain type, thin lines, few elements, colour only where it carries state.
##
## Three calm directions were shown to the owner as G2 mockups (docs/roadmap/v0.3.5/evidence/hud_mockups.png):
##   LINE  - no plates; each group sits over one hairline (the shipped default);
##   BARE  - no plates and no lines: type and bars straight on the game;
##   SLATE - flat, square, translucent dark plates; no lines.
## Swapping is one line: DEFAULT below (or set `HudStyle.current` before the HUD is built).
##
## Shared helpers for other HUD pieces:
##   HudStyle.style_label(label, size, bold)  - the style's font, size, colour and soft outline on a Label;
##   HudStyle.label(size, bold)                - a new Label styled that way (translated text is set by the caller);
##   HudStyle.font(bold)                       - the style's FontVariation (built on the bundled Atkinson TTFs);
##   HudStyle.accent() / text_color() / dim() / panel_bg() / line() / warn_color() - the colour tokens;
##   HudStyle.danger_color(heat)               - cool (0) to hot (1), for meters that heat up;
##   HudFrame.new()                            - a PanelContainer drawn as the style's plate (a hairline, or nothing);
##   HudBar.new()                              - a thin fill bar with a damage echo and a warn pulse.
## No outcome depends on any of this (EI-07): it only draws what WorldReader says.

enum Style { LINE, BARE, SLATE }

## The shipped style (owner picks from the G2 mockups; one constant to swap).
const DEFAULT := Style.LINE
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

## The style the HUD builds with.
static var current: Style = DEFAULT
## Calm mode: pulses hold steady. Set from the options (ViewPrefs.reduced_motion); read every frame.
static var reduced_motion := false
static var _fonts := {}


static func accent(_s: Style = current) -> Color:
	return ACCENT


static func text_color(_s: Style = current) -> Color:
	return TEXT


## Secondary text and unlit parts.
static func dim(_s: Style = current) -> Color:
	return Color(TEXT, 0.3)


## A plate's fill (SLATE only draws plates).
static func panel_bg(_s: Style = current) -> Color:
	return Color(0.03, 0.035, 0.045, 0.5)


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
