class_name EventPedestalViews
extends Node3D
## Event rooms in the world (v0.5.0 EV): one lit pedestal per event (a stepped hexagonal base, a slanted lectern
## column and a floating violet glyph crystal over it, with its own light), its name floating above while you stand
## near; the Wandering Drone's ring on the floor filling as you hold it; and a gold crown ring under every elite.
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
## The name shows within this distance (m).
const NAME_NEAR_M := 7.0
const RING_SEGMENTS := 48

var _reader: WorldReader
var _roots: Array[Node3D] = []
var _glyphs: Array[Node3D] = []
var _glyph_mats: Array[StandardMaterial3D] = []
var _lights: Array[OmniLight3D] = []
var _names: Array[Label3D] = []
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
		var root := make_pedestal(k)
		root.position = SimPlane.to_3d(reader.event_pos(k))
		add_child(root)
		_roots.append(root)
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


func name_label(k: int) -> Label3D:
	return _names[k]


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
	var p := reader.player_pos()
	for k in _roots.size():
		var near := reader.event_pos(k).distance_to(p) <= NAME_NEAR_M
		_names[k].text = tr(reader.event_name_key(k))
		var ready := reader.event_state(k) == WorldReader.EVENT_READY
		_names[k].visible = near and ready and not reader.event_open()  # the panel names it then
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
		_glyphs[k].rotation.y += turn * delta
		_glyphs[k].position.y = (
			GLYPH_Y + (sin(_t * 2.0 + k) * 0.06 if state != WorldReader.EVENT_DONE else -0.2)
		)


## The pedestal model: stepped hexagonal base, a slanted lectern, the glyph crystal and its light, the name.
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GLOW
	mat.emission_enabled = true
	mat.emission = GLOW
	mat.emission_energy_multiplier = GLYPH_ENERGY
	_glyph_mats.append(mat)
	var glyph := Node3D.new()
	glyph.position.y = GLYPH_Y
	n.add_child(glyph)
	var crystal := _mesh(RewardViews.bipyramid(3, 0.16, 0.26, 0.2), mat)
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glyph.add_child(crystal)
	for j in 2:
		var shard := _mesh(RewardViews.bipyramid(3, 0.04, 0.09, 0.07), mat)
		shard.position = Vector3(0.24 if j == 0 else -0.24, 0.05 * (j * 2 - 1), 0.0)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glyph.add_child(shard)
	_glyphs.append(glyph)
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = LIGHT_ENERGY
	light.omni_range = 4.5
	light.position.y = GLYPH_Y
	n.add_child(light)
	_lights.append(light)
	var label := Label3D.new()
	label.name = "Name"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 64
	label.outline_size = 16
	label.pixel_size = 0.008
	label.position.y = 2.6
	label.modulate = GLOW.lerp(Color.WHITE, 0.5)
	label.visible = false
	n.add_child(label)
	_names.append(label)
	return n


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
