class_name BeamLooks
extends RefCounted
## v0.9.0 LZ (owner C §6.2: "Default: Original energy color … Fire: A layered beam incorporating the established fire
## palette … Venom: Green or toxic-colored energy … Electricity: Blue-white or electrical arcs … Other existing elements
## should receive equivalent treatment. The color change alone is not sufficient: ideally the impact effect and beam
## texture also reflect the element"; PLAN C49): the Laser's look per element. Each look has a core and an edge colour
## (built on AttackFormLooks' element cores and VfxLayer's palette), its own scrolling strip texture (the owner's PNG
## `beam_core_<look>` in assets/textures/vfx/ when installed, docs/art/requests/v0.9.0_ART_LIST.md §7; else made here
## in code: greyscale R = how white-hot, A = coverage, tileable along its length), a scroll speed, and an impact (its
## spikes, softness and flicker; LaserView's impact shader). Presentation only (EI-07); pure functions of the look id.
## - default: the Gun's energy blue, a clean core with travelling pulses;
## - fire: a layered beam, a white-yellow core in orange flame tongues that lick out to the edge;
## - lightning: blue-white, a jagged arc crackling inside a thin glow;
## - frost: pale cyan, a smooth core with bright frost motes;
## - venom: toxic green, a thick core with bubbles along its edges;
## - bleed: dark red, heavy, streaked darker.

const LOOKS: Array[StringName] = [&"default", &"fire", &"lightning", &"frost", &"venom", &"bleed"]
## Spec element -> look, first match wins when the beam carries two (fire over lightning over frost ...).
const OF_ELEMENT := [
	["ember", &"fire"],
	["storm", &"lightning"],
	["frost", &"frost"],
	["venom", &"venom"],
	["bleed", &"bleed"],
]
## Look -> VfxLayer kind for the beam's element accent (VfxLayer.line) and its impact (&"" = none).
const VFX_KIND := {
	&"default": &"",
	&"fire": &"fire",
	&"lightning": &"storm",
	&"frost": &"frost",
	&"venom": &"venom",
	&"bleed": &"bleed",
}
## [core, edge, scroll (tiles a second), width (m), impact spikes, impact softness, impact flicker (Hz)].
const STYLE := {
	&"default": [Color("#E8F6FF"), Color("#3E8BFF"), 2.2, 0.30, 4, 0.55, 9.0],
	&"fire": [Color("#FFE7A6"), Color("#FF6A1A"), 1.6, 0.42, 0, 0.9, 7.0],
	&"lightning": [Color("#F4F8FF"), Color("#7FB2FF"), 4.5, 0.30, 6, 0.35, 17.0],
	&"frost": [Color("#F6FEFF"), Color("#9FE9FF"), 1.1, 0.32, 4, 0.25, 4.0],
	&"venom": [Color("#DDFF9E"), Color("#46D22A"), 1.3, 0.38, 0, 0.8, 5.0],
	&"bleed": [Color("#FF7080"), Color("#8E0A1C"), 1.0, 0.40, 3, 0.7, 4.5],
}
## The code strip's size (pixels): tileable along X.
const TEX_W := 256
const TEX_H := 32
const TEX_PREFIX := "beam_core_"

static var _made := {}


## The look of a beam carrying `elements` (AttackSpec.elements order).
static func look_of(elements: PackedStringArray) -> StringName:
	for pair: Array in OF_ELEMENT:
		if elements.has(pair[0]):
			return pair[1]
	return &"default"


static func core(look: StringName) -> Color:
	return STYLE[look][0]


static func edge(look: StringName) -> Color:
	return STYLE[look][1]


static func scroll(look: StringName) -> float:
	return STYLE[look][2]


static func width(look: StringName) -> float:
	return STYLE[look][3]


## The impact's [spikes, softness, flicker].
static func impact(look: StringName) -> Array:
	return [STYLE[look][4], STYLE[look][5], STYLE[look][6]]


## The strip of `look`: the owner's beam_core_<look> PNG when installed, else the code-made one (cached).
static func texture(look: StringName) -> Texture2D:
	var own := FxTextures.get_tex(TEX_PREFIX + String(look))
	return own if own != null else code_texture(look)


## The code-made strip of `look` (cached; the manifest id's fallback).
static func code_texture(look: StringName) -> Texture2D:
	if not _made.has(look):
		_made[look] = ImageTexture.create_from_image(strip(look))
	return _made[look]


## The strip image (TEX_W × TEX_H, RGBA8): R how white-hot, A coverage. Periodic along X, so it tiles.
static func strip(look: StringName) -> Image:
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	for x in TEX_W:
		var u := float(x) / TEX_W
		for y in TEX_H:
			var v := (float(y) + 0.5) / TEX_H * 2.0 - 1.0  # -1 .. 1 across the beam
			var p := _pixel(look, u, v, x, y)
			img.set_pixel(x, y, Color(p.x, p.x, p.x, clampf(p.y, 0.0, 1.0)))
	return img


## One texel: (whiteness, coverage) at `u` along (0..1, one period) and `v` across (-1..1).
static func _pixel(look: StringName, u: float, v: float, x: int, y: int) -> Vector2:
	var core_g := exp(-v * v * 14.0)
	var glow := exp(-v * v * 2.6)
	match look:
		&"fire":
			var tongue := 0.0
			for k in 3:
				var c := 0.35 * sin(TAU * (u * (3 + k * 2)) + k * 1.7)
				tongue += exp(-pow((absf(v) - 0.45 - c * 0.3) * 4.0, 2.0)) * (0.55 - k * 0.12)
			return Vector2(core_g, glow * 0.7 + tongue + core_g)
		&"lightning":
			var line := _zigzag(u, 12, 7) * 0.75
			var arc := exp(-pow((v - line) * 9.0, 2.0))
			var arc2 := exp(-pow((v - _zigzag(u, 9, 31) * 0.6) * 12.0, 2.0)) * 0.5
			return Vector2(maxf(arc, core_g * 0.6), glow * 0.35 + arc + arc2)
		&"frost":
			var mote := 0.0
			if _hash(x / 6, y / 4) > 0.9 and absf(v) < 0.8:
				mote = 1.0
			return Vector2(maxf(core_g, mote), glow * 0.55 + core_g * 0.6 + mote)
		&"venom":
			var bub := 0.0
			var cell := int(u * 16.0)
			var cx := (cell + 0.5) / 16.0
			var cy := (0.55 + 0.25 * _hash(cell, 3)) * (1.0 if cell % 2 == 0 else -1.0)
			var d := Vector2((u - cx) * 16.0, (v - cy) * 4.0).length()
			if _hash(cell, 9) > 0.35:
				bub = clampf(1.0 - absf(d - 0.35) * 5.0, 0.0, 1.0)
			return Vector2(core_g * 0.8 + bub * 0.4, glow * 0.8 + core_g * 0.5 + bub)
		&"bleed":
			var streak := 0.5 + 0.5 * sin(TAU * (u * 5.0) + v * 3.0)
			return Vector2(
				core_g * (0.5 + 0.3 * streak), glow * (0.75 + 0.25 * streak) + core_g * 0.4
			)
	var pulse := 0.75 + 0.25 * sin(TAU * u * 4.0)
	return Vector2(core_g * pulse, (glow * 0.6 + core_g) * pulse)


## A periodic jagged line in -1..1: `n` nodes along one period, seeded by `sd`.
static func _zigzag(u: float, n: int, sd: int) -> float:
	var f := u * n
	var k := int(floorf(f)) % n
	var t: float = f - floorf(f)
	var a := _hash(k, sd) * 2.0 - 1.0
	var b := _hash((k + 1) % n, sd) * 2.0 - 1.0
	return lerpf(a, b, t)


## A fixed hash in 0..1 (the texture is the same every run).
static func _hash(a: int, b: int) -> float:
	var n := (a * 73856093) ^ (b * 19349663)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0
