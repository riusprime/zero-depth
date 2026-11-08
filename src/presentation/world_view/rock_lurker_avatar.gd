class_name RockLurkerAvatar
extends AvatarBase
## v0.11.0 O17b (ENEMIES.md R3; owner 2026-11-08: "make sure they are animated as good as you can"): the Rock Lurker on
## the owner's model (EnemyModels &"rock_lurker", prepared by scripts/assets/o17_prep_rock_lurker.py): a heavy crouched
## creature whose back is one faceted boulder with thin red-orange cracks, a dark face plate with a red brow and one
## gem visor under the rock's front edge, two big gorilla arms (each an upper boulder and a clawed forearm) and two
## short hind legs. +X is the front; it sits at the actor's feet under ActorViews' facing node.
## Its clips, all drawn from the sim's state (WorldReader: lurker_hidden, lurker_rumbling, the state and the
## telegraph's progress) and run in frame time (EI-07: nothing here decides):
## - disguised (lurker_hidden, and its arrival): sunk to the ground with its legs folded under the rock and its face
##   drawn in, perfectly still: a boulder; only its cracks breathe, faint and slow;
## - the rumble (lurker_rumbling, the hero within 4 m): the rock shudders and lifts a little, the cracks pulse up and
##   the visor glints under the front edge (no shudder with reduced motion: a slow lift and pulse);
## - the burst (it stops hiding): a beat of anticipation (it sinks, the cracks flare), then the rock heaves up front
##   first, the arms unfold and the claws come out, and it lands heavily on them; woken by the hero's nearness it bursts
##   straight into its slam's windup (faster), woken by a hit it comes out walking;
## - the slam: through the windup (0.5 s, the telegraph's progress) it rears back on its hind legs with both arms
##   overhead and holds there trembling (the beat), then at the hit tick both claws smash down in front, the body
##   pitching forward and dropping; the rock shell follows through (a damped wobble) and the cracks flash; through the
##   recovery it stays down, then heaves itself back up;
## - a heavy knuckle walk (speed-matched to its stride: the arms reach and plant in turn, the hind legs lead them,
##   the body rolls onto the planted arm and dips at each plant);
## - idle awake: slow heavy breathing (the rock rises and falls, the head nods against it, the cracks breathe), the
##   head scanning, the weight shifting;
## - the hit flinch: AvatarBase's lean on this node, and the face recoiling under the rock, the arms flaring, the cracks
##   flashing;
## - death (ActorViews keeps it DEATH_SECONDS): the legs give, it collapses back down into a rock slumped a little to
##   one side, with a small rebound, and its glow fades out to a still stone;
## - reduced motion (ViewPrefs.reduced_motion): no shudders or trembles, no wobble, a smaller rear-up and heave and
##   smaller secondary motion (the same timings).
## The sim never puts it back into hiding, so there is no clip for that.
## VAT (SoloVat, owner 2026-11-06 "apply it to the rest of the enemies"): each pose is a set of plain numbers (_vd,
## VAT_DRIVES) the nodes are written from, each joint one of them, so the VatCrowd's shader poses the same body.
## Without the model file it builds a code-made stand-in on the same joints (L15).

const KIND := WorldReader.KIND_ROCK_LURKER
const MODEL := &"rock_lurker"
## Its height (m): EnemyModels' SPECS height (the art list's 0.9 m boulder; its 1.29 m length fits the 1.3 m body).
const HEIGHT := 0.9
const OUTLINE_M := 0.02
const ROLE := Color("#C93A1E")
const CRACK_COLOR := Color("#E2481F")
const VISOR_COLOR := Color("#FF5A24")
const STONE := Color("#8C8580")
const DARK := Color("#2E2D30")
const BONE := Color("#D9CDB8")
## The cracks' glow (emission energy): disguised (faint, breathing), the rumble's peak, awake.
const CRACK_REST := 0.6
const CRACK_RUMBLE := 2.2
const CRACK_OUT := 2.0
const VISOR_REST := 1.6
## The joints' rest places (model metres) when the model file is missing (the prep's pivots).
const PIVOTS := {
	&"body": Vector3(0.0, 0.225, 0.0),
	&"head": Vector3(0.27, 0.342, 0.0),
	&"arm_r": Vector3(0.135, 0.288, 0.324),
	&"arm_l": Vector3(0.135, 0.288, -0.324),
	&"hand_r": Vector3(0.261, 0.189, 0.36),
	&"hand_l": Vector3(0.261, 0.189, -0.36),
	&"leg_r": Vector3(-0.315, 0.216, 0.324),
	&"leg_l": Vector3(-0.315, 0.216, -0.324),
}
## The way the face draws in under the rock (a slide of HX metres).
const HEAD_IN := Vector3(-0.96, -0.28, 0.0)
## The hind feet's ground point the rear-up and the slam turn the body about (model metres).
const HIND_FOOT := Vector2(-0.34, 0.0)
## The walk: metres a full gait cycle covers, the arms' and legs' swing (radians), the hand's lift (elbow radians).
const STRIDE := 1.1
const ARM_SWING := 0.5
const LEG_SWING := 0.55
const HAND_LIFT := 0.6
const BREATH_HZ := 0.42
## The slam: the rear-up's pitch back (radians) and the smash's pitch forward; the recovery's length in ticks (the
## data's 0.8 s) and the share of it held down.
const REAR_PITCH := 0.62
const SLAM_PITCH := 0.15
const RECOVER_TICKS := 48
const RECOVER_HOLD := 0.4
## The burst's length (s): woken by a hit (it comes out walking) or straight into the slam's windup.
const BURST_S := 0.55
const BURST_SLAM_S := 0.34
## How long the death is drawn (ActorViews keeps the node this long).
const DEATH_SECONDS := 1.1
const TELEPORT_SPEED := 30.0

## The raw drives (_vd) and their specs [lo, hi, loop]: the body's slide (x, y), yaw, roll, pitch; the head's draw-in,
## yaw, pitch; each arm's roll (inward) and swing; each elbow; the hind legs' roll (inward, mirrored) and each one's
## swing; the cracks' glow (a drive no grid reads: sent as it is, the crack material's GLOW).
const BX := 0
const BY := 1
const BW := 2
const BR := 3
const BP := 4
const HX := 5
const HY := 6
const HP := 7
const AO_R := 8
const AO_L := 9
const AS_R := 10
const AS_L := 11
const EL_R := 12
const EL_L := 13
const LO := 14
const LS_R := 15
const LS_L := 16
const CRACK := 17
const VAT_DRIVES := [
	[-0.16, 0.2, false],
	[-0.3, 0.26, false],
	[-0.16, 0.16, false],
	[-0.3, 0.3, false],
	[-0.6, 0.9, false],
	[-0.1, 0.3, false],
	[-0.45, 0.45, false],
	[-0.6, 0.5, false],
	[-0.7, 0.7, false],
	[-0.7, 0.7, false],
	[-1.5, 2.2, false],
	[-1.5, 2.2, false],
	[-0.7, 1.9, false],
	[-0.7, 1.9, false],
	[-0.5, 0.7, false],
	[-1.4, 1.4, false],
	[-1.4, 1.4, false],
	[0.0, 0.0, false],
]
## Samples per drive's grid (a turn's step stays under about 0.05 rad; a slide is exact on two).
const VAT_SAMPLES := [2, 2, 9, 13, 33, 2, 19, 23, 29, 29, 75, 75, 53, 53, 25, 57, 57, 0]

var vat := false
var kind := KIND
var has_model := false
var body: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var hands: Array[Node3D] = []
var legs: Array[Node3D] = []

var _model: Node3D
var _lifted := Node3D.new()
var _rest := {}
var _crack_mat := StandardMaterial3D.new()
var _visor_mat := StandardMaterial3D.new()
var _vd := PackedFloat32Array()
var _lift := 0.0
var _visor := VISOR_REST
var _crack := CRACK_REST

var _state := WorldReader.STATE_SPAWN
var _state_ticks := 0
var _windup := 0.0
var _hidden := true
var _rumbling := false
var _tuck := 1.0
var _rumble := 0.0
var _burst := -1.0
var _burst_slam := false
var _speed := 0.0
var _walk := 0.0
var _phase := 0.0
var _rear := 0.0
var _slam := 0.0
var _impact := -1.0
var _die := -1.0
var _rise := 1.0


## Builds a Rock Lurker under `facing` for ActorViews (`vat_hook`: its _solo_vat, called before the setup) and marks
## `root` (its avatar, its body materials for the hit flash); returns its height.
static func attach(
	root: Node3D, facing: Node3D, outline: Color, technique: StringName, vat_hook: Callable
) -> float:
	var a := RockLurkerAvatar.new()
	vat_hook.call(root, a, KIND)
	a.setup(outline, technique)
	facing.add_child(a)
	root.set_meta(&"enemy_avatar", a)
	root.set_meta(&"mats", a.body_materials.duplicate())
	return HEIGHT


func setup(outline_color: Color, technique: StringName = &"outline") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vd.resize(VAT_DRIVES.size())
	_setup_glows()
	var m := EnemyModels.get_model(MODEL)
	has_model = not m.is_empty()
	_lifted.name = "Lift"  # the spawn's rise (the VAT instance's lift, not a joint)
	add_child(_lifted)
	_model = Node3D.new()
	_model.name = "Model"
	if has_model:
		_model.scale = Vector3.ONE * float(m["scale"])
	_lifted.add_child(_model)
	_read_rest(m)
	_build_joints()
	if not vat:
		if has_model:
			_dress_model(m, outline_color)
		else:
			_build_stand_in(outline_color, technique)
		# Only the rock and the face cast its shadow stand-in (EnemyShadows: built from the standing pose, it would
		# draw legs beside the boulder while it hides).
		for j: Node3D in Array(arms) + Array(hands) + Array(legs):
			for mi: MeshInstance3D in j.find_children("*", "MeshInstance3D", false, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pose()


func _setup_glows() -> void:
	for pair: Array in [
		[_crack_mat, CRACK_COLOR, CRACK_REST], [_visor_mat, VISOR_COLOR, VISOR_REST]
	]:
		var mat: StandardMaterial3D = pair[0]
		mat.albedo_color = (pair[1] as Color).darkened(0.55)
		mat.emission_enabled = true
		mat.emission = pair[1]
		mat.emission_energy_multiplier = pair[2]
		mat.roughness = 1.0
		write_stencil(mat)
	_crack_mat.set_meta(SoloVat.GLOW, CRACK + 1)  # VAT: the cracks glow at their own drive


## The joints' rest places in the model frame (the model's part pivots, or PIVOTS).
func _read_rest(m: Dictionary) -> void:
	for n: StringName in PIVOTS:
		_rest[n] = PIVOTS[n]
	if m.is_empty():
		return
	var parts: Dictionary = m["parts"]
	for n: StringName in parts:
		_rest[n] = (parts[n] as Dictionary)["pivot"]


## The joint nodes: the body under the model holder, the head, arms and hind legs under the body, a hand under each
## arm (each at its rest place relative to its parent).
func _build_joints() -> void:
	body = _joint(_model, &"body", Vector3.ZERO)
	head = _joint(body, &"head", _rest[&"body"])
	for side: String in ["r", "l"]:
		var arm := _joint(body, StringName("arm_" + side), _rest[&"body"])
		arms.append(arm)
		hands.append(_joint(arm, StringName("hand_" + side), _rest[StringName("arm_" + side)]))
		legs.append(_joint(body, StringName("leg_" + side), _rest[&"body"]))


func _joint(parent: Node3D, n: StringName, parent_at: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = String(n)
	j.position = (_rest[n] as Vector3) - parent_at
	parent.add_child(j)
	return j


func _part(n: StringName) -> Node3D:
	var by := {&"body": body, &"head": head}
	for k in 2:
		var side := "_r" if k == 0 else "_l"
		by[StringName("arm" + side)] = arms[k]
		by[StringName("hand" + side)] = hands[k]
		by[StringName("leg" + side)] = legs[k]
	return by.get(n)


## The owner's model on the joints: `base` (the stone and charcoal, coloured as delivered) and `role` (the brow,
## greyscale in the map, in the role colour) are the body plates (the hit flash); `glow` is the cracks' ribbons on the
## body and the visor on the head.
func _dress_model(m: Dictionary, outline: Color) -> void:
	var tex: Texture2D = m["texture"]
	var mats := {}
	for slot: StringName in [&"base", &"role"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = ROLE if slot == &"role" else Color.WHITE
		mat.roughness = 1.0
		ActorLooks.outline(mat, outline, OUTLINE_M)
		mat.set_meta(&"enemy_tex", true)
		mats[slot] = ActorViews.flashable(mat)
		body_materials.append(mat)
	var parts: Dictionary = m["parts"]
	for n: StringName in parts:
		var at := _part(n)
		if at == null:
			continue
		var part: Dictionary = parts[n]
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = part["mesh"]
		var surfaces: Array = part["surfaces"]
		for k in surfaces.size():
			var mat: Material = mats.get(surfaces[k], mats[&"base"])
			if surfaces[k] == &"glow":
				mat = _crack_mat if n == &"body" else _visor_mat
			mi.set_surface_override_material(k, mat)
		at.add_child(mi)


## Without the model: a code-made stand-in on the same joints (a faceted boulder with crack slivers, a dark face and
## its gem, block arms with bone claws, stub legs).
func _build_stand_in(outline: Color, technique: StringName) -> void:
	var b: Vector3 = _rest[&"body"]
	var stone := SphereMesh.new()
	stone.radius = 0.55
	stone.height = 0.72
	stone.radial_segments = 8
	stone.rings = 4
	_outlined(body, stone, Vector3(-0.08, 0.36, 0) - b, STONE, outline, STONE, technique, OUTLINE_M)
	for k in 4:
		var crack := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.36, 0.025, 0.03)
		crack.mesh = cm
		crack.material_override = _crack_mat
		var ang := (k + 0.5) * TAU / 4.0
		crack.position = Vector3(cos(ang) * 0.32 - 0.08, 0.6, sin(ang) * 0.32) - b
		crack.rotation = Vector3(0.0, -ang, 0.5)
		body.add_child(crack)
	var face := BoxMesh.new()
	face.size = Vector3(0.12, 0.2, 0.3)
	_outlined(head, face, Vector3(0.1, 0.0, 0), DARK, outline, DARK, technique, OUTLINE_M)
	var brow := BoxMesh.new()
	brow.size = Vector3(0.16, 0.08, 0.32)
	_outlined(head, brow, Vector3(0.14, 0.13, 0), ROLE, outline, ROLE, technique, OUTLINE_M)
	var gem := MeshInstance3D.new()
	var gm := PrismMesh.new()
	gm.size = Vector3(0.08, 0.08, 0.05)
	gem.mesh = gm
	gem.material_override = _visor_mat
	gem.position = Vector3(0.18, 0.05, 0)
	gem.rotation = Vector3(0, 0, -PI * 0.5)
	head.add_child(gem)
	for k in 2:
		var upper := BoxMesh.new()
		upper.size = Vector3(0.2, 0.22, 0.2)
		_outlined(
			arms[k], upper, Vector3(0.06, -0.05, 0), STONE, outline, STONE, technique, OUTLINE_M
		)
		var fore := BoxMesh.new()
		fore.size = Vector3(0.26, 0.2, 0.22)
		_outlined(
			hands[k], fore, Vector3(0.12, -0.09, 0), STONE, outline, STONE, technique, OUTLINE_M
		)
		var claw := PrismMesh.new()
		claw.size = Vector3(0.1, 0.12, 0.18)
		var c := _outlined(
			hands[k], claw, Vector3(0.3, -0.15, 0), BONE, outline, BONE, technique, OUTLINE_M
		)
		c.rotation.z = -PI * 0.5
		var leg := BoxMesh.new()
		leg.size = Vector3(0.16, 0.22, 0.16)
		_outlined(legs[k], leg, Vector3(0, -0.11, 0), STONE, outline, STONE, technique, OUTLINE_M)


# --- the sim's state -----------------------------------------------------------------------------------------------


func sync(reader: WorldReader, i: int) -> void:
	var tg := reader.telegraph(i)
	var st := reader.actor_state(i)
	apply_state(
		{
			"tick": reader.tick(),
			"pos": reader.actor_pos(i),
			"state": st,
			"windup": float(tg.get("progress", 0)) / 1000.0,
			"hidden": reader.lurker_hidden(i) or st == WorldReader.STATE_SPAWN,
			"rumbling": reader.lurker_rumbling(i),
		}
	)
	_show_rings(not _hidden)  # its disguise: no contact disc or team ring while it waits


## The same as sync(), from plain values (tests and tools drive the avatar with this): tick, pos, state (a WorldReader
## STATE_*), windup (0..1, the telegraph's progress), hidden (waiting as a boulder; its arrival counts), rumbling.
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var state: int = s["state"]
	var hidden := bool(s.get("hidden", false))
	if _fresh or state != _state:
		_state_ticks = 0
	elif tick > _last_tick:
		_state_ticks += tick - _last_tick
	_track_motion(tick, s.get("pos", Vector2.ZERO), TELEPORT_SPEED)
	if _fresh:
		_tuck = 1.0 if hidden else 0.0
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
	elif _hidden and not hidden:  # it stops hiding: the burst (into the slam when the hero woke it)
		_burst = 0.0
		_burst_slam = state == WorldReader.STATE_WINDUP
	if state != WorldReader.STATE_WINDUP and _burst < 0.0:
		_burst_slam = false
	_state = state
	_hidden = hidden
	_rumbling = bool(s.get("rumbling", false)) and hidden
	_windup = clampf(float(s.get("windup", 0.0)), 0.0, 1.0)
	strike_note(state)
	if _fresh:
		_fresh = false
		_pose()


## Starts the death (ActorViews keeps the node DEATH_SECONDS). False when it is already dying.
func die() -> bool:
	if _die >= 0.0:
		return false
	_die = 0.0
	return true


## ActorViews, once die() started it: the actor's node (`root`) stays DEATH_SECONDS while it collapses, its bar gone.
func fall(root: Node3D) -> void:
	set_process(true)
	if root.has_meta(&"bar"):
		(root.get_meta(&"bar") as Node3D).visible = false
	get_tree().create_timer(DEATH_SECONDS).timeout.connect(root.queue_free)


func dying() -> bool:
	return _die >= 0.0


# --- frame time ----------------------------------------------------------------------------------------------------


func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0:
		return
	_t += dt
	if _die >= 0.0:
		_die += dt
		_pose()
		return
	_speed = lerpf(_speed, _vel.length(), _rate(8.0, dt))
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt / 0.5)
	_rumble = move_toward(_rumble, 1.0 if _rumbling else 0.0, dt * (3.0 if _rumbling else 1.5))
	if _burst >= 0.0:
		_burst += dt
		var u := _burst / (BURST_SLAM_S if _burst_slam else BURST_S)
		_tuck = 1.0 - smoothstep(0.2, 0.62, u)
		if u >= 1.0:
			_burst = -1.0
	elif _hidden:
		_tuck = move_toward(_tuck, 1.0, dt * 2.0)
	else:
		_tuck = move_toward(_tuck, 0.0, dt * 4.0)
	var was_snapping := strike_snapping()
	strike_advance(dt)
	var winding := _state == WorldReader.STATE_WINDUP
	if winding:
		_rear = _rear_at(_windup)
	elif strike_snapping():
		_rear = minf(_rear, 1.0 - _strike_s / STRIKE_SNAP_S)
	else:
		_rear = move_toward(_rear, 0.0, dt * 4.0)
	var hold := 0.0
	if _state == WorldReader.STATE_RECOVER:
		hold = 1.0 - smoothstep(RECOVER_HOLD, 1.0, float(_state_ticks) / RECOVER_TICKS)
	var swing := strike_swing()
	if strike_snapping():
		_slam = maxf(swing, _slam)
	elif swing > 0.0 or hold > 0.0:
		_slam = maxf(swing, hold)
	else:
		_slam = move_toward(_slam, 0.0, dt * 3.0)
	if was_snapping and not strike_snapping():
		_impact = 0.0
	if _impact >= 0.0:
		_impact += dt
		if _impact > 1.5:
			_impact = -1.0
	var busy := maxf(maxf(_rear, _slam), _tuck)
	var walk_to := 0.0 if busy > 0.3 else clampf(_speed / 2.2, 0.0, 1.2)
	_walk = lerpf(_walk, walk_to, _rate(6.0, dt))
	_phase = fposmod(_phase + _speed * dt * TAU / STRIDE * (1.0 - busy), TAU * 8.0)
	_pose()


## 0..1: the rear-up through the windup at progress p (a burst's windup rears later, after the heave), with the last
## of it a slow extra coil (the beat).
func _rear_at(p: float) -> float:
	if _burst_slam:
		return smoothstep(0.28, 0.75, p)
	return smoothstep(0.0, 0.55, p)


# --- the pose ------------------------------------------------------------------------------------------------------


## The pose's numbers (the VAT drives, the lift, the glows) from the state, then the nodes from them.
func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var m := 0.4 if calm else 1.0
	var v := PackedFloat32Array()
	v.resize(VAT_DRIVES.size())
	var winding := _state == WorldReader.STATE_WINDUP
	var busy := clampf(maxf(_rear, _slam), 0.0, 1.0)
	# Idle awake: slow heavy breathing, the head scanning and nodding against it, the weight shifting.
	var br := sin(_t * TAU * BREATH_HZ)
	var idle := (1.0 - clampf(_walk, 0.0, 1.0)) * (1.0 - busy)
	v[BY] = 0.014 * br * idle
	v[BP] = 0.03 * br * idle
	v[HP] = -0.06 * br * idle
	v[HY] = 0.3 * sin(_t * 0.43) * sin(_t * 0.19 + 1.0) * idle * m
	v[BR] = 0.03 * sin(_t * 0.31) * idle * m
	for k in 2:
		v[AS_R + k] = 0.05 * br * idle
		v[EL_R + k] = -0.04 * br * idle
	# The knuckle walk (lateral sequence: each hind leg leads the arm on its side by a quarter cycle).
	var w := clampf(_walk, 0.0, 1.2)
	for k in 2:
		var s := 1.0 if k == 0 else -1.0
		var pa := _phase + PI * k
		var lift := smoothstep(0.0, 1.0, maxf(0.0, cos(pa)))
		v[AS_R + k] += w * (ARM_SWING * sin(pa) + 0.1 * lift)
		v[EL_R + k] += w * HAND_LIFT * lift
		v[AO_R + k] += -s * w * 0.07 * lift
		v[LS_R + k] += w * LEG_SWING * sin(pa + PI * 0.5)
	v[BY] += w * 0.024 * cos(2.0 * _phase) * (0.5 if calm else 1.0)
	v[BX] += -w * 0.012 * cos(2.0 * _phase) * m
	v[BR] += -w * 0.055 * cos(_phase) * m
	v[BW] += w * 0.05 * sin(_phase) * m
	v[BP] += -0.07 * w + w * 0.025 * cos(2.0 * _phase + 0.5) * m
	v[HP] += 0.06 * w - w * 0.02 * cos(2.0 * _phase) * m
	v[LO] += 0.05 * w
	# The slam: reared back on its hind legs (about the hind feet), arms overhead, holding with a tremble; then the
	# smash: pitched forward, dropped, both claws down in front.
	var coil := smoothstep(0.75, 1.0, _windup) if winding else 0.0
	var rear := _rear * (0.8 if calm else 1.0)  # (reduced motion: a smaller rear-up, the same timing)
	var pitch := REAR_PITCH * rear + 0.07 * coil * rear - SLAM_PITCH * _slam
	var about := _about_feet(pitch)
	v[BX] += about.x + 0.06 * _slam
	v[BY] += about.y + 0.03 * rear - 0.03 * _slam
	v[BP] += pitch
	v[HP] += -0.3 * rear + 0.12 * _slam
	v[HX] += -0.04 * rear
	for k in 2:
		var s := 1.0 if k == 0 else -1.0
		v[AS_R + k] += 1.6 * rear + 0.4 * _slam
		v[EL_R + k] += 0.6 * rear - 0.2 * _slam
		v[AO_R + k] += s * (0.14 * rear - 0.12 * _slam)
		v[LS_R + k] += -0.85 * pitch
	if winding and not calm and _rear > 0.9:
		v[BX] += 0.006 * sin(_t * 53.0) * _rear
		v[BR] += 0.014 * sin(_t * 41.0) * _rear
	# The shell's follow-through after the smash: a damped wobble (none with reduced motion).
	var wob := 0.0
	if _impact >= 0.0 and not calm:
		wob = exp(-5.0 * _impact) * sin(17.0 * _impact)
		v[BP] += -0.07 * wob
		v[BY] += 0.018 * wob
		for k in 2:
			v[AS_R + k] += 0.08 * wob
	# The burst: a beat of anticipation (it sinks), the heave (front first, claws out), the heavy landing.
	var flare := 0.0
	if _burst >= 0.0:
		var u := _burst / (BURST_SLAM_S if _burst_slam else BURST_S)
		var ant := smoothstep(0.0, 0.14, u) * (1.0 - smoothstep(0.14, 0.26, u))
		var heave := (
			smoothstep(0.16, 0.45, u) * (1.0 - smoothstep(0.45, 0.85, u)) * (0.6 if calm else 1.0)
		)
		var land := smoothstep(0.68, 0.82, u) * (1.0 - smoothstep(0.82, 1.0, u))
		flare = maxf(ant, heave)
		v[BY] += -0.025 * ant + 0.1 * heave - 0.03 * land
		v[BP] += 0.2 * heave - 0.04 * land
		v[HX] += -0.05 * heave
		v[HP] += 0.15 * heave
		for k in 2:
			var s := 1.0 if k == 0 else -1.0
			v[AS_R + k] += 0.45 * heave - 0.12 * land
			v[AO_R + k] += -s * 0.3 * heave
			v[EL_R + k] += 0.25 * heave
		if not calm and u < 0.3:
			v[BX] += 0.01 * sin(_t * 61.0) * ant
			v[BR] += 0.02 * sin(_t * 47.0) * ant
	# The flinch: the face recoils under the rock, the arms flare.
	var fl := maxf(flinch_amount(), 0.0)
	v[HX] += 0.06 * fl
	v[HP] += 0.12 * fl
	v[BY] += -0.015 * fl
	for k in 2:
		v[AO_R + k] += -(1.0 if k == 0 else -1.0) * 0.18 * fl
	# Disguised: sunk, legs folded under the rock, face drawn in; the rumble lifts and shudders it.
	var tuck := smoothstep(0.0, 1.0, _tuck)
	var dead := 0.0
	if _die >= 0.0:
		dead = smoothstep(0.0, 0.5, _die / DEATH_SECONDS * 1.1)
		dead = dead * dead * (3.0 - 2.0 * dead)
		tuck = maxf(tuck, dead)
	_blend_tucked(v, tuck)
	var ru := _rumble * tuck * (1.0 - dead)
	v[BY] += 0.022 * ru
	v[HX] += -0.035 * ru
	v[HP] += 0.1 * ru
	if not calm:
		v[BX] += 0.01 * ru * sin(_t * 47.0)
		v[BR] += 0.02 * ru * sin(_t * 39.0 + 1.0)
		v[BW] += 0.012 * ru * sin(_t * 31.0 + 2.0)
	if _die >= 0.0:  # slumped a little to one side, a small rebound as it lands
		var d := _die / DEATH_SECONDS
		v[BR] += 0.12 * dead
		v[BP] += -0.03 * dead
		v[BY] += -0.02 * dead + 0.016 * sin(PI * clampf((d - 0.45) / 0.25, 0.0, 1.0))
	# The glows: the cracks breathe faint while it waits, pulse with the rumble, burn awake; the visor climbs and
	# flashes through the windup (AvatarBase.tell_glow); both fade out as it dies.
	var pulse_hz := 0.8 if calm else 2.4
	var hidden_e := CRACK_REST + 0.15 * sin(_t * 1.1)
	hidden_e += (CRACK_RUMBLE + 0.7 - hidden_e) * ru * (0.55 + 0.45 * sin(_t * TAU * pulse_hz))
	var awake_e := CRACK_OUT + 0.4 * br * idle + 1.6 * _rear + 0.8 * flare
	var e := lerpf(awake_e, hidden_e, tuck)
	if _impact >= 0.0:
		e += 2.5 * exp(-4.0 * _impact)
	e += 1.5 * fl
	var vis := VISOR_REST * (tell_glow(_windup, _t, calm) if winding else 1.0) + 2.0 * flare
	vis = lerpf(vis, 0.3 + 1.6 * ru, tuck)
	if _die >= 0.0:
		var d := _die / DEATH_SECONDS
		e *= 1.0 - smoothstep(0.1, 0.85, d)
		vis *= 1.0 - smoothstep(0.0, 0.4, d)
	v[CRACK] = maxf(e, 0.0)
	_crack = v[CRACK]
	_visor = maxf(vis, 0.0)
	_crack_mat.emission_energy_multiplier = _crack
	_visor_mat.emission_energy_multiplier = _visor
	# The spawn: the rock rises out of the ground (the whole body's lift).
	var sink := 1.0 - _rise
	_lift = -0.6 * sink * sink * (3.0 - 2.0 * sink)
	for k in VAT_DRIVES.size():  # in range (the shader clamps there too)
		var spec: Array = VAT_DRIVES[k]
		if float(spec[1]) > float(spec[0]):
			v[k] = clampf(v[k], spec[0], spec[1])
	_vd = v
	_write_nodes()


## The body's slide that turns it by `pitch` about the hind feet instead of its own pivot.
func _about_feet(pitch: float) -> Vector2:
	var p0: Vector3 = _rest[&"body"]
	var d := HIND_FOOT - Vector2(p0.x, p0.y)
	var c := cos(pitch)
	var s := sin(pitch)
	return d - Vector2(d.x * c - d.y * s, d.x * s + d.y * c)


## The disguise (and the death's rock) blended in by `k`: sunk nose-down to the ground, the face drawn in under the
## rock, the arms swung back and rolled in under it with the claws folded, the hind legs tucked forward.
func _blend_tucked(v: PackedFloat32Array, k: float) -> void:
	if k <= 0.0:
		return
	var to := {BX: 0.0, BY: -0.25, BW: 0.0, BR: 0.0, BP: -0.05, HX: 0.24, HY: 0.0, HP: -0.3}
	to[AS_R] = -1.0
	to[AS_L] = -1.0
	to[AO_R] = 0.25
	to[AO_L] = -0.25
	to[EL_R] = 0.6
	to[EL_L] = 0.6
	to[LO] = 0.15
	to[LS_R] = -0.45
	to[LS_L] = -0.45
	for d: int in to:
		v[d] = lerpf(v[d], to[d], k)


func _write_nodes() -> void:
	if body == null:
		return
	_lifted.position = Vector3(0.0, _lift, 0.0)
	body.position = (_rest[&"body"] as Vector3) + Vector3(_vd[BX], _vd[BY], 0.0)
	body.rotation = Vector3(_vd[BR], _vd[BW], _vd[BP])
	head.position = (_rest[&"head"] as Vector3) - (_rest[&"body"] as Vector3) + HEAD_IN * _vd[HX]
	head.rotation = Vector3(0.0, _vd[HY], _vd[HP])
	for k in 2:
		arms[k].rotation = Vector3(_vd[AO_R + k], 0.0, _vd[AS_R + k])
		hands[k].rotation = Vector3(0.0, 0.0, _vd[EL_R + k])
		legs[k].rotation = Vector3(_vd[LO] * (1.0 if k == 0 else -1.0), 0.0, _vd[LS_R + k])


## The Lurker's contact disc and team ring (ActorViews' rings on its root) show only once it is out.
func _show_rings(on: bool) -> void:
	var root := get_parent().get_parent() if get_parent() != null else null
	if root == null:
		return
	for n in root.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).visible != on:
			(n as MeshInstance3D).visible = on


# --- what tests and tools read -------------------------------------------------------------------------------------


func crack_energy() -> float:
	return _crack


func visor_energy() -> float:
	return _visor


## 0..1 each: how far it is folded into its boulder (tuck), reared for the slam (rear), smashed down (slam), walking
## (walk, up to 1.2).
func amounts() -> Dictionary:
	return {"tuck": _tuck, "rear": _rear, "slam": _slam, "walk": _walk}


## The raw drives now (tests: which joints a clip moves).
func drives() -> PackedFloat32Array:
	return _vd


# --- the VAT rig (SoloVat) -----------------------------------------------------------------------------------------


## The spawn's rise (m): the whole body's lift VatCrowd moves the instance by.
func vat_lift() -> float:
	return _lift


func vat_drives() -> PackedFloat32Array:
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The visor's glow (the cracks glow at their own drive).
func glow_energy() -> float:
	return _visor


## The owner's model's colour map (VatLooks' textured variant), or null for the stand-in.
func vat_texture() -> Texture2D:
	return EnemyModels.get_model(MODEL).get("texture") if has_model else null


## Each node's transform split into its one-number parts as its position and rotation (Y, X, Z) compose them: the
## body (slide x and y from its rest under the holder, yaw, roll, pitch), the head (the draw-in, yaw, pitch), each arm
## (roll, swing) and its hand (the elbow), each hind leg (roll, mirrored; swing).
func vat_rig() -> Dictionary:
	var x := Vector3.RIGHT
	var y := Vector3.UP
	var z := Vector3.BACK
	var b0: Vector3 = _rest[&"body"]
	var j: Array = [
		[BX, -1, null, SoloVat.slide(x, b0, _model.transform)],
		[BY, 0, null, SoloVat.slide(y)],
		[BW, 1, null, SoloVat.turn(y)],
		[BR, 2, null, SoloVat.turn(x)],
		[BP, 3, body, SoloVat.turn(z)],
	]
	j.append([HX, 4, null, SoloVat.slide(HEAD_IN, (_rest[&"head"] as Vector3) - b0)])
	j.append([HY, 5, null, SoloVat.turn(y)])
	j.append([HP, 6, head, SoloVat.turn(z)])
	for k in 2:
		var s := 1.0 if k == 0 else -1.0
		j.append([AO_R + k, 4, null, SoloVat.turn(x, 1.0, SoloVat.at(arms[k].position))])
		j.append([AS_R + k, j.size() - 1, arms[k], SoloVat.turn(z)])
		j.append(
			[EL_R + k, j.size() - 1, hands[k], SoloVat.turn(z, 1.0, SoloVat.at(hands[k].position))]
		)
		j.append([LO, 4, null, SoloVat.turn(x, s, SoloVat.at(legs[k].position))])
		j.append([LS_R + k, j.size() - 1, legs[k], SoloVat.turn(z)])
	var grids: Array = []
	for d in VAT_DRIVES.size() - 1:
		grids.append([[d, VAT_SAMPLES[d]]])
	var out := SoloVat.rig("rock_lurker", VAT_DRIVES, grids, j, OUTLINE_M, false)
	if has_model:
		out["albedo_tex"] = vat_texture()
	return out


func vat_sample(rng: RandomNumberGenerator) -> Dictionary:
	var ranges := {
		"_t": [0.0, 40.0],
		"_phase": [0.0, 40.0],
		"_walk": [0.0, 1.2],
		"_tuck": [0.0, 1.0],
		"_rumble": [0.0, 1.0],
		"_rear": [0.0, 1.0],
		"_slam": [0.0, 1.0],
		"_impact": [-1.0, 1.5],
		"_burst": [-0.6, 0.6],
		"_burst_slam": [true, false, true],
		"_die": [-1.0, 1.2],
		"_windup": [0.0, 1.0],
		"_state": [WorldReader.STATE_MOVE, WorldReader.STATE_WINDUP],
		"_rise": [0.0, 1.0],
		"_flinch_t": [0.0, 0.25],
		"_flinch_s": [0.0, 1.5],
	}
	var s := SoloVat.sample(self, rng, ranges, _pose)
	return s


func vat_set(s: Dictionary) -> void:
	SoloVat.apply(self, s, _pose)
