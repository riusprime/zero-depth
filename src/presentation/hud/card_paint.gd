class_name CardPaint
extends RefCounted
## v0.8.0 N8 (owner O62: "Give each rarity its own color, and don't use it only on the board. Paint the whole card.
## And write the rarity out, because color alone isn't enough."): how a card wears its rarity. The colour is the
## tier's (PickSlot.TIERS: Common grey, Rare blue, Epic purple, Legendary gold; an ability card the hero's cyan); the
## slab's stone is tinted toward it (face and back), its frame line and its glow are it, and the rarity's word stays on
## the card (StoneCard's foot). The tint is kept dark (FACE_VALUE) so the warm text keeps its contrast (the unit test
## checks the ratio). Presentation only (EI-07).

## The rarity's colour taken down to this value (its hue kept, dark as stone), and how far the stone leans to it.
const FACE_VALUE := 0.19
const FACE_MIX := 0.8
## The text's least contrast ratio on a painted face (WCAG's 4.5:1 for body text).
const MIN_CONTRAST := 4.5


## The slab's fill for a card of rarity colour `c`.
static func face(c: Color) -> Color:
	var top := maxf(c.r, maxf(c.g, c.b))
	var dark := Color(c.r, c.g, c.b) * (FACE_VALUE / maxf(top, 0.001))
	return EmberStone.STONE.lerp(Color(dark.r, dark.g, dark.b), FACE_MIX)


## The brightest the face gets behind its text as StoneBox draws it (focused, the ember glow under it, at the text's
## lowest band, 80 % down the card; the grain at its lightest), for the contrast check.
static func face_peak(c: Color) -> Color:
	var f := face(c)
	var t := 0.8
	var lit := Color(f.r, f.g, f.b) * lerpf(0.8, 1.12, t) * 1.45
	var warm := pow(t, 4.0) * (0.03 + 0.1 * 0.8 + 0.2) * 1.6
	return lit + Color(EmberStone.EMBER.r, EmberStone.EMBER.g, EmberStone.EMBER.b) * warm


## WCAG relative luminance and contrast ratio.
static func luminance(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
