class_name TideDanceViews
extends Node3D
## The Tidecaller's Riptide and High Tide, drawn from WorldReader.boss_dance (EI-07: it reads; which strip is struck,
## the wave's front, the dry circle and every hit are the sim's, BossDance).
## - Riptide, the warning: each of the four strips is a floor quad of the reader's exact rectangle. The three struck
##   ones fill with clear water that rises with `warn` (streaks running along the strip, a foam edge) and the pack's
##   water ripple (tc_rip_water) on each; the dry one stays clear, a warm tint inside a bright pulsing border.
## - Riptide, the wave: a wall of water runs down each struck strip at `front` (the crossing waves' curling band,
##   TideWaveViews.wave_mesh, three times as tall and as wide as the strip), the strip behind it flooded, the ripple
##   riding the front; a hit (`riptide_hit`) bursts the pack's splash (tc_splash) on the hero.
## - High Tide: through the cast a room-sized water plane rises everywhere but the dry circle (caustics, a foam line at
##   the waterline), full while it floods and draining on `high_tide_end`. The dry circle is a warm disc of the exact
##   `radius` at `centre` with a bright rim, the pack's rim (tc_dry) on it, and a ring that fills through the cast and
##   shrinks with the flood's time left. A hero outside it in the flood is splashed on each of the sim's steps (and the
##   HUD's edge glow, flooding()).
## - The cast on the Tidecaller: the pack's rising water (tc_cast) under it through a Riptide warning or a High Tide
##   cast (its avatar tolls the bell meanwhile, TidecallerAvatar).
## The floor layers draw under every telegraph (render_priority) and never hide the hero. Every slot is built hidden
## at the start (the floor's shader warm-up draws it). Reduced motion stills the streaks, the pulse and the caustics.
## Nothing here decides an outcome.

const STRIPS := 4
const SEA := Color(0.42, 0.86, 1.0)
const DEEP := Color(0.04, 0.22, 0.5)
const FOAM := Color(0.9, 0.98, 1.0)
const DRY := Color(1.0, 0.86, 0.5)
const WATER_ID := &"tc_rip_water"
const SPLASH_ID := &"tc_splash"
const DRY_ID := &"tc_dry"
const CAST_ID := &"tc_cast"
const EFFECT_HIT := &"riptide_hit"
const EFFECT_TIDE_END := &"high_tide_end"
## The wall of water: its depth along the run (m) and its height over the crossing waves' crest.
const WALL_DEPTH_M := 2.4
const WALL_RISE := 3.0
## The wall rises out of the floor over this share of the run and sinks over the last of it.
const WALL_IN := 0.06
const WALL_OUT := 0.08
## The pack scenes' scale per metre of radius (ripple: about 1.7 m at 1; rim: 0.55; pulse: 0.45; lift: a 2.8 m area).
const RIPPLE_PER_M := 0.6
const RIM_PER_M := 0.55
const SPLASH_PER_M := 0.45
const CAST_SCALE := 1.4
## The water plane's level through the cast (it reaches this share at the cast's end) and its drain (s).
const CAST_LEVEL := 0.7
const DRAIN_S := 0.9
## The sim's High Tide step (ticks): the hero outside is splashed once a step.
const STEP_TICKS := 30
## Floor layers draw before the telegraphs' (priority 0) so a strike's marker always shows over the water.
const UNDER := -2
const STRIP_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 sea : source_color = vec4(0.42, 0.86, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.04, 0.22, 0.5, 1.0);
uniform vec4 foam : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform vec4 dry : source_color = vec4(1.0, 0.86, 0.5, 1.0);
uniform float struck = 1.0;
uniform float warn = 0.0;    // 0..1 through the warning
uniform float front = -1.0;  // 0..1 along the strip once the wave runs, -1 before
uniform float along_x = 1.0;
uniform float length_m = 24.0;
uniform float width_m = 6.0;
uniform float alpha = 1.0;
uniform float clock = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	float u = along_x > 0.5 ? UV.x : 1.0 - UV.y;  // along the strip, 0 at the room's low end
	float v = along_x > 0.5 ? UV.y : UV.x;        // across it
	float side_m = min(v, 1.0 - v) * width_m;
	float end_m = min(u, 1.0 - u) * length_m;
	vec2 p = vec2(u * length_m, v * width_m);
	if (struck > 0.5) {
		float n = texture(noise_tex, p * 0.07 + vec2(-clock * 0.06, clock * 0.02)).r;
		float behind = front >= 0.0 ? smoothstep(front + 0.01, front - 0.01, u) : 0.0;
		float level = max(warn, behind);
		float flow = fract(p.x * 0.18 - clock * (0.5 + 1.2 * level) + n * 0.6);
		float streak = smoothstep(0.7, 0.95, flow) * smoothstep(0.25, 0.75, n + 0.3);
		float border = smoothstep(0.4, 0.0, side_m);
		vec3 col = mix(deep.rgb, sea.rgb, 0.3 + 0.45 * n + 0.35 * streak);
		col = mix(col, foam.rgb, clamp(border * 0.7 + streak * 0.4, 0.0, 1.0));
		ALBEDO = col * (1.0 + 0.3 * level);
		ALPHA = clamp(alpha * (0.1 + 0.4 * level + 0.2 * streak * level + 0.45 * border), 0.0, 0.66);
	} else {
		float pulse = 0.72 + 0.28 * sin(clock * 5.0);
		float border = max(smoothstep(0.45, 0.0, side_m), smoothstep(0.3, 0.0, end_m));
		float inner = smoothstep(0.9, 0.55, side_m) * smoothstep(0.35, 0.55, side_m);
		ALBEDO = mix(dry.rgb, vec3(1.0, 0.98, 0.9), border) * (1.0 + 1.2 * border);
		ALPHA = clamp(alpha * (0.1 + 0.8 * border * pulse + 0.25 * inner), 0.0, 0.9);
	}
}
"""
const FLOOD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 sea : source_color = vec4(0.42, 0.86, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.04, 0.22, 0.5, 1.0);
uniform vec4 foam : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform vec2 room_size = vec2(24.0, 24.0);
uniform vec2 dry_at = vec2(0.0, 0.0);  // the circle's centre, metres from the plane's centre (x, z)
uniform float dry_r = 4.0;
uniform float level = 0.0;
uniform float clock = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 p = (UV - 0.5) * room_size;
	float d = length(p - dry_at);
	float wet = smoothstep(dry_r + 0.05, dry_r + 0.45, d);
	float n = texture(noise_tex, p * 0.06 + vec2(clock * 0.03, -clock * 0.02)).r;
	float c1 = texture(noise_tex, p * 0.13 + vec2(clock * 0.05, clock * 0.04)).r;
	float c2 = texture(noise_tex, p * 0.13 - vec2(clock * 0.04, clock * 0.06)).r;
	float caustic = smoothstep(0.08, 0.0, abs(c1 - c2));
	float shore = smoothstep(0.5, 0.0, abs(d - dry_r - 0.3) - 0.1 * n) * level;
	vec2 e = min(UV, 1.0 - UV) * room_size;
	float edge = smoothstep(0.0, 1.2, min(e.x, e.y));
	vec3 col = mix(deep.rgb, sea.rgb, 0.2 + 0.35 * n + 0.45 * caustic);
	ALBEDO = mix(col, foam.rgb, shore);
	ALPHA = clamp((wet * level * (0.3 + 0.12 * n + 0.14 * caustic) + 0.75 * shore) * edge, 0.0, 0.62);
}
"""
const DRY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 dry : source_color = vec4(1.0, 0.86, 0.5, 1.0);
uniform float radius_m = 4.0;
uniform float share = 1.0;  // the ring's lit share: filling through the cast, the flood's time left after
uniform float alpha = 1.0;
uniform float clock = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float m = r * radius_m;
	float rim = smoothstep(0.22, 0.0, abs(m - (radius_m - 0.15)));
	float turn = fract(atan(q.x, -q.y) / 6.2831853 + 1.0);
	float ring_d = abs(m - (radius_m - 0.75));
	float ring = smoothstep(0.2, 0.05, ring_d) * step(turn, share);
	float track = smoothstep(0.2, 0.05, ring_d) * 0.25;
	float pulse = 0.8 + 0.2 * sin(clock * 4.0);
	float fill = step(r, 1.0) * 0.22;
	float lit = max(rim * pulse, max(ring, track));
	ALBEDO = mix(dry.rgb, vec3(1.0, 0.99, 0.94), lit) * (1.0 + 1.4 * lit);
	ALPHA = clamp(alpha * (fill + 0.85 * lit), 0.0, 0.95) * step(r, 1.0);
}
"""

## The pack's effects (WorldViewRoot hands them over; a view built alone draws its own layers only).
var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _dance := {}
var _hero_at := Vector3.ZERO
var _boss_at := Vector3.ZERO
var _last_seq := 0
var _primed := false
var _clock := 0.0
var _strips: Array[MeshInstance3D] = []
var _strip_mats: Array[ShaderMaterial] = []
var _walls: Array[MeshInstance3D] = []
var _wall_mats: Array[ShaderMaterial] = []
var _flood: MeshInstance3D
var _flood_mat: ShaderMaterial
var _dry: MeshInstance3D
var _dry_mat: ShaderMaterial
## The water plane's last level and where it last stood, kept to drain it once the reader shows no High Tide.
var _level := 0.0
var _drain := 0.0
## The flood's last time left, to splash the hero once each sim step it spends outside.
var _flood_left := -1


func _init() -> void:
	name = "TideDanceViews"
	var noise := ProjectileMeshes.noise()
	var strip := Shader.new()
	strip.code = STRIP_SHADER
	var band := Shader.new()
	band.code = TideWaveViews.BAND_SHADER
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var wall_mesh := TideWaveViews.wave_mesh()
	for k in STRIPS:
		var sm := _material(strip, noise)
		sm.set_shader_parameter("sea", SEA)
		sm.set_shader_parameter("deep", DEEP)
		sm.set_shader_parameter("foam", FOAM)
		sm.set_shader_parameter("dry", DRY)
		_strips.append(_mesh(plane, sm))
		_strip_mats.append(sm)
		var wm := _material(band, noise)
		wm.set_shader_parameter("deep", DEEP)
		wm.set_shader_parameter("sea", SEA)
		wm.set_shader_parameter("foam", FOAM)
		wm.render_priority = 0
		_walls.append(_mesh(wall_mesh, wm))
		_wall_mats.append(wm)
	var flood := Shader.new()
	flood.code = FLOOD_SHADER
	_flood_mat = _material(flood, noise)
	_flood_mat.set_shader_parameter("sea", SEA)
	_flood_mat.set_shader_parameter("deep", DEEP)
	_flood_mat.set_shader_parameter("foam", FOAM)
	_flood = _mesh(plane, _flood_mat)
	var dry := Shader.new()
	dry.code = DRY_SHADER
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE * 2.0
	_dry_mat = _material(dry, null)
	_dry_mat.set_shader_parameter("dry", DRY)
	_dry = _mesh(disc, _dry_mat)
	_dry_mat.render_priority = UNDER + 1


func _material(shader: Shader, noise: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	if noise != null:
		m.set_shader_parameter("noise_tex", noise)
	m.render_priority = UNDER
	return m


## A hidden mesh on its own material, under this view.
func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	_dance = reader.boss_dance()
	_hero_at = SimPlane.to_3d(reader.actor_pos(0))
	if not _dance.is_empty():
		_boss_at = SimPlane.to_3d(reader.actor_pos(int(_dance["boss"])))
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.STATUS_APPLY:
			continue
		if e.effect_id == EFFECT_HIT:
			_splash(_hero_at, 1.6)
		elif e.effect_id == EFFECT_TIDE_END:
			_drain = DRAIN_S
	_splash_in_flood()


## The hero outside the dry circle in the flood: a splash on it each sim step it pays for.
func _splash_in_flood() -> void:
	var ht: Dictionary = _dance.get("high_tide", {})
	if ht.is_empty() or int(ht["flood"]) < 0:
		_flood_left = -1
		return
	var left := int(ht["left"])
	if (
		not bool(ht["inside"])
		and _flood_left >= 0
		and left / STEP_TICKS != _flood_left / STEP_TICKS
	):
		_splash(_hero_at, 0.9)
	_flood_left = left


func _splash(at: Vector3, radius: float) -> void:
	if pack_fx != null and pack_fx.has_id(SPLASH_ID) and pack_fx.has_room(&"impact"):
		pack_fx.spawn(SPLASH_ID, at + Vector3(0, 0.1, 0), radius * SPLASH_PER_M)


## True while the High Tide's water is up and the hero stands outside the dry circle (the HUD's edge glow).
static func flooding(reader: WorldReader) -> bool:
	var ht: Dictionary = reader.boss_dance().get("high_tide", {})
	return not ht.is_empty() and int(ht["flood"]) >= 0 and not bool(ht["inside"])


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	var idle := _dance.is_empty() and _drain <= 0.0
	if idle:
		if quiet:
			return
		quiet = true
	else:
		quiet = false
	_clock += delta * (0.0 if ViewPrefs.reduced_motion else 1.0)
	hold.begin()
	_draw_riptide()
	_draw_high_tide(delta)
	_draw_cast()
	hold.end()


func _draw_riptide() -> void:
	var rip: Dictionary = _dance.get("riptide", {})
	var on := not rip.is_empty()
	for k in STRIPS:
		_strips[k].visible = on
		_walls[k].visible = false
	if not on:
		return
	var strips: Array = _dance["strips"]
	var room: Rect2 = _dance["room"]
	var along_x := bool(_dance["along_x"])
	var length := room.size.x if along_x else room.size.y
	var struck: Array = rip["struck"]
	var warn := float(rip["warn"]) / 1000.0
	var wave := float(rip["wave"]) / 1000.0
	var front := float(rip["front"])
	for k in mini(STRIPS, strips.size()):
		var r: Rect2 = strips[k]
		var hit := struck.has(k)
		var mi := _strips[k]
		mi.position = SimPlane.to_3d(r.get_center(), 0.03 + 0.002 * k)
		mi.scale = Vector3(r.size.x, 1.0, r.size.y)
		var m := _strip_mats[k]
		m.set_shader_parameter("struck", 1.0 if hit else 0.0)
		m.set_shader_parameter("warn", clampf(warn, 0.0, 1.0) if warn >= 0.0 else 1.0)
		m.set_shader_parameter("front", front / maxf(length, 0.01) if wave >= 0.0 else -1.0)
		m.set_shader_parameter("along_x", 1.0 if along_x else 0.0)
		m.set_shader_parameter("length_m", length)
		m.set_shader_parameter("width_m", r.size.y if along_x else r.size.x)
		m.set_shader_parameter("clock", _clock)
		if not hit:
			continue
		var width := r.size.y if along_x else r.size.x
		var mid := r.get_center()
		var at := mid
		if wave >= 0.0:
			at = _front_point(r, along_x, front)
			_draw_wall(k, at, along_x, width, wave)
		var grow := 1.0 if wave >= 0.0 else 0.5 + 0.5 * clampf(warn, 0.0, 1.0)
		hold.put(
			[&"strip", k],
			WATER_ID,
			&"area",
			_at(SimPlane.to_3d(at, 0.06), width * 0.5 * RIPPLE_PER_M * grow)
		)


## The point on strip `r`'s centre line `front` metres from the room's low end.
static func _front_point(r: Rect2, along_x: bool, front: float) -> Vector2:
	var mid := r.get_center()
	if along_x:
		return Vector2(r.position.x + front, mid.y)
	return Vector2(mid.x, r.position.y + front)


func _draw_wall(k: int, at: Vector2, along_x: bool, width: float, wave: float) -> void:
	var rise := clampf(wave / WALL_IN, 0.0, 1.0)
	var sink := clampf((1.0 - wave) / WALL_OUT, 0.0, 1.0)
	var f := minf(ease(rise, 0.5), ease(sink, 0.5))
	var wall := _walls[k]
	wall.visible = f > 0.01
	# The mesh's crest stands 0.2 of its depth ahead of its centre: the crest rides the front
	var fwd := Vector2.RIGHT if along_x else Vector2.UP
	wall.position = SimPlane.to_3d(at - fwd * WALL_DEPTH_M * 0.2, 0.0)
	wall.rotation = Vector3(0.0, 0.0 if along_x else PI * 0.5, 0.0)
	wall.scale = Vector3(WALL_DEPTH_M, WALL_RISE * maxf(f, 0.01), width * 0.98)
	_wall_mats[k].set_shader_parameter("alpha", f)
	_wall_mats[k].set_shader_parameter("clock", _clock)


func _draw_high_tide(delta: float) -> void:
	var ht: Dictionary = _dance.get("high_tide", {})
	var room: Rect2 = _dance.get("room", Rect2())
	if not ht.is_empty():
		var cast := int(ht["cast"])
		_level = CAST_LEVEL * float(cast) / 1000.0 if cast >= 0 else 1.0
		_drain = 0.0
		_place_flood(room, ht["centre"], float(ht["radius"]))
	elif _drain > 0.0:
		_drain = maxf(0.0, _drain - delta)
		_level = minf(_level, _drain / DRAIN_S)
	else:
		_level = 0.0
	_flood.visible = _level > 0.001
	_flood_mat.set_shader_parameter("level", _level)
	_flood_mat.set_shader_parameter("clock", _clock)
	_dry.visible = not ht.is_empty()
	if ht.is_empty():
		return
	var radius := float(ht["radius"])
	_dry.position = SimPlane.to_3d(ht["centre"], 0.045)
	_dry.scale = Vector3.ONE * radius
	_dry_mat.set_shader_parameter("radius_m", radius)
	_dry_mat.set_shader_parameter("share", ring_share(ht))
	_dry_mat.set_shader_parameter("clock", _clock)
	hold.put(&"dry", DRY_ID, &"area", _at(_dry.position + Vector3(0, 0.02, 0), radius * RIM_PER_M))


func _place_flood(room: Rect2, centre: Vector2, radius: float) -> void:
	_flood.position = SimPlane.to_3d(room.get_center(), 0.025)
	_flood.scale = Vector3(room.size.x, 1.0, room.size.y)
	_flood_mat.set_shader_parameter("room_size", room.size)
	var off := SimPlane.to_3d(centre) - SimPlane.to_3d(room.get_center())
	_flood_mat.set_shader_parameter("dry_at", Vector2(off.x, off.z))
	_flood_mat.set_shader_parameter("dry_r", radius)


## The dry circle's ring: it fills through the cast and shrinks with the flood's time left (0..1).
static func ring_share(ht: Dictionary) -> float:
	var cast := int(ht["cast"])
	if cast >= 0:
		return float(cast) / 1000.0
	return clampf(1.0 - float(ht["flood"]) / 1000.0, 0.0, 1.0)


## The rising water under the Tidecaller while it casts Riptide's warning or the High Tide.
func _draw_cast() -> void:
	if casting(_dance):
		hold.put(&"cast", CAST_ID, &"status", _at(_boss_at + Vector3(0, 0.05, 0), CAST_SCALE))


## True while the Tidecaller casts: a Riptide warning or a High Tide's cast runs.
static func casting(dance: Dictionary) -> bool:
	var rip: Dictionary = dance.get("riptide", {})
	var ht: Dictionary = dance.get("high_tide", {})
	return (
		(not rip.is_empty() and int(rip["warn"]) >= 0)
		or (not ht.is_empty() and int(ht["cast"]) >= 0)
	)


static func _at(pos: Vector3, scale: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * scale), pos)


## Tests and the shot scripts: what is drawn now.
func strips_shown() -> int:
	return _strips.filter(func(n: MeshInstance3D) -> bool: return n.visible).size()


## Strip k as drawn, on the sim plane.
func strip_rect(k: int) -> Rect2:
	var mi := _strips[k]
	var size := Vector2(mi.scale.x, mi.scale.z)
	return Rect2(SimPlane.to_sim(mi.position) - size * 0.5, size)


func strip_struck(k: int) -> bool:
	return float(_strip_mats[k].get_shader_parameter("struck")) > 0.5


func strip_param(k: int, param: StringName) -> float:
	return float(_strip_mats[k].get_shader_parameter(param))


func wall_shown(k: int) -> bool:
	return _walls[k].visible


## Where wall k's crest stands on the sim plane.
func wall_crest(k: int) -> Vector2:
	var wall := _walls[k]
	var fwd := Vector2.RIGHT if is_zero_approx(wall.rotation.y) else Vector2.UP
	return SimPlane.to_sim(wall.position) + fwd * WALL_DEPTH_M * 0.2


func dry_shown() -> bool:
	return _dry.visible


func dry_centre() -> Vector2:
	return SimPlane.to_sim(_dry.position)


func dry_radius() -> float:
	return _dry.scale.x


func dry_share() -> float:
	return float(_dry_mat.get_shader_parameter("share"))


func flood_shown() -> bool:
	return _flood.visible


func flood_level() -> float:
	return _level


## The water plane's hole: [its centre on the sim plane, its radius].
func flood_hole() -> Array:
	var at: Vector2 = _flood_mat.get_shader_parameter("dry_at")
	var c := SimPlane.to_sim(_flood.position + Vector3(at.x, 0.0, at.y))
	return [c, float(_flood_mat.get_shader_parameter("dry_r"))]
