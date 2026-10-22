class_name HitFeel
extends Node3D
## Hit feel from the event log (PRESENTATION §6): a white flash on whoever took damage, a camera shake when you're
## hit, a spark where a hit was guarded, a dull grey spark off a Warden's armoured front, a bright one on its weak
## spot behind, and a pop of shards when an enemy dies. The combo's finisher (v0.3.0 L11) hits harder: a longer
## flash on each enemy it lands on, a bright spark and a small camera shake (none when shake is off).
## The sim's hit-stop is already in the tick (freeze_ticks); nothing here changes an outcome.
## Bosses (v0.3.0 BX): a dull grey-blue spark when the ranged armour deflects most of a far hit, a big gold one on
## the open weak point.
## v0.8.0 GF2 (owner O20): each of the player's hits on an enemy also throws an impact (ImpactFx: a flash and sparks
## where it hit, a spray out of the far side along the hit) and flinches the enemy's model away from the hit
## (AvatarBase.flinch for the normal kinds, BossAvatar.flinch's clip for the bosses: a pose only, the sim body never
## moves), on top of the white flash.
## v0.8.0 GF3 (owner O22): a Blade hit's impact is a cut along the slash with sparks along it (ImpactFx), its flinch is
## stronger and knocks the pose away from the swing, and it starts the view's hit-stop (HitStop: the hero's swing and
## the struck enemies held about 2 frames, shared by one swing's hits, rate-limited; a tiny camera kick). In the view
## only: the sim's own hit-stop above is unchanged and the sim never reads this one.

const SHARDS := 7
const SHARD_FRAMES := 30
const FINISHER_SHAKE := 0.3
const FINISHER_FLASH_MULT := 2
## A hit a boss's ranged armour deflected (v0.3.0 BX): a dull, small, grey-blue spark.
const DEFLECT_COLOR := Color(0.42, 0.46, 0.52)

var actors: ActorViews
var rig: IsoRig
## v0.8.0 GF2: the impacts (drawn into the effects layer: WorldViewRoot adds impacts.draw to its drawers).
var impacts := ImpactFx.new()
## v0.8.0 GF2: flinches started (tests).
var flinches := 0
## v0.8.0 GF3: the view's hit-stop (WorldViewRoot hands it the blade view, KitView, as `hit_stop.kit`).
var hit_stop := HitStop.new()
## v0.8.0 GF3: a count of the swings seen (one swing's hits share one freeze), and the last sync's swing tick / step.
var _swing_serial := 0
var _last_swing_t := 0
var _last_step := -1
var _last_seq := 0
var _rng := RandomNumberGenerator.new()
var _shards: Array = []
var _burst_mats := {}


func _init(p_actors: ActorViews, p_rig: IsoRig) -> void:
	actors = p_actors
	rig = p_rig
	hit_stop.actors = p_actors
	hit_stop.rig = p_rig
	_rng.seed = 1  # the cosmetic stream: presentation only, never feeds the sim (EI-05)


func sync(reader: WorldReader) -> void:
	var player_id := reader.actor_id(0)
	var shook := false
	var st := reader.swing_tick()
	if st > 0 and (_last_swing_t == 0 or st < _last_swing_t or reader.combo_step() != _last_step):
		_swing_serial += 1
	_last_swing_t = st
	_last_step = reader.combo_step()
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
				elif player_hit(e, player_id):
					var hit := impacts.on_hit(reader, e)
					_flinch(e.target_id, hit[0], hit[1], hit[2])
					if e.tags & SimEvent.TAG_MELEE:  # v0.8.0 GF3: a Blade hit holds the views a moment
						hit_stop.on_blade_hit(
							e.target_id,
							e.tick,
							_swing_serial if st > 0 else -1,
							SimPlane.to_3d(hit[0]),
							finisher_hit(reader, e),
							player_id
						)
			SimEvent.Kind.HIT:
				if e.tags & SimEvent.TAG_EXPOSED:  # BX: a boss's open weak point, struck up close
					_burst(e.pos, Color(1.0, 0.84, 0.42), 9, 0.11)
				elif e.tags & SimEvent.TAG_DEFLECTED:  # BX: the ranged armour turned most of it
					_burst(e.pos, DEFLECT_COLOR, 3, 0.06)
				elif e.tags & (SimEvent.TAG_BLOCKED | SimEvent.TAG_GUARDED):
					_burst(e.pos, Color(0.85, 0.9, 1.0), 4, 0.08)
				elif e.tags & SimEvent.TAG_ARMOURED:
					_burst(e.pos, Color(0.45, 0.45, 0.48), 3, 0.07)
				elif e.tags & SimEvent.TAG_WEAK_SPOT:
					_burst(e.pos, Color(1.0, 0.92, 0.55), 6, 0.09)
			SimEvent.Kind.KILL:
				if e.target_id != player_id:
					_burst(e.pos, ThemePalette.color(&"enemy_body"), SHARDS, 0.16, true)
	impacts.track(reader)


## v0.8.0 GF2: a DAMAGE event that is the player's hit on an enemy (not a damage-over-time tick).
static func player_hit(e: SimEvent, player_id: int) -> bool:
	return (
		e.kind == SimEvent.Kind.DAMAGE
		and e.owner_id == player_id
		and e.target_id != player_id
		and (e.tags & SimEvent.TAG_DOT) == 0
		and e.amount > 0
	)


## v0.8.0 GF2: flinches the hit enemy's model away along `away` (a model without a flinch: nothing).
## v0.8.0 GF3: `knock` (a Blade hit's) also knocks the pose away (AvatarBase.flinch).
func _flinch(id: int, away: Vector2, strength: float, knock: float = 0.0) -> void:
	var node := actors.actor_node(id)
	if node == null or not node.has_meta(&"enemy_avatar"):
		return
	var avatar: Object = node.get_meta(&"enemy_avatar")
	if avatar.has_method(&"flinch") and avatar.call(&"flinch", away, strength, knock):
		flinches += 1


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


## How many spark pieces are flying (tests).
func spark_count() -> int:
	return _shards.size()


## `lit`: the pieces are debris (a dead enemy's body), shaded by the scene's light like the body they came from;
## otherwise they are sparks of light, unshaded. v0.5.5 LK (A3 VFX audit): the death pop was unshaded, so its red
## chunks glowed at full brightness next to the lit bodies, and stood out of a darker scene as flat stickers.
func _burst(at: Vector2, c: Color, n: int, size: float, lit: bool = false) -> void:
	var key := [c, lit]
	var m: StandardMaterial3D = _burst_mats.get(key)
	if m == null:
		# One material per look, kept for the view's life, not one per kill (DAMAGE_LAG.md): nothing is
		# allocated per kill, and its shader never depends on another node staying alive.
		m = StandardMaterial3D.new()
		m.albedo_color = c
		if lit:
			m.roughness = 1.0
		else:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_burst_mats[key] = m
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size
	for k in ViewPrefs.sparks(n):  # reduced motion throws fewer (v0.3.0 O)
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
	hit_stop.advance(delta)  # v0.8.0 GF3
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
