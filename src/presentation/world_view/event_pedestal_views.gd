class_name EventPedestalViews
extends Node3D
## Event rooms in the world (v0.5.0 EV): one lit pedestal per event (a stepped hexagonal base, a slanted lectern
## column and a floating violet glyph crystal over it, with its own light); the Wandering Drone's ring on the floor
## filling as you hold it; and a gold crown ring under every elite.
## v0.8.0 N17 (owner O75: "the name displayed on top of the model of the curses device … you get to see it when you
## click it not from the text over the 3d model"): no name floats over a pedestal any more; its name shows in the
## panel interact opens (EventPanel). The turning, glowing crystal is the cue that it can be used. The curse room's
## altar (WorldReader.event_curse_altar) is its own model: a dark stone altar with a cracked crystal (code-made; the
## owner's `curse_altar` model replaces the stone through assets/models/manifest.json, ShopModels), in its dark room
## (CurseRoomView: the shroud, the cold light, the ritual sigils and, v0.8.0 N19, the crystals).
## A ready pedestal glows and its glyph turns; an active one (a fight or a defence) pulses red or cyan; a spent one
## goes dark. Glowing materials have emission on from creation; only energies and colours change (flash-safe).
## Reads only (EI-07).

const GLOW := Color("#B98CFF")
const FIGHT := Color("#FF5A4D")
const GUARD := Color("#3FD9F2")
const ELITE := Color("#F2C14E")
const STONE := Color("#3A3F4C")
const STONE_TOP := Color("#545B6A")
const GLYPH_Y := 1.45
const GLYPH_ENERGY := 2.6
const LIGHT_ENERGY := 1.3
## v0.8.0 N17: the curse altar's stone, and the owner's model that replaces it.
const CURSE_STONE := Color("#1C1D24")
const CURSE_TOP := Color("#2A2B36")
const CURSE_MODEL_ID := &"curse_altar"
## v0.8.0 N17 (owner, 2026-10-18: "give a little light on the floating symbol over the altar"): the altar's crystal
## light: cold violet, low, short, no shadow (BIOME_PERF_AND_LIGHT: never one of the 4 shadow casters), faded out with
## distance, pulsing gently with the room's glyphs (CurseRoomView.GLOW_SPEED; reduced motion: steady).
const CURSE_LIGHT := Color("#9C8CFF")
const CURSE_LIGHT_ENERGY := 0.8
const CURSE_LIGHT_RANGE := 2.4
const CURSE_PULSE := 0.25
const RING_SEGMENTS := 48

## v0.8.0 N17: the curse room's dressing (null on a floor without one); the altar draws the owner's model.
var curse_room: CurseRoomView
var curse_uses_model := false
var _reader: WorldReader
var _curse_k := -1
var _roots: Array[Node3D] = []
var _glyphs: Array[Node3D] = []
var _glyph_mats: Array[StandardMaterial3D] = []
var _lights: Array[OmniLight3D] = []
var _ring: MeshInstance3D
var _ring_fill: MeshInstance3D
var _ring_mat := StandardMaterial3D.new()
var _fill_mat := StandardMaterial3D.new()
var _crowns: Array[MeshInstance3D] = []
var _crown_mat := StandardMaterial3D.new()
var _t := 0.0


func _init() -> void:
	name = "EventPedestals"
	for m: StandardMaterial3D in [_ring_mat, _fill_mat, _crown_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
	_ring_mat.albedo_color = Color(GUARD, 0.35)
	_fill_mat.albedo_color = Color(GUARD, 0.8)
	_crown_mat.albedo_color = Color(ELITE, 0.85)


## Builds one pedestal per event on the floor (once; pedestals never move).
func setup(reader: WorldReader) -> void:
	_reader = reader
	for k in reader.event_count():
		var root := make_curse_altar(k) if k == reader.event_curse_altar() else make_pedestal(k)
		root.position = SimPlane.to_3d(reader.event_pos(k))
		add_child(root)
		_roots.append(root)
	if reader.event_curse_altar() >= 0:  # v0.8.0 N17 (O75): the dark room round it
		curse_room = CurseRoomView.new()
		add_child(curse_room)
		curse_room.setup(reader)
	_ring = MeshInstance3D.new()
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	_ring_fill = MeshInstance3D.new()
	_ring_fill.material_override = _fill_mat
	_ring_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_fill.visible = false
	add_child(_ring_fill)


func pedestal_count() -> int:
	return _roots.size()


## v0.8.0 N17 (O75): the Label3D nodes over the pedestals (none: the name shows only in the panel).
func label_count() -> int:
	return find_children("*", "Label3D", true, false).size()


func pedestal_root(k: int) -> Node3D:
	return _roots[k]


func glyph_energy(k: int) -> float:
	return _glyph_mats[k].emission_energy_multiplier


## Crown rings shown now (one per living elite).
func crown_count() -> int:
	var n := 0
	for c in _crowns:
		n += 1 if c.visible else 0
	return n


func ring_visible() -> bool:
	return _ring.visible


func sync(reader: WorldReader) -> void:
	_reader = reader
	_sync_ring(reader)
	_sync_crowns(reader)


func _process(delta: float) -> void:
	if _reader == null:
		return
	_t += delta
	for k in _roots.size():
		var state := _reader.event_state(k)
		var c := GLOW
		var energy := GLYPH_ENERGY
		var turn := 0.9
		match state:
			WorldReader.EVENT_ACTIVE:
				c = FIGHT if _reader.event_ambush() == k else GUARD
				energy = GLYPH_ENERGY * (1.0 + 0.6 * absf(sin(_t * 5.0)))
				turn = 2.4
			WorldReader.EVENT_DONE:
				energy = 0.15
				turn = 0.0
		var m := _glyph_mats[k]
		m.albedo_color = c
		m.emission = c
		m.emission_energy_multiplier = energy
		_lights[k].light_color = c
		_lights[k].light_energy = LIGHT_ENERGY * energy / GLYPH_ENERGY
		if k == _curse_k:  # v0.8.0 N17: its own soft light, breathing with the glyphs
			var pulse := curse_pulse() if state == WorldReader.EVENT_READY else 1.0
			m.emission_energy_multiplier = energy * pulse
			_lights[k].light_color = CURSE_LIGHT if state == WorldReader.EVENT_READY else c
			_lights[k].light_energy = CURSE_LIGHT_ENERGY * pulse * energy / GLYPH_ENERGY
		_glyphs[k].rotation.y += turn * delta
		_glyphs[k].position.y = (
			GLYPH_Y + (sin(_t * 2.0 + k) * 0.06 if state != WorldReader.EVENT_DONE else -0.2)
		)


## The pedestal model: stepped hexagonal base, a slanted lectern, the glyph crystal and its light.
func make_pedestal(k: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Pedestal%d" % k
	var stone := _stone(STONE)
	var top := _stone(STONE_TOP)
	n.add_child(_mesh(RewardViews.prism(6, 0.9, 0.82, 0.16, 0.0, 0.0, 21 + k), stone))
	n.add_child(_mesh(RewardViews.prism(6, 0.66, 0.6, 0.14, 0.16, 0.26, 23 + k), top))
	n.add_child(_mesh(RewardViews.prism(5, 0.26, 0.2, 0.72, 0.3, 0.3, 25 + k), stone))
	var lectern := _mesh(RewardViews.prism(4, 0.36, 0.42, 0.1, 0.0, 0.0, 27 + k), top)
	lectern.position.y = 1.02
	lectern.rotation_degrees.x = -18.0
	n.add_child(lectern)
	var glyph := _glyph_node(n)
	var crystal := _mesh(RewardViews.bipyramid(3, 0.16, 0.26, 0.2), _glyph_mats[k])
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glyph.add_child(crystal)
	for j in 2:
		var shard := _mesh(RewardViews.bipyramid(3, 0.04, 0.09, 0.07), _glyph_mats[k])
		shard.position = Vector3(0.24 if j == 0 else -0.24, 0.05 * (j * 2 - 1), 0.0)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glyph.add_child(shard)
	_add_light(n, 4.5)
	return n


## v0.8.0 N17 (O75): the curse room's altar: a squat dark stone altar (a plinth, a block with a sunken top, two
## horn-like side stones) and over it a cracked crystal (two halves split apart, chips between them) that glows and
## turns like a pedestal's. The owner's `curse_altar` model (docs/OWNER_TODO.md §3.1) replaces the stone once the
## manifest lists it; the crystal and its light stay.
func make_curse_altar(k: int) -> Node3D:
	var n := Node3D.new()
	n.name = "CurseAltar"
	var model := ShopModels.get_model(CURSE_MODEL_ID)
	curse_uses_model = not model.is_empty()
	if curse_uses_model:
		var body := _mesh(model["mesh"], model["material"])
		body.name = "Model"
		n.add_child(body)
	else:
		var stone := _stone(CURSE_STONE)
		var top := _stone(CURSE_TOP)
		n.add_child(_mesh(RewardViews.prism(4, 0.95, 0.9, 0.18, 0.0, 0.0, 41), stone))
		n.add_child(_mesh(RewardViews.prism(4, 0.68, 0.6, 0.62, 0.18, 0.12, 43), top))
		n.add_child(_mesh(RewardViews.prism(4, 0.78, 0.74, 0.12, 0.8, 0.0, 45), stone))
		for j in 2:
			var horn := _mesh(RewardViews.prism(3, 0.12, 0.05, 0.5, 0.0, 0.2, 47 + j), stone)
			horn.position = Vector3(0.0, 0.92, 0.52 if j == 0 else -0.52)
			horn.rotation_degrees.x = 14.0 if j == 0 else -14.0
			n.add_child(horn)
	var glyph := _glyph_node(n)
	for j in 2:  # the crystal, split in two along its height
		var half := _mesh(RewardViews.bipyramid(3, 0.15, 0.27, 0.18), _glyph_mats[k])
		half.position = Vector3(0.05 * (j * 2 - 1), 0.02 * j, 0.0)
		half.rotation_degrees.z = 9.0 * (j * 2 - 1)
		half.scale = Vector3(0.55, 1.0, 1.0)
		half.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glyph.add_child(half)
	for j in 3:  # chips flaking off the crack
		var chip := _mesh(RewardViews.bipyramid(3, 0.03, 0.06, 0.05), _glyph_mats[k])
		chip.position = Vector3(0.2 * (j - 1), -0.18 + 0.12 * j, 0.12 * (1 - j))
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glyph.add_child(chip)
	_add_light(n, CURSE_LIGHT_RANGE)
	var light := _lights[k]
	light.name = "CrystalLight"
	light.light_color = CURSE_LIGHT
	light.light_energy = CURSE_LIGHT_ENERGY
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 30.0
	light.distance_fade_length = 8.0
	_curse_k = k
	return n


## v0.8.0 N17: the curse altar's pulse now (1 ± CURSE_PULSE on the glyphs' beat; 1 under reduced motion).
func curse_pulse() -> float:
	if ViewPrefs.reduced_motion:
		return 1.0
	return 1.0 + CURSE_PULSE * sin(_t * CurseRoomView.GLOW_SPEED)


## v0.8.0 N17: the altar's crystal light (null without a curse altar; tests read it).
func curse_light() -> OmniLight3D:
	return _lights[_curse_k] if _curse_k >= 0 else null


## The glowing crystal's node and material (the next pedestal's), turned and lit by _process.
func _glyph_node(n: Node3D) -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GLOW
	mat.emission_enabled = true
	mat.emission = GLOW
	mat.emission_energy_multiplier = GLYPH_ENERGY
	_glyph_mats.append(mat)
	var glyph := Node3D.new()
	glyph.position.y = GLYPH_Y
	n.add_child(glyph)
	_glyphs.append(glyph)
	return glyph


func _add_light(n: Node3D, reach: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = LIGHT_ENERGY
	light.omni_range = reach
	light.position.y = GLYPH_Y
	n.add_child(light)
	_lights.append(light)


## The Wandering Drone's ring: the full circle dim, the share held bright.
func _sync_ring(reader: WorldReader) -> void:
	var k := reader.event_defend()
	_ring.visible = k >= 0
	_ring_fill.visible = k >= 0
	if k < 0:
		return
	var at := SimPlane.to_3d(reader.event_pos(k), 0.04)
	var r := reader.event_defend_radius_m()
	_ring.mesh = arc_mesh(r, 0.12, 1.0)
	_ring.position = at
	_ring_fill.mesh = arc_mesh(r, 0.22, reader.event_defend_progress())
	_ring_fill.position = at + Vector3(0, 0.01, 0)


func _sync_crowns(reader: WorldReader) -> void:
	var n := 0
	for i in reader.actor_count():
		if reader.actor_dead(i) or not reader.actor_elite(i):
			continue
		if n >= _crowns.size():
			var c := MeshInstance3D.new()
			c.mesh = arc_mesh(1.0, 0.1, 1.0)
			c.material_override = _crown_mat
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(c)
			_crowns.append(c)
		var crown := _crowns[n]
		var r := reader.actor_radius(i) + 0.25
		crown.scale = Vector3(r, 1.0, r)
		crown.position = SimPlane.to_3d(reader.actor_pos(i), 0.05)
		crown.visible = true
		n += 1
	for j in range(n, _crowns.size()):
		_crowns[j].visible = false


## A flat ring band on the floor (radius r, width w) covering `share` of the turn from the top.
static func arc_mesh(r: float, w: float, share: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := maxi(1, int(ceil(RING_SEGMENTS * clampf(share, 0.0, 1.0))))
	var span := TAU * clampf(share, 0.001, 1.0)
	for s in segs:
		var a0 := span * s / segs
		var a1 := span * (s + 1) / segs
		var o0 := Vector3(sin(a0), 0, cos(a0))
		var o1 := Vector3(sin(a1), 0, cos(a1))
		var p := [o0 * (r - w * 0.5), o0 * (r + w * 0.5), o1 * (r + w * 0.5), o1 * (r - w * 0.5)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(p[idx])
	return st.commit()


func _stone(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	m.vertex_color_use_as_albedo = true
	return ActorViews.flashable(m)


func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	return m
