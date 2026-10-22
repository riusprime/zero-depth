class_name ShopStallView
extends Node3D
## The shop's tent stall (v0.8.0 SR, owner O13: "it will be like in a tent shop with some stuff"), drawn where the
## sim's shop room put it (WorldReader.shop_piece): a patched canvas awning on crooked poles over a wooden counter,
## a hanging lantern's warm light, crates and sacks under it, goods on the counter, and the biome's vendor
## (ShopVendor) behind the counter. The dressing's own shop pieces are drawn too: goods on crates (shop_wares), sacks
## (shop_sack) and lantern posts (shop_lantern, each with its warm light). The owner's models replace the stand-ins
## when the manifest lists them (ShopModels: shop_tent, shop_wares, shop_vendor_<biome>). The owner's desert stall
## (shop_tent, every biome until their own) has its vendor and goods fused into the mesh: over it the code vendor is
## hidden, the counter's stand-in goods are left out, and the lantern shows the vendor's reactions (brighter on a sale,
## red on a refusal).
## It reads only: the vendor turns to you within NEAR_M of the counter, nods when a purchase or sale lands and shakes
## its head on a refusal (the reader's shop state, as the terminal's cues), and the lantern brightens while you are in
## reach. Reduced motion is the vendor's (ShopVendor). The stall's front (the counter) faces local +X, turned to the
## sim's facing (SimPlane.yaw_of(shop_angle)), its origin the centre of the stall's footprint.

## The vendor turns to you within this distance of the counter (m).
const NEAR_M := 7.0
const LANTERN := Color("#FFB45C")
const LANTERN_ENERGY := 1.5
const LANTERN_RANGE := 6.5
const POST_ENERGY := 1.1
const POST_RANGE := 5.0
## The awning's eaves (m) and the canvas walls' height.
const AWNING_FRONT := 2.6
const AWNING_BACK := 2.3
const WALL_H := 0.95
## The canvas, its stripe, its patches and the wood, per biome (the tent is re-dressed per biome, ART_LIST §1).
const LOOKS := {
	&"ruins": ["#A08F6A", "#6E7B5C", "#7A5C44", "#6B4A30"],
	&"night_rocks": ["#6F7A6E", "#3F4A44", "#8A8F7A", "#4F3D2C"],
	&"red_canyon": ["#C8643A", "#E8C27A", "#8E3E24", "#7A5232"],
	&"frozen_shore": ["#B9C7D0", "#6F8FA8", "#E6EEF8", "#6B5640"],
	&"starfall": ["#3A2E66", "#D4B062", "#5C3E8E", "#3E3550"],
}
const SALE_ACTIONS := [
	WorldReader.SHOP_BUY,
	WorldReader.SHOP_HEAL,
	WorldReader.SHOP_REROLL,
	WorldReader.SHOP_SELL,
	WorldReader.SHOP_SALVAGE,
]

var root: Node3D
var vendor: ShopVendor
var biome := &"ruins"
## True when the owner's tent model is drawn (ShopModels).
var tent_from_model := false
var _lantern: OmniLight3D
var _lantern_mat := StandardMaterial3D.new()
var _post_lights: Array[OmniLight3D] = []
var _mats: Array[StandardMaterial3D] = []
var _seen_tick := -1
var _denied_tick := -1
var _hot := false
var _counter := Vector2.ZERO
var _t := 0.0


func _init() -> void:
	name = "ShopStall"
	_lantern_mat.albedo_color = LANTERN
	_lantern_mat.emission_enabled = true
	_lantern_mat.emission = LANTERN
	_lantern_mat.emission_energy_multiplier = 2.0


## Builds the stall from the reader's shop pieces, in biome `p_biome` (once; it never moves).
func setup(reader: WorldReader, p_biome: StringName) -> void:
	biome = p_biome if LOOKS.has(p_biome) else &"ruins"
	_counter = reader.shop_pos()
	var angle := reader.shop_angle()
	var counter := {}
	var tent := {}
	for i in reader.shop_piece_count():
		var p := reader.shop_piece(i)
		if p["piece"] == &"shop_counter" and counter.is_empty():
			counter = p
		elif p["piece"] == &"shop_tent" and tent.is_empty():
			tent = p
	var foot := _bounds(counter).merge(_bounds(tent))
	root = Node3D.new()
	root.name = "Stall"
	root.position = SimPlane.to_3d(foot.get_center())
	root.rotation.y = SimPlane.yaw_of(angle)
	add_child(root)
	var front := Kin.dir(angle)
	var depth_c: float = (counter["size"] as Vector2).y if not counter.is_empty() else 0.8
	var counter_x := (_counter - foot.get_center()).dot(front)
	var model := ShopModels.get_model(&"shop_tent")
	if model.is_empty():
		_build_tent(foot, front, counter_x, depth_c)
	else:
		tent_from_model = true
		var mi := MeshInstance3D.new()
		mi.mesh = model["mesh"]
		if model["material"] != null:
			mi.material_override = model["material"]
		root.add_child(mi)
	_add_lantern_light(Vector3(counter_x - 0.1, 1.75, 0.0))
	vendor = ShopVendor.new()
	vendor.position = Vector3(counter_x - depth_c * 0.5 - 0.42, 0, 0)
	root.add_child(vendor)
	vendor.setup(biome)
	# v0.8.0 SR: the owner's stall has its vendor fused into the mesh (no piece to cut out), so the code vendor stays
	# hidden over it; it still runs (its reactions are read by the lantern below) and shows again with a stall model
	# that has no vendor of its own.
	vendor.visible = not tent_from_model
	for i in reader.shop_piece_count():
		var p := reader.shop_piece(i)
		if tent_from_model and p.get("on", &"") in [&"shop_counter", &"shop_tent"]:
			continue  # the owner's stall has its own goods and sacks
		match p["piece"]:
			&"shop_wares":
				add_child(_placed(p, _wares()))
			&"shop_sack":
				add_child(_placed(p, _sack()))
			&"shop_lantern":
				add_child(_placed(p, _lantern_post()))


func sync(reader: WorldReader) -> void:
	if root == null:
		return
	_hot = reader.shop_in_reach() or reader.shop_open()
	var s := reader.shop()
	var t: int = s["last_tick"]
	if t != _seen_tick:
		_seen_tick = t
		if t >= 0 and int(s["last_action"]) in SALE_ACTIONS:
			vendor.nod()
	var d: int = s["denied_tick"]
	if d != _denied_tick:
		_denied_tick = d
		if d >= 0:
			vendor.shake()
	var you := reader.player_pos()
	if Kin.length(you - _counter) <= NEAR_M:
		vendor.face(root.to_local(SimPlane.to_3d(you)) if root.is_inside_tree() else _local(you))
	else:
		vendor.face(null)


func hot() -> bool:
	return _hot


## Glowing and body materials (tests check the glowing ones keep emission on from creation).
func materials() -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = [_lantern_mat]
	out.append_array(_mats)
	if vendor != null:
		out.append_array(vendor.materials())
	return out


## The lantern's light energy and colour now (tests: the reactions it shows for a fused vendor).
func lantern_state() -> Array:
	return [_lantern.light_energy, _lantern.light_color]


func lantern() -> OmniLight3D:
	return _lantern


func light_count() -> int:
	return 1 + _post_lights.size()


func _process(delta: float) -> void:
	if root == null:
		return
	_t += delta
	var flicker := 1.0 if ViewPrefs.reduced_motion else 0.94 + 0.06 * sin(_t * 7.3) * sin(_t * 2.9)
	var energy := LANTERN_ENERGY * (1.35 if _hot else 1.0) * flicker
	# The lantern answers for a vendor that can't move (the owner's fused one): brighter on a sale, red on a refusal.
	var color := LANTERN
	if vendor.nodding():
		energy *= 1.6
	elif vendor.shaking():
		color = LANTERN.lerp(ShopVendor.DENY_GLOW, 0.75)
	_lantern.light_energy = energy
	_lantern.light_color = color
	_lantern_mat.emission = color
	_lantern_mat.emission_energy_multiplier = 2.0 * energy / LANTERN_ENERGY
	for l in _post_lights:
		l.light_energy = POST_ENERGY * flicker


## A sim point in the stall's frame (for a reader synced before the view is in the tree).
func _local(p: Vector2) -> Vector3:
	return root.transform.affine_inverse() * SimPlane.to_3d(p)


## A shop piece's footprint on the sim plane (its size turned by its axis-aligned angle).
static func _bounds(p: Dictionary) -> Rect2:
	if p.is_empty():
		return Rect2()
	var size: Vector2 = p["size"]
	var a := int(p["angle"]) & 4095
	if a % 2048 != 0:
		size = Vector2(size.y, size.x)
	var c: Vector2 = p["pos"]
	return Rect2(c - size * 0.5, size)


## A drawn piece at its sim spot, turned and scaled to its footprint, standing on what it stands on.
func _placed(p: Dictionary, node: Node3D) -> Node3D:
	var size: Vector2 = p["size"]
	var y := 0.0
	var under: StringName = p.get("on", &"")
	if under != &"" and under != &"shop_tent":
		var h := float(p.get("on_height", -1.0))
		if h <= 0.0:
			h = float(KitModels.SPECS.get(under, {"height": 1.0})["height"])
		y = h
	node.position = SimPlane.to_3d(p["pos"], y)
	node.rotation.y = SimPlane.yaw_of(int(p["angle"]))
	var natural: Vector2 = node.get_meta("foot", Vector2.ONE)
	if bool(p["solid"]):
		natural = size  # a lantern post keeps its size; its footprint is its post
	var k := Vector2(size.x / natural.x, size.y / natural.y)
	var up := minf(k.x, k.y)
	if p["piece"] == &"shop_lantern":
		up = float(p["height"]) / 2.2 if float(p["height"]) > 0.0 else 1.0
	node.scale = Vector3(k.x, up, k.y)
	return node


# --- the stand-ins ---------------------------------------------------------------------------------------------


## The stall: counter, crooked poles, a sloped patched awning, low back and side canvas, a rug, crates and the hanging
## lantern, filling the footprint (x front to back, z across).
func _build_tent(foot: Rect2, front: Vector2, counter_x: float, depth_c: float) -> void:
	var look: Array = LOOKS[biome]
	var canvas := _mat(Color(look[0]))
	var stripe := _mat(Color(look[1]))
	var patch := _mat(Color(look[2]))
	var wood := _mat(Color(look[3]))
	var wood_dark := _mat(Color(look[3]).darkened(0.35))
	var half_d := (foot.size.x if absf(front.x) > 0.5 else foot.size.y) * 0.5
	var half_w := (foot.size.y if absf(front.x) > 0.5 else foot.size.x) * 0.5
	var back := -half_d
	# The counter: a plank box, a thicker top with an overhang, dark front boards.
	_box(Vector3(depth_c, 0.94, half_w * 2.0), Vector3(counter_x, 0.47, 0), wood)
	_box(
		Vector3(depth_c + 0.08, 0.07, half_w * 2.0 + 0.04), Vector3(counter_x, 0.975, 0), wood_dark
	)
	for k in 4:
		var z := -half_w + (k + 0.5) * half_w * 0.5
		_box(
			Vector3(0.03, 0.8, half_w * 0.46),
			Vector3(counter_x + depth_c * 0.5 + 0.01, 0.46, z),
			wood_dark
		)
	# The crooked poles: taller at the front, each leaning a little its own way.
	var poles := [
		[half_d - 0.06, half_w - 0.06, 2.6, 0.05, -0.04],
		[half_d - 0.06, -half_w + 0.06, 2.55, -0.06, 0.05],
		[back + 0.06, half_w - 0.06, 2.3, 0.04, 0.06],
		[back + 0.06, -half_w + 0.06, 2.32, -0.05, -0.03],
	]
	for p: Array in poles:
		var pole := _box(Vector3(0.09, p[2], 0.09), Vector3(p[0], float(p[2]) * 0.5, p[1]), wood)
		pole.rotation = Vector3(p[3], 0, p[4])
	# The awning: one patched slope rising to the front (2.3 m at the back, 2.6 m over the counter), so the iso camera
	# sees the vendor under it from the front and over the low back; a striped valance, sewn-on patches.
	var front_eave := Vector2(half_d + 0.05, AWNING_FRONT)
	var back_eave := Vector2(back - 0.03, AWNING_BACK)
	_slope(back_eave, front_eave, half_w + 0.12, canvas)
	for k in 7:
		var z := -half_w - 0.06 + (k + 0.5) * (half_w * 2.0 + 0.12) / 7.0
		_box(
			Vector3(0.03, 0.18, (half_w * 2.0) / 7.0 - 0.02),
			Vector3(front_eave.x, AWNING_FRONT - 0.1, z),
			stripe if k % 2 == 0 else canvas
		)
	var tilt := atan2(front_eave.y - back_eave.y, front_eave.x - back_eave.x)
	for q: Array in [[0.55, 0.6, 0.5], [0.15, -0.75, 0.35], [-0.6, 0.35, 0.42]]:
		var along: float = q[0]
		var y := lerpf(
			back_eave.y, front_eave.y, (along - back_eave.x) / (front_eave.x - back_eave.x)
		)
		var pm := _box(
			Vector3(float(q[2]), 0.02, float(q[2]) * 0.8), Vector3(along, y + 0.035, q[1]), patch
		)
		pm.rotation.z = tilt
	# The low back and side walls of canvas (waist high, so the vendor shows from behind too), a rug on the floor.
	_box(Vector3(0.04, WALL_H, half_w * 2.0), Vector3(back + 0.03, WALL_H * 0.5, 0), canvas)
	for side in [-1.0, 1.0]:
		var span := counter_x - depth_c * 0.5 - back
		_box(
			Vector3(span, WALL_H, 0.04),
			Vector3(back + span * 0.5, WALL_H * 0.5, (half_w - 0.02) * side),
			stripe
		)
	_box(
		Vector3(counter_x - depth_c * 0.5 - back - 0.1, 0.02, half_w * 1.6),
		Vector3((back + counter_x - depth_c * 0.5) * 0.5, 0.01, 0),
		patch
	)
	# Crates in the back corners, a small stack of stock.
	for side in [-1.0, 1.0]:
		_box(Vector3(0.5, 0.5, 0.5), Vector3(back + 0.35, 0.25, (half_w - 0.35) * side), wood)
		var top := _box(
			Vector3(0.38, 0.36, 0.38), Vector3(back + 0.36, 0.68, (half_w - 0.38) * side), wood_dark
		)
		top.rotation.y = 0.3 * side
	# The hanging lantern under the front eave: a cord, a faceted cage and its glow.
	_box(Vector3(0.015, 0.5, 0.015), Vector3(counter_x + 0.05, 2.25, half_w * 0.55), wood_dark)
	var cage := MeshInstance3D.new()
	cage.mesh = RewardViews.prism(6, 0.09, 0.07, 0.2, 0.0, 0.3, 0)
	cage.material_override = _lantern_mat
	cage.position = Vector3(counter_x + 0.05, 1.8, half_w * 0.55)
	cage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cage)


func _add_lantern_light(at: Vector3) -> void:
	_lantern = OmniLight3D.new()
	_lantern.name = "Lantern"
	_lantern.light_color = LANTERN
	_lantern.light_energy = LANTERN_ENERGY
	_lantern.omni_range = LANTERN_RANGE
	_lantern.omni_attenuation = 1.4
	_lantern.position = at
	root.add_child(_lantern)


## Goods for the counter (or a crate): bottles, a scroll case, glowing crystal shards in a crate, a small chest.
## Width along x (1.0 m), depth z (0.6 m), front +Z; the owner's shop_wares model when listed.
func _wares() -> Node3D:
	var n := Node3D.new()
	n.set_meta("foot", Vector2(1.0, 0.6))
	var model := ShopModels.get_model(&"shop_wares")
	if not model.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = model["mesh"]
		if model["material"] != null:
			mi.material_override = model["material"]
		n.add_child(mi)
		return n
	var glass := _mat(Color("#5FA87A"), Color("#5FD08A"), 0.4)
	var glass_b := _mat(Color("#7A5FB0"), Color("#9A7AE0"), 0.4)
	var leather := _mat(Color("#6A4A30"))
	var wood := _mat(Color("#8A6440"))
	var gold := _mat(Color("#C9A24A"))
	var crystal := ShardViews.shared_material()
	for k in 3:  # bottles
		var b := MeshInstance3D.new()
		b.mesh = RewardViews.prism(6, 0.05, 0.035, 0.22 + 0.04 * k, 0.0, 0.0, 0)
		b.material_override = glass if k != 1 else glass_b
		b.position = Vector3(-0.42 + 0.1 * k, 0, 0.12 - 0.08 * k)
		n.add_child(b)
	var scroll := MeshInstance3D.new()  # a scroll case lying along the counter
	scroll.mesh = RewardViews.prism(6, 0.05, 0.05, 0.42, 0.0, 0.0, 151)
	scroll.material_override = leather
	scroll.rotation = Vector3(0, 0, PI / 2)
	scroll.position = Vector3(0.0, 0.05, 0.18)
	n.add_child(scroll)
	var box := _node_box(n, Vector3(0.28, 0.14, 0.24), Vector3(0.05, 0.07, -0.12), wood)  # the crystal crate
	box.rotation.y = 0.2
	for k in 3:
		var c := MeshInstance3D.new()
		c.mesh = RewardViews.bipyramid(4, 0.04, 0.12 + 0.03 * k, 0.02)
		c.material_override = crystal
		c.position = Vector3(-0.03 + 0.07 * k, 0.14, -0.12 + 0.03 * (k - 1))
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(c)
	_node_box(n, Vector3(0.26, 0.16, 0.2), Vector3(0.36, 0.08, 0.05), wood)  # the small chest
	_node_box(n, Vector3(0.27, 0.06, 0.21), Vector3(0.36, 0.19, 0.05), leather)
	_node_box(n, Vector3(0.04, 0.05, 0.02), Vector3(0.36, 0.14, 0.16), gold)
	return n


## A sack of stock: a squat faceted bag tied at the neck (0.6 m across, 0.5 m tall).
func _sack() -> Node3D:
	var n := Node3D.new()
	n.set_meta("foot", Vector2(0.6, 0.6))
	var cloth := _mat(Color("#B49A6E"))
	var cord := _mat(Color("#5A4632"))
	var a := MeshInstance3D.new()
	a.mesh = RewardViews.prism(7, 0.27, 0.22, 0.34, 0.0, 0.25, 157)
	a.material_override = cloth
	n.add_child(a)
	var b := MeshInstance3D.new()
	b.mesh = RewardViews.prism(7, 0.22, 0.07, 0.1, 0.34, 0.2, 163)
	b.material_override = cloth
	n.add_child(b)
	var c := MeshInstance3D.new()
	c.mesh = RewardViews.prism(6, 0.075, 0.075, 0.04, 0.42, 0.0, 0)
	c.material_override = cord
	n.add_child(c)
	var top := MeshInstance3D.new()
	top.mesh = RewardViews.prism(5, 0.06, 0.02, 0.08, 0.46, 0.4, 167)
	top.material_override = cloth
	n.add_child(top)
	return n


## A lantern post: a crooked pole, a crossbar, a hanging lantern and its warm light (2.2 m tall).
func _lantern_post() -> Node3D:
	var n := Node3D.new()
	var look: Array = LOOKS[biome]
	var wood := _mat(Color(look[3]))
	var pole := _node_box(n, Vector3(0.12, 2.2, 0.12), Vector3(0, 1.1, 0), wood)
	pole.rotation = Vector3(0.04, 0, -0.05)
	_node_box(n, Vector3(0.55, 0.07, 0.07), Vector3(0.22, 2.1, 0), wood)
	_node_box(n, Vector3(0.015, 0.2, 0.015), Vector3(0.42, 1.97, 0), wood)
	var cage := MeshInstance3D.new()
	cage.mesh = RewardViews.prism(6, 0.08, 0.06, 0.18, 0.0, 0.3, 0)
	cage.material_override = _lantern_mat
	cage.position = Vector3(0.42, 1.7, 0)
	cage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(cage)
	var l := OmniLight3D.new()
	l.light_color = LANTERN
	l.light_energy = POST_ENERGY
	l.omni_range = POST_RANGE
	l.omni_attenuation = 1.4
	l.position = Vector3(0.42, 1.65, 0)
	n.add_child(l)
	_post_lights.append(l)
	return n


# --- helpers ---------------------------------------------------------------------------------------------------


func _mat(c: Color, glow: Color = Color.BLACK, glow_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	m.vertex_color_use_as_albedo = true
	if glow_energy > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = glow_energy
	_mats.append(m)
	return m


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	return _node_box(root, size, at, mat)


static func _node_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## A canvas slope from a to b (x, y in the stall's frame), `half_w` either side across.
func _slope(a: Vector2, b: Vector2, half_w: float, mat: Material) -> void:
	var d := b - a
	var slab := _box(
		Vector3(d.length(), 0.05, half_w * 2.0),
		Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, 0),
		mat
	)
	slab.rotation.z = atan2(d.y, d.x)
