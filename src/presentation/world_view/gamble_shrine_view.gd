class_name GambleShrineView
extends Node3D
## The gamble shrine (v0.3.0 L19): an angular robotic obelisk on a hexagonal plinth, split by a window where a
## glowing core crystal floats and turns, with light strips up its faces and two fins. The next price floats above
## it (shard gem + number), red when you can't afford it. A use spins the core fast for the card's spin and lands
## with a flash; a refused use shakes it and dims the core. Glowing materials have emission on from creation and the
## body is ActorViews.flashable: only energies and the light change at runtime (flash-safe). Reads only.
## v0.6.0 Step SR: with the v0.5.9 look (WorldViewRoot sets kit_model when the floor has a lighting mood) the body is
## the owner's model (assets/models/kit/gamble_shrine.glb, a slot-machine shrine under a magenta crystal, through
## KitModels like the kit: scaled, bottom on the floor, LODs), its front turned to the camera and lined up with the
## sim's square footprint (Gamble.collider, turned 45°). The cues stay: shards orbit its crystal (spinning fast on a
## use), the crystal's light brightens in reach, the body flashes on the landing and shakes on a refusal, the price
## floats above. A missing model draws the code-built obelisk (L15). Presentation only: the sim's spot and footprint
## are unchanged.

const CORE := Color("#3FF2D0")
const METAL := Color("#3B4250")
const METAL_TOP := Color("#59606E")
const DENY := Color("#FF4A3D")
const PRICE_OK := Color("#F4F1EA")
const PRICE_POOR := Color("#FF4A3D")
## The price shows within this distance (m): from across the start hall.
const PRICE_NEAR_M := 9.0
const CORE_Y := 1.58
const CORE_ENERGY := 2.4
const LIGHT_ENERGY := 1.1
const SHAKE_S := 0.35
const LAND_FLASH_S := 0.35
## The owner's model (KitModels id) and its look.
const MODEL_ID := &"gamble_shrine"
## The model's front (its slot window, glTF +Z) turned to the iso camera (IsoRig.YAW_DEG), which also lines its
## sides up with Gamble.collider's square (turned 45°).
const MODEL_YAW := PI * 0.25
## Where the model's crystal sits in its unit box (x and z from the centre, y up from the floor; read from the mesh:
## the vertices of its top band).
const MODEL_CRYSTAL := Vector3(0.07, 0.86, -0.2)
## The model's crystal is magenta: its glow, shards and light take the shrine's map colour (MinimapStyle.SHRINE).
const MODEL_GLOW := Color("#D46BFF")
## How far the shards orbit the model's crystal (m).
const MODEL_ORBIT_M := 0.3

var root: Node3D
var price_label: Label3D
## Use the owner's model (set before setup; WorldViewRoot turns it on with the v0.5.9 look).
var kit_model := false
var _body: Node3D
var _core: Node3D
var _light: OmniLight3D
var _core_mat := StandardMaterial3D.new()
var _strip_mat := StandardMaterial3D.new()
var _metal_mats: Array[StandardMaterial3D] = []
var _t := 0.0
var _seen_tick := -1
var _denied_tick := -1
var _spin_left := 0.0
var _flash_left := 0.0
var _shake_left := 0.0
var _hot := false
var _glow := CORE
var _core_y := CORE_Y
var _model: MeshInstance3D


func _init() -> void:
	name = "GambleShrine"
	_core_mat.albedo_color = CORE
	_core_mat.emission_enabled = true
	_core_mat.emission = CORE
	_core_mat.emission_energy_multiplier = CORE_ENERGY
	_strip_mat.albedo_color = CORE
	_strip_mat.emission_enabled = true
	_strip_mat.emission = CORE
	_strip_mat.emission_energy_multiplier = 1.4


## Builds the shrine at its sim position (once; the shrine never moves).
func setup(at: Vector2) -> void:
	root = null
	if kit_model:
		var piece := KitModels.get_piece(MODEL_ID)
		if not piece.is_empty():
			root = _make_model(piece)
	if root == null:
		root = make_shrine()
	root.position = SimPlane.to_3d(at)
	add_child(root)


func sync(reader: WorldReader) -> void:
	if root == null:
		return
	var p := reader.player_pos()
	_hot = reader.gamble_in_reach()
	price_label.text = str(reader.gamble_price())
	var ok := reader.gamble_affordable() and not reader.gamble_exhausted()
	price_label.modulate = PRICE_OK if ok else PRICE_POOR
	price_label.visible = (
		reader.gamble_pos().distance_to(p) <= PRICE_NEAR_M and not reader.gamble_exhausted()
	)
	if reader.gamble_tick() != _seen_tick:
		_seen_tick = reader.gamble_tick()
		if _seen_tick >= 0:
			_spin_left = GambleCard.SPIN_S
	if reader.gamble_denied_tick() != _denied_tick:
		_denied_tick = reader.gamble_denied_tick()
		if _denied_tick >= 0:
			_shake_left = SHAKE_S


## Spinning (a use is being replayed).
func spinning() -> bool:
	return _spin_left > 0.0


func shaking() -> bool:
	return _shake_left > 0.0


## The glowing materials and the flashable body materials (tests check they keep their shader).
## True when the body is the owner's model (false: the code-built obelisk).
func uses_model() -> bool:
	return _model != null


## The owner's model as placed (null with the code-built obelisk).
func model() -> MeshInstance3D:
	return _model


func materials() -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = [_core_mat, _strip_mat]
	out.append_array(_metal_mats)
	return out


func _process(delta: float) -> void:
	if root == null:
		return
	_t += delta
	var energy := CORE_ENERGY * (1.35 if _hot else 1.0)
	var turn := 0.8 if not _hot else 1.4
	if _spin_left > 0.0:
		var before := _spin_left
		_spin_left = maxf(0.0, _spin_left - delta)
		var k := _spin_left / GambleCard.SPIN_S
		turn = 3.0 + 22.0 * k
		energy = CORE_ENERGY * (1.6 + 0.8 * absf(sin(_t * 30.0)))
		if before > 0.0 and _spin_left == 0.0:
			_flash_left = LAND_FLASH_S
	_core.rotation.y += turn * delta
	_core.position.y = _core_y + sin(_t * 2.2) * 0.05
	var flash := 0.0
	if _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
		flash = _flash_left / LAND_FLASH_S
		energy = CORE_ENERGY * (1.0 + 2.5 * flash)
	for m in _metal_mats:
		m.emission_energy_multiplier = 0.9 * flash
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		var s := _shake_left / SHAKE_S
		_body.position.x = sin(_shake_left * 70.0) * 0.07 * s
		energy = CORE_ENERGY * (1.0 - 0.7 * s)
		_light.light_color = _glow.lerp(DENY, s)
	else:
		_body.position.x = 0.0
		_light.light_color = _glow
	_core_mat.emission_energy_multiplier = energy
	_light.light_energy = LIGHT_ENERGY * energy / CORE_ENERGY


## The shrine model: plinth, obelisk split by the core window, strips, fins, the core, its light and the price.
func make_shrine() -> Node3D:
	var n := Node3D.new()
	_body = Node3D.new()
	n.add_child(_body)
	var metal := _metal(METAL)
	var top := _metal(METAL_TOP)
	_body.add_child(_mesh(RewardViews.prism(6, 0.78, 0.7, 0.18, 0.0, 0.0, 3), metal))
	_body.add_child(_mesh(RewardViews.prism(4, 0.56, 0.5, 0.2, 0.18, 0.0, 5), top))
	_body.add_child(_mesh(RewardViews.prism(4, 0.42, 0.33, 0.9, 0.38, 0.0, 7), metal))
	_body.add_child(_mesh(RewardViews.prism(4, 0.36, 0.3, 0.08, 1.28, 0.0, 9), top))
	_body.add_child(_mesh(RewardViews.prism(4, 0.3, 0.32, 0.08, 1.86, 0.0, 11), top))
	_body.add_child(_mesh(RewardViews.prism(4, 0.32, 0.05, 0.78, 1.94, 0.0, 13), metal))
	# The window's frame: two posts beside the core, joining the halves.
	for side in [-1.0, 1.0]:
		_body.add_child(_box(Vector3(0.08, 0.52, 0.16), Vector3(0.27 * side, 1.6, 0.0), 0.0, top))
		# Fins: angular plates leaning out from the lower body.
		_body.add_child(
			_box(Vector3(0.06, 0.7, 0.34), Vector3(0.44 * side, 0.82, 0.0), -16.0 * side, metal)
		)
	# Light strips up the four faces of the lower body and the tip.
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var dir := Vector3(cos(a), 0, sin(a))
		var strip := _box(
			Vector3(0.05, 0.62, 0.05), dir * 0.27 + Vector3(0, 0.86, 0), 0.0, _strip_mat
		)
		strip.rotation.y = -a
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(strip)
		var tip := _box(Vector3(0.04, 0.3, 0.04), dir * 0.2 + Vector3(0, 2.12, 0), 0.0, _strip_mat)
		tip.rotation.y = -a
		tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(tip)
	_core = Node3D.new()
	_core.position.y = CORE_Y
	n.add_child(_core)
	var crystal := _mesh(RewardViews.bipyramid(4, 0.17, 0.24, 0.24), _core_mat)
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core.add_child(crystal)
	for k in 3:
		var a := TAU * k / 3.0
		var bit := _mesh(RewardViews.bipyramid(3, 0.035, 0.06, 0.06), _core_mat)
		bit.position = Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2)
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_core.add_child(bit)
	_light = OmniLight3D.new()
	_light.light_color = CORE
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = 4.0
	_light.position.y = CORE_Y
	n.add_child(_light)
	_add_price(n)
	return n


## The owner's model (v0.6.0 Step SR) at its natural size (KitModels: bottom on the floor, centred), turned to the
## camera; shards orbit its crystal with the crystal's light; the price floats above.
func _make_model(piece: Dictionary) -> Node3D:
	_glow = MODEL_GLOW
	for m in [_core_mat, _strip_mat]:
		m.albedo_color = _glow
		m.emission = _glow
	var size: Vector3 = piece["size"]
	var n := Node3D.new()
	_body = Node3D.new()
	_body.rotation.y = MODEL_YAW
	n.add_child(_body)
	var mat := (piece["material"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	ActorViews.flashable(mat)
	mat.emission = _glow.lerp(Color.WHITE, 0.6)
	_metal_mats.append(mat)
	_model = _mesh(piece["mesh"], mat)
	_model.name = "Model"
	_model.scale = size
	_body.add_child(_model)
	var crystal := Basis(Vector3.UP, MODEL_YAW) * (MODEL_CRYSTAL * size)
	_core_y = crystal.y
	_core = Node3D.new()
	_core.position = crystal
	n.add_child(_core)
	for k in 3:
		var a := TAU * k / 3.0
		var bit := _mesh(RewardViews.bipyramid(3, 0.045, 0.08, 0.08), _core_mat)
		bit.position = Vector3(cos(a) * MODEL_ORBIT_M, 0.0, sin(a) * MODEL_ORBIT_M)
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_core.add_child(bit)
	_light = OmniLight3D.new()
	_light.light_color = _glow
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = 4.0
	_light.position = crystal
	n.add_child(_light)
	_add_price(n)
	return n


## The next price, floating above the shrine (hidden until near).
func _add_price(n: Node3D) -> void:
	price_label = Label3D.new()
	price_label.name = "Price"
	price_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	price_label.no_depth_test = true
	price_label.font_size = 80
	price_label.outline_size = 18
	price_label.pixel_size = 0.008
	price_label.position.y = 3.3
	price_label.visible = false
	n.add_child(price_label)
	var gem := _mesh(RewardViews.bipyramid(4, 0.08, 0.12, 0.12), ShardViews.shared_material())
	gem.position = Vector3(-0.55, 0.0, 0)
	price_label.add_child(gem)


func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.55
	m.roughness = 0.5
	m.vertex_color_use_as_albedo = true
	ActorViews.flashable(m)
	m.emission = CORE.lerp(Color.WHITE, 0.6)
	_metal_mats.append(m)
	return m


func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	return m


func _box(size: Vector3, pos: Vector3, roll_deg: float, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var m := _mesh(b, mat)
	m.position = pos
	m.rotation_degrees.z = roll_deg
	return m
