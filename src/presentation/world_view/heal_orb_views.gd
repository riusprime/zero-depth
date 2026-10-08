class_name HealOrbViews
extends Node3D
## Heal orbs (v0.4.0 TU, owner D8): each orb the sim lays down is a green, softly glowing sphere that pulses
## where it lies until the player walks over it. Reads WorldReader.heal_orbs / heal_orb_ids only; the pulse is
## frame time, cosmetic.

const COLOR := Color("#5CFF8A")
const RADIUS := 0.22
const HEIGHT := 0.45

static var _material: StandardMaterial3D
static var _mesh: SphereMesh

## Orb id -> its node.
var _nodes := {}
var _t := 0.0


func _init() -> void:
	name = "HealOrbs"


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = COLOR
		_material.emission_enabled = true
		_material.emission = COLOR
		_material.emission_energy_multiplier = 2.2
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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


func _make() -> MeshInstance3D:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = RADIUS
		_mesh.height = RADIUS * 2.0
		_mesh.radial_segments = 12
		_mesh.rings = 6
	var m := MeshInstance3D.new()
	m.mesh = _mesh
	m.material_override = material()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _process(delta: float) -> void:
	_t += delta
	var k := 0
	for id in _nodes:
		var n: Node3D = _nodes[id]
		var s := 1.0 + 0.12 * sin(_t * 4.0 + k)
		n.scale = Vector3.ONE * s
		k += 1
