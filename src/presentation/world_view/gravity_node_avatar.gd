class_name GravityNodeAvatar
extends AvatarBase
## The Gravity Node on the owner's model (EnemyModels &"gravity_node", cut by scripts/assets/gravity_node_prep.py into
## the face plate with its gem (the body), the charcoal core, the upper and lower shell halves and two rings: the pair
## of nearly level ones, fused along one side in the owner's mesh, and the upright one across the front), animated in
## code from the sim's state and drawn by the VAT crowd (SoloVat) while the switch is on. The owner asked for the
## enemies to be "animated as good as you can, if they can have multiple animations ... the better".
## The sim's node (data/enemies/gravity_node.tres, StarfallKinds) floats where it spawned and never attacks: every
## projectile within its reach bends toward it, always, and the hero within its reach drifts toward it
## (WorldReader.gravity_hero_pull: 0..1, stronger nearer). It faces the hero on its plan ticks.
## Its clips, each read from the sim through WorldReader (sync) and played in frame time (advance):
## - idle hover: it bobs HOVER_LIFT up, swaying a little; the rings turn at their own tilts (one each way), precessing
##   slowly; the shell halves breathe open a crack over the core, whose glow breathes with them;
## - the pull (the draw on the hero, eased): the rings spin faster and tighten in round the core, their wobble
##   settling, the halves part to bare the core, which glows and beats inward (each beat a sink and a flash);
## - the turn (the facing node turning toward the hero): the body trails the turn and swings after it, the rings tip
##   with it like a gyroscope;
## - a hit (its HP fell): a wobble (rolled and pitched, dipping), each ring knocked off its axis, settling back in a
##   few damped swings, the halves clapping shut, the core flashing;
## - the rise-in (SPAWN): it lifts off the ground, the rings unfolding from tight round the core and spinning up, the
##   halves closed, the core lighting;
## - the death (die(): DEATH_SECONDS): a last flare of the core, the halves split apart, the rings fly off and tip
##   over, it drops to the ground and rolls onto its side, the glows going out;
## - reduced motion (ViewPrefs.reduced_motion): the same clips at CALM of the body's amplitudes, the rings turning
##   slowly at one steady rate (no speed-up, no flicker of the studs), no beats, a hit eased once instead of swinging.
## The pose is a few plain numbers (the raw drives, _vd: each joint's turn, slide or stretch) worked out from the state
## first, then the nodes from them through the joint table (_joints, the same transforms the VAT rig declares), so the
## baked pose is the live one. Presentation only (EI-07): nothing here reaches the sim. +X is the front, +Z its right.

const KIND := WorldReader.KIND_GRAVITY_NODE
const MODEL := &"gravity_node"
## The model's own height (m, with its rings: EnemyModels scales it to this) and the lift it hovers at (its middle
## about 1.2 m up: the request row), the health bar's height over its top.
const MODEL_HEIGHT := 0.95
const HOVER_LIFT := 0.72
const HEIGHT := 1.7
## The role colour (the shell's plates, greyscale in the map), the core's dark and its glow, the gem visor's.
const COLOR := Color("#E8C22E")
const CORE_COLOR := Color("#1E1A24")
const CORE_GLOW := Color("#6A2CFF")
const VISOR_COLOR := Color("#B98CF5")
const VISOR_GLOW := Color("#B07CFF")
## The core's glow at rest, what a full draw adds, a beat's flash; the visor's at rest and at a full draw.
const CORE_REST := 0.12
const CORE_DRAW := 1.5
const CORE_FLASH := 1.2
const VISOR_REST := 1.4
const VISOR_DRAW := 3.2
## The rings' turn (rad/s) at rest (the level pair, the upright one: one each way), the share a full draw adds, the
## cap with reduced motion; the core's inward beats a second at a full draw.
const SPIN_A := 1.3
const SPIN_B := -1.7
const SPIN_DRAW := 2.2
const SPIN_CALM := 0.6
const BEATS := 2.0
## The clips' lengths (s): a hit's wobble, the death.
const HURT_SECONDS := 0.9
const DEATH_SECONDS := 1.4
## The bob (Hz) and the breath (Hz); reduced motion's share of the body's motion; the turn rate (rad/s) of a full trail.
const BOB_HZ := 0.45
const BREATH_HZ := 0.35
const CALM := 0.45
const TURN_REF := 3.0
## The lift it lies at once dead (m: its bottom just off the floor).
const FLOOR_LIFT := 0.03
const SHADOW_R := 0.42
## The pivots (m, the model's frame) when the model is missing (the prep's own): the orb's middle, the halves' hinges
## at the back of the gap, the rings' centres.
const PIVOTS := {
	&"body": Vector3(0.0, 0.475, 0.0),
	&"core": Vector3(0.0, 0.475, 0.0),
	&"shell_u": Vector3(-0.347, 0.504, 0.0),
	&"shell_l": Vector3(-0.347, 0.417, 0.0),
	&"ring_a": Vector3(-0.006, 0.453, -0.007),
	&"ring_b": Vector3(-0.012, 0.476, 0.03),
}
## The rings (RINGS order): each one's axis (its circle's normal, the prep's), radius (m), the in-plane line it tips
## about, and the way it flies off in the death (m, the body's frame).
const RINGS: Array[StringName] = [&"ring_a", &"ring_b"]
const RING_AXES := [Vector3(0.2531, 0.9673, -0.0135), Vector3(-0.921, 0.0707, 0.383)]
const RING_R := [0.412, 0.418]
const RING_FLY := [Vector3(-0.32, -0.36, 0.3), Vector3(0.34, -0.3, -0.36)]
## SoloVat: the raw drives (_vd) and their specs [lo, hi, loop]: the body's roll, pitch and yaw (about the orb's
## middle), the core's stretch, the upper half's lift (m) and tilt open (at its hinge, the front up), the lower half's
## drop (m) and tilt open (the front down), then per ring its flight (0..1 along RING_FLY), its tip, its stretch and
## its spin (a loop), then the visor's glow (no grid: sent as it is).
const ROLL := 0
const PITCH := 1
const YAW := 2
const CORE := 3
const UP_LIFT := 4
const UP_TILT := 5
const LOW_DROP := 6
const LOW_TILT := 7
const RING0 := 8
const FLY := 0
const TIP := 1
const SIZE := 2
const SPIN := 3
const VISOR := 16
const VAT_DRIVES := [
	[-0.8, 0.8, false],
	[-0.8, 0.8, false],
	[-0.7, 0.7, false],
	[-0.4, 0.3, false],
	[-0.03, 0.2, false],
	[-0.3, 0.9, false],
	[-0.03, 0.2, false],
	[-0.3, 0.9, false],
	[0.0, 1.0, false],
	[-1.7, 1.7, false],
	[-0.35, 0.15, false],
	[0.0, TAU, true],
	[0.0, 1.0, false],
	[-1.7, 1.7, false],
	[-0.35, 0.15, false],
	[0.0, TAU, true],
	[0.0, 0.0, false],
]
## Each drive's samples (a turn finely, the rings' wide tips and spins finest; a slide or a stretch linear: exact on
## two).
const VAT_SAMPLES := [33, 33, 33, 2, 2, 25, 2, 25, 2, 49, 2, 73, 2, 49, 2, 73]

## True (set before setup(), ActorViews from ViewPrefs.enemy_vat): a VatCrowd draws the body from baked poses; setup()
## builds no nodes.
var vat := false
var kind := KIND
var height := HEIGHT
## True when the body is the owner's model (else the code-made stand-in on the same joints).
var has_model := false
## The parts (tests): the rig's root (the face plate), the core, the halves, the rings (RINGS order), the ground disc.
var rig: Node3D
var core: Node3D
var shell_u: Node3D
var shell_l: Node3D
var rings: Array[Node3D] = []
var shadow: MeshInstance3D

var _vd := PackedFloat32Array()
var _lift := HOVER_LIFT
var _core_glow := CORE_REST
var _core_mat := StandardMaterial3D.new()
var _visor_mat := StandardMaterial3D.new()
var _pivots := PIVOTS.duplicate()
## The joint table: [drive, parent joint, frame node or null, make (SoloVat's)], a parent before its children.
var _joints: Array = []
# The state the pose is made from (sync and advance keep it; VatVerify.sample sets it).
var _state := WorldReader.STATE_SPAWN
var _hp := -1
var _draw := 0.0
var _draw_to := 0.0
var _rise := 0.0
var _spin_a := 0.0
var _spin_b := 0.0
var _beat := 0.0
var _omega := 0.0
var _hurt_t := -1.0
var _hurt_side := 1.0
var _die_t := -1.0
var _last_fy := 0.0
var _have_fy := false


## Builds a node under `facing` for ActorViews (`views`: on VAT while its switch is on) and marks `root` (the avatar,
## its body materials for the hit flash); returns its height.
static func attach(views: ActorViews, root: Node3D, facing: Node3D) -> float:
	var node := GravityNodeAvatar.new()
	views._solo_vat(root, node, KIND)
	node.setup()
	facing.add_child(node)
	root.set_meta(&"enemy_avatar", node)
	root.set_meta(&"mats", node.body_materials.duplicate())
	return HEIGHT


func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	_core_mat.albedo_color = CORE_COLOR
	_core_mat.emission_enabled = true
	_core_mat.emission = CORE_GLOW
	_core_mat.emission_energy_multiplier = CORE_REST
	_visor_mat.albedo_color = VISOR_COLOR
	_visor_mat.emission_enabled = true
	_visor_mat.emission = VISOR_GLOW
	_visor_mat.emission_energy_multiplier = VISOR_REST
	_visor_mat.set_meta(SoloVat.GLOW, VISOR + 1)  # a VAT node's gem glows at its VISOR drive
	_build_shadow()
	var m := EnemyModels.get_model(MODEL)
	has_model = not m.is_empty()
	if has_model:
		var parts_in: Dictionary = m["parts"]
		for pname: StringName in parts_in:
			_pivots[pname] = (parts_in[pname] as Dictionary)["pivot"] * float(m["scale"])
	if vat:  # the crowd draws the body
		_pose()
		return
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	core = _node(rig, "Core")
	shell_u = _node(rig, "ShellU")
	shell_l = _node(rig, "ShellL")
	for r in RINGS:
		rings.append(_node(rig, String(r).capitalize().replace(" ", "")))
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


func _node(parent: Node3D, n: String) -> Node3D:
	var node := Node3D.new()
	node.name = n
	parent.add_child(node)
	return node


## The frame node a part's mesh hangs in and that frame's own pivot (m).
func _frame_of(part: StringName) -> Array:
	match part:
		&"core":
			return [core, _pivots[&"core"]]
		&"shell_u":
			return [shell_u, _pivots[&"shell_u"]]
		&"shell_l":
			return [shell_l, _pivots[&"shell_l"]]
	var k := RINGS.find(part)
	return [rings[k], _pivots[part]] if k >= 0 else [rig, Vector3.ZERO]


## The owner's model: each part's mesh in its joint's frame, its surfaces on the base / role plates (the role plates
## greyscale in the map, tinted COLOR) and the gem's glow; the core all in its own glowing dark.
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
	mats[&"glow"] = _visor_mat
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
				k, _core_mat if pname == &"core" else mats.get(surfaces[k], mats[&"base"])
			)
		(f[0] as Node3D).add_child(mi)


## The code-made stand-in (the model file missing): a sphere, two domes, a plate and two tori on the same joints, so
## every clip still plays.
func _build_code() -> void:
	var mid: Vector3 = _pivots[&"core"]
	var ball := SphereMesh.new()
	ball.radius = 0.27
	ball.height = 0.54
	var mi := MeshInstance3D.new()
	mi.mesh = ball
	mi.material_override = _core_mat
	core.add_child(mi)
	for k in 2:
		var hinge: Vector3 = _pivots[&"shell_u" if k == 0 else &"shell_l"]
		var dome := SphereMesh.new()
		dome.radius = 0.36
		dome.height = 0.36
		dome.is_hemisphere = true
		var half := _body_piece(shell_u if k == 0 else shell_l, dome, mid - hinge, COLOR)
		half.rotation.x = PI * k  # the lower one upside down
	var plate := BoxMesh.new()
	plate.size = Vector3(0.08, 0.3, 0.22)
	_body_piece(rig, plate, mid + Vector3(0.33, 0.0, 0.0), Color("#2E2A34"))
	var gem := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.03, 0.1, 0.08)
	gem.mesh = gb
	gem.material_override = _visor_mat
	gem.position = mid + Vector3(0.38, 0.03, 0.0)
	rig.add_child(gem)
	for k in RINGS.size():
		var torus := TorusMesh.new()
		torus.inner_radius = float(RING_R[k]) - 0.02
		torus.outer_radius = float(RING_R[k]) + 0.02
		var ring := _body_piece(rings[k], torus, Vector3.ZERO, Color("#6E6A74"))
		ring.basis = Basis(Quaternion(Vector3.UP, (RING_AXES[k] as Vector3).normalized()))


## The joint table (see _joints): the body's roll, pitch and yaw about the orb's middle (the rig), the core's stretch
## there, each half's lift or drop and its tilt at its hinge, each ring's flight, tip (about a line in its plane),
## stretch and spin (about its axis) at its centre.
func _build_joints() -> void:
	var mid: Vector3 = _pivots[&"core"]
	var into := SoloVat.at(mid)
	var out := SoloVat.at(-mid)
	_joints = [
		[ROLL, -1, null, SoloVat.turn(Vector3.RIGHT, 1.0, into, out)],
		[PITCH, 0, null, SoloVat.turn(Vector3.BACK, 1.0, into, out)],
		[YAW, 1, rig, SoloVat.turn(Vector3.UP, 1.0, into, out)],
		[CORE, 2, core, SoloVat.stretch_by(Vector3.ONE, Vector3.ONE, into)],
		[
			UP_LIFT,
			2,
			null,
			SoloVat.slide(Vector3.UP, Vector3.ZERO, SoloVat.at(_pivots[&"shell_u"]))
		],
		[UP_TILT, 4, shell_u, SoloVat.turn(Vector3.BACK)],
		[
			LOW_DROP,
			2,
			null,
			SoloVat.slide(Vector3.DOWN, Vector3.ZERO, SoloVat.at(_pivots[&"shell_l"]))
		],
		[LOW_TILT, 6, shell_l, SoloVat.turn(Vector3.BACK, -1.0)],
	]
	for k in RINGS.size():
		var d := RING0 + 4 * k
		var at := SoloVat.at(_pivots[RINGS[k]])
		_joints.append([d + FLY, 2, null, SoloVat.slide(RING_FLY[k], Vector3.ZERO, at)])
		_joints.append([d + TIP, _joints.size() - 1, null, SoloVat.turn(tip_axis(k))])
		_joints.append(
			[d + SIZE, _joints.size() - 1, null, SoloVat.stretch_by(Vector3.ONE, Vector3.ONE)]
		)
		_joints.append([d + SPIN, _joints.size() - 1, rings[k], SoloVat.turn(ring_axis(k))])


## Ring `k`'s axis (unit) and the line in its plane it tips about (the level pair across the body, the upright one
## up and down).
static func ring_axis(k: int) -> Vector3:
	return (RING_AXES[k] as Vector3).normalized()


static func tip_axis(k: int) -> Vector3:
	var n := ring_axis(k)
	var line := Vector3.BACK if k == 0 else Vector3.UP
	return (line - n * line.dot(n)).normalized()


# --- Sync ---------------------------------------------------------------------------------------------------------
func sync(reader: WorldReader, i: int) -> void:
	apply_state(
		{
			"state": reader.actor_state(i),
			"hp": reader.actor_hp(i),
			"draw": reader.gravity_hero_pull(i),
		}
	)


## The same as sync(), from plain values (tests, the shot scripts): state, draw (0..1); hp optional.
func apply_state(s: Dictionary) -> void:
	var st: int = s["state"]
	var hp: int = s.get("hp", -1)
	if _fresh:
		_rise = 0.0 if st == WorldReader.STATE_SPAWN else 1.0
	elif hp >= 0 and _hp >= 0 and hp < _hp:
		_hurt_t = 0.0
		_hurt_side = -_hurt_side
	_state = st
	_hp = hp
	_draw_to = clampf(float(s.get("draw", 0.0)), 0.0, 1.0)
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
	var calm := ViewPrefs.reduced_motion
	_turning(dt, dying)
	var spawning := _state == WorldReader.STATE_SPAWN
	if not dying:
		_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * 1.6)
	_draw = move_toward(_draw, 0.0 if dying else _draw_to, dt * 2.0)
	# The rings' turn: steady at rest, faster with the draw, spun up through the rise-in, slowing to a stop in the
	# death; one slow steady rate with reduced motion.
	var rate := 1.0 + SPIN_DRAW * _draw
	if calm:
		rate = SPIN_CALM
	rate *= lerpf(2.5, 1.0, _rise) if not dying else maxf(0.0, 1.0 - _die_t / (DEATH_SECONDS * 0.6))
	_spin_a = fposmod(_spin_a + SPIN_A * rate * dt, TAU)
	_spin_b = fposmod(_spin_b + SPIN_B * rate * dt, TAU)
	_beat = fposmod(_beat + dt * BEATS * _draw, 1.0) if _draw > 0.0 and not calm else 0.0
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
	_omega = lerpf(_omega, w, _rate(6.0, dt))
	_last_fy = fy
	_have_fy = true


## Starts the death (ActorViews, when the sim drops the node: its bar hidden, freed DEATH_SECONDS later). True: it
## plays.
func die() -> bool:
	if _die_t < 0.0:
		_die_t = 0.0
	return true


func dying() -> bool:
	return _die_t >= 0.0


## The draw on the hero as the body shows it now (0..1, eased), the core's glow and the gem's (tests, the e2e).
func draw_pose() -> float:
	return _draw


func core_energy() -> float:
	return _core_glow


func visor_energy() -> float:
	return _visor_mat.emission_energy_multiplier


## The raw drives now (tests).
func drives() -> PackedFloat32Array:
	return _vd


# --- The pose -----------------------------------------------------------------------------------------------------
## The pose's numbers from the state (_vd, the lift, the glows), then (the code path) the nodes from them.
func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var k := CALM if calm else 1.0
	var d := PackedFloat32Array()
	d.resize(VAT_DRIVES.size())
	var breath := sin(TAU * _t * BREATH_HZ)
	var lift := HOVER_LIFT + 0.05 * k * sin(TAU * _t * BOB_HZ)
	_hover_pose(d, k, breath)
	_pull_pose(d, k)
	_turn_pose(d, k)
	lift += _hurt_pose(d, k, calm)
	lift = _rise_pose(d, lift)
	lift = _death_pose(d, lift, calm)
	for r in RINGS.size():
		d[RING0 + 4 * r + SPIN] = _spin_a if r == 0 else _spin_b
	for j in VISOR:
		if not bool(VAT_DRIVES[j][2]):
			d[j] = clampf(d[j], VAT_DRIVES[j][0], VAT_DRIVES[j][1])
	_core_glow = _core_energy(calm, breath)
	d[VISOR] = _visor(breath)
	_vd = d
	_lift = lift
	_core_mat.emission_energy_multiplier = _core_glow
	_visor_mat.emission_energy_multiplier = d[VISOR]
	var s := clampf(1.15 - 0.45 * _lift / HOVER_LIFT, 0.5, 1.2)
	shadow.scale = Vector3(s, 1, s)
	if not vat and rig != null:
		_apply()


## The hover: the body swaying a little, the rings precessing at their tilts, the halves breathing open a crack, the
## core breathing with them.
func _hover_pose(d: PackedFloat32Array, k: float, breath: float) -> void:
	d[ROLL] += k * 0.06 * sin(0.7 * _t)
	d[PITCH] += k * 0.05 * sin(0.55 * _t + 1.0)
	d[YAW] += k * 0.08 * sin(0.3 * _t + 0.5)
	var open := 0.5 * (breath + 1.0)
	d[UP_LIFT] += 0.012 * open
	d[UP_TILT] += 0.05 * open * k
	d[LOW_DROP] += 0.008 * open
	d[LOW_TILT] += 0.035 * open * k
	d[CORE] += 0.03 * breath * k
	var settle := 1.0 - 0.7 * _draw
	d[RING0 + TIP] += k * settle * 0.12 * sin(0.8 * _t)
	d[RING0 + 4 + TIP] += k * settle * 0.1 * sin(0.65 * _t + 2.0)


## The pull at its draw: the rings tighten in round the core, the halves part to bare it, the core beats inward
## (each beat a quick sink and a slow swell back).
func _pull_pose(d: PackedFloat32Array, k: float) -> void:
	var p := smoothstep(0.0, 1.0, _draw)
	if p <= 0.0:
		return
	for r in RINGS.size():
		d[RING0 + 4 * r + SIZE] -= 0.14 * p
	d[UP_LIFT] += 0.07 * p
	d[UP_TILT] += 0.32 * p
	d[LOW_DROP] += 0.05 * p
	d[LOW_TILT] += 0.22 * p
	var sink := sin(PI * clampf(_beat / 0.25, 0.0, 1.0)) if _beat < 0.25 else 0.0
	d[CORE] += 0.06 * p - 0.18 * p * sink * k


## The turn toward the hero: the body trails it, the rings tip with it.
func _turn_pose(d: PackedFloat32Array, k: float) -> void:
	var w := clampf(_omega / TURN_REF, -1.0, 1.0)
	d[YAW] -= 0.35 * w * k
	d[ROLL] += 0.12 * w * k
	d[RING0 + TIP] += 0.25 * w * k
	d[RING0 + 4 + TIP] -= 0.3 * w * k


## A hit: the body wobbles (rolled and pitched) and dips, each ring knocked off its axis and swinging back in damped
## swings, the halves clapping shut; with reduced motion one eased lean and back. Returns the lift's change.
func _hurt_pose(d: PackedFloat32Array, k: float, calm: bool) -> float:
	if _hurt_t < 0.0:
		return 0.0
	var u := _hurt_t / HURT_SECONDS
	var env := (1.0 - smoothstep(0.0, 1.0, u)) * smoothstep(0.0, 0.05, u)
	var swing := sin(TAU * 2.2 * _hurt_t)
	if calm:
		swing = 1.0
		env = sin(PI * clampf(u / 0.7, 0.0, 1.0))
	var s := _hurt_side
	d[ROLL] += 0.22 * s * env * swing * k
	d[PITCH] += 0.12 * env * swing * k
	d[RING0 + TIP] += 0.45 * s * env * swing * k
	d[RING0 + 4 + TIP] -= 0.5 * s * env * (swing if calm else sin(TAU * 1.8 * _hurt_t + 0.3)) * k
	var clap := 1.0 - smoothstep(0.0, 0.5, u)
	d[UP_TILT] *= 1.0 - clap
	d[LOW_TILT] *= 1.0 - clap
	d[UP_LIFT] *= 1.0 - clap
	d[LOW_DROP] *= 1.0 - clap
	return -0.06 * env * k


## The rise-in: from just off the ground up to its hover, quickest at first, the rings folded tight round the core and
## unfolding, the halves shut. Returns the lift.
func _rise_pose(d: PackedFloat32Array, lift: float) -> float:
	if _die_t >= 0.0:
		return lift
	var r := 1.0 - _rise
	if r <= 0.0:
		return lift
	var e := r * r
	for k in RINGS.size():
		d[RING0 + 4 * k + SIZE] -= 0.3 * e
		d[RING0 + 4 * k + TIP] *= 1.0 - r
	for j in [UP_LIFT, UP_TILT, LOW_DROP, LOW_TILT]:
		d[j] *= 1.0 - r
	d[CORE] -= 0.25 * e
	return lerpf(lift, 0.12, e)


## The death: the core flares, the halves split apart (the upper one thrown up and back, the lower one dropped open),
## the rings fly off and tip over, the body drops to the ground (a small bounce) and rolls onto its side. Returns the
## lift.
func _death_pose(d: PackedFloat32Array, lift: float, calm: bool) -> float:
	if _die_t < 0.0:
		return lift
	var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
	var keep := 1.0 - smoothstep(0.0, 0.25, u)
	for j in RING0:
		d[j] *= keep
	for r in RINGS.size():
		d[RING0 + 4 * r + TIP] *= keep
		d[RING0 + 4 * r + SIZE] *= keep
	var flare := sin(PI * clampf(u / 0.2, 0.0, 1.0))
	d[CORE] += 0.15 * flare
	var split := smoothstep(0.08, 0.4, u)
	d[UP_LIFT] += 0.16 * split * (1.0 - smoothstep(0.45, 0.75, u))  # thrown up, then down onto it
	d[UP_TILT] += 0.75 * split
	d[LOW_DROP] += 0.05 * split
	d[LOW_TILT] += 0.5 * split
	var fly := smoothstep(0.1, 0.55, u)
	for r in RINGS.size():
		d[RING0 + 4 * r + FLY] = fly
		d[RING0 + 4 * r + TIP] += (1.2 if r == 0 else -1.3) * fly
	# The fall: eased in (it drops), a small bounce on landing (none with reduced motion), then it lies there.
	var f := clampf((u - 0.15) / 0.4, 0.0, 1.0)
	var at := lerpf(lift, FLOOR_LIFT, f * f)
	if not calm and u > 0.55:
		at += 0.06 * sin(PI * clampf((u - 0.55) / 0.15, 0.0, 1.0))
	var tip := smoothstep(0.45, 0.85, u)
	d[ROLL] += 0.6 * tip
	d[PITCH] -= 0.2 * tip
	return at


## The core's glow: rest, breathing; brighter with the draw, a flash with each beat; a flash on a hit; dim as it rises
## in; a flare in the death, then out.
func _core_energy(calm: bool, breath: float) -> float:
	var e := CORE_REST * (1.0 + 0.3 * (0.4 if calm else 1.0) * breath) + CORE_DRAW * _draw
	if _beat > 0.0:
		e += CORE_FLASH * _draw * (1.0 - smoothstep(0.0, 0.5, _beat))
	if _hurt_t >= 0.0:
		e += 1.5 * (1.0 - _hurt_t / HURT_SECONDS)
	e *= lerpf(0.25, 1.0, _rise) if _die_t < 0.0 else 1.0
	if _die_t >= 0.0:
		var u := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)
		e = lerpf(e, 0.03, smoothstep(0.2, 0.6, u)) + 3.0 * sin(PI * clampf(u / 0.2, 0.0, 1.0))
	return e


## The gem's glow: rest with a slow pulse, brighter with the draw, going out in the death.
func _visor(breath: float) -> float:
	var e := VISOR_REST + 0.3 * breath + (VISOR_DRAW - VISOR_REST) * _draw
	e *= lerpf(0.3, 1.0, _rise) if _die_t < 0.0 else 1.0
	if _die_t >= 0.0:
		e = lerpf(e, 0.1, smoothstep(0.15, 0.6, clampf(_die_t / DEATH_SECONDS, 0.0, 1.0)))
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


## The core's glow (the instance's accent glow; the gem's is the VISOR drive).
func glow_energy() -> float:
	return _core_glow


## The owner's colour map (VatLooks' textured variant; HordeVat.texture), or null for the code-made body.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## One grid per drive but the visor's (a turn sampled finely, a slide or a stretch on two samples: exact), the joints
## as the table.
func vat_rig() -> Dictionary:
	var grids: Array = []
	for d in VAT_SAMPLES.size():
		grids.append([[d, VAT_SAMPLES[d]]])
	var out := SoloVat.rig("gravity_node", VAT_DRIVES, grids, _joints, true)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out
