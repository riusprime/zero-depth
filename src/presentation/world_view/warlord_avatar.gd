class_name WarlordAvatar
extends BossAvatar
## The Warlord (v0.4.0 BO, floor 1's second boss; prompt in docs/art/BOSSES_2.md): a shielded knight in the enemy
## style. A grey faceted armoured body over short armoured legs, a red tabard and red pauldrons, a closed grey helm
## with a glowing red T-slot visor under a crest of red crystal blades, a tall red tower shield on its left arm with a
## grey rim and a glowing emblem, and a long grey spear with a red head in its right hand. Moves: it braces behind the
## shield and bashes with it (the sweep), raises the spear and plants it to send spear lines through the floor (the
## flood), couches the spear for the lunge (the charge) and draws it back to throw for the javelin rain (the
## barrage). While its weak point is open the shield is lifted up and aside, baring the gold core on its chest (the
## sim drops its front armour then); staggered, it reels with both arms low.
## v0.7.5 BM: the owner's model (assets/models/bosses/warlord.glb, rigged by the owner: a 41-joint Tripo skeleton)
## replaces the code-built body, which stays as the fallback when the file is missing. It is posed from its bones,
## one function per layer (_pose_rig): breath and sway, a walk cycle from its speed (legs, knees, counter-swinging
## arms), the shield carried in front and lifted aside while the weak point is open, the spear raised and planted,
## couched and thrust, drawn back and thrown, a lunge lean, a flinch when hit, the stagger's reel, a fall when it
## dies, and the "shielded" hook (braced low behind the shield).

const HEIGHT := 2.7
const WALK_SPEED := 2.1
const STRIDE := 1.5
const HIP_Y := 0.85
const SHOULDER := Vector3(0.0, 0.95, 0.62)

const ARMOUR := Color("#6A6462")
const ARMOUR_DARK := Color("#4C4847")
const TRIM := Color("#2B2C31")
const RED := Color("#D23E35")
const RED_DARK := Color("#A9322B")
const VISOR := Color("#FF2A22")
const EMBLEM := Color("#FF3A26")
## v0.7.5 BM: points on the owner's model at rest (metres, model frame; evidence/BOSS_MODELS.md) and the bones they
## ride on: the chest's core, the spear's tip (right hand) and the shield's face (left forearm).
const MODEL_WEAK := Vector3(0.42, 1.35, 0)
const MODEL_SPEAR_TIP := Vector3(0.53, 2.7, 0.81)
const MODEL_SHIELD := Vector3(0.08, 0.75, -0.93)

var torso := Node3D.new()
var helm := Node3D.new()
var visor: MeshInstance3D
var emblem: MeshInstance3D
var shield_arm := Node3D.new()
var spear_arm := Node3D.new()
var shield := Node3D.new()
var spear := Node3D.new()
var legs: Array[Node3D] = []
var _lift := 0.0


## The owner's model: assets/models/bosses/warlord.glb (posed from its own bones).
func model_id() -> StringName:
	return &"warlord"


func _code_nodes() -> Array[Node]:
	return [torso, helm, shield_arm, spear_arm, shield, spear]


## The weak point sits on the chest, behind where the shield normally hangs.
func _weak_point_at() -> Vector3:
	return MODEL_WEAK if imported != null else Vector3(0.5, 1.75, 0)


func _weak_bone() -> StringName:
	return &"Spine01"


## 0..1: how far the shield is lifted (tests).
func shield_lift() -> float:
	return _lift


func has_death_pose() -> bool:
	return imported != null


func anchor_names() -> Array[StringName]:
	return [&"weak", &"spear_tip", &"shield"]


func _anchor(point: StringName) -> Vector3:
	match point:
		&"spear_tip":
			return (
				_on_bone(&"R_Hand", MODEL_SPEAR_TIP)
				if imported != null
				else model.to_local(spear.to_global(Vector3(2.4, 0, 0)))
			)
		&"shield":
			return (
				_on_bone(&"L_ForearmTwist02", MODEL_SHIELD)
				if imported != null
				else model.to_local(shield.global_position)
			)
	return weak_core.position


func _build() -> void:
	var p := parts
	torso.name = "Torso"
	torso.position.y = HIP_Y
	model.add_child(torso)
	# Armoured hips, a broad chest plate, a red tabard hanging front and back.
	p.piece(
		torso, BossParts.block(Vector3(0.75, 0.42, 0.95), 1, 0.25), Vector3(0, 0.1, 0), ARMOUR_DARK
	)
	p.piece(torso, BossParts.block(Vector3(0.9, 0.9, 1.15), 2, 0.22), Vector3(0, 0.72, 0), ARMOUR)
	p.piece(
		torso, BossParts.block(Vector3(0.3, 0.45, 0.8), 3, 0.3), Vector3(0.38, 0.85, 0), ARMOUR_DARK
	)
	p.piece(torso, BossParts.block(Vector3(0.12, 0.85, 0.6), 4, 0.15), Vector3(0.42, -0.05, 0), RED)
	p.piece(
		torso, BossParts.block(Vector3(0.12, 1.0, 0.75), 5, 0.15), Vector3(-0.42, 0.0, 0), RED_DARK
	)
	# Red pauldrons.
	for side in [-1.0, 1.0]:
		p.piece(
			torso,
			BossParts.block(Vector3(0.62, 0.32, 0.5), 6 + int(side), 0.3),
			Vector3(0.0, 1.22, side * 0.62),
			RED,
			Vector3(side * 0.28, 0, 0)
		)
	# The helm: a closed grey box with a red T visor, under a crest of red blades.
	helm.name = "Helm"
	helm.position = Vector3(0.05, 1.38, 0)
	torso.add_child(helm)
	p.piece(helm, BossParts.block(Vector3(0.52, 0.6, 0.5), 8, 0.2), Vector3(0, 0.25, 0), ARMOUR)
	visor = p.glow(
		helm, BossParts.block(Vector3(0.05, 0.08, 0.36), 9), Vector3(0.27, 0.33, 0), VISOR, 2.6
	)
	p.glow(helm, BossParts.block(Vector3(0.05, 0.3, 0.08), 10), Vector3(0.27, 0.2, 0), VISOR, 2.6)
	for k in 3:
		p.piece(
			helm,
			BossParts.crystal(0.55 - 0.1 * absf(k - 1), 0.12, 20 + k),
			Vector3(-0.08 - 0.12 * k, 0.55, 0),
			RED,
			Vector3(0, 0, 0.35 + 0.25 * k)
		)
	_build_shield_arm()
	_build_spear_arm()
	for side in [-1.0, 1.0]:
		_build_leg(side)


func _build_shield_arm() -> void:
	var p := parts
	shield_arm.name = "ShieldArm"
	shield_arm.position = SHOULDER * Vector3(1, 1, -1)
	torso.add_child(shield_arm)
	p.piece(
		shield_arm,
		BossParts.block(Vector3(0.3, 0.7, 0.3), 30, 0.3),
		Vector3(0, -0.3, 0),
		ARMOUR_DARK
	)
	shield.name = "Shield"
	shield.position = Vector3(0.45, -0.45, -0.05)
	shield_arm.add_child(shield)
	# A tall red tower shield facing +X, its grey rim and a glowing emblem.
	p.piece(shield, BossParts.block(Vector3(0.14, 1.6, 0.95), 31, 0.12), Vector3.ZERO, RED)
	p.piece(shield, BossParts.block(Vector3(0.1, 1.72, 0.12), 32), Vector3(0.02, 0, 0.5), ARMOUR)
	p.piece(shield, BossParts.block(Vector3(0.1, 1.72, 0.12), 33), Vector3(0.02, 0, -0.5), ARMOUR)
	p.piece(shield, BossParts.block(Vector3(0.1, 0.12, 1.05), 34), Vector3(0.02, 0.82, 0), ARMOUR)
	emblem = p.glow(shield, BossParts.crystal(0.5, 0.16, 35), Vector3(0.09, 0.0, 0), EMBLEM, 1.6)
	emblem.rotation = Vector3(0, 0, -PI * 0.5)


func _build_spear_arm() -> void:
	var p := parts
	spear_arm.name = "SpearArm"
	spear_arm.position = SHOULDER
	torso.add_child(spear_arm)
	p.piece(
		spear_arm,
		BossParts.block(Vector3(0.3, 0.75, 0.3), 40, 0.3),
		Vector3(0, -0.32, 0),
		ARMOUR_DARK
	)
	p.piece(
		spear_arm,
		BossParts.block(Vector3(0.32, 0.26, 0.32), 41, 0.3),
		Vector3(0.05, -0.72, 0),
		TRIM
	)
	spear.name = "Spear"
	spear.position = Vector3(0.05, -0.72, 0.05)
	spear_arm.add_child(spear)
	# A long grey shaft along +X held in the fist, a red leaf head at the front, a short butt behind.
	p.piece(spear, BossParts.tube(3.0, 0.05, 42, 6), Vector3(-0.9, 0, 0), ARMOUR)
	p.piece(
		spear, BossParts.crystal(0.55, 0.13, 43), Vector3(2.1, 0, 0), RED, Vector3(0, 0, -PI * 0.5)
	)
	p.piece(spear, BossParts.block(Vector3(0.14, 0.14, 0.14), 44), Vector3(-0.92, 0, 0), TRIM)


func _build_leg(side: float) -> void:
	var p := parts
	var salt := 0 if side < 0 else 100
	var pivot := Node3D.new()
	pivot.position = Vector3(0, HIP_Y, side * 0.3)
	model.add_child(pivot)
	p.piece(
		pivot,
		BossParts.block(Vector3(0.36, 0.5, 0.34), 50 + salt, 0.3),
		Vector3(0, -0.25, 0),
		ARMOUR_DARK
	)
	p.piece(
		pivot,
		BossParts.block(Vector3(0.4, 0.38, 0.36), 51 + salt, 0.3),
		Vector3(0.02, -0.6, 0),
		ARMOUR
	)
	p.piece(
		pivot,
		BossParts.block(Vector3(0.55, 0.14, 0.38), 52 + salt, 0.2),
		Vector3(0.1, -0.8, 0),
		TRIM
	)
	legs.append(pivot)


func _pose(dt: float) -> void:
	var walk := _gait(dt, WALK_SPEED, STRIDE)
	var s := sin(_phase)
	var breath := sin(_t * 1.5) * (1.0 - walk)
	var windup := _state == WorldReader.STATE_WINDUP
	var fade := _act_fade()
	var bash := 0.0
	var raise := 0.0
	var plant := 0.0
	var couch := 0.0
	var throw := 0.0
	match _move:
		WorldReader.MOVE_SWEEP:
			bash = -_wind if windup else fade
		WorldReader.MOVE_FLOOD:
			raise = _wind if windup else 0.0
			plant = 0.0 if windup else fade
		WorldReader.MOVE_CHARGE:
			couch = _wind if windup else fade
		WorldReader.MOVE_BARRAGE:
			throw = _wind if windup else -fade
	# The shield lifts up and aside while the weak point is open (and as the spear is planted).
	var lift_target := maxf(_weak_shown, plant * 0.6)
	_lift = lerpf(_lift, lift_target, _rate(8.0, dt))
	var stag := _stagger
	torso.position = Vector3(
		0.12 * couch - 0.06 * stag, HIP_Y + absf(s) * 0.05 * walk + breath * 0.01 - plant * 0.12, 0
	)
	torso.rotation = Vector3(
		-s * 0.05 * walk + sin(_t * 9.0) * 0.06 * stag,
		bash * 0.35 - throw * 0.3,
		0.04 * walk - couch * 0.35 - plant * 0.18 + raise * 0.08 + stag * 0.25
	)
	helm.rotation = Vector3(0, 0, couch * 0.2 - raise * 0.1 + stag * 0.15)
	(visor.material_override as StandardMaterial3D).emission_energy_multiplier = (
		2.6 + 3.0 * maxf(maxf(raise, couch), maxf(absf(bash), throw)) - 2.0 * stag
	)
	(emblem.material_override as StandardMaterial3D).emission_energy_multiplier = (
		1.6 + 2.5 * absf(bash) - 1.2 * _lift
	)
	# The shield arm: held forward across the body; drawn back then thrust for the bash; lifted when exposed.
	var guard := lerpf(0.55 - s * 0.15 * walk, -0.3, maxf(-bash, 0.0))
	guard = lerpf(guard, 1.1, maxf(bash, 0.0))
	guard = lerpf(guard, 2.6, _lift)
	guard = lerpf(guard, 0.0, stag)
	shield_arm.rotation = Vector3(-0.15 - _lift * 0.6, 0, guard)
	shield.rotation = Vector3(_lift * 0.5, 0, -guard * 0.55 + _lift * 0.4)
	# The spear arm: low at its side, raised overhead and driven down to plant, couched for the lunge, drawn
	# back for the throw.
	var swing := 0.15 + s * 0.25 * walk + breath * 0.03
	swing = lerpf(swing, 2.7, raise)
	swing = lerpf(swing, 0.9, plant)
	swing = lerpf(swing, 1.45, couch)
	swing = lerpf(swing, 2.4, maxf(throw, 0.0))
	swing = lerpf(swing, 1.6, maxf(-throw, 0.0))
	swing = lerpf(swing, -0.1, stag)
	spear_arm.rotation = Vector3(0.1 + raise * 0.2, 0, swing)
	# The spear points forward; overhead it tips down so the plant drives its head into the floor.
	spear.rotation = Vector3(0, 0, -swing + 0.1 - raise * 0.9 - plant * 1.0 + throw * 0.5)
	for k in legs.size():
		var sgn := -1.0 if k == 0 else 1.0
		legs[k].rotation = Vector3(0, 0, s * 0.4 * walk * sgn + couch * 0.2 * sgn)
		legs[k].position.y = HIP_Y + maxf(0.0, s * sgn) * 0.07 * walk


# --- The owner's model (v0.7.5 BM), posed from its bones -------------------------------------------------------
# Turns are in the model frame: +Z swings a hanging limb forward (and tips the torso back), +X swings it out to the
# left (-Z), +Y turns it to its left. A pose function adds its layer; BossAvatar commits them once per frame.


func _pose_rig(dt: float) -> void:
	var p := poser
	var walk := _walk
	var attack := _attack_amounts()
	_lift = lerpf(_lift, maxf(_weak_shown, attack["plant"] * 0.6), _rate(8.0, dt))
	_pose_idle(p, walk)
	_pose_walk(p, walk, attack)
	_pose_shield(p, attack)
	_pose_spear(p, attack)
	_pose_lunge(p, attack)
	_pose_shielded(p, _shield_hold)
	_pose_flinch(p, _flinch)
	_pose_stagger(p, _stagger)
	_pose_death(p, _death)


## This frame's attack inputs, 0..1 each (bash is -1..1: drawn back, then thrust), from the move and its phase.
func _attack_amounts() -> Dictionary:
	var windup := _state == WorldReader.STATE_WINDUP
	var fade := _act_fade()
	var out := {
		"bash": 0.0,
		"raise": 0.0,
		"plant": 0.0,
		"couch": 0.0,
		"thrust": 0.0,
		"draw": 0.0,
		"throw": 0.0,
	}
	match _move:
		WorldReader.MOVE_SWEEP:
			out["bash"] = -_wind if windup else fade
		WorldReader.MOVE_FLOOD:
			out["raise"] = _wind if windup else 0.0
			out["plant"] = 0.0 if windup else fade
		WorldReader.MOVE_CHARGE:
			out["couch"] = _wind if windup else 0.0
			out["thrust"] = 0.0 if windup else fade
		WorldReader.MOVE_BARRAGE:
			out["draw"] = _wind if windup else 0.0
			out["throw"] = 0.0 if windup else fade
	return out


## Breath (the chest rises, the shoulders lift, the head nods) and a slow sway from the hips.
func _pose_idle(p: BonePoser, walk: float) -> void:
	var calm := 1.0 - walk
	var breath := sin(_t * 1.5) * calm
	p.turn(&"Spine01", Vector3.BACK, breath * 0.025)
	p.turn(&"Spine02", Vector3.BACK, breath * 0.02)
	p.turn(&"Head", Vector3.BACK, -breath * 0.03)
	for side in ["L", "R"]:
		p.shift(StringName(side + "_Clavicle"), Vector3(0, breath * 0.012, 0))
	p.turn(&"Hip", Vector3.RIGHT, sin(_t * 0.7) * 0.025 * calm)


## The walk cycle from its speed: thighs swing, a knee bends on the leg coming forward, the feet stay flat, the hips
## roll, and the arms counter-swing (the spear arm more, the shield arm a little).
func _pose_walk(p: BonePoser, walk: float, attack: Dictionary) -> void:
	if walk <= 0.001:
		return
	var s := sin(_phase)
	var c := cos(_phase)
	var busy := 1.0 - maxf(attack["couch"], attack["thrust"])
	for side: int in [-1, 1]:
		var tag := "L_" if side < 0 else "R_"
		var swing := s * 0.45 * walk * side * busy
		var knee := -0.75 * walk * maxf(0.0, c * side) * busy
		p.turn(StringName(tag + "Thigh"), Vector3.BACK, swing)
		p.turn(StringName(tag + "Calf"), Vector3.BACK, knee)
		p.turn(StringName(tag + "Foot"), Vector3.BACK, -(swing + knee) * 0.8)
	p.turn(&"Hip", Vector3.RIGHT, s * 0.05 * walk)
	p.turn(&"Spine01", Vector3.UP, -s * 0.06 * walk)
	p.turn(&"R_Upperarm", Vector3.BACK, s * 0.3 * walk)
	p.turn(&"L_Upperarm", Vector3.BACK, -s * 0.1 * walk)


## The shield (left arm): carried turned to the front, drawn back then thrust for the bash, lifted up and aside
## while the weak point is open (the sim drops its front armour then).
func _pose_shield(p: BonePoser, attack: Dictionary) -> void:
	var bash: float = attack["bash"]
	# x: the arm forward (Z), y: the arm out (X), z: the arm turned to the front (Y), w: the forearm forward (Z).
	var carry := Vector4(0.3, -0.2, -0.9, 0.55)
	carry = carry.lerp(Vector4(-0.35, -0.1, -0.5, 0.35), maxf(-bash, 0.0))
	carry = carry.lerp(Vector4(1.15, -0.35, -1.2, 0.2), maxf(bash, 0.0))
	carry = carry.lerp(Vector4(0.55, 1.35, -0.2, 0.9), _lift)
	carry = carry.lerp(Vector4.ZERO, maxf(_stagger, _death))
	p.turn(&"L_Upperarm", Vector3.UP, carry.z)
	p.turn(&"L_Upperarm", Vector3.RIGHT, carry.y)
	p.turn(&"L_Upperarm", Vector3.BACK, carry.x)
	p.turn(&"L_Forearm", Vector3.BACK, carry.w)
	# The bash twists the torso: the shield side back in the windup, forward with the blow.
	p.turn(&"Spine01", Vector3.UP, -bash * 0.35)


## The spear (right arm): low at its side; raised overhead and driven down to plant; couched low and thrust;
## drawn back over the shoulder and thrown. The spear is on the hand bone, so the hand sets where it points.
func _pose_spear(p: BonePoser, attack: Dictionary) -> void:
	# x: the arm forward (Z), y: the forearm forward (Z), z: the hand (Z), w: the arm out (X).
	var arm := Vector4(0.0, 0.1, 0.0, 0.0)
	arm = arm.lerp(Vector4(2.5, 0.2, 1.0, -0.15), attack["raise"])
	arm = arm.lerp(Vector4(0.9, 0.3, 2.45, -0.1), attack["plant"])
	arm = arm.lerp(Vector4(-0.35, 1.25, -2.45, 0.1), attack["couch"])
	arm = arm.lerp(Vector4(0.75, 0.35, -2.65, 0.0), attack["thrust"])
	arm = arm.lerp(Vector4(2.9, 0.9, 0.9, -0.2), attack["draw"])
	arm = arm.lerp(Vector4(1.35, 0.15, -2.8, 0.0), attack["throw"])
	arm = arm.lerp(Vector4(-0.1, 0.0, 0.0, 0.0), maxf(_stagger, _death))
	p.turn(&"R_Upperarm", Vector3.RIGHT, arm.w)
	p.turn(&"R_Upperarm", Vector3.BACK, arm.x)
	p.turn(&"R_Forearm", Vector3.BACK, arm.y)
	p.turn(&"R_Hand", Vector3.BACK, arm.z)
	# The throw twists the spear side back in the draw and through with the throw; the plant bows the torso.
	p.turn(&"Spine01", Vector3.UP, -attack["draw"] * 0.35 + attack["throw"] * 0.3)
	p.turn(&"Spine01", Vector3.BACK, attack["raise"] * 0.08 - attack["plant"] * 0.28)
	p.turn(&"Head", Vector3.BACK, -attack["plant"] * 0.15 - attack["raise"] * 0.1)


## The lunge: a deep forward lean with the front leg bent and the back leg long, held through the thrust.
func _pose_lunge(p: BonePoser, attack: Dictionary) -> void:
	var lean := maxf(attack["couch"], attack["thrust"])
	if lean <= 0.001:
		return
	p.turn(&"Spine01", Vector3.BACK, -lean * 0.32)
	p.turn(&"Head", Vector3.BACK, lean * 0.2)
	p.turn(&"L_Thigh", Vector3.BACK, lean * 0.55)
	p.turn(&"L_Calf", Vector3.BACK, -lean * 0.6)
	p.turn(&"R_Thigh", Vector3.BACK, -lean * 0.4)
	p.turn(&"R_Foot", Vector3.BACK, lean * 0.3)
	pivot.position += Vector3(0.1, -0.08, 0) * lean


## The "shielded" hook (v0.7.5 BM; apply_state's "shielded", which a later step reads from the sim): braced low
## behind the shield held up in front.
func _pose_shielded(p: BonePoser, amount: float) -> void:
	if amount <= 0.001:
		return
	p.turn(&"L_Upperarm", Vector3.BACK, amount * 0.55)
	p.turn(&"L_Forearm", Vector3.BACK, amount * 0.45)
	p.turn(&"Spine01", Vector3.BACK, -amount * 0.18)
	for side in ["L_", "R_"]:
		p.turn(StringName(side + "Thigh"), Vector3.BACK, amount * 0.35)
		p.turn(StringName(side + "Calf"), Vector3.BACK, -amount * 0.6)
		p.turn(StringName(side + "Foot"), Vector3.BACK, amount * 0.25)
	pivot.position.y -= amount * 0.1


## A hit taken: the torso snaps back, the head jerks and the arms flinch out.
func _pose_flinch(p: BonePoser, amount: float) -> void:
	if amount <= 0.001:
		return
	var k := amount * amount
	p.turn(&"Spine01", Vector3.BACK, k * 0.22)
	p.turn(&"Head", Vector3.BACK, k * 0.25)
	p.turn(&"L_Upperarm", Vector3.RIGHT, k * 0.15)
	p.turn(&"R_Upperarm", Vector3.RIGHT, -k * 0.15)


## Staggered: it reels, slumped forward on bent knees with both arms low, wobbling.
func _pose_stagger(p: BonePoser, amount: float) -> void:
	if amount <= 0.001:
		return
	var wob := sin(_t * 9.0) * amount
	p.turn(&"Spine01", Vector3.BACK, -amount * 0.3 + wob * 0.05)
	p.turn(&"Spine02", Vector3.RIGHT, wob * 0.08)
	p.turn(&"Head", Vector3.BACK, -amount * 0.25)
	for side in ["L_", "R_"]:
		p.turn(StringName(side + "Thigh"), Vector3.BACK, amount * 0.25)
		p.turn(StringName(side + "Calf"), Vector3.BACK, -amount * 0.45)
	p.turn(&"L_Upperarm", Vector3.RIGHT, amount * 0.25)
	p.turn(&"R_Upperarm", Vector3.RIGHT, -amount * 0.2)


## Its death (after the sim removes it; BossAvatar.die): the knees buckle, the arms fall open and it topples onto its
## back, then sinks.
func _pose_death(p: BonePoser, amount: float) -> void:
	if amount <= 0.001:
		return
	var buckle := smoothstep(0.0, 0.35, amount)
	var fall := smoothstep(0.2, 0.85, amount)
	for side in ["L_", "R_"]:
		p.turn(StringName(side + "Thigh"), Vector3.BACK, buckle * 0.7 - fall * 0.4)
		p.turn(StringName(side + "Calf"), Vector3.BACK, -buckle * 1.1 + fall * 0.6)
	p.turn(&"L_Upperarm", Vector3.RIGHT, fall * 0.9)
	p.turn(&"R_Upperarm", Vector3.RIGHT, -fall * 0.9)
	p.turn(&"Head", Vector3.BACK, fall * 0.4)
	pivot.rotation.z += fall * 1.45
	# Lying on its back, its armour keeps it above the floor; at the very end it sinks away.
	var sink := smoothstep(0.85, 1.0, amount)
	pivot.position += Vector3(-0.5 * fall, -0.25 * buckle + 0.4 * fall - 0.9 * sink, 0)
