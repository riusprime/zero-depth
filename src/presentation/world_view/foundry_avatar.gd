class_name FoundryAvatar
extends BossAvatar
## The Foundry (v0.4.0 BO, floor 3's second boss; prompt in docs/art/BOSSES_2.md, code-built until the owner's
## sheet): a walking furnace in the enemy style. A squat grey faceted furnace body with a red hood on top, a glowing
## red-hot grate in its front behind a dark door frame, two grey chimneys glowing red inside, a pouring spout under
## the grate, a red launcher tube on its back for the Bomb Drones, and four short heavy grey legs on wide feet. Moves:
## the grate flares and it tips forward to pour (the flood: molten lanes), the chimneys kick (the slag mortar), it
## crouches and blows its vents (the vent ring), and the launcher tilts and kicks (launching Bomb Drones). While its
## weak point is open the grate's door hangs open on a gold core; staggered, it lurches and its fire dims.

const HEIGHT := 2.6
const WALK_SPEED := 1.5
const STRIDE := 1.3
const BODY_Y := 1.25

const IRON := Color("#6A6462")
const IRON_DARK := Color("#4C4847")
const FRAME := Color("#2B2C31")
const RED := Color("#D23E35")
const HOT := Color("#FF5A26")
const GLOW := Color("#FF3A26")

var body := Node3D.new()
var grate: MeshInstance3D
var door := Node3D.new()
var chimneys: Array[Node3D] = []
var launcher := Node3D.new()
var legs: Array[Node3D] = []
var _chimney_glow: Array[MeshInstance3D] = []
var _launcher_glow: MeshInstance3D
var _door_open := 0.0


## Its imported model, when the owner sends one: assets/models/bosses/foundry.glb (whole-body motion).
func model_id() -> StringName:
	return &"foundry"


func _code_nodes() -> Array[Node]:
	return [body, launcher]


func _weak_point_at() -> Vector3:
	return Vector3(1.05, BODY_Y - 0.05, 0)


## 0..1: how far the grate's door hangs open (tests).
func door_open() -> float:
	return _door_open


func _build() -> void:
	var p := parts
	body.name = "Body"
	body.position.y = BODY_Y
	model.add_child(body)
	# The furnace: a broad faceted iron block, a red hood on top, a darker base.
	p.piece(body, BossParts.block(Vector3(1.9, 1.3, 1.8), 1, 0.2), Vector3(0, 0.05, 0), IRON)
	p.piece(body, BossParts.block(Vector3(1.5, 0.35, 1.5), 2, 0.3), Vector3(-0.1, 0.85, 0), RED)
	p.piece(
		body, BossParts.block(Vector3(1.6, 0.35, 1.6), 3, 0.25), Vector3(0, -0.75, 0), IRON_DARK
	)
	# The front: a dark frame around the glowing grate, its door (hinged on the left) and the spout below.
	p.piece(body, BossParts.block(Vector3(0.2, 0.95, 1.15), 4, 0.15), Vector3(0.92, 0.0, 0), FRAME)
	grate = p.glow(
		body, BossParts.block(Vector3(0.06, 0.7, 0.85), 5), Vector3(1.02, 0.0, 0), HOT, 2.0
	)
	door.name = "Door"
	door.position = Vector3(1.06, 0.0, -0.45)
	body.add_child(door)
	for k in 3:
		p.piece(
			door,
			BossParts.block(Vector3(0.06, 0.12, 0.85), 6 + k),
			Vector3(0, -0.25 + 0.25 * k, 0.43),
			FRAME
		)
	p.piece(
		body,
		BossParts.tube(0.5, 0.16, 9, 6),
		Vector3(0.95, -0.55, 0),
		IRON_DARK,
		Vector3(0, 0, -0.5)
	)
	# Two chimneys on the hood, glowing inside.
	for side in [-1.0, 1.0]:
		var c := Node3D.new()
		c.position = Vector3(-0.35, 1.0, side * 0.45)
		body.add_child(c)
		p.piece(
			c, BossParts.tube(0.8, 0.2, 10, 8), Vector3.ZERO, IRON_DARK, Vector3(0, 0, PI * 0.5)
		)
		_chimney_glow.append(
			p.glow(c, BossParts.orb(0.16, 11, 7, 3), Vector3(0, 0.82, 0), GLOW, 1.6)
		)
		chimneys.append(c)
	# Side vents (glowing slits).
	for side in [-1.0, 1.0]:
		for k in 3:
			p.glow(
				body,
				BossParts.block(Vector3(0.5, 0.05, 0.04), 12 + k),
				Vector3(-0.1, -0.25 + 0.2 * k, side * 0.92),
				GLOW,
				1.2
			)
	# The launcher on the back: a red tube angled up and back.
	launcher.name = "Launcher"
	launcher.position = Vector3(-0.85, BODY_Y + 0.75, 0)
	model.add_child(launcher)
	p.piece(launcher, BossParts.block(Vector3(0.4, 0.3, 0.5), 20, 0.3), Vector3.ZERO, IRON_DARK)
	p.piece(
		launcher,
		BossParts.tube(0.9, 0.24, 21, 8),
		Vector3(0, 0.1, 0),
		RED,
		Vector3(0, 0, PI * 0.5 + 0.6)
	)
	_launcher_glow = p.glow(
		launcher, BossParts.orb(0.18, 22, 7, 3), Vector3(-0.55, 0.85, 0), GLOW, 1.2
	)
	for fx in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var leg := Node3D.new()
			leg.position = Vector3(fx * 0.6, BODY_Y - 0.75, side * 0.7)
			model.add_child(leg)
			p.piece(
				leg,
				BossParts.block(Vector3(0.42, 0.5, 0.42), 30, 0.3),
				Vector3(0, -0.15, 0),
				IRON_DARK
			)
			p.piece(
				leg,
				BossParts.block(Vector3(0.7, 0.16, 0.6), 31, 0.3),
				Vector3(0.05, -0.42, 0),
				FRAME
			)
			legs.append(leg)


func _pose(dt: float) -> void:
	var walk := _gait(dt, WALK_SPEED, STRIDE)
	var s := sin(_phase)
	var windup := _state == WorldReader.STATE_WINDUP
	var fade := _act_fade()
	var pour := 0.0
	var mortar := 0.0
	var vent := 0.0
	var launch := 0.0
	var kick := 0.0
	match _move:
		WorldReader.MOVE_FLOOD:
			pour = _wind if windup else fade
		WorldReader.MOVE_BARRAGE:
			mortar = _wind if windup else 0.0
			kick = 0.0 if windup else _hit
		WorldReader.MOVE_SLAM_RING:
			vent = _wind if windup else -fade
		WorldReader.MOVE_BROOD:
			launch = _wind if windup else 0.0
			kick = 0.0 if windup else _hit
	_door_open = lerpf(_door_open, maxf(_weak_shown, pour * 0.5), _rate(8.0, dt))
	var stag := _stagger
	var crouch := maxf(vent, 0.0)
	body.position = Vector3(
		0.05 * pour,
		BODY_Y + absf(s) * 0.04 * walk - crouch * 0.2 + maxf(-vent, 0.0) * 0.1 - stag * 0.12,
		0
	)
	body.rotation = Vector3(
		s * 0.03 * walk + sin(_t * 10.0) * 0.05 * stag, 0, -pour * 0.22 + stag * 0.1 + kick * 0.03
	)
	body.scale = Vector3.ONE * (1.0 + maxf(-vent, 0.0) * 0.06)
	door.rotation = Vector3(0, -_door_open * 1.9, 0)
	var heat := 1.0 - 0.7 * stag
	(grate.material_override as StandardMaterial3D).emission_energy_multiplier = (
		(2.0 + 4.0 * maxf(pour, crouch) + 2.0 * _late) * heat
	)
	for k in chimneys.size():
		chimneys[k].position.y = (
			1.0 - kick * 0.12 * (1.0 if _move == WorldReader.MOVE_BARRAGE else 0.0)
		)
		(_chimney_glow[k].material_override as StandardMaterial3D).emission_energy_multiplier = (
			(1.6 + 4.0 * mortar) * heat
		)
	launcher.position = Vector3(-0.85, BODY_Y + 0.75 + absf(s) * 0.04 * walk - stag * 0.12, 0)
	launcher.rotation = Vector3(
		0, 0, -launch * 0.3 + kick * 0.2 * (1.0 if _move == WorldReader.MOVE_BROOD else 0.0)
	)
	(_launcher_glow.material_override as StandardMaterial3D).emission_energy_multiplier = (
		(1.2 + 4.0 * launch) * heat
	)
	for j in legs.size():
		var diag := 1.0 if j == 0 or j == 3 else -1.0
		var lift := maxf(0.0, sin(_phase) * diag) * 0.18 * walk
		legs[j].position.y = BODY_Y - 0.75 + lift - crouch * 0.15
