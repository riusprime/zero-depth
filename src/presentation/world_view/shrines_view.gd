class_name ShrinesView
extends Node3D
## v0.9.0 SH, HF (owner Q29b, W36): the floor's Blood or Chaos shrine and its healing fountain, reading only
## (WorldReader.shrine). The Fortune shrine is GambleShrineView's.
## - Each body is the owner's model (`shrine_blood`, `shrine_chaos`, `healing_fountain` through ShopModels when
##   assets/models/manifest.json lists it), front turned to the iso camera like the gamble shrine's, else a code
##   stand-in of the same size (L15: missing art never blocks a step): Blood a dark stone pillar over a red basin,
##   Chaos a jagged violet obelisk, the fountain a stone basin of glowing water.
## - Each glows in its colour (an OmniLight3D and emission); brighter in reach. Blood paid, or Chaos cleared: it flashes
##   and sleeps (dim, its light low: `spent`). Chaos being fought: its light throbs fast. The fountain used: a flash of
##   water light, then dry for good: its water is gone (the stand-in's water disc hidden, the model darkened) and its
##   light out (`dry`). A floor resumed after a use shows the spent or dry look at once.
## The prompt (with the cost) is the HUD's shared one; the result lines are ShrineHud's; the sounds AudioEvents'.
## v0.9.0 BV (W71): per biome (InteractionLooks; set `biome` before setup): the owner's models tinted, the fountain's
## water and light in the biome's water (Ruins clear blue, Night Rocks moon-teal, Red Canyon oasis teal, Frozen Shore
## pale ice, Starfall star-lilac), and the biome's accent round each foot. Blood keeps its red and Chaos its violet
## (what they cost and do) in every biome.

const BLOOD := Color("#E0263C")
const CHAOS := Color("#A15CFF")
const WATER := Color("#6FD8FF")
const STONE := Color("#4B4650")
## The model's front (+Z) turned to the iso camera (GambleShrineView.MODEL_YAW).
const MODEL_YAW := PI * 0.25
const LIGHT_ENERGY := 1.2
const HOT := 1.5
const SPENT_GLOW := 0.15
const FLASH_S := 0.5
## How fresh (ticks) a use must be for its flash to play (else the spent look at once: a resumed floor).
const FRESH_TICKS := 30
const STANDIN_H := {&"shrine_blood": 1.5, &"shrine_chaos": 1.8, &"healing_fountain": 1.4}

var shrine_root: Node3D
var fountain_root: Node3D
var shrine_light := OmniLight3D.new()
var fountain_light := OmniLight3D.new()
var shrine_model := false
var fountain_model := false
var water: MeshInstance3D
## v0.9.0 BV: the floor's biome (WorldViewRoot sets it), the water colour drawn, and the fountain body's lit albedo.
var biome := &""
var water_color := WATER
var _wet := Color.WHITE
var _kind := -1
var _glow := BLOOD
var _shrine_mat: StandardMaterial3D
var _fountain_mat: StandardMaterial3D
var _spent := false
var _fighting := false
var _dry := false
var _hot_shrine := false
var _hot_fountain := false
var _flash := 0.0
var _fountain_flash := 0.0
var _t := 0.0
var _seen := [-1, -1, -1]


func _init() -> void:
	name = "Shrines"


func setup(reader: WorldReader, cover: Color = Color()) -> void:
	var d := reader.shrine()
	if d.is_empty():
		return
	var stone := cover.darkened(0.2) if cover != Color() else STONE
	water_color = InteractionLooks.color(biome, "water")
	if d["has_shrine"]:
		_kind = int(d["kind"])
		_glow = BLOOD if _kind == WorldReader.SHRINE_BLOOD else CHAOS
		var id := &"shrine_blood" if _kind == WorldReader.SHRINE_BLOOD else &"shrine_chaos"
		shrine_root = Node3D.new()
		shrine_root.name = "Blood" if _kind == WorldReader.SHRINE_BLOOD else "Chaos"
		shrine_root.position = SimPlane.to_3d(d["pos"])
		add_child(shrine_root)
		_shrine_mat = _body(shrine_root, id, stone, _glow)
		shrine_model = shrine_root.has_node("Model")
		_add_light(shrine_root, shrine_light, _glow, float(STANDIN_H[id]) * 0.8)
		InteractionLooks.add_accent(shrine_root, biome, 0.95, 0.0)
	if d["has_fountain"]:
		fountain_root = Node3D.new()
		fountain_root.name = "Fountain"
		fountain_root.position = SimPlane.to_3d(d["fountain_pos"])
		add_child(fountain_root)
		_fountain_mat = _body(fountain_root, &"healing_fountain", stone, water_color)
		fountain_model = fountain_root.has_node("Model")
		if _fountain_mat != null:
			_wet = _fountain_mat.albedo_color
		_add_light(fountain_root, fountain_light, water_color, 1.1)
		InteractionLooks.add_accent(fountain_root, biome, 0.9, 0.0)
	_seen = _marks(d)
	_spent = int(d["used_tick"]) >= 0 and int(d["chaos_phase"]) != 1
	_dry = int(d["fountain_tick"]) >= 0
	_apply()


func sync(reader: WorldReader) -> void:
	var d := reader.shrine()
	if d.is_empty():
		return
	var now := _marks(d)
	var fresh := func(t: int) -> bool: return t >= 0 and reader.tick() - t < FRESH_TICKS
	if now[0] != _seen[0] and fresh.call(now[0]) or now[1] != _seen[1] and fresh.call(now[1]):
		_flash = FLASH_S
	if now[2] != _seen[2] and fresh.call(now[2]):
		_fountain_flash = FLASH_S
	_seen = now
	_fighting = int(d["chaos_phase"]) == 1
	_spent = int(d["used_tick"]) >= 0 and not _fighting
	_dry = int(d["fountain_tick"]) >= 0
	var p := reader.player_pos()
	var reach := 1.8
	_hot_shrine = (
		d["has_shrine"] and not _spent and not _fighting and p.distance_to(d["pos"]) <= reach
	)
	_hot_fountain = d["has_fountain"] and not _dry and p.distance_to(d["fountain_pos"]) <= reach
	_apply()


## [the shrine's use tick, the Chaos clear tick, the fountain's heal tick].
static func _marks(d: Dictionary) -> Array:
	return [int(d["used_tick"]), int(d["clear_tick"]), int(d["fountain_tick"])]


## The shrine is spent (Blood paid, Chaos cleared): drawn dim.
func spent() -> bool:
	return _spent


## The fountain is dry (its one heal given).
func dry() -> bool:
	return _dry


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_fountain_flash = maxf(0.0, _fountain_flash - delta)
	_apply()


func _apply() -> void:
	if shrine_root != null:
		var e := 1.0
		if _spent:
			e = SPENT_GLOW
		elif _fighting:
			e = 1.2 + 0.8 * absf(sin(_t * 9.0))
		elif _hot_shrine:
			e = HOT
		e += 2.5 * (_flash / FLASH_S)
		shrine_light.light_energy = LIGHT_ENERGY * e
		if _shrine_mat != null:
			_shrine_mat.emission_energy_multiplier = 0.6 * e
	if fountain_root != null:
		var f := 0.0 if _dry else (HOT if _hot_fountain else 1.0)
		f += 2.5 * (_fountain_flash / FLASH_S)
		fountain_light.light_energy = LIGHT_ENERGY * f
		if water != null:
			water.visible = not _dry or _fountain_flash > 0.0
		if _fountain_mat != null:
			_fountain_mat.emission_energy_multiplier = 0.5 * f
			_fountain_mat.albedo_color = _wet * Color(0.55, 0.55, 0.6) if _dry else _wet


## The body: the owner's model (named "Model") or the stand-in. Returns the material whose glow changes.
func _body(n: Node3D, id: StringName, stone: Color, glow: Color) -> StandardMaterial3D:
	var model := ShopModels.get_model(id)
	if not model.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Model"
		mi.mesh = model["mesh"]
		mi.rotation.y = MODEL_YAW
		var mat := (model["material"] as Material).duplicate() as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission = glow.darkened(0.3)
		InteractionLooks.tint_in_place(mat, biome)  # v0.9.0 BV
		mi.material_override = mat
		n.add_child(mi)
		return mat
	var body := StandardMaterial3D.new()
	body.albedo_color = stone
	body.roughness = 0.9
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = glow
	glow_mat.emission_enabled = true
	glow_mat.emission = glow
	var h := float(STANDIN_H[id])
	match id:
		&"shrine_blood":  # a squat pillar over a red basin
			n.add_child(_cyl("Base", 0.7, 0.2, 0.1, body))
			n.add_child(_cyl("Pillar", 0.32, h - 0.55, 0.2 + (h - 0.55) * 0.5, body))
			n.add_child(_cyl("Basin", 0.55, 0.15, h - 0.28, body))
			n.add_child(_cyl("Blood", 0.48, 0.04, h - 0.18, glow_mat))
		&"shrine_chaos":  # a jagged obelisk with a floating shard
			var ob := MeshInstance3D.new()
			ob.name = "Obelisk"
			var prism := PrismMesh.new()
			prism.size = Vector3(0.9, h - 0.4, 0.7)
			ob.mesh = prism
			ob.material_override = body
			ob.position.y = (h - 0.4) * 0.5
			n.add_child(ob)
			var shard := MeshInstance3D.new()
			shard.name = "Shard"
			shard.mesh = RewardViews.bipyramid(4, 0.16, 0.22, 0.22)
			shard.material_override = glow_mat
			shard.position.y = h - 0.15
			n.add_child(shard)
		_:  # the fountain: a stone basin of water
			n.add_child(_cyl("Basin", 0.6, 0.55, 0.275, body))
			n.add_child(_cyl("Spout", 0.14, h - 0.55, 0.55 + (h - 0.55) * 0.5, body))
			water = _cyl("Water", 0.52, 0.03, 0.53, glow_mat)
			n.add_child(water)
	return glow_mat


func _add_light(n: Node3D, l: OmniLight3D, c: Color, y: float) -> void:
	l.name = "Glow"
	l.light_color = c
	l.omni_range = 4.0
	l.light_energy = LIGHT_ENERGY
	l.shadow_enabled = false
	l.position = Vector3(0, y, 0)
	n.add_child(l)


func _cyl(n: String, r: float, h: float, y: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = n
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	m.mesh = c
	m.material_override = mat
	m.position.y = y
	return m
