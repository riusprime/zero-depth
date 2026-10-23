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
	# v0.8.0 TX2: the owner's rock bursts (slams, eruptions), steam puffs (the Foundry's vent) and crystal shatter
	# bursts (the final boss between bodies).
	&"rockburst": ["fx_rock_burst", Vector2(2, 2), false, 0.0, 48, "fx_fire_noise"],
	&"steam": ["fx_steam_puffs", Vector2(2, 2), false, 0.04, 96, "fx_fire_noise"],
	&"shatter": ["fx_crystal_shatter", Vector2(2, 2), true, 0.0, 32, "fx_fire_noise"],
	# v0.9.0 VX (VFX_AUDIT.md; owner: "every VFX has a high quality layered effect"): the layers the hero's element
	# effects add. A soft glow halo and an energy ring (made in code, CODE_TEX, until the owner's PNG of that id is
	# installed), the owner's ember sparks and frost burst drawn as additive light, and the VX texture requests
	# (docs/art/requests/v0.9.0_ART_LIST.md §7c), whose pools exist only once their PNG is installed (VfxLayer falls back
	# to the pools above without them).
	&"glow": ["fx_soft_glow", Vector2(1, 1), true, 0.0, 256, "fx_fire_noise"],
	&"ring": ["fx_energy_ring", Vector2(1, 1), true, 0.0, 64, "fx_fire_noise"],
	# The ember art is coloured: drawn as unshaded colour over 1 (it blooms), not added, so it reads on light floors too.
	&"ember": ["fx_ember_sparks", Vector2(2, 2), false, 0.0, 192, "fx_fire_noise"],
	&"flake": ["fx_frost_burst", Vector2(1, 1), true, 0.0, 48, "fx_fire_noise"],
	&"shard": ["fx_frost_shards", Vector2(2, 2), true, 0.0, 128, "fx_fire_noise"],
	&"drop": ["fx_blood_drops", Vector2(2, 2), false, 0.0, 128, "fx_fire_noise"],
	&"fork": ["fx_lightning_fork", Vector2(2, 2), true, 0.0, 96, "fx_fire_noise"],
	&"muzzle": ["fx_muzzle_flash", Vector2(2, 2), true, 0.0, 48, "fx_fire_noise"],
}
## v0.9.0 VX: the sheets made in code when the owner's PNG isn't installed (V45's manifest: "fallback": "code").
const CODE_TEX: Array[String] = ["fx_soft_glow", "fx_energy_ring"]
## v0.9.0 VX: the pools whose sheet is a texture request: they are made only once it is installed.
const OPTIONAL_POOLS: Array[StringName] = [&"shard", &"drop", &"fork", &"muzzle"]
## Floor-mark textures: the texture and its atlas cell (-1: the whole texture; the splatter sheet is 2 x 2).
const MARK_TEX := {
	&"scorch": ["fx_scorch_mark", -1],
	&"frost": ["fx_frost_mark", -1],
	&"frost_burst": ["fx_frost_burst", -1],
	&"splat0": ["fx_splatter_mark", 0],
	&"splat1": ["fx_splatter_mark", 1],
	&"splat2": ["fx_splatter_mark", 2],
	&"splat3": ["fx_splatter_mark", 3],
	# v0.8.0 TX2: the cracks a slam, a spike row or a crater leaves (one cell: one kind, so overlapping ones merge).
	&"cracks": ["fx_ground_cracks", 0],
	# v0.9.0 VX V43: Fire's burning ground under its flames, once the owner's fire_patch is installed (else none).
	&"fire_patch": ["fire_patch", -1],
}
const DIR := "res://assets/textures/vfx/"
const LIGHTS := 10
const DECALS := 64
const ICE_CAP := 256
## P-20: every pool's pieces together a frame (the pools' own caps sum to 2,656), PRESENTATION §7's 2,000 live
## particles; past it the last pieces of the frame drop, as the attack-form canvas's MAX_PARTICLES does.
const MAX_SPRITES := 2000
## How long a floor mark stays (ticks) and how long it fades at the end.
const MARK_TICKS := 420.0
const MARK_FADE := 90.0
## v0.8.0 FV (owner O86, feedback 2026-10-19 Part 3: "every other effect requests unmerged lights"): every effect's
## light joins a light of its own colour within LIGHT_MERGE_M (the fire patches' 2.5 m since the lighting pass), so
## near-simultaneous effects (Twin pairs, chains, overlapping blasts) share one light instead of each taking a slot.
## A lone effect's light is unchanged. Each merge brightens the shared light by LIGHT_MERGE_BOOST, at most
## LIGHT_MERGE_BOOST_MAX times its brightest member (a burning horde no longer stacks ×1.08 per enemy). Starting values.
const LIGHT_MERGE_M := 2.5
const LIGHT_MERGE_BOOST := 1.08
const LIGHT_MERGE_BOOST_MAX := 1.3
## v0.8.0 FV: the enemy statuses' lights (burning enemies: the term that grows with the horde) are gathered over the
## frame, the brightest first, merged within LIGHT_MERGE_M; at most STATUS_LIGHTS_MAX new lights come from them, the
## rest only join a light already there or are dropped. Starting value (the pool holds LIGHTS).
const STATUS_LIGHTS_MAX := 4
## v0.8.0 FV: pressure thinning. While a pool is past PRESSURE of its cap (or the frame's pieces past PRESSURE of
## MAX_SPRITES), an effect's debris, smoke, sparks and ice crystals are halved (rounded up); its blast and flash stay.
## The cap then thins the effects gradually instead of cutting the frame's last ones off. Deterministic: it reads only
## this frame's counts, in the callers' fixed draw order. Starting value.
const PRESSURE := 0.7
## v0.9.0 VX: what a missing pool reads as (_put, _pressed).
const NO_POOL := {}

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

static var _has_tex := {}
## v0.8.0 N12 (owner O70): the floor marks' cut textures and the two sprite shaders, made once per run of the game
## and shared by every floor's layer (each floor made them again: ~30 ms of a load's frame).
static var _mark_cache := {}
static var _shader_cache := {}

## Sprite and ice pools: id -> {node, mm, used, cap}.
var pools := {}
var lights: Array[OmniLight3D] = []
var decals: Array[Decal] = []
var density := 1.0
## Drawn into each frame before it ends (StatusVisuals' enemy statuses): func(layer: VfxCore).
var drawers: Array[Callable] = []
## This frame's counts (the perf probe and the tests): sprites asked for; bursts asked for, drawn, merged into one
## drawn nearby and skipped past the budget (VfxLayer.burst, v0.8.0 PF).
var sprites_asked := 0
var bursts_asked := 0
var bursts_drawn := 0
var bursts_merged := 0
var bursts_skipped := 0
## v0.8.0 FV: this frame's light requests folded into a light already asked for (_light_merged); the status lights
## asked for and those dropped past STATUS_LIGHTS_MAX; the pieces left out by pressure thinning (_thin).
var lights_merged := 0
var status_lights_asked := 0
var status_lights_dropped := 0
var pieces_thinned := 0
## v0.8.0 N1: with `record` on (the light-walk probe, tests), the places of this frame's flame sprites (their
## centres), since a headless renderer keeps no instance transforms to read back.
var record := false
var placed_flames := PackedVector3Array()
## The same pools in a list (begin and finish walk it every frame without allocating).
var _pool_list: Array[Dictionary] = []
var _cam_basis := Basis()
## Light requests: [position, colour, energy, range, brightest member's energy].
var _light_wants: Array = []
## v0.8.0 FV: this frame's status light requests, laid in at finish (_flush_status_lights): [p, colour, energy, range].
var _status_wants: Array = []
## Floor marks: [key, texture id, position, radius, start tick, turn, colour].
var _marks: Array = []
var _mark_keys := {}
var _mark_tex := {}
var _now := 0.0
var _shaders := {}
## This frame's taken spots, per kind: kind -> {grid cell (Vector2i) -> [[Vector3, owner]]} (see _claim).
var _spots := {}
## P-20: pieces left under MAX_SPRITES this frame.
var _sprite_left := MAX_SPRITES
## While true, light requests are dropped (a thinned burst asks for none: VfxLayer.burst).
var _lights_off := false


func _init() -> void:
	name = "Vfx"
	# v0.8.0 N1 (owner O46/O55: "fire drawings popping randomly in position and timing through the whole screen"):
	# every piece here (the pools' instances, the pooled lights, the floor marks) is laid out again each frame, and a
	# pool slot holds a different effect from one frame to the next (a fire light hid, another effect's flames came
	# first). Under the project's physics interpolation the renderer drew each slot between its last two physics
	# ticks' places, so for a frame a flame or an ember stood halfway between two fires, and a pooled light slid.
	# The pieces are placed on frame time already (sim ticks plus the fraction): no interpolation, as every other
	# per-frame pool (AttackFormPool, BakedMeshPools, BossStrikeViews ...). The children inherit it.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for id: StringName in POOLS:
		var spec: Array = POOLS[id]
		if id in OPTIONAL_POOLS and not has_tex(spec[0]):
			continue  # v0.9.0 VX: a texture request not delivered yet (VfxLayer uses its fallback)
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
	_pool_list.append(pools[id])


func _shader(additive: bool) -> Shader:
	var key := additive
	if not _shaders.has(key):
		if not _shader_cache.has(key):
			var s := Shader.new()
			s.code = SHADER % ("blend_add" if additive else "blend_mix")
			_shader_cache[key] = s
		_shaders[key] = _shader_cache[key]
	return _shaders[key]


## v0.8.0 N12 (O70): reads the sprite sheets and cuts the floor marks once, ahead of a floor's first layer
## (ViewWarmup, on a worker while the loading cover shows).
static func warm() -> void:
	if not available():
		return
	for id: StringName in POOLS:
		_tex(POOLS[id][0])
		_tex(POOLS[id][5])
	for id: StringName in MARK_TEX:
		_mark_texture(MARK_TEX[id][0], int(MARK_TEX[id][1]))


static func _tex(id: String) -> Texture2D:
	var path := DIR + id + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return _code_tex(id) if id in CODE_TEX else null


## v0.9.0 VX: the code-made sheet of `id` (CODE_TEX), made once per run: white, the shape in its alpha.
## - fx_soft_glow: a soft round halo falling off smoothly to nothing at its edge;
## - fx_energy_ring: a bright thin ring with a softer glow either side and faint wisps breaking it up.
static func _code_tex(id: String) -> Texture2D:
	var key := "code/" + id
	if _mark_cache.has(key):
		return _mark_cache[key]
	var n := 64 if id == "fx_soft_glow" else 128
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0)
			var r := d.length()
			var a := 0.0
			if id == "fx_soft_glow":
				a = clampf(1.0 - r, 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a) * clampf(1.0 - r * r, 0.0, 1.0)
			else:
				var ang := d.angle()
				var wisp := 0.75 + 0.25 * sin(ang * 7.0 + sin(ang * 3.0) * 2.0)
				var band := clampf(1.0 - absf(r - 0.78) / 0.05, 0.0, 1.0)
				var soft := clampf(1.0 - absf(r - 0.76) / 0.2, 0.0, 1.0)
				a = clampf(band * wisp + soft * soft * 0.45 * wisp, 0.0, 1.0) * float(r < 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_mark_cache[key] = t
	return t


## A floor-mark texture: the whole texture, or one cell of a 2 x 2 sheet cut out (a decal takes no atlas cell).
static func _mark_texture(id: String, cell: int) -> Texture2D:
	var key := "%s/%d" % [id, cell]
	if not _mark_cache.has(key):
		_mark_cache[key] = _cut_mark(id, cell)
	return _mark_cache[key]


static func _cut_mark(id: String, cell: int) -> Texture2D:
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


## v0.8.0 TX2: true when texture `id` of DIR is installed (cached; a drawer keeps its code look without it).
static func has_tex(id: String) -> bool:
	if not _has_tex.has(id):
		_has_tex[id] = ResourceLoader.exists(DIR + id + ".png")
	return _has_tex[id]


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
	for p: Dictionary in _pool_list:
		p["used"] = 0
	_sprite_left = MAX_SPRITES
	sprites_asked = 0
	bursts_asked = 0
	bursts_drawn = 0
	bursts_merged = 0
	bursts_skipped = 0
	lights_merged = 0
	status_lights_asked = 0
	status_lights_dropped = 0
	pieces_thinned = 0
	_lights_off = false
	_light_wants.clear()
	_status_wants.clear()
	_spots.clear()
	if record:
		placed_flames.clear()


## Ends the frame: lets the drawers add theirs, shows the used pieces, gives the lights to the brightest requests,
## lays out the floor marks.
func finish() -> void:
	for d in drawers:
		if d.is_valid():
			d.call(self)
	_flush_status_lights()
	for p: Dictionary in _pool_list:
		(p["mm"] as MultiMesh).visible_instance_count = int(p["used"])
	_light_wants.sort_custom(_brighter)
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


## The light sort: the brighter request first.
static func _brighter(a: Array, b: Array) -> bool:
	return a[2] > b[2]


func now() -> float:
	return _now


func _put(
	pool: StringName, xf: Transform3D, c: Color, cell: int, dissolve: float, sd: float
) -> bool:
	sprites_asked += 1
	var p: Dictionary = pools.get(pool, NO_POOL)  # v0.9.0 VX: a texture request's pool may not exist
	if p.is_empty():
		return false
	var i: int = p["used"]
	if i >= int(p["cap"]) or _sprite_left <= 0:
		return false
	_sprite_left -= 1
	var mm: MultiMesh = p["mm"]
	mm.set_instance_transform(i, xf)
	mm.set_instance_color(i, c)
	mm.set_instance_custom_data(i, Color(float(cell), clampf(dissolve, 0.0, 1.0), sd, 0.0))
	p["used"] = i + 1
	if record and pool == &"flame":
		placed_flames.append(xf.origin)
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


## v0.9.0 VX: a sprite lying flat on the floor at `p`, `w` across, turned `roll` radians about the vertical.
static func _flat(p: Vector3, w: float, roll: float = 0.0) -> Transform3D:
	var x := Vector3(cos(roll), 0.0, -sin(roll)) * w
	var y := Vector3(sin(roll), 0.0, cos(roll)) * -w
	return Transform3D(Basis(x, y, Vector3.UP), p)


## v0.9.0 VX: whether pool `id` exists (a texture request's pool only once its PNG is installed).
func has_pool(id: StringName) -> bool:
	return pools.has(id)


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


## An effect's light: merged into a light of the same colour within LIGHT_MERGE_M (v0.8.0 FV; a lone one as before).
func _light(p: Vector3, c: Color, energy: float, rng: float) -> void:
	_light_merged(p, c, energy, rng, LIGHT_MERGE_M)


## One light for a cluster: when a light of colour `c` already stands within `merge` m, it takes the stronger
## energy and the wider range instead of a second light (overlapping fire patches light the room once, not once
## each: owner, 2026-10-12, "that's too much fire"). Only the same colour merges (a cold flash never joins a fire).
func _light_merged(p: Vector3, c: Color, energy: float, rng: float, merge: float) -> void:
	if energy <= 0.02 or _lights_off:
		return
	if not _merge_into(p, c, energy, rng, merge):
		_light_wants.append([p, c, energy, rng, energy])


## Folds a request into a light of colour `c` already asked for within `merge` m; false when there is none.
func _merge_into(p: Vector3, c: Color, energy: float, rng: float, merge: float) -> bool:
	for w: Array in _light_wants:
		if (w[1] as Color).is_equal_approx(c) and (w[0] as Vector3).distance_to(p) < merge:
			w[4] = maxf(float(w[4]), energy)
			w[2] = minf(
				maxf(float(w[2]), energy) * LIGHT_MERGE_BOOST, float(w[4]) * LIGHT_MERGE_BOOST_MAX
			)
			w[3] = maxf(float(w[3]), rng)
			lights_merged += 1
			return true
	return false


## v0.8.0 FV: an enemy status's light, gathered for _flush_status_lights (the brightest few get slots).
func _light_status(p: Vector3, c: Color, energy: float, rng: float) -> void:
	if energy > 0.02 and not _lights_off:
		status_lights_asked += 1
		_status_wants.append([p, c, energy, rng])


## Lays the frame's status lights in, the brightest first: each merges into a light of its colour within
## LIGHT_MERGE_M (an effect's or an earlier status's); past STATUS_LIGHTS_MAX new ones, the rest are dropped.
func _flush_status_lights() -> void:
	if _status_wants.is_empty():
		return
	_status_wants.sort_custom(_status_first)
	var opened := 0
	for w: Array in _status_wants:
		if _merge_into(w[0], w[1], w[2], w[3], LIGHT_MERGE_M):
			continue
		if opened >= STATUS_LIGHTS_MAX:
			status_lights_dropped += 1
			continue
		opened += 1
		_light_wants.append([w[0], w[1], w[2], w[3], w[2]])
	_status_wants.clear()


## The status-light order: the brighter first, ties by place (x, then z), so a frame always picks the same ones.
static func _status_first(a: Array, b: Array) -> bool:
	if float(a[2]) != float(b[2]):
		return float(a[2]) > float(b[2])
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	if pa.x != pb.x:
		return pa.x < pb.x
	return pa.z < pb.z


## v0.8.0 FV: `n` pieces of pool `pool` for one effect, halved (rounded up) under pressure (PRESSURE).
func _thin(pool: StringName, n: int) -> int:
	if n <= 1 or not _pressed(pool):
		return n
	var keep := (n + 1) / 2
	pieces_thinned += n - keep
	return keep


## True while pool `pool` is past PRESSURE of its cap, or the frame's pieces past PRESSURE of MAX_SPRITES.
func _pressed(pool: StringName) -> bool:
	var p: Dictionary = pools.get(pool, NO_POOL)
	if p.is_empty():
		return false
	return (
		int(p["used"]) >= int(float(p["cap"]) * PRESSURE)
		or MAX_SPRITES - _sprite_left >= int(MAX_SPRITES * PRESSURE)
	)


## Takes the spot `p` for `kind` this frame unless a piece of that kind from another effect (`owner`) already
## stands within `spacing` m (on the floor plane). Overlapping patches then draw one layer of flames, not one per
## patch; one patch's own flames never thin each other.
func _claim(kind: StringName, p: Vector3, spacing: float, owner: int = -1) -> bool:
	var grid: Dictionary = _spots.get(kind, {})
	if grid.is_empty():
		_spots[kind] = grid
	var cell := Vector2i(floori(p.x / spacing), floori(p.z / spacing))
	var flat := Vector2(p.x, p.z)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for q: Array in grid.get(cell + Vector2i(dx, dz), []):
				var at: Vector3 = q[0]
				if (
					(owner < 0 or int(q[1]) != owner)
					and Vector2(at.x, at.z).distance_to(flat) < spacing
				):
					return false
	if not grid.has(cell):
		grid[cell] = []
	(grid[cell] as Array).append([p, owner])
	return true


static func h(a: int, b: int) -> float:
	return AttackFormCanvas._hash(a, b)


# --- Floor marks ----------------------------------------------------------------------------------------------
## Leaves (or keeps) a floor mark keyed `key`: texture `tex` (MARK_TEX) at `p` (ground) `r` across in colour `c`.
## It stays MARK_TICKS from its first call, then fades.
func mark(key: int, tex: StringName, p: Vector3, r: float, c: Color) -> void:
	if _mark_keys.has(key):
		return
	for s: Array in _marks:  # an overlapping mark of the same kind is enough (stacked decals go black)
		if s[1] == tex and (s[2] as Vector3).distance_to(p) < maxf(float(s[3]), r) * 0.9:
			_mark_keys[key] = true
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
	# P-8: a mark suppressed by an overlapping one keeps its key here but never joins _marks, the list keys are erased
	# through, so on a long floor the keys pile up; past a few times the cap the cache is rebuilt from the live marks
	# (a still-overlapping key is suppressed again by the same test on its next call).
	if _mark_keys.size() > DECALS * 4:
		_mark_keys.clear()
		for s: Array in _marks:
			_mark_keys[s[0]] = true
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
	return int((pools[pool] as Dictionary)["used"]) if pools.has(pool) else 0


## The light requests this frame (before the LIGHTS brightest are kept).
func lights_asked() -> int:
	return _light_wants.size()


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


# --- v0.8.0 AV: helpers for the attack views' drawers (FireballViews, StoneSpikeViews) -----------------------------
## v0.9.0 VX: one sprite of pool `pool` lying flat on the floor at `p`, `s` across (a ground ring); false when full.
func flat_sprite(pool: StringName, p: Vector3, s: float, c: Color, cell: int, roll: float) -> bool:
	return _put(pool, _flat(p, s, roll), c, cell, 0.0, 0.0)


## A light request merged into a cluster (_light_merged), for a drawer outside this class.
func light_merged(p: Vector3, c: Color, energy: float, rng: float, merge: float) -> void:
	_light_merged(p, c, energy, rng, merge)


## One camera-facing sprite of pool `pool` (POOLS) centred at `p`, `s` across, turned `roll`, atlas cell `cell`.
## False when the pool or the frame's sprite budget is full.
func sprite(pool: StringName, p: Vector3, s: float, c: Color, cell: int, roll: float) -> bool:
	return _put(pool, _facing(p, s, s, true, roll), c, cell, 0.0, 0.0)


## v0.8.0 GF2: a camera-facing streak of pool `pool` from `a` to `b`, `w` wide (a spark drawn along its path), atlas
## cell `cell`. False when the pool or the frame's sprite budget is full.
func streak(pool: StringName, a: Vector3, b: Vector3, w: float, c: Color, cell: int) -> bool:
	if a.distance_squared_to(b) < 1e-6:
		return _put(pool, _facing(a, w, w, true), c, cell, 0.0, 0.0)
	return _put(pool, _ribbon(a, b, w), c, cell, 0.0, 0.0)
