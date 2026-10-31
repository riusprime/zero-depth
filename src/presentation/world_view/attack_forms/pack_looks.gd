class_name PackLooks
extends RefCounted
## v0.10.0 VX2 (docs/roadmap/v0.9.5/VFX_PACK.md R1-R13): which pack effect (data/vfx/pack_fx_vx2.tres) draws a hero
## shot or form of an element, and the colours it is given. The one place the hero's views read it, so a bolt, a
## needle, a wisp, a lance ball and a laser of one element are coloured alike. Presentation only (EI-07): constants
## and look-ups.
## - Colours (the lead's rule): primary = the first element's core, secondary = the second element's hot centre (or the
##   first's), tertiary = the first element's deep tone; no element: the Gun's energy blue (ElementLooks.energy_*).
## - An id is `vx2_<kind>_<element>`; a plain shot and the storm's share a scene (the pack's blue one).

## The elements that have their own scene; anything else (none, void) takes the storm's blue.
const SHAPED: Array[StringName] = [&"ember", &"frost", &"venom", &"storm", &"bleed"]
const VOID_VIOLET := Color("#8B55FF")
const PALE_GOLD := Color("#FFF3C4")
## How big a bolt's pack effect is drawn per metre of the shot's drawn core radius: the scene's head is this wide
## (ice ball, fire ball and the projectile's stretched sphere differ), so the on-screen size matches the old pulse.
const BOLT_PER_RADIUS := {
	&"ember": 0.9,
	&"frost": 1.4,
	&"venom": 3.2,
	&"storm": 3.2,
	&"bleed": 3.2,
}


## The element whose scene draws a shot of `element` (the plain shot's: storm).
static func shaped(element: StringName) -> StringName:
	return element if SHAPED.has(element) else &"storm"


## The table id of kind `kind` (bolt, jav, small, big, flare, laser) for `element`.
static func id_of(kind: String, element: StringName) -> StringName:
	return StringName("vx2_%s_%s" % [kind, shaped(element)])


## The laser's id: its own for venom (the beam scene) and void (the Phase Dash's).
static func laser_id(element: StringName) -> StringName:
	if element == &"void":
		return &"vx2_laser_void"
	return id_of("laser", element)


## `primary`, `secondary` and `tertiary` for a shot whose elements are `elements` (AttackSpec order).
static func colors(elements: PackedStringArray) -> Dictionary:
	return colors_of(ElementLooks.first(elements), ElementLooks.second(elements))


## The same from the first and second element ids (&"" for none).
static func colors_of(first: StringName, second: StringName = &"") -> Dictionary:
	return {
		&"primary": ElementLooks.core(first),
		&"secondary": ElementLooks.hot(second if second != &"" else first),
		&"tertiary": ElementLooks.deep(first),
	}


## The void's violet, for the Void's body and the Rune Explosion.
static func violet_colors() -> Dictionary:
	return {
		&"primary": VOID_VIOLET,
		&"secondary": ElementLooks.HOT[&"void"],
		&"tertiary": ElementLooks.DEEP[&"void"],
	}


## The MagicArea element a form of `element` draws its circle in (storm and none: arcane, recoloured by the caller).
static func circle_element(element: StringName) -> String:
	match element:
		&"ember":
			return "fire"
		&"frost":
			return "frost"
		&"venom":
			return "poison"
		&"bleed":
			return "blood"
	return "arcane"


## A basis whose x runs along `dir` (a unit vector on the ground), y up, scaled by `s`: the pack projectiles point
## along their local +x, trail behind (-x).
static func facing(dir: Vector3, s: float) -> Basis:
	var x := dir.normalized() if dir.length_squared() > 1e-8 else Vector3.RIGHT
	return Basis(x * s, Vector3.UP * s, x.cross(Vector3.UP) * s)
