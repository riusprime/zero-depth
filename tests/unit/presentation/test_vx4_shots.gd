extends GutTest
## v0.10.0 VX4 (VFX_PACK R31-R35): the hostile shots' core and trail are held pack effects (PackFx, family enemy_shot);
## the dark edge stays under them; a full family falls back to the old MultiMesh look.

var _density := ""


func before_each() -> void:
	_density = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"
	CandidateLooks.bolt = &""  # VX4's own rows (the owner's W3-O7 pick is tested in test_w3o7_candidates)


func after_each() -> void:
	ViewPrefs.effects_density = _density
	CandidateLooks.bolt = CandidateLooks.BOLT


func _looks() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in FireballViews.LOOKS:
		if not FireballViews.PACK_SKIP.has(key):
			out.append(key)
	return out


func _rig() -> Array:
	var w := CombatLab.world()
	var fb := FireballViews.new()
	add_child_autofree(fb)
	var pack := PackFx.new()
	add_child_autofree(pack)
	fb.pack_fx = pack
	return [w, fb, pack, WorldReader.new(w)]


func _shoot(w: World, id: int, key: StringName, at: Vector2, vel: Vector2) -> void:
	w.projectiles.add(id, -1, 1, at, vel, 0.18, 600)
	w.projectiles.set_look(w.projectiles.ids.size() - 1, key)


func test_every_look_but_the_crescent_has_a_pack_row() -> void:
	var pack := PackFx.new()
	add_child_autofree(pack)
	assert_eq(_looks().size(), 16, "18 hostile looks, the crescent and the Shade wisp apart")
	for key in _looks():
		assert_true(pack.has_id(StringName("shot_%s" % key)), "%s has its shot_ row" % key)
	assert_false(pack.has_id(&"shot_nemesis_crescent"), "the crescent stays as it was (gap N4)")


func test_each_look_spawns_its_pack_effect_and_keeps_its_dark_edge() -> void:
	for key in _looks():
		var r := _rig()
		var w: World = r[0]
		var fb: FireballViews = r[1]
		var pack: PackFx = r[2]
		_shoot(w, 701, key, Vector2(3, 1), Vector2(4, 0))
		fb.sync(r[3])
		var pid := StringName("shot_%s" % key)
		assert_eq(pack.live_count(&"enemy_shot"), 1, "%s: one pack effect" % key)
		assert_eq(pack.pooled(pid), 1, "%s: it is %s" % [key, pid])
		assert_eq(fb.core_count(key), 0, "%s: no MultiMesh core under the pack's" % key)
		assert_eq(fb.trail_count(key), 0, "%s: no MultiMesh trail" % key)
		assert_eq(fb.edge_count(key), 1, "%s: the dark edge is still drawn" % key)


func test_the_effect_follows_its_shot_faces_its_way_and_is_released_when_it_ends() -> void:
	var r := _rig()
	var w: World = r[0]
	var fb: FireballViews = r[1]
	var pack: PackFx = r[2]
	_shoot(w, 702, &"spear_ember", Vector2(2, 0), Vector2(0, 5))
	fb.sync(r[3])
	var node := _the_live(pack, &"shot_spear_ember")
	assert_not_null(node)
	assert_almost_eq(node.global_position.x, SimPlane.to_3d(Vector2(2, 0)).x, 0.001, "at the shot")
	var fwd := node.global_transform.basis.x.normalized()
	var way := (SimPlane.to_3d(Vector2(0, 1)) - SimPlane.to_3d(Vector2.ZERO)).normalized()
	assert_gt(fwd.dot(way), 0.99, "its +x runs along the velocity")
	w.projectiles.pos_x[0] = 2.0
	w.projectiles.pos_y[0] = 3.0
	fb.sync(r[3])
	assert_eq(pack.live_count(&"enemy_shot"), 1, "still one: it follows, it does not respawn")
	assert_almost_eq(
		node.global_position.z, SimPlane.to_3d(Vector2(2, 3)).z, 0.001, "moved with the shot"
	)
	w.projectiles.remove_sorted(PackedInt32Array([0]))
	fb.sync(r[3])
	assert_eq(pack.live_count(&"enemy_shot"), 0, "the shot ended: given back")
	assert_false(node.visible, "and hidden")


func test_a_held_shot_outlives_the_scenes_own_animation() -> void:
	var r := _rig()
	var w: World = r[0]
	var fb: FireballViews = r[1]
	var pack: PackFx = r[2]
	var n := 0
	for key in [&"spear_ember", &"ember_stone", &"lens_orb"]:  # a projectile, a fire ball (no animation), an orb
		_shoot(w, 710 + n, key, Vector2(1, 1), Vector2(1, 0))
		n += 1
	fb.sync(r[3])
	assert_eq(pack.live_count(&"enemy_shot"), 3)
	await wait_seconds(1.4)
	assert_eq(pack.live_count(&"enemy_shot"), 3, "none of them ended by itself")
	for key in [&"spear_ember", &"ember_stone", &"lens_orb"]:
		var node := _the_live(pack, StringName("shot_%s" % key))
		assert_true(node.visible, "%s is still showing" % key)


func test_a_full_family_falls_back_to_the_old_core_and_trail() -> void:
	ViewPrefs.effects_density = "low"
	var r := _rig()
	var w: World = r[0]
	var fb: FireballViews = r[1]
	var pack: PackFx = r[2]
	var cap := pack.cap_for(&"enemy_shot")
	for k in cap:
		pack.spawn(&"shot_arc_plasma", Vector3.ZERO, 1.0, {}, 0.0)
	assert_false(pack.has_room(&"enemy_shot"))
	_shoot(w, 720, &"acid_glob", Vector2(2, 2), Vector2(2, 0))
	fb.sync(r[3])
	assert_eq(pack.live_count(&"enemy_shot"), cap, "no slot taken, none stolen")
	assert_eq(fb.core_count(&"acid_glob"), 1, "the old core draws")
	assert_eq(fb.trail_count(&"acid_glob"), 1, "and the old trail")
	assert_eq(fb.edge_count(&"acid_glob"), 1)


func test_without_a_pack_every_look_draws_the_old_way() -> void:
	var w := CombatLab.world()
	var fb := FireballViews.new()
	add_child_autofree(fb)
	_shoot(w, 730, &"crown_bolt", Vector2(1, 1), Vector2(1, 0))
	fb.sync(WorldReader.new(w))
	assert_eq(fb.core_count(&"crown_bolt"), 1)
	assert_eq(fb.trail_count(&"crown_bolt"), 1)


func test_the_crescent_draws_as_before_with_a_pack() -> void:
	var r := _rig()
	_shoot(r[0], 731, &"nemesis_crescent", Vector2(1, 1), Vector2(1, 0))
	r[1].sync(r[3])
	assert_eq((r[2] as PackFx).live_count(&"enemy_shot"), 0)
	assert_eq((r[1] as FireballViews).core_count(&"nemesis_crescent"), 1)


func test_the_shade_wisp_stays_the_multimesh_so_the_dark_hides_it() -> void:
	assert_true(FireballViews.PACK_SKIP.has(&"shade_wisp"))
	var r := _rig()
	_shoot(r[0], 732, &"shade_wisp", Vector2(1, 1), Vector2(1, 0))
	r[1].sync(r[3])
	assert_eq((r[2] as PackFx).live_count(&"enemy_shot"), 0, "no pack node")
	assert_eq((r[1] as FireballViews).core_count(&"shade_wisp"), 1, "drawn by the MultiMesh core")


func test_the_looks_own_colours_reach_a_pack_scene_that_has_colours() -> void:
	var r := _rig()
	_shoot(r[0], 732, &"nemesis_bolt", Vector2(1, 1), Vector2(1, 0))
	r[1].sync(r[3])
	var node := _the_live(r[2], &"shot_nemesis_bolt")
	var want: Color = FireballViews.look_of(&"nemesis_bolt")["core"]
	assert_eq(node.get("primary_color"), want, "primary is the look's core")
	var trail: Color = FireballViews.look_of(&"nemesis_bolt")["trail"]
	assert_eq(node.get("secondary_color"), trail, "secondary is its trail")


func _the_live(pack: PackFx, pid: StringName) -> Node3D:
	for e in pack._live:
		if e["id"] == pid:
			return e["node"]
	return null
