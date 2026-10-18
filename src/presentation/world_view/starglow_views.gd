class_name StarglowViews
extends Node3D
## v0.7.5 NB2: the floor's starglow pools (Starfall), drawn exactly where the sim has them (WorldReader.ice_patch with
## surface_kind &"starglow": looks fast = is fast). It only helps (the hero runs faster on it), so it is ground, not a
## telegraph: none of the hostile hues, no pulse. Never casts a shadow. Presentation only.
## v0.8.0 MI (owner 2026-10-18: "ground star is currently a rectangle on the ground I created this texture but I want
## you to not make it a random rectangle but give it a crack shape, use the image"): each pool is a crack in the floor
## through which the owner's ground_star shows (its cosmic stone and starlight, sampled in world space so the pools
## never repeat it), with a soft violet glow round the crack. The crack shapes are CRACKS (four jagged branching
## shapes in one mask, scripts/assets/mi_prep.py), each pool drawing one of them turned or mirrored (eight ways) from
## the cosmetic stream, stretched over the sim's rect: every shape's trunks run out to all four sides, so the cracks
## reach the pool's edges, and a faint violet wash (AREA_ALPHA) keeps the rest of the rect readable, where the speed
## is. One mesh, one material for every pool on the floor (it was two: the faceted sheet and its rim). Without the
## owner's textures the v0.7.5 faceted sheet and bright rim draw (L15).

const DEEP := Color("#1B1046")
const LIGHT := Color("#3F2C96")
const RIM := Color("#C4A6FF")
const STAR := Color("#FFE6FA")
## Height above the ground (the rim a hair higher), so nothing z-fights.
const LIFT := 0.014
const RIM_W := 0.1
const FACET_M := 0.75
## Stars per square metre cell grid (cells per metre) and the share of cells that hold a star.
const STAR_CELLS_PER_M := 3.0
const STAR_SHARE := 0.16
## v0.8.0 MI: the owner's texture and the crack masks; metres one tile of the texture covers; the faint wash over the
## rest of the pool (alpha) and the crack's glow colour.
const STARS_TEX := "res://assets/textures/kit/ground_star.png"
const CRACKS_TEX := "res://assets/textures/kit/ground_star_cracks.png"
const TILE_M := 3.0
const AREA_ALPHA := 0.16
const CRACK_GLOW := Color("#B070FF")

const POOL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 deep : source_color = vec4(0.16, 0.12, 0.36, 1.0);
uniform vec4 light : source_color = vec4(0.35, 0.27, 0.69, 1.0);
uniform vec4 star : source_color = vec4(1.0, 0.9, 0.98, 1.0);
uniform float cells = 3.0;
uniform float share = 0.09;
uniform float motion = 1.0;

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The facet shade comes in the vertex colour (0..1 between deep and light); stars sit in a few grid cells,
	// each twinkling at its own phase.
	vec3 base = mix(deep.rgb, light.rgb, COLOR.r);
	vec2 g = world.xz * cells;
	vec2 c = floor(g);
	float h = hash(c);
	vec2 off = vec2(hash(c + 7.3), hash(c + 3.1)) * 0.5 + 0.25;
	float d = length(fract(g) - off);
	float tw = mix(1.0, 0.45 + 0.55 * sin(TIME * (1.2 + h * 2.4) + h * 40.0), motion);
	float s = step(1.0 - share, h) * smoothstep(0.2, 0.0, d) * tw;
	ALBEDO = base + star.rgb * s * 3.0;
}
"""

## v0.8.0 MI: the crack. COLOR.rg is the pool's shape's cell in the mask (0 or 0.5 each); UV the place in it.
const CRACK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D cracks : filter_linear_mipmap, repeat_disable;
uniform sampler2D stars : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile_m = 3.0;
uniform vec4 glow : source_color = vec4(0.69, 0.44, 1.0, 1.0);
uniform vec4 wash : source_color = vec4(0.11, 0.06, 0.27, 1.0);
uniform float wash_alpha = 0.1;
uniform float motion = 1.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = COLOR.rg + clamp(UV, vec2(0.004), vec2(0.996)) * 0.5;
	vec2 m = texture(cracks, uv).rg;
	vec3 sky = texture(stars, world.xz / tile_m).rgb;
	// The starlight in the crack breathes a little (frame time; still with reduced motion).
	float breathe = mix(1.0, 0.85 + 0.15 * sin(TIME * 1.7 + world.x * 0.7 + world.z * 0.4), motion);
	float core = m.r;
	float halo = m.g;
	vec3 ground = mix(wash.rgb, sky * 0.7, 0.5);
	// A soft cut where a crack meets the pool's edge (it still reaches it).
	vec2 q = min(UV, vec2(1.0) - UV);
	core *= mix(0.35, 1.0, smoothstep(0.0, 0.04, min(q.x, q.y)));
	vec3 col = mix(ground, sky * (1.15 + 0.55 * core) * breathe, core) + glow.rgb * halo * 0.3;
	ALBEDO = col;
	ALPHA = clamp(core + halo * 0.45 + wash_alpha, 0.0, 1.0);
}
"""

## The eight ways a crack shape is laid on its pool: the UVs of the rect's corners (a, b, c, d in _crack's order).
const TURNS := [
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
	[Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0)],
	[Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)],
	[Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)],
	[Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)],
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
	[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)],
	[Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector2(0, 1)],
]

var patch_count := 0
var sheet: MeshInstance3D
var rim: MeshInstance3D
## v0.8.0 MI: true when the pools are cracks (the owner's textures), and each pool's crack shape (0..3).
var cracked := false
var shapes := PackedInt32Array()


## Builds every pool of `reader`'s floor. `seed_value`: the floor seed (the cosmetic stream's root).
func build(reader: WorldReader, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 4243  # the cosmetic stream: presentation only
	patch_count = reader.ice_patch_count()
	if patch_count == 0:
		return
	var crack_mat := crack_material()
	if crack_mat != null:
		cracked = true
		var cs := SurfaceTool.new()
		cs.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in patch_count:
			var shape := rng.randi_range(0, 3)
			shapes.append(shape)
			_crack(cs, reader.ice_patch(i), shape, TURNS[rng.randi_range(0, TURNS.size() - 1)])
		sheet = _add_mesh("StarglowCracks", cs, crack_mat)
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rs := SurfaceTool.new()
	rs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in patch_count:
		var r := reader.ice_patch(i)
		_sheet(st, r, rng)
		_rim(rs, r)
	sheet = _add_mesh("StarglowSheet", st, pool_material())
	rim = _add_mesh("StarglowRim", rs, rim_material())


## v0.8.0 MI: the crack material (the owner's ground_star in the CRACKS shapes), or null without the textures.
static func crack_material() -> ShaderMaterial:
	if not (ResourceLoader.exists(STARS_TEX) and ResourceLoader.exists(CRACKS_TEX)):
		return null
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = CRACK_SHADER
	m.set_shader_parameter("cracks", load(CRACKS_TEX))
	m.set_shader_parameter("stars", load(STARS_TEX))
	m.set_shader_parameter("tile_m", TILE_M)
	m.set_shader_parameter("glow", CRACK_GLOW)
	m.set_shader_parameter("wash", DEEP)
	m.set_shader_parameter("wash_alpha", AREA_ALPHA)
	m.set_shader_parameter("motion", 0.0 if ViewPrefs.reduced_motion else 1.0)
	m.render_priority = 1
	return m


## The pool's shader material (its stars twinkle; still with reduced motion).
static func pool_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = POOL_SHADER
	m.set_shader_parameter("deep", DEEP)
	m.set_shader_parameter("light", LIGHT)
	m.set_shader_parameter("star", STAR)
	m.set_shader_parameter("cells", STAR_CELLS_PER_M)
	m.set_shader_parameter("share", STAR_SHARE)
	m.set_shader_parameter("motion", 0.0 if ViewPrefs.reduced_motion else 1.0)
	return m


static func rim_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = RIM
	m.roughness = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = RIM
	m.emission_energy_multiplier = 1.3
	return m


func _add_mesh(n: String, st: SurfaceTool, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## v0.8.0 MI: one pool as one quad over its exact rect, its crack shape's cell in the vertex colour and its turn in
## the corners' UVs.
func _crack(st: SurfaceTool, r: Rect2, shape: int, turn: Array) -> void:
	var cell := Color(0.5 * (shape % 2), 0.5 * floorf(shape / 2.0), 0.0)
	var corners := [
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)
	]
	for k: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(cell)
		st.set_uv(turn[k])
		st.set_normal(Vector3.UP)
		st.add_vertex(SimPlane.to_3d(corners[k], LIFT))


## The pool cut into facets, two triangles each, every triangle its own shade (in the vertex colour's red).
func _sheet(st: SurfaceTool, r: Rect2, rng: RandomNumberGenerator) -> void:
	var nx := maxi(1, int(round(r.size.x / FACET_M)))
	var ny := maxi(1, int(round(r.size.y / FACET_M)))
	for i in nx:
		for j in ny:
			var a := r.position + Vector2(r.size.x * i / nx, r.size.y * j / ny)
			var b := r.position + Vector2(r.size.x * (i + 1) / nx, r.size.y * j / ny)
			var c := r.position + Vector2(r.size.x * (i + 1) / nx, r.size.y * (j + 1) / ny)
			var d := r.position + Vector2(r.size.x * i / nx, r.size.y * (j + 1) / ny)
			var q := [a, b, c, d] if (i + j) % 2 == 0 else [b, c, d, a]
			for tri: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
				var shade := Color(rng.randf_range(0.1, 0.6), 0.0, 0.0)
				for p: Vector2 in tri:
					st.set_color(shade)
					st.set_normal(Vector3.UP)
					st.add_vertex(SimPlane.to_3d(p, LIFT))


## A flat strip RIM_W wide just inside the pool's edge, a hair above the sheet.
func _rim(st: SurfaceTool, r: Rect2) -> void:
	var inner := r.grow(-RIM_W)
	var y := LIFT + 0.002
	for strip: Rect2 in [
		Rect2(r.position, Vector2(r.size.x, RIM_W)),
		Rect2(Vector2(r.position.x, inner.end.y), Vector2(r.size.x, RIM_W)),
		Rect2(Vector2(r.position.x, inner.position.y), Vector2(RIM_W, inner.size.y)),
		Rect2(Vector2(inner.end.x, inner.position.y), Vector2(RIM_W, inner.size.y)),
	]:
		var a := strip.position
		var b := Vector2(strip.end.x, strip.position.y)
		var c := strip.end
		var d := Vector2(strip.position.x, strip.end.y)
		for p: Vector2 in [a, b, c, a, c, d]:
			st.set_normal(Vector3.UP)
			st.add_vertex(SimPlane.to_3d(p, y))
