class_name WardenLooks
extends RefCounted
## What the Twin Wardens' views share: their colours, the shaders of the floor (a danger circle, a lane strip), the
## Mirror Ward's curved wall of glass slabs (its mesh and material), and the pack forcefield's material that the held
## domes wear (PD-13: the pack's own effect, recoloured per body on a copy, never the vendor files). Looks only (EI-07).

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

## The Mirror Ward's wall: slabs of violet glass standing side by side on its arc, each a little different in height,
## its top cut at a slant, so the wall reads as faceted crystal; matte and lit by the room like the Wardens (no glow
## sheet, no grid), a faint violet glow its only light, a little see-through so the Warden behind it still shows.
const SLAB := Color("#7A55C4")
const SLAB_GLOW := 0.25
const SLAB_ALPHA := 0.88
## A slab's width along the arc (m, about), its thickness and the gap between two.
const SLAB_W := 0.62
const SLAB_T := 0.16
const SLAB_GAP := 0.07

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


## A curved wall of glass slabs `half_arc` (1/4096 turns) each side of +X, `radius` m out from the centre, at most
## `height` m tall: flat-shaded, each slab its own height and slanted top (the same for the same arc, built once).
static func arc_wall(half_arc: int, radius: float, height: float) -> ArrayMesh:
	var key := "%d:%.2f:%.2f" % [half_arc, radius, height]
	if _arcs.has(key):
		return _arcs[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # flat: every face its own normal
	var half := TAU * float(half_arc) / TURN
	var n := maxi(3, roundi(2.0 * half * radius / SLAB_W))
	var gap := SLAB_GAP / radius
	for k in n:
		var a0 := -half + 2.0 * half * float(k) / n + gap * 0.5
		var a1 := -half + 2.0 * half * float(k + 1) / n - gap * 0.5
		var h := height * lerpf(0.78, 1.0, _hash(k, 1))
		var slant := height * lerpf(-0.12, 0.12, _hash(k, 2))
		var lean := lerpf(-0.06, 0.1, _hash(k, 3))  # its top tipped a little in or out
		_slab(st, a0, a1, radius, h, slant, lean)
	st.generate_normals()
	var mesh := st.commit()
	_arcs[key] = mesh
	return mesh


## One slab from angle `a0` to `a1`, `h` tall at its middle, its top `slant` higher at a1's end than a0's.
static func _slab(
	st: SurfaceTool, a0: float, a1: float, r: float, h: float, slant: float, lean: float
) -> void:
	var ri := r - SLAB_T * 0.5
	var ro := r + SLAB_T * 0.5
	var d0 := Vector3(cos(a0), 0.0, -sin(a0))
	var d1 := Vector3(cos(a1), 0.0, -sin(a1))
	var h0 := h - slant * 0.5
	var h1 := h + slant * 0.5
	# Bottom (b) and top (t) corners: inner/outer at each end; the top moved out by `lean`.
	var bi0 := d0 * ri
	var bo0 := d0 * ro
	var bi1 := d1 * ri
	var bo1 := d1 * ro
	var ti0 := d0 * (ri + lean) + Vector3(0, h0 - 0.06, 0)
	var to0 := d0 * (ro + lean) + Vector3(0, h0, 0)
	var ti1 := d1 * (ri + lean) + Vector3(0, h1 - 0.06, 0)
	var to1 := d1 * (ro + lean) + Vector3(0, h1, 0)
	for q: Array in [
		[bo0, bo1, to1, to0],  # outer face
		[bi1, bi0, ti0, ti1],  # inner face
		[bi0, bo0, to0, ti0],  # the a0 end
		[bo1, bi1, ti1, to1],  # the a1 end
		[to0, to1, ti1, ti0],  # the slanted top
	]:
		for v: Vector3 in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			st.add_vertex(v)


static func _hash(k: int, salt: int) -> float:
	return VfxCore.h(k * 97 + 13, salt)


## The Mirror Ward's slabs' material: matte violet glass lit by the room, a faint glow, a little see-through.
static func arc_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(SLAB, SLAB_ALPHA)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.roughness = 1.0
	m.metallic = 0.0
	m.metallic_specular = 0.5
	m.emission_enabled = true
	m.emission = SLAB
	m.emission_energy_multiplier = SLAB_GLOW
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Transform: `scale` uniform at `pos`.
static func at(pos: Vector3, scale: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * scale), pos)
