class_name PrismAvatar
extends FinalBodyAvatar
## v0.8.0 FB1 (FINAL_BOSS.md F5), FB2 (owner O17: "rays that go in a cross and turn with her in the middle … a lot of
## small balls … quick, fast attacks"): the final boss's second body, the owner's model
## assets/models/bosses/final_boss_prism.glb (the torn figure ringed by floating red crystal shards), her shards cut in
## code as the separate pieces they are (BossRig: `body`, `core`, `shard_00` …) and animated by PrismClips. Her own
## layer after the clips (_pose_final):
## - the shards orbit her axis with the sim's shard ring (WorldReader.boss_shards: the angle of its first shard,
##   carried on between ticks at the ring's measured turn), each also turning on itself faster with the clips' "spin";
##   in the Cross's window ("open") they drift a little wider;
## - the shard nearest the sim shard that fires flares (an orb volley's shard while it fires, a bolt's shard through
##   its aim line: WorldReader.boss_cross "orb_shard", "bolt"): it swells, and the cast clip pulses the body;
## - while the body shatters, the shatter clip's lift and quickening shards over FinalBodyAvatar's tremble.
## Without the model a code-made stand-in (a robed crystal figure and six crystals) orbits the same way. Reads only.

const HEIGHT := 3.0
const MODEL_CHEST := Vector3(0.4, 1.9, 0.0)
const CRYSTAL := Color("#C8384E")
const ROBE := Color("#D9CFC8")
## A shard's own turn (radians a second) at the clips' "spin" 1, how much a flaring shard swells, how much wider the
## shards drift in the window ("open" 1), and the stand-in's orbit radius (m).
const SELF_SPIN := 6.0
const FLARE_SWELL := 0.7
const OPEN_DRIFT := 0.25
const STAND_IN_ORBIT := 1.4

var stand_in := Node3D.new()
var _stand_shards: Array[Node3D] = []
## The model's shards: [bone, rest pivot (model frame), offset from the axis (x, z), rest angle about the axis].
var _shards: Array = []
var _axis := Vector3.ZERO
## The sim ring's angle (radians, world yaw) at the last sync, its turn (radians a second), and the tick it was read.
var _ring := 0.0
var _ring_rate := 0.0
var _ring_tick := -1
var _has_ring := false
## Each model shard's own spin angle, its flare (0..1), and the sim shard firing now (-1 none) with its angle.
var _spin := 0.0
var _flares := PackedFloat32Array()
var _firing := -1
var _firing_yaw := 0.0
var _cast := 0.0
var _orb_shard := -1
var _bolt_shard := -1


func model_id() -> StringName:
	return &"final_boss_prism"


func _code_nodes() -> Array[Node]:
	return [stand_in]


func _clip_library() -> Dictionary:
	return PrismClips.library()


func _walk_speed() -> float:
	return 1.5


func _idle_seconds() -> float:
	return 3.2


func _weak_point_at() -> Vector3:
	return MODEL_CHEST if imported != null else Vector3(0.5, 1.8, 0)


func _weak_bone() -> StringName:
	return &"body"


func anchor_names() -> Array[StringName]:
	return [&"weak", &"core"]


func _anchor(point: StringName) -> Vector3:
	if point == &"core":
		return (
			_on_bone(&"core", _axis + Vector3(0, 0.6 * HEIGHT, 0))
			if imported != null
			else Vector3(0, 1.8, 0)
		)
	return weak_core.position


## The model's shards (tests and the tour): how many orbit.
func shard_count() -> int:
	return _shards.size() if imported != null else _stand_shards.size()


## 0..1: shard k's flare now (tests).
func shard_flare(k: int) -> float:
	return _flares[k] if k >= 0 and k < _flares.size() else 0.0


## The orbit's turn now (radians; tests).
func orbit_angle() -> float:
	return _ring


func sync(reader: WorldReader, i: int) -> void:
	var ring := reader.boss_shards(i)
	if not ring.is_empty():
		var d := SimPlane.to_3d(ring[0] - reader.actor_pos(i), 0.0)
		var yaw := atan2(-d.z, d.x)
		var tick := reader.tick()
		if _has_ring and tick > _ring_tick:
			_ring_rate = wrapf(yaw - _ring, -PI, PI) * 60.0 / float(tick - _ring_tick)
		_ring = yaw
		_ring_tick = tick
		_has_ring = true
	var c := reader.boss_cross(i)
	var orb := int(c.get("orb_shard", -1))
	var bolt: Dictionary = c.get("bolt", {})
	var bolt_shard := int(bolt.get("shard", -1))
	if (orb >= 0 and orb != _orb_shard) or (bolt_shard >= 0 and bolt_shard != _bolt_shard):
		_cast = 1.0
	_orb_shard = orb
	_bolt_shard = bolt_shard
	_firing = orb if orb >= 0 else bolt_shard
	if _firing >= 0 and _firing < ring.size():
		var d := SimPlane.to_3d(ring[_firing] - reader.actor_pos(i), 0.0)
		_firing_yaw = atan2(-d.z, d.x)
	super(reader, i)


## Plain values (tests, renders): "ring" (the sim ring's angle, radians), "firing" (a model-frame yaw a shard fires
## from, or absent), "cast" (0..1).
func apply_state(s: Dictionary) -> void:
	super(s)
	if s.has("ring"):
		_ring = float(s["ring"])
		_has_ring = true
	if s.has("firing"):
		_firing = 0
		_firing_yaw = float(s["firing"])
	if s.has("cast"):
		_cast = float(s["cast"])


func _build() -> void:
	var p := parts
	stand_in.name = "StandIn"
	model.add_child(stand_in)
	p.piece(stand_in, BossParts.crystal(2.2, 0.6, 21), Vector3(0, 0.6, 0), ROBE)
	for k in 6:
		var n := Node3D.new()
		stand_in.add_child(n)
		p.piece(n, BossParts.crystal(0.7, 0.18, 30 + k), Vector3.ZERO, CRYSTAL)
		_stand_shards.append(n)
	_flares.resize(6)


## The model's shards from its rig (their bones and rest pivots, and the orbit's axis: the `core` bone's x, z).
func _read_rig() -> void:
	_shards.clear()
	for b: Array in rig.bones:
		if b[0] == &"core":
			_axis = Vector3(b[2].x, 0.0, b[2].z)
	for b: Array in rig.bones:
		if not String(b[0]).begins_with("shard_"):
			continue
		var off: Vector3 = b[2] - _axis
		_shards.append([b[0], b[2], Vector2(off.x, off.z), atan2(-off.z, off.x)])
	_flares.resize(maxi(_shards.size(), 6))


## The orbit's turn in the model frame now: the sim ring's world angle carried on between ticks, less the body's
## facing (the model turns with it).
func _orbit_now() -> float:
	var carry := _ring_rate * _since_sync if not ViewPrefs.reduced_motion else 0.0
	return _ring + carry - _facing_yaw


func _pose(dt: float) -> void:
	_advance_shards(dt, 0.25, 0.0)
	var phi := _orbit_now()
	for k in _stand_shards.size():
		var a := phi + TAU * k / _stand_shards.size()
		var n := _stand_shards[k]
		n.position = Basis(Vector3.UP, a) * Vector3(STAND_IN_ORBIT, 1.7 + 0.3 * (k % 2), 0)
		n.rotation = Vector3(0, _spin, 0)
		n.scale = Vector3.ONE * (1.0 + FLARE_SWELL * _flares[k])


func _pose_final(dt: float) -> void:
	if _shards.is_empty() and rig != null:
		_read_rig()
	var an := animator
	var p := poser
	var spin := maxf(0.15, an.param(&"spin"))
	var open := clampf(an.param(&"open"), 0.0, 1.0)
	_advance_shards(dt, spin, open)
	if p == null or _shards.is_empty():
		return
	var phi := _orbit_now() - float(_shards[0][3])
	var wide := 1.0 + OPEN_DRIFT * open
	for k in _shards.size():
		var s: Array = _shards[k]
		var off := Vector3(s[2].x, 0.0, s[2].y)
		var moved := Basis(Vector3.UP, phi) * (off * wide)
		p.shift(s[0], moved - off + Vector3(0, 0.08 * sin(_t * 1.3 + k), 0))
		p.turn(
			s[0],
			Vector3.UP,
			phi + (0.0 if ViewPrefs.reduced_motion else _spin * (0.4 + 0.1 * (k % 3)))
		)
		if _flares[k] > 0.001:
			p.stretch(s[0], 1.0 + FLARE_SWELL * _flares[k])
	_pose_cast()


## The cast clip's pulse on the body (as a shard fires), and the shatter clip's lift while the body cracks.
func _pose_cast() -> void:
	var lib := PrismClips.library()
	for row: Array in [[lib[&"cast"], 1.0 - _cast, _cast], [lib[&"shatter"], _shatter, _shatter]]:
		var c: BossClip = row[0]
		var w: float = row[2]
		if w <= 0.001 or pivot == null:
			continue
		for k in c.targets.size():
			if c.targets[k] != BossClip.BODY:
				continue
			var v := c.value(k, row[1], ViewPrefs.reduced_motion) * w
			if c.channels[k] == BossClip.SHIFT:
				pivot.position += c.axes[k] * v
			elif c.channels[k] == BossClip.TURN:
				pivot.basis = Basis(c.axes[k], v) * pivot.basis


## The shards' own spin, the cast's fade and each shard's flare: the one nearest the firing sim shard swells.
func _advance_shards(dt: float, spin: float, _open: float) -> void:
	if not ViewPrefs.reduced_motion:
		_spin = fmod(_spin + dt * SELF_SPIN * spin, TAU)
	_cast = move_toward(_cast, 0.0, dt * 2.5)
	var n := _shards.size() if imported != null else _stand_shards.size()
	var near := -1
	if _firing >= 0 and n > 0:
		var want := _firing_yaw - _facing_yaw
		var best := 99.0
		var phi := _orbit_now()
		for k in n:
			var rest := (
				float(_shards[k][3]) - float(_shards[0][3]) if imported != null else TAU * k / n
			)
			var d := absf(wrapf(rest + phi - want, -PI, PI))
			if d < best:
				best = d
				near = k
	for k in mini(n, _flares.size()):
		_flares[k] = move_toward(
			_flares[k], 1.0 if k == near else 0.0, dt * (8.0 if k == near else 3.0)
		)
