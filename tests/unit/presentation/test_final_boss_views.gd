extends GutTest
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F2-F4): the final boss read in 3D, from the sim (EI-07). The Colossus's
## fists are cut from its mesh as the separate pieces they are and swing on their own (right, left, then both in the
## slam); every body has the clips its moves need; a body shatters in place and bursts into shards the next one rises
## from; the boss bar is one bar in three named segments; the arena is drawn round (its wall ring, seating, pillars,
## braziers, sealed gate) from the sim's ring; the Colossus's spikes erupt as stone spikes, its boulders fly as 3D
## boulders, its swings throw dust arcs.

const LONG := 1 << 24
const DT := 1.0 / 60.0
const HELD_ENDS: Array[StringName] = [&"shielded", &"stagger", &"death"]


func _bodies() -> Dictionary:
	return {&"colossus": ColossusAvatar, &"prism": PrismAvatar, &"nemesis": NemesisAvatar}


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _arena(seed_value: int = 201) -> World:
	var w := FinalLab.arena(FinalLab.run_state(seed_value))
	w.actors.invuln[0] = LONG
	w.actors.max_hp[0] = LONG
	w.actors.hp[0] = LONG
	return w


func _avatar(cls: Variant) -> BossAvatar:
	var a: BossAvatar = cls.new()
	a.setup(Color("#1A1A22"))
	add_child_autofree(a)
	a.set_process(false)
	return a


func test_the_colossus_fists_are_their_own_pieces() -> void:
	var m := BossModels.get_model(&"final_boss_colossus")
	assert_false(m.is_empty(), "the owner's Colossus is installed")
	var rig: BossRig = m["rig"]
	for bone: StringName in [&"body", &"chest", &"halo", &"fist_l", &"fist_r"]:
		assert_gte(rig.index_of(bone), 0, "its rig has %s" % bone)
	var verts: PackedVector3Array = (m["arrays"] as Array)[Mesh.ARRAY_VERTEX]
	var counts := {}
	var side := {}
	for k in verts.size():
		var b := rig.bone_ids[k * 4]
		if rig.weights[k * 4] < 0.999:
			continue
		counts[b] = int(counts.get(b, 0)) + 1
		side[b] = float(side.get(b, 0.0)) + verts[k].z
	var l := rig.index_of(&"fist_l")
	var r := rig.index_of(&"fist_r")
	assert_gt(int(counts.get(l, 0)), 1000, "the left fist's piece moves with its bone alone")
	assert_gt(int(counts.get(r, 0)), 1000, "and the right's")
	assert_lt(float(side[l]) / counts[l], -0.5, "the left fist is on the left (-Z)")
	assert_gt(float(side[r]) / counts[r], 0.5, "the right on the right")
	assert_gt(int(counts.get(rig.index_of(&"halo"), 0)), 200, "the halo is its own piece")


func test_the_final_models_load_only_where_the_fight_is() -> void:
	for id: StringName in [&"final_boss_colossus", &"final_boss_prism", &"final_boss_nemesis"]:
		assert_true(BossModels.SPECS.has(id))
		assert_true(bool(BossModels.SPECS[id].get("final", false)), "%s waits for its fight" % id)
		assert_false(BossModels.get_model(id).is_empty(), "%s is installed" % id)


func test_every_body_has_the_clips_its_moves_need() -> void:
	var bodies := _bodies()
	for id: StringName in bodies:
		var def: Resource = load("res://data/final_boss/%s.tres" % id)
		var a := _avatar(bodies[id])
		assert_not_null(a.imported, "%s draws the owner's model" % id)
		var lib := a.animator.clips
		for clip: StringName in BossAnimator.COMMON:
			assert_true(lib.has(clip), "%s has its %s clip" % [id, clip])
		for atk: Resource in def.get("attacks"):
			var move := StringName(atk.get("move"))
			assert_true(lib.has(move), "%s: %s (%s) has its clip" % [id, atk.get("id"), move])
			assert_true(BossAnimator.MOVE_CLIPS.values().has(move), "%s is a sim move" % move)
		for c: BossClip in lib.values():
			for k in c.track_count():
				var target := c.targets[k]
				if target != BossClip.BODY and c.channels[k] != BossClip.PARAM:
					assert_true(a.poser.has_bone(target), "%s %s: bone %s" % [id, c.name, target])
			if c.loop or HELD_ENDS.has(c.name):
				continue
			for k in c.track_count():
				assert_almost_eq(c.value(k, 1.0), 0.0, 0.001, "%s %s ends at rest" % [id, c.name])


## How far a bone is turned from its rest (radians).
func _turn(a: BossAvatar, bone: StringName) -> float:
	var k := a.skeleton.find_bone(String(bone))
	var rest := a.skeleton.get_bone_rest(k).basis.get_rotation_quaternion()
	return a.skeleton.get_bone_pose_rotation(k).angle_to(rest)


func test_the_combo_swings_right_then_left_then_slams_with_both() -> void:
	var w := _arena(202)
	FinalLab.past_rise(w)
	var i := FinalLab.body(w)
	w.actors.set_pos(i, Vector2.ZERO)
	w.actors.set_pos(0, Vector2(3, 0))
	var t := BossAi.table_of(w, i)
	var k := t.attack_index(&"fist_combo_3")
	BossAi.start_attack(w, i, k)
	w.bosses.chained[BossAi.entry_of(w, i)] = 1
	var reader := WorldReader.new(w)
	var a := _avatar(ColossusAvatar)
	var at := {}
	for n in 400:
		w.actors.set_pos(0, Vector2(3, 0))
		w.step(InputFrame.new())
		i = FinalLab.body(w)
		if w.actors.state[i] != EnemyAi.State.WINDUP and w.actors.state[i] != EnemyAi.State.ACTIVE:
			break
		a.sync(reader, i)
		a.advance(DT)
		var tg := reader.telegraph(i)
		var s := int(tg.get("strike", -1))
		if tg.get("striking", false) and not at.has(s):
			at[s] = [_turn(a, &"fist_l"), _turn(a, &"fist_r")]
	assert_eq(at.size(), 4, "four strikes seen")
	assert_gt(at[0][1], at[0][0] + 0.3, "the first swing is the right fist's")
	assert_gt(at[1][0], at[1][1] + 0.3, "the second the left's")
	assert_gt(at[3][0], 0.5, "the slam: the left fist down")
	assert_gt(at[3][1], 0.5, "and the right")


func test_a_body_shatters_in_place_and_the_next_rises_from_its_shards() -> void:
	var w := _arena(203)
	var reader := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var fx := FinalBossViews.new()
	add_child_autofree(fx)
	FinalLab.past_rise(w)
	actors.sync(reader)
	fx.sync(reader)
	var id := w.actors.ids[FinalLab.body(w)]
	var avatar: FinalBodyAvatar = actors.actor_node(id).get_meta(&"enemy_avatar")
	var signatures := BossSignatureViews.new()
	add_child_autofree(signatures)
	FinalLab.end_segment(w)
	var most := 0.0
	var ring := 0.0
	var eggs := 0
	for n in 60:
		w.step(InputFrame.new())
		actors.sync(reader)
		fx.sync(reader)
		signatures.sync(reader)
		fx._process(DT)
		most = maxf(most, avatar.shatter_amount())
		ring = maxf(ring, fx.ring_amount())
		eggs = maxi(eggs, signatures.egg_count())
	assert_eq(eggs, 0, "a shattering body is never read as a Brood Mother's egg")
	assert_gt(most, 0.5, "the Colossus cracks as it shatters")
	assert_gt(ring, 0.5, "a ring of light gathers")
	assert_eq(fx.burst_count(), 0, "not yet")
	while FinalBoss.shattering(w):
		w.step(InputFrame.new())
	actors.sync(reader)
	fx.sync(reader)
	assert_null(actors.actor_node(id), "the shattered body leaves at once (no fall)")
	assert_eq(fx.burst_count(), 1, "it bursts")
	assert_eq(fx.shard_count(), FinalBossViews.SHARDS)
	var prism := actors.actor_node(w.actors.ids[FinalLab.body(w)])
	assert_true(prism.get_meta(&"enemy_avatar") is PrismAvatar, "the Prism rises")
	for n in 30:
		fx._process(DT)
	FinalLab.past_rise(w)
	fx.sync(reader)
	assert_eq(fx.shard_count(), 0, "the shards went into it as it rose")
	FinalBoss.jump(w, 2)
	actors.sync(reader)
	var nemesis := actors.actor_node(w.actors.ids[FinalLab.body(w)])
	assert_true(nemesis.get_meta(&"enemy_avatar") is NemesisAvatar, "and the Nemesis")


func test_the_boss_bar_is_one_bar_in_three_named_segments() -> void:
	var w := _arena(204)
	var reader := WorldReader.new(w)
	var bar := BossBar.new()
	add_child_autofree(bar)
	FinalLab.past_rise(w)
	bar.sync(reader)
	assert_true(bar.visible)
	assert_eq(bar.boss_name(), tr("BOSS_HOLLOW_CROWN"))
	assert_eq(bar.segment_count(), 3)
	for k in 3:
		assert_almost_eq(bar.segment_fraction(k), 1.0, 0.01)
	FinalLab.hit(w, w.actors.hp[FinalLab.body(w)] / 2)
	bar.sync(reader)
	assert_almost_eq(bar.segment_fraction(0), 0.5, 0.05, "the Colossus's segment is its HP")
	FinalLab.end_segment(w)
	bar.sync(reader)
	assert_almost_eq(bar.segment_fraction(0), 0.0, 0.01)
	assert_eq(bar.status_text(), tr("HUD_FINAL_SHATTER"))
	FinalLab.through_shatter(w)
	bar.sync(reader)
	assert_almost_eq(bar.segment_fraction(1), 1.0, 0.01, "the Prism's, full once it rose")
	var plain := BossLab.world()
	BossLab.ready_boss(plain, &"gatekeeper")
	bar.sync(WorldReader.new(plain))
	assert_eq(bar.segment_count(), 0, "a floor's boss keeps the plain bar")
	assert_almost_eq(bar.hp_fraction(), 1.0, 0.01)


func test_the_arena_is_drawn_round_from_the_sims_ring() -> void:
	var w := _arena(205)
	var reader := WorldReader.new(w)
	var def: FinalArenaDefinition = ContentRepository.load_all().get_def(
		&"final_arena", &"hollow_arena"
	)
	var stage := FinalArenaStage.new()
	add_child_autofree(stage)
	stage.build(reader, def.palette, reader.final_arena_radius(), reader.seed_value())
	assert_eq(stage.wall_nodes.size(), 32, "a block per wall segment")
	for k in stage.wall_nodes.size():
		var o := w.floor_layout.walls[k]
		assert_almost_eq(
			SimPlane.to_sim(stage.wall_nodes[k].position).distance_to(o.center), 0.0, 0.01
		)
	assert_eq(stage.pillar_count, FinalArenaStage.PILLARS)
	assert_eq(stage.brazier_count, FinalArenaStage.BRAZIERS)
	assert_gt(stage.seat_count, 20, "tiered seating")
	assert_not_null(stage.gate)
	var gate := SimPlane.to_sim(stage.gate.position)
	assert_lt(
		gate.normalized().distance_to(w.floor_layout.portal_pos.normalized()),
		0.01,
		"where the sim's gate is"
	)
	var seats := stage.find_child("Seating", false, false)
	var near := 0
	for s: Node3D in seats.get_children():
		var p := SimPlane.to_sim(s.position)
		# The seating wraps the far half and SEAT_ARC past it; the arc facing the camera stays open.
		if (
			p.normalized().dot(w.floor_layout.start_pos.normalized())
			> cos(PI - FinalArenaStage.SEAT_ARC) + 0.05
		):
			near += 1
	assert_eq(near, 0, "no seating on the camera's side of the ring")
	var art := FileAccess.get_file_as_string("res://docs/art/requests/v0.8.0_ART_LIST.md")
	for id: StringName in FinalArenaStage.art_ids():
		assert_true(art.contains("`%s`" % id), "%s is an art request (ART_LIST §7)" % id)


func test_the_colossus_spikes_erupt_as_stone_spikes() -> void:
	var w := _arena(206)
	FinalLab.past_rise(w)
	var i := FinalLab.body(w)
	w.actors.set_pos(i, Vector2.ZERO)
	w.actors.set_pos(0, Vector2(4.5, 0))
	BossAi.start_attack(w, i, BossAi.table_of(w, i).attack_index(&"spike_burst"))
	var reader := WorldReader.new(w)
	var spikes := StoneSpikeViews.new()
	add_child_autofree(spikes)
	var most := 0
	var drawn := 0
	for n in 120:
		w.actors.set_pos(0, Vector2(4.5, 0))
		w.step(InputFrame.new())
		spikes.sync(reader)
		most = maxi(most, spikes.strike_count())
		drawn = maxi(drawn, spikes.spike_count())
	assert_gt(most, 6, "a strike per spike disc")
	assert_gt(drawn, 30, "clusters of spikes stand")
	assert_lte(spikes.pooled(), StoneSpikeViews.MAX_SPIKES)


func test_the_boulders_fly_as_3d_boulders() -> void:
	var w := _arena(207)
	FinalLab.past_rise(w)
	var i := FinalLab.body(w)
	w.actors.set_pos(i, Vector2(-6, 0))
	w.actors.set_pos(0, Vector2(4, 0))
	var atk_i := BossAi.table_of(w, i).attack_index(&"boulder_throw")
	BossAi.start_attack(w, i, atk_i)
	var reader := WorldReader.new(w)
	var view := BossShieldView.new()
	add_child_autofree(view)
	var most := 0
	for n in 90:
		w.step(InputFrame.new())
		view.sync(reader)
		most = maxi(most, view.boulder_count())
	assert_gt(most, 0, "a boulder in the air")


func test_the_combo_strikes_throw_dust_arcs_and_the_slam_a_crater() -> void:
	var w := _arena(208)
	FinalLab.past_rise(w)
	var i := FinalLab.body(w)
	w.actors.set_pos(i, Vector2.ZERO)
	w.actors.set_pos(0, Vector2(3, 0))
	BossAi.start_attack(w, i, BossAi.table_of(w, i).attack_index(&"fist_combo"))
	w.bosses.chained[BossAi.entry_of(w, i)] = 1
	var reader := WorldReader.new(w)
	var strikes := BossStrikeViews.new()
	add_child_autofree(strikes)
	var seen := {}
	var looks := {}
	for n in 200:
		w.actors.set_pos(0, Vector2(3, 0))
		w.step(InputFrame.new())
		strikes.sync(reader)
		for s: Array in strikes.strikes():
			seen["%s@%d" % [s[0], s[2]]] = true
			looks[s[0]] = true
	assert_gte(seen.size(), 2, "each swing and the slam raised a strike")
	assert_true(looks.has(&"cl_fists"), "a swing's dust arc")
	assert_true(looks.has(&"cl_slam"), "the slam's crater")
