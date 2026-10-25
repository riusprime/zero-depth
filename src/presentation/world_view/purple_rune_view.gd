class_name PurpleRuneView
extends Node3D
## v0.9.0 DP (owner Q26b: "one of the event rooms, in a big room, has activation purple runes, that make the screen
## shake so you know something happened, but then when you kill the boss the purple portal appears"; Q17: the purple
## runes are one of the few things that vibrate): the purple-rune room, reading only (WorldReader.purple_*).
## - The dais (`purple_rune_dais` through ShopModels when the owner's model is listed, else this code stand-in): a
##   two-tier octagonal stone plinth under a floating violet crystal, in the room's middle.
## - A ring of RUNES purple ritual sigils round it on the floor (fx_cast_sigils, the curse room's sheet:
##   FxTextures.sigil_material; violet diamonds without the sheet), dim until the dais is awakened.
## - Awakened (the sim's lit, at lit_tick): the runes light one after another (STEP_S apart), the crystal and a violet
##   light swell, the camera's vibration builds while they light (`vibration`, the level WorldViewRoot holds the rig
##   at: IsoRig.vibrate_to) and lands in a thud once the last one is lit (`thudded`, one frame: IsoRig.thud); the
##   `purple_runes` sound is AudioEvents'. A floor resumed with the runes already awake shows them lit, with no
##   vibration. Then they glow slowly for good.
## - v0.9.0 BV (W71): per biome (InteractionLooks; set `biome` before setup): the owner's dais tinted and the biome's
##   accent round its foot. The runes, the crystal and the light keep their violet in every biome (the Deep gate's).

const SIGIL := Color("#A86BFF")
const CRYSTAL := Color("#C68BFF")
const STONE := Color("#4A4452")
const MODEL_DAIS := &"purple_rune_dais"
const RUNES := 6
const RING_R := 2.3
const RUNE_SIZE := 1.1
## The runes' glow: unlit, and lit (× the colour), with a slow beat once all are lit.
const DIM := 0.12
const LIT := 1.0
const BEAT := 0.15
const BEAT_SPEED := 1.4
## The lighting in sequence: one rune every STEP_S; the vibration builds to RAMP_LEVEL over the sequence, then the
## thud (THUD) lands as the last rune lights.
const STEP_S := 0.15
const RAMP_LEVEL := 0.55
const THUD := 0.6
## How fresh (ticks) an awakening must be for the sequence to play (else it shows lit at once: a resumed floor).
const FRESH_TICKS := 30
const BASE_R := 0.85
const BASE_H := 0.3
const TOP_R := 0.55
const TOP_H := 0.25
const CRYSTAL_Y := 1.15

## Each rune's glow now (0..1) and the sigils.
var glow := PackedFloat32Array()
var sigils: Array[MeshInstance3D] = []
var uses_sheet := false
var uses_model := false
var lit := false
## The vibration level to hold the rig at this frame (0 = none), and true once the thud has landed until taken
## (take_thud).
var vibration := 0.0
var thudded := false
var crystal: MeshInstance3D
var light := OmniLight3D.new()
## v0.9.0 BV: the floor's biome (WorldViewRoot sets it).
var biome := &""
var _crystal_mat := StandardMaterial3D.new()
var _stone := StandardMaterial3D.new()
## Seconds since the sequence began (-1: not begun; past the sequence: all lit).
var _t := -1.0
var _beat := 0.0
var _thud_done := false


func _init() -> void:
	name = "PurpleRunes"


func setup(reader: WorldReader, cover: Color = Color()) -> void:
	var at := reader.purple_dais_pos()
	position = SimPlane.to_3d(at)
	_stone.albedo_color = cover.darkened(0.25) if cover != Color() else STONE
	_stone.roughness = 1.0
	_build_dais()
	for j in RUNES:
		var a := TAU * j / RUNES
		var g := _sigil(j % 4)
		g.position = Vector3(cos(a) * RING_R, 0.05, sin(a) * RING_R)
		sigils.append(g)
		add_child(g)
	glow.resize(RUNES)
	glow.fill(DIM)
	light.name = "Glow"
	light.light_color = SIGIL
	light.omni_range = 6.0
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.position = Vector3(0, 2.2, 0)
	add_child(light)
	if reader.purple_lit():  # awake already (a resumed floor): lit, no sequence, no vibration
		lit = true
		_t = sequence_s()
		_thud_done = true
	_apply()


## Whether the thud landed since the last call (WorldViewRoot plays it once).
func take_thud() -> bool:
	var t := thudded
	thudded = false
	return t


## The whole lighting sequence's length (s).
static func sequence_s() -> float:
	return STEP_S * RUNES


func sync(reader: WorldReader) -> void:
	if reader.purple_lit() and not lit:
		lit = true
		var fresh := reader.tick() - reader.purple_lit_tick() < FRESH_TICKS
		_t = 0.0 if fresh else sequence_s()
		_thud_done = not fresh
	_apply()


func _process(delta: float) -> void:
	if not lit:
		vibration = 0.0
		return
	if _t < sequence_s():
		_t = minf(sequence_s(), _t + delta)
	elif not ViewPrefs.reduced_motion:
		_beat += delta
	_apply()


## Rune j's glow at `t` seconds into the sequence (DIM before its turn, LIT from it).
static func rune_glow(j: int, t: float) -> float:
	if t < 0.0:
		return DIM
	return LIT if t >= STEP_S * (j + 1) - 0.0001 else DIM


func _apply() -> void:
	vibration = 0.0
	if lit and _t < sequence_s():
		vibration = RAMP_LEVEL * clampf(_t / sequence_s(), 0.0, 1.0)
	elif lit and not _thud_done:
		_thud_done = true
		thudded = true
	var lit_count := 0
	for j in RUNES:
		glow[j] = rune_glow(j, _t if lit else -1.0)
		if glow[j] >= LIT:
			lit_count += 1
		var k := glow[j]
		if lit_count == RUNES:
			k = LIT * (1.0 - BEAT + BEAT * sin(_beat * BEAT_SPEED + j))
		var m := sigils[j].material_override
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("alpha", k)
		elif m is StandardMaterial3D:
			(m as StandardMaterial3D).emission_energy_multiplier = k * 2.0
			(m as StandardMaterial3D).albedo_color.a = 0.25 + 0.75 * k
	var share := float(lit_count) / RUNES
	_crystal_mat.emission_energy_multiplier = 0.4 + 3.0 * share
	light.light_energy = 2.2 * share
	if crystal != null and not ViewPrefs.reduced_motion:
		crystal.rotation.y = _beat * 0.6


func _build_dais() -> void:
	var model := ShopModels.get_model(MODEL_DAIS)
	if not model.is_empty():
		uses_model = true
		var mi := MeshInstance3D.new()
		mi.name = "Model"
		mi.mesh = model["mesh"]
		mi.set_surface_override_material(0, InteractionLooks.tinted(model["material"], biome))
		add_child(mi)
	else:
		_tier("Base", BASE_R, BASE_H, BASE_H * 0.5)
		_tier("Top", TOP_R, TOP_H, BASE_H + TOP_H * 0.5)
	InteractionLooks.add_accent(self, biome, BASE_R + 0.35, BASE_H + TOP_H)
	_crystal_mat.albedo_color = CRYSTAL.darkened(0.4)
	_crystal_mat.metallic = 0.3
	_crystal_mat.roughness = 0.2
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = CRYSTAL
	var gem := SphereMesh.new()  # a low-poly, faceted gem: 4 segments round, 2 rings
	gem.radius = 0.22
	gem.height = 0.7
	gem.radial_segments = 4
	gem.rings = 2
	crystal = MeshInstance3D.new()
	crystal.name = "Crystal"
	crystal.mesh = gem
	crystal.material_override = _crystal_mat
	crystal.position.y = CRYSTAL_Y
	add_child(crystal)


func _tier(tier_name: String, r: float, h: float, y: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r * 0.92
	mesh.bottom_radius = r
	mesh.height = h
	mesh.radial_segments = 8
	var node := MeshInstance3D.new()
	node.name = tier_name
	node.mesh = mesh
	node.material_override = _stone
	node.position.y = y
	add_child(node)


## A flat rune on the floor: the owner's sheet's `cell` (the curse room's purple sigils), or a violet diamond.
func _sigil(cell: int) -> MeshInstance3D:
	var d := MeshInstance3D.new()
	d.name = "Rune%d" % sigils.size()
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tex := FxTextures.sigil_material(SIGIL, cell)
	if tex != null:
		uses_sheet = true
		d.mesh = FxTextures.floor_quad(RUNE_SIZE)
		tex.shader = FxTextures.shader(CurseRoomView.no_fog_sigil())
		tex.render_priority = 3
		d.material_override = tex
		return d
	var diamond := QuadMesh.new()
	diamond.size = Vector2.ONE * RUNE_SIZE * 0.5
	diamond.orientation = PlaneMesh.FACE_Y
	d.mesh = diamond
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = SIGIL
	m.emission_enabled = true
	m.emission = SIGIL
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	d.material_override = m
	d.rotation.y = PI * 0.25
	return d
