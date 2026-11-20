class_name ArcCasterAvatar
extends AvatarBase
## The Arc Caster on the owner's model (EnemyModels &"arc_caster", cut by scripts/assets/arc_caster_prep.py into
## the torso, the robe in two tiers, the hood with its visor, the staff arm, the staff with its crystal, the free arm's
## upper half and forearm, and three rune shards), animated in code from the sim's state and drawn by the VAT crowd
## (SoloVat) while the switch is on. The owner asked for the enemies to be "animated as good as you can, if they can
## have multiple animations ... the better"; a robe has no legs to plant, so it glides with the hem stepping and
## swaying.
## The sim's caster (data/enemies/arc_caster.tres) keeps its distance and casts a bolt, a spread or a rune: each a short
## windup (its telegraph's progress), one shot as it enters ACTIVE, then RECOVER. Its clips, each read from the sim
## through WorldReader (sync) and played in frame time (advance):
## - idle: it hovers a hand's breadth off the floor, bobbing, the robe's tiers swaying a beat behind each other, the
##   free hand turning a slow circle, the shards circling the hood, the crystal breathing;
## - the glide (no legs): the robe leans into the travel and the hem trails it, the hem's tier swinging side to side
##   with each "step" under the robe (a step a STEP_M of travel), a small bob per step, the arms carried;
## - the gather (the windup's progress): the staff is lifted high, the free arm drawn back with the claws cocked, the
##   chest arches back and the hood looks up, the shards spin faster and draw in, the crystal brightens and trembles;
## - the cast (entering ACTIVE): the staff thrust forward crystal first, the free hand flung after it, the body lunging
##   with the robe blown back, the shards flung out, the crystal flaring; it settles back through RECOVER;
## - a hit (AvatarBase's flinch): the hood snaps back, the arms fling, the staff tips, the shards start out;
## - the death (die(): DEATH_SECONDS): a jolt and a last flare, the staff slips and falls across the floor, the figure
##   crumples down into its robe, the shards fly off, the glows going out;
## - the rise-in (SPAWN): it rises up out of its robe, the shards gathering in from afar, the glows lighting;
## - reduced motion (ViewPrefs.reduced_motion): the idle and the glide at CALM of their size, no step bob, no tremble,
##   the shards still (no orbit); the gather and the cast keep their poses (they are the tell).
## The pose is a few plain numbers (the raw drives, _vd) worked out from the state first, then the nodes from them
## through the joint table (_joints, the same transforms the VAT rig declares), so the baked pose is the live one.
## Presentation only (EI-07): nothing here reaches the sim. +X is the front, +Z its right.
## The class also keeps the shape kit other code-made bodies use (_frustum, _octahedron).

const KIND := WorldReader.KIND_ARC_CASTER
const MODEL := &"arc_caster"
## The model's height with the staff (m; EnemyModels scales it to this: the Cinder Priest model it wore before), the
## lift it floats at, the health bar's height.
const MODEL_HEIGHT := 1.75
const HOVER_LIFT := 0.09
const HEIGHT := 1.85
## Its colours: the request's ranged violet on the plates (greyscale in the map), the crystal's and the visor's glows;
## the code-made stand-in's charcoal and grey.
const COLOR := Color("#8A50D8")
const CRYSTAL_COLOR := Color("#E8D2FF")
const CRYSTAL_GLOW := Color("#B985FF")
const VISOR_COLOR := Color("#D7B4FF")
const VISOR_GLOW := Color("#A877FF")
const TRIM := Color("#2A2630")
const GREY := Color("#5A5560")
## The crystal's glow: at rest, what the gather adds, the cast's flare (decaying FLARE_DECAY a second); the visor's.
const CRYSTAL_REST := 1.6
const CRYSTAL_GATHER := 5.0
const CRYSTAL_FLARE := 10.0
const FLARE_DECAY := 5.0
const VISOR_REST := 1.5
## The clips' lengths (s): the cast (its snap, its hold, the settle after), the rise-in, the death.
const CAST_SNAP_S := 0.07
const CAST_HOLD_S := 0.14
const CAST_END_S := 0.9
const SPAWN_SECONDS := 0.7
const DEATH_SECONDS := 1.0
## The idle's bob (Hz), the robe's sway (Hz), the free hand's circle (Hz), the shards' turn (rad/s); the glide's full
## speed (m/s: the sim's), the travel a step takes (m); the turn rate (rad/s) of a full trail. Reduced motion: CALM.
const BOB_HZ := 0.5
const SWAY_HZ := 0.4
const CIRCLE_HZ := 0.5
const ORBIT_RATE := 1.1
const GLIDE_MPS := 3.0
const STEP_M := 0.55
const TURN_REF := 3.0
const CALM := 0.35
## Crumpled fully (CRUMPLE 1), the robe below the waist keeps 1 - CRUMPLE_K of its height (the waist sinks with it so
## the hem stays on the floor) and spreads by CRUMPLE_SPREAD.
const CRUMPLE_K := 0.72
const CRUMPLE_SPREAD := 0.2
## How far a shard flies out at SCATTER 1 (m).
const SCATTER_M := 0.55
## The pivots (m, the model's frame) when the model is missing (the prep's own).
const PIVOTS := {
	&"torso": Vector3(0.0, 0.735, 0.0),
	&"hem_u": Vector3(0.0, 0.735, 0.0),
	&"hem_l": Vector3(0.0, 0.385, 0.0),
	&"hood": Vector3(0.0, 1.129, 0.0),
	&"arm_r": Vector3(-0.03, 1.024, 0.198),
	&"staff": Vector3(0.152, 1.059, 0.436),
	&"arm_l_u": Vector3(-0.038, 1.032, -0.126),
	&"arm_l_l": Vector3(0.005, 0.857, -0.24),
	&"shard_0": Vector3(0.0, 1.419, 0.0),
	&"shard_1": Vector3(0.0, 1.41, 0.0),
	&"shard_2": Vector3(0.0, 1.655, 0.0),
}
## The shards (and their places when the model is missing: m, the model's frame).
const SHARDS: Array[StringName] = [&"shard_0", &"shard_1", &"shard_2"]
const SHARD_AT := [Vector3(0.05, 1.42, 0.2), Vector3(-0.05, 1.41, -0.25), Vector3(-0.07, 1.66, 0.0)]

## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]. F: forward (a top tipping forward, a hanging part
## swinging forward), S: sideways (toward the right, an arm's outward), YAW: the body's trail of a turn, CRUMPLE: the
## robe crumpled (0..1), STAFF_DROP: the staff slipped down in the hand (m), ORBIT: the shards' turn round the hood
## (a loop), SCATTER: the shards out (+) or drawn in (-), VISOR: the visor's glow (sent as is).
const YAW := 0
const LEAN_F := 1
const LEAN_S := 2
const CRUMPLE := 3
const HEM_F := 4
const HEM_S := 5
const HEM_L_F := 6
const HEM_L_S := 7
const TORSO_F := 8
const TORSO_S := 9
const HOOD_F := 10
const HOOD_S := 11
const ARM_R_F := 12
const ARM_R_S := 13
const STAFF_DROP := 14
const STAFF_F := 15
const STAFF_S := 16
const ARM_L_F := 17
const ARM_L_S := 18
const ELBOW_L := 19
const ORBIT := 20
const SCATTER := 21
const VISOR := 22
const VAT_DRIVES := [
	[-1.0, 1.0, false],
	[-0.35, 0.5, false],
	[-0.35, 0.35, false],
	[0.0, 1.0, false],
	[-0.5, 0.5, false],
	[-0.4, 0.4, false],
	[-0.5, 0.5, false],
	[-0.4, 0.4, false],
	[-0.6, 1.0, false],
	[-0.35, 0.35, false],
	[-1.0, 1.0, false],
	[-0.45, 0.45, false],
	[-0.8, 1.7, false],
	[-0.6, 0.8, false],
	[-0.6, 0.8, false],
	[-0.8, 1.8, false],
	[-0.6, 1.6, false],
	[-1.0, 1.8, false],
	[-0.5, 1.4, false],
	[-0.3, 1.8, false],
	[0.0, TAU, true],
	[-0.6, 1.0, false],
	[0.0, 0.0, false],
]
## Each drive's samples (a turn finely, the wide ones finest; a slide or a stretch linear: exact on two).
const VAT_SAMPLES := [
	41, 25, 25, 2, 33, 25, 33, 25, 49, 25, 49, 25, 65, 33, 2, 65, 49, 65, 49, 57, 73, 2
]
## The poses the clips add at full weight: [drive, value] (and their lifts, m). Starting values, tuned on the clip
## sheet (scripts/shots/arc_caster_clips.gd).
const GATHER_POSE := [
	[ARM_R_F, 1.05],
	[ARM_R_S, 0.2],
	[STAFF_F, -0.35],
	[STAFF_DROP, -0.12],
	[TORSO_F, -0.22],
	[HOOD_F, -0.4],
	[LEAN_F, -0.08],
	[HEM_F, 0.08],
	[ARM_L_F, -0.7],
	[ARM_L_S, 0.55],
	[ELBOW_L, 1.1],
	[SCATTER, -0.45],
]
const GATHER_LIFT := 0.1
const CAST_POSE := [
	[ARM_R_F, 1.45],
	[ARM_R_S, -0.1],
	[STAFF_F, 0.95],
	[STAFF_DROP, 0.1],
	[TORSO_F, 0.16],
	[HOOD_F, 0.12],
	[LEAN_F, 0.1],
	[HEM_F, -0.3],
	[HEM_L_F, -0.28],
	[ARM_L_F, 1.45],
	[ARM_L_S, 0.25],
	[ELBOW_L, 0.05],
	[SCATTER, 0.75],
]
const CAST_LIFT := -0.03
const FLINCH_POSE := [
	[HOOD_F, -0.8],
	[TORSO_F, -0.3],
	[HEM_F, 0.12],
	[ARM_L_F, -0.4],
	[ARM_L_S, 0.6],
	[ARM_R_F, 0.25],
	[STAFF_F, -0.3],
	[STAFF_S, -0.2],
	[SCATTER, 0.3],
]

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds no nodes.
var vat := false
var kind := KIND
var height := HEIGHT
## True when the body is the owner's model (else the code-made stand-in on the same joints).
var has_model := false
## The joints' frame nodes by part name (tests): rig, waist, hem_u, hem_l, torso, hood, arm_r, staff, arm_l_u, arm_l_l,
## shard_0..2 (none on a VAT avatar).
var parts := {}

var _vd := PackedFloat32Array()
var _lift := HOVER_LIFT
var _crystal := CRYSTAL_REST
var _crystal_mat := StandardMaterial3D.new()
var _visor_mat := StandardMaterial3D.new()
var _pivots := PIVOTS.duplicate()
## Each shard's way out from the hood's axis (unit, level, in the hood's frame).
var _shard_out: Array[Vector3] = []
## The joint table: [grid, parent joint, frame node or null, make (SoloVat's)], a parent before its children.
var _joints: Array = []
# The state the pose is made from (sync and advance keep it; VatVerify.sample sets it): the sim's state, the windup's
# progress (0..1), seconds into the cast (-1: none), the rise-in (0..1), the glide's share (0..1) and direction (the
# facing's frame: x forward, y right), the step's phase (radians), the shards' turn, the facing's turn rate, the death.
var _state := WorldReader.STATE_SPAWN
var _wind := 0.0
var _cast_s := -1.0
var _rise := 0.0
var _glide := 0.0
var _dir := Vector2.RIGHT
var _step := 0.0
var _orbit := 0.0
var _omega := 0.0
var _die_t := -1.0
var _last_fy := 0.0
var _have_fy := false


## Builds the caster under `facing` for ActorViews (`views`: on VAT while its switch is on) and marks `root` (the
## avatar, its body materials for the hit flash); returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D) -> float:
	var a := ArcCasterAvatar.new()
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
		[_crystal_mat, CRYSTAL_COLOR, CRYSTAL_GLOW, CRYSTAL_REST],
		[_visor_mat, VISOR_COLOR, VISOR_GLOW, VISOR_REST]
	]:
		var mat: StandardMaterial3D = spec[0]
		mat.albedo_color = spec[1]
		mat.roughness = 1.0
		mat.emission_enabled = true
		mat.emission = spec[2]
		mat.emission_energy_multiplier = spec[3]
	_visor_mat.set_meta(SoloVat.GLOW, VISOR + 1)  # a VAT caster's visor glows at its VISOR drive
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
		var out: Vector3 = (shard_at[k] as Vector3) - (_pivots[&"hood"] as Vector3)
		out.y = 0.0
		_shard_out.append(out.normalized() if out.length() > 0.02 else Vector3.BACK)
	if not vat:
		_build_frames()
		if has_model:
			_build_model(m)
		else:
			_build_code()
	_build_joints()
	_pose()


func _frame(pname: String, parent: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = pname.to_pascal_case()
	(self if parent == null else parent).add_child(n)
	parts[pname] = n
	return n


## The frame nodes, nested as the joint table chains them.
func _build_frames() -> void:
	var rig := _frame("rig", null)
	var waist := _frame("waist", rig)
	var hem_u := _frame("hem_u", waist)
	_frame("hem_l", hem_u)
	var torso := _frame("torso", waist)
	var hood := _frame("hood", torso)
	for s in SHARDS:
		_frame(String(s), hood)
	var arm_r := _frame("arm_r", torso)
	_frame("staff", arm_r)
	var arm_l := _frame("arm_l_u", torso)
	_frame("arm_l_l", arm_l)


## The owner's model: each part's mesh in its frame (its pivot at the frame's origin), its surfaces on the base / role
## plates (the role plates greyscale in the map, tinted COLOR) and its glows (the crystal on the staff, the visor).
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
			var glow := _crystal_mat if pname == &"staff" else _visor_mat
			mi.set_surface_override_material(
				k, glow if surfaces[k] == &"glow" else mats.get(surfaces[k], mats[&"base"])
			)
		(parts.get(String(pname), parts["torso"]) as Node3D).add_child(mi)


## The code-made stand-in (the model file missing): a robe of two frustums, a chest, a pointed hood with a visor,
## grey arms, a tall staff with its crystal and three shards on the same joints, so every clip still plays.
func _build_code() -> void:
	var waist: Vector3 = _pivots[&"hem_u"]
	var knee: Vector3 = _pivots[&"hem_l"]
	_body_piece(
		parts["hem_u"],
		_frustum(0.3, 0.2, waist.y - knee.y, 7),
		Vector3(0, knee.y - waist.y, 0),
		COLOR
	)
	_body_piece(parts["hem_l"], _frustum(0.38, 0.3, knee.y, 7), Vector3(0, -knee.y, 0), COLOR)
	var neck: Vector3 = _pivots[&"hood"]
	_body_piece(parts["torso"], _frustum(0.2, 0.24, neck.y - waist.y, 6), Vector3.ZERO, TRIM)
	_body_piece(parts["hood"], _octahedron(0.24), Vector3(0, 0.25, 0), COLOR)
	_glow(parts["hood"], Vector3(0.03, 0.05, 0.1), Vector3(0.2, 0.08, 0), _visor_mat)
	for spec: Array in [["arm_r", 0.3], ["arm_l_u", 0.2], ["arm_l_l", 0.24]]:
		_body_piece(
			parts[spec[0]],
			NeedleAvatar._chamfer_box(Vector3(0.07, spec[1], 0.07), 0.02),
			Vector3(0.0, -float(spec[1]) * 0.5, 0.0),
			GREY
		)
	var grip: Vector3 = _pivots[&"staff"]
	_body_piece(
		parts["staff"],
		NeedleAvatar._chamfer_box(Vector3(0.05, MODEL_HEIGHT, 0.05), 0.012),
		Vector3(0, MODEL_HEIGHT * 0.5 - grip.y, 0),
		GREY
	)
	_glow(
		parts["staff"],
		Vector3(0.12, 0.2, 0.12),
		Vector3(0, MODEL_HEIGHT - 0.1 - grip.y, 0),
		_crystal_mat
	)
	for k in SHARDS.size():
		_body_piece(
			parts[String(SHARDS[k])],
			_octahedron(0.04),
			(SHARD_AT[k] as Vector3) - (_pivots[SHARDS[k]] as Vector3),
			COLOR
		)


func _glow(parent: Node3D, size: Vector3, at: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = NeedleAvatar._chamfer_box(size, minf(size.x, size.z) * 0.25)
	mi.position = at
	mi.material_override = mat
	parent.add_child(mi)


## The joint table (see _joints): the body's turn, lean and tilt (the rig, at the floor); the waist's sink in the
## crumple; the robe's upper tier swinging and tilting at the waist and squashed in the crumple, its hem tier swinging
## at the knee; the torso's bow and tilt at the waist; the hood's at the neck; each shard's turn round the hood's axis
## and its slide out; the staff arm's swing at the shoulder, the staff's slip in the hand and its tilts at the grip; the
## free arm's swing at the shoulder and its elbow's bend.
func _build_joints() -> void:
	var p := _pivots
	var waist: Vector3 = p[&"hem_u"]
	var x := Vector3.RIGHT
	var z := Vector3.BACK
	var crumple_slide := SoloVat.slide(Vector3(0, -waist.y * CRUMPLE_K, 0), waist)
	var crumple_squash := SoloVat.stretch_by(
		Vector3.ONE, Vector3(CRUMPLE_SPREAD, -CRUMPLE_K, CRUMPLE_SPREAD)
	)
	_joints = [
		[YAW, -1, null, SoloVat.turn(Vector3.UP)],
		[LEAN_F, 0, null, SoloVat.turn(z, -1.0)],
		[LEAN_S, 1, parts.get("rig"), SoloVat.turn(x)],
		[CRUMPLE, 2, parts.get("waist"), crumple_slide],
		[HEM_F, 3, null, SoloVat.turn(z)],
		[HEM_S, 4, null, SoloVat.turn(x, -1.0)],
		[CRUMPLE, 5, parts.get("hem_u"), crumple_squash],
		[HEM_L_F, 6, null, SoloVat.turn(z, 1.0, SoloVat.at(p[&"hem_l"] - waist))],
		[HEM_L_S, 7, parts.get("hem_l"), SoloVat.turn(x, -1.0)],
		[TORSO_F, 3, null, SoloVat.turn(z, -1.0)],
		[TORSO_S, 9, parts.get("torso"), SoloVat.turn(x)],
		[HOOD_F, 10, null, SoloVat.turn(z, -1.0, SoloVat.at(p[&"hood"] - waist))],
		[HOOD_S, 11, parts.get("hood"), SoloVat.turn(x)],
	]
	var hood := _joints.size() - 1
	for k in SHARDS.size():
		var at: Vector3 = p[SHARDS[k]] - p[&"hood"]
		_joints.append([ORBIT, hood, null, SoloVat.turn(Vector3.UP, 1.0, SoloVat.at(at))])
		_joints.append(
			[
				SCATTER,
				_joints.size() - 1,
				parts.get(String(SHARDS[k])),
				SoloVat.slide(_shard_out[k] * SCATTER_M)
			]
		)
	var shoulder_r: Vector3 = p[&"arm_r"]
	_joints.append([ARM_R_F, 10, null, SoloVat.turn(z, 1.0, SoloVat.at(shoulder_r - waist))])
	_joints.append([ARM_R_S, _joints.size() - 1, parts.get("arm_r"), SoloVat.turn(x, -1.0)])
	var arm_r := _joints.size() - 1
	_joints.append([STAFF_DROP, arm_r, null, SoloVat.slide(Vector3.DOWN, p[&"staff"] - shoulder_r)])
	_joints.append([STAFF_F, _joints.size() - 1, null, SoloVat.turn(z, -1.0)])
	_joints.append([STAFF_S, _joints.size() - 1, parts.get("staff"), SoloVat.turn(x)])
	var shoulder_l: Vector3 = p[&"arm_l_u"]
	_joints.append([ARM_L_F, 10, null, SoloVat.turn(z, 1.0, SoloVat.at(shoulder_l - waist))])
	_joints.append([ARM_L_S, _joints.size() - 1, parts.get("arm_l_u"), SoloVat.turn(x)])
	_joints.append(
		[
			ELBOW_L,
			_joints.size() - 1,
			parts.get("arm_l_l"),
			SoloVat.turn(z, 1.0, SoloVat.at(p[&"arm_l_l"] - shoulder_l))
		]
	)


# --- Sync ---------------------------------------------------------------------------------------------------------
## The cast from the sim: its windup's progress (the telegraph's) is the gather, entering ACTIVE the cast. Bolt, spread
## and rune share it: the same raised staff, the sim says what leaves it.
func sync(reader: WorldReader, i: int) -> void:
	apply_state(
		{
			"tick": reader.tick(),
			"state": reader.actor_state(i),
			"pos": reader.actor_pos(i),
			"windup": windup_progress(reader, i),
		}
	)


## The same as sync(), from plain values (tests and tools): tick, state, pos (the sim plane), windup (0..1).
func apply_state(s: Dictionary) -> void:
	var was := _state
	_state = int(s.get("state", WorldReader.STATE_MOVE))
	_wind = (
		clampf(float(s.get("windup", 0.0)), 0.0, 1.0) if _state == WorldReader.STATE_WINDUP else 0.0
	)
	if _state == WorldReader.STATE_ACTIVE and was != WorldReader.STATE_ACTIVE:
		_cast_s = 0.0
	_track_motion(int(s.get("tick", 0)), s.get("pos", Vector2.ZERO) as Vector2, 30.0)
	if _fresh:
		_fresh = false
		_rise = 0.0 if _state == WorldReader.STATE_SPAWN else 1.0
		_pose()


# --- Frame time ---------------------------------------------------------------------------------------------------
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0:
		return
	_t += dt
	var dying := _die_t >= 0.0
	_turning(dt, dying)
	if not dying:
		var spawning := _state == WorldReader.STATE_SPAWN
		_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt / SPAWN_SECONDS)
	if _cast_s >= 0.0:
		_cast_s += dt
		if _cast_s >= CAST_END_S:
			_cast_s = -1.0
	if dying:
		_die_t += dt
	# The glide: the sim's velocity in the facing's frame (x forward, y right); the step's phase by the travel.
	var v3 := Basis(Vector3.UP, -_last_fy) * SimPlane.to_3d(_vel)
	var local := Vector2(v3.x, v3.z)
	var speed := 0.0 if dying else local.length()
	_glide = lerpf(_glide, clampf(speed / GLIDE_MPS, 0.0, 1.0), _rate(6.0, dt))
	if speed > 0.05:
		_dir = _dir.lerp(local / speed, _rate(8.0, dt)).normalized()
	_step = fposmod(_step + speed * dt / STEP_M * PI, TAU)
	# The shards circle the hood (faster through the gather); still with reduced motion, stopped in the death.
	if not ViewPrefs.reduced_motion and not dying:
		_orbit = fposmod(_orbit + ORBIT_RATE * (1.0 + 3.0 * _wind) * dt, TAU)
	_pose()


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
	if _die_t < 0.0:
		_die_t = 0.0
	return true


func dying() -> bool:
	return _die_t >= 0.0


## 0..1: the gather shown (the windup's progress; tests).
func gather_pose() -> float:
	return _wind


## The raw drives now (tests).
func drives() -> PackedFloat32Array:
	return _vd


func visor_energy() -> float:
	return _visor_mat.emission_energy_multiplier


# --- The pose -----------------------------------------------------------------------------------------------------
## The pose's numbers from the state (_vd, the lift, the glows), then (the code path) the nodes from them.
func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var a := CALM if calm else 1.0
	var d := PackedFloat32Array()
	d.resize(VAT_DRIVES.size())
	var dead := _die_t >= 0.0
	var die_u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0) if dead else 0.0
	var fold := smoothstep(0.12, 0.8, die_u) if dead else 0.0
	var lift := HOVER_LIFT
	var crystal := CRYSTAL_REST * (1.0 + 0.2 * a * sin(_t * TAU * SWAY_HZ * 1.3))
	var visor := VISOR_REST
	# The gather through the windup (eased), the cast after it: the snap, the hold, the settle (a damped swing back).
	var gather := smoothstep(0.0, 1.0, _wind)
	var cast := 0.0
	if _cast_s >= 0.0:
		var e := _cast_s
		if e < CAST_SNAP_S:
			cast = e / CAST_SNAP_S
		elif e < CAST_SNAP_S + CAST_HOLD_S:
			cast = 1.0
		else:
			var u := (e - CAST_SNAP_S - CAST_HOLD_S) / (CAST_END_S - CAST_SNAP_S - CAST_HOLD_S)
			cast = (1.0 - smoothstep(0.0, 1.0, u)) * (1.0 if calm else 1.0 + 0.15 * sin(u * TAU))
		crystal += CRYSTAL_FLARE * (0.6 if calm else 1.0) * exp(-e * FLARE_DECAY)
		gather *= 1.0 - smoothstep(0.0, CAST_SNAP_S, e)
	var busy := clampf(maxf(gather, cast), 0.0, 1.0)
	var still := (1.0 - 0.7 * busy) * (1.0 - fold) * _rise
	lift += _idle(d, a * still, a, still)
	lift += _glide_pose(d, a * (1.0 - fold), calm)
	_add(d, GATHER_POSE, gather)
	lift += GATHER_LIFT * gather
	crystal += CRYSTAL_GATHER * gather
	visor += 1.4 * gather
	if gather > 0.0 and _wind > 0.75 and not calm:  # the staff and the crystal tremble at the top of the gather
		var shake := 0.03 * sin(_t * TAU * 11.0) * (_wind - 0.75) / 0.25
		d[STAFF_S] += shake
		d[ARM_R_F] += shake * 0.5
		d[ELBOW_L] += shake * 2.0
		crystal += 1.5 * sin(_t * TAU * 9.0)
	_add(d, CAST_POSE, cast)
	lift += CAST_LIFT * cast
	_turn_pose(d, a * (1.0 - fold))
	_add(d, FLINCH_POSE, flinch_amount())
	if _rise < 1.0 and not dead:  # the rise-in: up out of its robe, the shards gathering in
		var r := 1.0 - _rise
		d[CRUMPLE] += 0.9 * r
		d[TORSO_F] += 0.55 * r
		d[HOOD_F] += 0.5 * r
		d[SCATTER] += r * r
		d[ARM_L_S] += 0.4 * r  # the free arm held out of the floor
		d[ELBOW_L] += 0.5 * r
		d[STAFF_DROP] -= CRUMPLE_K * 0.9 * r * (_pivots[&"hem_u"] as Vector3).y  # the staff held up out of the floor
		lift -= (HOVER_LIFT - 0.04) * r
		crystal *= _rise
		visor *= _rise
	if dead:
		lift = _death(d, die_u, fold, calm, lift)
		crystal += 5.0 * sin(PI * clampf(die_u / 0.22, 0.0, 1.0))
		crystal *= 1.0 - smoothstep(0.2, 0.8, die_u)
		visor *= 1.0 - smoothstep(0.1, 0.6, die_u)
	for j in VAT_DRIVES.size():
		var spec: Array = VAT_DRIVES[j]
		if not bool(spec[2]) and float(spec[1]) > float(spec[0]):
			d[j] = clampf(d[j], spec[0], spec[1])
	d[ORBIT] = _orbit
	d[VISOR] = visor
	_vd = d
	_lift = lift
	_crystal = maxf(crystal, 0.0)
	_crystal_mat.emission_energy_multiplier = _crystal
	_visor_mat.emission_energy_multiplier = visor
	if not vat and not parts.is_empty():
		_apply()


## The idle: the hover's bob, the robe's tiers swaying a beat behind each other, the head bowed a little, the free
## hand's slow circle. `s` the sway's size, `a` the circle's, `held` the rest pose's share. Returns the lift's change.
func _idle(d: PackedFloat32Array, s: float, a: float, held: float) -> float:
	var ph := _t * TAU * SWAY_HZ
	var slow := _t * TAU * 0.21
	var c := _t * TAU * CIRCLE_HZ
	d[LEAN_F] += 0.02 * s * sin(ph + 0.5)
	d[LEAN_S] += 0.03 * s * sin(slow)
	d[HEM_F] -= 0.04 * s * sin(ph - 0.8)
	d[HEM_S] -= 0.04 * s * sin(slow - 0.9)
	d[HEM_L_F] -= 0.05 * s * sin(ph - 1.6)
	d[HEM_L_S] -= 0.05 * s * sin(slow - 1.8)
	d[TORSO_F] += 0.06 * held + 0.03 * s * sin(ph + 1.0)
	d[HOOD_F] += 0.14 * held + 0.05 * s * sin(ph + 1.7)
	d[HOOD_S] += 0.05 * s * sin(_t * TAU * 0.17)
	d[ARM_L_F] += 0.15 * held + 0.14 * a * held * sin(c)
	d[ARM_L_S] += 0.12 * held + 0.1 * a * held * cos(c)
	d[ELBOW_L] += 0.35 * held + 0.12 * a * held * sin(c + 1.2)
	d[ARM_R_F] += 0.03 * s * sin(ph + 0.3)
	d[STAFF_F] -= 0.03 * s * sin(ph + 0.3)  # the staff stays upright as the arm sways
	return 0.025 * s * sin(_t * TAU * BOB_HZ)


## The glide: the robe leaning into the travel with its hem trailing, the hem tier stepping side to side under it with
## a bob each step, the arms carried. Returns the lift's change.
func _glide_pose(d: PackedFloat32Array, s: float, calm: bool) -> float:
	var k := _glide * (0.6 if calm else 1.0) * (1.0 if s > 0.0 else 0.0)
	if k <= 0.0:
		return 0.0
	var v := _dir
	var step := sin(_step)
	var bob := 0.0 if calm else absf(step)
	d[LEAN_F] += 0.16 * k * v.x
	d[LEAN_S] += 0.12 * k * v.y
	d[HEM_F] += -0.22 * k * v.x
	d[HEM_S] += -0.16 * k * v.y
	d[HEM_L_F] += -0.12 * k * v.x + 0.1 * k * bob
	d[HEM_L_S] += 0.16 * k * step * (0.4 if calm else 1.0)
	d[TORSO_S] -= 0.04 * k * step * (0.0 if calm else 1.0)
	d[TORSO_F] -= 0.05 * k * v.x
	d[HOOD_F] += -0.08 * k * v.x + 0.04 * k * bob
	d[ARM_L_F] += -0.3 * k * v.x
	d[ARM_L_S] += 0.12 * k
	d[ARM_R_F] += 0.12 * k * v.x
	d[STAFF_F] += 0.08 * k * v.x
	return 0.035 * k * bob


## The turn toward its target: the body trails the facing and the robe swings out after it.
func _turn_pose(d: PackedFloat32Array, k: float) -> void:
	var w := clampf(_omega / TURN_REF, -1.0, 1.0)
	d[YAW] -= 0.3 * w * k
	d[HEM_S] += 0.15 * w * k
	d[HEM_L_S] += 0.2 * w * k


## The death at u (0..1 of DEATH_SECONDS): a jolt, the staff slipping and falling across the floor, the crumple into
## the robe, the shards flying off. Returns the lift.
func _death(d: PackedFloat32Array, u: float, fold: float, calm: bool, lift: float) -> float:
	var jolt := sin(PI * clampf(u / 0.22, 0.0, 1.0)) * (0.5 if calm else 1.0)
	var fall := smoothstep(0.06, 0.62, u)
	fall *= fall  # it drops, accelerating
	d[HOOD_F] += -0.55 * jolt + 0.7 * fold
	d[TORSO_F] += -0.2 * jolt + 0.72 * fold
	d[ARM_R_F] += 0.4 * jolt - 0.45 * fold
	d[ARM_L_S] += 0.45 * jolt - 0.1 * fold
	d[ARM_L_F] += -0.25 * fold
	d[ELBOW_L] += 0.3 * fold
	d[LEAN_F] += 0.04 * fold
	d[CRUMPLE] += 0.9 * fold
	d[SCATTER] += smoothstep(0.05, 0.5, u)
	# The staff tips over sideways to lie across the floor at its right (seen from the camera a staff falling forward
	# reads as one still standing), slipping down in the hand as it goes.
	d[STAFF_DROP] += 0.15 * fall
	d[STAFF_F] -= 0.2 * fall
	d[STAFF_S] += 1.57 * fall
	return lerpf(lift, 0.0, fold)


static func _add(d: PackedFloat32Array, pose: Array, w: float) -> void:
	if is_zero_approx(w):
		return
	for pair: Array in pose:
		d[int(pair[0])] += float(pair[1]) * w


## The nodes from the drives: each frame node's transform is its joints' makes composed since its parent frame (the
## rig's with the lift under it), as the VAT rig chains them.
func _apply() -> void:
	var acc: Array[Transform3D] = []
	acc.resize(_joints.size())
	var rig: Node3D = parts.get("rig")
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


## The crystal's glow (the instance's accent glow; the visor's is the VISOR drive).
func glow_energy() -> float:
	return _crystal


## The owner's colour map (VatLooks' textured variant), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## One grid per drive but the visor's, the joints as the table.
func vat_rig() -> Dictionary:
	var grids: Array = []
	for d in VAT_SAMPLES.size():
		grids.append([[d, VAT_SAMPLES[d]]])
	var key := "arc_caster_" + ("model" if has_model else "code")
	var out := SoloVat.rig(key, VAT_DRIVES, grids, _joints, true)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out


# --- The shape kit (other code-made bodies use it) -----------------------------------------------------------------
## A flat-shaded `sides`-sided frustum standing on the origin: radius r0 at the bottom, r1 at height h.
static func _frustum(r0: float, r1: float, h: float, sides: int) -> ArrayMesh:
	var tris := []
	var c := Vector3(0, h * 0.5, 0)
	for k in sides:
		var a0 := TAU * (k + 0.5) / sides
		var a1 := TAU * (k + 1.5) / sides
		var b0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var t0 := Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var t1 := Vector3(cos(a1) * r1, h, sin(a1) * r1)
		tris.append([b0, b1, t1])
		tris.append([b0, t1, t0])
		tris.append([Vector3.ZERO, b1, b0])
		tris.append([Vector3(0, h, 0), t0, t1])
	return flat_mesh(tris, c)


## A flat-shaded octahedron of half-size r (the crystal and the shards).
static func _octahedron(r: float) -> ArrayMesh:
	var tris := []
	var pts := [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	for k in 4:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[(k + 1) % 4]
		tris.append([a, b, Vector3(0, r * 1.4, 0)])
		tris.append([a, b, Vector3(0, -r * 1.4, 0)])
	return flat_mesh(tris, Vector3.ZERO)
