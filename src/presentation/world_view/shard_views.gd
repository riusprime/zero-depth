class_name ShardViews
extends Node3D
## Shard gems: when a kill pays shards (a SHARDS event), up to MAX_PER_KILL small violet crystals burst
## from the body, hang for a moment, then fly into the player and vanish. Cosmetic and in frame time: the sim
## already counted the shards. Jitter comes from a presentation RNG seeded per event, so shots look the same.
## Each gem is an outlined faceted shard (ShardMesh) lit by the scene with its
## own violet emission, instead of a flat unshaded crystal. The chest's price gem keeps shared_material().
## The flying gems are instances of two multimeshes (the crystals and their outline shells), so a burst of many
## payouts at once builds no node: one draw per half, the gems' places written once a frame.
## A normal kill's shards lie on
## the floor in the sim (ShardDrops); each drop is a small glowing cluster of the same gems on the ground (more gems
## for a bigger drop, DROP_GEMS_MAX at most), turning slowly. When the hero takes one (it leaves the reader with a
## pickup SHARDS event at its spot) the cluster is pulled into the hero over PULL_S and vanishes; a drop that left by
## merging (the floor's cap) just goes. The pickup's SHARDS event bursts nothing. Instant payouts (boss, chests,
## events) still burst and fly as before.

const COLOR := Color("#B48CFF")
const MAX_PER_KILL := 8
const MAX_ALIVE := 64
const BURST_S := 0.28
const SPEED := 13.0
const HEIGHT := 0.8
const PULL_S := 0.15
const DROP_GEMS_MAX := 4
const DROP_HEIGHT := 0.34
const DROP_SPREAD := 0.26
## How many shapes a drop of one size is drawn from. Building and baking a cluster is script work on every vertex,
## and a horde's kills drop dozens a second, so each size and shape is built once and every drop of it shares its
## meshes and materials. A drop still turns by its own number.
const DROP_SHAPES := 16
## A flying gem's outline shell margin (its share of the gem's size).
const GEM_OUTLINE := 0.2

static var _material: StandardMaterial3D
static var _mesh: ArrayMesh
static var _gem_material: StandardMaterial3D

var _last_seq := 0
var _target := Vector3.ZERO
## The flying gems by slot (a slot keeps its gem for the whole flight), a column each: place, velocity, age (s),
## turn about the vertical (rad), and whether the slot holds a gem.
var _g_pos := PackedVector3Array()
var _g_vel := PackedVector3Array()
var _g_age := PackedFloat64Array()
var _g_turn := PackedFloat32Array()
var _g_live := PackedByteArray()
## The slots burst since the gems last stepped (their interpolation starts at that step).
var _fresh := PackedInt32Array()
## The gems' crystals and outline shells (made at the first burst).
var _crystals: MultiMeshInstance3D
var _outlines: MultiMeshInstance3D
## The drops the last sync laid out (their places never change: a merge only grows the amount).
var _drop_seqs := PackedInt32Array()
var _drop_amounts := PackedInt32Array()
## The drops on the floor by sequence number: [node, gem count]; the pulled ones: [node, from, age].
var _drops := {}
var _pulled: Array[Array] = []
## The built drops by [gem count, shape], kept out of the tree: a drop on the floor is a copy of one (the copy
## shares its meshes and materials).
var _drop_shapes := {}


## The gem material, shared with the price tag on chests (emission on from creation).
static func shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = COLOR
		_material.emission_enabled = true
		_material.emission = COLOR
		_material.emission_energy_multiplier = 2.4
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _material


## The flying gems' material: the shard look (lit, toned facets, emission on from creation).
static func gem_material() -> StandardMaterial3D:
	if _gem_material == null:
		_gem_material = ShardMesh.crystal_material(COLOR, 1.6)
	return _gem_material


func _init() -> void:
	name = "Shards"


func sync(reader: WorldReader) -> void:
	_target = SimPlane.to_3d(reader.player_pos()) + Vector3(0, HEIGHT, 0)
	var taken := PackedVector2Array()
	var t0 := PerfMarks.start()
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.SHARDS and e.effect_id == WorldReader.SHARD_PICKUP_EFFECT:
			taken.append(e.pos)
		elif e.kind == SimEvent.Kind.SHARDS:
			_burst(e.pos, mini(e.amount, MAX_PER_KILL), reader.seed_value() * 31 + e.seq)
	PerfMarks.add(&"shards.events", t0)
	t0 = PerfMarks.start()
	_sync_drops(reader, taken)
	PerfMarks.add(&"shards.drops", t0)


## Shard drops lying on the floor (tests read it).
func drop_count() -> int:
	return _drops.size()


## Drops being pulled into the hero (tests read it).
func pulled_count() -> int:
	return _pulled.size()


func _sync_drops(reader: WorldReader, taken: PackedVector2Array) -> void:
	var seqs := reader.shard_drop_seqs()
	var amounts := reader.shard_drop_amounts()
	if taken.is_empty() and seqs == _drop_seqs and amounts == _drop_amounts:
		return  # The same drops as the last sync, none taken: nothing to lay out
	_drop_seqs = seqs.duplicate()
	_drop_amounts = amounts.duplicate()
	var at := reader.shard_drops()
	var live := {}
	for k in seqs.size():
		live[seqs[k]] = true
		var n := clampi(2 + amounts[k] / 4, 2, DROP_GEMS_MAX)
		var d: Array = _drops.get(seqs[k], [])
		if not d.is_empty() and d[1] != n:  # a merge made it bigger: more gems
			(d[0] as Node3D).queue_free()
			d = []
		if d.is_empty():
			var t0 := PerfMarks.start()
			var node := drop_node(n, seqs[k])
			node.rotation.y = float(seqs[k] % 7)
			add_child(node)
			d = [node, n]
			_drops[seqs[k]] = d
			PerfMarks.add(&"shards.drop_made", t0)
		(d[0] as Node3D).position = SimPlane.to_3d(at[k])
	for seq: int in _drops.keys():
		if live.has(seq):
			continue
		var node: Node3D = _drops[seq][0]
		_drops.erase(seq)
		if _was_taken(node.position, taken):
			_pulled.append([node, node.position, 0.0])
		else:
			node.queue_free()


## The drop shapes built so far (tests read it).
func shapes_built() -> int:
	return _drop_shapes.size()


## A drop of `n` gems for drop number `seq`: a copy of its size's shape, built on first use.
func drop_node(n: int, seq: int) -> Node3D:
	var key := [n, seq % DROP_SHAPES]
	if not _drop_shapes.has(key):
		var t0 := PerfMarks.start()
		var made := ShardMesh.baked(
			ShardMesh.cluster(gem_material(), n, DROP_HEIGHT, DROP_SPREAD, 1 + seq % DROP_SHAPES)
		)
		made.add_child(ShardMesh.glow(COLOR, 0.9, 0.4))
		_drop_shapes[key] = made
		PerfMarks.add(&"shards.shape_baked", t0)
	return (_drop_shapes[key] as Node3D).duplicate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for made: Node3D in _drop_shapes.values():
			made.free()


static func _was_taken(at: Vector3, taken: PackedVector2Array) -> bool:
	for p in taken:
		if SimPlane.to_3d(p).distance_to(at) < 0.05:
			return true
	return false


## Gems in flight (tests read it).
func count() -> int:
	return _g_live.count(1)


## The gems' crystal and outline batches (null before the first burst; tests read them). A slot past count() may be
## an empty one (drawn at zero size) until the gems after it land.
func gem_batches() -> Array[MultiMeshInstance3D]:
	return [_crystals, _outlines]


func _burst(at: Vector2, n: int, salt: int) -> void:
	if _mesh == null:
		_mesh = ShardMesh.shard(4, 0.1, 0.18, 0.15, 51)
	if _crystals == null:
		_crystals = _batch(gem_material())
		_crystals.name = "GemCrystals"
		_outlines = _batch(ShardMesh.outline_material())
		_outlines.name = "GemOutlines"
		_g_pos.resize(MAX_ALIVE)
		_g_vel.resize(MAX_ALIVE)
		_g_age.resize(MAX_ALIVE)
		_g_turn.resize(MAX_ALIVE)
		_g_live.resize(MAX_ALIVE)
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var origin := SimPlane.to_3d(at) + Vector3(0, HEIGHT, 0)
	for k in n:
		var slot := _g_live.find(0)
		if slot < 0:
			break
		var a := TAU * (k + rng.randf() * 0.6) / maxf(1.0, n)
		var v := Vector3(cos(a), 1.2 + rng.randf(), sin(a)) * (2.2 + rng.randf() * 1.6)
		_g_pos[slot] = origin
		_g_vel[slot] = v
		_g_age[slot] = 0.0
		_g_turn[slot] = 0.0
		_g_live[slot] = 1
		_fresh.append(slot)
	_draw_gems(false)


## One half of the gems: MAX_ALIVE instances of the shard mesh in `mat`, unshadowed, drawn wherever they fly. The
## instances move in the physics interpolation as the gems' nodes did (each slot keeps its gem for its flight).
func _batch(mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = MAX_ALIVE
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The gems are in world space, spread over the room: never cull the batch by its first instance's box.
	mmi.custom_aabb = AABB(Vector3(-512, -8, -512), Vector3(1024, 64, 1024))
	mmi.visible = false
	add_child(mmi)
	return mmi


## Writes every flying gem into both batches: the crystal turned about the vertical, its shell the same grown by
## the outline's margin (ShardMesh.outlined's shell, centred on the gem). The batches draw up to the last live slot;
## an empty slot below it is drawn at zero size. `moved`: after the gems' step (the frame's _process).
func _draw_gems(moved: bool) -> void:
	if _crystals == null:
		return
	var n := _g_live.rfind(1) + 1
	var grow := Basis.from_scale(Vector3.ONE * (1.0 + GEM_OUTLINE))
	for k in n:
		if _g_live[k] == 0:
			continue
		var b := Basis(Vector3.UP, _g_turn[k])
		_crystals.multimesh.set_instance_transform(k, Transform3D(b, _g_pos[k]))
		_outlines.multimesh.set_instance_transform(k, Transform3D(b * grow, _g_pos[k]))
	if moved:  # A new gem starts where its first step put it, as a node entering the tree did
		for slot in _fresh:
			_crystals.multimesh.reset_instance_physics_interpolation(slot)
			_outlines.multimesh.reset_instance_physics_interpolation(slot)
		_fresh.clear()
	for mmi: MultiMeshInstance3D in [_crystals, _outlines]:
		if mmi.multimesh.visible_instance_count != n:
			mmi.multimesh.visible_instance_count = n
		if mmi.visible != (n > 0):
			mmi.visible = n > 0


## A gem that reached the hero: gone at once (its slot drawn at zero size, not shrinking through the interpolation).
func _land(slot: int) -> void:
	_g_live[slot] = 0
	for mmi: MultiMeshInstance3D in [_crystals, _outlines]:
		mmi.multimesh.set_instance_transform(
			slot, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		)
		mmi.multimesh.reset_instance_physics_interpolation(slot)


func _process(delta: float) -> void:
	_process_drops(delta)
	if _crystals == null or not _g_live.has(1):
		return
	for i in _g_live.size():
		if _g_live[i] == 0:
			continue
		var age := _g_age[i] + delta
		_g_age[i] = age
		if age < BURST_S:
			_g_vel[i] *= maxf(0.0, 1.0 - delta * 5.0)
			_g_pos[i] += _g_vel[i] * delta
		else:
			var to := _target - _g_pos[i]
			var step := SPEED * delta * minf(1.0, (age - BURST_S) * 4.0 + 0.3)
			if to.length() <= maxf(step, 0.15):
				_land(i)
				continue
			_g_pos[i] += to.normalized() * step
		_g_turn[i] += delta * 9.0
	_draw_gems(true)


func _process_drops(delta: float) -> void:
	for d: Array in _drops.values():
		(d[0] as Node3D).rotation.y += delta * 0.8
	var i := 0
	while i < _pulled.size():
		var g := _pulled[i]
		var node: Node3D = g[0]
		g[2] += delta
		var t := minf(1.0, g[2] / PULL_S)
		if t >= 1.0:
			node.queue_free()
			_pulled.remove_at(i)
			continue
		node.position = (g[1] as Vector3).lerp(_target, t * t)
		node.scale = Vector3.ONE * (1.0 - 0.6 * t)
		i += 1
