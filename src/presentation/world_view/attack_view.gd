class_name AttackView
extends RefCounted
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md §4; PRESENTATION_CONTRACTS §4): the weapon attacks' looks composed
## from their final specs (WorldReader.attack_spec), never from which cards are held. Presentation only (EI-07).
##
## The layers, as far as MX1 draws them (the look is the v0.5 look; the 8-form / 5-element art is MX stage 3):
## - form: an ARC is the laser blade (KitView), a BOLT the dart (ActorViews); the others draw nothing yet;
## - size: the blade's arc and reach are the spec's (WorldReader.swing_shape reads them); a bolt's dart is longer
##   when the spec fires faster (rate bonus) and shorter when the shot splits (count > 1);
## - elements → core colour: a step's storm, bleed and frost pull the blade toward their colour, ember makes it
##   orange outright; a bolt's ember and bleed tint it (the other bolt elements draw from MX stage 3);
## - behaviour: a bouncing bolt is white-hot and brighter; a step that repeats (Twin Arc) keeps a longer trail; an
##   Nth-step charge (Overcharge) thickens the blade and flares it on the charged swing;
## - heat → edge colour: HeatLooks.attack_color over the core (Step LK), via edge_color.

const PLAIN_BOLT_SIZE := Vector3(0.38, 0.07, 0.07)
const FAST_BOLT_SIZE := Vector3(0.62, 0.06, 0.06)
const SPLIT_BOLT_SCALE := Vector3(0.75, 1, 1)
const BOLT_ENERGY := 2.5
const BOUNCE_ENERGY := 4.5
const TRAIL := 6
const REPEAT_TRAIL := 11
const NTH_WIDTH := 1.15
const CHARGED_WIDTH := 1.7

## Element → the colour it pulls an arc's core toward, and how far (the v0.5 item colours, ItemLooks).
const ARC_TINTS := [
	[&"storm", WorldReader.ITEM_CONDUCTOR, 0.7],
	[&"bleed", WorldReader.ITEM_SERRATED_EDGE, 0.7],
	[&"frost", WorldReader.ITEM_GLACIAL_EDGE, 0.7],
]
## The element whose colour an arc's core takes outright.
const ARC_CORE := [&"ember", WorldReader.ITEM_EMBER_EDGE]
const BOLT_TINTS := [
	[&"ember", WorldReader.ITEM_CINDER_SHOT, 0.55],
	[&"bleed", WorldReader.ITEM_BARBED_BOLTS, 0.55],
]


## The blade's look from combo step `spec` (WorldReader.attack_spec): {color, width, trail}. `charged`: the current
## swing is its Nth-step charge.
static func blade_look(spec: Dictionary, charged: bool) -> Dictionary:
	var c := ThemePalette.color(&"player_core")
	var elements: Array = Array(spec.get("elements", PackedStringArray()))
	for t: Array in ARC_TINTS:
		if elements.has(String(t[0])):
			c = c.lerp(ItemLooks.color(t[1]), t[2])
	if elements.has(String(ARC_CORE[0])):
		c = ItemLooks.color(ARC_CORE[1])
	var trail := REPEAT_TRAIL if int(spec.get("repeat_delay_ticks", 0)) > 0 else TRAIL
	var width := 1.0
	if int(spec.get("nth_every", 0)) > 0:
		width = NTH_WIDTH
		if charged:
			width = CHARGED_WIDTH
			c = c.lerp(ItemLooks.color(WorldReader.ITEM_OVERCHARGE), 0.6)
	return {"color": c, "width": width, "trail": trail}


## The bolt's look from the bolt spec: {size, color, energy} (ActorViews applies it to new player bolts).
static func bolt_look(spec: Dictionary) -> Dictionary:
	var look := {
		"size": PLAIN_BOLT_SIZE, "color": ThemePalette.color(&"player_core"), "energy": BOLT_ENERGY
	}
	if int(spec.get("rate_bonus_permille", 0)) > 0:
		look["size"] = FAST_BOLT_SIZE
	if int(spec.get("count", 1)) > 1:
		look["size"] = look["size"] * SPLIT_BOLT_SCALE
		look["color"] = look["color"].lerp(ItemLooks.color(WorldReader.ITEM_SPLINTER_SHOT), 0.5)
	if int(spec.get("bounces", 0)) > 0:
		look["color"] = look["color"].lerp(Color.WHITE, 0.6)
		look["energy"] = BOUNCE_ENERGY
	var elements: Array = Array(spec.get("elements", PackedStringArray()))
	for t: Array in BOLT_TINTS:
		if elements.has(String(t[0])):
			look["color"] = look["color"].lerp(ItemLooks.color(t[1]), t[2])
	return look


## The attack's edge at heat tier `tier`: the core below Hot, the heat meter's tier colour from Hot (Step LK, A2).
static func edge_color(core: Color, tier: int) -> Color:
	return HeatLooks.attack_color(core, tier)


## What draws a spec's form in MX1: &"blade" (KitView), &"bolt" (ActorViews), or &"" (no art yet).
static func drawer(spec: Dictionary) -> StringName:
	match int(spec.get("form", -1)):
		WorldReader.FORM_ARC:
			return &"blade"
		WorldReader.FORM_BOLT:
			return &"bolt"
	return &""


## The current blade look and the bolt look of `reader`'s build.
static func blade_look_of(reader: WorldReader) -> Dictionary:
	return blade_look(reader.attack_spec(reader.step_attack_id()), reader.swing_overcharged())


static func bolt_look_of(reader: WorldReader) -> Dictionary:
	return bolt_look(reader.attack_spec(WorldReader.ATTACK_BOLT))
