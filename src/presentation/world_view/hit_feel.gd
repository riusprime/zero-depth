class_name HitFeel
extends Node3D
## Hit feel from the event log (PRESENTATION §6): a white flash on whoever took damage, a camera shake when you're
## hit, a spark where a hit was guarded, a dull grey spark off a Warden's armoured front, a bright one on its weak
## spot behind, and a pop of shards when an enemy dies. The combo's finisher (v0.3.0 L11) hits harder: a longer
## flash on each enemy it lands on, a bright spark and a small camera shake (none when shake is off).
## The sim's hit-stop is already in the tick (freeze_ticks); nothing here changes an outcome.

const SHARDS := 7
const SHARD_FRAMES := 30
const FINISHER_SHAKE := 0.3
const FINISHER_FLASH_MULT := 2

var actors: ActorViews
var rig: IsoRig
var _last_seq := 0
var _rng := RandomNumberGenerator.new()
var _shards: Array = []
var _burst_mats := {}


func _init(p_actors: ActorViews, p_rig: IsoRig) -> void:
	actors = p_actors
	rig = p_rig
	_rng.seed = 1  # the cosmetic stream: presentation only, never feeds the sim (EI-05)


func sync(reader: WorldReader) -> void:
	var player_id := reader.actor_id(0)
	var shook := false
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		match e.kind:
			SimEvent.Kind.DAMAGE:
				if finisher_hit(reader, e):
					actors.flash(e.target_id, actors.flash_frames * FINISHER_FLASH_MULT)
					_burst(e.pos, Color(0.85, 1.0, 1.0), 6, 0.1)
					if not shook:
						rig.shake(FINISHER_SHAKE)
						shook = true
				else:
					actors.flash(e.target_id)
				if e.target_id == player_id:
					rig.shake(0.55)
			SimEvent.Kind.HIT:
				if e.tags & (SimEvent.TAG_BLOCKED | SimEvent.TAG_GUARDED):
					_burst(e.pos, Color(0.85, 0.9, 1.0), 4, 0.08)
				elif e.tags & SimEvent.TAG_ARMOURED:
					_burst(e.pos, Color(0.45, 0.45, 0.48), 3, 0.07)
				elif e.tags & SimEvent.TAG_WEAK_SPOT:
					_burst(e.pos, Color(1.0, 0.92, 0.55), 6, 0.09)
			SimEvent.Kind.KILL:
				if e.target_id != player_id:
					_burst(e.pos, ThemePalette.color(&"enemy_body"), SHARDS, 0.16)


## A DAMAGE event from the combo's finisher itself (the player's melee, not an item's echo), read while that swing
## is still running.
static func finisher_hit(reader: WorldReader, e: SimEvent) -> bool:
	return (
		e.kind == SimEvent.Kind.DAMAGE
		and (e.tags & SimEvent.TAG_MELEE) != 0
		and e.effect_id == &""
		and e.owner_id == reader.actor_id(0)
		and reader.swing_tick() > 0
		and reader.is_finisher()
	)


func _burst(at: Vector2, c: Color, n: int, size: float) -> void:
	var m: StandardMaterial3D = _burst_mats.get(c)
	if m == null:
		# One material per colour, kept for the view's life, not one per kill (DAMAGE_LAG.md): nothing is
		# allocated per kill, and its shader never depends on another node staying alive.
		m = StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_burst_mats[c] = m
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
