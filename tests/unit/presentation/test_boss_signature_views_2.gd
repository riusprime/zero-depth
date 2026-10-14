extends GutTest
## v0.8.0 BS2 (owner O5; BOSS_SIGNATURES.md S4-S6): the new signature mechanics read in 3D, from the sim (EI-07): the
## Hive Lens's Gaze shows its eye brightening and a thin aim line through the windup, then a real beam (core, glow,
## the strip it burns on the floor) along the sim's own beam, with a flare, a light and scorch marks where a wall
## stops it; a hostile shot's ricochet throws sparks; the Foundry's molten floor is drawn piece for piece while the
## sim has it, and its meltdown's floor glows, then melts. The new clips: the gaze, the ricochet brace, the meltdown.

const LONG := 1 << 20


func _fight(id: StringName, player_at: Vector2, room := 0.0) -> Array:
	var w := BossLab.world()
	if room > 0.0:
		var t := 0.5
		var walls: Array[Obb] = [
			Obb.make(Vector2(room + t, 0), Vector2(t, room + 2.0 * t), 0),
			Obb.make(Vector2(-room - t, 0), Vector2(t, room + 2.0 * t), 0),
			Obb.make(Vector2(0, room + t), Vector2(room + 2.0 * t, t), 0),
			Obb.make(Vector2(0, -room - t), Vector2(room + 2.0 * t, t), 0),
		]
		w.set_walls(walls)
		w.bosses.arena = Rect2(-room, -room, room * 2.0, room * 2.0)
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	w.actors.invuln[0] = LONG
	var bt := BossAi.table_of(w, i)
	for k in bt.phase_attacks.size():
		bt.phase_attacks[k] = PackedInt32Array()  # only the attacks a test starts
	bt.punish_ticks = 0
	bt.gap_ticks = 0
	return [w, w.actors.ids[i]]


func _view() -> BossSignatureViews:
	var v := BossSignatureViews.new()
	add_child_autofree(v)
	return v


func test_the_gaze_shows_its_aim_line_then_a_beam_along_the_sims() -> void:
	var s := _fight(&"hive_lens", Vector2(-6, 0), 10.0)
	var w: World = s[0]
	var aid: int = s[1]
	var reader := WorldReader.new(w)
	var view := _view()
	BossLab.start(w, w.actors.index_of(aid), &"gaze")
	w.step(InputFrame.new())
	view.sync(reader)
	assert_true((view.get_node("GazeAim") as Node3D).visible, "a thin aim line in the windup")
	assert_false((view.get_node("GazeBeam") as Node3D).visible, "no beam yet")
	assert_true((view.get_node("GazeEye") as Node3D).visible, "the eye brightening")
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	CombatLab.idle(w, atk.windup_ticks + 30)
	view.sync(reader)
	assert_true((view.get_node("GazeBeam") as Node3D).visible, "the beam")
	assert_false((view.get_node("GazeAim") as Node3D).visible)
	var g := reader.boss_gaze(w.actors.index_of(aid))
	var ends := view.gaze_ends()
	assert_eq(ends.size(), 2)
	assert_almost_eq(
		SimPlane.to_sim(ends[1]).distance_to(g["to"]), 0.0, 0.001, "it ends where the sim's does"
	)
	assert_true(g["hit"], "the room's wall stopped it")
	assert_true((view.get_node("GazeImpact") as Node3D).visible, "a flare where it strikes")
	assert_true((view.get_node("GazeImpactLight") as Node3D).visible, "and a light")
	for k in 12:
		w.step(InputFrame.new())
		view.sync(reader)
	var scorch := (view.get_node("Scorch") as MultiMeshInstance3D).multimesh
	assert_gt(scorch.visible_instance_count, 2, "scorch marks left on the floor")
	CombatLab.idle(w, atk.active_ticks + 2)
	view.sync(reader)
	assert_false(view.gaze_drawn(), "gone with the gaze")


func test_a_ricochet_throws_sparks() -> void:
	var s := _fight(&"siege_engine", Vector2(0, 8), 10.0)
	var w: World = s[0]
	var aid: int = s[1]
	var reader := WorldReader.new(w)
	var view := _view()
	w.queue_projectile(
		aid,
		ActorStore.TEAM_ENEMY,
		Vector2(5, 0),
		Vector2(0.1, 0.0),
		5,
		0.22,
		600,
		SimEvent.TAG_PROJECTILE,
		1
	)
	var most := 0
	for t in 80:
		w.step(InputFrame.new())
		view.sync(reader)
		most = maxi(most, view.spark_count())
	assert_eq(w.projectiles.size(), 1)
	assert_gte(w.projectiles.bounce_tick[0], 0, "it bounced")
	assert_eq(most, 1, "one spark burst at the bounce")
	CombatLab.idle(w, 20)
	view.sync(reader)
	assert_eq(view.spark_count(), 0, "it fades")


func test_the_molten_floor_is_drawn_while_the_sim_has_it() -> void:
	var s := _fight(&"foundry", Vector2(2, 3), 11.0)
	var w: World = s[0]
	var aid: int = s[1]
	var reader := WorldReader.new(w)
	var view := _view()
	BossLab.start(w, w.actors.index_of(aid), &"molten_flood")
	CombatLab.until(w, func(x: World) -> bool: return not x.bosses.lava_x.is_empty(), 400)
	view.sync(reader)
	var n := w.bosses.lava_x.size()
	assert_gt(n, 0)
	assert_eq(view.lava_count(), n, "a lava piece for each of the sim's")
	CombatLab.until(w, func(x: World) -> bool: return x.bosses.lava_x.is_empty(), 400)
	view.sync(reader)
	assert_eq(view.lava_count(), 0, "cooled with the sim's")


func test_the_meltdown_glows_then_melts() -> void:
	var s := _fight(&"foundry", Vector2(1, 1), 16.0)
	var w: World = s[0]
	var aid: int = s[1]
	var reader := WorldReader.new(w)
	var view := _view()
	BossLab.start(w, w.actors.index_of(aid), &"meltdown")
	CombatLab.idle(w, 20)
	view.sync(reader)
	assert_eq(view.melt_count(), 1, "the ring glows through the roar")
	CombatLab.until(w, func(x: World) -> bool: return not x.bosses.melt_boss.is_empty(), 400)
	view.sync(reader)
	assert_eq(view.melt_count(), 1, "then melts")
	var m := (view.get_node("Meltdown") as MeshInstance3D).material_override as ShaderMaterial
	assert_almost_eq(float(m.get_shader_parameter("radius")), 12.0, 0.001, "at the sim's radius")


func test_the_new_clips() -> void:
	var gaze: BossClip = HiveLensClips.library().get(&"gaze")
	assert_not_null(gaze, "the Hive Lens's gaze clip")
	assert_eq(gaze.strike, 0.2, "a short windup, a long stare")
	assert_eq(
		BossAnimator.clip_name_for(WorldReader.MOVE_GAZE, false, HiveLensClips.library()), &"gaze"
	)
	assert_eq(
		BossAnimator.clip_name_for(WorldReader.MOVE_PATTERN, true, SiegeEngineClips.library()),
		&"pattern_shielded",
		"the Turret Cross braces for its ricochet volley"
	)
	var melt: BossClip = FoundryClips.library().get(&"melt")
	assert_not_null(melt, "the Foundry's meltdown roar")
	assert_eq(
		BossAnimator.clip_name_for(WorldReader.MOVE_MELT, false, FoundryClips.library()), &"melt"
	)
	var heat := 0.0
	for k in melt.targets.size():
		if melt.targets[k] == &"heat":
			heat = melt.value(k, melt.strike, false)
	assert_gt(heat, 2.0, "its fire roars as the ring melts")
