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
## v0.8.0 GX (owner O86, graphics feedback §4): the haze's height falloff, "high" lighting only. Below `fog_height`
## (m) the haze thickens by `fog_height_density` per metre (0: off), so whatever lies under the floor's level sinks
## into it; Godot has one fog colour, so it hazes toward `fog_color`.
@export var fog_height := 0.0
@export var fog_height_density := 0.0
## v0.8.0 GX (O86, feedback §1): volumetric fog on the "high" tier, so the fire props' light hangs in the air. A low
## layer (from just under the floor up to `volumetric_height` m) that follows the view, `volumetric_density` thick,
## tinted `volumetric_albedo`; the fire props light it at `volumetric_light_energy`, the sun or moon at
## `volumetric_sun_energy` (low: torches, not the sun, carry it, and the void stays dark). Starting values.
@export var volumetric_enabled := false
@export var volumetric_density := 0.03
@export var volumetric_albedo := Color(1.0, 0.86, 0.7)
@export var volumetric_height := 3.5
@export var volumetric_light_energy := 1.0
@export var volumetric_sun_energy := 0.0
@export var glow_intensity := 0.6
## The warm light that fire props and chests throw (Step 4 uses it for light props).
@export var warm_light_color := Color(1.0, 0.62, 0.3)
@export var warm_light_energy := 2.2
@export var warm_light_range := 6.0
## The small warm light the hero carries (owner Q3, 2026-10-08: "yes to the hero light"), so the hero's
## surroundings stay readable in dark rooms; energy 0 turns it off.
@export var hero_light_energy := 1.2
@export var hero_light_range := 4.5
## Screen-edge darkening, 0 (none) to 1.
@export var vignette := 0.35
## v0.6.1 lighting pass (owner, 2026-10-12: "we need to work a bit more into the lighting of the game"; deep dark
## shadows, warm light pooling round fires and the chest). Glow: what brightness starts to bloom (lower: more
## blooms) and how much of the whole image bleeds into it.
@export var glow_threshold := 1.0
@export var glow_bloom := 0.0
## How wide the glow spreads (0: Godot's narrow default levels; 1: wide halos round bright sources).
@export var glow_spread := 0.0
## The grade: shadows pulled toward `grade_shadows`, highlights toward `grade_highlights` (a teal-orange split tone),
## by `grade_strength` (0: none). Contrast and saturation over the whole image (1: unchanged).
@export var grade_shadows := Color(0.5, 0.5, 0.5)
@export var grade_highlights := Color(0.5, 0.5, 0.5)
@export var grade_strength := 0.0
@export var contrast := 1.0
@export var saturation := 1.0
## v0.8.0 N10 (owner O68, "the texture seems a bit too grained … make it bigger"): how much wall one tile of the
## procedural walls' textures covers (m): the face texture (3:2) this long along the wall (its height follows the
## aspect), the top texture this wide. Read when a floor is built (the dev panel's Restart floor shows an edit).
@export var wall_texture_m := 4.0
@export var wall_top_texture_m := 4.5
## v0.8.0 N15 (owner O73, "Night biome textures look busy … how could we make it less busy keeping this model?"):
## calmer walls, the same model (ProceduralWall rule 6; the defaults are N13's look). In the walls' shader: how much
## of the textures' finest detail stays (1: all; toward 0 it blends into a sample 2.5 mips coarser), and each
## texture's contrast round its own mean colour (1: as installed; the face's lower where the modelled blocks already
## draw the pattern, so the two don't overlap).
@export var wall_detail := 1.0
@export var wall_face_contrast := 1.0
@export var wall_top_contrast := 1.0
## In the builder: the top's laid stones this many times bigger; the share of missing, recessed and chipped blocks,
## gone top stones and missing quoins times this; the blocks' corner jitter and the stones' height jitter times this;
## the thick walls' rubble-fill lumps this big (m) and their height noise times this; the stones' and blocks'
## brightness noise times this; the fill's brightness against the rim's (0.97).
@export var wall_stone_scale := 1.0
@export var wall_breakage := 1.0
@export var wall_jitter := 1.0
@export var wall_fill_lump_m := 1.2
@export var wall_fill_noise := 1.0
@export var wall_tint_noise := 1.0
@export var wall_fill_shade := 0.66


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
		["fog_height", fog_height, -20.0, 10.0],
		["fog_height_density", fog_height_density, 0.0, 4.0],
		["volumetric_density", volumetric_density, 0.0, 0.2],
		["volumetric_height", volumetric_height, 0.5, 12.0],
		["volumetric_light_energy", volumetric_light_energy, 0.0, 16.0],
		["volumetric_sun_energy", volumetric_sun_energy, 0.0, 4.0],
		["glow_intensity", glow_intensity, 0.0, 8.0],
		["warm_light_energy", warm_light_energy, 0.0, 16.0],
		["warm_light_range", warm_light_range, 0.5, 30.0],
		["vignette", vignette, 0.0, 1.0],
		["hero_light_energy", hero_light_energy, 0.0, 8.0],
		["hero_light_range", hero_light_range, 0.5, 15.0],
		["glow_threshold", glow_threshold, 0.0, 4.0],
		["glow_bloom", glow_bloom, 0.0, 1.0],
		["glow_spread", glow_spread, 0.0, 1.0],
		["grade_strength", grade_strength, 0.0, 1.0],
		["contrast", contrast, 0.5, 2.0],
		["saturation", saturation, 0.0, 2.0],
		["wall_texture_m", wall_texture_m, 0.5, 16.0],
		["wall_top_texture_m", wall_top_texture_m, 0.5, 16.0],
		["wall_detail", wall_detail, 0.0, 1.0],
		["wall_face_contrast", wall_face_contrast, 0.0, 1.5],
		["wall_top_contrast", wall_top_contrast, 0.0, 1.5],
		["wall_stone_scale", wall_stone_scale, 0.5, 2.5],
		["wall_breakage", wall_breakage, 0.0, 2.0],
		["wall_jitter", wall_jitter, 0.0, 2.0],
		["wall_fill_lump_m", wall_fill_lump_m, 0.6, 3.0],
		["wall_fill_noise", wall_fill_noise, 0.0, 2.0],
		["wall_tint_noise", wall_tint_noise, 0.0, 2.0],
		["wall_fill_shade", wall_fill_shade, 0.3, 1.0],
	]:
		if f[1] < f[2] or f[1] > f[3]:
			out.append("%s: %s is outside %s..%s" % f)
	if sun_pitch_deg >= 0.0 or sun_pitch_deg < -90.0:
		out.append("sun_pitch_deg: %s must point down (-90..0)" % sun_pitch_deg)
	return out


## The grade as a per-channel 1D colour-correction curve (Environment.adjustment_color_correction): each channel
## bends toward the shadow colour's in the darks and the highlight colour's in the lights, weighted by strength.
## Null when there is no grade.
func grade_texture() -> GradientTexture1D:
	if grade_strength <= 0.0:
		return null
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	var n := 17
	for k in n:
		var x := k / float(n - 1)
		var ws := (1.0 - x) * (1.0 - x) * x * 4.0  # peaks in the darks, 0 at black and white
		var wh := x * x * (1.0 - x) * 4.0  # peaks in the lights
		offsets.append(x)
		colors.append(
			Color(
				_bend(x, grade_shadows.r, grade_highlights.r, ws, wh),
				_bend(x, grade_shadows.g, grade_highlights.g, ws, wh),
				_bend(x, grade_shadows.b, grade_highlights.b, ws, wh)
			)
		)
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t


func _bend(x: float, s: float, h: float, ws: float, wh: float) -> float:
	return clampf(x + grade_strength * 0.35 * (ws * (s - 0.5) + wh * (h - 0.5)), 0.0, 1.0)
