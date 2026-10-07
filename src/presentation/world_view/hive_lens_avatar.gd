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

var eye := Node3D.new()
var iris: MeshInstance3D
var shadow: MeshInstance3D
var pods: Array[Node3D] = []
var tails: Array[Node3D] = []
var _pod_glow: Array[MeshInstance3D] = []
var _split := 0.0


## Its imported model, when the owner sends one: assets/models/bosses/hive_lens.glb (whole-body motion).
func model_id() -> StringName:
	return &"hive_lens"


func _code_nodes() -> Array[Node]:
	return [eye]


func _weak_point_at() -> Vector3:
	return Vector3(EYE_R + 0.1, HOVER_Y, 0)


## 0..1: how far the drone pods have split off (tests).
func split_amount() -> float:
	return _split


func _build() -> void:
	var p := parts
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
