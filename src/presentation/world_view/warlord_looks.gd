class_name WarlordLooks
extends RefCounted
## What the Warlord's War Banner and Duel views share: their colours, the floor ring's shader (the banner's warm circle,
## the cage's danger rim), the code-made War Banner (a stand-in until the owner's model: a pole, a crossbar and a red
## cloth that waves and can burn from its hem up) and the pose of a javelin planted in the fence. Looks only (EI-07).

## The Warlord's red and steel (WarlordAvatar), its emblem's glow.
const RED := Color("#D23E35")
const RED_DARK := Color("#A9322B")
const STEEL := Color("#6A6462")
const EMBLEM := Color("#FF3A26")
## The banner's warmth: its circle, the glow it lends whoever fights in it.
const WARM := Color("#FFB04A")
const TRIM := Color("#E8B45A")
## The cage's danger rim.
const DANGER := Color("#FF4A24")
const EMBER := Color(1.0, 0.55, 0.15)
const DUST := {
	&"primary": Color(0.72, 0.64, 0.52),
	&"secondary": Color(0.72, 0.64, 0.52),
	&"tertiary": Color(0.72, 0.64, 0.52)
}
## The banner stand-in's measures (m): the pole's height, where the crossbar hangs, the cloth's size.
const POLE_H := 3.2
const BAR_Y := 2.95
const CLOTH := Vector2(1.1, 1.5)

## A floor circle of radius 1 (the node's scale is its radius in metres): a band of `edge` (a share of the radius) at
## its rim, at `edge_alpha`, and a faint wash inside at `fill_alpha`, a little brighter toward the rim; `pulse` 1
## breathes it slowly. Depth-tested, so the bodies on it stand over it.
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.69, 0.29, 1.0);
uniform float alpha = 1.0;
uniform float edge = 0.04;
uniform float edge_alpha = 0.6;
uniform float fill_alpha = 0.08;
uniform float pulse = 0.0;
uniform float clock = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float band = smoothstep(edge, 0.0, abs(r - (1.0 - edge)));
	float inside = step(r, 1.0 - edge) * (0.55 + 0.45 * r * r);
	float beat = mix(1.0, 0.8 + 0.2 * sin(clock * 2.5), pulse);
	ALBEDO = tint.rgb * (1.0 + 0.6 * band);
	ALPHA = clamp(alpha * beat * (band * edge_alpha + inside * fill_alpha), 0.0, 0.9) * step(r, 1.0);
}
"""
## The banner's cloth (a quad hanging from its top edge, UV.y 0 at the crossbar): it waves more toward its free end
## (`wave` 0 still), its hem and head in the trim's gold, and `burn` 0..1 eats it from the hem up behind a glowing
## ember edge.
const CLOTH_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform vec4 cloth : source_color = vec4(0.82, 0.24, 0.21, 1.0);
uniform vec4 trim : source_color = vec4(0.91, 0.71, 0.35, 1.0);
uniform vec4 ember : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform float wave = 1.0;
uniform float burn = 0.0;
uniform float clock = 0.0;

void vertex() {
	VERTEX.z += sin(UV.x * 4.5 + UV.y * 2.0 - clock * 3.2) * 0.07 * wave * (0.25 + UV.y);
}

void fragment() {
	float line = 1.02 - burn * 1.05 + 0.04 * sin(UV.x * 23.0) * step(0.001, burn);
	if (UV.y > line) {
		discard;
	}
	float glow = smoothstep(0.08, 0.0, line - UV.y) * step(0.001, burn);
	float band = max(step(0.88, UV.y), step(UV.y, 0.07));
	ALBEDO = mix(cloth.rgb, trim.rgb, band * 0.85) * (1.0 - 0.55 * burn);
	EMISSION = ember.rgb * glow * 3.0;
	ROUGHNESS = 0.9;
}
"""

static var _ring: Shader
static var _cloth: Shader


static func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s


## A hidden floor ring (2 m across: its scale is a radius) under `parent`, in `tint`.
static func ring(parent: Node3D, tint: Color) -> MeshInstance3D:
	if _ring == null:
		_ring = _shader(RING_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _ring
	m.set_shader_parameter("tint", tint)
	m.render_priority = -1
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


static func param(mi: MeshInstance3D, key: StringName, value: Variant) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter(key, value)


static func _solid(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## The War Banner (a stand-in in code until the owner's model): a steel pole POLE_H tall with a red spearhead, a
## crossbar, and a red cloth with a gold hem and a glowing emblem hanging from it, turned toward the game's camera.
## Built hidden under `parent`, its foot at the origin. Returns {"root", "top" (the part a charge snaps off: the
## crossbar, the cloth and the head), "cloth" (its ShaderMaterial)}.
static func banner(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "WarBanner"
	root.visible = false
	parent.add_child(root)
	var steel := _solid(STEEL)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.055
	pole.bottom_radius = 0.07
	pole.height = BAR_Y - 0.6
	pole.radial_segments = 6
	pole.rings = 1
	_mesh(root, pole, Vector3(0, pole.height * 0.5, 0), steel)
	var top := Node3D.new()
	top.position.y = BAR_Y - 0.6
	root.add_child(top)
	var upper := CylinderMesh.new()
	upper.top_radius = 0.05
	upper.bottom_radius = 0.055
	upper.height = POLE_H - top.position.y
	upper.radial_segments = 6
	upper.rings = 1
	_mesh(top, upper, Vector3(0, upper.height * 0.5, 0), steel)
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.11
	head.height = 0.42
	head.radial_segments = 4
	head.rings = 1
	_mesh(top, head, Vector3(0, upper.height + 0.2, 0), _solid(RED, 0.6))
	var yaw := Node3D.new()  # the cloth and its bar face the iso camera's corner
	yaw.rotation.y = PI * 0.25
	top.add_child(yaw)
	var bar := BoxMesh.new()
	bar.size = Vector3(CLOTH.x + 0.2, 0.07, 0.07)
	_mesh(yaw, bar, Vector3(CLOTH.x * 0.5, 0.6, 0), steel)
	var quad := QuadMesh.new()
	quad.size = CLOTH
	quad.subdivide_width = 6
	quad.subdivide_depth = 4
	if _cloth == null:
		_cloth = _shader(CLOTH_SHADER)
	var cloth := ShaderMaterial.new()
	cloth.shader = _cloth
	cloth.set_shader_parameter("cloth", RED)
	cloth.set_shader_parameter("trim", TRIM)
	cloth.set_shader_parameter("ember", EMBER)
	var mi := _mesh(yaw, quad, Vector3(CLOTH.x * 0.5 + 0.06, 0.6 - CLOTH.y * 0.5, 0), cloth)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var emblem := BoxMesh.new()
	emblem.size = Vector3(0.28, 0.42, 0.03)
	var em := _mesh(yaw, emblem, mi.position + Vector3(0, 0.05, 0.03), _solid(EMBLEM, 1.8))
	em.rotation.z = PI * 0.25
	return {"root": root, "top": top, "cloth": cloth}


## A fence javelin's transform: its head `sink` m into the floor at `at` (3D, on the floor), its shaft rising outward
## from `centre` (3D) at `pitch` (radians below level from the tail to the head), `size` times the javelin's size.
static func planted(
	at: Vector3, centre: Vector3, pitch: float, size: float, sink: float
) -> Transform3D:
	var inward := centre - at
	inward.y = 0.0
	if inward.length_squared() < 0.0001:
		inward = Vector3(1, 0, 0)
	inward = inward.normalized()
	var yaw := atan2(-inward.z, inward.x)
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), -pitch)
	var dir := b * Vector3(1, 0, 0)
	var head := at - Vector3(0, sink, 0)
	var length := BossSignatureViews.JAVELIN_LENGTH * size
	return Transform3D(b * Basis.from_scale(Vector3.ONE * size), head - dir * length)


## Transform: `scale` uniform at `pos`.
static func at(pos: Vector3, scale: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * scale), pos)


## Transform: `across` wide (x, z) and `tall` high at `pos` (a rim kept low while it spans a wide circle).
static func flat(pos: Vector3, across: float, tall: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(across, tall, across)), pos)
