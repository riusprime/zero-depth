class_name HatchlingAvatar
extends ChargerAvatar
## The Brood Mother's Hatchling on the owner's model (EnemyModels &"hatchling", cut by
## scripts/assets/hatchling_swarmer_prep.py into the body with its eye, the spiky carapace and six two-part legs). The
## owner asked for the enemies to be "animated as good as you can", and for the horde critters to stay small and
## animated. Hatchlings pour out of the Brood Mother's eggs, so it stays on the Charger's batched path: the Charger's
## state and drives (ChargerAvatar, ChargerVat's twelve, reckoned for a batch by the native avatar), only the joints
## the drives pose are the model's. Without the model file it is the Charger's code body in its colours at
## FALLBACK_SCALE, as before.
## Its clips, from the sim's states through ChargerAvatar (the same as the Charger's):
## - the scurry: its six legs in two tripods, each foot swinging back on the ground and lifted as it comes forward,
##   the stride growing with the pace (the phase runs with the ground speed); the body's bob;
## - idle: the carapace breathing, the body's breath, now and then one foot lifting and tapping;
## - the tell (WINDUP): it rears on its hind feet, the carapace bristling up and back, the long front legs raised with
##   their claws curled, a tremble at the top;
## - the charge (ACTIVE): it pitches nose down onto its front feet and lunges, the front legs thrown ahead, the
##   carapace slapping down;
## - the daze (RECOVER): it slumps and lists to one side, the legs splayed and limp, twitching;
## - the crouch of the tell's last part, the hit flinch (AvatarBase), the rise-in (out of the ground, the legs
##   unfolding from under it);
## - the death (die(): DEATH_SECONDS): it hops and rolls onto its back, the legs curling up, the eye going out;
## - reduced motion: no tremble, no shimmer (ChargerAvatar's drives).
## Each joint is one grid's drives made into a transform (_joints: the same make for the nodes and the VAT rig), so
## the baked pose is the live one. Presentation only (EI-07). +X is the front, +Z its right.

const KIND := WorldReader.KIND_HATCHLING
const MODEL := &"hatchling"
## The model's height (EnemyModels), the code body's scale and height without it.
const MODEL_HEIGHT := 0.4
const FALLBACK_SCALE := 0.66
## The death's fall (s).
const DEATH_SECONDS := 0.6
## The grids (VatBake's, over ChargerVat's drives): the stance (wind x lunge x daze), the gait (the phase, a loop, x
## the walk), the body's height x the crouch, the fold (the rise-in x the death), the idle fidget (its clock, a loop, x
## its amount), the dazed twitch (its clock, a loop, x the daze). Starting values (scripts/checks/vat_bake_report.gd).
const STANCE := 0
const GAIT := 1
const LIFT := 2
const FOLD := 3
const FIDGET_GRID := 4
const TWITCH := 5
const GRIDS := [
	[[ChargerVat.WIND, 17], [ChargerVat.LUNGE, 17], [ChargerVat.DAZE, 9]],
	[[ChargerVat.PHASE, 64], [ChargerVat.WALK, 9]],
	[[ChargerVat.BODY_Y, 33], [ChargerVat.CROUCH, 2]],
	[[ChargerVat.RISE, 17], [ChargerVat.DEATH, 25]],
	[[ChargerVat.FIDGET_CLOCK, 96], [ChargerVat.FIDGET, 3]],
	[[ChargerVat.TWITCH_CLOCK, 16], [ChargerVat.DAZE, 3]],
]
## The legs (fr / fl the long front pair, mr / ml the side pair, br / bl the hind pair), their tripods (half a stride
## apart) and their feet (m, the model's frame: the prep's tips).
const LEGS: Array[StringName] = [&"fr", &"fl", &"mr", &"ml", &"br", &"bl"]
const TRIPOD := [0.0, 0.5, 0.5, 0.0, 0.0, 0.5]
const FEET := [
	Vector3(0.282, 0.012, 0.17),
	Vector3(0.274, 0.018, -0.182),
	Vector3(-0.101, 0.005, 0.278),
	Vector3(-0.074, 0.02, -0.28),
	Vector3(-0.285, 0.009, 0.023),
	Vector3(-0.275, 0.016, -0.047),
]
## The body's height drive (ChargerVat's span) at the model's size, the crouch's draw-back (m).
const BODY_K := 0.45
const DRAW_M := 0.04
## The lean (rad, + nose up) on the wind-up and the lunge, about the hind feet (REAR_X) or the front (FRONT_X), the
## lunge's and the wind-up's shift (m), the daze's list (rad) about one side's feet (LIST_Z).
const LEAN_WIND := 0.3
const LEAN_LUNGE := 0.25
const REAR_X := -0.27
const FRONT_X := 0.27
const LUNGE_M := 0.08
const WIND_M := 0.03
const LIST := 0.14
const LIST_Z := 0.25
## The carapace: its bristle (m up, rad back) on the wind-up, its slap on the lunge (rad), its breath (m).
const BRISTLE_M := 0.02
const BRISTLE := 0.14
const SLAP := 0.1
const BREATH_M := 0.006
## The legs (rad): the stride's swing and lift, the knee's share; the wind-up's raise of the front pair (hip, knee),
## the lunge's reach, the daze's limp; the rise-in's fold, the death's curl (hip, knee); the fidget's tap; the twitch.
const SWING := 0.5
const STEP_LIFT := 0.45
const KNEE_LIFT := 0.6
const RAISE_HIP := 0.7
const RAISE_KNEE := 0.9
const REACH_HIP := 0.3
const REACH_KNEE := 0.4
const LIMP_HIP := 0.12
const LIMP_KNEE := 0.3
const FOLD_HIP := 0.6
const FOLD_KNEE := 2.0
const CURL_HIP := 0.9
const CURL_KNEE := 2.0
const TAP := 0.33
const TWITCH_RAD := 0.08
## The death's roll onto its back (rad) about the body's middle (BODY_Y m up) and its hop (m).
const DEATH_ROLL := 2.6
const BODY_Y := 0.17
const HOP_M := 0.06

## True when the body is the owner's model (setup).
var has_model := false
## The joint table: [grid, parent (index or -1), node (null on a VAT avatar), make (the grid's values in its axes'
## order -> Transform3D)].
var _joints: Array = []


## A Charger avatar of `p_kind`: this class for the Hatchling.
static func avatar_of(p_kind: int) -> ChargerAvatar:
	return HatchlingAvatar.new() if p_kind == KIND else ChargerAvatar.new()


## ActorViews: the Hatchling under `facing`; its height (the health bar).
static func attach(views: ActorViews, root: Node3D, facing: Node3D) -> float:
	var hatch := HatchlingAvatar.new()
	hatch.enemy_tint = views.enemy_tint  # They pick its shared materials
	hatch.role_glow = ActorViews.role_glow_energy
	if VatCrowd.supports(KIND):  # Drawn by the VAT crowd while the switch is on
		hatch.vat = ViewPrefs.enemy_vat
		root.set_meta(&"vat_kind", true)
	hatch.setup(KIND)
	root.set_meta(&"hit_look", hatch)
	if not hatch.has_model:
		hatch.scale = Vector3.ONE * FALLBACK_SCALE
	facing.add_child(hatch)
	root.set_meta(&"enemy_avatar", hatch)
	root.set_meta(&"mats", hatch.body_materials.duplicate())
	return MODEL_HEIGHT if hatch.has_model else ChargerAvatar.HEIGHT * FALLBACK_SCALE


func setup(p_kind := KIND) -> void:
	var m := EnemyModels.get_model(MODEL)
	has_model = not m.is_empty()
	if not has_model:
		super.setup(p_kind)
		return
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	kind = p_kind
	if vat:  # No nodes; the crowd draws the body
		_model.free()
		_model = null
		_build_joints({}, null)
		_pose()
		return
	add_child(_model)
	var eye := _look_color(kind, &"eye")
	_visor_mat = EnemyLooks.accent(eye, eye, VISOR_ENERGY)  # Shared, GLOW per Hatchling
	_build_joints(m["parts"], m["texture"])
	_pose()


## Starts the death's fall (the owner's model; the code body goes at once).
func die() -> bool:
	_touch()
	if not has_model:
		return false
	_die_t = 0.0
	return true


func dying() -> bool:
	_peek()
	return _die_t >= 0.0


## The owner's model's colour map (VatBake: the textured plates).
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## Its own rig on the model (the joint table over ChargerVat's drives); the Charger's without it.
func vat_rig() -> Dictionary:
	if not has_model:
		return super.vat_rig()
	var drives: Array = []
	for d in ChargerVat.DRIVES:
		var loops := d in [ChargerVat.PHASE, ChargerVat.FIDGET_CLOCK, ChargerVat.TWITCH_CLOCK]
		drives.append([0.0, 1.0, loops])
	var out := SoloVat.rig("hatchling", drives, GRIDS, _joints, false)
	out["albedo_tex"] = vat_texture()
	return out


## Every piece stays its own node (the joints are nested; nothing is merged).
func rig_spec() -> Dictionary:
	if not has_model:
		return super.rig_spec()
	return {"keep": RigMerge.pieces_under(self), "sets": [_hit_pieces]}


## The joints' nodes from this pose's drives (vat_drives: the VAT crowd's very numbers), through the joint table.
func _pose_nodes(sink: Vector3, y: float, crouch: float, lunge: float, rise: float) -> void:
	if not has_model:
		super._pose_nodes(sink, y, crouch, lunge, rise)
		return
	if _model.position != sink:
		_model.position = sink
	var d := vat_drives()
	for j: Array in _joints:
		var vals: Array = []
		for ax: Array in GRIDS[j[0]]:
			vals.append(d[ax[0]])
		(j[2] as Node3D).transform = (j[3] as Callable).call(vals)


## The joint table (and, given the model's `parts`, its nodes with the pieces): the death's roll, the body's height,
## its lean; the carapace's bristle and breath; per leg the upper half's stride, stance, hold, fold and tap, the lower
## half's knee on the same grids and the twitch.
func _build_joints(parts: Dictionary, tex: Texture2D) -> void:
	_joints.clear()
	var root := _joint(FOLD, -1, "Fall", _fall)
	_joint(LIFT, root, "Lift", _lift)
	var lean := _joint(STANCE, root + 1, "Lean", _lean)
	var shell_at: Vector3 = parts.get(&"shell", {}).get("pivot", Vector3(0, 0.21, 0))
	var bristle := func(v: Array) -> Transform3D: return _bristle(shell_at, v)
	var shell := _joint(STANCE, lean, "Shell", bristle)
	var breath := _joint(FIDGET_GRID, shell, "Breath", _breath)
	_mesh(parts, &"shell", breath, tex)
	_mesh(parts, &"body", lean, tex)
	for k in LEGS.size():
		var leg := LEGS[k]
		var hip: Vector3 = parts.get(StringName("leg_%s_u" % leg), {}).get("pivot", FEET[k] * 0.5)
		var knee: Vector3 = parts.get(StringName("leg_%s_l" % leg), {}).get("pivot", FEET[k] * 0.8)
		var foot: Vector3 = FEET[k]
		var out := Vector3(foot.x - hip.x, 0.0, foot.z - hip.z).normalized()
		var axis := out.cross(Vector3.UP).normalized()
		var reach := Vector2(foot.x - hip.x, foot.z - hip.z).length()
		var front := k < 2
		var u := _joint(GAIT, lean, "Leg%sU" % leg.to_upper(), _stride.bind(k, hip, axis, out.z))
		u = _joint(STANCE, u, "", _turn.bind(axis, _hip_stance.bind(front)))
		u = _joint(LIFT, u, "", _turn.bind(axis, _hip_hold.bind(reach)))
		u = _joint(FOLD, u, "", _turn.bind(axis, _fold.bind(FOLD_HIP, CURL_HIP)))
		u = _joint(FIDGET_GRID, u, "", _turn.bind(axis, _tap.bind(k)))
		_mesh(parts, StringName("leg_%s_u" % leg), u, tex)
		var low := _joint(GAIT, u, "Leg%sL" % leg.to_upper(), _knee_step.bind(k, knee - hip, axis))
		low = _joint(STANCE, low, "", _turn.bind(axis, _knee_stance.bind(front)))
		low = _joint(LIFT, low, "", _turn.bind(axis, _knee_hold.bind(reach)))
		low = _joint(FOLD, low, "", _turn.bind(axis, _fold.bind(-FOLD_KNEE, -CURL_KNEE)))
		low = _joint(TWITCH, low, "", _turn.bind(axis, _twitch.bind(k)))
		_mesh(parts, StringName("leg_%s_l" % leg), low, tex)


## A joint on `grid` under joint `parent` (its node a child of the parent's, when the model is built); its index.
func _joint(grid: int, parent: int, pname: String, make: Callable) -> int:
	var node: Node3D = null
	if _model != null:
		node = Node3D.new()
		node.name = pname if pname != "" else "J%d" % _joints.size()
		(_model if parent < 0 else _joints[parent][2] as Node3D).add_child(node)
		if parent < 0:
			body = node  # (ChargerAvatar.advance poses only with a body)
	_joints.append([grid, parent, node, make])
	return _joints.size() - 1


## The model's part `pname` under joint `at`: its surfaces on the shared plates (role: the kind's colour on the
## greyscale texels) and the eye on the visor's accent.
func _mesh(parts: Dictionary, pname: StringName, at: int, tex: Texture2D) -> void:
	if _model == null or not parts.has(pname):
		return
	var part: Dictionary = parts[pname]
	var mi := MeshInstance3D.new()
	mi.name = String(pname).to_pascal_case()
	mi.mesh = part["mesh"]
	mi.extra_cull_margin = 0.3  # poses move parts past the rest bounds
	var surfaces: Array = part["surfaces"]
	var glows := false
	for s in surfaces.size():
		var which: StringName = surfaces[s]
		var mat: Material = _visor_mat
		if which != &"glow":
			var c := _look_color(kind, &"body") if which == &"role" else Color.WHITE
			mat = shared_body(kind, c, tex)
		glows = glows or which == &"glow"
		mi.set_surface_override_material(s, mat)
	(_joints[at][2] as Node3D).add_child(mi)
	_hit_pieces.append(mi)
	if glows:
		visor = mi


# --- the makes: one grid's values (in its axes' order) to a joint's transform -------------------------------------


static func _turn(v: Array, axis: Vector3, angle: Callable) -> Transform3D:
	return Transform3D(Basis(axis, angle.call(v)), Vector3.ZERO)


## The death's hop and roll onto its back about the body's middle ([rise, death]).
static func _fall(v: Array) -> Transform3D:
	var dd: float = v[1]
	var c := Vector3(0.0, BODY_Y, 0.0)
	var roll := Basis(Vector3.RIGHT, -dd * DEATH_ROLL)
	return Transform3D(roll, c - roll * c + Vector3(0.0, sin(dd * PI) * HOP_M, 0.0))


## The body's height and the crouch's draw-back ([body_y, crouch]).
static func _lift(v: Array) -> Transform3D:
	var by := lerpf(ChargerVat.BODY_Y_LO, ChargerVat.BODY_Y_HI, v[0]) * BODY_K
	return Transform3D(Basis.IDENTITY, Vector3(-float(v[1]) * DRAW_M, by, 0.0))


## The lean about the hind or the front feet, the lunge's shove, the daze's list ([wind, lunge, daze]).
static func _lean(v: Array) -> Transform3D:
	var wind: float = v[0]
	var lunge: float = v[1]
	var daze: float = v[2]
	var lean := wind * LEAN_WIND * (1.0 - lunge) - lunge * LEAN_LUNGE
	var px := REAR_X if lean > 0.0 else FRONT_X
	var tip := Basis(Vector3.BACK, lean)
	var p := Vector3(px, 0.0, 0.0)
	var xf := Transform3D(tip, p - tip * p + Vector3(-wind * WIND_M + lunge * LUNGE_M, 0.0, 0.0))
	var list := Basis(Vector3.RIGHT, daze * LIST)
	var q := Vector3(0.0, 0.0, LIST_Z)
	return xf * Transform3D(list, q - list * q)


## The carapace at its pivot `at`: up and back on the wind-up, slapped down on the lunge ([wind, lunge, daze]).
static func _bristle(at: Vector3, v: Array) -> Transform3D:
	var wind: float = v[0]
	var lunge: float = v[1]
	var up := wind * BRISTLE_M * (1.0 - lunge)
	return Transform3D(
		Basis(Vector3.BACK, -wind * BRISTLE * (1.0 - lunge) + lunge * SLAP), at + Vector3(0, up, 0)
	)


## The carapace's breath ([clock, amount]).
static func _breath(v: Array) -> Transform3D:
	var b := sin(float(v[0]) * TAU) * BREATH_M * (0.4 + 0.6 * float(v[1]))
	return Transform3D(Basis.IDENTITY, Vector3(0.0, b, 0.0))


## Leg k's upper half at its hip: the stride's swing (about up) and lift ([phase, walk]); `side` turns the swing so
## the foot sweeps back on the ground.
static func _stride(v: Array, k: int, hip: Vector3, axis: Vector3, side: float) -> Transform3D:
	var at := (float(v[0]) + float(TRIPOD[k])) * TAU
	var walk: float = v[1]
	var yaw := sin(at) * SWING * walk * side
	var lift := maxf(0.0, cos(at)) * STEP_LIFT * walk
	return Transform3D(Basis(Vector3.UP, yaw) * Basis(axis, lift), hip)


## Leg k's lower half at its knee (`at`, from the hip): the stride's knee lift ([phase, walk]).
static func _knee_step(v: Array, k: int, at: Vector3, axis: Vector3) -> Transform3D:
	var a := (float(v[0]) + float(TRIPOD[k])) * TAU
	return Transform3D(Basis(axis, maxf(0.0, cos(a)) * STEP_LIFT * KNEE_LIFT * float(v[1])), at)


## The hip's stance ([wind, lunge, daze]): the front pair raised on the wind-up and thrown ahead on the lunge; all
## limp in the daze.
static func _hip_stance(v: Array, front: bool) -> float:
	var wind: float = v[0]
	var lunge: float = v[1]
	var raise := wind * RAISE_HIP * (1.0 - lunge) + lunge * REACH_HIP if front else -lunge * 0.1
	return raise + float(v[2]) * LIMP_HIP


static func _knee_stance(v: Array, front: bool) -> float:
	var wind: float = v[0]
	var lunge: float = v[1]
	var curl := -wind * RAISE_KNEE * (1.0 - lunge) + lunge * REACH_KNEE if front else lunge * 0.15
	return curl + float(v[2]) * LIMP_KNEE


## The hip's hold ([body_y, crouch]): the leg lifts as the body sinks (and dips as it rises), so the foot stays near
## the ground.
static func _hip_hold(v: Array, reach: float) -> float:
	var by := lerpf(ChargerVat.BODY_Y_LO, ChargerVat.BODY_Y_HI, v[0]) * BODY_K
	return clampf(-by / maxf(reach, 0.05), -0.6, 0.6)


static func _knee_hold(v: Array, reach: float) -> float:
	return -0.4 * _hip_hold(v, reach)


## The fold ([rise, death]): the legs tucked up under it before the rise, curled up as it dies.
static func _fold(v: Array, rise_k: float, death_k: float) -> float:
	return (1.0 - float(v[0])) * rise_k + float(v[1]) * death_k


## Leg k's idle tap ([clock, amount]): now and then one foot lifts (the Charger's fidget, eased in and out so the
## baked clock samples it closely).
static func _tap(v: Array, k: int) -> float:
	var u := maxf(0.0, sin(float(v[0]) * TAU + k * 1.6 + 4.0) - 0.85) / 0.15
	return u * u * TAP * float(v[1])


## Leg k's dazed twitch ([clock, daze]).
static func _twitch(v: Array, k: int) -> float:
	return sin(float(v[0]) * TAU + k) * TWITCH_RAD * float(v[1])
