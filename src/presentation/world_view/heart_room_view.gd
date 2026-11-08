class_name HeartRoomView
extends Node3D
## v0.11.0 O14b (owner Q-O14b "Both"; OWNER_QUESTIONS §J N1, N2; RUNIC_CLUES.md): the hidden room under the Hollow
## Crown's throne, reading only (WorldReader.heart_*). Out of sight until its cracked wall breaks (BreakablesView draws
## the wall and its rubble); then:
## - the room: a floating slab of the arena's dark stone beyond the ring, walled round in the ring's stone (the near
##   walls low, LOW_H, so the iso camera sees in), lit by a dim violet light;
## - the rune slab on the far wall: the lore lines (RunicLinesDefinition.heart_lines) carved in Elder Futhark glyphs
##   (RunicGlyphs strokes, as the Runic Stone's ring: thin violet emissive ribbons), never translated;
## - the pedestal in the middle: a stone column holding the City's Heart (a code crystal, crimson) in the pack's flare
##   orb glow (PD-13: `o14b_heart_glow`, magic_orb_flare_vfx_02 tinted crimson), both gone once it is taken;
## - the sealed door (N2) on the far wall: a stone frame taller than the walls and a dark leaf with a faint crimson
##   seam; within its reach the Runic Stone's speech bubble (RuneBubble) speaks its line
##   (RunicLinesDefinition.sealed_line, "THE CROWN IS NOT YET REMEMBERED") in runes.
## The shock ring of a saved blow is RelicPulseView's (any floor). Presentation only: nothing here writes the sim.

const STONE := Color("#3B3150")
const STONE_DARK := Color("#251E33")
const VIOLET := Color("#9B6BFF")
const CRIMSON := Color("#FF3A5C")
const WALL_H := 1.5
## The walls between the room and the camera (its end wall and its near side wall) stand this high.
const LOW_H := 0.5
const SLAB_H := 2.4
const PEDESTAL_H := 1.0
const DOOR_H := 2.8
const DOOR_W := 2.2
## A carved glyph's height (m), a stroke's width, the gaps between glyphs and rows, glyphs a row.
const GLYPH_M := 0.2
const STROKE_M := 0.03
const GLYPH_GAP_M := 0.06
const ROW_GAP_M := 0.1
const ROW_GLYPHS := 14
const GLOW_ID := &"o14b_heart_glow"

## Built pieces, for tests and the tour: the room (hidden until revealed), the heart on the pedestal, the glyphs carved
## on the slab, the door's leaf and the bubble.
var root: Node3D
var revealed := false
var heart: Node3D
var glyphs_carved := 0
var door_leaf: MeshInstance3D
var bubble := RuneBubble.new()
var pack_fx: PackFx
var heart_lines := PackedStringArray()
var sealed_line := ""
var glow: Node3D
var _reader: WorldReader
var _layer := CanvasLayer.new()
var _t := 0.0


## `lines`: the Runic Stone's lines definition (its heart_lines and sealed_line), or null (none carved, none spoken).
func setup(reader: WorldReader, lines: RunicLinesDefinition) -> void:
	name = "HeartRoom"
	_reader = reader
	if lines != null:
		heart_lines = lines.heart_lines
		sealed_line = lines.sealed_line
	root = Node3D.new()
	root.name = "Room"
	add_child(root)
	_build_room(reader)
	_build_slab(reader)
	_build_pedestal(reader)
	_build_door(reader)
	_layer.name = "HeartBubble"
	add_child(_layer)
	_layer.add_child(bubble)
	root.visible = false
	sync(reader)


func _process(delta: float) -> void:
	_t += delta
	if heart != null and heart.visible and not ViewPrefs.reduced_motion:
		heart.rotation.y = _t * 0.8
		heart.position.y = PEDESTAL_H + 0.45 + 0.06 * sin(_t * 1.6)
	if bubble.is_open() and _reader != null:
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam != null:
			bubble.anchor_px = cam.unproject_position(
				SimPlane.to_3d(_reader.heart_door_pos(), DOOR_H + 0.3)
			)


func sync(reader: WorldReader) -> void:
	if not revealed and reader.crack_broken():
		revealed = true
		root.visible = true
	var here := reader.heart_relic_here()
	if heart != null:
		heart.visible = here
	if revealed and here and glow == null and pack_fx != null:
		glow = pack_fx.spawn(
			GLOW_ID, heart.global_position if heart.is_inside_tree() else _heart_at(), 1.0, {}, 0.0
		)
	elif glow != null and not here:
		pack_fx.release(glow)
		glow = null
	var speak := (
		revealed and sealed_line != "" and reader.heart_door_sealed() and reader.heart_door_near()
	)
	if speak and not bubble.is_open():
		bubble.show_line(RuneCipher.encode(sealed_line))
	elif not speak and bubble.is_open():
		bubble.close()


func _heart_at() -> Vector3:
	return SimPlane.to_3d(_reader.heart_pedestal_pos(), PEDESTAL_H + 0.45)


func _mat(c: Color, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material, yaw := 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


## The ground slab, its rock underside, the walls (all but the pedestal's and the slab's blocks) and the light.
func _build_room(reader: WorldReader) -> void:
	var room := reader.heart_room_rect()
	var outer := room.grow(reader.heart_wall_thickness())
	var stone := _mat(STONE)
	var ground := _box(
		root,
		Vector3(outer.size.x, 0.2, outer.size.y),
		SimPlane.to_3d(outer.get_center(), -0.1),
		_mat(STONE_DARK.lightened(0.08))
	)
	ground.name = "Ground"
	var under := _box(
		root,
		Vector3(outer.size.x * 0.8, 2.4, outer.size.y * 0.8),
		SimPlane.to_3d(outer.get_center(), -1.4),
		_mat(STONE_DARK.darkened(0.3))
	)
	under.name = "Underside"
	under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pedestal := reader.heart_pedestal_pos()
	var slab := reader.heart_slab_pos()
	var k := 0
	for o: Obb in reader.heart_walls():
		if o.center == pedestal or o.center == slab:
			continue
		var low := o.center.x > room.end.x or o.center.y < room.position.y
		var h := LOW_H if low else WALL_H
		var node := _box(
			root,
			Vector3(o.half.x * 2.0, h, o.half.y * 2.0),
			SimPlane.to_3d(o.center, h * 0.5),
			stone,
			SimPlane.yaw_of(o.angle)
		)
		node.name = "Wall%d" % k
		k += 1
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = VIOLET
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.position = SimPlane.to_3d(room.get_center(), 3.0)
	root.add_child(light)


## The rune slab on the far wall and the heart lines carved on its room face (3D +Z: sim -Y).
func _build_slab(reader: WorldReader) -> void:
	var at := reader.heart_slab_pos()
	var half := reader.heart_slab_half()
	var slab := _box(
		root,
		Vector3(half.x * 2.0, SLAB_H, half.y * 2.0),
		SimPlane.to_3d(at, SLAB_H * 0.5),
		_mat(STONE_DARK)
	)
	slab.name = "RuneSlab"
	var rows: Array = []
	for line in heart_lines:
		rows.append_array(RuneCipher.wrap(RuneCipher.encode(line), ROW_GLYPHS))
	if rows.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := GLYPH_M / RunicGlyphs.H
	var cell := RunicGlyphs.W * s + GLYPH_GAP_M
	var face_z := half.y + 0.012
	var top := SLAB_H * 0.5 - 0.3
	for r in rows.size():
		var row: Array = rows[r]
		var x0 := -cell * row.size() * 0.5
		var y0 := top - r * (GLYPH_M + ROW_GAP_M)
		for i in row.size():
			var g: int = row[i]
			if g == RuneCipher.GAP:
				continue
			glyphs_carved += 1
			for stroke: PackedVector2Array in RunicGlyphs.strokes(g):
				for j in stroke.size() - 1:
					var a := Vector3(x0 + i * cell + stroke[j].x * s, y0 - stroke[j].y * s, face_z)
					var b := Vector3(
						x0 + i * cell + stroke[j + 1].x * s, y0 - stroke[j + 1].y * s, face_z
					)
					_ribbon(st, a, b)
	var mi := MeshInstance3D.new()
	mi.name = "Glyphs"
	mi.mesh = st.commit()
	var m := _mat(VIOLET.lightened(0.2), VIOLET, 2.2)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	slab.add_child(mi)


## A flat ribbon from a to b on the slab's face (its normal +Z).
static func _ribbon(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var d := b - a
	if d.length() < 0.0001:
		return
	var side := d.cross(Vector3(0, 0, 1)).normalized() * STROKE_M * 0.5
	var ext := d.normalized() * STROKE_M * 0.5
	var a2 := a - ext
	var b2 := b + ext
	for v in [a2 - side, a2 + side, b2 + side, a2 - side, b2 + side, b2 - side]:
		st.add_vertex(v)


## The pedestal and the heart on it.
func _build_pedestal(reader: WorldReader) -> void:
	var at := reader.heart_pedestal_pos()
	var p := Node3D.new()
	p.name = "Pedestal"
	p.position = SimPlane.to_3d(at)
	root.add_child(p)
	var side := reader.heart_pedestal_half() * 2.0
	_box(
		p,
		Vector3(side, PEDESTAL_H, side),
		Vector3(0, PEDESTAL_H * 0.5, 0),
		_mat(STONE.lightened(0.05))
	)
	_box(p, Vector3(side + 0.3, 0.15, side + 0.3), Vector3(0, PEDESTAL_H, 0), _mat(STONE_DARK))
	heart = Node3D.new()
	heart.name = "CityHeart"
	heart.position = Vector3(0, PEDESTAL_H + 0.45, 0)
	p.add_child(heart)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BossParts.crystal(0.55, 0.2, 1411)
	mesh.material_override = _mat(Color("#8A1830"), CRIMSON, 2.6)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	heart.add_child(mesh)


## The sealed door on the far wall: two jambs and a lintel above the wall, a dark leaf with a crimson seam.
func _build_door(reader: WorldReader) -> void:
	var d := Node3D.new()
	d.name = "SealedDoor"
	d.position = SimPlane.to_3d(reader.heart_door_pos())
	root.add_child(d)
	var stone := _mat(STONE.lightened(0.08))
	var depth := reader.heart_wall_thickness() + 0.2
	for s in [-1.0, 1.0]:
		_box(
			d,
			Vector3(0.4, DOOR_H, depth),
			Vector3(s * (DOOR_W * 0.5 + 0.2), DOOR_H * 0.5, -depth * 0.5 + 0.1),
			stone
		)
	_box(d, Vector3(DOOR_W + 0.8, 0.4, depth), Vector3(0, DOOR_H + 0.2, -depth * 0.5 + 0.1), stone)
	door_leaf = _box(
		d,
		Vector3(DOOR_W, DOOR_H, 0.25),
		Vector3(0, DOOR_H * 0.5, 0.05),
		_mat(STONE_DARK.darkened(0.2))
	)
	door_leaf.name = "Leaf"
	var seam := _box(
		door_leaf,
		Vector3(0.05, DOOR_H * 0.9, 0.02),
		Vector3(0, 0, 0.14),
		_mat(CRIMSON, CRIMSON, 1.6)
	)
	seam.name = "Seam"
	seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
