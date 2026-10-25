class_name BiomeEdge
extends Node3D
## v0.7.5 NB1: what lies beyond a floor's edge, by BiomeLook.edge. One builder per style, so the next biome adds its
## own (NB2's cosmic biome: a star field) beside these without touching the others:
## - &"water" (Frozen Shore): a dark frozen sea under the void, the floor standing on a snow bank whose lip shows at
##   every edge, and white ice floes drifting on the water (cosmetic stream). The sea shimmers slowly (frame time;
##   still with reduced motion).
## - &"stars" (v0.7.5 NB2, Starfall): a starry void. The floor is a floating island (dark star stone under every
##   ground rect, faceted spikes hanging from its rim), twinkling stars and soft nebula light (violet, teal, magenta)
##   far below, and small rock and crystal islands drifting in the void around it (cosmetic stream; the twinkle and
##   the drift are frame time, still with reduced motion). Its meshes and shaders are in StarVoid.
## The void stays impassable in the sim (the floor's outer walls); this is only what you see there. No collision.
## Presentation only.

## - v0.8.0 MI &"islands" (Night Rocks, owner O78: "the moss island goes in Night Rocks"): the mood's own void, with
##   the biome's floating islands (BiomeLook pool void_island: the owner's moss island) drifting below the floor's
##   level around it, as Starfall's do; nothing else.
## v0.8.0 MI: `pieces` names the owner's void models a style draws ({&"void_island": id, &"void_spike": id}; Starfall:
## floating_island_starfall and void_spike); a missing one keeps the code-made piece. An island model carries its own
## crystals, so the code-made crystal clusters are left off with it.
const STYLES: Array[StringName] = [&"water", &"stars", &"islands"]
## v0.9.5 BG: the starry void's own nebula clouds are off now that bg_starfall_deep carries the nebulae (true puts
## them back; they are still drawn from the rng, so the islands keep their places).
const NEBULA_CLOUDS := false
## The sea's surface below the ground, the snow bank's foot, and how far the sea reaches past the floor (m).
const WATER_Y := -0.45
const BANK_FOOT := -0.6
const BANK_LIP := 0.14
const SEA_MARGIN := 150.0
## Floes: how many per square metre of open water near the floor, how far out they float, their sizes (m).
const FLOE_DENSITY := 0.05
const FLOE_REACH := 9.0
const FLOE_MIN := 0.5
const FLOE_MAX := 2.2
const FLOE_KEEP := 0.7
const SNOW := Color("#DCE6F2")
const FLOE := Color("#EEF5FC")

const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 deep : source_color = vec4(0.08, 0.16, 0.26, 1.0);
uniform vec4 shallow : source_color = vec4(0.16, 0.3, 0.42, 1.0);
uniform float motion = 1.0;
// v0.9.5 BG: the biome's Deep image under the shimmer (BiomeBackdrop sets these; bd_mix 0 = the old sea).
uniform sampler2D bd_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform vec2 bd_focus = vec2(0.0);
uniform float bd_tile = 42.0;
uniform float bd_parallax = 0.35;
uniform vec2 bd_drift = vec2(0.0);
uniform float bd_bright = 0.85;
uniform float bd_mix = 0.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Low-poly ripples: a few slow crossing waves bend the normal, quantised into facets, so the moon glints in
	// patches instead of one smooth highlight.
	float t = TIME * 0.35 * motion;
	vec2 p = floor(world.xz * 1.5) / 1.5;
	float a = sin(p.x * 0.9 + t) + sin(p.y * 1.3 - t * 0.8) + sin((p.x + p.y) * 0.6 + t * 0.5);
	float b = cos(p.x * 1.1 - t * 0.7) + cos(p.y * 0.8 + t * 0.6);
	vec3 n = normalize(vec3(a * 0.035, 1.0, b * 0.035));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 sea_col = mix(deep.rgb, shallow.rgb, clamp(0.5 + a * 0.12, 0.0, 1.0));
	vec2 bd_uv = (world.xz - bd_focus * (1.0 - bd_parallax)) / bd_tile + bd_drift * TIME;
	ALBEDO = mix(sea_col, texture(bd_tex, bd_uv).rgb * bd_bright, bd_mix);
	ROUGHNESS = 0.3;
	SPECULAR = 0.45;
}
"""

var style := &""
var floe_count := 0
var water: MeshInstance3D
var bank: MeshInstance3D
var floes: MultiMeshInstance3D
## v0.7.5 NB2 (&"stars"): the rock under the floor, its hanging spikes, the stars, the nebula clouds, the floating
## islands and the crystals on some of them, and their counts.
var underside: MeshInstance3D
var spikes: MultiMeshInstance3D
var stars: MultiMeshInstance3D
var nebula: Node3D
var islands: MultiMeshInstance3D
var crystals: MultiMeshInstance3D
var star_count := 0
var spike_count := 0
var island_count := 0
var crystal_count := 0
var nebula_count := 0


static func has_style(s: StringName) -> bool:
	return s in STYLES


## Builds the edge `p_style` around a floor whose ground covers `ground` (sim-plane rects) within `bounds`.
## `edge_color`: the biome palette's `edge` token. `seed_value`: the floor seed (the cosmetic stream's root).
func build(
	p_style: StringName,
	ground: Array,
	bounds: Rect2,
	edge_color: Color,
	seed_value: int,
	pieces: Dictionary = {}
) -> void:
	style = p_style
	if style == &"water":
		_build_water(ground, bounds, edge_color, seed_value)
	elif style == &"stars":
		_build_stars(ground, bounds, edge_color, seed_value, pieces)
	elif style == &"islands":
		_build_islands(ground, bounds, edge_color, seed_value, pieces)


## v0.8.0 MI: Night Rocks' void: only the drifting islands (the owner's moss island; the code-made rock without it).
func _build_islands(
	ground: Array, bounds: Rect2, edge_color: Color, seed_value: int, pieces: Dictionary
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 3301  # the cosmetic stream: presentation only
	var isles := StarVoid.island_xforms(ground, bounds, rng)
	island_count = isles[0].size()
	var model := StarVoid.model_piece(pieces.get(&"void_island", &""), true)
	if model.is_empty():
		islands = _multi(
			"Islands", StarVoid.island_mesh(), isles[0], StarVoid.drift_material(edge_color, false)
		)
	else:
		islands = _multi("Islands", model["mesh"], isles[0], model["material"])


## v0.7.5 NB2: Starfall's starry void (StarVoid's rules and meshes).
func _build_stars(
	ground: Array, bounds: Rect2, edge_color: Color, seed_value: int, pieces: Dictionary = {}
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 3301  # the cosmetic stream: presentation only
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r: Rect2 in ground:
		_box(st, r.grow(StarVoid.ROCK_LIP), StarVoid.ROCK_FOOT, -0.004)
	underside = MeshInstance3D.new()
	underside.name = "Underside"
	underside.mesh = st.commit()
	underside.material_override = StarVoid.rock_material(edge_color)
	underside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(underside)
	var hang := StarVoid.spike_xforms(ground, rng)
	spike_count = hang.size()
	var spike_model := StarVoid.model_piece(pieces.get(&"void_spike", &""), false)
	if spike_model.is_empty():
		spikes = _multi("Spikes", StarVoid.spike_mesh(), hang, StarVoid.rock_material(edge_color))
	else:
		spikes = _multi("Spikes", spike_model["mesh"], hang, spike_model["material"])
	var sky := StarVoid.star_xforms(ground, bounds, rng)
	star_count = sky[0].size()
	stars = _multi("Stars", StarVoid.star_mesh(), sky[0], StarVoid.star_material(), sky[1])
	nebula = Node3D.new()
	nebula.name = "Nebula"
	add_child(nebula)
	var clouds := StarVoid.nebula_clouds(bounds, rng)  # always drawn: the islands after it keep their places
	for cloud: Dictionary in clouds if NEBULA_CLOUDS else []:
		var mi := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2.ONE * float(cloud["size"])
		mi.mesh = q
		mi.position = cloud["at"]
		mi.material_override = StarVoid.nebula_material(cloud["color"], cloud["seed"])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nebula.add_child(mi)
	nebula_count = nebula.get_child_count()
	var isles := StarVoid.island_xforms(ground, bounds, rng)
	island_count = isles[0].size()
	var isle_model := StarVoid.model_piece(pieces.get(&"void_island", &""), true)
	if not isle_model.is_empty():
		islands = _multi("Islands", isle_model["mesh"], isles[0], isle_model["material"])
		return  # its crystals are part of the owner's island
	crystal_count = isles[1].size()
	islands = _multi(
		"Islands", StarVoid.island_mesh(), isles[0], StarVoid.drift_material(edge_color, false)
	)
	crystals = _multi(
		"Crystals",
		CodeProps.star_crystal_mesh(),
		isles[1],
		StarVoid.drift_material(edge_color, true)
	)


## A MultiMeshInstance3D of `mesh` at `xforms` (null when there are none), coloured per instance by `colors`.
func _multi(
	n: String, mesh: Mesh, xforms: Array, mat: Material, colors: Array = []
) -> MultiMeshInstance3D:
	if xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		if mm.use_colors:
			mm.set_instance_color(k, colors[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _build_water(ground: Array, bounds: Rect2, edge_color: Color, seed_value: int) -> void:
	# The sea.
	var plane := PlaneMesh.new()
	var sea := bounds.grow(SEA_MARGIN)
	plane.size = sea.size
	water = MeshInstance3D.new()
	water.name = "Sea"
	water.mesh = plane
	water.position = SimPlane.to_3d(sea.get_center(), WATER_Y)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = WATER_SHADER
	mat.set_shader_parameter("deep", edge_color.darkened(0.55))
	mat.set_shader_parameter("shallow", edge_color.darkened(0.25))
	mat.set_shader_parameter("motion", 0.0 if ViewPrefs.reduced_motion else 1.0)
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# The snow bank: one box per ground rect from under the sea up to just below the ground, its lip a little wider.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r: Rect2 in ground:
		_box(st, r.grow(BANK_LIP), BANK_FOOT, -0.004)
	bank = MeshInstance3D.new()
	bank.name = "SnowBank"
	bank.mesh = st.commit()
	var snow := StandardMaterial3D.new()
	snow.albedo_color = SNOW
	snow.roughness = 0.9
	bank.material_override = snow
	bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bank)
	_build_floes(ground, bounds, seed_value)


func _build_floes(ground: Array, bounds: Rect2, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 6173  # the cosmetic stream: presentation only
	var area := bounds.grow(FLOE_REACH)
	var tries := int(area.get_area() * FLOE_DENSITY)
	var xforms: Array[Transform3D] = []
	for k in tries:
		var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		var s := rng.randf_range(FLOE_MIN, FLOE_MAX)
		var yaw := rng.randf() * TAU
		var squash := rng.randf_range(0.6, 1.0)
		if _near_ground(p, s * 0.5 + FLOE_KEEP, ground):
			continue
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(s, 1.0, s * squash))
		xforms.append(Transform3D(basis, SimPlane.to_3d(p, WATER_Y)))
	floe_count = xforms.size()
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = floe_mesh()
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	floes = MultiMeshInstance3D.new()
	floes.name = "Floes"
	floes.multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_color = FLOE
	m.roughness = 0.5
	floes.material_override = m
	floes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floes)


static func _near_ground(p: Vector2, d: float, ground: Array) -> bool:
	for r: Rect2 in ground:
		if r.grow(d).has_point(p):
			return true
	return false


## A floe: a flat, slightly irregular hexagonal slab (unit diameter, 0.12 m thick, its top 0.06 m above the water).
static func floe_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [0.5, 0.42, 0.48, 0.38, 0.5, 0.44]
	var top: Array[Vector3] = []
	var low: Array[Vector3] = []
	for k in 6:
		var a := TAU * k / 6.0
		var r: float = radii[k]
		top.append(Vector3(cos(a) * r, 0.06, sin(a) * r))
		low.append(Vector3(cos(a) * r * 0.9, -0.06, sin(a) * r * 0.9))
	var centre := Vector3(0, 0.06, 0)
	for k in 6:
		var k2 := (k + 1) % 6
		_face(st, [centre, top[k2], top[k]], Vector3.UP)
		var side := ((top[k] + top[k2]) * 0.5 * Vector3(1, 0, 1)).normalized()
		_face(st, [top[k], top[k2], low[k2]], side)
		_face(st, [top[k], low[k2], low[k]], side)
	return st.commit()


## A box from y0 to y1 over the sim rect r (its top and four sides; the bottom is never seen).
static func _box(st: SurfaceTool, r: Rect2, y0: float, y1: float) -> void:
	var a := SimPlane.to_3d(r.position)
	var c := SimPlane.to_3d(r.end)
	var x0 := minf(a.x, c.x)
	var x1 := maxf(a.x, c.x)
	var z0 := minf(a.z, c.z)
	var z1 := maxf(a.z, c.z)
	var t := [Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)]
	var b := [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)]
	_face(st, [t[0], t[1], t[2]], Vector3.UP)
	_face(st, [t[0], t[2], t[3]], Vector3.UP)
	for side: Array in [
		[0, 1, Vector3(0, 0, -1)],
		[1, 2, Vector3(1, 0, 0)],
		[2, 3, Vector3(0, 0, 1)],
		[3, 0, Vector3(-1, 0, 0)]
	]:
		var i: int = side[0]
		var j: int = side[1]
		_face(st, [t[i], t[j], b[j]], side[2])
		_face(st, [t[i], b[j], b[i]], side[2])


## One triangle with a given outward normal, wound clockwise seen from that side (Godot's front face).
static func _face(st: SurfaceTool, tri: Array, n: Vector3) -> void:
	var a: Vector3 = tri[0]
	var b: Vector3 = tri[1]
	var c: Vector3 = tri[2]
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	for p: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)
