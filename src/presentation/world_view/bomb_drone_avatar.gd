class_name BombDroneAvatar
extends Node3D
## The Bomb Drone (v0.3.5 AI, owner F6): a low-poly quad-rotor in the enemy sheet's red and grey, hovering
## HOVER_Y up with a soft bob. A faceted red hull with a red slit eye in front, four grey arms with spinning rotor
## blades, and a dark bomb slung under its belly whose fuse glows. The bomb drops away as the drone lobs it (the
## telegraph view draws it flying to its circle) and a fresh one rises into the bay as the drone recovers. A soft
## dark shadow on the ground marks where the drone really is: the sim treats it as a body on the ground, so melee
## and shots hit it there (the owner: "hittable from the ground level").
## Presentation only (EI-07): sync() reads the sim through WorldReader once per tick, advance() animates in frame
## time, and nothing here feeds back into the sim. ActorViews puts it under the actor's facing node: +X is the front.

## How high the hull hovers, and the bob's height and rate (starting values, PLAN "Enemy and boss AI").
const HOVER_Y := 1.8
const BOB_M := 0.08
const BOB_HZ := 0.9
## The model's top (for the health bar).
const HEIGHT := HOVER_Y + 0.3
const ARM_LEN := 0.36
const ROTOR_R := 0.17
const SHADOW_R := 0.42
const OUTLINE_M := 0.02

const RED := Color("#D8433A")
const GREY := Color("#5F5551")
const DARK := Color("#24272D")
const EYE := Color("#FF2A22")
const BOMB := Color("#1B1C20")

## Parts, read by tests and by ActorViews (flash materials; the eye, fuse and shadow are their own).
var hull: Node3D
var bomb: Node3D
var shadow: MeshInstance3D
var rotors: Array[Node3D] = []
var body_materials: Array[StandardMaterial3D] = []

var _eye_mat := StandardMaterial3D.new()
var _fuse_mat := StandardMaterial3D.new()
var _fresh := true
var _state := WorldReader.STATE_SPAWN
var _state_tick := 0
var _ticks_in := 0
var _t := 0.0
var _rise := 0.0
var _armed := 1.0
var _fuse := 0.0


func setup(outline_color: Color, technique: StringName = &"xray") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var team := ThemePalette.color(&"enemy_body")
	# The ground shadow: a dark, soft disc right under the drone (it stays on the ground).
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
	add_child(shadow)
	hull = Node3D.new()
	add_child(hull)
	var body := NeedleAvatar._chamfer_box(Vector3(0.42, 0.18, 0.36), 0.06, 0.02)
	_piece(hull, body, Vector3.ZERO, RED, outline_color, team, technique)
	var cap := NeedleAvatar._chamfer_box(Vector3(0.24, 0.08, 0.22), 0.03, 0.01)
	_piece(hull, cap, Vector3(-0.02, 0.12, 0), GREY, outline_color, team, &"outline")
	_eye_mat.albedo_color = EYE
	_eye_mat.emission_enabled = true
	_eye_mat.emission = EYE
	_eye_mat.emission_energy_multiplier = 2.2
	NeedleAvatar._write_stencil(_eye_mat)
	var slit := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.01, 0.04, 0.2)
	slit.mesh = sb
	slit.material_override = _eye_mat
	slit.position = Vector3(0.215, 0.01, 0)
	slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hull.add_child(slit)
	# Four arms on the diagonals, each with a hub and a two-blade rotor.
	var arm := NeedleAvatar._chamfer_box(Vector3(ARM_LEN, 0.05, 0.06), 0.012)
	var hub := NeedleAvatar._prism(0.045, 0.07, 8)
	var blade := NeedleAvatar._chamfer_box(Vector3(ROTOR_R * 2.0, 0.012, 0.05), 0.004)
	for k in 4:
		var yaw := TAU * (k + 0.5) / 4.0
		var holder := Node3D.new()
		holder.rotation = Vector3(0, yaw, 0)
		hull.add_child(holder)
		_piece(
			holder,
			arm,
			Vector3(ARM_LEN * 0.5 + 0.1, 0.02, 0),
			GREY,
			outline_color,
			team,
			&"outline"
		)
		var top := Node3D.new()
		top.position = Vector3(ARM_LEN + 0.1, 0.07, 0)
		holder.add_child(top)
		var hub_node := Node3D.new()
		hub_node.rotation = Vector3(PI * 0.5, 0, 0)
		top.add_child(hub_node)
		_piece(hub_node, hub, Vector3.ZERO, DARK, outline_color, team, &"outline")
		var rotor := Node3D.new()
		rotor.position.y = 0.045
		top.add_child(rotor)
		_piece(rotor, blade, Vector3.ZERO, DARK, outline_color, team, &"outline")
		rotors.append(rotor)
	# The bomb under the belly, its fuse light on top of it.
	bomb = Node3D.new()
	bomb.position = Vector3(0, -0.2, 0)
	hull.add_child(bomb)
	_piece(
		bomb, ArcCasterAvatar._octahedron(0.1), Vector3.ZERO, BOMB, outline_color, team, &"outline"
	)
	var hot := ThemePalette.color(&"telegraph_hostile")
	_fuse_mat.albedo_color = hot
	_fuse_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fuse_mat.emission_enabled = true
	_fuse_mat.emission = hot
	_fuse_mat.emission_energy_multiplier = 1.0
	var fuse := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.04, 0.04, 0.04)
	fuse.mesh = fb
	fuse.material_override = _fuse_mat
	fuse.position = Vector3(0, -0.13, 0)
	fuse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bomb.add_child(fuse)
	_pose()


func sync(reader: WorldReader, i: int) -> void:
	apply_state({"tick": reader.tick(), "state": reader.actor_state(i)})


## The same as sync(), from plain values (tests drive the avatar with this).
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var state: int = s["state"]
	if _fresh or state != _state:
		_state = state
		_state_tick = tick
	_ticks_in = tick - _state_tick
	if _fresh:
		_fresh = false
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_pose()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or hull == null:
		return
	_t += dt
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 1.8))
	# The bomb leaves with the windup (the lob) and a new one is slung back under the belly in the recovery.
	var lobbed := _state == WorldReader.STATE_WINDUP or _state == WorldReader.STATE_ACTIVE
	_armed = move_toward(_armed, 0.0 if lobbed else 1.0, dt * (12.0 if lobbed else 1.5))
	_fuse = 1.0 if _state == WorldReader.STATE_MOVE else 0.0
	for k in rotors.size():
		rotors[k].rotation.y = _t * (34.0 if k % 2 == 0 else -34.0)
	_pose()


## The hull's current height above the ground (the hover plus the bob).
func hover_height() -> float:
	return hull.position.y


## True while a bomb hangs in the bay (it is drawn).
func bomb_armed() -> bool:
	return bomb.visible


func _pose() -> void:
	var bob := sin(_t * TAU * BOB_HZ) * BOB_M
	hull.position = Vector3(0, lerpf(0.5, HOVER_Y, _rise) + bob, 0)
	hull.rotation = Vector3(sin(_t * 1.3) * 0.06, 0, sin(_t * 1.7) * 0.05 - 0.08)
	bomb.visible = _armed > 0.05
	bomb.scale = Vector3.ONE * maxf(_armed, 0.05)
	_fuse_mat.emission_energy_multiplier = 0.8 + _fuse * (1.5 + sin(_t * 12.0) * 1.2)
	var s := lerpf(0.6, 1.0, _rise) * (1.0 - bob * 0.8)
	shadow.scale = Vector3(s, 1, s)


func _piece(
	parent: Node3D,
	mesh: Mesh,
	at: Vector3,
	c: Color,
	outline: Color,
	team: Color,
	technique: StringName
) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 1.0
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = outline
	mat.stencil_outline_thickness = OUTLINE_M
	piece.material_override = mat
	parent.add_child(piece)
	body_materials.append(ActorViews.flashable(mat))
	if technique == &"xray":
		var ghost := MeshInstance3D.new()
		ghost.mesh = mesh
		var gm := StandardMaterial3D.new()
		gm.albedo_color = c
		gm.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		gm.stencil_color = Color(team, 0.85)
		ghost.material_override = gm
		ghost.position = at
		ghost.scale = Vector3.ONE * 0.96
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ghost)
