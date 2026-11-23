extends GutTest
## The owner's props (docs/art/requests/v0.12.0_models.md Part 2; the owner on the barrel: "add an vfx premade
## explosion, but dont make it explode twice, just one exploding animation"; on the door: "you'll have to split the
## model for it to open"), cut by scripts/assets/props_v0120_prep.py: each one listed, at its size, standing on the
## floor and matte; the parts the game moves are their own meshes (the ice's shards, the barrel's lid, the door's
## jambs, middle and slab; the game draws only the slab, its frame the walls' own blocks). In the views: every Lockdown
## hazard draws the owner's model with the code's hot parts, the rock and star still fall; the containers and the
## barrel are his, the barrel's lid rattles on its fuse and its blast plays exactly one pack explosion; the final
## plateau's pylons are his with a crystal in the socket and the channels lit as each locks in.

## id -> [width, depth, height] (m) as prepared (the request rows; the flat hazards' height their own).
const SIZES := {
	&"container_crate": [0.87, 0.9, 0.8],
	&"container_urn": [0.78, 0.81, 0.9],
	&"container_barrel": [0.77, 0.74, 0.9],
	&"explosive_barrel": [0.61, 0.6, 1.0],
	&"approach_pylon": [1.39, 1.2, 2.4],
	&"hazard_cable": [2.0, 1.66, 0.54],
	&"hazard_rock": [1.2, 1.15, 0.8],
	&"hazard_vent": [1.29, 1.3, 0.36],
	&"hazard_ice": [1.3, 1.29, 0.2],
	&"hazard_star": [0.86, 0.89, 0.8],
	&"timed_door": [1.55, 4.43, 4.15],
}
const PARTS := {&"hazard_ice": 6, &"explosive_barrel": 2, &"timed_door": 4}


func test_each_prop_is_listed_at_its_size_on_the_floor_and_matte() -> void:
	for id: StringName in SIZES:
		assert_ne(ShopModels.listed_path(id), "", "%s listed" % id)
		var m := ShopModels.get_model(id)
		assert_false(m.is_empty(), "%s loads" % id)
		if m.is_empty():
			continue
		var box: AABB = m["aabb"]
		var want: Array = SIZES[id]
		assert_almost_eq(box.size.x, float(want[0]), 0.03, "%s width" % id)
		assert_almost_eq(box.size.z, float(want[1]), 0.03, "%s depth" % id)
		assert_almost_eq(box.size.y, float(want[2]), 0.03, "%s height" % id)
		assert_almost_eq(box.position.y, 0.0, 0.01, "%s stands on the floor" % id)
		var mat := m["material"] as StandardMaterial3D
		assert_not_null(mat.albedo_texture, "%s has its colour map" % id)
		assert_eq(mat.metallic, 0.0, "%s matte" % id)
		assert_gte(mat.roughness, 0.85, "%s matte" % id)
		assert_eq(ShopModels.parts(id).size(), int(PARTS.get(id, 1)), "%s's moving parts" % id)
	var glow := ShopModels.get_model(&"approach_pylon")["material"] as StandardMaterial3D
	assert_not_null(glow.emission_texture, "the pylon's channels in an emission map")


func test_every_hazard_is_the_owners_with_the_codes_hot_parts() -> void:
	var w := LockLab.world()
	assert_not_null(w, "a floor with a Lockdown")
	if w == null:
		return
	w.floor_layout.lockdown_kinds[0] = WorldReader.LOCKDOWN_HAZARD
	var reader := WorldReader.new(w)
	for b in LockdownView.HAZARDS:
		var v := LockdownView.new()
		add_child_autofree(v)
		v.setup(reader, b)
		assert_true(v.hazard_uses_model, "%s: the owner's %s" % [b, v.hazard_id])
		assert_true(v.has_node("Hazard/Model"), "%s: drawn" % b)
		match v.hazard_id:
			&"hazard_cable":
				assert_true(v.has_node("Hazard/Model/Spark"), "the cable sparks")
			&"hazard_vent":
				assert_true(v.has_node("Hazard/Model/Crack"), "the vent's crack glows")
				assert_true(v.has_node("Hazard/Model/Plume"), "and breathes heat")
			&"hazard_ice":
				assert_eq(v.shard_count(), 6, "the plate in its shards")
	# The ice cracks apart and the rock falls, over the impact.
	for b in [&"frozen_shore", &"night_rocks"]:
		var v := LockdownView.new()
		add_child_autofree(v)
		v.setup(reader, b)
		v._impact.visible = true
		v._impact_left = LockdownView.IMPACT_S
		v._process(0.01)
		var high := (v._impact.get_child(0) as Node3D).position.y
		v._process(LockdownView.IMPACT_S * 0.5)
		if b == &"night_rocks":
			assert_gt(high, 3.0, "the rock starts in the sky")
			assert_almost_eq(
				(v._impact.get_child(0) as Node3D).position.y, 0.0, 0.01, "and lands on the floor"
			)
		else:
			var s0 := v.get_node("Hazard/Model/Shard0") as Node3D
			assert_false(s0.transform.basis.is_equal_approx(Basis.IDENTITY), "the shards tip apart")


func _view(w: World) -> WorldViewRoot:
	var biome: BiomeDefinition = SharedContent.repo().get_def(&"biomes", &"ruins")
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	add_child_autofree(v)
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	return v


func test_the_barrel_rattles_and_bursts_in_exactly_one_explosion() -> void:
	var w := CrackLab.world(&"blade", false)
	if w == null:
		return
	var b := w.breakables
	var at := w.floor_layout.start_pos + Vector2(0.0, 3.0)
	b.add(at, Breakables.Kind.CRATE, 0, 0, 0)
	b.add(at + Vector2(8.0, 0.0), Breakables.Kind.EXPLOSIVE, 0, 0, 0)
	var crate := b.pos.size() - 2
	var barrel := b.pos.size() - 1
	var v := _view(w)
	var bv := v.breakables
	assert_true(bv.props[crate].has_node("Model"), "the owner's crate")
	assert_true(bv.props[barrel].has_node("Model"), "the owner's barrel")
	var lid := bv.props[barrel].get_node_or_null("Lid") as Node3D
	assert_not_null(lid, "its lid and fuse a part of their own")
	assert_not_null(v.pack_fx, "the packs are there")
	if lid == null or v.pack_fx == null:
		return
	var before := int(v.pack_fx.spawned_in.get(&"explosion", 0))
	Breakables.hit(w, crate)
	v.sync()
	assert_eq(bv.explosions, 0, "a crate breaks into chips, no explosion")
	Breakables.hit(w, barrel)
	var rattled := false
	for k in 90:
		w.step(InputFrame.new())
		v.sync()
		rattled = rattled or lid.position.y > 0.0
	assert_true(rattled, "the lid rattles while the fuse burns")
	assert_false(bv.props[barrel].visible, "the barrel blew")
	for k in 60:  # a second's play past the blast: nothing replays it
		w.step(InputFrame.new())
		v.sync()
		bv._process(1.0 / 60.0)
	assert_eq(bv.explosions, 1, "one explosion for the barrel")
	assert_eq(int(v.pack_fx.spawned_in.get(&"explosion", 0)) - before, 1, "the pack's, played once")
	assert_null(bv.find_child("Blast", true, false), "no code ball of fire beside it")


func test_the_owners_pylons_light_their_socket_and_channels() -> void:
	var w := FinalLab.approach(FinalLab.run_state(20261022))
	CombatLab.idle(w, 60)
	var reader := WorldReader.new(w)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var v := FinalApproachView.new()
	add_child_autofree(v)
	v.setup(reader, rig)
	assert_true(v.pylon_uses_model, "the owner's approach_pylon")
	var p0 := v.pylons[0]
	assert_true(
		p0.has_node("Model") and p0.has_node("Crystal"), "the model, a crystal in its socket"
	)
	var mat := (p0.get_node("Model") as MeshInstance3D).get_surface_override_material(0)
	var dark := (mat as StandardMaterial3D).emission_energy_multiplier
	w.actors.set_pos(0, w.floor_layout.pylons[0])
	w.step(InputFrame.make(Vector2i.ZERO, 0, 1000, InputFrame.INTERACT, InputFrame.INTERACT))
	v.sync(reader)
	assert_true(v.locked[0], "pylon A locked in")
	assert_gt(
		(mat as StandardMaterial3D).emission_energy_multiplier, dark + 2.0, "its channels light"
	)
	assert_eq((mat as StandardMaterial3D).emission, FinalApproachView.VIOLET, "violet")
	var other := (v.pylons[1].get_node("Model") as MeshInstance3D).get_surface_override_material(0)
	assert_ne(other, mat, "each pylon lights its own")
