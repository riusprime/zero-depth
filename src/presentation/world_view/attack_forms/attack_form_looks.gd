class_name AttackFormLooks
extends RefCounted
## v0.6.0 MX3 (docs/design/MODIFIER_ENGINE.md §4, owner pick "Element core, heat edge"): the look of any attack,
## composed from its final spec (WorldReader.attack_spec) by layer, never from which cards are held. Pure: a spec in,
## a look dictionary out (AttackFormView draws it). Presentation only (EI-07).
##
## The layers:
## - form → which pool draws it (8 forms, AttackSpec.Form numbers via WorldReader.FORM_*);
## - size, reach, count, spread, directions → the meshes' scale and how many there are, laid out on the pattern
##   (a halo of 12 shots is 12 darts evenly round the hero);
## - elements → the core colour and the particles (storm white-blue crackle, ember orange sparks, frost pale shards,
##   venom green drip, void violet smear, bleed MX1's tint); two elements: the first one's core, the second's rim;
## - heat → the edge (the trail and the rim's outer band): HeatLooks.attack_color over the rim, values untouched;
## - behaviour → motion cues: pierce a streak, bounce a flash at the bounce, home a curved trail, return a tether;
## - damage weight → thicker and brighter; crit → a white-hot flash.
##
## Readability (PRESENTATION_CONTRACTS §3–4): a flat mark on the floor (a zone's patch, a lob's landing circle, a
## burst's or a ring's fill) never takes a hostile hue (the telegraphs' red-orange and the reds and magentas round it):
## ground_safe() leans such a colour toward the player's cool core until it leaves that band. The light that rises
## off the floor (trails, rims, darts, the ring's raised front) may carry the heat edge, as the vent ring does.

## Form numbers (AttackSpec.Form; a test pins them to WorldReader.FORM_*).
const ARC := 0
const BOLT := 1
const RING := 2
const BEAM := 3
const ZONE := 4
const ORBITER := 5
const LOB := 6
const BURST := 7
const FORM_COUNT := 8
const FORM_NAMES: Array[StringName] = [
	&"arc", &"bolt", &"ring", &"beam", &"zone", &"orbiter", &"lob", &"burst"
]

## `directions` in a spec (MX stage 2+ may carry it as one of these ints or names; absent = forward).
const DIR_FORWARD := 0
const DIR_BACK := 1
const DIR_CIRCLE := 2

## The element cores (art: per element, not per card). Bleed keeps MX1's tint (bleed_core()).
const ELEMENT_CORE := {
	&"storm": Color("#7FB2FF"),
	&"ember": Color("#FFAA33"),
	&"frost": Color("#B5F2FF"),
	&"venom": Color("#5FE03C"),
	&"void": Color("#8B55FF"),
}
## Each element's particles: the kind (AttackFormView.PARTICLE_KINDS) and colour.
const ELEMENT_PARTICLE := {
	&"storm": [&"crackle", Color("#CFE4FF")],
	&"ember": [&"sparks", Color("#FF9440")],
	&"frost": [&"shards", Color("#F2FDFF")],
	&"venom": [&"drip", Color("#4FD23A")],
	&"void": [&"smear", Color("#B57BFF")],
	&"bleed": [&"drip", Color("#E0405E")],
}
## How far MX1 pulls the blade's core toward the bleed item's colour (AttackView.ARC_TINTS).
const BLEED_TINT := 0.7

## Base glow (the colour multiplier the additive layers draw at; > 1 feeds the environment's glow) per form.
const ENERGY: Array[float] = [0.9, 1.2, 0.6, 1.1, 0.5, 1.0, 0.7, 0.6]
## Display life in ticks per form when the spec doesn't say (a bolt, a zone and an orbiter use life_ticks).
const LIFE: Array[int] = [10, 40, 20, 9, 150, 240, 36, 12]
## Defaults for a spec without the size field (metres).
const DEFAULT_REACH := 1.6
const DEFAULT_RADIUS := 1.5
const DEFAULT_SPEED := 0.3
const DEFAULT_HALF_ARC := 640
## Damage weight → width and brightness: 1 + WEIGHT_GAIN × (weight − 1), clamped.
const WEIGHT_GAIN := 0.5
const WEIGHT_MIN := 0.8
const WEIGHT_MAX := 2.0
## A crit's flash colour: the heat meter's white-hot.
const CRIT_FLASH := HeatLooks.WHITE_HOT
## Hostile hue band (degrees, wrapping through 0): the telegraphs' red-orange #FF6A3D (14°), the molten core #FF8A2E
## (26°) and the reds and magentas round them. A ground mark with saturation over HOSTILE_SAT never lands in it.
const HOSTILE_HUE_FROM := 300.0
const HOSTILE_HUE_TO := 34.0
const HOSTILE_SAT := 0.35


## The look of `spec` at heat tier `tier`. `opts`: crit (bool), weight (float, the damage multiplier; default the
## spec's damage_mul_permille / 1000, else 1). Keys: form, core, rim, edge, ground, ground_edge, particles
## ([[kind, colour, share]]), cues, energy, width, crit, flash, angles (yaw offsets in radians), and the form's sizes
## (half_angle, reach, length, radius, speed, life).
static func compose(
	spec: Dictionary, tier: int = HeatLooks.TIER_COOL, opts: Dictionary = {}
) -> Dictionary:
	var form := clampi(int(spec.get("form", BOLT)), 0, FORM_COUNT - 1)
	var els: Array = Array(spec.get("elements", PackedStringArray()))
	var core := core_of(els)
	var rim := rim_of(els)
	var w := weight_scale(float(opts.get("weight", weight_of(spec))))
	var crit := bool(opts.get("crit", false))
	var look := {
		"form": form,
		"name": FORM_NAMES[form],
		"core": core,
		"rim": rim,
		"edge": HeatLooks.attack_color(rim, tier),
		"ground": ground_safe(core),
		"ground_edge": ground_safe(rim),
		"particles": particles_of(els),
		"elements": els,
		"cues": cues_of(spec),
		"energy": ENERGY[form] * w,
		"width": w,
		"crit": crit,
		"flash": CRIT_FLASH if crit else Color(0, 0, 0, 0),
		"angles": angles_of(spec),
		"count": maxi(1, int(spec.get("count", 1))),
	}
	_sizes(look, spec, form)
	return look


## The core colour: the first element's, or the player's own (no element: the plain v0.5 cyan).
static func core_of(elements: Array) -> Color:
	if elements.is_empty():
		return ThemePalette.color(&"player_core")
	return element_color(StringName(elements[0]))


## The rim: the second element's core when there are two or more, else the core lifted toward white.
static func rim_of(elements: Array) -> Color:
	if elements.size() >= 2:
		return element_color(StringName(elements[1]))
	return core_of(elements).lerp(Color.WHITE, 0.2)


static func element_color(element: StringName) -> Color:
	if element == &"bleed":
		return bleed_core()
	return ELEMENT_CORE.get(element, ThemePalette.color(&"player_core"))


## MX1's bleed tint (the blade's core pulled 70 % toward Serrated Edge's colour), kept as the bleed element's core.
static func bleed_core() -> Color:
	return ThemePalette.color(&"player_core").lerp(
		ItemLooks.color(WorldReader.ITEM_SERRATED_EDGE), BLEED_TINT
	)


## [[kind, colour, share]]: the core element's particles, and with two elements half of each.
static func particles_of(elements: Array) -> Array:
	var out := []
	var seen := {}
	for e: Variant in elements:
		var id := StringName(e)
		if seen.has(id) or not ELEMENT_PARTICLE.has(id):
			continue
		seen[id] = true
		var p: Array = ELEMENT_PARTICLE[id]
		out.append([p[0], p[1], 1.0])
		if out.size() == 2:
			break
	if out.size() == 2:
		out[0][2] = 0.5
		out[1][2] = 0.5
	return out


## Behaviour → motion cues: &"streak" (pierce), &"bounce_flash" (bounces), &"curve" (home), &"tether" (return).
static func cues_of(spec: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if int(spec.get("pierce", 0)) > 0:
		out.append(&"streak")
	if int(spec.get("bounces", 0)) > 0:
		out.append(&"bounce_flash")
	if bool(spec.get("home", false)):
		out.append(&"curve")
	if bool(spec.get("return", false)):
		out.append(&"tether")
	return out


## The damage multiplier the spec carries (damage_mul_permille, 1000 = none; a stat card's mul(damage)).
static func weight_of(spec: Dictionary) -> float:
	return float(spec.get("damage_mul_permille", 1000)) / 1000.0


## A damage multiplier as a width / brightness scale.
static func weight_scale(weight: float) -> float:
	return clampf(1.0 + WEIGHT_GAIN * (weight - 1.0), WEIGHT_MIN, WEIGHT_MAX)


## The spec's directions as DIR_* (an int, or a name: "forward", "back", "circle").
static func directions_of(spec: Dictionary) -> int:
	var d: Variant = spec.get("directions", DIR_FORWARD)
	if d is String or d is StringName:
		match String(d):
			"back":
				return DIR_BACK
			"circle":
				return DIR_CIRCLE
		return DIR_FORWARD
	return clampi(int(d), DIR_FORWARD, DIR_CIRCLE)


## Yaw offsets (radians) of each copy from the aim: `count` copies over `spread` (1/4096 turns) centred on the aim;
## circle spreads them evenly all round; back adds each one's mirror behind.
static func angles_of(spec: Dictionary) -> PackedFloat32Array:
	var n := maxi(1, int(spec.get("count", 1)))
	var out := PackedFloat32Array()
	var dirs := directions_of(spec)
	if dirs == DIR_CIRCLE:
		for k in n:
			out.append(TAU * k / n)
		return out
	var spread := TAU * float(int(spec.get("spread", 0))) / 4096.0
	for k in n:
		out.append(0.0 if n == 1 else -spread * 0.5 + spread * k / (n - 1))
	if dirs == DIR_BACK:
		for k in n:
			out.append(wrapf(out[k] + PI, -PI, PI))
	return out


## Lean `c` toward the player's core until its hue leaves the hostile band (a ground mark); unchanged otherwise.
static func ground_safe(c: Color) -> Color:
	var out := c
	var cool := ThemePalette.color(&"player_core")
	for k in 10:
		if not is_hostile_hue(out):
			return out
		out = c.lerp(cool, 0.12 * (k + 1))
	return cool


## True if `c` is a saturated colour in the telegraphs' hostile hue band.
static func is_hostile_hue(c: Color) -> bool:
	if c.s < HOSTILE_SAT:
		return false
	var h := c.h * 360.0
	return h >= HOSTILE_HUE_FROM or h <= HOSTILE_HUE_TO


static func _sizes(look: Dictionary, spec: Dictionary, form: int) -> void:
	var reach := float(spec.get("reach_m", 0.0))
	var radius := float(spec.get("radius_m", 0.0))
	var speed := float(spec.get("speed", 0.0))
	var life := int(spec.get("life_ticks", 0))
	var bonus := int(spec.get("reach_bonus_permille", 0))
	reach = (reach if reach > 0.0 else DEFAULT_REACH) * (1000 + bonus) / 1000.0
	look["reach"] = reach
	look["radius"] = radius if radius > 0.0 else DEFAULT_RADIUS
	look["speed"] = speed if speed > 0.0 else DEFAULT_SPEED
	var half := int(spec.get("half_arc", 0))
	look["half_angle"] = TAU * float(half if half > 0 else DEFAULT_HALF_ARC) / 4096.0
	var w: float = look["width"]
	match form:
		BOLT:
			# A dart grows with its speed (a faster shot reads as a longer streak), thicker with its radius.
			look["length"] = clampf(0.3 + float(look["speed"]) * 1.1, 0.3, 1.3)
			look["thick"] = clampf(maxf(radius, 0.06) * 0.9, 0.05, 0.4) * w
		BEAM:
			look["length"] = reach if float(spec.get("reach_m", 0.0)) > 0.0 else 4.0
			look["thick"] = maxf(radius, 0.08) * w
		ARC:
			look["thick"] = 0.16 * w
		ORBITER:
			look["thick"] = maxf(radius, 0.18) * w
		_:
			look["thick"] = 0.14 * w
	if form in [BOLT, ZONE, ORBITER] and life > 0:
		look["life"] = life
	else:
		look["life"] = LIFE[form]
