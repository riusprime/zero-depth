class_name ShardViews
extends Node3D
## Shard gems (v0.3.0 E): when a kill pays shards (a SHARDS event), up to MAX_PER_KILL small violet crystals burst
## from the body, hang for a moment, then fly into the player and vanish. Cosmetic and in frame time: the sim
## already counted the shards. Jitter comes from a presentation RNG seeded per event, so shots look the same.
## v0.6.1 SW (owner R3, the shard look): each gem is an outlined faceted shard (ShardMesh) lit by the scene with its
## own violet emission, instead of a flat unshaded crystal. The chest's price gem keeps shared_material().

const COLOR := Color("#B48CFF")
const MAX_PER_KILL := 8
const MAX_ALIVE := 64
const BURST_S := 0.28
const SPEED := 13.0
const HEIGHT := 0.8

static var _material: StandardMaterial3D
static var _mesh: ArrayMesh
static var _gem_material: StandardMaterial3D

var _last_seq := 0
var _target := Vector3.ZERO
## Each gem: [node, velocity, age].
var _gems: Array[Array] = []


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


## v0.6.1 SW: the flying gems' material: the shard look (lit, toned facets, emission on from creation).
static func gem_material() -> StandardMaterial3D:
	if _gem_material == null:
		_gem_material = ShardMesh.crystal_material(COLOR, 1.6)
	return _gem_material


func _init() -> void:
	name = "Shards"


func sync(reader: WorldReader) -> void:
	_target = SimPlane.to_3d(reader.player_pos()) + Vector3(0, HEIGHT, 0)
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.SHARDS:
			_burst(e.pos, mini(e.amount, MAX_PER_KILL), reader.seed_value() * 31 + e.seq)


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
