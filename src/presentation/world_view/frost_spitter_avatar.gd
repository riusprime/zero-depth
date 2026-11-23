class_name FrostSpitterAvatar
extends AvatarBase
## The Frost Spitter on the owner's model (EnemyModels &"frost_spitter", cut by scripts/assets/frost_spitter_prep.py
## into the shell, the body, the head, the throat sac and each of its four legs' upper half and foot), animated in code
## from the sim's state and drawn by the VAT crowd (SoloVat) while the switch is on. The owner asked for the enemies to
## be "animated as good as you can, if they can have multiple animations ... the better".
## The sim's spitter (data/enemies/frost_spitter.tres, CanyonShore) keeps its distance band at 2.6 m/s, winds up its
## lob (the telegraph: the blue arc to the landing), throws an ice blob for a tick (the blob flies on its own,
## CanyonShoreViews) and recovers.
## Its clips, each read from the sim through WorldReader (sync) and played in frame time (advance):
## - idle: the sac breathing and glowing with each breath, a gulp now and then, the head glancing in held looks with
##   a twitch, the shell riding the breath, the weight shifting, a foot re-planted now and then;
## - the gait: a scuttling trot (the diagonal pairs together), each foot planted on the ground while it is down (the
##   legs are posed by reach: hip and knee solved for where the foot stands, so the body's bob, roll and pitch never
##   drag a foot), lifted and carried forward in the air; the body bobbing twice a stride, rocking with the pairs, the
##   sac and the shell jiggling a beat behind, the head holding its line. The same legs step it round as it turns;
## - the tell (WINDUP, the sim's own progress): the sac swells in gulps, glowing brighter, while it rears back on its
##   hind legs, the head tipping up (the mouth opening), the shell tilting back, the visor climbing and flashing from
##   TELL_FLASH_FROM (steady with reduced motion), a quiver at the top;
## - the spit (ACTIVE, then RECOVER: SPIT_SECONDS, the attack's active and recovery time): the head snaps forward
##   with the mouth wide, the body lunges after it and recoils, the sac empties at once with a flash and refills
##   through the recovery, the mouth closing, the front feet bracing;
## - a hit flinch (its HP fell): the body jolts back, the sac wobbles, the head ducks, a foot lifts;
## - the rise-in (SPAWN): it unfolds from a crouch on its folded legs, the sac filling;
## - the death (die(): DEATH_SECONDS): the sac bursts and empties with a last flash, the legs give way and the body
##   drops onto its belly, tipping to one side, the head drooping, the visor going out, a last kick of a leg;
## - reduced motion (ViewPrefs.reduced_motion): the same clips at CALM of the body's amplitudes, no quivers, twitches
##   or kicks, the flashes steady.
## The pose is a few plain numbers (the raw drives, _vd: each joint's turn, slide or stretch) worked out from the state
## first, then the nodes from them through the joint table (_joints, the same transforms the VAT rig declares), so the
## baked pose is the live one. On the VAT crowd it is batched (EnemyBatch: nothing here reads the tree, its turn is its
## facing node's; its death's timer is the batch's, drop), and the native batch runs the same sync, frame step and pose
## (native/src/zd_avatar_frost_spitter.cpp). Presentation only (EI-07): nothing here reaches the sim. +X is the front,
## +Z its right.

const KIND := WorldReader.KIND_FROST_SPITTER
const MODEL := &"frost_spitter"
const HEIGHT := 0.88
## The role colour (the shell's blue plates), the sac's pale ice and its glow (deeper, so a bright sac stays ice-blue
## and never burns white), the gem visor's.
const COLOR := Color("#3A6BD4")
const SAC_COLOR := Color("#9ED8F2")
const SAC_GLOW := Color("#3FA9E8")
const VISOR_COLOR := Color("#8FE6FF")
## The sac's glow (emission energy) at rest, what a full swell adds, its flash as it empties.
const SAC_REST := 0.5
const SAC_FULL := 1.4
const SAC_FLASH := 2.5
## The visor's glow at rest and at the tell's peak.
const VISOR_REST := 1.6
const VISOR_TELL := 6.5
const TELEPORT_SPEED := 30.0
## The clips' lengths (s): the spit and its recovery (the attack's active_seconds + recovery_seconds), a hit's
## flinch, the death.
const SPIT_SECONDS := 0.7
const HURT_SECONDS := 0.35
const DEATH_SECONDS := 1.0
## The gait: the speed (m/s) a full stride is made at (the sim's move speed), the share of the stride a foot is down,
## the foot's sweep either side of its stride's middle (m) and its lift (m) at a full stride; the cadence (Hz) that
## keeps a planted foot still on the ground there. A longer stride than STRIDE_MAX quickens the cadence instead.
const MOVE_SPEED := 2.6
const DUTY := 0.5
const SWEEP := 0.15
const LIFT := 0.07
const STRIDE_MAX := 1.3
const STEP_HZ := MOVE_SPEED * DUTY / (2.0 * SWEEP)
## How far (m) each pair's stride sits from its rest foot (the front feet behind theirs, the hind ones ahead: the
## legs keep to their reach), the body's crouch (m) at a full stride, the turn rate (rad/s) of a full turning step and
## the body's turn (radians) one step makes.
const GATHER := [-0.1, -0.1, 0.09, 0.09]
const CROUCH := 0.025
const TURN_REF := 3.0
const TURN_SWING := 0.22
## The legs (fr / fl: the front pair; br / bl: the hind pair) and each one's place in the stride (0..1): a trot, the
## diagonal pairs together (the hind foot a beat after).
const LEGS: Array[StringName] = [&"fr", &"fl", &"br", &"bl"]
const STRIDE_AT := [0.0, 0.5, 0.53, 0.03]
## The breath (Hz); reduced motion's share of the body's motion.
const BREATH_HZ := 0.5
const CALM := 0.45
## The joints' pivots and the feet's tips (m, the model's frame) when the model is missing (the prep's own).
const PIVOTS := {
	&"body": Vector3.ZERO,
	&"shell": Vector3(-0.022, 0.468, 0.0),
	&"head": Vector3(0.334, 0.479, 0.0),
	&"sac": Vector3(0.223, 0.401, 0.0),
	&"leg_fr_u": Vector3(0.167, 0.345, 0.251),
	&"leg_fr_l": Vector3(0.262, 0.128, 0.345),
	&"leg_fl_u": Vector3(0.167, 0.345, -0.251),
	&"leg_fl_l": Vector3(0.262, 0.128, -0.345),
	&"leg_br_u": Vector3(-0.189, 0.345, 0.24),
	&"leg_br_l": Vector3(-0.451, 0.156, 0.262),
	&"leg_bl_u": Vector3(-0.189, 0.345, -0.24),
	&"leg_bl_l": Vector3(-0.451, 0.156, -0.262),
}
const FEET := [
	Vector3(0.49, 0.022, 0.334),
	Vector3(0.49, 0.022, -0.334),
	Vector3(-0.457, 0.011, 0.295),
	Vector3(-0.457, 0.011, -0.295),
]
## The body's roll and pitch pivots (the pitch's at its hind feet: it rears back on them).
const ROLL_AT := Vector3(0.0, 0.2, 0.0)
const PITCH_AT := Vector3(-0.36, 0.05, 0.0)
## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]: the body's surge (m, + forward), roll, pitch and sway
## (its yaw), the head's nod (+ up: the mouth opens) and yaw, the shell's lift (m) and tilt, the sac's swell (a
## stretch: + swells, - empties), each leg's yaw, hip and knee turns in LEGS order, then the visor's glow (no grid:
## sent as it is). A pitch's plus is up (the nose), a roll's tips the top to the right (+Z).
const SURGE := 0
const ROLL := 1
const PITCH := 2
const SWAY := 3
const HEAD_P := 4
const HEAD_Y := 5
const SHELL_UP := 6
const SHELL_P := 7
const SAC := 8
const LEG0 := 9
const VISOR := 21
const VAT_DRIVES := [
	[-0.1, 0.1, false],
	[-0.3, 0.3, false],
	[-0.35, 0.45, false],
	[-0.3, 0.3, false],
	[-0.45, 0.6, false],
	[-0.6, 0.6, false],
	[-0.03, 0.05, false],
	[-0.25, 0.25, false],
	[-0.7, 0.7, false],
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
	[0.0, 0.0, false],
]
## Each drive's samples (a turn finely; a slide or the sac's stretch linear: exact on two).
const VAT_SAMPLES := [
	2, 25, 33, 25, 41, 41, 2, 25, 2, 33, 49, 57, 33, 49, 57, 33, 49, 57, 33, 49, 57
]

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds no nodes.
var vat := false
var kind := KIND
var height := HEIGHT
## True when the body is the owner's model (else the code-made stand-in on the same joints).
var has_model := false
## The parts (tests): the rig's root (the body), the shell, the head, the sac, each leg's upper and lower node (LEGS
## order).
var rig: Node3D
var shell: Node3D
var head: Node3D
var sac: Node3D
var uppers: Array[Node3D] = []
var lowers: Array[Node3D] = []

var _vd := PackedFloat32Array()
var _lift := 0.0
var _sac_glow := SAC_REST
var _sac_mat := StandardMaterial3D.new()
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
var _speed := 0.0
## The way it goes in the facing's frame ((x, z), unit: it may back away while it faces the hero).
var _dir := Vector2.RIGHT
var _omega := 0.0
var _phase := 0.0
var _stride := 0.0
var _coil := 0.0
var _rise := 0.0
var _spit_t := -1.0
var _hurt_t := -1.0
var _hurt_leg := 0
var _die_t := -1.0
var _last_fy := 0.0
var _have_fy := false


## Builds a spitter under `facing` for ActorViews (`views`: on VAT while its switch is on) and marks `root` (the
## avatar, its body materials for the hit flash); returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D) -> float:
	var spitter := FrostSpitterAvatar.new()
	views._solo_vat(root, spitter, KIND)
	spitter.setup()
	facing.add_child(spitter)
	root.set_meta(&"enemy_avatar", spitter)
	root.set_meta(&"mats", spitter.body_materials.duplicate())
	return HEIGHT


func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	for m: StandardMaterial3D in [_sac_mat, _visor_mat]:
		var c := SAC_COLOR if m == _sac_mat else VISOR_COLOR
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = SAC_GLOW if m == _sac_mat else c
	_sac_mat.emission_energy_multiplier = SAC_REST
	_visor_mat.emission_energy_multiplier = VISOR_REST
	_visor_mat.set_meta(SoloVat.GLOW, VISOR + 1)  # a VAT spitter's visor glows at its VISOR drive
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
	shell = _node(rig, "Shell")
	head = _node(rig, "Head")
	sac = _node(rig, "Sac")
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
		&"shell":
			return [shell, _pivots[&"shell"]]
		&"head":
			return [head, _pivots[&"head"]]
		&"sac":
			return [sac, _pivots[&"sac"]]
	var s := String(part)
	var k := LEGS.find(StringName(s.substr(4, 2)))
	if not s.begins_with("leg_") or k < 0:
		return [rig, Vector3.ZERO]
	return [uppers[k] if s.ends_with("_u") else lowers[k], _pivots[part]]


## The owner's model: each part's mesh in its joint's frame, its surfaces on the base / role plates (the role plates
## greyscale in the map, tinted COLOR) and the glow (the sac's, and the body's throat under it; on the head the
## visor's).
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
		var glow := _visor_mat if pname == &"head" else _sac_mat
		for k in surfaces.size():
			mi.set_surface_override_material(
				k, glow if surfaces[k] == &"glow" else mats.get(surfaces[k], mats[&"base"])
			)
		(f[0] as Node3D).add_child(mi)


## The code-made stand-in (the model file missing): boxes on the same joints, so every clip still plays.
func _build_code() -> void:
	var charcoal := Color("#262A32")
	var grey := Color("#56606A")
	_piece(rig, Vector3(0.62, 0.22, 0.42), Vector3(-0.04, 0.3, 0), charcoal)
	_piece(shell, Vector3(0.84, 0.16, 0.76), Vector3(0.0, 0.04, 0), COLOR)
	_piece(head, Vector3(0.1, 0.1, 0.26), Vector3(0.03, 0.02, 0), charcoal)
	_glow_box(head, Vector3(0.03, 0.04, 0.07), Vector3(0.085, 0.03, 0), _visor_mat)
	_glow_box(sac, Vector3(0.24, 0.24, 0.3), Vector3(0.06, -0.12, 0), _sac_mat)
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
	var piece := _piece(parent, Vector3(0.06, (to - from).length(), 0.06), (from + to) * 0.5, c)
	piece.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))


## The joint table (see _joints): the body's surge, roll, pitch and sway (the rig), the head's nod at its hinge and
## its yaw, the shell's lift and tilt at its rim's centre, the sac's stretch at its root, each leg's yaw (about the
## vertical at its hip), hip turn (about the level line across the body there, turning with the yaw) and knee turn.
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
		[SHELL_UP, 3, null, SoloVat.slide(Vector3.UP, Vector3.ZERO, SoloVat.at(_pivots[&"shell"]))],
		[SHELL_P, 6, shell, SoloVat.turn(z)],
		[
			SAC,
			3,
			sac,
			SoloVat.stretch_by(Vector3.ONE, Vector3(1.0, 0.9, 0.7), SoloVat.at(_pivots[&"sac"]))
		],
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
		}
	)


## The same as sync(), from plain values (tests, EnemyShadows): tick, state, pos, windup (0..1); hp optional.
func apply_state(s: Dictionary) -> void:
	_touch()
	var st: int = s["state"]
	var hp: int = s.get("hp", -1)
	if _fresh:
		_rise = 0.0 if st == WorldReader.STATE_SPAWN else 1.0
	else:
		var spat := st == WorldReader.STATE_ACTIVE and _state != WorldReader.STATE_ACTIVE
		var missed := st == WorldReader.STATE_RECOVER and _state == WorldReader.STATE_WINDUP
		if spat or missed:  # (a tick's throw missed between two syncs still spits)
			_spit_t = 0.0
		if hp >= 0 and _hp >= 0 and hp < _hp:
			_hurt_t = 0.0
			_hurt_leg = (_hurt_leg + 1) % LEGS.size()
	_track_motion(int(s["tick"]), s.get("pos", Vector2.ZERO), TELEPORT_SPEED)
	_state = st
	_tell = float(s.get("windup", 0.0))
	_hp = hp
	if _fresh:
		_fresh = false
		_pose()


# --- Frame time ---------------------------------------------------------------------------------------------------
func advance(delta: float) -> void:
	_touch()
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
	# The stride: the walk's and the turn's share, at a steady cadence.
	var most := maxf(_speed / MOVE_SPEED, absf(_omega) / TURN_REF)
	_stride = move_toward(_stride, minf(most, 1.0), dt * 5.0)
	_phase = fposmod(_phase + STEP_HZ * maxf(1.0, most / STRIDE_MAX) * dt * signf(_stride), 1.0)
	var winding := _state == WorldReader.STATE_WINDUP and not dying
	_coil = _tell if winding else move_toward(_coil, 0.0, dt * 10.0)
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.2))
	_spit_t = _clip(_spit_t, dt, SPIT_SECONDS)
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
		w = clampf(wrapf(fy - _last_fy, -PI, PI) / dt, -6.0, 6.0)
	_omega = lerpf(_omega, w, _rate(10.0, dt))
	_last_fy = fy
	_have_fy = true


## Starts the death (ActorViews or the enemy batch, when the sim drops the spitter: its bar hidden, freed
## DEATH_SECONDS later). True: it plays.
func die() -> bool:
	_touch()
	if _die_t < 0.0:
		_die_t = 0.0
	return true


func dying() -> bool:
	_peek()
	return _die_t >= 0.0


## The sac's swell now (the SAC drive: over 0 swollen, under 0 emptied; tests, the e2e), its glow and the visor's.
func sac_swell() -> float:
	_peek()
	return _vd[SAC]


func sac_energy() -> float:
	_peek()
	return _sac_glow


func visor_energy() -> float:
	_peek()
	return _visor_mat.emission_energy_multiplier


## The raw drives now (tests).
func drives() -> PackedFloat32Array:
	_peek()
	return _vd


## Where foot `k`'s tip and its knee stand now (m, the facing's frame; tests): the legs' chain from the drives.
func foot_at(k: int) -> Vector3:
	_peek()
	var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
	var low := Transform3D(Basis(Vector3.BACK, _vd[LEG0 + 3 * k + 2]), Vector3.ZERO)
	return _upper_xf(k) * low * (_feet[k] - knee)


func knee_at(k: int) -> Vector3:
	_peek()
	return _upper_xf(k) * Vector3.ZERO


## Leg `k`'s knee frame (its origin the knee) in the facing's frame.
func _upper_xf(k: int) -> Transform3D:
	var hip: Vector3 = _pivots[StringName("leg_%s_u" % LEGS[k])]
	var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
	var yaw := Transform3D(Basis(Vector3.UP, _vd[LEG0 + 3 * k]), hip)
	var up := Transform3D(Basis(Vector3.BACK, _vd[LEG0 + 3 * k + 1]), Vector3.ZERO)
	return _body_xf(_vd) * yaw * up * SoloVat.at(knee - hip)


# --- The pose -----------------------------------------------------------------------------------------------------
## The pose's numbers from the state (_vd, the lift, the glows): the clips' body drives and the feet's places first,
## then the legs reach for the feet under that body; then (the code path) the nodes from them.
func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var k := CALM if calm else 1.0
	var d := PackedFloat32Array()
	d.resize(VAT_DRIVES.size())
	for j in LEGS.size():
		_foot[j] = Vector3.ZERO
	var breath := sin(TAU * _t * BREATH_HZ)
	var lift := _walk_pose(d, k)
	lift += _idle_pose(d, k, calm, breath)
	lift += _tell_pose(d, k, calm)
	lift += _spit_pose(d, k, calm)
	lift += _hurt_pose(d, k, calm)
	lift += _rise_pose(d)
	lift = _death_pose(d, lift, calm)
	for j in LEG0:
		d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	_lift = lift
	_reach(d)
	for j in range(LEG0, VISOR):
		d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	_sac_glow = _sac_energy(calm, breath, d[SAC])
	d[VISOR] = _visor(calm)
	_vd = d
	_sac_mat.emission_energy_multiplier = _sac_glow
	_visor_mat.emission_energy_multiplier = d[VISOR]
	if not vat and rig != null:
		_apply()


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


## The gait (and the turn's stepping): each foot through its stride at its pair's place, along the way the body goes
## (the facing's frame), the turn sweeping it round the body; the body bobbing as each pair lands, rocking, swaying,
## the sac and the shell jiggling a beat behind. Returns its lift.
func _walk_pose(d: PackedFloat32Array, k: float) -> float:
	var g := clampf(_stride, 0.0, 1.0)
	var walk := clampf(_speed / MOVE_SPEED, 0.0, STRIDE_MAX)
	var turn := clampf(_omega / TURN_REF, -1.0, 1.0)
	var dir := Vector3(_dir.x, 0.0, _dir.y)
	for j in LEGS.size():
		var c := leg_cycle(fposmod(_phase - float(STRIDE_AT[j]), 1.0))
		var tip: Vector3 = _feet[j]
		var th := turn * TURN_SWING * c.x
		_foot[j] += (
			dir * (walk * SWEEP * c.x)
			+ Vector3(minf(walk, 1.0) * float(GATHER[j]) + th * tip.z, LIFT * g * c.y, -th * tip.x)
		)
	if g <= 0.0:
		return 0.0
	var p := _phase
	var w := minf(walk, 1.0)
	d[ROLL] += g * k * 0.04 * sin(TAU * (p - 0.1))
	d[SWAY] += w * k * 0.05 * sin(TAU * (p + 0.15))
	d[PITCH] += w * k * 0.015 * sin(2.0 * TAU * (p - 0.1)) - w * 0.03
	d[HEAD_Y] -= w * k * 0.045 * sin(TAU * (p + 0.15))  # the head holds its line against the sway
	d[HEAD_P] += w * k * 0.04 * cos(2.0 * TAU * (p - 0.2))
	d[SAC] += g * k * 0.07 * sin(2.0 * TAU * (p - 0.2))
	d[SHELL_UP] += g * k * 0.006 * sin(2.0 * TAU * (p - 0.15))
	d[SHELL_P] += g * k * 0.025 * sin(2.0 * TAU * (p - 0.22))
	return -CROUCH * w - g * k * 0.012 * cos(2.0 * TAU * (p - 0.05))


## One foot through its stride at q (0 its touchdown): (the sweep: 1 ahead .. -1 behind; the lift 0..1). On the
## ground the foot keeps still while the body passes over it; in the air it lifts and comes forward eased.
static func leg_cycle(q: float) -> Vector2:
	if q < DUTY:
		return Vector2(1.0 - 2.0 * q / DUTY, 0.0)
	var w := (q - DUTY) / (1.0 - DUTY)
	var up := sin(PI * w)
	return Vector2(-1.0 + 2.0 * smoothstep(0.0, 1.0, w), up * up * (3.0 - 2.0 * up))


## Idle (fading as it walks, winds up or dies): the sac breathing (and a gulp now and then), the shell riding the
## breath, the head's held glances and its twitch, the weight shifting, a foot re-planted now and then. Returns its
## lift.
func _idle_pose(d: PackedFloat32Array, k: float, calm: bool, breath: float) -> float:
	var idle := (1.0 - clampf(_stride, 0.0, 1.0)) * (1.0 - _coil) * (1.0 if _die_t < 0.0 else 0.0)
	if idle <= 0.0:
		return 0.0
	d[SAC] += idle * k * 0.08 * breath
	d[SHELL_UP] += idle * k * 0.004 * (breath + 1.0)
	d[SHELL_P] -= idle * k * 0.015 * breath
	d[HEAD_Y] += idle * k * 0.35 * _scan(_t, 2.4, 0.0)
	d[HEAD_P] += idle * k * (0.07 * _scan(_t, 3.3, 5.0) + 0.025 * (breath + 1.0))
	if not calm:
		d[HEAD_P] += idle * 0.08 * _twitch(_t, 3.9, 11.0)
		d[HEAD_Y] += idle * 0.07 * _twitch(_t, 4.6, 23.0)
		d[SAC] += idle * 0.14 * _gulp(_t)
	d[ROLL] += idle * k * 0.025 * sin(0.6 * _t)
	d[PITCH] += idle * k * 0.015 * sin(0.6 * _t + 1.7)
	d[SWAY] += idle * k * 0.03 * sin(0.4 * _t + 0.4)
	# A foot re-planted now and then (a different one each time): lifted, carried a little and set down.
	var u := _t / 2.8
	var seg := floorf(u)
	if _hash(seg + 7.0) > 0.4:
		var j := int(_hash(seg + 3.0) * LEGS.size()) % LEGS.size()
		var e := sin(PI * clampf((u - seg - 0.2) / 0.2, 0.0, 1.0))
		_foot[j] += Vector3(0.025, 0.05, 0.0) * e * idle
	return idle * k * 0.006 * breath


## The tell at its progress (_coil): a short crouch, then it rears back on its hind legs (the front feet lifting and
## reaching), the head tipping up (the mouth opening), the shell tilting back, while the sac swells in three gulps to
## full; a quiver at the top (not with reduced motion). Returns its lift.
func _tell_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	var p := _coil
	if p <= 0.0:
		return 0.0
	var crouch := sin(PI * clampf(p / 0.3, 0.0, 1.0)) * (1.0 - smoothstep(0.1, 0.35, p))
	var rear := smoothstep(0.1, 0.7, p)
	d[SAC] += 0.55 * gulps(p)
	d[PITCH] += (0.24 * rear - 0.05 * crouch) * k
	d[SURGE] -= 0.04 * rear * k
	d[HEAD_P] += 0.3 * rear * k - 0.08 * crouch
	d[HEAD_Y] *= 1.0 - rear
	d[SHELL_P] += 0.08 * rear * k
	d[SHELL_UP] += 0.01 * rear
	for j in 2:  # the front feet lift and reach
		_foot[j] += Vector3(0.05, 0.06, 0.0) * rear * k
	if not calm and _state == WorldReader.STATE_WINDUP:
		var top := smoothstep(0.75, 0.9, p)
		d[ROLL] += 0.012 * top * sin(TAU * 14.0 * _t)
		d[SAC] += 0.035 * top * sin(TAU * 11.0 * _t)
		d[HEAD_P] += 0.03 * top * sin(TAU * 9.0 * _t + 1.0)
	return -0.02 * crouch * k - 0.03 * rear


## The sac's swell through the windup at its progress p: three gulps, each one quick and then held, full from 85 %.
static func gulps(p: float) -> float:
	var g := clampf(p / 0.85, 0.0, 1.0) * 3.0
	return (floorf(g) + smoothstep(0.0, 0.45, g - floorf(g))) / 3.0


## The spit (SPIT_SECONDS from the throw): the head snaps forward with the mouth wide, the body lunging after it and
## recoiling, the sac emptying at once (a wobble as it goes, not with reduced motion) and refilling through the
## recovery, the mouth closing, the front feet bracing. Returns its lift.
func _spit_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _spit_t < 0.0:
		return 0.0
	var u := _spit_t / SPIT_SECONDS
	var snap := smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.25, 0.8, u))
	var gape := smoothstep(0.0, 0.04, u) * (1.0 - smoothstep(0.2, 0.65, u))
	var recoil := sin(PI * clampf((u - 0.08) / 0.3, 0.0, 1.0))
	var empty := smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.3, 1.0, u))
	d[PITCH] += (-0.12 * snap + 0.06 * recoil) * k
	d[SURGE] += (0.06 * snap - 0.05 * recoil) * k
	d[HEAD_P] += 0.5 * gape - 0.1 * snap
	d[SAC] -= 0.75 * empty
	d[SHELL_UP] += 0.015 * recoil
	d[SHELL_P] += (-0.06 * snap + 0.05 * recoil) * k
	for j in 2:  # (thrust out stiff: the lunge keeps the wrists off the ground)
		_foot[j] += Vector3(0.08, 0.0, 0.0) * snap
	if not calm:
		d[SAC] += 0.08 * empty * sin(TAU * 16.0 * _spit_t)
		d[ROLL] += 0.02 * recoil * sin(TAU * 10.0 * _spit_t)
	return (-0.015 * snap + 0.02 * recoil) * k


## A hit (its HP fell): the body jolts back, the sac squashes and wobbles (no wobble with reduced motion), the head
## ducks, a foot lifts. Returns its lift.
func _hurt_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _hurt_t < 0.0:
		return 0.0
	var h := _hurt_t / HURT_SECONDS
	var e := sin(PI * minf(h / 0.25, 1.0)) * (1.0 - smoothstep(0.25, 1.0, h))
	d[SURGE] -= 0.035 * e * k
	d[PITCH] += 0.05 * e * k
	d[HEAD_P] -= 0.15 * e * k
	d[SAC] -= 0.12 * e
	_foot[_hurt_leg] += Vector3(0.0, 0.05, 0.0) * e * k
	if not calm:
		d[SAC] += 0.08 * e * sin(TAU * 9.0 * _hurt_t)
		d[ROLL] += 0.03 * e * sin(TAU * 12.0 * _hurt_t)
	return -0.01 * e * k


## The rise-in: crouched on its folded legs (the front feet reaching further ahead, so the wrists stay off the
## ground), the sac empty and the head down, unfolding as it arrives, quickest at first, and at once as it sets off
## (its stride needs the height). Returns its lift.
func _rise_pose(d: PackedFloat32Array) -> float:
	var r := 1.0 - _rise
	if r <= 0.0:
		return 0.0
	var low := r * r * (1.0 - clampf(_stride, 0.0, 1.0))
	for j in 2:
		_foot[j] += Vector3(0.1, 0.0, 0.02 * signf(_feet[j].z)) * low
	d[SAC] -= 0.45 * r
	d[HEAD_P] -= 0.2 * r
	d[SHELL_UP] -= 0.01 * r
	return -0.14 * low


## The death: the sac bursts and empties (a wobble as it goes, not with reduced motion), the legs give way, the feet
## sliding out (the front ones far ahead, the legs lying out straight), and the body drops onto its belly tipping to
## one side, the head drooping, the shell slumping; a last kick of a hind leg (not with reduced motion). Returns the
## lift.
func _death_pose(d: PackedFloat32Array, lift: float, calm: bool) -> float:
	if _die_t < 0.0:
		return lift
	var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
	var keep := 1.0 - smoothstep(0.0, 0.2, u)
	for j in [SURGE, ROLL, PITCH, SWAY, HEAD_Y]:
		d[j] *= keep
	lift *= keep
	var burst := smoothstep(0.02, 0.3, u)
	var sag := smoothstep(0.12, 0.55, u)
	d[SAC] = lerpf(d[SAC], -0.65, burst)
	d[HEAD_P] = lerpf(d[HEAD_P], -0.12, sag)
	d[PITCH] -= 0.03 * sag
	d[ROLL] += 0.1 * sag
	d[SHELL_P] = lerpf(d[SHELL_P], -0.06, sag)
	d[SHELL_UP] = lerpf(d[SHELL_UP], -0.012, sag)
	for j in LEGS.size():
		var tip: Vector3 = _feet[j]
		var out := Vector3(0.14 if tip.x > 0.0 else -0.04, 0.0, signf(tip.z) * 0.06)
		_foot[j] = _foot[j] * keep + out * sag
	if not calm:
		d[SAC] += 0.15 * burst * (1.0 - smoothstep(0.2, 0.45, u)) * sin(TAU * 13.0 * _die_t)
		var kick := sin(PI * clampf((u - 0.68) / 0.16, 0.0, 1.0))
		_foot[2] += Vector3(-0.04, 0.07, 0.0) * kick
	return lift - 0.14 * sag


## The sac's glow: rest, brighter as it swells (and with each breath in, less with reduced motion), flashing as it
## empties at the spit and on a hit, dim as it rises in, flashing as it bursts in the death and then going out.
func _sac_energy(calm: bool, breath: float, swell: float) -> float:
	var e := SAC_REST + SAC_FULL * maxf(0.0, swell)
	e *= 1.0 + 0.25 * (0.4 if calm else 1.0) * breath
	if _spit_t >= 0.0:
		e += SAC_FLASH * (1.0 - smoothstep(0.0, 0.35, _spit_t / SPIT_SECONDS))
	if _hurt_t >= 0.0:
		e += 1.0 * (1.0 - _hurt_t / HURT_SECONDS)
	e *= lerpf(0.3, 1.0, _rise)
	if _die_t >= 0.0:
		var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
		e = lerpf(e, 0.05, smoothstep(0.15, 0.7, u))
		e += SAC_FLASH * sin(PI * clampf(u / 0.25, 0.0, 1.0))
	return e


## The visor's glow: rest; through the windup climbing to VISOR_TELL and flashing from TELL_FLASH_FROM (a flicker; a
## steady step with reduced motion); fading after the spit; going out in the death.
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
	if _spit_t >= 0.0:
		e = maxf(e, VISOR_TELL * (1.0 - smoothstep(0.0, 0.5, _spit_t / SPIT_SECONDS)))
	if _die_t >= 0.0:
		e = lerpf(e, 0.1, smoothstep(0.1, 0.6, clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)))
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


## A gulp now and then (mostly 0): the sac swells quickly and settles with a small dip.
static func _gulp(t: float) -> float:
	var u := t / 3.6 + 2.0
	var seg := floorf(u)
	if _hash(seg + 41.0) < 0.5:
		return 0.0
	var f := (u - seg - 0.5) / 0.08
	return sin(PI * clampf(f, 0.0, 1.0)) - 0.4 * sin(PI * clampf(f - 1.0, 0.0, 1.0))


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
	_peek()
	return _lift


func vat_drives() -> PackedFloat32Array:
	_peek()
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The sac's glow (the instance's accent glow; the visor's is the VISOR drive).
func glow_energy() -> float:
	_peek()
	return _sac_glow


## The owner's colour map (VatLooks' textured variant; HordeVat.texture), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## One grid per drive but the visor's (a turn sampled finely, a slide or the stretch on two samples: exact), the
## joints as the table.
func vat_rig() -> Dictionary:
	var grids: Array = []
	for d in VAT_SAMPLES.size():
		grids.append([[d, VAT_SAMPLES[d]]])
	var out := SoloVat.rig("frost_spitter", VAT_DRIVES, grids, _joints, true)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out
