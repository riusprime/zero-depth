class_name WallCalm
extends RefCounted
## v0.8.0 N15 (owner O73, "Night biome textures look busy - this is true, how could we make it less bussy keeping this
## model?"; "some biomes look too busy"): ProceduralWall's rule 6, calmer walls without changing the model. Each
## biome's values are data (BiomeMood's wall_* fields, validated, on the dev panel's lighting page); the defaults
## are N13's look. In the shader: the textures' finest detail blended toward a blurred sample ("detail") and their
## contrast squashed toward their own mean colour ("face_contrast", lower on the faces so the painted blocks don't
## double the modelled ones; "top_contrast"). In the builder: bigger top stones ("stone"), fewer missing, recessed
## and chipped blocks, gone top stones and missing quoins ("breaks"), less corner and height jitter ("jitter"),
## bigger, flatter fill lumps ("fill_lump", "fill_noise"), less vertex-colour noise ("tint") and a smaller
## rim-vs-fill value step ("fill_shade"). Only thresholds and ranges scale: the cosmetic stream's draws are the same
## whatever the values (EI-05). Presentation only.

## The builder's values at N13's look (calm_of's keys).
const BUILDER := {
	"stone": 1.0,
	"breaks": 1.0,
	"jitter": 1.0,
	"fill_lump": 1.2,  # ProceduralWall.FILL_LUMP
	"fill_noise": 1.0,
	"tint": 1.0,
	"fill_shade": 0.66,
}
## The shader's blurred sample: this many mip levels coarser than the sharp one.
const SOFT_BIAS := 2.5
## The walls' shader (ProceduralWall.material): the face or top texture by the vertex colour's alpha, times its
## colour (grime, tint); flat, rough stone; v0.8.0 N15: each texture's fine detail blended toward a sample SOFT_BIAS
## mips coarser (detail: 1 none of it, 0 all) and its contrast squashed toward its mean colour (its last mip; 1: as
## installed).
const SHADER := """shader_type spatial;
render_mode cull_back, diffuse_burley;
uniform sampler2D face_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail = 1.0;
uniform float face_contrast = 1.0;
uniform float top_contrast = 1.0;
vec3 calm(sampler2D s, vec2 uv, float contrast) {
	vec3 sharp = texture(s, uv).rgb;
	vec3 soft = texture(s, uv, //BIAS).rgb;
	vec3 mean = textureLod(s, uv, 12.0).rgb;
	return mean + (mix(soft, sharp, detail) - mean) * contrast;
}
void fragment() {
	vec3 top = calm(top_tex, UV, top_contrast);
	vec3 face = calm(face_tex, UV, face_contrast);
	vec3 t = COLOR.a > 0.5 ? top : face;
	ALBEDO = t * COLOR.rgb;
	ROUGHNESS = 1.0;
	//FADE
}
"""


## A biome's builder values (BUILDER's keys) from its mood (null: the defaults).
static func calm_of(mood: BiomeMood) -> Dictionary:
	if mood == null:
		return BUILDER.duplicate()
	return {
		"stone": mood.wall_stone_scale,
		"breaks": mood.wall_breakage,
		"jitter": mood.wall_jitter,
		"fill_lump": mood.wall_fill_lump_m,
		"fill_noise": mood.wall_fill_noise,
		"tint": mood.wall_tint_noise,
		"fill_shade": mood.wall_fill_shade,
	}


## A biome's shader values from its mood ({"detail", "face_contrast", "top_contrast"}).
static func look_of(mood: BiomeMood) -> Dictionary:
	if mood == null:
		return {"detail": 1.0, "face_contrast": 1.0, "top_contrast": 1.0}
	return {
		"detail": mood.wall_detail,
		"face_contrast": mood.wall_face_contrast,
		"top_contrast": mood.wall_top_contrast,
	}
