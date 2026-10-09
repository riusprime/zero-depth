class_name VfxLayer
extends Node3D
## Real 3D effects for the elements (owner, 2026-10-09: "fire should be fire, even if minimalistic, that matches the
## style of the game … not a circle with bad made particles on top"; docs/art/VFX_REQUESTS.md). The owner's
## textures (assets/textures/vfx/) on camera-facing sprites in the lit scene, pooled light flashes that light the
## floor and walls, and scorch decals. AttackFormCanvas calls it per frame instead of drawing its flat ground shapes
## when the new look is on (WorldViewRoot sets canvas.vfx); without it the canvas draws as before.
## Presentation only: it reads nothing from the sim and decides nothing. Everything is laid out again each frame from
## the canvas's effects (sim ticks plus the interpolation fraction), so it pauses and replays with them.
## Budget (PRESENTATION_CONTRACTS §7): each sprite pool has a fixed size, LIGHTS lights, DECALS decals.

## Sprite pools: texture, atlas frames (columns, rows), blend (true: additive light, false: matter), fire wobble,
## capacity.
const POOLS := {
	&"flame": ["fx_flame_shapes", Vector2(2, 2), true, 0.10, 256],
	&"blast": ["fx_explosion_burst", Vector2(2, 2), true, 0.04, 64],
	&"smoke": ["fx_smoke_puffs", Vector2(2, 2), false, 0.0, 160],
	&"debris": ["fx_debris_chunks", Vector2(2, 2), false, 0.0, 96],
	&"spark": ["fx_spark_shapes", Vector2(2, 2), true, 0.0, 512],
	&"bolt": ["fx_lightning_bolts", Vector2(1, 4), true, 0.0, 256],
}
const DIR := "res://assets/textures/vfx/"
const LIGHTS := 8
const DECALS := 48
## How long a scorch stays (ticks) and how long it fades at the end.
const SCORCH_TICKS := 420.0
const SCORCH_FADE := 90.0

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

var pools := {}
var lights: Array[OmniLight3D] = []
var decals: Array[Decal] = []
var density := 1.0
var _cam_basis := Basis()
var _light_wants: Array = []
## Scorches: [key, pos (3D), radius, start tick, yaw].
var _scorches: Array = []
var _scorch_keys := {}
var _now := 0.0
var _shaders := {}


func _init() -> void:
	name = "Vfx"
	var noise: Texture2D = _tex("fx_fire_noise")
	for id: StringName in POOLS:
		var spec: Array = POOLS[id]
		var mat := ShaderMaterial.new()
		mat.shader = _shader(bool(spec[2]))
		mat.set_shader_parameter("atlas", _tex(spec[0]))
		mat.set_shader_parameter("noise", noise)
		mat.set_shader_parameter("frames", spec[1])
		mat.set_shader_parameter("wobble", spec[3])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = QuadMesh.new()
		mm.instance_count = int(spec[4])
		mm.visible_instance_count = 0
		var node := MultiMeshInstance3D.new()
		node.name = "Vfx_" + String(id)
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = 16384.0
		add_child(node)
		pools[id] = {"node": node, "mm": mm, "used": 0, "cap": int(spec[4])}
	for k in LIGHTS:
		var l := OmniLight3D.new()
		l.shadow_enabled = false
		l.visible = false
		l.omni_attenuation = 1.2
		add_child(l)
		lights.append(l)
	var scorch: Texture2D = _tex("fx_scorch_mark")
	for k in DECALS:
		var d := Decal.new()
		d.texture_albedo = scorch
		d.modulate = Color(0.05, 0.04, 0.035, 0.0)
		d.albedo_mix = 1.0
		d.visible = false
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		add_child(d)
		decals.append(d)


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


## Ends the frame: shows the used sprites, gives the lights to the brightest requests, lays out the scorches.
func finish() -> void:
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
	_lay_scorches()


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


## A ribbon from `a` to `b` `w` wide, facing the camera (lightning).
func _ribbon(a: Vector3, b: Vector3, w: float) -> Transform3D:
	var d := b - a
	var side := d.cross(_cam_basis.z).normalized() * w
	if side.length() < 0.0001:
		side = _cam_basis.y * w
	var n := d.cross(side).normalized()
	return Transform3D(Basis(d, side, n), (a + b) * 0.5)


func _light(p: Vector3, c: Color, energy: float, rng: float) -> void:
	if energy > 0.02:
		_light_wants.append([p, c, energy, rng])


static func h(a: int, b: int) -> float:
	return AttackFormCanvas._hash(a, b)


# --- Elements -------------------------------------------------------------------------------------------------
## Fire over a patch of radius `r` at `c` (ground): upright flames, rising embers, a little smoke, warm light, a
## scorch under it. `fade` 0..1, `age` in ticks, `sd` the effect's seed.
func fire(c: Vector3, r: float, fade: float, age: float, sd: int, warm: Color) -> void:
	if fade <= 0.0:
		return
	var n := clampi(int(round((2.0 + r * r * 2.2) * density)), 2, 16)
	for k in n:
		var a := TAU * h(sd, k)
		var d := sqrt(h(sd + 3, k)) * r * 0.8
		var p := c + Vector3(cos(a) * d, 0.0, sin(a) * d)
		# Each flame breathes on its own beat and swaps its shape now and then.
		var beat := 0.85 + 0.15 * sin(age * (0.35 + 0.2 * h(sd + 5, k)) + TAU * h(sd + 7, k))
		var hgt := (
			(0.9 + 0.9 * h(sd + 9, k)) * (0.6 + 0.4 * (1.0 - d / maxf(r, 0.01))) * beat * fade
		)
		var cell := (k + int(age / (9.0 + 5.0 * h(sd, k + 40)))) % 4
		_put(
			&"flame",
			_facing(p, hgt * 0.72, hgt, false),
			Color(1.6, 1.4, 1.2, fade),
			cell,
			0.0,
			h(sd, k) * 10.0
		)
		_embers(p, age, sd + k * 13, 2, fade)
	for k in maxi(1, int(n / 4)):
		_smoke(c + Vector3(0, 0.5, 0), age, sd + 77 + k, 0.35 + r * 0.25, fade * 0.45, 70.0)
	_light(
		c + Vector3(0, 0.9, 0),
		warm,
		(3.0 + r) * fade * (0.85 + 0.15 * sin(age * 0.9 + sd)),
		r + 3.5
	)
	scorch(sd, c, r * 1.1)


## Rising embers from `p`: `n` sparks on short cycles.
func _embers(p: Vector3, age: float, sd: int, n: int, fade: float) -> void:
	for j in n:
		var period := 34.0 + 20.0 * h(sd, j)
		var u := fposmod(age + h(sd + 1, j) * period, period) / period
		var a := TAU * h(sd + 2, j)
		var q := p + Vector3(cos(a) * 0.25 * u, 0.2 + 1.4 * u, sin(a) * 0.25 * u)
		var s := 0.07 * (1.0 - u * 0.6)
		_put(&"spark", _facing(q, s, s, true), Color(2.2, 1.1, 0.35, (1.0 - u) * fade), 3, 0.0, 0.0)


## A smoke puff rising from `p` on a `period`-tick cycle, `size` across at the start.
func _smoke(p: Vector3, age: float, sd: int, size: float, alpha: float, period: float) -> void:
	var u := fposmod(age + h(sd, 1) * period, period) / period
	var q := p + Vector3((h(sd, 2) - 0.5) * 0.6 * u, 1.4 * u, (h(sd, 3) - 0.5) * 0.6 * u)
	var s := size * (0.6 + 1.1 * u)
	var a := alpha * sin(PI * u)
	_put(
		&"smoke",
		_facing(q, s, s, true, h(sd, 4) * TAU),
		Color(0.16, 0.14, 0.13, a),
		int(h(sd, 5) * 4.0),
		u * 0.8,
		h(sd, 6)
	)


## A bomb landing `u` (0..1) through, radius `r` at `c` (ground): a fireball that blooms and burns away, debris
## thrown out, a smoke cloud, a light flash, a ragged scorch.
func explosion(c: Vector3, r: float, u: float, sd: int, warm: Color) -> void:
	var bloom := clampf(u / 0.25, 0.0, 1.0)
	var burn := clampf((u - 0.15) / 0.55, 0.0, 1.0)
	for k in 3:
		var a := TAU * h(sd, k)
		var off := Vector3(cos(a), 0, sin(a)) * r * 0.35 * h(sd + 1, k)
		var s := r * (0.9 + 0.5 * h(sd + 2, k)) * (0.5 + 0.7 * bloom)
		_put(
			&"blast",
			_facing(c + off + Vector3(0, 0.05, 0), s, s, false),
			Color(1.8, 1.6, 1.4, 1.0),
			(sd + k) % 4,
			burn,
			h(sd, k)
		)
	var nd := int(round(6 * density))
	for k in nd:
		var a := TAU * (k + h(sd + 4, k)) / maxf(nd, 1)
		var sp := r * (0.9 + 0.8 * h(sd + 5, k))
		var t := clampf(u * 1.6, 0.0, 1.0)
		var q := (
			c
			+ Vector3(
				cos(a) * sp * t,
				(2.4 * t - 2.6 * t * t) * (0.8 + h(sd + 6, k)) + 0.15,
				sin(a) * sp * t
			)
		)
		var s := 0.7 + 0.4 * h(sd + 7, k)
		_put(
			&"debris",
			_facing(q, s, s, true, u * 6.0 * (h(sd, k) - 0.5)),
			Color(0.95, 0.9, 0.85, 1.0 - clampf((u - 0.75) / 0.25, 0.0, 1.0)),
			(sd + k) % 4,
			0.0,
			0.0
		)
	for k in int(round(4 * density)):
		var a := TAU * h(sd + 8, k)
		var q := c + Vector3(cos(a) * r * 0.4, 0.4 + 1.2 * u, sin(a) * r * 0.4)
		var s := r * (0.7 + 0.9 * u)
		var al := 0.75 * clampf((u - 0.1) / 0.2, 0.0, 1.0) * (1.0 - u)
		_put(
			&"smoke",
			_facing(q, s, s, true, TAU * h(sd + 9, k)),
			Color(0.14, 0.12, 0.11, al),
			(sd + k) % 4,
			u * 0.85,
			h(sd, k + 9)
		)
	for k in int(round(10 * density)):
		var a := TAU * h(sd + 10, k)
		var t := clampf(u * 2.2, 0.0, 1.0)
		var q := (
			c + Vector3(cos(a) * r * 1.3 * t, 0.3 + 1.6 * t - 1.8 * t * t, sin(a) * r * 1.3 * t)
		)
		_put(&"spark", _facing(q, 0.12, 0.12, true), Color(2.4, 1.3, 0.4, 1.0 - t), k % 4, 0.0, 0.0)
	_light(c + Vector3(0, 1.0, 0), warm, 7.0 * pow(1.0 - u, 2.0), r * 3.0 + 2.0)
	scorch(sd, c, r * 1.25)


## Lightning from `a` to `b`: a jagged bolt that re-strikes every few ticks, sparks at its end, a cold flicker.
func lightning(
	a: Vector3, b: Vector3, fade: float, age: float, sd: int, cold: Color, width: float = 0.5
) -> void:
	if fade <= 0.0:
		return
	var strike := int(age / 3.0)
	var span := a.distance_to(b)
	var on := 0.75 + 0.25 * float((strike + sd) % 2)
	var segs := clampi(int(span / 2.5) + 1, 1, 6)
	var prev := a
	for s in segs:
		var t := float(s + 1) / segs
		var nxt := a.lerp(b, t)
		if s < segs - 1:
			nxt += (
				Vector3(
					h(sd + strike, s) - 0.5,
					(h(sd + strike, s + 9) - 0.5) * 0.6,
					h(sd + strike, s + 17) - 0.5
				)
				* minf(span * 0.25, 0.9)
			)
		_put(
			&"bolt",
			_ribbon(prev, nxt, width * (0.8 + 0.4 * h(sd, s))),
			Color(cold.r * 2.2, cold.g * 2.2, cold.b * 2.4, fade * on),
			(strike + s + sd) % 4,
			0.0,
			0.0
		)
		prev = nxt
	for j in 3:
		var q := (
			b
			+ (
				Vector3(
					h(sd + strike, j + 30) - 0.5,
					h(sd + strike, j + 40) * 0.5,
					h(sd + strike, j + 50) - 0.5
				)
				* 0.5
			)
		)
		_put(
			&"spark",
			_facing(q, 0.16, 0.16, true, h(sd, j) * TAU),
			Color(cold.r * 2.0, cold.g * 2.0, cold.b * 2.2, fade),
			j % 4,
			0.0,
			0.0
		)
	_light(b + Vector3(0, 0.6, 0), cold, 1.8 * fade * on, 4.0)


## A crackling field of radius `r` at `c`: short bolts between points inside it, re-striking, a cold light.
func storm_field(c: Vector3, r: float, fade: float, age: float, sd: int, cold: Color) -> void:
	var strike := int(age / 4.0)
	var n := clampi(int(round((1.5 + r * 1.2) * density)), 1, 8)
	for k in n:
		var a := TAU * h(sd + strike, k)
		var b := TAU * h(sd + strike, k + 20)
		var p := (
			c
			+ Vector3(
				cos(a) * r * 0.75 * h(sd, k + 3),
				0.25 + 0.4 * h(sd + strike, k + 7),
				sin(a) * r * 0.75 * h(sd, k + 3)
			)
		)
		var q := (
			c
			+ Vector3(
				cos(b) * r * 0.8 * h(sd, k + 5),
				0.2 + 0.5 * h(sd + strike, k + 9),
				sin(b) * r * 0.8 * h(sd, k + 5)
			)
		)
		lightning(p, q, fade * 0.8, age, sd + k * 7, cold, 0.35)
	_light(c + Vector3(0, 0.8, 0), cold, (1.2 + r * 0.4) * fade, r + 3.0)


## A shock ring of radius `r` at `c`: lightning running round its edge at waist height, no ground fill.
func storm_ring(c: Vector3, r: float, fade: float, age: float, sd: int, cold: Color) -> void:
	if r < 0.1 or fade <= 0.0:
		return
	var n := clampi(int(r * 3.0), 6, 18)
	var y := Vector3(0, 0.35, 0)
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var p := c + y + Vector3(cos(a0), 0, sin(a0)) * r
		var q := c + y + Vector3(cos(a1), 0, sin(a1)) * r
		_put(
			&"bolt",
			_ribbon(p, q, 0.45),
			Color(
				cold.r * 2.2,
				cold.g * 2.2,
				cold.b * 2.4,
				fade * (0.7 + 0.3 * h(sd + int(age / 3.0), k))
			),
			(k + int(age / 3.0)) % 4,
			0.0,
			0.0
		)
	_light(c + Vector3(0, 0.6, 0), cold, 1.6 * fade, r + 2.5)


## Leaves (or keeps) a scorch keyed `key` at `p` (ground) `r` across; it stays SCORCH_TICKS from its first call.
func scorch(key: int, p: Vector3, r: float) -> void:
	if _scorch_keys.has(key):
		return
	_scorch_keys[key] = true
	_scorches.append([key, p, r, _now, TAU * h(key, 99)])
	while _scorches.size() > DECALS:
		_scorch_keys.erase(_scorches[0][0])
		_scorches.pop_front()


func _lay_scorches() -> void:
	var keep: Array = []
	for s: Array in _scorches:
		if _now - float(s[3]) < SCORCH_TICKS:
			keep.append(s)
		else:
			_scorch_keys.erase(s[0])
	_scorches = keep
	for k in decals.size():
		var d := decals[k]
		if k < _scorches.size():
			var s: Array = _scorches[k]
			var left := SCORCH_TICKS - (_now - float(s[3]))
			var r: float = s[2]
			d.position = s[1] + Vector3(0, 0.3, 0)
			d.rotation = Vector3(0, s[4], 0)
			d.size = Vector3(r * 2.0, 1.2, r * 2.0)
			d.modulate.a = (
				0.85
				* clampf(left / SCORCH_FADE, 0.0, 1.0)
				* clampf((_now - float(s[3])) / 6.0, 0.0, 1.0)
			)
			d.visible = true
		else:
			d.visible = false


## How many sprites a pool drew this frame (tests and the bench).
## Drops every scorch mark (a new floor; the mockup between scenes).
func clear_scorches() -> void:
	_scorches.clear()
	_scorch_keys.clear()


func used(pool: StringName) -> int:
	return int((pools[pool] as Dictionary)["used"])


func lights_on() -> int:
	var n := 0
	for l in lights:
		if l.visible:
			n += 1
	return n


func scorches() -> int:
	return _scorches.size()
