class_name HealOrbViews
extends Node3D
## Heal orbs (v0.4.0 TU, owner D8): each orb the sim lays down is a green, softly glowing crystal that pulses
## where it lies until the player walks over it. Reads WorldReader.heal_orbs / heal_orb_ids only; the pulse is
## frame time, cosmetic.
## v0.6.1 SW (owner R3, the shard look): the green sphere became an outlined faceted shard (ShardMesh) lit by the
## scene with its own emission, turning slowly in a soft additive green glow; same colour, height and pulse.

const COLOR := Color("#5CFF8A")
const RADIUS := 0.22
const HEIGHT := 0.45

static var _material: StandardMaterial3D
static var _mesh: ArrayMesh

## Orb id -> its node.
var _nodes := {}
var _t := 0.0


func _init() -> void:
	name = "HealOrbs"


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = ShardMesh.crystal_material(COLOR, 1.4)
	return _material


func sync(reader: WorldReader) -> void:
	var ids := reader.heal_orb_ids()
	var at := reader.heal_orbs()
	var keep := {}
	for k in ids.size():
		var id := ids[k]
		keep[id] = true
		if not _nodes.has(id):
			_nodes[id] = _make()
		(_nodes[id] as Node3D).position = SimPlane.to_3d(at[k]) + Vector3(0, HEIGHT, 0)
	for id in _nodes.keys():
		if not keep.has(id):
			(_nodes[id] as Node).queue_free()
			_nodes.erase(id)


## Orbs drawn (tests read it).
func count() -> int:
	return _nodes.size()


func _make() -> Node3D:
	if _mesh == null:
		_mesh = ShardMesh.shard(5, RADIUS * 0.75, RADIUS * 1.3, RADIUS, 41)
	var m := ShardMesh.outlined(_mesh, material(), Vector3.ZERO, 0.18)
	(m.get_meta(&"crystal") as MeshInstance3D).cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	m.add_child(ShardMesh.glow(COLOR, RADIUS * 4.0, 0.28))
	add_child(m)
	return m


func _process(delta: float) -> void:
	_t += delta
	var k := 0
	for id in _nodes:
		var n: Node3D = _nodes[id]
		var s := 1.0 + 0.12 * sin(_t * 4.0 + k)
		n.scale = Vector3.ONE * s
		n.rotation.y = _t * 1.2 + k
		k += 1
