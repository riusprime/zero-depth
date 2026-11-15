class_name LensLooks
extends RefCounted
## What the Hive Lens's drone and Lattice views share: their colours, heights, the burnt glass's floor shader, the
## plain rod a beam falls back to when the pack has no room, and the placing of a pack beam at an exact width. Looks
## only (EI-07).

## The Lens's own light (its Gaze's pink) for the strands, the shield layers and the hits a strand lands.
const LENS := Color(1.0, 0.22, 0.52)
const LENS_CORE := Color(1.0, 0.8, 0.9)
## The Focus Beam's light (BossStrikeLooks' LIGHT glow): a drone it cuts bursts in it, and one on its lane glows in it.
const BEAM := Color(1.0, 0.86, 0.5)
## Heights (m): where a strand runs (about the hero's waist, so its footprint reads on the floor under it), the
## drones' and the Lens's bodies (LensDroneAvatar.HOVER_Y, HiveLensAvatar.HOVER_Y) where a thread joins them.
const STRAND_Y := 0.8
const DRONE_Y := 1.3
const LENS_Y := 1.75
## Sorts under the telegraphs and the bodies.
const UNDER := -2

const STRAND_COLORS := {
	&"primary": Color(1.0, 0.75, 0.88),
	&"secondary": Color(1.0, 0.22, 0.52),
	&"tertiary": Color(0.55, 0.06, 0.24)
}
## A feeding thread: the strand's beam in a dim rose, so it reads as a quiet link, far fainter than a strand.
const THREAD_COLORS := {
	&"primary": Color(0.24, 0.08, 0.15),
	&"secondary": Color(0.2, 0.05, 0.12),
	&"tertiary": Color(0.1, 0.02, 0.06)
}
const LAYER_COLORS := {
	&"primary": Color(1.0, 0.55, 0.78),
	&"secondary": Color(1.0, 0.29, 0.66),
	&"tertiary": Color(0.5, 0.08, 0.3)
}
const BEAM_COLORS := {
	&"primary": Color(1.0, 0.95, 0.75),
	&"secondary": Color(1.0, 0.86, 0.5),
	&"tertiary": Color(0.7, 0.42, 0.1)
}
const GLOW_COLORS := {
	&"primary": Color(1.0, 0.75, 0.9),
	&"secondary": Color(1.0, 0.3, 0.6),
	&"tertiary": Color(0.5, 0.08, 0.28)
}
const ORBIT_COLORS := {
	&"primary": Color(0.6, 0.22, 0.4),
	&"secondary": Color(0.45, 0.1, 0.28),
	&"tertiary": Color(0.2, 0.04, 0.12)
}
const SMOKE_COLORS := {
	&"primary": Color(0.85, 0.78, 0.82),
	&"secondary": Color(0.55, 0.46, 0.52),
	&"tertiary": Color(0.3, 0.24, 0.28)
}

## A strip of burnt glass on a plane 1 m square scaled to its rectangle: dark, cracked glass over a hot rose glow in
## its cracks and along its edge; `heat` (1 just laid, lower as it cools) brightens the cracks and the glow and adds a
## slow shimmer (none with `still`); it never cools so far that it stops reading as dangerous while it lies.
const GLASS_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 glass : source_color = vec4(0.1, 0.05, 0.09, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.3, 0.55, 1.0);
uniform vec4 white : source_color = vec4(1.0, 0.85, 0.92, 1.0);
uniform vec2 size_m = vec2(8.0, 1.0);
uniform float heat = 1.0;
uniform float clock = 0.0;
uniform float seed = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 p = (UV - 0.5) * size_m;
	float n = texture(noise_tex, p * 0.35 + vec2(seed, seed * 0.6)).r;
	float n2 = texture(noise_tex, p * 0.9 - vec2(seed * 0.4, seed)).r;
	float cracks = smoothstep(0.07, 0.0, abs(n2 - 0.5)) + smoothstep(0.05, 0.0, abs(n - 0.48)) * 0.7;
	vec2 e = min(UV, 1.0 - UV) * size_m;
	float edge_d = min(e.x, e.y);
	float edge = smoothstep(0.25, 0.0, edge_d);
	float shimmer = 0.85 + 0.15 * sin(clock * 3.0 + p.x * 1.7);
	vec3 col = glass.rgb * (0.8 + 0.5 * n) + hot.rgb * heat * (0.28 + 0.22 * n2) * shimmer;
	col = mix(col, hot.rgb * (0.9 + 0.8 * heat) * shimmer, clamp(cracks * (0.5 + 0.5 * heat), 0.0, 1.0));
	col = mix(col, mix(hot.rgb, white.rgb, heat * 0.5), edge * (0.55 + 0.45 * heat));
	float body = 0.62 + 0.25 * heat;
	ALBEDO = col;
	ALPHA = clamp(max(body, edge * 0.95), 0.0, 0.92) * smoothstep(0.0, 0.06, edge_d);
}
"""

static var _shaders := {}
static var _rod_mesh: CylinderMesh = null


static func shader(code: String) -> Shader:
	if not _shaders.has(code.hash()):
		var s := Shader.new()
		s.code = code
		_shaders[code.hash()] = s
	return _shaders[code.hash()]


## A hidden strip of burnt glass under `parent`, on its own material.
static func glass_mesh(parent: Node3D) -> MeshInstance3D:
	var m := ShaderMaterial.new()
	m.shader = shader(GLASS_SHADER)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	m.render_priority = UNDER
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


## Lays a 1 m plane on the floor over the rectangle from `a` to `b` (sim points), `half_width` each side.
static func lay_strip(
	mi: MeshInstance3D, a: Vector2, b: Vector2, half_width: float, y: float
) -> void:
	var a3 := SimPlane.to_3d(a, y)
	var b3 := SimPlane.to_3d(b, y)
	var along := b3 - a3
	var len := maxf(along.length(), 0.01)
	var x := along / len
	var z := x.cross(Vector3.UP).normalized()
	mi.transform = Transform3D(Basis(x * len, Vector3.UP, z * half_width * 2.0), (a3 + b3) * 0.5)


## A hidden plain rod (a unit cylinder, its axis +Y) in `c`, glowing: a beam's look when the pack had no room for it.
static func rod(parent: Node3D, c: Color) -> MeshInstance3D:
	if _rod_mesh == null:
		_rod_mesh = CylinderMesh.new()
		_rod_mesh.top_radius = 1.0
		_rod_mesh.bottom_radius = 1.0
		_rod_mesh.height = 1.0
		_rod_mesh.radial_segments = 8
		_rod_mesh.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	var mi := MeshInstance3D.new()
	mi.mesh = _rod_mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


## Puts a unit rod from `a` to `b` with radius `r`.
static func place_rod(mi: MeshInstance3D, a: Vector3, b: Vector3, r: float) -> void:
	var y := b - a
	var len := maxf(y.length(), 0.001)
	var yn := y / len
	var side := Vector3.UP if absf(yn.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := yn.cross(side).normalized()
	var z := x.cross(yn).normalized()
	mi.transform = Transform3D(Basis(x * r, yn * len, z * r), (a + b) * 0.5)


## Puts a held pack beam from `a` to `b` so it draws `half_width` each side of its line, as the Gaze's and the Focus
## Beams' pack beams do (BossPackHold.beam_place: the scene drawn BEAM_FACTOR / BEAM_NATIVE_R across per metre of half
## width), but without its floor on the scale, so a thread can be thinner than any attack's beam.
static func place_beam(node: Node3D, a: Vector3, b: Vector3, half_width: float) -> void:
	var d := b - a
	if d.length() < 0.05:  # a thread that has snapped all the way in has no direction left
		d = Vector3(0, 0, -0.05)
	var len := d.length()
	var dn := d / len
	var up := Vector3.UP if absf(dn.y) < 0.98 else Vector3.RIGHT
	var w := clampf(half_width * BossPackHold.BEAM_FACTOR / BossPackHold.BEAM_NATIVE_R, 0.05, 6.0)
	var xf := Transform3D(Basis.looking_at(dn, up) * Basis.from_scale(Vector3(w, w, 1.0)), a)
	if node.is_inside_tree():
		node.global_transform = xf
	else:
		node.transform = xf
	node.set("beam_length", len)


## The half width a pack beam placed by place_beam draws (its scale across, in the same terms).
static func beam_radius(node: Node3D) -> float:
	var xf := node.global_transform if node.is_inside_tree() else node.transform
	return xf.basis.x.length() * BossPackHold.BEAM_NATIVE_R / BossPackHold.BEAM_FACTOR


## Whether a body at `p` of radius `r` touches the lane `o` (an Obb: centre, half extents, axes).
static func on_lane(p: Vector2, r: float, o: Obb) -> bool:
	var d := p - o.center
	return absf(d.dot(o.axis_u)) <= o.half.x + r and absf(d.dot(o.axis_v)) <= o.half.y + r
