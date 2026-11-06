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
## v0.10.5 (owner PERF_PLAYLOG_1: view.elite_fx 56.2 ms, the first elite): the rings and the arrival sigil are pooled
## and made at the floor's load (prepare), the Conduit's pack beams too (WorldViewRoot); same marks, same look.

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
## v0.10.0 VX5: the arrival sigil is a MagicArea (R13) and the Conduit's beam the pack's (R27); false: the old ones.
const PACK_SIGILS := true
const PACK_BEAMS := true
const SIGIL_R := 1.6

## v0.10.5 (owner PERF_PLAYLOG_1: view.elite_fx 56.2 ms on f4, the first elite's arrival): the rings by use (inner and
## outer radius, colour), pooled: prepare() makes PREFILL of each at the floor's load, a ring that ends goes back to
## its pool hidden, and the rings of one use share one mesh.
const RINGS := {
	&"arrive": [1.0, 1.25, GOLD],
	&"dust": [2.6, 3.0, DUST],
	&"rift": [0.35, 1.0, RIFT],
}
const PREFILL := {&"arrive": 1, &"dust": 2, &"rift": 2}
## v0.10.5: idle pack beams (the Conduit's, pack_ids) made at the floor's load (WorldViewRoot).
const PACK_PREFILL := 2


## v0.10.5: the arrival sigil, kept and played again (prepare): a MagicArea that hides when its fade ends instead of
## freeing itself (a new one loads and compiles its shaders and builds its meshes, materials and particles).
class PooledSigil:
	extends MagicArea

	func _process(delta: float) -> void:
		if _phase == FADING and _t + delta >= _fade:
			park()
			return
		super(delta)

	## Hidden and still until play() (its sparks off); v0.10.5 PC: out of the tree (EliteViews keeps it).
	func park() -> void:
		_phase = IDLE
		if _sparks != null:
			_sparks.emitting = false
		visible = false
		set_process(false)
		if get_parent() != null:
			get_parent().remove_child(self)


## Nodes alive, each [node, seconds left, seconds total, kind &"arrive" | &"beam" | &"dust"].
var _fx: Array = []
## v0.10.5: idle rings by use (RINGS), and their shared meshes. v0.10.5 PC (owner PERF_PLAYLOG_2: idle pool nodes in
## the tree cost every frame): the idle rings and the parked sigil wait outside the tree, kept here (freed with the
## view).
var _idle := {}
var _meshes := {}
var _sigil: PooledSigil = null
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


## v0.10.5: the floor's elite effects made now (WorldViewRoot, at the floor's load behind the cover): PREFILL rings of
## each use and the arrival sigil, all hidden. The view is marked ShaderWarmup.WARM_META, so the warm-up draws each
## piece once (their shaders and pipelines compile on the cover, not at the first elite).
func prepare() -> void:
	set_meta(ShaderWarmup.WARM_META, true)
	for use: StringName in PREFILL:
		var idle: Array = _idle.get_or_add(use, [])
		while idle.size() < int(PREFILL[use]):
			var n := _new_ring(use)
			_park(n)
	if _sigil == null and PACK_SIGILS and MagicArea.kinds().has("circle"):
		_sigil = PooledSigil.new()
		_sigil.element = "shadow"
		_sigil.kind = "circle"
		for key: StringName in _sigil_options():
			_sigil.set_option(key, _sigil_options()[key])
		_sigil.autoplay = false
		_sigil.visible = false
		add_child(_sigil)
		_sigil.park()


## The pack ids the elites spawn (the Conduit's beam), for WorldViewRoot to fill their pools at the load.
static func pack_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if PACK_BEAMS:
		out.append(BossPackHold.beam_id(BEAM))
	return out


## The pooled rings waiting by use (tests).
func idle_rings(use: StringName) -> int:
	return (_idle.get(use, []) as Array).size()


func has_pooled_sigil() -> bool:
	return _sigil != null


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
			_park(_marks[id] as Node3D)
			_marks.erase(id)


func _process(delta: float) -> void:
	_t += delta
	var calm := ViewPrefs.reduced_motion
	for k in range(_fx.size() - 1, -1, -1):
		var e: Array = _fx[k]
		e[1] -= delta
		var n: Node3D = e[0]
		if e[1] <= 0.0:
			if n.has_meta(&"ring_use"):
				_park(n)
			else:
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
	if PACK_SIGILS and MagicArea.kinds().has("circle"):
		# R13: the sigil is a magic circle in the shadow element (it forms, fades and frees itself in about ARRIVE_S;
		# v0.10.5: the pooled one hides instead, and the next arrival plays it again)
		if _sigil != null and not _sigil.visible:
			_sigil.seed = randf() * 10.0  # (as MagicArea.add gives each new one)
			_sigil.position = SimPlane.to_3d(at, Y)
			if _sigil.get_parent() == null:
				add_child(_sigil)  # (v0.10.5 PC: parked outside the tree)
			_sigil.visible = true
			_sigil.set_process(true)
			_sigil.play()
		else:
			var options := _sigil_options()
			options[&"position"] = SimPlane.to_3d(at, Y)
			MagicArea.add(self, "shadow_circle", options)
	else:
		var sigil := _disc(SIGIL_R, GOLD, 0.85)
		sigil.position = SimPlane.to_3d(at, Y)
		add_child(sigil)
		_fx.append([sigil, ARRIVE_S, ARRIVE_S, &"arrive"])
	var ring := _ring_for(&"arrive")
	ring.position = SimPlane.to_3d(at, Y + 0.01)
	_fx.append([ring, ARRIVE_S, ARRIVE_S, &"dust"])


## The arrival sigil's MagicArea options (R13), its position aside.
static func _sigil_options() -> Dictionary:
	return {
		&"radius": SIGIL_R,
		&"light": false,
		&"one_shot": true,
		&"appear": ARRIVE_S * 0.2,
		&"duration": 0.0,
	}


func _rift(id: int, tg: Dictionary) -> void:
	var n: Node3D = _marks.get(id)
	if n == null:
		n = _ring_for(&"rift")
		_marks[id] = n
	var r: float = tg["radius"]
	n.position = SimPlane.to_3d(tg["center"], Y + 0.02)
	n.scale = Vector3(r * 0.55, 1, r * 0.55)
	var m := (n.get_child(0) as GeometryInstance3D).material_override as StandardMaterial3D
	m.albedo_color = Color(RIFT, 0.9 if tg.get("locked", false) else 0.45)


func _beam(o: Obb) -> void:
	var pack := BossPackHold.find(self) if PACK_BEAMS else null
	if pack != null and pack.has_room(&"beam"):  # R27: the pack's beam along the Conduit's line for BEAM_S
		var from := SimPlane.to_3d(o.center - o.axis_u * o.half.x, 0.9)
		var to := SimPlane.to_3d(o.center + o.axis_u * o.half.x, 0.9)
		var pn := pack.spawn(BossPackHold.beam_id(BEAM), from, 1.0, {}, BEAM_S)
		if pn != null:
			BossPackHold.beam_place(pn, from, to, o.half.y * 0.7)
			return
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
	var n := _ring_for(&"dust")
	n.position = SimPlane.to_3d(at, Y)
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


## v0.10.5: a ring of `use` (RINGS) shown, in the view: an idle one from its pool (as new: no turn, no scale, its
## colour at 0.7), else a new one.
func _ring_for(use: StringName) -> Node3D:
	var idle: Array = _idle.get(use, [])
	if idle.is_empty():
		return _new_ring(use)
	var n: Node3D = idle.pop_back()
	if n.get_parent() == null:
		add_child(n)  # (v0.10.5 PC: idle outside the tree)
	n.transform = Transform3D.IDENTITY
	var m := (n.get_child(0) as GeometryInstance3D).material_override as StandardMaterial3D
	m.albedo_color = Color(RINGS[use][2] as Color, 0.7)
	n.visible = true
	return n


func _new_ring(use: StringName) -> Node3D:
	var spec: Array = RINGS[use]
	var n := _ring(spec[0], spec[1], spec[2])
	n.set_meta(&"ring_use", use)
	add_child(n)
	return n


## Back to its pool, hidden and out of the tree (v0.10.5 PC).
func _park(n: Node3D) -> void:
	n.visible = false
	(_idle.get_or_add(n.get_meta(&"ring_use"), []) as Array).append(n)
	if n.get_parent() == self:
		remove_child(n)


## v0.10.5 PC: the idle pieces outside the tree (ShaderWarmup draws them once at the load).
func idle_pieces() -> Array[Node]:
	var out: Array[Node] = []
	for use: StringName in _idle:
		for n: Variant in _idle[use]:  # (a Variant: freeing the view frees its in-tree pieces first)
			if is_instance_valid(n) and (n as Node).get_parent() == null:
				out.append(n)
	if is_instance_valid(_sigil) and _sigil.get_parent() == null:
		out.append(_sigil)
	return out


## v0.10.5 PC: how many idle pieces wait outside the tree (tests, scripts/checks/pool_node_count.gd).
func idle_outside() -> int:
	return idle_pieces().size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:  # the pieces outside the tree go with the view
		for n in idle_pieces():
			n.free()
		_idle.clear()
		_sigil = null


func _ring(inner: float, outer: float, c: Color) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var key := Vector2(inner, outer)
	if not _meshes.has(key):
		var torus := TorusMesh.new()
		torus.inner_radius = inner
		torus.outer_radius = outer
		torus.rings = 32
		_meshes[key] = torus
	mi.mesh = _meshes[key]
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
