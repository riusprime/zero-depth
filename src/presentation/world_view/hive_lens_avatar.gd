class_name HiveLensAvatar
extends BossAvatar
## The Hive Lens (v0.4.0 BO, floor 2's second boss; prompt in docs/art/BOSSES_2.md, code-built until the owner's
## sheet): a floating eye in the enemy style. A faceted grey armoured sphere hovering HOVER_Y up with a slow bob, one
## great red iris in front with a dark pupil and a ring of red crystal lashes round it, three red faceted drone pods
## docked on its rim at 120 degrees, and three grey cable tails hanging beneath with glowing red tips; a soft dark
## shadow on the ground marks where the sim has it. Moves: the iris flares and the eye turns into a beam (the rail
## sweeps), the pods pulse for the prism fan, the whole eye swells for the glare ring, and it drops onto the player
## for the dive (the leap). At half HP it splits (the deploy): the three pods drift off its rim during the windup and
## are gone once the drones are out. While its weak point is open the iris core shows gold; staggered, it sags and
## wobbles.
## v0.7.5 BM: the owner's model (assets/models/bosses/hive_lens.glb, rigged by the owner: a 23-joint Tripo skeleton)
## replaces the code-built body, which stays as the fallback when the file is missing. 1.9 m across its two side pods,
## floating with its sphere's centre HOVER_Y up, it is posed from its bones, one function per layer (_pose_rig): a
## bob and a slow roll, the crown spinning, the three cable tails swaying with a lag down each chain and trailing its
## motion, the body turning its eye to the player, an "open" pose while the weak point is open (the crown tips back
## and the pods spread), the split (the pods spread and lift through the deploy and stay apart after it), the dive,
## the glare's swell, the beam's recoil, a flinch, the stagger's sag, and the "shielded" hook: the closed pose (the
## crown folds down over the eye, the pods draw in, the tails curl up). Its ground shadow stays with the model.

const HEIGHT := 2.6
const HOVER_Y := 1.75
const BOB_M := 0.1
const EYE_R := 0.95
const SHADOW_R := 1.0

const SHELL := Color("#6A6462")
const SHELL_DARK := Color("#4C4847")
const RED := Color("#D8433A")
const IRIS := Color("#FF2A22")
const PUPIL := Color("#1B1C20")
const TIP := Color("#FF3A26")
## v0.7.5 BM: the owner's model's bones (Tripo names as Godot imports them) and its eye's front at rest (metres,
## model frame; evidence/BOSS_MODELS.md).
const SPINE_0 := &"tripo__Spine_0"
const SPINE_1 := &"tripo__Spine_1"
const CROWN_BASE := &"tripo__Spine_2"
const CROWN := &"tripo__Head_0"
const SHELL_TOP := &"bone_21"
const PODS := &"bone_22"
## The three cable tails, root first: the middle one under the back, the right one and the left one.
const TAILS: Array[Array] = [
	[
		&"tripo__1_Left_Limb_0",
		&"tripo__1_Left_Limb_1",
		&"tripo__1_Left_Limb_2",
		&"tripo__1_Left_Limb_3"
	],
	[
		&"tripo__0_Right_Limb_0",
		&"tripo__0_Right_Limb_1",
		&"tripo__0_Right_Limb_2",
		&"tripo__0_Right_Limb_3"
	],
	[
		&"tripo__0_Left_Limb_0",
		&"tripo__0_Left_Limb_1",
		&"tripo__0_Left_Limb_2",
		&"tripo__0_Left_Limb_3"
	],
]
## Each tail's side: -1 under the back (it curls and splays fore and aft), +1 right, -1 left (they splay sideways).
const TAIL_SIDE := [0, 1, -1]
const MODEL_EYE := Vector3(0.6, 1.84, 0)
## The most the body turns its eye toward the player beyond its facing (radians).
const AIM_MAX := 0.6

var eye := Node3D.new()
var iris: MeshInstance3D
var shadow: MeshInstance3D
var pods: Array[Node3D] = []
var tails: Array[Node3D] = []
var _pod_glow: Array[MeshInstance3D] = []
var _split := 0.0
# v0.7.5 BM: the cables' lagged drag (one per chain segment, model frame x/z) and the crown's spin angle.
var _drag: Array[Vector2] = []
var _spin := 0.0


## v0.7.5 BF2: its dodge-first moves pose as the old ones: a pattern (the spiral, the petals, the rings) as its prism
## fan (the crown spins up), the Focus Beam's tracked lines as its beam (the iris stretches, the body rocks back).
## The Prism Spiral's eye closing is the "shielded" pose (WorldReader.boss_shielded).
func apply_state(s: Dictionary) -> void:
	super(s)
	if _move == WorldReader.MOVE_PATTERN:
		_move = WorldReader.MOVE_BOLT_FAN
	elif _move == WorldReader.MOVE_LANES:
		_move = WorldReader.MOVE_RAIL


## The owner's model: assets/models/bosses/hive_lens.glb (posed from its own bones).
func model_id() -> StringName:
	return &"hive_lens"


func _code_nodes() -> Array[Node]:
	return [eye]


func _weak_point_at() -> Vector3:
	return MODEL_EYE if imported != null else Vector3(EYE_R + 0.1, HOVER_Y, 0)


func _weak_bone() -> StringName:
	return SPINE_1


## The model keeps the code body's ground shadow (where the sim has it).
func _build_body() -> void:
	super()
	if imported != null:
		_build_shadow()


func anchor_names() -> Array[StringName]:
	return [&"weak", &"eye"]


func _anchor(point: StringName) -> Vector3:
	if point == &"eye":
		return (
			_on_bone(SPINE_1, MODEL_EYE)
			if imported != null
			else eye.position + Vector3(EYE_R, 0, 0)
		)
	return weak_core.position


## 0..1: how far the drone pods have split off (tests).
func split_amount() -> float:
	return _split


func _build() -> void:
	var p := parts
	_build_shadow()
	_build_eye(p)


## The soft dark disc on the ground under it.
func _build_shadow() -> void:
	shadow = MeshInstance3D.new()
	shadow.name = "Shadow"
	var disc := CylinderMesh.new()
	disc.top_radius = SHADOW_R
	disc.bottom_radius = SHADOW_R
	disc.height = 0.005
	disc.radial_segments = 20
	shadow.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.35)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override = sm
	shadow.position.y = 0.012
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(shadow)


func _build_eye(p: BossParts) -> void:
	eye.name = "Eye"
	eye.position.y = HOVER_Y
	model.add_child(eye)
	# The armoured sphere: a faceted grey ball with a darker band round its middle.
	p.piece(eye, BossParts.orb(EYE_R, 1, 9, 6), Vector3.ZERO, SHELL)
	p.piece(
		eye,
		BossParts.tube(0.24, EYE_R * 1.02, 2, 10),
		Vector3(0, 0, 0),
		SHELL_DARK,
		Vector3(0, 0, PI * 0.5),
		Vector3(1, 1, 1)
	)
	# The iris (a red disc set into the front), its pupil, and a ring of red crystal lashes.
	iris = p.glow(eye, BossParts.orb(0.48, 3, 10, 3), Vector3(EYE_R - 0.18, 0, 0), IRIS, 2.4)
	iris.scale = Vector3(0.45, 1, 1)
	p.piece(
		eye,
		BossParts.orb(0.18, 4, 8, 3),
		Vector3(EYE_R + 0.06, 0, 0),
		PUPIL,
		Vector3.ZERO,
		Vector3(0.4, 1, 1)
	)
	for k in 8:
		var a := TAU * k / 8.0
		var at := Vector3(EYE_R * 0.72, cos(a) * 0.62, sin(a) * 0.62)
		p.piece(
			eye, BossParts.crystal(0.38, 0.09, 10 + k), at, RED, Vector3(a, 0, -PI * 0.5 + 0.35)
		)
	# Three drone pods docked on the rim (they split off at half HP).
	for k in 3:
		var holder := Node3D.new()
		holder.rotation = Vector3(TAU * k / 3.0 + PI / 3.0, 0, 0)
		eye.add_child(holder)
		var pod := Node3D.new()
		pod.position = Vector3(-0.2, EYE_R * 0.95, 0)
		holder.add_child(pod)
		p.piece(pod, BossParts.block(Vector3(0.55, 0.32, 0.5), 30 + k, 0.3), Vector3.ZERO, RED)
		_pod_glow.append(
			p.glow(
				pod,
				BossParts.block(Vector3(0.06, 0.08, 0.3), 33 + k),
				Vector3(0.28, 0, 0),
				IRIS,
				1.8
			)
		)
		pods.append(pod)
	# Cable tails hanging beneath, each ending in a glowing red tip.
	for k in 3:
		var tail := Node3D.new()
		tail.position = Vector3(-0.2 + 0.2 * k, -EYE_R * 0.8, (k - 1) * 0.35)
		eye.add_child(tail)
		p.piece(
			tail,
			BossParts.tube(0.75, 0.06, 40 + k, 6),
			Vector3.ZERO,
			SHELL_DARK,
			Vector3(0, 0, -PI * 0.5)
		)
		p.glow(
			tail,
			BossParts.crystal(0.22, 0.08, 45 + k),
			Vector3(0, -0.8, 0),
			TIP,
			1.6,
			Vector3(PI, 0, 0)
		)
		tails.append(tail)


func _pose(dt: float) -> void:
	_gait(dt, 2.6, 2.0)
	var windup := _state == WorldReader.STATE_WINDUP
	var fade := _act_fade()
	var beam := 0.0
	var prism := 0.0
	var glare := 0.0
	var dive := 0.0
	match _move:
		WorldReader.MOVE_RAIL:
			beam = _wind if windup else fade
		WorldReader.MOVE_BOLT_FAN:
			prism = _wind if windup else fade
		WorldReader.MOVE_SLAM_RING:
			glare = _wind if windup else fade
		WorldReader.MOVE_LEAP:
			dive = _wind if windup else 0.0
	# The split: the pods drift out through the deploy's windup and are gone after it (phase 2 onward).
	var splitting := windup and _move == WorldReader.MOVE_DEPLOY
	var target := 1.0 if _boss_phase > 0 and not splitting else (_wind if splitting else 0.0)
	_split = move_toward(_split, target, dt * 3.0)
	var stag := _stagger
	var bob := sin(_t * TAU * 0.6) * BOB_M * (1.0 - stag)
	eye.position = Vector3(-0.1 * glare, HOVER_Y + bob - 0.35 * stag - 0.25 * dive, 0)
	eye.rotation = Vector3(
		sin(_t * 1.1) * 0.05 + sin(_t * 9.0) * 0.1 * stag,
		0,
		sin(_t * 0.9) * 0.04 - dive * 0.3 + stag * 0.3 + _speed * 0.03
	)
	eye.scale = Vector3.ONE * (1.0 + glare * 0.12)
	iris.scale = Vector3(0.45, 1.0 + beam * 0.25, 1.0 + beam * 0.25)
	(iris.material_override as StandardMaterial3D).emission_energy_multiplier = (
		2.4 + 4.0 * maxf(beam, glare) - 1.6 * stag
	)
	for k in pods.size():
		var pod := pods[k]
		pod.visible = _split < 0.98
		pod.position = Vector3(-0.2, EYE_R * 0.95 + _split * 1.2, 0)
		pod.scale = Vector3.ONE * (1.0 - _split * 0.5)
		(_pod_glow[k].material_override as StandardMaterial3D).emission_energy_multiplier = (
			1.8 + 3.0 * prism + 2.0 * _split
		)
	for k in tails.size():
		tails[k].rotation = Vector3(
			sin(_t * 1.7 + k) * 0.15, 0, sin(_t * 1.3 + k * 2.0) * 0.2 - _speed * 0.08
		)
	var s := 1.0 - (bob + 0.35 * stag) * 0.4
	shadow.scale = Vector3(s, 1, s)


# --- The owner's model (v0.7.5 BM), posed from its bones -------------------------------------------------------
# Turns are in the model frame: +Z tips a part's top back (a hanging tail forward), +X tips it toward the left (a
# hanging tail out to the left, -Z), +Y turns it to its left.


func _pose_rig(dt: float) -> void:
	var p := poser
	var attack := _attack_amounts()
	var splitting := _state == WorldReader.STATE_WINDUP and _move == WorldReader.MOVE_DEPLOY
	var target := 1.0 if _boss_phase > 0 and not splitting else (_wind if splitting else 0.0)
	_split = move_toward(_split, target, dt * 3.0)
	var calm := 0.0 if ViewPrefs.reduced_motion else 1.0
	_spin = wrapf(
		_spin + dt * (0.5 + 4.0 * attack["prism"]) * maxf(calm, attack["prism"]), 0.0, TAU
	)
	_pose_hover(p, attack, calm)
	_pose_aim(p)
	_pose_tails(p, dt, attack, calm)
	_pose_open(p, _weak_shown)
	_pose_split(p, _split)
	_pose_shielded(p, _shield_hold)
	_pose_flinch(p, _flinch)
	_pose_stagger(p, _stagger)
	# It floats: every tip, roll and swell of the body turns about its sphere's centre, not the ground under it.
	var centre := Vector3(0, HOVER_Y, 0)
	pivot.position += centre - pivot.transform.basis * centre


## This frame's attack inputs, 0..1 each, from the move and its phase.
func _attack_amounts() -> Dictionary:
	var windup := _state == WorldReader.STATE_WINDUP
	var fade := _act_fade()
	var out := {"beam": 0.0, "prism": 0.0, "glare": 0.0, "dive": 0.0}
	match _move:
		WorldReader.MOVE_RAIL:
			out["beam"] = _wind if windup else fade
		WorldReader.MOVE_BOLT_FAN:
			out["prism"] = _wind if windup else fade
		WorldReader.MOVE_SLAM_RING:
			out["glare"] = _wind if windup else fade
		WorldReader.MOVE_LEAP:
			out["dive"] = _wind if windup else 0.0
	return out


## The hover: a bob, a slow roll about its eye's axis, the crown turning; the dive pitches it forward and down, the
## beam rocks it back, the glare swells it. The shadow shrinks as it rises.
func _pose_hover(p: BonePoser, attack: Dictionary, calm: float) -> void:
	var bob := sin(_t * TAU * 0.6) * BOB_M * (1.0 - _stagger) * maxf(calm, 0.3)
	pivot.position.y += bob - 0.25 * attack["dive"]
	pivot.rotation.x += sin(_t * 0.8) * 0.1 * calm
	pivot.rotation.z += -attack["dive"] * 0.45 + attack["beam"] * 0.1
	pivot.scale *= 1.0 + attack["glare"] * 0.12
	p.turn(CROWN, Vector3.UP, _spin)
	if shadow != null:
		var s := 1.0 - (bob + 0.35 * _stagger) * 0.4
		shadow.scale = Vector3(s, 1, s)


## The body turns its eye toward the player (beyond its facing, which already turns to it), with a lag.
func _pose_aim(_p: BonePoser) -> void:
	pivot.rotation.y += clampf(_aim_shown, -AIM_MAX, AIM_MAX)


## The three cable tails: each segment sways a little later than the one above it and trails the body's motion
## (more toward the tip); the glare splays them out, the dive sweeps them back.
func _pose_tails(p: BonePoser, dt: float, attack: Dictionary, calm: float) -> void:
	var n := TAILS.size() * 4
	if _drag.size() != n:
		_drag.resize(n)
		_drag.fill(Vector2.ZERO)
	var want := Vector2(_local_vel.x, _local_vel.z)
	for c in TAILS.size():
		var chain: Array = TAILS[c]
		var side: int = TAIL_SIDE[c]
		for k in chain.size():
			var j := c * 4 + k
			_drag[j] = _drag[j].lerp(want, _rate(6.0 - 1.2 * k, dt))
			var lag := float(k) * 0.7 + float(c) * 2.1
			var sway := Vector2(sin(_t * 1.7 - lag), sin(_t * 1.3 - lag)) * 0.09 * calm
			# Trailing: moving forward (+x) swings a hanging tail back (-Z turn); moving right (+z) swings it left.
			var trail := Vector2(-_drag[j].x, _drag[j].y) * 0.06
			var splay: float = attack["glare"] * 0.5 * (1.0 if k == 0 else 0.3)
			var tz: float = sway.x + trail.x - attack["dive"] * 0.25 - (splay if side == 0 else 0.0)
			var tx: float = sway.y + trail.y - splay * side
			p.turn(StringName(chain[k]), Vector3.BACK, clampf(tz, -0.7, 0.7))
			p.turn(StringName(chain[k]), Vector3.RIGHT, clampf(tx, -0.7, 0.7))


## The "open" pose while the weak point is open: the crown tips back, the shell lifts and the pods spread.
func _pose_open(p: BonePoser, amount: float) -> void:
	if amount <= 0.001:
		return
	p.turn(CROWN_BASE, Vector3.BACK, amount * 0.45)
	p.shift(SHELL_TOP, Vector3(0, amount * 0.08, 0))
	p.shift(PODS, Vector3(0, amount * 0.06, 0))
	p.stretch(PODS, 1.0 + amount * 0.1)


## The split (the deploy): the pods spread and lift off its rim through the windup, and stay apart after it.
func _pose_split(p: BonePoser, amount: float) -> void:
	if amount <= 0.001:
		return
	p.shift(PODS, Vector3(0, amount * 0.16, 0))
	p.stretch(PODS, 1.0 + amount * 0.35)
	p.turn(CROWN_BASE, Vector3.BACK, -amount * 0.1)


## The "shielded" hook (v0.7.5 BM; apply_state's "shielded", which a later step reads from the sim): the closed
## pose. The crown folds down over the eye, the shell and pods draw in, the tails curl up under it.
func _pose_shielded(p: BonePoser, amount: float) -> void:
	if amount <= 0.001:
		return
	p.turn(CROWN_BASE, Vector3.BACK, -amount * 0.85)
	p.turn(CROWN, Vector3.BACK, -amount * 0.35)
	p.shift(SHELL_TOP, Vector3(0.06, -0.04, 0) * amount)
	p.stretch(PODS, 1.0 - amount * 0.12)
	for c in TAILS.size():
		var chain: Array = TAILS[c]
		var side: int = TAIL_SIDE[c]
		for k in chain.size():
			var curl := amount * (0.35 if k == 0 else 0.55)
			if side == 0:
				p.turn(StringName(chain[k]), Vector3.BACK, curl)
			else:
				p.turn(StringName(chain[k]), Vector3.RIGHT, curl * side)


## A hit taken: it jolts back and its tails whip.
func _pose_flinch(p: BonePoser, amount: float) -> void:
	if amount <= 0.001:
		return
	var k := amount * amount
	pivot.rotation.z += k * 0.18
	pivot.position.x -= k * 0.1
	for chain: Array in TAILS:
		p.turn(StringName(chain[0]), Vector3.BACK, k * 0.3)


## Staggered: it sags toward the ground and wobbles, its tails limp and its crown drooping.
func _pose_stagger(p: BonePoser, amount: float) -> void:
	if amount <= 0.001:
		return
	pivot.position.y -= 0.35 * amount
	pivot.rotation += Vector3(sin(_t * 9.0) * 0.1, 0, 0.3) * amount
	p.turn(CROWN_BASE, Vector3.BACK, -amount * 0.3)
