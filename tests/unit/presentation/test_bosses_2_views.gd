extends GutTest
## The second bosses' views (PLAN v0.4.0 BO): each code-built model builds flashable, outlined pieces (emission on
## from the start, never toggled), poses from the boss state (the Warlord's shield lifts while its weak point is
## open, the Hive Lens's pods split off, the Foundry's door opens), the weak point glows by energy only; ActorViews
## picks each model and the Lens Drone's; the flood's standing lanes are drawn styled; the drawn flood lanes are the
## hit area (EI-07); each boss has its own telegraph sound and the flood its burst; the boss bar names each.

const DT := 1.0 / 60.0
const EPS := 0.04
var avatars := [WarlordAvatar, HiveLensAvatar, FoundryAvatar]


func _avatar(cls: Variant, technique: StringName = &"xray") -> BossAvatar:
	var a: BossAvatar = cls.new()
	a.setup(Color("#1A1A22"), technique)
	add_child_autofree(a)
	a.set_process(false)
	return a


func _count_meshes(n: Node) -> int:
	return n.find_children("*", "MeshInstance3D", true, false).size()


func _drive(a: BossAvatar, state: Dictionary, frames: int, tick0: int = 1) -> void:
	for t in frames:
		var s := state.duplicate()
		s["tick"] = tick0 + t
		s["pos"] = Vector2.ZERO
		a.apply_state(s)
		a.advance(DT)


func test_each_model_builds_flashable_outlined_pieces() -> void:
	for cls in avatars:
		var a := _avatar(cls)
		var name: String = a.get_script().get_global_name()
		assert_null(a.imported, "%s: code-built (no model file yet)" % name)
		assert_gt(a.body_materials.size(), 15, "%s has its body pieces" % name)
		for m in a.body_materials:
			assert_true(m.emission_enabled, "%s: flashable (emission on, energy only)" % name)
			assert_eq(m.emission_energy_multiplier, 0.0, "%s: dark until a hit" % name)
			assert_eq(m.stencil_mode, BaseMaterial3D.STENCIL_MODE_OUTLINE, "%s: outlined" % name)
		var o := _avatar(cls, &"outline")
		assert_lt(_count_meshes(o), _count_meshes(a), "%s: xray adds silhouette twins" % name)


func test_the_lens_drone_builds_flashable_and_hovers() -> void:
	var d := LensDroneAvatar.new()
	d.setup(Color.BLACK)
	add_child_autofree(d)
	d.set_process(false)
	assert_gt(d.body_materials.size(), 2)
	for m in d.body_materials:
		assert_true(m.emission_enabled)
	d.apply_state({"tick": 1, "state": WorldReader.STATE_MOVE})
	for k in 30:
		d.advance(DT)
	assert_gt(d.hover_height(), 1.0, "it hovers")
	assert_almost_eq(d.shadow.position.y, 0.012, 0.001, "its shadow stays on the ground")


func test_windup_and_stagger_drive_each_pose() -> void:
	var moves := {
		WarlordAvatar: WorldReader.MOVE_FLOOD,
		HiveLensAvatar: WorldReader.MOVE_RAIL,
		FoundryAvatar: WorldReader.MOVE_FLOOD,
	}
	for cls in avatars:
		var a := _avatar(cls)
		_drive(a, {"state": WorldReader.STATE_WINDUP, "move": moves[cls], "windup": 0.9}, 40)
		assert_gt(a.windup_amount(), 0.5, "%s winds up" % a.get_script().get_global_name())
		_drive(a, {"state": WorldReader.STATE_STAGGERED}, 40, 41)
		assert_gt(a.stagger_amount(), 0.8)


func test_the_warlord_lifts_its_shield_while_its_weak_point_is_open() -> void:
	var a := _avatar(WarlordAvatar) as WarlordAvatar
	_drive(a, {"state": WorldReader.STATE_MOVE}, 30)
	assert_lt(a.shield_lift(), 0.05, "shield down")
	var down := a.shield.global_position
	_drive(a, {"state": WorldReader.STATE_RECOVER, "weak": 1.0}, 30, 31)
	assert_gt(a.shield_lift(), 0.9, "lifted")
	assert_gt(a.shield.global_position.y, down.y + 0.5, "the shield goes up")
	assert_true(a.weak_core.visible, "baring the core")


func test_the_hive_lens_splits_off_its_pods() -> void:
	var a := _avatar(HiveLensAvatar) as HiveLensAvatar
	assert_eq(a.pods.size(), 3)
	_drive(a, {"state": WorldReader.STATE_MOVE, "phase": 0}, 30)
	assert_true(a.pods[0].visible, "docked in phase 1")
	_drive(
		a,
		{
			"state": WorldReader.STATE_WINDUP,
			"move": WorldReader.MOVE_DEPLOY,
			"windup": 0.9,
			"phase": 1
		},
		20,
		31
	)
	assert_gt(a.split_amount(), 0.2, "drifting off through the windup")
	_drive(a, {"state": WorldReader.STATE_RECOVER, "phase": 1}, 60, 51)
	assert_false(a.pods[0].visible, "gone once the drones are out")
	assert_gt(a.eye.position.y, 1.2, "it floats")


func test_the_foundry_opens_its_door_on_the_weak_point() -> void:
	var a := _avatar(FoundryAvatar) as FoundryAvatar
	_drive(a, {"state": WorldReader.STATE_MOVE}, 20)
	assert_lt(a.door_open(), 0.05)
	_drive(a, {"state": WorldReader.STATE_RECOVER, "weak": 1.0}, 30, 21)
	assert_gt(a.door_open(), 0.8, "the grate's door hangs open")
	var grate := a.grate.material_override as StandardMaterial3D
	assert_true(grate.emission_enabled, "the grate only changes energy")


func test_the_weak_point_glows_by_energy_only() -> void:
	for cls in avatars:
		var a := _avatar(cls)
		var mat := a.weak_material
		assert_true(mat.emission_enabled)
		_drive(a, {"state": WorldReader.STATE_RECOVER, "weak": 1.0}, 10)
		assert_true(a.weak_core.visible)
		assert_gt(mat.emission_energy_multiplier, 1.0)
		_drive(a, {"state": WorldReader.STATE_MOVE, "weak": 0.0}, 30, 11)
		assert_false(a.weak_core.visible)
		assert_true(mat.emission_enabled, "never toggled")


func test_actor_views_pick_the_new_models() -> void:
	var w := BossLab.world()
	var want := {
		&"warlord": "WarlordAvatar", &"hive_lens": "HiveLensAvatar", &"foundry": "FoundryAvatar"
	}
	var views := ActorViews.new()
	add_child_autofree(views)
	var reader := WorldReader.new(w)
	var x := 6
	for id: StringName in want:
		var aid := w.spawn_boss(BossLab.table_index(w, id), Vector2(x, 0))
		x += 6
		views.sync(reader)
		var node := views.actor_node(aid)
		var avatar: Node = node.get_meta(&"enemy_avatar")
		assert_eq(avatar.get_script().get_global_name(), want[id])
		assert_true(node.get_meta(&"boss", false), "%s is drawn as a boss" % id)
		assert_gt((node.get_meta(&"mats") as Array).size(), 0, "its flashable materials")
	var drone := w.add_enemy(ActorStore.Kind.LENS_DRONE, Vector2(-5, 0))
	views.sync(reader)
	assert_true(views.actor_node(drone).get_meta(&"enemy_avatar") is LensDroneAvatar)


func test_the_floods_standing_lanes_are_drawn_styled() -> void:
	for spec in [[&"warlord", &"spear_lines", &"spears"], [&"foundry", &"molten_flood", &"molten"]]:
		var w := BossLab.world()
		var i := BossLab.ready_boss(w, spec[0])
		var aid := w.actors.ids[i]
		w.actors.set_pos(0, Vector2(30, 30))
		BossLab.start(w, i, spec[1])
		var reader := WorldReader.new(w)
		var tv := TelegraphViews.new()
		add_child_autofree(tv)
		CombatLab.until(
			w,
			func(x: World) -> bool:
				return x.actors.state[x.actors.index_of(aid)] == EnemyAi.State.ACTIVE
		)
		w.step(InputFrame.new())
		var tg := reader.telegraph(w.actors.index_of(aid))
		assert_eq(tg.get("style", &""), spec[2], "%s stands styled" % spec[1])
		tv.sync(reader)
		assert_eq(tv.count(), 1)
		var deco := tv.find_child("Deco", true, false) as MeshInstance3D
		assert_not_null(deco, "with its marks")
		assert_gt((deco.mesh as ImmediateMesh).get_surface_count(), 0)


## Flood `attack_id` of `id` at the origin, aimed at `aim_at` (held through the windup); the player then stands at
## `stand`. Returns [hit, the drawn lanes].
func _flood(id: StringName, attack_id: StringName, aim_at: Vector2, stand: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id)
	var aid := w.actors.ids[i]
	var reader := WorldReader.new(w)
	var t_b := BossAi.table_of(w, i)
	w.actors.set_pos(0, aim_at)
	BossLab.start(w, i, attack_id)
	var tg := reader.telegraph(i)
	for t in 400:
		var j := w.actors.index_of(aid)
		if j < 0 or w.actors.state[j] == EnemyAi.State.RECOVER:
			break
		var atk := BossAi.attack_of(w, j)
		var aiming := atk != null and BossAi.tracking(w, j, t_b, atk)
		w.actors.set_pos(0, aim_at if aiming else stand)
		w.step(InputFrame.new())
	return [CombatLab.player_damage(w).size() > 0, tg["obbs"]]


func test_the_drawn_flood_lanes_are_the_hit_area() -> void:
	var pr := PlayerTable.starting_values().radius_m
	for spec in [[&"warlord", &"spear_lines"], [&"foundry", &"molten_flood"]]:
		var aim := Vector2(7, 0)
		var obbs: Array = _flood(spec[0], spec[1], aim, aim)[1]
		var mid := obbs[obbs.size() / 2] as Obb
		var outer := obbs[obbs.size() - 1] as Obb
		var hy := outer.half.y
		var off := outer.center.dot(outer.axis_v)
		for d in [off + hy + pr - EPS, off + hy + pr + EPS, mid.center.dot(mid.axis_v)]:
			var stand: Vector2 = (
				Vector2(5, 0) + outer.axis_v * (float(d) - Vector2(5, 0).dot(outer.axis_v))
			)
			var got: Array = _flood(spec[0], spec[1], aim, stand)
			var drawn := false
			for o: Obb in obbs:
				drawn = drawn or Collide.circle_vs_obb(stand, pr, o) != Vector2.ZERO
			assert_eq(got[0], drawn, "%s at %.2f: hit iff inside a drawn lane" % [spec[1], d])


func test_each_boss_has_its_own_telegraph_sound_and_the_flood_bursts() -> void:
	for kind in [WorldReader.KIND_WARLORD, WorldReader.KIND_HIVE_LENS, WorldReader.KIND_FOUNDRY]:
		var cue: StringName = AudioEvents.BOSS_FLAVOUR[kind]
		assert_true(
			ResourceLoader.exists("res://data/audio/cues/%s.tres" % cue), "%s has a cue" % cue
		)
		assert_true(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % cue))
	assert_eq(AudioEvents.attack_cue(WorldReader.MOVE_FLOOD), &"boss_floor_burst")
	assert_eq(AudioEvents.DEATHS[WorldReader.KIND_LENS_DRONE], &"enemy_death_lens_drone")
	assert_eq(EndPanel.CAUSES[WorldReader.KIND_LENS_DRONE], "CAUSE_LENS_DRONE")


func test_the_boss_bar_names_each() -> void:
	for id: StringName in [&"warlord", &"hive_lens", &"foundry"]:
		var w := BossLab.world()
		var reader := WorldReader.new(w)
		var hud := Hud.new()
		add_child_autofree(hud)
		w.spawn_boss(BossLab.table_index(w, id), Vector2(6, 0))
		CombatLab.idle(w, BossAi.INTRO_TICKS + 2)
		hud.sync(reader)
		assert_true(hud.boss_bar.visible)
		var key := w.boss_tables[BossLab.table_index(w, id)].name_key
		assert_eq(hud.boss_bar.boss_name(), tr(key))
		assert_ne(tr(key), String(key), "%s is translated" % key)
