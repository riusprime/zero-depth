# gdlint: disable=max-public-methods, max-file-lines
class_name HordeAvatar
extends AvatarBase
## The six horde kinds, code-built low-poly in the enemy sheet's red and grey (no concept sheet yet; the
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
## +X is the front. every material is EnemyLooks' (shared by every enemy of the
## same look, so a crowd's identical pieces draw instanced) and the meshes are shared too (_shared_mesh); the hit
## flash and the status tints (show_hit, from ActorViews) and the accent's glow (GLOW) are instance uniforms on this
## enemy's own pieces, set only when they change.
## The Swarmer's lane, the Splitter's and Splitling's disc, the Shield Bearer's bash lane and
## the Sniper's line are no longer drawn on the ground; these kinds (TELL_KINDS) read their windup from the body
## (AvatarBase "tell"): a crouch and draw-back that deepens with the windup's progress, the accent (eye, seam, visor,
## scope) brightening and flashing just before the strike, and the Sniper's muzzle charging up at its barrel's tip (in
## the air, never a line on the ground). The facing is the sim's, held through the windup.
## The melee kinds (STRIKE_KINDS)
## raise their strike pose by STRIKE_RAISE_BY of the windup's progress and hold it (AvatarBase.strike_raise): the
## Swarmer's mandibles gape and its body rears, the Splitter's claws lift high and back, the Shield Bearer draws its
## shield back and leans in behind it. At the hit tick (the sim's ACTIVE) the strike snaps out (strike_swing): the
## mandibles bite shut as the body lunges, the claws chop down through the front, the shield slams forward.

## Each kind's main plate (body), its second plate or trim (trim), its limbs and frame (grey) and its eye
## (eye) come from EnemyPalettes; the light grey, dark and bone parts stay neutral.
const GREY_LIGHT := Color("#8A817C")
const DARK := Color("#24272D")
const BONE := Color("#D9CDB8")
## The Mender's heal colour (beam, crystal, cross): pale green, not a reserved role (ART_DIRECTION).
const MEND := Color("#7CF29A")
const SPLITLING_SCALE := 0.62
const HEIGHTS := {
	WorldReader.KIND_SWARMER: 0.36,
	WorldReader.KIND_SPLITTER: 0.95,
	WorldReader.KIND_SHIELD_BEARER: 1.25,
	WorldReader.KIND_MENDER: 1.75,
	WorldReader.KIND_MINE_LAYER: 0.7,
	WorldReader.KIND_SNIPER: 1.3,
}
## The kinds whose windup the body tells (no ground mark); the Mender has no attack and the Mine Layer's
## mines keep theirs.
const TELL_KINDS: Array[int] = [
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SPLITLING,
	WorldReader.KIND_SHIELD_BEARER,
	WorldReader.KIND_SNIPER,
]
## The melee kinds whose strike is a raise-and-hold then a snap.
const STRIKE_KINDS: Array[int] = [
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SPLITLING,
	WorldReader.KIND_SHIELD_BEARER,
]
## The Splitter's claw pivot (x, height) and how far out to each side the claws hang (z).
const CLAW_PIVOT := Vector3(0.1, 0.6, 0.36)
## The owner's models, posed in code: the walk is full at WALK_FULL_MPS (m/s on the ground), a stride
## WALK_HZ a second, the legs swing WALK_SWING (radians); a death lasts DEATH_SECONDS.
## Starting values.
const WALK_FULL_MPS := 2.0
const WALK_HZ := 2.2
const WALK_SWING := 0.3
const DEATH_SECONDS := 0.4
## The Sniper's muzzle glow at full charge (emission energy; 0 when cold), and where it sits on the barrel.
const MUZZLE_ENERGY := 4.0
const MUZZLE_AT := Vector3(0.92, 0, 0)
## The idle bob (radians a second of frame time, metres) and the Swarmer's legs' scuttle (radians a
## second, each leg SWARMER_LEG_PHASE further on, swinging SWARMER_LEG_SWING): named so the VAT bake (VatBake) reads the
## same numbers the pose uses. Unchanged values.
const BOB_RATE := 7.0
const BOB_M := 0.015
const SWARMER_LEG_RATE := 22.0
const SWARMER_LEG_PHASE := 1.7
const SWARMER_LEG_SWING := 0.25
## The Sniper's barrel angle spans [SNIPER_AIM_MIN, SNIPER_AIM_MIN + SNIPER_AIM_SPAN] (radians: the
## windup's -0.04 and the crouch's -0.12 down, the strike's +0.12 up); its VAT grid runs over that span.
const SNIPER_AIM_MIN := -0.16
const SNIPER_AIM_SPAN := 0.28
## The owner's models whose legs walk (the Mender floats).
const MODEL_LEG_KINDS: Array[int] = [
	WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING, WorldReader.KIND_SHIELD_BEARER
]

## The code bodies' meshes, one per shape for every enemy (keyed by their vertices), and the boxes by size.
static var _meshes := {}
static var _boxes := {}

var kind := WorldReader.KIND_SWARMER
## The model's top (for the health bar).
var height := 1.0
## The pivot every part hangs from (the rise-in and the lean), and the kind's moving parts, by name.
var body: Node3D
var parts := {}
## A signature's tell drive (CanyonShoreBodies.read: the beetle's heat, the priest's pulse, 0..1) and
## whether the turtle's shell stands.
var sig_drive := 0.0
var sig_on := true
## The owner's model (null: the code-made body), scaled to the kind's height.
var model: Node3D
## True (set before setup(), ActorViews from
## ViewPrefs.enemy_vat): the body is drawn by a VatCrowd from baked poses, not by nodes. setup() builds no piece and
## _pose() writes no node; the drives the crowd reads (windup_pose, strike_pose, crouch_amount, anim_time, vat_lift,
## glow_energy) are the very numbers the nodes' pose is made of. Only VatCrowd.supports() kinds.
var vat := false

## The glowing accent (eye, seam, crystal, scope): shared (EnemyLooks.accent), its energy this enemy's GLOW.
var _glow_mat: ShaderMaterial
## The Sniper's muzzle (its GLOW from 0).
var _muzzle_mat: ShaderMaterial
## The eye slit the Splitter / Splitling and the Mender get when the palette asks for one on every kind
## (their glow is the seam and the heal crystal), steady.
var _eye_mat: ShaderMaterial
## This enemy's accent pieces (the glow) and muzzle, and the energies last set on them (the body plates
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
## Each part's rest pivot, the walk's phase and pace (0..1, from how fast the node moves on screen), and
## the death (seconds in; -1: alive).
var _rest := {}
var _walk := 0.0
var _walk_t := 0.0
var _last_at := Vector3.INF
var _die_t := -1.0
var _model_scale := 1.0
var _vat_lift := 0.0
## The crouch pose_at() poses at (< 0: none, the windup's own).
var _bake_crouch := -1.0
## The body is the owner's model (set by setup() even when `vat` builds no node).
var _is_model := false
## The VAT kinds past the Swarmer: the body's whole transform in the avatar's space (its pivot's
## place, lean and scale and, on a model, the model's sway and death shrink past its rest scale) and the drives the
## crowd's shader poses the parts at (vat_drives), both from the last _pose().
var _vat_body := Transform3D.IDENTITY
var _vat_d := Vector4.ZERO
## The Ice Crab's slide (0..1 through it; -1: none) and whether it was walking (a stop starts one).
var _slide := -1.0
var _slide_armed := false


static func height_of(p_kind: int) -> float:
	if CritterBodies.is_critter(p_kind):  # v0.11.0 O9
		return float(CritterBodies.HEIGHTS[p_kind])
	if CanyonShoreBodies.is_kind(p_kind):  # v0.11.0 O13c
		return float(CanyonShoreBodies.HEIGHTS[p_kind])
	if p_kind == WorldReader.KIND_SPLITLING:
		return float(HEIGHTS[WorldReader.KIND_SPLITTER]) * SPLITLING_SCALE
	return float(HEIGHTS.get(p_kind, 1.0))


static func is_horde_kind(p_kind: int) -> bool:
	return (
		p_kind == WorldReader.KIND_SPLITLING
		or HEIGHTS.has(p_kind)
		or CritterBodies.is_critter(p_kind)
		or CanyonShoreBodies.is_kind(p_kind)
	)  # R5-R8 # v0.11.0 O9: the horde critters (CritterBodies)


## The owner's model a kind draws with (EnemyModels; the Splitling the Splitter's, smaller), or &"".
static func model_id(p_kind: int) -> StringName:
	match p_kind:
		WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING:
			return &"splitter"
		WorldReader.KIND_SHIELD_BEARER:
			return &"shield_bearer"
		WorldReader.KIND_MENDER:
			return &"mender"
		WorldReader.KIND_LENS_DRONE:  # v0.11.0 S4 (VatCrowd.supports reads it; the Lens Drone is no HordeAvatar)
			return &"lens_drone"
	return &""


## True when the body is the owner's model.
func has_model() -> bool:
	return _is_model


## Starts the death (the owner's model only): the body sinks and tips over DEATH_SECONDS, the Splitter's
## halves fly apart (its two Splitlings are already in the sim). False for the code-made body (it goes at once).
func die() -> bool:
	_touch()
	if not _is_model:
		return false
	_die_t = 0.0
	return true


func dying() -> bool:
	_peek()
	return _die_t >= 0.0


func setup(p_kind: int) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	kind = p_kind
	height = height_of(kind)
	if vat:  # No nodes; the crowd draws the body
		var m := EnemyModels.get_model(model_id(kind))
		_is_model = not m.is_empty()  # The owner's model's numbers, no node
		if _is_model:
			_model_scale = float(m["scale"])
		_pose()
		return
	body = Node3D.new()
	add_child(body)
	var glow := _col(&"eye")
	_eye_mat = EnemyLooks.accent(glow, glow, 1.5)
	if kind in [WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING]:
		glow = ThemePalette.color(&"telegraph_hostile")
	elif kind == WorldReader.KIND_MENDER:
		glow = MEND
	var owner_model := EnemyModels.get_model(model_id(kind))  # The owner's model first
	_glow_mat = EnemyLooks.accent(glow, glow, 1.5)
	if not owner_model.is_empty():
		_build_model(owner_model)
		_is_model = true
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
			_ when CritterBodies.is_critter(kind):  # v0.11.0 O9
				CritterBodies.build(self)
			_ when CanyonShoreBodies.is_kind(kind):  # v0.11.0 O13c
				CanyonShoreBodies.build(self)
	_pose()


## The values straight to _apply (no Dictionary per enemy per sync).
func sync(reader: WorldReader, i: int) -> void:
	if CanyonShoreBodies.is_kind(kind):  # Its tell's drive (heat, pulse, shell)
		CanyonShoreBodies.read(self, reader, i)
	_apply(
		reader.tick(),
		reader.actor_state(i),
		reader.actor_heal_target(i) >= 0,
		windup_progress(reader, i),
	)


## The same as sync(), from plain values (tests drive the avatar with this); "windup" (0..1, optional) is the
## windup's progress.
func apply_state(s: Dictionary) -> void:
	_apply(
		int(s["tick"]), int(s["state"]), bool(s.get("healing", false)), float(s.get("windup", 0.0))
	)


func _apply(tick: int, state: int, healing: bool, windup: float) -> void:
	_touch()
	_healing = healing
	_tell_p = clampf(windup, 0.0, 1.0)
	if _fresh or state != _state:
		_state = state
		_state_tick = tick
	_ticks_in = tick - _state_tick
	strike_note(state)  # The hit tick starts the strike
	if _fresh:
		_fresh = false
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_pose()


func advance(delta: float) -> void:
	_touch()
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or (body == null and not vat):
		return
	_t += dt
	if _die_t >= 0.0:
		_die_t += dt
	# The walk's pace from how fast the body moves (the critters' too: the crab's slide)
	if (_is_model or CritterBodies.is_critter(kind)) and (is_inside_tree() or detached):
		var at := _view_position()
		var speed := (
			0.0
			if _last_at == Vector3.INF
			else Vector2(at.x - _last_at.x, at.z - _last_at.z).length() / dt
		)
		_last_at = at
		_walk = move_toward(_walk, clampf(speed / WALK_FULL_MPS, 0.0, 1.0), dt * 4.0)
		_walk_t += dt * lerpf(0.0, WALK_HZ * TAU, _walk)
		_slide_step(dt)
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.5))
	var winding := _state == WorldReader.STATE_WINDUP
	strike_advance(dt)
	if STRIKE_KINDS.has(kind):
		# Raised from the windup's progress and held; the strike snaps out at the hit tick.
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
	_peek()
	return _wind


## 0..1 how far its strike is out (tests).
func strike_pose() -> float:
	_peek()
	return _strike


## The accent's glow (tests): the eye, seam, crystal or scope.
func glow_energy() -> float:
	_peek()
	return _glow_e


## 0..1 how deep the windup crouch is (0 for a kind without a tell or outside the windup).
func crouch_amount() -> float:
	_peek()
	if _bake_crouch >= 0.0:
		return _bake_crouch
	if not TELL_KINDS.has(kind) or _state != WorldReader.STATE_WINDUP:
		return 0.0
	return tell_crouch(_tell_p)


## The Sniper's muzzle glow (0 when cold; always 0 for the other kinds).
func muzzle_energy() -> float:
	_peek()
	return _muzzle_e if kind == WorldReader.KIND_SNIPER else 0.0


## The frame-time clock the pose runs on (seconds; the VAT crowd reads the legs' phase from it).
func anim_time() -> float:
	_peek()
	return _t


## How far the whole body is lifted now (m, the idle bob and the rise-in's sink): the part of the
## body's pose the VAT crowd moves the instance by (VatBake bakes the rest at no bob, fully risen).
func vat_lift() -> float:
	_peek()
	return _vat_lift


## VatBake: poses the body straight from its drives (the windup raise `wind`, the strike `strike`,
## the crouch, the clock `t`, the rise-in `rise`), as advance() would have left them, so the bake runs this very pose
## code over a grid of them. Tools and tests only; the game never calls it.
func pose_at(wind: float, strike: float, crouch: float, t: float, rise: float) -> void:
	_wind = wind
	_strike = strike
	_bake_crouch = crouch
	_t = t
	_rise = rise
	_pose()
	_bake_crouch = -1.0


func _pose() -> void:
	var calm := ViewPrefs.reduced_motion
	var bob := 0.0 if calm else sin(_t * BOB_RATE) * BOB_M
	var crouch := crouch_amount()
	var telling := TELL_KINDS.has(kind) and _state == WorldReader.STATE_WINDUP
	var tell := tell_glow(_tell_p, _t, calm) if telling else 1.0
	var energy := (1.5 + _wind * 3.0) * tell + _strike * 2.0
	if vat and kind == WorldReader.KIND_SWARMER:  # The crowd draws the body; its numbers only
		_vat_lift = bob - (1.0 - _rise) * height
		_set_glow(energy * lerpf(0.2, 1.0, _rise))
		return
	# The crouch sinks the body by a share of its height and draws it back from the way it will strike.
	# (the body's place `bp` and lean `brz` are reckoned first and set once, _place_body: on its
	# node, or as the VAT crowd's instance transform.)
	var bp := Vector3(
		-_wind * 0.06 - crouch * 0.08 * height + _strike * 0.12,
		bob - (1.0 - _rise) * height - crouch * 0.1 * height,
		0
	)
	var brz := crouch * 0.12
	if CritterBodies.is_critter(kind):  # The body's own move, then the gait's parts
		var mv := CritterBodies.body_move(kind, _t, _slide, calm)
		_place_body(bp + (mv[0] as Vector3), brz + float(mv[1]))
		_pose_parts(Vector4(0, 0, 0, CritterBodies.phase_at(kind, _t)))
		_set_glow(energy * lerpf(0.2, 1.0, _rise))
		return
	if _is_model:  # The owner's model's parts
		_pose_model(energy, calm, bp, brz)
		return
	match kind:
		WorldReader.KIND_SWARMER:
			# Rears up with the mandibles gaping, then lunges and bites them shut.
			brz += _wind * 0.25 - _strike * 0.2
			bp.x += _strike * 0.08
			for k in 2:
				var m: Node3D = parts["mandible%d" % k]
				m.rotation.y = (0.15 + _wind * 0.85 - _strike * 0.75) * (1.0 if k == 0 else -1.0)
			for k in 6:
				var leg: Node3D = parts["leg%d" % k]
				leg.rotation.z = (
					sin(_t * SWARMER_LEG_RATE + k * SWARMER_LEG_PHASE) * SWARMER_LEG_SWING
				)
		WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING:
			var gap := 0.03 + _wind * 0.08 + sin(_t * 3.0) * 0.01
			(parts["left"] as Node3D).position.z = -gap
			(parts["right"] as Node3D).position.z = gap
			# The claws lift high and back over the body, then chop down through the front.
			var claws := parts["claws"] as Node3D
			claws.rotation.z = _wind * 1.1 - _strike * 0.85
			claws.position.x = CLAW_PIVOT.x - _wind * 0.06 + _strike * 0.14
			brz += _wind * 0.1 - _strike * 0.16
		WorldReader.KIND_SHIELD_BEARER:
			# The shield draws back and tips up, the body leans in behind it; then the shield slams out.
			var shield := parts["shield"] as Node3D
			shield.position.x = 0.5 - _wind * 0.24 + _strike * 0.38
			shield.rotation.z = _wind * 0.22 - _strike * 0.12
			brz += -_wind * 0.06 - _strike * 0.12
		WorldReader.KIND_MENDER:
			bp.y += 0.18 + sin(_t * 2.2) * 0.06
			(parts["cross"] as Node3D).rotation.y = _t * 2.0
			energy = 1.5 + (2.5 + sin(_t * 9.0) if _healing else 0.0)
		WorldReader.KIND_MINE_LAYER:
			# The drives (the windup, the mine shown) through _pose_parts, as the VAT bake poses it.
			_pose_parts(Vector4(_wind, 1.0 if _strike < 0.5 else 0.0, 0.0, 0.0))
		WorldReader.KIND_SNIPER:
			var charge := smoothstep(0.0, 1.0, _tell_p) if telling else 0.0
			var muzzle := MUZZLE_ENERGY * charge * tell / (1.0 + TELL_GLOW_CLIMB + TELL_GLOW_FLASH)
			_set_muzzle(maxf(muzzle, _strike * MUZZLE_ENERGY))
			# The drives (the barrel's angle, the muzzle's size) through _pose_parts.
			_pose_parts(
				Vector4(
					-_wind * 0.04 + _strike * 0.12 - crouch * 0.12,
					0.4 + 0.6 * maxf(charge, _strike),
					0.0,
					0.0
				)
			)
		_ when CanyonShoreBodies.is_kind(kind):  # v0.11.0 O13c
			energy = CanyonShoreBodies.pose(self, energy, calm)
	_place_body(bp, brz)
	_set_glow(energy * lerpf(0.2, 1.0, _rise))


## Sets the body's place `bp` and lean `brz` and, on the owner's model, its sway `mrx` and death
## shrink `ms` (x its rest scale) on the nodes; a VAT avatar keeps them as one transform for its crowd (vat_offset).
func _place_body(bp: Vector3, brz: float, mrx := 0.0, ms := 1.0) -> void:
	if not vat:
		body.position = bp
		body.rotation.z = brz
		if model != null:
			model.rotation = Vector3(mrx, 0, 0)
			model.scale = Vector3.ONE * _model_scale * ms
		return
	var bs := SPLITLING_SCALE if kind == WorldReader.KIND_SPLITLING else 1.0
	var xf := Transform3D(
		Basis.from_euler(Vector3(0, 0, brz)) * Basis.from_scale(Vector3.ONE * bs), bp
	)
	if _is_model:
		xf = (
			xf
			* Transform3D(
				Basis.from_euler(Vector3(mrx, 0, 0)) * Basis.from_scale(Vector3.ONE * ms),
				Vector3.ZERO
			)
		)
	_vat_body = xf


## The moving parts of the kinds past the Swarmer, posed from their drives `d` (natural units):
## - the owner's models: the windup raise x, the strike y, the death z (the Splitter's), the legs' swing w (-1..1, x
##   WALK_SWING); the Mender's: the crystal raised x (0 / 1) and the cross's turn w (radians);
## - the Mine Layer: the windup x (the hopper lowers), the mine shown y (0 / 1);
## - the Sniper: the barrel's angle x (radians), the muzzle's size y.
## The live pose (_pose) and the VAT bake (vat_bake_pose) both pose through here; a VAT avatar keeps `d` in its grid's
## units (vat_drives) instead.
func _pose_parts(d: Vector4) -> void:
	if vat:
		_vat_d = HordeVat.grid_of(self, d)
		return
	if CritterBodies.is_critter(kind):  # v0.11.0 O9
		CritterBodies.pose_parts(self, d.w)
		return
	if model != null:
		for pname: String in parts:
			var n := parts[pname] as Node3D
			n.position = _rest[pname]
			n.rotation = Vector3.ZERO
		if MODEL_LEG_KINDS.has(kind):
			(parts["leg_l"] as Node3D).rotation.z = d.w * WALK_SWING
			(parts["leg_r"] as Node3D).rotation.z = -d.w * WALK_SWING
	match kind:
		WorldReader.KIND_SHIELD_BEARER:
			# The shield lifts and draws back through the windup (held raised: O25), then bashes out at the hit.
			var shield := parts["shield"] as Node3D
			shield.position += Vector3(-d.x * 0.12 + d.y * 0.3, d.x * 0.1, 0)
			shield.rotation.z = d.x * 0.3 - d.y * 0.18
		WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING:
			# The seam gapes through the windup; the claws lift up and out (held), then chop forward and down.
			var gap := 0.012 + d.x * 0.045 + d.z * 0.4
			for side: Array in [["half_l", "arm_l", -1.0], ["half_r", "arm_r", 1.0]]:
				var s: float = side[2]
				var half := parts[side[0]] as Node3D
				var arm := parts[side[1]] as Node3D
				half.position.z += gap * s
				half.rotation.x = -s * d.z * 0.6
				arm.position.z += gap * s
				arm.rotation.x = -s * (d.x * 0.55 - d.y * 0.2)
				arm.rotation.z = d.x * 0.7 - d.y * 0.9
				arm.rotation.y = s * d.y * 0.55
		WorldReader.KIND_MENDER:
			# The cross over it turns; healing raises its crystals.
			(parts["cross"] as Node3D).rotation.y = d.w
			(parts["crystal"] as Node3D).position.y += d.x * 0.1
		WorldReader.KIND_MINE_LAYER:
			(parts["hopper"] as Node3D).position.y = 0.42 - d.x * 0.25
			(parts["mine"] as Node3D).visible = d.y > 0.5
		WorldReader.KIND_SNIPER:
			(parts["barrel"] as Node3D).rotation.z = d.x
			(parts["muzzle"] as Node3D).scale = Vector3.ONE * d.y


## The hit flash and the accent glow are each written to a list of pieces (RigMerge swaps merged
## pieces in them).
## The Sniper's muzzle has a glow value of its own (_set_muzzle), so it stays a node of its own.
func rig_spec() -> Dictionary:
	var keep: Array[Node] = []
	if _muzzle_piece != null:
		keep.append(_muzzle_piece)
	return {"keep": keep, "sets": [_hit_pieces, _glow_pieces]}


## The accent's energy on this enemy's accent pieces, set only when it changes.
func _set_glow(e: float) -> void:
	if e == _glow_e:
		return
	_glow_e = e
	for piece in _glow_pieces:
		piece.set_instance_shader_parameter(EnemyLooks.GLOW, e)


func _set_muzzle(e: float) -> void:
	if e == _muzzle_e:
		return
	_muzzle_e = e
	if _muzzle_piece != null:  # (a VAT Sniper has none; the crowd reads muzzle_energy)
		_muzzle_piece.set_instance_shader_parameter(EnemyLooks.GLOW, e)


# --- v0.8.0 MI: the owner's models ----------------------------------------------------------------------------------


## The owner's model (EnemyModels.get_model): each part a node at its pivot, its surfaces on three materials: the
## frame as delivered (`base`), the plates in the kind's role colour (`role`: greyscale in the texture, times
## _col(&"body")), the accents on the glowing accent material (`glow`). Both body materials take the hit flash and
## the biome's tint and role glow like the code bodies' plates (they were the "enemy_tex" materials); no drawn
## outline (owner v0.7.5 on his models: the stroke is ugly).
func _build_model(m: Dictionary) -> void:
	var tex: Texture2D = m["texture"]
	var base := _body_material(Color.WHITE, tex)
	var role := _body_material(_col(&"body"), tex)
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


## The shared body material for a plate of colour `c` (times `tex`, the owner's colour map, when given),
## AvatarBase.shared_body: the biome's cast and the role glow picked in.
func _body_material(c: Color, tex: Texture2D) -> ShaderMaterial:
	return shared_body(kind, c, tex)


## The model's parts in this frame's pose (model units, about a metre each; +X the front, each part turning
## about its own pivot). What drives each move is the same as the code body's: the windup's raise-and-hold (_wind),
## the strike's snap (_strike), the Mender's heal, the walk's pace (_walk) and the death (_die_t).
## (the body's moves are reckoned into `bp` / `brz` and the model's sway and shrink, set by
## _place_body; the parts' through _pose_parts: the same arithmetic as before, split so the VAT bake poses the parts.)
func _pose_model(energy: float, calm: bool, bp: Vector3, brz: float) -> void:
	var d := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0) if _die_t >= 0.0 else 0.0
	var mrx := 0.0
	var drives := Vector4(_wind, _strike, 0.0, sin(_walk_t) * _walk)
	if MODEL_LEG_KINDS.has(kind):
		bp.y += absf(sin(_walk_t)) * 0.025 * _walk
	match kind:
		WorldReader.KIND_SHIELD_BEARER:
			brz += -_strike * 0.05
		WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING:
			drives.z = d  # the halves fly apart as it dies
		WorldReader.KIND_MENDER:
			# It floats and sways; the cross over it turns; healing raises its crystals and lights them.
			bp.y += 0.22 + (0.0 if calm else sin(_t * 2.2) * 0.06)
			if not calm:
				mrx = sin(_t * 1.3) * 0.05
			drives = Vector4(1.0 if _healing else 0.0, 0.0, 0.0, _t * 2.0)
			energy = 1.5 + (2.5 + sin(_t * 9.0) if _healing else 0.0)
	if d > 0.0:
		brz += d * 0.7
		bp.y += d * 0.04 * height  # tips over above the ground (no sinking through it)
	_place_body(bp, brz, mrx, 1.0 - 0.35 * d)
	_pose_parts(drives)
	_set_glow(energy * lerpf(0.2, 1.0, _rise) * (1.0 - d))


# --- v0.10.5 W3-V4b: the VAT kinds past the Swarmer (HordeVat, VatBake, VatCrowd) ---------------------------------


## VatBake: poses the parts at stance grid point `u` and gait phase `phase` (0..1) through the same code as the live
## pose (the body's own moves are the crowd's instance transform, vat_offset, so the model stays at its rest scale).
## The Swarmer: pose_at, as the pilot baked it. Tools only (built with its pieces).
func vat_bake_pose(u: Vector3, phase: float) -> void:
	if kind == WorldReader.KIND_SWARMER:
		pose_at(u.x, u.y, u.z, VatBake.gait_period(kind) * phase, 1.0)
		return
	_pose_parts(HordeVat.natural(kind, u, phase))
	if model != null:
		model.transform = Transform3D(Basis.from_scale(Vector3.ONE * _model_scale), Vector3.ZERO)


## VatBake.drives_of (the kinds past the Swarmer; the Swarmer's are VatBake's own): the four drives this instance's
## shader poses it at (HordeVat: the stance grid's x, y, z, the gait's w), from the last _pose().
func vat_grid_drives() -> PackedFloat32Array:
	_peek()
	return PackedFloat32Array([_vat_d.x, _vat_d.y, _vat_d.z, _vat_d.w])


## VatCrowd: the body's transform in the avatar's space past the baked pose (the Swarmer's: its lift).
func vat_offset() -> Transform3D:
	_peek()
	if kind == WorldReader.KIND_SWARMER:
		return Transform3D(Basis.IDENTITY, Vector3(0, _vat_lift, 0))
	return _vat_body


## Tools and tests (VatVerify.pose_error_full, HordeVat.sample): poses from every input at once, as advance() would
## have left them: {wind, strike, crouch, t, rise, die (s into the death, < 0 alive), walk, walk_t, healing, tell,
## winding}.
func pose_with(s: Dictionary) -> void:
	_wind = s["wind"]
	_strike = s["strike"]
	_bake_crouch = s["crouch"]
	_t = s["t"]
	_rise = s["rise"]
	_die_t = s["die"]
	_walk = s["walk"]
	_walk_t = s["walk_t"]
	_healing = s["healing"]
	_tell_p = s["tell"]
	_state = WorldReader.STATE_WINDUP if s["winding"] else WorldReader.STATE_MOVE
	_pose()
	_bake_crouch = -1.0


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
	# The claws hang from the shoulders, out to the sides past the body, so a raised claw and its
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
	# The muzzle that charges up through the windup (a small hot gem at the barrel's tip, in the air).
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


## A steady eye slit on the eye material (see _eye_mat).
func _eye(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Eye"
	mi.mesh = _box(size)
	mi.material_override = _eye_mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## This kind's colour in `slot` under the active palette.
func _col(slot: StringName) -> Color:
	if CritterBodies.is_critter(kind):  # A critter wears its biome's colours, not a role's
		return CritterBodies.color(kind, slot)
	if CanyonShoreBodies.is_kind(kind):  # The prompts' role colours
		return CanyonShoreBodies.color(kind, slot)
	return EnemyPalettes.color(kind, slot)


## A flashable body piece. the shared mesh and material (it was its own material per piece).
func _piece(parent: Node3D, mesh: Mesh, at: Vector3, c: Color) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = _shared_mesh(mesh)
	piece.position = at
	piece.material_override = _body_material(c, null)
	parent.add_child(piece)
	_hit_pieces.append(piece)


## The one mesh every enemy draws for `mesh`'s shape (the builders make a new one per call).
static func _shared_mesh(mesh: Mesh) -> Mesh:
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var key := (
		"%s/%d/%d/%d" % [mesh.get_class(), mesh.get_surface_count(), verts.size(), hash(verts)]
	)
	if not _meshes.has(key):
		_meshes[key] = mesh
	return _meshes[key]


## The one box of `size` every enemy draws (the accents and the Mender's cross).
static func _box(size: Vector3) -> BoxMesh:
	var key := "%.4f/%.4f/%.4f" % [size.x, size.y, size.z]
	if not _boxes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_boxes[key] = bm
	return _boxes[key]


## ENEMIES.md H4: the Ice Crab slides a little when it stops (a full walk, then nearly none, starts the
## slide; CritterBodies.body_move draws it). The other kinds never slide.
func _slide_step(dt: float) -> void:
	if kind != WorldReader.KIND_ICE_CRAB:
		return
	if _walk > 0.6:
		_slide_armed = true
	elif _slide_armed and _walk < 0.25:
		_slide_armed = false
		_slide = 0.0
	if _slide >= 0.0:
		_slide += dt / CritterBodies.SLIDE_SECONDS
		if _slide > 1.0:
			_slide = -1.0
