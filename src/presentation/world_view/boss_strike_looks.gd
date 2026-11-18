class_name BossStrikeLooks
extends RefCounted
## v0.8.0 AV part 2 (owner O7: "so the attacks look real … not … a red thingy"): the look of every boss ground attack
## other than the Gatekeeper's shock lanes (StoneSpikeViews). Per boss kind and move (WorldReader.MOVE_*): the marker's
## ground pattern (TelegraphViews draws the locked flash and a windup's fill with it instead of a flat red fill; the
## dull outline while it tracks and the bright edge once it locks stay, so the lock flash is still the dodge cue) and
## the strike's 3D effect (BossStrikeViews). Colours stay off the hero's (ThemePalette player_core, a cyan).
## Presentation only: a look changes nothing the sim decides.

## Marker patterns (the MARK_SHADER's `pattern`).
## VOID, the void bosses' (a cracked dark violet stain); WATER, the Tidecaller's (ice cracks in the snow's colour).
## The code patterns in MARK_SHADER stay as the fallback while the crack sheet is missing.
enum Pattern { STONE, BLADE, ACID, LIGHT, HAZARD, MOLTEN, VOID, WATER }

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
	Pattern.WATER: [Color(0.02, 0.07, 0.05), Color(0.52, 1.0, 0.42)],  # sea-green, 80° from the hero's cyan
}

## Per pattern, the texture that replaces the code pattern: [texture id, world scale (repeats a metre), how much of
## its own colour shows as the ground under the hot part (0: the look's dark tint), flow, and how opaque that ground is
## (a factor of the marker's base alpha: under 1 the floor shows through)]. The ink patterns (INK) take only the
## crack sheet's shape from fx_ground_cracks, none of its painted colour. The Foundry's crust is drawn in fewer,
## larger plates with the floor showing through.
const PATTERN_TEX := {
	Pattern.STONE: ["fx_ground_cracks", 0.3, 0.0, 0.0, 1.0],
	Pattern.BLADE: ["tex_mark_steel", 0.25, 1.0, 0.0, 1.0],
	Pattern.LIGHT: ["tex_mark_light", 0.2, 1.0, 0.0, 1.0],
	Pattern.HAZARD: ["fx_ground_cracks", 0.25, 0.0, 0.0, 1.0],
	Pattern.MOLTEN: ["tex_lava_crust", 0.1, 0.45, 1.0, 0.55],
	Pattern.VOID: ["fx_ground_cracks", 0.3, 0.0, 0.0, 1.0],
	Pattern.WATER: ["fx_ground_cracks", 0.3, 0.0, 0.0, 1.0],
}

## The patterns drawn in the floor's own style rather than as a painted texture: thin crack lines (the core of the
## crack sheet's cracks, as the stone slam's cracks are drawn) over a stain of the ground. "line": the cracks' colour;
## "hot": the colour they warm toward; "warm": [how warm while the marker shows, how warm in its last moments (the
## lock's pulse, the end of a windup)]; "stain": the ground under them, its alpha a factor of the marker's base alpha;
## "lines": 0 draws the stain alone (a flat fill). The lock's bright edge stays the dodge cue over all of them.
const INK := {
	# The slam's dark cracks over a slight darkening; a faint warm glow only as the hit comes.
	Pattern.STONE:
	{
		"line": Color(0.09, 0.085, 0.09),
		"hot": Color(1.0, 0.42, 0.18),
		"warm": Vector2(0.0, 0.12),
		"stain": Color(0.12, 0.11, 0.115, 0.8),
		"lines": 1.0,
	},
	# A flat dark-green fill: the acid is told by its colour, not a painted slime.
	Pattern.ACID:
	{
		"line": Color(0.07, 0.17, 0.05),
		"hot": Color(0.62, 1.0, 0.22),
		"warm": Vector2.ZERO,
		"stain": Color(0.07, 0.17, 0.05, 1.5),
		"lines": 0.0,
	},
	# Scorched dark ground, its cracks glowing the Siege Engine's red-orange.
	Pattern.HAZARD:
	{
		"line": Color(0.32, 0.08, 0.03),
		"hot": Color(1.0, 0.36, 0.1),
		"warm": Vector2(0.3, 0.7),
		"stain": Color(0.07, 0.05, 0.04, 1.3),
		"lines": 1.0,
	},
	# A dark violet stain cracked like dark stone, the violet showing in the cracks as the hit comes.
	Pattern.VOID:
	{
		"line": Color(0.05, 0.02, 0.08),
		"hot": Color(0.62, 0.22, 0.85),
		"warm": Vector2(0.05, 0.25),
		"stain": Color(0.14, 0.05, 0.2, 1.5),
		"lines": 1.0,
	},
	# Ice cracks in the snow's own pale blue-grey; no glow.
	Pattern.WATER:
	{
		"line": Color(0.36, 0.46, 0.58),
		"hot": Color(0.78, 0.86, 0.94),
		"warm": Vector2(0.0, 0.3),
		"stain": Color(0.5, 0.6, 0.7, 1.2),
		"lines": 1.0,
	},
}
## Looks whose ink differs from their pattern's. The Shockwave's warning can cover the whole room: a quieter dark
## wash under its glowing edge, no cracks.
const LOOK_INK := {
	&"se_shock":
	{
		"line": Color(0.07, 0.05, 0.04),
		"hot": Color(1.0, 0.36, 0.1),
		"warm": Vector2.ZERO,
		"stain": Color(0.07, 0.05, 0.04, 1.1),
		"lines": 0.0,
	},
}
## Boss moves drawn on the ground in a look but with no strike of BossStrikeViews' (the Great Javelin's aim lane takes
## the spear lines' steel scratches; its landing is GreatJavelinViews').
const MARK_ONLY := {
	WorldReader.KIND_WARLORD: {WorldReader.MOVE_GREAT_JAVELIN: &"wl_spears"},
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
	# FINAL_BOSS.md F4: the Colossus. Its fists' swings throw a dust arc, the slam and the leap blow a
	# crater, its boulders land as craters too (their shards are fireballs). Its spikes are StoneSpikeViews'.
	&"cl_fists": {"pattern": Pattern.STONE, "strike": &"dust_arc"},
	&"cl_slam": {"pattern": Pattern.STONE, "strike": &"crater"},
	&"cl_leap": {"pattern": Pattern.STONE, "strike": &"crater"},
	&"cl_boulder": {"pattern": Pattern.STONE, "strike": &"crater"},
	&"cl_spikes": {"pattern": Pattern.STONE, "strike": &"crack_impact"},
	# FINAL_BOSS.md F6: the Nemesis. Its swings (its combo's and a card's arc) cut a steel arc in its own
	# colours, a card's blast flashes as a burst; its volleys are fireballs (FireballViews' nemesis looks).
	&"nm_slash": {"pattern": Pattern.VOID, "strike": &"steel_arc"},
	&"nm_cast": {"pattern": Pattern.VOID, "strike": &"light_burst"},
	# The Tidecaller. The Undertow's circle erupts as a burst of spray, the Shell Slam blows a ring of steam
	# off the water, both over swirling water.
	&"tc_undertow": {"pattern": Pattern.WATER, "strike": &"eruption"},
	&"tc_slam": {"pattern": Pattern.WATER, "strike": &"steam_ring"},
	# The Twin Wardens. The Sword Lane's strip scorches where his blade cut (the slash itself is TwinViews'), the
	# Shield Bash cracks a shock ring out of the stone.
	&"tw_sweep": {"pattern": Pattern.BLADE, "strike": &"skid"},
	&"tw_bash": {"pattern": Pattern.STONE, "strike": &"shock_ring"},
	&"tw_charge": {"pattern": Pattern.STONE, "strike": &"skid"},  # The amber's Charge, Ground Slam
	&"tw_slam": {"pattern": Pattern.STONE, "strike": &"crater"},
	&"tw_runes": {"pattern": Pattern.VOID, "strike": &"light_ring"},  # The violet's Rune Ring, Blink
	&"tw_blink": {"pattern": Pattern.VOID, "strike": &"light_burst"},
	# The amber Warden's sword: each cut of his combo a steel arc over scratched steel; the overhead's wide arc
	# smashes into the stone (cracks, a dust arc). The violet one's Shadow Swords: each line torn dark violet, a
	# violet beam down it as the blade cuts (the blades and their slash are WardenBladeViews').
	&"tw_sword": {"pattern": Pattern.BLADE, "strike": &"steel_arc"},
	&"tw_overhead": {"pattern": Pattern.STONE, "strike": &"dust_arc"},
	&"tw_swords": {"pattern": Pattern.VOID, "strike": &"beam"},
	# The Clockwork Judge. The Verdict's square takes a column of gold light where the pendulum drops (the
	# pendulum itself is JudgeViews'); the Gavel Slam rings a light shockwave out over the floor.
	&"cj_verdict": {"pattern": Pattern.LIGHT, "strike": &"beam"},
	&"cj_gavel": {"pattern": Pattern.LIGHT, "strike": &"light_ring"},
	# The Lantern Shade. The Snuff's circle closes like a hand of shadow (a void burst over the swirling
	# dark); the Lantern Sweep rings a light shockwave out where the lantern swung.
	&"ls_snuff": {"pattern": Pattern.VOID, "strike": &"light_burst"},
	&"ls_sweep": {"pattern": Pattern.VOID, "strike": &"light_ring"},
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
	WorldReader.KIND_TIDECALLER:  # v0.9.0 NB1
	{
		WorldReader.MOVE_MARKS: &"tc_undertow",
		WorldReader.MOVE_SLAM_RING: &"tc_slam",
	},
	WorldReader.KIND_TWIN_WARDEN:  # The amber Warden (the boss) and its violet twin alike
	{
		WorldReader.MOVE_CHAIN_SWEEP: &"tw_sweep",
		WorldReader.MOVE_SLAM_RING: &"tw_bash",
		WorldReader.MOVE_CHARGE: &"tw_charge",  # Each Warden's own moveset
		WorldReader.MOVE_MARKS: &"tw_slam",
		WorldReader.MOVE_LEAP: &"tw_blink",
		WorldReader.MOVE_SWEEP: &"tw_overhead",
		WorldReader.MOVE_SWORD_COMBO: &"tw_sword",
		WorldReader.MOVE_SHADOW_SWORDS: &"tw_swords",
	},
	WorldReader.KIND_TWIN_WARDEN_VIOLET:
	{
		WorldReader.MOVE_CHAIN_SWEEP: &"tw_sweep",
		WorldReader.MOVE_SLAM_RING: &"tw_runes",  # The violet's ring is its Rune Ring
		WorldReader.MOVE_CHARGE: &"tw_charge",
		WorldReader.MOVE_MARKS: &"tw_slam",
		WorldReader.MOVE_LEAP: &"tw_blink",
		WorldReader.MOVE_SWEEP: &"tw_sword",
		WorldReader.MOVE_SWORD_COMBO: &"tw_sword",
		WorldReader.MOVE_SHADOW_SWORDS: &"tw_swords",
	},
	WorldReader.KIND_CLOCKWORK_JUDGE:  # v0.9.0 NB3
	{
		WorldReader.MOVE_VERDICT: &"cj_verdict",
		WorldReader.MOVE_SLAM_RING: &"cj_gavel",
	},
	WorldReader.KIND_LANTERN_SHADE:  # v0.9.0 NB4
	{
		WorldReader.MOVE_MARKS: &"ls_snuff",
		WorldReader.MOVE_SLAM_RING: &"ls_sweep",
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
uniform sampler2D pattern_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tex_on = 0.0;
uniform float tex_scale = 0.25;
uniform float tex_body = 1.0;
uniform float tex_flow = 0.0;
uniform float tex_body_alpha = 1.0;
uniform float ink_on = 0.0;
uniform vec4 ink_line : source_color = vec4(0.09, 0.085, 0.09, 1.0);
uniform vec4 ink_hot : source_color = vec4(1.0, 0.42, 0.18, 1.0);
uniform vec4 ink_stain : source_color = vec4(0.12, 0.11, 0.115, 1.0);
uniform float ink_stain_k = 0.7;
uniform float ink_lines = 1.0;
uniform vec2 ink_warm = vec2(0.0, 0.4);

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
	if (ink_on > 0.5) {
		// Ink: the crack sheet's thin cores (its alpha where its red is high; the sampler is linear) as lines over a
		// stain of the ground, warming toward `ink_hot` only as the heat nears the hit.
		vec4 tx = texture(pattern_tex, p * tex_scale);
		float line = tx.a * smoothstep(0.3, 0.78, tx.r) * ink_lines;
		float warm = mix(ink_warm.x, ink_warm.y, smoothstep(0.75, 1.0, heat));
		vec3 lc = mix(ink_line.rgb, ink_hot.rgb * (1.0 + 0.6 * heat), warm);
		ALBEDO = mix(ink_stain.rgb, lc, line);
		float stain = base_alpha * ink_stain_k * mix(0.85, 1.0, heat);
		ALPHA = clamp(max(stain, line * mix(0.6, 1.0, heat)), 0.0, 1.0);
	} else {
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
		} else if (pattern == 7) {  // water (v0.9.0 NB1, the Tidecaller): caustic ripples swirling round, foam flecks
			vec2 c = cells(p * 1.3 + vec2(sin(t * 0.6), cos(t * 0.5)) * 0.4);
			float caustic = 1.0 - smoothstep(0.04, 0.16 + 0.1 * heat, c.y - c.x);
			float swirl = sin(length(fract(p / 5.0) - 0.5) * 30.0 - t * 5.0 + n * 4.0) * 0.5 + 0.5;
			m = max(caustic * 0.9, smoothstep(0.75, 1.0, swirl) * 0.7);
			m = max(m, smoothstep(0.7, 0.9, n) * 0.5 * heat);
		} else {  // void (v0.8.0 FB3, the Nemesis): thin rifts torn across the ground, a slow swirl in the dark
			float a = abs(fract((p.x * 0.8 - p.y * 0.6) * 1.3 + n * 1.4 + t * 0.1) - 0.5);
			m = 1.0 - smoothstep(0.02, 0.07 + 0.05 * heat, a);
			m = max(m, smoothstep(0.62, 0.85, n) * 0.6 * heat);
		}
		vec3 hot = glow.rgb * (1.0 + heat * 1.6);
		vec3 body = dark.rgb;
		float body_alpha = base_alpha;
		if (tex_on > 0.5) {
			// The owner's texture in place of the code pattern: its alpha is the part that heats (the scratches, the
			// light's seams, the crust's seams), tinted toward the glow; a surface's own colour is the ground under it
			// (tex_body), darkened so the hot part reads; tex_body_alpha under 1 lets the floor show through both.
			vec4 tx = texture(pattern_tex, p * tex_scale + vec2(t * 0.01, 0.0) * tex_flow);
			m = tx.a;
			hot = mix(tx.rgb, glow.rgb, 0.45) * (1.0 + heat * 1.6);
			body = mix(dark.rgb, tx.rgb * 0.5, tex_body);
			body_alpha *= tex_body_alpha;
		}
		ALBEDO = mix(body, hot, m);
		ALPHA = clamp(max(body_alpha, m * mix(0.45, 1.0, heat) * (0.5 + 0.5 * tex_body_alpha)), 0.0, 1.0);
	}
}
"""

static var _shader: Shader


## The look of boss kind `kind`'s move `move` (WorldReader.MOVE_*), or &"" (drawn as before).
static func look_for(kind: int, move: int) -> StringName:
	var moves: Dictionary = BY_KIND.get(kind, {})
	return moves.get(move, &"")


## The look boss kind `kind`'s move `move` is drawn in on the ground: its strike's look, or a MARK_ONLY one.
static func mark_look_for(kind: int, move: int) -> StringName:
	var look := look_for(kind, move)
	if look != &"":
		return look
	var moves: Dictionary = MARK_ONLY.get(kind, {})
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
	var spec: Array = PATTERN_TEX.get(pattern_of(look), [])
	var tex := BossStrikeMeshes.texture(spec[0]) if not spec.is_empty() else null
	var ink := ink_of(look)
	var inked := not ink.is_empty() and (tex != null or float(ink["lines"]) == 0.0)
	m.set_shader_parameter("ink_on", 1.0 if inked else 0.0)
	m.set_shader_parameter("tex_on", 1.0 if tex != null and not inked else 0.0)
	if tex != null:
		m.set_shader_parameter("pattern_tex", tex)
		m.set_shader_parameter("tex_scale", spec[1])
		m.set_shader_parameter("tex_body", spec[2])
		m.set_shader_parameter("tex_flow", spec[3])
		m.set_shader_parameter("tex_body_alpha", spec[4])
	if inked:
		var stain: Color = ink["stain"]
		m.set_shader_parameter("ink_line", ink["line"])
		m.set_shader_parameter("ink_hot", ink["hot"])
		m.set_shader_parameter("ink_stain", Color(stain, 1.0))
		m.set_shader_parameter("ink_stain_k", stain.a)
		m.set_shader_parameter("ink_lines", ink["lines"])
		m.set_shader_parameter("ink_warm", ink["warm"])
	return m


## The crack sheet `t` (fx_ground_cracks) as thin crack lines: white, only its cracks' cores (where its red is high)
## in the alpha, none of its painted lava; a floor mark tints it dark. At most 256 px across (a mark is a few metres).
static func crack_lines(t: Texture2D) -> Texture2D:
	var img := t.get_image()
	if img == null:
		return t
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var n := mini(256, img.get_width())
	if img.get_width() != n:
		img.resize(n, n * img.get_height() / img.get_width(), Image.INTERPOLATE_BILINEAR)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(1, 1, 1, c.a * smoothstep(0.6, 0.9, c.r)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The ink `look` is drawn in ({} for a painted or code pattern): its own, or its pattern's.
static func ink_of(look: StringName) -> Dictionary:
	return LOOK_INK.get(look, INK.get(pattern_of(look), {}))
