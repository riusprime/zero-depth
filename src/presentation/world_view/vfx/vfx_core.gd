class_name VfxCore
extends Node3D
## The pools behind VfxLayer's element looks (docs/art/VFX_REQUESTS.md): the owner's textures on camera-facing
## sprites in the lit scene, low-poly ice crystals, pooled light flashes that light the floor and walls, and marks
## left on the floor (scorch, frost, splatter decals). VfxLayer draws the elements with these; this class only holds
## and lays out the pools.
## Presentation only: it reads nothing from the sim and decides nothing. Everything is laid out again each frame from
## its callers' effects (sim ticks plus the interpolation fraction), so it pauses and replays with them.
## Budget (PRESENTATION_CONTRACTS §7): each pool has a fixed size, LIGHTS lights, DECALS floor marks.

## Sprite pools: texture, atlas frames (columns, rows), blend (true: additive light, false: matter), wobble, capacity,
## the noise texture the wobble and the dissolve read.
const POOLS := {
	&"flame": ["fx_flame_shapes", Vector2(2, 2), true, 0.10, 320, "fx_fire_noise"],
	&"blast": ["fx_explosion_burst", Vector2(2, 2), true, 0.0, 64, "fx_fire_noise"],
	&"smoke": ["fx_smoke_puffs", Vector2(2, 2), false, 0.0, 192, "fx_fire_noise"],
	&"debris": ["fx_debris_chunks", Vector2(2, 2), false, 0.0, 96, "fx_fire_noise"],
	&"spark": ["fx_spark_shapes", Vector2(2, 2), true, 0.0, 640, "fx_fire_noise"],
	&"bolt": ["fx_lightning_bolts", Vector2(1, 4), true, 0.0, 320, "fx_fire_noise"],
	&"splash": ["fx_liquid_splash", Vector2(2, 2), false, 0.0, 192, "fx_fire_noise"],
	&"bubble": ["fx_bubbles", Vector2(2, 2), false, 0.0, 192, "fx_fire_noise"],
	&"tendril": ["fx_void_tendrils", Vector2(2, 2), false, 0.08, 160, "fx_void_noise"],
	&"rift": ["fx_void_rift", Vector2(2, 2), true, 0.03, 48, "fx_void_noise"],
}
## Floor-mark textures: the texture and its atlas cell (-1: the whole texture; the splatter sheet is 2 x 2).
const MARK_TEX := {
	&"scorch": ["fx_scorch_mark", -1],
	&"frost": ["fx_frost_mark", -1],
	&"frost_burst": ["fx_frost_burst", -1],
	&"splat0": ["fx_splatter_mark", 0],
	&"splat1": ["fx_splatter_mark", 1],
	&"splat2": ["fx_splatter_mark", 2],
	&"splat3": ["fx_splatter_mark", 3],
}
const DIR := "res://assets/textures/vfx/"
const LIGHTS := 10
const DECALS := 64
const ICE_CAP := 256
## How long a floor mark stays (ticks) and how long it fades at the end.
const MARK_TICKS := 420.0
const MARK_FADE := 90.0

const SHADER := """
shader_type spatial;
render_mode unshaded, %s, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec2 frames = vec2(2.0, 2.0);
uniform float wobble = 0.0;

varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	// custom: x = atlas cell, y = dissolve (0 whole .. 1 gone), z = seed, w = unused.
	vec2 uv = UV;
	if (wobble > 0.0) {
		vec2 n = texture(noise, vec2(UV.x * 0.7 + custom.z, UV.y * 0.6 + TIME * 0.9 + custom.z)).rg - 0.5;
		uv += n * wobble * (1.0 - UV.y);
	}
	float cell = custom.x;
	vec2 c = vec2(mod(cell, frames.x), floor(cell / frames.x));
	vec4 t = texture(atlas, (clamp(uv, 0.002, 0.998) + c) / frames);
	float n2 = texture(noise, UV * 1.3 + vec2(custom.z)).r;
	float keep = smoothstep(custom.y - 0.12, custom.y + 0.12, n2 * 0.9 + 0.05);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = clamp(t.a * COLOR.a * keep, 0.0, 1.0);
}
"""

## Sprite and ice pools: id -> {node, mm, used, cap}.
var pools := {}
var lights: Array[OmniLight3D] = []
var decals: Array[Decal] = []
var density := 1.0
## Drawn into each frame before it ends (StatusVisuals' enemy statuses): func(layer: VfxCore).
var drawers: Array[Callable] = []
var _cam_basis := Basis()
var _light_wants: Array = []
## Floor marks: [key, texture id, position, radius, start tick, turn, colour].
var _marks: Array = []
var _mark_keys := {}
var _mark_tex := {}
var _now := 0.0
var _shaders := {}


func _init() -> void:
	name = "Vfx"
	for id: StringName in POOLS:
		var spec: Array = POOLS[id]
		var mat := ShaderMaterial.new()
		mat.shader = _shader(bool(spec[2]))
		mat.set_shader_parameter("atlas", _tex(spec[0]))
		mat.set_shader_parameter("noise", _tex(spec[5]))
		mat.set_shader_parameter("frames", spec[1])
		mat.set_shader_parameter("wobble", spec[3])
		_pool(id, QuadMesh.new(), mat, int(spec[4]))
	_pool(&"ice", _crystal_mesh(), _ice_material(), ICE_CAP)
	for k in LIGHTS:
		var l := OmniLight3D.new()
		l.shadow_enabled = false
		l.visible = false
		l.omni_attenuation = 1.2
		add_child(l)
		lights.append(l)
	for id: StringName in MARK_TEX:
		_mark_tex[id] = _mark_texture(MARK_TEX[id][0], int(MARK_TEX[id][1]))
	for k in DECALS:
		var d := Decal.new()
		d.albedo_mix = 1.0
		d.visible = false
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		add_child(d)
		decals.append(d)


func _pool(id: StringName, mesh: Mesh, mat: Material, cap: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = "Vfx_" + String(id)
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 16384.0
	add_child(node)
	pools[id] = {"node": node, "mm": mm, "used": 0, "cap": cap}


func _shader(additive: bool) -> Shader:
	var key := additive
	if not _shaders.has(key):
		var s := Shader.new()
		s.code = SHADER % ("blend_add" if additive else "blend_mix")
		_shaders[key] = s
	return _shaders[key]


static func _tex(id: String) -> Texture2D:
	var path := DIR + id + ".png"
	return load(path) if ResourceLoader.exists(path) else null


## A floor-mark texture: the whole texture, or one cell of a 2 x 2 sheet cut out (a decal takes no atlas cell).
static func _mark_texture(id: String, cell: int) -> Texture2D:
	var t := _tex(id)
	if t == null or cell < 0:
		return t
	var img := t.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	var w := img.get_width() / 2
	var h := img.get_height() / 2
	var part := img.get_region(Rect2i((cell % 2) * w, (cell / 2) * h, w, h))
	part.generate_mipmaps()
	return ImageTexture.create_from_image(part)


## A low-poly ice crystal one unit tall on its base: a pentagonal shaft with a pointed tip, flat faces.
static func _crystal_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 5
	var r := 0.5
	var shaft := 0.62
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var b0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var b1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		var t0 := b0 * 0.82 + Vector3(0, shaft, 0)
		var t1 := b1 * 0.82 + Vector3(0, shaft, 0)
		for v: Vector3 in [b0, t1, t0, b0, b1, t1, t0, t1, Vector3(0, 1, 0)]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func _ice_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 0.18
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = Color(0.32, 0.62, 0.85)
	m.emission_energy_multiplier = 0.55
	m.rim_enabled = true
	m.rim = 0.6
	return m


## True when the owner's textures are installed (otherwise the canvas keeps its flat look).
static func available() -> bool:
	return ResourceLoader.exists(DIR + "fx_flame_shapes.png")


# --- Per frame ------------------------------------------------------------------------------------------------
## Starts a frame at sim time `now` (ticks): empties the pools and the light requests.
func begin(now: float) -> void:
	_now = now
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		_cam_basis = cam.global_transform.basis
	for p: Dictionary in pools.values():
		p["used"] = 0
	_light_wants.clear()


## Ends the frame: lets the drawers add theirs, shows the used pieces, gives the lights to the brightest requests,
## lays out the floor marks.
func finish() -> void:
	for d in drawers:
		if d.is_valid():
			d.call(self)
	for p: Dictionary in pools.values():
		(p["mm"] as MultiMesh).visible_instance_count = int(p["used"])
	_light_wants.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	for k in lights.size():
		var l := lights[k]
		if k < _light_wants.size():
			var w: Array = _light_wants[k]
			l.position = w[0]
			l.light_color = w[1]
			l.light_energy = w[2]
			l.omni_range = w[3]
			l.visible = true
		else:
			l.visible = false
	_lay_marks()


func now() -> float:
	return _now


func _put(
	pool: StringName, xf: Transform3D, c: Color, cell: int, dissolve: float, sd: float
) -> bool:
	var p: Dictionary = pools[pool]
	var i: int = p["used"]
	if i >= int(p["cap"]):
		return false
	var mm: MultiMesh = p["mm"]
	mm.set_instance_transform(i, xf)
	mm.set_instance_color(i, c)
	mm.set_instance_custom_data(i, Color(float(cell), clampf(dissolve, 0.0, 1.0), sd, 0.0))
	p["used"] = i + 1
	return true


## An ice crystal standing on `base`, leaning toward `up`, `hgt` tall and `w` across.
func _crystal(base: Vector3, up: Vector3, hgt: float, w: float, c: Color) -> void:
	if hgt <= 0.01:
		return
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_put(&"ice", Transform3D(Basis(x * w, y * hgt, z * w), base), c, 0, 0.0, 0.0)


## A camera-facing sprite `w` wide and `h` tall whose bottom centre is at `base` (or its centre, `centred`), turned
## `roll` radians in the screen plane.
func _facing(base: Vector3, w: float, h: float, centred: bool, roll: float = 0.0) -> Transform3D:
	var right := _cam_basis.x
	var up := _cam_basis.y
	if roll != 0.0:
		var r2 := right * cos(roll) + up * sin(roll)
		up = up * cos(roll) - right * sin(roll)
		right = r2
	var b := Basis(right * w, up * h, _cam_basis.z)
	var o := base if centred else base + up * (h * 0.5)
	return Transform3D(b, o)


## A ribbon from `a` to `b` `w` wide, facing the camera, the texture's width along it (lightning).
func _ribbon(a: Vector3, b: Vector3, w: float) -> Transform3D:
	var d := b - a
	var side := d.cross(_cam_basis.z).normalized() * w
	if side.length() < 0.0001:
		side = _cam_basis.y * w
	var n := d.cross(side).normalized()
	return Transform3D(Basis(d, side, n), (a + b) * 0.5)


## A ribbon from `a` to `b` with the texture's height along it (a void rift running down a line).
func _ribbon_tall(a: Vector3, b: Vector3, w: float) -> Transform3D:
	var xf := _ribbon(a, b, w)
	return Transform3D(Basis(xf.basis.y, xf.basis.x, -xf.basis.z), xf.origin)


func _light(p: Vector3, c: Color, energy: float, rng: float) -> void:
	if energy > 0.02:
		_light_wants.append([p, c, energy, rng])


static func h(a: int, b: int) -> float:
	return AttackFormCanvas._hash(a, b)


# --- Floor marks ----------------------------------------------------------------------------------------------
## Leaves (or keeps) a floor mark keyed `key`: texture `tex` (MARK_TEX) at `p` (ground) `r` across in colour `c`.
## It stays MARK_TICKS from its first call, then fades.
func mark(key: int, tex: StringName, p: Vector3, r: float, c: Color) -> void:
	if _mark_keys.has(key):
		return
	_mark_keys[key] = true
	_marks.append([key, tex, p, r, _now, TAU * h(key, 99), c])
	while _marks.size() > DECALS:
		_mark_keys.erase(_marks[0][0])
		_marks.pop_front()


## Drops every floor mark (a new floor; the mockup between scenes).
func clear_marks() -> void:
	_marks.clear()
	_mark_keys.clear()


func _lay_marks() -> void:
	var keep: Array = []
	for s: Array in _marks:
		if _now - float(s[4]) < MARK_TICKS:
			keep.append(s)
		else:
			_mark_keys.erase(s[0])
	_marks = keep
	for k in decals.size():
		var d := decals[k]
		if k >= _marks.size():
			d.visible = false
			continue
		var s: Array = _marks[k]
		var tex: Texture2D = _mark_tex.get(s[1])
		if d.texture_albedo != tex:
			d.texture_albedo = tex
		var left := MARK_TICKS - (_now - float(s[4]))
		var r: float = s[3]
		var c: Color = s[6]
		d.position = s[2] + Vector3(0, 0.3, 0)
		d.rotation = Vector3(0, s[5], 0)
		d.size = Vector3(r * 2.0, 1.2, r * 2.0)
		d.modulate = Color(
			c.r,
			c.g,
			c.b,
			c.a * clampf(left / MARK_FADE, 0.0, 1.0) * clampf((_now - float(s[4])) / 6.0, 0.0, 1.0)
		)
		d.visible = tex != null


# --- Counts (tests and the bench) ------------------------------------------------------------------------------
## How many pieces a pool drew this frame.
func used(pool: StringName) -> int:
	return int((pools[pool] as Dictionary)["used"])


func lights_on() -> int:
	var n := 0
	for l in lights:
		if l.visible:
			n += 1
	return n


func marks() -> int:
	return _marks.size()


## The floor marks now that use texture `tex`.
func marks_of(tex: StringName) -> int:
	var n := 0
	for s: Array in _marks:
		if s[1] == tex:
			n += 1
	return n
