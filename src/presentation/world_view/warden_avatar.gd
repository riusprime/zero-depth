class_name WardenAvatar
extends AvatarBase
## The Warden on the owner's model (EnemyModels &"warden", cut by scripts/assets/warden_prep.py into the body under
## its bronze shell, the head, each arm's shoulder boulder and forearm with its fist, each leg's thigh, shin and foot):
## a hulking rock golem that walks on its feet and its knuckles. Animated in code from the sim's state and drawn by the
## VAT crowd (SoloVat) while the switch is on. The owner asked for the enemies to be "animated as good as you can, if
## they can have multiple animations ... the better". The Warden takes less damage from the front and more from the
## back; the seam that splits its shell glows (its cracks, the model's glow surface), the eye glows under the lip.
## Its clips, each read from the sim through WorldReader (sync) and played in frame time (advance):
## - idle: heavy breathing, the head's slow held glances, the weight shifting from foot to foot, a fist re-planted now
##   and then; the feet and the knuckles stay planted (the limbs are posed by reach: hip, knee and foot, shoulder and
##   elbow solved for where the foot or the fist stands);
## - the walk: a heavy four-beat knuckle-walk (left foot, left fist, right foot, right fist), each foot and fist still
##   on the ground while it is down and swung forward in the air, the body thumping down as each foot lands, rolling
##   onto it, swaying, leaning into the walk; the same steps carry it round as it turns;
## - the tell (WINDUP, the sim's own progress): the fists climb overhead and meet, the chest heaves back, the knees
##   bend into a crouch that deepens with the windup, the head tips up, the eye brightens and flashes from
##   TELL_FLASH_FROM (steady with reduced motion), trembling at the top;
## - the slam (the hit tick: AvatarBase's strike snap): the fists come down hard on the ground in front, the chest
##   pitching forward and the knees dropping; the impact shakes it and a dust ring runs out over the slam's circle (its
##   radius from the telegraph); the fists stay down through the first part of the recovery, then push it back up;
## - a hit (its HP fell): the body jolts back, the head ducks;
## - the rise-in (SPAWN): it climbs out of the ground, leaning back, reaching up;
## - the death (die(): DEATH_SECONDS): the cracks flare and go out with the eye, the knees buckle, it falls forward onto
##   its fists and then its chest, tipping to one side, the head drooping;
## - reduced motion (ViewPrefs.reduced_motion): the same clips at CALM of the body's amplitudes, no trembles or fist
##   re-plants, the flashes steady.
## The pose is a few plain numbers (the raw drives, _vd) worked out from the state first, then the nodes from them
## through the joint table (_joints, the same transforms the VAT rig declares), so the baked pose is the live one.
## On the VAT crowd it is batched (EnemyBatch): nothing here reads the tree (the facing's turn is its parent's own
## transform), and BatchWarden keeps its dust ring in the tree. Presentation only (EI-07). +X is the front, +Z its
## right; the node sits at the actor's feet under the facing.

const KIND := WorldReader.KIND_WARDEN
const MODEL := &"warden"
const HEIGHT := 1.25
## The cracks' glow (the bronze shell takes the tank's role colour, EnemyPalettes' body).
const CRACK_COLOR := Color("#FF8A3C")
const TELEPORT_SPEED := 30.0
## The clips' lengths (s): a hit's jolt, the death, the rise-in.
const HURT_SECONDS := 0.4
const DEATH_SECONDS := 1.3
const RISE_SECONDS := 0.45
## Recovery is the attack's 0.667 s (data/enemies/warden.tres, a starting value); the fists rise over its end.
const RECOVER_TICKS := 40
## The gait: the speed (m/s) a full stride is made at (the sim's 1.6 m/s), the share of a stride a foot or fist is
## down, its sweep either side of its stride's middle (m) and its lift (m); the cadence that keeps a planted foot still.
## A longer stride than STRIDE_MAX quickens the cadence instead.
const MOVE_SPEED := 1.6
const DUTY := 0.5
const SWEEP := 0.13
const LIFT := 0.075
const STRIDE_MAX := 1.4
const STEP_HZ := MOVE_SPEED * DUTY / (2.0 * SWEEP)
const TURN_REF := 2.0
const TURN_SWING := 0.18
## The limbs that step (the legs, then the arms on their knuckles; r is +Z) and each one's place in the stride.
const LIMBS: Array[StringName] = [&"leg_r", &"leg_l", &"arm_r", &"arm_l"]
const STRIDE_AT := [0.5, 0.0, 0.75, 0.25]
## The breath (Hz); reduced motion's share of the body's motion.
const BREATH_HZ := 0.35
const CALM := 0.45
## The joints' pivots (m, the model's frame) when the model is missing (the prep's), and the fists' knuckles at rest.
const PIVOTS := {
	&"body": Vector3.ZERO,
	&"head": Vector3(0.147, 0.686, 0.0),
	&"arm_r_u": Vector3(-0.025, 0.76, 0.429),
	&"arm_r_l": Vector3(0.037, 0.515, 0.466),
	&"arm_l_u": Vector3(-0.025, 0.76, -0.429),
	&"arm_l_l": Vector3(0.037, 0.515, -0.466),
	&"leg_r_u": Vector3(-0.086, 0.368, 0.221),
	&"leg_r_l": Vector3(-0.098, 0.184, 0.221),
	&"leg_r_f": Vector3(-0.074, 0.086, 0.221),
	&"leg_l_u": Vector3(-0.086, 0.368, -0.221),
	&"leg_l_l": Vector3(-0.098, 0.184, -0.221),
	&"leg_l_f": Vector3(-0.074, 0.086, -0.221),
}
const KNUCKLES := [Vector3(0.245, 0.098, 0.404), Vector3(0.245, 0.098, -0.404)]
## Where the fists stand from their place in the model (a little in toward the feet, so the arms keep some bend to
## reach forward with as they walk).
const FIST_IN := Vector3(-0.08, 0.0, 0.0)
## Where the fists land in the slam (m, the facing's frame: on the ground in front, a little in).
const SLAM_AT := [Vector3(0.62, 0.1, 0.33), Vector3(0.62, 0.1, -0.33)]
## The fists overhead: the shoulder's turn up, the elbow's bend, the roll in so they meet.
const ARM_UP := 2.5
const ELBOW_UP := 0.55
const ROLL_UP := 0.4
## The body's roll and pitch pivots (the pitch's at the hips).
const ROLL_AT := Vector3(0.0, 0.32, 0.0)
const PITCH_AT := Vector3(-0.09, 0.32, 0.0)
## The slam's dust ring's run (s from the impact; WardenDust draws it).
const DUST_SECONDS := WardenDust.SECONDS
## The slam's radius when no telegraph gave one (data/enemies/warden.tres, slam radius_m).
const SLAM_RADIUS := 2.4
## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]: the body's surge (m), roll, pitch (+ the chest back)
## and sway; the head's nod (+ up) and yaw; per arm (r, l) its yaw, roll, shoulder turn (+ forward and up) and elbow;
## per leg (r, l) its yaw, hip, knee and foot turns; then the eye's glow (no grid: sent as it is).
const SURGE := 0
const ROLL := 1
const PITCH := 2
const SWAY := 3
const HEAD_P := 4
const HEAD_Y := 5
const ARM0 := 6
const LEG0 := 14
const EYE := 22
const VAT_DRIVES := [
	[-0.15, 0.15, false],
	[-0.45, 0.45, false],
	[-0.75, 0.5, false],
	[-0.3, 0.3, false],
	[-0.6, 0.6, false],
	[-0.7, 0.7, false],
	[-1.0, 1.0, false],
	[-0.8, 0.8, false],
	[-1.6, 3.2, false],
	[-2.6, 2.6, false],
	[-1.0, 1.0, false],
	[-0.8, 0.8, false],
	[-1.6, 3.2, false],
	[-2.6, 2.6, false],
	[-0.8, 0.8, false],
	[-1.6, 1.6, false],
	[-2.4, 2.4, false],
	[-1.6, 1.6, false],
	[-0.8, 0.8, false],
	[-1.6, 1.6, false],
	[-2.4, 2.4, false],
	[-1.6, 1.6, false],
	[0.0, 0.0, false],
]
## Each drive's samples (a slide linear: exact on two; a turn finely).
const VAT_SAMPLES := [
	2, 37, 49, 25, 33, 33, 41, 33, 129, 97, 41, 33, 129, 97, 33, 65, 73, 49, 33, 65, 73, 49
]

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds only the dust ring.
var vat := false
var kind := KIND
## True when the body is the owner's model (else the code-made stand-in on the same joints).
var has_model := false
## The parts (tests): the rig's root (the body), the head, each arm's upper and lower node and each leg's upper,
## lower and foot node (r, l).
var rig: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var fists: Array[Node3D] = []
var legs: Array[Node3D] = []
var shins: Array[Node3D] = []
var feet: Array[Node3D] = []
## The impact's dust ring (hidden between slams).
var dust: WardenDust

var _vd := PackedFloat32Array()
var _lift := 0.0
var _eye_mat := StandardMaterial3D.new()
var _crack_mat := StandardMaterial3D.new()
var _crack := 1.8
var _pivots := PIVOTS.duplicate()
var _scale := 1.0
## The joint table: [drive, parent joint, frame node or null, make (SoloVat's)], a parent before its children.
var _joints: Array = []
# Each limb's end offset from its rest (m, the facing's frame) the clips ask for (LIMBS order); the limbs reach for it.
var _end: Array[Vector3] = []
# The state the pose is made from (sync and advance keep it; VatVerify.sample sets it).
var _state := WorldReader.STATE_MOVE
var _state_ticks := 0
var _windup := 0.0
var _hp := -1
var _speed := 0.0
var _dir := Vector2.RIGHT
var _omega := 0.0
var _phase := 0.0
var _stride := 0.0
var _raise := 0.0
var _slam := 0.0
var _rise := 1.0
var _shake := 0.0
var _hurt_t := -1.0
var _die_t := -1.0
var _last_fy := 0.0
var _have_fy := false
# The slam's radius (the telegraph's, read in the windup), and seconds since the impact (-1: no dust).
var _slam_r := SLAM_RADIUS
var _dust_t := -1.0


## Builds a Warden under `facing` for ActorViews (`views`: on VAT while its switch is on; `look`: the kind whose colours
## it wears, a biome version's) and marks `root`; returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D, look: int) -> float:
	var w := WardenAvatar.new()
	views._solo_vat(root, w, KIND)
	w.look_kind = look
	w.setup()
	facing.add_child(w)
	root.set_meta(&"enemy_avatar", w)
	root.set_meta(&"mats", w.body_materials.duplicate())
	return HEIGHT


func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	var eye := _look_color(KIND, &"eye")
	_eye_mat.albedo_color = eye
	_eye_mat.emission_enabled = true
	_eye_mat.emission = eye
	_eye_mat.emission_energy_multiplier = 2.4
	_eye_mat.set_meta(SoloVat.GLOW, EYE + 1)  # a VAT Warden's eye glows at its EYE drive
	_crack_mat.albedo_color = CRACK_COLOR
	_crack_mat.emission_enabled = true
	_crack_mat.emission = CRACK_COLOR
	_crack_mat.emission_energy_multiplier = _crack
	var m := EnemyModels.get_model(MODEL)
	has_model = not m.is_empty()
	if has_model:
		_scale = float(m["scale"])
		var parts_in: Dictionary = m["parts"]
		for pname: StringName in parts_in:
			_pivots[pname] = (parts_in[pname] as Dictionary)["pivot"] * _scale
	for k in LIMBS.size():
		_end.append(Vector3.ZERO)
	dust = WardenDust.new()
	add_child(dust)
	if vat:  # the crowd draws the body; the dust ring stays a node
		_pose()
		return
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	head = _node(rig, "Head")
	for side: String in ["r", "l"]:
		var up := _node(rig, "Arm_%s_u" % side)
		arms.append(up)
		fists.append(_node(up, "Arm_%s_l" % side))
		var thigh := _node(rig, "Leg_%s_u" % side)
		legs.append(thigh)
		var shin := _node(thigh, "Leg_%s_l" % side)
		shins.append(shin)
		feet.append(_node(shin, "Leg_%s_f" % side))
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


func _pivot(part: String) -> Vector3:
	return _pivots[StringName(part)]


## The frame node a part's mesh hangs in and that frame's own pivot (m).
func _frame_of(part: StringName) -> Array:
	var s := String(part)
	if part == &"head":
		return [head, _pivot("head")]
	var k := 0 if s.contains("_r_") else 1
	if s.begins_with("arm_"):
		return [arms[k] if s.ends_with("_u") else fists[k], _pivot(s)]
	if s.begins_with("leg_"):
		var nodes: Array[Node3D] = [legs[k], shins[k], feet[k]]
		return [nodes["ulf".find(s.right(1))], _pivot(s)]
	return [rig, Vector3.ZERO]


## The owner's model: each part's mesh in its joint's frame, its surfaces on the base / role plates (the bronze shell
## greyscale in the map, tinted in the role colour) and the glow (the eye on the head, the cracks on the body).
func _build_model(m: Dictionary) -> void:
	var tex: Texture2D = m["texture"]
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
		mi.scale = Vector3.ONE * _scale
		var surfaces: Array = part["surfaces"]
		var glow := _eye_mat if pname == &"head" else _crack_mat
		for k in surfaces.size():
			mi.set_surface_override_material(
				k, glow if surfaces[k] == &"glow" else mats.get(surfaces[k], mats[&"base"])
			)
		(f[0] as Node3D).add_child(mi)


## The code-made stand-in (the model file missing): boxes on the same joints, so every clip still plays.
func _build_code() -> void:
	var stone := Color("#3B383B")
	_piece(rig, Vector3(0.5, 0.5, 0.6), Vector3(-0.05, 0.6, 0), stone)
	_piece(rig, Vector3(0.7, 0.2, 0.7), Vector3(-0.08, 0.9, 0), _look_color(KIND, &"body"))
	_piece(head, Vector3(0.14, 0.16, 0.2), Vector3(0.06, 0, 0), stone)
	var eye := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(0.03, 0.04, 0.1)
	eye.mesh = em
	eye.material_override = _eye_mat
	eye.position = Vector3(0.13, 0.0, 0)
	head.add_child(eye)
	for k in 2:
		var s := "r" if k == 0 else "l"
		var el := _pivot("arm_%s_l" % s)
		var knuckles: Vector3 = KNUCKLES[k]
		_piece(arms[k], Vector3(0.3, 0.3, 0.26), Vector3.ZERO, stone)
		_piece(fists[k], Vector3(0.22, 0.22, 0.2), knuckles - el + Vector3(0, 0.08, 0), stone)
		_piece(fists[k], Vector3(0.14, 0.3, 0.14), (knuckles - el) * 0.5, stone)
		var hip := _pivot("leg_%s_u" % s)
		var knee := _pivot("leg_%s_l" % s)
		var ankle := _pivot("leg_%s_f" % s)
		_piece(legs[k], Vector3(0.16, 0.2, 0.16), (knee - hip) * 0.5, stone)
		_piece(shins[k], Vector3(0.14, 0.12, 0.14), (ankle - knee) * 0.5, stone)
		_piece(feet[k], Vector3(0.26, 0.08, 0.16), Vector3(0.06, -0.04, 0), stone)


func _piece(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _body_piece(parent, m, at, c)


## The joint table (see _joints): the body's surge, roll, pitch and sway (the rig); the head's nod at its neck and its
## yaw; per arm its yaw (about the vertical at the shoulder), roll, shoulder turn and elbow; per leg its yaw, hip, knee
## and foot (at the ankle).
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
		[HEAD_P, 3, null, SoloVat.turn(z, 1.0, SoloVat.at(_pivot("head")))],
		[HEAD_Y, 4, head, SoloVat.turn(Vector3.UP)],
	]
	for k in 2:
		var s := "r" if k == 0 else "l"
		var sh := _pivot("arm_%s_u" % s)
		var a := ARM0 + 4 * k
		_joints.append([a, 3, null, SoloVat.turn(Vector3.UP, 1.0, SoloVat.at(sh))])
		_joints.append([a + 1, _joints.size() - 1, null, SoloVat.turn(Vector3.RIGHT)])
		_joints.append([a + 2, _joints.size() - 1, arms[k], SoloVat.turn(z)])
		_joints.append(
			[
				a + 3,
				_joints.size() - 1,
				fists[k],
				SoloVat.turn(z, 1.0, SoloVat.at(_pivot("arm_%s_l" % s) - sh))
			]
		)
	for k in 2:
		var s := "r" if k == 0 else "l"
		var hip := _pivot("leg_%s_u" % s)
		var knee := _pivot("leg_%s_l" % s)
		var l := LEG0 + 4 * k
		_joints.append([l, 3, null, SoloVat.turn(Vector3.UP, 1.0, SoloVat.at(hip))])
		_joints.append([l + 1, _joints.size() - 1, legs[k], SoloVat.turn(z)])
		_joints.append(
			[l + 2, _joints.size() - 1, shins[k], SoloVat.turn(z, 1.0, SoloVat.at(knee - hip))]
		)
		_joints.append(
			[
				l + 3,
				_joints.size() - 1,
				feet[k],
				SoloVat.turn(z, 1.0, SoloVat.at(_pivot("leg_%s_f" % s) - knee))
			]
		)


# --- Sync ---------------------------------------------------------------------------------------------------------
func sync(reader: WorldReader, i: int) -> void:
	var tg := reader.telegraph(i)
	apply_state(
		{
			"tick": reader.tick(),
			"pos": reader.actor_pos(i),
			"state": reader.actor_state(i),
			"windup": float(tg.get("progress", 0)) / 1000.0,
			"radius": float(tg.get("radius", _slam_r)),
			"hp": reader.actor_hp(i),
		}
	)


## The same as sync(), from plain values (tests drive the avatar with this): tick, pos, state (a WorldReader
## STATE_*), windup (0..1, the telegraph's progress), radius (optional: the slam's), hp (optional).
func apply_state(s: Dictionary) -> void:
	_touch()
	var tick: int = s["tick"]
	var state: int = s["state"]
	var hp: int = s.get("hp", -1)
	var dt_ticks := tick - _last_tick
	if _fresh or state != _state:
		_state_ticks = 0
	elif dt_ticks > 0:
		_state_ticks += dt_ticks
	if not _fresh and hp >= 0 and _hp >= 0 and hp < _hp:
		_hurt_t = 0.0
	_track_motion(tick, s["pos"], TELEPORT_SPEED)
	_state = state
	_hp = hp
	_windup = clampf(s.get("windup", 0.0), 0.0, 1.0)
	if state == WorldReader.STATE_WINDUP and s.has("radius"):
		_slam_r = maxf(float(s["radius"]), 0.5)
	strike_note(state)  # The hit tick starts the slam's downswing
	if _fresh:
		_fresh = false
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_pose()


# --- Frame time ---------------------------------------------------------------------------------------------------
func advance(delta: float) -> void:
	_touch()
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0:
		return
	_t += dt
	var dying := _die_t >= 0.0
	var busy := maxf(_raise, _slam)
	var moving := _state == WorldReader.STATE_MOVE and not dying
	_speed = lerpf(_speed, _vel.length() if moving else 0.0, _rate(8.0 if moving else 12.0, dt))
	_turning(dt, dying)
	var local := Vector3(_vel.x, 0.0, -_vel.y).rotated(Vector3.UP, -_last_fy)
	if moving and local.length() > 0.2:
		var to := _dir.lerp(Vector2(local.x, local.z).normalized(), _rate(8.0, dt))
		_dir = to.normalized() if to.length() > 0.05 else _dir
	var most := maxf(_speed / MOVE_SPEED, absf(_omega) / TURN_REF) * (1.0 - busy)
	_stride = move_toward(_stride, minf(most, 1.0), dt * 4.0)
	_phase = fposmod(_phase + STEP_HZ * maxf(1.0, most / STRIDE_MAX) * dt * signf(_stride), 1.0)
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt / RISE_SECONDS)
	# Windup: the fists climb overhead by STRIKE_RAISE_BY of its progress and hold there, trembling.
	# The hit tick: they come down hard (strike_swing's snap). Recover: they stay on the ground, then rise back.
	var was_snapping := strike_snapping()
	strike_advance(dt)
	var winding := _state == WorldReader.STATE_WINDUP and not dying
	_raise = strike_raised(winding, _windup, move_toward(_raise, 0.0, dt * 5.0))
	var hold := 0.0
	if _state == WorldReader.STATE_RECOVER:
		hold = 1.0 - smoothstep(0.35, 1.0, float(_state_ticks) / RECOVER_TICKS)
	var swing := strike_swing()
	if strike_snapping():
		_slam = maxf(swing, _slam)
	elif swing > 0.0 or hold > 0.0:
		_slam = maxf(swing, hold)
	else:
		_slam = lerpf(_slam, 0.0, _rate(5.0, dt))
	if was_snapping and not strike_snapping():
		_shake = 1.0  # the impact
		_dust_t = 0.0
	_shake = move_toward(_shake, 0.0, dt * 4.0)
	_hurt_t = _clip(_hurt_t, dt, HURT_SECONDS)
	if dying:
		_die_t += dt
	_advance_dust(dt)
	_pose()


static func _clip(t: float, dt: float, length: float) -> float:
	if t < 0.0:
		return t
	t += dt
	return t if t < length else -1.0


## The facing's turn rate (rad/s), from the facing node the sim's facing turns (ActorViews).
func _turning(dt: float, dying: bool) -> void:
	var fy := (get_parent() as Node3D).rotation.y if get_parent() is Node3D else 0.0
	var w := 0.0
	if _have_fy and not dying:
		w = clampf(wrapf(fy - _last_fy, -PI, PI) / dt, -6.0, 6.0)
	_omega = lerpf(_omega, w, _rate(10.0, dt))
	_last_fy = fy
	_have_fy = true


## Starts the death (ActorViews, when the sim drops the Warden: freed DEATH_SECONDS later). True: it plays.
func die() -> bool:
	_touch()
	if _die_t < 0.0:
		_die_t = 0.0
	return true


func dying() -> bool:
	_peek()
	return _die_t >= 0.0


## 0..1: how far the fists are raised overhead (the windup pose) and slammed down (the attack and its recovery).
func raise_amount() -> float:
	_peek()
	return _raise


func slam_amount() -> float:
	_peek()
	return _slam


## 0..1 how deep the windup crouch is (from the windup's progress).
func crouch_amount() -> float:
	_peek()
	return _crouch()


func _crouch() -> float:
	if _state != WorldReader.STATE_WINDUP or _die_t >= 0.0:
		return 0.0
	return tell_crouch(_windup)


## The eye's glow (emission energy; the cracks': glow_energy).
func visor_energy() -> float:
	_peek()
	return _vd[EYE]


## The raw drives now (tests).
func drives() -> PackedFloat32Array:
	_peek()
	return _vd


## Where a limb's point stands now (m, the facing's frame; tests): `part` &"fist" (the knuckles), &"knee" or
## &"ankle", of side `k` (0 the right, 1 the left), through its chain from the drives.
func limb_at(part: StringName, k: int) -> Vector3:
	_peek()
	var s := "r" if k == 0 else "l"
	var body := _body_xf(_vd)
	if part == &"fist":
		var sh := _pivot("arm_%s_u" % s)
		var el := _pivot("arm_%s_l" % s)
		var a := ARM0 + 4 * k
		var turn := (
			Basis(Vector3.UP, _vd[a])
			* Basis(Vector3.RIGHT, _vd[a + 1])
			* Basis(Vector3.BACK, _vd[a + 2])
		)
		var elbow := (
			body * Transform3D(turn, sh) * Transform3D(Basis(Vector3.BACK, _vd[a + 3]), el - sh)
		)
		return elbow * (KNUCKLES[k] * _scale - el)
	var hip := _pivot("leg_%s_u" % s)
	var knee := _pivot("leg_%s_l" % s)
	var l := LEG0 + 4 * k
	var turn := Basis(Vector3.UP, _vd[l]) * Basis(Vector3.BACK, _vd[l + 1])
	var at_knee := (
		body * Transform3D(turn, hip) * Transform3D(Basis(Vector3.BACK, _vd[l + 2]), knee - hip)
	)
	return at_knee * (_pivot("leg_%s_f" % s) - knee if part == &"ankle" else Vector3.ZERO)


# --- The pose -----------------------------------------------------------------------------------------------------
## The pose's numbers from the state (_vd, the lift, the glows): the clips' body drives and the limb ends' places
## first, then the limbs reach for them under that body (the arms blended toward their raised pose); then (the code
## path) the nodes from them.
func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var k := CALM if calm else 1.0
	var d := PackedFloat32Array()
	d.resize(VAT_DRIVES.size())
	for j in LIMBS.size():
		_end[j] = Vector3.ZERO
	var breath := sin(TAU * _t * BREATH_HZ)
	var lift := _walk_pose(d, k)
	lift += _idle_pose(d, k, calm, breath)
	lift += _tell_pose(d, k, calm)
	lift += _slam_pose(d, k, calm)
	lift += _hurt_pose(d, k)
	lift += _rise_pose(d)
	lift = _death_pose(d, lift, calm)
	for j in ARM0:
		d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	_lift = lift
	_reach_all(d)
	for j in range(ARM0, EYE):
		d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	d[EYE] = _eye(calm)
	_crack = _crack_energy(calm)
	_vd = d
	_eye_mat.emission_energy_multiplier = d[EYE]
	_crack_mat.emission_energy_multiplier = _crack
	if not vat and rig != null:
		_apply()


## The rig's transform (the body's: the lift, the surge, the roll, the pitch and the sway) from the drives `d`.
func _body_xf(d: PackedFloat32Array) -> Transform3D:
	return (
		Transform3D(Basis.IDENTITY, Vector3(d[SURGE], _lift, 0.0))
		* SoloVat.at(ROLL_AT)
		* Transform3D(Basis(Vector3.RIGHT, d[ROLL]), Vector3.ZERO)
		* SoloVat.at(-ROLL_AT)
		* SoloVat.at(PITCH_AT)
		* Transform3D(Basis(Vector3.BACK, d[PITCH]), Vector3.ZERO)
		* SoloVat.at(-PITCH_AT)
		* Transform3D(Basis(Vector3.UP, d[SWAY]), Vector3.ZERO)
	)


## The limbs reach for their ends: each leg's ankle (its foot then turned back flat, tipping its toe down as it
## swings) and each arm's knuckles (toward the slam's spot as it slams), the arms then blended toward the raised pose.
func _reach_all(d: PackedFloat32Array) -> void:
	var inv := _body_xf(d).affine_inverse()
	for k in 2:
		var s := "r" if k == 0 else "l"
		var ankle := _pivot("leg_%s_f" % s)
		var r := _reach(
			_pivot("leg_%s_u" % s), _pivot("leg_%s_l" % s), ankle, inv * (ankle + _end[k])
		)
		var l := LEG0 + 4 * k
		d[l] = r.x
		d[l + 1] = r.y
		d[l + 2] = r.z
		var swing := clampf(_end[k].y / LIFT, 0.0, 1.0)
		d[l + 3] = -(r.y + r.z) - d[PITCH] - 0.35 * swing
	var up := smoothstep(0.0, 1.0, _raise)
	for k in 2:
		var s := "r" if k == 0 else "l"
		var rest: Vector3 = KNUCKLES[k] * _scale
		var aim: Vector3 = (rest + FIST_IN + _end[2 + k]).lerp(
			SLAM_AT[k], smoothstep(0.0, 1.0, _slam)
		)
		var r := _reach(_pivot("arm_%s_u" % s), _pivot("arm_%s_l" % s), rest, inv * aim)
		var a := ARM0 + 4 * k
		var side := 1.0 if k == 0 else -1.0
		d[a] = lerpf(r.x, 0.0, up)
		d[a + 1] = lerpf(0.0, -side * ROLL_UP, up)
		d[a + 2] = lerpf(r.y, ARM_UP, up)
		d[a + 3] = lerpf(r.z, ELBOW_UP, up)


## A two-bone limb (root, joint and end at rest, the body's frame) reaching for `target`: (the yaw about the vertical
## at the root that brings the target to the rest's distance across the limb's plane, the root's and the joint's turns
## about +Z in that plane). Past its reach the end stops short.
static func _reach(root: Vector3, mid: Vector3, end: Vector3, target: Vector3) -> Vector3:
	var v := target - root
	var r0 := end - root
	var across := acos(clampf(r0.z / maxf(Vector2(v.x, v.z).length(), 0.0001), -1.0, 1.0))
	var toward := atan2(v.x, v.z)
	var y1 := wrapf(toward - across, -PI, PI)
	var y2 := wrapf(toward + across, -PI, PI)
	var yaw := y1 if absf(y1) < absf(y2) else y2
	var t := v.rotated(Vector3.UP, -yaw)
	var aim := Vector2(t.x, t.y)
	var u0 := Vector2(mid.x - root.x, mid.y - root.y)
	var l0 := Vector2(end.x - mid.x, end.y - mid.y)
	var a := u0.length()
	var b := l0.length()
	var rch := clampf(aim.length(), absf(a - b) + 0.002, (a + b) * 0.998)
	var bend := signf(Vector2(r0.x, r0.y).cross(u0))
	var off := acos(clampf((a * a + rch * rch - b * b) / (2.0 * a * rch), -1.0, 1.0))
	var root_turn := wrapf(aim.angle() + bend * off - u0.angle(), -PI, PI)
	var l1 := aim.normalized() * rch - u0.rotated(root_turn)
	return Vector3(yaw, root_turn, wrapf(l1.angle() - l0.angle() - root_turn, -PI, PI))


## The walk (and the turn's stepping): each foot and fist through its stride at its place in the four beats, along
## the way the body goes, the turn sweeping it round; the body thumping down as each foot lands, rolling onto it,
## swaying, leaning into the walk, the head holding its line. Returns its lift.
func _walk_pose(d: PackedFloat32Array, k: float) -> float:
	var g := clampf(_stride, 0.0, 1.0)
	var walk := clampf(_speed / MOVE_SPEED, 0.0, STRIDE_MAX)
	var turn := clampf(_omega / TURN_REF, -1.0, 1.0)
	var dir := Vector3(_dir.x, 0.0, _dir.y)
	for j in LIMBS.size():
		var c := _leg_cycle(fposmod(_phase - float(STRIDE_AT[j]), 1.0))
		var rest := _limb_rest(j)
		var th := turn * TURN_SWING * c.x
		_end[j] += dir * (walk * SWEEP * c.x) + Vector3(th * rest.z, LIFT * g * c.y, -th * rest.x)
	if g <= 0.0:
		return 0.0
	var p := _phase
	var w := minf(walk, 1.0)
	# The left foot lands at 0 and the right at 0.5: the body thumps down after each and rolls onto it.
	var thump := _thump(p) + _thump(p - 0.5)
	d[ROLL] += g * k * 0.045 * sin(TAU * (p - 0.12))
	d[SWAY] += w * k * 0.07 * sin(TAU * (p + 0.1))
	d[PITCH] -= w * 0.07 + w * k * 0.02 * sin(2.0 * TAU * p)
	d[HEAD_Y] -= w * k * 0.06 * sin(TAU * (p + 0.1))
	d[HEAD_P] += w * k * 0.04 * cos(2.0 * TAU * (p - 0.1))
	return -0.05 * w - g * k * 0.03 * thump


## A foot's landing at stride phase p (0 its touchdown): a sharp dip, then a slow rise.
static func _thump(p: float) -> float:
	var q := fposmod(p, 1.0)
	if q < 0.06:
		return sin(PI * 0.5 * q / 0.06)
	return exp(-(q - 0.06) * 10.0) if q < 0.5 else 0.0


## Limb `j`'s end at rest (m, the facing's frame): the ankle or the knuckles.
func _limb_rest(j: int) -> Vector3:
	if j < 2:
		return _pivot("leg_%s_f" % ("r" if j == 0 else "l"))
	return KNUCKLES[j - 2] * _scale + FIST_IN


## One foot or fist through its stride at q (0 its touchdown): (the sweep: 1 ahead .. -1 behind; the lift 0..1).
static func _leg_cycle(q: float) -> Vector2:
	if q < DUTY:
		return Vector2(1.0 - 2.0 * q / DUTY, 0.0)
	var w := (q - DUTY) / (1.0 - DUTY)
	var up := sin(PI * w)
	return Vector2(-1.0 + 2.0 * smoothstep(0.0, 1.0, w), up * up * (3.0 - 2.0 * up))


## Idle (fading as it walks, winds up, slams or dies): heavy breathing, the head's held glances, the weight shifting
## from foot to foot, a fist re-planted now and then. Returns its lift.
func _idle_pose(d: PackedFloat32Array, k: float, calm: bool, breath: float) -> float:
	var busy := maxf(_raise, _slam)
	var alive := 1.0 if _die_t < 0.0 else 0.0
	var idle := (1.0 - clampf(_stride, 0.0, 1.0)) * (1.0 - busy) * alive
	if idle <= 0.0:
		return 0.0
	d[PITCH] += idle * k * 0.025 * breath
	d[HEAD_P] += idle * k * (0.06 * _scan(_t, 3.7, 5.0) + 0.02 * breath)
	d[HEAD_Y] += idle * k * 0.3 * _scan(_t, 2.9, 0.0)
	d[ROLL] += idle * k * 0.035 * sin(0.55 * _t)
	d[SWAY] += idle * k * 0.04 * sin(0.37 * _t + 0.6)
	d[SURGE] += idle * k * 0.01 * sin(0.55 * _t + 1.4)
	if not calm:  # a fist re-planted now and then (a different one each time): lifted, set down a little on
		var u := _t / 3.4
		var seg := floorf(u)
		if _hash(seg + 5.0) > 0.35:
			var j := 2 + int(_hash(seg + 9.0) * 2.0) % 2
			var e := sin(PI * clampf((u - seg - 0.25) / 0.18, 0.0, 1.0))
			_end[j] += Vector3(0.03, 0.09, 0.0) * e * idle
	return idle * k * 0.012 * breath


## The tell (WINDUP): the fists climb overhead (_raise, held: the arms' blend in _reach_all), the chest heaves back,
## the knees bend into a crouch that deepens with the windup's progress, the head tips up; a tremble at the top.
## Returns its lift.
func _tell_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	var r := _raise
	var c := _crouch()
	if r <= 0.0 and c <= 0.0:
		return 0.0
	d[PITCH] += 0.26 * r * k
	d[SURGE] -= 0.05 * r * k
	d[HEAD_P] += 0.3 * r * k
	d[HEAD_Y] *= 1.0 - r
	if not calm and _state == WorldReader.STATE_WINDUP:
		var top := r * smoothstep(0.6, 1.0, _windup)
		d[SURGE] += 0.012 * top * sin(_t * 47.0)
		d[ROLL] += 0.015 * top * sin(_t * 39.0)
	return -0.02 * r - 0.07 * c


## The slam (_slam: the downswing's snap, held through the first of the recovery): the chest pitches forward, the
## knees drop, the fists on the ground in front (their spot in _reach_all); the impact's shake. Returns its lift.
func _slam_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	var s := _slam
	if s <= 0.0 and _shake <= 0.0:
		return 0.0
	d[PITCH] -= 0.5 * s + 0.06 * _shake * k
	d[SURGE] += 0.06 * s
	d[HEAD_P] -= 0.15 * s
	d[HEAD_Y] *= 1.0 - s
	var lift := -0.08 * s
	if not calm and _shake > 0.0:
		lift += 0.02 * _shake * sin(_t * 60.0)
		d[ROLL] += 0.03 * _shake * sin(_t * 53.0)
	return lift


## A hit (its HP fell): the body jolts back, the head ducks. Returns its lift.
func _hurt_pose(d: PackedFloat32Array, k: float) -> float:
	if _hurt_t < 0.0:
		return 0.0
	var h := _hurt_t / HURT_SECONDS
	var e := sin(PI * 0.5 * minf(h / 0.25, 1.0)) * (1.0 - smoothstep(0.25, 1.0, h))
	d[SURGE] -= 0.05 * e * k
	d[PITCH] += 0.08 * e * k
	d[HEAD_P] -= 0.2 * e * k
	d[ROLL] += 0.04 * e * k
	return -0.02 * e * k


## The rise-in: climbing out of the ground, leaning back, the fists reaching up. Returns its lift.
func _rise_pose(d: PackedFloat32Array) -> float:
	var sink := 1.0 - _rise
	if sink <= 0.0:
		return 0.0
	sink = sink * sink * (3.0 - 2.0 * sink)
	d[PITCH] += 0.25 * sink
	d[HEAD_P] += 0.2 * sink
	for j in [2, 3]:
		_end[j] += Vector3(0.05, 0.25, 0.0) * sink
	return -1.35 * sink


## The death: the knees buckle and it drops, falls forward onto its fists (sliding out ahead) and then its chest,
## tipping to one side, the head drooping. Returns the lift.
func _death_pose(d: PackedFloat32Array, lift: float, calm: bool) -> float:
	if _die_t < 0.0:
		return lift
	var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
	var keep := 1.0 - smoothstep(0.0, 0.2, u)
	for j in [SURGE, ROLL, PITCH, SWAY, HEAD_Y]:
		d[j] *= keep
	lift *= keep
	var buckle := smoothstep(0.05, 0.4, u)
	var fall := smoothstep(0.35, 0.8, u)
	for j in LIMBS.size():
		_end[j] *= keep
	for j in [2, 3]:  # the fists slide out ahead as it falls on them
		_end[j] += Vector3(0.22, 0.0, 0.0) * fall
	d[PITCH] -= 0.3 * buckle + 0.32 * fall
	d[SURGE] += 0.1 * fall
	d[ROLL] += 0.3 * fall
	d[HEAD_P] = lerpf(d[HEAD_P], -0.45, buckle)
	if not calm:
		d[ROLL] += 0.02 * buckle * (1.0 - fall) * sin(_die_t * 30.0)
	return lift - 0.14 * buckle - 0.12 * fall


## The eye's glow: rest; through the windup climbing and flashing (tell_glow: steady with reduced motion); flaring at
## the impact; dim while it rises in; flickering out in the death.
func _eye(calm: bool) -> float:
	var winding := _state == WorldReader.STATE_WINDUP and _die_t < 0.0
	var tell := tell_glow(_windup, _t, calm) if winding else 1.0
	var e := ((2.4 + 4.0 * _raise) * tell + 2.0 * _shake) * lerpf(0.3, 1.0, _rise)
	if _die_t >= 0.0:
		var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
		var flicker := 1.0 if calm else 0.6 + 0.4 * absf(sin(_die_t * 23.0))
		e = lerpf(e * flicker, 0.0, smoothstep(0.1, 0.7, u))
	return e


## The cracks' glow: breathing at rest (steady with reduced motion), hotter as the fists rise and at the impact;
## flaring once as it dies, then going out.
func _crack_energy(calm: bool) -> float:
	var e := 1.8 + (0.0 if calm else 0.5 * sin(_t * 3.4)) + 1.5 * _raise + 1.5 * _shake
	if _die_t >= 0.0:
		var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
		e += 3.0 * sin(PI * clampf(u / 0.3, 0.0, 1.0))
		e = lerpf(e, 0.0, smoothstep(0.35, 0.9, u))
	return e


## A held glance: a pseudo-random value in -1..1 per `every` s that holds, then moves quickly to the next.
static func _scan(t: float, every: float, seed_off: float) -> float:
	var u := t / every + seed_off
	var seg := floorf(u)
	var a := _hash(seg) * 2.0 - 1.0
	var b := _hash(seg + 1.0) * 2.0 - 1.0
	return lerpf(a, b, smoothstep(0.55, 0.9, u - seg))


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
## The whole body's lift (m): VatCrowd moves the instance by it (the dust ring is its own node).
func vat_lift() -> float:
	_peek()
	return _lift


func vat_drives() -> PackedFloat32Array:
	_peek()
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The cracks' glow (the instance's accent glow; the eye's is the EYE drive).
func glow_energy() -> float:
	_peek()
	return _crack


## The owner's colour map (VatLooks' textured variant), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## One grid per drive but the eye's, the joints as the table.
func vat_rig() -> Dictionary:
	var grids: Array = []
	for d in VAT_SAMPLES.size():
		grids.append([[d, VAT_SAMPLES[d]]])
	var out := SoloVat.rig("warden", VAT_DRIVES, grids, _joints, true)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out


# --- The slam's dust ring ---------------------------------------------------------------------------------------
## 0..1 how far the impact's dust ring has run (-1: none showing).
func dust_amount() -> float:
	_peek()
	return clampf(_dust_t / DUST_SECONDS, 0.0, 1.0) if _dust_t >= 0.0 else -1.0


## The slam's radius the dust ring runs out to (the telegraph's).
func slam_radius() -> float:
	_peek()
	return _slam_r


## The ring's clock (seconds since the impact; -1 once it has run), then the ring shown at it.
func _advance_dust(dt: float) -> void:
	if _dust_t >= 0.0:
		_dust_t += dt
		if _dust_t / DUST_SECONDS >= 1.0:
			_dust_t = -1.0
	dust.show_at(_dust_t, _slam_r)
