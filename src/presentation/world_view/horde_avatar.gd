class_name HordeAvatar
extends Node3D
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
## Flash materials come from ActorViews.flashable; nothing toggles emission_enabled at runtime. +X is the front.

const RED := Color("#D8433A")
const RED_DARK := Color("#A9302B")
const GREY := Color("#5F5551")
const GREY_LIGHT := Color("#8A817C")
const DARK := Color("#24272D")
const BONE := Color("#D9CDB8")
const EYE := Color("#FF2A22")
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

var kind := WorldReader.KIND_SWARMER
## The model's top (for the health bar).
var height := 1.0
## The pivot every part hangs from (the rise-in and the lean), and the kind's moving parts, by name.
var body: Node3D
var parts := {}
var body_materials: Array[StandardMaterial3D] = []

## The glowing accent (eye, seam, crystal, scope): its own material, emission on from the start.
var _glow_mat := StandardMaterial3D.new()
var _fresh := true
var _state := WorldReader.STATE_SPAWN
var _state_tick := 0
var _ticks_in := 0
var _healing := false
var _t := 0.0
var _rise := 0.0
var _wind := 0.0
var _strike := 0.0
var _outline := Color.BLACK
var _technique := &"xray"


static func height_of(p_kind: int) -> float:
	if p_kind == WorldReader.KIND_SPLITLING:
		return float(HEIGHTS[WorldReader.KIND_SPLITTER]) * SPLITLING_SCALE
	return float(HEIGHTS.get(p_kind, 1.0))


static func is_horde_kind(p_kind: int) -> bool:
	return p_kind == WorldReader.KIND_SPLITLING or HEIGHTS.has(p_kind)


func setup(p_kind: int, outline_color: Color, technique: StringName = &"xray") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	kind = p_kind
	_outline = outline_color
	_technique = technique
	height = height_of(kind)
	body = Node3D.new()
	add_child(body)
	var glow := EYE
	match kind:
		WorldReader.KIND_SWARMER:
			_build_swarmer()
		WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING:
			glow = ThemePalette.color(&"telegraph_hostile")
			_build_splitter()
			if kind == WorldReader.KIND_SPLITLING:
				body.scale = Vector3.ONE * SPLITLING_SCALE
		WorldReader.KIND_SHIELD_BEARER:
			_build_shield_bearer()
		WorldReader.KIND_MENDER:
			glow = MEND
			_build_mender()
		WorldReader.KIND_MINE_LAYER:
			_build_mine_layer()
		WorldReader.KIND_SNIPER:
			_build_sniper()
	_glow_mat.albedo_color = glow
	_glow_mat.emission_enabled = true
	_glow_mat.emission = glow
	_glow_mat.emission_energy_multiplier = 1.5
	NeedleAvatar._write_stencil(_glow_mat)
	_pose()


func sync(reader: WorldReader, i: int) -> void:
	apply_state(
		{
			"tick": reader.tick(),
			"state": reader.actor_state(i),
			"healing": reader.actor_heal_target(i) >= 0,
		}
	)


## The same as sync(), from plain values (tests drive the avatar with this).
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var state: int = s["state"]
	_healing = bool(s.get("healing", false))
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
	if dt <= 0.0 or body == null:
		return
	_t += dt
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.5))
	var winding := _state == WorldReader.STATE_WINDUP
	_wind = move_toward(_wind, 1.0 if winding else 0.0, dt * (2.2 if winding else 5.0))
	if _state == WorldReader.STATE_ACTIVE:
		_strike = 1.0
	else:
		_strike = move_toward(_strike, 0.0, dt * 4.0)
	_pose()


## How far into its windup pose the model is, 0..1 (tests).
func windup_pose() -> float:
	return _wind


## The accent's glow (tests): the eye, seam, crystal or scope.
func glow_energy() -> float:
	return _glow_mat.emission_energy_multiplier


func _pose() -> void:
	var bob := sin(_t * 7.0) * 0.015
	body.position = Vector3(-_wind * 0.06 + _strike * 0.12, bob - (1.0 - _rise) * height, 0)
	var energy := 1.5 + _wind * 3.0 + _strike * 2.0
	match kind:
		WorldReader.KIND_SWARMER:
			for k in 2:
				var m: Node3D = parts["mandible%d" % k]
				m.rotation.y = (0.15 + _wind * 0.7 - _strike * 0.6) * (1.0 if k == 0 else -1.0)
			for k in 6:
				var leg: Node3D = parts["leg%d" % k]
				leg.rotation.z = sin(_t * 22.0 + k * 1.7) * 0.25
		WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING:
			var gap := 0.03 + _wind * 0.08 + sin(_t * 3.0) * 0.01
			(parts["left"] as Node3D).position.z = -gap
			(parts["right"] as Node3D).position.z = gap
			(parts["claws"] as Node3D).rotation.z = -_wind * 0.5 + _strike * 0.8
		WorldReader.KIND_SHIELD_BEARER:
			(parts["shield"] as Node3D).position.x = 0.5 - _wind * 0.18 + _strike * 0.3
		WorldReader.KIND_MENDER:
			body.position.y += 0.18 + sin(_t * 2.2) * 0.06
			(parts["cross"] as Node3D).rotation.y = _t * 2.0
			energy = 1.5 + (2.5 + sin(_t * 9.0) if _healing else 0.0)
		WorldReader.KIND_MINE_LAYER:
			(parts["hopper"] as Node3D).position.y = 0.42 - _wind * 0.25
			(parts["mine"] as Node3D).visible = _strike < 0.5
		WorldReader.KIND_SNIPER:
			(parts["barrel"] as Node3D).rotation.z = -_wind * 0.04 + _strike * 0.12
	_glow_mat.emission_energy_multiplier = energy * lerpf(0.2, 1.0, _rise)


# --- the six builds -----------------------------------------------------------------------------------------------


func _build_swarmer() -> void:
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.34, 0.14, 0.26), 0.04, 0.03),
		Vector3(0, 0.17, 0),
		RED
	)
	_piece(
		body, NeedleAvatar._chamfer_box(Vector3(0.18, 0.1, 0.18), 0.03), Vector3(0.2, 0.18, 0), GREY
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
		_piece(hip, leg, Vector3(0, -0.08, 0), GREY)
		parts["leg%d" % k] = hip


func _build_splitter() -> void:
	var half := ArcCasterAvatar._frustum(0.3, 0.2, 0.72, 6)
	for name in ["left", "right"]:
		var h := Node3D.new()
		body.add_child(h)
		_piece(h, half, Vector3(0, 0.08, 0), RED if name == "left" else RED_DARK)
		_piece(
			h, NeedleAvatar._chamfer_box(Vector3(0.2, 0.12, 0.2), 0.03), Vector3(0, 0.82, 0), GREY
		)
		parts[name] = h
	_glow(body, Vector3(0.5, 0.62, 0.02), Vector3(0.02, 0.44, 0))
	var claws := Node3D.new()
	claws.position = Vector3(0.24, 0.45, 0)
	body.add_child(claws)
	var claw := NeedleAvatar._chamfer_box(Vector3(0.3, 0.06, 0.06), 0.015)
	for side in [-1.0, 1.0]:
		_piece(claws, claw, Vector3(0.14, -0.04, 0.22 * side), GREY)
		_piece(claws, ArcCasterAvatar._octahedron(0.04), Vector3(0.3, -0.06, 0.22 * side), BONE)
	parts["claws"] = claws


func _build_shield_bearer() -> void:
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.5, 0.62, 0.62), 0.07, 0.03),
		Vector3(-0.05, 0.42, 0),
		GREY
	)
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.36, 0.26, 0.4), 0.06, 0.02),
		Vector3(-0.02, 0.86, 0),
		RED
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
		RED
	)
	_piece(
		shield, NeedleAvatar._chamfer_box(Vector3(0.06, 0.6, 0.1), 0.02), Vector3(0.04, 0.6, 0), RED
	)
	parts["shield"] = shield


func _build_mender() -> void:
	_piece(body, ArcCasterAvatar._frustum(0.32, 0.16, 0.9, 8), Vector3(0, 0.1, 0), RED)
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.26, 0.24, 0.26), 0.06, 0.02),
		Vector3(0, 1.1, 0),
		GREY
	)
	for side in [-1.0, 1.0]:
		_piece(
			body,
			NeedleAvatar._chamfer_box(Vector3(0.08, 0.3, 0.08), 0.02),
			Vector3(0.1, 1.0, 0.22 * side),
			GREY
		)
	var crystal := MeshInstance3D.new()
	crystal.mesh = ArcCasterAvatar._octahedron(0.1)
	crystal.material_override = _glow_mat
	crystal.position = Vector3(0.14, 1.36, 0)
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(crystal)
	var cross := Node3D.new()
	cross.position = Vector3(0, 1.62, 0)
	body.add_child(cross)
	for size in [Vector3(0.26, 0.07, 0.07), Vector3(0.07, 0.26, 0.07)]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		bar.mesh = bm
		bar.material_override = _glow_mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cross.add_child(bar)
	parts["cross"] = cross


func _build_mine_layer() -> void:
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.7, 0.24, 0.5), 0.06, 0.03),
		Vector3(0, 0.2, 0),
		RED
	)
	_piece(body, ArcCasterAvatar._frustum(0.2, 0.1, 0.16, 6), Vector3(0.08, 0.32, 0), GREY)
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
	_piece(hopper, NeedleAvatar._chamfer_box(Vector3(0.24, 0.12, 0.3), 0.03), Vector3.ZERO, GREY)
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
			GREY
		)
	_piece(
		body,
		NeedleAvatar._chamfer_box(Vector3(0.36, 0.26, 0.26), 0.05, 0.02),
		Vector3(0, 0.78, 0),
		RED
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
		DARK
	)
	_glow(barrel, Vector3(0.012, 0.05, 0.05), Vector3(0.115, 0.1, 0))
	parts["barrel"] = barrel


# --- pieces -------------------------------------------------------------------------------------------------------


## A glowing accent box (an eye, the seam, a scope lens) on the accent material.
func _glow(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _glow_mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## An outlined, flashable body piece (and its X-ray twin while the technique is xray).
func _piece(parent: Node3D, mesh: Mesh, at: Vector3, c: Color) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 1.0
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = _outline
	mat.stencil_outline_thickness = OUTLINE_M
	piece.material_override = mat
	parent.add_child(piece)
	body_materials.append(ActorViews.flashable(mat))
	if _technique == &"xray":
		var ghost := MeshInstance3D.new()
		ghost.mesh = mesh
		var gm := StandardMaterial3D.new()
		gm.albedo_color = c
		gm.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		gm.stencil_color = Color(ThemePalette.color(&"enemy_body"), 0.85)
		ghost.material_override = gm
		ghost.position = at
		ghost.scale = Vector3.ONE * 0.96
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ghost)
