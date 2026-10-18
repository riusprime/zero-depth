class_name CurseRoomView
extends Node3D
## v0.8.0 N17 (owner O75: "we need to create a room for this that looks dark and uses the glyphs symbols around it with
## a new model") and N19 (owner O80: "you misstok the right glyphs I meant the purple ones that some enemies use and we
## have 4 of those that look kind like a ritual, not the fire, ice etc, the room should have crystals and ambiented like
## a dark pact room that's dark and mystical"): the curse room's dressing round the curse altar (EventPedestalViews
## draws the altar, its floating crystal and that crystal's soft light). The same in every biome:
## - a veil: a dark shroud laid over the room's floor (the biome's own lighting is never touched, as ArenaViews' veil),
##   so only the edges of the biome's ground show and the room reads far darker than the rooms round it;
## - a cold, low key light over the room (a pale blue-violet, no shadow: the light budget, BIOME_PERF_AND_LIGHT O30);
## - the four purple ritual sigils (fx_cast_sigils, the 2 x 2 sheet the Arc Caster's rune and The Fallen's cast disc
##   use; FxTextures.sigil_material): one large sigil on the floor under the altar, the other three in a ritual ring
##   round it, and the four again upright on the walls; each glows slowly on its own beat and turns slowly (reduced
##   motion: a steady glow, no turn). Without the sheet, plain violet diamonds stand in;
## - crystals: a faceted cluster of dark violet crystals on each crystal footprint the sim placed round the walls
##   (WorldReader.curse_room_crystals; CurseRoom.furnish makes them solid), every other cluster with glowing points in
##   violet or a deep red that pulse with the sigils. Code-made (one palette for every biome; the owner's crystal kit
##   pieces are each biome's own look).
## Once the altar's choice is taken everything fades to embers. Presentation only (EI-07): reads WorldReader's curse
## altar, its room, its crystals, the doorways and the altar's state.

const SHROUD := Color(0.01, 0.006, 0.02, 0.78)
const COLD := Color("#6E78E0")
const SIGIL := Color("#A86BFF")
const COLD_ENERGY := 0.45
const COLD_HEIGHT := 3.4
## The large floor sigil under the altar (m across), the ring of the other three (radius and size, m).
const BIG_SIZE := 3.6
const RING_COUNT := 3
const RING_R := 2.25
const RING_SIZE := 1.25
## The wall sigils: on the wall face (m in from it), their height, size, spacing along the walls, the most of them and
## how far they keep from a doorway (m).
const WALL_INSET := 0.08
const WALL_STEP := 3.4
const SIGIL_Y := 1.9
const SIGIL_SIZE := 1.15
const MAX_WALL_SIGILS := 8
const DOOR_CLEAR := 1.6
## The slow glow: brightness between these (× the colour), its speed (rad / s); spent: embers. The turn (rad / s).
const GLOW_LO := 0.55
const GLOW_HI := 1.6
const GLOW_SPEED := 1.3
const SPENT_GLOW := 0.25
const TURN_SPEED := 0.12
## The fx_cast_sigils cells (2 x 2): the big one, then the ring's three.
const CELLS := 4
## The crystals: dark faceted body, glowing points in violet and a deep red.
const CRYSTAL_DARK := Color("#1C0B2B")
const CRYSTAL_EDGE := Color("#4B1F7A")
const CRYSTAL_VIOLET := Color("#B36BFF")
const CRYSTAL_RED := Color("#E0365A")

var shroud: MeshInstance3D
var cold := OmniLight3D.new()
## Every sigil drawn: the big floor one first, the ring's, then the wall ones.
var sigils: Array[MeshInstance3D] = []
## The floor sigils (the big one and the ring), the first entries of `sigils`.
var floor_count := 0
## Each sigil's fx_cast_sigils cell (0..3) and turn direction (+1 / -1; 0 for the upright ones).
var cells := PackedInt32Array()
var spins := PackedFloat32Array()
## Whether the owner's sheet drew the sigils (false: the code diamonds).
var uses_sheet := false
## The crystal clusters (one node each) and their glowing crystals' materials.
var crystals: Array[Node3D] = []
var glow_mats: Array[StandardMaterial3D] = []
var calm := false
var _reader: WorldReader
var _k := -1
var _t := 0.0
var _phase: Array[float] = []
var _dark_mat := StandardMaterial3D.new()


func _init() -> void:
	name = "CurseRoom"


func setup(reader: WorldReader) -> void:
	_reader = reader
	_k = reader.event_curse_altar()
	calm = ViewPrefs.reduced_motion
	if _k < 0:
		return
	var room := reader.floor_room(reader.event_curse_room())
	var at := reader.event_pos(_k)
	_build_shroud(room)
	cold.name = "Cold"
	cold.light_color = COLD
	cold.light_energy = COLD_ENERGY
	cold.omni_range = maxf(room.size.x, room.size.y) * 0.7
	cold.shadow_enabled = false
	cold.distance_fade_enabled = true  # BIOME_PERF_AND_LIGHT (O30): off-screen lights fade out
	cold.distance_fade_begin = 30.0
	cold.distance_fade_length = 8.0
	cold.position = SimPlane.to_3d(room.get_center(), COLD_HEIGHT)
	add_child(cold)
	var big := _sigil(0, BIG_SIZE, true)
	big.position = SimPlane.to_3d(at, 0.04)
	_add(big, 0, 1.0)
	for j in RING_COUNT:
		var a := TAU * j / RING_COUNT + PI * 0.5
		var g := _sigil(1 + j, RING_SIZE, true)
		g.position = SimPlane.to_3d(at + Vector2(cos(a), sin(a)) * RING_R, 0.05)
		_add(g, 1 + j, -1.0)
	floor_count = sigils.size()
	var n := 0
	for p in wall_points(room, _doors(reader)):
		if n >= MAX_WALL_SIGILS:
			break
		var cell := n % CELLS
		var g := _sigil(cell, SIGIL_SIZE, false)
		g.position = SimPlane.to_3d(p, SIGIL_Y)
		var to := SimPlane.to_3d(room.get_center()) - SimPlane.to_3d(p)
		g.rotation.y = atan2(to.x, to.z)  # the quad's face (+Z) toward the room
		_add(g, cell, 0.0)
		n += 1
	_build_crystals(reader)
	_apply()


## Points on `room`'s wall faces (WALL_INSET in), one every WALL_STEP along each side (the corners left out), none
## within DOOR_CLEAR of a doorway in `doors`.
static func wall_points(room: Rect2, doors: Array = []) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r := room.grow(-WALL_INSET)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return out
	for side in 4:
		var horizontal := side < 2
		var length := r.size.x if horizontal else r.size.y
		var count := maxi(1, int(floor(length / WALL_STEP)))
		for j in count:
			var u := (j + 0.5) / count
			var p := Vector2.ZERO
			match side:
				0:
					p = Vector2(r.position.x + u * r.size.x, r.position.y)
				1:
					p = Vector2(r.position.x + u * r.size.x, r.end.y)
				2:
					p = Vector2(r.position.x, r.position.y + u * r.size.y)
				3:
					p = Vector2(r.end.x, r.position.y + u * r.size.y)
			var near := false
			for d: Rect2 in doors:
				if d.grow(DOOR_CLEAR).has_point(p):
					near = true
			if not near:
				out.append(p)
	return out


## v0.8.0 N19: the room dresser's placements (StageDresser.dress) without its loose decoration and wall lights inside
## `room` (the pact room has its own fixed look; the walls, the doorways and every other room are untouched).
static func strip(placements: Array, room: Rect2) -> Array:
	if room.size == Vector2.ZERO:
		return placements
	var out: Array = []
	var inside := room.grow(0.3)
	for p: Dictionary in placements:
		var kind: StringName = p.get("kind", &"")
		var at := SimPlane.to_sim((p["xform"] as Transform3D).origin)
		if (kind == &"decor" or kind == &"light") and inside.has_point(at):
			continue
		out.append(p)
	return out


func _process(delta: float) -> void:
	if _reader == null or _k < 0:
		return
	if not calm:
		_t += delta
	_apply()


## Glow of sigil j now (tests read it).
func glow_of(j: int) -> float:
	if spent():
		return SPENT_GLOW
	if calm:
		return (GLOW_LO + GLOW_HI) * 0.5
	return lerpf(GLOW_LO, GLOW_HI, 0.5 + 0.5 * sin(_t * GLOW_SPEED + _phase[j]))


## Sigil j's turn now (rad; 0 under reduced motion or for an upright one).
func turn_of(j: int) -> float:
	return 0.0 if calm else _t * TURN_SPEED * spins[j]


func spent() -> bool:
	return _reader != null and _reader.event_state(_k) == WorldReader.EVENT_DONE


func _apply() -> void:
	for j in sigils.size():
		var k := glow_of(j)
		var m := sigils[j].material_override
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("alpha", k / GLOW_HI)
			(m as ShaderMaterial).set_shader_parameter("turn", turn_of(j))
		elif m is StandardMaterial3D:
			(m as StandardMaterial3D).emission_energy_multiplier = k * 2.0
		if j >= floor_count and not calm:  # the wall ones breathe a little
			sigils[j].position.y = SIGIL_Y + 0.05 * sin(_t * 0.9 + _phase[j])
	var g := glow_of(0) if not sigils.is_empty() else GLOW_LO
	for i in glow_mats.size():
		glow_mats[i].emission_energy_multiplier = g * (2.6 if i % 2 == 0 else 2.0)


func _add(g: MeshInstance3D, cell: int, spin: float) -> void:
	_phase.append(float(sigils.size()) * 1.7)
	sigils.append(g)
	cells.append(cell)
	spins.append(spin)
	add_child(g)


## A sigil quad, `size` m across: flat on the floor or upright; the owner's sheet's `cell`, or a violet diamond.
func _sigil(cell: int, size: float, flat: bool) -> MeshInstance3D:
	var d := MeshInstance3D.new()
	d.name = "Sigil%d" % sigils.size()
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tex := FxTextures.sigil_material(SIGIL, cell)
	if tex != null:
		uses_sheet = true
		var q := FxTextures.floor_quad(size) if flat else QuadMesh.new()
		if not flat:
			(q as QuadMesh).size = Vector2.ONE * size
		d.mesh = q
		tex.shader = FxTextures.shader(no_fog_sigil())  # the same sigil shader, out of the biome's fog
		tex.render_priority = 3
		d.material_override = tex
		return d
	var diamond := QuadMesh.new()
	diamond.size = Vector2(size, size) * 0.5
	if flat:
		diamond.orientation = PlaneMesh.FACE_Y
	d.mesh = diamond
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = SIGIL
	m.emission_enabled = true
	m.emission = SIGIL
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	d.material_override = m
	d.rotation.y = PI * 0.25 if flat else 0.0
	d.rotation.z = 0.0 if flat else PI * 0.25
	return d


## One faceted cluster per crystal footprint: 4-6 pointed five-sided crystals leaning outward, the tallest in the
## middle; every other cluster carries two glowing ones (violet, or a deep red on every fourth).
func _build_crystals(reader: WorldReader) -> void:
	_dark_mat.albedo_color = CRYSTAL_DARK
	_dark_mat.metallic = 0.35
	_dark_mat.roughness = 0.22
	_dark_mat.emission_enabled = true
	_dark_mat.emission = CRYSTAL_EDGE
	_dark_mat.emission_energy_multiplier = 0.9
	var list := reader.curse_room_crystals()
	for i in list.size():
		var at: Vector2 = list[i][0]
		var half: float = list[i][1]
		var cluster := Node3D.new()
		cluster.name = "Crystals%d" % i
		cluster.position = SimPlane.to_3d(at)
		var count := 4 + (i * 7 + reader.seed_value()) % 3
		var glowing := i % 2 == 0
		var mat_glow: StandardMaterial3D = null
		if glowing:
			mat_glow = StandardMaterial3D.new()
			var c := CRYSTAL_RED if i % 4 == 2 else CRYSTAL_VIOLET
			mat_glow.albedo_color = c.darkened(0.55)
			mat_glow.emission_enabled = true
			mat_glow.emission = c
			mat_glow.roughness = 0.15
			glow_mats.append(mat_glow)
		for j in count:
			var u := float(j) / count
			var a := TAU * u + float(i) * 1.3
			var r := 0.0 if j == 0 else half * 0.75
			var h := 1.9 if j == 0 else 0.8 + 0.7 * fposmod(sin(float(i * 11 + j) * 3.7), 1.0)
			var m := CylinderMesh.new()
			m.top_radius = 0.0
			m.bottom_radius = 0.3 if j == 0 else 0.2
			m.height = h
			m.radial_segments = 5
			m.rings = 0
			var node := MeshInstance3D.new()
			node.mesh = m
			node.material_override = mat_glow if glowing and j < 2 else _dark_mat
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.position = Vector3(cos(a) * r, h * 0.45, sin(a) * r)
			var lean := 0.0 if j == 0 else 0.3
			node.rotation = Vector3(sin(a) * lean, a, -cos(a) * lean)
			cluster.add_child(node)
		add_child(cluster)
		crystals.append(cluster)


static func _doors(reader: WorldReader) -> Array:
	var out: Array = []
	for i in reader.floor_door_count():
		out.append(reader.floor_door_rect(i))
	return out


func _build_shroud(room: Rect2) -> void:
	shroud = MeshInstance3D.new()
	shroud.name = "Shroud"
	var plane := PlaneMesh.new()
	plane.size = room.size
	shroud.mesh = plane
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = SHROUD
	m.render_priority = 2
	m.disable_fog = true  # a foggy biome (Frozen Shore) would wash the veil out to its fog colour
	shroud.material_override = m
	shroud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shroud.position = SimPlane.to_3d(room.get_center(), 0.03)
	add_child(shroud)


## FxTextures.SIGIL without the biome's fog: in a foggy biome (Frozen Shore) the fog tinted the additive quads into
## pale squares.
static func no_fog_sigil() -> String:
	return FxTextures.SIGIL.replace("shadows_disabled;", "shadows_disabled, fog_disabled;")
