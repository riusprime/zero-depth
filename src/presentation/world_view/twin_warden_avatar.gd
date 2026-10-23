class_name TwinWardenAvatar
extends BossAvatar
## v0.9.0 NB2 (BOSSES_4_5.md N2; art list §2): the Twin Wardens, floor 4's two stone knights joined by a burning chain.
## This is the amber one (the boss); TwinWardenVioletAvatar its violet twin. Both play TwinWardenClips, so they move
## as a pair: the whole figure moves through the clips' BODY channel on both models (the owner's amber file keeps
## its Mixamo skeleton but weights nearly every vertex to the hips, so only the whole figure can move); the violet
## file is cut into parts (Body, Helm, Shield, Sword; BossModels `parts`), which add small accents. On top of the clips
## (_pose_rig) the anger the sim reads out (WorldReader.boss_twin) drives it: an angry Warden leans forward, its cracks
## and visor blaze and its light flares, so the player sees which one is fast. With the file missing it is a code
## stand-in of the same parts (a faceted body and cape, a slit helm with stone fins, a tower shield with its shackle,
## a short sword) posed from the same inputs. Presentation only (EI-07): it reads the sim and moves its own children.

const HEIGHT := 2.2
const WALK_SPEED := 1.6
const STRIDE := 1.1

const STONE := Color("#8A8378")
const STONE_DARK := Color("#5A544C")
const IRON := Color("#3A3836")
## Points on the owner's model at rest (metres, model frame +X front): the visor, the shield's shackle (the chain's
## end), the chest (the weak point).
const MODEL_VISOR := Vector3(0.3, 1.95, 0.0)
const MODEL_SHACKLE := Vector3(0.35, 1.0, -0.55)
const MODEL_CHEST := Vector3(0.35, 1.35, 0.0)
const LIGHT_ENERGY := 1.0

var torso := Node3D.new()
var helm := Node3D.new()
var shield := Node3D.new()
var sword := Node3D.new()
var crack_light: OmniLight3D
var _cracks: Array[MeshInstance3D] = []
## The anger read each tick (WorldReader.boss_twin), smoothed in frame time (0..1).
var _angry := false
var _anger := 0.0


## The cracks' and visor's colour (the violet twin overrides it).
func glow_color() -> Color:
	return Color("#FFB347")


## Which side its shield is on (+1 its left, -Z; the violet twin carries it on its right).
func shield_side() -> float:
	return 1.0


func sync(reader: WorldReader, i: int) -> void:
	_angry = bool(reader.boss_twin(i).get("angry", false))
	super(reader, i)


## Render scripts and tests set the anger directly: "angry" (bool).
func apply_state(s: Dictionary) -> void:
	if s.has("angry"):
		_angry = bool(s["angry"])
	super(s)


func model_id() -> StringName:
	return &"boss_twin_warden_amber"


func _code_nodes() -> Array[Node]:
	return [torso, helm, shield, sword]


func _weak_point_at() -> Vector3:
	return MODEL_CHEST if imported != null else Vector3(0.4, 1.3, 0)


func anchor_names() -> Array[StringName]:
	return [&"weak", &"visor", &"shackle"]


func _anchor(point: StringName) -> Vector3:
	var side := shield_side()
	if imported == null:
		var code := {
			&"visor": helm.position + Vector3(0.28, 0.05, 0),
			&"shackle": shield.position + Vector3(0.1, -0.35, 0),
		}
		return code.get(point, weak_core.position)
	match point:
		&"visor":
			return pivot.transform * MODEL_VISOR
		&"shackle":
			return pivot.transform * (MODEL_SHACKLE * Vector3(1, 1, side))
	return weak_core.position


## 0..1: how angry it shows now (tests).
func anger_amount() -> float:
	return _anger


func _build_body() -> void:
	super()
	crack_light = OmniLight3D.new()
	crack_light.name = "CrackLight"
	crack_light.light_color = glow_color()
	crack_light.light_energy = LIGHT_ENERGY
	crack_light.omni_range = 2.8
	crack_light.shadow_enabled = false
	crack_light.position = MODEL_CHEST + Vector3(0.45, 0, 0)
	model.add_child(crack_light)


func _build() -> void:
	var p := parts
	var side := shield_side()
	torso.name = "Body"
	model.add_child(torso)
	# Legs planted wide, the faceted chest and shoulder plates, a stone cape in rigid folds behind.
	for z in [-0.22, 0.22]:
		p.piece(
			torso, BossParts.block(Vector3(0.36, 0.9, 0.3), 1, 0.2), Vector3(0, 0.45, z), STONE_DARK
		)
	p.piece(torso, BossParts.block(Vector3(0.6, 0.8, 0.9), 2, 0.25), Vector3(0, 1.25, 0), STONE)
	for z in [-0.5, 0.5]:
		p.piece(torso, BossParts.block(Vector3(0.5, 0.25, 0.4), 3, 0.3), Vector3(0, 1.62, z), STONE)
	p.piece(
		torso,
		BossParts.block(Vector3(0.12, 1.3, 1.0), 4, 0.15),
		Vector3(-0.38, 0.95, 0),
		STONE_DARK
	)
	# The cracks glowing across the chest.
	for k in 3:
		_cracks.append(
			p.glow(
				torso,
				BossParts.block(Vector3(0.04, 0.32 - 0.06 * k, 0.05), 5 + k),
				Vector3(0.31, 1.2 + 0.12 * k, -0.15 + 0.15 * k),
				glow_color(),
				2.0
			)
		)
	# The tall narrow helm, its visor slit and a short crest of stone fins.
	helm.name = "Helm"
	helm.position = Vector3(0, 1.85, 0)
	model.add_child(helm)
	p.piece(helm, BossParts.block(Vector3(0.42, 0.5, 0.36), 8, 0.2), Vector3.ZERO, STONE)
	for k in 3:
		p.piece(
			helm,
			BossParts.crystal(0.22, 0.04, 9 + k),
			Vector3(-0.08 + 0.08 * k, 0.3, 0),
			STONE_DARK
		)
	_cracks.append(
		p.glow(
			helm,
			BossParts.block(Vector3(0.04, 0.05, 0.28), 12),
			Vector3(0.22, 0.05, 0),
			glow_color(),
			3.0
		)
	)
	# The tower shield on its arm with the iron shackle round the wrist; the short broad sword in the other hand.
	shield.name = "Shield"
	shield.position = Vector3(0.3, 1.05, -0.55 * side)
	model.add_child(shield)
	p.piece(shield, BossParts.block(Vector3(0.12, 1.2, 0.62), 13, 0.12), Vector3(0.05, 0, 0), STONE)
	p.piece(
		shield,
		BossParts.tube(0.3, 0.08, 14, 8),
		Vector3(-0.08, -0.35, 0),
		IRON,
		Vector3(PI * 0.5, 0, 0)
	)
	sword.name = "Sword"
	sword.position = Vector3(0.25, 0.85, 0.55 * side)
	model.add_child(sword)
	p.piece(
		sword,
		BossParts.block(Vector3(0.08, 0.9, 0.18), 15, 0.1),
		Vector3(0.2, 0.25, 0),
		STONE_DARK,
		Vector3(0, 0, -0.5)
	)


## The stand-in, posed from the same inputs as the owner's model: the march, the windup's lean, the strike, the anger.
func _pose(dt: float) -> void:
	var walk := _gait(dt, WALK_SPEED, STRIDE)
	var s := sin(_phase)
	var windup := _state == WorldReader.STATE_WINDUP
	var fade := _act_fade()
	_advance_anger(dt)
	var lean := (_wind * 0.15 if windup else -fade * 0.2) + 0.12 * _anger
	torso.position = Vector3(0, absf(s) * 0.06 * walk - _stagger * 0.12, 0)
	torso.rotation = Vector3(s * 0.06 * walk, 0, -lean + _stagger * 0.15)
	helm.position = Vector3(0, 1.85 + torso.position.y, 0)
	helm.rotation = Vector3(0, sin(_t * 0.7) * 0.08, -lean)
	var raise := _wind if windup and _move == WorldReader.MOVE_SLAM_RING else 0.0
	shield.position.y = 1.05 + torso.position.y + raise * 0.2
	shield.rotation = Vector3(0, 0.3 * _shielded_amount(), s * 0.06 * walk)
	sword.rotation = Vector3(0, 0, -0.1 * s * walk - 0.5 * (_wind if windup else 0.0))
	var glow := (2.0 + 2.5 * _wind + 3.0 * _anger) * (1.0 - 0.6 * _stagger)
	for m in _cracks:
		(m.material_override as StandardMaterial3D).emission_energy_multiplier = glow
	if crack_light != null:
		crack_light.light_energy = LIGHT_ENERGY * (1.0 + 0.8 * _wind + 1.5 * _anger)


func _shielded_amount() -> float:
	return 1.0 if _shielded else 0.0


## The anger's smoothed amount: up fast as it turns angry, down slower as it calms.
func _advance_anger(dt: float) -> void:
	_anger = move_toward(_anger, 1.0 if _angry else 0.0, dt * (6.0 if _angry else 2.0))


func _clip_library() -> Dictionary:
	return TwinWardenClips.library()


func _walk_speed() -> float:
	return WALK_SPEED


func _stride() -> float:
	return STRIDE


func _idle_seconds() -> float:
	return 3.6


## After the clips: an angry Warden leans in and its light flares with the clips' glow.
func _pose_rig(dt: float) -> void:
	_advance_anger(dt)
	if not ViewPrefs.reduced_motion:
		pivot.rotation.z -= 0.1 * _anger
	if crack_light != null:
		var glow := maxf(0.0, 1.0 + 0.6 * animator.param(&"glow") + 1.6 * _anger)
		crack_light.light_energy = LIGHT_ENERGY * glow * (1.0 - 0.6 * _stagger)
