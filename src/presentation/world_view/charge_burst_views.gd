class_name ChargeBurstViews
extends Node3D
## The burst at the end of a boss's charge (any boss whose charge bursts), drawn from WorldReader (EI-07: where it
## ends, when it locks and when it bursts are the sim's, BossChargeBurst).
## - Through the wind-up: a plain red-orange ring of the burst's exact radius where the lane ends (the telegraph's
##   "burst"), the floor inside it darkened and cracked as the slam will crack it. It follows the aim, dull and slowly
##   pulsing, while the aim tracks; once the aim locks it flashes white-hot and pulses fast, like every other
##   telegraph's lock.
## - Armed (the run has stopped, WorldReader.boss_charge_bursts): the circle stays where it was armed and darkens from
##   its middle out as the burst comes.
## - The burst, once, where an armed circle went off, sized to the radius: the charge slams into the stone floor
##   (GroundSlamViews: faceted chunks of the floor kicked up and falling back, a fractured floor, a brief dust kick; no
##   fire or light), the amber Warden's and the Warlord's lunge alike.
## - The amber Warden's shade (The Fallen remembering the ward, WorldReader.boss_fallen "shade" and "burst"): the same
##   circle at its run's end, locked as its aim locks, then armed and smashing down the same way.
## Every slot is built hidden at the start. Reduced motion stills the pulse. Nothing here decides.

const SLOTS := 4
## The danger circle (a unit disc; the node's scale is the radius): a plain ring in the tint, dull while `locked` is 0
## and pulsing fast and flashing white-hot once it is 1, over the floor darkened and cracked as the slam will crack it
## (GroundSlamViews' dark crack lines), darkening further from the middle out with `fill` (an armed burst counting
## down).
const CIRCLE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.29, 0.14, 1.0);
uniform float alpha = 1.0;
uniform float locked = 0.0;
uniform float flash = 0.0;
uniform float fill = 0.0;
uniform float clock = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x) / 6.2831853;
	float edge = smoothstep(0.05, 0.0, abs(r - 0.94));
	float pulse = 0.8 + 0.2 * sin(clock * (5.0 + 8.0 * locked));
	float ring = edge * (0.55 + 0.45 * locked) * pulse + edge * flash;
	float w = a * 9.0 + 0.18 * sin(r * 13.0 + a * 21.0) + 0.1 * sin(r * 29.0);
	float crack = smoothstep(0.07, 0.0, abs(fract(w) - 0.5) - 0.012 * (1.0 - r)) * smoothstep(0.12, 0.3, r);
	float inside = step(r, 0.9);
	float dark = (0.16 + 0.5 * crack + 0.22 * step(r, fill)) * inside;
	vec3 hot = mix(tint.rgb * (0.8 + 0.3 * locked), vec3(1.0, 0.95, 0.85), clamp(flash, 0.0, 1.0));
	vec3 ground = mix(vec3(0.07, 0.06, 0.06), vec3(1.0, 0.95, 0.85), 0.5 * flash * inside);
	ALBEDO = mix(ground, hot, clamp(ring * 2.0, 0.0, 1.0));
	ALPHA = clamp(alpha * (ring + dark + 0.25 * flash * inside), 0.0, 0.92) * step(r, 1.0);
}
"""

## The lock's flash (s).
const FLASH_S := 0.18

static var _shader: Shader

## The charges' ground slams.
var slams := GroundSlamViews.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
## The circles drawn this frame: [centre (sim), radius, locked, fill 0..1 (an armed one), its key].
var _circles: Array = []
var _discs: Array[MeshInstance3D] = []
## Key -> the seconds since it locked (its flash), and the armed bursts last seen (key -> [centre, radius, left]).
var _locked_at := {}
var _armed := {}
var _clock := 0.0


func _init() -> void:
	name = "ChargeBurstViews"
	for k in SLOTS:
		_discs.append(_circle())
	slams.driven = true
	add_child(slams)


func sync(reader: WorldReader) -> void:
	_circles = []
	for i in range(reader.actor_count() if reader.any_boss() else 0):
		if not WorldReader.is_boss_kind(reader.actor_kind(i)):
			continue
		var tg := reader.telegraph(i)
		var b: Dictionary = tg.get("burst", {})
		if tg.get("shape", &"") != &"lane" or b.is_empty() or float(b["radius"]) <= 0.0:
			continue
		var locked := bool(tg.get("locked", true))
		_circles.append([b["center"], float(b["radius"]), locked, 0.0, "w%d" % reader.actor_id(i)])
	var rows := reader.boss_charge_bursts()
	var fallen := reader.boss_fallen()
	if not fallen.is_empty():  # The amber Warden's shade, as The Fallen remembers the ward: a charge with no actor
		var sh: Dictionary = fallen["shade"]
		if not sh.is_empty() and float(sh["burst_radius"]) > 0.0:
			_circles.append([sh["end"], float(sh["burst_radius"]), bool(sh["locked"]), 0.0, "fs"])
		var bu: Dictionary = fallen["burst"]
		if not bu.is_empty():
			var row := bu.duplicate()
			row["boss"] = -1
			rows.append(row)
	var seen := {}
	for row: Dictionary in rows:
		var key := "a%d" % int(row["boss"])
		seen[key] = true
		_armed[key] = [row["centre"], float(row["radius"]), int(row["left"])]
		_circles.append(
			[row["centre"], float(row["radius"]), true, float(row["progress"]) / 1000.0, key]
		)
	for key: String in _armed.keys():
		if seen.has(key):
			continue
		var last: Array = _armed[key]
		if int(last[2]) <= 2:  # it went off (a burst cancelled early leaves without one)
			_slam(last[0], float(last[1]))
		_armed.erase(key)


func _slam(centre: Vector2, radius: float) -> void:
	slams.slam(SimPlane.to_3d(centre, 0.0), radius)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	slams.advance(delta)
	if _circles.is_empty() and not slams.busy():
		if quiet:
			return
		quiet = true
	else:
		quiet = false
	_clock += delta * (0.0 if ViewPrefs.reduced_motion else 1.0)
	var live := {}
	for k in SLOTS:
		var mi := _discs[k]
		mi.visible = k < _circles.size()
		if not mi.visible:
			continue
		var c: Array = _circles[k]
		var key: String = c[4]
		live[key] = true
		var locked := bool(c[2])
		if locked and not _locked_at.has(key):
			_locked_at[key] = 0.0
		elif locked:
			_locked_at[key] = float(_locked_at[key]) + delta
		var flash := 0.0
		if locked:
			flash = 1.0 - clampf(float(_locked_at[key]) / FLASH_S, 0.0, 1.0)
		var radius: float = c[1]
		mi.position = SimPlane.to_3d(c[0], 0.05 + 0.003 * k)
		mi.scale = Vector3.ONE * radius
		WardenLooks.param(mi, &"locked", 1.0 if locked else 0.0)
		WardenLooks.param(mi, &"flash", flash)
		WardenLooks.param(mi, &"fill", float(c[3]))
		WardenLooks.param(mi, &"alpha", 1.0 if locked else 0.7)
		WardenLooks.param(mi, &"clock", _clock)
	for key: String in _locked_at.keys():
		if not live.has(key):
			_locked_at.erase(key)


## Tests and the shot scripts: the circles drawn now, each [centre (sim), radius, locked, fill].
func circles() -> Array:
	var out := []
	for k in mini(SLOTS, _circles.size()):
		var mi := _discs[k]
		(
			out
			. append(
				[
					SimPlane.to_sim(mi.position),
					mi.scale.x,
					(
						float(
							(mi.material_override as ShaderMaterial).get_shader_parameter("locked")
						)
						> 0.5
					),
					float((mi.material_override as ShaderMaterial).get_shader_parameter("fill")),
				]
			)
		)
	return out


func shown() -> int:
	return _discs.filter(func(n: MeshInstance3D) -> bool: return n.visible).size()


## A hidden danger circle (radius 1; the node's scale is the radius) wearing its own CIRCLE_SHADER material.
func _circle() -> MeshInstance3D:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CIRCLE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", WardenLooks.DANGER)
	m.render_priority = -1
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	mi.mesh = plane
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi
