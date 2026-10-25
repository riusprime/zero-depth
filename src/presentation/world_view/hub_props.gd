class_name HubProps
extends RefCounted
## v0.9.0 HB: the hub's code stand-ins (until the owner's models arrive: docs/art/requests/v0.9.0_ART_LIST.md §4) and
## the layered glows they share. Owner's VFX bar (PLAN VX: "every VFX has a high quality layered effect … no cheap 2d
## flat arts with just plane colours"): every glow here is a stack, never one flat colour: an emissive core, a soft
## camera-facing halo, a glow pooled on the floor, a real light, and (where it lives) motes drifting up.
## Presentation only (EI-07): built once from the hub's plan, animated in frame time, deciding nothing.

const STONE := Color("#77716B")
const STONE_LIT := Color("#9C948A")
const STONE_DARK := Color("#3A3C40")
const PLAZA := Color("#B39A82")
const PLAZA_SEAM := Color("#8C765F")
const BLUE := Color("#2BC4E2")
const BLUE_CORE := Color("#DDF8FF")
const GOLD := Color("#D9A441")
const GOLD_CORE := Color("#FFF0C8")
const VIOLET := Color("#9B4DFF")
const VIOLET_CORE := Color("#EBD6FF")
const CREAM := Color("#EEE6D8")
const FIRE := Color("#FF9A4A")
## The kit's ground texture (StageView.GROUND_TEXTURES), tiled every this many metres.
const GROUND_TEX := "res://assets/textures/kit/ground_b.png"
const GROUND_TEX_M := 4.0

const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 core : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float pulse = 0.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float glow = exp(-d * d * 5.0) * 0.8 + exp(-d * 9.0) * 0.6;
	float hot = exp(-d * d * 40.0);
	float k = strength * (1.0 + pulse * 0.15 * sin(TIME * 2.3));
	ALBEDO = (color.rgb * glow + core.rgb * hot) * k * (1.0 - smoothstep(0.8, 1.0, d));
}
"""

## A glow pooled on the floor: a soft disc with a brighter ring, flickering a little (a look only).
const POOL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float ring = 0.7;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float pool = exp(-d * d * 3.0) * 0.55;
	float band = exp(-pow((d - ring) * 9.0, 2.0)) * 0.45;
	ALBEDO = color.rgb * (pool + band) * strength * smoothstep(1.0, 0.85, d);
}
"""

## The machine's portal: layered swirling noise in blue and white, a hot rim and a dark eye (a look only).
const PORTAL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(0.17, 0.77, 0.89, 1.0);
uniform vec4 core : source_color = vec4(0.87, 0.97, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(0.61, 0.3, 1.0, 1.0);
uniform float strength = 1.0;
uniform float speed = 1.0;
uniform float accent_mix = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	if (r > 1.0) discard;
	float a = atan(d.y, d.x);
	float t = TIME * speed;
	float swirl = a + r * 4.0 - t * 1.3;
	float n1 = noise(vec2(cos(swirl), sin(swirl)) * 2.5 + vec2(r * 5.0 - t, t * 0.3));
	float n2 = noise(vec2(swirl * 1.7, r * 9.0 + t * 1.7));
	float bands = smoothstep(0.35, 0.95, n1 * 0.65 + n2 * 0.5);
	float rim = exp(-pow((r - 0.93) * 14.0, 2.0));
	float eye = smoothstep(0.0, 0.45, r);
	vec3 base = mix(color.rgb, accent.rgb, accent_mix * (0.5 + 0.5 * sin(a * 3.0 + t)));
	vec3 col = base * (0.35 + bands * 1.2) * eye + core.rgb * (rim * 1.4 + bands * bands * 0.5);
	ALBEDO = col * strength * smoothstep(1.0, 0.9, r);
}
"""

static var _shaders := {}


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


static func stone(c: Color, rough: float = 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.2)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


static func mesh(parent: Node3D, n: String, m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


static func box(
	parent: Node3D, n: String, size: Vector3, mat: Material, at: Vector3
) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return mesh(parent, n, b, mat, at)


static func cylinder(
	parent: Node3D,
	n: String,
	r_top: float,
	r_bottom: float,
	h: float,
	mat: Material,
	at: Vector3,
	sides := 10
) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	var mi := mesh(parent, n, c, mat, at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


## The plaza's flagstone ground (the kit's ground texture, tinted warm stone) on a disc of radius `r`.
static func ground_material(tint: Color) -> StandardMaterial3D:
	var m := stone(tint, 0.95)
	if ResourceLoader.exists(GROUND_TEX):
		m.albedo_texture = load(GROUND_TEX)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE / GROUND_TEX_M
	return m


## One layered glow at `at` (parent-local): a soft camera-facing halo (with a white-hot centre), a glow pooled on the
## floor under it, and a real light. Returns the pieces {halo, pool, light} so their strength can be driven.
static func glow(
	parent: Node3D, n: String, c: Color, core: Color, at: Vector3, size: float
) -> Dictionary:
	var root := Node3D.new()
	root.name = n
	root.position = at
	parent.add_child(root)
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	var hm := ShaderMaterial.new()
	hm.shader = _shader(HALO_SHADER)
	hm.set_shader_parameter(&"color", c)
	hm.set_shader_parameter(&"core", core)
	hm.set_shader_parameter(&"pulse", 0.0 if ViewPrefs.reduced_motion else 1.0)
	var halo := mesh(root, "Halo", q, hm, Vector3.ZERO)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pool := floor_pool(parent, n + "Pool", c, Vector3(at.x, 0.03, at.z), size * 1.6)
	var l := OmniLight3D.new()
	l.name = "Light"
	l.light_color = c.lerp(Color.WHITE, 0.25)
	l.light_energy = 1.2
	l.omni_range = size * 2.4
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	root.add_child(l)
	return {"halo": halo, "pool": pool, "light": l, "root": root}


## A glow pooled on the floor (flat, additive), `size` m across.
static func floor_pool(
	parent: Node3D, n: String, c: Color, at: Vector3, size: float
) -> MeshInstance3D:
	var pm := ShaderMaterial.new()
	pm.shader = _shader(POOL_SHADER)
	pm.set_shader_parameter(&"color", c)
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	q.orientation = PlaneMesh.FACE_Y
	var mi := mesh(parent, n, q, pm, at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Sets a glow's strength (0 dark .. 1 lit; above 1 brighter, as when the hero stands at it).
static func set_glow(g: Dictionary, k: float, light_energy: float = 1.2) -> void:
	if g.is_empty():
		return
	((g["halo"] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(
		&"strength", k
	)
	((g["pool"] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(
		&"strength", k
	)
	(g["light"] as OmniLight3D).light_energy = light_energy * k
	(g["root"] as Node3D).visible = k > 0.001
	(g["pool"] as MeshInstance3D).visible = k > 0.001


## Motes drifting up from a disc of radius `r` (small glowing specks; none under reduced motion).
static func motes(
	parent: Node3D, n: String, c: Color, at: Vector3, r: float, amount: int
) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = n
	p.position = at
	p.amount = amount
	p.lifetime = 2.6
	p.preprocess = 2.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = r
	p.emission_ring_inner_radius = r * 0.3
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 0.25, 0)
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.7
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.09
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c.lerp(Color.WHITE, 0.35)
	m.albedo_color.a = 0.9
	q.material = m
	p.mesh = q
	p.emitting = not ViewPrefs.reduced_motion
	p.visible = not ViewPrefs.reduced_motion
	parent.add_child(p)
	return p


## v0.9.0 HB3 (the VX bar: layered, never flat): a brazier's fire at `at` under `parent`, `size` m across: flame licks
## from the owner's flame sheet (fx_flame_shapes, 2 x 2: a random lick each, rising and shrinking, white-gold at the
## root to deep orange, gone in smoke-red), a hot halo, a warm pool on the floor, a real light (HubView flickers it:
## flicker()) and embers drifting up. Returns HubProps.glow's pieces plus {"flames", "embers"}.
static func fire(parent: Node3D, n: String, at: Vector3, size: float) -> Dictionary:
	var g := glow(parent, n, FIRE, GOLD_CORE, at + Vector3(0, size * 0.35, 0), size * 1.9)
	(g["light"] as OmniLight3D).omni_range = size * 7.0
	var p := CPUParticles3D.new()
	p.name = n + "Flames"
	p.position = at
	p.amount = 16
	p.lifetime = 0.75
	p.preprocess = 0.75
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.22
	p.direction = Vector3.UP
	p.spread = 8.0
	p.gravity = Vector3(0, size * 1.6, 0)
	p.initial_velocity_min = size * 0.5
	p.initial_velocity_max = size * 1.0
	p.scale_amount_min = 0.75
	p.scale_amount_max = 1.15
	p.angle_min = -12.0
	p.angle_max = 12.0
	p.anim_offset_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.55))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.15))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.93, 0.7, 1.0))
	ramp.set_color(1, Color(0.55, 0.08, 0.02, 0.0))
	ramp.add_point(0.35, Color(1.0, 0.6, 0.18, 0.95))
	ramp.add_point(0.75, Color(0.85, 0.22, 0.05, 0.55))
	p.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size * 0.95
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sheet := FxTextures.get_tex("fx_flame_shapes")
	if sheet != null:
		m.albedo_texture = sheet
		m.particles_anim_h_frames = 2
		m.particles_anim_v_frames = 2
		m.particles_anim_loop = false
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	g["flames"] = p
	g["embers"] = motes(parent, n + "Embers", FIRE, at + Vector3(0, size * 0.3, 0), size * 0.25, 10)
	return g


## A fire's light flickering at time `t` (s): a sum of three incommensurate sines round its rest energy (a look only).
static func flicker(g: Dictionary, t: float, seed_value: float) -> void:
	var k := (
		1.0
		+ 0.12 * sin(t * 9.1 + seed_value)
		+ 0.07 * sin(t * 15.7 + seed_value * 2.3)
		+ 0.05 * sin(t * 23.3 + seed_value * 0.7)
	)
	(g["light"] as OmniLight3D).light_energy = 1.4 * k


## The portal disc's material (the machine's swirl).
static func portal_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(PORTAL_SHADER)
	m.set_shader_parameter(&"color", BLUE)
	m.set_shader_parameter(&"core", BLUE_CORE)
	m.set_shader_parameter(&"accent", VIOLET)
	m.set_shader_parameter(&"speed", 0.0 if ViewPrefs.reduced_motion else 1.0)
	return m


## The owner's hub model `id` (ShopModels: listed in assets/models/manifest.json, front +Z kept) at `at` under `parent`,
## or null when it isn't installed (the caller's code stand-in stays). `stand_in` (optional) is hidden when it is.
static func owner_model(
	parent: Node3D, id: StringName, at: Vector3, stand_in: Node3D = null
) -> MeshInstance3D:
	var m := ShopModels.get_model(id)
	if m.is_empty():
		return null
	var mi := mesh(parent, "Model", m["mesh"], m["material"], at)
	mi.set_meta(&"model_id", id)
	if stand_in != null:
		stand_in.visible = false
	return mi


## A node to hold a station's code stand-in (hidden when the owner's model draws instead).
static func stand_in(parent: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = "StandIn"
	parent.add_child(n)
	return n


## A kit piece (KitModels: the owner's model, normalised to a unit box) scaled to `size` and turned `yaw`, or the
## stand-in box in `fallback` when the piece isn't installed.
static func kit_piece(
	parent: Node3D,
	n: String,
	id: StringName,
	size: Vector3,
	at: Vector3,
	yaw: float,
	fallback: Color
) -> Node3D:
	var piece := KitModels.get_piece(id)
	var node := Node3D.new()
	node.name = n
	node.position = at
	node.rotation.y = yaw
	parent.add_child(node)
	if piece.is_empty():
		box(node, "Box", size, stone(fallback), Vector3(0, size.y * 0.5, 0))
		return node
	var mi := MeshInstance3D.new()
	mi.name = "Model"
	mi.mesh = piece["mesh"]
	mi.material_override = piece["material"]
	mi.scale = size
	node.add_child(mi)
	return node
