class_name Plaques
extends RefCounted
## The owner's wide crystal plaques (v0.6.1 R1, owner: "does this fit the arts missing for the old card look?"). The
## 12 plaques are the owner's art, cropped by scripts/art/crop_plaques.py into assets/ui/plaques/ (manifest.json lists
## each with its hash, size, dark panel, text box and nine-slice margins).
##
## A plaque is drawn as a nine-slice (PlaqueBox): the crystal end-clusters keep their shape at the plaque's scale and
## only the plain middle stretches, so one plaque fits any width. Text sits in the dark inner panel (CONTENT).
## **Colour comes from the card frames' table** (CardFrames.FRAME: family → colour; the plaque of a colour is the frame
## of that colour). USE_FAMILY says which family a plaque that is not a card wears (the shop's services, Leave, the
## banner); a card's plaque uses CardFrames.family like its frame. Presentation only (EI-07): nothing here changes an
## outcome.

const DIR := "res://assets/ui/plaques/"
## Every plaque's size in the PNGs (px).
const SIZE := Vector2(488, 201)
## Nine-slice margins (plaque px), one set for all twelve: left and right cover every plaque's end-clusters and loose
## gems, top and bottom leave a plain band inside every plaque's dark panel (the manifest's per-plaque `nine_slice`
## are all inside these; tests/content/test_plaque_assets.gd checks it).
const SLICE_LEFT := 167
const SLICE_TOP := 101
const SLICE_RIGHT := 144
const SLICE_BOTTOM := 94
## Where text sits, in plaque px at scale 1: inside every plaque's clear dark panel (the manifest's `text` boxes).
const CONTENT := Rect2(162, 58, 175, 92)

## What a plaque that is not a card wears (a family of CardFrames.FRAME).
const USE_FAMILY := {
	&"shop_heal": &"healing",
	&"shop_reroll": &"economy",
	&"shop_cleanse": &"curse",
	&"event_leave": &"time",
	&"event_shards": &"economy",
	&"event_chest": &"economy",
	&"event_overclock": &"fire",
	&"event_cleanse": &"healing",
	&"banner": &"epic",
}
## The shrine's stats (GambleIcons ids) → family.
const GAMBLE_FAMILY := {
	&"max_hp": &"healing",
	&"melee_damage": &"damage",
	&"shot_damage": &"projectile",
	&"move_speed": &"dash",
	&"dash_cooldown": &"time",
	&"regen": &"healing",
	&"heat_capacity": &"fire",
	&"shard_gain": &"economy",
}
## An unfocused plaque is drawn a little dimmer (CardFrames.frame_modulate).
const IDLE := Color(0.8, 0.8, 0.82)

static var _cache := {}


## The plaque (a colour id) a family wears: the card frames' table.
static func of_family(fam: StringName) -> StringName:
	return CardFrames.frame_of(fam)


## The plaque of a use in USE_FAMILY.
static func of_use(use: StringName) -> StringName:
	return of_family(USE_FAMILY.get(use, CardFrames.DEFAULT_FAMILY))


## The plaque of card `id` (CardFrames.family: type, tier, cursed as for its frame).
static func of_card(
	id: StringName, type: int = -1, tier: int = 0, cursed: bool = false
) -> StringName:
	return of_family(CardFrames.family(id, type, tier, cursed))


## The plaque of a shrine stat.
static func of_gamble(stat: StringName) -> StringName:
	return of_family(GAMBLE_FAMILY.get(stat, CardFrames.DEFAULT_FAMILY))


## The plaque whose tint is nearest `c` (a combo's own colour, which has no family): hue first, then lightness.
static func nearest(c: Color) -> StringName:
	var best := CardFrames.FRAME[CardFrames.DEFAULT_FAMILY] as StringName
	var best_d := INF
	for fam: StringName in CardFrames.FRAME:
		var id: StringName = CardFrames.FRAME[fam]
		var t := CardFrames.tint(id)
		var dh := absf(c.h - t.h)
		dh = minf(dh, 1.0 - dh)
		var d := dh * 4.0 * minf(c.s, t.s) + absf(c.s - t.s) + absf(c.v - t.v) * 0.5
		if d < best_d:
			best_d = d
			best = id
	return best


## The plaque's tint (its title colour): the card frame tint of the same colour.
static func tint(plaque: StringName) -> Color:
	return CardFrames.tint(plaque)


static func path(plaque: StringName) -> String:
	return DIR + "plaque_%s.png" % plaque


## The plaque's texture (loaded once).
static func texture(plaque: StringName) -> Texture2D:
	if not _cache.has(plaque):
		_cache[plaque] = load(path(plaque))
	return _cache[plaque]


## A plaque style box `height` px tall at its natural size (the scale is height / SIZE.y); `pad` adds px inside the
## text box on the left and right.
static func box(plaque: StringName, height: float, pad: float = 0.0) -> PlaqueBox:
	return PlaqueBox.new(plaque, height / SIZE.y, pad)


## The text box's size (px) of a plaque `height` px tall and `width` px wide.
static func content_size(height: float, width: float, pad: float = 0.0) -> Vector2:
	var s := height / SIZE.y
	return Vector2(width - (SIZE.x - CONTENT.size.x) * s - pad * 2.0, CONTENT.size.y * s)


## The narrowest plaque (px) whose text box is `content_w` wide at `height`.
static func width_for(content_w: float, height: float, pad: float = 0.0) -> float:
	var s := height / SIZE.y
	return maxf(SIZE.x * s, content_w + (SIZE.x - CONTENT.size.x) * s + pad * 2.0)
