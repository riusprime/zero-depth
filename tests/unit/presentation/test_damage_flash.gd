extends GutTest
## The damage path never swaps a shader (PLAN v0.2.0 L11, docs/roadmap/v0.2.0/evidence/DAMAGE_LAG.md). The hit
## flash used to toggle emission_enabled on the hurt actor's materials: that picks a different shader, which the
## renderer compiled on every hit and freed when the flash ended (a stall per hit, worst on the player, whose
## hood and poncho materials share their shader with nobody). These pin the fix: flashes and tints change only
## shader parameters, and materials made per shot or per kill are shared and kept, not made fresh.


func _setup() -> Array:
	var w := World.new(3, PlayerTable.starting_values())
	var enemy := w.add_dummy(Vector2(1.2, 0), 0.35, 500)
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	views.set_process(false)  # the test steps the flash countdown itself
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var feel := HitFeel.new(views, rig)
	add_child_autofree(feel)
	views.sync(reader)
	return [w, reader, views, feel, enemy]


func test_a_hit_on_you_flashes_without_changing_any_shader() -> void:
	var s := _setup()
	var w: World = s[0]
	var views: ActorViews = s[2]
	var feel: HitFeel = s[3]
	var player := views.actor_node(w.actors.ids[0])
	var before := DamageFlashKeys.of(player)
	assert_gt(before.size(), 5, "the wanderer has its body pieces")
	var mats: Array = player.get_meta(&"mats")
	assert_gt(mats.size(), 0)
	Damage.hit(w, 0, 5, 2, 2, 2, 0, Vector2(3, 0), Vector2.ZERO)
	feel.sync(s[1])
	assert_true(views.is_flashing(w.actors.ids[0]), "the hit still flashes")
	for m: StandardMaterial3D in mats:
		assert_gt(m.emission_energy_multiplier, 1.0, "flashing: the body glows white")
	assert_eq(DamageFlashKeys.of(player), before, "the flash changed no material's shader")
	for k in views.flash_frames:
		views._process(1.0 / 60.0)
	assert_false(views.is_flashing(w.actors.ids[0]))
	for m: StandardMaterial3D in mats:
		assert_eq(m.emission_energy_multiplier, 0.0, "the flash is over: no glow")
	assert_eq(DamageFlashKeys.of(player), before, "nor did its end")


func test_an_enemy_flash_and_a_burn_tint_change_no_shader() -> void:
	var s := _setup()
	var w: World = s[0]
	var views: ActorViews = s[2]
	var enemy_id: int = s[4]
	var node := views.actor_node(enemy_id)
	var before := DamageFlashKeys.of(node)
	views.flash(enemy_id)
	assert_eq(DamageFlashKeys.of(node), before)
	views.set_tint(enemy_id, Color.ORANGE, 0.7)
	for k in views.flash_frames:
		views._process(1.0 / 60.0)
	assert_eq(DamageFlashKeys.of(node), before, "tinted")
	views.set_tint(enemy_id, Color.BLACK, 0.0)
	assert_eq(DamageFlashKeys.of(node), before, "tint cleared")
	assert_eq(w.actors.size(), 2)


func test_shots_share_one_kept_material_per_look() -> void:
	var s := _setup()
	var w: World = s[0]
	var reader: WorldReader = s[1]
	var views: ActorViews = s[2]
	w.queue_projectile(2, ActorStore.TEAM_ENEMY, Vector2(0, 5), Vector2(0.1, 0), 0, 0.1, 3, 0)
	w.step(InputFrame.new())
	views.sync(reader)
	var first_id := w.projectiles.ids[0]
	var first := views.projectile_node(first_id).get_child(0) as MeshInstance3D
	var mat := first.material_override
	for k in 5:
		w.step(InputFrame.new())
	views.sync(reader)
	assert_null(views.projectile_node(first_id), "the first shot expired")
	w.queue_projectile(2, ActorStore.TEAM_ENEMY, Vector2(0, 5), Vector2(0.1, 0), 0, 0.1, 3, 0)
	w.step(InputFrame.new())
	views.sync(reader)
	var second := views.projectile_node(w.projectiles.ids[0]).get_child(0) as MeshInstance3D
	assert_same(second.material_override, mat, "the next shot reuses the kept material")


func test_kill_shards_reuse_their_material() -> void:
	var s := _setup()
	var w: World = s[0]
	var reader: WorldReader = s[1]
	var feel: HitFeel = s[3]
	w.add_dummy(Vector2(-1.2, 0), 0.35, 500)
	Damage.hit(w, 1, 9999, 2, 2, 2, 0, Vector2.ZERO, Vector2(1.2, 0))
	feel.sync(reader)
	var mats := {}
	for c in feel.get_children():
		mats[(c as MeshInstance3D).material_override] = true
	assert_eq(mats.size(), 1, "one burst, one material")
	Damage.hit(w, 2, 9999, 2, 2, 2, 0, Vector2.ZERO, Vector2(-1.2, 0))
	feel.sync(reader)
	assert_gt(feel.get_child_count(), HitFeel.SHARDS, "a second burst")
	for c in feel.get_children():
		mats[(c as MeshInstance3D).material_override] = true
	assert_eq(mats.size(), 1, "a second burst of the same colour shares it")


func test_enemy_models_are_built_flashable() -> void:
	var avatars: Array[Node3D] = [ChargerAvatar.new(), NeedleAvatar.new(), WardenAvatar.new()]
	for avatar in avatars:
		var name: String = avatar.get_script().get_global_name()
		avatar.setup(Color.BLACK, &"xray")
		assert_gt(avatar.body_materials.size(), 0)
		for m: StandardMaterial3D in avatar.body_materials:
			assert_true(m.emission_enabled, "%s: a hit flash changes energy only" % name)
		avatar.free()
