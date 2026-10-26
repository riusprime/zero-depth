class_name HordeAvatar
extends AvatarBase
## The six horde kinds (v0.4.0 EN), code-built low-poly in the enemy sheet's red and grey (no concept sheet yet; the
## agent's reading of the enemy style, ART_DIRECTION "Horde enemies"). One class builds each kind:
## - Swarmer: a tiny red beetle on six grey legs with bone mandibles that open through its windup.
## - Splitter: two red half-bodies pressed together over a glowing seam that gapes as it winds up; grey claws.
##   A Splitling is the same model at SPLITLING_SCALE.
## - Shield Bearer: a squat grey body under a red helm behind a tall grey tower shield (red trim) on its front; the
##   shield draws back through the windup and slams forward on the bash.
## - Mender: a floating red robe and grey hood holding up a pale-green heal crystal, a spinning green cross over it
##   (the priority mark); the crystal flares while its beam heals (the beam itself is HordeVisuals').
## - Mine Layer: a low red crawler with a grey dome and a mine sitting in its rear hopper, lowered to drop it.
## - Sniper: a red box body on a grey tripod with a long grey barrel; its scope glows hotter through the windup.
## Presentation only (EI-07): sync() reads the sim through WorldReader once per tick, advance() animates in frame time.
## +X is the front. v0.8.0 HR (owner O89, the horde lag): every material is EnemyLooks' (shared by every enemy of the
## same look, so a crowd's identical pieces draw instanced) and the meshes are shared too (_shared_mesh); the hit
## flash and the status tints (show_hit, from ActorViews) and the accent's glow (GLOW) are instance uniforms on this
## enemy's own pieces, set only when they change; the X-ray is a pass of each piece's material (no twin nodes).
## v0.8.0 TG (owner O4, Q3): the Swarmer's lane, the Splitter's and Splitling's disc, the Shield Bearer's bash lane and
## the Sniper's line are no longer drawn on the ground; these kinds (TELL_KINDS) read their windup from the body
## (AvatarBase "tell"): a crouch and draw-back that deepens with the windup's progress, the accent (eye, seam, visor,
## scope) brightening and flashing just before the strike, and the Sniper's muzzle charging up at its barrel's tip (in
## the air, never a line on the ground). The facing is the sim's, held through the windup.
## v0.8.0 P1 (owner O26: "Their arm movements don't communicate attacks properly"): the melee kinds (STRIKE_KINDS)
## raise their strike pose by STRIKE_RAISE_BY of the windup's progress and hold it (AvatarBase.strike_raise): the
## Swarmer's mandibles gape and its body rears, the Splitter's claws lift high and back, the Shield Bearer draws its
## shield back and leans in behind it. At the hit tick (the sim's ACTIVE) the strike snaps out (strike_swing): the
## mandibles bite shut as the body lunges, the claws chop down through the front, the shield slams forward.

## v0.8.0 EC: each kind's main plate (body), its second plate or trim (trim), its limbs and frame (grey) and its eye
## (eye) come from EnemyPalettes; the light grey, dark and bone parts stay neutral.
const GREY_LIGHT := Color("#8A817C")
const DARK := Color("#24272D")
const BONE := Color("#D9CDB8")
## The Mender's heal colour (beam, crystal, cross): pale green, not a reserved role (ART_DIRECTION).
const MEND := Color("#7CF29A")
const OUTLINE_M := 0.02
const SPLITLING_SCALE := 0.62
const HEIGHTS := {
	WorldReader.KIND_SWARMER: 0.36,
	WorldReader.KIND_SPLITTER: 0.95,
	WorldReader.KIND_SHIELD_BEARER: 1.25,
	WorldReader.KIND_MENDER: 1.75,
	WorldReader.KIND_MINE_LAYER: 0.7,
	WorldReader.KIND_SNIPER: 1.3,
}
## v0.8.0 TG: the kinds whose windup the body tells (no ground mark); the Mender has no attack and the Mine Layer's
## mines keep theirs.
const TELL_KINDS: Array[int] = [
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SPLITLING,
	WorldReader.KIND_SHIELD_BEARER,
	WorldReader.KIND_SNIPER,
]
## v0.8.0 P1: the melee kinds whose strike is a raise-and-hold then a snap.
const STRIKE_KINDS: Array[int] = [
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SPLITLING,
	WorldReader.KIND_SHIELD_BEARER,
]
## v0.8.0 P1: the Splitter's claw pivot (x, height) and how far out to each side the claws hang (z).
const CLAW_PIVOT := Vector3(0.1, 0.6, 0.36)
## v0.8.0 MI (the owner's models, posed in code): the walk is full at WALK_FULL_MPS (m/s on the ground), a stride
## WALK_HZ a second, the legs swing WALK_SWING (radians); a death lasts DEATH_SECONDS; the X-ray twin shrinks by
## (m). Starting values.
const WALK_FULL_MPS := 2.0
const WALK_HZ := 2.2
const WALK_SWING := 0.3
const DEATH_SECONDS := 0.4
## The Sniper's muzzle glow at full charge (emission energy; 0 when cold), and where it sits on the barrel.
const MUZZLE_ENERGY := 4.0
const MUZZLE_AT := Vector3(0.92, 0, 0)

## v0.8.0 HR: the code bodies' meshes, one per shape for every enemy (keyed by their vertices), and the boxes by size.
static var _meshes := {}
static var _boxes := {}

var kind := WorldReader.KIND_SWARMER
## The model's top (for the health bar).
var height := 1.0
## The pivot every part hangs from (the rise-in and the lean), and the kind's moving parts, by name.
var body: Node3D
var parts := {}
## v0.8.0 MI: the owner's model (null: the code-made body), scaled to the kind's height.
var model: Node3D

## The glowing accent (eye, seam, crystal, scope): shared (EnemyLooks.accent), its energy this enemy's GLOW.
var _glow_mat: ShaderMaterial
## v0.8.0 TG: the Sniper's muzzle (its GLOW from 0).
var _muzzle_mat: ShaderMaterial
## v0.8.0 EC: the eye slit the Splitter / Splitling and the Mender get when the palette asks for one on every kind
## (their glow is the seam and the heal crystal), steady.
var _eye_mat: ShaderMaterial
## v0.8.0 HR: the X-ray pass the body's pieces carry (null without the xray technique).
## v0.8.0 HR: this enemy's accent pieces (the glow) and muzzle, and the energies last set on them (the body plates
## and their flash: AvatarBase's _hit_pieces).
var _glow_pieces: Array[GeometryInstance3D] = []
var _muzzle_piece: GeometryInstance3D
var _glow_e := -1.0
var _muzzle_e := 0.0
var _tell_p := 0.0
var _state := WorldReader.STATE_SPAWN
var _state_tick := 0
var _ticks_in := 0
var _healing := false
var _rise := 0.0
var _wind := 0.0
var _strike := 0.0
var _outline := Color.BLACK
var _technique := &"outline"
## v0.8.0 MI: each part's rest pivot, the walk's phase and pace (0..1, from how fast the node moves on screen), and
## the death (seconds in; -1: alive).
var _rest := {}
var _walk := 0.0
var _walk_t := 0.0
var _last_at := Vector3.INF
var _die_t := -1.0
var _model_scale := 1.0


static func height_of(p_kind: int) -> float:
	if p_kind == WorldReader.KIND_SPLITLING:
		return float(HEIGHTS[WorldReader.KIND_SPLITTER]) * SPLITLING_SCALE
	return float(HEIGHTS.get(p_kind, 1.0))


static func is_horde_kind(p_kind: int) -> bool:
	return p_kind == WorldReader.KIND_SPLITLING or HEIGHTS.has(p_kind)


## v0.8.0 MI: the owner's model a kind draws with (EnemyModels; the Splitling the Splitter's, smaller), or &"".
static func model_id(p_kind: int) -> StringName:
	match p_kind:
		WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING:
			return &"splitter"
		WorldReader.KIND_SHIELD_BEARER:
			return &"shield_bearer"
		WorldReader.KIND_MENDER:
			return &"mender"
	return &""


## v0.8.0 MI: true when the body is the owner's model.
func has_model() -> bool:
	return model != null


## v0.8.0 MI: starts the death (the owner's model only): the body sinks and tips over DEATH_SECONDS, the Splitter's
## halves fly apart (its two Splitlings are already in the sim). False for the code-made body (it goes at once).
func die() -> bool:
	if model == null:
		return false
	_die_t = 0.0
	return true


func dying() -> bool:
	return _die_t >= 0.0


func setup(p_kind: int, outline_color: Color, technique: StringName = &"outline") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	kind = p_kind
	_outline = outline_color
	_technique = technique
	height = height_of(kind)
	body = Node3D.new()
	add_child(body)
	var glow := _col(&"eye")
	_eye_mat = EnemyLooks.accent(glow, glow, 1.5)
	if kind in [WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING]:
		glow = ThemePalette.color(&"telegraph_hostile")
	elif kind == WorldReader.KIND_MENDER:
		glow = MEND
	var owner_model := EnemyModels.get_model(model_id(kind))  # v0.8.0 MI: the owner's model first
	_glow_mat = EnemyLooks.accent(glow, glow, 1.5)
	if not owner_model.is_empty():
		_build_model(owner_model)
		if kind == WorldReader.KIND_SPLITLING:
			body.scale = Vector3.ONE * SPLITLING_SCALE
	else:
		match kind:
			WorldReader.KIND_SWARMER:
				_build_swarmer()
			WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING:
				_build_splitter()
				if kind == WorldReader.KIND_SPLITLING:
					body.scale = Vector3.ONE * SPLITLING_SCALE
			WorldReader.KIND_SHIELD_BEARER:
				_build_shield_bearer()
			WorldReader.KIND_MENDER:
				_build_mender()
			WorldReader.KIND_MINE_LAYER:
				_build_mine_layer()
			WorldReader.KIND_SNIPER:
				_build_sniper()
	_pose()


func sync(reader: WorldReader, i: int) -> void:
	apply_state(
		{
			"tick": reader.tick(),
			"state": reader.actor_state(i),
			"healing": reader.actor_heal_target(i) >= 0,
			"windup": windup_progress(reader, i),
		}
	)


## The same as sync(), from plain values (tests drive the avatar with this); "windup" (0..1, optional) is the
## windup's progress.
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var state: int = s["state"]
	_healing = bool(s.get("healing", false))
	_tell_p = clampf(float(s.get("windup", 0.0)), 0.0, 1.0)
	if _fresh or state != _state:
		_state = state
		_state_tick = tick
	_ticks_in = tick - _state_tick
	strike_note(state)  # v0.8.0 P1: the hit tick starts the strike
	if _fresh:
		_fresh = false
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_pose()


func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or body == null:
		return
	_t += dt
	if _die_t >= 0.0:
		_die_t += dt
	if model != null and is_inside_tree():  # v0.8.0 MI: the walk's pace from how fast the body moves
		var at := global_position
		var speed := (
			0.0
			if _last_at == Vector3.INF
			else Vector2(at.x - _last_at.x, at.z - _last_at.z).length() / dt
		)
		_last_at = at
		_walk = move_toward(_walk, clampf(speed / WALK_FULL_MPS, 0.0, 1.0), dt * 4.0)
		_walk_t += dt * lerpf(0.0, WALK_HZ * TAU, _walk)
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.5))
	var winding := _state == WorldReader.STATE_WINDUP
	strike_advance(dt)
	if STRIKE_KINDS.has(kind):
		# v0.8.0 P1: raised from the windup's progress and held; the strike snaps out at the hit tick.
		_wind = strike_raised(winding, _tell_p, move_toward(_wind, 0.0, dt * 5.0))
		_strike = strike_swing()
	else:
		_wind = move_toward(_wind, 1.0 if winding else 0.0, dt * (2.2 if winding else 5.0))
		if _state == WorldReader.STATE_ACTIVE:
			_strike = 1.0
		else:
			_strike = move_toward(_strike, 0.0, dt * 4.0)
	_pose()


## How far into its windup pose the model is, 0..1 (tests).
func windup_pose() -> float:
	return _wind


## v0.8.0 P1: 0..1 how far its strike is out (tests).
func strike_pose() -> float:
	return _strike


## The accent's glow (tests): the eye, seam, crystal or scope.
func glow_energy() -> float:
	return _glow_e


## v0.8.0 TG: 0..1 how deep the windup crouch is (0 for a kind without a tell or outside the windup).
func crouch_amount() -> float:
	if not TELL_KINDS.has(kind) or _state != WorldReader.STATE_WINDUP:
		return 0.0
	return tell_crouch(_tell_p)


## v0.8.0 TG: the Sniper's muzzle glow (0 when cold; always 0 for the other kinds).
func muzzle_energy() -> float:
	return _muzzle_e if parts.has("muzzle") else 0.0


func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var bob := 0.0 if calm else sin(_t * 7.0) * 0.015
	var crouch := crouch_amount()
	var telling := TELL_KINDS.has(kind) and _state == WorldReader.STATE_WINDUP
	var tell := tell_glow(_tell_p, _t, calm) if telling else 1.0
	# The crouch sinks the body by a share of its height and draws it back from the way it will strike.
	body.position = Vector3(
		-_wind * 0.06 - crouch * 0.08 * height + _strike * 0.12,
		bob - (1.0 - _rise) * height - crouch * 0.1 * height,
		0
	)
	body.rotation.z = crouch * 0.12
	var energy := (1.5 + _wind * 3.0) * tell + _strike * 2.0
	if model != null:  # v0.8.0 MI: the owner's model's parts
		_pose_model(energy, calm)
		return
	match kind:
		WorldReader.KIND_SWARMER:
			# v0.8.0 P1: rears up with the mandibles gaping, then lunges and bites them shut.
			body.rotation.z += _wind * 0.25 - _strike * 0.2
			body.position.x += _strike * 0.08
			for k in 2:
				var m: Node3D = parts["mandible%d" % k]
				m.rotation.y = (0.15 + _wind * 0.85 - _strike * 0.75) * (1.0 if k == 0 else -1.0)
			for k in 6:
				var leg: Node3D = parts["leg%d" % k]
				leg.rotation.z = sin(_t * 22.0 + k * 1.7) * 0.25
		WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING:
			var gap := 0.03 + _wind * 0.08 + sin(_t * 3.0) * 0.01
			(parts["left"] as Node3D).position.z = -gap
			(parts["right"] as Node3D).position.z = gap
			# v0.8.0 P1: the claws lift high and back over the body, then chop down through the front.
			var claws := parts["claws"] as Node3D
			claws.rotation.z = _wind * 1.1 - _strike * 0.85
			claws.position.x = CLAW_PIVOT.x - _wind * 0.06 + _strike * 0.14
			body.rotation.z += _wind * 0.1 - _strike * 0.16
		WorldReader.KIND_SHIELD_BEARER:
			# v0.8.0 P1: the shield draws back and tips up, the body leans in behind it; then the shield slams out.
			var shield := parts["shield"] as Node3D
			shield.position.x = 0.5 - _wind * 0.24 + _strike * 0.38
			shield.rotation.z = _wind * 0.22 - _strike * 0.12
			body.rotation.z += -_wind * 0.06 - _strike * 0.12
		WorldReader.KIND_MENDER:
			body.position.y += 0.18 + sin(_t * 2.2) * 0.06
			(parts["cross"] as Node3D).rotation.y = _t * 2.0
			energy = 1.5 + (2.5 + sin(_t * 9.0) if _healing else 0.0)
		WorldReader.KIND_MINE_LAYER:
			(parts["hopper"] as Node3D).position.y = 0.42 - _wind * 0.25
			(parts["mine"] as Node3D).visible = _strike < 0.5
		WorldReader.KIND_SNIPER:
			(parts["barrel"] as Node3D).rotation.z = -_wind * 0.04 + _strike * 0.12 - crouch * 0.12
			var charge := smoothstep(0.0, 1.0, _tell_p) if telling else 0.0
			var muzzle := MUZZLE_ENERGY * charge * tell / (1.0 + TELL_GLOW_CLIMB + TELL_GLOW_FLASH)
			_set_muzzle(maxf(muzzle, _strike * MUZZLE_ENERGY))
			(parts["muzzle"] as Node3D).scale = Vector3.ONE * (0.4 + 0.6 * maxf(charge, _strike))
	_set_glow(energy * lerpf(0.2, 1.0, _rise))


## v0.8.0 HR: the accent's energy on this enemy's accent pieces, set only when it changes.
func _set_glow(e: float) -> void:
	if e == _glow_e:
		return
	_glow_e = e
	for piece in _glow_pieces:
		piece.set_instance_shader_parameter(EnemyLooks.GLOW, e)


func _set_muzzle(e: float) -> void:
	if e == _muzzle_e or _muzzle_piece == null:
		return
	_muzzle_e = e
	_muzzle_piece.set_instance_shader_parameter(EnemyLooks.GLOW, e)


# --- v0.8.0 MI: the owner's models ----------------------------------------------------------------------------------


## The owner's model (EnemyModels.get_model): each part a node at its pivot, its surfaces on three materials: the
## frame as delivered (`base`), the plates in the kind's role colour (`role`: greyscale in the texture, times
## _col(&"body")), the accents on the glowing accent material (`glow`). Both body materials take the hit flash and
## the biome's tint and role glow like the code bodies' plates (they were the "enemy_tex" materials); no drawn
## outline (owner v0.7.5 on his models: the stroke is ugly; v0.8.0 HR: the stencil is written straight, no empty
## outline pass).
func _build_model(m: Dictionary) -> void:
	var tex: Texture2D = m["texture"]
	var base := _body_material(Color.WHITE, tex, 0.0)
	var role := _body_material(_col(&"body"), tex, 0.0)
	model = Node3D.new()
	model.name = "Model"
	_model_scale = float(m["scale"])
	model.scale = Vector3.ONE * _model_scale
	body.add_child(model)
	var parts_in: Dictionary = m["parts"]
	for pname: StringName in parts_in:
		var part: Dictionary = parts_in[pname]
		var pivot := Node3D.new()
		pivot.name = String(pname)
		pivot.position = part["pivot"]
		model.add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = part["mesh"]
		mi.extra_cull_margin = 0.5  # poses move parts past the rest bounds
		var surfaces: Array = part["surfaces"]
		var plates := false
		var glows := false
		for s in surfaces.size():
			var which: StringName = surfaces[s]
			glows = glows or which == &"glow"
			plates = plates or which != &"glow"
			mi.set_surface_override_material(
				s, _glow_mat if which == &"glow" else (role if which == &"role" else base)
			)
		pivot.add_child(mi)
		if plates:
			_hit_pieces.append(mi)
		if glows:
			_glow_pieces.append(mi)
		parts[String(pname)] = pivot
		_rest[String(pname)] = pivot.position


## v0.8.0 HR: the shared body material for a plate of colour `c` (times `tex`, the owner's colour map, when given),
## outlined `outline_m` thick (AvatarBase.shared_body: the biome's cast and the role glow picked in).
func _body_material(c: Color, tex: Texture2D, outline_m: float) -> ShaderMaterial:
	return shared_body(kind, c, tex, _outline, outline_m)


## v0.8.0 MI: the model's parts in this frame's pose (model units, about a metre each; +X the front, each part turning
## about its own pivot). What drives each move is the same as the code body's: the windup's raise-and-hold (_wind),
## the strike's snap (_strike), the Mender's heal, the walk's pace (_walk) and the death (_die_t).
func _pose_model(energy: float, calm: bool) -> void:
	var swing := sin(_walk_t) * WALK_SWING * _walk
	var d := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0) if _die_t >= 0.0 else 0.0
	model.rotation = Vector3.ZERO
	for pname: String in parts:
		var n := parts[pname] as Node3D
		n.position = _rest[pname]
		n.rotation = Vector3.ZERO
	if parts.has("leg_l"):
		(parts["leg_l"] as Node3D).rotation.z = swing
		(parts["leg_r"] as Node3D).rotation.z = -swing
		body.position.y += absf(sin(_walk_t)) * 0.025 * _walk
	match kind:
		WorldReader.KIND_SHIELD_BEARER:
			# The shield lifts and draws back through the windup (held raised: O25), then bashes out at the hit.
			var shield := parts["shield"] as Node3D
			shield.position += Vector3(-_wind * 0.12 + _strike * 0.3, _wind * 0.1, 0)
			shield.rotation.z = _wind * 0.3 - _strike * 0.18
			body.rotation.z += -_strike * 0.05
		WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING:
			# The seam gapes through the windup; the claws lift up and out (held), then chop forward and down.
			var gap := 0.012 + _wind * 0.045 + d * 0.4
			for side: Array in [["half_l", "arm_l", -1.0], ["half_r", "arm_r", 1.0]]:
				var s: float = side[2]
				var half := parts[side[0]] as Node3D
				var arm := parts[side[1]] as Node3D
				half.position.z += gap * s
				half.rotation.x = -s * d * 0.6
				arm.position.z += gap * s
				arm.rotation.x = -s * (_wind * 0.55 - _strike * 0.2)
				arm.rotation.z = _wind * 0.7 - _strike * 0.9
				arm.rotation.y = s * _strike * 0.55
		WorldReader.KIND_MENDER:
			# It floats and sways; the cross over it turns; healing raises its crystals and lights them.
			body.position.y += 0.22 + (0.0 if calm else sin(_t * 2.2) * 0.06)
			if not calm:
				model.rotation.x = sin(_t * 1.3) * 0.05
			(parts["cross"] as Node3D).rotation.y = _t * 2.0
			var lift := 1.0 if _healing else 0.0
			(parts["crystal"] as Node3D).position.y += lift * 0.1
			energy = 1.5 + (2.5 + sin(_t * 9.0) if _healing else 0.0)
	model.scale = Vector3.ONE * _model_scale * (1.0 - 0.35 * d)
	if d > 0.0:
		body.rotation.z += d * 0.7
		body.position.y += d * 0.04 * height  # tips over above the ground (no sinking through it)
	_set_glow(energy * lerpf(0.2, 1.0, _rise) * (1.0 - d))


# --- the six builds -----------------------------------------------------------------------------------------------


func _build_swarmer() -> void:
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.34, 0.14, 0.26), 0.04, 0.03),
		Vector3(0, 0.17, 0),
		_col(&"body")
	)
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.18, 0.1, 0.18), 0.03),
		Vector3(0.2, 0.18, 0),
		_col(&"trim")
	)
	_glow(body, Vector3(0.012, 0.03, 0.12), Vector3(0.295, 0.2, 0))
	var mandible := NeedleAvatar._chamfer_box(Vector3(0.14, 0.03, 0.03), 0.01)
	for k in 2:
		var hinge := Node3D.new()
		hinge.position = Vector3(0.28, 0.15, 0.06 * (1.0 if k == 0 else -1.0))
		body.add_child(hinge)
		_piece(hinge, mandible, Vector3(0.06, 0, 0), BONE)
		parts["mandible%d" % k] = hinge
	var leg := NeedleAvatar._chamfer_box(Vector3(0.03, 0.16, 0.03), 0.008)
	for k in 6:
		var hip := Node3D.new()
		var side := 1.0 if k % 2 == 0 else -1.0
		hip.position = Vector3(0.1 - 0.1 * (k / 2), 0.16, 0.12 * side)
		hip.rotation.x = 0.7 * side
		body.add_child(hip)
		_piece(hip, leg, Vector3(0, -0.08, 0), _col(&"grey"))
		parts["leg%d" % k] = hip


func _build_splitter() -> void:
	var half := ArcCasterAvatar._frustum(0.3, 0.2, 0.72, 6)
	for name in ["left", "right"]:
		var h := Node3D.new()
		body.add_child(h)
		_piece(h, half, Vector3(0, 0.08, 0), _col(&"body" if name == "left" else &"trim"))
		_piece(
			h,
			NeedleAvatar._chamfer_box(Vector3(0.2, 0.12, 0.2), 0.03),
			Vector3(0, 0.82, 0),
			_col(&"grey")
		)
		if EnemyPalettes.eyes_on_all():
			_eye(h, Vector3(0.012, 0.035, 0.1), Vector3(0.105, 0.82, 0))
		parts[name] = h
	_glow(body, Vector3(0.5, 0.62, 0.02), Vector3(0.02, 0.44, 0))
	# v0.8.0 P1 (O26): the claws hang from the shoulders, out to the sides past the body, so a raised claw and its
	# chop read from the iso camera (they were tucked into the body's front).
	var claws := Node3D.new()
	claws.position = Vector3(CLAW_PIVOT.x, CLAW_PIVOT.y, 0)
	body.add_child(claws)
	var claw := NeedleAvatar._chamfer_box(Vector3(0.44, 0.09, 0.09), 0.02)
	for side in [-1.0, 1.0]:
		_piece(claws, claw, Vector3(0.22, 0, CLAW_PIVOT.z * side), _col(&"grey"))
		_piece(
			claws,
			ArcCasterAvatar._octahedron(0.08),
			Vector3(0.47, -0.02, CLAW_PIVOT.z * side),
			BONE
		)
	parts["claws"] = claws


func _build_shield_bearer() -> void:
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.5, 0.62, 0.62), 0.07, 0.03),
		Vector3(-0.05, 0.42, 0),
		_col(&"grey")
	)
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.36, 0.26, 0.4), 0.06, 0.02),
		Vector3(-0.02, 0.86, 0),
		_col(&"body")
	)
	_glow(body, Vector3(0.012, 0.04, 0.24), Vector3(0.165, 0.86, 0))
	for side in [-1.0, 1.0]:
		_piece(
			body,
			NeedleAvatar._chamfer_box(Vector3(0.16, 0.34, 0.14), 0.03),
			Vector3(-0.05, 0.1, 0.18 * side),
			DARK
		)
	var shield := Node3D.new()
	body.add_child(shield)
	_piece(
		shield,
		NeedleAvatar._chamfer_box(Vector3(0.1, 1.0, 1.0), 0.03, 0.02),
		Vector3(0, 0.6, 0),
		GREY_LIGHT
	)
	_piece(
		shield,
		NeedleAvatar._chamfer_box(Vector3(0.06, 0.1, 1.04), 0.02),
		Vector3(0.04, 1.05, 0),
		_col(&"trim")
	)
	_piece(
		shield,
		NeedleAvatar._chamfer_box(Vector3(0.06, 0.6, 0.1), 0.02),
		Vector3(0.04, 0.6, 0),
		_col(&"trim")
	)
	parts["shield"] = shield


func _build_mender() -> void:
	_piece(body, ArcCasterAvatar._frustum(0.32, 0.16, 0.9, 8), Vector3(0, 0.1, 0), _col(&"body"))
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.26, 0.24, 0.26), 0.06, 0.02),
		Vector3(0, 1.1, 0),
		_col(&"trim")
	)
	if EnemyPalettes.eyes_on_all():
		_eye(body, Vector3(0.012, 0.04, 0.16), Vector3(0.135, 1.1, 0))
	for side in [-1.0, 1.0]:
		_piece(
			body,
			NeedleAvatar._chamfer_box(Vector3(0.08, 0.3, 0.08), 0.02),
			Vector3(0.1, 1.0, 0.22 * side),
			_col(&"grey")
		)
	var crystal := MeshInstance3D.new()
	crystal.mesh = _shared_mesh(ArcCasterAvatar._octahedron(0.1))
	crystal.material_override = _glow_mat
	crystal.position = Vector3(0.14, 1.36, 0)
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(crystal)
	_glow_pieces.append(crystal)
	var cross := Node3D.new()
	cross.position = Vector3(0, 1.62, 0)
	body.add_child(cross)
	for size in [Vector3(0.26, 0.07, 0.07), Vector3(0.07, 0.26, 0.07)]:
		var bar := MeshInstance3D.new()
		bar.mesh = _box(size)
		bar.material_override = _glow_mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cross.add_child(bar)
		_glow_pieces.append(bar)
	parts["cross"] = cross


func _build_mine_layer() -> void:
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.7, 0.24, 0.5), 0.06, 0.03),
		Vector3(0, 0.2, 0),
		_col(&"body")
	)
	_piece(body, ArcCasterAvatar._frustum(0.2, 0.1, 0.16, 6), Vector3(0.08, 0.32, 0), _col(&"trim"))
	_glow(body, Vector3(0.012, 0.04, 0.2), Vector3(0.355, 0.24, 0))
	for side in [-1.0, 1.0]:
		_piece(
			body,
			NeedleAvatar._chamfer_box(Vector3(0.72, 0.14, 0.1), 0.03),
			Vector3(0, 0.08, 0.28 * side),
			DARK
		)
	var hopper := Node3D.new()
	hopper.position = Vector3(-0.3, 0.42, 0)
	body.add_child(hopper)
	_piece(
		hopper,
		NeedleAvatar._chamfer_box(Vector3(0.24, 0.12, 0.3), 0.03),
		Vector3.ZERO,
		_col(&"grey")
	)
	var mine := Node3D.new()
	mine.position = Vector3(0, 0.09, 0)
	hopper.add_child(mine)
	_piece(mine, ArcCasterAvatar._frustum(0.12, 0.08, 0.06, 8), Vector3.ZERO, DARK)
	parts["hopper"] = hopper
	parts["mine"] = mine


func _build_sniper() -> void:
	for k in 3:
		var hip := Node3D.new()
		hip.position = Vector3(0, 0.62, 0)
		hip.rotation = Vector3(0, TAU * k / 3.0 + PI / 3.0, 0.45)
		body.add_child(hip)
		_piece(
			hip,
			NeedleAvatar._chamfer_box(Vector3(0.05, 0.7, 0.05), 0.01),
			Vector3(0, -0.33, 0),
			_col(&"grey")
		)
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.36, 0.26, 0.26), 0.05, 0.02),
		Vector3(0, 0.78, 0),
		_col(&"body")
	)
	var barrel := Node3D.new()
	barrel.position = Vector3(0.16, 0.84, 0)
	body.add_child(barrel)
	var tube := NeedleAvatar._prism(0.035, 0.9, 6)
	var along := Node3D.new()
	along.rotation = Vector3(0, PI * 0.5, 0)
	along.position = Vector3(0.45, 0, 0)
	barrel.add_child(along)
	_piece(along, tube, Vector3.ZERO, GREY_LIGHT)
	_piece(
		barrel,
		NeedleAvatar._chamfer_box(Vector3(0.18, 0.08, 0.08), 0.02),
		Vector3(0.02, 0.1, 0),
		_col(&"trim")
	)
	_glow(barrel, Vector3(0.012, 0.05, 0.05), Vector3(0.115, 0.1, 0))
	parts["barrel"] = barrel
	# v0.8.0 TG: the muzzle that charges up through the windup (a small hot gem at the barrel's tip, in the air).
	_muzzle_mat = EnemyLooks.accent(_col(&"eye"), _col(&"eye").lightened(0.3), 0.0)
	var muzzle := MeshInstance3D.new()
	muzzle.name = "Muzzle"
	muzzle.mesh = _shared_mesh(ArcCasterAvatar._octahedron(0.06))
	muzzle.material_override = _muzzle_mat
	muzzle.position = MUZZLE_AT
	muzzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	barrel.add_child(muzzle)
	_muzzle_piece = muzzle
	parts["muzzle"] = muzzle


# --- pieces -------------------------------------------------------------------------------------------------------


## A glowing accent box (an eye, the seam, a scope lens) on the accent material.
func _glow(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _box(size)
	mi.material_override = _glow_mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_glow_pieces.append(mi)


## v0.8.0 EC: a steady eye slit on the eye material (see _eye_mat).
func _eye(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Eye"
	mi.mesh = _box(size)
	mi.material_override = _eye_mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## v0.8.0 EC: this kind's colour in `slot` under the active palette.
func _col(slot: StringName) -> Color:
	return EnemyPalettes.color(kind, slot)


## An outlined, flashable body piece (its material carries the X-ray pass while the technique is xray). v0.8.0 HR:
## the shared mesh and material (it was AvatarBase._outlined: its own material and an X-ray twin node per piece).
func _piece(parent: Node3D, mesh: Mesh, at: Vector3, c: Color) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = _shared_mesh(mesh)
	piece.position = at
	piece.material_override = _body_material(c, null, OUTLINE_M)
	parent.add_child(piece)
	_hit_pieces.append(piece)


## v0.8.0 HR: the one mesh every enemy draws for `mesh`'s shape (the builders make a new one per call).
static func _shared_mesh(mesh: Mesh) -> Mesh:
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var key := (
		"%s/%d/%d/%d" % [mesh.get_class(), mesh.get_surface_count(), verts.size(), hash(verts)]
	)
	if not _meshes.has(key):
		_meshes[key] = mesh
	return _meshes[key]


## v0.8.0 HR: the one box of `size` every enemy draws (the accents and the Mender's cross).
static func _box(size: Vector3) -> BoxMesh:
	var key := "%.4f/%.4f/%.4f" % [size.x, size.y, size.z]
	if not _boxes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_boxes[key] = bm
	return _boxes[key]
