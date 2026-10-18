class_name CurseRoomView
extends Node3D
## v0.8.0 N17 (owner O75: "we need to create a room for this that looks dark and uses the glyphs symbols around it with
## a new model"): the curse room's dressing round the curse altar (EventPedestalViews draws the altar itself):
## - a shroud: a dark veil laid over the room's floor (the biome's own lighting is never touched, as ArenaViews' veil),
##   so the room reads darker than the rooms round it;
## - a cold, low light over the room (a pale blue-violet), and the altar's own violet glow;
## - the owner's glyph symbols (the TX3 sheets, ElementGlyphs): a ring of glyphs carved into the floor round the altar
##   and sigils floating along the room's walls, each glowing slowly on its own beat (reduced motion: a steady glow).
##   Without the sheets, plain violet diamonds stand in.
## Once the altar's choice is taken the glyphs fade to embers. Presentation only (EI-07): reads WorldReader's curse
## altar, its room and its state.

const SHROUD := Color(0.015, 0.012, 0.03, 0.62)
const COLD := Color("#7C86E8")
const SIGIL := Color("#B98CFF")
const COLD_ENERGY := 0.55
const COLD_HEIGHT := 3.2
## The floor ring round the altar: how many glyphs, how far out (m), their size.
const RING_COUNT := 6
const RING_R := 1.9
const RING_SIZE := 0.8
## The floating sigils: inset from the walls (m), spacing along them, height, size and the most of them.
const WALL_INSET := 1.1
const WALL_STEP := 3.2
const SIGIL_Y := 1.7
const SIGIL_SIZE := 0.7
const MAX_SIGILS := 14
## The slow glow: brightness between these (× the colour), its speed (rad / s); spent: embers.
const GLOW_LO := 0.55
const GLOW_HI := 1.6
const GLOW_SPEED := 1.3
const SPENT_GLOW := 0.25
const GLYPHS: Array[StringName] = [
	&"void", &"bleed", &"star", &"storm", &"venom", &"ember", &"frost", &"blades"
]

var shroud: MeshInstance3D
var cold := OmniLight3D.new()
## Every glyph drawn: the floor ring first, then the floating sigils.
var sigils: Array[Node3D] = []
var floor_count := 0
var calm := false
var _reader: WorldReader
var _k := -1
var _t := 0.0
var _phase: Array[float] = []


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
	for j in RING_COUNT:
		var a := TAU * j / RING_COUNT
		var p := at + Vector2(cos(a), sin(a)) * RING_R
		var g := _glyph(GLYPHS[j % GLYPHS.size()], RING_SIZE, true)
		g.position = SimPlane.to_3d(p, 0.05)
		g.rotation.y = -a
		_add(g)
	floor_count = sigils.size()
	var n := 0
	for p in wall_points(room):
		if n >= MAX_SIGILS:
			break
		var g := _glyph(GLYPHS[(n + 3) % GLYPHS.size()], SIGIL_SIZE, false)
		g.position = SimPlane.to_3d(p, SIGIL_Y)
		_add(g)
		n += 1
	_apply(0.0)


## Points WALL_INSET inside `room`'s walls, one every WALL_STEP along each side (the corners left out).
static func wall_points(room: Rect2) -> PackedVector2Array:
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
			out.append(p)
	return out


func _process(delta: float) -> void:
	if _reader == null or _k < 0:
		return
	if not calm:
		_t += delta
	_apply(_t)


## Glow `k` of sigil j now (tests read it).
func glow_of(j: int) -> float:
	var spent := _reader != null and _reader.event_state(_k) == WorldReader.EVENT_DONE
	if spent:
		return SPENT_GLOW
	if calm:
		return (GLOW_LO + GLOW_HI) * 0.5
	return lerpf(GLOW_LO, GLOW_HI, 0.5 + 0.5 * sin(_t * GLOW_SPEED + _phase[j]))


func _apply(_now: float) -> void:
	for j in sigils.size():
		var k := glow_of(j)
		var c := Color(SIGIL.r * k, SIGIL.g * k, SIGIL.b * k, 1.0)
		var s := sigils[j]
		if s is Sprite3D:
			(s as Sprite3D).modulate = c
		elif s is MeshInstance3D:
			var m := (s as MeshInstance3D).material_override as StandardMaterial3D
			m.emission_energy_multiplier = k * 2.0
		if j >= floor_count and not calm:  # the floating ones bob a little
			s.position.y = SIGIL_Y + 0.08 * sin(_t * 0.9 + _phase[j])


func _add(g: Node3D) -> void:
	_phase.append(float(sigils.size()) * 1.7)
	sigils.append(g)
	add_child(g)


## One glyph from the owner's sheets (a Sprite3D: flat on the floor, or upright facing the camera), or a violet
## diamond when the sheet is missing.
func _glyph(id: StringName, size: float, flat: bool) -> Node3D:
	var r := ElementGlyphs.region(id)
	if r.is_empty():
		var d := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(size, size) * 0.5
		if flat:
			q.orientation = PlaneMesh.FACE_Y
		d.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = SIGIL
		m.emission_enabled = true
		m.emission = SIGIL
		m.billboard_mode = (
			BaseMaterial3D.BILLBOARD_DISABLED if flat else BaseMaterial3D.BILLBOARD_FIXED_Y
		)
		d.material_override = m
		d.rotation.z = 0.0 if flat else PI * 0.25
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return d
	var s := Sprite3D.new()
	s.texture = r[0]
	s.region_enabled = true
	s.region_rect = r[1]
	var rect: Rect2 = r[1]
	s.pixel_size = size / maxf(1.0, rect.size.x)
	s.shaded = false
	s.transparent = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if flat:
		s.axis = Vector3.AXIS_Y
	else:
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.render_priority = 3
	return s


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
	shroud.material_override = m
	shroud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shroud.position = SimPlane.to_3d(room.get_center(), 0.03)
	add_child(shroud)
