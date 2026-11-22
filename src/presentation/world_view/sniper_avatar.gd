class_name SniperAvatar
extends AvatarBase
## The Sniper on the owner's model (EnemyModels &"sniper", cut by scripts/assets/needle_sniper_prep.py into the body
## (the hub, the face plate and its scope lens), the ridged blue shell, the long barrel and each of its three legs'
## upper half and long lower half), animated in code from the sim's state and drawn by the VAT crowd (SoloVat) while
## the switch is on. The owner asked for the enemies to be "animated as good as you can, if they can have multiple
## animations ... the better". Its biome's version, the Split Sniper, wears its palette on the same model.
## The sim's Sniper (data/enemies/sniper.tres) keeps far off at 2.6 m/s, takes a long aim (its windup: 1 s) down a
## line, fires one hard shot (a tracer down the line, HordeVisuals; the Split Sniper's line splits, VariantViews) and
## recovers.
## Its clips, each read from the sim through WorldReader (sync) and played in frame time (advance):
## - idle: the body scanning the room in held looks over its tripod (the long barrel sweeping with it) with a twitch
##   now and then, the lens breathing, the shell's plates riding the breath, the weight shifting, a foot re-planted;
## - the gait: a long-legged tripod walk, one leg in the air at a time (each foot planted while it is down: the legs
##   are posed by reach), the body dipping and rocking toward the leg in the air; the same legs step it round as it
##   turns;
## - the aim (WINDUP, the sim's own progress): it settles its tripod (the feet press out, the body sinks between them
##   with a small settling bounce), the body sweeps the barrel across the line and then locks onto it, every sway dying
##   out, the barrel tipping onto the aim, the lens and the muzzle charging and flashing from TELL_FLASH_FROM (steady
##   with reduced motion), a tremor just before the shot;
## - the shot (ACTIVE, then RECOVER: SHOT_SECONDS): the barrel slams back and runs out again, the body kicks back and
##   its nose up, the shell jolts, the muzzle flares; the feet stay planted. The Split Sniper's shot kicks twice;
## - the recovery's vent: the shell lifts at its front and lets the heat out, the muzzle cooling;
## - a hit flinch (its HP fell): the body jolts back and rolls, the shell rattles, a foot lifts;
## - the rise-in (SPAWN): it unfolds its tripod from a crouch;
## - the death (die(): DEATH_SECONDS): the tripod splays and gives way, the body drops tipping back, then its nose
##   drops as it lands, the barrel sliding out, the lens and the muzzle going out, a last kick of a leg;
## - reduced motion (ViewPrefs.reduced_motion): the same clips at CALM of the body's amplitudes, no tremors, twitches
##   or kicks, the flashes steady.
## The pose is a few plain numbers (the raw drives, _vd) worked out from the state first, then the nodes from them
## through the joint table (_joints, the same transforms the VAT rig declares), so the baked pose is the live one.
## On the VAT crowd it is batched (EnemyBatch: nothing here reads the tree, its turn is its facing node's), and the
## native batch runs the same sync, frame step and pose (native/src/zd_avatar_sniper.cpp).
## Presentation only (EI-07): nothing here reaches the sim. +X is the front (the barrel), +Z its right.

const KIND := WorldReader.KIND_SNIPER
const MODEL := &"sniper"
const HEIGHT := 1.3
## The lens's colour (a variant's: its palette's eye) and the bore's dark face.
const LENS := Color("#6FD2FF")
const HOLE := Color("#141417")
## The lens's glow at rest and on a shot; the muzzle's at full charge and its flare on a shot.
const LENS_REST := 1.8
const LENS_SHOT := 7.0
const MUZZLE_CHARGE := 4.0
const MUZZLE_FLARE := 8.0
const TELEPORT_SPEED := 20.0
## The clips' lengths (s): the shot and its recovery (the attack's active and recovery time), the vent, a hit's
## flinch, the death, the settle of the tripod as the aim starts; the Split Sniper's second kick, after the first.
const SHOT_SECONDS := 0.52
const VENT_SECONDS := 0.7
const HURT_SECONDS := 0.35
const DEATH_SECONDS := 1.1
const SETTLE_SECONDS := 0.45
const SECOND_KICK := 0.15
## The gait: the speed (m/s) a full stride is made at (the sim's move speed), the share of the stride a foot is down
## (two of three always are), the foot's sweep either side of its stride's middle (m) and its lift (m); the cadence
## (Hz) that keeps a planted foot still there. A longer stride than STRIDE_MAX quickens the cadence instead.
const MOVE_SPEED := 2.6
const DUTY := 0.7
const SWEEP := 0.17
const LIFT := 0.1
const STRIDE_MAX := 1.4
const STEP_HZ := MOVE_SPEED * DUTY / (2.0 * SWEEP)
## How far (m) each foot's stride sits in from its rest toward the body (the legs stand nearly straight at rest), the
## body's crouch (m) at a full stride, the turn rate (rad/s) of a full turning step and the turn (radians) a step
## makes.
const GATHER := 0.09
const CROUCH := 0.06
const TURN_REF := 3.0
const TURN_SWING := 0.2
## The legs (f: the front one; r: the hind one on its right; l: the one on its left) and each one's place in the
## stride: one at a time.
const LEGS: Array[StringName] = [&"f", &"r", &"l"]
const STRIDE_AT := [0.0, 0.333, 0.667]
## The settled tripod: how far the body sinks (m) and the feet press out (m); the sweep of the barrel across the line
## (radians) while it still searches.
const BRACE_DROP := 0.08
const BRACE_WIDE := 0.04
const SEARCH := 0.14
## The breath (Hz); reduced motion's share of the body's motion.
const BREATH_HZ := 0.45
const CALM := 0.45
## The joints' pivots and the feet's tips (m, the model's frame) when the model is missing (the prep's own).
const PIVOTS := {
	&"body": Vector3.ZERO,
	&"shell": Vector3(-0.205, 0.885, 0.0),
	&"barrel": Vector3(0.387, 0.755, 0.0),
	&"leg_f_u": Vector3(0.008, 0.648, -0.103),
	&"leg_f_l": Vector3(0.134, 0.49, -0.182),
	&"leg_r_u": Vector3(-0.008, 0.648, -0.079),
	&"leg_r_l": Vector3(-0.142, 0.442, -0.197),
	&"leg_l_u": Vector3(-0.024, 0.663, 0.039),
	&"leg_l_l": Vector3(-0.071, 0.411, 0.276),
}
const FEET := [
	Vector3(0.387, 0.008, -0.232),
	Vector3(-0.276, 0.008, -0.379),
	Vector3(-0.106, 0.008, 0.441),
]
## The barrel's tip (m, the model's frame, at rest): where the shot leaves it (HordeVisuals draws the tracer at its
## height).
const MUZZLE_AT := Vector3(1.058, 0.759, 0.0)
## The body's roll and pitch pivot: the hub its legs hang from, so it turns on its tripod.
const HUB := Vector3(0.0, 0.66, 0.0)
## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]: the body's surge (m, + forward), roll, pitch (+ the
## nose up) and sway (its yaw on the tripod), the shell's lift (m) and tilt (+ its front up), the barrel's slide (m,
## + out), each leg's yaw, hip and knee turns in LEGS order, then the muzzle's glow (no grid: sent as it is).
const SURGE := 0
const ROLL := 1
const PITCH := 2
const SWAY := 3
const SHELL_UP := 4
const SHELL_P := 5
const BARREL := 6
const LEG0 := 7
const MUZZLE := 16
const VAT_DRIVES := [
	[-0.12, 0.08, false],
	[-0.3, 0.3, false],
	[-0.4, 0.4, false],
	[-0.5, 0.5, false],
	[-0.04, 0.08, false],
	[-0.25, 0.25, false],
	[-0.2, 0.06, false],
	[-0.8, 0.8, false],
	[-1.3, 1.3, false],
	[-1.8, 1.8, false],
	[-0.8, 0.8, false],
	[-1.3, 1.3, false],
	[-1.8, 1.8, false],
	[-0.8, 0.8, false],
	[-1.3, 1.3, false],
	[-1.8, 1.8, false],
	[0.0, 0.0, false],
]
## Each drive's samples (a turn finely; a slide linear: exact on two).
const VAT_SAMPLES := [2, 25, 41, 41, 2, 25, 2, 33, 57, 65, 33, 57, 65, 33, 57, 65]

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds no nodes.
var vat := false
var kind := KIND
var height := HEIGHT
## True when the body is the owner's model (else the code-made stand-in on the same joints).
var has_model := false
## The parts (tests): the rig's root (the body), the shell, the barrel, each leg's upper and lower node (LEGS order).
var rig: Node3D
var shell: Node3D
var barrel: Node3D
var uppers: Array[Node3D] = []
var lowers: Array[Node3D] = []

var _vd := PackedFloat32Array()
var _lift := 0.0
var _lens_mat := StandardMaterial3D.new()
var _hole_mat := StandardMaterial3D.new()
var _pivots := PIVOTS.duplicate()
var _hips: Array[Vector3] = []
var _knees: Array[Vector3] = []
var _feet: Array[Vector3] = []
var _muzzle_rest := MUZZLE_AT
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
var _brace := 0.0
var _charge := 0.0
var _rise := 0.0
var _settle_t := -1.0
var _shot_t := -1.0
var _double := false
var _heat := 0.0
var _vent_t := -1.0
var _hurt_t := -1.0
var _hurt_leg := 0
var _die_t := -1.0
var _last_fy := 0.0
var _have_fy := false


## Builds a Sniper (or its biome's version `p_kind`) under `facing` for ActorViews (`views`: on VAT while its switch
## is on) and marks `root` (the avatar, its body materials for the hit flash); returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D, p_kind: int) -> float:
	var sniper := SniperAvatar.new()
	views._solo_vat(root, sniper, p_kind)
	sniper.look_kind = p_kind
	sniper.setup()
	facing.add_child(sniper)
	root.set_meta(&"enemy_avatar", sniper)
	root.set_meta(&"mats", sniper.body_materials.duplicate())
	return HEIGHT


func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	var variant := look_kind >= 0 and look_kind != KIND
	_double = look_kind == WorldReader.KIND_SPLIT_SNIPER
	var lens := _look_color(KIND, &"eye") if variant else LENS
	_lens_mat.albedo_color = lens
	_lens_mat.emission_enabled = true
	_lens_mat.emission = lens
	_lens_mat.emission_energy_multiplier = LENS_REST
	_hole_mat.albedo_color = HOLE
	_hole_mat.emission_enabled = true
	_hole_mat.emission = ThemePalette.color(&"proj_hostile")
	_hole_mat.emission_energy_multiplier = 0.0
	_hole_mat.set_meta(SoloVat.GLOW, MUZZLE + 1)  # a VAT Sniper's muzzle glows at its MUZZLE drive
	var m := EnemyModels.get_model(MODEL)
	has_model = not m.is_empty()
	var s := 1.0
	if has_model:
		s = float(m["scale"])
		var parts_in: Dictionary = m["parts"]
		for pname: StringName in parts_in:
			_pivots[pname] = (parts_in[pname] as Dictionary)["pivot"] * s
	_muzzle_rest = MUZZLE_AT * s
	for k in LEGS.size():
		_hips.append(_pivots[StringName("leg_%s_u" % LEGS[k])])
		_knees.append(_pivots[StringName("leg_%s_l" % LEGS[k])])
		_feet.append(FEET[k] * s)
		_foot.append(Vector3.ZERO)
	if not vat:  # (else the crowd draws the body)
		rig = _node(self, "Rig")
		shell = _node(rig, "Shell")
		barrel = _node(rig, "Barrel")
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
		&"barrel":
			return [barrel, _pivots[&"barrel"]]
	var bits := String(part).split("_")
	var k := LEGS.find(StringName(bits[1])) if bits.size() == 3 and bits[0] == "leg" else -1
	if k < 0:
		return [rig, Vector3.ZERO]
	return [uppers[k] if bits[2] == "u" else lowers[k], _pivots[part]]


## The owner's model: each part's mesh in its joint's frame, its surfaces on the base / role plates (the role plates
## greyscale in the map, tinted the kind's role colour) and the glow (the lens on the body, the muzzle on the barrel).
func _build_model(m: Dictionary) -> void:
	var tex: Texture2D = m["texture"]
	var s: float = m["scale"]
	var parts_in: Dictionary = m["parts"]
	var mats := {}
	for slot: StringName in [&"base", &"role"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = _look_color(KIND, &"body") if slot == &"role" else Color.WHITE
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
		var glow := _hole_mat if pname == &"barrel" else _lens_mat
		for k in surfaces.size():
			mi.set_surface_override_material(
				k, glow if surfaces[k] == &"glow" else mats.get(surfaces[k], mats[&"base"])
			)
		(f[0] as Node3D).add_child(mi)


## The code-made stand-in (the model file missing): boxes on the same joints, so every clip still plays.
func _build_code() -> void:
	var charcoal := Color("#262A32")
	var grey := Color("#56606A")
	_box(rig, Vector3(0.3, 0.3, 0.26), Vector3(0.0, 0.76, 0), charcoal)
	_box(shell, Vector3(0.6, 0.18, 0.3), Vector3(0.05, 0.0, 0), _look_color(KIND, &"body"))
	_box(barrel, Vector3(0.68, 0.05, 0.05), Vector3(0.34, 0.0, 0), grey)
	_glow_box(rig, Vector3(0.02, 0.1, 0.1), Vector3(0.16, 0.86, 0), _lens_mat)
	_glow_box(
		barrel,
		Vector3(0.012, 0.06, 0.06),
		Vector3(MUZZLE_AT.x - _pivots[&"barrel"].x, 0, 0),
		_hole_mat
	)
	for k in LEGS.size():
		_rod(uppers[k], Vector3.ZERO, _knees[k] - _hips[k], grey)
		_rod(lowers[k], Vector3.ZERO, _feet[k] - _knees[k], grey)


func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	return _body_piece(parent, CodeMeshes.chamfer_box(size, minf(size.x, size.y) * 0.15), at, c)


func _glow_box(parent: Node3D, size: Vector3, at: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)


func _rod(parent: Node3D, from: Vector3, to: Vector3, c: Color) -> void:
	var piece := _box(parent, Vector3(0.05, (to - from).length(), 0.05), (from + to) * 0.5, c)
	piece.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))


## The joint table (see _joints): the body's surge, roll and pitch (both at the hub) and sway (the rig), the shell's
## lift and tilt at its back, the barrel's slide at its root, each leg's yaw, hip and knee (LeggedRig.leg_joints).
func _build_joints() -> void:
	var z := Vector3.BACK
	_joints = [
		[SURGE, -1, null, SoloVat.slide(Vector3.RIGHT)],
		[ROLL, 0, null, SoloVat.turn(Vector3.RIGHT, 1.0, SoloVat.at(HUB))],
		[PITCH, 1, null, SoloVat.turn(z, 1.0, Transform3D.IDENTITY, SoloVat.at(-HUB))],
		[SWAY, 2, rig, SoloVat.turn(Vector3.UP)],
		[SHELL_UP, 3, null, SoloVat.slide(Vector3.UP, Vector3.ZERO, SoloVat.at(_pivots[&"shell"]))],
		[SHELL_P, 4, shell, SoloVat.turn(z)],
		[
			BARREL,
			3,
			barrel,
			SoloVat.slide(Vector3.RIGHT, Vector3.ZERO, SoloVat.at(_pivots[&"barrel"]))
		],
	]
	for k in LEGS.size():
		var up: Node3D = uppers[k] if k < uppers.size() else null
		var low: Node3D = lowers[k] if k < lowers.size() else null
		var bones: Array[Vector3] = [_hips[k], _knees[k], _feet[k]]
		_joints.append_array(LeggedRig.leg_joints(LEG0, k, 3, _joints.size(), bones, up, low))


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
		var shot := st == WorldReader.STATE_ACTIVE and _state != WorldReader.STATE_ACTIVE
		var missed := st == WorldReader.STATE_RECOVER and _state == WorldReader.STATE_WINDUP
		if shot or missed:  # (a one-tick shot between two syncs still kicks)
			_shot_t = 0.0
			_heat = 1.0
		if st == WorldReader.STATE_RECOVER and _state != WorldReader.STATE_RECOVER:
			_vent_t = 0.0
		if st == WorldReader.STATE_WINDUP and _state != WorldReader.STATE_WINDUP:
			_settle_t = 0.0
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
	_speed = lerpf(_speed, _vel.length() if moving else 0.0, _rate(8.0 if moving else 5.0, dt))
	var fy := (get_parent() as Node3D).rotation.y if get_parent() is Node3D else 0.0
	_omega = LeggedRig.turning(_omega, fy, _last_fy, _have_fy and not dying, dt, _rate(10.0, dt))
	_last_fy = fy
	_have_fy = true
	var local := Vector3(_vel.x, 0.0, -_vel.y).rotated(Vector3.UP, -_last_fy)
	if moving and local.length() > 0.2:
		var to := _dir.lerp(Vector2(local.x, local.z).normalized(), _rate(10.0, dt))
		_dir = to.normalized() if to.length() > 0.05 else _dir
	var most := maxf(_speed / MOVE_SPEED, absf(_omega) / TURN_REF)
	_stride = move_toward(_stride, minf(most, 1.0), dt * (4.0 if most > _stride else 2.5))
	_phase = fposmod(_phase + STEP_HZ * maxf(1.0, most / STRIDE_MAX) * dt * signf(_stride), 1.0)
	var planted := (
		_state != WorldReader.STATE_MOVE and _state != WorldReader.STATE_SPAWN and not dying
	)
	_brace = move_toward(_brace, 1.0 if planted else 0.0, dt * (4.0 if planted else 2.0))
	var charge := _tell if _state == WorldReader.STATE_WINDUP else 0.0
	_charge = move_toward(_charge, charge, dt * (20.0 if charge > _charge else 4.0))
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.2))
	_settle_t = LeggedRig.clip(_settle_t, dt, SETTLE_SECONDS)
	_shot_t = LeggedRig.clip(_shot_t, dt, SHOT_SECONDS)
	_vent_t = LeggedRig.clip(_vent_t, dt, VENT_SECONDS)
	_hurt_t = LeggedRig.clip(_hurt_t, dt, HURT_SECONDS)
	_heat = move_toward(_heat, 0.0, dt * 1.2)
	if dying:
		_die_t += dt
	_pose()


## Starts the death (ActorViews or the enemy batch, when the sim drops the Sniper: its bar hidden, freed DEATH_SECONDS
## later). True: it plays.
func die() -> bool:
	_touch()
	if _die_t < 0.0:
		_die_t = 0.0
	return true


func dying() -> bool:
	_peek()
	return _die_t >= 0.0


## The barrel's recoil now (m it has slid back from rest; 0 at rest).
func barrel_recoil() -> float:
	_peek()
	return maxf(0.0, -_vd[BARREL])


## The lens's glow and the muzzle's now (emission energies; the muzzle 0 when cold).
func lens_energy() -> float:
	_peek()
	return _lens_mat.emission_energy_multiplier


func muzzle_energy() -> float:
	_peek()
	return _hole_mat.emission_energy_multiplier


## How deep its aim's crouch is (0..1; the windup tell).
func crouch_amount() -> float:
	_peek()
	return tell_crouch(_tell) if _state == WorldReader.STATE_WINDUP else 0.0


## The raw drives now (tests).
func drives() -> PackedFloat32Array:
	_peek()
	return _vd


## Where foot `k`'s tip and its knee stand now (m, the facing's frame; tests).
func foot_at(k: int) -> Vector3:
	_peek()
	return LeggedRig.tip_at(_vd, LEG0, k, _body_xf(_vd), _hips[k], _knees[k], _feet[k])


func knee_at(k: int) -> Vector3:
	_peek()
	return (
		LeggedRig.knee_xf(_vd, LEG0, k, _body_xf(_vd), _hips[k], _knees[k], _feet[k]) * Vector3.ZERO
	)


## Where the barrel's tip is now (m, the facing's frame): the muzzle the shot leaves.
func muzzle_at() -> Vector3:
	_peek()
	return _body_xf(_vd) * (_muzzle_rest + Vector3(_vd[BARREL], 0, 0))


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
	lift += _aim_pose(d, k, calm)
	lift += _shot_pose(d, k, calm)
	lift += _vent_pose(d, k)
	lift += _hurt_pose(d, k, calm)
	lift += _rise_pose(d)
	lift = _death_pose(d, lift, calm)
	for j in LEG0:
		d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	_lift = lift
	var want: Array[Vector3] = []
	for j in LEGS.size():
		want.append(_feet[j] + _foot[j])
	LeggedRig.reach(d, LEG0, _body_xf(d), _hips, _knees, _feet, want)
	for j in range(LEG0, MUZZLE):
		d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	d[MUZZLE] = _muzzle(calm)
	_vd = d
	_lens_mat.emission_energy_multiplier = _lens(calm, breath)
	_hole_mat.emission_energy_multiplier = d[MUZZLE]
	if not vat and rig != null:
		LeggedRig.apply(_joints, _vd, _lift, rig)


## The rig's transform (the body's: the lift, the surge, the roll and the pitch at the hub, the sway) from `d`.
func _body_xf(d: PackedFloat32Array) -> Transform3D:
	return (
		Transform3D(Basis.IDENTITY, Vector3(d[SURGE], _lift, 0.0))
		* SoloVat.at(HUB)
		* Transform3D(Basis(Vector3.RIGHT, d[ROLL]), Vector3.ZERO)
		* Transform3D(Basis(Vector3.BACK, d[PITCH]), Vector3.ZERO)
		* SoloVat.at(-HUB)
		* Transform3D(Basis(Vector3.UP, d[SWAY]), Vector3.ZERO)
	)


## The gait (and the turn's stepping): each foot through its stride at its place (one leg up at a time), along the
## way the body goes, gathered in toward the hub for room; the body dipping and rocking toward the leg in the air.
## Returns its lift.
func _walk_pose(d: PackedFloat32Array, k: float) -> float:
	var g := clampf(_stride, 0.0, 1.0)
	var walk := clampf(_speed / MOVE_SPEED, 0.0, STRIDE_MAX)
	var turn := clampf(_omega / TURN_REF, -1.0, 1.0)
	var dir := Vector3(_dir.x, 0.0, _dir.y)
	var lean := Vector2.ZERO
	for j in LEGS.size():
		var c := LeggedRig.leg_cycle(fposmod(_phase - float(STRIDE_AT[j]), 1.0), DUTY)
		var tip: Vector3 = _feet[j]
		var th := turn * TURN_SWING * c.x
		var inward := -Vector3(tip.x, 0.0, tip.z).normalized() * GATHER * g
		_foot[j] += (
			dir * (walk * SWEEP * c.x) + inward + Vector3(th * tip.z, LIFT * g * c.y, -th * tip.x)
		)
		lean += Vector2(tip.x, tip.z).normalized() * c.y  # toward the leg in the air
	if g <= 0.0:
		return 0.0
	var p := _phase
	var w := minf(walk, 1.0)
	d[PITCH] += g * k * 0.03 * lean.x - w * 0.03
	d[ROLL] -= g * k * 0.04 * lean.y
	d[SWAY] += w * k * 0.04 * sin(TAU * (p + 0.1))
	d[SHELL_UP] += g * k * 0.008 * sin(3.0 * TAU * (p - 0.15))
	d[SHELL_P] += g * k * 0.03 * sin(3.0 * TAU * (p - 0.2))
	return -CROUCH * g - g * k * 0.018 * cos(3.0 * TAU * (p - 0.08))


## Idle (fading as it walks, aims or dies): the body scanning the room in held looks on its tripod (the barrel
## sweeping with it) and their twitch, the shell's plates riding the breath, the weight shifting, a foot re-planted
## now and then. Returns its lift.
func _idle_pose(d: PackedFloat32Array, k: float, calm: bool, breath: float) -> float:
	var idle := (1.0 - clampf(_stride, 0.0, 1.0)) * (1.0 - _brace) * _alive()
	if idle <= 0.0:
		return 0.0
	d[SWAY] += idle * k * 0.4 * LeggedRig.scan(_t, 2.8, 0.0)
	d[PITCH] += idle * k * 0.06 * LeggedRig.scan(_t, 3.6, 4.0)
	d[ROLL] += idle * k * 0.02 * sin(0.6 * _t + 0.5)
	d[SHELL_UP] += idle * k * 0.006 * (breath + 1.0)
	d[SHELL_P] -= idle * k * 0.02 * breath
	if not calm:
		d[SWAY] += idle * 0.07 * LeggedRig.twitch(_t, 4.3, 9.0)
		d[PITCH] += idle * 0.04 * LeggedRig.twitch(_t, 3.9, 21.0)
	var step := LeggedRig.replant(_t, 3.1, LEGS.size())
	if int(step[0]) >= 0:
		_foot[int(step[0])] += Vector3(0.03, 0.07, 0.0) * float(step[1]) * idle
	return idle * k * 0.008 * breath


## The aim (the brace, eased in through the windup and held to the end of the recovery): the feet press out and the
## body sinks between them with a settling bounce; through the first half the body sweeps the barrel across the line
## (dying out), then locks on, the barrel tipping onto the aim and every sway held still; a tremor at the top just
## before the shot (not with reduced motion). Returns its lift.
func _aim_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	var b := smoothstep(0.0, 1.0, _brace)
	if b <= 0.0:
		return 0.0
	for j in LEGS.size():
		var tip: Vector3 = _feet[j]
		_foot[j] += Vector3(tip.x, 0.0, tip.z).normalized() * BRACE_WIDE * b
	var aiming := _state == WorldReader.STATE_WINDUP
	var p := _tell if aiming else 1.0
	var search := (1.0 - smoothstep(0.25, 0.6, p)) * b
	d[SWAY] += search * k * SEARCH * sin(TAU * 0.9 * _t)
	d[PITCH] += search * k * 0.03 * sin(TAU * 0.6 * _t + 1.0)
	d[PITCH] -= 0.035 * smoothstep(0.3, 0.7, p) * b
	d[SHELL_UP] -= 0.01 * b
	d[SHELL_P] -= 0.05 * b * k
	d[BARREL] += 0.03 * b
	var lift := -BRACE_DROP * b * lerpf(0.7, 1.0, k)
	if _settle_t >= 0.0:  # the tripod settles: a small bounce as the weight comes onto it
		var u := _settle_t / SETTLE_SECONDS
		lift -= 0.02 * k * sin(PI * 3.0 * u) * (1.0 - u)
	if not calm and aiming:
		var top := smoothstep(0.8, 0.92, p)
		d[PITCH] += 0.004 * top * sin(TAU * 13.0 * _t)
	return lift


## The shot (SHOT_SECONDS from it): the barrel slams back and runs out again, the body kicks back and its nose up, the
## shell jolts and settles (a shudder, not with reduced motion); the Split Sniper kicks a second time SECOND_KICK
## after. Returns its lift.
func _shot_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _shot_t < 0.0:
		return 0.0
	var e := kick(_shot_t)
	if _double:
		e = maxf(e, 0.85 * kick(_shot_t - SECOND_KICK))
	var u := _shot_t / SHOT_SECONDS
	var rock := sin(PI * clampf(u / 0.6, 0.0, 1.0)) * (1.0 - u * 0.5)
	d[BARREL] -= 0.15 * e
	d[SURGE] -= (0.04 * rock + 0.02 * e) * k
	d[PITCH] += (0.12 * rock + 0.04 * e) * k
	d[SHELL_UP] += 0.02 * rock
	d[SHELL_P] += 0.06 * rock * k
	if not calm:
		d[ROLL] += 0.025 * rock * sin(TAU * 14.0 * _shot_t)
	return 0.01 * rock * k


## The barrel's kick at `t` s after its shot (0..1): a slam back in a frame or two, then it runs out again.
static func kick(t: float) -> float:
	if t < 0.0:
		return 0.0
	return smoothstep(0.0, 0.025, t) * (1.0 - smoothstep(0.03, 0.12, t))


## The vent after the shot (VENT_SECONDS from the recovery): the shell lifts at its front and lets the heat out, then
## settles. Returns its lift.
func _vent_pose(d: PackedFloat32Array, k: float) -> float:
	if _vent_t < 0.0:
		return 0.0
	var e := sin(PI * clampf(_vent_t / VENT_SECONDS, 0.0, 1.0))
	d[SHELL_UP] += 0.035 * e
	d[SHELL_P] += 0.1 * e * k
	return 0.0


## A hit (its HP fell): the body jolts back and rolls, the shell rattles (not with reduced motion), a foot lifts.
## Returns its lift.
func _hurt_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _hurt_t < 0.0:
		return 0.0
	var h := _hurt_t / HURT_SECONDS
	var e := sin(PI * minf(h / 0.25, 1.0)) * (1.0 - smoothstep(0.25, 1.0, h))
	d[SURGE] -= 0.04 * e * k
	d[PITCH] += 0.07 * e * k
	d[ROLL] += 0.07 * e * k * (1.0 if _hurt_leg % 2 == 0 else -1.0)
	_foot[_hurt_leg] += Vector3(0.0, 0.06, 0.0) * e * k
	if not calm:
		d[SHELL_UP] += 0.012 * e * absf(sin(TAU * 10.0 * _hurt_t))
		d[SHELL_P] += 0.05 * e * sin(TAU * 12.0 * _hurt_t)
	return -0.015 * e * k


## The rise-in: crouched low on its folded tripod (the feet further out), the barrel drawn in, unfolding as it
## arrives, quickest at first, and at once as it sets off. Returns its lift.
func _rise_pose(d: PackedFloat32Array) -> float:
	var r := 1.0 - _rise
	if r <= 0.0:
		return 0.0
	var low := r * r * (1.0 - clampf(_stride, 0.0, 1.0))
	for j in LEGS.size():
		var tip: Vector3 = _feet[j]
		_foot[j] += Vector3(tip.x, 0.0, tip.z).normalized() * 0.12 * low
	d[SHELL_UP] -= 0.02 * r
	d[PITCH] -= 0.1 * r
	d[BARREL] -= 0.12 * r
	return -0.22 * low


## The death: the tripod splays and gives way and the body drops tipping back and to one side, then its nose drops as
## it lands, the barrel sliding out, the shell slumping; a last kick of a leg (not with reduced motion). Returns the
## lift.
func _death_pose(d: PackedFloat32Array, lift: float, calm: bool) -> float:
	if _die_t < 0.0:
		return lift
	var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
	var keep := 1.0 - smoothstep(0.0, 0.2, u)
	for j in [SURGE, ROLL, PITCH, SWAY]:
		d[j] *= keep
	lift *= keep
	var splay := smoothstep(0.05, 0.6, u)
	var land := smoothstep(0.45, 0.85, u)
	d[PITCH] += 0.18 * splay - 0.3 * land
	d[ROLL] += 0.14 * splay
	d[SHELL_P] = lerpf(d[SHELL_P], -0.15, land)
	d[SHELL_UP] = lerpf(d[SHELL_UP], -0.02, land)
	d[BARREL] = lerpf(d[BARREL], 0.05, splay)
	for j in LEGS.size():
		var tip: Vector3 = _feet[j]
		_foot[j] = _foot[j] * keep + Vector3(tip.x, 0.0, tip.z).normalized() * 0.2 * splay
	if not calm:
		var kick_e := sin(PI * clampf((u - 0.7) / 0.15, 0.0, 1.0))
		_foot[1] += Vector3(-0.03, 0.08, 0.0) * kick_e
	return lift - 0.3 * splay


## The lens's glow: rest (breathing, less with reduced motion); through the aim climbing and flashing from
## TELL_FLASH_FROM (tell_glow); flaring to LENS_SHOT on the shot; dim as it rises in; going out in the death.
func _lens(calm: bool, breath: float) -> float:
	var e := LENS_REST * (1.0 + 0.2 * (0.4 if calm else 1.0) * breath)
	if _state == WorldReader.STATE_WINDUP and _die_t < 0.0:
		e = LENS_REST * tell_glow(_tell, _t, calm)
	if _shot_t >= 0.0:
		e = maxf(e, LENS_SHOT * (1.0 - _shot_t / SHOT_SECONDS))
	if _hurt_t >= 0.0:
		e += 1.0 * (1.0 - _hurt_t / HURT_SECONDS)
	e *= lerpf(0.25, 1.0, _rise)
	if _die_t >= 0.0:
		e = lerpf(e, 0.05, smoothstep(0.1, 0.6, clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)))
	return e


## The muzzle's glow: cold at rest; charging through the aim (flickering at its flash, steady with reduced motion),
## flaring on the shot, cooling with its heat after; going out in the death.
func _muzzle(calm: bool) -> float:
	var e := MUZZLE_CHARGE * smoothstep(0.0, 1.0, _charge)
	if _state == WorldReader.STATE_WINDUP and tell_flashing(_tell) and not calm:
		e *= 0.8 + 0.4 * float(int(_t * TELL_FLICKER_HZ * 2.0) % 2)
	e = maxf(e, MUZZLE_CHARGE * 0.5 * _heat)
	if _shot_t >= 0.0:
		e = maxf(e, MUZZLE_FLARE * (1.0 - smoothstep(0.0, 0.4, _shot_t / SHOT_SECONDS)))
	if _die_t >= 0.0:
		e *= 1.0 - smoothstep(0.0, 0.4, clampf(_die_t / DEATH_SECONDS, 0.0, 1.0))
	return e


## 1 while it lives, easing to 0 over the death's first fifth (the clips it stops fade out, never snap).
func _alive() -> float:
	return (
		1.0
		if _die_t < 0.0
		else 1.0 - smoothstep(0.0, 0.2, clampf(_die_t / DEATH_SECONDS, 0.0, 1.0))
	)


# --- SoloVat: the VAT rig -----------------------------------------------------------------------------------------
## The whole body's lift (m): VatCrowd moves the instance by it.
func vat_lift() -> float:
	_peek()
	return _lift


func vat_drives() -> PackedFloat32Array:
	_peek()
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The lens's glow (the instance's accent glow; the muzzle's is the MUZZLE drive).
func glow_energy() -> float:
	_peek()
	return _lens_mat.emission_energy_multiplier


## The owner's colour map (VatLooks' textured variant; HordeVat.texture), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## One grid per drive but the muzzle's (a turn sampled finely, a slide on two samples: exact), the joints as the table.
func vat_rig() -> Dictionary:
	var grids: Array = []
	for d in VAT_SAMPLES.size():
		grids.append([[d, VAT_SAMPLES[d]]])
	var out := SoloVat.rig("sniper", VAT_DRIVES, grids, _joints, true)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out
