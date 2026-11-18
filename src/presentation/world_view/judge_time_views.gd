class_name JudgeTimeViews
extends Node3D
## The Clockwork Judge's Time Wave and what it leaves in the room, drawn from WorldReader.boss_time, boss_pickups and
## boss_shot_fields (EI-07: it reads; the cut, the walls and the slowed shots are the sim's).
## - The cast: a clock dial drawn in dull gold and ink lines on the floor under the Judge whose hand goes round once
##   through the cast, a thin gold ring closing on it, and the pack's rising area (cj_cast: lift_area_vfx_04) held on
##   it, pressed flat so its light stays on the floor and off the Judge.
## - The wave: when it lands (the `time_wave` event) a thin gold line ringed in ink, with a clock's ticks inside it,
##   runs out from the Judge across the whole room, and the pack's pulse (cj_pulse: pulse_area_vfx_04) bursts on the
##   hero it has just slowed.
## - The hour orbs: each is the pack's Basic Area 04 (cj_orb) sized to the disc the hero must touch, over a clock dial
##   of that exact radius, with a small brass clock standing above it (matte, lit by the sun, outlined by the ink
##   pass). An orb that runs down (the last phase) shows it: the clock's hand and the dial's go round once over its
##   life and the effect shrinks. Taking one bursts the pulse.
## - The stopped gears: each wall is the Judge's own gear (JudgeGearMesh: dark iron, a gold band and hub) standing
##   across the floor, set low enough that the hero shows over it, cutting the floor along the wall's whole length and
##   as thick as the wall, in a dark crack of the wall's exact footprint. It rolls up out of the floor when placed and
##   sinks back at its end, each time throwing up chunks, grit and dust of the floor's stone along its length
##   (GroundSlamViews).
## - The slow fields: a cool, dark blue rippling disc of the field's radius, its rim kept clear, under the pack's
##   ripple (cj_field: ripple_area_vfx_05 in dark blue, played slowly), fading over its last second.
## Every slot is built hidden at the start and the first orb and gear are marked for the floor's shader warm-up, so
## their materials are drawn once before the fight. Reduced motion
## stills the roll, the bob and the ripples. Nothing here decides an outcome.

const GOLD := JudgeViews.GOLD
const HOT := JudgeViews.HOT
const BRASS := Color("#B8862E")
const FACE := Color("#D9C89A")
const IRON := Color("#1E1C1F")
## The slow fields' blues: cooler and darker than the hero's cyan.
const COOL := Color(0.16, 0.26, 0.52)
const PALE := Color(0.5, 0.62, 0.82)
## The rings' gold, unlit and kept under the glow's threshold, and their ink.
const DULL := Color(0.86, 0.66, 0.3)
const INK := Color(0.07, 0.06, 0.08)
## The crack a gear stands in.
const CRACK := Color(0.06, 0.05, 0.06, 0.9)
const ORB_ID := &"cj_orb"
const FIELD_ID := &"cj_field"
const CAST_ID := &"cj_cast"
const PULSE_ID := &"cj_pulse"
const EFFECT_WAVE := &"time_wave"
## Slots built for each kind (the Judge's data asks for 3 orbs, 4 gears and 3 fields).
const ORBS := 6
const GEARS := 6
const FIELDS := 4
## The pack scenes' scale per metre of radius (basic area: a 3 m quad; ripple: 4 m; lift: 2.8 m; pulse: 4.5 m).
const ORB_PER_M := 0.7
const FIELD_PER_M := 0.52
const CAST_SCALE := 1.3
const PULSE_PER_M := 0.45
## The wave's ring: seconds to cross, how far it runs (past any boss room's corner), its line's width (m).
const WAVE_S := 0.9
const WAVE_REACH_M := 34.0
const WAVE_BAND_M := 0.22
## The cast's pack area pressed flat (its height's share), so its rising light stays below the Judge's knees.
const CAST_FLAT := 0.18
const CAST_DIAL_M := 3.4
const CAST_RING_FROM_M := 7.0
## The clock over an orb: its height, its bob, and how fast its hand turns while the orb does not run down.
const CLOCK_H := 1.55
const CLOCK_BOB := 0.08
const CLOCK_IDLE_TURN := TAU / 8.0
## How far the clock's face tips back from upright toward the sky (rad).
const CLOCK_TIP := 1.0
## A gear's rise and sink (ticks) and its teeth.
const GEAR_RISE_TICKS := 24.0
const GEAR_SINK_TICKS := 36.0
const GEAR_ROLL := 1.4
## The floor a gear throws up: grit and dust at points this far apart along it, and the chunks' share as it rises and
## as it sinks.
const GEAR_KICK_STEP_M := 0.8
const GEAR_KICK_SIZE := 0.32
const GEAR_CHUNKS_UP := 0.6
const GEAR_CHUNKS_DOWN := 0.35
const GEAR_SLAM_PARTS := GroundSlamViews.P_MID | GroundSlamViews.P_GRIT | GroundSlamViews.P_DUST
## How far under the floor a standing gear's axle lies, as a share of its radius (its top then stands 0.6 of it).
const GEAR_SUNK := 0.4
const FIELD_FADE_TICKS := 60.0
const FIELD_IN_TICKS := 18.0
const FIELD_SPEED := 0.45
const WAVE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 gold : source_color = vec4(1.0, 0.78, 0.3, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.95, 0.72, 1.0);
uniform float alpha = 0.0;
uniform float band = 0.1;
uniform float clock = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float turns = atan(q.y, q.x) / 6.2831853;
	float n = texture(noise_tex, vec2(turns * 3.0, r * 0.6 - clock * 0.2)).r;
	float edge = 1.0 - band;
	float front = smoothstep(band, 0.0, abs(r - edge));
	float wake = smoothstep(edge - band * 5.0, edge, r) * step(r, edge) * (0.2 + 0.6 * n);
	float ticks = step(0.7, fract(turns * 60.0)) * smoothstep(band * 1.5, 0.0, abs(r - (edge - band * 2.5)));
	float lit = max(front, max(wake * 0.6, ticks * 0.5));
	ALBEDO = mix(gold.rgb, hot.rgb, front) * (0.4 + 1.8 * lit);
	ALPHA = clamp(alpha * lit, 0.0, 1.0) * smoothstep(1.0, 0.97, r);
}
"""
## The Time Wave's ring and the cast's closing ring: a thin gold line edged in ink with a clock's ticks just inside,
## drawn over the floor without light of its own.
const TIME_RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 gold : source_color = vec4(0.86, 0.66, 0.3, 1.0);
uniform vec4 ink : source_color = vec4(0.07, 0.06, 0.08, 1.0);
uniform float alpha = 0.0;
uniform float band = 0.1;
uniform float clock = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float turns = atan(q.y, q.x) / 6.2831853;
	float edge = 1.0 - band * 2.0;
	float d = abs(r - edge);
	float line = smoothstep(band * 0.5, band * 0.3, d);
	float inked = smoothstep(band, band * 0.8, d);
	float td = abs(r - (edge - band * 3.0));
	float ticks = step(0.8, fract(turns * 60.0)) * smoothstep(band, band * 0.6, td);
	float lit = max(line, ticks);
	ALBEDO = mix(ink.rgb, gold.rgb, lit);
	ALPHA = clamp(alpha * max(lit, inked * 0.7), 0.0, 1.0) * smoothstep(1.0, 0.99, r);
}
"""
const FIELD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 cool : source_color = vec4(0.3, 0.55, 1.0, 1.0);
uniform vec4 pale : source_color = vec4(0.82, 0.92, 1.0, 1.0);
uniform float alpha = 0.0;
uniform float clock = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float turns = atan(q.y, q.x) / 6.2831853;
	float n = texture(noise_tex, UV * 1.5 + vec2(clock * 0.01, -clock * 0.008)).r;
	float rim = smoothstep(0.05, 0.0, abs(r - 0.95));
	float wave = 0.5 + 0.5 * sin((r * 4.0 + clock * 0.12) * 6.2831853);
	float ripple = wave * wave * wave * wave * (1.0 - r) * 0.8;
	float ticks = step(0.8, fract(turns * 12.0)) * smoothstep(0.06, 0.0, abs(r - 0.82));
	float inked = smoothstep(0.035, 0.015, abs(r - 0.985));
	float body = max(ripple * 0.4, ticks * 0.5);
	vec3 col = mix(cool.rgb, pale.rgb, max(rim, body * 0.6));
	ALBEDO = mix(col, vec3(0.05, 0.06, 0.09), inked * (1.0 - rim));
	ALPHA = clamp(alpha * max(inked * 0.9, rim + body + 0.16 + 0.08 * n), 0.0, 0.85);
	ALPHA *= smoothstep(1.0, 0.99, r);
}
"""

## The floor's chunks, grit and dust the gears throw up (WorldViewRoot hands it the biome's floor colours).
var slams := GroundSlamViews.new(8)
## The pack's effects (WorldViewRoot hands them over; a view built alone draws its own layers only).
var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _time := {}
var _orbs: Array = []
var _fields: Array = []
var _boss_at := Vector3.ZERO
var _hero_at := Vector3.ZERO
var _last_seq := 0
var _primed := false
var _clock := 0.0
## An orb's first `left` by its id: the whole life a running orb counts down from.
var _orb_life := {}
var _orb_nodes: Array[Node3D] = []
var _orb_dials: Array[ShaderMaterial] = []
var _orb_clocks: Array[Node3D] = []
var _orb_hands: Array[Node3D] = []
var _gear_nodes: Array[Node3D] = []
var _gear_wheels: Array[Node3D] = []
var _gear_strips: Array[MeshInstance3D] = []
## Per standing gear (by its place): 1 once it threw up the floor rising, 2 once it did sinking.
var _gear_kicked := {}
var _field_nodes: Array[MeshInstance3D] = []
var _field_mats: Array[ShaderMaterial] = []
var _wave := MeshInstance3D.new()
var _wave_mat := ShaderMaterial.new()
var _wave_t := WAVE_S
var _wave_at := Vector3.ZERO
var _cast_ring := MeshInstance3D.new()
var _cast_ring_mat := ShaderMaterial.new()
var _cast_dial := MeshInstance3D.new()
var _cast_dial_mat := ShaderMaterial.new()


func _init() -> void:
	name = "JudgeTimeViews"
	add_child(slams)
	var ring := Shader.new()
	ring.code = TIME_RING_SHADER
	var dial := Shader.new()
	dial.code = JudgeViews.ECHO_MARKER_SHADER
	var disc := Shader.new()
	disc.code = FIELD_SHADER
	for pair: Array in [[_wave, _wave_mat], [_cast_ring, _cast_ring_mat]]:
		_floor_quad(pair[0], pair[1], ring)
		(pair[1] as ShaderMaterial).set_shader_parameter("gold", DULL)
		(pair[1] as ShaderMaterial).set_shader_parameter("ink", INK)
	_floor_quad(_cast_dial, _cast_dial_mat, dial)
	JudgeViews.dial_colours(_cast_dial_mat)
	for k in ORBS:
		_build_orb(dial)
	for k in GEARS:
		_build_gear()
	_orb_nodes[0].set_meta(ShaderWarmup.WARM_META, true)
	_gear_nodes[0].set_meta(ShaderWarmup.WARM_META, true)
	for k in FIELDS:
		var mi := MeshInstance3D.new()
		var mat := ShaderMaterial.new()
		_floor_quad(mi, mat, disc)
		mat.set_shader_parameter("cool", COOL)
		mat.set_shader_parameter("pale", PALE)
		_field_nodes.append(mi)
		_field_mats.append(mat)


## A hidden 2 m floor quad on its own material of `shader` (scaled to a radius when drawn).
func _floor_quad(mi: MeshInstance3D, mat: ShaderMaterial, shader: Shader, to: Node = null) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	mi.mesh = plane
	mat.shader = shader
	mat.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	(to if to != null else self).add_child(mi)


## A matte part lit like the game's models (JudgeGearMesh.lit()), seen from either side.
static func _solid(c: Color) -> StandardMaterial3D:
	var m := JudgeGearMesh.lit(c)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _part(to: Node3D, mesh: Mesh, mat: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	to.add_child(mi)
	return mi


## An orb's slot: the dial on the floor (scaled to the orb's radius) and the small clock above it: a faceted brass
## case (eight sides, thicker than its face, so it shows its edge), a parchment face, four hour marks and two hands,
## turned to the camera and tipped back to the sky when drawn.
func _build_orb(dial: Shader) -> void:
	var node := Node3D.new()
	node.visible = false
	add_child(node)
	var mi := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	_floor_quad(mi, mat, dial, node)
	mi.visible = true
	JudgeViews.dial_colours(mat)
	var clock := Node3D.new()
	clock.rotation = Vector3(-0.6, 0.0, 0.0)
	node.add_child(clock)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.37
	rim.bottom_radius = 0.37
	rim.height = 0.16
	rim.radial_segments = 8
	rim.rings = 1
	var flat := Vector3(PI * 0.5, 0.0, 0.0)  # a cylinder stood on its edge, its faces along Z
	_part(clock, rim, _solid(BRASS)).rotation = flat
	var face := CylinderMesh.new()
	face.top_radius = 0.28
	face.bottom_radius = 0.28
	face.height = 0.18
	face.radial_segments = 8
	face.rings = 1
	_part(clock, face, _solid(FACE)).rotation = flat
	var iron := _solid(IRON)
	var mark := BoxMesh.new()
	mark.size = Vector3(0.035, 0.07, 0.02)
	for h in 4:
		var a := TAU * float(h) / 4.0
		var m := _part(clock, mark, iron, Vector3(sin(a) * 0.21, cos(a) * 0.21, 0.095))
		m.rotation.z = -a
	var hand := Node3D.new()
	hand.position = Vector3(0, 0, 0.105)
	clock.add_child(hand)
	var long := BoxMesh.new()
	long.size = Vector3(0.04, 0.24, 0.02)
	_part(hand, long, iron, Vector3(0, 0.11, 0))
	var short := BoxMesh.new()
	short.size = Vector3(0.05, 0.15, 0.02)
	_part(clock, short, iron, Vector3(0.05, 0.04, 0.1)).rotation.z = -1.0
	_orb_nodes.append(node)
	_orb_dials.append(mat)
	_orb_clocks.append(clock)
	_orb_hands.append(hand)


## A gear's slot: the Judge's gear (a unit wheel scaled to the wall's half length and its width), casting its shadow,
## and the dark crack of the wall's footprint it stands in.
func _build_gear() -> void:
	var node := Node3D.new()
	node.visible = false
	add_child(node)
	var wheel := Node3D.new()
	node.add_child(wheel)
	var gear := _part(wheel, JudgeGearMesh.mesh(), JudgeGearMesh.material())
	gear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var crack := StandardMaterial3D.new()
	crack.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crack.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crack.albedo_color = CRACK
	var strip := _part(node, box, crack)
	_gear_nodes.append(node)
	_gear_wheels.append(wheel)
	_gear_strips.append(strip)


## The biome's floor colours for the stone the gears throw up.
func floor_palette(palette: Dictionary) -> void:
	slams.floor_palette(palette)


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	_time = reader.boss_time()
	_orbs = reader.boss_pickups()
	_fields = reader.boss_shot_fields()
	_hero_at = SimPlane.to_3d(reader.actor_pos(0))
	if not _time.is_empty():
		_boss_at = SimPlane.to_3d(reader.actor_pos(int(_time["boss"])))
	var known := {}
	for o: Dictionary in _orbs:
		known[o["id"]] = true
		if int(o["left"]) >= 0 and not _orb_life.has(o["id"]):
			_orb_life[o["id"]] = maxi(1, int(o["left"]))
	for id: int in _orb_life.keys():
		if not known.has(id):
			_orb_life.erase(id)
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == EFFECT_WAVE:
			_fire_wave(SimPlane.to_3d(e.pos))
		elif e.kind == SimEvent.Kind.BOSS_PICKUP_TAKEN:
			_burst(SimPlane.to_3d(e.pos, 0.1), 1.2)
	_kick_gears()


## Each gear throws up the floor once as it rises out of it and once as it starts to sink (one met already standing,
## a fight joined under way, only as it sinks).
func _kick_gears() -> void:
	var seen := {}
	for g: Dictionary in _time.get("gears", []):
		var key := "%s/%d" % [g["centre"], int(g["angle"])]
		seen[key] = true
		var was := int(_gear_kicked.get(key, 0))
		if not _gear_kicked.has(key):
			was = 0 if float(g["age"]) < GEAR_RISE_TICKS * 0.5 else 1
			if was == 0:
				_gear_debris(g, GEAR_CHUNKS_UP)
				was = 1
		if was == 1 and float(g["left"]) <= GEAR_SINK_TICKS:
			_gear_debris(g, GEAR_CHUNKS_DOWN)
			was = 2
		_gear_kicked[key] = was
	for key: String in _gear_kicked.keys():
		if not seen.has(key):
			_gear_kicked.erase(key)


## Chunks of the floor round gear row `g`'s middle (`chunks` of the slam's share) and grit and dust all along it.
func _gear_debris(g: Dictionary, chunks: float) -> void:
	var half: Vector2 = g["half"]
	var at := SimPlane.to_3d(g["centre"])
	var along := Basis(Vector3.UP, SimPlane.yaw_of(int(g["angle"]))) * Vector3.RIGHT
	var n := clampi(int(half.x * 2.0 / GEAR_KICK_STEP_M) + 1, 3, 9)
	var points: Array = []
	for k in n:
		points.append(at + along * lerpf(-half.x, half.x, float(k) / float(n - 1)))
	slams.kick(points, GEAR_KICK_SIZE)
	slams.slam(at, maxf(1.4, half.x), {"parts": GEAR_SLAM_PARTS, "amount": chunks})


## The wave lands: the ring starts from the Judge, the pulse bursts on the hero it slowed.
func _fire_wave(at: Vector3) -> void:
	_wave_at = at
	_wave_t = 0.0
	_burst(_hero_at + Vector3(0, 0.1, 0), 1.0)


func _burst(at: Vector3, radius: float) -> void:
	if pack_fx != null and pack_fx.has_id(PULSE_ID) and pack_fx.has_room(&"impact"):
		pack_fx.spawn(PULSE_ID, at, radius * PULSE_PER_M)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	var idle := _time.is_empty() and _orbs.is_empty() and _fields.is_empty() and _wave_t >= WAVE_S
	if idle:
		if quiet:
			return
		quiet = true
	else:
		quiet = false
	_clock += delta * (0.0 if ViewPrefs.reduced_motion else 1.0)
	hold.begin()
	_draw_cast()
	_draw_wave(delta)
	_draw_orbs()
	_draw_gears()
	_draw_fields()
	hold.end()


## The cast: the dial's hand goes round once, the ring closes on the Judge, the pack's area rises from it.
func _draw_cast() -> void:
	var p := float(_time.get("wave", -1)) / 1000.0
	var on := p >= 0.0
	_cast_dial.visible = on
	_cast_ring.visible = on
	if not on:
		return
	_cast_dial.position = _boss_at + Vector3(0, 0.05, 0)
	_cast_dial.scale = Vector3.ONE * CAST_DIAL_M
	_cast_dial_mat.set_shader_parameter("heat", p)
	_cast_dial_mat.set_shader_parameter("alpha", 0.5 + 0.5 * p)
	_cast_dial_mat.set_shader_parameter("clock", _clock)
	var r := lerpf(CAST_RING_FROM_M, 1.4, p)
	_cast_ring.position = _boss_at + Vector3(0, 0.07, 0)
	_cast_ring.scale = Vector3.ONE * r
	_cast_ring_mat.set_shader_parameter("alpha", 0.25 + 0.6 * p)
	_cast_ring_mat.set_shader_parameter("band", clampf(0.16 / r, 0.004, 0.12))
	_cast_ring_mat.set_shader_parameter("clock", _clock)
	var flat := Basis.from_scale(Vector3(CAST_SCALE, CAST_SCALE * CAST_FLAT, CAST_SCALE))
	hold.put(&"cast", CAST_ID, &"status", Transform3D(flat, _boss_at + Vector3(0, 0.05, 0)))


func _draw_wave(delta: float) -> void:
	_wave_t = minf(WAVE_S, _wave_t + delta)
	var on := _wave_t < WAVE_S
	_wave.visible = on
	if not on:
		return
	var u := _wave_t / WAVE_S
	var r := wave_radius()
	_wave.position = _wave_at + Vector3(0, 0.09, 0)
	_wave.scale = Vector3.ONE * r
	_wave_mat.set_shader_parameter("alpha", 1.0 - u * u)
	_wave_mat.set_shader_parameter("band", clampf(WAVE_BAND_M / r, 0.004, 0.1))
	_wave_mat.set_shader_parameter("clock", _clock)


static func _at(pos: Vector3, scale: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * scale), pos)


## How much of its life orb `o` has left, 1 for one that stays until taken.
func orb_share(o: Dictionary) -> float:
	if int(o["left"]) < 0:
		return 1.0
	return clampf(
		float(o["left"]) / float(_orb_life.get(o["id"], maxi(1, int(o["left"])))), 0.0, 1.0
	)


func _draw_orbs() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	for k in ORBS:
		var node := _orb_nodes[k]
		node.visible = k < _orbs.size()
		if not node.visible:
			continue
		var o: Dictionary = _orbs[k]
		var radius := float(o["radius"])
		var share := orb_share(o)
		var runs := int(o["left"]) >= 0
		var grow := clampf(float(o["age"]) / 15.0, 0.0, 1.0)
		node.position = SimPlane.to_3d(o["centre"])
		var dial := node.get_child(0) as Node3D
		dial.position = Vector3(0, 0.05 + 0.002 * k, 0)
		dial.scale = Vector3.ONE * radius
		var mat := _orb_dials[k]
		mat.set_shader_parameter("heat", 1.0 - share if runs else 0.0)
		mat.set_shader_parameter("alpha", 0.75 * grow)
		mat.set_shader_parameter("clock", _clock + 0.37 * k)
		var clock := _orb_clocks[k]
		clock.position = Vector3(0, CLOCK_H + CLOCK_BOB * sin(_clock * 2.4 + k), 0)
		clock.scale = Vector3.ONE * (0.4 + 0.6 * grow)
		if cam != null:  # turned to the camera and tipped back to the sky, so the room's light falls on its face
			var back := cam.global_basis.z
			var face := Basis(Vector3.UP, atan2(back.x, back.z)) * Basis(Vector3.RIGHT, -CLOCK_TIP)
			clock.global_basis = face.scaled(clock.scale)
		var turn := TAU * (1.0 - share) if runs else _clock * CLOCK_IDLE_TURN
		_orb_hands[k].rotation.z = -turn
		var size := radius * ORB_PER_M * grow * (0.55 + 0.45 * share)
		hold.put([&"orb", o["id"]], ORB_ID, &"area", _at(node.position + Vector3(0, 0.06, 0), size))


func _draw_gears() -> void:
	var gears: Array = _time.get("gears", [])
	for k in GEARS:
		var node := _gear_nodes[k]
		node.visible = k < gears.size()
		if not node.visible:
			continue
		var g: Dictionary = gears[k]
		var half: Vector2 = g["half"]
		var up := gear_raised(g)
		node.position = SimPlane.to_3d(g["centre"])
		node.rotation.y = SimPlane.yaw_of(int(g["angle"]))
		var wheel := _gear_wheels[k]
		var r := half.x / sqrt(1.0 - GEAR_SUNK * GEAR_SUNK)  # the floor cuts it along the wall's length
		wheel.scale = Vector3(r, r, half.y * 2.0)
		wheel.position.y = -r * lerpf(1.05, GEAR_SUNK, up)
		wheel.rotation.z = 0.0 if ViewPrefs.reduced_motion else GEAR_ROLL * (1.0 - up)
		var strip := _gear_strips[k]
		strip.scale = Vector3(half.x * 2.0, 0.04, half.y * 2.0)
		strip.position.y = 0.03


## 0..1: how far gear row `g` stands out of the floor (it rises when placed and sinks over its last moments).
static func gear_raised(g: Dictionary) -> float:
	var rise := clampf(float(g["age"]) / GEAR_RISE_TICKS, 0.0, 1.0)
	var sink := clampf(float(g["left"]) / GEAR_SINK_TICKS, 0.0, 1.0)
	return ease(minf(rise, sink), 0.4)


func _draw_fields() -> void:
	for k in FIELDS:
		var mi := _field_nodes[k]
		mi.visible = k < _fields.size()
		if not mi.visible:
			continue
		var f: Dictionary = _fields[k]
		var radius := float(f["radius"])
		var fade := clampf(float(f["age"]) / FIELD_IN_TICKS, 0.0, 1.0)
		if int(f["left"]) >= 0:
			fade = minf(fade, clampf(float(f["left"]) / FIELD_FADE_TICKS, 0.0, 1.0))
		var at := SimPlane.to_3d(f["centre"])
		mi.position = at + Vector3(0, 0.04 + 0.002 * k, 0)
		mi.scale = Vector3.ONE * radius
		_field_mats[k].set_shader_parameter("alpha", 0.7 * fade)
		_field_mats[k].set_shader_parameter("clock", _clock)
		var size := radius * FIELD_PER_M * (0.6 + 0.4 * fade)
		var n := hold.put(
			[&"field", f["id"]], FIELD_ID, &"area", _at(at + Vector3(0, 0.06, 0), size)
		)
		if n != null and "speed_scale" in n and not pack_fx.is_held():
			n.set("speed_scale", FIELD_SPEED)


## Tests and the shot scripts: what is drawn now.
func orbs_shown() -> int:
	return _orb_nodes.filter(func(n: Node3D) -> bool: return n.visible).size()


func orb_position(k: int) -> Vector3:
	return _orb_nodes[k].position


func orb_dial_radius(k: int) -> float:
	return (_orb_nodes[k].get_child(0) as Node3D).scale.x


func orb_hand_turn(k: int) -> float:
	return -_orb_hands[k].rotation.z


func gears_shown() -> int:
	return _gear_nodes.filter(func(n: Node3D) -> bool: return n.visible).size()


## Gear slot k's footprint as drawn: {"centre" (sim plane), "half" (its strip: half length, half width), "wheel"
## (half the length the floor cuts its wheel along, half its thickness), "yaw", "raised" (m its wheel's top stands
## over the floor)}.
func gear_footprint(k: int) -> Dictionary:
	var node := _gear_nodes[k]
	var strip := _gear_strips[k]
	var wheel := _gear_wheels[k]
	return {
		"centre": SimPlane.to_sim(node.position),
		"half": Vector2(strip.scale.x, strip.scale.z) * 0.5,
		"wheel":
		Vector2(sqrt(maxf(0.0, wheel.scale.x ** 2 - wheel.position.y ** 2)), wheel.scale.z * 0.5),
		"yaw": node.rotation.y,
		"raised": wheel.scale.y + wheel.position.y,
	}


func fields_shown() -> int:
	return _field_nodes.filter(func(n: MeshInstance3D) -> bool: return n.visible).size()


func field_radius(k: int) -> float:
	return _field_nodes[k].scale.x


func field_alpha(k: int) -> float:
	return float(_field_mats[k].get_shader_parameter("alpha"))


func cast_shown() -> bool:
	return _cast_dial.visible


func wave_live() -> bool:
	return _wave_t < WAVE_S


## The wave ring's radius now (m).
func wave_radius() -> float:
	return lerpf(1.0, WAVE_REACH_M, ease(_wave_t / WAVE_S, 0.6))
