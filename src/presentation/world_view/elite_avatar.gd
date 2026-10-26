class_name EliteAvatar
extends AvatarBase
## v0.9.0 EL (owner Q26; ELITES.md E1-E3; art list §3.1): the three elites, drawn with the owner's models
## (assets/models/enemies/elite_*.glb, cut into parts by scripts/assets/mi2_prep.py: the owner, "enemies are not
## animated, you will have to do it manually") and posed here in frame time from the sim's state (EI-07: it reads,
## never writes). Each part turns about its own pivot (+X the front, Y up). The surfaces are `base` (as delivered) and
## `glow` (eyes, runes, crystals: the elite's accent, which carries the tells).
## - The Breaker: walks heavily (legs, a sway); its Ground Slam raises the huge right fist overhead through the windup
##   (held up, glowing hotter), slams it down at the hit, and holds it in the ground, leaning in, through the stuck
##   window (the accent dims and pulses: open to hits). Its punch draws the fist back, then snaps it out.
## - The Rift Hunter: a predatory crouch, the shards turning over its shoulders; through the Rift Step's windup it
##   crouches lower with both blades drawn back, is gone for the vanish (no body), reappears blades swept through, and
##   stands still for its pause.
## - The Conduit: floats and bobs, its ring turning round its chest; through the Charged Beam's windup it lifts the
##   staff toward you, the ring spins up and the runes brighten; on the shot the staff kicks; then it drops to the floor
##   for the overload, tilted, the ring slowed, the runes flickering. Its orb fan lifts the staff a little.
## A missing model file gives a code-made stand-in (L15: a box body and a glowing accent) so the game still runs.

const HEIGHTS := {
	WorldReader.KIND_BREAKER: 2.6,
	WorldReader.KIND_RIFT_HUNTER: 2.1,
	WorldReader.KIND_CONDUIT: 2.3,
}
const MODEL_IDS := {
	WorldReader.KIND_BREAKER: &"elite_breaker",
	WorldReader.KIND_RIFT_HUNTER: &"elite_rift_hunter",
	WorldReader.KIND_CONDUIT: &"elite_conduit",
}
## Each elite's accent (ELITES.md: bronze and gold, dark violet and gold, pale teal and gold): the glow's colour.
const ACCENTS := {
	WorldReader.KIND_BREAKER: Color("#F2C14E"),
	WorldReader.KIND_RIFT_HUNTER: Color("#B98CFF"),
	WorldReader.KIND_CONDUIT: Color("#7FF2E0"),
}
## The walk (as HordeAvatar's): full at WALK_FULL_MPS, WALK_HZ strides a second, the legs swing WALK_SWING.
const WALK_FULL_MPS := 1.6
const WALK_HZ := 1.6
const WALK_SWING := 0.32
## The Conduit floats this high (m) while it isn't overloaded.
const FLOAT_M := 0.3
const DEATH_SECONDS := 0.6

var kind := WorldReader.KIND_BREAKER
var height := 2.6
var body: Node3D
var model: Node3D
var parts := {}
var _rest := {}
var _glow_mat: ShaderMaterial
var _glow_pieces: Array[GeometryInstance3D] = []
var _glow_e := -1.0
var _outline := Color.BLACK
var _technique := &"outline"
var _state := WorldReader.STATE_SPAWN
var _pick := WorldReader.ELITE_BASIC
var _progress := 0.0
var _vanished := false
var _vulnerable := false
var _rise := 0.0
## Frame-time poses, 0..1: the windup's raise, the strike's snap, the punish window's slump, the float.
var _raise := 0.0
var _snap := 0.0
var _slump := 0.0
var _float := 1.0
var _walk := 0.0
var _walk_t := 0.0
var _last_at := Vector3.INF
var _die_t := -1.0
var _model_scale := 1.0


static func is_elite_kind(p_kind: int) -> bool:
	return HEIGHTS.has(p_kind)


func has_model() -> bool:
	return model != null


func setup(p_kind: int, outline_color: Color, technique: StringName = &"outline") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	kind = p_kind
	_outline = outline_color
	_technique = technique
	height = float(HEIGHTS.get(kind, 2.4))
	body = Node3D.new()
	add_child(body)
	var owner_model := EnemyModels.get_model(MODEL_IDS.get(kind, &""))
	var accent: Color = ACCENTS.get(kind, Color.WHITE)
	_glow_mat = EnemyLooks.accent(accent, accent, 1.5)
	if owner_model.is_empty():
		_build_stand_in(accent)
	else:
		_build_model(owner_model)
	_pose()


func die() -> bool:
	if body == null:
		return false
	_die_t = 0.0
	return true


func dying() -> bool:
	return _die_t >= 0.0


func sync(reader: WorldReader, i: int) -> void:
	apply_state(
		{
			"tick": reader.tick(),
			"state": reader.actor_state(i),
			"pick": reader.elite_attack(i),
			"windup": windup_progress(reader, i),
			"vanished": reader.elite_vanished(i),
			"vulnerable": reader.elite_vulnerable(i),
		}
	)


## The same as sync() from plain values (tests drive the avatar with this).
func apply_state(s: Dictionary) -> void:
	_state = int(s["state"])
	_pick = int(s.get("pick", WorldReader.ELITE_BASIC))
	_progress = clampf(float(s.get("windup", 0.0)), 0.0, 1.0)
	_vanished = bool(s.get("vanished", false))
	_vulnerable = bool(s.get("vulnerable", false))
	strike_note(_state)
	if _fresh:
		_fresh = false
		_rise = 0.0 if _state == WorldReader.STATE_SPAWN else 1.0
		_pose()


func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or body == null:
		return
	_t += dt
	if _die_t >= 0.0:
		_die_t += dt
	if is_inside_tree():
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
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (4.0 if spawning else 1.6))
	var ability := _pick == WorldReader.ELITE_ABILITY
	var winding := _state == WorldReader.STATE_WINDUP
	strike_advance(dt)
	# The raise follows the windup's progress (the sim's telegraph, not a timer), held up to the hit.
	_raise = strike_raised(winding, _progress, move_toward(_raise, 0.0, dt * 3.0))
	_snap = strike_swing()
	var window := _state == WorldReader.STATE_RECOVER and ability
	_slump = move_toward(_slump, 1.0 if window else 0.0, dt * (8.0 if window else 2.5))
	var grounded := kind == WorldReader.KIND_CONDUIT and window
	_float = move_toward(_float, 0.0 if grounded else 1.0, dt * (6.0 if grounded else 1.5))
	_pose()


## 0..1 how far the windup pose is raised (tests).
func raise_pose() -> float:
	return _raise


## 0..1 how far it has slumped into its punish window (tests).
func slump_pose() -> float:
	return _slump


## The accent's glow now (tests).
func glow_energy() -> float:
	return _glow_e


func _pose() -> void:
	if body == null:
		return
	var calm := ViewPrefs.reduced_motion
	var d := clampf(_die_t / DEATH_SECONDS, 0.0, 1.0) if _die_t >= 0.0 else 0.0
	visible = not _vanished
	body.position = Vector3(0, -(1.0 - _rise) * height * 0.6, 0)
	body.rotation = Vector3.ZERO
	var ability := _pick == WorldReader.ELITE_ABILITY
	var energy := 1.5 + _raise * (3.0 if ability else 1.5) + _snap * 2.0
	if _vulnerable:  # the punish window: the accent dims and pulses (steady with reduced motion)
		energy = 0.6 + (0.0 if calm else 0.5 * absf(sin(_t * 6.0)))
	if model != null:
		_pose_model(ability, calm)
	else:
		body.rotation.z = -_raise * 0.15 + _snap * 0.2 + _slump * 0.25
		if kind == WorldReader.KIND_CONDUIT:
			body.position.y += FLOAT_M * _float
	if d > 0.0:
		body.rotation.z += d * 1.2
		body.position.y += d * 0.05 * height
		body.scale = Vector3.ONE * (1.0 - 0.3 * d)
	_set_glow(energy * lerpf(0.2, 1.0, _rise) * (1.0 - d))


func _pose_model(ability: bool, calm: bool) -> void:
	for pname: String in parts:
		var n := parts[pname] as Node3D
		n.position = _rest[pname]
		n.rotation = Vector3.ZERO
	var swing := sin(_walk_t) * WALK_SWING * _walk
	if parts.has("leg_l"):
		(parts["leg_l"] as Node3D).rotation.z = swing
		(parts["leg_r"] as Node3D).rotation.z = -swing
		body.position.y += absf(sin(_walk_t)) * 0.03 * _walk
	match kind:
		WorldReader.KIND_BREAKER:
			var arm := parts.get("arm_r") as Node3D
			if ability:
				# Up overhead through the windup (held), down into the ground at the hit, held there while stuck.
				body.rotation.z = -_raise * 0.12 + _snap * 0.22 + _slump * 0.28
				if arm != null:
					arm.rotation.z = _raise * 2.5 - _snap * 2.9 - _slump * 0.35
			elif arm != null:
				arm.rotation.z = -_raise * 0.6 + _snap * 1.3
				arm.position.x += -_raise * 0.12 + _snap * 0.25
			if parts.has("arm_l"):
				(parts["arm_l"] as Node3D).rotation.z = -swing * 0.5 + _raise * 0.3
			if not calm and _walk > 0.0:
				body.rotation.x = sin(_walk_t) * 0.04 * _walk
		WorldReader.KIND_RIFT_HUNTER:
			var crouch := _raise if ability else 0.0
			body.position.y -= crouch * 0.18
			body.rotation.z = crouch * 0.2 - _snap * 0.25
			for side: Array in [["blade_r", 1.0], ["blade_l", -1.0]]:
				if parts.has(side[0]):
					var b := parts[side[0]] as Node3D
					b.rotation.z = crouch * 1.1 - _snap * 1.6
					b.rotation.x = float(side[1]) * (crouch * 0.4 + _snap * 0.6)
			if parts.has("shards"):
				(parts["shards"] as Node3D).rotation.y = _t * (0.8 if calm else 1.6)
				(parts["shards"] as Node3D).position.y += 0.0 if calm else sin(_t * 2.0) * 0.03
		WorldReader.KIND_CONDUIT:
			var bob := 0.0 if calm else sin(_t * 1.8) * 0.06
			body.position.y += (FLOAT_M + bob) * _float
			body.rotation.z = _slump * 0.35 + _snap * -0.12
			body.rotation.x = _slump * 0.15
			if parts.has("staff"):
				(parts["staff"] as Node3D).rotation.z = (
					-_raise * (1.0 if ability else 0.45) + _snap * 0.4
				)
			if parts.has("ring"):
				var spin := 0.7 + _raise * 6.0 - _slump * 0.6
				(parts["ring"] as Node3D).rotation.y = _t * spin
			if parts.has("shards"):
				(parts["shards"] as Node3D).rotation.y = -_t * 0.9


func _set_glow(e: float) -> void:
	if e == _glow_e:
		return
	_glow_e = e
	for piece in _glow_pieces:
		piece.set_instance_shader_parameter(EnemyLooks.GLOW, e)


## The owner's model (EnemyModels.get_model): each part a node at its pivot, `base` on the shared body material (the
## hit flash and the biome's cast), `glow` on the accent.
func _build_model(m: Dictionary) -> void:
	var base := shared_body(kind, Color.WHITE, m["texture"], _outline, 0.0)
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
		mi.extra_cull_margin = 1.0  # poses move parts past the rest bounds
		# The owner (2026-10-23): "Dont put the yellow strokes on elites, it looks ugly, show the model as is": every
		# surface, the bright accents too, keeps the model's own texture (no gold glow material over them).
		var surfaces: Array = part["surfaces"]
		for s in surfaces.size():
			mi.set_surface_override_material(s, base)
		pivot.add_child(mi)
		_hit_pieces.append(mi)
		parts[String(pname)] = pivot
		_rest[String(pname)] = pivot.position


## L15: without the model file, a box body of the elite's height and a glowing accent band.
func _build_stand_in(accent: Color) -> void:
	var w := height * 0.4
	var box := BoxMesh.new()
	box.size = Vector3(w, height, w)
	var piece := MeshInstance3D.new()
	piece.mesh = box
	piece.position = Vector3(0, height * 0.5, 0)
	piece.material_override = shared_body(kind, accent.darkened(0.6), null, _outline, 0.02)
	body.add_child(piece)
	_hit_pieces.append(piece)
	var band := BoxMesh.new()
	band.size = Vector3(w * 1.05, height * 0.08, w * 1.05)
	var glow := MeshInstance3D.new()
	glow.mesh = band
	glow.position = Vector3(0, height * 0.8, 0)
	glow.material_override = _glow_mat
	body.add_child(glow)
	_glow_pieces.append(glow)
