class_name StressMarkViews
extends Node3D
## v0.9.5 SM (owner: "one of their sides with a small orange arc (textured detail) marked, up right left or down"):
## the Stress Mark's weak sides (WorldReader.stress_mask) drawn on the enemies within the card's radius of the hero
## as a small orange arc on the ground just outside the enemy's footprint, on the marked screen side.
## - an arc is a flat quad with a code-drawn texture (a thin bright band with small notches, one ImageTexture made
##   once and cached), additive, unshaded, fog off; the texture's alpha is zero outside the arc, so no square shows;
## - it pulses gently (the shader's TIME: presentation only, never an outcome);
## - a side the sim breaks (STRESS_BREAK) flashes white and grows for FLASH_FRAMES while the view asks for a burst
##   of sparks (`bursts`; WorldViewRoot hands them to the impact layer, scaled by Effects density);
## - a side that leaves for any other reason (death, out of range, the card gone) is just hidden.
## Pooled: nodes are made once in _init. Presentation only (EI-07).

const ORANGE := Color("#FF8A2A")
const WHITE := Color("#FFF4E0")
const POOL := 48
const FLASH_FRAMES := 12
const ARC_DEG := 90.0
const GAP_M := 0.18
const Y := 0.05
const TEX_SIZE := 128
## The ring's radius and thickness as a share of the texture's half size, the notch count over the arc.
const RING_OUTER := 0.96
const RING_INNER := 0.78
const NOTCHES := 8

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D arc : filter_linear_mipmap, repeat_disable;
uniform vec4 color : source_color = vec4(1.0, 0.54, 0.16, 1.0);
uniform float flash = 0.0;
uniform float strength = 1.0;
void fragment() {
	vec4 t = texture(arc, UV);
	float pulse = 0.82 + 0.18 * sin(TIME * 4.0);
	vec3 c = mix(color.rgb, vec3(1.0, 0.96, 0.88), flash);
	ALBEDO = c * t.a * strength * mix(pulse, 1.6, flash);
}
"""

static var _tex: ImageTexture
static var _shader: Shader

## What the last sync drew (tests read them).
var drawn := 0
## Breaks seen by the last sync: [position (sim plane), outward direction (sim plane), tick].
var bursts: Array = []
var _quads: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _key := PackedInt32Array()  # actor id * 4 + side, or -1 for a free slot
var _age := PackedInt32Array()  # frames since it broke, or -1 while it stands
var _base := PackedFloat32Array()  # the quad's size in metres
var _last_seq := 0


func _init() -> void:
	name = "StressMarks"
	for k in POOL:
		var q := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		q.mesh = plane
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = shader()
		m.set_shader_parameter("arc", arc_texture())
		q.material_override = m
		q.visible = false
		add_child(q)
		_quads.append(q)
		_mats.append(m)
		_key.append(-1)
		_age.append(-1)
		_base.append(1.0)


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader


## The arc's texture, made once: a ring band over ARC_DEG centred on +X (u), a bright core line with a softer edge,
## notches cut across the band, and zero alpha everywhere else (the edge mask).
static func arc_texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var half := ARC_DEG * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var u := (float(x) + 0.5) / TEX_SIZE * 2.0 - 1.0
			var v := (float(y) + 0.5) / TEX_SIZE * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var a := 0.0
			if r >= RING_INNER and r <= RING_OUTER and u > 0.0:
				var deg := rad_to_deg(atan2(v, u))
				if absf(deg) <= half:
					var across := (r - RING_INNER) / (RING_OUTER - RING_INNER)  # 0..1
					var core := 1.0 - absf(across - 0.5) * 2.0  # 1 on the middle line
					a = clampf(0.35 + core * 0.9, 0.0, 1.0)
					var along := (deg + half) / ARC_DEG * NOTCHES
					if across > 0.62 and fposmod(along, 1.0) < 0.16:
						a *= 0.15  # a notch cut in the outer edge
					a *= clampf((half - absf(deg)) / 6.0, 0.0, 1.0)  # the ends fade out
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex


func sync(reader: WorldReader) -> void:
	bursts = []
	var radius := reader.stress_radius_m()
	var player := reader.player_pos()
	var want := {}  # key -> actor index
	if radius > 0.0:
		var r2 := radius * radius
		for i in range(1, reader.actor_count()):
			if reader.actor_dead(i) or reader.actor_team(i) != WorldReader.TEAM_ENEMY:
				continue
			if reader.actor_pos(i).distance_squared_to(player) > r2:
				continue
			var m := reader.stress_mask(i)
			if m == 0:
				continue
			for s in 4:
				if m & (1 << s):
					want[reader.actor_id(i) * 4 + s] = i
	var broke := {}
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.STRESS_BREAK:
			broke[e.target_id * 4 + e.amount_applied] = e
	drawn = 0
	for k in POOL:  # standing arcs that went: a break flashes, anything else hides
		if _key[k] >= 0 and _age[k] < 0 and not want.has(_key[k]):
			if broke.has(_key[k]):
				_age[k] = 0
				var ev: SimEvent = broke[_key[k]]
				bursts.append([ev.pos, WorldReader.stress_side_dir(ev.amount_applied), ev.tick])
			else:
				_free(k)
	for key: int in want:
		var slot := _slot_of(key)
		if slot < 0:
			slot = _free_slot()
			if slot < 0:
				continue  # past the pool: not drawn
			_key[slot] = key
			_age[slot] = -1
		if _age[slot] < 0:
			_place(slot, reader, int(want[key]), key % 4)
	for k in POOL:
		if _key[k] >= 0 and _age[k] >= 0:
			_age[k] += 1
			if _age[k] > FLASH_FRAMES:
				_free(k)
			else:
				_flash(k)
		if _quads[k].visible:
			drawn += 1


func _slot_of(key: int) -> int:
	return _key.find(key)


func _free_slot() -> int:
	return _key.find(-1)


func _free(k: int) -> void:
	_key[k] = -1
	_age[k] = -1
	_quads[k].visible = false


func _place(k: int, reader: WorldReader, i: int, side: int) -> void:
	var rad := (reader.actor_radius(i) + GAP_M) / RING_INNER
	var q := _quads[k]
	q.position = SimPlane.to_3d(reader.actor_pos(i), Y)
	q.rotation = Vector3(0.0, SimPlane.yaw_of(WorldReader.stress_side_angle(side)), 0.0)
	_base[k] = rad * 2.0
	q.scale = Vector3(_base[k], 1.0, _base[k])
	_mats[k].set_shader_parameter("flash", 0.0)
	_mats[k].set_shader_parameter("strength", 1.0)
	q.visible = true


func _flash(k: int) -> void:
	var u := float(_age[k]) / FLASH_FRAMES
	var q := _quads[k]
	var size := _base[k] * (1.0 + 0.35 * u)
	q.scale = Vector3(size, 1.0, size)
	_mats[k].set_shader_parameter("flash", 1.0)
	_mats[k].set_shader_parameter("strength", 1.0 - u)


## Pool reads (tests): the quad of (actor id, side), or null.
func quad_of(actor_id: int, side: int) -> MeshInstance3D:
	var k := _slot_of(actor_id * 4 + side)
	return null if k < 0 or not _quads[k].visible else _quads[k]


func flashing() -> int:
	var n := 0
	for k in POOL:
		n += 1 if _key[k] >= 0 and _age[k] >= 0 else 0
	return n
