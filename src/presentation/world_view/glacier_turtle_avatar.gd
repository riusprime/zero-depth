class_name GlacierTurtleAvatar
extends AvatarBase
## The Glacier Turtle on the owner's model (EnemyModels &"glacier_turtle", cut by scripts/assets/glacier_turtle_prep.py
## into the body, the ice carapace on its back, the head, the ice shield it holds in front and each of its four thick
## legs' upper half and foot), animated in code from the sim's state and drawn by the VAT crowd (SoloVat) while the
## switch is on. The owner asked for the enemies to be "animated as good as you can, if they can have multiple
## animations ... the better".
## The sim's turtle (data/enemies/glacier_turtle.tres, CanyonShore) is a Warden that walks at 1.1 m/s and turns slowly
## (45 degrees a second) to face the hero; its ice shield (its own HP) takes every hit from its front; broken, it bursts
## into three sliding ice chunks (CanyonShoreViews draws them); it winds up its slam (the telegraph), slams a disc
## round it for a tick and recovers. Its speed is the same with the shield gone.
## Its clips, each read from the sim through WorldReader (sync) and played in frame time (advance):
## - idle: a slow heavy breath lifting the carapace, the head in held looks with a sniff now and then, the shield's
##   weight swaying and hefted now and then (it settles with a bump), a foot re-planted now and then;
## - the walk: a heavy diagonal amble, each foot planted while it is down (the legs are posed by reach: hip and knee
##   solved for where the foot stands, so the body's bob, roll and pitch never drag a foot), the body low, rolling
##   with the pairs, the carapace and the shield swaying a beat behind, the head bobbing. The same legs step it round
##   while it turns: the head leads the turn, the shield swings after;
## - the brace (a hit on the shield: its shell HP fell): the shield shudders and tips back against it, the body
##   braces low behind it, the head ducks, the visor flares;
## - the tell (WINDUP, the sim's own progress): a short crouch, then it rears up on its hind legs hoisting the shield
##   high (its face kept upright), the front feet off the ground, the head up, the visor climbing and flashing from
##   TELL_FLASH_FROM (steady with reduced motion), a quiver at the top;
## - the slam (ACTIVE, then RECOVER: SLAM_SECONDS, the attack's recovery): it crashes down, the front feet stamping
##   out wide, the shield driven into the ground in front, the carapace bouncing, then it heaves itself back up;
## - the break (the shell HP reaches 0): the shield swells for a blink and is gone (its chunks fly: CanyonShoreViews),
##   the turtle reels back on its hind legs, the head jerking and shaking;
## - bare (the shield gone, for the rest of its life): crouched lower, the carapace tucked down, the head drawn in and
##   darting in quick looks, the breath quicker, the walk in shorter quicker steps with more roll, a tremble at rest;
## - a hit flinch (its HP fell): the body jolts, the carapace rattles, the head ducks, a foot lifts;
## - the rise-in (SPAWN): it pushes up from a crouch on its folded legs;
## - the death (die(): DEATH_SECONDS): the legs give way and splay, the belly drops to the ground tipping to one side,
##   the head droops to the floor, the carapace slumps, the visor goes out; a shield still held topples forward onto
##   its face (a bounce as it lands, not with reduced motion);
## - reduced motion (ViewPrefs.reduced_motion): the same clips at CALM of the body's amplitudes, no shudders, shakes,
##   quivers or trembles, the flashes steady.
## The owner's model has no bronze: its colours are drawn as delivered (the role plates take COLOR only on the
## code-made stand-in), its visor cyan.
## The breath's held looks, twitches and its clips' timers use the Frost Spitter's helpers (FrostSpitterAvatar).
## The pose is a few plain numbers (the raw drives, _vd: each joint's turn, slide or stretch) worked out from the state
## first, then the nodes from them through the joint table (_joints, the same transforms the VAT rig declares), so the
## baked pose is the live one. Presentation only (EI-07): nothing here reaches the sim. +X is the front, +Z its right.

const KIND := WorldReader.KIND_GLACIER_TURTLE
const MODEL := &"glacier_turtle"
const HEIGHT := 0.92
## The role colour (the stand-in's cap), the ice (the stand-in's shield and carapace), the gem visor's glow.
const COLOR := Color("#9A6232")
const ICE := Color("#A9D6EE")
const VISOR_COLOR := Color("#6FE3FF")
## The visor's glow at rest, at the tell's peak, its flare as the shield takes a hit.
const VISOR_REST := 1.6
const VISOR_TELL := 6.5
const VISOR_BRACE := 2.0
const TELEPORT_SPEED := 30.0
## The clips' lengths (s): the slam and its recovery (the attack's recovery_seconds), the brace, the break, a hit's
## flinch, the death; the shield's blink before it is gone.
const SLAM_SECONDS := 0.9
const BRACE_SECONDS := 0.4
const BREAK_SECONDS := 0.75
const HURT_SECONDS := 0.35
const DEATH_SECONDS := 1.2
const POP_SECONDS := 0.06
## The walk: the speed (m/s) a full stride is made at (the sim's move speed), the share of the stride a foot is down,
## the foot's sweep either side of its stride's middle (m) and its lift (m) at a full stride. The cadence keeps a
## planted foot still on the ground (the speed x DUTY over twice the sweep); bare, the sweep is BARE_SWEEP of it (so
## quicker steps). A longer stride than STRIDE_MAX quickens the cadence instead.
const MOVE_SPEED := 1.1
const DUTY := 0.6
const SWEEP := 0.11
const BARE_SWEEP := 0.75
const LIFT := 0.06
const STRIDE_MAX := 1.3
## How far (m) each pair's stride sits from its rest foot (the legs keep to their reach), the body's crouch (m) at a
## full stride, the turn rate (rad/s) of a full turning step (the sim's 45 degrees a second) and the body's turn
## (radians) one step makes.
const GATHER := [-0.04, -0.04, 0.04, 0.04]
const CROUCH := 0.045
const TURN_REF := 0.8
const TURN_SWING := 0.2
## The legs (fr / fl: the front pair; br / bl: the hind pair) and each one's place in the stride (0..1): a diagonal
## amble (the hind foot a beat after its front one).
const LEGS: Array[StringName] = [&"fr", &"fl", &"br", &"bl"]
const STRIDE_AT := [0.0, 0.5, 0.56, 0.06]
## The breath (Hz; bare, quicker by BARE_BREATH); reduced motion's share of the body's motion.
const BREATH_HZ := 0.32
const BARE_BREATH := 1.7
const CALM := 0.45
## The joints' pivots and the feet's tips (m, the model's frame) when the model is missing (the prep's own).
const PIVOTS := {
	&"body": Vector3.ZERO,
	&"carapace": Vector3(-0.186, 0.426, 0.0),
	&"head": Vector3(0.133, 0.479, 0.0),
	&"shield": Vector3(0.625, 0.0, 0.0),
	&"leg_fr_u": Vector3(0.186, 0.373, 0.279),
	&"leg_fr_l": Vector3(0.2, 0.16, 0.346),
	&"leg_fl_u": Vector3(0.186, 0.373, -0.279),
	&"leg_fl_l": Vector3(0.2, 0.16, -0.346),
	&"leg_br_u": Vector3(-0.412, 0.373, 0.279),
	&"leg_br_l": Vector3(-0.426, 0.16, 0.346),
	&"leg_bl_u": Vector3(-0.412, 0.373, -0.279),
	&"leg_bl_l": Vector3(-0.426, 0.16, -0.346),
}
const FEET := [
	Vector3(0.279, 0.013, 0.386),
	Vector3(0.279, 0.013, -0.386),
	Vector3(-0.506, 0.013, 0.399),
	Vector3(-0.506, 0.013, -0.399),
]
## The body's roll and pitch pivots (the pitch's at its hind feet: it rears up on them).
const ROLL_AT := Vector3(0.0, 0.2, 0.0)
const PITCH_AT := Vector3(-0.5, 0.03, 0.0)
## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]: the body's surge (m, + forward), roll, pitch and sway
## (its yaw), the head's nod (+ up) and yaw, the carapace's lift (m) and tilt, the shield's lift (m), tilt (+ its top
## back), roll and size (0: gone), then each leg's yaw, hip and knee turns in LEGS order. A pitch's plus is up (the
## nose), a roll's tips the top to the right (+Z).
const SURGE := 0
const ROLL := 1
const PITCH := 2
const SWAY := 3
const HEAD_P := 4
const HEAD_Y := 5
const BACK_UP := 6
const BACK_P := 7
const SHIELD_UP := 8
const SHIELD_P := 9
const SHIELD_R := 10
const SHIELD_ON := 11
const LEG0 := 12
const VAT_DRIVES := [
	[-0.12, 0.12, false],
	[-0.3, 0.3, false],
	[-0.35, 0.45, false],
	[-0.3, 0.3, false],
	[-0.6, 0.6, false],
	[-0.7, 0.7, false],
	[-0.04, 0.05, false],
	[-0.2, 0.2, false],
	[-0.1, 0.4, false],
	[-1.4, 0.5, false],
	[-0.3, 0.3, false],
	[0.0, 1.15, false],
	[-0.7, 0.7, false],
	[-1.3, 1.3, false],
	[-1.8, 1.8, false],
	[-0.7, 0.7, false],
	[-1.3, 1.3, false],
	[-1.8, 1.8, false],
	[-0.7, 0.7, false],
	[-1.3, 1.3, false],
	[-1.8, 1.8, false],
	[-0.7, 0.7, false],
	[-1.3, 1.3, false],
	[-1.8, 1.8, false],
]
## Each drive's samples (a turn finely; a slide or a stretch linear: exact on two).
const VAT_SAMPLES := [
	2, 25, 33, 25, 41, 41, 2, 25, 2, 57, 25, 2, 33, 49, 57, 33, 49, 57, 33, 49, 57, 33, 49, 57
]

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds no nodes.
var vat := false
var kind := KIND
var height := HEIGHT
## True when the body is the owner's model (else the code-made stand-in on the same joints).
var has_model := false
## The parts (tests): the rig's root (the body), the carapace, the head, the shield, each leg's upper and lower node
## (LEGS order).
var rig: Node3D
var carapace: Node3D
var head: Node3D
var shield: Node3D
var uppers: Array[Node3D] = []
var lowers: Array[Node3D] = []

var _vd := PackedFloat32Array()
var _lift := 0.0
var _visor_mat := StandardMaterial3D.new()
var _pivots := PIVOTS.duplicate()
var _feet: Array[Vector3] = []
## The joint table: [drive, parent joint, frame node or null, make (SoloVat's)], a parent before its children.
var _joints: Array = []
# Each foot's offset from its rest (m, the facing's frame on the ground) the clips ask for; the legs reach for it.
var _foot: Array[Vector3] = []
# The state the pose is made from (sync and advance keep it; VatVerify.sample sets it).
var _state := WorldReader.STATE_SPAWN
var _tell := 0.0
var _hp := -1
## The shield's HP left (-1: not read yet, whole), and how bare the turtle stands (0 shield held .. 1 gone).
var _shell := -1
var _bare := 0.0
var _speed := 0.0
## The way it goes in the facing's frame ((x, z), unit: it may back away while it faces the hero).
var _dir := Vector2.RIGHT
var _omega := 0.0
var _phase := 0.0
var _stride := 0.0
var _coil := 0.0
var _rise := 0.0
var _slam_t := -1.0
var _brace_t := -1.0
var _break_t := -1.0
var _hurt_t := -1.0
var _hurt_leg := 0
var _die_t := -1.0
var _last_fy := 0.0
var _have_fy := false


## Builds a turtle under `facing` for ActorViews (`views`: on VAT while its switch is on) and marks `root` (the
## avatar, its body materials for the hit flash); returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D) -> float:
	var turtle := GlacierTurtleAvatar.new()
	views._solo_vat(root, turtle, KIND)
	turtle.setup()
	facing.add_child(turtle)
	root.set_meta(&"enemy_avatar", turtle)
	root.set_meta(&"mats", turtle.body_materials.duplicate())
	return HEIGHT


func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	_visor_mat.albedo_color = VISOR_COLOR
	_visor_mat.emission_enabled = true
	_visor_mat.emission = VISOR_COLOR
	_visor_mat.emission_energy_multiplier = VISOR_REST
	var m := EnemyModels.get_model(MODEL)
	has_model = not m.is_empty()
	var s := 1.0
	if has_model:
		s = float(m["scale"])
		var parts_in: Dictionary = m["parts"]
		for pname: StringName in parts_in:
			_pivots[pname] = (parts_in[pname] as Dictionary)["pivot"] * float(m["scale"])
	for k in LEGS.size():
		_feet.append(FEET[k] * s)
		_foot.append(Vector3.ZERO)
	if vat:  # the crowd draws the body
		_pose()
		return
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	carapace = _node(rig, "Carapace")
	head = _node(rig, "Head")
	shield = _node(rig, "Shield")
	for k in LEGS.size():
		var up := _node(rig, "Leg_%s_u" % LEGS[k])
		uppers.append(up)
		lowers.append(_node(up, "Leg_%s_l" % LEGS[k]))
	if has_model:
		_build_model(m)
	else:
		_build_code()
	_build_joints()
	_pose()


func _node(parent: Node3D, n: String) -> Node3D:
	var node := Node3D.new()
	node.name = n
	parent.add_child(node)
	return node


## The frame node a part's mesh hangs in and that frame's own pivot (m).
func _frame_of(part: StringName) -> Array:
	match part:
		&"carapace":
			return [carapace, _pivots[&"carapace"]]
		&"head":
			return [head, _pivots[&"head"]]
		&"shield":
			return [shield, _pivots[&"shield"]]
	var s := String(part)
	var k := LEGS.find(StringName(s.substr(4, 2)))
	if not s.begins_with("leg_") or k < 0:
		return [rig, Vector3.ZERO]
	return [uppers[k] if s.ends_with("_u") else lowers[k], _pivots[part]]


## The owner's model: each part's mesh in its joint's frame, its surfaces on the base plates (the colour map as
## delivered; a role surface, if any, tinted COLOR) and the visor's glow.
func _build_model(m: Dictionary) -> void:
	var tex: Texture2D = m["texture"]
	var s: float = m["scale"]
	var parts_in: Dictionary = m["parts"]
	var mats := {}
	for slot: StringName in [&"base", &"role"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = COLOR if slot == &"role" else Color.WHITE
		mat.roughness = 1.0
		mat.set_meta(&"enemy_tex", true)
		mats[slot] = ActorViews.flashable(mat)
		body_materials.append(mat)
	for pname: StringName in parts_in:
		var part: Dictionary = parts_in[pname]
		var f: Array = _frame_of(pname)
		var mi := MeshInstance3D.new()
		mi.name = String(pname)
		mi.mesh = part["mesh"]
		mi.position = _pivots[pname] - (f[1] as Vector3)
		mi.scale = Vector3.ONE * s
		var surfaces: Array = part["surfaces"]
		for k in surfaces.size():
			mi.set_surface_override_material(
				k, _visor_mat if surfaces[k] == &"glow" else mats.get(surfaces[k], mats[&"base"])
			)
		(f[0] as Node3D).add_child(mi)


## The code-made stand-in (the model file missing): boxes on the same joints, so every clip still plays.
func _build_code() -> void:
	var charcoal := Color("#2A2828")
	var grey := Color("#5C5A58")
	_piece(rig, Vector3(0.8, 0.26, 0.6), Vector3(-0.1, 0.32, 0), charcoal)
	_piece(carapace, Vector3(0.84, 0.24, 0.8), Vector3(0.0, 0.06, 0), ICE)
	_piece(carapace, Vector3(0.3, 0.08, 0.3), Vector3(0.0, 0.2, 0), COLOR)
	_piece(head, Vector3(0.22, 0.18, 0.2), Vector3(0.12, -0.04, 0), charcoal)
	_glow_box(head, Vector3(0.03, 0.06, 0.08), Vector3(0.24, -0.04, 0), _visor_mat)
	_piece(shield, Vector3(0.12, 0.88, 0.56), Vector3(-0.1, 0.44, 0), ICE)
	for k in LEGS.size():
		var hip: Vector3 = _pivots[StringName("leg_%s_u" % LEGS[k])]
		var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
		_rod(uppers[k], Vector3.ZERO, knee - hip, grey)
		_rod(lowers[k], Vector3.ZERO, _feet[k] - knee, grey)


func _piece(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _body_piece(parent, m, at, c)


func _glow_box(parent: Node3D, size: Vector3, at: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)


func _rod(parent: Node3D, from: Vector3, to: Vector3, c: Color) -> void:
	var piece := _piece(parent, Vector3(0.12, (to - from).length(), 0.12), (from + to) * 0.5, c)
	piece.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))


## The joint table (see _joints): the body's surge, roll, pitch and sway (the rig), the head's nod at the neck and its
## yaw, the carapace's lift and tilt at its centre, the shield's lift, tilt and roll at its front foot and its size,
## each leg's yaw (about the vertical at its hip), hip turn (about the level line across the body there, turning with
## the yaw) and knee turn.
func _build_joints() -> void:
	var z := Vector3.BACK
	_joints = [
		[SURGE, -1, null, SoloVat.slide(Vector3.RIGHT)],
		[
			ROLL,
			0,
			null,
			SoloVat.turn(Vector3.RIGHT, 1.0, SoloVat.at(ROLL_AT), SoloVat.at(-ROLL_AT))
		],
		[PITCH, 1, null, SoloVat.turn(z, 1.0, SoloVat.at(PITCH_AT), SoloVat.at(-PITCH_AT))],
		[SWAY, 2, rig, SoloVat.turn(Vector3.UP)],
		[HEAD_P, 3, null, SoloVat.turn(z, 1.0, SoloVat.at(_pivots[&"head"]))],
		[HEAD_Y, 4, head, SoloVat.turn(Vector3.UP)],
		[
			BACK_UP,
			3,
			null,
			SoloVat.slide(Vector3.UP, Vector3.ZERO, SoloVat.at(_pivots[&"carapace"]))
		],
		[BACK_P, 6, carapace, SoloVat.turn(z)],
		[
			SHIELD_UP,
			3,
			null,
			SoloVat.slide(Vector3.UP, Vector3.ZERO, SoloVat.at(_pivots[&"shield"]))
		],
		[SHIELD_P, 8, null, SoloVat.turn(z)],
		[SHIELD_R, 9, null, SoloVat.turn(Vector3.RIGHT)],
		[SHIELD_ON, 10, shield, SoloVat.stretch_by(Vector3.ZERO, Vector3.ONE)],
	]
	for k in LEGS.size():
		var hip: Vector3 = _pivots[StringName("leg_%s_u" % LEGS[k])]
		var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
		_joints.append([LEG0 + 3 * k, 3, null, SoloVat.turn(Vector3.UP, 1.0, SoloVat.at(hip))])
		_joints.append([LEG0 + 3 * k + 1, _joints.size() - 1, uppers[k], SoloVat.turn(z)])
		_joints.append(
			[
				LEG0 + 3 * k + 2,
				_joints.size() - 1,
				lowers[k],
				SoloVat.turn(z, 1.0, SoloVat.at(knee - hip))
			]
		)


# --- Sync ---------------------------------------------------------------------------------------------------------
func sync(reader: WorldReader, i: int) -> void:
	apply_state(
		{
			"tick": reader.tick(),
			"state": reader.actor_state(i),
			"pos": reader.actor_pos(i),
			"windup": windup_progress(reader, i),
			"hp": reader.actor_hp(i),
			"shell": reader.shell_hp(i),
		}
	)


## The same as sync(), from plain values (tests, EnemyShadows): tick, state, pos, windup (0..1); hp and shell (the
## shield's HP left) optional.
func apply_state(s: Dictionary) -> void:
	var st: int = s["state"]
	var hp: int = s.get("hp", -1)
	var shell: int = s.get("shell", -1)
	if _fresh:
		_rise = 0.0 if st == WorldReader.STATE_SPAWN else 1.0
		_bare = 1.0 if shell == 0 else 0.0
	else:
		var slammed := st == WorldReader.STATE_ACTIVE and _state != WorldReader.STATE_ACTIVE
		var missed := st == WorldReader.STATE_RECOVER and _state == WorldReader.STATE_WINDUP
		if slammed or missed:  # (a tick's slam missed between two syncs still slams)
			_slam_t = 0.0
		if shell == 0 and _shell != 0:
			_break_t = 0.0
		elif shell >= 0 and _shell > 0 and shell < _shell:
			_brace_t = 0.0
		if hp >= 0 and _hp >= 0 and hp < _hp:
			_hurt_t = 0.0
			_hurt_leg = (_hurt_leg + 1) % LEGS.size()
	_track_motion(int(s["tick"]), s.get("pos", Vector2.ZERO), TELEPORT_SPEED)
	_state = st
	_tell = float(s.get("windup", 0.0))
	_hp = hp
	_shell = shell
	if _fresh:
		_fresh = false
		_pose()


# --- Frame time ---------------------------------------------------------------------------------------------------
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0:
		return
	_t += dt
	var dying := _die_t >= 0.0
	var moving := _state == WorldReader.STATE_MOVE and not dying
	_speed = lerpf(_speed, _vel.length() if moving else 0.0, _rate(8.0 if moving else 14.0, dt))
	_turning(dt, dying)
	var local := Vector3(_vel.x, 0.0, -_vel.y).rotated(Vector3.UP, -_last_fy)
	if moving and local.length() > 0.2:
		var to := _dir.lerp(Vector2(local.x, local.z).normalized(), _rate(10.0, dt))
		_dir = to.normalized() if to.length() > 0.05 else _dir
	# The stride: the walk's and the turn's share, at the cadence that keeps a planted foot still.
	var most := maxf(_speed / MOVE_SPEED, absf(_omega) / TURN_REF)
	_stride = move_toward(_stride, minf(most, 1.0), dt * 4.0)
	var hz := MOVE_SPEED * DUTY / (2.0 * _sweep())
	_phase = fposmod(_phase + hz * maxf(1.0, most / STRIDE_MAX) * dt * signf(_stride), 1.0)
	var winding := _state == WorldReader.STATE_WINDUP and not dying
	_coil = _tell if winding else move_toward(_coil, 0.0, dt * 10.0)
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 1.8))
	_bare = move_toward(_bare, 1.0 if _shell == 0 else 0.0, dt * 1.6)
	_slam_t = FrostSpitterAvatar._clip(_slam_t, dt, SLAM_SECONDS)
	_brace_t = FrostSpitterAvatar._clip(_brace_t, dt, BRACE_SECONDS)
	_break_t = FrostSpitterAvatar._clip(_break_t, dt, BREAK_SECONDS)
	_hurt_t = FrostSpitterAvatar._clip(_hurt_t, dt, HURT_SECONDS)
	if dying:
		_die_t += dt
	_pose()


## The foot's sweep (m) either side of its stride's middle now: shorter (so quicker steps) as it stands bare.
func _sweep() -> float:
	return SWEEP * lerpf(1.0, BARE_SWEEP, _bare)


## The facing's turn rate (rad/s, + toward -Z: Godot's yaw), from the facing node the sim's facing turns (ActorViews).
func _turning(dt: float, dying: bool) -> void:
	var fy := (get_parent() as Node3D).rotation.y if get_parent() is Node3D else 0.0
	var w := 0.0
	if _have_fy and not dying:
		w = clampf(wrapf(fy - _last_fy, -PI, PI) / dt, -6.0, 6.0)
	_omega = lerpf(_omega, w, _rate(10.0, dt))
	_last_fy = fy
	_have_fy = true


## Starts the death (ActorViews, when the sim drops the turtle: its bar hidden, freed DEATH_SECONDS later). True: it
## plays.
func die() -> bool:
	if _die_t < 0.0:
		_die_t = 0.0
	return true


func dying() -> bool:
	return _die_t >= 0.0


## The shield's size now (the SHIELD_ON drive: 1 held, 0 gone; tests, the e2e), how bare it stands, the visor's glow.
func shield_shown() -> float:
	return _vd[SHIELD_ON]


func bareness() -> float:
	return _bare


func visor_energy() -> float:
	return _visor_mat.emission_energy_multiplier


## The raw drives now (tests).
func drives() -> PackedFloat32Array:
	return _vd


## Where foot `k`'s tip and its knee stand now (m, the facing's frame; tests): the legs' chain from the drives.
func foot_at(k: int) -> Vector3:
	var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
	var low := Transform3D(Basis(Vector3.BACK, _vd[LEG0 + 3 * k + 2]), Vector3.ZERO)
	return _upper_xf(k) * low * (_feet[k] - knee)


func knee_at(k: int) -> Vector3:
	return _upper_xf(k) * Vector3.ZERO


## Where the shield's front foot stands now (m, the facing's frame; tests): it keeps to the ground while held.
func shield_foot() -> Vector3:
	return _body_xf(_vd) * (_pivots[&"shield"] + Vector3(0.0, _vd[SHIELD_UP], 0.0))


## Leg `k`'s knee frame (its origin the knee) in the facing's frame.
func _upper_xf(k: int) -> Transform3D:
	var hip: Vector3 = _pivots[StringName("leg_%s_u" % LEGS[k])]
	var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
	var yaw := Transform3D(Basis(Vector3.UP, _vd[LEG0 + 3 * k]), hip)
	var up := Transform3D(Basis(Vector3.BACK, _vd[LEG0 + 3 * k + 1]), Vector3.ZERO)
	return _body_xf(_vd) * yaw * up * SoloVat.at(knee - hip)


# --- The pose -----------------------------------------------------------------------------------------------------
## The pose's numbers from the state (_vd, the lift, the visor's glow): the clips' body drives and the feet's places
## first, then the legs reach for the feet under that body and the shield keeps to the ground; then (the code path)
## the nodes from them.
func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var k := CALM if calm else 1.0
	var d := PackedFloat32Array()
	d.resize(VAT_DRIVES.size())
	for j in LEGS.size():
		_foot[j] = Vector3.ZERO
	var breath := sin(TAU * _breath_t())
	var lift := _walk_pose(d, k)
	lift += _idle_pose(d, k, calm, breath)
	lift += _bare_pose(d, k, calm)
	lift += _tell_pose(d, k, calm)
	lift += _slam_pose(d, k, calm)
	lift += _brace_pose(d, k, calm)
	lift += _break_pose(d, k, calm)
	lift += _hurt_pose(d, k, calm)
	lift += _rise_pose(d)
	lift = _death_pose(d, lift, calm)
	d[SHIELD_UP] -= lift  # a held shield stands on the ground under the body's bob
	d[SHIELD_ON] = _shield_size()
	for j in LEG0:
		d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	_lift = lift
	_reach(d)
	for j in range(LEG0, VAT_DRIVES.size()):
		d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	_vd = d
	_visor_mat.emission_energy_multiplier = _visor(calm)
	if not vat and rig != null:
		_apply()


## The breath's clock (cycles): quicker as it stands bare (its rate eased, so the breath never jumps).
func _breath_t() -> float:
	return _t * BREATH_HZ * lerpf(1.0, BARE_BREATH, _bare)


## The shield's size: held (1); gone once broken, after a blink where it swells (POP_SECONDS from the break).
func _shield_size() -> float:
	if _shell != 0:
		return 1.0
	if _break_t >= 0.0 and _break_t < POP_SECONDS:
		return 1.0 + 0.12 * smoothstep(0.0, POP_SECONDS, _break_t)
	return 0.0


## The rig's transform (the body's: the lift, the surge, the roll, the pitch and the sway) from the drives `d`, as
## _apply composes it.
func _body_xf(d: PackedFloat32Array) -> Transform3D:
	var roll := Transform3D(Basis(Vector3.RIGHT, d[ROLL]), Vector3.ZERO)
	var pitch := Transform3D(Basis(Vector3.BACK, d[PITCH]), Vector3.ZERO)
	return (
		Transform3D(Basis.IDENTITY, Vector3(d[SURGE], _lift, 0.0))
		* SoloVat.at(ROLL_AT)
		* roll
		* SoloVat.at(-ROLL_AT)
		* SoloVat.at(PITCH_AT)
		* pitch
		* SoloVat.at(-PITCH_AT)
		* Transform3D(Basis(Vector3.UP, d[SWAY]), Vector3.ZERO)
	)


## The legs reach for their feet (_foot: each one's offset from its rest on the ground): under the body's transform
## now, each leg's yaw turns its plane through the foot, then its hip and knee bend in that plane so the foot's tip
## lands there (two bones; past the leg's reach the foot stops short, off the ground).
func _reach(d: PackedFloat32Array) -> void:
	var inv := _body_xf(d).affine_inverse()
	for j in LEGS.size():
		var hip: Vector3 = _pivots[StringName("leg_%s_u" % LEGS[j])]
		var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[j])]
		var tip: Vector3 = _feet[j]
		var v := inv * (tip + _foot[j]) - hip
		var r0 := tip - hip
		# The yaw that brings the foot to its rest's distance across the leg's plane (the hip and the knee turn in that
		# plane, keeping it), the smaller of the two.
		var across := acos(clampf(r0.z / maxf(Vector2(v.x, v.z).length(), 0.0001), -1.0, 1.0))
		var toward := atan2(v.x, v.z)
		var y1 := wrapf(toward - across, -PI, PI)
		var y2 := wrapf(toward + across, -PI, PI)
		var yaw := y1 if absf(y1) < absf(y2) else y2
		var t := v.rotated(Vector3.UP, -yaw)
		var aim := Vector2(t.x, t.y)
		var u0 := Vector2(knee.x - hip.x, knee.y - hip.y)
		var l0 := Vector2(tip.x - knee.x, tip.y - knee.y)
		var a := u0.length()
		var b := l0.length()
		var reach := clampf(aim.length(), absf(a - b) + 0.002, (a + b) * 0.998)
		var bend := signf(Vector2(r0.x, r0.y).cross(u0))
		var off := acos(clampf((a * a + reach * reach - b * b) / (2.0 * a * reach), -1.0, 1.0))
		var hip_turn := wrapf(aim.angle() + bend * off - u0.angle(), -PI, PI)
		var l1 := aim.normalized() * reach - u0.rotated(hip_turn)
		d[LEG0 + 3 * j] = yaw
		d[LEG0 + 3 * j + 1] = hip_turn
		d[LEG0 + 3 * j + 2] = wrapf(l1.angle() - l0.angle() - hip_turn, -PI, PI)


## The walk (and the turn's stepping): each foot through its stride at its pair's place, along the way the body goes
## (the facing's frame), the turn sweeping it round the body; the body low, bobbing as each pair lands and rolling
## with them (more when bare), the carapace and the shield swaying a beat behind, the head bobbing and leading a turn.
## Returns its lift.
func _walk_pose(d: PackedFloat32Array, k: float) -> float:
	var g := clampf(_stride, 0.0, 1.0)
	var walk := clampf(_speed / MOVE_SPEED, 0.0, STRIDE_MAX)
	var turn := clampf(_omega / TURN_REF, -1.0, 1.0)
	var dir := Vector3(_dir.x, 0.0, _dir.y)
	var sweep := _sweep()
	for j in LEGS.size():
		var c := leg_cycle(fposmod(_phase - float(STRIDE_AT[j]), 1.0))
		var tip: Vector3 = _feet[j]
		var th := turn * TURN_SWING * c.x
		_foot[j] += (
			dir * (walk * sweep * c.x)
			+ Vector3(minf(walk, 1.0) * float(GATHER[j]) + th * tip.z, LIFT * g * c.y, -th * tip.x)
		)
	d[HEAD_Y] += 0.3 * turn * k  # the head leads a turn
	d[SHIELD_R] -= 0.04 * turn * k  # and the shield swings after it
	if g <= 0.0:
		return 0.0
	var p := _phase
	var w := minf(walk, 1.0)
	var rock := 1.0 + 0.6 * _bare
	d[ROLL] += g * k * 0.05 * rock * sin(TAU * (p - 0.1))
	d[SWAY] += w * k * 0.04 * sin(TAU * (p + 0.15))
	d[PITCH] += w * k * 0.012 * sin(2.0 * TAU * (p - 0.1))
	d[HEAD_Y] -= w * k * 0.04 * sin(TAU * (p + 0.15))
	d[HEAD_P] += w * k * 0.05 * cos(2.0 * TAU * (p - 0.2)) - w * 0.04
	d[BACK_UP] += g * k * 0.006 * sin(2.0 * TAU * (p - 0.18))
	d[BACK_P] += g * k * 0.02 * sin(2.0 * TAU * (p - 0.25))
	d[SHIELD_P] += g * k * 0.025 * sin(2.0 * TAU * (p - 0.3))
	d[SHIELD_R] += g * k * 0.03 * sin(TAU * (p - 0.3))
	return -CROUCH * w - g * k * 0.014 * cos(2.0 * TAU * (p - 0.05))


## One foot through its stride at q (0 its touchdown): (the sweep: 1 ahead .. -1 behind; the lift 0..1). On the
## ground the foot keeps still while the body passes over it; in the air it lifts and comes forward eased.
static func leg_cycle(q: float) -> Vector2:
	if q < DUTY:
		return Vector2(1.0 - 2.0 * q / DUTY, 0.0)
	var w := (q - DUTY) / (1.0 - DUTY)
	var up := sin(PI * w)
	return Vector2(-1.0 + 2.0 * smoothstep(0.0, 1.0, w), up * up * (3.0 - 2.0 * up))


## Idle (fading as it walks, winds up or dies): the breath lifting the carapace and the body, the head's held looks
## and a sniff now and then, the shield swaying under its weight and hefted now and then, a foot re-planted now and
## then. Returns its lift.
func _idle_pose(d: PackedFloat32Array, k: float, calm: bool, breath: float) -> float:
	var idle := (1.0 - clampf(_stride, 0.0, 1.0)) * (1.0 - _coil) * (1.0 if _die_t < 0.0 else 0.0)
	if idle <= 0.0:
		return 0.0
	var every := lerpf(3.0, 1.1, _bare)  # bare, it darts its looks
	d[BACK_UP] += idle * k * 0.007 * (breath + 1.0)
	d[BACK_P] -= idle * k * 0.012 * breath
	d[HEAD_Y] += idle * k * 0.4 * FrostSpitterAvatar._scan(_t, every, 0.0)
	d[HEAD_P] += (
		idle * k * (0.08 * FrostSpitterAvatar._scan(_t, every * 1.3, 5.0) + 0.02 * (breath + 1.0))
	)
	d[ROLL] += idle * k * 0.02 * sin(0.5 * _t)
	d[SWAY] += idle * k * 0.025 * sin(0.35 * _t + 0.4)
	d[SHIELD_R] += idle * k * 0.015 * sin(0.45 * _t + 1.1)
	d[SHIELD_P] += idle * k * 0.01 * breath
	if not calm:
		d[HEAD_P] += idle * 0.07 * FrostSpitterAvatar._twitch(_t, 4.4, 11.0)  # a sniff
		var heft := _heft(_t) * (1.0 - _bare)
		d[SHIELD_UP] += idle * 0.035 * heft
		d[SHIELD_P] += idle * 0.04 * heft
		d[HEAD_P] -= idle * 0.05 * heft
	# A foot re-planted now and then (a different one each time): lifted, carried a little and set down.
	var u := _t / 3.4
	var seg := floorf(u)
	if FrostSpitterAvatar._hash(seg + 7.0) > 0.4:
		var j := int(FrostSpitterAvatar._hash(seg + 3.0) * LEGS.size()) % LEGS.size()
		var e := sin(PI * clampf((u - seg - 0.2) / 0.22, 0.0, 1.0))
		_foot[j] += Vector3(0.02, 0.045, 0.0) * e * idle
	return -idle * k * 0.004 * (breath + 1.0)


## Bare (the shield gone): crouched lower, the carapace tucked down, the head drawn in and low; a tremble at rest (not
## with reduced motion). Returns its lift.
func _bare_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _bare <= 0.0:
		return 0.0
	var b := _bare
	d[BACK_UP] -= 0.018 * b
	d[BACK_P] -= 0.04 * b * k
	d[HEAD_P] -= 0.12 * b
	d[SURGE] -= 0.02 * b
	if not calm:
		var still := (1.0 - clampf(_stride, 0.0, 1.0)) * (1.0 if _die_t < 0.0 else 0.0)
		d[ROLL] += 0.008 * b * still * sin(TAU * 7.0 * _t)
		d[HEAD_Y] += 0.02 * b * still * sin(TAU * 5.0 * _t + 0.6)
	return -0.025 * b


## The tell at its progress (_coil): a short crouch, then it rears up on its hind legs (the front feet lifting and
## reaching), hoisting the shield high with its face kept upright, the head up; a quiver at the top (not with reduced
## motion). Returns its lift.
func _tell_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	var p := _coil
	if p <= 0.0:
		return 0.0
	var crouch := sin(PI * clampf(p / 0.3, 0.0, 1.0)) * (1.0 - smoothstep(0.1, 0.35, p))
	var rear := smoothstep(0.12, 0.75, p)
	d[PITCH] += (0.27 * rear - 0.04 * crouch) * k
	d[SURGE] -= 0.04 * rear * k
	d[HEAD_P] += 0.25 * rear * k - 0.08 * crouch
	d[HEAD_Y] *= 1.0 - rear
	d[BACK_P] += 0.05 * rear * k
	d[SHIELD_P] -= 0.22 * rear * k  # its face kept upright as the body tips back
	d[SHIELD_UP] += 0.05 * rear * k
	for j in 2:  # the front feet lift and reach
		_foot[j] += Vector3(0.05, 0.1, 0.0) * rear * k
	if not calm and _state == WorldReader.STATE_WINDUP:
		var top := smoothstep(0.75, 0.9, p)
		d[ROLL] += 0.012 * top * sin(TAU * 13.0 * _t)
		d[SHIELD_R] += 0.02 * top * sin(TAU * 11.0 * _t + 0.5)
		d[HEAD_P] += 0.03 * top * sin(TAU * 9.0 * _t + 1.0)
	return -0.03 * crouch * k


## The slam (SLAM_SECONDS from the strike): it crashes down onto its front feet stamped out wide, the body squashing,
## the shield driven into the ground in front, the carapace bouncing (a rattle, not with reduced motion), the head
## thrust down; then it heaves itself back up. Returns its lift.
func _slam_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _slam_t < 0.0:
		return 0.0
	var u := _slam_t / SLAM_SECONDS
	var crash := smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.35, 0.95, u))
	var bounce := sin(PI * clampf((u - 0.06) / 0.25, 0.0, 1.0))
	d[PITCH] -= 0.06 * crash * k
	d[SURGE] += 0.04 * crash * k
	d[HEAD_P] -= 0.18 * crash * k
	d[BACK_UP] += 0.025 * bounce * k
	d[BACK_P] -= 0.06 * bounce * k
	d[SHIELD_P] -= 0.2 * crash * k
	for j in 2:  # the front feet stamped out wide
		_foot[j] += Vector3(0.04, 0.0, 0.09 * signf(_feet[j].z)) * crash
	if not calm:
		var rattle := 1.0 - smoothstep(0.1, 0.5, u)
		d[BACK_UP] += 0.006 * rattle * sin(TAU * 17.0 * _slam_t)
		d[ROLL] += 0.025 * rattle * sin(TAU * 10.0 * _slam_t + 0.7)
		d[SHIELD_R] += 0.03 * rattle * sin(TAU * 13.0 * _slam_t)
	return -0.035 * crash * k


## The brace (a hit on the shield): the shield tips back against it and shudders (no shudder with reduced motion),
## the body braces low behind it, the head ducks. Returns its lift.
func _brace_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _brace_t < 0.0:
		return 0.0
	var h := _brace_t / BRACE_SECONDS
	var e := sin(0.5 * PI * minf(h / 0.2, 1.0)) * (1.0 - smoothstep(0.2, 1.0, h))
	d[SHIELD_P] += 0.1 * e * k
	d[SURGE] -= 0.025 * e * k
	d[HEAD_P] -= 0.12 * e * k
	d[BACK_UP] -= 0.008 * e
	if not calm:
		d[SHIELD_R] += 0.05 * e * sin(TAU * 18.0 * _brace_t)
		d[SHIELD_P] += 0.035 * e * sin(TAU * 15.0 * _brace_t + 0.4)
	return -0.018 * e * k


## The break (BREAK_SECONDS from the shell's last HP): it reels back onto its hind legs, the front feet lifting, the
## head thrown up and shaking (no shake with reduced motion), the carapace jolting; then it settles, bare. Returns its
## lift.
func _break_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _break_t < 0.0:
		return 0.0
	var u := _break_t / BREAK_SECONDS
	var reel := sin(PI * minf(u / 0.25, 1.0) * 0.5) * (1.0 - smoothstep(0.35, 1.0, u))
	d[PITCH] += 0.16 * reel * k
	d[SURGE] -= 0.06 * reel * k
	d[HEAD_P] += 0.3 * reel * k
	d[BACK_UP] += 0.012 * reel
	for j in 2:
		_foot[j] += Vector3(-0.02, 0.06, 0.0) * reel * k
	if not calm:
		var shake := 1.0 - smoothstep(0.2, 0.7, u)
		d[HEAD_Y] += 0.18 * shake * reel * sin(TAU * 7.0 * _break_t)
		d[ROLL] += 0.03 * shake * sin(TAU * 9.0 * _break_t)
	return 0.0


## A hit (its HP fell): the body jolts, the carapace rattles (not with reduced motion), the head ducks, a foot lifts.
## Returns its lift.
func _hurt_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _hurt_t < 0.0:
		return 0.0
	var h := _hurt_t / HURT_SECONDS
	var e := sin(0.5 * PI * minf(h / 0.25, 1.0)) * (1.0 - smoothstep(0.25, 1.0, h))
	d[SURGE] -= 0.03 * e * k
	d[PITCH] += 0.04 * e * k
	d[HEAD_P] -= 0.15 * e * k
	d[BACK_UP] += 0.008 * e
	_foot[_hurt_leg] += Vector3(0.0, 0.03, 0.04 * signf(_feet[_hurt_leg].z)) * e * k
	if not calm:
		d[BACK_P] += 0.04 * e * sin(TAU * 12.0 * _hurt_t)
		d[ROLL] += 0.025 * e * sin(TAU * 11.0 * _hurt_t)
	return -0.012 * e * k


## The rise-in: crouched on its folded legs (the feet splayed a little), the head and the carapace low, pushing up as
## it arrives, quickest at first, and at once as it sets off (its stride needs the height). Returns its lift.
func _rise_pose(d: PackedFloat32Array) -> float:
	var r := 1.0 - _rise
	if r <= 0.0:
		return 0.0
	var low := r * r * (1.0 - clampf(_stride, 0.0, 1.0))
	for j in LEGS.size():
		_foot[j] += Vector3(0.03 * signf(_feet[j].x), 0.0, 0.03 * signf(_feet[j].z)) * low
	d[HEAD_P] -= 0.25 * r
	d[BACK_UP] -= 0.015 * r
	return -0.12 * low


## The death: the legs give way, the feet sliding out wide, the belly dropping to the ground tipping to one side, the
## head drooping to the floor, the carapace slumping; a shield still held topples forward onto its face (a bounce as
## it lands, not with reduced motion). Returns the lift.
func _death_pose(d: PackedFloat32Array, lift: float, calm: bool) -> float:
	if _die_t < 0.0:
		return lift
	var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
	var keep := 1.0 - smoothstep(0.0, 0.2, u)
	for j in [SURGE, ROLL, PITCH, SWAY, HEAD_Y, SHIELD_R]:
		d[j] *= keep
	lift *= keep
	var sag := smoothstep(0.08, 0.5, u)
	d[HEAD_P] = lerpf(d[HEAD_P], -0.45, smoothstep(0.2, 0.7, u))
	d[ROLL] += 0.09 * sag
	d[BACK_P] = lerpf(d[BACK_P], -0.05, sag)
	d[BACK_UP] = lerpf(d[BACK_UP], -0.02, sag)
	for j in LEGS.size():
		var tip: Vector3 = _feet[j]
		var out := Vector3(0.08 * signf(tip.x), 0.0, signf(tip.z) * 0.17)
		_foot[j] = _foot[j] * keep + out * sag
	var fall := clampf((u - 0.1) / 0.45, 0.0, 1.0)
	fall *= fall
	d[SHIELD_P] = lerpf(d[SHIELD_P], -1.3, fall)
	d[SHIELD_UP] += 0.04 * fall
	if not calm:
		var land := sin(PI * clampf((u - 0.55) / 0.15, 0.0, 1.0))
		d[SHIELD_P] += 0.12 * land
		d[SHIELD_UP] += 0.02 * land
	return lift - 0.1 * sag


## The visor's glow: rest; through the windup climbing to VISOR_TELL and flashing from TELL_FLASH_FROM (a flicker; a
## steady step with reduced motion); fading after the slam; flaring as the shield takes a hit and as it breaks; dimmer
## while it rises in; going out in the death.
func _visor(calm: bool) -> float:
	var e := VISOR_REST
	if _state == WorldReader.STATE_WINDUP and _die_t < 0.0:
		e = VISOR_REST + (VISOR_TELL - VISOR_REST) * tell_crouch(_tell)
		if tell_flashing(_tell):
			e = (
				VISOR_TELL * 1.2
				if calm or int(_t * TELL_FLICKER_HZ * 2.0) % 2 == 0
				else VISOR_TELL * 0.8
			)
	if _slam_t >= 0.0:
		e = maxf(e, VISOR_TELL * (1.0 - smoothstep(0.0, 0.5, _slam_t / SLAM_SECONDS)))
	if _brace_t >= 0.0:
		e += VISOR_BRACE * (1.0 - _brace_t / BRACE_SECONDS)
	if _break_t >= 0.0:
		e += 2.0 * VISOR_BRACE * (1.0 - _break_t / BREAK_SECONDS)
	e *= lerpf(0.4, 1.0, _rise)
	if _die_t >= 0.0:
		e = lerpf(e, 0.1, smoothstep(0.1, 0.6, clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)))
	return e


## The shield hefted now and then (mostly 0): lifted, held a moment and set down with a small bump.
static func _heft(t: float) -> float:
	var u := t / 5.2 + 1.0
	var seg := floorf(u)
	if FrostSpitterAvatar._hash(seg + 53.0) < 0.45:
		return 0.0
	var f := u - seg
	var up := smoothstep(0.3, 0.38, f) * (1.0 - smoothstep(0.5, 0.56, f))
	return up - 0.35 * sin(PI * clampf((f - 0.56) / 0.05, 0.0, 1.0))


## The nodes from the drives: each frame node's transform is its joints' makes composed since its parent frame (the
## rig's with the lift under it), as the VAT rig chains them. A shield of no size is hidden.
func _apply() -> void:
	var acc: Array[Transform3D] = []
	acc.resize(_joints.size())
	for j in _joints.size():
		var jt: Array = _joints[j]
		var parent: int = jt[1]
		var base := Transform3D.IDENTITY
		if parent >= 0 and (_joints[parent] as Array)[2] == null:
			base = acc[parent]
		acc[j] = base * (jt[3] as Callable).call([_vd[jt[0]]])
		var frame: Node3D = jt[2]
		if frame == null:
			continue
		frame.transform = (
			Transform3D(Basis.IDENTITY, Vector3(0, _lift, 0)) * acc[j] if frame == rig else acc[j]
		)
	shield.visible = _vd[SHIELD_ON] > 0.0


# --- SoloVat: the VAT rig -----------------------------------------------------------------------------------------
## The whole body's lift (m): VatCrowd moves the instance by it.
func vat_lift() -> float:
	return _lift


func vat_drives() -> PackedFloat32Array:
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The visor's glow (the instance's accent glow).
func glow_energy() -> float:
	return _visor_mat.emission_energy_multiplier


## The owner's colour map (VatLooks' textured variant; HordeVat.texture), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## One grid per drive (a turn sampled finely, a slide or a stretch on two samples: exact), the joints as the table.
func vat_rig() -> Dictionary:
	var grids: Array = []
	for d in VAT_SAMPLES.size():
		grids.append([[d, VAT_SAMPLES[d]]])
	var out := SoloVat.rig("glacier_turtle", VAT_DRIVES, grids, _joints, true)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out
