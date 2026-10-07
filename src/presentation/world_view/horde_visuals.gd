class_name HordeVisuals
extends Node3D
## What the horde kinds (v0.4.0 EN) show besides their models and telegraphs, read through WorldReader (EI-07):
## - each mine on the floor: a dark disc with a blinking red light inside a faint ring of the circle that arms it (an
##   armed mine's filling circle is its layer's telegraph, TelegraphViews);
## - each Mender's heal beam: a pale-green ray from its crystal to the ally it heals, pulsing;
## - each Sniper's shot: a bright tracer down its line that fades in TRACER_S.

const TRACER_S := 0.18
const MINE_RING_ALPHA := 0.45
const BEAM_W := 0.06

var _mines := {}
var _beams := {}
var _tracers: Array = []
var _states := {}
var _t := 0.0
var _ring_mat := StandardMaterial3D.new()
var _mine_mat := StandardMaterial3D.new()
var _light_mat := StandardMaterial3D.new()
var _beam_mat := StandardMaterial3D.new()


func _ready() -> void:
	var hot := ThemePalette.color(&"telegraph_hostile")
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(hot, MINE_RING_ALPHA)
	_mine_mat.albedo_color = Color("#24272D")
	_mine_mat.roughness = 1.0
	_light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_mat.albedo_color = Color("#FF2A22")
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.albedo_color = Color(HordeAvatar.MEND, 0.8)


func sync(reader: WorldReader) -> void:
	_sync_mines(reader)
	var beams := {}
	for i in range(1, reader.actor_count()):
		var id := reader.actor_id(i)
		var kind := reader.actor_kind(i)
		if kind == WorldReader.KIND_MENDER:
			var j := reader.actor_index(reader.actor_heal_target(i))
			if j >= 0:
				beams[id] = true
				_beam(id, reader.actor_pos(i), reader.actor_pos(j))
		elif kind == WorldReader.KIND_SNIPER:
			var st := reader.actor_state(i)
			if st == WorldReader.STATE_ACTIVE and _states.get(id, st) != st:
				_tracer(reader.sniper_line(i))
			_states[id] = st
	for id in _beams.keys():
		if not beams.has(id):
			_beams[id].queue_free()
			_beams.erase(id)
	for id in _states.keys():  # bounded: forget snipers that are gone
		if reader.actor_index(id) < 0:
			_states.erase(id)


func _process(delta: float) -> void:
	_t += delta
	var light := 0.5 + 0.5 * sin(_t * 10.0)
	_light_mat.albedo_color = Color("#FF2A22").lerp(Color("#5A0E0B"), light)
	_beam_mat.albedo_color = Color(HordeAvatar.MEND, 0.55 + 0.35 * sin(_t * 14.0))
	for k in range(_tracers.size() - 1, -1, -1):
		var tr_node: MeshInstance3D = _tracers[k][0]
		_tracers[k][1] -= delta
		var left: float = _tracers[k][1]
		if left <= 0.0:
			tr_node.queue_free()
			_tracers.remove_at(k)
		else:
			(tr_node.material_override as StandardMaterial3D).albedo_color.a = left / TRACER_S


## Mines and beams showing (tests).
func mine_count() -> int:
	return _mines.size()


func beam_count() -> int:
	return _beams.size()


func tracer_count() -> int:
	return _tracers.size()


func _sync_mines(reader: WorldReader) -> void:
	var seen := {}
	for k in reader.mine_count():
		var id := reader.mine_id(k)
		seen[id] = true
		var n: Node3D = _mines.get(id)
		if n == null:
			n = _make_mine(reader.mine_radius(k))
			_mines[id] = n
			add_child(n)
		n.position = SimPlane.to_3d(reader.mine_pos(k), 0.0)
		(n.get_node("Ring") as Node3D).visible = reader.mine_fuse(k) < 0
	for id in _mines.keys():
		if not seen.has(id):
			_mines[id].queue_free()
			_mines.erase(id)


func _make_mine(r: float) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = ArcCasterAvatar._frustum(0.2, 0.13, 0.08, 8)
	body.material_override = _mine_mat
	root.add_child(body)
	var light := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.07, 0.04, 0.07)
	light.mesh = lb
	light.material_override = _light_mat
	light.position.y = 0.1
	root.add_child(light)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.05
	torus.outer_radius = r
	torus.rings = 48
	ring.mesh = torus
	ring.scale = Vector3(1, 0.05, 1)
	ring.position.y = 0.03
	ring.material_override = _ring_mat
	root.add_child(ring)
	for c in root.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


func _beam(id: int, from: Vector2, to: Vector2) -> void:
	var n: MeshInstance3D = _beams.get(id)
	if n == null:
		n = MeshInstance3D.new()
		n.mesh = BoxMesh.new()
		n.material_override = _beam_mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beams[id] = n
		add_child(n)
	var a := SimPlane.to_3d(from, 1.55)
	var b := SimPlane.to_3d(to, 0.6)
	var len := maxf(a.distance_to(b), 0.01)
	(n.mesh as BoxMesh).size = Vector3(BEAM_W, BEAM_W, len)
	n.position = (a + b) * 0.5
	if len > 0.02:
		n.look_at_from_position(
			n.position, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
		)


func _tracer(o: Obb) -> void:
	var n := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(o.half.x * 2.0, 0.05, 0.08)
	n.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = ThemePalette.color(&"proj_hostile")
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.position = SimPlane.to_3d(o.center, SimPlane.CORE_HEIGHT)
	n.rotation = Vector3(0, SimPlane.yaw_of(o.angle), 0)
	add_child(n)
	_tracers.append([n, TRACER_S])
