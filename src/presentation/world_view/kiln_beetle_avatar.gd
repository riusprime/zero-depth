class_name KilnBeetleAvatar
extends AvatarBase
## v0.11.0 O17e (ENEMIES.md R5; owner 2026-11-08: "make sure they are animated as good as you can, if they can have
## multiple animations ... the better"): the Kiln Beetle on the owner's model (EnemyModels &"kiln_beetle", cut by
## scripts/assets/o17_prep_kiln_beetle.py into the shell, the body, the head and each of its EIGHT legs' upper half
## and claw), animated in code from the sim's state and drawn by the VAT crowd (SoloVat) while the switch is on.
## The sim's beetle is a slow armoured Warden (data/enemies/kiln_beetle.tres): it walks at 1.2 m/s, turns at 90
## degrees a second, winds up its slam (the telegraph), slams for a tick (a disc round it) and recovers; when it dies
## its burst stands where it fell and blows a second later (CanyonShore; CanyonShoreViews draws the burst).
## Its clips, each read from the sim through WorldReader (sync) and played in frame time (advance):
## - idle: slow breathing that swells and lifts the shell, the vents puffing brighter on each breath out, the head
##   glancing in held looks with a small twitch now and then, the weight shifting, a leg re-planted now and then;
## - the walk: an alternating tetrapod (r1 l2 r3 l4 against l1 r2 l3 r4, each set's legs a little apart, rear first),
##   each leg sweeping back on the ground and lifting forward, its claw tucking and reaching, the knee taking the
##   weight as it lands; the stride's length follows the speed at a steady cadence, so the feet keep to the ground;
##   the body low, rocking from side to side with the sets, swaying, dipping on each landing, the head steadying. The
##   same legs step it round while it turns in place (each leg's share of the turn: its side's ground speed);
## - the heat (its HP lost, the tell the player reads: WorldReader.actor_hp over actor_max_hp): the vents and the
##   molten belly glow brighter, the breath quickens, the shell sits higher (the gap under it glowing) and trembles
##   more (no tremble with reduced motion);
## - the slam's windup (WINDUP, the sim's own progress): a short crouch, then it rears up on its hind legs (the front
##   legs raised and reaching, the middle ones bracing), the shell drawing in a breath, the head up, the gem visor
##   climbing and flashing from TELL_FLASH_FROM (steady with reduced motion), a quiver at the top;
## - the slam (ACTIVE, then RECOVER: SLAM_SECONDS, the attack's recovery): it crashes down onto splayed front legs, the
##   shell squashes and rebounds and rattles, the vents puff, then it heaves itself back up and re-plants its feet;
## - a hit flinch (its HP fell): the shell jolts and squashes, the head ducks, a leg scrabbles, the vents flare;
## - the rise-in (SPAWN) and the death across the burst's fuse (die(): DEATH_SECONDS, the sim's burst_delay_seconds):
##   it sags, its legs splay and scrabble, the shell swells and lifts off its glowing belly, the vents go white-hot and
##   a shake grows until the burst (the burst's own effect, CanyonShoreViews) takes it;
## - reduced motion (ViewPrefs.reduced_motion): the same clips at CALM of the body's amplitudes, no shakes, trembles,
##   quivers or scrabbles, the flashes steady.
## The pose is a few plain numbers (the raw drives, _vd: each joint's turn) worked out from the state first, then the
## nodes from them through the joint table (_joints, the same transforms the VAT rig declares), so the baked pose is
## the live one. Presentation only (EI-07): nothing here reaches the sim. +X is the front, +Z its right.

const KIND := WorldReader.KIND_KILN_BEETLE
const MODEL := &"kiln_beetle"
const HEIGHT := 0.72
## The role colour (the shell's plates), the heat's glow (the vents and the molten belly) and the gem visor's.
const COLOR := Color("#E8C22E")
const HEAT_COLOR := Color("#FF8A1E")
const VISOR_COLOR := Color("#FFC23A")
## The heat's glow (emission energy) at full HP, what it adds at no HP left, its breath's puff, its peak as it bursts.
const HEAT_REST := 1.2
const HEAT_FULL := 7.0
const HEAT_PUFF := 0.22
const HEAT_BURST := 16.0
## The visor's glow at rest and at the tell's peak.
const VISOR_REST := 1.6
const VISOR_TELL := 7.0
const TELEPORT_SPEED := 30.0
## The clips' lengths (s): the slam and its recovery (the attack's recovery_seconds), a hit's flinch, the death (the
## burst's fuse: burst_delay_seconds; the burst blows as the body goes).
const SLAM_SECONDS := 0.8
const HURT_SECONDS := 0.35
const DEATH_SECONDS := 1.0
## The walk: the speed (m/s) a full stride is made at (the sim's move speed), the cadence (Hz) that keeps the feet on
## the ground there (MOVE_SPEED x DUTY over the foot's sweep: 2 x SWING x the hip-to-claw reach, LEVER m), the share
## of the stride a foot is down, the legs' sweep and lift and the claws' tuck at a full stride (radians); a longer
## stride than STRIDE_MAX quickens the cadence instead.
const MOVE_SPEED := 1.2
const LEVER := 0.24
const DUTY := 0.58
const SWING := 0.5
const LIFT := 0.42
const FOLD := 0.55
const STRIDE_MAX := 1.3
const STEP_HZ := MOVE_SPEED * DUTY / (2.0 * SWING * LEVER)
## The legs (r: right, l: left; 1 front to 4 rear) and each one's place in the stride (0..1): the two sets half a
## stride apart, a set's legs a little apart (the rear first: a wave forward).
const LEGS: Array[StringName] = [&"r1", &"r2", &"r3", &"r4", &"l1", &"l2", &"l3", &"l4"]
const STRIDE_AT := [0.06, 0.54, 0.02, 0.5, 0.56, 0.04, 0.52, 0.0]
## The breath (Hz) at full HP and what it quickens by at no HP left; reduced motion's share of the body's motion.
const BREATH_HZ := 0.42
const BREATH_HOT := 0.55
const CALM := 0.45
## The joints' pivots (m, the model's frame) when the model is missing (the code-made body's: the prep's own).
const PIVOTS := {
	&"body": Vector3.ZERO,
	&"shell": Vector3(-0.021, 0.267, 0.0),
	&"head": Vector3(0.277, 0.203, 0.0),
	&"leg_r1_u": Vector3(0.301, 0.235, 0.138),
	&"leg_r1_l": Vector3(0.441, 0.123, 0.203),
	&"leg_r2_u": Vector3(0.138, 0.245, 0.289),
	&"leg_r2_l": Vector3(0.204, 0.112, 0.429),
	&"leg_r3_u": Vector3(-0.13, 0.256, 0.304),
	&"leg_r3_l": Vector3(-0.201, 0.101, 0.471),
	&"leg_r4_u": Vector3(-0.315, 0.256, 0.181),
	&"leg_r4_l": Vector3(-0.467, 0.123, 0.269),
	&"leg_l1_u": Vector3(0.3, 0.235, -0.14),
	&"leg_l1_l": Vector3(0.44, 0.123, -0.206),
	&"leg_l2_u": Vector3(0.103, 0.245, -0.303),
	&"leg_l2_l": Vector3(0.152, 0.112, -0.45),
	&"leg_l3_u": Vector3(-0.129, 0.256, -0.304),
	&"leg_l3_l": Vector3(-0.2, 0.101, -0.471),
	&"leg_l4_u": Vector3(-0.313, 0.256, -0.184),
	&"leg_l4_l": Vector3(-0.464, 0.123, -0.273),
}
## The claws' reach past the knee (m, the code-made body's), the body's roll and pitch pivots (the pitch's at its
## rear: it rears up on its hind legs).
const CLAW := 0.1
const ROLL_AT := Vector3(0.0, 0.14, 0.0)
const PITCH_AT := Vector3(-0.3, 0.06, 0.0)
## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]: the body's roll, pitch and sway (its yaw), the
## head's pitch and yaw, the shell's lift (m) and swell (over 0: it swells; under 0: it squashes flat and wide), each
## leg's sweep (+ forward), lift (+ up) and claw (+ out, - tucked) in LEGS order, then the visor's glow (no grid: sent
## as it is). A pitch's plus is up (the nose, the head), a roll's tips the top to the right (+Z).
const ROLL := 0
const PITCH := 1
const SWAY := 2
const HEAD_P := 3
const HEAD_Y := 4
const SHELL_UP := 5
const SHELL_SW := 6
const LEG0 := 7
const VISOR := 31
const VAT_DRIVES := [
	[-0.3, 0.3, false],
	[-0.3, 0.5, false],
	[-0.3, 0.3, false],
	[-0.5, 0.5, false],
	[-0.6, 0.6, false],
	[-0.02, 0.08, false],
	[-0.3, 0.3, false],
	[-1.0, 1.0, false],
	[-0.8, 1.4, false],
	[-1.2, 1.2, false],
	[-1.0, 1.0, false],
	[-0.8, 1.4, false],
	[-1.2, 1.2, false],
	[-1.0, 1.0, false],
	[-0.8, 1.4, false],
	[-1.2, 1.2, false],
	[-1.0, 1.0, false],
	[-0.8, 1.4, false],
	[-1.2, 1.2, false],
	[-1.0, 1.0, false],
	[-0.8, 1.4, false],
	[-1.2, 1.2, false],
	[-1.0, 1.0, false],
	[-0.8, 1.4, false],
	[-1.2, 1.2, false],
	[-1.0, 1.0, false],
	[-0.8, 1.4, false],
	[-1.2, 1.2, false],
	[-1.0, 1.0, false],
	[-0.8, 1.4, false],
	[-1.2, 1.2, false],
	[0.0, 0.0, false],
]
## Each drive's samples (a turn finely; the lift a slide, exact on two; the swell piecewise linear, exact on three).
const VAT_SAMPLES := [
	25,
	33,
	25,
	41,
	49,
	2,
	3,
	41,
	45,
	49,
	41,
	45,
	49,
	41,
	45,
	49,
	41,
	45,
	49,
	41,
	45,
	49,
	41,
	45,
	49,
	41,
	45,
	49,
	41,
	45,
	49,
]

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds no nodes.
var vat := false
var kind := KIND
var height := HEIGHT
## True when the body is the owner's model (else the code-made stand-in on the same joints).
var has_model := false
## The parts (tests): the rig's root (the body), the shell, the head, each leg's upper and lower node (LEGS order).
var rig: Node3D
var shell: Node3D
var head: Node3D
var uppers: Array[Node3D] = []
var lowers: Array[Node3D] = []

var _vd := PackedFloat32Array()
var _lift := 0.0
var _heat_glow := HEAT_REST
var _heat_mat := StandardMaterial3D.new()
var _visor_mat := StandardMaterial3D.new()
var _pivots := PIVOTS.duplicate()
## Each leg's foot across the body (m, +Z right: its share of a turn) and the joint table: [drive, parent joint,
## frame node or null, make (SoloVat's)], a parent before its children.
var _foot_z := PackedFloat32Array()
var _joints: Array = []
# The state the pose is made from (sync and advance keep it; vat_sample sets it).
var _state := WorldReader.STATE_SPAWN
var _tell := 0.0
var _hp := -1
var _heat := 0.0
var _speed := 0.0
var _omega := 0.0
var _phase := 0.0
var _stride := 0.0
var _coil := 0.0
var _rise := 0.0
var _slam_t := -1.0
var _hurt_t := -1.0
var _hurt_leg := 0
var _die_t := -1.0
var _last_fy := 0.0
var _have_fy := false


## Builds a beetle under `facing` for ActorViews (`views`: on VAT while its switch is on) and marks `root` (the avatar,
## its body materials for the hit flash); returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D) -> float:
	var beetle := KilnBeetleAvatar.new()
	views._solo_vat(root, beetle, KIND)
	beetle.setup()
	facing.add_child(beetle)
	root.set_meta(&"enemy_avatar", beetle)
	root.set_meta(&"mats", beetle.body_materials.duplicate())
	return HEIGHT


func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	for m: StandardMaterial3D in [_heat_mat, _visor_mat]:
		var c := HEAT_COLOR if m == _heat_mat else VISOR_COLOR
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
	_heat_mat.emission_energy_multiplier = HEAT_REST
	_visor_mat.emission_energy_multiplier = VISOR_REST
	_visor_mat.set_meta(SoloVat.GLOW, VISOR + 1)  # a VAT beetle's visor glows at its VISOR drive
	var m := EnemyModels.get_model(MODEL)
	has_model = not m.is_empty()
	if has_model:
		var s: float = m["scale"]
		var parts_in: Dictionary = m["parts"]
		for pname: StringName in parts_in:
			_pivots[pname] = (parts_in[pname] as Dictionary)["pivot"] * s
	_foot_z.resize(LEGS.size())
	for k in LEGS.size():
		_foot_z[k] = (_pivots[StringName("leg_%s_l" % LEGS[k])] as Vector3).z
	if vat:  # the crowd draws the body
		_pose()
		return
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	shell = _node(rig, "Shell")
	head = _node(rig, "Head")
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
	if part == &"shell":
		return [shell, _pivots[&"shell"]]
	if part == &"head":
		return [head, _pivots[&"head"]]
	var s := String(part)
	var k := LEGS.find(StringName(s.substr(4, 2)))
	if not s.begins_with("leg_") or k < 0:
		return [rig, Vector3.ZERO]
	return [uppers[k] if s.ends_with("_u") else lowers[k], _pivots[part]]


## The owner's model: each part's mesh in its joint's frame, its surfaces on the base / role plates (the role plates
## greyscale in the map, tinted COLOR) and the glow (the heat's: the vents and the belly; on the head the visor's).
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
		var glow := _visor_mat if pname == &"head" else _heat_mat
		for k in surfaces.size():
			mi.set_surface_override_material(
				k, glow if surfaces[k] == &"glow" else mats.get(surfaces[k], mats[&"base"])
			)
		(f[0] as Node3D).add_child(mi)


## The code-made stand-in (the model file missing): boxes on the same joints, so every clip still plays.
func _build_code() -> void:
	var charcoal := Color("#2A2626")
	var grey := Color("#5E5852")
	_piece(rig, Vector3(0.7, 0.2, 0.56), Vector3(0, 0.16, 0), charcoal)
	_glow_box(rig, Vector3(0.6, 0.04, 0.5), Vector3(0, 0.27, 0), _heat_mat)  # the molten belly
	_piece(shell, Vector3(0.9, 0.3, 0.82), Vector3(0, 0.17, 0), COLOR)
	for n in 3:  # the vents
		_glow_box(shell, Vector3(0.05, 0.03, 0.5), Vector3(-0.2 + n * 0.16, 0.33, 0), _heat_mat)
	_piece(head, Vector3(0.14, 0.2, 0.22), Vector3(0.09, -0.02, 0), charcoal)
	_glow_box(head, Vector3(0.03, 0.06, 0.07), Vector3(0.165, 0.0, 0), _visor_mat)
	for k in LEGS.size():
		var hip: Vector3 = _pivots[StringName("leg_%s_u" % LEGS[k])]
		var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
		var out := Vector3(knee.x - hip.x, 0, knee.z - hip.z).normalized()
		_rod(uppers[k], Vector3.ZERO, knee - hip, grey)
		_rod(lowers[k], Vector3.ZERO, out * CLAW * 0.6 + Vector3(0, -knee.y, 0), grey)


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
	var piece := _piece(parent, Vector3(0.06, (to - from).length(), 0.06), (from + to) * 0.5, c)
	piece.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))


## The joint table (see _joints): the body's roll, pitch and sway (the rig), the head's pitch and yaw at the neck, the
## shell's lift and swell at its rim's centre, each leg's sweep (about the vertical at its hip), lift (about the
## level line across it, turning with the sweep) and claw (the same line at the knee).
func _build_joints() -> void:
	var z := Vector3.BACK
	var sp: Vector3 = _pivots[&"shell"]
	_joints = [
		[
			ROLL,
			-1,
			null,
			SoloVat.turn(Vector3.RIGHT, 1.0, SoloVat.at(ROLL_AT), SoloVat.at(-ROLL_AT))
		],
		[PITCH, 0, null, SoloVat.turn(z, 1.0, SoloVat.at(PITCH_AT), SoloVat.at(-PITCH_AT))],
		[SWAY, 1, rig, SoloVat.turn(Vector3.UP)],
		[HEAD_P, 2, null, SoloVat.turn(z, 1.0, SoloVat.at(_pivots[&"head"]))],
		[HEAD_Y, 3, head, SoloVat.turn(Vector3.UP)],
		[SHELL_UP, 2, null, SoloVat.slide(Vector3.UP, Vector3.ZERO, SoloVat.at(sp))],
		[SHELL_SW, 5, shell, KilnBeetleAvatar.swell],
	]
	for k in LEGS.size():
		var hip: Vector3 = _pivots[StringName("leg_%s_u" % LEGS[k])]
		var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
		var out := Vector3(knee.x - hip.x, 0.0, knee.z - hip.z).normalized()
		var across := out.cross(Vector3.UP)  # a turn about it by + lifts the leg
		var side := 1.0 if hip.z > 0.0 else -1.0  # a sweep's + is forward on both sides
		_joints.append([LEG0 + 3 * k, 2, null, SoloVat.turn(Vector3.UP, side, SoloVat.at(hip))])
		_joints.append([LEG0 + 3 * k + 1, _joints.size() - 1, uppers[k], SoloVat.turn(across)])
		_joints.append(
			[
				LEG0 + 3 * k + 2,
				_joints.size() - 1,
				lowers[k],
				SoloVat.turn(across, 1.0, SoloVat.at(knee - hip))
			]
		)


## The shell's swell (a joint's make): over 0 it swells (taller a little less than wide), under 0 it squashes flat and
## spreads, about its rim's centre (the shell node's origin).
static func swell(v: Array) -> Transform3D:
	var s := float(v[0])
	var sc := (
		Vector3(1.0 + s, 1.0 + 0.8 * s, 1.0 + s)
		if s >= 0.0
		else Vector3(1.0 - 0.5 * s, 1.0 + s, 1.0 - 0.5 * s)
	)
	return Transform3D(Basis.from_scale(sc), Vector3.ZERO)


# --- Sync ---------------------------------------------------------------------------------------------------------
func sync(reader: WorldReader, i: int) -> void:
	apply_state(
		{
			"tick": reader.tick(),
			"state": reader.actor_state(i),
			"pos": reader.actor_pos(i),
			"windup": windup_progress(reader, i),
			"hp": reader.actor_hp(i),
			"max_hp": reader.actor_max_hp(i),
		}
	)


## The same as sync(), from plain values (tests, EnemyShadows): tick, state, pos, windup (0..1); hp, max_hp optional.
func apply_state(s: Dictionary) -> void:
	var st: int = s["state"]
	var hp: int = s.get("hp", -1)
	var full: int = s.get("max_hp", -1)
	if _fresh:
		_rise = 0.0 if st == WorldReader.STATE_SPAWN else 1.0
	else:
		var struck := st == WorldReader.STATE_ACTIVE and _state != WorldReader.STATE_ACTIVE
		var missed := st == WorldReader.STATE_RECOVER and _state == WorldReader.STATE_WINDUP
		if struck or missed:  # (a tick's strike missed between two syncs still slams)
			_slam_t = 0.0
		if hp >= 0 and _hp >= 0 and hp < _hp:
			_hurt_t = 0.0
			_hurt_leg = (_hurt_leg + 3) % LEGS.size()
	if hp >= 0 and full > 0:
		_heat = clampf(1.0 - float(hp) / float(full), 0.0, 1.0)
	_track_motion(int(s["tick"]), s.get("pos", Vector2.ZERO), TELEPORT_SPEED)
	_state = st
	_tell = float(s.get("windup", 0.0))
	_hp = hp
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
	# The stride: each leg's share of the walk and the turn (its side's ground speed), at a steady cadence.
	var most := 0.0
	for k in LEGS.size():
		most = maxf(most, absf(_speed + _omega * _foot_z[k]) / MOVE_SPEED)
	_stride = move_toward(_stride, minf(most, 1.0), dt * 4.0)
	_phase = fposmod(_phase + STEP_HZ * maxf(1.0, most / STRIDE_MAX) * dt * signf(_stride), 1.0)
	var winding := _state == WorldReader.STATE_WINDUP and not dying
	_coil = _tell if winding else move_toward(_coil, 0.0, dt * 14.0)
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.0))
	_slam_t = _clip(_slam_t, dt, SLAM_SECONDS)
	_hurt_t = _clip(_hurt_t, dt, HURT_SECONDS)
	if dying:
		_die_t += dt
	_pose()


static func _clip(t: float, dt: float, length: float) -> float:
	if t < 0.0:
		return t
	t += dt
	return t if t < length else -1.0


## The facing's turn rate (rad/s, + toward -Z: Godot's yaw), from the facing node the sim's facing turns (ActorViews).
func _turning(dt: float, dying: bool) -> void:
	var fy := (get_parent() as Node3D).rotation.y if get_parent() is Node3D else 0.0
	var w := 0.0
	if _have_fy and not dying:
		w = clampf(wrapf(fy - _last_fy, -PI, PI) / dt, -4.0, 4.0)
	_omega = lerpf(_omega, w, _rate(10.0, dt))
	_last_fy = fy
	_have_fy = true


## Starts the death (ActorViews, when the sim drops the beetle: its bar hidden, freed DEATH_SECONDS later). True: it
## plays.
func die() -> bool:
	if _die_t < 0.0:
		_die_t = 0.0
	return true


func dying() -> bool:
	return _die_t >= 0.0


## The heat's and the visor's glow now (tests, the e2e).
func heat_energy() -> float:
	return _heat_glow


func visor_energy() -> float:
	return _visor_mat.emission_energy_multiplier


## The heat now (0 at full HP, 1 at none; tests).
func heat() -> float:
	return _heat


## The raw drives now (tests).
func drives() -> PackedFloat32Array:
	return _vd


# --- The pose -----------------------------------------------------------------------------------------------------
## The pose's numbers from the state (_vd, the lift, the glows), then (the code path) the nodes from them.
func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var k := CALM if calm else 1.0
	var d := PackedFloat32Array()
	d.resize(VAT_DRIVES.size())
	var lift := _walk_pose(d, k)
	var breath := sin(TAU * _t * (BREATH_HZ + BREATH_HOT * _heat))
	lift += _idle_pose(d, k, calm, breath)
	lift += _heat_pose(d, k, calm)
	lift += _tell_pose(d, k, calm)
	lift += _slam_pose(d, k, calm)
	lift += _hurt_pose(d, k, calm)
	lift += _rise_pose(d)
	lift = _death_pose(d, lift, calm)
	_heat_glow = _heat_energy(calm, breath)
	d[VISOR] = _visor(calm)
	for j in d.size():
		if j != VISOR:
			d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	_vd = d
	_lift = lift
	_heat_mat.emission_energy_multiplier = _heat_glow
	_visor_mat.emission_energy_multiplier = d[VISOR]
	if not vat and rig != null:
		_apply()


## The walk (and the turn's stepping): each leg through its stride at its own share (its side's ground speed over the
## full stride's), the body rocking with the sets, swaying, dipping as each set lands. Returns its lift.
func _walk_pose(d: PackedFloat32Array, k: float) -> float:
	var g := clampf(_stride, 0.0, 1.0)
	for j in LEGS.size():
		var share := clampf((_speed + _omega * _foot_z[j]) / MOVE_SPEED, -STRIDE_MAX, STRIDE_MAX)
		var c := leg_cycle(fposmod(_phase - float(STRIDE_AT[j]), 1.0))
		d[LEG0 + 3 * j] += share * SWING * c.x
		d[LEG0 + 3 * j + 1] += absf(share) * LIFT * c.y
		d[LEG0 + 3 * j + 2] += absf(share) * FOLD * c.z
	if g <= 0.0:
		return 0.0
	var p := _phase
	var walk := clampf(_speed / MOVE_SPEED, 0.0, 1.0)  # (turning in place: the legs step, the body stays calm)
	d[ROLL] += g * k * 0.035 * sin(TAU * (p - 0.15))
	d[SWAY] += walk * k * 0.045 * sin(TAU * (p + 0.1))
	d[PITCH] += walk * k * 0.012 * sin(2.0 * TAU * (p - 0.05))
	d[HEAD_Y] -= walk * k * 0.03 * sin(TAU * (p + 0.1))  # the head holds its line against the sway
	d[HEAD_P] += walk * k * 0.03 * cos(2.0 * TAU * (p - 0.12))
	var land := pow(0.5 + 0.5 * cos(2.0 * TAU * (p - 0.03)), 4.0)  # each set's landing
	d[SHELL_SW] -= g * k * 0.012 * land
	return g * k * (0.004 - 0.009 * land)


## One leg through its stride at q (0 its touchdown): (the sweep: 1 forward .. -1 back; the lift 0..1; the claw: under
## 0 tucked, over 0 reaching). On the ground the foot sweeps back, the knee giving under the weight as it lands; in the
## air it lifts and comes forward eased, the claw tucked, reaching out just before it lands.
static func leg_cycle(q: float) -> Vector3:
	if q < DUTY:
		var s := q / DUTY
		var press := sin(PI * minf(s / 0.35, 1.0)) * 0.2
		return Vector3(1.0 - 2.0 * s, 0.0, -press)
	var w := (q - DUTY) / (1.0 - DUTY)
	var up := sin(PI * w)
	var tuck := -sin(PI * minf(w / 0.75, 1.0)) + 0.5 * smoothstep(0.55, 0.9, w) * (1.0 - w) * 4.0
	return Vector3(-1.0 + 2.0 * smoothstep(0.0, 1.0, w), up * up * (3.0 - 2.0 * up), tuck)


## Idle (fading as it walks): the breath swelling and lifting the shell, the head's held glances and its twitch, the
## weight shifting, a leg re-planted now and then. Returns its lift.
func _idle_pose(d: PackedFloat32Array, k: float, calm: bool, breath: float) -> float:
	var idle := (1.0 - clampf(_stride, 0.0, 1.0)) * (1.0 - _coil) * (1.0 if _die_t < 0.0 else 0.0)
	if idle <= 0.0:
		return 0.0
	d[SHELL_SW] += idle * k * 0.03 * breath
	d[SHELL_UP] += idle * k * 0.004 * (breath + 1.0)
	d[HEAD_Y] += idle * k * 0.3 * _scan(_t, 2.2, 0.0)
	d[HEAD_P] += idle * k * (0.08 * _scan(_t, 3.1, 5.0) - 0.02 * breath)
	if not calm:
		d[HEAD_P] += idle * 0.07 * _twitch(_t, 3.7, 11.0)
		d[HEAD_Y] += idle * 0.06 * _twitch(_t, 4.3, 23.0)
	d[ROLL] += idle * k * 0.022 * sin(0.55 * _t)
	d[PITCH] += idle * k * 0.012 * sin(0.55 * _t + 1.7)
	d[SWAY] += idle * k * 0.02 * sin(0.37 * _t + 0.4)
	# A leg re-planted now and then (a different one each time): lifted, set down a little forward.
	var u := _t / 2.6
	var seg := floorf(u)
	if _hash(seg + 7.0) > 0.45:
		var j := int(_hash(seg + 3.0) * LEGS.size()) % LEGS.size()
		var e := sin(PI * clampf((u - seg - 0.2) / 0.22, 0.0, 1.0))
		d[LEG0 + 3 * j] += idle * 0.12 * e
		d[LEG0 + 3 * j + 1] += idle * 0.35 * e
		d[LEG0 + 3 * j + 2] -= idle * 0.3 * e
	return idle * k * 0.005 * breath


## The heat (its HP lost): the shell sits higher on its glowing gap (held: kept with reduced motion), and trembles
## more as it runs out (not with reduced motion). Returns its lift.
func _heat_pose(d: PackedFloat32Array, _k: float, calm: bool) -> float:
	var h := _heat
	if h <= 0.0:
		return 0.0
	d[SHELL_UP] += 0.02 * pow(h, 1.5)
	if not calm:
		var tr := h * h
		d[SHELL_UP] += 0.005 * tr * _wobble(_t * 3.1, 0.0)
		d[SHELL_SW] += 0.014 * tr * _wobble(_t * 2.7, 2.0)
		d[ROLL] += 0.01 * tr * _wobble(_t * 2.3, 4.0)
	return 0.0


## The slam's windup at its progress (_coil): a short crouch, then it rears up on its hind legs, the front legs raised
## and reaching, the middle ones bracing, the shell drawing in a breath, the head up; a quiver at the top (not with
## reduced motion). Returns its lift.
func _tell_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	var p := _coil
	if p <= 0.0:
		return 0.0
	var crouch := sin(PI * clampf(p / 0.32, 0.0, 1.0)) * (1.0 - smoothstep(0.12, 0.4, p))
	var rear := smoothstep(0.15, 0.65, p)
	d[PITCH] += 0.38 * rear * k - 0.03 * crouch
	d[SHELL_SW] += 0.07 * rear - 0.06 * crouch
	d[HEAD_P] += 0.3 * rear - 0.1 * crouch
	d[HEAD_Y] *= 1.0 - rear
	for side in 2:
		var o := 4 * side
		var j1 := LEG0 + 3 * o
		d[j1] += 0.35 * rear  # the front legs: up and reaching
		d[j1 + 1] += 1.0 * rear - 0.15 * crouch
		d[j1 + 2] += 0.55 * rear
		var j2 := LEG0 + 3 * (o + 1)
		d[j2] += 0.15 * rear
		d[j2 + 1] += 0.35 * rear
		d[j2 + 2] += 0.2 * rear
		var j3 := LEG0 + 3 * (o + 2)  # the hind legs brace and take the weight
		d[j3] -= 0.15 * rear
		d[j3 + 1] -= 0.25 * rear + 0.1 * crouch
		d[j3 + 2] -= 0.3 * rear
		var j4 := LEG0 + 3 * (o + 3)
		d[j4] -= 0.2 * rear
		d[j4 + 1] -= 0.1 * rear + 0.1 * crouch
		d[j4 + 2] -= 0.2 * rear
	if not calm and _state == WorldReader.STATE_WINDUP:
		var top := smoothstep(0.6, 0.75, p)
		d[ROLL] += 0.012 * top * sin(TAU * 13.0 * _t)
		d[SHELL_UP] += 0.003 * top * sin(TAU * 17.0 * _t)
		if tell_flashing(p):
			for side in 2:
				d[LEG0 + 3 * (4 * side) + 2] += 0.15 * sin(TAU * 9.0 * _t + side)
	return -0.02 * crouch * k


## The slam (SLAM_SECONDS from the strike): it crashes down onto its splayed front legs, the shell squashing and
## rebounding and rattling (no rattle with reduced motion), then heaves itself back up and re-plants its front feet.
## Returns its lift.
func _slam_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _slam_t < 0.0:
		return 0.0
	var u := _slam_t / SLAM_SECONDS
	var down := smoothstep(0.0, 0.05, u) * (1.0 - smoothstep(0.18, 0.65, u))
	var squash := smoothstep(0.02, 0.07, u) * (1.0 - smoothstep(0.07, 0.3, u))
	var rebound := sin(PI * clampf((u - 0.18) / 0.3, 0.0, 1.0))
	var heave := sin(PI * clampf((u - 0.45) / 0.45, 0.0, 1.0))
	d[PITCH] += (-0.16 * down + 0.04 * heave) * k
	d[SHELL_SW] += -0.24 * squash + 0.07 * rebound
	d[HEAD_P] += -0.2 * down + 0.08 * heave
	for side in 2:
		var o := 4 * side
		for leg in 2:  # the front pair splayed out under the blow, then re-planted in turn
			var j := LEG0 + 3 * (o + leg)
			var step := sin(PI * clampf((u - 0.5 - 0.12 * leg - 0.06 * side) / 0.22, 0.0, 1.0))
			d[j] += (0.3 - 0.15 * leg) * down + 0.15 * step
			d[j + 1] += -0.3 * down + 0.4 * step
			d[j + 2] += 0.6 * down - 0.3 * step
		for leg in [2, 3]:
			d[LEG0 + 3 * (o + leg) + 1] += 0.15 * down
	if not calm:
		var rattle := (1.0 - smoothstep(0.1, 0.6, u)) * smoothstep(0.03, 0.06, u)
		d[SHELL_UP] += 0.008 * rattle * sin(TAU * 19.0 * _slam_t)
		d[ROLL] += 0.03 * rattle * sin(TAU * 11.0 * _slam_t + 0.7)
	return (-0.045 * down + 0.012 * heave) * k


## A hit (its HP fell): the shell jolts and squashes, the head ducks, a leg scrabbles. Returns its lift.
func _hurt_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _hurt_t < 0.0:
		return 0.0
	var h := _hurt_t / HURT_SECONDS
	var e := sin(PI * minf(h / 0.25, 1.0)) * (1.0 - smoothstep(0.25, 1.0, h))
	d[SHELL_SW] -= 0.07 * e * k
	d[SHELL_UP] += 0.008 * e
	d[HEAD_P] -= 0.15 * e * k
	d[PITCH] -= 0.03 * e * k
	var j := LEG0 + 3 * _hurt_leg
	d[j + 1] += 0.45 * e * k
	d[j + 2] -= 0.4 * e * k
	if not calm:
		d[j] += 0.25 * e * sin(TAU * 8.0 * _hurt_t)
		d[ROLL] += 0.03 * e * sin(TAU * 12.0 * _hurt_t)
	return -0.012 * e * k


## The rise-in: low, legs drawn up and claws tucked, the shell drawn in, rising as it arrives. Returns its lift.
func _rise_pose(d: PackedFloat32Array) -> float:
	var r := 1.0 - _rise
	if r <= 0.0:
		return 0.0
	for j in LEGS.size():
		d[LEG0 + 3 * j + 1] += 0.5 * r
		d[LEG0 + 3 * j + 2] -= 0.9 * r
	d[SHELL_SW] -= 0.05 * r
	d[HEAD_P] -= 0.25 * r
	return -0.1 * r


## The death over the burst's fuse: it sags, its legs splay out and scrabble (no scrabble with reduced motion), the
## shell swells and lifts off its glowing belly, a shake grows (not with reduced motion), it heaves up at the end as
## the burst takes it. Returns the lift.
func _death_pose(d: PackedFloat32Array, lift: float, calm: bool) -> float:
	if _die_t < 0.0:
		return lift
	var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
	var sag := smoothstep(0.0, 0.18, u)
	var keep := 1.0 - sag
	for j in [ROLL, PITCH, SWAY, HEAD_Y]:
		d[j] *= keep
	lift *= keep
	var swell_u := pow(smoothstep(0.08, 1.0, u), 1.6)
	d[SHELL_SW] = lerpf(d[SHELL_SW], 0.28 * swell_u, sag)
	d[SHELL_UP] = lerpf(d[SHELL_UP], 0.012 + 0.055 * swell_u, sag)
	d[HEAD_P] = lerpf(d[HEAD_P], -0.18 + 0.3 * smoothstep(0.7, 1.0, u), sag)
	var scrabble := sag * (1.0 - smoothstep(0.8, 0.97, u))
	for j in LEGS.size():
		var front := j % 4 < 2
		var b := LEG0 + 3 * j
		d[b] = lerpf(d[b], 0.3 if front else -0.3, sag)
		d[b + 1] = lerpf(d[b + 1], 0.32, sag)
		d[b + 2] = lerpf(d[b + 2], 0.6, sag)
		if not calm:
			var f := 7.0 + 5.0 * u
			d[b] += 0.18 * scrabble * sin(TAU * f * _die_t + j * 1.7)
			d[b + 1] += 0.3 * scrabble * sin(TAU * f * _die_t + j * 2.3 + 1.0)
			d[b + 2] += 0.25 * scrabble * sin(TAU * f * _die_t + j * 0.9 + 2.0)
	if not calm:
		var shake := 0.004 + 0.035 * u * u
		d[ROLL] += shake * _wobble(_die_t * 9.0, 1.0)
		d[PITCH] += shake * _wobble(_die_t * 8.0, 3.0)
		d[SHELL_UP] += shake * 0.25 * _wobble(_die_t * 11.0, 5.0)
	return lift - 0.045 * sag + 0.03 * smoothstep(0.75, 1.0, u)


## The heat's glow: rest, climbing as its HP runs out, puffing on each breath out (less with reduced motion), drawn
## in through the windup and puffed out at the slam, flaring on a hit, white-hot through the death.
func _heat_energy(calm: bool, breath: float) -> float:
	var e := HEAT_REST + HEAT_FULL * pow(_heat, 1.2)
	e *= 1.0 + HEAT_PUFF * (0.4 if calm else 1.0) * maxf(0.0, breath)
	e *= 1.0 - 0.3 * smoothstep(0.1, 0.6, _coil)
	if _slam_t >= 0.0:
		e += 3.5 * (1.0 - smoothstep(0.0, 0.55, _slam_t / SLAM_SECONDS))
	if _hurt_t >= 0.0:
		e += 1.5 * (1.0 - _hurt_t / HURT_SECONDS)
	if _die_t >= 0.0:
		var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
		e = lerpf(e, HEAT_BURST, smoothstep(0.0, 1.0, u))
		if not calm:
			e *= 1.0 + 0.15 * sin(TAU * (6.0 + 10.0 * u) * _die_t)
	return e


## The visor's glow: rest; through the windup climbing to VISOR_TELL and flashing from TELL_FLASH_FROM (a flicker; a
## steady step with reduced motion); fading after the slam; white-hot as it bursts.
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
	if _die_t >= 0.0:
		e = maxf(e, lerpf(VISOR_REST, VISOR_TELL * 1.4, clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)))
	return e


## A held glance: a pseudo-random value in -1..1 per `every` s that holds, then moves quickly to the next.
static func _scan(t: float, every: float, seed_off: float) -> float:
	var u := t / every + seed_off
	var seg := floorf(u)
	var a := _hash(seg) * 2.0 - 1.0
	var b := _hash(seg + 1.0) * 2.0 - 1.0
	return lerpf(a, b, smoothstep(0.55, 0.85, u - seg))


## A quick twitch now and then (-1..1, mostly 0).
static func _twitch(t: float, every: float, seed_off: float) -> float:
	var u := t / every + seed_off
	var seg := floorf(u)
	if _hash(seg + 31.0) < 0.55:
		return 0.0
	var s := 1.0 if _hash(seg + 17.0) > 0.5 else -1.0
	return s * sin(PI * clampf((u - seg - 0.4) / 0.05, 0.0, 1.0))


## A tremble (-1..1): three sines at unrelated rates.
static func _wobble(t: float, seed_off: float) -> float:
	return (
		sin(TAU * (t * 3.7 + seed_off)) * 0.5
		+ sin(TAU * (t * 5.3 + seed_off * 1.3)) * 0.3
		+ sin(TAU * (t * 8.9 + seed_off * 0.7)) * 0.2
	)


static func _hash(x: float) -> float:
	var v := sin(x * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)


## The nodes from the drives: each frame node's transform is its joints' makes composed since its parent frame (the
## rig's with the lift under it), as the VAT rig chains them.
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


# --- SoloVat: the VAT rig -----------------------------------------------------------------------------------------
## The whole body's lift (m): VatCrowd moves the instance by it.
func vat_lift() -> float:
	return _lift


func vat_drives() -> PackedFloat32Array:
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The heat's glow (the instance's accent glow; the visor's is the VISOR drive).
func glow_energy() -> float:
	return _heat_glow


## The owner's colour map (VatLooks' textured variant; HordeVat.texture), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## One grid per drive but the visor's (a turn sampled finely, the slide on two samples, the swell on three: exact),
## the joints as the table.
func vat_rig() -> Dictionary:
	var grids: Array = []
	for d in VAT_SAMPLES.size():
		grids.append([[d, VAT_SAMPLES[d]]])
	var out := SoloVat.rig("kiln_beetle", VAT_DRIVES, grids, _joints, true)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out


func vat_sample(rng: RandomNumberGenerator) -> Dictionary:
	var ranges := {
		"_t": [0.0, 40.0],
		"_phase": [0.0, 1.0],
		"_speed": [0.0, 2.0],
		"_omega": [-2.0, 2.0],
		"_stride": [0.0, 1.0],
		"_heat": [0.0, 1.0],
		"_coil": [0.0, 1.0],
		"_tell": [0.0, 1.0],
		"_rise": [0.0, 1.0],
		"_slam_t": [-0.3, SLAM_SECONDS],
		"_hurt_t": [-0.2, HURT_SECONDS],
		"_hurt_leg": [0, 1, 2, 3, 4, 5, 6, 7],
		"_die_t": [-0.6, DEATH_SECONDS],
		"_state":
		[
			WorldReader.STATE_MOVE,
			WorldReader.STATE_WINDUP,
			WorldReader.STATE_ACTIVE,
			WorldReader.STATE_RECOVER
		],
	}
	return SoloVat.sample(self, rng, ranges, _pose)


func vat_set(s: Dictionary) -> void:
	SoloVat.apply(self, s, _pose)
