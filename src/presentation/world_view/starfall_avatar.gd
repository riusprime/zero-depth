class_name StarfallAvatar
extends AvatarBase
## ENEMIES.md R9; OWNER_TODO §3.2 holds the prompt for the owner's model: the Star Warper's code-made stand-in body,
## in the Charger family's style (faceted, flat-lit blocks with one glowing accent):
## - Star Warper: a lean hooded crawler in violet with two blade arms and a pale-gold star on its chest; through
##   its windup the star flares and it crouches; at the blink it snaps upright; stunned, it reels (a slow wobble) with
##   its star dim.
## (The Gravity Node is on the owner's model: GravityNodeAvatar.)
## Its colours are its own (COLORS, not EnemyPalettes' roles: a signature is its biome's). Presentation only
## (EI-07): sync() reads the sim through WorldReader once per tick, advance() animates in frame time.

const KINDS: Array[int] = [WorldReader.KIND_STAR_WARPER]
## The body's top (m, for the health bar).
const HEIGHTS := {
	WorldReader.KIND_STAR_WARPER: 1.15,
}
## [body, trim, grey, accent] per kind (starting values): the role colour OWNER_TODO §3.2 gives its prompt (the Arc
## Caster's violet), a charcoal trim, grey limbs.
const COLORS := {
	WorldReader.KIND_STAR_WARPER: ["#8A50D8", "#2E2A34", "#6E6A74", "#FFE6A0"],
}

var kind := WorldReader.KIND_STAR_WARPER
var height := 1.0
var body: Node3D
var _parts: BossParts
var _accent: StandardMaterial3D
var _state := WorldReader.STATE_SPAWN
var _wind := 0.0
var _stun := false
var _reel := 0.0
var _snap := 0.0
var _rise := 0.0


static func takes(p_kind: int) -> bool:
	return KINDS.has(p_kind)


static func height_of(p_kind: int) -> float:
	return float(HEIGHTS.get(p_kind, 1.0))


static func color(p_kind: int, k: int) -> Color:
	var row: Array = COLORS.get(p_kind, [])
	return Color(String(row[k])) if k < row.size() else ThemePalette.UNKNOWN


## ActorViews._make_actor: a body of `p_kind` under the actor's `facing` (the root's enemy_avatar and mats metas set);
## returns its height (the health bar's).
static func make(root: Node3D, facing: Node3D, p_kind: int) -> float:
	var a := StarfallAvatar.new()
	a.setup(p_kind)
	facing.add_child(a)
	root.set_meta(&"enemy_avatar", a)
	root.set_meta(&"mats", a.body_materials.duplicate())
	return a.height


func setup(p_kind: int) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	kind = p_kind
	height = height_of(kind)
	_parts = BossParts.new()
	body = Node3D.new()
	add_child(body)
	_build_warper()
	body_materials = _parts.body_materials
	_pose()


func _build_warper() -> void:
	var c_body := color(kind, 0)
	var c_trim := color(kind, 1)
	_parts.piece(
		body, BossParts.block(Vector3(0.5, 0.42, 0.44), 91, 0.3), Vector3(0, 0.36, 0), c_body
	)
	_parts.piece(
		body, BossParts.block(Vector3(0.36, 0.3, 0.34), 92, 0.3), Vector3(0.06, 0.7, 0), c_trim
	)
	# the hood: a point leaning forward
	_parts.piece(
		body, BossParts.crystal(0.42, 0.2, 93), Vector3(0.08, 0.92, 0), c_body, Vector3(0, 0, -0.35)
	)
	for side in [-1.0, 1.0]:
		_parts.piece(
			body,
			BossParts.crystal(0.5, 0.07, 94),
			Vector3(0.24, 0.42, 0.26 * side),
			color(kind, 2),
			Vector3(0.0, 0.0, -1.2)
		)
	var star := _parts.glow(
		body,
		BossParts.crystal(0.16, 0.12, 95),
		Vector3(0.26, 0.62, 0),
		color(kind, 3),
		1.6,
		Vector3(0, 0, PI * 0.5)
	)
	_accent = star.material_override as StandardMaterial3D


func sync(reader: WorldReader, i: int) -> void:
	apply_state(
		{
			"state": reader.actor_state(i),
			"windup": windup_progress(reader, i),
			"stunned": reader.warper_stunned(i),
		}
	)


## The same as sync(), from plain values (tests drive the avatar with this).
func apply_state(s: Dictionary) -> void:
	var st: int = s["state"]
	if st == WorldReader.STATE_ACTIVE and _state != st:
		_snap = 1.0  # the blink: it snaps upright
	_state = st
	_wind = float(s.get("windup", 0.0)) if _state == WorldReader.STATE_WINDUP else 0.0
	_stun = bool(s.get("stunned", false))
	if _fresh:
		_fresh = false
		_rise = 0.0 if _state == WorldReader.STATE_SPAWN else 1.0
		_pose()


func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or body == null:
		return
	_t += dt
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.5))
	_reel = move_toward(_reel, 1.0 if _stun else 0.0, dt * 4.0)
	_snap = move_toward(_snap, 0.0, dt * 4.0)
	_pose()


## 0..1: how far into its windup crouch the Warper is (tests).
func windup_pose() -> float:
	return _wind


func _pose() -> void:
	if body == null:
		return
	var crouch := _wind * 0.18 * (1.0 - _snap)
	body.position = Vector3(0, -crouch + (1.0 - _rise) * -0.4, 0)
	body.scale = Vector3(1.0, 1.0 - crouch * 0.6 + _snap * 0.08, 1.0)
	body.rotation = Vector3(sin(_t * 9.0) * 0.18 * _reel, 0, -_wind * 0.25 + _reel * 0.3)
	_accent.emission_energy_multiplier = (1.6 + _wind * 4.0) * (1.0 - 0.75 * _reel)
