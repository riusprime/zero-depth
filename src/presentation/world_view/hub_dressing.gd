class_name HubDressing
extends RefCounted
## v0.9.0 HB3 (owner: "we need decoration, floor, some other models to decorate, a different walls we don't re use what
## we have"; the art list §4b, eight pieces delivered 2026-10-23, prepared by scripts/assets/hb3_prep.py): the Rune
## Ring's floor, walls, pillar braziers, sealed gate and dressing props, drawn from the hub's plan. Each piece is the
## owner's (ShopModels lists it) or a code stand-in when it isn't installed (L15). The plan frame is HubView's: plan
## (x, y) is local (x, 0, -y).
## - The floor: the paving (hub_ground, tiled) on the plaza, the centre medallion (hub_ground_centre) laid once under
##   the machine with its 16 sockets on the floor runes, and the walkway (hub_ground_path) along the paths: the spawn to
##   the medallion, a ring round the medallion past every station's front, the medallion to the north gate, and a band
##   along the walls;
## - the walls: 12 segments of the owner's wall (re-bent onto the plaza's ring by the prep), the north one left for the
##   gate; the south ones (between the camera and the plaza) sunk so only their top stays above the floor, as HB's low
##   south rim (nothing tall between the camera and the hero);
## - the pillar braziers: the owner's pillar at each of the hub's `pillars`, turned to the middle, with a layered fire
##   in its bowl (HubProps.fire: the VX bar);
## - the props (the crates, the crystal planters) at the hub's `props`, turned to the middle.
## Presentation only (EI-07).

const GROUND_TEX := "res://assets/textures/hub/hub_ground.png"
const CENTRE_TEX := "res://assets/textures/hub/hub_ground_centre.png"
const PATH_TEX := "res://assets/textures/hub/hub_ground_path.png"
## One paving tile's size on the floor (m).
const GROUND_TILE_M := 6.0
## The medallion's sockets lie on a ring this share of its half size (hb3_prep.py's socket_share), so the medallion is
## laid rune_ring_m / MEDALLION_SOCKET m from its centre to its edge.
const MEDALLION_SOCKET := 0.7729
## The walkway: its width (m) and one tile's length per its width (the prepared texture's 683 / 1024).
const PATH_W := 2.4
const PATH_TILE := 683.0 / 1024.0
## The band along the walls: its inner radius short of the plaza's (m).
const BAND_W := 1.6
## The wall: 12 segments of 30° (hb3_prep.py's SEGMENT_DEG), 4.6 m tall; a south one shows this much above the floor.
const SEGMENTS := 12
const WALL_H := 4.6
const SOUTH_SHOWS := 1.5
## The pillar's bowl (m over the floor) where its fire burns (the prepared pillar is 3.6 m tall).
const PILLAR_FIRE_Y := 3.42
const PILLAR_STAND_IN_H := 3.2

## The floor's layers (m over the plaza's paving; the medallion over the walkway).
const PATH_Y := 0.006
const MEDALLION_Y := 0.012


## The plaza's floor (see the header) under `plan`.
static func ground(plan: Node3D, hub: HubDefinition) -> void:
	var outer := CylinderMesh.new()
	outer.top_radius = hub.radius_m + 12.0
	outer.bottom_radius = outer.top_radius
	outer.height = 0.1
	outer.radial_segments = 48
	HubProps.mesh(
		plan, "Outer", outer, paving(HubProps.PLAZA_SEAM.darkened(0.5)), Vector3(0, -0.07, 0)
	)
	var disc := CylinderMesh.new()
	disc.top_radius = hub.radius_m + 0.6
	disc.bottom_radius = disc.top_radius
	disc.height = 0.1
	disc.radial_segments = 96
	HubProps.mesh(plan, "Plaza", disc, paving(Color(0.92, 0.9, 0.86)), Vector3(0, -0.05, 0))
	var med_r := medallion_radius(hub)
	var walk := path_material()
	var paths := Node3D.new()
	paths.name = "Paths"
	plan.add_child(paths)
	# The band along the walls, the ring past the stations' fronts, the spawn's and the gate's lanes.
	_strip(paths, "Band", _arc(hub.radius_m - BAND_W * 0.5 + 0.2, 128), BAND_W, walk)
	_strip(paths, "Ring", _arc(med_r + PATH_W * 0.5 - 0.35, 128), PATH_W, walk)
	var south := PackedVector2Array(
		[Vector2(0, -(hub.radius_m - BAND_W + 0.1)), Vector2(0, -(med_r - 0.3))]
	)
	_strip(paths, "SpawnLane", south, PATH_W, walk)
	var north := PackedVector2Array(
		[Vector2(0, med_r + PATH_W - 0.6), Vector2(0, hub.radius_m - BAND_W + 0.1)]
	)
	_strip(paths, "GateLane", north, PATH_W, walk)
	var tex: Texture2D = load(CENTRE_TEX) if ResourceLoader.exists(CENTRE_TEX) else null
	if tex != null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.roughness = 0.75
		m.metallic_specular = 0.35
		var q := PlaneMesh.new()
		q.size = Vector2.ONE * med_r * 2.0
		var mi := HubProps.mesh(plan, "Medallion", q, m, Vector3(0, MEDALLION_Y, 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:  # the stand-in: a darker disc with a carved ring along the runes
		var c := CylinderMesh.new()
		c.top_radius = med_r
		c.bottom_radius = med_r
		c.height = 0.02
		c.radial_segments = 64
		HubProps.mesh(
			plan,
			"Medallion",
			c,
			HubProps.stone(HubProps.STONE_DARK.lightened(0.1)),
			Vector3(0, MEDALLION_Y, 0)
		)


## How far the medallion reaches from the plaza's centre (m): its sockets on the runes' ring.
static func medallion_radius(hub: HubDefinition) -> float:
	return hub.rune_ring_m / MEDALLION_SOCKET


## The owner's paving (tiled, tinted `tint`), or the plaza's flagstones (HubProps.ground_material) without it.
static func paving(tint: Color) -> StandardMaterial3D:
	if not ResourceLoader.exists(GROUND_TEX):
		return HubProps.ground_material(tint)
	var m := HubProps.stone(tint, 0.95)
	m.albedo_texture = load(GROUND_TEX)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE / GROUND_TILE_M
	return m


## The walkway's material (the owner's walkway, tiling along the strip), or a darker flagstone without it.
static func path_material() -> StandardMaterial3D:
	if not ResourceLoader.exists(PATH_TEX):
		return HubProps.stone(HubProps.PLAZA.darkened(0.15))
	var m := HubProps.stone(Color.WHITE, 0.95)
	m.albedo_texture = load(PATH_TEX)
	m.texture_repeat = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## The plaza's wall: SEGMENTS of the owner's segment round the centre (the north one left for the gate), the south
## ones sunk (see the header); a stone box per segment without the model.
static func walls(plan: Node3D, hub: HubDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "Walls"
	plan.add_child(root)
	var m := ShopModels.get_model(&"hub_wall_segment")
	var span := TAU / SEGMENTS
	for k in SEGMENTS:
		var a := span * k  # plan angle from east, counter-clockwise
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.01:
			continue  # the north gate's slot
		var south := sin(a) < -0.3
		var seg := Node3D.new()
		seg.name = "Wall%d" % k
		seg.rotation.y = a - PI * 1.5  # the segment's middle lies on +z (the plan's south) in its file
		seg.position.y = -(WALL_H - SOUTH_SHOWS) if south else 0.0
		root.add_child(seg)
		if not m.is_empty():
			var mi := HubProps.mesh(seg, "Model", m["mesh"], m["material"], Vector3.ZERO)
			mi.set_meta(&"model_id", &"hub_wall_segment")
			continue
		var r := hub.radius_m + hub.wall_m * 0.5
		HubProps.box(
			seg,
			"Box",
			Vector3(TAU * r / SEGMENTS + 0.1, WALL_H, hub.wall_m),
			HubProps.stone(HubProps.STONE_LIT),
			Vector3(0, WALL_H * 0.5, r)
		)
	return root


## The pillar braziers at the hub's `pillars`, each turned to the middle with its fire; returns the fires
## (HubProps.fire) so the view can flicker their lights.
static func pillars(plan: Node3D, hub: HubDefinition) -> Array[Dictionary]:
	var fires: Array[Dictionary] = []
	var m := ShopModels.get_model(&"hub_pillar_brazier")
	var i := 0
	for p in hub.pillars:
		var node := Node3D.new()
		node.name = "Pillar%d" % i
		node.position = Vector3(p.x, 0, -p.y)
		node.rotation.y = HubLayout.facing(p)
		plan.add_child(node)
		var fire_y := PILLAR_FIRE_Y
		if not m.is_empty():
			var mi := HubProps.mesh(node, "Model", m["mesh"], m["material"], Vector3.ZERO)
			mi.set_meta(&"model_id", &"hub_pillar_brazier")
		else:
			var s := hub.pillar_half_m * 1.6
			HubProps.box(
				node,
				"Column",
				Vector3(s, PILLAR_STAND_IN_H, s),
				HubProps.stone(HubProps.STONE),
				Vector3(0, PILLAR_STAND_IN_H * 0.5, 0)
			)
			fire_y = PILLAR_STAND_IN_H + 0.15
		fires.append(HubProps.fire(node, "Fire", Vector3(0, fire_y, 0), 0.9))
		i += 1
	return fires


## The dressing props at the hub's `props` (their footprints are solid: HubLayout), turned to the middle.
static func props(plan: Node3D, hub: HubDefinition) -> void:
	var i := 0
	for d: Dictionary in hub.props:
		var at: Vector2 = d["at"]
		var node := Node3D.new()
		node.name = "Prop%d" % i
		node.position = Vector3(at.x, 0, -at.y)
		node.rotation.y = HubLayout.facing(at)
		plan.add_child(node)
		var id := StringName(d["id"])
		var stand := HubProps.stand_in(node)
		var half: Vector2 = d.get("half", Vector2.ONE * 0.5)
		HubProps.box(
			stand,
			"Box",
			Vector3(half.x * 2.0, 1.0, half.y * 2.0),
			HubProps.stone(HubProps.STONE_DARK),
			Vector3(0, 0.5, 0)
		)
		var mi := HubProps.owner_model(node, id, Vector3.ZERO, stand)
		if mi != null:
			mi.set_meta(&"model_id", id)
		i += 1


## The north gate (the owner's gateway and, apart, its two doors; or the kit's stone arch with a code slab) at plan
## (0, `gy`), its front to the plaza. Returns {"frame": its node, "doors": the node hidden when it opens}.
static func gate(plan: Node3D, hub: HubDefinition, gy: float) -> Dictionary:
	var frame := ShopModels.get_model(&"hub_sealed_gate")
	var doors := ShopModels.get_model(&"hub_sealed_gate_doors")
	var root := Node3D.new()
	root.name = "Gate"
	root.position = Vector3(0, 0, -gy)
	plan.add_child(root)
	var seal := Node3D.new()
	seal.name = "Seal"
	root.add_child(seal)
	if not frame.is_empty() and not doors.is_empty():
		HubProps.mesh(root, "Model", frame["mesh"], frame["material"], Vector3.ZERO).set_meta(
			&"model_id", &"hub_sealed_gate"
		)
		HubProps.mesh(seal, "Doors", doors["mesh"], doors["material"], Vector3.ZERO).set_meta(
			&"model_id", &"hub_sealed_gate_doors"
		)
		return {"frame": root, "doors": seal, "model": true}
	HubProps.kit_piece(
		root,
		"Arch",
		&"stone_arch",
		Vector3(hub.gate_half_m * 2.0 + 1.2, 2.6, hub.wall_m + 0.2),
		Vector3.ZERO,
		0.0,
		HubProps.STONE
	)
	HubProps.box(
		seal,
		"Slab",
		Vector3(hub.gate_half_m * 2.0, 2.1, 0.3),
		HubProps.stone(HubProps.STONE_DARK),
		Vector3(0, 1.05, 0)
	)
	return {"frame": root, "doors": seal, "model": false}


## A floor strip `w` m wide along plan points `pts` (a closed ring when its ends meet), the walkway's texture across it
## (u: one edge to the other) and tiling along it (v).
static func _strip(
	parent: Node3D, n: String, pts: PackedVector2Array, w: float, mat: Material
) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	var tile := w * PATH_TILE
	var count := pts.size()
	if count > 2 and pts[0].distance_to(pts[count - 1]) < 0.001:  # a ring: whole tiles round it, no seam
		var total := 0.0
		for i in range(1, count):
			total += pts[i - 1].distance_to(pts[i])
		tile = total / maxf(1.0, roundf(total / tile))
	for i in count:
		var p := pts[i]
		if i > 0:
			along += pts[i - 1].distance_to(p)
		var d := (pts[mini(i + 1, count - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := Vector2(d.y, -d.x) * w * 0.5  # to the strip's right
		for k in 2:
			var q := p - side if k == 0 else p + side
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(float(k), along / tile))
			st.add_vertex(Vector3(q.x, PATH_Y, -q.y))
	for i in count - 1:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	var mi := HubProps.mesh(parent, n, st.commit(), mat, Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A closed ring of `n` + 1 plan points at radius `r` (its first point repeated last).
static func _arc(r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := TAU * i / n
		out.append(Vector2(cos(a), sin(a)) * r)
	return out
