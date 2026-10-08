extends GutTest
## The bosses' views (v0.3.0 C): each code-built model (the fallback when no model file is installed) builds with
## flashable, outlined body pieces and its parts, animates its windup and hides when burrowed; ActorViews picks each
## model (and no floating bar); TelegraphViews draws every new shape; the HUD's boss bar shows the name, HP and
## stagger only while a boss is alive.

const DT := 1.0 / 60.0
var avatars := [GatekeeperAvatar, BroodMotherAvatar, SiegeEngineAvatar]


func _avatar(cls: Variant, technique: StringName = &"xray") -> BossAvatar:
	var a: BossAvatar = cls.new()
	a.setup(Color("#1A1A22"), technique)
	add_child_autofree(a)
	a.set_process(false)
	return a


func _count_meshes(n: Node) -> int:
	return n.find_children("*", "MeshInstance3D", true, false).size()


func after_each() -> void:
	BossModels.dir = BossModels.DIR


## The code-built bodies (the fallback when no model file is installed).
func _code_bodies() -> void:
	BossModels.dir = "res://tests/no_such_models/"


func test_each_model_builds_flashable_outlined_pieces() -> void:
	_code_bodies()
	for cls in avatars:
		var a := _avatar(cls)
		var name: String = a.get_script().get_global_name()
		assert_gt(a.body_materials.size(), 15, "%s has its body pieces" % name)
		for m in a.body_materials:
			assert_true(m.emission_enabled, "%s: flashable (emission on, energy only)" % name)
			assert_eq(m.stencil_mode, BaseMaterial3D.STENCIL_MODE_OUTLINE, "%s: outlined" % name)
		var o := _avatar(cls, &"outline")
		assert_lt(_count_meshes(o), _count_meshes(a), "%s: xray adds silhouette twins" % name)


func test_the_parts_the_sheet_shows() -> void:
	_code_bodies()
	var g := _avatar(GatekeeperAvatar) as GatekeeperAvatar
	assert_eq(g.fists.size(), 2)
	assert_gte(g.crown.size(), 6, "a crown of crystals")
	assert_not_null(g.cracks, "glowing cracks on the back")
	assert_lt(g.cracks.position.x, 0.0, "the cracks are behind (+X is the front)")
	var b := _avatar(BroodMotherAvatar) as BroodMotherAvatar
	assert_eq(b.legs.size(), 8, "four legs a side")
	assert_gt(b.eggs.size(), 10, "an egg sac")
	assert_lt(b.sac.position.x, 0.0, "the sac is behind")
	var s := _avatar(SiegeEngineAvatar) as SiegeEngineAvatar
	assert_eq(s.legs.size(), 4)
	assert_eq(s.mortars.size(), 2)
	assert_gt(s.cannon.position.x, 0.5, "the cannon points forward")


func test_windup_stagger_and_burrow_drive_the_pose() -> void:
	for cls in avatars:
		var a := _avatar(cls)
		var move := WorldReader.MOVE_SLAM_RING
		for t in 40:
			a.apply_state(
				{
					"tick": t + 1,
					"pos": Vector2.ZERO,
					"state": WorldReader.STATE_WINDUP,
					"move": move,
					"windup": float(t) / 40.0
				}
			)
			a.advance(DT)
		assert_gt(a.windup_amount(), 0.5, "%s winds up" % a.get_script().get_global_name())
		for t in 40:
			a.apply_state(
				{"tick": 41 + t, "pos": Vector2.ZERO, "state": WorldReader.STATE_STAGGERED}
			)
			a.advance(DT)
		assert_gt(a.stagger_amount(), 0.8)
		for t in 40:
			a.apply_state(
				{
					"tick": 81 + t,
					"pos": Vector2.ZERO,
					"state": WorldReader.STATE_ACTIVE,
					"hidden": true
				}
			)
			a.advance(DT)
		assert_false(a.model.visible, "underground: hidden")


func test_actor_views_pick_each_boss_model() -> void:
	var w := BossLab.world()
	var ids := []
	for k in w.boss_tables.size():
		ids.append(w.spawn_boss(k, Vector2(6 * (k + 1), 0)))
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	views.sync(reader)
	var want := {
		ActorStore.Kind.GATEKEEPER: "GatekeeperAvatar",
		ActorStore.Kind.BROOD_MOTHER: "BroodMotherAvatar",
		ActorStore.Kind.SIEGE_ENGINE: "SiegeEngineAvatar",
		ActorStore.Kind.WARLORD: "WarlordAvatar",
		ActorStore.Kind.HIVE_LENS: "HiveLensAvatar",
		ActorStore.Kind.FOUNDRY: "FoundryAvatar",
	}
	for id in ids:
		var i := w.actors.index_of(id)
		var node := views.actor_node(id)
		var avatar: Node = node.get_meta(&"enemy_avatar")
		assert_eq(avatar.get_script().get_global_name(), want[w.actors.kinds[i]])
		assert_gt((node.get_meta(&"mats") as Array).size(), 0, "its flashable materials")
		CombatLab.idle(w, BossAi.INTRO_TICKS + 2)
		views.sync(reader)
		assert_false((node.get_meta(&"bar") as Node3D).visible, "no floating bar: the HUD shows it")


func test_hatchlings_use_a_small_crawler() -> void:
	var w := BossLab.world()
	var id := w.add_enemy(ActorStore.Kind.HATCHLING, Vector2(4, 0))
	var views := ActorViews.new()
	add_child_autofree(views)
	views.sync(WorldReader.new(w))
	var avatar: Node3D = views.actor_node(id).get_meta(&"enemy_avatar")
	assert_true(avatar is ChargerAvatar)
	assert_lt(avatar.scale.x, 1.0)


func test_telegraph_views_draw_every_boss_shape() -> void:
	var specs := [
		[&"gatekeeper", &"fist_slam", &"ring"],
		[&"gatekeeper", &"shock_lanes_5", &"lanes"],
		[&"gatekeeper", &"sweep", &"arc"],
		[&"gatekeeper", &"charge", &"lane"],
		[&"brood_mother", &"leap", &"disc"],
		[&"brood_mother", &"burrow", &"ripple"],
		[&"brood_mother", &"brood_4", &"discs"],
		[&"siege_engine", &"barrage_7", &"discs"],
		[&"siege_engine", &"rail_sweep", &"sweep"],
		[&"siege_engine", &"bolt_fan", &"lanes"],
		[&"siege_engine", &"deploy", &"discs"],
	]
	for spec in specs:
		var w := BossLab.world()
		var i := BossLab.ready_boss(w, spec[0])
		w.actors.set_pos(0, Vector2(7, 0))
		BossLab.start(w, i, spec[1])
		var reader := WorldReader.new(w)
		assert_eq(reader.telegraph(i)["shape"], spec[2], "%s %s" % [spec[0], spec[1]])
		var tv := TelegraphViews.new()
		add_child_autofree(tv)
		CombatLab.idle(w, 10)
		tv.sync(reader)
		assert_eq(tv.count(), 1, "%s %s is drawn" % [spec[0], spec[1]])
		var drawn := 0
		for mi: MeshInstance3D in tv.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh is ImmediateMesh:
				drawn += (mi.mesh as ImmediateMesh).get_surface_count()
			else:
				drawn += 1
		assert_gt(drawn, 0, "with geometry")


func test_the_boss_bar_shows_while_a_boss_lives() -> void:
	var w := BossLab.world()
	var reader := WorldReader.new(w)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.sync(reader)
	assert_false(hud.boss_bar.visible, "no boss, no bar")
	var id := w.spawn_boss(BossLab.table_index(w, &"siege_engine"), Vector2(6, 0))
	CombatLab.idle(w, BossAi.INTRO_TICKS + 2)
	var i := w.actors.index_of(id)
	Damage.hit(w, i, 900, 1, 1, 1, 0, Vector2(6, 5), w.actors.pos(i))
	hud.sync(reader)
	assert_true(hud.boss_bar.visible)
	assert_eq(hud.boss_bar.boss_name(), tr(&"BOSS_SIEGE_ENGINE"))
	assert_almost_eq(hud.boss_bar.hp_fraction(), 0.5, 0.01)
	assert_almost_eq(
		hud.boss_bar.stagger_fraction(), 1.0, 0.01, "900 > 300: staggered, the meter shows full"
	)
	assert_true(reader.boss_staggered(i))
	Damage.hit(w, i, 99999, 1, 1, 1, 0, Vector2(6, 5), w.actors.pos(i))
	w.step(InputFrame.new())
	hud.sync(reader)
	assert_false(hud.boss_bar.visible, "gone with the boss")


func test_the_end_panel_names_the_boss_attack() -> void:
	var p := EndPanel.new(false, WorldReader.KIND_GATEKEEPER, &"CAUSE_GATEKEEPER_SLAM")
	add_child_autofree(p)
	assert_eq((p.find_child("Cause", true, false) as Label).text, "CAUSE_GATEKEEPER_SLAM")
	var q := EndPanel.new(false, WorldReader.KIND_CHARGER)
	add_child_autofree(q)
	assert_eq((q.find_child("Cause", true, false) as Label).text, "CAUSE_CHARGER")
