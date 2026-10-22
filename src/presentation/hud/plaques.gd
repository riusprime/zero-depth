class_name Plaques
extends RefCounted
## The wide plaques (v0.6.1 R1, first the owner's crystal plaques; v0.8.0 MU, owner O14 "we're just throwing away the
## shard cards": carved Ember stone slabs, PlaqueBox). A plaque fits any width; text sits inside its margins, clear of
## the glowing groove along its foot. **Colour comes from the card colours' table** (CardFrames.FRAME: family → colour
## id). USE_FAMILY says which family a plaque that is not a card wears (the shop's services, Leave, the banner); a
## card's plaque uses CardFrames.family like its card. Presentation only (EI-07): nothing here changes an outcome.

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
## An unfocused plaque is drawn a little dimmer (the face's brightness).
const IDLE := 0.84


## The plaque (a colour id) a family wears: the card colours' table.
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


## The plaque's tint (its inlay and title colour): the card colour of the same id.
static func tint(plaque: StringName) -> Color:
	return CardFrames.tint(plaque)


## A plaque style box `height` px tall; `pad` adds px inside its margins on the left and right.
static func box(plaque: StringName, height: float, pad: float = 0.0) -> PlaqueBox:
	return PlaqueBox.new(plaque, height, pad)


## The text box's size (px) of a plaque `height` px tall and `width` px wide.
static func content_size(height: float, width: float, pad: float = 0.0) -> Vector2:
	var m := PlaqueBox.margins(height, pad)
	return Vector2(width - m.x - m.z, height - m.y - m.w)
