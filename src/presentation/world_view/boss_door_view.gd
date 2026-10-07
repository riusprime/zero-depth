class_name BossDoorView
extends Node3D
## The boss door (v0.3.0 PLAN "Boss room and portal", B): a heavy stone slab between two jambs under a lintel, with a
## red seal on both faces. It sinks into the floor as you walk up (the doorway is open in the sim until you enter),
## rises and shuts once the sim seals it behind you, and its seal goes dark when the boss is dead. Presentation only:
## it reads WorldReader and decides nothing (EI-07); the slide is cosmetic.
##
## Local frame: the gap spans local Z, local +X points into the boss room; setup() turns +X to the sim angle.

const SLAB_HEIGHT := 2.2
const JAMB_HEIGHT := 2.5
const JAMB_W := 0.6
## The slab opens when the player is this close (m) to the door's centre and the door isn't sealed.
const OPEN_RADIUS := 5.0
## Open/close speed (fraction of the slide per second).
const SLIDE_RATE := 2.4
const SEAL_RED := Color("#E2321F")
const SEAL_ENERGY := 2.4
const SEAL_ENERGY_SPENT := 0.15

var slab: MeshInstance3D
var seal_material := StandardMaterial3D.new()
## 0 = shut, 1 = sunk into the floor.
var open_amount := 0.0
var _target := 0.0
var _sealed := false
var _spent := false
var _stone := StandardMaterial3D.new()
var _stone_dark := StandardMaterial3D.new()


func setup(
	sim_center: Vector2, into_angle: int, width: float, half_thick: float, stone: Color
) -> void:
	name = "BossDoor"
	position = SimPlane.to_3d(sim_center)
	rotation = Vector3(0, SimPlane.yaw_of(into_angle), 0)
	_stone.albedo_color = stone.darkened(0.15)
	_stone.roughness = 1.0
	_stone_dark.albedo_color = stone.darkened(0.45)
	_stone_dark.roughness = 1.0
	seal_material.albedo_color = SEAL_RED
	seal_material.emission_enabled = true
	seal_material.emission = SEAL_RED
	seal_material.emission_energy_multiplier = SEAL_ENERGY
	var depth := half_thick * 2.0 + 0.3
	for side in [-1.0, 1.0]:
		_box(
			Vector3(depth, JAMB_HEIGHT, JAMB_W),
			Vector3(0, JAMB_HEIGHT * 0.5, side * (width * 0.5 + JAMB_W * 0.5)),
			_stone_dark
		)
	_box(
		Vector3(depth + 0.1, 0.5, width + JAMB_W * 2.0 + 0.2),
		Vector3(0, JAMB_HEIGHT + 0.25, 0),
		_stone
	)
	slab = _box(Vector3(half_thick * 1.4, SLAB_HEIGHT, width - 0.04), Vector3.ZERO, _stone)
	# The seal: a red disc and a ring of four studs on each face of the slab.
	for face in [-1.0, 1.0]:
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.48
		cyl.bottom_radius = 0.48
		cyl.height = 0.06
		cyl.radial_segments = 8
		disc.mesh = cyl
		disc.material_override = seal_material
		disc.rotation = Vector3(0, 0, PI * 0.5)
		disc.position = Vector3(face * (half_thick * 0.7 + 0.03), 0.15, 0)
		slab.add_child(disc)
		for k in 4:
			var stud := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.06, 0.16, 0.16)
			stud.mesh = b
			stud.material_override = seal_material
			var a := k * PI * 0.5 + PI * 0.25
			stud.position = Vector3(
				face * (half_thick * 0.7 + 0.03), 0.15 + 0.72 * cos(a), 0.72 * sin(a)
			)
			slab.add_child(stud)
	_apply()


## Reads the sim: open while you approach, shut once sealed, the seal spent when the portal opens.
func sync(reader: WorldReader) -> void:
	_sealed = reader.boss_door_sealed()
	var near := reader.player_pos().distance_to(reader.boss_door_center()) <= OPEN_RADIUS
	_target = 1.0 if near and not _sealed else 0.0
	var spent := reader.portal_active()
	if spent != _spent:
		_spent = spent
		seal_material.emission_energy_multiplier = SEAL_ENERGY_SPENT if spent else SEAL_ENERGY


func is_sealed() -> bool:
	return _sealed


## Jumps the slide to its target (shot scripts and tests).
func settle() -> void:
	open_amount = _target
	_apply()


func _process(delta: float) -> void:
	if is_equal_approx(open_amount, _target):
		return
	open_amount = move_toward(open_amount, _target, SLIDE_RATE * delta)
	_apply()


func _apply() -> void:
	if slab != null:
		slab.position = Vector3(0, SLAB_HEIGHT * 0.5 - open_amount * (SLAB_HEIGHT + 0.05), 0)
		slab.visible = open_amount < 0.999


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var node := MeshInstance3D.new()
	node.mesh = box
	node.material_override = mat
	node.position = pos
	add_child(node)
	return node
