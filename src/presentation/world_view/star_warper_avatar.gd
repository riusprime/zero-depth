class_name StarWarperAvatar
extends AvatarBase
## The Star Warper (ENEMIES.md R9: "Marks a star on the floor beside you, then 1 s later blinks onto it and strikes") on
## the owner's model (EnemyModels &"star_warper", cut by scripts/assets/star_warper_prep.py into the torso, the star
## head with its visor, each arm's upper half and forearm with its blade claws, the tail in three segments and three
## star shards), animated in code from the sim's state and drawn by the VAT crowd (SoloVat) while the switch is on.
## The model has no legs; the owner: it "might be a \"floating\" creature", and "if there is floating enemies ... make
## sure to animate them and give them some movement, these models can not walk or be static models that look out of
## place". So it floats HOVER_LIFT over the sim's own place and path at the sim's speed (nothing in the sim changes).
## Its clips, each read from the sim through WorldReader (sync) and played in frame time (advance):
## - idle hover: it bobs, swaying a little, the tail waving down its length like a wisp, the arms drifting with the
##   claws flexing, the star tilting, the shards circling the head round the face's axis;
## - the glide (the sim moving it): it leans into the travel and banks into a sideways one, the tail trailing behind
##   and whipping faster, the arms swept back;
## - the turn (the facing node turning): the body trails the turn, the tail swings out after it;
## - the tell (its windup, the star on the floor): the arms drawn back and up with the blade claws cocked, the head
##   tipped back, the tail coiling under, it rises; the shards spin faster and draw in and the star's glow (the visor,
##   the shards) brightens; over the windup's last DISSOLVE_FROM it breaks into its star shards: the body shrinks away
##   to nothing while the shards fly out (StarfallViews puts the pack's shatter burst where it vanished);
## - the strike (entering ACTIVE, on its mark): it reforms out of the shards as the claws slash forward and down, the
##   body lunging, then settles through RECOVER;
## - the stun (the hero stood on the star, WorldReader.warper_stunned): it reforms where it stands and reels, sagging
##   in the air with a slow wobble, its star dim;
## - a hit (its HP fell): it sags in the air and wobbles back up in damped swings, the head jerked;
## - the death (die(): DEATH_SECONDS): a jolt and a flare, it slumps and drops toward the floor limp, then breaks into
##   its shards and is gone;
## - the rise-in (SPAWN): it forms out of its shards, rising to its hover;
## - reduced motion (ViewPrefs.reduced_motion): no bob and no orbit, the sways at CALM of their size, a hit eased once.
## The pose is a few plain numbers (the raw drives, _vd) worked out from the state first, then the nodes from them
## through the joint table (_joints, the same transforms the VAT rig declares), so the baked pose is the live one.
## On the VAT crowd it is batched (EnemyBatch: nothing here reads the tree, its turn is its facing node's; its ground
## disc hangs in the tree from the batch's holder, BatchStarWarper), and the native batch runs the same sync, frame
## step and pose (native/src/zd_avatar_star_warper.cpp).
## Presentation only (EI-07): nothing here reaches the sim. +X is the front, +Z its right.

const KIND := WorldReader.KIND_STAR_WARPER
const MODEL := &"star_warper"
## The model's own height (m; EnemyModels scales it to this: the stand-in's), the lift it floats at (the tail's tip
## that far off the floor), the health bar's height.
const MODEL_HEIGHT := 1.15
const HOVER_LIFT := 0.22
const HEIGHT := 1.5
## Its colours: the request's violet on the plates (greyscale in the map), the visor's and the shards' glows.
const COLOR := Color("#8A50D8")
const VISOR_COLOR := Color("#E2C4FF")
const VISOR_GLOW := Color("#B07CFF")
const SHARD_COLOR := Color("#C9A2FF")
const SHARD_GLOW := Color("#9A5CFF")
const TRIM := Color("#2E2A34")
const GREY := Color("#6E6A74")
## The glows: the shards' at rest and what the tell adds; the visor's at rest and what the tell adds.
const SHARD_REST := 1.2
const SHARD_TELL := 4.0
const VISOR_REST := 1.5
const VISOR_TELL := 3.5
## The clips' lengths (s): the strike (its snap, its hold, the settle after), a hit's wobble, the death.
const SLASH_SNAP_S := 0.08
const SLASH_HOLD_S := 0.14
const SLASH_END_S := 0.8
const HURT_SECONDS := 0.8
const DEATH_SECONDS := 1.2
## The windup's share past which it breaks into shards; the smallest it shrinks to; the rate it reforms (a second).
const DISSOLVE_FROM := 0.86
const FORM_MIN := 0.06
const REFORM_RATE := 7.0
## The bob (Hz), the tail's wave (Hz at rest, at full glide), the shards' turn (rad/s), the glide's full speed (m/s:
## the sim's), the turn rate (rad/s) of a full trail. Reduced motion: CALM.
const BOB_HZ := 0.55
const WAVE_HZ := 0.6
const WAVE_GLIDE_HZ := 1.4
const ORBIT_RATE := 1.4
const GLIDE_MPS := 3.0
const TURN_REF := 3.0
const CALM := 0.4
## How far a shard flies out at SCATTER 1 (m), and how much of it is up.
const SCATTER_M := 0.6
## The pivots (m, the model's frame) when the model is missing (the prep's own); the body's middle (the rig turns and
## shrinks about it).
const PIVOTS := {
	&"torso": Vector3(0.0, 0.345, 0.0),
	&"head": Vector3(0.034, 0.69, 0.0),
	&"arm_l_u": Vector3(0.023, 0.65, -0.098),
	&"arm_l_l": Vector3(0.006, 0.569, -0.23),
	&"arm_r_u": Vector3(0.023, 0.65, 0.098),
	&"arm_r_l": Vector3(0.006, 0.569, 0.23),
	&"tail_a": Vector3(0.0, 0.345, 0.0),
	&"tail_b": Vector3(-0.098, 0.23, 0.034),
	&"tail_c": Vector3(-0.167, 0.127, 0.081),
	&"shard_0": Vector3(0.034, 0.897, 0.0),
	&"shard_1": Vector3(0.034, 0.897, 0.0),
	&"shard_2": Vector3(0.034, 0.897, 0.0),
}
const MIDDLE := Vector3(0.0, 0.55, 0.0)
## The shards (and their places when the model is missing: m, the model's frame).
const SHARDS: Array[StringName] = [&"shard_0", &"shard_1", &"shard_2"]
const SHARD_AT := [Vector3(0.0, 0.8, -0.3), Vector3(0.0, 1.07, -0.12), Vector3(0.0, 0.8, 0.3)]
const TAILS: Array[StringName] = [&"tail_a", &"tail_b", &"tail_c"]

## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]: the body's roll, pitch (+ leaning forward) and yaw
## about its middle, its form (the shrink into shards: 0 whole, -1 gone); the head's nod (+ forward) and tilt; per arm
## (left, right) its sweep (+ forward), raise (+ up) and elbow (+ the claws swung forward); per tail segment its swing
## (+ back) and sway (+ right); the shards' turn round the face's axis (a loop) and their flight out (+) or in (-); the
## visor's glow (sent as is).
const ROLL := 0
const PITCH := 1
const YAW := 2
const FORM := 3
const HEAD_F := 4
const HEAD_S := 5
const ARM_L := 6
const ARM_R := 9
const SWEEP := 0
const RAISE := 1
const ELBOW := 2
const TAIL0 := 12
const SWING := 0
const SWAY := 1
const ORBIT := 18
const SCATTER := 19
const VISOR := 20
const VAT_DRIVES := [
	[-0.9, 0.9, false],
	[-0.6, 0.7, false],
	[-0.7, 0.7, false],
	[-1.0, 0.0, false],
	[-0.7, 0.8, false],
	[-0.7, 0.7, false],
	[-1.2, 1.4, false],
	[-0.8, 0.9, false],
	[-0.5, 1.4, false],
	[-1.2, 1.4, false],
	[-0.8, 0.9, false],
	[-0.5, 1.4, false],
	[-0.8, 1.0, false],
	[-0.7, 0.7, false],
	[-0.9, 1.1, false],
	[-0.8, 0.8, false],
	[-1.0, 1.2, false],
	[-0.9, 0.9, false],
	[0.0, TAU, true],
	[-0.5, 1.0, false],
	[0.0, 0.0, false],
]
## Each drive's samples (a turn finely, the wide ones finest; the form's stretch and the shards' slide linear: exact on
## two).
const VAT_SAMPLES := [41, 33, 33, 2, 41, 33, 57, 41, 49, 57, 41, 49, 41, 33, 41, 41, 49, 41, 73, 2]
## The tell's and the strike's poses at full weight: [drive, value]. Starting values, tuned on the clip sheet
## (scripts/shots/star_warper_clips.gd).
const TELL_POSE := [
	[ARM_L + SWEEP, -0.9],
	[ARM_R + SWEEP, -0.9],
	[ARM_L + RAISE, 0.55],
	[ARM_R + RAISE, 0.55],
	[ARM_L + ELBOW, 0.9],
	[ARM_R + ELBOW, 0.9],
	[HEAD_F, -0.35],
	[PITCH, -0.18],
	[TAIL0 + SWING, -0.35],
	[TAIL0 + 2 + SWING, 0.5],
	[TAIL0 + 4 + SWING, 0.7],
	[SCATTER, -0.35],
]
const TELL_LIFT := 0.1
const STRIKE_POSE := [
	[ARM_L + SWEEP, 1.15],
	[ARM_R + SWEEP, 1.15],
	[ARM_L + RAISE, -0.45],
	[ARM_R + RAISE, -0.45],
	[ARM_L + ELBOW, 1.2],
	[ARM_R + ELBOW, 1.2],
	[HEAD_F, 0.15],
	[PITCH, 0.25],
	[TAIL0 + SWING, 0.6],
	[TAIL0 + 2 + SWING, 0.5],
	[TAIL0 + 4 + SWING, 0.4],
]
const STRIKE_LIFT := -0.08

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds no nodes.
var vat := false
var kind := KIND
var height := HEIGHT
## True when the body is the owner's model (else the code-made stand-in on the same joints).
var has_model := false
## The joints' frame nodes by part name (tests): rig, head, arm_l_u, arm_l_l, arm_r_u, arm_r_l, tail_a..c, shard_0..2
## (none on a VAT avatar); the ground disc (kept live on VAT).
var parts := {}
var shadow: MeshInstance3D

var _vd := PackedFloat32Array()
var _lift := HOVER_LIFT
var _shard_glow := SHARD_REST
var _shard_mat := StandardMaterial3D.new()
var _visor_mat := StandardMaterial3D.new()
var _pivots := PIVOTS.duplicate()
## Each shard's way out from the head's middle (unit, in the face's plane).
var _shard_out: Array[Vector3] = []
## The joint table: [grid, parent joint, frame node or null, make (SoloVat's)], a parent before its children.
var _joints: Array = []
# The state the pose is made from (sync and advance keep it; VatVerify.sample sets it): the sim's state, the windup's
# progress (0..1), stunned, HP, the form now (0 whole, 1 gone), seconds into the strike (-1: none), the rise-in, the
# reel (0..1), the glide's share and direction (the facing's frame: x forward, y right), the tail's wave phase, the
# shards' turn, the facing's turn rate, a hit's clip and side, the death.
var _state := WorldReader.STATE_SPAWN
var _wind := 0.0
var _stun := false
var _hp := -1
var _gone := 1.0
var _slash_s := -1.0
var _rise := 0.0
var _reel := 0.0
var _glide := 0.0
var _dir := Vector2.RIGHT
var _wave := 0.0
var _orbit := 0.0
var _omega := 0.0
var _hurt_t := -1.0
var _hurt_side := 1.0
var _die_t := -1.0
var _last_fy := 0.0
var _have_fy := false


## Builds the Warper under `facing` for ActorViews (`views`: on VAT while its switch is on) and marks `root` (the
## avatar, its body materials for the hit flash); returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D) -> float:
	var a := StarWarperAvatar.new()
	views._solo_vat(root, a, KIND)
	a.setup()
	facing.add_child(a)
	root.set_meta(&"enemy_avatar", a)
	root.set_meta(&"mats", a.body_materials.duplicate())
	return HEIGHT


func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	for spec: Array in [
		[_shard_mat, SHARD_COLOR, SHARD_GLOW, SHARD_REST],
		[_visor_mat, VISOR_COLOR, VISOR_GLOW, VISOR_REST]
	]:
		var mat: StandardMaterial3D = spec[0]
		mat.albedo_color = spec[1]
		mat.roughness = 1.0
		mat.emission_enabled = true
		mat.emission = spec[2]
		mat.emission_energy_multiplier = spec[3]
	_visor_mat.set_meta(SoloVat.GLOW, VISOR + 1)  # a VAT Warper's visor glows at its VISOR drive
	_build_shadow()
	var m := EnemyModels.get_model(MODEL)
	has_model = not m.is_empty()
	var shard_at: Array = SHARD_AT.duplicate()
	if has_model:
		var parts_in: Dictionary = m["parts"]
		for pname: StringName in parts_in:
			_pivots[pname] = (parts_in[pname] as Dictionary)["pivot"] * float(m["scale"])
		for k in SHARDS.size():
			var part: Dictionary = parts_in.get(SHARDS[k], {})
			if not part.is_empty():
				var box := (part["mesh"] as Mesh).get_aabb()
				shard_at[k] = (_pivots[SHARDS[k]] as Vector3) + box.get_center() * float(m["scale"])
	for k in SHARDS.size():
		var out: Vector3 = (shard_at[k] as Vector3) - (_pivots[SHARDS[k]] as Vector3)
		out.x = 0.0
		_shard_out.append(out.normalized() if out.length() > 0.02 else Vector3.UP)
	if not vat:
		_build_frames()
		if has_model:
			_build_model(m)
		else:
			_build_code()
	_build_joints()
	_pose()


## The ground disc under it (kept live on VAT: the crowd draws only the body), smaller the higher it floats.
func _build_shadow() -> void:
	shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.34
	disc.bottom_radius = 0.34
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


## The frame nodes, nested as the joint table chains them (the shards beside the rig: they do not shrink with it).
func _build_frames() -> void:
	var rig := _frame("rig", null)
	_frame("head", rig)
	for side in ["l", "r"]:
		var upper := _frame("arm_%s_u" % side, rig)
		_frame("arm_%s_l" % side, upper)
	var tail := rig
	for t in TAILS:
		tail = _frame(String(t), tail)
	for s in SHARDS:
		_frame(String(s), null)


## The owner's model: each part's mesh in its frame (its pivot at the frame's origin), its surfaces on the base / role
## plates (the role plates greyscale in the map, tinted COLOR) and its glows (the visor on the head, the shards).
func _build_model(m: Dictionary) -> void:
	var tex: Texture2D = m["texture"]
	var mats := {}
	for slot: StringName in [&"base", &"role"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = COLOR if slot == &"role" else Color.WHITE
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
			var glow := _shard_mat if SHARDS.has(pname) else _visor_mat
			mi.set_surface_override_material(
				k, glow if surfaces[k] == &"glow" else mats.get(surfaces[k], mats[&"base"])
			)
		var frame: Node3D = parts.get(String(pname), parts["rig"])
		if frame == parts["rig"]:  # the torso hangs on the rig at its own place
			mi.position = _pivots[pname]
		frame.add_child(mi)


## The code-made stand-in (the model file missing): an hourglass body, a five-pointed star head with its visor, thin
## grey arms with bone claws, a three-segment tail and three shards, on the same joints, so every clip still plays.
func _build_code() -> void:
	var rig: Node3D = parts["rig"]
	_body_piece(rig, ArcCasterAvatar._frustum(0.08, 0.16, 0.3, 6), Vector3(0, 0.33, 0), TRIM)
	var head: Node3D = parts["head"]
	for k in 5:
		var a := TAU * k / 5.0
		var arm := _body_piece(
			head, BossParts.crystal(0.24, 0.07, 95 + k), Vector3(0, 0.1, 0), COLOR
		)
		arm.rotation = Vector3(a, 0, 0)
	var gem := MeshInstance3D.new()
	gem.mesh = NeedleAvatar._chamfer_box(Vector3(0.03, 0.06, 0.06), 0.01)
	gem.position = Vector3(0.1, 0.06, 0)
	gem.material_override = _visor_mat
	head.add_child(gem)
	for side in ["l", "r"]:
		var s := -1.0 if side == "l" else 1.0
		_body_piece(
			parts["arm_%s_u" % side],
			NeedleAvatar._chamfer_box(Vector3(0.05, 0.05, 0.14), 0.01),
			Vector3(0, -0.03, 0.06 * s),
			GREY
		)
		_body_piece(
			parts["arm_%s_l" % side],
			NeedleAvatar._chamfer_box(Vector3(0.05, 0.3, 0.05), 0.01),
			Vector3(0.03, -0.12, 0.12 * s),
			GREY
		)
	for k in TAILS.size():
		_body_piece(
			parts[String(TAILS[k])],
			ArcCasterAvatar._frustum(0.035 - 0.008 * k, 0.05 - 0.01 * k, 0.11, 5),
			Vector3(-0.03, -0.11, 0),
			GREY
		)
	for k in SHARDS.size():
		var mi := MeshInstance3D.new()
		mi.mesh = ArcCasterAvatar._octahedron(0.045)
		mi.position = (SHARD_AT[k] as Vector3) - (_pivots[SHARDS[k]] as Vector3)
		mi.material_override = _shard_mat
		parts[String(SHARDS[k])].add_child(mi)


## The joint table (see _joints): the body's roll, pitch and yaw about its middle and its form (a stretch there: the
## rig); the head's nod and tilt at the neck; each arm's sweep and raise at the shoulder and its elbow; the tail's
## segments' swing and sway at their joints; each shard's turn round the face's axis through the head's middle (after
## the yaw, not the form) and its slide out.
func _build_joints() -> void:
	var p := _pivots
	var into := SoloVat.at(MIDDLE)
	var out := SoloVat.at(-MIDDLE)
	var x := Vector3.RIGHT
	var z := Vector3.BACK
	_joints = [
		[ROLL, -1, null, SoloVat.turn(x, 1.0, into, out)],
		[PITCH, 0, null, SoloVat.turn(z, -1.0, into, out)],
		[YAW, 1, null, SoloVat.turn(Vector3.UP, 1.0, into, out)],
		[FORM, 2, null, SoloVat.stretch_by(Vector3.ONE, Vector3.ONE * (1.0 - FORM_MIN), into)],
		[FORM, 3, parts.get("rig"), SoloVat.slide(Vector3.ZERO, -MIDDLE)],
		[HEAD_F, 4, null, SoloVat.turn(z, -1.0, SoloVat.at(p[&"head"]))],
		[HEAD_S, 5, parts.get("head"), SoloVat.turn(x)],
	]
	for side in 2:
		var d := ARM_L if side == 0 else ARM_R
		var s := -1.0 if side == 0 else 1.0
		var nm := "l" if side == 0 else "r"
		var shoulder: Vector3 = p[StringName("arm_%s_u" % nm)]
		var elbow: Vector3 = p[StringName("arm_%s_l" % nm)]
		_joints.append([d + SWEEP, 4, null, SoloVat.turn(Vector3.UP, s, SoloVat.at(shoulder))])
		_joints.append(
			[d + RAISE, _joints.size() - 1, parts.get("arm_%s_u" % nm), SoloVat.turn(x, -s)]
		)
		_joints.append(
			[
				d + ELBOW,
				_joints.size() - 1,
				parts.get("arm_%s_l" % nm),
				SoloVat.turn(Vector3.UP, s, SoloVat.at(elbow - shoulder))
			]
		)
	var parent := 4
	var at := Vector3.ZERO
	for k in TAILS.size():
		var pivot: Vector3 = p[TAILS[k]]
		_joints.append(
			[TAIL0 + 2 * k + SWING, parent, null, SoloVat.turn(z, -1.0, SoloVat.at(pivot - at))]
		)
		_joints.append(
			[TAIL0 + 2 * k + SWAY, _joints.size() - 1, parts.get(String(TAILS[k])), SoloVat.turn(x)]
		)
		parent = _joints.size() - 1
		at = pivot
	for k in SHARDS.size():
		_joints.append([ORBIT, 2, null, SoloVat.turn(x, 1.0, SoloVat.at(p[SHARDS[k]]))])
		_joints.append(
			[
				SCATTER,
				_joints.size() - 1,
				parts.get(String(SHARDS[k])),
				SoloVat.slide(_shard_out[k] * SCATTER_M)
			]
		)


# --- Sync ---------------------------------------------------------------------------------------------------------
func sync(reader: WorldReader, i: int) -> void:
	var s := {
		"tick": reader.tick(),
		"state": reader.actor_state(i),
		"pos": reader.actor_pos(i),
		"hp": reader.actor_hp(i),
		"stunned": reader.warper_stunned(i),
	}
	if reader.actor_state(i) == WorldReader.STATE_WINDUP:
		s["windup"] = windup_progress(reader, i)
	apply_state(s)


## The same as sync(), from plain values (tests and tools): tick, state, pos (the sim plane), hp, stunned, windup
## (0..1). Missing keys: at rest.
func apply_state(s: Dictionary) -> void:
	_touch()
	var was := _state
	_state = int(s.get("state", WorldReader.STATE_MOVE))
	_wind = (
		clampf(float(s.get("windup", 0.0)), 0.0, 1.0) if _state == WorldReader.STATE_WINDUP else 0.0
	)
	_stun = bool(s.get("stunned", false))
	var hp: int = s.get("hp", -1)
	if not _fresh and hp >= 0 and _hp >= 0 and hp < _hp:
		_hurt_t = 0.0
		_hurt_side = -_hurt_side
	_hp = hp
	if _state == WorldReader.STATE_ACTIVE and was != WorldReader.STATE_ACTIVE:
		_slash_s = 0.0  # the blink: it reforms on its mark, striking
	# The blink moves it to its mark in one tick: no glide out of that (AvatarBase's teleport speed).
	_track_motion(int(s.get("tick", 0)), s.get("pos", Vector2.ZERO) as Vector2, 12.0)
	if _fresh:
		_fresh = false
		var spawning := _state == WorldReader.STATE_SPAWN
		_rise = 0.0 if spawning else 1.0
		_gone = 1.0 if spawning else 0.0
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
	if not dying:
		var spawning := _state == WorldReader.STATE_SPAWN
		_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * 1.5)
		# The form: whole, broken into shards through the windup's end, reforming fast after (on its mark, or where it
		# stands when the blink was cancelled); formed out of the shards as it rises in.
		var gone := 0.0
		if _state == WorldReader.STATE_WINDUP:
			gone = smoothstep(DISSOLVE_FROM, 1.0, _wind)
		elif spawning:
			gone = 1.0 - smoothstep(0.0, 0.8, _rise)
		_gone = gone if gone > _gone else move_toward(_gone, gone, dt * REFORM_RATE)
		_reel = move_toward(_reel, 1.0 if _stun else 0.0, dt * 4.0)
	if _slash_s >= 0.0:
		_slash_s += dt
		if _slash_s >= SLASH_END_S:
			_slash_s = -1.0
	_hurt_t = _clip(_hurt_t, dt, HURT_SECONDS)
	if dying:
		_die_t += dt
	var v3 := Basis(Vector3.UP, -_last_fy) * SimPlane.to_3d(_vel)
	var local := Vector2(v3.x, v3.z)
	var speed := 0.0 if dying else local.length()
	_glide = lerpf(_glide, clampf(speed / GLIDE_MPS, 0.0, 1.0), _rate(6.0, dt))
	if speed > 0.05:
		_dir = _dir.lerp(local / speed, _rate(8.0, dt)).normalized()
	_wave = fposmod(
		_wave + TAU * lerpf(WAVE_HZ, WAVE_GLIDE_HZ, _glide) * dt * (CALM if calm else 1.0), TAU
	)
	if not calm and not dying:
		var spin := ORBIT_RATE * (1.0 + 3.0 * _wind) * (1.0 - 0.7 * _reel)
		_orbit = fposmod(_orbit + spin * dt, TAU)
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


## 0..1: the tell shown (the windup's progress), how far it has broken into shards (tests, the e2e).
func tell_pose() -> float:
	_peek()
	return _wind


func gone() -> float:
	_peek()
	return _gone


## The raw drives now, the visor's glow (tests).
func drives() -> PackedFloat32Array:
	_peek()
	return _vd


func visor_energy() -> float:
	_peek()
	return _visor_mat.emission_energy_multiplier


# --- The pose -----------------------------------------------------------------------------------------------------
## The pose's numbers from the state (_vd, the lift, the glows), then (the code path) the nodes from them.
func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var k := CALM if calm else 1.0
	var d := PackedFloat32Array()
	d.resize(VAT_DRIVES.size())
	var dead := _die_t >= 0.0
	var die_u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0) if dead else 0.0
	var limp := smoothstep(0.1, 0.55, die_u) if dead else 0.0
	var tell := smoothstep(0.0, 0.85, _wind)
	var strike := _slash_weight(calm)
	var busy := clampf(maxf(tell, strike), 0.0, 1.0)
	var free := (1.0 - 0.6 * busy) * (1.0 - limp)
	var lift := HOVER_LIFT + (0.0 if calm else 0.05 * sin(TAU * BOB_HZ * _t)) * free
	_hover_pose(d, k * free)
	_glide_pose(d, k * (1.0 - limp))
	_turn_pose(d, k * (1.0 - limp))
	_add(d, TELL_POSE, tell)
	lift += TELL_LIFT * tell
	_add(d, STRIKE_POSE, strike)
	lift += STRIKE_LIFT * strike
	lift += _reel_pose(d, k, calm)
	lift += _hurt_pose(d, k, calm)
	if _rise < 1.0 and not dead:  # the rise-in: forming, rising to its hover
		lift = lerpf(lift, 0.08, (1.0 - _rise) * (1.0 - _rise))
	var gone := _gone
	if dead:
		lift = _death_pose(d, die_u, limp, calm, lift)
		gone = maxf(gone, smoothstep(0.55, 1.0, die_u))
	d[FORM] = -gone
	d[SCATTER] = lerpf(d[SCATTER], 1.0, gone)
	for j in VAT_DRIVES.size():
		var spec: Array = VAT_DRIVES[j]
		if not bool(spec[2]) and float(spec[1]) > float(spec[0]):
			d[j] = clampf(d[j], spec[0], spec[1])
	d[ORBIT] = _orbit
	var glow := SHARD_REST + SHARD_TELL * tell
	var visor := VISOR_REST + VISOR_TELL * tell
	if _wind > 0.6 and not calm:  # the star flickers as it gathers to blink
		visor += 0.8 * sin(_t * TAU * 9.0) * (_wind - 0.6) / 0.4
	var dim := 1.0 - 0.75 * _reel
	glow *= dim * lerpf(0.3, 1.0, _rise)
	visor *= dim * lerpf(0.3, 1.0, _rise)
	if dead:
		var flare := sin(PI * clampf(die_u / 0.2, 0.0, 1.0))
		var out := 1.0 - smoothstep(0.3, 0.9, die_u)
		glow = (glow + 3.0 * flare) * out
		visor = (visor + 2.0 * flare) * out
	d[VISOR] = visor
	_vd = d
	_lift = lift
	_shard_glow = maxf(glow, 0.0)
	_shard_mat.emission_energy_multiplier = _shard_glow
	_visor_mat.emission_energy_multiplier = visor
	var sh := clampf(1.25 - 0.3 * _lift / HOVER_LIFT, 0.5, 1.2) * (1.0 - 0.8 * gone)
	shadow.scale = Vector3(sh, 1, sh)
	if not vat and not parts.is_empty():
		_apply()


## The strike's weight now: the snap, the hold, the settle (with a small overshoot unless calm).
func _slash_weight(calm: bool) -> float:
	if _slash_s < 0.0:
		return 0.0
	var e := _slash_s
	if e < SLASH_SNAP_S:
		return e / SLASH_SNAP_S
	if e < SLASH_SNAP_S + SLASH_HOLD_S:
		return 1.0
	var u := (e - SLASH_SNAP_S - SLASH_HOLD_S) / (SLASH_END_S - SLASH_SNAP_S - SLASH_HOLD_S)
	return (1.0 - smoothstep(0.0, 1.0, u)) * (1.0 if calm else 1.0 - 0.2 * sin(u * TAU))


## The hover: a slow sway, the tail's wave down its length (each segment a beat behind the one above, wider toward the
## tip), the arms drifting with the claws flexing, the star tilting.
func _hover_pose(d: PackedFloat32Array, s: float) -> void:
	d[ROLL] += 0.06 * s * sin(0.7 * _t)
	d[PITCH] += 0.05 * s * sin(0.55 * _t + 1.0)
	d[HEAD_S] += 0.08 * s * sin(0.45 * _t + 0.4)
	d[HEAD_F] += 0.05 * s * sin(0.6 * _t + 2.0)
	for k in TAILS.size():
		var ph := _wave - 0.9 * k
		d[TAIL0 + 2 * k + SWAY] += (0.14 + 0.08 * k) * s * sin(ph)
		d[TAIL0 + 2 * k + SWING] += (0.08 + 0.04 * k) * s * sin(ph * 0.5 + 0.7)
	for side in 2:
		var a := ARM_L if side == 0 else ARM_R
		var ph := 0.8 * _t + 1.7 * side
		d[a + SWEEP] += 0.08 * s * sin(ph)
		d[a + RAISE] += 0.06 * s * sin(ph * 0.8 + 0.5)
		d[a + ELBOW] += 0.2 * s + 0.12 * s * sin(1.3 * _t + side)


## The glide: leaning into the travel, banking into a sideways one, the tail trailing behind (and out to the side away
## from a sideways one), the arms swept back.
func _glide_pose(d: PackedFloat32Array, s: float) -> void:
	var g := _glide * s
	if g <= 0.0:
		return
	var v := _dir
	d[PITCH] += 0.3 * g * v.x
	d[ROLL] += 0.25 * g * v.y
	d[HEAD_F] -= 0.12 * g * v.x
	for k in TAILS.size():
		d[TAIL0 + 2 * k + SWING] += (0.4 - 0.08 * k) * g * v.x
		d[TAIL0 + 2 * k + SWAY] -= (0.3 + 0.1 * k) * g * v.y
	for side in 2:
		var a := ARM_L if side == 0 else ARM_R
		d[a + SWEEP] -= 0.45 * g * maxf(v.x, 0.0)
		d[a + RAISE] += 0.15 * g


## The turn: the body trails the facing, the tail swings out after it.
func _turn_pose(d: PackedFloat32Array, s: float) -> void:
	var w := clampf(_omega / TURN_REF, -1.0, 1.0)
	d[YAW] -= 0.35 * w * s
	d[ROLL] += 0.1 * w * s
	for k in TAILS.size():
		d[TAIL0 + 2 * k + SWAY] += (0.2 + 0.1 * k) * w * s


## The stun (a cancelled blink): it sags, the head and arms hanging, reeling in a slow wobble. Returns the lift's
## change.
func _reel_pose(d: PackedFloat32Array, s: float, calm: bool) -> float:
	if _reel <= 0.0:
		return 0.0
	var r := smoothstep(0.0, 1.0, _reel)
	var wob := 1.0 if calm else sin(_t * TAU * 1.4)
	d[ROLL] += 0.22 * r * wob * s
	d[PITCH] += 0.14 * r
	d[HEAD_F] += 0.38 * r
	d[HEAD_S] += 0.25 * r * wob * s
	for side in 2:
		var a := ARM_L if side == 0 else ARM_R
		d[a + RAISE] -= 0.45 * r
		d[a + SWEEP] -= 0.1 * r
	return -0.12 * r


## A hit: it sags in the air and bobs back up in damped swings, rolled to one side, the head jerked; with reduced
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
	d[ROLL] += 0.25 * _hurt_side * env * swing * s
	d[PITCH] -= 0.15 * env * swing * s
	d[HEAD_F] -= 0.35 * env * swing
	d[TAIL0 + SWING] += 0.3 * env * swing * s
	return -0.1 * env * (0.5 + 0.5 * swing)


## The death: a jolt, then it slumps limp (the head, the arms and the tail hanging, tipping forward) and drops toward
## the floor, then breaks into its shards (_pose). Returns the lift.
func _death_pose(d: PackedFloat32Array, u: float, limp: float, calm: bool, lift: float) -> float:
	var jolt := sin(PI * clampf(u / 0.2, 0.0, 1.0)) * (0.5 if calm else 1.0)
	d[HEAD_F] += -0.5 * jolt + 0.6 * limp
	d[PITCH] += -0.2 * jolt + 0.4 * limp
	d[ROLL] += 0.3 * limp
	for side in 2:
		var a := ARM_L if side == 0 else ARM_R
		d[a + RAISE] += 0.4 * jolt - 0.6 * limp
		d[a + ELBOW] += 0.6 * limp
	for k in TAILS.size():
		d[TAIL0 + 2 * k + SWING] *= 1.0 - limp
		d[TAIL0 + 2 * k + SWAY] *= 1.0 - limp
	var fall := smoothstep(0.15, 0.6, u)
	return lerpf(lift, 0.06, fall * fall)


static func _add(d: PackedFloat32Array, pose: Array, w: float) -> void:
	if is_zero_approx(w):
		return
	for pair: Array in pose:
		d[int(pair[0])] += float(pair[1]) * w


## The nodes from the drives: each frame node's transform is its joints' makes composed since its parent frame (a
## frame with no frame above it with the lift under it), as the VAT rig chains them.
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
		if frame != null:
			frame.transform = up * acc[j] if top[j] else acc[j]


# --- SoloVat: the VAT rig -----------------------------------------------------------------------------------------
## The whole body's lift (m): VatCrowd moves the instance by it.
func vat_lift() -> float:
	_peek()
	return _lift


func vat_drives() -> PackedFloat32Array:
	_peek()
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The shards' glow (the instance's accent glow; the visor's is the VISOR drive).
func glow_energy() -> float:
	_peek()
	return _shard_glow


## The owner's colour map (VatLooks' textured variant), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## One grid per drive but the visor's, the joints as the table.
func vat_rig() -> Dictionary:
	var grids: Array = []
	for d in VAT_SAMPLES.size():
		grids.append([[d, VAT_SAMPLES[d]]])
	var key := "star_warper_" + ("model" if has_model else "code")
	var out := SoloVat.rig(key, VAT_DRIVES, grids, _joints, true)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out
