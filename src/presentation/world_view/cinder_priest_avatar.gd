class_name CinderPriestAvatar
extends AvatarBase
## v0.11.0 O17d (ENEMIES.md R6; owner, 2026-11-08: "make sure they are animated as good as you can"): the Red Canyon's
## Cinder Priest on the owner's model (EnemyModels &"cinder_priest", cut by scripts/assets/o17_prep_cinder_priest.py),
## posed in code. A tall violet-robed priest with a staff taller than itself; it stands by its lava vent and the vent
## erupts every 3 s, and its staff keeps time with the vent (WorldReader.priest_pulse, the vent's warning 0..1000):
## - idle chant: a slow hover-like sway of the robe, the head bowed, the free hand turning a small circle, the crystal
##   breathing;
## - glide (no legs): the robe bobs, the body leans into the travel, the hem trails behind and flutters;
## - the eruption cycle, on the sim's numbers only: through the vent's warning the staff is raised slowly (a small dip
##   first), the crystal brightens, the body rises a little and looks up, the free hand reaches out; over the warning's
##   last SLAM_FROM the staff is slammed down toward the vent, landing on the eruption tick (the vent's last eruption,
##   WorldReader.lava_vents), held, and the body recoils and settles (a damped follow-through) while the crystal
##   flares; the body turns toward its vent through it;
## - hit flinch: AvatarBase's lean, plus the hood snapping back and the arms flung;
## - death (die(), from ActorViews when the sim drops it): a jolt, the staff slips from the hand and falls, the figure
##   crumples down into its robe and the crystal's glow dies, over DEATH_SECONDS;
## - spawn: it rises up out of its robe; reduced motion (ViewPrefs.reduced_motion): the idle and glide at CALM of their
##   size, no flutter, tremble, flicker or overshoot; the cycle's poses stay (they are the tell).
## The model's parts hang in a chain of joints (Body > Waist > Hem / Torso > Hood, ArmL, ArmR > Staff); every joint's
## transform is made of its own drives (SoloVat's one-number joints), so the VAT crowd draws it from a bake of this very
## pose code (vat_rig). Without the model file a code-made body of the same parts stands in (L15).
## Presentation only (EI-07): sync() reads the sim through WorldReader once per tick, advance() animates in frame
## time; nothing here reaches the sim. ActorViews puts it under the actor's facing node: +X is the front.

const KIND := WorldReader.KIND_CINDER_PRIEST
const MODEL_ID := &"cinder_priest"
## The body's top (m, for the health bar; EnemyModels scales the model to it).
const HEIGHT := 1.75
const OUTLINE_M := 0.02
const DEATH_SECONDS := 0.9
const SPAWN_SECONDS := 0.6
## Its colours (the art list's ranged violet, the family's charcoal and greys; the ember crystal, the gem visor).
const ROLE := Color("#8A50D8")
const TRIM := Color("#2A2630")
const GREY := Color("#5A5560")
const BONE := Color("#D9CDB8")
const EMBER := Color("#FF7A2E")
const GEM := Color("#C090FF")
## v0.11.0 F6 (owner: "reuse the existing Priest model with a modified color palette"): the Arc Caster draws this very
## model (KIND_ARC_CASTER) in its own colours. One block per kind: role (the plates), base (a multiplier on the frame
## and bone: WHITE as delivered), gem (the visor), ember (the staff's crystal).
const LOOKS := {
	WorldReader.KIND_CINDER_PRIEST: {"role": ROLE, "base": Color.WHITE, "gem": GEM, "ember": EMBER},
	WorldReader.KIND_ARC_CASTER:
	{
		"role": Color("#8F8CF2"),
		"base": Color.WHITE,
		"gem": Color("#BFF6FF"),
		"ember": Color("#5FD8FF"),
	},
}
## The code-made body's joints (m; the model's own come from its file: the same places).
const WAIST := Vector3(0, 0.752, 0)
const NECK := Vector3(0, 1.208, -0.052)
const SHOULDER_R := Vector3(0, 1.103, 0.228)
const SHOULDER_L := Vector3(-0.035, 1.085, -0.228)
const GRIP := Vector3(0.193, 0.971, 0.359)
## Crumpled fully (CRUMPLE 1), the hem keeps 1 - CRUMPLE_K of its height and spreads by CRUMPLE_SPREAD; the waist sinks
## with it so the hem stays on the floor.
const CRUMPLE_K := 0.75
const CRUMPLE_SPREAD := 0.18
## The slam: from this share of the vent's warning to the eruption (accelerating), held SLAM_HOLD_S, then the recoil
## (RECOIL_HZ, damped by RECOIL_DECAY a second) until STRIKE_END_S after the eruption. Starting values.
const SLAM_FROM := 0.9
const SLAM_HOLD_S := 0.1
const RECOIL_HZ := 1.5
const RECOIL_DECAY := 5.5
const STRIKE_END_S := 1.4
## The crystal's glow: at rest, added at the top of the warning, the eruption's flare (decaying FLARE_DECAY a second);
## the visor's at rest. Starting values.
const CRYSTAL_REST := 2.2
const CRYSTAL_GATHER := 6.0
const CRYSTAL_FLARE := 12.0
const FLARE_DECAY := 6.0
const VISOR_REST := 1.6
## The chant's breath and the glide's bob (Hz), the glide's full speed (m/s: the sim's 2.4), the turn to the vent's
## widest (radians) and rates (a second). Reduced motion: the idle and glide sways at CALM of their size.
const CHANT_HZ := 0.45
const CIRCLE_HZ := 0.55
const GLIDE_HZ := 1.4
const GLIDE_MPS := 2.4
const TURN_MAX := 1.1
const CALM := 0.35

## The raw drives (_vd) and their specs [lo, hi, loop] (SoloVat). F: forward (a top's lean, a hanging part's bottom
## or hand swinging forward), S: sideways (toward +Z, the right; an arm's: outward), YAW: the turn to the vent, CRUMPLE:
## the robe crumpled (0..1), STAFF_DROP: the staff slipped down in the hand (m), VISOR: the visor's glow (sent as is).
const YAW := 0
const LEAN_F := 1
const LEAN_S := 2
const CRUMPLE := 3
const HEM_F := 4
const HEM_S := 5
const TORSO_F := 6
const TORSO_S := 7
const HOOD_F := 8
const HOOD_S := 9
const ARM_L_F := 10
const ARM_L_S := 11
const ARM_R_F := 12
const ARM_R_S := 13
const STAFF_DROP := 14
const STAFF_F := 15
const STAFF_S := 16
const VISOR := 17
const VAT_DRIVES := [
	[-1.2, 1.2, false],
	[-0.4, 0.4, false],
	[-0.3, 0.3, false],
	[0.0, 1.0, false],
	[-0.45, 0.45, false],
	[-0.35, 0.35, false],
	[-0.6, 1.0, false],
	[-0.3, 0.3, false],
	[-1.0, 1.0, false],
	[-0.4, 0.4, false],
	[-0.8, 1.4, false],
	[-0.4, 1.1, false],
	[-0.8, 1.6, false],
	[-0.6, 0.6, false],
	[-0.3, 0.8, false],
	[-0.6, 1.8, false],
	[-0.5, 1.6, false],
	[0.0, 0.0, false],
]
## Each turn drive's grid samples (SoloVat; the error report: scripts/checks/vat_bake_report.gd).
const SAMPLES := {
	YAW: 49,
	LEAN_F: 25,
	LEAN_S: 25,
	HEM_F: 33,
	HEM_S: 25,
	TORSO_F: 49,
	TORSO_S: 25,
	HOOD_F: 49,
	HOOD_S: 25,
	ARM_L_F: 57,
	ARM_L_S: 49,
	ARM_R_F: 65,
	ARM_R_S: 33,
	STAFF_F: 65,
	STAFF_S: 49,
}
## The poses the cycle adds at full weight: [drive, value] (and their lifts, m). Starting values, tuned on the clip
## sheet (scripts/shots/o17_priest_clips.gd).
const GATHER_POSE := [
	[ARM_R_F, 1.12],
	[ARM_R_S, 0.14],
	[STAFF_F, 1.24],
	[STAFF_DROP, -0.16],
	[TORSO_F, -0.2],
	[HOOD_F, -0.42],
	[LEAN_F, -0.06],
	[HEM_F, 0.06],
	[ARM_L_F, 0.62],
	[ARM_L_S, 0.42],
]
const GATHER_LIFT := 0.09
const SLAM_POSE := [
	[ARM_R_F, 0.36],
	[ARM_R_S, -0.06],
	[STAFF_F, 1.0],
	[STAFF_DROP, 0.06],
	[TORSO_F, 0.48],
	[HOOD_F, 0.42],
	[LEAN_F, 0.13],
	[HEM_F, -0.14],
	[ARM_L_F, -0.42],
	[ARM_L_S, 0.62],
]
const SLAM_LIFT := -0.05
const FLINCH_POSE := [
	[HOOD_F, -0.8],
	[TORSO_F, -0.3],
	[HEM_F, 0.1],
	[ARM_L_F, -0.35],
	[ARM_L_S, 0.6],
	[ARM_R_F, 0.2],
	[STAFF_F, -0.2],
	[STAFF_S, -0.15],
]

## The pieces' joints by name (body, waist, hem, torso, hood, arm_l, arm_r, staff; none on a VAT avatar).
var parts := {}
## True when the body is the owner's model.
var has_model := false
## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds no pieces.
var vat := false
var kind := KIND
## The colours in use (LOOKS[kind] when empty at setup(); tools set it first to try another).
var palette := {}

var _vd := PackedFloat32Array()
var _lift := 0.0
var _crystal := CRYSTAL_REST
var _crystal_mat := StandardMaterial3D.new()
var _visor_mat := StandardMaterial3D.new()
# The joints' places (m, the avatar's frame; the model's or the code body's) and the model's scale.
var _waist := WAIST
var _neck := NECK
var _shoulder_r := SHOULDER_R
var _shoulder_l := SHOULDER_L
var _grip := GRIP
var _scale := 1.0
# Sim state from the last sync: its state, the vent's pulse (0..1), seconds since its vent erupted (-1: none in the
# strike's span), the vent's direction in the facing's frame (radians; NAN: none), the facing's yaw.
var _state := WorldReader.STATE_SPAWN
var _pulse := 0.0
var _erupt_s := -1.0
var _vent_yaw := NAN
var _facing := 0.0
# Frame-time animation: the rise-in (0..1), the glide's share (0..1) and its direction (the facing's frame: x
# forward, y right), the turn to the vent (its share 0..1 and the eased yaw), the death (seconds in; -1: alive).
var _rise := 0.0
var _glide := 0.0
var _dir := Vector2.RIGHT
var _turn := 0.0
var _yaw := 0.0
var _die_t := -1.0


## ActorViews: builds the priest for the actor `root` under its `facing` node (drawn by the VAT crowd while the switch
## is on, ActorViews._solo_vat), its metas set; returns its height (the bar's).
static func attach(views: ActorViews, root: Node3D, facing: Node3D, p_kind: int) -> float:
	var a := CinderPriestAvatar.new()
	a.kind = p_kind
	views._solo_vat(root, a, p_kind)
	a.setup(views.outline_color, views.technique)
	facing.add_child(a)
	root.set_meta(&"enemy_avatar", a)
	root.set_meta(&"mats", a.body_materials.duplicate())
	return HEIGHT


func setup(outline_color: Color, technique: StringName = &"outline") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	if palette.is_empty():
		palette = LOOKS.get(kind, LOOKS[KIND])
	for m: StandardMaterial3D in [_crystal_mat, _visor_mat]:
		m.roughness = 1.0
		m.emission_enabled = true
	_crystal_mat.albedo_color = palette["ember"]
	_crystal_mat.emission = palette["ember"]
	_visor_mat.albedo_color = palette["gem"]
	_visor_mat.emission = palette["gem"]
	_visor_mat.set_meta(SoloVat.GLOW, VISOR + 1)  # VAT: the visor glows at its own drive
	var m := EnemyModels.get_model(MODEL_ID)
	has_model = not m.is_empty()
	if has_model:
		_scale = float(m["scale"])
		var pv: Dictionary = m["parts"]
		_waist = _pivot(pv, &"hem", WAIST)
		_neck = _pivot(pv, &"hood", NECK)
		_shoulder_r = _pivot(pv, &"arm_r", SHOULDER_R)
		_shoulder_l = _pivot(pv, &"arm_l", SHOULDER_L)
		_grip = _pivot(pv, &"staff", GRIP)
	if vat:
		_pose()
		return
	_build_joints()
	if has_model:
		_build_model(m, outline_color)
	else:
		_build_code_body(outline_color, technique)
	_pose()


func _pivot(pv: Dictionary, pname: StringName, fallback: Vector3) -> Vector3:
	if not pv.has(pname):
		return fallback
	return ((pv[pname] as Dictionary)["pivot"] as Vector3) * _scale


func _joint(pname: String, parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pname.to_pascal_case()
	n.position = at
	var host: Node3D = self if parent == null else parent
	host.add_child(n)
	parts[pname] = n
	return n


func _build_joints() -> void:
	var body := _joint("body", null, Vector3.ZERO)
	var waist := _joint("waist", body, _waist)
	_joint("hem", waist, Vector3.ZERO)
	var torso := _joint("torso", waist, Vector3.ZERO)
	_joint("hood", torso, _neck - _waist)
	_joint("arm_l", torso, _shoulder_l - _waist)
	var arm_r := _joint("arm_r", torso, _shoulder_r - _waist)
	_joint("staff", arm_r, _grip - _shoulder_r)


## The owner's model: each part's mesh under its joint (the model's `body` part is the torso), its violet plates in
## the role colour (greyscale in the texture), its frame as delivered, the crystal and the visor on their glows.
func _build_model(m: Dictionary, _outline: Color) -> void:
	var tex: Texture2D = m["texture"]
	var mats := {}
	for slot: StringName in [&"base", &"role"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = palette["role"] if slot == &"role" else palette["base"]
		mat.roughness = 1.0
		ActorLooks.outline(mat, Color.BLACK, 0.0)
		mat.set_meta(&"enemy_tex", true)
		mats[slot] = ActorViews.flashable(mat)
		body_materials.append(mat)
	var parts_in: Dictionary = m["parts"]
	for pname: StringName in parts_in:
		var joint: Node3D = parts.get(
			"torso" if pname == &"body" else String(pname), parts["torso"]
		)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = (parts_in[pname] as Dictionary)["mesh"]
		mi.scale = Vector3.ONE * _scale
		mi.extra_cull_margin = 1.0  # poses move parts past the rest bounds
		var surfaces: Array = (parts_in[pname] as Dictionary)["surfaces"]
		for k in surfaces.size():
			var glow := _crystal_mat if pname == &"staff" else _visor_mat
			mi.set_surface_override_material(
				k, glow if surfaces[k] == &"glow" else mats.get(surfaces[k], mats[&"base"])
			)
		joint.add_child(mi)


## L15: without the model file, a code-made priest of the same parts (the O13c stand-in's shapes): a violet robe hem,
## a charcoal chest, a pointed violet hood with a dark face plate and a gem visor, grey arms, a tall grey staff with
## the ember crystal.
func _build_code_body(outline: Color, technique: StringName) -> void:
	var team := Color.BLACK
	var w := _waist.y
	_outlined(
		parts["hem"],
		ArcCasterAvatar._frustum(0.36, 0.19, w, 7),
		Vector3(0, -w, 0),
		palette["role"],
		outline,
		team,
		technique,
		OUTLINE_M
	)
	for n in 6:  # the hem's spikes, bone and grey
		var a := n * TAU / 6.0
		_outlined(
			parts["hem"],
			NeedleAvatar._chamfer_box(Vector3(0.06, 0.12, 0.06), 0.015),
			Vector3(cos(a) * 0.34, 0.06 - w, sin(a) * 0.34),
			BONE if n % 2 == 0 else GREY,
			outline,
			team,
			technique,
			OUTLINE_M
		)
	var chest := _neck.y - w
	_outlined(
		parts["torso"],
		ArcCasterAvatar._frustum(0.2, 0.24, chest, 6),
		Vector3.ZERO,
		TRIM,
		outline,
		team,
		technique,
		OUTLINE_M
	)
	var hood: Node3D = parts["hood"]
	_outlined(
		hood,
		ArcCasterAvatar._octahedron(0.2),
		Vector3(-0.02, 0.2, 0),
		palette["role"],
		outline,
		team,
		technique,
		OUTLINE_M
	)
	_outlined(
		hood,
		NeedleAvatar._chamfer_box(Vector3(0.08, 0.16, 0.14), 0.02),
		Vector3(0.13, 0.08, 0),
		TRIM,
		outline,
		team,
		technique,
		OUTLINE_M
	)
	_glow_piece(hood, Vector3(0.03, 0.04, 0.08), Vector3(0.18, 0.1, 0), _visor_mat)
	for side: String in ["arm_l", "arm_r"]:
		_outlined(
			parts[side],
			NeedleAvatar._chamfer_box(Vector3(0.08, 0.4, 0.08), 0.02),
			Vector3(0.04, -0.18, 0),
			GREY,
			outline,
			team,
			technique,
			OUTLINE_M
		)
	var staff: Node3D = parts["staff"]
	_outlined(
		staff,
		NeedleAvatar._chamfer_box(Vector3(0.05, 1.72, 0.05), 0.012),
		Vector3(0, 1.72 * 0.5 - _grip.y, 0),
		GREY,
		outline,
		team,
		technique,
		OUTLINE_M
	)
	_glow_piece(staff, Vector3(0.12, 0.18, 0.12), Vector3(0, 1.62 - _grip.y, 0), _crystal_mat)


func _glow_piece(parent: Node3D, size: Vector3, at: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = NeedleAvatar._chamfer_box(size, minf(size.x, size.z) * 0.25)
	mi.position = at
	mi.material_override = mat
	parent.add_child(mi)


func sync(reader: WorldReader, i: int) -> void:
	if kind == WorldReader.KIND_ARC_CASTER:
		_sync_caster(reader, i)
		return
	var s := {
		"tick": reader.tick(),
		"state": reader.actor_state(i),
		"pos": reader.actor_pos(i),
		"pulse": reader.priest_pulse(i),
		"facing": SimPlane.yaw_of(reader.actor_facing(i)),
	}
	var id := reader.actor_id(i)
	for v: Array in reader.lava_vents():  # its own vent: its last eruption and where it stands
		if int(v[5]) != id or not bool(v[4]):
			continue
		s["erupt_age"] = int(v[3])
		var to: Vector2 = (v[0] as Vector2) - reader.actor_pos(i)
		if to.length_squared() > 1e-4:
			s["vent_yaw"] = wrapf(atan2(to.y, to.x) - float(s["facing"]), -PI, PI)
		break
	apply_state(s)


## The Arc Caster's cast on the Priest's clips (it has no vent): its windup's progress (the sim's telegraph, 0..1000) is
## the gather (staff raised, crystal brightening, the slam over the last tenth), entering ACTIVE is the strike (hold,
## recoil, flare). Bolt, spread and rune share it: the same raised staff, the sim says what leaves it.
func _sync_caster(reader: WorldReader, i: int) -> void:
	var st := reader.actor_state(i)
	var s := {
		"tick": reader.tick(),
		"state": st,
		"pos": reader.actor_pos(i),
		"facing": SimPlane.yaw_of(reader.actor_facing(i)),
	}
	if st == WorldReader.STATE_WINDUP:
		s["pulse"] = int(reader.telegraph(i).get("progress", 0))
	apply_state(s)


## The same as sync(), from plain values (tests and tools drive the avatar with this): tick, state, pos (the sim
## plane), pulse (0..1000, priest_pulse), erupt_age (ticks since its vent erupted; -1 or missing: none), vent_yaw
## (radians in the facing's frame; missing: no vent), facing (the facing's yaw, radians). Missing keys: at rest.
func apply_state(s: Dictionary) -> void:
	var was := _state
	_state = int(s.get("state", WorldReader.STATE_MOVE))
	_pulse = clampf(float(s.get("pulse", 0)) / 1000.0, 0.0, 1.0)
	var age := int(s.get("erupt_age", -1))
	if kind == WorldReader.KIND_ARC_CASTER:  # its strike starts as it enters ACTIVE; advance() ages it
		if _state == WorldReader.STATE_ACTIVE and was != WorldReader.STATE_ACTIVE:
			_erupt_s = 0.0
	else:
		_erupt_s = age / 60.0 if age >= 0 and age / 60.0 < STRIKE_END_S else -1.0
	_vent_yaw = float(s["vent_yaw"]) if s.has("vent_yaw") else NAN
	_facing = float(s.get("facing", 0.0))
	_track_motion(int(s.get("tick", 0)), s.get("pos", Vector2.ZERO) as Vector2, 30.0)
	if _fresh:
		_fresh = false
		_rise = 0.0 if _state == WorldReader.STATE_SPAWN else 1.0
		_pose()


func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or (parts.is_empty() and not vat):
		return
	_t += dt
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt / SPAWN_SECONDS)
	if _erupt_s >= 0.0:
		_erupt_s += dt
		if _erupt_s >= STRIKE_END_S:
			_erupt_s = -1.0
	if _die_t >= 0.0:
		_die_t += dt
	# The glide: the sim's velocity in the facing's frame (x forward, y right).
	var v3 := Basis(Vector3.UP, -_facing) * SimPlane.to_3d(_vel)
	var local := Vector2(v3.x, v3.z)
	var speed := local.length()
	_glide = lerpf(_glide, clampf(speed / GLIDE_MPS, 0.0, 1.0), _rate(6.0, dt))
	if speed > 0.05:
		_dir = _dir.lerp(local / speed, _rate(8.0, dt)).normalized()
	# The turn to the vent: through its warning and the strike, back after.
	var engaged := not is_nan(_vent_yaw) and (_pulse > 0.0 or (_erupt_s >= 0.0 and _erupt_s < 0.7))
	_turn = move_toward(_turn, 1.0 if engaged else 0.0, dt * (4.0 if engaged else 1.5))
	if not is_nan(_vent_yaw):
		_yaw = lerpf(_yaw, clampf(_vent_yaw, -TURN_MAX, TURN_MAX), _rate(8.0, dt))
	_pose()


## Starts the death (ActorViews, when the sim drops it): false when it is already dying.
func die() -> bool:
	if _die_t >= 0.0:
		return false
	_die_t = 0.0
	return true


func dying() -> bool:
	return _die_t >= 0.0


## The pose's numbers (the VAT drives, the lift, the glows) from the state, then the joints from them.
func _pose() -> void:
	if _vd.size() != VAT_DRIVES.size():
		_vd.resize(VAT_DRIVES.size())
	_vd.fill(0.0)
	var calm := ViewPrefs.reduced_motion
	var a := CALM if calm else 1.0
	var die_u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0) if _die_t >= 0.0 else 0.0
	var fold := smoothstep(0.12, 0.8, die_u) if _die_t >= 0.0 else 0.0
	_lift = 0.0
	_crystal = CRYSTAL_REST
	var visor := VISOR_REST
	# The cycle's weights: the raise through the warning (eased, a small dip first), the slam over its last part to
	# the eruption tick, then held and the recoil after it.
	var p := _pulse
	var slam := 0.0
	if p > SLAM_FROM:
		var u := (p - SLAM_FROM) / (1.0 - SLAM_FROM)
		slam = u * u
	var gather := smoothstep(0.0, 1.0, p) * (1.0 - slam)
	var dip := 0.18 * sin(PI * clampf(p / 0.2, 0.0, 1.0)) if p > 0.0 and p < 0.2 else 0.0
	if _erupt_s >= 0.0:
		var e := _erupt_s
		if e < SLAM_HOLD_S:
			slam = 1.0
		else:
			var x := e - SLAM_HOLD_S
			slam = exp(-x * RECOIL_DECAY) * (1.0 if calm else cos(x * TAU * RECOIL_HZ))
		_crystal += CRYSTAL_FLARE * (0.6 if calm else 1.0) * exp(-e * FLARE_DECAY)
	var busy := clampf(maxf(gather, absf(slam)), 0.0, 1.0)
	var still := (1.0 - 0.75 * busy) * (1.0 - fold) * _rise
	_idle(a * still, a, still)
	_glide_pose(a * (1.0 - fold), calm)
	_add(GATHER_POSE, gather)
	_lift += GATHER_LIFT * gather
	_vd[ARM_R_F] -= dip
	_vd[STAFF_DROP] += dip * 0.2
	_crystal += CRYSTAL_GATHER * gather
	visor += 1.2 * gather
	if gather > 0.0 and p > 0.8 and not calm:  # the staff trembles at the top of the raise
		var shake := 0.025 * sin(_t * TAU * 11.0) * (p - 0.8) / 0.2
		_vd[STAFF_S] += shake
		_vd[ARM_R_F] += shake * 0.6
		_crystal += 1.2 * sin(_t * TAU * 9.0)
	_add(SLAM_POSE, slam)
	_lift += SLAM_LIFT * slam
	_crystal += CRYSTAL_GATHER * maxf(slam, 0.0) * (1.0 if _erupt_s < 0.0 else 0.0)
	_vd[YAW] = _yaw * _turn * (1.0 - fold)
	_add(FLINCH_POSE, flinch_amount())
	if _rise < 1.0:  # the rise-in: up out of its robe
		var r := 1.0 - _rise
		_vd[CRUMPLE] += 0.9 * r
		_vd[TORSO_F] += 0.55 * r
		_vd[HOOD_F] += 0.5 * r
		_crystal *= _rise
		visor *= _rise
	if _die_t >= 0.0:
		_death(die_u, fold, calm)
		_crystal *= 1.0 - smoothstep(0.15, 0.75, die_u)
		visor *= 1.0 - smoothstep(0.1, 0.6, die_u)
	for k in VAT_DRIVES.size():
		var spec: Array = VAT_DRIVES[k]
		if float(spec[1]) > float(spec[0]):
			_vd[k] = clampf(_vd[k], spec[0], spec[1])
	_vd[VISOR] = visor
	_crystal = maxf(_crystal, 0.0)
	_crystal_mat.emission_energy_multiplier = _crystal
	_visor_mat.emission_energy_multiplier = visor
	if not vat and not parts.is_empty():
		_apply()


## The chant: `s` the sway's size (CALM with reduced motion, less while busy or dying), `a` the circle's, `held` the
## bowed head's share (it lifts through the cycle).
func _idle(s: float, a: float, held: float) -> void:
	var ph := _t * TAU * CHANT_HZ
	var slow := _t * TAU * 0.21
	var c := _t * TAU * CIRCLE_HZ
	_lift += 0.03 * s * sin(ph)
	_vd[LEAN_F] += 0.02 * s * sin(ph + 0.5)
	_vd[LEAN_S] += 0.035 * s * sin(slow)
	_vd[HEM_F] -= 0.03 * s * sin(ph - 0.8)  # the hem lags the sway
	_vd[HEM_S] -= 0.035 * s * sin(slow - 0.9)
	_vd[TORSO_F] += 0.1 * held + 0.035 * s * sin(ph + 1.0)
	_vd[TORSO_S] += 0.02 * s * sin(slow + 0.6)
	_vd[HOOD_F] += 0.22 * held + 0.05 * s * sin(ph + 1.7)  # the head bowed, a beat behind the chest
	_vd[HOOD_S] += 0.05 * s * sin(_t * TAU * 0.17)
	_vd[ARM_L_F] += 0.36 * held + 0.15 * a * held * sin(c)  # the free hand turns a small circle
	_vd[ARM_L_S] += 0.16 * held + 0.12 * a * held * cos(c)
	_vd[ARM_R_F] += 0.03 * s * sin(ph + 0.3)
	_vd[STAFF_F] += 0.03 * s * sin(ph + 0.3)  # the staff stays upright as the arm sways
	_crystal *= 1.0 + 0.2 * a * sin(ph * 1.3)


## The glide: the robe leaning into the travel, the hem trailing and fluttering, the bob, the arms carried.
func _glide_pose(s: float, calm: bool) -> void:
	var k := _glide * (0.6 if calm else 1.0) * (1.0 if s > 0.0 else 0.0)
	if k <= 0.0:
		return
	var d := _dir
	var ph := _t * TAU * GLIDE_HZ
	var flutter := 0.0 if calm else 1.0
	_lift += 0.035 * k * s * (0.5 + 0.5 * sin(ph))
	_vd[LEAN_F] += 0.16 * k * d.x
	_vd[LEAN_S] += 0.12 * k * d.y
	_vd[HEM_F] += -0.24 * k * d.x + 0.05 * k * flutter * sin(ph - 0.7)
	_vd[HEM_S] += -0.18 * k * d.y + 0.04 * k * flutter * sin(ph * 0.5 + 1.1)
	_vd[TORSO_F] += -0.05 * k * d.x
	_vd[HOOD_F] += -0.1 * k * d.x + 0.04 * k * flutter * sin(ph - 1.4)
	_vd[ARM_L_F] += -0.3 * k * d.x
	_vd[ARM_L_S] += 0.12 * k
	_vd[ARM_R_F] += 0.16 * k * d.x + 0.06 * k * flutter * sin(ph)
	_vd[STAFF_F] += 0.06 * k * d.x - 0.06 * k * flutter * sin(ph)


## The death at u (0..1 of DEATH_SECONDS): a jolt, the staff slipping and falling, the crumple into the robe.
func _death(u: float, fold: float, calm: bool) -> void:
	var jolt := sin(PI * clampf(u / 0.22, 0.0, 1.0)) * (0.5 if calm else 1.0)
	var fall := smoothstep(0.06, 0.62, u)
	fall *= fall  # it drops, accelerating
	_vd[HOOD_F] += -0.55 * jolt + 0.7 * fold
	_vd[TORSO_F] += -0.2 * jolt + 0.72 * fold
	_vd[ARM_R_F] += 0.4 * jolt - 0.45 * fold
	_vd[ARM_L_S] += 0.45 * jolt - 0.1 * fold
	_vd[ARM_L_F] += -0.25 * fold
	_vd[LEAN_F] += 0.04 * fold
	_vd[CRUMPLE] += 0.88 * fold
	# The staff tips over sideways to lie across the floor at its right (seen from the camera a staff falling forward
	# reads as one still standing), the bow's forward tilt taken back, slipping down in the hand as it goes.
	_vd[STAFF_DROP] += 0.34 * fall
	_vd[STAFF_F] -= 0.6 * fall
	_vd[STAFF_S] += 1.45 * fall
	_crystal += 5.0 * jolt


func _add(pose: Array, w: float) -> void:
	if is_zero_approx(w):
		return
	for pair: Array in pose:
		_vd[int(pair[0])] += float(pair[1]) * w


## The joints from the drives (exactly what vat_rig's joints compose).
func _apply() -> void:
	var c := _vd[CRUMPLE]
	(parts["body"] as Node3D).transform = Transform3D(
		(
			Basis(Vector3.UP, _vd[YAW])
			* Basis(Vector3.BACK, -_vd[LEAN_F])
			* Basis(Vector3.RIGHT, _vd[LEAN_S])
		),
		Vector3(0, _lift, 0)
	)
	(parts["waist"] as Node3D).position = _waist - Vector3(0, _waist.y * CRUMPLE_K * c, 0)
	(parts["hem"] as Node3D).transform = Transform3D(
		(
			Basis(Vector3.BACK, _vd[HEM_F])
			* Basis(Vector3.RIGHT, -_vd[HEM_S])
			* Basis.from_scale(
				Vector3(1.0 + CRUMPLE_SPREAD * c, 1.0 - CRUMPLE_K * c, 1.0 + CRUMPLE_SPREAD * c)
			)
		),
		Vector3.ZERO
	)
	(parts["torso"] as Node3D).basis = (
		Basis(Vector3.BACK, -_vd[TORSO_F]) * Basis(Vector3.RIGHT, _vd[TORSO_S])
	)
	(parts["hood"] as Node3D).basis = (
		Basis(Vector3.BACK, -_vd[HOOD_F]) * Basis(Vector3.RIGHT, _vd[HOOD_S])
	)
	(parts["arm_l"] as Node3D).basis = (
		Basis(Vector3.BACK, _vd[ARM_L_F]) * Basis(Vector3.RIGHT, _vd[ARM_L_S])
	)
	(parts["arm_r"] as Node3D).basis = (
		Basis(Vector3.BACK, _vd[ARM_R_F]) * Basis(Vector3.RIGHT, -_vd[ARM_R_S])
	)
	(parts["staff"] as Node3D).transform = Transform3D(
		Basis(Vector3.BACK, -_vd[STAFF_F]) * Basis(Vector3.RIGHT, _vd[STAFF_S]),
		_grip - _shoulder_r - Vector3(0, _vd[STAFF_DROP], 0)
	)


# --- the VAT rig (SoloVat) ------------------------------------------------------------------------------------------


## The body's lift (m): the hover, the bob, the cycle's rise and drop (VatCrowd moves the instance by it).
func vat_lift() -> float:
	return _lift


func vat_drives() -> PackedFloat32Array:
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The crystal's glow (the instance's; the visor's is the VISOR drive).
func glow_energy() -> float:
	return _crystal


## The owner's model's colour map (VatLooks' textured variant), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL_ID).get("texture") if has_model else null


## The joint chain (see _apply): the body's turn, lean and tilt; the waist's sink; the hem's swing, tilt and
## crumple; the torso's bow and tilt; the hood's, each arm's (at its shoulder) and the staff's (its slip in the hand,
## then its tilts) turns. The crumple's two joints share one grid (a slide and a stretch: exact on two samples).
func vat_rig() -> Dictionary:
	var x := Vector3.RIGHT
	var z := Vector3.BACK
	var crumple_slide := SoloVat.slide(Vector3(0, -_waist.y * CRUMPLE_K, 0), _waist)
	var crumple_stretch := SoloVat.stretch_by(
		Vector3.ONE, Vector3(CRUMPLE_SPREAD, -CRUMPLE_K, CRUMPLE_SPREAD)
	)
	var joints: Array = [
		[0, -1, null, SoloVat.turn(Vector3.UP)],
		[1, 0, null, SoloVat.turn(z, -1.0)],
		[2, 1, parts.get("body"), SoloVat.turn(x)],
		[3, 2, parts.get("waist"), crumple_slide],
		[4, 3, null, SoloVat.turn(z)],
		[5, 4, null, SoloVat.turn(x, -1.0)],
		[3, 5, parts.get("hem"), crumple_stretch],
		[6, 3, null, SoloVat.turn(z, -1.0)],
		[7, 7, parts.get("torso"), SoloVat.turn(x)],
		[8, 8, null, SoloVat.turn(z, -1.0, SoloVat.at(_neck - _waist))],
		[9, 9, parts.get("hood"), SoloVat.turn(x)],
		[10, 8, null, SoloVat.turn(z, 1.0, SoloVat.at(_shoulder_l - _waist))],
		[11, 11, parts.get("arm_l"), SoloVat.turn(x)],
		[12, 8, null, SoloVat.turn(z, 1.0, SoloVat.at(_shoulder_r - _waist))],
		[13, 13, parts.get("arm_r"), SoloVat.turn(x, -1.0)],
		[14, 14, null, SoloVat.slide(Vector3.DOWN, _grip - _shoulder_r)],
		[15, 15, null, SoloVat.turn(z, -1.0)],
		[16, 16, parts.get("staff"), SoloVat.turn(x)],
	]
	var grids: Array = [
		[[YAW, SAMPLES[YAW]]],
		[[LEAN_F, SAMPLES[LEAN_F]]],
		[[LEAN_S, SAMPLES[LEAN_S]]],
		[[CRUMPLE, 2]],
		[[HEM_F, SAMPLES[HEM_F]]],
		[[HEM_S, SAMPLES[HEM_S]]],
		[[TORSO_F, SAMPLES[TORSO_F]]],
		[[TORSO_S, SAMPLES[TORSO_S]]],
		[[HOOD_F, SAMPLES[HOOD_F]]],
		[[HOOD_S, SAMPLES[HOOD_S]]],
		[[ARM_L_F, SAMPLES[ARM_L_F]]],
		[[ARM_L_S, SAMPLES[ARM_L_S]]],
		[[ARM_R_F, SAMPLES[ARM_R_F]]],
		[[ARM_R_S, SAMPLES[ARM_R_S]]],
		[[STAFF_DROP, 2]],
		[[STAFF_F, SAMPLES[STAFF_F]]],
		[[STAFF_S, SAMPLES[STAFF_S]]],
	]
	var key := (
		("cinder_priest_" if kind == KIND else "cinder_priest_%d_" % kind)
		+ ("model" if has_model else "code")
	)
	var out := SoloVat.rig(key, VAT_DRIVES, grids, joints, OUTLINE_M, true)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out


## VatBake.pose_error: a random state (every input the pose reads, mixed freely), posed.
func vat_sample(rng: RandomNumberGenerator) -> Dictionary:
	return (
		SoloVat
		. sample(
			self,
			rng,
			{
				"_t": [0.0, 40.0],
				"_rise": [0.0, 1.0],
				"_pulse": [0.0, 1.0],
				"_erupt_s": [-0.5, STRIKE_END_S],
				"_glide": [0.0, 1.0],
				"_dir": [Vector2.RIGHT, Vector2(-0.6, 0.8), Vector2(0.0, -1.0), Vector2(-1.0, 0.0)],
				"_turn": [0.0, 1.0],
				"_yaw": [-TURN_MAX, TURN_MAX],
				"_die_t": [-1.0, -1.0, DEATH_SECONDS * 0.3, DEATH_SECONDS * 0.7, DEATH_SECONDS],
			},
			_pose
		)
	)


func vat_set(s: Dictionary) -> void:
	SoloVat.apply(self, s, _pose)
