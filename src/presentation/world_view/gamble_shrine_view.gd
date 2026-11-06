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
## v0.8.0 N14 (owner O72): a failed use cracks and fizzles (the core flickers out to red, the body jolts, sparks of
## light die off); a spent shrine (its wins given) goes dim, its shards slow, and the price above it reads "Spent".
## v0.9.0 BV (W71): per biome (InteractionLooks; set `biome` before setup): the owner's model (Fortune, or the gamble
## shrine) tinted and the biome's accent round its foot. Its golden (or magenta) glow is the same in every biome.

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
## v0.8.0 N14: a failed use's crack and fizzle (s), and a spent shrine's glow (a share of its core's).
## v0.9.5 SS (owner: "clearer and more visual when it fails"): the fizzle is a white flash, a gutter to red that dims
## the core to 20 %, and a recovery (their sum is FIZZLE_S); five cracks fade over CRACK_S; the body drops JOLT_M and
## springs back; twelve dark smoke puffs rise SMOKE_RISE_M.
const FLASH_S := 0.08
const GUTTER_S := 0.6
const RECOVER_S := 0.5
const FIZZLE_S := 1.18
const CRACK_S := 1.0
const CRACK_COUNT := 5
const CRACK_M := 1.0
const JOLT_M := 0.06
const JOLT_BACK_S := 0.3
const GUTTER_GLOW := 0.2
const PUFFS := 12
const SMOKE_RISE_M := 0.8
const SMOKE_S := 1.0
## v0.9.5 SS: a win floats the stat's icon over the shrine (metres above its foot, seconds), and a gold ring pulses.
const PRIZE_FROM_M := 1.4
const PRIZE_TO_M := 2.0
const PRIZE_S := 2.0
const PRIZE_POP_S := 0.2
const PRIZE_FADE_S := 0.5
const PRIZE_WIDTH_M := 0.45
const PRIZE_PX := 64
const PULSE_S := 0.3
const PULSE_GOLD := Color("#FFC94A")
const CRACK_TINT := Color("#FF3A2A")
const SPENT_GLOW := 0.15
const PRICE_SPENT := Color("#8A8F99")
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
## v0.9.0 SH (owner Q29b: "Today's gamble shrine becomes the Fortune Shrine"): the owner's Fortune Shrine model
## (ShopModels id, assets/models/devices/shrine_fortune.glb, 2.0 m tall as scripts/assets/mi2_prep.py prepares it), its
## front (+Z) turned to the camera like the gamble shrine's; the shards orbit FORTUNE_GLOW_Y of its height up, in its
## golden light. Without it, the v0.6.0 gamble shrine model, then the code-built obelisk.
const FORTUNE_ID := &"shrine_fortune"
const FORTUNE_GLOW := Color("#FFC94A")
const FORTUNE_GLOW_Y := 0.78

static var _crack_tex: ImageTexture

var root: Node3D
var price_label: Label3D
## Use the owner's model (set before setup; WorldViewRoot turns it on with the v0.5.9 look).
var kit_model := false
## v0.9.0 BV: the floor's biome (set before setup; WorldViewRoot sets it).
var biome := &""
var _body: Node3D
var _core: Node3D
var _light: OmniLight3D
var _core_mat := StandardMaterial3D.new()
var _strip_mat := StandardMaterial3D.new()
var _metal_mats: Array[StandardMaterial3D] = []
var _t := 0.0
var _seen_tick := -1
var _denied_tick := -1
var _fail_tick := -1
var _fizzle_left := 0.0
var _spent := false
var _spin_left := 0.0
var _flash_left := 0.0
var _shake_left := 0.0
var _hot := false
var _glow := CORE
var _core_y := CORE_Y
var _model: MeshInstance3D
## v0.9.5 SS: the effects layer's drawer feeds (smoke, gold ring) when VfxCore is on; the cracks and the prize.
var _crack: Sprite3D
var _crack_left := 0.0
var _puff_age := -1.0
var _pulse_left := 0.0
var _prize: Sprite3D
var _prize_age := 0.0
var _won_id := &""
var _core_col := CORE


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
	if kit_model:  # v0.9.0 SH: the owner's Fortune Shrine first, then his v0.6.0 gamble shrine
		var fortune := ShopModels.get_model(FORTUNE_ID)
		if not fortune.is_empty():
			root = _make_fortune(fortune)
	if kit_model and root == null:
		var piece := KitModels.get_piece(MODEL_ID)
		if not piece.is_empty():
			root = _make_model(piece)
	if root == null:
		root = make_shrine()
	InteractionLooks.add_accent(root, biome, 0.95, 0.0)  # v0.9.0 BV
	root.position = SimPlane.to_3d(at)
	add_child(root)


func sync(reader: WorldReader) -> void:
	if root == null:
		return
	var p := reader.player_pos()
	_hot = reader.gamble_in_reach()
	_spent = reader.gamble_spent()  # v0.8.0 N14: dimmed, "Spent" above it
	var gem := price_label.get_child(0) as Node3D
	if _spent:
		price_label.text = tr("UI_GAMBLE_SPENT_TAG")
		price_label.modulate = PRICE_SPENT
		gem.visible = false
	else:
		price_label.text = str(reader.gamble_price())
		var ok := reader.gamble_affordable() and not reader.gamble_exhausted()
		price_label.modulate = PRICE_OK if ok else PRICE_POOR
		gem.visible = true
	price_label.visible = (
		reader.gamble_pos().distance_to(p) <= PRICE_NEAR_M
		and (_spent or not reader.gamble_exhausted())
	)
	if reader.gamble_fail_tick() != _fail_tick:
		_fail_tick = reader.gamble_fail_tick()
		if _fail_tick >= 0:
			_fizzle_left = FIZZLE_S
			_crack_left = CRACK_S
			_puff_age = 0.0
	if reader.gamble_tick() != _seen_tick:
		_seen_tick = reader.gamble_tick()
		if _seen_tick >= 0:
			_spin_left = GambleCard.SPIN_S
			_won_id = reader.gamble_stat_id(reader.gamble_last_stat())
	if reader.gamble_denied_tick() != _denied_tick:
		_denied_tick = reader.gamble_denied_tick()
		if _denied_tick >= 0:
			_shake_left = SHAKE_S


## Spinning (a use is being replayed).
func spinning() -> bool:
	return _spin_left > 0.0


func shaking() -> bool:
	return _shake_left > 0.0


## v0.8.0 N14: a failed use's crack and fizzle is playing.
func fizzling() -> bool:
	return _fizzle_left > 0.0


## v0.9.5 SS: the cracks are showing.
func cracked() -> bool:
	return _crack != null and _crack.visible


## v0.9.5 SS: the prize icon floating over the shrine (null when none).
func prize() -> Sprite3D:
	return _prize


## v0.9.5 SS: the gold ring pulse is playing.
func pulsing() -> bool:
	return _pulse_left > 0.0


## v0.9.5 SS: how many smoke puffs the fail throws at the current Effects density.
static func puff_count() -> int:
	var share := 1.0
	match ViewPrefs.effects_density:
		"low":
			share = 0.35
		"medium":
			share = 0.65
	return maxi(1, int(round(PUFFS * share)))


## v0.8.0 N14: the shrine is spent and drawn dim.
func dimmed() -> bool:
	return _spent


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
	_core_col = _glow
	var energy := CORE_ENERGY * (1.35 if _hot else 1.0)
	var turn := 0.8 if not _hot else 1.4
	if _spent:  # v0.8.0 N14: its wins given, the shrine sleeps
		energy = CORE_ENERGY * SPENT_GLOW
		turn = 0.15
	if _spin_left > 0.0:
		var before := _spin_left
		_spin_left = maxf(0.0, _spin_left - delta)
		var k := _spin_left / GambleCard.SPIN_S
		turn = 3.0 + 22.0 * k
		energy = CORE_ENERGY * (1.6 + 0.8 * absf(sin(_t * 30.0)))
		if before > 0.0 and _spin_left == 0.0:
			_flash_left = LAND_FLASH_S
			_start_prize()
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
		_body.position.y = 0.0
		energy = CORE_ENERGY * (1.0 - 0.7 * s)
		_light.light_color = _glow.lerp(DENY, s)
	elif _fizzle_left > 0.0:  # v0.8.0 N14 / v0.9.5 SS: the crack and fizzle of a failed use
		_fizzle_left = maxf(0.0, _fizzle_left - delta)
		var e := FIZZLE_S - _fizzle_left
		var look := fizzle_look(e, not ViewPrefs.reduced_motion, _t)
		_body.position.x = 0.0
		_body.position.y = 0.0 if ViewPrefs.reduced_motion else -JOLT_M * jolt_at(e)
		energy = CORE_ENERGY * float(look["glow"])
		_core_col = look["color"]
		_light.light_color = _core_col
	else:
		_body.position.x = 0.0
		_body.position.y = 0.0
		_light.light_color = _glow
	_core_mat.emission = _core_col
	_core_mat.emission_energy_multiplier = energy
	_light.light_energy = LIGHT_ENERGY * energy / CORE_ENERGY
	_tick_fx(delta)


## v0.9.5 SS: the failed use's core at `e` seconds in: {"glow": share of CORE_ENERGY, "color"}. A white flash (FLASH_S),
## then it gutters to DENY red and dims to GUTTER_GLOW over GUTTER_S (flickering unless `flicker` is off), then recovers
## to its own light over RECOVER_S.
func fizzle_look(e: float, flicker: bool, t: float) -> Dictionary:
	if e < FLASH_S:
		return {"glow": 3.2, "color": Color.WHITE}
	var g := e - FLASH_S
	if g < GUTTER_S:
		var k := g / GUTTER_S
		var wob := 1.0
		if flicker:
			wob = 0.8 + 0.2 * signf(sin(t * 90.0))
		return {
			"glow": lerpf(1.6, GUTTER_GLOW, k) * wob,
			"color": Color.WHITE.lerp(DENY, minf(1.0, g / 0.12))
		}
	var r := minf(1.0, (g - GUTTER_S) / RECOVER_S)
	return {"glow": lerpf(GUTTER_GLOW, 1.0, r), "color": DENY.lerp(_glow, r)}


## v0.9.5 SS: the body's drop at `e` seconds into the fizzle, 0..1 of JOLT_M: down fast, then springing back.
static func jolt_at(e: float) -> float:
	if e < FLASH_S:
		return e / FLASH_S
	return maxf(0.0, 1.0 - (e - FLASH_S) / JOLT_BACK_S)


## v0.9.5 SS: advances the cracks, smoke, ring and prize.
func _tick_fx(delta: float) -> void:
	if _crack_left > 0.0:
		_crack_left = maxf(0.0, _crack_left - delta)
		if _crack == null:
			_crack = _make_crack()
			root.add_child(_crack)
		_crack.visible = _crack_left > 0.0
		_crack.position = _core.position
		_crack.modulate.a = _crack_left / CRACK_S
	if _puff_age >= 0.0:
		_puff_age += delta
		if _puff_age > SMOKE_S:
			_puff_age = -1.0
	_pulse_left = maxf(0.0, _pulse_left - delta)
	if _prize != null:
		_prize_age += delta
		if _prize_age >= PRIZE_S:
			_prize.queue_free()
			_prize = null
		else:
			var u := _prize_age / PRIZE_S
			_prize.position.y = lerpf(PRIZE_FROM_M, PRIZE_TO_M, u)
			var pop := minf(1.0, _prize_age / PRIZE_POP_S)
			_prize.scale = Vector3.ONE * lerpf(0.6, 1.0, pop)
			_prize.modulate.a = minf(1.0, (PRIZE_S - _prize_age) / PRIZE_FADE_S)


## v0.9.5 SS: the won stat's icon (GambleIcons, the card's symbol drawn once into a small viewport) floats up from the
## shrine; a gold ring pulses on its base.
func _start_prize() -> void:
	_pulse_left = PULSE_S
	if _won_id == &"" or root == null:
		return
	if _prize != null:
		_prize.queue_free()
	var vp := SubViewport.new()
	vp.size = Vector2i(PRIZE_PX, PRIZE_PX)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var icon := GambleIconView.new(_won_id, float(PRIZE_PX))
	icon.size = Vector2(PRIZE_PX, PRIZE_PX)
	vp.add_child(icon)
	_prize = Sprite3D.new()
	_prize.name = "Prize"
	_prize.add_child(vp)
	_prize.texture = vp.get_texture()
	_prize.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prize.no_depth_test = true
	_prize.fixed_size = false
	_prize.shaded = false
	_prize.pixel_size = PRIZE_WIDTH_M / float(PRIZE_PX)
	_prize.position.y = PRIZE_FROM_M
	_prize.scale = Vector3.ONE * 0.6
	_prize_age = 0.0
	root.add_child(_prize)


## v0.9.5 SS: five cracks across the core, a billboard drawn in code (dark red with a bright edge so it reads on any
## glow); shown for CRACK_S while it fades.
func _make_crack() -> Sprite3D:
	if _crack_tex == null:
		_crack_tex = _crack_texture()
	var sp := Sprite3D.new()
	sp.name = "Cracks"
	sp.texture = _crack_tex
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.no_depth_test = true
	sp.shaded = false
	sp.pixel_size = CRACK_M / float(_crack_tex.get_width())
	sp.visible = false
	return sp


static func _crack_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for k in CRACK_COUNT:
		var a := TAU * (float(k) + 0.25 * float(k % 2)) / CRACK_COUNT + 0.4
		var p := c
		var span := size * (0.34 + 0.08 * float((k * 3) % 4) / 3.0)
		var steps := 6
		for j in steps:
			var kink := (0.5 - float((k * 7 + j * 5) % 5) / 4.0) * 0.7
			var q := p + Vector2.from_angle(a + kink) * span / steps
			_line(img, p, q, CRACK_TINT, 3)
			p = q
	# The dark core of each crack on top of its red edge.
	for k in CRACK_COUNT:
		var a := TAU * (float(k) + 0.25 * float(k % 2)) / CRACK_COUNT + 0.4
		var p := c
		var span := size * (0.34 + 0.08 * float((k * 3) % 4) / 3.0)
		var steps := 6
		for j in steps:
			var kink := (0.5 - float((k * 7 + j * 5) % 5) / 4.0) * 0.7
			var q := p + Vector2.from_angle(a + kink) * span / steps
			_line(img, p, q, Color("#1A0202"), 1)
			p = q
	return ImageTexture.create_from_image(img)


static func _line(img: Image, a: Vector2, b: Vector2, col: Color, r: int) -> void:
	var n := int(a.distance_to(b)) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var x := int(p.x) + dx
				var y := int(p.y) + dy
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, col)


## v0.9.5 SS: the effects layer's drawer: the fail's dark smoke rising off the core and the win's gold ring on the foot.
func draw_fx(layer: VfxCore) -> void:
	if root == null or not is_inside_tree():
		return
	var base := root.global_position
	if _puff_age >= 0.0:
		var u := _puff_age / SMOKE_S
		for k in puff_count():
			var h1 := VfxCore.h(k + 3, 17) - 0.5
			var h2 := VfxCore.h(k + 5, 29) - 0.5
			var lag := 0.35 * float(k) / PUFFS  # the puffs leave one after another
			var v := clampf((u - lag) / (1.0 - lag), 0.0, 1.0)
			if v <= 0.0:
				continue
			var p := base + Vector3(h1 * 0.6, _core_y + SMOKE_RISE_M * v, h2 * 0.6)
			var col := Color(0.1, 0.09, 0.11, 0.85 * (1.0 - v))
			layer.sprite(&"smoke", p, 0.3 + 0.35 * v, col, k % 4, h1 * 4.0)
	if _pulse_left > 0.0:
		var w := 1.0 - _pulse_left / PULSE_S
		var col := Color(PULSE_GOLD, 1.0 - w)
		layer.flat_sprite(&"ring", base + Vector3(0, 0.05, 0), lerpf(0.8, 2.6, w), col, 0, 0.0)


## The shrine model: plinth, obelisk split by the core window, strips, fins, the core, its light and the price.
func make_shrine() -> Node3D:
	var n := Node3D.new()
	_body = Node3D.new()
	n.add_child(_body)
	var tint: Color = InteractionLooks.look(biome)["tint"]  # v0.9.0 BV (Ruins: white)
	var metal := _metal(METAL * tint)
	var top := _metal(METAL_TOP * tint)
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
	InteractionLooks.tint_in_place(mat, biome)  # v0.9.0 BV
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


## v0.9.0 SH: the owner's Fortune Shrine (ShopModels: already in metres, bottom on the floor, centred), turned to the
## camera; the same cues as _make_model, in its golden light.
func _make_fortune(piece: Dictionary) -> Node3D:
	_glow = FORTUNE_GLOW
	for m in [_core_mat, _strip_mat]:
		m.albedo_color = _glow
		m.emission = _glow
	var n := Node3D.new()
	_body = Node3D.new()
	_body.rotation.y = MODEL_YAW
	n.add_child(_body)
	var mat := (piece["material"] as Material).duplicate() as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
	ActorViews.flashable(mat)
	mat.emission = _glow.lerp(Color.WHITE, 0.6)
	InteractionLooks.tint_in_place(mat, biome)  # v0.9.0 BV
	_metal_mats.append(mat)
	_model = _mesh(piece["mesh"], mat)
	_model.name = "Model"
	_body.add_child(_model)
	var box: AABB = piece["aabb"]
	var crystal := Vector3(0.0, box.end.y * FORTUNE_GLOW_Y, 0.0)
	_core_y = crystal.y
	_core = Node3D.new()
	_core.position = crystal
	n.add_child(_core)
	for k in 3:
		var a := TAU * k / 3.0
		var bit := _mesh(RewardViews.bipyramid(3, 0.045, 0.08, 0.08), _core_mat)
		bit.position = Vector3(cos(a), 0.0, sin(a)) * (maxf(box.size.x, box.size.z) * 0.5 + 0.1)
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
