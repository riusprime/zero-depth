class_name HudStyle
extends RefCounted
## The HUD's look (PLAN v0.3.0 L21, UI): one place for its colours, type and framing, so every HUD piece (and the
## pick panel, start screen and heat meter when their owners adopt it) reads as one techno/echo system.
##
## Three directions were shown to the owner as G2 mockups (docs/roadmap/v0.3.0/evidence/hud_mockups.png):
##   TERMINAL   - wide-tracked condensed caps, corner brackets, scanlines, a red/cyan chromatic split;
##   HOLO_ECHO  - cyan holographic panels; text trails fading echo copies of itself (the shipped default);
##   INDUSTRIAL - chamfered gunmetal plates, slanted heavy caps, segmented bars, a hazard-amber accent.
## Swapping is one line: DEFAULT below (or set `HudStyle.current` before the HUD is built).
##
## Shared helpers for other HUD pieces:
##   HudStyle.style_label(label, size, bold)  - the style's font, tracking, caps and text colour on a Label;
##   HudStyle.font(bold)                       - the style's FontVariation (built on the bundled Atkinson TTFs);
##   HudStyle.accent() / text_color() / dim() / panel_bg() / warn_color() - the style's colour tokens;
##   HudStyle.danger_color(heat)               - cool (0) to hot (1), for meters that heat up;
##   HudFrame.new()                            - a PanelContainer drawn as the style's plate;
##   HudBar.new()                              - a fill bar drawn in the style, with a damage echo and a warn pulse;
##   EchoLabel.new(size, bold)                 - a Label with the style's ghost copies and a glitch on change.
## No outcome depends on any of this (EI-07): it only draws what WorldReader says.

enum Style { TERMINAL, HOLO_ECHO, INDUSTRIAL }

## The shipped style (owner picks from the G2 mockups; one constant to swap).
const DEFAULT := Style.HOLO_ECHO
## Low-HP warning (L24): below this share of max HP the HP bar pulses red (starting value).
const LOW_HP_PERCENT := 30
## Warning pulses per second (starting value).
const PULSE_HZ := 2.0
## A value change makes its label echo/glitch for this long (s).
const ECHO_S := 0.45
const FONT_REGULAR := "res://assets/fonts/AtkinsonHyperlegible-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/AtkinsonHyperlegible-Bold.ttf"
const WARN := Color("#FF2E3A")
## Out-of-combat regen's pulse on the HP bar (v0.3.0 L25).
const REGEN := Color("#5BE38A")
## Cool to hot, for the danger meter: cyan, yellow, orange, red.
const HEAT := [Color("#3FD8FF"), Color("#FFD24A"), Color("#FF7A2E"), Color("#FF2E3A")]

## The style the HUD builds with.
static var current: Style = DEFAULT
## Calm mode: pulses hold steady and glitches don't move. No options row sets it yet; the options workstream can
## wire a setting to it (it is read every frame).
static var reduced_motion := false
static var _fonts := {}


static func accent(s: Style = current) -> Color:
	match s:
		Style.TERMINAL:
			return Color("#E6F4F1")
		Style.INDUSTRIAL:
			return Color("#F2A93B")
	return Color("#5FE8FF")


static func text_color(s: Style = current) -> Color:
	match s:
		Style.TERMINAL:
			return Color("#E6F4F1")
		Style.INDUSTRIAL:
			return Color("#ECE6DA")
	return Color("#DFFBFF")


## Secondary text and unlit parts.
static func dim(s: Style = current) -> Color:
	match s:
		Style.TERMINAL:
			return Color(0.75, 0.82, 0.8, 0.32)
		Style.INDUSTRIAL:
			return Color(0.55, 0.55, 0.52, 0.55)
	return Color(0.37, 0.91, 1.0, 0.25)


static func panel_bg(s: Style = current) -> Color:
	match s:
		Style.TERMINAL:
			return Color(0.01, 0.02, 0.03, 0.62)
		Style.INDUSTRIAL:
			return Color(0.14, 0.15, 0.17, 0.88)
	return Color(0.02, 0.12, 0.17, 0.55)


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


## The style's font: the bundled Atkinson Hyperlegible (OFL, assets/fonts/OFL.txt) with tracking and shape.
static func font(bold: bool = false, s: Style = current) -> FontVariation:
	var key := "%d_%s" % [s, bold]
	if _fonts.has(key):
		return _fonts[key]
	var v := FontVariation.new()
	v.base_font = load(FONT_BOLD if bold else FONT_REGULAR)
	match s:
		Style.TERMINAL:
			v.spacing_glyph = 3
			v.variation_transform = Transform2D(Vector2(0.86, 0), Vector2(0, 1), Vector2.ZERO)
		Style.INDUSTRIAL:
			v.spacing_glyph = 2
			v.variation_embolden = 0.5 if bold else 0.25
			v.variation_transform = Transform2D(Vector2(1.04, 0), Vector2(-0.16, 1), Vector2.ZERO)
		_:
			v.spacing_glyph = 3
			v.variation_transform = Transform2D(Vector2(1.06, 0), Vector2(0, 1), Vector2.ZERO)
	_fonts[key] = v
	return v


## The style's type on a label: font, size, caps, colour and a soft outline for legibility over the floor.
static func style_label(l: Label, size: int, bold: bool = false, s: Style = current) -> void:
	l.add_theme_font_override("font", font(bold, s))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", text_color(s))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4 if size < 30 else 8)
	l.uppercase = true


## Ghost copies an EchoLabel draws behind its text: [offset, colour] pairs.
static func ghosts(s: Style = current) -> Array:
	match s:
		Style.TERMINAL:
			return [
				[Vector2(-1.5, 0), Color(1.0, 0.18, 0.3, 0.55)],
				[Vector2(1.5, 0), Color(0.2, 0.9, 1.0, 0.55)]
			]
		Style.INDUSTRIAL:
			return [[Vector2(2, 2), Color(0, 0, 0, 0.85)]]
	var a := accent(s)
	return [[Vector2(2, 1.5), Color(a, 0.3)], [Vector2(4, 3), Color(a, 0.12)]]
