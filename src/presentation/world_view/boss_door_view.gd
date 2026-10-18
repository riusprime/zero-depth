class_name BossDoorView
extends Node3D
## The boss door (v0.3.0 PLAN "Boss room and portal", B): a heavy stone slab between two jambs under a lintel, with a
## red seal on both faces. It sinks into the floor as you walk up (the doorway is open in the sim until you enter),
## rises and shuts once the sim seals it behind you, and its seal goes dark when the boss is dead. Presentation only:
## it reads WorldReader and decides nothing (EI-07); the slide is cosmetic.
##
## Local frame: the gap spans local Z, local +X points into the boss room; setup() turns +X to the sim angle.
##
## v0.8.0 BD (owner O82): the biome's own door (BossDoorModels; setup's `biome`) in place of the stone, about 18 %
## bigger (owner: "15-20% bigger"; a 2.6 m slab): its jambs stand unscaled at the gap's sides, its lintel and slab
## stretch along the gap to the sim's width (the slab is exactly the gap), the seal sits in the slab's socket on each
## face. No model for the biome (or no file): the code-made door, as before (L15).
## v0.8.0 BD (owner O83: "opening the door now is a press button"): on a floor with the press (WorldReader
## boss_door_progress >= 0) the slab follows the sim's opening (shut until pressed, down as the sim opens it, its
## landing a small shake: `landed`); the sealing behind you, and the door after the fight, as before.

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
## v0.8.0 BD: the biome's model is drawn (false: the code-made door), and its frame's parts.
var from_model := false
var jamb_n: MeshInstance3D
var jamb_p: MeshInstance3D
var lintel: MeshInstance3D
## v0.8.0 BD: the slab landed this frame (the sim's door finished opening); the world view shakes the camera.
var landed := false
var seal_material := StandardMaterial3D.new()
## 0 = shut, 1 = sunk into the floor.
var open_amount := 0.0
var _target := 0.0
var _sealed := false
var _spent := false
var _stone := StandardMaterial3D.new()
var _stone_dark := StandardMaterial3D.new()
var _slab_h := SLAB_HEIGHT
var _driven := false
var _last_progress := -1.0


func setup(
	sim_center: Vector2,
	into_angle: int,
	width: float,
	half_thick: float,
	stone: Color,
	biome: StringName = &""
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
	if _build_model(BossDoorModels.get_model(biome), width):
		_apply()
		return
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


## v0.8.0 BD: the biome's door from `model` (BossDoorModels.get_model), the gap `width` m; false (nothing built) when
## there is none.
func _build_model(model: Dictionary, width: float) -> bool:
	if model.is_empty():
		return false
	var spec: Dictionary = model["spec"]
	var parts: Dictionary = model["parts"]
	var stretch := Vector3(1, 1, width / maxf(float(spec["width"]), 0.01))
	from_model = true
	_slab_h = float(spec["slab_h"])
	jamb_n = _part(parts[&"jamb_n"], "JambN", Vector3(0, 0, -width * 0.5), Vector3.ONE)
	jamb_p = _part(parts[&"jamb_p"], "JambP", Vector3(0, 0, width * 0.5), Vector3.ONE)
	lintel = _part(parts[&"lintel"], "Lintel", Vector3.ZERO, stretch)
	slab = _part(parts[&"slab"], "Slab", Vector3.ZERO, stretch)
	# The seal: a red disc in the socket of each face (2 cm proud of its floor) and a ring of four studs round it.
	for key: String in ["seal_front", "seal_back"]:
		var sk: Vector3 = spec[key]
		var face := -1.0 if key == "seal_front" else 1.0
		_seal(slab, Vector3(sk.x + face * 0.02, sk.y, 0.0), sk.z, face)
	return true


func _part(part: Dictionary, part_name: String, at: Vector3, stretch: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = part["mesh"]
	if part["material"] != null:
		node.material_override = part["material"]
	# A jamb stands at the gap's side (`at`, unscaled); the lintel and the slab stretch about their pivot (the middle).
	node.position = at if at != Vector3.ZERO else (part["pivot"] as Vector3) * stretch
	node.scale = stretch
	add_child(node)
	return node


## A red disc of radius `r` facing `face` (-1: the front, toward -X) at `at` on `parent`, with four studs round it.
func _seal(parent: Node3D, at: Vector3, r: float, face: float) -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.9
	cyl.bottom_radius = r * 0.9
	cyl.height = 0.05
	cyl.radial_segments = 10
	disc.mesh = cyl
	disc.material_override = seal_material
	disc.rotation = Vector3(0, 0, PI * 0.5)
	disc.position = at
	parent.add_child(disc)
	for k in 4:
		var stud := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.05, 0.12, 0.12)
		stud.mesh = b
		stud.material_override = seal_material
		var a := k * PI * 0.5 + PI * 0.25
		stud.position = at + Vector3(face * 0.01, r * 1.25 * cos(a), r * 1.25 * sin(a))
		parent.add_child(stud)


## Reads the sim: open while you approach, shut once sealed, the seal spent when the portal opens. v0.8.0 BD: on a
## floor with the press, before the fight the slab is where the sim's opening is (boss_door_progress).
func sync(reader: WorldReader) -> void:
	_sealed = reader.boss_door_sealed()
	var progress := reader.boss_door_progress()
	_driven = progress >= 0.0
	landed = progress >= 1.0 and _last_progress >= 0.0 and _last_progress < 1.0
	_last_progress = progress
	if _driven:
		_target = progress
		open_amount = progress
		_apply()
	else:
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
		var rest := 0.0 if from_model else _slab_h * 0.5  # v0.8.0 BD: the model's slab is pivoted on the floor
		slab.position = Vector3(0, rest - open_amount * (_slab_h + 0.05), 0)
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
