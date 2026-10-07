class_name HitFeel
extends Node3D
## Hit feel from the event log (PRESENTATION §6): a white flash on whoever took damage, a camera shake when you're
## hit, a spark where a hit was blocked or guarded, and a pop of shards when an enemy dies.
## The sim's hit-stop is already in the tick (freeze_ticks); nothing here changes an outcome.

const SHARDS := 7
const SHARD_FRAMES := 30

var actors: ActorViews
var rig: IsoRig
var _last_seq := 0
var _rng := RandomNumberGenerator.new()
var _shards: Array = []


func _init(p_actors: ActorViews, p_rig: IsoRig) -> void:
	actors = p_actors
	rig = p_rig
	_rng.seed = 1  # the cosmetic stream: presentation only, never feeds the sim (EI-05)


func sync(reader: WorldReader) -> void:
	var player_id := reader.actor_id(0)
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		match e.kind:
			SimEvent.Kind.DAMAGE:
				actors.flash(e.target_id)
				if e.target_id == player_id:
					rig.shake(0.55)
			SimEvent.Kind.HIT:
				if e.tags & (SimEvent.TAG_BLOCKED | SimEvent.TAG_GUARDED):
					_burst(e.pos, Color(0.85, 0.9, 1.0), 4, 0.08)
			SimEvent.Kind.KILL:
				if e.target_id != player_id:
					_burst(e.pos, ThemePalette.color(&"enemy_body"), SHARDS, 0.16)


func _burst(at: Vector2, c: Color, n: int, size: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size
	for k in n:
		var s := MeshInstance3D.new()
		s.mesh = box
		s.material_override = m
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		s.position = SimPlane.to_3d(at, 0.4)
		var dir := Vector3(
			_rng.randf_range(-1, 1), _rng.randf_range(0.6, 1.4), _rng.randf_range(-1, 1)
		)
		add_child(s)
		_shards.append([s, dir * _rng.randf_range(2.5, 4.5), SHARD_FRAMES])


func _process(delta: float) -> void:
	for k in range(_shards.size() - 1, -1, -1):
		var sh: Array = _shards[k]
		var node: MeshInstance3D = sh[0]
		var vel: Vector3 = sh[1]
		vel.y -= 9.8 * delta
		sh[1] = vel
		node.position += vel * delta
		node.rotation += Vector3(4, 3, 2) * delta
		sh[2] -= 1
		if sh[2] <= 0 or node.position.y < 0.0:
			node.queue_free()
			_shards.remove_at(k)
