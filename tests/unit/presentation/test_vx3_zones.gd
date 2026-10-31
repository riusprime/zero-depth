# gdlint: disable=max-public-methods
extends GutTest
## v0.10.0 VX3 (VFX_PACK R19-R26, R28-R30, R41, I7): the zones, rings, element bursts and enemy statuses are the
## pack's effects (VfxLayer, VfxPackViews, ElementVisuals, StatusVisuals): each spawns its pack id with its colours, a
## held one (a patch, a ring, a status, an orb) lives while it is drawn and goes back when it is not, a burst spawns
## once, a full family draws the old look instead, and the hero's fire patch is in ground-safe colours (I7).

var _layer: VfxLayer
var _fx: PackFx
var _saved := ""


func before_each() -> void:
	_saved = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"
	_layer = add_child_autofree(VfxLayer.new())
	_fx = add_child_autofree(PackFx.new())
	_layer.pack_fx = _fx


func after_each() -> void:
	ViewPrefs.effects_density = _saved


## One frame at `now`, `draw` called inside it.
func _frame(now: float, draw: Callable) -> void:
	_layer.begin(now)
	draw.call()
	_layer.finish()


## The live nodes of `id` (PackFx's own list).
func _live(id: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e: Dictionary in _fx.get(&"_live"):
		if e["id"] == id:
			out.append(e["node"])
	return out


func _live_any(ids: Array[StringName]) -> int:
	var n := 0
	for id in ids:
		n += _live(id).size()
	return n


## The effects spawned that are not floor-mark effects (v0.10.0 VX7: a mark's decal carries a pack effect too, which
## these tests do not count).
func _spawned() -> int:
	return _fx.spawned - _fx.live_count(&"mark")


func test_the_table_has_every_vx3_id_with_its_scene() -> void:
	for id: StringName in [
		&"zone_fire_a",
		&"zone_fire_b",
		&"zone_fire_foe_a",
		&"zone_fire_foe_b",
		&"zone_frost_a",
		&"zone_frost_d",
		&"zone_frost_mist",
		&"zone_venom_a",
		&"zone_venom_b",
		&"zone_bleed",
		&"fumes_cloud",
		&"ring_fire",
		&"ring_frost",
		&"ring_venom",
		&"ring_bleed",
		&"burst_frost",
		&"burst_shatter",
		&"burst_venom",
		&"burst_bleed",
		&"burst_puddle",
		&"burst_wildfire",
		&"status_burn_a",
		&"status_burn_b",
		&"status_burn_c",
		&"status_poison",
		&"status_poison_bubble",
		&"status_frost_a",
		&"status_frost_b",
		&"guard_orb",
	]:
		assert_true(_fx.has_id(id), "%s is in the table" % id)
	var def := PackFx.shared_def()
	assert_eq(def.validate().size(), 0)
	assert_eq(def.families[def.row(&"fumes_cloud")], &"cloud", "the cloud is the capped family")


# --- Fire patches (R21) and I7 --------------------------------------------------------------------------------
func test_a_hero_fire_patch_is_one_held_area_in_ground_safe_colours() -> void:
	var at := Vector3(2, 0, 1)
	for k in 5:
		_frame(float(k), func() -> void: _layer.field(&"fire", at, 1.2, 1.0, float(k), 7))
	assert_eq(_spawned(), 1, "one effect for five frames of one patch")
	var ids: Array[StringName] = [&"zone_fire_a", &"zone_fire_b"]
	assert_eq(_live_any(ids), 1)
	assert_eq(_fx.live_count(&"area"), 1)
	var node := _live(ids[absi(7) % 2])[0]
	var wave := node.get_node("WaveMesh") as MeshInstance3D
	var mat := wave.material_override as ShaderMaterial
	assert_not_null(mat, "the patch's own tinted material")
	var core: Color = mat.get_shader_parameter(&"edge_color")
	var deep: Color = mat.get_shader_parameter(&"main_color")
	assert_eq(core, AttackFormLooks.ground_safe(ElementLooks.core(&"ember")))
	assert_eq(deep, AttackFormLooks.ground_safe(ElementLooks.deep(&"ember")))
	assert_false(AttackFormLooks.is_hostile_hue(core), "I7: not a telegraph's hue")
	assert_false(AttackFormLooks.is_hostile_hue(deep), "I7: the deep tone leaned cooler too")


func test_i7_the_hero_fire_colours_pass_ground_safe_and_an_enemys_keep_the_warm_hue() -> void:
	var hero := VfxPackViews.kind_colors(&"fire", true)
	for key: StringName in hero:
		var c: Color = hero[key]
		assert_false(AttackFormLooks.is_hostile_hue(c), "hero %s is ground-safe" % key)
		assert_eq(c, AttackFormLooks.ground_safe(c), "idempotent")
	var foe := VfxPackViews.kind_colors(&"fire", false)
	assert_true(
		AttackFormLooks.is_hostile_hue(foe[&"tertiary"]),
		"the plain deep ember is in the hostile band: the hero's would have been leaned"
	)
	assert_ne(hero[&"tertiary"], foe[&"tertiary"])
	var bleed := VfxPackViews.kind_colors(&"bleed", true)
	assert_false(AttackFormLooks.is_hostile_hue(bleed[&"primary"]), "a hero bleed pool too")


func test_an_enemy_fire_patch_is_fire_area_06_or_07_in_the_scenes_own_warm_colours() -> void:
	_frame(0.0, func() -> void: _layer.field(&"fire", Vector3.ZERO, 1.2, 1.0, 0.0, 8, true))
	var ids: Array[StringName] = [&"zone_fire_foe_a", &"zone_fire_foe_b"]
	assert_eq(_live_any(ids), 1, "a hostile patch")
	assert_eq(_live_any([&"zone_fire_a", &"zone_fire_b"]), 0, "not the hero's scenes")
	var wave := _live(ids[absi(8) % 2])[0].get_node("WaveMesh") as MeshInstance3D
	assert_null(wave.material_override, "no tint: the scene's own colours")


func test_a_patch_goes_back_when_it_is_no_longer_drawn() -> void:
	_frame(0.0, func() -> void: _layer.field(&"fire", Vector3.ZERO, 1.2, 1.0, 0.0, 3))
	_frame(1.0, func() -> void: _layer.field(&"fire", Vector3.ZERO, 1.2, 1.0, 1.0, 3))
	assert_eq(_fx.live_count(&"area"), 1)
	_frame(2.0, func() -> void: pass)
	assert_eq(_fx.live_count(&"area"), 0, "released the frame nothing drew it")
	_frame(3.0, func() -> void: _layer.field(&"fire", Vector3.ZERO, 1.2, 1.0, 3.0, 3))
	assert_eq(_fx.live_count(&"area"), 1, "and it comes back from the pool")
	assert_eq(_spawned(), 2)


func test_two_copies_of_one_patch_are_two_effects_and_overlap_thins() -> void:
	_frame(
		0.0,
		func() -> void:
			_layer.field(&"fire", Vector3(0, 0, 0), 1.2, 1.0, 0.0, 5)
			_layer.field(&"fire", Vector3(6, 0, 0), 1.2, 1.0, 0.0, 5)
			# another patch right on top of the first one: it draws no flames of its own
			_layer.field(&"fire", Vector3(0.3, 0, 0), 1.2, 1.0, 0.0, 6)
	)
	assert_eq(_fx.live_count(&"area"), 2)


# --- Frost, venom, bleed (R22, R23, R25) ------------------------------------------------------------------------
func test_a_frost_field_is_an_ice_area_and_a_mist_in_the_frost_colours() -> void:
	_frame(0.0, func() -> void: _layer.field(&"frost", Vector3.ZERO, 1.5, 1.0, 0.0, 1))
	var ice: Array[StringName] = [
		&"zone_frost_a", &"zone_frost_b", &"zone_frost_c", &"zone_frost_d"
	]
	assert_eq(_live_any(ice), 1)
	assert_eq(_live(&"zone_frost_mist").size(), 1)
	var node := _live_any_node(ice)
	assert_eq(node.get("primary_color"), ElementLooks.core(&"frost"))


func _live_any_node(ids: Array[StringName]) -> Node3D:
	for id in ids:
		var l := _live(id)
		if not l.is_empty():
			return l[0]
	return null


func test_a_venom_field_is_a_poison_puddle() -> void:
	_frame(0.0, func() -> void: _layer.field(&"venom", Vector3.ZERO, 1.5, 1.0, 0.0, 2))
	var ids: Array[StringName] = [&"zone_venom_a", &"zone_venom_b"]
	assert_eq(_live_any(ids), 1)
	assert_eq(_live_any_node(ids).get("primary_color"), ElementLooks.core(&"venom"))


func test_a_bleed_pool_is_the_puddle_in_bleeds_colours_leaned_ground_safe() -> void:
	_frame(0.0, func() -> void: _layer.field(&"bleed", Vector3.ZERO, 1.5, 1.0, 0.0, 2))
	var nodes := _live(&"zone_bleed")
	assert_eq(nodes.size(), 1)
	var want := AttackFormLooks.ground_safe(ElementLooks.core(&"bleed"))
	assert_eq(nodes[0].get("primary_color"), want)
	assert_ne(want, ElementLooks.core(&"bleed"), "bleed's dark red is in the hostile band: leaned")


func test_the_patch_falls_back_to_the_old_look_when_the_area_family_is_full() -> void:
	ViewPrefs.effects_density = "low"  # the cap is 4
	var cap := _fx.cap_for(&"area")
	_layer.begin(0.0)
	for k in cap:
		_layer.field(&"venom", Vector3(k * 8.0, 0, 0), 1.2, 1.0, 0.0, 100 + k)
	assert_eq(_fx.live_count(&"area"), cap)
	var asked := _layer.sprites_asked
	var spawned := _spawned()
	_layer.field(&"venom", Vector3(0, 0, 40), 1.2, 1.0, 0.0, 999)
	_layer.finish()
	assert_eq(_spawned(), spawned, "no room: nothing evicted")
	assert_gt(_layer.sprites_asked, asked, "the old bubbles and splashes draw instead")


func test_without_the_pack_the_old_patch_draws() -> void:
	_layer.pack_fx = null
	_frame(0.0, func() -> void: _layer.field(&"fire", Vector3.ZERO, 1.2, 1.0, 0.0, 3))
	assert_eq(_fx.spawned, 0)
	assert_gt(_layer.sprites_asked, 0)


# --- Rings (R26) --------------------------------------------------------------------------------------------------
func test_an_element_ring_is_a_held_pack_ring_that_follows_the_radius() -> void:
	for k in 4:
		_frame(
			float(k),
			func() -> void: _layer.ring(&"frost", Vector3.ZERO, 0.5 + k, 1.0, float(k), 11)
		)
	assert_eq(_fx.spawned, 1)
	var nodes := _live(&"ring_frost")
	assert_eq(nodes.size(), 1)
	assert_almost_eq(nodes[0].scale.x, 3.5 * VfxPackViews.ZONE_PER_M[&"ring_frost"], 0.001)
	_frame(5.0, func() -> void: pass)
	assert_eq(_fx.live_count(&"area"), 0, "gone with the ring")
	for kind in [&"fire", &"venom", &"bleed"]:
		_frame(9.0, func() -> void: _layer.ring(kind, Vector3.ZERO, 1.0, 1.0, 9.0, 12))
		assert_eq(_live(VfxPackViews.RING_IDS[kind]).size(), 1, "%s ring" % kind)
		_frame(10.0, func() -> void: pass)


func test_frost_nova_and_ember_ward_play_their_pack_rings_once() -> void:
	var view: ElementVisuals = add_child_autofree(ElementVisuals.new())
	view.pack_fx = _fx
	assert_true(view._pack_ring(Vector2(1, 1), 3.0, &"ring_frost", &"frost"))
	assert_eq(_live(&"ring_frost").size(), 1)
	assert_true(view._pack_ring(Vector2(1, 1), 3.0, &"ring_fire", &"fire"))
	assert_eq(_live(&"ring_fire").size(), 1)
	assert_eq(
		_live(&"ring_fire")[0].get("primary_color"),
		VfxPackViews.kind_colors(&"fire", true)[&"primary"]
	)
	view.pack_fx = null
	assert_false(view._pack_ring(Vector2(1, 1), 3.0, &"ring_frost", &"frost"), "no pack: the torus")


# --- Bursts (R19, R20, status payoffs) --------------------------------------------------------------------------
func test_a_frost_burst_spawns_one_explosion_for_all_its_frames() -> void:
	for k in 10:
		_frame(float(k), func() -> void: _layer.burst(&"frost", Vector3.ZERO, 2.0, k / 10.0, 21))
	assert_eq(_spawned(), 1)
	assert_eq(_live(&"burst_frost").size(), 1)
	assert_eq(_live(&"burst_frost")[0].get("primary_color"), ElementLooks.core(&"frost"))
	assert_eq(_live(&"burst_shatter").size(), 0, "a plain frost burst has no ice patch")


func test_a_shatter_adds_a_small_ice_patch() -> void:
	_frame(0.0, func() -> void: _layer.burst(&"shatter", Vector3.ZERO, 1.6, 0.0, 22))
	assert_eq(_live(&"burst_frost").size(), 1)
	assert_eq(_live(&"burst_shatter").size(), 1)
	assert_eq(_spawned(), 2)


func test_venom_and_bleed_bursts_are_a_bubble_and_a_short_puddle() -> void:
	_frame(0.0, func() -> void: _layer.burst(&"venom", Vector3.ZERO, 1.5, 0.1, 23))
	assert_eq(_live(&"burst_venom").size(), 1)
	assert_eq(_live(&"burst_puddle").size(), 1)
	_frame(1.0, func() -> void: _layer.burst(&"bleed", Vector3(8, 0, 0), 1.5, 0.1, 24))
	assert_eq(_live(&"burst_bleed").size(), 1)
	assert_eq(_live(&"burst_puddle").size(), 2)
	assert_eq(_live(&"burst_bleed")[0].get("primary_color"), ElementLooks.core(&"bleed"))
	assert_eq(_spawned(), 4, "no more on later frames")
	_frame(2.0, func() -> void: _layer.burst(&"bleed", Vector3(8, 0, 0), 1.5, 0.2, 24))
	assert_eq(_spawned(), 4)


func test_wildfire_is_fire_area_03() -> void:
	_frame(0.0, func() -> void: _layer.burst(&"wildfire", Vector3.ZERO, 1.6, 0.0, 25))
	assert_eq(_live(&"burst_wildfire").size(), 1)
	assert_eq(
		_live(&"explosion_fire_a").size() + _live(&"explosion_fire_b").size(), 0, "not the VX0 fire"
	)


func test_a_burst_with_no_room_draws_the_old_look_for_all_its_frames() -> void:
	ViewPrefs.effects_density = "low"
	var cap := _fx.cap_for(&"explosion")
	_layer.begin(0.0)
	for k in cap:
		_layer.burst(&"frost", Vector3(k * 30.0, 0, 0), 2.0, 0.1, 300 + k)
	_layer.finish()
	assert_eq(_fx.live_count(&"explosion"), cap)
	var spawned := _fx.spawned
	_layer.begin(1.0)
	var asked := _layer.sprites_asked
	_layer.burst(&"frost", Vector3(0, 0, 300), 2.0, 0.1, 777)
	assert_eq(_fx.spawned, spawned, "no room")
	assert_gt(_layer.sprites_asked, asked, "the crystals draw")
	_layer.finish()
	_layer.begin(2.0)
	asked = _layer.sprites_asked
	_layer.burst(&"frost", Vector3(0, 0, 300), 2.0, 0.2, 777)
	assert_gt(_layer.sprites_asked, asked, "and on the next frame too")
	_layer.finish()


# --- Statuses on an enemy (R28-R30) and the guard orbs (R41) ------------------------------------------------------
func test_burn_is_a_held_pack_flame_that_follows_the_enemy_and_ends_with_the_status() -> void:
	var burns: Array[StringName] = [&"status_burn_a", &"status_burn_b", &"status_burn_c"]
	var asked := 0
	for k in 3:
		_frame(float(k), func() -> void: _layer.status(Vector3(k, 0, 0), 0.4, {&"burn": 2}, 5, 0.9))
	assert_eq(_live_any(burns), 1, "one flame scene on the body")
	assert_eq(_fx.spawned, 1)
	var node := _live(burns[absi(5) % 3])[0]
	assert_almost_eq(node.global_position.x, 2.0, 0.001, "it followed the enemy")
	_frame(3.0, func() -> void: pass)
	assert_eq(_live_any(burns), 0, "released when the status ended")
	assert_eq(asked, 0)


func test_burn_varies_by_enemy() -> void:
	_layer.begin(0.0)
	for sd in 3:
		_layer.status(Vector3(sd * 4.0, 0, 0), 0.4, {&"burn": 1}, sd, 0.9)
	_layer.finish()
	assert_eq(_live(&"status_burn_a").size(), 1)
	assert_eq(_live(&"status_burn_b").size(), 1)
	assert_eq(_live(&"status_burn_c").size(), 1)


func test_poison_is_a_stink_cloud_and_now_and_then_a_bubble() -> void:
	for k in 300:
		_frame(float(k), func() -> void: _layer.status(Vector3.ZERO, 0.4, {&"poison": 2}, 9, 0.9))
	assert_eq(_live(&"status_poison").size(), 1, "one held cloud")
	assert_gt(_fx.spawned, 2, "bubbles popped over five seconds")
	assert_lt(_fx.spawned, 12, "occasionally, not every frame")


func test_frost_stacks_are_ice_mist_at_the_feet_and_the_cage_stays_ours() -> void:
	var mists: Array[StringName] = [&"status_frost_a", &"status_frost_b"]
	_frame(0.0, func() -> void: _layer.status(Vector3.ZERO, 0.4, {&"frost": 2}, 4, 0.9))
	assert_eq(_live_any(mists), 1)
	assert_eq(_live_any_node(mists).get("primary_color"), ElementLooks.core(&"frost"))
	_frame(1.0, func() -> void: _layer.status(Vector3.ZERO, 0.4, {&"frozen": 1}, 4, 0.9))
	assert_eq(_live_any(mists), 1, "a frozen enemy has the mist too")
	_layer.begin(2.0)
	var asked := _layer.sprites_asked
	_layer.status(Vector3.ZERO, 0.4, {&"frozen": 1}, 4, 0.9)
	assert_gt(_layer.sprites_asked, asked, "and our crystal cage")
	_layer.finish()


func test_shock_stays_as_it_was_and_bleed_is_the_vx7_drips() -> void:
	_frame(
		0.0, func() -> void: _layer.status(Vector3.ZERO, 0.4, {&"bleed": 2, &"shock": 2}, 4, 0.9)
	)
	assert_eq(_fx.live_count(&"status"), 1, "only bleed's drips (VX7 N2); shock has none (N1)")
	assert_eq(_live(&"vx7_bleed_drips").size(), 1)


func test_a_full_status_family_draws_the_old_flames_for_the_rest() -> void:
	ViewPrefs.effects_density = "low"
	var cap := _fx.cap_for(&"status")
	_layer.begin(0.0)
	for sd in cap:
		_layer.status(Vector3(sd * 4.0, 0, 0), 0.4, {&"burn": 1}, 50 + sd, 0.9)
	assert_eq(_fx.live_count(&"status"), cap)
	var asked := _layer.sprites_asked
	_layer.status(Vector3(0, 0, 40), 0.4, {&"burn": 1}, 999, 0.9)
	_layer.finish()
	assert_eq(_fx.live_count(&"status"), cap, "none evicted")
	assert_gt(_layer.sprites_asked, asked, "the old flame sprites")


func test_the_guard_orbs_are_held_pack_orbs_and_go_with_the_charges() -> void:
	for k in 3:
		_frame(float(k), func() -> void: _layer.status(Vector3.ZERO, 0.4, {&"guard": 3}, 0, 0.9))
	assert_eq(_layer.guard_orbs_packed, 3)
	assert_eq(_live(&"guard_orb").size(), 3)
	assert_eq(_fx.spawned, 3)
	_frame(3.0, func() -> void: _layer.status(Vector3.ZERO, 0.4, {&"guard": 1}, 0, 0.9))
	assert_eq(_live(&"guard_orb").size(), 1, "one charge left, one orb")
	_frame(4.0, func() -> void: pass)
	assert_eq(_layer.guard_orbs_packed, 0)
	assert_eq(_live(&"guard_orb").size(), 0)


func test_status_visuals_hide_their_own_orbs_the_pack_draws() -> void:
	var src := FileAccess.get_file_as_string("res://src/presentation/world_view/status_visuals.gd")
	assert_true(src.contains("guard_orbs_packed"), "the boxes yield to the pack's orbs")
	assert_true(src.contains('fx.burst(&"shatter"'), "the shatter payoff")
	assert_true(src.contains('fx.burst(&"wildfire"'), "the wildfire payoff")


# --- Toxic Fumes (R24) ------------------------------------------------------------------------------------------
func _world() -> World:
	var repo := ContentRepository.load_all()
	var w := FloorScenario.build(
		4,
		PlayerTable.starting_values(),
		ContentCompiler.compile_enemies(repo),
		ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo),
		ContentCompiler.compile_items(repo)
	)
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	w.pair_table = WandCompiler.pairs(repo)
	return w


func test_toxic_fumes_clouds_are_pack_clouds_up_to_the_cap_and_flat_quads_past_it() -> void:
	var w := _world()
	var view: ElementVisuals = add_child_autofree(ElementVisuals.new())
	view.pack_fx = _fx
	var reader := WorldReader.new(w)
	var clouds := PackedInt32Array()
	for k in 6:
		clouds.append_array(PackedInt32Array([1000 + k * 6000, 2000, 180]))
	w.pair_clouds = clouds
	view.sync(reader)
	var cap := _fx.cap_for(&"cloud")
	assert_eq(cap, 4)
	assert_eq(_fx.live_count(&"cloud"), cap, "the pack's four")
	assert_eq(view.cloud_count(), 6 - cap, "the rest are the old flat quads")
	assert_eq(
		_live(&"fumes_cloud")[0].get("primary_color"),
		VfxPackViews.kind_colors(&"venom", true)[&"primary"]
	)
	view.sync(reader)
	assert_eq(_fx.spawned, cap, "held, not respawned each sync")
	w.pair_clouds = PackedInt32Array()
	view.sync(reader)
	assert_eq(_fx.live_count(&"cloud"), 0, "released with the clouds")
	assert_eq(view.cloud_count(), 0)


func test_toxic_fumes_without_the_pack_are_the_flat_quads() -> void:
	var w := _world()
	var view: ElementVisuals = add_child_autofree(ElementVisuals.new())
	w.pair_clouds = PackedInt32Array([1000, 2000, 180])
	view.sync(WorldReader.new(w))
	assert_eq(view.cloud_count(), 1)
