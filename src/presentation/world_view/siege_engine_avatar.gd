class_name SiegeEngineAvatar
extends BossAvatar
## The Siege Engine (floor 3 boss; the sheet's FORTRESS TURRET, docs/art/first-three-bosses-concept.png): a walking
## fortress, the Needle grown huge. A red armoured box hull with a dark front plate and two red slit eyes, a long
## grey main cannon with a vented muzzle, grey armour pods on its flanks, two mortar tubes on its back glowing red
## inside, and four heavy grey mechanical legs on wide foot plates. Moves: the mortars glow and kick for a barrage,
## the cannon's muzzle charges for the rail sweep and the bolt fan, it squats to deploy; staggered, it lurches.

const HEIGHT := 2.5
const WALK_SPEED := 1.1
const STRIDE := 1.4
const HULL_Y := 1.6

const HULL_COLOR := Color("#D23E35")
const HULL_DARK := Color("#A9322B")
const PLATE_COLOR := Color("#2B2C31")
const METAL_COLOR := Color("#6A6462")
const METAL_DARK := Color("#4C4847")
const EYE_COLOR := Color("#FF2A22")
const GLOW_COLOR := Color("#FF3A26")
## v0.8.0 BA: the model's legs (BossRig), front left, front right, back left, back right.
const LEG_TAGS: Array[StringName] = [&"fl", &"fr", &"bl", &"br"]
const LEG_THIGHS: Array[StringName] = [&"thigh_fl", &"thigh_fr", &"thigh_bl", &"thigh_br"]
const LEG_SHINS: Array[StringName] = [&"shin_fl", &"shin_fr", &"shin_bl", &"shin_br"]

var hull := Node3D.new()
var cannon := Node3D.new()
var muzzle: MeshInstance3D
var eyes: Array[MeshInstance3D] = []
var mortars: Array[Node3D] = []
var legs: Array[Node3D] = []
var _mortar_glow: Array[MeshInstance3D] = []


## v0.7.5 BF3: its dodge-first moves pose as the old ones: the Turret Cross as its cannon's volleys (it recoils), the
## Mortar Grid and the Barrage's tracked circles as its mortar tubes, the Rail lane as its rail's charge.
func apply_state(s: Dictionary) -> void:
	super(s)
	match _move:
		WorldReader.MOVE_PATTERN:
			_move = WorldReader.MOVE_BOLT_FAN
		WorldReader.MOVE_GRID, WorldReader.MOVE_MARKS:
			_move = WorldReader.MOVE_BARRAGE
		WorldReader.MOVE_LANES:
			_move = WorldReader.MOVE_RAIL


## The sheet's name for this boss: its imported model would be fortress_turret.glb.
func model_id() -> StringName:
	return &"fortress_turret"


func _code_nodes() -> Array[Node]:
	return [hull, cannon]


func _recoils() -> bool:
	return true


func _build() -> void:
	var p := parts
	hull.name = "Hull"
	hull.position.y = HULL_Y
	model.add_child(hull)
	# The armoured box: main hull, a raised top plate, a lower red skirt.
	p.piece(
		hull, BossParts.block(Vector3(1.9, 1.0, 1.55), 3, 0.22), Vector3(0, 0.05, 0), HULL_COLOR
	)
	p.piece(
		hull, BossParts.block(Vector3(1.35, 0.32, 1.2), 4, 0.3), Vector3(-0.1, 0.66, 0), HULL_COLOR
	)
	# A sloped front glacis over the face plate, and a small hatch on top.
	p.piece(
		hull,
		BossParts.block(Vector3(0.55, 0.16, 1.45), 41, 0.3),
		Vector3(0.78, 0.55, 0),
		HULL_COLOR,
		Vector3(0, 0, -0.5)
	)
	p.piece(
		hull, BossParts.block(Vector3(0.45, 0.16, 0.45), 42, 0.4), Vector3(-0.2, 0.86, 0), HULL_DARK
	)
	p.piece(
		hull, BossParts.block(Vector3(1.45, 0.4, 1.35), 5, 0.25), Vector3(-0.05, -0.6, 0), HULL_DARK
	)
	# Flank armour pods.
	for side in [-1.0, 1.0]:
		p.piece(
			hull,
			BossParts.block(Vector3(0.75, 0.8, 0.42), 6, 0.3),
			Vector3(0.05, -0.12, side * 0.92),
			METAL_COLOR
		)
	# The front: a dark plate with two slit eyes, and the cannon's shroud.
	p.piece(
		hull, BossParts.block(Vector3(0.22, 0.7, 1.0), 7, 0.2), Vector3(0.95, 0.12, 0), PLATE_COLOR
	)
	for side in [-1.0, 1.0]:
		eyes.append(
			p.glow(
				hull,
				BossParts.block(Vector3(0.05, 0.36, 0.08), 8),
				Vector3(1.07, 0.24, side * 0.3),
				EYE_COLOR,
				2.6
			)
		)
	cannon.name = "Cannon"
	cannon.position = Vector3(1.0, -0.02, 0)
	hull.add_child(cannon)
	p.piece(
		cannon, BossParts.block(Vector3(0.42, 0.46, 0.5), 9, 0.25), Vector3(0.1, 0, 0), METAL_DARK
	)
	p.piece(cannon, BossParts.tube(2.5, 0.17, 10), Vector3(0.25, 0, 0), METAL_COLOR)
	# The vented muzzle: a heavier block with dark vent slots and a glowing bore.
	p.piece(
		cannon,
		BossParts.block(Vector3(0.55, 0.42, 0.42), 11, 0.2),
		Vector3(2.65, 0, 0),
		METAL_COLOR
	)
	for k in 3:
		p.piece(
			cannon,
			BossParts.block(Vector3(0.08, 0.06, 0.44), 12),
			Vector3(2.5 + k * 0.13, 0.17, 0),
			PLATE_COLOR
		)
	p.piece(
		cannon, BossParts.block(Vector3(0.04, 0.24, 0.24), 13), Vector3(2.93, 0, 0), PLATE_COLOR
	)
	muzzle = p.glow(cannon, BossParts.orb(0.09, 13, 6, 3), Vector3(2.9, 0, 0), GLOW_COLOR, 0.3)
	# Mortar tubes on the back, pointing up and back.
	for side in [-1.0, 1.0]:
		var m := Node3D.new()
		m.position = Vector3(-0.55, 0.45, side * 0.66)
		m.rotation = Vector3(side * 0.35, 0, PI * 0.5 + 0.35)
		hull.add_child(m)
		p.piece(m, BossParts.tube(0.7, 0.27, 14), Vector3(-0.1, 0, 0), METAL_DARK)
		p.piece(m, BossParts.tube(0.16, 0.32, 15), Vector3(0.48, 0, 0), METAL_COLOR)
		_mortar_glow.append(
			parts.glow(m, BossParts.orb(0.2, 16, 7, 3), Vector3(0.6, 0, 0), GLOW_COLOR, 1.8)
		)
		mortars.append(m)
	for fx in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			_build_leg(fx, side)


func _build_leg(fx: float, side: float) -> void:
	var p := parts
	var root := Node3D.new()
	root.name = "Leg_%s%s" % ["f" if fx > 0 else "b", "r" if side > 0 else "l"]
	root.position = Vector3(fx * 0.6, HULL_Y - 0.5, side * 0.7)
	model.add_child(root)
	# A heavy armoured thigh out and down to the knee, a thick shin down to a wide foot plate.
	p.piece(root, BossParts.block(Vector3(0.5, 0.5, 0.5), 20), Vector3.ZERO, METAL_DARK)
	p.piece(
		root,
		BossParts.block(Vector3(0.58, 0.62, 0.95), 21, 0.3),
		Vector3(fx * 0.18, -0.02, side * 0.48),
		METAL_COLOR,
		Vector3(side * 0.25, 0, 0)
	)
	var knee := Node3D.new()
	knee.position = Vector3(fx * 0.3, 0.02, side * 0.98)
	root.add_child(knee)
	p.piece(knee, BossParts.block(Vector3(0.42, 0.42, 0.42), 22, 0.35), Vector3.ZERO, METAL_DARK)
	p.piece(
		knee,
		BossParts.block(Vector3(0.5, 0.95, 0.48), 23, 0.3),
		Vector3(fx * 0.06, -0.55, side * 0.06),
		METAL_COLOR,
		Vector3(side * 0.08, 0, -fx * 0.08)
	)
	p.piece(
		knee,
		BossParts.block(Vector3(0.82, 0.2, 0.78), 24, 0.3),
		Vector3(fx * 0.1, -1.0, side * 0.1),
		METAL_DARK
	)
	root.set_meta(&"knee", knee)
	legs.append(root)


func _pose(dt: float) -> void:
	var walk := _gait(dt, WALK_SPEED, STRIDE)
	var s := sin(_phase)
	var mortar := 0.0
	var charge := 0.0
	var squat := 0.0
	var kick := _hit
	if _state == WorldReader.STATE_WINDUP:
		match _move:
			WorldReader.MOVE_BARRAGE:
				mortar = _wind
			WorldReader.MOVE_RAIL, WorldReader.MOVE_BOLT_FAN:
				charge = _wind
			WorldReader.MOVE_DEPLOY:
				squat = _wind
	elif _state == WorldReader.STATE_ACTIVE and _move == WorldReader.MOVE_RAIL:
		charge = 1.0
	var stag := _stagger
	hull.position.y = HULL_Y + absf(s) * 0.05 * walk - squat * 0.3 - charge * 0.08 - stag * 0.15
	hull.rotation = Vector3(
		s * 0.03 * walk + sin(_t * 10.0) * 0.05 * stag, 0, -charge * 0.05 + stag * 0.1 + kick * 0.04
	)
	cannon.position.x = (
		1.0
		- (
			kick * 0.25
			if _move == WorldReader.MOVE_BOLT_FAN or _move == WorldReader.MOVE_RAIL
			else 0.0
		)
	)
	(muzzle.material_override as StandardMaterial3D).emission_energy_multiplier = 0.3 + 5.0 * charge
	muzzle.scale = Vector3.ONE * (1.0 + charge * 0.8)
	for k in mortars.size():
		var recoil := kick if _move == WorldReader.MOVE_BARRAGE else 0.0
		mortars[k].position.x = -0.6 - recoil * 0.12
		(_mortar_glow[k].material_override as StandardMaterial3D).emission_energy_multiplier = (
			1.8 + 4.0 * mortar
		)
	for e in eyes:
		(e.material_override as StandardMaterial3D).emission_energy_multiplier = (
			2.6 + 2.0 * maxf(charge, mortar) - 2.0 * stag
		)
	for j in legs.size():
		var diag := 1.0 if j == 0 or j == 3 else -1.0
		var lift := maxf(0.0, sin(_phase) * diag) * 0.3 * walk
		var leg := legs[j]
		leg.position.y = HULL_Y - 0.5 + lift * 0.4 - squat * 0.3
		(leg.get_meta(&"knee") as Node3D).rotation = Vector3(0, 0, cos(_phase) * diag * 0.15 * walk)


## v0.8.0 BA: the owner's model (rigged in code, BossRig) plays its keyframed clips (SiegeEngineClips); the legs
## follow the clips' leg parameters, and in its last phase it stays a little lower, planted.
func _clip_library() -> Dictionary:
	return SiegeEngineClips.library()


func _walk_speed() -> float:
	return WALK_SPEED


func _stride() -> float:
	return STRIDE


func _idle_seconds() -> float:
	return 2.2


func _pose_rig(_dt: float) -> void:
	var an := animator
	var p := poser
	var squat := an.param(&"squat") + 0.35 * _late
	var lift_a := an.param(&"gait_a_lift")
	var lift_b := an.param(&"gait_b_lift")
	var swing_a := an.param(&"gait_a_swing")
	var swing_b := an.param(&"gait_b_swing")
	var front_kneel := an.param(&"front_kneel")
	var back_kneel := an.param(&"back_kneel")
	var front_lift := an.param(&"front_lift")
	for j in LEG_TAGS.size():
		var fb := 1 if j < 2 else -1
		var side := -1 if j % 2 == 0 else 1
		# The diagonal pairs: front left with back right (a), front right with back left (b).
		var a := fb * side < 0
		var lift := (lift_a if a else lift_b) + (front_lift if fb > 0 else 0.0)
		var kneel := front_kneel if fb > 0 else back_kneel
		var stride := (swing_a if a else swing_b) + kneel * 0.35 * fb
		p.turn(LEG_THIGHS[j], Vector3(0, 0, 1), stride + lift * 0.6)
		p.turn(LEG_THIGHS[j], Vector3(1, 0, 0), -side * squat * 0.26)
		p.turn(LEG_SHINS[j], Vector3(0, 0, 1), -lift * 0.9 - kneel * 0.8 * fb)
	p.shift(&"hull", Vector3(0, -0.1 * _late, 0))
