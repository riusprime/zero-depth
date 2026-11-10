class_name ScrapHoundAvatar
extends AvatarBase
## v0.11.0 O17a (ENEMIES.md R2; owner 2026-11-08: "make sure they are animated as good as you can, if they can have
## multiple animations ... the better"): the Scrap Hound on the owner's model (EnemyModels &"scrap_hound", cut by
## scripts/assets/o17_prep_scrap_hound.py into the chest, the hips, the head, the tail and each leg's upper and lower
## half), animated in code from the sim's state and drawn by the VAT crowd (SoloVat) while the switch is on.
## Its clips, each read from the sim through WorldReader (sync) and played in frame time (advance):
## - idle: panting (the chest and head bob at PANT_HZ), the head scanning in held glances with a curious tilt, the
##   tail wagging with a flick now and then, the weight shifting;
## - the gait: a diagonal trot that blends into a rotary gallop with speed (GALLOP_FROM..GALLOP_FULL m/s): the stride
##   rate follows the speed, the legs sweep through their stance and fold through their swing (the hocks and wrists
##   tuck), the spine gathers and stretches, the body rocks and bounds, the head counters the rock, the tail streams.
##   While it circles (the sim turns its facing to the hero, it runs sideways) the body turns to the way it runs (the
##   avatar node's own yaw: its shadow turns with it), banks into the curve, its hips swing out and its head stays on
##   the hero;
## - the tell (WINDUP, the sim's own progress): the body snaps round to the hero, sinks low with its weight back over
##   coiled hind legs, the head drops to aim, the tail stiffens and quivers, the visor climbs and flashes from
##   TELL_FLASH_FROM (AvatarBase's tell: steady with reduced motion);
## - the dart (ACTIVE): a stretched leap, front legs reaching, hind legs driving back, the spine at full stretch;
## - the bite (the dart's end, RECOVER): a snap of the head and a shake, the front legs braced in a skid stop, then
##   heavy panting;
## - the yelp (a hit stopped it: RECOVER, WorldReader.hound_yelped): the head flung up, a skid, a hop back with its
##   legs tucked, the tail tucked under, a cower, then it settles (YELP_SECONDS, the sim's stagger);
## - a hit flinch (any other hit: its HP fell): the head jerks, the tail dips (with AvatarBase's flinch);
## - the rise-in (SPAWN) and the death (die(): a stumble on buckling front legs, a roll onto its side, the legs
##   folding, a last twitch, the visor going out, DEATH_SECONDS);
## - reduced motion (ViewPrefs.reduced_motion): the same clips at CALM of the body's and head's amplitudes, no shakes,
##   shivers or twitches, the flash steady.
## The pose is a few plain numbers (the raw drives, _vd: each joint's turn) worked out from the state first, then the
## nodes from them through the joint table (_joints, the same transforms the VAT rig declares), so the baked pose is
## the live one. Presentation only (EI-07): nothing here reaches the sim. +X is the front.

const KIND := WorldReader.KIND_SCRAP_HOUND
const MODEL := &"scrap_hound"
const HEIGHT := 0.75
## The role colour (the shell's plates) and the visor's glow (emission energy) at rest and at the tell's peak.
const COLOR := Color("#C93A1E")
const VISOR_COLOR := Color("#FF5030")
const VISOR_REST := 1.6
const VISOR_TELL := 7.0
const TELEPORT_SPEED := 30.0
## The clips' lengths (s): the yelp (the sim's stagger, data/enemies/scrap_hound.tres stagger_seconds), the bite and
## the recovery after it (the attack's recovery_seconds), a plain hit's flinch, the death.
const YELP_SECONDS := 0.8
const BITE_SECONDS := 0.6
const HURT_SECONDS := 0.3
const DEATH_SECONDS := 1.0
## The gait: the trot blends into the gallop between these speeds (m/s); the stride rate (Hz) at speed v is
## TROT_HZ + TROT_HZ_PER * v, GALLOP_HZ + GALLOP_HZ_PER * v; the legs' swing (radians) and the knees' fold.
const GALLOP_FROM := 2.6
const GALLOP_FULL := 4.4
const TROT_HZ := 1.3
const TROT_HZ_PER := 0.42
const GALLOP_HZ := 2.3
const GALLOP_HZ_PER := 0.17
const TROT_SWING := 0.38
const TROT_FOLD := 0.6
const GALLOP_SWING := Vector2(0.62, 0.55)  # front, hind
const GALLOP_FOLD := Vector2(1.1, 0.9)
const TROT_DUTY := 0.5
const GALLOP_DUTY := 0.36
## Each leg's touchdown in the stride (0..1): the trot's diagonal pairs, the rotary gallop's hind left, hind right,
## front right, front left. Legs in LEGS order.
const LEGS: Array[StringName] = [&"fr", &"fl", &"hr", &"hl"]
const TROT_DOWN := [0.0, 0.5, 0.5, 0.0]
const GALLOP_DOWN := [0.42, 0.5, 0.08, 0.0]
## The model stands mid-stride: each upper leg's turn that stands it square (the far hind leg is ahead of the near).
const REST_U := [0.0, 0.0, 0.12, -0.12]
## The bank (radians) at full lean, the turn rate x speed that gives it, the yaw's ease (per second) while it runs and
## while it turns in; the idle's pant rate (Hz); reduced motion's share of the body's and head's motion.
const LEAN_MAX := 0.24
const BANK_K := 0.09
const YAW_RATE := 9.0
const YAW_RATE_TELL := 16.0
const PANT_HZ := 2.4
const CALM := 0.45
## The joints' pivots (m, the model's frame) when the model is missing (the code-made body's).
const PIVOTS := {
	&"body_f": Vector3(0.033, 0.57, 0.0),
	&"body_r": Vector3(0.033, 0.57, 0.0),
	&"head": Vector3(0.318, 0.504, 0.0),
	&"tail": Vector3(-0.318, 0.499, 0.0),
	&"leg_fr_u": Vector3(0.219, 0.394, 0.115),
	&"leg_fr_l": Vector3(0.25, 0.197, 0.148),
	&"leg_fl_u": Vector3(0.241, 0.394, -0.115),
	&"leg_fl_l": Vector3(0.283, 0.208, -0.159),
	&"leg_hr_u": Vector3(-0.099, 0.46, 0.115),
	&"leg_hr_l": Vector3(-0.022, 0.301, 0.142),
	&"leg_hl_u": Vector3(-0.077, 0.46, -0.115),
	&"leg_hl_l": Vector3(-0.011, 0.312, -0.153),
}
## The whole body's pitch pivot (m).
const PITCH_AT := Vector3(0.0, 0.3, 0.0)
## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]: the body's roll (the bank, the death's roll) and
## pitch, its slide along its length, the hips' pitch and yaw against the chest (the spine), the head's pitch, yaw and
## roll, the tail's pitch and yaw, each leg's upper and lower turn (LEGS order). A pitch's plus is up (the nose, the
## head, the tail), the spine's tucks the hips under, a roll's tips the top to the right (+Z), a leg's swings it
## forward (a lower leg's: unfolds it).
const ROLL := 0
const PITCH := 1
const SHIFT := 2
const SPINE := 3
const SPINE_Y := 4
const HEAD_P := 5
const HEAD_Y := 6
const HEAD_R := 7
const TAIL_P := 8
const TAIL_Y := 9
const LEG0 := 10
const VAT_DRIVES := [
	[-1.7, 0.5, false],
	[-0.5, 0.5, false],
	[-0.3, 0.3, false],
	[-0.45, 0.45, false],
	[-0.45, 0.45, false],
	[-0.8, 0.8, false],
	[-0.9, 0.9, false],
	[-0.5, 0.5, false],
	[-1.0, 0.8, false],
	[-0.9, 0.9, false],
	[-1.4, 1.4, false],
	[-1.8, 1.0, false],
	[-1.4, 1.4, false],
	[-1.8, 1.0, false],
	[-1.4, 1.4, false],
	[-1.8, 1.0, false],
	[-1.4, 1.4, false],
	[-1.8, 1.0, false],
]
const VAT_SAMPLES := [57, 33, 2, 33, 33, 41, 45, 33, 45, 45, 71, 71, 71, 71, 71, 71, 71, 71]

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds no nodes.
var vat := false
var kind := KIND
var height := HEIGHT
## True when the body is the owner's model (else the code-made stand-in on the same joints).
var has_model := false
## The parts (tests): the rig's root, the hips, the head, the tail, each leg's upper and lower node (LEGS order).
var rig: Node3D
var hips: Node3D
var head: Node3D
var tail: Node3D
var uppers: Array[Node3D] = []
var lowers: Array[Node3D] = []

var _vd := PackedFloat32Array()
var _lift := 0.0
var _glow := VISOR_REST
var _visor_mat := StandardMaterial3D.new()
var _pivots := PIVOTS.duplicate()
## The joint table: [drive, parent joint, frame node or null, make (SoloVat's)], a parent before its children.
var _joints: Array = []
# The state the pose is made from (sync and advance keep it; vat_sample sets it).
var _state := WorldReader.STATE_SPAWN
var _tell := 0.0
var _hp := -1
var _speed := 0.0
var _gallop := 0.0
var _phase := 0.0
var _yaw := 0.0
var _turn := 0.0
var _bank := 0.0
var _last_h := 0.0
var _have_h := false
var _coil := 0.0
var _dart := 0.0
var _rise := 0.0
var _bite_t := -1.0
var _yelp_t := -1.0
var _hurt_t := -1.0
var _die_t := -1.0


## Builds a hound under `facing` for ActorViews (`views`: on VAT while its switch is on) and marks `root` (the avatar,
## its body materials for the hit flash); returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D) -> float:
	var hound := ScrapHoundAvatar.new()
	views._solo_vat(root, hound, KIND)
	hound.setup()
	facing.add_child(hound)
	root.set_meta(&"enemy_avatar", hound)
	root.set_meta(&"mats", hound.body_materials.duplicate())
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
	if vat:  # the crowd draws the body
		_pose()
		return
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	hips = _node(rig, "Hips")
	head = _node(rig, "Head")
	tail = _node(hips, "Tail")
	for k in LEGS.size():
		var up := _node(hips if k >= 2 else rig, "Leg_%s_u" % LEGS[k])
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
	var fixed := {
		&"body_f": [rig, Vector3.ZERO],
		&"body_r": [hips, _pivots[&"body_r"]],
		&"head": [head, _pivots[&"head"]],
		&"tail": [tail, _pivots[&"tail"]],
	}
	if fixed.has(part):
		return fixed[part]
	var s := String(part)
	var k := LEGS.find(StringName(s.substr(4, 2)))
	if k < 0:
		return [rig, Vector3.ZERO]
	return [uppers[k] if s.ends_with("_u") else lowers[k], _pivots[part]]


## The owner's model: each part's mesh in its joint's frame, its surfaces on the base / role plates (the role plates
## greyscale in the map, tinted COLOR) and the visor (glow).
func _build_model(m: Dictionary) -> void:
	var tex: Texture2D = m["texture"]
	var s: float = m["scale"]
	var parts_in: Dictionary = m["parts"]
	for pname: StringName in parts_in:
		_pivots[pname] = (parts_in[pname] as Dictionary)["pivot"] * s
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


## The code-made stand-in (the model file missing): boxes and rods on the same joints, so every clip still plays.
func _build_code() -> void:
	var charcoal := Color("#24272D")
	var grey := Color("#8A817C")
	var spine: Vector3 = _pivots[&"body_f"]
	_piece(rig, Vector3(0.36, 0.2, 0.24), Vector3(0.15, 0.4, 0), charcoal)
	_piece(rig, Vector3(0.36, 0.12, 0.28), Vector3(0.15, 0.55, 0), COLOR)
	_piece(hips, Vector3(0.36, 0.18, 0.22), Vector3(-0.18, 0.42, 0) - spine, charcoal)
	_piece(hips, Vector3(0.36, 0.1, 0.26), Vector3(-0.18, 0.54, 0) - spine, COLOR)
	var neck: Vector3 = _pivots[&"head"]
	_piece(head, Vector3(0.22, 0.16, 0.16), Vector3(0.42, 0.36, 0) - neck, charcoal)
	var visor := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.03, 0.06, 0.1)
	visor.mesh = vm
	visor.material_override = _visor_mat
	visor.position = Vector3(0.535, 0.38, 0) - neck
	head.add_child(visor)
	_piece(tail, Vector3(0.24, 0.05, 0.05), Vector3(-0.12, 0, 0), grey)
	var toes := [
		Vector3(0.5, 0.02, 0.18),
		Vector3(0.52, 0.02, -0.18),
		Vector3(-0.19, 0.02, 0.2),
		Vector3(-0.05, 0.02, -0.2)
	]
	for k in LEGS.size():
		var hip: Vector3 = _pivots[StringName("leg_%s_u" % LEGS[k])]
		var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
		_rod(uppers[k], Vector3.ZERO, knee - hip, grey)
		_rod(lowers[k], Vector3.ZERO, (toes[k] as Vector3) - knee, grey)


func _piece(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _body_piece(parent, m, at, c)


func _rod(parent: Node3D, from: Vector3, to: Vector3, c: Color) -> void:
	var piece := _piece(parent, Vector3(0.05, (to - from).length(), 0.05), (from + to) * 0.5, c)
	piece.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))


## The joint table (see _joints): the body's roll, pitch and slide (the rig), the head's pitch, yaw and roll at the
## neck, the hips' pitch and yaw at the spine, the tail's pitch and yaw at its root, each leg's upper turn at its hip
## or shoulder and lower turn at its knee or elbow (front legs on the chest, hind legs on the hips).
func _build_joints() -> void:
	var z := Vector3.BACK
	var spine: Vector3 = _pivots[&"body_r"]
	_joints = [
		[ROLL, -1, null, SoloVat.turn(Vector3.RIGHT)],
		[PITCH, 0, null, SoloVat.turn(z, 1.0, SoloVat.at(PITCH_AT), SoloVat.at(-PITCH_AT))],
		[SHIFT, 1, rig, SoloVat.slide(Vector3.RIGHT)],
		[HEAD_P, 2, null, SoloVat.turn(z, 1.0, SoloVat.at(_pivots[&"head"]))],
		[HEAD_Y, 3, null, SoloVat.turn(Vector3.UP)],
		[HEAD_R, 4, head, SoloVat.turn(Vector3.RIGHT)],
		[SPINE, 2, null, SoloVat.turn(z, 1.0, SoloVat.at(spine))],
		[SPINE_Y, 6, hips, SoloVat.turn(Vector3.UP)],
		[TAIL_P, 7, null, SoloVat.turn(z, -1.0, SoloVat.at(_pivots[&"tail"] - spine))],
		[TAIL_Y, 8, tail, SoloVat.turn(Vector3.UP)],
	]
	for k in LEGS.size():
		var hip: Vector3 = _pivots[StringName("leg_%s_u" % LEGS[k])]
		var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
		var on_hips := k >= 2
		_joints.append(
			[
				LEG0 + 2 * k,
				7 if on_hips else 2,
				uppers[k],
				SoloVat.turn(z, 1.0, SoloVat.at(hip - spine if on_hips else hip))
			]
		)
		_joints.append(
			[
				LEG0 + 2 * k + 1,
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
			"yelped": reader.hound_yelped(i),
			"hp": reader.actor_hp(i),
		}
	)


## The same as sync(), from plain values (tests, EnemyShadows): tick, state, pos, windup (0..1); yelped, hp optional.
func apply_state(s: Dictionary) -> void:
	var st: int = s["state"]
	var yelped: bool = s.get("yelped", false)
	var hp: int = s.get("hp", -1)
	if _fresh:
		_rise = 0.0 if st == WorldReader.STATE_SPAWN else 1.0
	else:
		if st == WorldReader.STATE_RECOVER and _state != WorldReader.STATE_RECOVER:
			if yelped:
				_yelp_t = 0.0
				_hurt_t = -1.0
			elif _state == WorldReader.STATE_ACTIVE:
				_bite_t = 0.0
		elif hp >= 0 and _hp >= 0 and hp < _hp and _yelp_t < 0.0:
			_hurt_t = 0.0
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
	var moving := (
		(_state == WorldReader.STATE_MOVE or _state == WorldReader.STATE_ACTIVE) and not dying
	)
	var target := _vel.length() if moving else 0.0
	_speed = lerpf(_speed, target, _rate(10.0 if moving else 22.0, dt))  # (it plants its feet when it stops)
	_gallop = move_toward(_gallop, smoothstep(GALLOP_FROM, GALLOP_FULL, _speed), dt * 3.0)
	_phase = fposmod(_phase + stride_hz() * dt, 1.0)
	_steer(dt, dying)
	var winding := _state == WorldReader.STATE_WINDUP
	_coil = tell_crouch(_tell) if winding else move_toward(_coil, 0.0, dt * 7.0)
	var active := _state == WorldReader.STATE_ACTIVE and not dying
	_dart = move_toward(_dart, 1.0 if active else 0.0, dt * (16.0 if active else 5.0))
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.5))
	_bite_t = _clip(_bite_t, dt, BITE_SECONDS)
	_yelp_t = _clip(_yelp_t, dt, YELP_SECONDS)
	_hurt_t = _clip(_hurt_t, dt, HURT_SECONDS)
	if dying:
		_die_t += dt
	_pose()


static func _clip(t: float, dt: float, length: float) -> float:
	if t < 0.0:
		return t
	t += dt
	return t if t < length else -1.0


## The stride rate now (Hz): the trot's and the gallop's at this speed, blended.
func stride_hz() -> float:
	return lerpf(TROT_HZ + TROT_HZ_PER * _speed, GALLOP_HZ + GALLOP_HZ_PER * _speed, _gallop)


## The body turns to the way it runs (the sim faces it to the hero while it circles) and banks into the curve; it
## turns back to the hero (its facing) when it stops, fast through the tell. The yaw is this node's own (the flinch's
## rest transform carries it while a flinch runs).
func _steer(dt: float, dying: bool) -> void:
	var want := 0.0
	var running := _speed > 1.0 and _state == WorldReader.STATE_MOVE and not dying
	if running and _vel.length() > 0.5:
		var h := atan2(_vel.y, _vel.x)
		var fy := (get_parent() as Node3D).rotation.y if get_parent() is Node3D else 0.0
		want = wrapf(h - fy, -PI, PI)
		if _have_h:
			_turn = lerpf(_turn, wrapf(h - _last_h, -PI, PI) / dt, _rate(6.0, dt))
		_last_h = h
		_have_h = true
	else:
		_have_h = false
		_turn = lerpf(_turn, 0.0, _rate(6.0, dt))
	if not dying:
		var r := YAW_RATE_TELL if _state == WorldReader.STATE_WINDUP else YAW_RATE
		_yaw = wrapf(_yaw + wrapf(want - _yaw, -PI, PI) * _rate(r, dt), -PI, PI)
	_bank = (
		clampf(_turn * _speed * BANK_K, -1.0, 1.0) if running else _bank * (1.0 - _rate(6.0, dt))
	)
	var b := Basis(Vector3.UP, _yaw)
	if flinching():
		_rest_xf.basis = b
	else:
		transform.basis = b


## Starts the death (ActorViews, when the sim drops the hound): DEATH_SECONDS, then it is freed. True: it plays.
func die() -> bool:
	if _die_t < 0.0:
		_die_t = 0.0
	return true


func dying() -> bool:
	return _die_t >= 0.0


## The body's yaw against its facing now (radians; tests).
func body_yaw() -> float:
	return _yaw


## The visor's glow now (tests, the e2e): rest, climbing through the tell, flashing near its end.
func visor_energy() -> float:
	return _glow


## The raw drives now (tests).
func drives() -> PackedFloat32Array:
	return _vd


# --- The pose -----------------------------------------------------------------------------------------------------
## The pose's numbers from the state (_vd, the lift, the visor's glow), then (the code path) the nodes from them.
func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var k := CALM if calm else 1.0
	var d := PackedFloat32Array()
	d.resize(VAT_DRIVES.size())
	var lift := 0.0
	var amp := clampf(_speed / 2.2, 0.0, 1.0)
	# The legs' gait (the full swing even with reduced motion: the feet must keep up with the ground) and the body's
	# rock and bound with it.
	var legs := _gait_legs(amp)
	for j in 8:
		d[LEG0 + j] = legs[j]
	var p := _phase
	var g := _gallop
	var c1 := cos(TAU * (p - 0.93))
	var c2 := cos(TAU * (p - 0.2))
	lift += (
		amp
		* k
		* lerpf(0.012 * cos(2.0 * TAU * p), 0.035 * (0.5 + 0.5 * cos(TAU * (p - 0.92))) - 0.02, g)
	)
	d[ROLL] += amp * k * lerpf(0.025 * sin(TAU * p), 0.0, g)
	d[PITCH] += amp * k * lerpf(0.0, 0.08 * c2, g)
	d[SPINE] += amp * k * lerpf(0.02 * sin(2.0 * TAU * p), 0.15 * c1, g)
	d[HEAD_P] += amp * k * lerpf(-0.03 * cos(2.0 * TAU * p), -0.1 * c2 - 0.12, g)
	d[TAIL_P] += (
		amp * k * lerpf(0.06 * sin(TAU * (p - 0.2)), 0.15 * cos(TAU * (p - 0.35)) + 0.08, g)
	)
	d[TAIL_Y] += amp * k * lerpf(0.12 * sin(TAU * p), 0.05 * sin(TAU * p), g)
	# The turn: banked into the curve, the hips swung out, the head into the turn and on the hero.
	d[ROLL] += -_bank * LEAN_MAX * k
	d[SPINE_Y] += _bank * 0.22 * k
	d[TAIL_Y] += -_bank * 0.3 * k
	d[HEAD_Y] += clampf(-_yaw * 0.4, -0.5, 0.5) * (1.0 - _coil) + _bank * 0.15 * k
	# Idle: panting, the scanning glances, the tail's wag and flick, the weight shifting (fading as it runs).
	var idle := 1.0 - smoothstep(0.2, 1.6, _speed)
	var pant := sin(TAU * PANT_HZ * _t) * (1.0 + 1.5 * _bite_envelope())
	lift += idle * k * 0.004 * pant
	d[HEAD_P] += idle * k * (0.035 * pant - 0.04)
	d[SPINE] += idle * k * 0.012 * pant
	var look := _scan(_t, 1.7, 0.0) * idle * (1.0 - _coil) * k
	d[HEAD_Y] += 0.35 * look * (1.0 - absf(_yaw) / PI)
	d[HEAD_R] += idle * k * 0.14 * _scan(_t, 2.3, 7.0)
	d[TAIL_Y] += idle * k * 0.14 * sin(TAU * 1.1 * _t)
	d[TAIL_P] += idle * k * (0.06 + 0.25 * _flick(_t))
	d[ROLL] += idle * k * 0.015 * sin(0.8 * _t)
	d[SHIFT] += idle * k * 0.01 * sin(0.8 * _t + 1.0)
	lift += _tell_pose(d, k, calm)
	lift += _dart_pose(d)
	lift += _bite_pose(d, k, calm)
	lift += _yelp_pose(d, k, calm)
	lift += _hurt_pose(d, k)
	lift += _rise_pose(d)
	lift = _death_pose(d, lift, calm)
	for j in d.size():
		d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	_vd = d
	_lift = lift
	_glow = _visor(calm)
	_visor_mat.emission_energy_multiplier = _glow
	if not vat and rig != null:
		_apply()


## Each leg's upper and lower turn (LEGS order, upper then lower) in the gait at this swing `amp`.
func _gait_legs(amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(8)
	for k in LEGS.size():
		var hind := k >= 2
		var t := _leg_cycle(fposmod(_phase - float(TROT_DOWN[k]), 1.0), TROT_DUTY, hind)
		var g := _leg_cycle(fposmod(_phase - float(GALLOP_DOWN[k]), 1.0), GALLOP_DUTY, hind)
		var sw := GALLOP_SWING.y if hind else GALLOP_SWING.x
		var fo := GALLOP_FOLD.y if hind else GALLOP_FOLD.x
		out[2 * k] = REST_U[k] + amp * lerpf(t.x * TROT_SWING, g.x * sw, _gallop)
		out[2 * k + 1] = amp * lerpf(t.y * TROT_FOLD, g.y * fo, _gallop)
	return out


## One leg through its stride at q (0 its touchdown): (the swing, -1 back .. 1 forward; the knee: under 0 folded).
## In its stance the foot sweeps back (the leg squats a little mid-way; a hind leg's hock drives out at the push-off);
## in its swing it comes forward eased, folded most a third of the way, a front leg reaching at the end.
static func _leg_cycle(q: float, duty: float, hind: bool) -> Vector2:
	if q < duty:
		var s := q / duty
		var fold := -0.12 * sin(PI * s) + (0.25 * smoothstep(0.65, 1.0, s) if hind else 0.0)
		return Vector2(1.0 - 2.0 * s, fold)
	var w := (q - duty) / (1.0 - duty)
	var tuck := -sin(PI * minf(w / 0.85, 1.0))
	if not hind:
		tuck += 0.25 * smoothstep(0.7, 1.0, w)
	return Vector2(-1.0 + 2.0 * smoothstep(0.0, 1.0, w), tuck)


## A held glance: a pseudo-random value in -1..1 per `every` s that holds, then moves quickly to the next.
static func _scan(t: float, every: float, seed_off: float) -> float:
	var u := t / every + seed_off
	var seg := floorf(u)
	var a := _hash(seg) * 2.0 - 1.0
	var b := _hash(seg + 1.0) * 2.0 - 1.0
	return lerpf(a, b, smoothstep(0.55, 0.85, u - seg))


## A quick tail flick now and then (0..1).
static func _flick(t: float) -> float:
	var u := t / 2.9
	var seg := floorf(u)
	if _hash(seg + 31.0) < 0.5:
		return 0.0
	return sin(PI * clampf((u - seg - 0.3) / 0.12, 0.0, 1.0))


static func _hash(x: float) -> float:
	var v := sin(x * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)


## The tell: snapped round to the hero (the yaw), low, its weight back over coiled hind legs, the head dropped to aim,
## the tail stiff and quivering; a shiver just before it goes (not with reduced motion). Returns its lift.
func _tell_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	var c := _coil
	if c <= 0.0:
		return 0.0
	d[PITCH] += 0.14 * c * k
	d[SHIFT] -= 0.07 * c
	d[SPINE] += 0.08 * c * k
	for j in 2:
		d[LEG0 + 2 * j] += 0.3 * c
		d[LEG0 + 2 * j + 1] -= 0.15 * c
		d[LEG0 + 4 + 2 * j] += 0.45 * c
		d[LEG0 + 4 + 2 * j + 1] -= 0.75 * c
	d[HEAD_P] -= 0.16 * c
	d[HEAD_R] *= 1.0 - c
	d[TAIL_P] = lerpf(d[TAIL_P], -0.12, c)
	d[TAIL_Y] *= 1.0 - c
	if not calm and _state == WorldReader.STATE_WINDUP:
		d[TAIL_Y] += 0.06 * c * sin(TAU * 16.0 * _t)
		if tell_flashing(_tell):
			d[ROLL] += 0.02 * sin(TAU * 20.0 * _t)
	return -0.075 * c * k


## The dart: a stretched leap over the gait (front legs reaching, hind legs driving back, spine at full stretch, the
## head thrust forward, the body forward and low). Returns its lift.
func _dart_pose(d: PackedFloat32Array) -> float:
	var w := smoothstep(0.0, 1.0, _dart) * 0.85
	if w <= 0.0:
		return 0.0
	var leap := {
		PITCH: -0.08,
		SHIFT: 0.06,
		SPINE: -0.3,
		HEAD_P: -0.12,
		HEAD_Y: 0.0,
		HEAD_R: 0.0,
		TAIL_P: 0.05,
		TAIL_Y: 0.0
	}
	for j: int in leap:
		d[j] = lerpf(d[j], leap[j], w)
	for j in 2:
		d[LEG0 + 2 * j] = lerpf(d[LEG0 + 2 * j], 0.95, w)
		d[LEG0 + 2 * j + 1] = lerpf(d[LEG0 + 2 * j + 1], 0.35, w)
		d[LEG0 + 4 + 2 * j] = lerpf(d[LEG0 + 4 + 2 * j], -0.85, w)
		d[LEG0 + 4 + 2 * j + 1] = lerpf(d[LEG0 + 4 + 2 * j + 1], 0.25, w)
	return -0.02 * w


## 1 at the bite, falling to 0 over BITE_SECONDS (the recovery's heavy panting).
func _bite_envelope() -> float:
	return 1.0 - smoothstep(0.0, 1.0, _bite_t / BITE_SECONDS) if _bite_t >= 0.0 else 0.0


## The bite at the dart's end: the head snaps down and back with a shake (not with reduced motion), the body carries
## forward into a skid stop on braced front legs. Returns its lift.
func _bite_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _bite_t < 0.0:
		return 0.0
	var b := _bite_t / BITE_SECONDS
	var snap := smoothstep(0.0, 0.1, b) * (1.0 - smoothstep(0.1, 0.45, b))
	var brace := 1.0 - smoothstep(0.15, 0.8, b)
	d[HEAD_P] += -0.3 * snap + 0.1 * sin(PI * clampf((b - 0.25) / 0.4, 0.0, 1.0))
	if not calm:
		d[HEAD_R] += 0.28 * sin(TAU * 11.0 * _bite_t) * smoothstep(0.08, 0.2, b) * (1.0 - b)
	d[SHIFT] += 0.08 * snap
	d[PITCH] += (-0.09 * snap + 0.04 * brace) * k
	for j in 2:
		d[LEG0 + 2 * j] += 0.75 * brace * (1.0 - _dart)  # (the dart's reach eases into the brace)
		d[LEG0 + 2 * j + 1] += 0.3 * brace
		d[LEG0 + 4 + 2 * j] += 0.2 * brace
	return -0.03 * brace * k


## The yelp: the head flung up (a twist), a skid on braced front legs, a hop back with the legs tucked, the tail
## tucked under, a cower with a glance away, then it settles. Returns its lift.
func _yelp_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _yelp_t < 0.0:
		return 0.0
	var y := _yelp_t / YELP_SECONDS
	var jerk := smoothstep(0.0, 0.06, y) * (1.0 - smoothstep(0.08, 0.35, y))
	var skid := smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.15, 0.4, y))
	var hop := sin(PI * clampf((y - 0.12) / 0.33, 0.0, 1.0))
	var back := smoothstep(0.08, 0.45, y) * (1.0 - smoothstep(0.6, 1.0, y))
	var tuck := smoothstep(0.0, 0.12, y) * (1.0 - smoothstep(0.75, 1.0, y))
	var cower := smoothstep(0.4, 0.55, y) * (1.0 - smoothstep(0.8, 1.0, y))
	d[HEAD_P] += (0.45 * jerk - 0.2 * cower) * k
	d[HEAD_R] += 0.25 * jerk * k
	d[HEAD_Y] += 0.3 * cower * k
	d[PITCH] += 0.14 * jerk * k
	d[SHIFT] -= 0.16 * back * k
	d[SPINE] += 0.12 * cower * k
	d[TAIL_P] = lerpf(d[TAIL_P], -0.85, tuck)
	d[TAIL_Y] *= 1.0 - tuck
	for j in 2:
		d[LEG0 + 2 * j] += 0.35 * skid
		d[LEG0 + 2 * j + 1] -= 0.6 * hop * k
		d[LEG0 + 4 + 2 * j + 1] -= (0.6 * hop + 0.3 * cower) * k
	if not calm:
		d[ROLL] += 0.04 * sin(TAU * 14.0 * _yelp_t) * jerk
	return (0.02 * jerk + 0.07 * hop - 0.05 * cower) * k


## A plain hit (its HP fell, not a yelp): the head jerks up, the tail dips. Returns its lift.
func _hurt_pose(d: PackedFloat32Array, k: float) -> float:
	if _hurt_t < 0.0:
		return 0.0
	var h := _hurt_t / HURT_SECONDS
	var e := sin(PI * minf(h / 0.3, 1.0)) * (1.0 - smoothstep(0.3, 1.0, h)) * k
	d[HEAD_P] += 0.35 * e
	d[HEAD_R] += 0.15 * e
	d[TAIL_P] -= 0.4 * e
	return -0.02 * e


## The rise-in: low, legs folded under, head down, rising as it arrives. Returns its lift.
func _rise_pose(d: PackedFloat32Array) -> float:
	var r := 1.0 - _rise
	if r <= 0.0:
		return 0.0
	for j in 4:
		d[LEG0 + 2 * j] += 0.3 * r
		d[LEG0 + 2 * j + 1] -= 0.7 * r
	d[HEAD_P] -= 0.25 * r
	return -0.12 * r


## The death: a stumble on buckling front legs (nose down), a roll onto its left side, the legs folding, a last
## twitch (not with reduced motion), the head and tail limp. Returns the lift.
func _death_pose(d: PackedFloat32Array, lift: float, calm: bool) -> float:
	if _die_t < 0.0:
		return lift
	var u := _die_t / (DEATH_SECONDS * 0.9)
	var stumble := smoothstep(0.0, 0.3, u)
	var roll := smoothstep(0.25, 0.7, u)
	var fold := smoothstep(0.45, 0.95, u)
	var still := 1.0 - stumble
	for j in [ROLL, SHIFT, SPINE, SPINE_Y, HEAD_Y, HEAD_R, TAIL_Y]:
		d[j] *= still
	lift *= still
	d[PITCH] = lerpf(d[PITCH] * still - 0.22 * stumble, 0.0, roll)
	for j in 2:
		d[LEG0 + 2 * j] = lerpf(d[LEG0 + 2 * j], -0.2, stumble) + 0.75 * fold
		d[LEG0 + 2 * j + 1] = lerpf(d[LEG0 + 2 * j + 1], -0.9, stumble) - 0.8 * fold
		d[LEG0 + 4 + 2 * j] = lerpf(d[LEG0 + 4 + 2 * j], 0.1, stumble) + 0.7 * fold
		d[LEG0 + 4 + 2 * j + 1] = lerpf(d[LEG0 + 4 + 2 * j + 1], -0.3, stumble) - 1.2 * fold
	if not calm:
		var twitch := sin(PI * clampf((u - 0.72) / 0.25, 0.0, 1.0))
		d[LEG0 + 5] += 0.3 * sin(TAU * 7.0 * _die_t) * twitch
		d[LEG0 + 7] += 0.3 * sin(TAU * 7.0 * _die_t + 1.3) * twitch
	d[ROLL] = lerpf(d[ROLL], -1.3, roll)
	d[HEAD_P] = lerpf(d[HEAD_P], -0.18, stumble) + 0.12 * roll
	d[HEAD_R] -= 0.25 * roll
	d[TAIL_P] = lerpf(d[TAIL_P], -0.3, stumble)
	d[TAIL_Y] += 0.15 * roll
	return lift - 0.1 * stumble * (1.0 - roll) + 0.13 * roll


## The visor's glow: rest; through the tell climbing to VISOR_TELL and flashing from TELL_FLASH_FROM (a flicker; a
## steady step with reduced motion); bright through the dart; out as it dies.
func _visor(calm: bool) -> float:
	var e := VISOR_REST
	if _state == WorldReader.STATE_WINDUP:
		e = VISOR_REST + (VISOR_TELL - VISOR_REST) * tell_crouch(_tell)
		if tell_flashing(_tell):
			e = (
				VISOR_TELL * 1.2
				if calm or int(_t * TELL_FLICKER_HZ * 2.0) % 2 == 0
				else VISOR_TELL * 0.8
			)
	e = maxf(e, VISOR_REST + (VISOR_TELL * 0.8 - VISOR_REST) * _dart)
	if _die_t >= 0.0:
		e *= 1.0 - smoothstep(0.3, 1.0, _die_t / DEATH_SECONDS) * 0.95
	return e


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


## The visor's glow (the instance's accent glow).
func glow_energy() -> float:
	return _glow


## The owner's colour map (VatLooks' textured variant; HordeVat.texture), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## One grid per drive (a turn sampled finely, the slide on two samples: exact), the joints as the table.
func vat_rig() -> Dictionary:
	var grids: Array = []
	for d in VAT_DRIVES.size():
		grids.append([[d, VAT_SAMPLES[d]]])
	var out := SoloVat.rig("scrap_hound", VAT_DRIVES, grids, _joints, false)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out


func vat_sample(rng: RandomNumberGenerator) -> Dictionary:
	var ranges := {
		"_t": [0.0, 40.0],
		"_phase": [0.0, 1.0],
		"_speed": [0.0, 14.0],
		"_gallop": [0.0, 1.0],
		"_yaw": [-PI, PI],
		"_bank": [-1.0, 1.0],
		"_coil": [0.0, 1.0],
		"_tell": [0.0, 1.0],
		"_dart": [0.0, 1.0],
		"_rise": [0.0, 1.0],
		"_bite_t": [-0.3, BITE_SECONDS],
		"_yelp_t": [-0.4, YELP_SECONDS],
		"_hurt_t": [-0.15, HURT_SECONDS],
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
