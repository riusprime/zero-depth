class_name FinalBossViews
extends Node3D
## v0.8.0 FB1 (owner O16; FINAL_BOSS.md F3: "at each segment's end the body shatters in a burst … the next rises from
## the shards"): the shatter between two of the final boss's bodies. While a body shatters (WorldReader
## .final_shattering) a ring of crystal light gathers round it and grows brighter; the tick the sim removes it, it
## bursts:
## SHARDS stone-and-crystal shards fly out and land round where it stood, with a flash of light; while the next body
## rises (its intro), the shards lift off the floor, spiral in and sink into it, and are gone when it stands. Reads
## only (EI-07): the body's state, the fight's phase and positions from WorldReader; the shards' flight is frame time
## from the cosmetic hash (VfxCore.h), still with reduced motion (no spin, a straight fall). One MultiMesh, one light.

const SHARDS := 36
## Seconds the shards fly out and fall; how far they go (m); their size (m).
const FLY_S := 0.7
const FLY_M := Vector2(1.5, 4.5)
const SHARD_M := Vector2(0.25, 0.6)
const GLOW := Color("#C060FF")
const HOT := Color("#FF3A5A")
## The gathering ring's radius over the boss's (m) and its light's range.
const RING_M := 0.6
const LIGHT_RANGE := 9.0
## v0.8.0 TX2: seconds the owner's crystal shatter bursts flare (draw_fx).
const BURST_FX_S := 0.55

const SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert;

uniform vec4 stone : source_color = vec4(0.23, 0.18, 0.32, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.23, 0.35, 1.0);
varying float heat;

void vertex() {
	heat = INSTANCE_CUSTOM.r;
}

void fragment() {
	ALBEDO = stone.rgb;
	EMISSION = glow.rgb * (0.6 + 3.0 * heat);
	ROUGHNESS = 0.6;
}
"""

## Live shards: [from (Vector3, the burst's centre), out (Vector3, where it lands), spin axis, size, seed].
var _shards: Array = []
## Seconds since the last burst (-1 none), and how far the next body's rise has run (0..1, -1 none).
var _age := -1.0
var _rise := -1.0
var _rise_at := Vector3.ZERO
## The shattering body seen last sync: [actor id, centre, radius] (empty when none).
var _watch: Array = []
var _shatter := 0.0
var _phase := -1
var _node := MultiMeshInstance3D.new()
var _ring := MeshInstance3D.new()
var _ring_mat := StandardMaterial3D.new()
var _light := OmniLight3D.new()
var _bursts := 0
## v0.8.0 TX2: where the last burst was and the burst body's radius (draw_fx).
var _burst_at := Vector3.ZERO
var _burst_r := 1.0


func _init() -> void:
	name = "FinalBossViews"
	# v0.8.0 N1 (O55, the lighting audit): the ring, the shards and their light are laid out in _process on frame
	# time: no physics interpolation on top (the light jumped from the ring to a burst over a tick).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = BossParts.crystal(1.0, 0.45, 77)
	mm.instance_count = SHARDS
	mm.visible_instance_count = 0
	_node.multimesh = mm
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = SHADER
	sm.set_shader_parameter("glow", HOT)
	_node.material_override = sm
	_node.extra_cull_margin = 64.0
	_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_node)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 32
	_ring.mesh = torus
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_color = Color(GLOW, 0.0)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	_light.light_color = GLOW
	_light.omni_range = LIGHT_RANGE
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)


func sync(reader: WorldReader) -> void:
	if not reader.final_fight():
		return
	var i := reader.boss_index()
	var id := reader.actor_id(i) if i >= 0 else -1
	# The body we watched shattering is gone: it bursts where it stood.
	if not _watch.is_empty() and int(_watch[0]) != id:
		_burst(_watch[1], _watch[2], reader.tick())
		_watch = []
	_shatter = reader.final_shatter_permille() / 1000.0 if reader.final_shattering() else 0.0
	if i >= 0 and reader.actor_state(i) == WorldReader.STATE_SHATTER:
		_watch = [id, SimPlane.to_3d(reader.actor_pos(i)), reader.actor_radius(i)]
	# The next body rising (its intro) pulls the shards in.
	if i >= 0 and reader.actor_state(i) == WorldReader.STATE_SPAWN and not _shards.is_empty():
		_rise = reader.boss_intro_permille(i) / 1000.0
		_rise_at = SimPlane.to_3d(reader.actor_pos(i))
	elif _rise >= 0.0 and (i < 0 or reader.actor_state(i) != WorldReader.STATE_SPAWN):
		_rise = -1.0
		_shards.clear()
	_phase = reader.final_phase()


func _process(delta: float) -> void:
	if _age >= 0.0:
		_age += delta
	_draw_ring()
	_draw_shards()


## The bursts so far (tests and the tour).
func burst_count() -> int:
	return _bursts


## Shards alive (tests).
func shard_count() -> int:
	return _shards.size()


## 0..1: the gathering ring's strength now (tests).
func ring_amount() -> float:
	return _shatter


## v0.8.0 TX2: a VfxCore drawer (WorldViewRoot adds it with the new look): the owner's crystal shatter bursts
## (fx_crystal_shatter) flaring where the body burst over its first BURST_FX_S, a big one in the middle and three
## smaller round it, growing as they fade. Frame time like the shards; nothing without the texture.
func draw_fx(layer: VfxCore) -> void:
	if _age < 0.0 or _age >= BURST_FX_S or not VfxCore.has_tex("fx_crystal_shatter"):
		return
	var u := _age / BURST_FX_S
	var fade := (1.0 - u) * (1.0 - u)
	var c := _burst_at + Vector3(0, 1.4, 0)
	var big := (_burst_r * 2.0 + 2.5) * (0.6 + 0.6 * u)
	layer.sprite(&"shatter", c, big, Color(1.4, 1.2, 1.25, fade), _bursts % 4, 0.0)
	for k in 3:
		var a := TAU * (k + VfxCore.h(_bursts, k)) / 3.0
		var off := Vector3(cos(a), 0.3 * (VfxCore.h(_bursts + 1, k) - 0.5), sin(a)) * big * 0.35
		layer.sprite(
			&"shatter",
			c + off * (0.6 + u),
			big * 0.45,
			Color(1.3, 1.1, 1.2, fade),
			(_bursts + k + 1) % 4,
			a
		)


func _burst(at: Vector3, radius: float, tick: int) -> void:
	_bursts += 1
	_age = 0.0
	_burst_at = at
	_burst_r = radius
	_rise = -1.0
	_shards.clear()
	var sd := tick * 37 + _bursts * 101
	for k in SHARDS:
		var a := TAU * VfxCore.h(sd, k)
		var d := lerpf(FLY_M.x, FLY_M.y, VfxCore.h(sd + 1, k)) + radius
		var out := at + Vector3(cos(a), 0.0, sin(a)) * d
		var axis := (
			Vector3(VfxCore.h(sd + 2, k) - 0.5, 1.0, VfxCore.h(sd + 3, k) - 0.5).normalized()
		)
		var size := lerpf(SHARD_M.x, SHARD_M.y, VfxCore.h(sd + 4, k))
		_shards.append([at + Vector3(0, 1.4, 0), out, axis, size, VfxCore.h(sd + 5, k)])
	_light.position = at + Vector3(0, 1.5, 0)


func _draw_ring() -> void:
	_ring.visible = _shatter > 0.0 and not _watch.is_empty()
	if not _ring.visible:
		_light.light_energy = maxf(0.0, 4.0 * (1.0 - _age / 0.5)) if _age >= 0.0 else 0.0
		return
	var c: Vector3 = _watch[1]
	var r := float(_watch[2]) + RING_M + 1.4 * (1.0 - _shatter)
	_ring.position = c + Vector3(0, 0.15 + 1.6 * _shatter, 0)
	_ring.scale = Vector3(r, 1.0, r)
	_ring_mat.albedo_color = Color(GLOW, 0.25 + 0.6 * _shatter)
	_light.position = c + Vector3(0, 1.5, 0)
	_light.light_energy = 1.0 + 3.0 * _shatter


func _draw_shards() -> void:
	var mm := _node.multimesh
	if _shards.is_empty():
		mm.visible_instance_count = 0
		return
	var still := ViewPrefs.reduced_motion
	var fly := clampf(_age / FLY_S, 0.0, 1.0) if _age >= 0.0 else 1.0
	var buf := PackedFloat32Array()
	var n := 0
	for s: Array in _shards:
		var from: Vector3 = s[0]
		var out: Vector3 = s[1]
		var p := from.lerp(out, fly)
		p.y = lerpf(from.y, 0.12, fly) + (0.0 if still else 2.2 * fly * (1.0 - fly))
		var size: float = s[3]
		var heat := 1.0 - fly * 0.7
		if _rise >= 0.0:  # pulled in by the rising body, sinking into it
			var k := smoothstep(0.0, 1.0, _rise)
			var swirl := 0.0 if still else (1.0 - k) * 1.5
			var off := (out - _rise_at).rotated(Vector3.UP, swirl)
			p = (_rise_at + off * (1.0 - k)) + Vector3(0, 0.12 + 1.6 * sin(k * PI) * 0.6, 0)
			size *= 1.0 - 0.8 * k
			heat = 0.3 + 0.7 * k
		var spin := 0.0 if still else (_age * 6.0 * float(s[4]) if fly < 1.0 else float(s[4]) * 3.0)
		var b := Basis(s[2] as Vector3, spin).scaled(Vector3.ONE * size)
		buf.append_array(
			[
				b.x.x,
				b.y.x,
				b.z.x,
				p.x,
				b.x.y,
				b.y.y,
				b.z.y,
				p.y,
				b.x.z,
				b.y.z,
				b.z.z,
				p.z,
				heat,
				0.0,
				0.0,
				0.0
			]
		)
		n += 1
	buf.resize(mm.instance_count * 16)
	mm.buffer = buf
	mm.visible_instance_count = n
