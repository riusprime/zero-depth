class_name EliteViews
extends Node3D
## v0.9.0 EL (ELITES.md E0-E3; W67: "a short spawn effect … Avoid lengthy cinematic introductions"): what the elites
## add on the ground and in the air, read from the sim each tick (WorldReader; EI-07), beside TelegraphViews (which
## draws each ability's hit area from the same function the hit resolves: the slam's filling circle, the rift mark,
## the beam's line):
## - the arrival: a gold sigil on the ground where it rises and a burst ring opening out, ARRIVE_S long (no pause, no
##   banner);
## - the Rift Hunter's mark: a violet rift turning on its mark (dim while it follows you, bright once locked);
## - the Conduit's beam: a bright teal bar along the beam the tick it fires, fading over BEAM_S;
## - the Breaker's slam: a dust ring opening to the circle's edge, and a thud of the camera (WorldViewRoot: IsoRig.thud,
##   none with reduced motion or the shake off) only when the hero stands within THUD_M.
## Reduced motion: the same marks, nothing turns or pulses.

const ARRIVE_S := 0.7
const BEAM_S := 0.35
const DUST_S := 0.45
const THUD := 0.35
const THUD_M := 6.0
const Y := 0.05
const GOLD := Color("#F2C14E")
const RIFT := Color("#9B5CFF")
const BEAM := Color("#B8FFF4")
const DUST := Color("#C9B79A")

## Nodes alive, each [node, seconds left, seconds total, kind &"arrive" | &"beam" | &"dust"].
var _fx: Array = []
## The rift marks shown now, by elite id.
var _marks := {}
var _arrive_tick := -1
## Elites seen in their slam's active tick (by id), so one slam makes one ring.
var _slams := {}
var _thud := false
var _t := 0.0


## True once for a slam that landed near the hero (WorldViewRoot thuds the camera).
func take_thud() -> bool:
	var t := _thud
	_thud = false
	return t


func fx_count() -> int:
	return _fx.size()


func mark_count() -> int:
	return _marks.size()


func sync(reader: WorldReader) -> void:
	var d := reader.elites()
	if bool(d.get("active", false)) and int(d["arrive_tick"]) != _arrive_tick:
		if _arrive_tick != -1 or reader.tick() - int(d["arrive_tick"]) < 30:
			_arrival(d["arrive_pos"])
		_arrive_tick = int(d["arrive_tick"])
	var seen := {}
	for i in range(reader.actor_count() if reader.any_elite() else 0):
		var kind := reader.actor_kind(i)
		if not WorldReader.is_elite_kind(kind) or reader.actor_dead(i):
			continue
		var id := reader.actor_id(i)
		var tg := reader.telegraph(i)
		if kind == WorldReader.KIND_RIFT_HUNTER and tg.get("shape", &"") == &"disc":
			seen[id] = true
			_rift(id, tg)
		var beam := reader.elite_beam(i) if kind == WorldReader.KIND_CONDUIT else null
		if beam != null and not _slams.has(id):
			_slams[id] = true
			_beam(beam)
		var striking := reader.actor_state(i) == WorldReader.STATE_ACTIVE
		var ability := reader.elite_attack(i) == WorldReader.ELITE_ABILITY
		if kind == WorldReader.KIND_BREAKER and striking and ability and not _slams.has(id):
			_slams[id] = true
			var at := reader.actor_pos(i)
			_dust(at)
			if at.distance_to(reader.player_pos()) <= THUD_M:
				_thud = true
		if beam == null and not (striking and ability):
			_slams.erase(id)
	for id in _marks.keys():
		if not seen.has(id):
			(_marks[id] as Node3D).queue_free()
			_marks.erase(id)


func _process(delta: float) -> void:
	_t += delta
	var calm := ViewPrefs.reduced_motion
	for k in range(_fx.size() - 1, -1, -1):
		var e: Array = _fx[k]
		e[1] -= delta
		var n: Node3D = e[0]
		if e[1] <= 0.0:
			n.queue_free()
			_fx.remove_at(k)
			continue
		var u: float = 1.0 - e[1] / e[2]
		var m := (n.get_child(0) as GeometryInstance3D).material_override as StandardMaterial3D
		match e[3]:
			&"arrive":
				n.scale = Vector3.ONE * (0.6 + 0.6 * u)
				m.albedo_color.a = 0.85 * (1.0 - u)
			&"dust":
				n.scale = Vector3.ONE * lerpf(0.4, 1.0, u)
				m.albedo_color.a = 0.6 * (1.0 - u)
			_:
				m.albedo_color.a = 0.9 * (1.0 - u)
	for n: Node3D in _marks.values():
		if not calm:
			n.rotation.y = _t * 2.5


func _arrival(at: Vector2) -> void:
	var sigil := _disc(1.6, GOLD, 0.85)
	sigil.position = SimPlane.to_3d(at, Y)
	add_child(sigil)
	_fx.append([sigil, ARRIVE_S, ARRIVE_S, &"arrive"])
	var ring := _ring(1.0, 1.25, GOLD)
	ring.position = SimPlane.to_3d(at, Y + 0.01)
	add_child(ring)
	_fx.append([ring, ARRIVE_S, ARRIVE_S, &"dust"])


func _rift(id: int, tg: Dictionary) -> void:
	var n: Node3D = _marks.get(id)
	if n == null:
		n = _ring(0.35, 1.0, RIFT)
		add_child(n)
		_marks[id] = n
	var r: float = tg["radius"]
	n.position = SimPlane.to_3d(tg["center"], Y + 0.02)
	n.scale = Vector3(r * 0.55, 1, r * 0.55)
	var m := (n.get_child(0) as GeometryInstance3D).material_override as StandardMaterial3D
	m.albedo_color = Color(RIFT, 0.9 if tg.get("locked", false) else 0.45)


func _beam(o: Obb) -> void:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(o.half.x * 2.0, 0.25, o.half.y * 1.4)
	mi.mesh = box
	mi.material_override = _mat(BEAM, 0.9)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	n.position = SimPlane.to_3d(o.center, 0.9)
	n.rotation = Vector3(0, SimPlane.yaw_of(o.angle), 0)
	add_child(n)
	_fx.append([n, BEAM_S, BEAM_S, &"beam"])


func _dust(at: Vector2) -> void:
	var n := _ring(2.6, 3.0, DUST)
	n.position = SimPlane.to_3d(at, Y)
	add_child(n)
	_fx.append([n, DUST_S, DUST_S, &"dust"])


func _disc(r: float, c: Color, a: float) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.01
	cyl.radial_segments = 32
	mi.mesh = cyl
	mi.material_override = _mat(c, a)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n


func _ring(inner: float, outer: float, c: Color) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 32
	mi.mesh = torus
	mi.scale = Vector3(1, 0.04, 1)
	mi.material_override = _mat(c, 0.7)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n


func _mat(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, a)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
