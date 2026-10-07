class_name CardStyle
extends RefCounted
## The cards' look (v0.3.5 F16, owner: "the card select from chests and altars are way too AI slop, we should not
## have the rounded card with the color shadow at the left, change it to match the style of the game"): the pick
## cards, the item and combo cards and the gamble card share one flat, square, low-poly panel: a dark fill, a thin
## neutral outline (bright when focused), no rounded corners, no shadow, no coloured side bar. Colour is kept for
## what it means: the item's name, and the rarity as a small faceted mark (CardMark).
##
## Three looks were shown to the owner as G2 mockups (docs/roadmap/v0.3.5/evidence/card_mockups.png):
##   FLAT  - square corners, a 1 px outline;
##   FACET - the same with two opposite corners cut, like the game's chamfered low-poly shapes (shipped: owner pick, 2026-10-07);
##   RULE  - square, no outline; a thin rule along the top edge, in the card's colour.
## Swapping is one line: DEFAULT below (or set `CardStyle.current` before the cards are built).

enum Look { FLAT, FACET, RULE }

const DEFAULT := Look.FACET
const BG := Color(0.035, 0.04, 0.05, 0.9)
const BG_FOCUS := Color(0.075, 0.085, 0.1, 0.95)
const EDGE := Color(0.8, 0.84, 0.88, 0.3)
const EDGE_FOCUS := Color(0.94, 0.96, 0.98, 0.95)
## FACET's corner cut (px).
const CUT := 10

static var current: Look = DEFAULT


## Styles `box` as a card: `accent` is the card's colour (RULE draws it), `focused` brightens the outline and fill.
static func apply(
	box: StyleBoxFlat, accent: Color, focused: bool = false, look: Look = current
) -> void:
	box.bg_color = BG_FOCUS if focused else BG
	box.set_corner_radius_all(0)
	box.corner_detail = 1
	box.shadow_size = 0
	box.shadow_color = Color(0, 0, 0, 0)
	box.anti_aliasing = false
	box.set_border_width_all(2 if focused else 1)
	box.border_color = EDGE_FOCUS if focused else EDGE
	match look:
		Look.FACET:
			box.corner_radius_top_left = CUT
			box.corner_radius_bottom_right = CUT
			box.anti_aliasing = true
		Look.RULE:
			box.set_border_width_all(0)
			box.border_width_top = 3 if focused else 2
			box.border_color = accent if focused else Color(accent, 0.7)


## A new card StyleBoxFlat with these content margins (px).
static func box(margin: Vector4, accent: Color = EDGE, look: Look = current) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.content_margin_left = margin.x
	b.content_margin_top = margin.y
	b.content_margin_right = margin.z
	b.content_margin_bottom = margin.w
	apply(b, accent, false, look)
	return b


## True when the box has no rounded corner, no shadow and no side thicker than the rest (tests).
static func is_plain(b: StyleBoxFlat) -> bool:
	var square := (
		b.corner_radius_top_right == 0
		and b.corner_radius_bottom_left == 0
		and (b.corner_detail == 1 or b.corner_radius_top_left == 0)
	)
	var even := b.border_width_left <= b.border_width_right and b.border_width_left <= 3
	return square and b.shadow_size == 0 and even
