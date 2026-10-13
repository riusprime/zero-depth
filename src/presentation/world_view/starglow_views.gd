class_name StarglowViews
extends Node3D
## v0.7.5 NB2: the floor's starglow pools (Starfall), drawn exactly where the sim has them (WorldReader.ice_patch with
## surface_kind &"starglow": looks fast = is fast). Each pool is one flat faceted sheet of deep night-violet facets in
## close shades with small stars twinkling in it (a shader: frame time, still with reduced motion), and a bright
## lavender rim on its exact edge so its boundary reads at a glance. It only helps (the hero runs faster on it), so it
## is ground, not a telegraph: none of the hostile hues, no pulse. Never casts a shadow. Its facet shades come from
## the cosmetic stream. Presentation only.

const DEEP := Color("#2A1E5C")
const LIGHT := Color("#5A44B0")
const RIM := Color("#C4A6FF")
const STAR := Color("#FFE6FA")
## Height above the ground (the rim a hair higher), so nothing z-fights.
const LIFT := 0.014
const RIM_W := 0.1
const FACET_M := 0.75
## Stars per square metre cell grid (cells per metre) and the share of cells that hold a star.
const STAR_CELLS_PER_M := 3.0
const STAR_SHARE := 0.09

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
	float s = step(1.0 - share, h) * smoothstep(0.16, 0.0, d) * tw;
	ALBEDO = base + star.rgb * s * 2.2;
}
"""

var patch_count := 0
var sheet: MeshInstance3D
var rim: MeshInstance3D


## Builds every pool of `reader`'s floor. `seed_value`: the floor seed (the cosmetic stream's root).
func build(reader: WorldReader, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 4243  # the cosmetic stream: presentation only
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rs := SurfaceTool.new()
	rs.begin(Mesh.PRIMITIVE_TRIANGLES)
	patch_count = reader.ice_patch_count()
	for i in patch_count:
		var r := reader.ice_patch(i)
		_sheet(st, r, rng)
		_rim(rs, r)
	if patch_count == 0:
		return
	sheet = _add_mesh("StarglowSheet", st, pool_material())
	rim = _add_mesh("StarglowRim", rs, rim_material())


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
	m.emission_energy_multiplier = 0.9
	return m


func _add_mesh(n: String, st: SurfaceTool, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


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
