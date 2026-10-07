class_name GatekeeperAvatar
extends BossAvatar
## The Gatekeeper (floor 1 boss; the sheet's STONE SENTINEL, docs/art/first-three-bosses-concept.png): a colossal
## grey boulder golem, the Warden's big brother. A spiky faceted red crown of crystals over a red back shell, a dark
## visor frame with a glowing red slot, glowing red cracks across the back of the shell (the weak spot: it takes
## more from behind), huge boulder shoulders and stacked stone fists hanging almost to the ground, a dark stone core
## and short stumpy legs on wide feet. Moves: fists overhead for the slam and the lanes, a twist for the sweep, a
## head-down lean for the charge; staggered, it reels back with its arms limp.

const HEIGHT := 2.95
const WALK_SPEED := 1.5
const STRIDE := 1.7
const HIP_Y := 0.8
## Shoulder pivots in the chest frame.
const SHOULDER := Vector3(-0.02, 1.0, 0.95)
const ARM_UP := 2.6
const ARM_SLAM := 0.55

const ROCK_COLOR := Color("#6B5F5B")
const ROCK_DARK := Color("#544B49")
const CORE_COLOR := Color("#34333A")
const SHELL_COLOR := Color("#D63D33")
const CROWN_COLOR := Color("#E04437")
const VISOR_FRAME_COLOR := Color("#26262B")
const VISOR_COLOR := Color("#FF2A22")
const CRACK_COLOR := Color("#FF4A2A")

var chest := Node3D.new()
var shell: MeshInstance3D
var crown: Array[MeshInstance3D] = []
var visor: MeshInstance3D
var cracks: Node3D
var arms: Array[Node3D] = []
var fists: Array[Node3D] = []
var legs: Array[Node3D] = []
var _elbows: Array[Node3D] = []


## The sheet's name for this boss: its imported model would be stone_sentinel.glb.
func model_id() -> StringName:
	return &"stone_sentinel"


func _code_nodes() -> Array[Node]:
	return [chest]


func _build() -> void:
	var p := parts
	chest.name = "Chest"
	chest.position.y = HIP_Y
	model.add_child(chest)
	# Core: a dark stone pelvis and a stacked chest of dark stones.
	p.piece(chest, BossParts.rock(Vector3(1.0, 0.6, 0.95), 3), Vector3(0.0, 0.08, 0), CORE_COLOR)
	p.piece(chest, BossParts.rock(Vector3(1.2, 1.0, 1.25), 4), Vector3(0.05, 0.62, 0), CORE_COLOR)
	p.piece(chest, BossParts.rock(Vector3(0.55, 0.5, 0.5), 5), Vector3(0.42, 0.42, 0.32), ROCK_DARK)
	p.piece(
		chest, BossParts.rock(Vector3(0.55, 0.5, 0.5), 7), Vector3(0.42, 0.42, -0.32), ROCK_DARK
	)
	# The back shell: a big red faceted dome over the back, from the crown down to the hips, split by cracks.
	shell = p.piece(
		chest,
		BossParts.rock(Vector3(1.45, 1.55, 1.6), 9),
		Vector3(-0.4, 0.82, 0),
		SHELL_COLOR,
		Vector3(0, 0, 0.22),
		Vector3.ONE,
		"Shell"
	)
	# The head: a dark visor frame with the glowing slot, under the crown.
	p.piece(
		chest,
		BossParts.block(Vector3(0.34, 0.6, 0.46), 5),
		Vector3(0.56, 0.95, 0),
		VISOR_FRAME_COLOR
	)
	visor = p.glow(
		chest,
		BossParts.block(Vector3(0.05, 0.38, 0.12), 6),
		Vector3(0.74, 0.93, 0),
		VISOR_COLOR,
		2.6
	)
	# The crown: a cluster of red crystals rising from the head and over the shell, tallest in the middle.
	var spikes := [
		[Vector3(0.32, 1.1, 0.0), 1.45, 0.36, Vector3(0, 0, -0.08)],
		[Vector3(0.3, 1.08, 0.34), 1.2, 0.32, Vector3(0.26, 0, -0.06)],
		[Vector3(0.3, 1.08, -0.34), 1.2, 0.32, Vector3(-0.26, 0, -0.06)],
		[Vector3(0.18, 1.0, 0.64), 0.9, 0.3, Vector3(0.55, 0, 0.0)],
		[Vector3(0.18, 1.0, -0.64), 0.9, 0.3, Vector3(-0.55, 0, 0.0)],
		[Vector3(-0.2, 1.25, 0.22), 1.0, 0.34, Vector3(0.2, 0, 0.3)],
		[Vector3(-0.2, 1.25, -0.22), 1.0, 0.34, Vector3(-0.2, 0, 0.3)],
		[Vector3(-0.62, 1.12, 0.0), 0.75, 0.34, Vector3(0, 0, 0.6)],
	]
	for k in spikes.size():
		var s: Array = spikes[k]
		crown.append(
			p.piece(chest, BossParts.crystal(s[1], s[2] * 1.35, 40 + k), s[0], CROWN_COLOR, s[3])
		)
	# Red cowl plates framing the visor, down to the chest, as on the sheet's front view.
	for side in [-1.0, 1.0]:
		p.piece(
			chest,
			BossParts.crystal(0.75, 0.26, 60 + int(side)),
			Vector3(0.42, 0.7, side * 0.42),
			CROWN_COLOR,
			Vector3(side * 0.35, 0, -0.1)
		)
	# Red shell plates down the shoulders' backs, as on the sheet's side view.
	for side in [-1.0, 1.0]:
		p.piece(
			chest,
			BossParts.rock(Vector3(0.7, 0.7, 0.6), 50 + int(side)),
			Vector3(-0.15, 1.05, side * 0.62),
			SHELL_COLOR
		)
	_build_cracks()
	for side in [-1.0, 1.0]:
		_build_arm(side)
		_build_leg(side)


## Glowing cracks across the back of the shell (the weak spot), facing -X.
func _build_cracks() -> void:
	cracks = Node3D.new()
	cracks.name = "Cracks"
	cracks.position = Vector3(-1.2, 0.82, 0)
	cracks.rotation = Vector3(0, PI, -0.22)
	chest.add_child(cracks)
	var lines := [
		[
			Vector2(0.0, 0.6),
			Vector2(0.1, 0.3),
			Vector2(-0.06, 0.02),
			Vector2(0.08, -0.26),
			Vector2(0.0, -0.58)
		],
		[Vector2(-0.06, 0.02), Vector2(-0.34, 0.14), Vector2(-0.55, 0.02)],
		[Vector2(0.08, -0.26), Vector2(0.34, -0.18), Vector2(0.55, -0.34)],
		[Vector2(0.1, 0.3), Vector2(0.38, 0.42)],
		[Vector2(-0.34, 0.14), Vector2(-0.44, 0.44)],
	]
	parts.glow(cracks, BossParts.strips(lines, 0.07), Vector3.ZERO, CRACK_COLOR, 2.4)
	# The cracks run round onto the shell's flanks, as on the sheet's side view.
	for side in [-1.0, 1.0]:
		var flank := Node3D.new()
		flank.position = Vector3(-0.5, 0.8, side * 0.86)
		flank.rotation = Vector3(0, -side * PI * 0.5, 0)
		flank.scale = Vector3(1, 0.8, 0.8)
		chest.add_child(flank)
		parts.glow(flank, BossParts.strips(lines, 0.07), Vector3.ZERO, CRACK_COLOR, 2.4)


func _build_arm(side: float) -> void:
	var p := parts
	var salt := 0 if side < 0 else 100
	var arm := Node3D.new()
	arm.name = "Arm_" + ("r" if side > 0 else "l")
	arm.position = SHOULDER * Vector3(1, 1, side)
	chest.add_child(arm)
	# A huge boulder shoulder, a stone upper arm, a heavy forearm and a stacked stone fist.
	p.piece(
		arm,
		BossParts.rock(Vector3(1.05, 1.0, 1.0), 11 + salt),
		Vector3(0, 0.08, side * 0.1),
		ROCK_COLOR
	)
	p.piece(
		arm,
		BossParts.rock(Vector3(0.75, 0.7, 0.72), 13 + salt),
		Vector3(0.02, -0.5, side * 0.2),
		ROCK_DARK
	)
	var elbow := Node3D.new()
	elbow.position = Vector3(0, -0.72, side * 0.26)
	arm.add_child(elbow)
	p.piece(
		elbow,
		BossParts.rock(Vector3(0.9, 0.78, 0.88), 17 + salt),
		Vector3(0.05, -0.2, 0),
		ROCK_COLOR
	)
	var fist := Node3D.new()
	fist.name = "Fist_" + ("r" if side > 0 else "l")
	fist.position = Vector3(0.1, -0.68, side * 0.1)
	elbow.add_child(fist)
	p.piece(fist, BossParts.rock(Vector3(1.05, 0.85, 1.0), 21 + salt), Vector3.ZERO, ROCK_COLOR)
	p.piece(
		fist,
		BossParts.rock(Vector3(0.52, 0.45, 0.5), 25 + salt),
		Vector3(0.4, 0.14, side * 0.22),
		ROCK_DARK
	)
	p.piece(
		fist,
		BossParts.rock(Vector3(0.5, 0.42, 0.48), 27 + salt),
		Vector3(0.38, -0.2, -side * 0.16),
		ROCK_COLOR
	)
	p.piece(
		fist,
		BossParts.rock(Vector3(0.48, 0.4, 0.45), 29 + salt),
		Vector3(-0.1, -0.3, side * 0.3),
		ROCK_DARK
	)
	arms.append(arm)
	_elbows.append(elbow)
	fists.append(fist)


func _build_leg(side: float) -> void:
	var p := parts
	var salt := 0 if side < 0 else 100
	var pivot := Node3D.new()
	pivot.position = Vector3(0, HIP_Y, side * 0.42)
	model.add_child(pivot)
	p.piece(
		pivot, BossParts.rock(Vector3(0.62, 0.62, 0.6), 31 + salt), Vector3(0, -0.24, 0), ROCK_DARK
	)
	p.piece(
		pivot,
		BossParts.rock(Vector3(0.82, 0.4, 0.66), 33 + salt),
		Vector3(0.12, -0.58, side * 0.06),
		ROCK_COLOR
	)
	legs.append(pivot)


func _pose(dt: float) -> void:
	var walk := _gait(dt, WALK_SPEED, STRIDE)
	var s := sin(_phase)
	var breath := sin(_t * 1.4) * (1.0 - walk)
	var m := _move
	# What the arms do: raised overhead (slam, lanes), one pulled back (sweep), swept back (charge).
	var raise := 0.0
	var slam := 0.0
	var twist := 0.0
	var lean := 0.0
	if _state == WorldReader.STATE_WINDUP:
		match m:
			WorldReader.MOVE_SLAM_RING, WorldReader.MOVE_LANES:
				raise = _wind
			WorldReader.MOVE_SWEEP:
				twist = -_wind
			WorldReader.MOVE_CHARGE:
				lean = _wind
	elif _state == WorldReader.STATE_ACTIVE or _state == WorldReader.STATE_RECOVER:
		var fade := (
			1.0
			if _state == WorldReader.STATE_ACTIVE
			else 1.0 - smoothstep(20.0, 60.0, float(_state_ticks))
		)
		match m:
			WorldReader.MOVE_SLAM_RING, WorldReader.MOVE_LANES:
				slam = fade
			WorldReader.MOVE_SWEEP:
				twist = fade
			WorldReader.MOVE_CHARGE:
				lean = fade
	var stag := _stagger
	chest.position = Vector3(
		-0.08 * stag, HIP_Y + absf(s) * 0.05 * walk + breath * 0.012 - slam * 0.18 - lean * 0.1, 0
	)
	chest.rotation = Vector3(
		-s * 0.05 * walk + sin(_t * 9.0) * 0.06 * stag,
		twist * 0.9,
		0.05 * walk + raise * 0.18 - slam * 0.22 - lean * 0.35 + stag * 0.3
	)
	visor.scale = Vector3.ONE * (1.0 + raise * 0.25)
	(visor.material_override as StandardMaterial3D).emission_energy_multiplier = (
		2.6 + 3.0 * maxf(raise, lean) - 2.0 * stag
	)
	for k in arms.size():
		var side := -1.0 if k == 0 else 1.0
		var hang := 0.1 + side * s * 0.3 * walk + breath * 0.03
		var swing := lerpf(lerpf(hang, ARM_UP, raise), ARM_SLAM, slam)
		swing = lerpf(swing, -0.6, lean)
		if twist != 0.0:
			swing = lerpf(swing, 1.3, absf(twist) * (1.0 if side > 0 else 0.4))
		swing = lerpf(swing, -0.2, stag)
		var roll := -side * (0.3 - raise * 0.45 + slam * 0.1) + side * stag * 0.25
		arms[k].rotation = Vector3(roll, 0, swing)
		_elbows[k].rotation = Vector3(0, 0, raise * 0.5 + 0.1 * (1.0 - stag))
	for k in legs.size():
		var sgn := -1.0 if k == 0 else 1.0
		legs[k].rotation = Vector3(0, 0, s * 0.38 * walk * sgn)
		legs[k].position.y = HIP_Y + maxf(0.0, s * sgn) * 0.08 * walk + 0.02


## The owner's model, rigged in code (BossRig): the fists rise overhead for the slam and the lanes and come down
## hard, the right arm draws back and sweeps, the arms swing back for the charge, the legs and arms swing as it
## walks, the crown nods, and staggered the arms hang limp.
func _pose_rig(_dt: float) -> void:
	var walk := _walk
	var s := sin(_phase)
	var fade := _act_fade()
	var windup := _state == WorldReader.STATE_WINDUP
	var raise := 0.0
	var slam := 0.0
	var sweep := 0.0
	var charge := 0.0
	match _move:
		WorldReader.MOVE_SLAM_RING, WorldReader.MOVE_LANES:
			raise = _wind if windup else 0.0
			slam = 0.0 if windup else fade
		WorldReader.MOVE_SWEEP:
			sweep = -_wind if windup else fade
		WorldReader.MOVE_CHARGE:
			charge = _wind if windup else fade
	var stag := _stagger
	var wob := sin(_t * 9.0) * stag
	for side: int in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		var swing := side * s * 0.3 * walk
		swing = lerpf(lerpf(swing, 2.5, raise), 0.55, slam)
		swing = lerpf(swing, -0.55, charge)
		if sweep != 0.0:
			swing = (
				(sweep * 1.3 if sweep > 0.0 else sweep * 0.8) if side > 0 else swing + sweep * 0.2
			)
		swing = lerpf(swing, -0.1, stag)
		var roll := side * (raise * 0.35 - slam * 0.15 - 0.05) + side * stag * 0.2
		bone_q(
			StringName("arm_" + tag),
			Quaternion(Vector3.FORWARD, -roll) * Quaternion(Vector3(0, 0, 1), swing)
		)
		bone(StringName("fist_" + tag), Vector3(0, 0, 1), raise * 0.55 - slam * 0.2 + 0.05)
		bone(StringName("leg_" + tag), Vector3(0, 0, 1), s * 0.38 * walk * side)
	bone_q(
		&"torso",
		(
			Quaternion(Vector3.UP, sweep * 0.55)
			* Quaternion(Vector3(0, 0, 1), raise * 0.12 - slam * 0.18 - charge * 0.3 + wob * 0.06)
		)
	)
	bone(&"head", Vector3(0, 0, 1), -raise * 0.12 + slam * 0.15 + charge * 0.2 + wob * 0.1)
