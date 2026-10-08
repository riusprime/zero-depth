class_name ShopTerminalView
extends Node3D
## The shop terminal (v0.5.0 SH): a low-poly vending console on a hexagonal plinth, in the game's metal and the
## shards' violet: a chamfered body, a slanted glowing screen facing the way in, a coin slot strip, two side posts
## with light caps, and a shard gem turning over the screen. It brightens while you stand in reach, pulses when a
## purchase or sale lands, and shakes (the screen going red) on a refusal. Glowing materials have emission on from
## creation and the body is ActorViews.flashable (flash-safe). Reads only. Its front (the screen) faces local +X,
## turned to the sim facing (SimPlane.yaw_of).

const GLOW := Color("#B48CFF")
const METAL := Color("#3B4250")
const METAL_TOP := Color("#59606E")
const DENY := Color("#FF4A3D")
const SCREEN_ENERGY := 1.8
const LIGHT_ENERGY := 1.0
const PULSE_S := 0.4
const SHAKE_S := 0.35
const GEM_Y := 2.05

var root: Node3D
var _body: Node3D
var _gem: Node3D
var _light: OmniLight3D
var _screen_mat := StandardMaterial3D.new()
var _strip_mat := StandardMaterial3D.new()
var _metal_mats: Array[StandardMaterial3D] = []
var _t := 0.0
var _seen_tick := -1
var _denied_tick := -1
var _pulse_left := 0.0
var _shake_left := 0.0
var _hot := false


func _init() -> void:
	name = "ShopTerminal"
	for m: StandardMaterial3D in [_screen_mat, _strip_mat]:
		m.albedo_color = GLOW
		m.emission_enabled = true
		m.emission = GLOW
	_screen_mat.emission_energy_multiplier = SCREEN_ENERGY
	_strip_mat.emission_energy_multiplier = 1.3


## Builds the terminal at its sim position, facing `angle` (once; it never moves).
func setup(at: Vector2, angle: int) -> void:
	root = make_terminal()
	root.position = SimPlane.to_3d(at)
	root.rotation.y = SimPlane.yaw_of(angle)
	add_child(root)


func sync(reader: WorldReader) -> void:
	if root == null:
		return
	_hot = reader.shop_in_reach() or reader.shop_open()
	var s := reader.shop()
	var t: int = s["last_tick"]
	if t != _seen_tick:
		_seen_tick = t
		if (
			t >= 0
			and (
				int(s["last_action"])
				in [
					WorldReader.SHOP_BUY,
					WorldReader.SHOP_HEAL,
					WorldReader.SHOP_REROLL,
					WorldReader.SHOP_SELL,
					WorldReader.SHOP_SALVAGE
				]
			)
		):
			_pulse_left = PULSE_S
	var d: int = s["denied_tick"]
	if d != _denied_tick:
		_denied_tick = d
		if d >= 0:
			_shake_left = SHAKE_S


func hot() -> bool:
	return _hot


func pulsing() -> bool:
	return _pulse_left > 0.0


func shaking() -> bool:
	return _shake_left > 0.0


## The glowing materials and the flashable body materials (tests check they keep their shader).
func materials() -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = [_screen_mat, _strip_mat]
	out.append_array(_metal_mats)
	return out


func _process(delta: float) -> void:
	if root == null:
		return
	_t += delta
	var energy := SCREEN_ENERGY * (1.4 if _hot else 1.0) * (0.92 + 0.08 * sin(_t * 3.0))
	_gem.rotation.y += (1.6 if _hot else 0.7) * delta
	_gem.position.y = GEM_Y + sin(_t * 2.0) * 0.05
	var flash := 0.0
	if _pulse_left > 0.0:
		_pulse_left = maxf(0.0, _pulse_left - delta)
		flash = _pulse_left / PULSE_S
		energy *= 1.0 + 1.8 * flash
	for m in _metal_mats:
		m.emission_energy_multiplier = 0.7 * flash
	var c := GLOW
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		var k := _shake_left / SHAKE_S
		_body.position.z = sin(_shake_left * 70.0) * 0.06 * k
		c = GLOW.lerp(DENY, k)
	else:
		_body.position.z = 0.0
	_screen_mat.emission = c
	_screen_mat.emission_energy_multiplier = energy
	_light.light_color = c
	_light.light_energy = LIGHT_ENERGY * energy / SCREEN_ENERGY


## The model: plinth, body, slanted screen, slot strip, side posts with caps, the gem and its light.
func make_terminal() -> Node3D:
	var n := Node3D.new()
	_body = Node3D.new()
	n.add_child(_body)
	var metal := _metal(METAL)
	var top := _metal(METAL_TOP)
	_body.add_child(_mesh(RewardViews.prism(6, 0.8, 0.72, 0.16, 0.0, 0.0, 21), metal))
	_body.add_child(_mesh(RewardViews.prism(4, 0.58, 0.52, 0.12, 0.16, PI / 4.0, 23), top))
	# The body: a chamfered block, its upper front cut back where the screen leans.
	_body.add_child(_box(Vector3(0.62, 0.95, 0.78), Vector3(-0.04, 0.75, 0), 0.0, metal))
	_body.add_child(_box(Vector3(0.44, 0.5, 0.78), Vector3(-0.13, 1.47, 0), 0.0, metal))
	_body.add_child(_box(Vector3(0.5, 0.08, 0.84), Vector3(-0.1, 1.74, 0), 0.0, top))
	# The screen: a dark bezel and the glowing face, leaning back toward the body.
	var bezel := _box(Vector3(0.07, 0.56, 0.7), Vector3(0.16, 1.42, 0), 22.0, top)
	_body.add_child(bezel)
	var screen := _box(Vector3(0.03, 0.46, 0.6), Vector3(0.2, 1.43, 0), 22.0, _screen_mat)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(screen)
	# The coin slot strip and the tray below it.
	var slot := _box(Vector3(0.03, 0.05, 0.36), Vector3(0.28, 0.98, 0), 0.0, _strip_mat)
	slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(slot)
	_body.add_child(_box(Vector3(0.16, 0.06, 0.44), Vector3(0.34, 0.62, 0), 0.0, top))
	for side in [-1.0, 1.0]:
		_body.add_child(_box(Vector3(0.12, 1.5, 0.12), Vector3(-0.1, 0.98, 0.46 * side), 0.0, top))
		var cap := _box(Vector3(0.14, 0.1, 0.14), Vector3(-0.1, 1.78, 0.46 * side), 0.0, _strip_mat)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(cap)
	_gem = Node3D.new()
	_gem.position = Vector3(0.05, GEM_Y, 0)
	n.add_child(_gem)
	var gem := _mesh(RewardViews.bipyramid(4, 0.12, 0.18, 0.18), ShardViews.shared_material())
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gem.add_child(gem)
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = 3.6
	_light.position = Vector3(0.6, 1.4, 0)
	n.add_child(_light)
	return n


func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.55
	m.roughness = 0.5
	m.vertex_color_use_as_albedo = true
	ActorViews.flashable(m)
	m.emission = GLOW.lerp(Color.WHITE, 0.6)
	_metal_mats.append(m)
	return m


func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	return m


func _box(size: Vector3, pos: Vector3, lean_deg: float, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var m := _mesh(b, mat)
	m.position = pos
	m.rotation_degrees.z = lean_deg
	return m
