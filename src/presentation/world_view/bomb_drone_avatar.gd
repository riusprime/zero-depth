class_name BombDroneAvatar
extends AvatarBase
## The Bomb Drone on the owner's model (EnemyModels &"bomb_drone", cut by scripts/assets/bomb_drone_prep.py into the
## hull with its visor, four arms with their rotor housings, the four rotors and the claw cradle), hovering HOVER_Y up
## (the hull's middle) with a dark bomb of its own slung in the cradle, animated in code from the sim's state and drawn
## by the VAT crowd (SoloVat) while the switch is on. The owner: floating enemies need "some movement, these models can
## not walk or be static models that look out of place". A soft dark disc on the ground marks where the drone really is:
## the sim treats it as a body on the ground, so melee and shots hit it there (the owner: "hittable from the ground
## level"). Its clips, each read from the sim through WorldReader (sync) and played in frame time (advance):
## - idle hover: it bobs, rocking a little, the rotors spinning (each pair the other way), the arms and claws quivering;
##   the bomb's fuse flickers while it carries one;
## - the glide (the sim moving it): it tips its nose into the travel and banks into a sideways one;
## - the turn (the facing node turning): it banks into the turn, the hull trailing it;
## - the lob (its windup): the claws spring open and the bomb drops away (the telegraph view draws it flying to its
##   circle) as the drone snaps its nose down to throw and then kicks up, lighter; the rotors spin up and the visor
##   brightens while the circle fills; through the recovery a new bomb rises into the cradle and the claws close on it;
## - a hit (its HP fell): it sags in the air and wobbles back up in damped swings, the arms flapping (AvatarBase's
##   flinch leans it about the hull);
## - the death (die(): DEATH_SECONDS): a jolt, the rotors spin down and the bomb drops; it tips over and falls to the
##   floor, where its arms break off and splay out, the claws burst open and the visor goes out;
## - the rise-in (SPAWN): it lifts off the floor to its hover, arms unfolding, rotors spooling up;
## - reduced motion (ViewPrefs.reduced_motion): no bob, the sways at CALM of their size, slower rotors, one eased dip.
## The pose is a few plain numbers (the raw drives, _vd) worked out from the state first, then the nodes from them
## through the joint table (_joints, the same transforms the VAT rig declares), so the baked pose is the live one.
## On the VAT crowd it is batched (EnemyBatch: nothing here reads the tree, its turn is its facing node's; its ground
## disc hangs in the tree from the batch's anchor, BatchBombDrone), and the native batch runs the same sync, frame step
## and pose (native/src/zd_avatar_bomb_drone.cpp).
## Presentation only (EI-07): nothing here reaches the sim. +X is the front, +Z its right.

const KIND := WorldReader.KIND_BOMB_DRONE
const MODEL := &"bomb_drone"
## The model's own height (m: EnemyModels scales it to this, so the scale is 1 and it spans 1.0 m across its rotors,
## the old code drone's span).
const MODEL_HEIGHT := 0.588
## How high the hull's middle hovers (the telegraph view's lob starts there), the bob's height and rate (starting
## values, PLAN "Enemy and boss AI"); the model's top (the health bar's height).
const HOVER_Y := 1.8
const BOB_M := 0.08
const BOB_HZ := 0.9
const HEIGHT := HOVER_Y + 0.3
## The hull's middle in the model's frame (the rig turns about it) and the lift that puts it at HOVER_Y.
const HULL := Vector3(0.0, 0.35, 0.0)
const LIFT := HOVER_Y - 0.35
## The lift it rises in from, and the one it lies at once dead.
const LIFT_GROUND := 0.22
const LIFT_DEAD := 0.08
const SHADOW_R := 0.42
## Its colours: the plates take the palette's body colour (the request's bomber yellow); the visor's gem; the bomb.
const VISOR_COLOR := Color("#FFE27A")
const VISOR_GLOW := Color("#FFC21A")
const VISOR_REST := 1.6
const VISOR_TELL := 2.5
const DARK := Color("#24272D")
const GREY := Color("#5F5551")
const BOMB := Color("#1B1C20")
## The rotors' spin (rad/s), what the lob adds (a share), the glide's full speed (m/s: the sim's), the turn rate
## (rad/s) of a full bank. Reduced motion: CALM.
const SPIN := 34.0
const SPIN_TELL := 0.5
const GLIDE_MPS := 2.6
const TURN_REF := 3.0
const CALM := 0.4
## The clips' lengths (s): the throw, a hit's wobble, the death.
const LOB_S := 0.5
const HURT_SECONDS := 0.8
const DEATH_SECONDS := 1.2
## The bomb in the cradle (m, the model's frame), its size, how far it sinks as it is let go; the claws' spread when
## open (a share across, and what they shorten).
const BOMB_AT := Vector3(0.0, 0.085, 0.0)
const BOMB_R := 0.068
const BOMB_DROP := 0.12
const CLAW_OPEN := Vector3(0.45, -0.2, 0.45)
## How far each arm slides out when it breaks off (m, along its own side).
const BREAK_M := 0.22
## The arms (and their rotors): "u" / "d" the upper and lower pair, "r" / "l" the drone's right (+Z) and left; each
## rotor's spin direction (opposite pairs the same way).
const ARMS: Array[StringName] = [&"ur", &"ul", &"dr", &"dl"]
const SPIN_SIGN := [1.0, -1.0, -1.0, 1.0]
## The pivots (m, the model's frame) when the model is missing (the prep's own).
const PIVOTS := {
	&"hull": Vector3(0.0, 0.35, 0.0),
	&"arm_ur": Vector3(-0.135, 0.431, 0.2),
	&"arm_ul": Vector3(-0.15, 0.38, -0.2),
	&"arm_dr": Vector3(0.019, 0.226, 0.2),
	&"arm_dl": Vector3(0.024, 0.245, -0.2),
	&"rotor_ur": Vector3(-0.107, 0.559, 0.342),
	&"rotor_ul": Vector3(-0.195, 0.537, -0.324),
	&"rotor_dr": Vector3(0.025, 0.152, 0.322),
	&"rotor_dl": Vector3(0.034, 0.156, -0.337),
	&"cradle": Vector3(0.0, 0.17, 0.0),
}

## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]: the hull's roll (+ the right side down), pitch (+ the
## nose down) and yaw about its middle; each arm's droop (+ down) at its root; the arms' break (their slide out); the
## rotors' turn (a loop); the claws' spread; the bomb (0: let go, folded to a point under the cradle; 1: slung); the
## visor's glow (sent as is).
const ROLL := 0
const PITCH := 1
const YAW := 2
const DROOP0 := 3
const BREAK := 7
const ROTOR := 8
const CLAW := 9
const BOMB_S := 10
const VISOR := 11
const VAT_DRIVES := [
	[-0.9, 0.9, false],
	[-0.7, 0.9, false],
	[-0.6, 0.6, false],
	[-0.8, 1.4, false],
	[-0.8, 1.4, false],
	[-0.8, 1.4, false],
	[-0.8, 1.4, false],
	[0.0, 1.0, false],
	[0.0, TAU, true],
	[0.0, 1.0, false],
	[0.0, 1.0, false],
	[0.0, 0.0, false],
]
## Each drive's samples (a turn finely, the spin finest; a slide or a stretch is linear: exact on two).
const VAT_SAMPLES := [41, 41, 33, 41, 41, 41, 41, 2, 128, 2, 2]

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds only the ground disc.
var vat := false
var kind := KIND
## True when the body is the owner's model (else the code-made stand-in on the same joints).
var has_model := false
## The joints' frame nodes by part name (tests): rig (the hull), arm_ur..dl, rotor_ur..dl, cradle, bomb (none on a VAT
## avatar); the ground disc (kept live on VAT).
var parts := {}
var shadow: MeshInstance3D
## The bomb's frame and the rotors' (tests).
var bomb: Node3D
var rotors: Array[Node3D] = []

var _vd := PackedFloat32Array()
var _lift := LIFT
var _visor_mat := StandardMaterial3D.new()
var _fuse_mat := StandardMaterial3D.new()
var _pivots := PIVOTS.duplicate()
## The joint table: [grid, parent joint, frame node or null, make (SoloVat's)], a parent before its children.
var _joints: Array = []
# The state the pose is made from (sync and advance keep it; VatVerify.sample sets it): the sim's state, HP, the
# rise-in, the bomb slung (0..1), the fuse lit, the throw (seconds into it; -1: none), the aim (the visor's tell, 0..1),
# the rotors' turn and spin (rad/s), the glide's share and direction (the facing's frame: x forward, y right), the
# facing's turn rate, a hit's clip and side, the death.
var _state := WorldReader.STATE_SPAWN
var _hp := -1
var _rise := 0.0
var _armed := 1.0
var _fuse := 0.0
var _lob_s := -1.0
var _aim := 0.0
var _rot := 0.0
var _spin := 0.0
var _glide := 0.0
var _dir := Vector2.RIGHT
var _omega := 0.0
var _hurt_t := -1.0
var _hurt_side := 1.0
var _die_t := -1.0
var _last_fy := 0.0
var _have_fy := false


## Builds the drone under `facing` for ActorViews (`views`: on VAT while its switch is on) and marks `root` (the
## avatar, its body materials for the hit flash); returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D, p_kind: int) -> float:
	var a := BombDroneAvatar.new()
	views._solo_vat(root, a, p_kind)
	a.setup()
	facing.add_child(a)
	root.set_meta(&"enemy_avatar", a)
	root.set_meta(&"mats", a.body_materials.duplicate())
	return HEIGHT


func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	_visor_mat.albedo_color = VISOR_COLOR
	_visor_mat.roughness = 1.0
	_visor_mat.emission_enabled = true
	_visor_mat.emission = VISOR_GLOW
	_visor_mat.emission_energy_multiplier = VISOR_REST
	_visor_mat.set_meta(SoloVat.GLOW, VISOR + 1)  # a VAT drone's visor glows at its VISOR drive
	var hot := ThemePalette.color(&"telegraph_hostile")
	_fuse_mat.albedo_color = hot
	_fuse_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fuse_mat.emission_enabled = true
	_fuse_mat.emission = hot
	_build_shadow()
	var m := EnemyModels.get_model(MODEL)
	has_model = not m.is_empty()
	if has_model:
		var parts_in: Dictionary = m["parts"]
		for pname: StringName in parts_in:
			_pivots[pname] = (parts_in[pname] as Dictionary)["pivot"] * float(m["scale"])
	if not vat:
		_build_frames()
		if has_model:
			_build_model(m)
		else:
			_build_code()
		_build_bomb()
	_build_joints()
	_pose()


## The ground disc under it (kept live on VAT: the crowd draws only the body).
func _build_shadow() -> void:
	shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = SHADOW_R
	disc.bottom_radius = SHADOW_R
	disc.height = 0.005
	disc.radial_segments = 16
	shadow.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.35)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override = sm
	shadow.position.y = 0.012
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.set_meta(SoloVat.LIVE, true)
	add_child(shadow)


func _frame(pname: String, parent: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = pname.to_pascal_case()
	(self if parent == null else parent).add_child(n)
	parts[pname] = n
	return n


## The frame nodes, nested as the joint table chains them.
func _build_frames() -> void:
	var rig := _frame("rig", null)
	for a in ARMS:
		var arm := _frame("arm_%s" % a, rig)
		rotors.append(_frame("rotor_%s" % a, arm))
	_frame("cradle", rig)
	bomb = _frame("bomb", rig)


## The owner's model: each part's mesh in its frame (its pivot at the frame's origin), its surfaces on the base / role
## plates (the role plates greyscale in the map, tinted the palette's body colour) and the visor's glow.
func _build_model(m: Dictionary) -> void:
	var tex: Texture2D = m["texture"]
	var mats := {}
	for slot: StringName in [&"base", &"role"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = _look_color(KIND, &"body") if slot == &"role" else Color.WHITE
		mat.roughness = 1.0
		mat.set_meta(&"enemy_tex", true)
		mats[slot] = ActorViews.flashable(mat)
		body_materials.append(mat)
	var parts_in: Dictionary = m["parts"]
	for pname: StringName in parts_in:
		var part: Dictionary = parts_in[pname]
		var mi := MeshInstance3D.new()
		mi.name = String(pname)
		mi.mesh = part["mesh"]
		mi.scale = Vector3.ONE * float(m["scale"])
		mi.extra_cull_margin = 1.0  # poses move parts past the rest bounds
		var surfaces: Array = part["surfaces"]
		for k in surfaces.size():
			mi.set_surface_override_material(
				k, _visor_mat if surfaces[k] == &"glow" else mats.get(surfaces[k], mats[&"base"])
			)
		var frame: Node3D = parts.get(String(pname), parts["rig"])
		if frame == parts["rig"]:  # the hull hangs on the rig at its own place
			mi.position = _pivots[pname]
		frame.add_child(mi)


## The code-made stand-in (the model file missing): a chamfered hull with its cap and visor slit, four arms out to
## their housings, the two-blade rotors and three claws, on the same joints, so every clip still plays.
func _build_code() -> void:
	var rig: Node3D = parts["rig"]
	_body_piece(
		rig,
		NeedleAvatar._chamfer_box(Vector3(0.44, 0.24, 0.38), 0.06, 0.02),
		HULL,
		_look_color(KIND, &"body")
	)
	_body_piece(
		rig,
		NeedleAvatar._chamfer_box(Vector3(0.26, 0.08, 0.24), 0.03, 0.01),
		HULL + Vector3(-0.02, 0.15, 0),
		_look_color(KIND, &"trim")
	)
	var slit := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.01, 0.04, 0.16)
	slit.mesh = sb
	slit.material_override = _visor_mat
	slit.position = HULL + Vector3(0.225, -0.04, 0)
	rig.add_child(slit)
	for k in ARMS.size():
		var arm_node: Node3D = parts["arm_%s" % ARMS[k]]
		var root: Vector3 = _pivots[StringName("arm_%s" % ARMS[k])]
		var hub: Vector3 = _pivots[StringName("rotor_%s" % ARMS[k])]
		var span := hub - Vector3(0, 0.03, 0) - root
		var arm := _body_piece(
			arm_node,
			NeedleAvatar._chamfer_box(Vector3(0.05, 0.05, span.length()), 0.012),
			span * 0.5,
			GREY
		)
		arm.basis = Basis.looking_at(span, Vector3.UP)
		_body_piece(
			arm_node,
			ArcCasterAvatar._frustum(0.07, 0.07, 0.07, 8),
			hub - root - Vector3(0, 0.08, 0),
			DARK
		)
		_body_piece(
			rotors[k],
			NeedleAvatar._chamfer_box(Vector3(0.3, 0.012, 0.05), 0.004),
			Vector3.ZERO,
			DARK
		)
	for k in 3:
		var a := TAU * k / 3.0
		var claw := _body_piece(
			parts["cradle"],
			NeedleAvatar._chamfer_box(Vector3(0.03, 0.16, 0.03), 0.008),
			Vector3(cos(a) * 0.08, -0.08, sin(a) * 0.08),
			GREY
		)
		claw.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)


## Its own bomb (the model carries none): a faceted dark iron ball slung in the cradle, its fuse glowing under it. Not a
## body plate: the hit flash stays on the drone.
func _build_bomb() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = BOMB
	iron.roughness = 0.7
	var ball := MeshInstance3D.new()
	ball.name = "Bomb"
	ball.mesh = _ball(BOMB_R, 8, 4)
	ball.material_override = iron
	bomb.add_child(ball)
	var fuse := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.035, 0.035, 0.035)
	fuse.mesh = fb
	fuse.material_override = _fuse_mat
	fuse.position = Vector3(0, -BOMB_R - 0.01, 0)
	fuse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bomb.add_child(fuse)


## A flat-shaded ball of radius r: `sides` round, `bands` from pole to pole.
static func _ball(r: float, sides: int, bands: int) -> ArrayMesh:
	var tris := []
	for b in bands:
		var p0 := PI * b / bands
		var p1 := PI * (b + 1) / bands
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var q00 := Vector3(sin(p0) * cos(a0), cos(p0), sin(p0) * sin(a0)) * r
			var q01 := Vector3(sin(p0) * cos(a1), cos(p0), sin(p0) * sin(a1)) * r
			var q10 := Vector3(sin(p1) * cos(a0), cos(p1), sin(p1) * sin(a0)) * r
			var q11 := Vector3(sin(p1) * cos(a1), cos(p1), sin(p1) * sin(a1)) * r
			if b > 0:
				tris.append([q00, q01, q11])
			if b < bands - 1:
				tris.append([q00, q11, q10])
	return flat_mesh(tris, Vector3.ZERO)


## The joint table (see _joints): the hull's roll, pitch and yaw about its middle (the rig); each arm's droop at its
## root and its slide out when it breaks; each rotor's turn on its axis; the cradle's spread at the belly; the bomb's
## sink-and-fold under the cradle (one number: linear, so exact on two samples).
func _build_joints() -> void:
	var p := _pivots
	var into := SoloVat.at(HULL)
	var out := SoloVat.at(-HULL)
	var x := Vector3.RIGHT
	_joints = [
		[ROLL, -1, null, SoloVat.turn(x, 1.0, into, out)],
		[PITCH, 0, null, SoloVat.turn(Vector3.BACK, -1.0, into, out)],
		[YAW, 1, parts.get("rig"), SoloVat.turn(Vector3.UP, 1.0, into, out)],
	]
	for k in ARMS.size():
		var a := String(ARMS[k])
		var s := 1.0 if a.ends_with("r") else -1.0
		var root: Vector3 = p[StringName("arm_" + a)]
		var hub: Vector3 = p[StringName("rotor_" + a)]
		_joints.append([DROOP0 + k, 2, null, SoloVat.turn(x, s, SoloVat.at(root))])
		_joints.append(
			[
				BREAK,
				_joints.size() - 1,
				parts.get("arm_" + a),
				SoloVat.slide(Vector3(0, -0.05, s) * BREAK_M)
			]
		)
		_joints.append(
			[
				ROTOR,
				_joints.size() - 1,
				parts.get("rotor_" + a),
				SoloVat.turn(Vector3.UP, SPIN_SIGN[k], SoloVat.at(hub - root))
			]
		)
	var cradle: Vector3 = p[&"cradle"]
	_joints.append(
		[
			CLAW,
			2,
			parts.get("cradle"),
			SoloVat.stretch_by(Vector3.ONE, CLAW_OPEN, SoloVat.at(cradle))
		]
	)
	_joints.append([BOMB_S, 2, parts.get("bomb"), BombDroneAvatar._sling])


## The bomb's make: slung at BOMB_AT at 1, sunk BOMB_DROP under it and folded to a point at 0 (both linear in the
## value, so the vertices are too).
static func _sling(v: Array) -> Transform3D:
	var s := float(v[0])
	return Transform3D(
		Basis.from_scale(Vector3.ONE * s), BOMB_AT + Vector3(0, -BOMB_DROP * (1.0 - s), 0)
	)


# --- Sync ---------------------------------------------------------------------------------------------------------
func sync(reader: WorldReader, i: int) -> void:
	apply_state(
		{
			"tick": reader.tick(),
			"state": reader.actor_state(i),
			"pos": reader.actor_pos(i),
			"hp": reader.actor_hp(i),
		}
	)


## The same as sync(), from plain values (tests and tools): tick, state, pos (the sim plane), hp. Missing keys: at rest.
func apply_state(s: Dictionary) -> void:
	_touch()
	var was := _state
	_state = int(s.get("state", WorldReader.STATE_MOVE))
	var hp: int = s.get("hp", -1)
	if not _fresh and hp >= 0 and _hp >= 0 and hp < _hp:
		_hurt_t = 0.0
		_hurt_side = -_hurt_side
	_hp = hp
	if _state == WorldReader.STATE_WINDUP and was != WorldReader.STATE_WINDUP and not _fresh:
		_lob_s = 0.0
	_track_motion(int(s.get("tick", 0)), s.get("pos", Vector2.ZERO) as Vector2, 12.0)
	if _fresh:
		_fresh = false
		_rise = 0.0 if _state == WorldReader.STATE_SPAWN else 1.0
		_spin = SPIN * (0.3 if _rise < 1.0 else 1.0)
		_pose()


# --- Frame time ---------------------------------------------------------------------------------------------------
func advance(delta: float) -> void:
	_touch()
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0:
		return
	_t += dt
	var dying := _die_t >= 0.0
	var calm := ViewPrefs.reduced_motion
	_turning(dt, dying)
	if dying:
		_die_t += dt
		_armed = move_toward(_armed, 0.0, dt * 6.0)
	else:
		var spawning := _state == WorldReader.STATE_SPAWN
		_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 1.8))
		# The bomb leaves with the windup (the lob) and a new one is slung back under the belly in the recovery.
		var lobbed := _state == WorldReader.STATE_WINDUP or _state == WorldReader.STATE_ACTIVE
		_armed = move_toward(_armed, 0.0 if lobbed else 1.0, dt * (12.0 if lobbed else 1.5))
		var winding := _state == WorldReader.STATE_WINDUP
		_aim = move_toward(_aim, 1.0 if winding else 0.0, dt * (6.0 if winding else 3.0))
	_fuse = 1.0 if _state == WorldReader.STATE_MOVE and not dying else 0.0
	_lob_s = _clip(_lob_s, dt, LOB_S)
	_hurt_t = _clip(_hurt_t, dt, HURT_SECONDS)
	var target := 0.0 if dying else SPIN * (1.0 + SPIN_TELL * _aim) * lerpf(0.3, 1.0, _rise)
	_spin = lerpf(_spin, target * (CALM if calm else 1.0), _rate(2.5 if dying else 4.0, dt))
	_rot = fposmod(_rot + _spin * dt, TAU)
	var v3 := Basis(Vector3.UP, -_last_fy) * SimPlane.to_3d(_vel)
	var local := Vector2(v3.x, v3.z)
	var speed := 0.0 if dying else local.length()
	_glide = lerpf(_glide, clampf(speed / GLIDE_MPS, 0.0, 1.0), _rate(5.0, dt))
	if speed > 0.05:
		_dir = _dir.lerp(local / speed, _rate(8.0, dt)).normalized()
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
	_omega = lerpf(_omega, w, _rate(6.0, dt))
	_last_fy = fy
	_have_fy = true


## Starts the death (ActorViews, when the sim drops it: freed DEATH_SECONDS later). True: it plays.
func die() -> bool:
	_touch()
	if _die_t < 0.0:
		_die_t = 0.0
	return true


func dying() -> bool:
	_peek()
	return _die_t >= 0.0


## The flinch leans the hull about itself, not about the ground under it.
func _flinch_pivot() -> float:
	return HOVER_Y


## The hull's middle's current height above the ground (the hover plus the bob).
func hover_height() -> float:
	_peek()
	return _lift + HULL.y


## True while a bomb hangs in the bay (it is drawn).
func bomb_armed() -> bool:
	_peek()
	return _armed > 0.05


## The raw drives now, the visor's glow, the rotors' spin (rad/s) (tests).
func drives() -> PackedFloat32Array:
	_peek()
	return _vd


func visor_energy() -> float:
	_peek()
	return _visor_mat.emission_energy_multiplier


func spin_rate() -> float:
	_peek()
	return _spin


# --- The pose -----------------------------------------------------------------------------------------------------
## The pose's numbers from the state (_vd, the lift, the glows), then (the code path) the nodes from them.
func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var k := CALM if calm else 1.0
	var d := PackedFloat32Array()
	d.resize(VAT_DRIVES.size())
	var dead := _die_t >= 0.0
	var die_u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0) if dead else 0.0
	var fall := smoothstep(0.1, 0.6, die_u) if dead else 0.0
	var free := 1.0 - fall
	var bob := (0.0 if calm else sin(_t * TAU * BOB_HZ) * BOB_M) * free
	var lift := lerpf(LIFT_GROUND, LIFT, _rise) + bob
	# The hover: a soft rock, the arms and claws quivering.
	d[ROLL] += 0.06 * k * free * sin(_t * 1.3)
	d[PITCH] += 0.05 * k * free * sin(_t * 1.7)
	for a in ARMS.size():
		d[DROOP0 + a] += 0.04 * k * free * sin(_t * 2.3 + 1.6 * a)
	d[CLAW] += 0.06 * k * free * (0.5 + 0.5 * sin(_t * 1.1))
	_glide_pose(d, k * free)
	lift += _lob_pose(d, calm)
	lift += _hurt_pose(d, k, calm)
	# The rise-in: the arms unfold from tucked (the upper pair folded down, the lower up) as it lifts off.
	var fold := (1.0 - _rise) * (1.0 - _rise) * (0.0 if dead else 1.0)
	for a in ARMS.size():
		d[DROOP0 + a] += fold * (0.6 if a < 2 else -0.5)
	d[CLAW] += 1.0 - _armed
	d[BOMB_S] = maxf(_armed, 0.05) if bomb_armed() else 0.0
	var visor := VISOR_REST + VISOR_TELL * _aim
	if _aim > 0.0 and not calm:  # the gem flickers as the circle fills
		visor += 0.6 * _aim * sin(_t * TAU * 7.0)
	visor *= lerpf(0.4, 1.0, _rise)
	if dead:
		lift = _death_pose(d, die_u, fall, lift)
		var flare := sin(PI * clampf(die_u / 0.2, 0.0, 1.0))
		visor = (visor + 2.0 * flare) * (1.0 - smoothstep(0.35, 0.8, die_u))
	for j in VAT_DRIVES.size():
		var spec: Array = VAT_DRIVES[j]
		if not bool(spec[2]) and float(spec[1]) > float(spec[0]):
			d[j] = clampf(d[j], spec[0], spec[1])
	d[ROTOR] = _rot
	d[VISOR] = visor
	_vd = d
	_lift = lift
	_visor_mat.emission_energy_multiplier = visor
	_fuse_mat.emission_energy_multiplier = 0.8 + _fuse * (1.5 + sin(_t * 12.0) * 1.2)
	var sh := lerpf(0.6, 1.0, _rise) * (1.0 - bob * 0.8)
	shadow.scale = Vector3(sh, 1, sh)
	if not vat and not parts.is_empty():
		_apply()


## The glide: the nose tipped into the travel, banked into a sideways one; the turn: banked into it, the hull trailing.
func _glide_pose(d: PackedFloat32Array, s: float) -> void:
	var g := _glide * s
	d[PITCH] += 0.28 * g * _dir.x
	d[ROLL] += 0.25 * g * _dir.y
	var w := clampf(_omega / TURN_REF, -1.0, 1.0) * s
	d[ROLL] -= 0.3 * w
	d[YAW] -= 0.25 * w
	for a in ARMS.size():  # the arms lag a little behind the bank
		d[DROOP0 + a] += 0.1 * w * (1.0 if String(ARMS[a]).ends_with("r") else -1.0)


## The throw (the windup's start): the nose snaps down to fling the bomb, then it kicks up, lighter. Returns the lift's
## change.
func _lob_pose(d: PackedFloat32Array, calm: bool) -> float:
	if _lob_s < 0.0:
		return 0.0
	var u := _lob_s / LOB_S
	var snap := sin(PI * clampf(u / 0.4, 0.0, 1.0))
	var kick := sin(PI * clampf((u - 0.25) / 0.75, 0.0, 1.0))
	var k := 0.5 if calm else 1.0
	d[PITCH] += (0.45 * snap - 0.2 * kick) * k
	for a in ARMS.size():
		d[DROOP0 + a] -= 0.15 * snap * k
	return 0.12 * kick * k


## A hit: it sags in the air and bobs back up in damped swings, rolled to one side, the arms flapping; with reduced
## motion one eased dip and back. Returns the lift's change.
func _hurt_pose(d: PackedFloat32Array, s: float, calm: bool) -> float:
	if _hurt_t < 0.0:
		return 0.0
	var u := _hurt_t / HURT_SECONDS
	var env := (1.0 - smoothstep(0.0, 1.0, u)) * smoothstep(0.0, 0.05, u)
	var swing := cos(TAU * 2.0 * _hurt_t)
	if calm:
		swing = 1.0
		env = sin(PI * clampf(u / 0.7, 0.0, 1.0))
	d[ROLL] += 0.3 * _hurt_side * env * swing * s
	d[PITCH] -= 0.15 * env * swing * s
	for a in ARMS.size():
		d[DROOP0 + a] += 0.3 * env * swing * s
	return -0.12 * env * (0.5 + 0.5 * swing)


## The death: a jolt, then it tips over to one side and falls to the floor; on the impact the arms break off and splay
## out (the upper ones fall, more on the high side; the lower ones splay flat on the low side and drop on the high one),
## the claws burst open. Returns the lift.
func _death_pose(d: PackedFloat32Array, u: float, fall: float, lift: float) -> float:
	var jolt := sin(PI * clampf(u / 0.15, 0.0, 1.0))
	d[ROLL] += (0.2 * jolt + 0.3 * fall) * _hurt_side
	d[PITCH] += -0.25 * jolt + 0.2 * fall
	var brk := smoothstep(0.5, 0.85, u)
	d[BREAK] = brk
	for a in ARMS.size():
		var low := (1.0 if String(ARMS[a]).ends_with("r") else -1.0) == _hurt_side
		var drop := (0.9 if low else 1.4) if a < 2 else (-0.4 if low else 0.35)
		d[DROOP0 + a] += 0.3 * jolt + drop * brk
	d[CLAW] = maxf(d[CLAW], smoothstep(0.45, 0.7, u))
	return lerpf(lift, LIFT_DEAD, fall * fall)


## The nodes from the drives: each frame node's transform is its joints' makes composed since its parent frame (a
## frame with no frame above it with the lift under it), as the VAT rig chains them. A bomb let go is hidden, its frame
## left at the point it folds to (what the VAT crowd draws for it).
func _apply() -> void:
	var acc: Array[Transform3D] = []
	acc.resize(_joints.size())
	var top: Array[bool] = []
	top.resize(_joints.size())
	var up := Transform3D(Basis.IDENTITY, Vector3(0, _lift, 0))
	for j in _joints.size():
		var jt: Array = _joints[j]
		var parent: int = jt[1]
		var base := Transform3D.IDENTITY
		top[j] = parent < 0 or (top[parent] and (_joints[parent] as Array)[2] == null)
		if parent >= 0 and (_joints[parent] as Array)[2] == null:
			base = acc[parent]
		acc[j] = base * (jt[3] as Callable).call([_vd[jt[0]]])
		var frame: Node3D = jt[2]
		if frame == null:
			continue
		var xf := up * acc[j] if top[j] else acc[j]
		if frame == bomb and _vd[BOMB_S] <= 0.0:
			xf = Transform3D(Basis.IDENTITY, xf.origin)
		frame.transform = xf
	bomb.visible = bomb_armed()


# --- SoloVat: the VAT rig -----------------------------------------------------------------------------------------
## The whole body's lift (m): VatCrowd moves the instance by it (the ground disc is its own node).
func vat_lift() -> float:
	_peek()
	return _lift


func vat_drives() -> PackedFloat32Array:
	_peek()
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The visor's glow (the instance's accent glow and its VISOR drive; the bomb's iron has none, the fuse is unshaded).
func glow_energy() -> float:
	_peek()
	return _visor_mat.emission_energy_multiplier


## The owner's colour map (VatLooks' textured variant), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## One grid per drive but the visor's, the joints as the table.
func vat_rig() -> Dictionary:
	var grids: Array = []
	for d in VAT_SAMPLES.size():
		grids.append([[d, VAT_SAMPLES[d]]])
	var key := "bomb_drone_" + ("model" if has_model else "code")
	var out := SoloVat.rig(key, VAT_DRIVES, grids, _joints, true)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out
