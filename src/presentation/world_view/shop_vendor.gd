class_name ShopVendor
extends Node3D
## The shop's vendor (v0.8.0 SR, owner O13: "each biome that will have like its own vendor like with a model"):
## one per biome, standing behind the stall's counter. Until the owner's models arrive (ShopModels,
## shop_vendor_<biome>) each is a code-made stand-in in the game's chunky faceted style (flat-shaded prisms and
## blocks, a glowing eye or lens), built to the art list's size (docs/art/requests/v0.8.0_ART_LIST.md §1):
## - ruins: a hunched scavenger in a hooded patched coat and amber goggles, a big backpack of junk and wires (1.6 m);
## - night_rocks: a lantern-carrying hermit in a moss-grey cloak, a staff hung with charms (1.7 m);
## - red_canyon: a desert trader in wrapped scarves under a wide-brimmed hat, a bandolier of pouches (1.7 m);
## - frozen_shore: a fur-wrapped fisher-trader, a hood rimmed in frost, a hook on a pole (1.7 m);
## - starfall: a floating cloaked astral merchant, a star-map cape, small crystals orbiting it (1.8 m, floating).
## It reacts (ShopStallView drives it): it idles (breathing, a slow look round), turns to face you when you come
## near (face()), nods on a sale (nod()) and shakes its head on a refusal (shake()). Reduced motion
## (ViewPrefs.reduced_motion): no breathing, look-round, hover or orbit; it turns to you at once; the nod and the
## shake are a short glow of its eyes (warm for a sale, red for a refusal) instead of a head movement. Its front is
## local +X, its feet at y = 0. Glowing materials have emission on from creation (flash-safe). Presentation only.

const TURN_SPEED := 4.0
## The most it turns from the counter's facing to look at you (radians): never its back to the counter.
const TURN_MAX := 1.35
const NOD_S := 0.7
const SHAKE_S := 0.7
const BREATH_HZ := 0.35
const LOOK_AMP := 0.45
const GLOW_ENERGY := 1.6
const SALE_GLOW := Color("#FFD27A")
const DENY_GLOW := Color("#FF4A3D")
## Per biome: the art list's height (m) and how high its neck pivot sits.
const HEIGHTS := {
	&"ruins": 1.6, &"night_rocks": 1.7, &"red_canyon": 1.7, &"frozen_shore": 1.7, &"starfall": 1.8
}

var biome := &"ruins"
## True when the owner's model is drawn instead of the stand-in.
var from_model := false
var _hover: Node3D
var _body: Node3D
var _head: Node3D
var _orbit: Node3D
var _eye_mat := StandardMaterial3D.new()
var _eye_color := Color("#FFB347")
var _mats: Array[StandardMaterial3D] = []
var _t := 0.0
var _yaw := 0.0
var _target := 0.0
var _has_target := false
var _nod_left := 0.0
var _shake_left := 0.0


func _init() -> void:
	name = "Vendor"
	_eye_mat.emission_enabled = true


## Builds the vendor of `p_biome` (an unknown biome gets the Ruins scavenger): the owner's model when the manifest
## lists it, else the stand-in.
func setup(p_biome: StringName) -> void:
	biome = p_biome if HEIGHTS.has(p_biome) else &"ruins"
	_hover = Node3D.new()
	add_child(_hover)
	_body = Node3D.new()
	_hover.add_child(_body)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, height() - 0.32, 0)
	_body.add_child(_head)
	var model := ShopModels.get_model(ShopModels.vendor_id(biome))
	if not model.is_empty():
		from_model = true
		var mi := MeshInstance3D.new()
		mi.mesh = model["mesh"]
		if model["material"] != null:
			mi.material_override = model["material"]
		_body.add_child(mi)
		_eye_color = SALE_GLOW
	else:
		match biome:
			&"night_rocks":
				_build_hermit()
			&"red_canyon":
				_build_trader()
			&"frozen_shore":
				_build_fisher()
			&"starfall":
				_build_astral()
			_:
				_build_scavenger()
	_eye_mat.albedo_color = _eye_color
	_eye_mat.emission = _eye_color
	_eye_mat.emission_energy_multiplier = GLOW_ENERGY


## The art list's height for this vendor (m; the Starfall merchant's includes its float).
func height() -> float:
	return float(HEIGHTS.get(biome, 1.6))


## Turn toward a point in the parent's frame (the stall's: +X its front), or back to the counter's facing (null).
func face(target_local: Variant) -> void:
	if target_local == null:
		_has_target = false
		_target = 0.0
	else:
		var p: Vector3 = target_local - position
		_has_target = true
		_target = clampf(atan2(-p.z, p.x), -TURN_MAX, TURN_MAX)
	if ViewPrefs.reduced_motion:
		_yaw = _target
		rotation.y = _yaw


## A sale: the vendor nods.
func nod() -> void:
	_nod_left = NOD_S
	_shake_left = 0.0


## A refusal: the vendor shakes its head.
func shake() -> void:
	_shake_left = SHAKE_S
	_nod_left = 0.0


func nodding() -> bool:
	return _nod_left > 0.0


func shaking() -> bool:
	return _shake_left > 0.0


## True when it has turned to the point face() was given (within a few degrees).
func facing_target() -> bool:
	return _has_target and absf(_yaw - _target) < 0.08


func has_target() -> bool:
	return _has_target


## Its turn from the counter's facing (radians about Y).
func yaw() -> float:
	return _yaw


## The head's pose (for tests): rotation in radians (x tilt, y turn, z nod).
func head_rotation() -> Vector3:
	return _head.rotation if _head != null else Vector3.ZERO


## Every material it draws (tests check the glowing ones keep emission on).
func materials() -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = [_eye_mat]
	out.append_array(_mats)
	return out


func eye_material() -> StandardMaterial3D:
	return _eye_mat


func _process(delta: float) -> void:
	step(delta)


## One frame of its animation (tests call it directly).
func step(delta: float) -> void:
	if _body == null:
		return
	_t += delta
	var calm := ViewPrefs.reduced_motion
	if calm:
		_yaw = _target
	else:
		_yaw = move_toward(_yaw, _target, TURN_SPEED * delta)
	rotation.y = _yaw
	var breath := 0.0 if calm else sin(_t * TAU * BREATH_HZ)
	_body.scale = Vector3(1.0 + breath * 0.012, 1.0 + breath * 0.022, 1.0 + breath * 0.012)
	var look := 0.0 if calm or _has_target else LOOK_AMP * sin(_t * 0.55) * absf(sin(_t * 0.21))
	var nod := 0.0
	var turn := look
	var glow := GLOW_ENERGY
	var glow_color := _eye_color
	if _nod_left > 0.0:
		_nod_left = maxf(0.0, _nod_left - delta)
		var k := 1.0 - _nod_left / NOD_S
		if calm:
			glow_color = SALE_GLOW
			glow = GLOW_ENERGY * 2.2
		else:
			nod = -0.45 * absf(sin(k * TAU))
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		var k := 1.0 - _shake_left / SHAKE_S
		if calm:
			glow_color = DENY_GLOW
			glow = GLOW_ENERGY * 2.2
		else:
			turn = 0.5 * sin(k * TAU * 2.0) * (1.0 - k)
			glow_color = _eye_color.lerp(DENY_GLOW, 1.0 - k)
	if from_model:
		_body.rotation = Vector3(0, turn * 0.6, nod * 0.35)
	else:
		_head.rotation = Vector3(0, turn, nod)
	_eye_mat.emission = glow_color
	_eye_mat.albedo_color = glow_color
	_eye_mat.emission_energy_multiplier = glow
	if biome == &"starfall":
		_hover.position.y = 0.0 if calm else sin(_t * 1.4) * 0.06
		if _orbit != null and not calm:
			_orbit.rotation.y += delta * 0.9


# --- the stand-ins (front +X, feet at y = 0) -------------------------------------------------------------------


## Ruins: a hunched scavenger, hooded patched coat, amber goggles, a big backpack of junk and wires.
func _build_scavenger() -> void:
	_eye_color = Color("#FFB347")
	var coat := _mat(Color("#8A7458"))
	var patch_a := _mat(Color("#8A7A5A"))
	var patch_b := _mat(Color("#4E5B4A"))
	var dark := _mat(Color("#2A2420"))
	var metal := _mat(Color("#5D646C"), 0.5)
	var rust := _mat(Color("#8C5A3A"))
	_part(RewardViews.prism(7, 0.36, 0.3, 0.75, 0.0, 0.2, 31), coat)  # coat skirt
	var torso := _part(RewardViews.prism(6, 0.3, 0.22, 0.5, 0.7, 0.3, 37), coat)
	torso.rotation.z = -0.28  # hunched forward
	_part(_cube(Vector3(0.05, 0.16, 0.16)), patch_a, Vector3(0.3, 0.45, 0.12), Vector3(0, 0, -0.1))
	_part(
		_cube(Vector3(0.05, 0.13, 0.14)), patch_b, Vector3(0.27, 0.95, -0.13), Vector3(0, 0, -0.3)
	)
	for side in [-1.0, 1.0]:  # arms, hanging forward
		_part(
			_cube(Vector3(0.12, 0.5, 0.12)),
			coat,
			Vector3(0.12, 0.85, 0.3 * side),
			Vector3(0, 0, -0.35)
		)
		_part(_cube(Vector3(0.1, 0.1, 0.1)), dark, Vector3(0.28, 0.62, 0.3 * side))
	# The backpack of junk: a crate of parts, pipes, a coil of wire, an antenna.
	_part(_cube(Vector3(0.36, 0.55, 0.5)), metal, Vector3(-0.32, 1.0, 0), Vector3(0, 0, -0.2))
	_part(_cube(Vector3(0.08, 0.5, 0.08)), rust, Vector3(-0.45, 1.4, 0.16), Vector3(0.3, 0, 0.2))
	_part(
		_cube(Vector3(0.06, 0.4, 0.06)), metal, Vector3(-0.36, 1.42, -0.2), Vector3(-0.4, 0, -0.1)
	)
	_part(
		RewardViews.prism(8, 0.13, 0.13, 0.06, 0.0, 0.0, 41),
		rust,
		Vector3(-0.52, 0.98, 0.0),
		Vector3(0, 0, PI / 2)
	)
	_part(_cube(Vector3(0.02, 0.45, 0.02)), dark, Vector3(-0.5, 1.6, -0.12), Vector3(0, 0, 0.2))
	# The head: a deep hood, a dark face, two amber goggle lenses.
	_head_part(RewardViews.prism(6, 0.2, 0.08, 0.36, -0.12, 0.4, 43), coat, Vector3(-0.02, 0, 0))
	_head_part(_cube(Vector3(0.1, 0.18, 0.22)), dark, Vector3(0.1, 0.02, 0))
	for side in [-1.0, 1.0]:
		_head_part(
			RewardViews.prism(6, 0.05, 0.05, 0.05, 0.0, 0.0, 0),
			_eye_mat,
			Vector3(0.17, 0.05, 0.06 * side),
			Vector3(0, 0, PI / 2)
		)
	_head.position = Vector3(0.14, 1.3, 0)


## Night Rocks: a lantern-carrying hermit, moss-grey cloak, a staff hung with charms.
func _build_hermit() -> void:
	_eye_color = Color("#FFD27A")
	var cloak := _mat(Color("#5E6B5C"))
	var inner := _mat(Color("#3E463D"))
	var wood := _mat(Color("#5A4632"))
	var charm := _mat(Color("#C9B98A"), 0.3)
	var dark := _mat(Color("#221F1C"))
	_part(RewardViews.prism(8, 0.42, 0.22, 1.3, 0.0, 0.25, 47), cloak)  # the cloak, a long cone
	_part(RewardViews.prism(6, 0.24, 0.2, 0.25, 1.15, 0.1, 53), inner)  # shoulders
	_part(_cube(Vector3(0.12, 0.55, 0.12)), cloak, Vector3(0.1, 0.95, -0.28), Vector3(0, 0, -0.5))
	_part(_cube(Vector3(0.12, 0.5, 0.12)), cloak, Vector3(0.05, 0.9, 0.3), Vector3(0.1, 0, -0.1))
	# The staff in its left hand, charms hanging from its head.
	_part(
		_cube(Vector3(0.06, 1.75, 0.06)), wood, Vector3(0.12, 0.88, 0.38), Vector3(0.05, 0, -0.06)
	)
	for k in 3:
		var at := Vector3(0.16 + 0.04 * k, 1.55 - 0.12 * k, 0.42 + 0.03 * (k - 1))
		_part(RewardViews.bipyramid(4, 0.04, 0.06, 0.06), charm, at)
	# The lantern held out in its right hand.
	_part(_cube(Vector3(0.02, 0.18, 0.02)), dark, Vector3(0.36, 0.78, -0.3))
	_part(RewardViews.prism(6, 0.08, 0.06, 0.16, 0.0, 0.0, 0), _eye_mat, Vector3(0.36, 0.56, -0.3))
	# The head: a pointed hood over a shadowed face, two small glints.
	_head_part(RewardViews.prism(5, 0.2, 0.02, 0.5, -0.12, 0.3, 59), cloak)
	_head_part(_cube(Vector3(0.08, 0.16, 0.2)), dark, Vector3(0.12, 0.0, 0))
	for side in [-1.0, 1.0]:
		_head_part(_cube(Vector3(0.03, 0.03, 0.04)), _eye_mat, Vector3(0.165, 0.03, 0.05 * side))
	_head.position = Vector3(0.04, 1.38, 0)


## Red Canyon: a desert trader in wrapped scarves, a wide-brimmed hat, a bandolier of pouches.
func _build_trader() -> void:
	_eye_color = Color("#FFC27A")
	var robe := _mat(Color("#C9A26B"))
	var scarf_a := _mat(Color("#B5522E"))
	var scarf_b := _mat(Color("#D9A35B"))
	var hat := _mat(Color("#8A5A34"))
	var leather := _mat(Color("#4E3424"))
	var pouch := _mat(Color("#7A5532"))
	var dark := _mat(Color("#2B201A"))
	_part(RewardViews.prism(7, 0.32, 0.27, 0.9, 0.0, 0.15, 61), robe)
	_part(RewardViews.prism(7, 0.27, 0.22, 0.4, 0.9, 0.2, 67), robe)
	# Scarves wrapped round the chest and neck, a loose end down the back.
	_part(RewardViews.prism(7, 0.28, 0.26, 0.12, 1.05, 0.5, 71), scarf_a)
	_part(RewardViews.prism(7, 0.24, 0.2, 0.12, 1.2, 0.9, 73), scarf_b)
	_part(_cube(Vector3(0.04, 0.5, 0.14)), scarf_a, Vector3(-0.24, 0.98, 0.05), Vector3(0, 0, 0.15))
	# The bandolier across the chest with its pouches.
	_part(_cube(Vector3(0.05, 0.75, 0.08)), leather, Vector3(0.27, 1.0, 0), Vector3(0.75, 0, 0))
	for k in 3:
		_part(
			_cube(Vector3(0.08, 0.09, 0.1)), pouch, Vector3(0.3, 0.8 + 0.14 * k, -0.18 + 0.15 * k)
		)
	for side in [-1.0, 1.0]:
		_part(
			_cube(Vector3(0.12, 0.52, 0.12)),
			robe,
			Vector3(0.06, 0.95, 0.33 * side),
			Vector3(0.1 * side, 0, -0.15)
		)
		_part(_cube(Vector3(0.09, 0.09, 0.09)), dark, Vector3(0.12, 0.68, 0.36 * side))
	# The head: a wrapped face with a slit for the eyes, the wide hat.
	_head_part(RewardViews.prism(6, 0.15, 0.14, 0.26, -0.1, 0.3, 79), scarf_b)
	_head_part(_cube(Vector3(0.04, 0.05, 0.2)), dark, Vector3(0.14, 0.05, 0))
	for side in [-1.0, 1.0]:
		_head_part(_cube(Vector3(0.02, 0.03, 0.04)), _eye_mat, Vector3(0.165, 0.05, 0.05 * side))
	_head_part(RewardViews.prism(10, 0.42, 0.4, 0.04, 0.17, 0.0, 83), hat)  # the brim
	_head_part(RewardViews.prism(6, 0.16, 0.13, 0.18, 0.2, 0.2, 89), hat)  # the crown
	_head_part(RewardViews.prism(6, 0.165, 0.165, 0.04, 0.21, 0.2, 0), scarf_a)  # its band
	_head.position = Vector3(0.02, 1.43, 0)


## Frozen Shore: a fur-wrapped fisher-trader, a hood rimmed in frost, a hook on a pole.
func _build_fisher() -> void:
	_eye_color = Color("#9FE3FF")
	var fur := _mat(Color("#D9D6CC"))
	var fur_dark := _mat(Color("#A9A49A"))
	var frost := _mat(Color("#CFEAF5"), 0.0, Color("#8FCFEA"), 0.25)
	var wood := _mat(Color("#6B5640"))
	var steel := _mat(Color("#9AA3AA"), 0.6)
	var dark := _mat(Color("#2E2A27"))
	_part(RewardViews.prism(8, 0.4, 0.36, 0.85, 0.0, 0.2, 97), fur)  # a bulky fur coat
	_part(RewardViews.prism(8, 0.36, 0.26, 0.42, 0.85, 0.3, 101), fur)
	_part(RewardViews.prism(8, 0.41, 0.41, 0.1, 0.18, 0.2, 103), fur_dark)  # its hem band
	_part(_cube(Vector3(0.06, 0.6, 0.12)), fur_dark, Vector3(0.37, 0.75, 0))  # the coat's front seam
	for side in [-1.0, 1.0]:
		_part(
			_cube(Vector3(0.16, 0.5, 0.16)),
			fur,
			Vector3(0.08, 0.92, 0.38 * side),
			Vector3(0.12 * side, 0, -0.1)
		)
		_part(_cube(Vector3(0.12, 0.12, 0.12)), fur_dark, Vector3(0.14, 0.64, 0.4 * side))
	# The pole with its hook, in the right hand.
	_part(
		_cube(Vector3(0.05, 2.0, 0.05)), wood, Vector3(0.16, 1.0, -0.42), Vector3(-0.04, 0, -0.04)
	)
	_part(_cube(Vector3(0.03, 0.2, 0.03)), steel, Vector3(0.22, 1.95, -0.44), Vector3(0, 0, 0.5))
	_part(_cube(Vector3(0.03, 0.14, 0.03)), steel, Vector3(0.3, 1.86, -0.44), Vector3(0, 0, -0.4))
	# The head: a fur hood rimmed in frost round a dark face.
	_head_part(RewardViews.prism(7, 0.23, 0.12, 0.38, -0.14, 0.3, 107), fur)
	_head_part(
		RewardViews.prism(8, 0.15, 0.15, 0.05, 0.0, 0.0, 109),
		frost,
		Vector3(0.15, 0.03, 0),
		Vector3(0, 0, PI / 2)
	)
	_head_part(_cube(Vector3(0.06, 0.18, 0.2)), dark, Vector3(0.14, 0.02, 0))
	for side in [-1.0, 1.0]:
		_head_part(_cube(Vector3(0.03, 0.03, 0.04)), _eye_mat, Vector3(0.175, 0.04, 0.05 * side))
	_head.position = Vector3(0.04, 1.4, 0)


## Starfall: a floating cloaked astral merchant, a star-map cape, small crystals orbiting it.
func _build_astral() -> void:
	_eye_color = Color("#F0E0FF")
	var cloak := _mat(Color("#2A2148"))
	var trim := _mat(Color("#D4B062"), 0.6)
	var star := _mat(Color("#E9C8FF"), 0.0, Color("#E9C8FF"), 1.4)
	var crystal := _mat(Color("#E9C8FF"), 0.0, Color("#C060F0"), 1.2)
	var void_mat := _mat(Color("#120E22"))
	var lift := 0.35
	_part(RewardViews.prism(8, 0.3, 0.42, 0.8, lift, 0.2, 113), cloak)  # the cloak flares down to a point
	_part(RewardViews.bipyramid(8, 0.3, 0.02, 0.3), cloak, Vector3(0, lift + 0.02, 0))
	_part(RewardViews.prism(8, 0.3, 0.22, 0.42, lift + 0.8, 0.3, 127), cloak)
	_part(RewardViews.prism(8, 0.43, 0.43, 0.04, lift + 0.76, 0.2, 131), trim)  # the cloak's gold band
	# The star-map cape: a wide panel down its back, dotted with stars.
	_part(
		_cube(Vector3(0.05, 0.95, 0.66)), cloak, Vector3(-0.3, lift + 0.6, 0), Vector3(0, 0, 0.12)
	)
	for k in 7:
		var at := Vector3(-0.34, lift + 0.25 + 0.12 * k, -0.24 + float((k * 5) % 7) * 0.08)
		_part(_cube(Vector3(0.02, 0.035, 0.035)), star, at)
	for side in [-1.0, 1.0]:
		_part(
			_cube(Vector3(0.11, 0.45, 0.11)),
			cloak,
			Vector3(0.1, lift + 0.85, 0.3 * side),
			Vector3(0.2 * side, 0, -0.3)
		)
	# The head: a deep hood with a void inside and two pale eyes, a gold circlet.
	_head_part(RewardViews.prism(6, 0.19, 0.04, 0.42, -0.14, 0.4, 137), cloak)
	_head_part(_cube(Vector3(0.06, 0.18, 0.2)), void_mat, Vector3(0.12, 0.0, 0))
	for side in [-1.0, 1.0]:
		_head_part(_cube(Vector3(0.03, 0.035, 0.04)), _eye_mat, Vector3(0.155, 0.03, 0.05 * side))
	_head_part(RewardViews.prism(8, 0.2, 0.2, 0.03, 0.12, 0.0, 0), trim)
	_head.position = Vector3(0.02, lift + 1.13, 0)
	# Three crystals orbit it at chest height.
	_orbit = Node3D.new()
	_orbit.position = Vector3(0, lift + 0.95, 0)
	_body.add_child(_orbit)
	for k in 3:
		var a := TAU * k / 3.0
		var c := MeshInstance3D.new()
		c.mesh = RewardViews.bipyramid(4, 0.05, 0.09, 0.09)
		c.material_override = crystal
		c.position = Vector3(cos(a) * 0.55, 0.12 * sin(a * 2.0), sin(a) * 0.55)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_orbit.add_child(c)


# --- helpers ---------------------------------------------------------------------------------------------------


func _mat(
	c: Color, metallic: float = 0.0, glow: Color = Color.BLACK, glow_energy: float = 0.0
) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = 0.75 if metallic == 0.0 else 0.45
	m.vertex_color_use_as_albedo = true
	if glow_energy > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = glow_energy
	_mats.append(m)
	return m


static func _cube(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _part(
	mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	_body.add_child(mi)
	return mi


func _head_part(
	mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mi := _part(mesh, mat, at, rot)
	_body.remove_child(mi)
	_head.add_child(mi)
	if mat == _eye_mat:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
