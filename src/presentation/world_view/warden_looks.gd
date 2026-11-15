class_name WardenLooks
extends RefCounted
## What the Twin Wardens' views share: their colours, the shaders of the floor (a danger circle, a lane strip) and of
## the Mirror Ward's curved wall, that wall's mesh, and the pack forcefield's material that the held domes wear
## (PD-13: the pack's own effect, recoloured per body on a copy, never the vendor files). Looks only (EI-07).

const AMBER := Color("#FFB347")
const VIOLET := Color("#B98CFF")
## The burst's circle: a hot red-orange, far from the hero's cyan, so the end of the lane reads as "do not stand".
const DANGER := Color("#FF4A24")
const SHADOW := Color("#1E0A33")
## The sim's angles are 1/4096 turns.
const TURN := 4096.0
## The pack's forcefield scenes whose material the domes take a copy of, by look (each held dome wears its own copy,
## so two domes never share colours, whichever scene they come from).
## The domes' rim light (the scenes ship 0 to 0.2): a clear edge that shows on every floor.
const FIELD_FRESNEL := 0.35
const FIELD_SCENES := {
	&"amber": "res://assets/BinbunVFX/fire_effects/effects/Fire/fire_forcefield_01.tscn",
	&"violet": "res://assets/BinbunVFX/fire_effects/effects/Fire/fire_forcefield_04.tscn",
	&"full": "res://assets/BinbunVFX/fire_effects/effects/Fire/fire_forcefield_04.tscn",
}

## A floor circle of radius 1 (the node's scale is the radius in metres): a bright edge ring, a hatched fill, an
## inner fill that grows with `fill` (an armed burst counting down), dull while `locked` is 0 and flashing once it is 1.
const DISC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.29, 0.14, 1.0);
uniform float alpha = 1.0;
uniform float locked = 0.0;
uniform float flash = 0.0;
uniform float fill = 0.0;
uniform float share = 1.0;
uniform float clock = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float turn = fract(atan(q.x, -q.y) / 6.2831853 + 1.0);
	float edge = smoothstep(0.1, 0.0, abs(r - 0.94)) * step(turn, share);
	float inner = smoothstep(0.06, 0.0, abs(r - 0.78)) * 0.35;
	float hatch = step(0.62, fract((q.x + q.y) * 4.0 + clock * 0.6)) * 0.22;
	float grow = step(r, fill) * 0.45;
	float pulse = 0.75 + 0.25 * sin(clock * (6.0 + 8.0 * locked));
	float lit = edge * (0.55 + 0.45 * locked) * pulse + inner + flash * 0.6;
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.95, 0.85), clamp(flash + 0.4 * edge * locked, 0.0, 1.0)) * (1.0 + lit);
	float body = (hatch * (0.4 + 0.6 * locked) + grow + 0.06) * step(r, 0.96);
	ALPHA = clamp(alpha * (lit + body), 0.0, 0.95) * step(r, 1.0);
}
"""
## A lane on the floor (a unit plane along +X, scaled to the lane): a glowing core, chevrons running out along it.
const STRIP_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform float alpha = 0.0;
uniform float glow = 1.0;
uniform float length_m = 10.0;
uniform float clock = 0.0;

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float body = 1.0 - smoothstep(0.6, 1.0, across);
	float core = 1.0 - smoothstep(0.0, 0.22, across);
	float chev = smoothstep(0.7, 0.95, fract(UV.x * length_m * 0.5 - clock * 2.2 - across * 0.6));
	float fade = smoothstep(0.0, 0.04, UV.x) * (1.0 - smoothstep(0.94, 1.0, UV.x));
	ALBEDO = tint.rgb * (0.8 + glow * (1.2 * core + chev));
	ALPHA = clamp(alpha * fade * (body * 0.2 + core * 0.5 * glow + chev * body * 0.4), 0.0, 1.0);
}
"""

## The Mirror Ward's wall (the arc mesh: u along the arc, v 0 at the top and 1 at the foot): a sheet of violet light,
## brightest at its foot, its top edge and its two ends, bands of light climbing it, a hexagon lattice over it.
const ARC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.73, 0.55, 1.0, 1.0);
uniform float alpha = 1.0;
uniform float arc_m = 5.0;
uniform float clock = 0.0;

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float foot = smoothstep(0.2, 1.0, v);
	float top = smoothstep(0.06, 0.0, v);
	float ends = smoothstep(0.04, 0.0, min(u, 1.0 - u));
	float bands = smoothstep(0.75, 1.0, fract(v * 4.0 + clock * 0.8));
	vec2 p = vec2(u * arc_m, v * 2.6) * 3.0;
	vec2 h = abs(fract(vec2(p.x + 0.5 * floor(p.y), p.y)) - 0.5);
	float hex = smoothstep(0.42, 0.5, max(h.x * 1.15, h.y));
	float lit = 0.12 + 0.35 * foot + 0.25 * bands + 0.25 * hex + 0.9 * top + 0.8 * ends;
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.95, 1.0), clamp(top + ends * 0.6, 0.0, 1.0)) * (1.0 + lit);
	ALPHA = clamp(alpha * lit, 0.0, 0.9);
}
"""

static var _disc: Shader
static var _strip: Shader
static var _plane: PlaneMesh
static var _fields := {}
static var _arcs := {}


## A sim angle (1/4096 turns) as a direction on the sim plane.
static func dir_of(angle: int) -> Vector2:
	return Vector2.from_angle(TAU * float(angle) / TURN)


## A unit plane on the floor (1 m a side; the node's scale sizes it).
static func plane() -> PlaneMesh:
	if _plane == null:
		_plane = PlaneMesh.new()
		_plane.size = Vector2.ONE
	return _plane


## A hidden floor mesh under `parent` wearing its own copy of `code`'s shader.
static func floor_mesh(parent: Node3D, disc: bool, tint: Color) -> MeshInstance3D:
	if _disc == null:
		_disc = Shader.new()
		_disc.code = DISC_SHADER
		_strip = Shader.new()
		_strip.code = STRIP_SHADER
	var m := ShaderMaterial.new()
	m.shader = _disc if disc else _strip
	m.set_shader_parameter("tint", tint)
	m.render_priority = -1
	var mi := MeshInstance3D.new()
	mi.mesh = plane()
	if disc:
		mi.mesh = PlaneMesh.new()
		(mi.mesh as PlaneMesh).size = Vector2.ONE * 2.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


static func param(mi: MeshInstance3D, key: StringName, value: Variant) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter(key, value)


## Lays strip `mi` along `from` → `to` (sim plane), `width` metres across, at `height`.
static func lay_strip(
	mi: MeshInstance3D, from: Vector2, to: Vector2, width: float, height: float
) -> void:
	var a := SimPlane.to_3d(from, height)
	var b := SimPlane.to_3d(to, height)
	var length := a.distance_to(b)
	var along := (b - a) / length if length > 0.0001 else Vector3.RIGHT
	var side := along.cross(Vector3.UP)
	mi.transform = Transform3D(
		Basis(along * maxf(length, 0.05), Vector3.UP, side * width), (a + b) * 0.5
	)
	param(mi, &"length_m", length)


## The pack forcefield's material (a copy) in `main` / `edge` / `glow`, for the scene of `which` (one per colour, so
## two domes never share their colours); null without the pack.
static func field_material(
	which: StringName, main: Color, edge: Color, glow: Color
) -> ShaderMaterial:
	var key := "%s:%s:%s" % [which, main.to_html(), glow.to_html()]
	if _fields.has(key):
		return _fields[key]
	var scene := (
		load(FIELD_SCENES[which]) as PackedScene
		if ResourceLoader.exists(FIELD_SCENES[which])
		else null
	)
	if scene == null:
		return null
	var n := scene.instantiate() as Node3D
	var mi := n.get_node_or_null("FieldMesh") as MeshInstance3D
	var src: ShaderMaterial = null
	if mi != null and mi.mesh != null:
		src = mi.mesh.surface_get_material(0) as ShaderMaterial
	n.free()
	if src == null:
		return null
	var m := src.duplicate() as ShaderMaterial
	m.set_shader_parameter(&"main_color", main)
	m.set_shader_parameter(&"edge_color", edge)
	m.set_shader_parameter(&"glow_color", glow)
	m.set_shader_parameter(&"fresnel_multiplier", FIELD_FRESNEL)
	_fields[key] = m
	return m


## Puts `m` on every mesh of a held pack forcefield (once per node: its own copy, not the scene's shared one).
static func wear(node: Node3D, m: ShaderMaterial, tag: StringName) -> void:
	if node == null or m == null or node.get_meta(&"tw_wear", &"") == tag:
		return
	node.set_meta(&"tw_wear", tag)
	for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m


## A curved wall `half_arc` (1/4096 turns) each side of +X, `radius` m out from the centre, `height` m tall, its UV
## u along the arc and v 0 at the top, 1 at the foot.
static func arc_wall(half_arc: int, radius: float, height: float) -> ArrayMesh:
	var key := "%d:%.2f:%.2f" % [half_arc, radius, height]
	if _arcs.has(key):
		return _arcs[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 28
	var half := TAU * float(half_arc) / TURN
	for k in segs:
		var a0 := -half + 2.0 * half * float(k) / segs
		var a1 := -half + 2.0 * half * float(k + 1) / segs
		var u0 := float(k) / segs
		var u1 := float(k + 1) / segs
		var p0 := Vector3(cos(a0), 0.0, -sin(a0)) * radius
		var p1 := Vector3(cos(a1), 0.0, -sin(a1)) * radius
		var up := Vector3(0.0, height, 0.0)
		var quad := [
			[p0, Vector2(u0, 1.0)],
			[p1, Vector2(u1, 1.0)],
			[p1 + up, Vector2(u1, 0.0)],
			[p0, Vector2(u0, 1.0)],
			[p1 + up, Vector2(u1, 0.0)],
			[p0 + up, Vector2(u0, 0.0)],
		]
		for v: Array in quad:
			st.set_normal(((v[0] as Vector3) * Vector3(1, 0, 1)).normalized())
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var mesh := st.commit()
	_arcs[key] = mesh
	return mesh


## A material on the Mirror Ward's curved wall (ARC_SHADER) in `c`.
static func arc_material(c: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = ARC_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", c)
	return m


## Transform: `scale` uniform at `pos`.
static func at(pos: Vector3, scale: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * scale), pos)
