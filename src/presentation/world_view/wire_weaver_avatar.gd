class_name WireWeaverAvatar
extends AvatarBase
## The Wire Weaver on the owner's model (ENEMIES.md R1; owner: "the enemies have to be animated and then passed
## through VAT animation so they don't consume as much and they run smooth"; "make sure they are animated as good as
## you can, if they can have multiple animations ... the better"): EnemyModels &"wire_weaver", cut by
## scripts/assets/wire_weaver_prep.py into the body (the hull, the shell, the spool's discs and bracket), the head
## (the face socket and its gem visor), the spool (the coiled cable drum between the discs, tugging on its axle), each
## of its four legs' upper half and shin and each claw arm's upper half and forearm. The model carries no cable
## posts, so the two it carries are built here, upright beside the spool's axle ends, in the look of the posts it
## plants (RuinsRocksAvatar draws those): it lifts them, launches them to the cable's ends and grows new ones.
## The sim's Weaver (RuinsRocks R1, data/enemies/wire_weaver.tres) keeps a distance band, then marks a cable across the
## hero's way (WINDUP: the line on the ground), plants two posts at its ends at once (ACTIVE) and recovers.
## Its clips, each read from the sim through WorldReader (sync) and played in frame time (advance):
## - idle: a slow breathing bob, the head scanning in held glances, the claws flexing, the drum ticking, the
##   post tops flickering faintly, a leg re-planted now and then;
## - the gait: its four legs in two pairs (back right and left, behind and front right), each foot sweeping back on the
##   ground and lifting forward folded, the stride following the speed along its facing (backwards as it backs off),
##   stepping round while it turns; the body bobbing twice a stride, rocking and swaying, the arms swinging;
## - the tell (WINDUP, the sim's own progress): a short crouch, then it leans back and braces, the posts rise out of
##   their straps and tip forward, their tops sparking brighter and brighter, the arms raise and open toward the
##   line, the spool winds back, the gem visor climbs and flashes from TELL_FLASH_FROM (steady with reduced motion);
## - the plant (ACTIVE, PLANT_SECONDS): the posts shoot up and away (gone: they stand at the cable's ends now), the body
##   kicks back, the arms sweep apart along the cable, the drum jerks out paying the cable off;
## - empty-handed until it reloads (RELOAD_SECONDS after the plant): new posts rise out of the straps as the drum
##   winds;
## - a hit flinch (its HP fell): the body jolts, the head ducks, a leg scrabbles, the posts rattle;
## - the rise-in (SPAWN) and the death (die(): DEATH_SECONDS): its legs buckle out and it drops onto its belly, rolling
##   aside, the arms fall slack, the drum slumps, the posts topple back, the sparks fizzle and the visor dies;
## - reduced motion (ViewPrefs.reduced_motion): the same clips at CALM of the body's amplitudes, no flickers, shakes or
##   scrabbles, the flashes steady.
## The pose is a few plain numbers (the raw drives, _vd: each joint's turn, slide or stretch) worked out from the state
## first, then the nodes from them through the joint table (_joints, the same transforms the VAT rig declares), so the
## baked pose is the live one. On the VAT crowd it is batched (EnemyBatch: nothing here reads the tree, its turn is its
## facing node's; its death's timer is the batch's, drop), and the native batch runs the same sync, frame step and pose
## (native/src/zd_avatar_wire_weaver.cpp). Presentation only (EI-07): nothing here reaches the sim. +X is the front, +Z
## its right.

const KIND := WorldReader.KIND_WIRE_WEAVER
const MODEL := &"wire_weaver"
const HEIGHT := 1.0
## The role colour (the shell's plates), the gem visor's glow and the post tops' (emission energy: rest, the tell's
## peak).
const COLOR := Color("#E8C22E")
const VISOR_COLOR := Color("#FFC23A")
const SPARK_COLOR := Color("#FFD84A")
const VISOR_REST := 1.6
const VISOR_TELL := 7.0
const SPARK_REST := 1.4
const SPARK_TELL := 7.0
const SPARK_PLANT := 11.0
## The carried posts (m): grey, a dark foot, a glowing top; each one's foot beside an axle end (+Z), its height.
const POST_GREY := Color("#8A817C")
const POST_DARK := Color("#5F5551")
const POST_FOOT := Vector3(-0.2, 0.58, 0.35)
const POST_LEN := 0.44
## The map's texels the rod and the foot take on the owner's model (grey, dark; wire_weaver_prep.py's post_uvs).
const POST_UVS: Array[Vector2] = [Vector2(0.27002, 0.87939), Vector2(0.47314, 0.80029)]
const TELEPORT_SPEED := 30.0
## The clips' lengths (s): the plant and its recovery (the attack's recovery_seconds), the reload after it, a hit's
## flinch, the death.
const PLANT_SECONDS := 0.5
const RELOAD_FROM := 0.7
const RELOAD_SECONDS := 0.6
const HURT_SECONDS := 0.3
const DEATH_SECONDS := 1.0
## The walk: the sim's move speed (m/s), the share of the stride a foot is down, a foot's travel per radian of sweep
## (m: the hip-to-foot drop), the legs' sweep and lift and the shins' tuck at a full stride (radians), the cadence (Hz)
## that keeps the feet on the ground at MOVE_SPEED; a longer stride than STRIDE_MAX quickens it instead.
const MOVE_SPEED := 2.6
const DUTY := 0.56
const LEVER := 0.45
const SWING := 0.42
const LIFT := 0.5
const FOLD := 0.75
const STRIDE_MAX := 1.3
const STEP_HZ := MOVE_SPEED * DUTY / (2.0 * SWING * LEVER)
## The legs (rc behind, rr back right, ml left, fr front right: the model's own layout) and each one's place in the
## stride: two pairs half a stride apart. The arms (r, l).
const LEGS: Array[StringName] = [&"rc", &"rr", &"ml", &"fr"]
const STRIDE_AT := [0.5, 0.0, 0.04, 0.54]
const ARMS: Array[StringName] = [&"r", &"l"]
## Reduced motion's share of the body's motion; the breath (Hz).
const CALM := 0.45
const BREATH_HZ := 0.5
## The joints' pivots (m, the model's frame) when the model is missing (the code-made body's: the prep's own), and
## the feet and claws the code-made limbs reach to.
const PIVOTS := {
	&"body": Vector3.ZERO,
	&"head": Vector3(0.201, 0.603, 0.0),
	&"spool": Vector3(-0.206, 0.822, 0.0),
	&"leg_rc_u": Vector3(-0.271, 0.442, -0.01),
	&"leg_rc_l": Vector3(-0.459, 0.271, -0.014),
	&"leg_rr_u": Vector3(-0.181, 0.442, 0.191),
	&"leg_rr_l": Vector3(-0.345, 0.271, 0.369),
	&"leg_ml_u": Vector3(-0.131, 0.442, -0.211),
	&"leg_ml_l": Vector3(-0.064, 0.271, -0.35),
	&"leg_fr_u": Vector3(0.035, 0.392, 0.161),
	&"leg_fr_l": Vector3(0.151, 0.263, 0.232),
	&"arm_r_u": Vector3(0.126, 0.533, 0.221),
	&"arm_r_l": Vector3(0.236, 0.411, 0.276),
	&"arm_l_u": Vector3(0.134, 0.441, -0.205),
	&"arm_l_l": Vector3(0.338, 0.366, -0.295),
}
const FEET := [
	Vector3(-0.46, 0.0, -0.022),
	Vector3(-0.346, 0.0, 0.379),
	Vector3(-0.045, 0.0, -0.366),
	Vector3(0.19, 0.0, 0.246)
]
const CLAWS := [Vector3(0.47, 0.17, 0.257), Vector3(0.47, 0.27, -0.29)]
## The body's roll and pitch pivots (m).
const ROLL_AT := Vector3(0.0, 0.1, 0.0)
const PITCH_AT := Vector3(-0.1, 0.1, 0.0)
## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]: the body's roll, pitch and sway (its yaw), the head's
## pitch and yaw, the drum's turn, each leg's sweep (+ the foot forward), lift (+ up) and shin (+ out, -
## tucked) in LEGS order, each arm's swing (+ out), raise (+ up) and elbow (+ unfolding) in ARMS order, each post's
## rise (m), tip (+ forward) and size (its stretch: hidden at the low end), then the visor's glow (no grid: sent as it
## is). A pitch's plus is up (the nose), a roll's tips the top to the right (+Z).
const ROLL := 0
const PITCH := 1
const SWAY := 2
const HEAD_P := 3
const HEAD_Y := 4
const SPOOL := 5
const LEG0 := 6
const ARM0 := 18
const POST0 := 24
const VISOR := 30
const POST_MIN := 0.02
## A leg's, an arm's and a post's three drive specs (each one repeated per limb), the body's six before them.
const LEG_SPECS := [[-0.9, 0.9, false], [-0.7, 1.3, false], [-1.3, 1.3, false]]
const ARM_SPECS := [[-0.8, 1.2, false], [-1.0, 1.4, false], [-1.3, 1.3, false]]
const POST_SPECS := [[-0.3, 0.5, false], [-1.4, 1.2, false], [POST_MIN, 1.0, false]]
const VAT_DRIVES := (
	[
		[-0.7, 0.4, false],
		[-0.5, 0.5, false],
		[-0.4, 0.4, false],
		[-0.5, 0.5, false],
		[-0.6, 0.6, false],
		[-0.6, 0.6, false],
	]
	+ LEG_SPECS
	+ LEG_SPECS
	+ LEG_SPECS
	+ LEG_SPECS
	+ ARM_SPECS
	+ ARM_SPECS
	+ POST_SPECS
	+ POST_SPECS
	+ [[0.0, 0.0, false]]
)
## Each drive's samples (a turn about one radian in 20; a slide or a stretch two: exact).
const LEG_SAMPLES := [37, 41, 53]
const ARM_SAMPLES := [41, 49, 53]
const POST_SAMPLES := [2, 53, 2]
const VAT_SAMPLES := (
	[23, 21, 17, 21, 25, 25]
	+ LEG_SAMPLES
	+ LEG_SAMPLES
	+ LEG_SAMPLES
	+ LEG_SAMPLES
	+ ARM_SAMPLES
	+ ARM_SAMPLES
	+ POST_SAMPLES
	+ POST_SAMPLES
)

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds no nodes.
var vat := false
var kind := KIND
var height := HEIGHT
## True when the body is the owner's model (else the code-made stand-in on the same joints).
var has_model := false
## The parts (tests): the rig's root (the body), the head, the spool, each leg's upper and lower node (LEGS order),
## each arm's upper and lower node (ARMS order), the two carried posts (+Z, then -Z).
var rig: Node3D
var head: Node3D
var spool: Node3D
var uppers: Array[Node3D] = []
var lowers: Array[Node3D] = []
var arms: Array[Node3D] = []
var forearms: Array[Node3D] = []
var posts: Array[Node3D] = []

var _vd := PackedFloat32Array()
var _lift := 0.0
var _spark := SPARK_REST
var _spark_mat := StandardMaterial3D.new()
var _visor_mat := StandardMaterial3D.new()
var _pivots := PIVOTS.duplicate()
## Each leg's foot across the body (m, +Z right: its share of a turn) and its sweep's axis; the joint table: [drive,
## parent joint, frame node or null, make (SoloVat's)], a parent before its children.
var _foot_z := PackedFloat32Array()
var _joints: Array = []
# The state the pose is made from (sync and advance keep it; VatVerify.sample sets it).
var _state := WorldReader.STATE_SPAWN
var _tell := 0.0
var _hp := -1
var _speed := 0.0
var _omega := 0.0
var _phase := 0.0
var _stride := 0.0
var _coil := 0.0
var _rise := 0.0
var _plant_t := -1.0
var _hurt_t := -1.0
var _hurt_leg := 0
var _die_t := -1.0
var _last_fy := 0.0
var _have_fy := false


## Builds a Weaver under `facing` for ActorViews (`views`: on VAT while its switch is on) and marks `root` (the avatar,
## its body materials for the hit flash); returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D) -> float:
	var weaver := WireWeaverAvatar.new()
	views._solo_vat(root, weaver, KIND)
	weaver.setup()
	facing.add_child(weaver)
	root.set_meta(&"enemy_avatar", weaver)
	root.set_meta(&"mats", weaver.body_materials.duplicate())
	return HEIGHT


func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	for mat: StandardMaterial3D in [_spark_mat, _visor_mat]:
		var c := SPARK_COLOR if mat == _spark_mat else VISOR_COLOR
		mat.albedo_color = c
		mat.emission_enabled = true
		mat.emission = c
	_spark_mat.emission_energy_multiplier = SPARK_REST
	_visor_mat.emission_energy_multiplier = VISOR_REST
	_visor_mat.set_meta(SoloVat.GLOW, VISOR + 1)  # a VAT Weaver's visor glows at its VISOR drive
	var m := EnemyModels.get_model(MODEL)
	has_model = not m.is_empty()
	if has_model:
		var s: float = m["scale"]
		var parts_in: Dictionary = m["parts"]
		for pname: StringName in parts_in:
			_pivots[pname] = (parts_in[pname] as Dictionary)["pivot"] * s
	_foot_z.resize(LEGS.size())
	for k in LEGS.size():
		_foot_z[k] = (FEET[k] as Vector3).z
	if vat:  # the crowd draws the body
		_pose()
		return
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	head = _node(rig, "Head")
	spool = _node(rig, "Spool")
	for k in LEGS.size():
		var up := _node(rig, "Leg_%s_u" % LEGS[k])
		uppers.append(up)
		lowers.append(_node(up, "Leg_%s_l" % LEGS[k]))
	for k in ARMS.size():
		var up := _node(rig, "Arm_%s_u" % ARMS[k])
		arms.append(up)
		forearms.append(_node(up, "Arm_%s_l" % ARMS[k]))
	var base: StandardMaterial3D = null
	if has_model:
		base = _build_model(m)
	else:
		_build_code()
	for k in 2:
		posts.append(_node(rig, "Post_%d" % k))
		_build_post(posts[k], base)
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
		&"head":
			return [head, _pivots[&"head"]]
		&"spool":
			return [spool, _pivots[&"spool"]]
	var s := String(part)
	if s.begins_with("leg_"):
		var k := LEGS.find(StringName(s.substr(4, 2)))
		if k >= 0:
			return [uppers[k] if s.ends_with("_u") else lowers[k], _pivots[part]]
	if s.begins_with("arm_"):
		var k := ARMS.find(StringName(s.substr(4, 1)))
		if k >= 0:
			return [arms[k] if s.ends_with("_u") else forearms[k], _pivots[part]]
	return [rig, Vector3.ZERO]


## The owner's model: each part's mesh in its joint's frame, its surfaces on the base / role plates (the role plates
## greyscale in the map, tinted COLOR) and the gem visor (glow).
func _build_model(m: Dictionary) -> StandardMaterial3D:
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
	return mats[&"base"]


## A carried post on `node` (its foot): a grey rod, a dark foot block and a glowing top, as the planted ones look.
## On the owner's model (`base`: its base plates' material) the rod and the foot take their colours from the map's
## own grey and dark texels (POST_UVS), so the VAT crowd, which draws every plate through the map, draws them alike.
func _build_post(node: Node3D, base: StandardMaterial3D) -> void:
	var rod := CylinderMesh.new()
	rod.top_radius = 0.032
	rod.bottom_radius = 0.026
	rod.height = POST_LEN
	rod.radial_segments = 6
	rod.rings = 1
	var foot := BoxMesh.new()
	foot.size = Vector3(0.09, 0.04, 0.09)
	if base == null:
		_body_piece(node, rod, Vector3(0, POST_LEN * 0.5, 0), POST_GREY)
		_body_piece(node, foot, Vector3(0, 0.02, 0), POST_DARK)
	else:
		_textured(node, rod, Vector3(0, POST_LEN * 0.5, 0), POST_UVS[0], base)
		_textured(node, foot, Vector3(0, 0.02, 0), POST_UVS[1], base)
	var top := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.048
	sm.height = 0.096
	sm.radial_segments = 6
	sm.rings = 3
	top.mesh = sm
	top.position = Vector3(0, POST_LEN + 0.03, 0)
	top.material_override = _spark_mat
	node.add_child(top)


## A piece of `mesh` at `at` under `parent`, every vertex at `uv` of the map `mat` draws.
func _textured(
	parent: Node3D, mesh: PrimitiveMesh, at: Vector3, uv: Vector2, mat: Material
) -> void:
	var arrays := mesh.get_mesh_arrays()
	var uvs := PackedVector2Array()
	uvs.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	uvs.fill(uv)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.position = at
	mi.material_override = mat
	parent.add_child(mi)


## The code-made stand-in (the model file missing): boxes and rods on the same joints, so every clip still plays.
func _build_code() -> void:
	var charcoal := Color("#24272D")
	var grey := Color("#8A817C")
	_piece(rig, Vector3(0.5, 0.26, 0.42), Vector3(0.0, 0.5, 0), charcoal)
	_piece(rig, Vector3(0.48, 0.16, 0.46), Vector3(0.04, 0.68, 0), COLOR)
	var neck: Vector3 = _pivots[&"head"]
	_piece(head, Vector3(0.1, 0.22, 0.22), Vector3(0.29, 0.6, 0) - neck, charcoal)
	var gem := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.03, 0.08, 0.08)
	gem.mesh = gm
	gem.material_override = _visor_mat
	gem.position = Vector3(0.345, 0.6, 0) - neck
	head.add_child(gem)
	var drum := CylinderMesh.new()
	drum.top_radius = 0.15
	drum.bottom_radius = 0.15
	drum.height = 0.38
	drum.radial_segments = 8
	var d := _body_piece(spool, drum, Vector3.ZERO, Color("#3A3433"))
	d.rotation.x = PI * 0.5
	for k in LEGS.size():
		var hip: Vector3 = _pivots[StringName("leg_%s_u" % LEGS[k])]
		var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
		_rod(uppers[k], Vector3.ZERO, knee - hip, grey)
		_rod(lowers[k], Vector3.ZERO, (FEET[k] as Vector3) - knee, grey)
	for k in ARMS.size():
		var sh: Vector3 = _pivots[StringName("arm_%s_u" % ARMS[k])]
		var el: Vector3 = _pivots[StringName("arm_%s_l" % ARMS[k])]
		_rod(arms[k], Vector3.ZERO, el - sh, grey)
		_rod(forearms[k], Vector3.ZERO, (CLAWS[k] as Vector3) - el, grey)


func _piece(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _body_piece(parent, m, at, c)


func _rod(parent: Node3D, from: Vector3, to: Vector3, c: Color) -> void:
	var piece := _piece(parent, Vector3(0.045, (to - from).length(), 0.045), (from + to) * 0.5, c)
	piece.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))


## The joint table (see _joints): the body's roll, pitch and sway (the rig), the head's pitch and yaw at the neck, the
## drum's turn on its axle, each leg's sweep (about the line across its hip square to the leg and the front, so the
## foot moves fore and aft whichever way the leg points), lift (about the level line across it) and shin (the same line
## at the knee), each arm's swing (about the vertical at the shoulder), raise and elbow, each post's rise, tip and size
## at its foot.
func _build_joints() -> void:
	var z := Vector3.BACK
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
		[SPOOL, 2, spool, SoloVat.turn(z, 1.0, SoloVat.at(_pivots[&"spool"]))],
	]
	for k in LEGS.size():
		var hip: Vector3 = _pivots[StringName("leg_%s_u" % LEGS[k])]
		var knee: Vector3 = _pivots[StringName("leg_%s_l" % LEGS[k])]
		var reach: Vector3 = (FEET[k] as Vector3) - hip
		var sweep := reach.cross(Vector3.RIGHT).normalized()  # a turn about it by + moves the foot forward
		var out := Vector3(knee.x - hip.x, 0.0, knee.z - hip.z).normalized()
		var across := out.cross(Vector3.UP)  # a turn about it by + lifts the leg
		_joints.append([LEG0 + 3 * k, 2, null, SoloVat.turn(sweep, 1.0, SoloVat.at(hip))])
		_joints.append([LEG0 + 3 * k + 1, _joints.size() - 1, uppers[k], SoloVat.turn(across)])
		_joints.append(
			[
				LEG0 + 3 * k + 2,
				_joints.size() - 1,
				lowers[k],
				SoloVat.turn(across, 1.0, SoloVat.at(knee - hip))
			]
		)
	for k in ARMS.size():
		var sh: Vector3 = _pivots[StringName("arm_%s_u" % ARMS[k])]
		var el: Vector3 = _pivots[StringName("arm_%s_l" % ARMS[k])]
		var out := (
			Vector3((CLAWS[k] as Vector3).x - sh.x, 0.0, (CLAWS[k] as Vector3).z - sh.z)
			. normalized()
		)
		var across := out.cross(Vector3.UP)  # a turn about it by + raises the arm
		var side := -1.0 if sh.z > 0.0 else 1.0  # a swing's + is outward on both sides
		_joints.append([ARM0 + 3 * k, 2, null, SoloVat.turn(Vector3.UP, side, SoloVat.at(sh))])
		_joints.append([ARM0 + 3 * k + 1, _joints.size() - 1, arms[k], SoloVat.turn(across)])
		_joints.append(
			[
				ARM0 + 3 * k + 2,
				_joints.size() - 1,
				forearms[k],
				SoloVat.turn(across, 1.0, SoloVat.at(el - sh))
			]
		)
	for k in 2:
		var foot := POST_FOOT * Vector3(1.0, 1.0, 1.0 if k == 0 else -1.0)
		_joints.append([POST0 + 3 * k, 2, null, SoloVat.slide(Vector3.UP, foot)])
		_joints.append([POST0 + 3 * k + 1, _joints.size() - 1, null, SoloVat.turn(z, -1.0)])
		_joints.append(
			[
				POST0 + 3 * k + 2,
				_joints.size() - 1,
				posts[k],
				SoloVat.stretch_by(Vector3.ZERO, Vector3.ONE)
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


## The same as sync(), from plain values (tests, the shots): tick, state, pos, windup (0..1); hp optional.
func apply_state(s: Dictionary) -> void:
	_touch()
	var st: int = s["state"]
	var hp: int = s.get("hp", -1)
	if _fresh:
		_rise = 0.0 if st == WorldReader.STATE_SPAWN else 1.0
	else:
		var planted := st == WorldReader.STATE_ACTIVE and _state != WorldReader.STATE_ACTIVE
		var skipped := st == WorldReader.STATE_RECOVER and _state == WorldReader.STATE_WINDUP
		if planted or skipped:  # (the one-tick plant missed between two syncs still plants)
			_plant_t = 0.0
			_coil = 0.0  # (the plant's own pose takes the tell's hold over)
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
	var fy := (get_parent() as Node3D).rotation.y if get_parent() is Node3D else 0.0
	var ahead := _vel.dot(Vector2(cos(fy), sin(fy))) if moving else 0.0
	_speed = lerpf(_speed, ahead, _rate(9.0 if moving else 14.0, dt))
	_turning(fy, dt, dying)
	# The stride: each leg's share of the walk and the turn (its side's ground speed), at a steady cadence.
	var most := 0.0
	for k in LEGS.size():
		most = maxf(most, absf(_speed + _omega * _foot_z[k]) / MOVE_SPEED)
	_stride = move_toward(_stride, minf(most, 1.0), dt * 4.0)
	_phase = fposmod(_phase + STEP_HZ * maxf(1.0, most / STRIDE_MAX) * dt * signf(_stride), 1.0)
	var winding := _state == WorldReader.STATE_WINDUP and not dying
	_coil = _tell if winding else move_toward(_coil, 0.0, dt * 10.0)
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.0))
	_plant_t = _clip(_plant_t, dt, RELOAD_FROM + RELOAD_SECONDS)
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
func _turning(fy: float, dt: float, dying: bool) -> void:
	var w := 0.0
	if _have_fy and not dying:
		w = clampf(wrapf(fy - _last_fy, -PI, PI) / dt, -4.0, 4.0)
	_omega = lerpf(_omega, w, _rate(10.0, dt))
	_last_fy = fy
	_have_fy = true


## The drum's turn now (radians, + pays cable out; a tug, never a full turn: its underside, cut from the cradle, stays
## down): it rocks with the walk and ticks while it waits, winds back taut through the tell, jerks out and rings at
## the plant, winds the new posts up, slumps out as it dies.
func _spool_turn(k: float) -> float:
	var a := k * (0.06 * sin(TAU * _phase) * clampf(_stride, 0.0, 1.0) + 0.05 * _scan(_t, 1.6, 9.0))
	a -= 0.35 * smoothstep(0.1, 0.7, _coil)
	if _plant_t >= 0.0:
		var held := 1.0 - smoothstep(0.0, 0.25 * PLANT_SECONDS, _plant_t)
		var ring := (
			sin(TAU * 2.5 * _plant_t) * (1.0 - smoothstep(0.0, 1.2 * PLANT_SECONDS, _plant_t))
		)
		a += -0.35 * held + 0.45 * k * ring - 0.25 * sin(PI * _reloading())
	if _die_t >= 0.0:
		a = lerpf(a, 0.3, smoothstep(0.0, 0.5, _die_t / DEATH_SECONDS))
	return a


## Starts the death (ActorViews or the enemy batch, when the sim drops the Weaver: its bar hidden, freed DEATH_SECONDS
## later). True: it plays.
func die() -> bool:
	_touch()
	if _die_t < 0.0:
		_die_t = 0.0
	return true


func dying() -> bool:
	_peek()
	return _die_t >= 0.0


## The post tops' and the visor's glow now (tests, the e2e).
func spark_energy() -> float:
	_peek()
	return _spark


func visor_energy() -> float:
	_peek()
	return _visor_mat.emission_energy_multiplier


## True while it carries its two posts (not between a plant and the reload; tests).
func carrying() -> bool:
	return drives()[POST0 + 2] > 0.5 and drives()[POST0 + 5] > 0.5


## The raw drives now (tests).
func drives() -> PackedFloat32Array:
	_peek()
	return _vd


# --- The pose -----------------------------------------------------------------------------------------------------
## The pose's numbers from the state (_vd, the lift, the glows), then (the code path) the nodes from them.
func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var k := CALM if calm else 1.0
	var d := PackedFloat32Array()
	d.resize(VAT_DRIVES.size())
	d[POST0 + 2] = 1.0
	d[POST0 + 5] = 1.0
	d[SPOOL] = _spool_turn(k)
	var lift := _walk_pose(d, k)
	lift += _idle_pose(d, k, calm)
	lift += _tell_pose(d, k, calm)
	lift += _plant_pose(d, k, calm)
	lift += _hurt_pose(d, k, calm)
	lift += _rise_pose(d)
	lift = _death_pose(d, lift, calm)
	_spark = _spark_energy(calm)
	d[VISOR] = _visor(calm)
	for j in d.size():
		if j != VISOR:
			d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	_vd = d
	_lift = lift
	_spark_mat.emission_energy_multiplier = _spark
	_visor_mat.emission_energy_multiplier = d[VISOR]
	if not vat and rig != null:
		_apply()


## The walk (and the turn's stepping): each leg through its stride at its own share (its side's ground speed over the
## full stride's), the body bobbing twice a stride, rocking with the pairs and swaying, the arms swinging, the posts
## nodding. Returns its lift.
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
	var walk := clampf(absf(_speed) / MOVE_SPEED, 0.0, 1.0)
	d[ROLL] += g * k * 0.05 * sin(TAU * (p - 0.1))
	d[SWAY] += walk * k * 0.06 * sin(TAU * (p + 0.15))
	d[PITCH] += walk * k * (0.02 * sin(2.0 * TAU * (p - 0.05)) - 0.04 * signf(_speed))
	d[HEAD_Y] -= walk * k * 0.05 * sin(TAU * (p + 0.15))
	d[HEAD_P] += walk * k * 0.04 * cos(2.0 * TAU * (p - 0.1))
	for a in ARMS.size():
		var s := 1.0 if a == 0 else -1.0
		d[ARM0 + 3 * a + 1] += walk * k * (0.12 * s * sin(TAU * p) - 0.05)
		d[ARM0 + 3 * a + 2] += walk * k * 0.1 * sin(TAU * p + 0.8 * s)
	for q in 2:
		d[POST0 + 3 * q + 1] += walk * k * 0.06 * sin(2.0 * TAU * (p - 0.2) + q)
	var land := pow(0.5 + 0.5 * cos(2.0 * TAU * (p - 0.05)), 3.0)
	return g * k * (0.012 - 0.022 * land)


## One leg through its stride at q (0 its touchdown): (the sweep: 1 forward .. -1 back; the lift 0..1; the shin: under 0
## tucked, over 0 reaching). On the ground the foot sweeps back, the knee giving a little as it takes the weight; in
## the air it lifts and comes forward eased, the shin tucked, reaching out just before it lands.
static func leg_cycle(q: float) -> Vector3:
	if q < DUTY:
		var s := q / DUTY
		return Vector3(1.0 - 2.0 * s, 0.0, -sin(PI * minf(s / 0.35, 1.0)) * 0.15)
	var w := (q - DUTY) / (1.0 - DUTY)
	var up := sin(PI * w)
	var tuck := -sin(PI * minf(w / 0.75, 1.0)) + 0.5 * smoothstep(0.55, 0.9, w) * (1.0 - w) * 4.0
	return Vector3(-1.0 + 2.0 * smoothstep(0.0, 1.0, w), up * up * (3.0 - 2.0 * up), tuck)


## Idle (fading as it walks): a breathing bob, the head's held glances and its twitch, the claws flexing in turn, the
## weight shifting, a leg re-planted now and then. Returns its lift.
func _idle_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	var idle := (1.0 - clampf(_stride, 0.0, 1.0)) * (1.0 - _coil) * (1.0 if _die_t < 0.0 else 0.0)
	if idle <= 0.0:
		return 0.0
	var breath := sin(TAU * BREATH_HZ * _t)
	d[HEAD_Y] += idle * k * 0.35 * _scan(_t, 2.0, 0.0)
	d[HEAD_P] += idle * k * (0.12 * _scan(_t, 2.9, 5.0) - 0.03 * breath)
	if not calm:
		d[HEAD_P] += idle * 0.08 * _twitch(_t, 3.3, 11.0)
		d[HEAD_Y] += idle * 0.07 * _twitch(_t, 4.1, 23.0)
	d[ROLL] += idle * k * 0.03 * sin(0.6 * _t)
	d[PITCH] += idle * k * 0.02 * sin(0.6 * _t + 1.7)
	d[SWAY] += idle * k * 0.04 * sin(0.4 * _t + 0.4)
	for a in ARMS.size():
		var flex := sin(PI * clampf(fposmod(_t / 1.7 + 0.5 * a, 1.0) / 0.3, 0.0, 1.0))
		d[ARM0 + 3 * a + 1] += idle * k * (0.06 * breath + 0.1 * flex)
		d[ARM0 + 3 * a + 2] += idle * k * 0.3 * flex
	# A leg re-planted now and then (a different one each time): lifted, set down a little forward.
	var u := _t / 2.4
	var seg := floorf(u)
	if _hash(seg + 7.0) > 0.4:
		var j := int(_hash(seg + 3.0) * LEGS.size()) % LEGS.size()
		var e := sin(PI * clampf((u - seg - 0.2) / 0.2, 0.0, 1.0))
		d[LEG0 + 3 * j] += idle * 0.15 * e
		d[LEG0 + 3 * j + 1] += idle * 0.45 * e
		d[LEG0 + 3 * j + 2] -= idle * 0.4 * e
	return idle * k * 0.008 * breath


## The tell at its progress (_coil): a short crouch, then it leans back and braces its legs wide, the posts rise out of
## their straps and tip forward, the arms raise and open toward the line, the head up; a quiver at the top (not with
## reduced motion). Returns its lift.
func _tell_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	var p := _coil
	if p <= 0.0:
		return 0.0
	var crouch := sin(PI * clampf(p / 0.3, 0.0, 1.0)) * (1.0 - smoothstep(0.1, 0.35, p))
	var brace := smoothstep(0.15, 0.6, p)
	var lift_posts := smoothstep(0.2, 0.75, p)
	d[PITCH] += 0.16 * brace * k - 0.05 * crouch
	d[HEAD_P] += 0.22 * brace - 0.12 * crouch
	d[HEAD_Y] *= 1.0 - brace
	for j in LEGS.size():
		d[LEG0 + 3 * j + 1] -= 0.18 * brace + 0.15 * crouch
		d[LEG0 + 3 * j + 2] += 0.25 * brace
	for a in ARMS.size():
		d[ARM0 + 3 * a] += 0.35 * brace
		d[ARM0 + 3 * a + 1] += 0.75 * brace - 0.1 * crouch
		d[ARM0 + 3 * a + 2] += 0.6 * brace
	for q in 2:
		d[POST0 + 3 * q] += 0.16 * lift_posts
		d[POST0 + 3 * q + 1] += 0.35 * lift_posts
	if not calm and _state == WorldReader.STATE_WINDUP:
		var top := smoothstep(0.6, 0.8, p)
		d[ROLL] += 0.015 * top * sin(TAU * 13.0 * _t)
		for q in 2:
			d[POST0 + 3 * q + 1] += 0.05 * top * sin(TAU * 11.0 * _t + q)
		if tell_flashing(p):
			for a in ARMS.size():
				d[ARM0 + 3 * a + 2] += 0.12 * sin(TAU * 9.0 * _t + a)
	return -0.04 * crouch * k + 0.01 * brace * k


## The plant (from the strike): the posts shoot up and forward and are gone (they stand at the cable's ends), the body
## kicks back and settles, the arms sweep apart along the cable and come back; then the reload: new posts rise out of
## the straps. Returns its lift.
func _plant_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _plant_t < 0.0:
		return 0.0
	var u := clampf(_plant_t / PLANT_SECONDS, 0.0, 1.0)
	var fly := smoothstep(0.0, 0.3, u)
	var kick := sin(PI * clampf(u / 0.35, 0.0, 1.0))
	var spread := sin(PI * clampf((u - 0.05) / 0.8, 0.0, 1.0))
	var held := 1.0 - smoothstep(0.0, 0.25, u)  # the tell's hold, let go
	d[PITCH] += (0.22 * kick * held - 0.12 * kick * (1.0 - held) + 0.16 * held) * k
	d[HEAD_P] += 0.2 * held - 0.1 * kick
	for a in ARMS.size():
		d[ARM0 + 3 * a] += 0.35 * held + 0.75 * spread
		d[ARM0 + 3 * a + 1] += 0.75 * held + 0.25 * spread
		d[ARM0 + 3 * a + 2] += 0.6 * held + 0.5 * spread
	for j in LEGS.size():
		d[LEG0 + 3 * j + 1] -= 0.18 * held + 0.12 * kick
		d[LEG0 + 3 * j + 2] += 0.25 * held
	# The posts: launched from the tell's hold (up, tipping forward, shrinking away), then the new ones rising out of
	# the straps from below as they grow.
	var r := _reloading()
	for q in 2:
		if _plant_t < RELOAD_FROM:
			d[POST0 + 3 * q] = 0.16 + 0.3 * fly
			d[POST0 + 3 * q + 1] = 0.35 + 0.8 * fly
			d[POST0 + 3 * q + 2] = lerpf(1.0, POST_MIN, fly)
		else:
			d[POST0 + 3 * q] = -0.25 * (1.0 - r)
			d[POST0 + 3 * q + 1] = 0.0
			d[POST0 + 3 * q + 2] = lerpf(POST_MIN, 1.0, r)
	if not calm:
		d[ROLL] += 0.03 * kick * sin(TAU * 9.0 * _plant_t)
	return (-0.03 * kick + 0.01 * held) * k


## The reload now (0 while it has none coming, rising to 1 as the new posts stand).
func _reloading() -> float:
	if _plant_t < RELOAD_FROM:
		return 0.0
	return smoothstep(0.0, 1.0, (_plant_t - RELOAD_FROM) / RELOAD_SECONDS)


## A hit (its HP fell): the body jolts back, the head ducks, a leg scrabbles, the posts rattle. Returns its lift.
func _hurt_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _hurt_t < 0.0:
		return 0.0
	var h := _hurt_t / HURT_SECONDS
	var e := smoothstep(0.0, 0.15, h) * (1.0 - smoothstep(0.2, 1.0, h))
	d[PITCH] += 0.1 * e * k
	d[HEAD_P] -= 0.25 * e * k
	d[ROLL] += 0.05 * e * k * (1.0 if _hurt_leg % 2 == 0 else -1.0)
	var j := LEG0 + 3 * _hurt_leg
	d[j + 1] += 0.5 * e * k
	d[j + 2] -= 0.45 * e * k
	for a in ARMS.size():
		d[ARM0 + 3 * a + 1] += 0.25 * e * k
	if not calm:
		d[j] += 0.25 * e * sin(TAU * 8.0 * _hurt_t)
		for q in 2:
			d[POST0 + 3 * q + 1] += 0.12 * e * sin(TAU * 12.0 * _hurt_t + q)
	return -0.02 * e * k


## The rise-in: low, legs drawn up and shins tucked, the arms folded, rising as it arrives. Returns its lift.
func _rise_pose(d: PackedFloat32Array) -> float:
	var r := 1.0 - _rise
	if r <= 0.0:
		return 0.0
	for j in LEGS.size():
		d[LEG0 + 3 * j + 1] += 0.55 * r
		d[LEG0 + 3 * j + 2] -= 0.8 * r
	for a in ARMS.size():
		d[ARM0 + 3 * a + 1] -= 0.4 * r
		d[ARM0 + 3 * a + 2] -= 0.7 * r
	d[HEAD_P] -= 0.25 * r
	return -0.22 * r


## The death: the legs buckle out and it drops onto its belly, rolling aside, the arms fall slack, the head sags, the
## posts topple back, legs scrabbling a moment (not with reduced motion). Returns the lift.
func _death_pose(d: PackedFloat32Array, lift: float, calm: bool) -> float:
	if _die_t < 0.0:
		return lift
	var u := clampf(_die_t / (DEATH_SECONDS * 0.9), 0.0, 1.0)
	var buckle := smoothstep(0.0, 0.45, u)
	var settle := smoothstep(0.35, 0.9, u)
	var keep := 1.0 - buckle
	for j in [SWAY, HEAD_Y]:
		d[j] *= keep
	lift *= keep
	d[ROLL] = lerpf(d[ROLL], -0.32, settle)
	d[PITCH] = lerpf(d[PITCH], -0.12, buckle)
	d[HEAD_P] = lerpf(d[HEAD_P], -0.35, buckle)
	for j in LEGS.size():
		var b := LEG0 + 3 * j
		d[b] *= keep
		d[b + 1] = lerpf(d[b + 1], 0.95, buckle)
		d[b + 2] = lerpf(d[b + 2], 0.9, buckle)
		if not calm:
			var scrabble := buckle * (1.0 - smoothstep(0.5, 0.8, u))
			d[b + 2] += 0.3 * scrabble * sin(TAU * 8.0 * _die_t + j * 1.9)
	for a in ARMS.size():
		d[ARM0 + 3 * a] = lerpf(d[ARM0 + 3 * a], 0.3, buckle)
		d[ARM0 + 3 * a + 1] = lerpf(d[ARM0 + 3 * a + 1], -0.7, buckle)
		d[ARM0 + 3 * a + 2] = lerpf(d[ARM0 + 3 * a + 2], -0.6, settle)
	for q in 2:
		d[POST0 + 3 * q + 1] = lerpf(d[POST0 + 3 * q + 1], -1.2, smoothstep(0.15, 0.75, u))
	return lift - 0.3 * buckle


## The post tops' glow: a faint flicker at rest (steady with reduced motion), climbing through the tell with sparks,
## a burst as they launch, the new ones coming up dim, fizzling out as it dies.
func _spark_energy(calm: bool) -> float:
	var e := SPARK_REST
	if not calm:
		e *= 1.0 + 0.25 * sin(TAU * 7.0 * _t) * sin(TAU * 2.3 * _t)
	if _coil > 0.0:
		e = lerpf(e, SPARK_TELL, smoothstep(0.1, 0.8, _coil))
		if not calm and tell_flashing(_coil):
			e *= 1.0 + 0.35 * signf(sin(TAU * TELL_FLICKER_HZ * 2.0 * _t))
	if _plant_t >= 0.0:
		var u := _plant_t / PLANT_SECONDS
		e = maxf(e, SPARK_PLANT * (1.0 - smoothstep(0.0, 0.4, u)))
		if _plant_t >= RELOAD_FROM:
			e = SPARK_REST * _reloading()
	if _die_t >= 0.0:
		var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
		var fizz := 1.0 if calm else 0.6 + 0.8 * absf(sin(TAU * 11.0 * _die_t))
		e = lerpf(e, 0.0, smoothstep(0.2, 1.0, u)) * fizz
	return e


## The visor's glow: rest; through the tell climbing to VISOR_TELL and flashing from TELL_FLASH_FROM (a flicker; a
## steady step with reduced motion); fading after the plant; out as it dies.
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
	if _plant_t >= 0.0:
		e = maxf(e, VISOR_TELL * (1.0 - smoothstep(0.0, 0.6, _plant_t / PLANT_SECONDS)))
	if _die_t >= 0.0:
		e *= 1.0 - smoothstep(0.3, 1.0, _die_t / DEATH_SECONDS) * 0.95
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
	return SoloVat.normalized(drives(), VAT_DRIVES)


## The post tops' glow (the instance's accent glow; the visor's is the VISOR drive).
func glow_energy() -> float:
	return spark_energy()


## The owner's colour map (VatLooks' textured variant; HordeVat.texture), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## One grid per drive but the visor's (a turn sampled finely, a slide or a stretch on two samples: exact), the joints
## as the table.
func vat_rig() -> Dictionary:
	var grids: Array = []
	for d in VAT_SAMPLES.size():
		grids.append([[d, VAT_SAMPLES[d]]])
	var out := SoloVat.rig("wire_weaver", VAT_DRIVES, grids, _joints, true)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out
