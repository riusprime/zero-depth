class_name InteractionLooks
extends RefCounted
## v0.9.0 BV (owner W71, §11 Biomes: Ruins "machinery, destructible walls, pressure plates", Night Rocks "hidden paths,
## glowing switches, statues", Red Canyon "heat vents, unstable structures, explosives", Frozen Shore "frozen
## mechanisms, ice runes", Starfall "cosmic relays, floating runes, unstable portals"; "share scripts … different
## models, sounds, and visual effects"): each Wave 4 interaction's look per biome. The mechanics are shared; the views
## (TimedDoorView, RuneAlignmentView, BreakablesView, RuneMarkingsView, PurpleRuneView, LockdownView, ShrinesView,
## GambleShrineView) read their colours here, keyed on the floor's biome id (StageView.prop_style).
## - The owner's models (ShopModels, KitModels) are kept, tinted: their material's albedo multiplied by the biome's
##   `tint` (a copy, made once per material and biome: `tinted`). Ruins keeps the material as delivered.
## - Code stand-ins take the biome's colours: the rune glow (`rune`; the rune puzzle's matched face), the unmatched
##   glyph (`glyph`), the hidden room's light (`room`), the metal (bolts, bars), the containers' wood and clay, the
##   explosive barrel's body and band (dark on Red Canyon's red ground, so it reads), the fountain's water and the
##   hidden markings' scratch (dark on Frozen Shore's snow, where a pale one vanished).
## - Each biome adds its own small touch round an interaction's foot (`add_accent`, built once at setup): Ruins grey
##   rubble, Night Rocks glowing blue crystals, Red Canyon basalt with ember cracks, Frozen Shore snow and ice shards,
##   Starfall floating star shards. Meshes only, no particles: Effects density Low keeps them.
## - Hostile warnings stay in the hostile hues (LockdownView.WARN, a dark band round it per biome: `warn_rim`), never
##   the hero's attack colours. The purple runes keep their violet (the Deep gate's colour) in every biome.
## An unknown biome ("": a test's bare stage) draws Ruins' colours with no accent: the look before BV.

const BIOMES: Array[StringName] = [
	&"ruins", &"night_rocks", &"red_canyon", &"frozen_shore", &"starfall"
]
const FALLBACK := &"ruins"
const LOOKS := {
	&"ruins":
	{
		"rune": Color("#FFB347"),
		"glyph": Color("#9FD8FF"),
		"room": Color("#FFE7B8"),
		"tint": Color(1, 1, 1),
		"metal": Color("#2E2B29"),
		"wood": Color("#7A5634"),
		"clay": Color("#A0603A"),
		"keg": Color("#8E2B1E"),
		"keg_band": Color("#C8A23A"),
		"water": Color("#6FD8FF"),
		"marking": Color(0.92, 0.95, 1.0),
		"warn_rim": Color("#1A1A22"),
		"accent": Color("#8C8C90"),
	},
	&"night_rocks":
	{
		"rune": Color("#7CFFC4"),
		"glyph": Color("#C8D2FF"),
		"room": Color("#D8FFF0"),
		"tint": Color("#B4C6EC"),
		"metal": Color("#2A3142"),
		"wood": Color("#4E5A70"),
		"clay": Color("#5E6F94"),
		"keg": Color("#9A2A2A"),
		"keg_band": Color("#E0892B"),
		"water": Color("#8CF0D8"),
		"marking": Color("#A8FFE0"),
		"warn_rim": Color("#1A1A22"),
		"accent": Color("#6FA8FF"),
	},
	&"red_canyon":
	{
		"rune": Color("#FF9E6B"),
		"glyph": Color("#FFE2B0"),
		"room": Color("#FFD6B0"),
		"tint": Color("#F0C2A8"),
		"metal": Color("#4A2E24"),
		"wood": Color("#A0784A"),
		"clay": Color("#C0623E"),
		"keg": Color("#5A1A12"),
		"keg_band": Color("#F2C14E"),
		"water": Color("#58D8C8"),
		"marking": Color("#3A1E18"),
		"warn_rim": Color("#1A1A22"),
		"accent": Color("#3A2420"),
	},
	&"frozen_shore":
	{
		"rune": Color("#6FD6FF"),
		"glyph": Color("#F2F6FF"),
		"room": Color("#E8F4FF"),
		"tint": Color("#E2EEFF"),
		"metal": Color("#5C6E80"),
		"wood": Color("#8C8A86"),
		"clay": Color("#7FA4C4"),
		"keg": Color("#A3302A"),
		"keg_band": Color("#2E2B29"),
		"water": Color("#A8E8FF"),
		"marking": Color("#3A5A80"),
		"warn_rim": Color("#1A1A22"),
		"accent": Color("#F4F8FF"),
	},
	&"starfall":
	{
		"rune": Color("#FF7BEA"),
		"glyph": Color("#B8C4FF"),
		"room": Color("#FFE0FA"),
		"tint": Color("#C9B8F0"),
		"metal": Color("#3A2E5C"),
		"wood": Color("#4A3D6E"),
		"clay": Color("#7A5CB0"),
		"keg": Color("#8E2440"),
		"keg_band": Color("#F4E3FF"),
		"water": Color("#D6B8FF"),
		"marking": Color("#F0B8FF"),
		"warn_rim": Color("#1A1A22"),
		"accent": Color("#FF7BEA"),
	},
}

static var _tinted := {}
static var _accent_mats := {}


## The biome's id with a look (`FALLBACK` for an unknown one).
static func resolve(biome: StringName) -> StringName:
	return biome if LOOKS.has(biome) else FALLBACK


## The biome's look (Ruins' for an unknown biome).
static func look(biome: StringName) -> Dictionary:
	return LOOKS[resolve(biome)]


## One colour of the biome's look.
static func color(biome: StringName, key: String) -> Color:
	return look(biome)[key]


## The biome of a stage (its prop_style), "" without one.
static func of_stage(stage: StageView) -> StringName:
	return stage.prop_style if stage != null else &""


## The owner's model material `mat` tinted for `biome`: `mat` itself where the tint is white (Ruins) or it is not a
## StandardMaterial3D; else a copy with its albedo multiplied by the tint, made once per material and biome.
static func tinted(mat: Material, biome: StringName) -> Material:
	var std := mat as StandardMaterial3D
	var tint: Color = look(biome)["tint"]
	if std == null or tint == Color(1, 1, 1):
		return mat
	var key := "%d:%s" % [mat.get_instance_id(), resolve(biome)]
	if not _tinted.has(key):
		var copy := std.duplicate() as StandardMaterial3D
		copy.albedo_color = std.albedo_color * tint
		_tinted[key] = copy
	return _tinted[key]


## Multiplies a material the view already owns (a copy) by the biome's tint, in place.
static func tint_in_place(mat: StandardMaterial3D, biome: StringName) -> void:
	if mat != null:
		mat.albedo_color = mat.albedo_color * (look(biome)["tint"] as Color)


## Whether the biome has an accent (a known biome; a bare stage's "" has none).
static func has_accent(biome: StringName) -> bool:
	return LOOKS.has(biome)


## The biome's touch round an interaction's foot (a circle of `radius` m) and, for Frozen Shore and Starfall, at its
## top (`top` m up): an "Accent" node under `parent`, built once. Nothing for an unknown biome. Returns the node.
static func add_accent(parent: Node3D, biome: StringName, radius: float, top: float) -> Node3D:
	if not has_accent(biome):
		return null
	var n := Node3D.new()
	n.name = "Accent"
	parent.add_child(n)
	var mat := accent_material(biome)
	match biome:
		&"ruins":  # grey rubble at the foot
			for k in 3:
				var a := TAU * (k + 0.3) / 3.0
				var b := _piece(n, _chunk(0.16 + 0.04 * k), mat)
				b.position = Vector3(cos(a) * radius, 0.07, sin(a) * radius)
				b.rotation = Vector3(0.3 * k, 0.9 * k, 0.2)
		&"night_rocks":  # glowing blue crystals: the "glowing switches"
			for k in 3:
				var a := TAU * (k + 0.15) / 3.0
				var c := _piece(n, RewardViews.bipyramid(4, 0.07, 0.18 + 0.05 * k, 0.04), mat)
				c.position = Vector3(cos(a) * radius, 0.1, sin(a) * radius)
				c.rotation = Vector3(0.25, 0.7 * k, -0.2)
		&"red_canyon":  # dark basalt with ember cracks: the "heat vents"
			for k in 4:
				var a := TAU * (k + 0.1) / 4.0
				var s := _piece(n, _chunk(0.2), accent_material(&"red_canyon_rock"))
				s.position = Vector3(cos(a) * radius, 0.06, sin(a) * radius)
				s.rotation.y = a
				var crack := _piece(n, _chunk(0.08), mat)
				crack.position = s.position + Vector3(0, 0.11, 0)
		&"frozen_shore":  # snow round the foot, ice shards, and snow on top
			var drift := _piece(
				n, _disc(radius + 0.25, 0.08), accent_material(&"frozen_shore_snow")
			)
			drift.position.y = 0.04
			for k in 3:
				var a := TAU * (k + 0.5) / 3.0
				var shard := _piece(n, RewardViews.bipyramid(3, 0.06, 0.22, 0.03), mat)
				shard.position = Vector3(cos(a) * radius, 0.12, sin(a) * radius)
				shard.rotation = Vector3(0.35, a, 0.3)
			if top > 0.0:
				var cap := _piece(n, _disc(0.3, 0.07), accent_material(&"frozen_shore_snow"))
				cap.position.y = top + 0.035
		&"starfall":  # floating star shards: the "floating runes"
			for k in 2:
				var a := TAU * (k + 0.25) / 2.0
				var star := _piece(n, RewardViews.bipyramid(4, 0.06, 0.12, 0.12), mat)
				star.position = Vector3(
					cos(a) * radius, maxf(top, 0.6) + 0.35 + 0.2 * k, sin(a) * radius
				)
	return n


## The accent's shared material per biome (and Red Canyon's rock, Frozen Shore's snow), made once.
static func accent_material(id: StringName) -> StandardMaterial3D:
	if _accent_mats.has(id):
		return _accent_mats[id]
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	match id:
		&"red_canyon_rock":
			m.albedo_color = color(&"red_canyon", "accent")
		&"frozen_shore_snow":
			m.albedo_color = Color("#E9EEF4")
		&"ruins":
			m.albedo_color = color(id, "accent")
		&"red_canyon":  # ember cracks
			m.albedo_color = Color("#5A1A10")
			m.emission_enabled = true
			m.emission = Color("#FF6A1A")
			m.emission_energy_multiplier = 1.2
		&"frozen_shore":  # ice
			m.albedo_color = Color("#BFDFF5")
			m.metallic = 0.1
			m.roughness = 0.15
		_:  # Night Rocks' crystals, Starfall's stars: glowing
			m.albedo_color = color(id, "accent").darkened(0.3)
			m.emission_enabled = true
			m.emission = color(id, "accent")
			m.emission_energy_multiplier = 1.4
	_accent_mats[id] = m
	return m


static func _piece(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _chunk(size: float) -> Mesh:
	var b := BoxMesh.new()
	b.size = Vector3(size, size * 0.8, size * 0.9)
	return b


static func _disc(r: float, h: float) -> Mesh:
	var c := CylinderMesh.new()
	c.top_radius = r * 0.85
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	return c
