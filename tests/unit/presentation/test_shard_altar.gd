extends GutTest
## v0.6.1 SW (owner R3): the altars in the crystal-shard look (ShardMesh): built from outlined, lit, faceted shards on a
## stone base, standing at the sim's altar on the old footprint, coloured by tier from the card-frame table, and
## every cue kept (the in-reach glow, the bobbing fragments, the arena seal, gone when used). Also the small pieces
## restyled in the same step: heal orbs, shard gems, the dropped core.

var _items: Array[ItemTable] = []


func before_all() -> void:
	_items = ContentCompiler.compile_items(ContentRepository.load_all())


func _world() -> World:
	var w := World.new(9, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	w.set_item_tables(_items)
	return w


func _meshes(n: Node) -> Array:
	return n.find_children("*", "MeshInstance3D", true, false)


## The shards' coloured MeshInstance3Ds (the "Crystal" halves of ShardMesh.outlined).
func _crystals(n: Node) -> Array:
	return n.find_children("Crystal", "MeshInstance3D", true, false)


func test_the_shard_builder_makes_outlined_lit_faceted_crystals() -> void:
	var mesh := ShardMesh.crystal(6, 0.2, 1.0, 0.3, 4)
	assert_eq(mesh.get_surface_count(), 1)
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var tones := {}
	for c in colors:
		tones[snappedf(c.r, 0.01)] = true
	assert_gte(tones.size(), 4, "bright and dark facets side by side")
	var aabb := mesh.get_aabb()
	assert_almost_eq(aabb.position.y, 0.0, 0.001, "it stands on y = 0")
	assert_almost_eq(aabb.end.y, 1.0, 0.001, "its tip at the height asked")
	assert_eq(
		ShardMesh.crystal(6, 0.2, 1.0, 0.3, 4).get_aabb(), aabb, "deterministic from the salt"
	)
	var mat := ShardMesh.crystal_material(Color.RED, 0.5)
	var piece := ShardMesh.outlined(mesh, mat, Vector3(0, 0.45, 0))
	var shell: MeshInstance3D = piece.get_meta(&"outline")
	var line := shell.material_override as StandardMaterial3D
	assert_eq(line.cull_mode, BaseMaterial3D.CULL_FRONT, "an inverted-hull outline")
	assert_eq(line.albedo_color, ShardMesh.OUTLINE, "in the dark line colour")
	assert_gt(shell.scale.x, 1.0, "a little bigger than the shard")
	assert_ne(
		mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "the shard is lit by the scene"
	)
	assert_true(mat.emission_enabled, "with a glow of its own")
	assert_true(mat.vertex_color_use_as_albedo, "its facet tones")
	piece.free()
	var cluster := ShardMesh.cluster(mat, 6, 0.8, 0.5, 2)
	assert_eq(_crystals(cluster).size(), 6, "a shard per count")
	cluster.free()


func test_the_altar_is_a_shard_cluster_on_a_stone_base_at_the_sim_altar() -> void:
	var w := _world()
	var at := Vector2(5, -3)
	var id := w.add_reward(RewardStore.Kind.ALTAR, at, 0)
	var v := RewardViews.new()
	add_child_autofree(v)
	v.sync(WorldReader.new(w))
	var n := v.node_of(id)
	assert_not_null(n)
	assert_eq(n.position, SimPlane.to_3d(at), "at the sim's altar")
	assert_eq(n.name, &"ShardAltar")
	var crystals := _crystals(n)
	assert_gte(crystals.size(), 8, "a cluster of shards and floating fragments")
	for c: MeshInstance3D in crystals:
		var m := c.material_override as StandardMaterial3D
		assert_ne(m.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "lit, not a flat fill")
		var shell: MeshInstance3D = c.get_parent().get_meta(&"outline")
		assert_eq(shell.mesh, c.mesh, "every shard outlined")
	# The footprint: nothing solid reaches past the old plinth's radius (the glow sprite and the seal ring aside).
	var far := 0.0
	for m: MeshInstance3D in _meshes(n):
		if m.name == &"Glow" or n.get_meta(&"seal").is_ancestor_of(m):
			continue
		var xf := n.global_transform.affine_inverse() * m.global_transform
		for q in m.mesh.get_faces():
			var p := xf * q
			far = maxf(far, Vector2(p.x, p.z).length())
	assert_lte(far, RewardViews.ALTAR_RADIUS + 0.06, "on the old footprint (%.2f m)" % far)
	assert_gt(far, 0.5, "the base fills it")
	w.rewards.remove_at(w.rewards.index_of(id))
	v.sync(WorldReader.new(w))
	assert_null(v.node_of(id), "a used altar goes with its reward")


func test_each_tier_wears_its_card_frame_colour() -> void:
	var v := RewardViews.new()
	add_child_autofree(v)
	var plain := v.make_altar()
	var epic := v.make_altar(true)
	var legend := v.make_altar(false, true)
	var want := {
		plain: CardFrames.tint(&"blue"),
		epic: CardFrames.tint(&"purple"),
		legend: CardFrames.tint(&"gold")
	}
	for n: Node3D in want:
		var mat: StandardMaterial3D = n.get_meta(&"crystal_mat")
		assert_eq(mat.albedo_color, want[n], "%s altar's shards" % n.get_meta(&"tier"))
		assert_eq(mat.emission, want[n], "and their glow")
		for c: MeshInstance3D in _crystals(n):
			assert_eq(c.material_override, mat, "every shard of the altar")
	assert_eq(
		RewardViews.altar_color(&"epic"), CardFrames.tint(CardFrames.FRAME[&"dash"]), "purple"
	)
	assert_eq(legend.get_meta(&"tier"), &"legendary")
	assert_true(legend.get_meta(&"legendary"))
	assert_eq((legend.get_meta(&"light") as OmniLight3D).light_color, RewardViews.LEGENDARY_LIGHT)
	for n: Node3D in want:
		n.free()


func test_in_reach_it_brightens_and_the_fragments_bob() -> void:
	var w := _world()
	var id := w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	var far_id := w.add_reward(RewardStore.Kind.ALTAR, Vector2(12, 12), 0)
	var r := WorldReader.new(w)
	var v := RewardViews.new()
	add_child_autofree(v)
	v.sync(r)
	assert_eq(r.reward_id(r.reward_in_reach()), id, "the near altar is in reach")
	var spin: Node3D = v.node_of(id).get_meta(&"spin")
	var ys := {}
	for k in 40:
		v.sync(r)
		v._process(1.0 / 30.0)
		ys[snappedf((spin.get_child(0) as Node3D).position.y, 0.001)] = true
	assert_gt(ys.size(), 5, "the fragments bob")
	var hot: StandardMaterial3D = v.node_of(id).get_meta(&"crystal_mat")
	var cold: StandardMaterial3D = v.node_of(far_id).get_meta(&"crystal_mat")
	assert_gt(
		hot.emission_energy_multiplier,
		cold.emission_energy_multiplier,
		"the usable altar glows brighter"
	)
	var hot_light: OmniLight3D = v.node_of(id).get_meta(&"light")
	var cold_light: OmniLight3D = v.node_of(far_id).get_meta(&"light")
	assert_gt(hot_light.light_energy, cold_light.light_energy, "and its light")
	var glow_hot := (v.node_of(id).get_meta(&"glow") as MeshInstance3D).material_override
	var glow_cold := (v.node_of(far_id).get_meta(&"glow") as MeshInstance3D).material_override
	assert_gt(glow_hot.albedo_color.a, glow_cold.albedo_color.a, "and its inner glow")
	assert_true(
		hot.emission_enabled and cold.emission_enabled, "emission never toggled (flash-safe)"
	)
	var seal: Node3D = v.node_of(id).get_meta(&"seal")
	assert_false(seal.visible, "no arena seal outside an arena")
	var ring := (seal.get_child(0) as MeshInstance3D).mesh as TorusMesh
	assert_gt(ring.inner_radius, RewardViews.ALTAR_RADIUS, "the seal ring still circles the base")


func test_heal_orbs_shard_gems_and_dropped_cores_wear_the_shard_look() -> void:
	var orbs := HealOrbViews.new()
	add_child_autofree(orbs)
	var orb := orbs._make()
	assert_eq(_crystals(orb).size(), 1, "a heal orb is an outlined shard")
	assert_eq(HealOrbViews.material().albedo_color, HealOrbViews.COLOR, "still green")
	assert_ne(HealOrbViews.material().shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "lit")
	assert_not_null(orb.get_meta(&"outline"))
	var shards := ShardViews.new()
	add_child_autofree(shards)
	shards._burst(Vector2.ZERO, 3, 7)
	assert_eq(shards.count(), 3)
	assert_eq(_crystals(shards).size(), 3, "every gem an outlined shard")
	assert_ne(ShardViews.gem_material().shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "lit")
	var v := RewardViews.new()
	add_child_autofree(v)
	var drop := v.make_drop(CardFrames.tint(&"pink"))
	assert_gte(_crystals(drop).size(), 3, "the core shard and its chips")
	assert_eq(drop.get_meta(&"crystal_color"), CardFrames.tint(&"pink"), "in its card's colour")
	drop.free()
