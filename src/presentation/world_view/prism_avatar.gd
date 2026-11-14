class_name PrismAvatar
extends FinalBodyAvatar
## The final boss's second body (the owner asked for "rays that go in a cross and turn with her in the middle … a lot
## of small balls … quick, fast attacks"): the owner's model assets/models/bosses/final_boss_prism.glb, the torn
## hooded figure with nine red crystals floating round her. It is one mesh skinned to a full skeleton (the body, the
## chest, the hood, the cloak's chains, the spikes hanging under her, the halo, and one bone per floating crystal;
## scripts/assets/boss_anim/final_prism) and carries its own animations: "idle" and "walk" (a float) replace the code
## clips of those names, and OWNER_PLAYS says which animation each move, the rise and the shatter play.
## The file floats her and her crystals: each crystal hangs near its own place and turns slowly about its own long
## axis. The owner asked for exactly that ("it should be that kind of rotation with the crystal floating near the
## same"; the crystals no longer circle her), so the avatar never turns the crystals' parent bone and adds no spin,
## bob or drift of its own. The sim's shard ring (WorldReader.boss_shards) still turns, unseen: it is only where her
## bolts and orbs start. What the avatar adds is game state:
## - the crystal nearest the sim shard that fires flares (WorldReader.boss_cross "orb_shard", "bolt"): it swells, and
##   a short pulse lifts the body; PrismViews puts the muzzle flash on the same crystal (nearest_crystal);
## - she forms and breaks over the boss's place: the file's "form" starts, and its "break" ends, centred on the
##   model's origin, half a metre beside her own axis, so the avatar slides the model back by as much as the body
##   bone has left its place (_after_bones); she forms in sight, where the last body broke, not out of the floor;
## - while the sim holds her shattering, "break" plays through the 1.5 s and holds its last pose, the low heap.
## The moves the file has no animation for (PrismClips: the shielded hold, the flinch, the stagger, the roar, the
## death) turn her bones over the file's idle. Without the model a code-made stand-in (a robed crystal figure and six
## crystals floating in place) flares the same way. Reads only.

const HEIGHT := 3.0
## Points on the owner's model at rest (metres, model frame, +X the front, her axis at 0): the chest (the weak
## point, the "chest" bone) and the crystal on it (the "core" bone).
const MODEL_CHEST := Vector3(0.3, 2.05, 0.0)
const MODEL_CORE := Vector3(0.28, 2.14, -0.04)
const CRYSTAL := Color("#C8384E")
const ROBE := Color("#D9CFC8")
## The bone her figure stands on (BossModels centres the model on it), and the floating crystals' bones' prefix.
const AXIS_BONE := &"body"
const CRYSTAL_PREFIX := "shard_"
const WALK_SPEED := 1.5
## She has no feet to slide, so the stride only sets the float's pace: one loop of the file's "walk" (10 s, one turn
## of every crystal) takes STRIDE / WALK_SPEED seconds at her move speed.
const STRIDE := 15.0
## The file's animations by the clip that plays them, with the seconds of each one's strike pose and of the end of
## its active part: the Cross opens her (the spin, then the window), an orb spell is a cast, a lone bolt a flick; the
## Facet Lances and the Shattered Kneel have their own; she forms as she rises and breaks as she shatters.
const OWNER_PLAYS := {
	&"cross": {"anim": &"open", "strike": 1.0, "recover": 9.5},
	&"pattern": {"anim": &"cast", "strike": 0.8, "recover": 1.8},
	&"bolt_fan": {"anim": &"flick", "strike": 0.5, "recover": 0.53},
	&"lances": {"anim": &"lances", "strike": 0.8, "recover": 3.7},
	&"kneel": {"anim": &"kneel", "strike": 0.6, "recover": 3.6},
	&"rise": {"anim": &"form"},
	&"shatter": {"anim": &"break"},
}
## How much a flaring crystal swells; the stand-in's crystals' distance from her (m) and seconds per turn.
const FLARE_SWELL := 0.7
const STAND_IN_RING := 1.4
const STAND_IN_TURN_SECONDS := 10.0

var stand_in := Node3D.new()
var _stand_shards: Array[Node3D] = []
## The model's floating crystals' bones, in name order: their indices and their names.
var _crystals := PackedInt32Array()
var _crystal_names: Array[StringName] = []
## The body bone, and where the model's origin is from its rest place (model frame, across the floor).
var _axis_bone := -1
var _origin_from_axis := Vector3.ZERO
## Each crystal's flare (0..1), the sim shard firing now (-1 none) and its place in this node's space.
var _flares := PackedFloat32Array()
var _firing := -1
var _firing_at := Vector3.ZERO
var _cast := 0.0
var _orb_shard := -1
var _bolt_shard := -1
## The idle loop's start (seconds of _t): the loop begins as the rise ends, on the frame "form" ends on.
var _idle_from := 0.0


func model_id() -> StringName:
	return &"final_boss_prism"


func _code_nodes() -> Array[Node]:
	return [stand_in]


func _clip_library() -> Dictionary:
	return PrismClips.library()


func _owner_plays() -> Dictionary:
	return OWNER_PLAYS


func _walk_speed() -> float:
	return WALK_SPEED


func _stride() -> float:
	return STRIDE


## The length the file's idle was made at, so it plays as made.
func _idle_seconds() -> float:
	return 10.0


## All of "form" plays over the intro: her crystals leave the floor in its second half, so she floats whole as the
## last body's shards finish sinking into her and before her first crystal can fire.
func _rise_intro_share() -> float:
	return 1.0


func _weak_point_at() -> Vector3:
	return MODEL_CHEST if imported != null else Vector3(0.5, 1.8, 0)


func _weak_bone() -> StringName:
	return &"chest"


func anchor_names() -> Array[StringName]:
	return [&"weak", &"core"]


func _anchor(point: StringName) -> Vector3:
	if point == &"core":
		return _on_bone(&"core", MODEL_CORE) if imported != null else Vector3(0, 1.8, 0)
	return weak_core.position


## How many crystals float round her (tests and the tour).
func shard_count() -> int:
	return _crystals.size() if imported != null else _stand_shards.size()


## 0..1: crystal k's flare now (tests).
func shard_flare(k: int) -> float:
	return _flares[k] if k >= 0 and k < _flares.size() else 0.0


## Where crystal k is drawn now, in this node's space (metres; +X her front).
func crystal_place(k: int) -> Vector3:
	if imported == null:
		return model.transform * _stand_shards[k].position
	return model.transform * (_skel_to_model() * skeleton.get_bone_global_pose(_crystals[k]).origin)


## Where the sim shard that fires now is, in this node's space (tests); meaningless while none fires.
func firing_place() -> Vector3:
	return _firing_at


## True while a sim shard fires (an orb volley, a bolt's aim).
func is_firing() -> bool:
	return _firing >= 0


## The drawn crystal nearest a point (-1 with none), by the distance across the floor: `at` is in this node's space.
func nearest_crystal_index(at: Vector3) -> int:
	var near := -1
	var best := INF
	for k in shard_count():
		var p := crystal_place(k)
		var d := Vector2(p.x - at.x, p.z - at.z).length_squared()
		if d < best:
			best = d
			near = k
	return near


## The world place of the drawn crystal nearest the world point `at` (PrismViews: what a sim shard fires looks as if
## it leaves a crystal). `at` itself with no crystal, or outside the tree.
func nearest_crystal(at: Vector3) -> Vector3:
	if not is_inside_tree():
		return at
	var k := nearest_crystal_index(global_transform.affine_inverse() * at)
	return global_transform * crystal_place(k) if k >= 0 else at


## How far the body bone stands from the boss's place across the floor now (metres, this node's space; tests).
func axis_offset() -> float:
	if imported == null or _axis_bone < 0:
		return 0.0
	var p := model.transform * (_skel_to_model() * skeleton.get_bone_global_pose(_axis_bone).origin)
	return Vector2(p.x, p.z).length()


func sync(reader: WorldReader, i: int) -> void:
	var ring := reader.boss_shards(i)
	var c := reader.boss_cross(i)
	var orb := int(c.get("orb_shard", -1))
	var bolt: Dictionary = c.get("bolt", {})
	var bolt_shard := int(bolt.get("shard", -1))
	if (orb >= 0 and orb != _orb_shard) or (bolt_shard >= 0 and bolt_shard != _bolt_shard):
		_cast = 1.0
	_orb_shard = orb
	_bolt_shard = bolt_shard
	_firing = orb if orb >= 0 else bolt_shard
	if _firing >= ring.size():
		_firing = -1
	if _firing >= 0:
		var yaw := SimPlane.yaw_of(reader.actor_facing(i))
		_firing_at = (
			Basis(Vector3.UP, yaw).inverse()
			* SimPlane.to_3d(ring[_firing] - reader.actor_pos(i), 0.0)
		)
	super(reader, i)


## Plain values (tests, renders): "firing" (where a sim shard fires from, a Vector3 in this node's space, metres;
## null for none), "cast" (0..1).
func apply_state(s: Dictionary) -> void:
	super(s)
	if s.has("firing"):
		_firing = 0 if s["firing"] != null else -1
		if _firing >= 0:
			_firing_at = s["firing"]
	if s.has("cast"):
		_cast = float(s["cast"])


func _build_body() -> void:
	super()
	if imported == null:
		return
	for k in skeleton.get_bone_count():
		if skeleton.get_bone_name(k).begins_with(CRYSTAL_PREFIX):
			_crystal_names.append(StringName(skeleton.get_bone_name(k)))
	_crystal_names.sort_custom(_by_name)
	for n in _crystal_names:
		_crystals.append(skeleton.find_bone(String(n)))
	_flares.resize(maxi(_crystals.size(), 6))
	_axis_bone = skeleton.find_bone(String(AXIS_BONE))
	if _axis_bone >= 0:
		var to_model := BossModels.relative_transform(pivot, skeleton)
		_origin_from_axis = (
			to_model.origin - to_model * skeleton.get_bone_global_rest(_axis_bone).origin
		)
		_origin_from_axis.y = 0.0


static func _by_name(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)


func _build() -> void:
	var p := parts
	stand_in.name = "StandIn"
	model.add_child(stand_in)
	p.piece(stand_in, BossParts.crystal(2.2, 0.6, 21), Vector3(0, 0.6, 0), ROBE)
	for k in 6:
		var n := Node3D.new()
		stand_in.add_child(n)
		p.piece(n, BossParts.crystal(0.7, 0.18, 30 + k), Vector3.ZERO, CRYSTAL)
		n.position = (
			Basis(Vector3.UP, TAU * k / 6.0) * Vector3(STAND_IN_RING, 1.7 + 0.3 * (k % 2), 0)
		)
		_stand_shards.append(n)
	_flares.resize(6)


## The stand-in's crystals float in place, each turning slowly on itself; the one that fires swells.
func _pose(dt: float) -> void:
	_advance_flares(dt)
	var turn := 0.0 if ViewPrefs.reduced_motion else _t * TAU / STAND_IN_TURN_SECONDS
	for k in _stand_shards.size():
		var n := _stand_shards[k]
		n.rotation = Vector3(0, turn * (1.0 if k % 2 == 0 else -1.0), 0)
		n.scale = Vector3.ONE * (1.0 + FLARE_SWELL * _flares[k])


## The idle loop starts as the rise ends, so "form" runs into it without a jump.
func _animate(dt: float) -> void:
	super(dt)
	if _rise_t < 1.0:
		_idle_from = _t
	animator.set_layer(BossAnimator.IDLE, &"idle", (_t - _idle_from) / _idle_seconds(), 1.0 - _walk)


## After the clips: the firing crystal swells and the body pulses.
func _pose_final(dt: float) -> void:
	_advance_flares(dt)
	var p := poser
	if p == null:
		return
	for k in _crystals.size():
		if _flares[k] > 0.001:
			p.stretch(_crystal_names[k], 1.0 + FLARE_SWELL * _flares[k])
	_pose_pulse()


## The pulse clip on the body as a crystal fires.
func _pose_pulse() -> void:
	if _cast <= 0.001 or pivot == null:
		return
	var c: BossClip = PrismClips.library()[&"pulse"]
	for k in c.targets.size():
		if c.targets[k] != BossClip.BODY:
			continue
		var v := c.value(k, 1.0 - _cast, ViewPrefs.reduced_motion) * _cast
		if c.channels[k] == BossClip.SHIFT:
			pivot.position += c.axes[k] * v
		elif c.channels[k] == BossClip.TURN:
			pivot.basis = Basis(c.axes[k], v) * pivot.basis


## While she forms or breaks, the model is slid so that she does not cross the floor: those two animations move the
## body bone between her own axis and the model's origin, and the slide here is the same share of that way, back.
func _after_bones() -> void:
	if _axis_bone < 0 or (_rise_t >= 1.0 and _shatter <= 0.0):
		return
	var way := _origin_from_axis
	if absf(way.z) < 0.001:
		return
	var to_model := BossModels.relative_transform(pivot, skeleton)
	var rest := to_model * skeleton.get_bone_global_rest(_axis_bone).origin
	var now := to_model * skeleton.get_bone_global_pose(_axis_bone).origin
	pivot.position -= way * ((now.z - rest.z) / way.z)


## The pulse's fade and each crystal's flare: the one nearest the firing sim shard swells.
func _advance_flares(dt: float) -> void:
	_cast = move_toward(_cast, 0.0, dt * 2.5)
	var near := nearest_crystal_index(_firing_at) if _firing >= 0 else -1
	for k in mini(shard_count(), _flares.size()):
		_flares[k] = move_toward(
			_flares[k], 1.0 if k == near else 0.0, dt * (8.0 if k == near else 3.0)
		)
