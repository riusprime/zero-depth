class_name StoneThrowerAvatar
extends AvatarBase
## v0.11.0 O17c (ENEMIES.md R4; owner 2026-11-08: "make sure they are animated as good as you can"): the Stone
## Thrower on the owner's model (EnemyModels &"stone_thrower", prepared by scripts/assets/o17_prep_stone_thrower.py):
## a hunched brute with a bronze carapace (tank bronze, the role plates), a small head with one gem visor, two huge
## arms and short legs, and the rock it rips out of the floor (the model's own rock, its own part). Its parts hang in a
## chain of joints (the hips, the torso, the head, each arm's shoulder, elbow and wrist, each leg) posed in code from
## the sim's state, read through WorldReader once a tick (sync / apply_state) and animated in frame time (advance):
## - idle: heavy breathing (the chest heaves, the shoulders and head ride it), the arms hanging and swaying a little out
##   of step, the knuckles brushing the floor, a slow weight shift and a look round;
## - walk: a heavy knuckle-drag gait, the legs' swing matched to its speed (STRIDE: the planted foot keeps pace with
##   the ground), the body bobbing on each step and rolling over the planted leg, the arms swinging against the legs
##   with the forearms and hands trailing (it walks backward when it backs off to keep its distance);
## - the lift (the sim's windup, 0.8 s; the tell): a small rise, then it crouches and digs both hands into the floor
##   in front, rips the rock out (the views' dust), heaves it up past its chest and holds it overhead, arched back, a
##   strain shudder growing to the throw, the visor climbing and flashing (tell_glow);
## - the throw (the sim's ACTIVE: its first tick is the throw): the rock leaves the hands at once (RuinsRocksViews flies
##   it from RELEASE_AT along the sim's arc) as the arms whip over and down past the knees, a step forward, the body
##   folding into the follow-through and settling;
## - recovery (RECOVER): it straightens up, the arms swinging back to hang, a heavy breath;
## - hit flinch: on top of AvatarBase's lean and squash, the head snaps back and the arms flare;
## - death (die(); ActorViews keeps the node DEATH_SECONDS): it staggers back, drops to its knees and topples forward,
##   then sinks; a rock it held falls and rolls;
## - the rise-in (SPAWN): up out of the floor.
## Reduced motion (ViewPrefs.reduced_motion): smaller breathing, sway and bob, no strain shudder, no flail; the poses
## that carry the read (the lift, the throw) stay.
## VAT (SoloVat, like the Warden): every joint is one number (a turn, a slide, a stretch) of the raw drives (_vd), so a
## VatCrowd draws it from baked poses; the code avatar is the reference. Missing model: a code-made body on the same
## joints. Presentation only (EI-07): nothing here decides. +X is the front.

const KIND := WorldReader.KIND_STONE_THROWER
const MODEL_ID := &"stone_thrower"
const HEIGHT := 1.6
const ROLE := Color("#9A6232")
const CHARCOAL := Color("#2E3036")
const GREY := Color("#77706B")
const BONE := Color("#D9CDB8")
const ROCK_COLOR := Color("#8E8780")
## The joints' pivots (model metres, the right side; the left mirrors z): the prep script's (its PELVIS, NECK ...),
## used as they are by the code-made body; the model's own pivots win when it is there.
const PELVIS := Vector3(0.0, 0.62, 0.0)
const NECK := Vector3(0.3, 0.9, 0.0)
const SHOULDER := Vector3(0.0, 1.12, 0.44)
const ELBOW := Vector3(0.04, 0.8, 0.56)
const WRIST := Vector3(0.16, 0.41, 0.62)
const HIP := Vector3(0.0, 0.6, 0.17)
## Where a hand grips the rock, in the hand's frame (the right hand's; the left mirrors z), and the rock's size (its
## part's scale: the sim's cover is 0.9 m square, the delivered rock about 0.76 m across).
const GRIP := Vector3(0.1, -0.2, -0.06)
const ROCK_SCALE := 1.15
## The rock's centre at the end of the lift (metres in the avatar's frame, +X its front): RuinsRocksViews starts the
## thrown rock's flight there (test_stone_thrower_avatar checks it against the pose).
const RELEASE_AT := Vector3(-0.24, 1.95, 0.0)
## The topple's pivot (in front of the knees, on the floor) and how long the death runs.
const TOPPLE_AT := Vector3(0.42, 0.0, 0.0)
const DEATH_SECONDS := 1.7
## The walk: metres a full stride (two steps) covers, the legs' swing for it (radians each way: the foot travels
## STRIDE / 2 under the hip at the hip height, so a planted foot keeps pace with the ground), the foot's lift (m).
const STRIDE := 1.15
const LEG_SWING := 0.46
const FOOT_LIFT := 0.07
const WALK_SPEED := 1.8
const TELEPORT_SPEED := 30.0
const RISE_SECONDS := 0.5
## The visor's rest glow and its climb with the lift.
const VISOR_REST := 1.8
const VISOR_LIFT := 2.6
## The sim's timing when apply_state isn't told it (stone_thrower.tres: the 0.8 s lift, the 0.6 s flight and its
## landing tick, the 0.8 s recovery).
const TICKS := Vector3i(48, 37, 48)

## The raw drives (_vd) and their specs [lo, hi, loop] (SoloVat): the topple, the hips' slides, twist and roll, the
## torso's lean and breath, the head's turn and nod, each arm's spread, swing, elbow and wrist, each leg's lift and
## swing, the rock's place, spin and scale, each arm's yaw.
const TOPPLE := 0
const HX := 1
const HY := 2
const HZ := 3
const TWIST := 4
const SWAY := 5
const LEAN := 6
const BREATH := 7
const HYAW := 8
const HNOD := 9
const SPREAD0 := 10
const SWING0 := 12
const ELBOW0 := 14
const WRIST0 := 16
const LIFT0 := 18
const LEG0 := 20
const RKX := 22
const RKY := 23
const RKZ := 24
const RSPIN := 25
const RSCALE := 26
const YAW0 := 27
const VAT_DRIVES := [
	[-1.45, 0.02, false],  # TOPPLE
	[-0.2, 0.25, false],  # HX
	[-0.45, 0.12, false],  # HY
	[-0.08, 0.08, false],  # HZ
	[-0.2, 0.2, false],  # TWIST
	[-0.15, 0.15, false],  # SWAY
	[-0.85, 0.55, false],  # LEAN
	[-2.0, 2.0, false],  # BREATH
	[-0.45, 0.45, false],  # HYAW
	[-0.5, 0.75, false],  # HNOD
	[-0.3, 0.8, false],  # SPREAD r
	[-0.3, 0.8, false],  # SPREAD l
	[-0.6, 2.4, false],  # SWING r
	[-0.6, 2.4, false],  # SWING l
	[-0.15, 1.3, false],  # ELBOW r
	[-0.15, 1.3, false],  # ELBOW l
	[-0.6, 1.2, false],  # WRIST r
	[-0.6, 1.2, false],  # WRIST l
	[0.0, 0.1, false],  # LIFT r
	[0.0, 0.1, false],  # LIFT l
	[-1.25, 0.6, false],  # LEG r
	[-1.25, 0.6, false],  # LEG l
	[-1.5, 2.5, false],  # RKX
	[-0.8, 2.6, false],  # RKY
	[-0.5, 0.5, false],  # RKZ
	[0.0, TAU, true],  # RSPIN
	[0.0, 1.2, false],  # RSCALE
	[-0.1, 0.4, false],  # YAW r (inward: the hands come together in front)
	[-0.1, 0.4, false],  # YAW l
]
## Radians between two baked samples of a turn (the bake report's error stays well under a pixel).
const TURN_STEP := 0.02
## The chest's stretch per unit of breath.
const CHEST_BREATH := Vector3(0.022, 0.03, 0.028)

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds no pieces.
var vat := false
var kind := KIND
var has_model := false
var height := HEIGHT
## The joint nodes (null on a VAT avatar), arms and legs right then left.
var hips: Node3D
var torso: Node3D
var chest: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var forearms: Array[Node3D] = []
var hands: Array[Node3D] = []
var legs: Array[Node3D] = []
var rock: Node3D

var _body: Node3D
var _scale := 1.0
var _off := {}
var _vd := PackedFloat32Array()
var _lift := 0.0
var _visor_mat := StandardMaterial3D.new()
var _state := WorldReader.STATE_MOVE
var _state_ticks := 0
var _ticks := TICKS
## Seconds into the attack (from the lift's start; -1: none running), the frame clock's lead over the sim's
## (never more than a tick), the walk, its phase and the signed speed along the facing.
var _atk := -1.0
var _atk_sim := 0.0
var _walk := 0.0
var _phase := 0.0
var _speed := 0.0
var _fwd := Vector2.ZERO
var _rise := 1.0
## After a throw: the heavy breath's strength (1 at the end of the recovery, fading).
var _puff := 0.0
## The death: seconds in (-1: alive), and whether it held a rock (it falls).
var _die_t := -1.0
var _drop := false
var _drop_from := Vector3.ZERO
var _rock_shown := 0.0


## ActorViews' way in: the avatar under `facing` (on the VAT crowd while its switch is on: _solo_vat), `root` marked
## (the avatar, its body materials for the hit flash); returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D, p_kind: int) -> float:
	var a := StoneThrowerAvatar.new()
	views._solo_vat(root, a, p_kind)
	a.setup()
	facing.add_child(a)
	root.set_meta(&"enemy_avatar", a)
	root.set_meta(&"mats", a.body_materials.duplicate())
	return a.height


func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	var m := EnemyModels.get_model(MODEL_ID)
	has_model = not m.is_empty()
	_scale = float(m["scale"]) if has_model else 1.0
	_read_offsets(m)
	if vat:
		_pose()
		return
	_build_nodes()
	if has_model:
		_build_model(m)
	else:
		_build_code()
	_pose()


## The pivots (model metres) the joints hang from: the model's parts' own, else the prep script's constants.
func _read_offsets(m: Dictionary) -> void:
	var piv := {
		&"body": PELVIS,
		&"head": NECK,
		&"arm_r": SHOULDER,
		&"fore_r": ELBOW,
		&"hand_r": WRIST,
		&"leg_r": HIP,
	}
	if not m.is_empty():
		var parts: Dictionary = m["parts"]
		for k: StringName in piv.keys():
			if parts.has(k):
				piv[k] = (parts[k] as Dictionary)["pivot"]
	var pelvis: Vector3 = piv[&"body"]
	_off = {
		"pelvis": pelvis,
		"neck": piv[&"head"] - pelvis,
		"shoulder": piv[&"arm_r"] - pelvis,
		"elbow": piv[&"fore_r"] - piv[&"arm_r"],
		"wrist": piv[&"hand_r"] - piv[&"fore_r"],
		"hip": piv[&"leg_r"] - pelvis,
	}


static func _mirror(v: Vector3, side: float) -> Vector3:
	return Vector3(v.x, v.y, v.z * side)


func _build_nodes() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	hips = Node3D.new()
	hips.name = "Hips"
	_body.add_child(hips)
	torso = Node3D.new()
	torso.name = "Torso"
	hips.add_child(torso)
	chest = Node3D.new()
	chest.name = "Chest"
	torso.add_child(chest)
	head = Node3D.new()
	head.name = "Head"
	torso.add_child(head)
	for k in 2:
		var arm := Node3D.new()
		arm.name = "Arm%d" % k
		torso.add_child(arm)
		var fore := Node3D.new()
		fore.name = "Fore%d" % k
		arm.add_child(fore)
		var hand := Node3D.new()
		hand.name = "Hand%d" % k
		fore.add_child(hand)
		var leg := Node3D.new()
		leg.name = "Leg%d" % k
		hips.add_child(leg)
		arms.append(arm)
		forearms.append(fore)
		hands.append(hand)
		legs.append(leg)
	rock = Node3D.new()
	rock.name = "Rock"
	add_child(rock)


## The owner's model: each part under its joint (its origin at the pivot), the base on the colour map, the bronze plates
## tinted tank bronze, the visor gem on the glow material.
func _build_model(m: Dictionary) -> void:
	var tex: Texture2D = m["texture"]
	var mats := {}
	for slot: StringName in [&"base", &"role", &"rock"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = ROLE if slot == &"role" else Color.WHITE
		mat.roughness = 1.0
		mat.set_meta(&"enemy_tex", true)
		mats[slot] = ActorViews.flashable(mat)
		body_materials.append(mat)
	_visor_mat.albedo_color = ROLE.lightened(0.35)
	_visor_mat.emission_enabled = true
	_visor_mat.emission = Color("#FF9A3C")
	_visor_mat.emission_energy_multiplier = VISOR_REST
	_visor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var homes := {
		&"body": chest,
		&"head": head,
		&"arm_r": arms[0],
		&"arm_l": arms[1],
		&"fore_r": forearms[0],
		&"fore_l": forearms[1],
		&"hand_r": hands[0],
		&"hand_l": hands[1],
		&"leg_r": legs[0],
		&"leg_l": legs[1],
		&"rock": rock,
	}
	var parts: Dictionary = m["parts"]
	for pname: StringName in parts:
		var home: Node3D = homes.get(pname)
		if home == null:
			continue
		var part: Dictionary = parts[pname]
		var mi := MeshInstance3D.new()
		mi.name = String(pname)
		mi.mesh = part["mesh"]
		var surfaces: Array = part["surfaces"]
		for k in surfaces.size():
			var mat: Material = (
				mats[&"rock"] if pname == &"rock" else mats.get(surfaces[k], mats[&"base"])
			)
			if surfaces[k] == &"glow":
				mat = _visor_mat
			mi.set_surface_override_material(k, mat)
		home.add_child(mi)


## The code-made body when the model file is missing: blocks on the same joints, in the stand-in's colours.
func _build_code() -> void:
	var sh: Vector3 = _off["shoulder"]
	_block(chest, Vector3(0.62, 0.5, 0.62), Vector3(0.02, 0.2, 0), CHARCOAL)
	_block(chest, Vector3(0.9, 0.34, 1.0), Vector3(-0.1, 0.62, 0), ROLE)
	_block(head, Vector3(0.26, 0.24, 0.26), Vector3(0.08, 0.08, 0), CHARCOAL)
	var gem := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.05, 0.09, 0.07)
	gem.mesh = gm
	gem.position = Vector3(0.22, 0.1, 0)
	gem.material_override = _visor_mat
	_visor_mat.emission_enabled = true
	_visor_mat.emission = Color("#FF9A3C")
	_visor_mat.albedo_color = ROLE
	_visor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head.add_child(gem)
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		var el := _mirror(_off["elbow"], side)
		var wr := _mirror(_off["wrist"], side)
		_block(arms[k], Vector3(0.26, 0.36, 0.26), el * 0.5, GREY)
		_block(forearms[k], Vector3(0.32, 0.42, 0.32), wr * 0.5, GREY)
		_block(hands[k], Vector3(0.26, 0.3, 0.24), Vector3(0.06, -0.18, 0), BONE)
		_block(legs[k], Vector3(0.22, 0.6, 0.22), Vector3(0, -0.3, 0), GREY)
	var stone := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.38
	sm.height = 0.62
	sm.radial_segments = 7
	sm.rings = 4
	stone.mesh = sm
	var rm := ActorViews.flashable(AvatarBase.plain_material(ROCK_COLOR))
	stone.material_override = rm
	body_materials.append(rm)
	rock.add_child(stone)
	if sh == Vector3.ZERO:
		push_warning("StoneThrowerAvatar: no shoulder offset")


func _block(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> void:
	var m := BoxMesh.new()
	m.size = size
	_body_piece(parent, m, at, c)


# --- The sim's state ---------------------------------------------------------------------------------------------


func sync(reader: WorldReader, i: int) -> void:
	apply_state(
		{
			"tick": reader.tick(),
			"pos": reader.actor_pos(i),
			"state": reader.actor_state(i),
			"state_ticks": reader.actor_state_ticks(i),
			"facing": Kin.dir(reader.actor_facing(i)),
			"ticks": reader.thrower_ticks(i),
		}
	)


## The same as sync(), from plain values (tests and the shot tools drive the avatar with this): tick, pos, state (a
## WorldReader STATE_*), and optionally state_ticks (ticks into the state; else counted from the ticks seen), windup
## (0..1 of the lift: the shot tools' way of giving it), facing (the sim's facing as a unit vector; else the walk is
## taken as forward) and ticks (Vector3i: the lift, the flight with its landing tick, the recovery).
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var state: int = s["state"]
	var dt_ticks := tick - _last_tick
	if _fresh or state != _state:
		_state_ticks = 0
	elif dt_ticks > 0:
		_state_ticks += dt_ticks
	if s.has("state_ticks"):
		_state_ticks = int(s["state_ticks"])
	_ticks = s.get("ticks", TICKS)
	if state == WorldReader.STATE_WINDUP and s.has("windup") and not s.has("state_ticks"):
		_state_ticks = roundi(float(s["windup"]) * _ticks.x)
	_track_motion(tick, s["pos"], TELEPORT_SPEED)
	_fwd = s.get("facing", Vector2.ZERO)
	_state = state
	_atk_sim = _attack_clock()
	if _atk_sim < 0.0:
		_atk = -1.0
	elif _atk < 0.0 or absf(_atk - _atk_sim) > 2.0 / 60.0:
		_atk = _atk_sim
	else:
		_atk = maxf(_atk, _atk_sim)  # the frame clock never trails the sim's
	if _fresh:
		_fresh = false
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_pose()


## Seconds into the attack the sim is at now (from the lift's start), or -1 outside it.
func _attack_clock() -> float:
	var t := float(_state_ticks)
	match _state:
		WorldReader.STATE_WINDUP:
			return t / 60.0
		WorldReader.STATE_ACTIVE:
			return (_ticks.x + t) / 60.0
		WorldReader.STATE_RECOVER:
			return (_ticks.x + _ticks.y + t) / 60.0
	return -1.0


## v0.8.0 MI's way (ActorViews keeps the node DEATH_SECONDS): starts the death. A rock in its hands falls.
func die() -> bool:
	if _die_t >= 0.0:
		return true
	_die_t = 0.0
	_drop = _rock_shown > 0.5
	_drop_from = Vector3(_vd[RKX], _vd[RKY], _vd[RKZ])
	return true


func dying() -> bool:
	return _die_t >= 0.0


# --- Frame time --------------------------------------------------------------------------------------------------


func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0:
		return
	_t += dt
	if _die_t >= 0.0:
		_die_t += dt
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt / RISE_SECONDS)
	if _atk >= 0.0:
		_atk = minf(_atk + dt, _atk_sim + 1.0 / 60.0)  # smooth between ticks, never a tick ahead
		if _state == WorldReader.STATE_WINDUP:  # the rock leaves the hands on the sim's throw tick, not before
			_atk = minf(_atk, _ticks.x / 60.0 - 0.001)
	var signed := _vel.length()
	if _fwd != Vector2.ZERO and _vel.length() > 0.05:
		signed = _vel.dot(_fwd)
	_speed = lerpf(_speed, signed, _rate(10.0, dt))
	var busy := _atk >= 0.0 or _die_t >= 0.0
	_walk = lerpf(
		_walk, 0.0 if busy else clampf(absf(_speed) / WALK_SPEED, 0.0, 1.0), _rate(6.0, dt)
	)
	_phase += _speed * dt * TAU / STRIDE * (0.0 if busy else 1.0)
	if _state == WorldReader.STATE_RECOVER:
		_puff = 1.0
	else:
		_puff = move_toward(_puff, 0.0, dt / 2.5)
	_pose()


## The pose code's clocks (tests and the shot tools): seconds into the attack (-1: none), the walk (0..1).
func attack_time() -> float:
	return _atk


func walk_amount() -> float:
	return _walk


## Whether the rock is in its hands now (shown: ripped and not yet thrown), and the visor's glow.
func rock_lifted() -> bool:
	return _rock_shown > 0.5 and _die_t < 0.0


func visor_energy() -> float:
	return _visor_mat.emission_energy_multiplier


## The rock's centre now, in this node's frame (metres).
func rock_position() -> Vector3:
	return Vector3(_vd[RKX], _vd[RKY], _vd[RKZ])


# --- The pose ----------------------------------------------------------------------------------------------------


func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var p := StoneThrowerPoses.locomotion(_t, _walk, _phase, _speed, _puff, calm)
	if _atk >= 0.0:  # (a death freezes it: no sync moves the sim's clock on)
		p = StoneThrowerPoses.attack(_atk, p, _ticks, _t, calm)
	if _die_t >= 0.0:
		p = StoneThrowerPoses.death(_die_t, p, calm)
	# The hit flinch: the head snaps back, the arms flare, the chest is knocked back (AvatarBase leans the whole).
	var f := flinch_amount() * (0.5 if calm else 1.0)
	if f != 0.0 and _die_t < 0.0:
		p[LEAN] = float(p.get(LEAN, 0.0)) + 0.14 * f
		p[HNOD] = float(p.get(HNOD, 0.0)) + 0.3 * f
		p[HY] = float(p.get(HY, 0.0)) - 0.03 * f
		for k in 2:
			p[SPREAD0 + k] = float(p.get(SPREAD0 + k, 0.0)) + 0.18 * f
			p[ELBOW0 + k] = float(p.get(ELBOW0 + k, 0.0)) + 0.22 * f
	for d in VAT_DRIVES.size():
		_vd[d] = float(p.get(d, 0.0))
	# The rise-in: up out of the floor; the death's last moment: sinking.
	var sink := 1.0 - _rise
	sink = sink * sink * (3.0 - 2.0 * sink)
	_lift = -1.7 * sink
	if _die_t >= 0.0:
		_lift = -0.45 * smoothstep(1.3, DEATH_SECONDS, _die_t)
	_pose_rock(calm)
	var tell := 1.0
	if _state == WorldReader.STATE_WINDUP and _atk >= 0.0 and _die_t < 0.0:
		var u := clampf(_atk * 60.0 / float(_ticks.x), 0.0, 1.0)
		tell = (1.0 + VISOR_LIFT * smoothstep(0.3, 0.7, u) / VISOR_REST) * tell_glow(u, _t, calm)
	_visor_mat.emission_energy_multiplier = VISOR_REST * tell
	if vat or hips == null:
		return
	var xs := _locals()
	var up := Transform3D(Basis.IDENTITY, Vector3(0, _lift, 0))  # (VAT: the instance's lift, not baked)
	_body.transform = up * xs[0]
	hips.transform = xs[1]
	torso.transform = xs[2]
	chest.transform = xs[3]
	head.transform = xs[4]
	for k in 2:
		arms[k].transform = xs[5 + k]
		forearms[k].transform = xs[7 + k]
		hands[k].transform = xs[9 + k]
		legs[k].transform = xs[11 + k]
	rock.transform = up * xs[13]


## Where the rock is: in the hands from the moment it is ripped (rising out of the floor between them) to the throw,
## gone from the throw to the next rip; falling and rolling from the hands of a Thrower that dies holding it.
func _pose_rock(calm: bool) -> void:
	var shown := 0.0
	var at := Vector3(0.6, -0.5, 0.0)
	var spin := 0.0
	if _die_t >= 0.0:
		if _drop:
			var d := _die_t
			var fall := clampf(d / 0.45, 0.0, 1.0)
			var floor_y := 0.38 * ROCK_SCALE
			var y := lerpf(_drop_from.y, floor_y, fall * fall)
			if d > 0.45:
				y = floor_y + 0.12 * absf(sin(clampf((d - 0.45) / 0.35, 0.0, 1.0) * PI))
			var roll := clampf((d - 0.45) / 0.9, 0.0, 1.0)
			var x := _drop_from.x + 0.35 * fall + 0.45 * (1.0 - (1.0 - roll) * (1.0 - roll))
			at = Vector3(x, y, _drop_from.z)
			spin = -(x - _drop_from.x) / (0.38 * ROCK_SCALE)
			shown = 1.0
	elif _atk >= 0.0:
		var lift := _ticks.x / 60.0
		if _atk < lift:
			var u := _atk / lift
			var grips := grip_points()
			var mid: Vector3 = (grips[0] + grips[1]) * 0.5
			var up := smoothstep(0.3, 0.48, u)
			at = mid + Vector3(0.0, -0.42 * (1.0 - up), 0.0)
			shown = 1.0 if u >= 0.28 else 0.0
			spin = (
				0.25 * (1.0 - up)
				+ (0.0 if calm else 0.03 * sin(_t * TAU * 3.0) * smoothstep(0.7, 1.0, u))
			)
	_rock_shown = shown
	var size := ROCK_SCALE * (0.82 + 0.18 * smoothstep(0.3, 0.48, _atk * 60.0 / float(_ticks.x)))
	if _die_t >= 0.0:
		size = ROCK_SCALE
	_vd[RKX] = at.x
	_vd[RKY] = at.y
	_vd[RKZ] = at.z
	_vd[RSPIN] = fposmod(spin, TAU)
	_vd[RSCALE] = size if shown > 0.0 else 0.001


## Each joint node's transform from the drives, in the order _pose sets them: the body (the scale and the topple), the
## hips, the torso, the chest, the head, the arms, forearms, hands and legs (right, left), the rock.
func _locals() -> Array[Transform3D]:
	var xs: Array[Transform3D] = []
	var s := _scale
	var tp := TOPPLE_AT / s
	xs.append(
		(
			Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
			* Transform3D(Basis.IDENTITY, tp)
			* Transform3D(Basis(Vector3.BACK, _vd[TOPPLE]), Vector3.ZERO)
			* Transform3D(Basis.IDENTITY, -tp)
		)
	)
	var pelvis: Vector3 = _off["pelvis"]
	xs.append(
		Transform3D(
			Basis(Vector3.UP, _vd[TWIST]) * Basis(Vector3.RIGHT, _vd[SWAY]),
			pelvis + Vector3(_vd[HX], _vd[HY], _vd[HZ])
		)
	)
	xs.append(Transform3D(Basis(Vector3.BACK, _vd[LEAN]), Vector3.ZERO))
	xs.append(Transform3D(Basis.from_scale(Vector3.ONE + CHEST_BREATH * _vd[BREATH]), Vector3.ZERO))
	xs.append(
		Transform3D(
			Basis(Vector3.UP, _vd[HYAW]) * Basis(Vector3.BACK, _vd[HNOD]), _off["neck"] as Vector3
		)
	)
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		xs.append(
			Transform3D(
				(
					Basis(Vector3.UP, side * _vd[YAW0 + k])
					* Basis(Vector3.RIGHT, -side * _vd[SPREAD0 + k])
					* Basis(Vector3.BACK, _vd[SWING0 + k])
				),
				_mirror(_off["shoulder"], side)
			)
		)
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		xs.append(Transform3D(Basis(Vector3.BACK, _vd[ELBOW0 + k]), _mirror(_off["elbow"], side)))
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		xs.append(Transform3D(Basis(Vector3.BACK, _vd[WRIST0 + k]), _mirror(_off["wrist"], side)))
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		xs.append(
			Transform3D(
				Basis(Vector3.BACK, _vd[LEG0 + k]),
				_mirror(_off["hip"], side) + Vector3(0, _vd[LIFT0 + k], 0)
			)
		)
	xs.append(
		Transform3D(
			Basis(Vector3.BACK, _vd[RSPIN]) * Basis.from_scale(Vector3.ONE * s * _vd[RSCALE]),
			Vector3(_vd[RKX], _vd[RKY], _vd[RKZ])
		)
	)
	return xs


## Both hands' grip points now (right, left), in this node's frame, from the drives (no nodes needed: the VAT avatar
## holds its rock between the same hands).
func grip_points() -> Array[Vector3]:
	var xs := _locals()
	var torso_xf := xs[0] * xs[1] * xs[2]
	var out: Array[Vector3] = []
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		var hand_xf := torso_xf * xs[5 + k] * xs[7 + k] * xs[9 + k]
		out.append(hand_xf * _mirror(GRIP, side))
	return out


# --- VAT (SoloVat) -----------------------------------------------------------------------------------------------


## The rise-in's and the death's sink (m): the whole body's lift VatCrowd moves the instance by.
func vat_lift() -> float:
	return _lift


func vat_drives() -> PackedFloat32Array:
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The visor's glow (climbing and flashing through the lift).
func glow_energy() -> float:
	return _visor_mat.emission_energy_multiplier


## The model's colour map (VatLooks' textured variant; HordeVat.texture asks), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL_ID).get("texture") if has_model else null


## Each node's transform split into one-number joints as _locals composes them.
func vat_rig() -> Dictionary:
	var x := Vector3.RIGHT
	var y := Vector3.UP
	var z := Vector3.BACK
	var s := _scale
	var tp := TOPPLE_AT / s
	var j: Array = [
		[
			TOPPLE,
			-1,
			_body,
			SoloVat.turn(z, 1.0, SoloVat.stretch(Vector3.ONE * s) * SoloVat.at(tp), SoloVat.at(-tp))
		],
		[HX, 0, null, SoloVat.slide(x, _off["pelvis"])],
		[HY, 1, null, SoloVat.slide(y)],
		[HZ, 2, null, SoloVat.slide(z)],
		[TWIST, 3, null, SoloVat.turn(y)],
		[SWAY, 4, hips, SoloVat.turn(x)],
		[LEAN, 5, torso, SoloVat.turn(z)],
		[BREATH, 6, chest, SoloVat.stretch_by(Vector3.ONE, CHEST_BREATH)],
		[HYAW, 6, null, SoloVat.turn(y, 1.0, SoloVat.at(_off["neck"]))],
		[HNOD, 8, head, SoloVat.turn(z)],
	]
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		var shoulder := _mirror(_off["shoulder"], side)
		j.append([YAW0 + k, 6, null, SoloVat.turn(y, side, SoloVat.at(shoulder))])
		j.append([SPREAD0 + k, j.size() - 1, null, SoloVat.turn(x, -side)])
		j.append([SWING0 + k, j.size() - 1, _node(arms, k), SoloVat.turn(z)])
		var el := _mirror(_off["elbow"], side)
		j.append(
			[ELBOW0 + k, j.size() - 1, _node(forearms, k), SoloVat.turn(z, 1.0, SoloVat.at(el))]
		)
		var wr := _mirror(_off["wrist"], side)
		j.append([WRIST0 + k, j.size() - 1, _node(hands, k), SoloVat.turn(z, 1.0, SoloVat.at(wr))])
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		j.append([LIFT0 + k, 5, null, SoloVat.slide(y, _mirror(_off["hip"], side))])
		j.append([LEG0 + k, j.size() - 1, _node(legs, k), SoloVat.turn(z)])
	j.append([RKX, -1, null, SoloVat.slide(x)])
	j.append([RKY, j.size() - 1, null, SoloVat.slide(y)])
	j.append([RKZ, j.size() - 1, null, SoloVat.slide(z)])
	j.append([RSPIN, j.size() - 1, null, SoloVat.turn(z)])
	j.append([RSCALE, j.size() - 1, rock, SoloVat.stretch_by(Vector3.ZERO, Vector3.ONE * s)])
	var grids: Array = []
	for d in VAT_DRIVES.size():
		grids.append([[d, _samples(d)]])
	var out := SoloVat.rig("stone_thrower", VAT_DRIVES, grids, j, true)
	if has_model:  # the owner's model's colour map (VatLooks' textured variant)
		out["albedo_tex"] = vat_texture()
	return out


func _node(list: Array[Node3D], k: int) -> Node3D:
	return list[k] if k < list.size() else null


## Samples along drive d: a turn every TURN_STEP radians (a loop wraps), a slide or a stretch two (linear: exact).
static func _samples(d: int) -> int:
	var spec: Array = VAT_DRIVES[d]
	var span := float(spec[1]) - float(spec[0])
	var turn := d in [TOPPLE, TWIST, SWAY, LEAN, HYAW, HNOD, RSPIN, YAW0, YAW0 + 1]
	turn = turn or (d >= SPREAD0 and d < LIFT0)
	turn = turn or d == LEG0 or d == LEG0 + 1
	if not turn:
		return 2
	return ceili(span / TURN_STEP) + (0 if bool(spec[2]) else 1)


func vat_sample(rng: RandomNumberGenerator) -> Dictionary:
	var ranges := {
		"_t": [0.0, 40.0],
		"_phase": [0.0, 40.0],
		"_walk": [0.0, 1.0],
		"_speed": [-1.8, 1.8],
		"_puff": [0.0, 1.0],
		"_rise": [0.0, 1.0],
		"_atk": [-1.0, 2.3],
		"_atk_sim": [-1.0, 2.3],
		"_die_t": [-1.0, 1.8],
		"_drop": [false, true, false],
		"_flinch_t": [0.0, 0.25],
		"_flinch_s": [0.0, 1.0],
		"_state": [WorldReader.STATE_MOVE, WorldReader.STATE_WINDUP, WorldReader.STATE_ACTIVE],
	}
	return SoloVat.sample(self, rng, ranges, _pose)


func vat_set(s: Dictionary) -> void:
	SoloVat.apply(self, s, _pose)
