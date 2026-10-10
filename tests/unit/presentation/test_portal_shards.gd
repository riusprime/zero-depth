extends GutTest
## v0.6.1 SW2 (owner A1: "the portals could have some of them around matching the color of the portal"): crystal
## shard clusters (ShardMesh) round both gates, in the gate's own colour (the visor blue; the Deep gate's violet), lit
## by the scene, with floating fragments; clear of the opening and the walk-in path; the gate's cues unchanged.


func _gate(deep := false) -> PortalGate:
	var g := PortalGate.new()
	add_child_autofree(g)
	if deep:
		g.set_deep()
	return g


func _crystals(n: Node) -> Array:
	return n.find_children("Crystal", "MeshInstance3D", true, false)


## Every solid vertex of the gate's shards (crystals and outline shells), in the gate's local frame.
func _shard_points(g: PortalGate) -> PackedVector3Array:
	var out := PackedVector3Array()
	var pieces: Array[Node3D] = []
	pieces.append_array(g.shard_clusters)
	pieces.append_array(g.shard_fragments)
	for p in pieces:
		for m: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
			var xf := g.global_transform.affine_inverse() * m.global_transform
			var verts: PackedVector3Array = m.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for v in verts:
				out.append(xf * v)
	return out


func test_both_gates_have_shard_clusters_and_fragments() -> void:
	for deep in [false, true]:
		var g := _gate(deep)
		assert_gte(g.shard_clusters.size(), 4, "clusters at both pillars' feet and on the lintel")
		assert_gte(g.shard_fragments.size(), 3, "a few floating fragments")
		var crystals := _crystals(g)
		assert_gte(crystals.size(), 20, "outlined shards")
		for c: MeshInstance3D in crystals:
			var m := c.material_override as StandardMaterial3D
			assert_eq(m, g.shard_material, "one shared material")
			assert_ne(m.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "lit by the scene")
			assert_true(m.emission_enabled, "a glow of its own, on from creation")
			var shell: MeshInstance3D = c.get_parent().get_meta(&"outline")
			assert_eq(shell.mesh, c.mesh, "every shard outlined")


func test_the_shards_wear_the_portals_own_colour() -> void:
	var g := _gate()
	var visor := PortalGate.visor_blue()
	assert_eq(g.shard_material.albedo_color, visor, "the gate's visor blue")
	assert_eq(g.shard_material.emission, visor)
	assert_eq(g.shard_color(), g.light.light_color, "the colour of the gate's own light")
	assert_eq(g.shard_material.albedo_color, g.portal_material.get_shader_parameter("color_mid"))
	for s: MeshInstance3D in g.shard_glows:
		var c := (s.material_override as StandardMaterial3D).albedo_color
		assert_eq(Color(c, 1.0), Color(visor, 1.0), "its glow too")
	var d := _gate(true)
	assert_eq(d.shard_material.albedo_color, PortalGate.DEEP_VIOLET, "the Deep gate's violet")
	assert_eq(d.shard_material.emission, PortalGate.DEEP_VIOLET)
	assert_eq(d.shard_color(), d.light.light_color)
	assert_eq(d.shard_material.albedo_color, d.portal_material.get_shader_parameter("color_mid"))
	for s: MeshInstance3D in d.shard_glows:
		var c := (s.material_override as StandardMaterial3D).albedo_color
		assert_eq(Color(c, 1.0), Color(PortalGate.DEEP_VIOLET, 1.0))


func test_the_shards_keep_clear_of_the_opening_and_the_walk_in_path() -> void:
	for deep in [false, true]:
		var g := _gate(deep)
		var points := _shard_points(g)
		assert_gt(points.size(), 100)
		var worst := INF
		for p in points:
			assert_true(p.x >= PortalGate.WALL_X - 0.02, "in front of the wall line: %s" % p)
			if p.y < PortalGate.OPENING_H:
				worst = minf(worst, absf(p.z))
		assert_gte(
			worst,
			PortalGate.SHARD_CLEAR_Z - 0.02,
			"below the lintel nothing is nearer the centre line than the clear half-width"
		)
		# The walk-in square (FloorLayout.GATE_FRONT wide) and the opening are inside that half-width.
		assert_gt(PortalGate.SHARD_CLEAR_Z, FloorLayout.GATE_FRONT * 0.5)
		assert_gt(PortalGate.SHARD_CLEAR_Z, PortalGate.OPENING_W * 0.5)
		for s: MeshInstance3D in g.shard_glows:
			var half := (s.mesh as QuadMesh).size.x * 0.5
			assert_gte(
				absf(s.position.z) - half, PortalGate.OPENING_W * 0.5, "glow off the opening"
			)


func test_the_gate_keeps_its_cues_and_the_shards_follow_its_state() -> void:
	var g := _gate()
	assert_eq(g.stone_blocks.size(), 14, "the stone pillars and lintel unchanged")
	assert_eq((g.portal.mesh as QuadMesh).size, Vector2(PortalGate.OPENING_W, PortalGate.OPENING_H))
	var sealed := g.shard_material.emission_energy_multiplier
	assert_almost_eq(sealed, PortalGate.SHARD_ENERGY_SEALED, 1e-5)
	g.set_sealed(false)
	var open := g.shard_material.emission_energy_multiplier
	assert_gt(open, sealed, "brighter open")
	g.flare()
	g._process(0.1)
	assert_gt(g.shard_material.emission_energy_multiplier, open, "brighter in the flare")
	assert_gt(g.light.light_energy, PortalGate.LIGHT_ENERGY_OPEN, "the gate's own flare still runs")
	g._process(PortalGate.FLARE_SECONDS)
	assert_almost_eq(g.shard_material.emission_energy_multiplier, open, 1e-5, "back after it")
	assert_true(g.shard_material.emission_enabled, "emission never toggled")


func test_the_fragments_float() -> void:
	var g := _gate()
	var before: Array = g.shard_fragments.map(func(f: Node3D) -> float: return f.position.y)
	g._process(0.4)
	var moved := 0
	for k in g.shard_fragments.size():
		var f := g.shard_fragments[k]
		var y: float = f.get_meta(&"base_y")
		assert_almost_eq(f.position.y, y, PortalGate.FRAGMENT_BOB + 1e-4, "near its spot")
		if absf(f.position.y - float(before[k])) > 1e-4:
			moved += 1
	assert_gt(moved, 0, "they bob")
