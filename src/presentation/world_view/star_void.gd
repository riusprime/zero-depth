class_name StarVoid
extends RefCounted
## v0.7.5 NB2: the pieces of Starfall's starry void (BiomeEdge's &"stars" style): where they go and what they are
## made of. The floor is a floating island of dark star stone with faceted spikes hanging from its rim; twinkling
## stars (white, pale teal, lavender, pink) fill the void below; soft nebula clouds (violet, teal, magenta) glow under
## them; small rock islands, some carrying a crystal cluster, drift around the floor. Every placement comes from the
## cosmetic stream BiomeEdge hands in; the twinkle and the drift are frame time, still with reduced motion. All of it
## stays below the ground (y < 0) and clear of the floor, so nothing stands where you walk or hides a fight. No
## collision. Presentation only.
## v0.8.0 TX3: with the owner's `fx_star_motes` installed (MOTES_TEX, 2 x 2: a four-point twinkle, a soft round star,
## a tiny comet, a sparkle cluster) each star is one of those sprites on a camera-facing quad (still one MultiMesh,
## one draw), added over the void; without it the code-made octahedron stays.

## The rock under the floor: how far it reaches past the ground and how deep it goes (m).
const ROCK_LIP := 0.12
const ROCK_FOOT := -2.2
const ROCK := Color("#4A4270")
## Spikes hanging from the floor's rim: one every SPIKE_STEP metres of open edge, their top radius and length (m).
const SPIKE_STEP := 1.4
const SPIKE_RADIUS := Vector2(0.45, 1.0)
const SPIKE_LENGTH := Vector2(1.2, 3.4)
## Stars: per square metre of the void around the floor, how far out, between which depths, their sizes (m). The
## camera's far plane (IsoRig: 100 m, 60 m out) keeps the void in view to about 11 m under the ground at the screen top.
const STAR_DENSITY := 0.1
const STAR_REACH := 45.0
const STAR_Y := Vector2(-10.5, -3.0)
const STAR_SIZE := Vector2(0.08, 0.2)
const STAR_BIG_SHARE := 0.06
const STAR_BIG := Vector2(0.28, 0.42)
## Star colours and their weights.
const STAR_COLORS := [
	[Color("#FFFFFF"), 60], [Color("#B8FFF4"), 15], [Color("#D8C4FF"), 15], [Color("#FFC8EE"), 10]
]
## Nebula clouds: one per this many square metres of the floor's area (clamped), their sizes and depth (m).
const NEBULA_AREA := 500.0
const NEBULA_MIN := 6
const NEBULA_MAX := 16
const NEBULA_SIZE := Vector2(28.0, 64.0)
const NEBULA_Y := -11.0
const NEBULA_REACH := 30.0
const NEBULA_COLORS := [Color("#7A3CFF"), Color("#2AB8A8"), Color("#E040B0")]
## Floating islands: per square metre of the void near the floor, how far out, how far they keep from the floor's
## edge, their top radius and depth (m), and the share carrying a crystal cluster.
const ISLAND_DENSITY := 0.006
const ISLAND_REACH := 22.0
const ISLAND_KEEP := 2.0
const ISLAND_RADIUS := Vector2(0.6, 2.4)
const ISLAND_Y := Vector2(-7.0, -1.2)
const CRYSTAL_SHARE := 0.45
## A crystal's tip keeps this far under the ground's level (m); one shorter than GEM_MIN is left off.
const GEM_CLEAR := 0.1
const GEM_MIN := 0.4
## The drift: how far (m) and how fast (radians per second) the islands bob.
const DRIFT_M := 0.18
const DRIFT_SPEED := 0.45

const STAR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float motion = 1.0;

varying vec3 tint;
varying float phase;

void vertex() {
	tint = COLOR.rgb;
	phase = float(INSTANCE_ID) * 1.618034;
}

void fragment() {
	// Over 1 so the brightest stars cross the glow threshold and halo; each twinkles at its own rate and phase.
	float rate = 0.8 + fract(phase) * 2.6;
	float tw = mix(1.0, 0.3 + 0.7 * (0.5 + 0.5 * sin(TIME * rate + phase * 6.0)), motion);
	ALBEDO = tint * (0.9 + 1.7 * tw);
}
"""

## v0.8.0 TX3: the owner's star motes, and a sprite quad's size against the old octahedron's (the motes' glow round a
## small core; starting value).
const MOTES_TEX := "res://assets/textures/vfx/fx_star_motes.png"
const SPRITE_SCALE := 2.8

const SPRITE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float motion = 1.0;
uniform sampler2D motes : source_color, filter_linear_mipmap;

varying vec3 tint;
varying float phase;

void vertex() {
	tint = COLOR.rgb;
	phase = float(INSTANCE_ID) * 1.618034;
	// Face the camera, keeping the instance's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	// One of the four motes (its quarter from the instance), tinted toward the star's colour; it twinkles as before.
	float v = floor(fract(phase * 0.37) * 4.0);
	vec4 tx = texture(motes, (vec2(mod(v, 2.0), floor(v * 0.5)) + UV) * 0.5);
	float rate = 0.8 + fract(phase) * 2.6;
	float tw = mix(1.0, 0.3 + 0.7 * (0.5 + 0.5 * sin(TIME * rate + phase * 6.0)), motion);
	ALBEDO = tx.rgb * mix(vec3(1.0), tint, 0.6) * tx.a * (0.9 + 1.7 * tw);
}
"""

const NEBULA_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.48, 0.24, 1.0, 1.0);
uniform float seed_value = 0.0;
uniform float strength = 0.32;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// A soft cloud: a radial falloff broken up by two octaves of value noise, so no two clouds share an outline.
	vec2 uv = UV - 0.5;
	float n = noise(UV * 3.0 + seed_value) * 0.6 + noise(UV * 7.0 - seed_value) * 0.4;
	float a = smoothstep(1.0, 0.05, length(uv) * 2.0 + (n - 0.5) * 0.8);
	ALBEDO = tint.rgb * strength;
	ALPHA = a * a * smoothstep(1.0, 0.75, length(uv) * 2.0);
}
"""

const DRIFT_SHADER := """
shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.23, 0.2, 0.32, 1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float use_tex = 0.0;
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow_energy = 0.0;
uniform float rough = 0.85;
uniform float spec = 0.4;
uniform float metal = 0.0;
uniform float drift = 0.18;
uniform float speed = 0.45;
uniform float motion = 1.0;

void vertex() {
	// A slow bob in world metres, its phase from where the instance floats (an island and its crystal move as one).
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = dot(o.xz, vec2(0.37, 0.61));
	float sy = max(length(MODEL_MATRIX[1].xyz), 0.001);
	VERTEX.y += sin(TIME * speed + ph) * drift * motion / sy;
}

void fragment() {
	// v0.8.0 MI: an owner's island model draws its own colour map (use_tex 1).
	ALBEDO = mix(albedo.rgb, texture(tex, UV).rgb, use_tex);
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	EMISSION = glow.rgb * glow_energy;
	RIM = 0.45;
	RIM_TINT = 0.5;
}
"""


## The dark star stone, a little toward the biome's `edge` colour (the floor's rock and its spikes).
static func rock_material(edge_color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = ROCK.lerp(edge_color, 0.3)
	m.roughness = 0.9
	m.rim_enabled = true
	m.rim = 0.45
	m.rim_tint = 0.5
	return m


static func star_material() -> ShaderMaterial:
	var tex := motes()
	var m := _shader(SPRITE_SHADER if tex != null else STAR_SHADER)
	m.set_shader_parameter("motion", _motion())
	if tex != null:
		m.set_shader_parameter("motes", tex)
	return m


## v0.8.0 TX3: the owner's star motes (null: not installed; the code-made stars stay).
static func motes() -> Texture2D:
	return load(MOTES_TEX) as Texture2D if ResourceLoader.exists(MOTES_TEX) else null


static func nebula_material(tint: Color, seed_value: float) -> ShaderMaterial:
	var m := _shader(NEBULA_SHADER)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("seed_value", seed_value)
	return m


## The islands' stone (crystal false) or the crystals on them (true): lit by the scene, bobbing together.
static func drift_material(edge_color: Color, crystal: bool) -> ShaderMaterial:
	var m := _shader(DRIFT_SHADER)
	m.set_shader_parameter("drift", DRIFT_M)
	m.set_shader_parameter("speed", DRIFT_SPEED)
	m.set_shader_parameter("motion", _motion())
	if crystal:
		m.set_shader_parameter("albedo", CodeProps.STAR_CRYSTAL)
		m.set_shader_parameter("glow", CodeProps.STAR_GLOW)
		m.set_shader_parameter("glow_energy", 0.9)
		m.set_shader_parameter("rough", 0.15)
		m.set_shader_parameter("spec", 0.8)
		m.set_shader_parameter("metal", ShardMesh.CRYSTAL_METALLIC)  # v0.8.0 GX: the glint
	else:
		m.set_shader_parameter("albedo", ROCK.lerp(edge_color, 0.3))
	return m


## v0.8.0 MI: an owner's void piece (KitModels role &"void": a floating island, a hanging spike) in the frame the
## code-made ones use (unit footprint, its top at y = 0 and its bottom at y = -1), with its material: for an island
## the drifting shader on its colour map (`drift` true), else its own textured material. {} when the model is
## missing (the code-made piece stays; L15).
static func model_piece(id: StringName, drift: bool) -> Dictionary:
	var piece := KitModels.get_piece(id) if id != &"" else {}
	if piece.is_empty():
		return {}
	var arrays := (piece["mesh"] as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in verts.size():
		verts[k].y -= 1.0
	arrays[Mesh.ARRAY_VERTEX] = verts
	for slot in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
		arrays[slot] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var src: StandardMaterial3D = piece["material"]
	var mat: Material
	if drift:
		var sm := _shader(DRIFT_SHADER)
		sm.set_shader_parameter("drift", DRIFT_M)
		sm.set_shader_parameter("speed", DRIFT_SPEED)
		sm.set_shader_parameter("motion", _motion())
		sm.set_shader_parameter("use_tex", 1.0)
		if src != null and src.albedo_texture != null:
			sm.set_shader_parameter("tex", src.albedo_texture)
		mat = sm
	else:
		mat = src.duplicate() if src != null else StandardMaterial3D.new()
	return {"mesh": mesh, "material": mat}


static func _shader(code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = code
	return m


static func _motion() -> float:
	return 0.0 if ViewPrefs.reduced_motion else 1.0


## Spikes along every open stretch of the floor's rim (an edge point whose outside is not another ground rect),
## hanging from the rock's foot.
static func spike_xforms(ground: Array, rng: RandomNumberGenerator) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for r: Rect2 in ground:
		var g := r.grow(ROCK_LIP)
		var c := g.get_center()
		var corners := [
			g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)
		]
		for side in 4:
			var a: Vector2 = corners[side]
			var b: Vector2 = corners[(side + 1) % 4]
			var n := maxi(1, int(a.distance_to(b) / SPIKE_STEP))
			for k in n:
				var p := a.lerp(b, (k + rng.randf_range(0.2, 0.8)) / n)
				var radius := rng.randf_range(SPIKE_RADIUS.x, SPIKE_RADIUS.y)
				var length := rng.randf_range(SPIKE_LENGTH.x, SPIKE_LENGTH.y)
				var yaw := rng.randf() * TAU
				var outside := p + (p - c).normalized() * 0.4
				if _in_any(outside, ground, 0.0):
					continue
				var inward := p.lerp(c, minf(radius * 0.6 / maxf(p.distance_to(c), 0.001), 0.5))
				var basis := (
					Basis(Vector3.UP, yaw)
					* Basis.from_scale(Vector3(radius * 2.0, length, radius * 2.0))
				)
				out.append(Transform3D(basis, SimPlane.to_3d(inward, ROCK_FOOT + 0.05)))
	return out


## [stars' transforms, their colours]: scattered over the void around the floor (none hidden under it).
static func star_xforms(ground: Array, bounds: Rect2, rng: RandomNumberGenerator) -> Array:
	var xf: Array[Transform3D] = []
	var colors: Array[Color] = []
	var area := bounds.grow(STAR_REACH)
	var total := 0
	for c: Array in STAR_COLORS:
		total += int(c[1])
	for k in int(area.get_area() * STAR_DENSITY):
		var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		var y := rng.randf_range(STAR_Y.x, STAR_Y.y)
		var big := rng.randf() < STAR_BIG_SHARE
		var s := (
			rng.randf_range(STAR_BIG.x, STAR_BIG.y)
			if big
			else rng.randf_range(STAR_SIZE.x, STAR_SIZE.y)
		)
		var pick := rng.randi_range(0, total - 1)
		var yaw := rng.randf() * TAU
		if _in_any(p, ground, 0.5):
			continue
		var color: Color = STAR_COLORS[0][0]
		for c: Array in STAR_COLORS:
			pick -= int(c[1])
			if pick < 0:
				color = c[0]
				break
		xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), SimPlane.to_3d(p, y)))
		colors.append(color)
	return [xf, colors]


## The nebula clouds: [{"at": Vector3, "size": float, "color": Color, "seed": float}], deepest of all.
static func nebula_clouds(bounds: Rect2, rng: RandomNumberGenerator) -> Array:
	var out := []
	var n := clampi(int(bounds.get_area() / NEBULA_AREA), NEBULA_MIN, NEBULA_MAX)
	var area := bounds.grow(NEBULA_REACH)
	for k in n:
		var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		(
			out
			. append(
				{
					"at": SimPlane.to_3d(p, NEBULA_Y - k * 0.05),
					"size": rng.randf_range(NEBULA_SIZE.x, NEBULA_SIZE.y),
					"color": NEBULA_COLORS[k % NEBULA_COLORS.size()],
					"seed": rng.randf() * 100.0,
				}
			)
		)
	return out


## [islands' transforms, crystals' transforms]: small floating rocks around the floor, clear of its edge.
static func island_xforms(ground: Array, bounds: Rect2, rng: RandomNumberGenerator) -> Array:
	var isles: Array[Transform3D] = []
	var gems: Array[Transform3D] = []
	var area := bounds.grow(ISLAND_REACH)
	for k in int(area.get_area() * ISLAND_DENSITY):
		var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		var r := rng.randf_range(ISLAND_RADIUS.x, ISLAND_RADIUS.y)
		var depth := r * rng.randf_range(0.9, 1.6)
		var y := rng.randf_range(ISLAND_Y.x, ISLAND_Y.y)
		var yaw := rng.randf() * TAU
		var gem := rng.randf() < CRYSTAL_SHARE
		# A crystal's tip stays under the ground's level even at the top of its bob (nothing rises beside the floor).
		var gem_h := minf(r * rng.randf_range(0.9, 1.7), -y - DRIFT_M - GEM_CLEAR)
		if _in_any(p, ground, r + ISLAND_KEEP):
			continue
		var at := SimPlane.to_3d(p, y)
		isles.append(
			Transform3D(
				Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(r * 2.0, depth, r * 2.0)), at
			)
		)
		if gem and gem_h >= GEM_MIN:
			gems.append(
				Transform3D(
					Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(r * 0.9, gem_h, r * 0.9)), at
				)
			)
	return [isles, gems]


static func _in_any(p: Vector2, ground: Array, d: float) -> bool:
	for r: Rect2 in ground:
		if r.grow(d).has_point(p):
			return true
	return false


## A star: a camera-facing quad for the owner's motes (SPRITE_SCALE across, the shader turns it), or without them a
## tiny octahedron (unit size).
static func star_mesh() -> ArrayMesh:
	if motes() != null:
		return _sprite_quad(SPRITE_SCALE)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, 0.5, 0)
	var low := Vector3(0, -0.5, 0)
	var ring := [Vector3(0.5, 0, 0), Vector3(0, 0, 0.5), Vector3(-0.5, 0, 0), Vector3(0, 0, -0.5)]
	for k in 4:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % 4]
		_facet(st, top, a, b, Vector3.ZERO)
		_facet(st, low, b, a, Vector3.ZERO)
	return st.commit()


static func _sprite_quad(w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := w * 0.5
	var corners := [Vector3(-h, h, 0), Vector3(h, h, 0), Vector3(h, -h, 0), Vector3(-h, -h, 0)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.BACK)
		st.set_uv(uvs[k])
		st.add_vertex(corners[k])
	return st.commit()


## A hanging spike: a jittered five-sided ring at y = 0 (unit diameter) to a point at y = -1, flat facets.
static func spike_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [0.5, 0.4, 0.47, 0.36, 0.44]
	var ring: Array[Vector3] = []
	for k in 5:
		var a := TAU * k / 5.0
		ring.append(Vector3(cos(a) * radii[k], 0.0, sin(a) * radii[k]))
	var tip := Vector3(0.06, -1.0, -0.04)
	var inside := Vector3(0.0, -0.3, 0.0)
	for k in 5:
		_facet(st, ring[k], ring[(k + 1) % 5], tip, inside)
	return st.commit()


## A floating island: a flat jittered seven-sided top at y = 0 (unit diameter), a shoulder ring, and a point at
## y = -1 underneath, flat facets.
static func island_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [0.5, 0.43, 0.48, 0.4, 0.5, 0.42, 0.46]
	var top: Array[Vector3] = []
	var mid: Array[Vector3] = []
	for k in 7:
		var a := TAU * k / 7.0
		top.append(Vector3(cos(a) * radii[k], 0.0, sin(a) * radii[k]))
		mid.append(
			Vector3(
				cos(a + 0.25) * radii[k] * 0.7,
				-0.35 - 0.06 * (k % 2),
				sin(a + 0.25) * radii[k] * 0.7
			)
		)
	var tip := Vector3(0.05, -1.0, 0.03)
	var inside := Vector3(0.0, -0.3, 0.0)
	for k in 7:
		var k2 := (k + 1) % 7
		_facet(st, Vector3.ZERO, top[k], top[k2], inside)
		_facet(st, top[k], mid[k], top[k2], inside)
		_facet(st, top[k2], mid[k], mid[k2], inside)
		_facet(st, mid[k], tip, mid[k2], inside)
	return st.commit()


## One flat facet, its normal pointing away from `inside`, wound clockwise seen from outside (Godot's front face).
static func _facet(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - inside) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	for p: Vector3 in [a, b, c]:
		st.set_normal((-n).normalized())
		st.add_vertex(p)
