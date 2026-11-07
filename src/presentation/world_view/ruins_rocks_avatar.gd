class_name RuinsRocksAvatar
extends AvatarBase
## v0.11.0 O13b (ENEMIES.md R1-R4; OWNER_TODO §3.2's prompts): the code-made stand-in bodies of the Ruins' and the
## Night Rocks' signature enemies, in the Charger family's style until the owner's models arrive (then VAT): a faceted
## ridged shell in the kind's role colour, a dark shield-shaped face with one glowing gem visor, a charcoal body, grey
## segmented limbs with bone tips. Drawn as nodes (they come one or two at a time, not in crowds; no VAT crowd yet).
## - Wire Weaver (bomber yellow): a spindly walker on four thin legs, four long arms, a coil of cable on its back; its
##   arms rise and its visor flashes while it marks a cable (the tell).
## - Cable post (WIRE_POST): a short grey post with a sparking yellow top.
## - Scrap Hound (melee red-orange): a lean, low four-legged hound with a long snout; its eyes flash bright as it turns
##   in (the tell) and it lunges low; stopped by a hit, it jolts back (the yelp).
## - Rock Lurker (melee red-orange cracks): while it waits, a grey boulder with thin glowing cracks (faint; brighter and
##   shaking while it rumbles); out, the rock is its back, its face and four thick legs showing.
## - Stone Thrower (tank bronze): a hunched brute with two huge arms; through its windup it lifts a rock overhead (the
##   rock leaves its hands at the throw: RuinsRocksViews flies it).
## Presentation only (EI-07): sync() reads the sim through WorldReader once per tick, advance() animates in frame time.
## +X is the front.

const COLORS := {
	WorldReader.KIND_WIRE_WEAVER: Color("#E8C22E"),
	WorldReader.KIND_WIRE_POST: Color("#E8C22E"),
	WorldReader.KIND_SCRAP_HOUND: Color("#C93A1E"),
	WorldReader.KIND_ROCK_LURKER: Color("#C93A1E"),
	WorldReader.KIND_STONE_THROWER: Color("#9A6232"),
}
const HEIGHTS := {
	WorldReader.KIND_WIRE_WEAVER: 1.15,
	WorldReader.KIND_WIRE_POST: 0.95,
	WorldReader.KIND_SCRAP_HOUND: 0.75,
	WorldReader.KIND_ROCK_LURKER: 1.1,
	WorldReader.KIND_STONE_THROWER: 1.6,
}
const CHARCOAL := Color("#24272D")
const FACE := Color("#16181D")
const GREY := Color("#8A817C")
const GREY_DARK := Color("#5F5551")
const ROCK := Color("#A39A92")
const BONE := Color("#D9CDB8")
const OUTLINE_M := 0.02
## The visor's rest glow, its tell's peak, and the lurker's cracks at rest, rumbling and bursting (emission energy).
const VISOR_REST := 1.6
const VISOR_TELL := 7.0
const CRACK_REST := 1.1
const CRACK_RUMBLE := 2.2
const CRACK_OUT := 3.0
## The rumble's shake (m) and rate, the yelp's jolt (radians) and how long it lasts (s); the walk's rate and swing.
const SHAKE_M := 0.025
const SHAKE_HZ := 23.0
const YELP_TILT := 0.45
const YELP_SECONDS := 0.3
const WALK_HZ := 2.6
const WALK_SWING := 0.35

var kind := -1
var height := 1.0
var _model := Node3D.new()
var _body := Node3D.new()
var _visor_mat: StandardMaterial3D
var _crack_mat: StandardMaterial3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _rock: Node3D
var _legs_root: Node3D
var _state := -1
var _tell := 0.0
var _hidden := false
var _rumble := false
var _yelp := 0.0
var _flight := -1
var _walk_phase := 0.0


static func draws(p_kind: int) -> bool:
	return COLORS.has(p_kind)


## Builds the body of `p_kind` under `facing` and marks `root` (ActorViews: the avatar, its body materials for the
## hit flash); returns its height.
static func attach(root: Node3D, facing: Node3D, p_kind: int, outline: Color) -> float:
	var sig := RuinsRocksAvatar.new()
	sig.setup(p_kind, outline)
	facing.add_child(sig)
	root.set_meta(&"enemy_avatar", sig)
	root.set_meta(&"mats", sig.body_materials.duplicate())
	return sig.height


## Builds the model for `p_kind` (one of COLORS).
func setup(p_kind: int, outline: Color) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	kind = p_kind
	height = HEIGHTS.get(kind, 1.0)
	add_child(_model)
	_model.add_child(_body)
	var c: Color = COLORS[kind]
	_visor_mat = _glow(c, VISOR_REST)
	match kind:
		WorldReader.KIND_WIRE_WEAVER:
			_build_weaver(c, outline)
		WorldReader.KIND_WIRE_POST:
			_build_post(c, outline)
		WorldReader.KIND_SCRAP_HOUND:
			_build_hound(c, outline)
		WorldReader.KIND_ROCK_LURKER:
			_build_lurker(c, outline)
		WorldReader.KIND_STONE_THROWER:
			_build_thrower(c, outline)


# --- Pieces -----------------------------------------------------------------------------------------------------
func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color, outline: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _outlined(parent, m, at, c, outline, c, &"outline", OUTLINE_M)


func _prism(parent: Node3D, size: Vector3, at: Vector3, c: Color, outline: Color) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	return _outlined(parent, m, at, c, outline, c, &"outline", OUTLINE_M)


func _rod(
	parent: Node3D, length: float, r: float, at: Vector3, c: Color, outline: Color
) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r * 0.8
	m.height = length
	m.radial_segments = 6
	m.rings = 1
	return _outlined(parent, m, at, c, outline, c, &"outline", OUTLINE_M)


func _stone(parent: Node3D, r: float, at: Vector3, c: Color, outline: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 1.6
	m.radial_segments = 7
	m.rings = 4
	return _outlined(parent, m, at, c, outline, c, &"outline", OUTLINE_M)


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	write_stencil(m)
	return m


func _gem(parent: Node3D, at: Vector3, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
	mi.rotation = Vector3(0, 0, -PI * 0.5)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## The shield face (dark) and its gem visor at `at` (the front of the head), `s` its scale.
func _face(parent: Node3D, at: Vector3, s: float, outline: Color) -> void:
	_box(parent, Vector3(0.06, 0.2, 0.22) * s, at, FACE, outline)
	_gem(parent, at + Vector3(0.04 * s, 0.02 * s, 0), Vector3(0.12, 0.08, 0.06) * s, _visor_mat)


## A segmented limb hanging from `hip` (a pivot node), two rods and a bone tip.
func _limb(hip: Vector3, length: float, r: float, outline: Color, lean := 0.0) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hip
	pivot.rotation.z = lean
	_body.add_child(pivot)
	_rod(pivot, length * 0.5, r, Vector3(0, -length * 0.25, 0), GREY, outline)
	_rod(pivot, length * 0.5, r * 0.8, Vector3(0, -length * 0.75, 0), GREY_DARK, outline)
	_box(pivot, Vector3(r * 2.2, r * 2.2, r * 2.2), Vector3(0, -length, 0), BONE, outline)
	return pivot


func _build_weaver(c: Color, outline: Color) -> void:
	_box(_body, Vector3(0.42, 0.26, 0.36), Vector3(0, 0.78, 0), CHARCOAL, outline)
	_prism(_body, Vector3(0.5, 0.2, 0.44), Vector3(-0.02, 0.99, 0), c, outline)
	_face(_body, Vector3(0.24, 0.8, 0), 1.0, outline)
	var coil := TorusMesh.new()
	coil.inner_radius = 0.08
	coil.outer_radius = 0.16
	coil.rings = 8
	coil.ring_segments = 5
	_outlined(_body, coil, Vector3(-0.2, 1.08, 0), GREY_DARK, outline, c, &"outline", OUTLINE_M)
	for k in 4:
		var x := 0.12 if k < 2 else -0.12
		var z := 0.16 if k % 2 == 0 else -0.16
		_legs.append(_limb(Vector3(x, 0.7, z), 0.72, 0.03, outline, 0.25 if x > 0 else -0.25))
	for k in 4:
		var z := 0.2 if k % 2 == 0 else -0.2
		var y := 0.9 if k < 2 else 0.78
		var arm := _limb(Vector3(0.14, y, z), 0.6, 0.025, outline, 1.1)
		_arms.append(arm)


func _build_post(_c: Color, outline: Color) -> void:
	_rod(_body, 0.8, 0.07, Vector3(0, 0.4, 0), GREY, outline)
	_box(_body, Vector3(0.22, 0.08, 0.22), Vector3(0, 0.04, 0), GREY_DARK, outline)
	var top := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	s.radial_segments = 6
	s.rings = 3
	top.mesh = s
	top.position = Vector3(0, 0.86, 0)
	top.material_override = _visor_mat
	_body.add_child(top)
	_visor_mat.emission_energy_multiplier = VISOR_TELL * 0.6


func _build_hound(c: Color, outline: Color) -> void:
	_box(_body, Vector3(0.7, 0.2, 0.26), Vector3(0, 0.5, 0), CHARCOAL, outline)
	_prism(_body, Vector3(0.66, 0.14, 0.3), Vector3(-0.02, 0.67, 0), c, outline)
	_box(_body, Vector3(0.24, 0.14, 0.16), Vector3(0.44, 0.56, 0), CHARCOAL, outline)
	_face(_body, Vector3(0.6, 0.6, 0), 1.9, outline)  # (big eyes: they flash as it turns in)
	for side in [0.15, -0.15]:
		_box(_body, Vector3(0.22, 0.12, 0.02), Vector3(-0.08, 0.5, side), GREY_DARK, outline)  # scrap plates
	var tail := _rod(_body, 0.3, 0.025, Vector3(-0.44, 0.62, 0), GREY, outline)
	tail.rotation.z = 1.0
	for k in 4:
		var x := 0.26 if k < 2 else -0.26
		var z := 0.11 if k % 2 == 0 else -0.11
		_legs.append(_limb(Vector3(x, 0.45, z), 0.42, 0.028, outline))


func _build_lurker(c: Color, outline: Color) -> void:
	_rock = Node3D.new()
	_body.add_child(_rock)
	var shell := _stone(_rock, 0.62, Vector3(0, 0.5, 0), ROCK, outline)
	shell.rotation = Vector3(0.2, 0.7, 0.1)
	_crack_mat = _glow(c, CRACK_REST)
	for k in 5:
		var crack := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.42, 0.04, 0.05)
		crack.mesh = m
		crack.material_override = _crack_mat
		var ang := k * TAU / 5.0
		crack.position = Vector3(cos(ang) * 0.5, 0.55 + 0.18 * sin(ang * 2.0), sin(ang) * 0.5)
		crack.rotation = Vector3(0.4 * k, -ang, 0.6)
		crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rock.add_child(crack)
	_legs_root = Node3D.new()
	_body.add_child(_legs_root)
	_face(_legs_root, Vector3(0.6, 0.36, 0), 0.9, outline)
	for k in 4:
		var x := 0.3 if k < 2 else -0.3
		var z := 0.34 if k % 2 == 0 else -0.34
		var leg := _limb(Vector3(x, 0.36, z), 0.34, 0.06, outline)
		_body.remove_child(leg)
		_legs_root.add_child(leg)
		_legs.append(leg)


func _build_thrower(c: Color, outline: Color) -> void:
	_box(_body, Vector3(0.6, 0.55, 0.6), Vector3(0, 0.85, 0), CHARCOAL, outline)
	_prism(_body, Vector3(0.6, 0.32, 0.66), Vector3(-0.12, 1.24, 0), c, outline)
	_face(_body, Vector3(0.32, 0.98, 0), 0.8, outline)
	for side in [0.4, -0.4]:
		_arms.append(_limb(Vector3(0.05, 1.1, side), 0.8, 0.09, outline, 0.2))
		_legs.append(_limb(Vector3(0, 0.55, side * 0.5), 0.5, 0.08, outline))
	_rock = Node3D.new()
	_body.add_child(_rock)
	_stone(_rock, 0.32, Vector3.ZERO, ROCK, outline)
	_rock.position = Vector3(0.1, 1.95, 0)
	_rock.visible = false


# --- Sync and pose ----------------------------------------------------------------------------------------------
func sync(reader: WorldReader, i: int) -> void:
	var st := reader.actor_state(i)
	if kind == WorldReader.KIND_SCRAP_HOUND and reader.hound_yelped(i) and _state != st:
		_yelp = YELP_SECONDS
	_state = st
	_tell = windup_progress(reader, i)
	_track_motion(reader.tick(), reader.actor_pos(i), 30.0)
	if kind == WorldReader.KIND_ROCK_LURKER:
		_hidden = reader.lurker_hidden(i) or st == WorldReader.STATE_SPAWN
		_rumble = reader.lurker_rumbling(i)
		_show_rings(not _hidden)  # its disguise: no team ring while it waits
	if kind == WorldReader.KIND_STONE_THROWER:
		_flight = reader.thrower_flight(i)
	_fresh = false


## The tell's glow on the visor now (tests): rest, climbing with the windup, flashing near its end.
func visor_energy() -> float:
	return _visor_mat.emission_energy_multiplier


func crack_energy() -> float:
	return _crack_mat.emission_energy_multiplier if _crack_mat != null else 0.0


func rock_lifted() -> bool:
	return _rock != null and _rock.visible and kind == WorldReader.KIND_STONE_THROWER


func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	_t += dt
	var speed := _vel.length()
	_walk_phase += dt * WALK_HZ * TAU * clampf(speed / 2.0, 0.0, 1.5)
	var swing := sin(_walk_phase) * WALK_SWING * clampf(speed / 2.0, 0.0, 1.0)
	for k in _legs.size():
		_legs[k].rotation.x = swing * (1.0 if k % 2 == 0 else -1.0)
	var winding := _state == WorldReader.STATE_WINDUP
	if kind != WorldReader.KIND_WIRE_POST:
		var e := VISOR_REST
		if winding:
			e = VISOR_REST + (VISOR_TELL - VISOR_REST) * tell_crouch(_tell)
			if tell_flashing(_tell) and int(_t * TELL_FLICKER_HZ) % 2 == 0:
				e = VISOR_TELL * 1.4
		_visor_mat.emission_energy_multiplier = e
	else:
		_visor_mat.emission_energy_multiplier = VISOR_TELL * (0.5 + 0.3 * sin(_t * 31.0))
	match kind:
		WorldReader.KIND_WIRE_WEAVER:
			for arm in _arms:
				arm.rotation.z = lerpf(1.1, 2.4, _tell if winding else 0.0)
		WorldReader.KIND_SCRAP_HOUND:
			_body.position.y = -0.08 * tell_crouch(_tell) if winding else 0.0
			_yelp = maxf(0.0, _yelp - dt)
			_body.rotation.z = YELP_TILT * (_yelp / YELP_SECONDS)
		WorldReader.KIND_ROCK_LURKER:
			_pose_lurker()
		WorldReader.KIND_STONE_THROWER:
			# its telegraph runs over the lift and the flight: the lift is its first part
			var lift := clampf(_tell * 1.8, 0.0, 1.0) if winding else 0.0
			for arm in _arms:
				arm.rotation.z = lerpf(0.2, 3.0, lift)
			_rock.visible = winding
			_rock.position = Vector3(0.05, lerpf(1.3, 2.35, lift), 0)


func _pose_lurker() -> void:
	_legs_root.visible = not _hidden
	var e := CRACK_REST
	if _rumble:
		e = CRACK_RUMBLE
	if not _hidden:
		e = CRACK_OUT
	_crack_mat.emission_energy_multiplier = e
	var shake := Vector3.ZERO
	if _hidden and _rumble:
		shake = Vector3(sin(_t * SHAKE_HZ), 0, cos(_t * SHAKE_HZ * 1.3)) * SHAKE_M
	_rock.position = shake + (Vector3(0, 0.12, 0) if not _hidden else Vector3.ZERO)


## The Lurker's contact disc and team ring (ActorViews' rings on its root) show only once it is out.
func _show_rings(on: bool) -> void:
	var root := get_parent().get_parent() if get_parent() != null else null
	if root == null:
		return
	for n in root.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).visible != on:
			(n as MeshInstance3D).visible = on
