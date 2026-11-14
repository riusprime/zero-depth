extends GutTest
## An enemy's spawn reuses what an earlier one built, so a horde's top-up does not stall the frame:
## - the pieces every actor wears (ActorParts: the contact disc, the team ring, the dazed ring and the health bar) are
##   shared per size and colour, and draw as each actor's own copy did;
## - a VAT kind's proxy shadow is made once (behind the loading cover when the warm-up runs), never from a new
##   reference avatar per crowd;
## - the code-built bodies' boxes, prisms and boss pieces are one mesh per shape.

const KINDS: Array[int] = [
	ActorStore.Kind.SWARMER,
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.NEEDLE,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.SCRAP_HOUND,
	ActorStore.Kind.KILN_BEETLE,
	ActorStore.Kind.CINDER_PRIEST,
	ActorStore.Kind.BREAKER,
]


func _setup() -> Array:
	var w := CombatLab.world()
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	views.set_process(false)
	views.sync(reader)
	return [w, reader, views]


## The unshaded pieces of an actor node (its own children and the bar's), as [mesh, material] pairs.
func _pieces(node: Node3D) -> Array:
	var out := []
	for c in node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override is StandardMaterial3D:
			var mi := c as MeshInstance3D
			if (
				(mi.material_override as StandardMaterial3D).shading_mode
				== BaseMaterial3D.SHADING_MODE_UNSHADED
			):
				out.append([mi.mesh, mi.material_override])
	var bar: Node3D = node.get_meta(&"bar")
	var bmi := bar.get_child(0) as MeshInstance3D
	out.append([bmi.mesh, bmi.material_override])
	return out


func test_a_second_wave_of_the_same_kinds_makes_no_mesh_or_material() -> void:
	var s := _setup()
	var w: World = s[0]
	var views: ActorViews = s[2]
	var first := []
	for k in KINDS.size():
		first.append(w.add_enemy(KINDS[k], Vector2(3 + k * 2, 2)))
	views.sync(s[1])
	var made := views.shared_parts.made()
	assert_gt(made, 0, "the first wave made the shared pieces")
	var second := []
	for k in KINDS.size():
		second.append(w.add_enemy(KINDS[k], Vector2(3 + k * 2, -2)))
	views.sync(s[1])
	assert_eq(views.shared_parts.made(), made, "the second wave of the same kinds made none")
	for k in KINDS.size():
		var a := _pieces(views.actor_node(first[k]))
		var b := _pieces(views.actor_node(second[k]))
		assert_eq(a.size(), b.size(), "kind %d: the same pieces" % KINDS[k])
		for p in a.size():
			assert_same(a[p][0], b[p][0], "kind %d piece %d: one mesh" % [KINDS[k], p])
			assert_same(a[p][1], b[p][1], "kind %d piece %d: one material" % [KINDS[k], p])


func test_the_shared_pieces_keep_each_actors_look() -> void:
	var s := _setup()
	var w: World = s[0]
	var views: ActorViews = s[2]
	var id := w.add_enemy(ActorStore.Kind.CHARGER, Vector2(4, 0))
	views.sync(s[1])
	var node := views.actor_node(id)
	var r: float = w.actors.radius[w.actors.index_of(id)]
	var disc: CylinderMesh
	var ring: TorusMesh
	for c in node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh:
			disc = (c as MeshInstance3D).mesh
			var m := (c as MeshInstance3D).material_override as StandardMaterial3D
			assert_eq(m.albedo_color, Color(views.outline_color, 0.55), "the disc's colour")
			assert_eq(m.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "the disc blends")
		elif ring == null and c is MeshInstance3D and (c as MeshInstance3D).mesh is TorusMesh:
			ring = (c as MeshInstance3D).mesh  # The team ring comes before the dazed one
			var m := (c as MeshInstance3D).material_override as StandardMaterial3D
			assert_eq(m.albedo_color, ThemePalette.color(&"enemy_body"), "the ring's team colour")
	assert_almost_eq(disc.top_radius, r + 0.1, 0.0001, "the disc fits the radius")
	assert_almost_eq(ring.inner_radius, r + 0.16, 0.0001, "the ring fits the radius")
	assert_almost_eq(ring.outer_radius, r + 0.24, 0.0001)
	var bar := (node.get_meta(&"bar") as Node3D).get_child(0) as MeshInstance3D
	var bm := bar.material_override as StandardMaterial3D
	assert_eq(bm.albedo_color, ThemePalette.color(&"enemy_bar"), "the enemy bar's colour")
	assert_eq(bm.billboard_mode, BaseMaterial3D.BILLBOARD_ENABLED)
	assert_true(bm.billboard_keep_scale and bm.no_depth_test, "drawn over everything at its scale")
	var hero_bar := (
		(views.actor_node(w.actors.ids[0]).get_meta(&"bar") as Node3D).get_child(0)
		as MeshInstance3D
	)
	assert_eq(
		(hero_bar.material_override as StandardMaterial3D).albedo_color,
		ThemePalette.color(&"player_bar"),
		"the hero's bar keeps its own colour"
	)


func test_a_vat_kinds_proxy_shadow_is_made_once_and_warmed() -> void:
	var kind := ActorStore.Kind.SWARMER
	var was := ViewPrefs.enemy_shadows
	ViewPrefs.enemy_shadows = "proxy"
	EnemyShadows.clear_cache()
	var warm := VatCrowd.warm_proxy(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	warm.free()
	assert_true(EnemyShadows.has_proxy(kind), "the warm-up makes the shadow's mesh")
	var first := VatCrowd.shadow_mesh(kind)
	assert_not_null(first)
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var again := VatCrowd.shadow_mesh(kind)
	assert_same(again, first, "the same mesh")
	assert_eq(
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "no reference avatar built"
	)
	ViewPrefs.enemy_shadows = was


func test_code_built_shapes_are_one_mesh_per_shape() -> void:
	var box := NeedleAvatar._chamfer_box(Vector3(0.3, 0.07, 0.3), 0.015)
	assert_same(NeedleAvatar._chamfer_box(Vector3(0.3, 0.07, 0.3), 0.015), box)
	assert_ne(NeedleAvatar._chamfer_box(Vector3(0.3, 0.07, 0.31), 0.015), box, "another size")
	var prism := NeedleAvatar._prism(0.05, 0.08, 8)
	assert_same(NeedleAvatar._prism(0.05, 0.08, 8), prism)
	assert_same(BossParts.block(Vector3.ONE, 7), BossParts.block(Vector3.ONE, 7))
	assert_same(BossParts.crystal(0.4, 0.2, 93), BossParts.crystal(0.4, 0.2, 93))
	assert_same(BossParts.orb(0.36, 96, 8, 6), BossParts.orb(0.36, 96, 8, 6))
	assert_same(BossParts.tube(0.05, 0.56, 98, 12), BossParts.tube(0.05, 0.56, 98, 12))
	assert_same(BossParts.rock(Vector3.ONE, 3), BossParts.rock(Vector3.ONE, 3))
	assert_ne(BossParts.rock(Vector3.ONE, 3), BossParts.rock(Vector3.ONE, 4), "another salt")
	# The shared mesh is the one a fresh build makes (the same vertices).
	var fresh := NeedleAvatar._build_chamfer_box(Vector3(0.3, 0.07, 0.3), 0.015, 0.0)
	assert_eq(
		fresh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], box.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)


## (Its two small BoxMesh pieces, the eye slit and the bore, are still its own: cheap primitives, not built in code.)
func test_two_node_path_needles_share_their_code_built_meshes() -> void:
	var a := NeedleAvatar.new()
	a.setup()
	var b := NeedleAvatar.new()
	b.setup()
	var ma := a.find_children("*", "MeshInstance3D", true, false)
	var mb := b.find_children("*", "MeshInstance3D", true, false)
	assert_eq(ma.size(), mb.size())
	var shared := 0
	for k in ma.size():
		var mesh := (ma[k] as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			assert_same(mesh, (mb[k] as MeshInstance3D).mesh, "piece %d" % k)
			shared += 1
	assert_gt(shared, 10, "the boxes and prisms")
	a.free()
	b.free()
