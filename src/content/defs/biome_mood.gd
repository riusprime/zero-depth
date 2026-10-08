class_name BiomeMood
extends Resource
## A biome's lighting mood (v0.5.9 Step 1, owner L3: "the lighting and occlusion ambience"): a dim sun or moon,
## dark tinted ambient, contact shadow (SSAO), warm bounce light (SSIL), haze and a vignette. Presentation only:
## StageView reads it, the sim never does. Starting values, tuned on screenshots with the owner.

## The sun or moon: colour, energy, and its direction (pitch below the horizon, yaw), in degrees.
@export var sun_color := Color(1, 0.98, 0.95)
@export var sun_energy := 1.05
@export var sun_pitch_deg := -38.0
@export var sun_yaw_deg := 168.0
## Flat ambient light (what lights the shadowed sides).
@export var ambient_color := Color(1, 0.95, 0.86)
@export var ambient_energy := 0.55
## The void around the floor.
@export var void_color := Color(0.1, 0.09, 0.08)
## AgX tonemap exposure.
@export var exposure := 1.0
## Contact shadow under and between blocks (Environment SSAO).
@export var ssao_radius := 1.2
@export var ssao_intensity := 2.5
## How much of the contact shadow also darkens directly lit surfaces (0: shadowed areas only).
@export var ssao_light_affect := 0.5
## Contact shadow drawn from the geometry (ContactShadows): how far it reaches from a block (m) and how dark it
## is where it meets the block (0-1).
@export var contact_radius := 0.9
@export var contact_strength := 0.55
## Warm light bouncing off lit surfaces onto their neighbours (Environment SSIL).
@export var ssil_enabled := true
@export var ssil_intensity := 1.0
## Haze over the scene (exponential fog); 0 turns it off.
@export var fog_density := 0.004
@export var fog_color := Color(0.2, 0.16, 0.13)
@export var glow_intensity := 0.6
## The warm light that fire props and chests throw (Step 4 uses it for light props).
@export var warm_light_color := Color(1.0, 0.62, 0.3)
@export var warm_light_energy := 2.2
@export var warm_light_range := 6.0
## Screen-edge darkening, 0 (none) to 1.
@export var vignette := 0.35


## Problems as "field: why" strings (BiomeDefinition turns them into ValidationIssues).
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for f: Array in [
		["sun_energy", sun_energy, 0.0, 4.0],
		["ambient_energy", ambient_energy, 0.0, 4.0],
		["exposure", exposure, 0.1, 4.0],
		["ssao_radius", ssao_radius, 0.01, 16.0],
		["ssao_intensity", ssao_intensity, 0.0, 16.0],
		["ssao_light_affect", ssao_light_affect, 0.0, 1.0],
		["ssil_intensity", ssil_intensity, 0.0, 16.0],
		["contact_radius", contact_radius, 0.05, 4.0],
		["contact_strength", contact_strength, 0.0, 1.0],
		["fog_density", fog_density, 0.0, 0.2],
		["glow_intensity", glow_intensity, 0.0, 8.0],
		["warm_light_energy", warm_light_energy, 0.0, 16.0],
		["warm_light_range", warm_light_range, 0.5, 30.0],
		["vignette", vignette, 0.0, 1.0],
	]:
		if f[1] < f[2] or f[1] > f[3]:
			out.append("%s: %s is outside %s..%s" % f)
	if sun_pitch_deg >= 0.0 or sun_pitch_deg < -90.0:
		out.append("sun_pitch_deg: %s must point down (-90..0)" % sun_pitch_deg)
	return out
