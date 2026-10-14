class_name BossStrikeLooks
extends RefCounted
## v0.8.0 AV part 2 (owner O7: "so the attacks look real … not … a red thingy"): the look of every boss ground attack
## other than the Gatekeeper's shock lanes (StoneSpikeViews). Per boss kind and move (WorldReader.MOVE_*): the marker's
## ground pattern (TelegraphViews draws the locked flash and a windup's fill with it instead of a flat red fill; the
## dull outline while it tracks and the bright edge once it locks stay, so the lock flash is still the dodge cue) and
## the strike's 3D effect (BossStrikeViews). Colours stay off the hero's (ThemePalette player_core, a cyan).
## Presentation only: a look changes nothing the sim decides.

## Marker patterns (the MARK_SHADER's `pattern`).
## v0.8.0 FB3: VOID, the Nemesis's (dark rifts, a violet-red glow).
enum Pattern { STONE, BLADE, ACID, LIGHT, HAZARD, MOLTEN, VOID }

## Strike kinds BossStrikeViews draws, by the geometry they take: discs (a marker's circles, a leap's landing, a
## burrow's eruption, a spawn's circles), a ring, an arc, lanes, and a charge's lane.
const DISC_STRIKES: Array[StringName] = [
	&"crater", &"acid_splat", &"crack_impact", &"eruption", &"shell", &"javelins", &"light_burst"
]
const RING_STRIKES: Array[StringName] = [&"light_ring", &"shock_ring", &"steam_ring"]
const ARC_STRIKES: Array[StringName] = [&"dust_arc", &"steel_arc"]
const LANE_STRIKES: Array[StringName] = [&"spears", &"beam", &"rail", &"molten", &"fire_lanes"]
const CHARGE_STRIKES: Array[StringName] = [&"skid"]

## Per pattern: [dark ground tint, glow]. The glow is the strike's light and the locked marker's hot colour.
const PATTERN_COLORS := {
	Pattern.STONE: [Color(0.08, 0.05, 0.04), Color(1.0, 0.42, 0.18)],
	Pattern.BLADE: [Color(0.1, 0.07, 0.05), Color(1.0, 0.66, 0.3)],
	Pattern.ACID: [Color(0.04, 0.09, 0.03), Color(0.62, 1.0, 0.22)],
	Pattern.LIGHT: [Color(0.12, 0.07, 0.16), Color(1.0, 0.86, 0.5)],
	Pattern.HAZARD: [Color(0.09, 0.07, 0.03), Color(1.0, 0.7, 0.12)],
	Pattern.MOLTEN: [Color(0.1, 0.035, 0.02), Color(1.0, 0.55, 0.1)],
	Pattern.VOID: [Color(0.05, 0.02, 0.08), Color(0.8, 0.25, 1.0)],
}

## Look id -> {"pattern", "strike"}.
const LOOKS := {
	&"gk_slam": {"pattern": Pattern.STONE, "strike": &"crater"},
	&"gk_sweep": {"pattern": Pattern.STONE, "strike": &"dust_arc"},
	&"wl_spears": {"pattern": Pattern.BLADE, "strike": &"spears"},
	&"wl_lunge": {"pattern": Pattern.BLADE, "strike": &"skid"},
	&"wl_bash": {"pattern": Pattern.BLADE, "strike": &"steel_arc"},
	&"wl_javelins": {"pattern": Pattern.BLADE, "strike": &"javelins"},
	&"bm_eggs": {"pattern": Pattern.ACID, "strike": &"acid_splat"},
	&"bm_leap": {"pattern": Pattern.ACID, "strike": &"crack_impact"},
	&"bm_burrow": {"pattern": Pattern.ACID, "strike": &"eruption"},
	&"bm_brood": {"pattern": Pattern.ACID, "strike": &"acid_splat"},
	&"hl_beam": {"pattern": Pattern.LIGHT, "strike": &"beam"},
	&"hl_flare": {"pattern": Pattern.LIGHT, "strike": &"light_ring"},
	&"hl_dive": {"pattern": Pattern.LIGHT, "strike": &"light_burst"},
	&"hl_split": {"pattern": Pattern.LIGHT, "strike": &"light_burst"},
	&"se_mortar": {"pattern": Pattern.HAZARD, "strike": &"shell"},
	&"se_barrage": {"pattern": Pattern.HAZARD, "strike": &"shell"},
	&"se_rail": {"pattern": Pattern.HAZARD, "strike": &"rail"},
	&"se_shock": {"pattern": Pattern.HAZARD, "strike": &"shock_ring"},
	&"se_deploy": {"pattern": Pattern.HAZARD, "strike": &"shell"},
	&"fd_molten": {"pattern": Pattern.MOLTEN, "strike": &"molten"},
	&"fd_vent": {"pattern": Pattern.MOLTEN, "strike": &"steam_ring"},
	&"fd_firestorm": {"pattern": Pattern.MOLTEN, "strike": &"fire_lanes"},
	&"fd_bombs": {"pattern": Pattern.MOLTEN, "strike": &"shell"},
	# v0.8.0 FB1 (FINAL_BOSS.md F4): the Colossus. Its fists' swings throw a dust arc, the slam and the leap blow a
	# crater, its boulders land as craters too (their shards are fireballs). Its spikes are StoneSpikeViews'.
	&"cl_fists": {"pattern": Pattern.STONE, "strike": &"dust_arc"},
	&"cl_slam": {"pattern": Pattern.STONE, "strike": &"crater"},
	&"cl_leap": {"pattern": Pattern.STONE, "strike": &"crater"},
	&"cl_boulder": {"pattern": Pattern.STONE, "strike": &"crater"},
	&"cl_spikes": {"pattern": Pattern.STONE, "strike": &"crack_impact"},
	# v0.8.0 FB3 (FINAL_BOSS.md F6): the Nemesis. Its swings (its combo's and a card's arc) cut a steel arc in its own
	# colours, a card's blast flashes as a burst; its volleys are fireballs (FireballViews' nemesis looks).
	&"nm_slash": {"pattern": Pattern.VOID, "strike": &"steel_arc"},
	&"nm_cast": {"pattern": Pattern.VOID, "strike": &"light_burst"},
}

## Boss kind -> move -> look. The Gatekeeper's row_lanes are StoneSpikeViews' (cracked ground, then spikes).
const BY_KIND := {
	WorldReader.KIND_GATEKEEPER:
	{
		WorldReader.MOVE_MARKS: &"gk_slam",
		WorldReader.MOVE_SWEEP: &"gk_sweep",
	},
	WorldReader.KIND_WARLORD:
	{
		WorldReader.MOVE_FLOOD: &"wl_spears",
		WorldReader.MOVE_CHARGE: &"wl_lunge",
		WorldReader.MOVE_SWEEP: &"wl_bash",
		WorldReader.MOVE_BARRAGE: &"wl_javelins",
	},
	WorldReader.KIND_BROOD_MOTHER:
	{
		WorldReader.MOVE_MARKS: &"bm_eggs",
		WorldReader.MOVE_LEAP: &"bm_leap",
		WorldReader.MOVE_BURROW: &"bm_burrow",
		WorldReader.MOVE_BROOD: &"bm_brood",
	},
	WorldReader.KIND_HIVE_LENS:
	{
		WorldReader.MOVE_LANES: &"hl_beam",
		WorldReader.MOVE_SLAM_RING: &"hl_flare",
		WorldReader.MOVE_LEAP: &"hl_dive",
		WorldReader.MOVE_DEPLOY: &"hl_split",
	},
	WorldReader.KIND_SIEGE_ENGINE:
	{
		WorldReader.MOVE_GRID: &"se_mortar",
		WorldReader.MOVE_MARKS: &"se_barrage",
		WorldReader.MOVE_BARRAGE: &"se_barrage",
		WorldReader.MOVE_LANES: &"se_rail",
		WorldReader.MOVE_SLAM_RING: &"se_shock",
		WorldReader.MOVE_DEPLOY: &"se_deploy",
	},
	WorldReader.KIND_FOUNDRY:
	{
		WorldReader.MOVE_ROW_FLOOD: &"fd_molten",
		WorldReader.MOVE_SLAM_RING: &"fd_vent",
		WorldReader.MOVE_FLOOD: &"fd_firestorm",
		WorldReader.MOVE_BROOD: &"fd_bombs",
	},
	WorldReader.KIND_COLOSSUS:  # v0.8.0 FB1
	{
		WorldReader.MOVE_COMBO: &"cl_fists",
		WorldReader.MOVE_LEAP: &"cl_leap",
		WorldReader.MOVE_MARKS: &"cl_boulder",
		WorldReader.MOVE_SPIKE_CHASE: &"cl_spikes",
		WorldReader.MOVE_SPIKE_BURST: &"cl_spikes",
	},
	WorldReader.KIND_NEMESIS:  # v0.8.0 FB3
	{
		WorldReader.MOVE_MIMIC_COMBO: &"nm_slash",
		WorldReader.MOVE_CARD_CAST: &"nm_cast",
	},
}

## The marker's ground pattern: a world-space pattern in the look's colours, dull at heat 0, hot and bright at 1.
## Unshaded so no shadow hides it.
const MARK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 glow : source_color = vec4(1.0, 0.42, 0.18, 1.0);
uniform vec4 dark : source_color = vec4(0.08, 0.05, 0.04, 1.0);
uniform int pattern = 0;
uniform float heat = 0.5;
uniform float base_alpha = 0.3;
uniform float motion = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wp;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Distances to the nearest and second-nearest cell points (a cellular pattern).
vec2 cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float d = length(g + hash2(i + g) - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d1, d2);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float t = TIME * motion;
	float n = texture(noise_tex, p * 0.12 + vec2(t * 0.02, 0.0)).r;
	float m = 0.0;
	if (pattern == 0) {  // stone: glowing cracks
		vec2 c = cells(p * 1.4);
		float w = mix(0.05, 0.14, heat);
		m = 1.0 - smoothstep(w * 0.35, w, c.y - c.x);
	} else if (pattern == 1) {  // blades: crossing scratches, a steel glint running along them
		float a = abs(fract((p.x + p.y) * 1.6 + n * 0.6) - 0.5);
		float b = abs(fract((p.x - p.y) * 1.1 - n * 0.5) - 0.5);
		m = max(1.0 - smoothstep(0.03, 0.09, a), 0.7 * (1.0 - smoothstep(0.02, 0.06, b)));
	} else if (pattern == 2) {  // acid: bubbling blobs
		vec2 c = cells(p * 1.8 + vec2(0.0, t * 0.15));
		m = 1.0 - smoothstep(0.18, 0.34 + 0.12 * heat, c.x);
		m = max(m * 0.85, (1.0 - smoothstep(0.02, 0.06, abs(n - 0.5))) * 0.6);
	} else if (pattern == 3) {  // light: shimmering caustic bands
		float r1 = sin(length(p - floor(p / 6.0) * 6.0 - 3.0) * 7.0 - t * 4.0);
		float r2 = sin((p.x * 0.7 - p.y * 0.7) * 5.0 + n * 6.0 + t * 2.0);
		m = smoothstep(0.55, 1.0, max(r1, r2) * 0.5 + 0.5 + (n - 0.5) * 0.4);
	} else if (pattern == 4) {  // hazard: diagonal warning stripes over a target grid
		float s = fract((p.x + p.y) * 0.9);
		float g = min(abs(fract(p.x * 0.5) - 0.5), abs(fract(p.y * 0.5) - 0.5));
		m = max(step(0.5, s) * 0.8, 1.0 - smoothstep(0.015, 0.04, g));
	} else if (pattern == 5) {  // molten: dark crust plates with hot seams, flowing
		vec2 c = cells(p * 1.1 + vec2(t * 0.25, t * 0.1));
		m = 1.0 - smoothstep(0.06, 0.2 + 0.15 * heat, c.y - c.x);
		m = max(m, smoothstep(0.55, 0.8, n) * heat);
	} else {  // void (v0.8.0 FB3, the Nemesis): thin rifts torn across the ground, a slow swirl in the dark
		float a = abs(fract((p.x * 0.8 - p.y * 0.6) * 1.3 + n * 1.4 + t * 0.1) - 0.5);
		m = 1.0 - smoothstep(0.02, 0.07 + 0.05 * heat, a);
		m = max(m, smoothstep(0.62, 0.85, n) * 0.6 * heat);
	}
	vec3 hot = glow.rgb * (1.0 + heat * 1.6);
	ALBEDO = mix(dark.rgb, hot, m);
	ALPHA = clamp(max(base_alpha, m * mix(0.45, 1.0, heat)), 0.0, 1.0);
}
"""

static var _shader: Shader


## The look of boss kind `kind`'s move `move` (WorldReader.MOVE_*), or &"" (drawn as before).
static func look_for(kind: int, move: int) -> StringName:
	var moves: Dictionary = BY_KIND.get(kind, {})
	return moves.get(move, &"")


static func pattern_of(look: StringName) -> int:
	return int((LOOKS[look] as Dictionary)["pattern"])


static func strike_of(look: StringName) -> StringName:
	return (LOOKS[look] as Dictionary)["strike"]


## The look's glow (its strike's light, the locked marker's hot colour).
static func glow_of(look: StringName) -> Color:
	return PATTERN_COLORS[pattern_of(look)][1]


static func dark_of(look: StringName) -> Color:
	return PATTERN_COLORS[pattern_of(look)][0]


static func mark_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = MARK_SHADER
	return _shader


## A marker material for `look`: its pattern at `heat`, over a ground tint of `base_alpha`.
static func mark_material(look: StringName, heat: float, base_alpha: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = mark_shader()
	m.set_shader_parameter("pattern", pattern_of(look))
	m.set_shader_parameter("glow", glow_of(look))
	m.set_shader_parameter("dark", dark_of(look))
	m.set_shader_parameter("heat", heat)
	m.set_shader_parameter("base_alpha", base_alpha)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	return m
