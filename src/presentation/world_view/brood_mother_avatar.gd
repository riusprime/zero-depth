class_name BroodMotherAvatar
extends BossAvatar
## The Brood Mother (floor 2 boss; the sheet's CRAWLER QUEEN, docs/art/first-three-bosses-concept.png): a huge
## crawler queen, the Charger's mother. A red faceted hood carapace rising to a point over a dark face with a red hex
## visor; behind it a huge red egg sac of glowing spheres with spikes; four grey legs a side on dark joints, each
## ending in a long pale bone talon (the front pair longest). Moves: crouches before a leap and tucks its legs in the
## air, sinks out of sight to burrow, swells its sac before a brood; staggered, it sags and shudders.

const HEIGHT := 2.1
const WALK_SPEED := 2.4
const STRIDE := 1.5
const BODY_Y := 0.88
## Leg yaws (radians from straight out to the right side, + toward the front), the front pair first.
const LEG_YAWS := [0.95, 0.4, -0.15, -0.7]

const HOOD_COLOR := Color("#D8413A")
const FACE_COLOR := Color("#1C1D22")
const SAC_COLOR := Color("#B0302B")
const EGG_COLOR := Color("#D42A22")
const SPIKE_COLOR := Color("#5E5350")
const LEG_COLOR := Color("#5F5755")
const JOINT_COLOR := Color("#34363C")
const TALON_COLOR := Color("#E3C9B0")
const VISOR_COLOR := Color("#FF2A22")

var body := Node3D.new()
var hood: MeshInstance3D
var visor: MeshInstance3D
var sac := Node3D.new()
var eggs: Array[MeshInstance3D] = []
var legs: Array[Node3D] = []


## The sheet's name for this boss: its imported model would be crawler_queen.glb.
func model_id() -> StringName:
	return &"crawler_queen"


func _code_nodes() -> Array[Node]:
	return [body, sac]


func _build() -> void:
	var p := parts
	body.name = "Body"
	body.position.y = BODY_Y
	model.add_child(body)
	# The thorax under the hood, and the dark face with its hex visor.
	p.piece(body, BossParts.rock(Vector3(1.3, 0.7, 1.15), 3), Vector3(0.0, -0.05, 0), JOINT_COLOR)
	p.piece(body, BossParts.rock(Vector3(0.6, 0.62, 0.78), 4), Vector3(0.62, 0.05, 0), FACE_COLOR)
	visor = p.glow(
		body,
		BossParts.loft(
			BossParts.ngon(6), [[0.0, 1.0, 1.0], [1.0, 1.0, 1.0]], Vector3(0.24, 0.06, 0.24), 5
		),
		Vector3(0.9, 0.1, 0),
		VISOR_COLOR,
		2.8,
		Vector3(0, 0, -PI * 0.5)
	)
	# The hood: a faceted cowl rising to a ridged point over the face, open low at the front.
	var levels := [
		[0.0, 1.0, 1.0, -0.1],
		[0.35, 1.04, 1.02, 0.0],
		[0.75, 0.66, 0.7, 0.22],
		[1.15, 0.04, 0.04, 0.5]
	]
	hood = p.piece(
		body,
		BossParts.loft(BossParts.ngon(6, true), levels, Vector3(0.78, 1.45, 0.8), 8, 0.1),
		Vector3(0.2, 0.32, 0),
		HOOD_COLOR,
		Vector3.ZERO,
		Vector3.ONE,
		"Hood"
	)
	# The hood's flaps hang down over the sides.
	for side in [-1.0, 1.0]:
		p.piece(
			body,
			BossParts.crystal(0.62, 0.3, 9 + int(side)),
			Vector3(0.3, 0.42, side * 0.62),
			HOOD_COLOR,
			Vector3(PI - side * 0.35, 0, 0.1)
		)
	_build_sac()
	for side in [-1.0, 1.0]:
		for k in LEG_YAWS.size():
			_build_leg(side, k)


## The egg sac: a cluster of glowing eggs swelling out of a dark red membrane, with a few spikes on top.
func _build_sac() -> void:
	sac.name = "Sac"
	sac.position = Vector3(-1.15, 0.55, 0)
	body.add_child(sac)
	parts.piece(
		sac,
		BossParts.orb(0.85, 11, 9, 6),
		Vector3.ZERO,
		SAC_COLOR,
		Vector3.ZERO,
		Vector3(1.1, 1.0, 1.05)
	)
	var k := 0
	for band in [[-0.45, 6, 0.0], [-0.05, 8, 0.5], [0.4, 7, 0.2], [0.78, 3, 0.6]]:
		var y: float = band[0]
		var n: int = band[1]
		var ring := sqrt(maxf(0.0, 1.0 - y * y))
		for j in n:
			var a := TAU * (float(j) + float(band[2])) / n
			var at := Vector3(cos(a) * ring * 1.0, y * 0.92, sin(a) * ring * 0.95)
			if at.x > 0.5:
				continue  # the hood covers the front
			var r := 0.3 + BossParts.noise(40 + k) * 0.13
			# Lit eggs (so their round facets read), each with a faint inner glow (emission, not a shader swap).
			eggs.append(parts.piece(sac, BossParts.orb(r, 50 + k, 7, 5), at, EGG_COLOR))
			k += 1
	for j in 7:
		var a := TAU * (float(j) + 0.3) / 7.0
		var at := Vector3(cos(a) * 0.75 - 0.05, 0.72, sin(a) * 0.75)
		var tilt := Vector3(sin(a) * 0.8, 0, -cos(a) * 0.7)
		parts.piece(sac, BossParts.crystal(0.34, 0.08, 70 + j), at, SPIKE_COLOR, tilt)


func _build_leg(side: float, k: int) -> void:
	var p := parts
	var root := Node3D.new()
	root.name = "Leg_%s%d" % ["r" if side > 0 else "l", k]
	root.position = Vector3(0.4 - k * 0.3, -0.05, side * 0.45)
	# Local +Z points out from the body along the leg's yaw.
	root.rotation = Vector3(0, side * float(LEG_YAWS[k]) + (PI if side < 0 else 0.0), 0)
	body.add_child(root)
	var front := k == 0
	var femur := 1.25 if front else 1.12
	# Femur up and out to a high knee; tibia down and out; a long pale talon to the ground.
	p.piece(root, BossParts.orb(0.18, 80 + k, 6, 4), Vector3.ZERO, JOINT_COLOR)
	p.piece(
		root,
		BossParts.block(Vector3(0.26, 0.26, femur), 81 + k, 0.3),
		Vector3(0, 0.39 * femur, 0.31 * femur),
		LEG_COLOR,
		Vector3(-0.9, 0, 0)
	)
	var knee := Node3D.new()
	knee.position = Vector3(0, 0.78 * femur, 0.62 * femur)
	root.add_child(knee)
	p.piece(knee, BossParts.orb(0.17, 85 + k, 6, 4), Vector3.ZERO, JOINT_COLOR)
	p.piece(
		knee,
		BossParts.block(Vector3(0.22, 0.22, 1.0), 86 + k, 0.3),
		Vector3(0, -0.4, 0.3),
		LEG_COLOR,
		Vector3(0.93, 0, 0)
	)
	var talon := 1.25 if front else 1.0
	p.piece(
		knee,
		BossParts.crystal(talon, 0.15, 90 + k),
		Vector3(0, -0.7, 0.58),
		TALON_COLOR,
		Vector3(PI - 0.3, 0, 0)
	)
	root.set_meta(&"knee", knee)
	legs.append(root)


func _pose(dt: float) -> void:
	var walk := _gait(dt, WALK_SPEED, STRIDE)
	var breath := sin(_t * 2.0)
	var crouch := 0.0
	var swell := 0.0
	var tuck := 0.0
	if _state == WorldReader.STATE_WINDUP:
		match _move:
			WorldReader.MOVE_LEAP:
				crouch = _wind
			WorldReader.MOVE_BURROW:
				crouch = _wind * 0.6
			WorldReader.MOVE_BROOD:
				swell = _wind
	if _airborne:
		tuck = sin(PI * _leap)
	if _move == WorldReader.MOVE_BROOD and _state == WorldReader.STATE_ACTIVE:
		swell = 1.0
	var stag := _stagger
	body.position.y = (
		BODY_Y - crouch * 0.35 + breath * 0.02 - stag * 0.25 + absf(sin(_phase)) * 0.05 * walk
	)
	body.rotation = Vector3(sin(_t * 11.0) * 0.05 * stag, 0, -crouch * 0.12 + stag * 0.12)
	var pulse := 1.0 + swell * (0.12 + 0.04 * sin(_t * 18.0)) + breath * 0.015
	sac.scale = Vector3(pulse, pulse, pulse)
	for e in eggs:
		var em := e.material_override as StandardMaterial3D
		em.emission = EGG_COLOR
		em.emission_energy_multiplier = 0.08 + 1.5 * swell
	(visor.material_override as StandardMaterial3D).emission_energy_multiplier = (
		2.6 + 3.0 * crouch - 2.0 * stag
	)
	for j in legs.size():
		var side := -1.0 if j < LEG_YAWS.size() else 1.0
		var k := j % LEG_YAWS.size()
		var ph := _phase + (PI if (k + (0 if side > 0 else 1)) % 2 == 0 else 0.0)
		var lift := maxf(0.0, sin(ph)) * 0.35 * walk
		var swing := cos(ph) * 0.25 * walk
		var leg := legs[j]
		var base_yaw := side * float(LEG_YAWS[k]) + (PI if side < 0 else 0.0)
		leg.rotation = Vector3(
			-lift + crouch * 0.25 - tuck * 0.6 + stag * 0.2, base_yaw + swing * side, 0
		)
		(leg.get_meta(&"knee") as Node3D).rotation = Vector3(tuck * 0.8 - crouch * 0.2, 0, 0)
