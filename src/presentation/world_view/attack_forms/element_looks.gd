class_name ElementLooks
extends RefCounted
## v0.9.0 VX V1 (VFX_AUDIT.md, owner "Dark red (Recommended)"): the one element palette. Every form reads its element
## colours here: AttackFormLooks (the Orbs, the Blade, the impacts through ImpactFx), BeamLooks (the Laser, Bomb, Void,
## Lance, Scatter, Glaive, Seekers, Wave and Wisps) and the effects layer's accents. Per element:
## - hot: the white-hot centre of a beam, a slug or a flash (BeamLooks.core);
## - core: the element's own colour, the body of every form (an Orb's core, a beam's glow: BeamLooks.edge);
## - deep: the darker outer tone a layered effect falls off to (smoke tints, halos' outer band);
## - kind: the effects layer's look for its accents and impacts (VfxLayer: fire, storm, frost, venom, bleed, void);
## - look: BeamLooks' look id (its strip, scroll and impact shape).
## Bleed is dark red everywhere (V1 (a)); V46 (owner "Move the hero's side"): Frost leans a little greener and the Bleed
## centre darker, so no hero colour sits near a hostile shot's core (a test pins the distances). The hero's shots never
## have a dark edge: every edge the forms draw is `core`, never `deep` (V50).
## Presentation only (EI-07): pure constants and look-ups.

## The elements, in the order the Codex lists them (Q11), plus the retired void element (phase_dash).
const ELEMENTS: Array[StringName] = [&"ember", &"storm", &"frost", &"venom", &"bleed", &"void"]
const HOT := {
	&"ember": Color("#FFF4D6"),
	&"storm": Color("#F8FAFF"),
	&"frost": Color("#F0FFF8"),
	&"venom": Color("#D2FFB0"),
	&"bleed": Color("#E84256"),
	&"void": Color("#F2EEFF"),
}
const CORE := {
	&"ember": Color("#FFAA33"),
	&"storm": Color("#7FB2FF"),
	&"frost": Color("#9AF5DC"),
	&"venom": Color("#5FE03C"),
	&"bleed": Color("#A8102A"),
	&"void": Color("#8B55FF"),
}
const DEEP := {
	&"ember": Color("#FF6A1A"),
	&"storm": Color("#3E7BFF"),
	&"frost": Color("#4FC8C0"),
	&"venom": Color("#2FA81E"),
	&"bleed": Color("#5E0412"),
	&"void": Color("#5A2AD0"),
}
const KIND := {
	&"ember": &"fire",
	&"storm": &"storm",
	&"frost": &"frost",
	&"venom": &"venom",
	&"bleed": &"bleed",
	&"void": &"void",
}
const LOOK := {
	&"ember": &"fire",
	&"storm": &"lightning",
	&"frost": &"frost",
	&"venom": &"venom",
	&"bleed": &"bleed",
}
## No element: the Gun's own energy blue (the Laser's default beam, the forms without an element).
const DEFAULT_HOT := Color("#F4FCFF")
const DEFAULT_CORE := Color("#3E8BFF")
const DEFAULT_DEEP := Color("#2050C8")
## v0.9.0 MP2 (owner, 2026-10-24: "the black one should also modify the attack color to a purle violet kind of
## attack"): while The Fallen's dark epic robe is worn, the plain energy (no element) is a purple-violet, layered as the
## blue is: a hot pale-violet centre, the violet, a deep violet. Kept apart from the hostile looks (V46: the violet
## fireball's #E9B8FF core and #9A4AE0 trail; the Chaos shrine's #A15CFF; The Fallen's own #C23CFF edge): every
## RGB distance over 0.2 (tests/unit/presentation/test_epic_robes.gd). The elements keep their own colours.
const FALLEN_HOT := Color("#FFF0FF")
const FALLEN_CORE := Color("#B526C8")
const FALLEN_DEEP := Color("#5A1680")

## The robe style whose energy the hero's plain shots wear (&"fallen" or none; PlayerAvatar._set_epic sets it).
static var energy_style := &""


## v0.9.0 MP2: the hero's plain energy follows the worn robe (`style`: &"fallen" turns it violet; anything else blue).
static func set_energy(style: StringName) -> void:
	energy_style = style if style == &"fallen" else &""


static func energy_hot() -> Color:
	return FALLEN_HOT if energy_style == &"fallen" else DEFAULT_HOT


static func energy_core() -> Color:
	return FALLEN_CORE if energy_style == &"fallen" else DEFAULT_CORE


static func energy_deep() -> Color:
	return FALLEN_DEEP if energy_style == &"fallen" else DEFAULT_DEEP


## The plain bolt's colour (no element): the player's cyan core, or The Fallen's violet.
static func player_energy() -> Color:
	return FALLEN_CORE if energy_style == &"fallen" else ThemePalette.color(&"player_core")


static func has(e: StringName) -> bool:
	return CORE.has(e)


static func hot(e: StringName) -> Color:
	return HOT.get(e, energy_hot())


static func core(e: StringName) -> Color:
	return CORE.get(e, energy_core())


static func deep(e: StringName) -> Color:
	return DEEP.get(e, energy_deep())


## The effects layer's kind for element `e` (&"" for none).
static func kind(e: StringName) -> StringName:
	return KIND.get(e, &"")


## The first element of `elements` (AttackSpec order) that has a look (&"" for none).
static func first(elements: PackedStringArray) -> StringName:
	for e in elements:
		if CORE.has(StringName(e)):
			return StringName(e)
	return &""


## The second element with a look, after `first` (&"" for none).
static func second(elements: PackedStringArray) -> StringName:
	var seen := false
	for e in elements:
		var id := StringName(e)
		if not CORE.has(id):
			continue
		if seen:
			return id
		seen = true
	return &""


## V2 (ART_DIRECTION §4: two elements, the first one's core and the second one's rim): a beam form's [centre, edge] for
## `elements`. One element: its hot centre and its core; two: the first's core as the centre and the second's core as
## the edge (each element's own colour, so neither sits near a hostile core: V46); none: the Gun's
## energy blue.
static func pair(elements: PackedStringArray) -> Array[Color]:
	var a := first(elements)
	if a == &"":
		return [energy_hot(), energy_core()]
	var b := second(elements)
	if b == &"":
		return [hot(a), core(a)]
	return [core(a), core(b)]
