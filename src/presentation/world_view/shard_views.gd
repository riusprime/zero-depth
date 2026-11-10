class_name ShardViews
extends Node3D
## Shard gems: when a kill pays shards (a SHARDS event), up to MAX_PER_KILL small violet crystals burst
## from the body, hang for a moment, then fly into the player and vanish. Cosmetic and in frame time: the sim
## already counted the shards. Jitter comes from a presentation RNG seeded per event, so shots look the same.
## Each gem is an outlined faceted shard (ShardMesh) lit by the scene with its
## own violet emission, instead of a flat unshaded crystal. The chest's price gem keeps shared_material().
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

static var _material: StandardMaterial3D
static var _mesh: ArrayMesh
static var _gem_material: StandardMaterial3D

var _last_seq := 0
var _target := Vector3.ZERO
## Each gem: [node, velocity, age].
var _gems: Array[Array] = []
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
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.SHARDS and e.effect_id == WorldReader.SHARD_PICKUP_EFFECT:
			taken.append(e.pos)
		elif e.kind == SimEvent.Kind.SHARDS:
			_burst(e.pos, mini(e.amount, MAX_PER_KILL), reader.seed_value() * 31 + e.seq)
	_sync_drops(reader, taken)


## Shard drops lying on the floor (tests read it).
func drop_count() -> int:
	return _drops.size()


## Drops being pulled into the hero (tests read it).
func pulled_count() -> int:
	return _pulled.size()


func _sync_drops(reader: WorldReader, taken: PackedVector2Array) -> void:
	var at := reader.shard_drops()
	var seqs := reader.shard_drop_seqs()
	var amounts := reader.shard_drop_amounts()
	var live := {}
	for k in seqs.size():
		live[seqs[k]] = true
		var n := clampi(2 + amounts[k] / 4, 2, DROP_GEMS_MAX)
		var d: Array = _drops.get(seqs[k], [])
		if not d.is_empty() and d[1] != n:  # a merge made it bigger: more gems
			(d[0] as Node3D).queue_free()
			d = []
		if d.is_empty():
			var node := drop_node(n, seqs[k])
			node.rotation.y = float(seqs[k] % 7)
			add_child(node)
			d = [node, n]
			_drops[seqs[k]] = d
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
		var made := ShardMesh.baked(
			ShardMesh.cluster(gem_material(), n, DROP_HEIGHT, DROP_SPREAD, 1 + seq % DROP_SHAPES)
		)
		made.add_child(ShardMesh.glow(COLOR, 0.9, 0.4))
		_drop_shapes[key] = made
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
	return _gems.size()


func _burst(at: Vector2, n: int, salt: int) -> void:
	if _mesh == null:
		_mesh = ShardMesh.shard(4, 0.1, 0.18, 0.15, 51)
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var origin := SimPlane.to_3d(at) + Vector3(0, HEIGHT, 0)
	for k in n:
		if _gems.size() >= MAX_ALIVE:
			return
		var gem := ShardMesh.outlined(_mesh, gem_material(), Vector3.ZERO, 0.2)
		(gem.get_meta(&"crystal") as MeshInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		gem.position = origin
		add_child(gem)
		var a := TAU * (k + rng.randf() * 0.6) / maxf(1.0, n)
		var v := Vector3(cos(a), 1.2 + rng.randf(), sin(a)) * (2.2 + rng.randf() * 1.6)
		_gems.append([gem, v, 0.0])


func _process(delta: float) -> void:
	_process_drops(delta)
	var i := 0
	while i < _gems.size():
		var g := _gems[i]
		var gem: Node3D = g[0]
		g[2] += delta
		if g[2] < BURST_S:
			g[1] *= maxf(0.0, 1.0 - delta * 5.0)
			gem.position += g[1] * delta
		else:
			var to := _target - gem.position
			var step := SPEED * delta * minf(1.0, (g[2] - BURST_S) * 4.0 + 0.3)
			if to.length() <= maxf(step, 0.15):
				gem.queue_free()
				_gems.remove_at(i)
				continue
			gem.position += to.normalized() * step
		gem.rotation.y += delta * 9.0
		i += 1


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
