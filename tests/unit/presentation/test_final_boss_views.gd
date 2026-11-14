extends GutTest
## The final boss read in 3D, from the sim (EI-07). The Colossus plays its file's animations: one per strike of its
## combo (the right hook, the left, then the slam), its break through the shatter (held folded until it is removed)
## and its rise over the intro, on the floor; its crystals turn about their own lengths; every body has the clips its
## moves need; a body shatters in place and bursts into shards the next one rises from; the boss bar is one bar in
## three named segments; the arena is drawn round (its wall ring, seating, pillars, braziers, sealed gate) from the
## sim's ring; the Colossus's spikes erupt as stone spikes, its boulders fly as 3D boulders, its swings throw dust
## arcs.

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
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	return a


func test_the_colossus_plays_its_files_animations() -> void:
	var m := BossModels.get_model(&"final_boss_colossus")
	assert_false(m.is_empty(), "the owner's Colossus is installed")
	assert_true(bool(m.get("skinned", false)), "kept as delivered: its own skeleton and skin")
	var a := _avatar(ColossusAvatar) as ColossusAvatar
	assert_eq(a.skeleton.get_bone_count(), 57, "its full skeleton")
	for clip: StringName in [
		&"idle",
		&"walk",
		&"flinch",
		&"stagger",
		&"roar",
		&"rise",
		&"combo",
		&"combo_l",
		&"combo_slam",
		&"leap",
		&"marks",
		&"spike_chase",
		&"spike_burst",
		FinalBodyAvatar.SHATTER_CLIP,
	]:
		assert_true(a.animator.owner_has(clip), "%s plays an animation of its file" % clip)
	for clip: StringName in [&"death", &"shielded"]:
		assert_false(a.animator.owner_has(clip), "%s stays a code clip" % clip)
	# Every bone the code names is in the file (a turn on a missing bone does nothing, silently).
	var named: Array[StringName] = [&"halo", &"chest", ColossusClips.FIST_L, ColossusClips.FIST_R]
	for row: Array in ColossusAvatar.SPIKES:
		named.append(row[0])
	named.append(a._weak_bone())
	for bone in named:
		assert_true(a.poser.has_bone(bone), "the skeleton has %s" % bone)
	# The anchors ride their bones: a fist's anchor is at its palm, the left on the left (-Z).
	_settle(a, {"state": WorldReader.STATE_MOVE})
	assert_lt(a.anchor(&"fist_l").z, -1.0, "the left fist's anchor on the left")
	assert_gt(a.anchor(&"fist_r").z, 1.0, "the right's on the right")
	assert_gt(a.anchor(&"halo").y, 3.5, "the halo's over the hood")
	# A combo clip's time is its animation's time over its length, so the strike pose is the animation's.
	for clip: StringName in [&"combo", &"combo_l", &"combo_slam"]:
		var c: BossClip = a.animator.clips[clip]
		var spec: Dictionary = ColossusAvatar.OWNER_PLAYS[clip]
		var anim: Animation = a.animator._owner[clip][0]
		for t: float in [0.2, c.strike, 0.5, c.hold, 0.9]:
			assert_almost_eq(
				BossAnimator.owner_time(anim, c, t, spec["strike"], spec["recover"]),
				t * anim.length,
				0.001,
				"%s runs evenly at %.2f" % [clip, t]
			)
	# It floats: one loop of its glide takes 3 s at its walk speed, and its idle is the file's 4 s.
	assert_almost_eq(a._stride() / a._walk_speed(), 3.0, 0.001)
	assert_almost_eq(a._idle_seconds(), 4.0, 0.001)


## Holds a plain state for `frames` frames (the layers fade in), from tick `from`.
func _settle(a: BossAvatar, s: Dictionary, frames: int = 30, from: int = 1) -> void:
	for t in frames:
		var d := s.duplicate()
		d["tick"] = from + t
		d["pos"] = Vector2.ZERO
		a.apply_state(d)
		a.advance(DT)


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
			if move == &"interphase":
				continue  # v0.9.5 BH6: a carrier of the Fallen's interphase hits, never picked: no clip
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


## Runs a combo in the sim and returns, per strike, what the avatar showed on the tick it landed:
## [the attack layer's clip, its time over its strike's, the left fist's anchor, the right's]; and under &"after",
## ten ticks on: [the clip, the sim state, the clip's time].
func _combo_strikes(attack: StringName, seed_value: int) -> Dictionary:
	var w := _arena(seed_value)
	FinalLab.past_rise(w)
	var i := FinalLab.body(w)
	w.actors.set_pos(i, Vector2.ZERO)
	w.actors.set_pos(0, Vector2(3, 0))
	var t := BossAi.table_of(w, i)
	BossAi.start_attack(w, i, t.attack_index(attack))
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
			var c := a.animator.action_clip()
			at[s] = [
				c.name,
				a.animator.action_time() / c.strike,
				a.anchor(&"fist_l"),
				a.anchor(&"fist_r")
			]
	for n in 10:
		a.sync(reader, i)
		a.advance(DT)
		w.step(InputFrame.new())
		i = FinalLab.body(w)
	at[&"after"] = [a.animator.action_clip().name, w.actors.state[i], a.animator.action_time()]
	return at


func test_the_combo_swings_right_then_left_then_slams_with_both() -> void:
	var cases := {
		&"fist_combo": [&"combo", &"combo_l", &"combo_slam"],
		&"fist_combo_3": [&"combo", &"combo_l", &"combo", &"combo_slam"],
	}
	var seed_value := 202
	for attack: StringName in cases:
		var want: Array = cases[attack]
		var at := _combo_strikes(attack, seed_value)
		seed_value += 10
		assert_eq(at.size() - 1, want.size(), "%s: every strike seen" % attack)
		for k in want.size():
			if not at.has(k):
				continue
			assert_eq(at[k][0], want[k], "%s strike %d plays %s" % [attack, k, want[k]])
			assert_almost_eq(float(at[k][1]), 1.0, 0.001, "its strike pose on the tick it lands")
			var l: Vector3 = at[k][2]
			var r: Vector3 = at[k][3]
			match want[k]:
				&"combo":
					assert_gt(
						r.x, l.x + 1.5, "%s strike %d: the right fist is across" % [attack, k]
					)
				&"combo_l":
					assert_gt(l.x, r.x + 1.5, "%s strike %d: the left fist is across" % [attack, k])
				&"combo_slam":
					assert_lt(maxf(l.y, r.y), 1.0, "%s: both fists down in the slam" % attack)
					assert_gt(minf(l.x, r.x), 1.5, "and before it")
		var after: Array = at[&"after"]
		assert_eq(after[1], EnemyAi.State.RECOVER, "%s: recovering after the slam" % attack)
		assert_eq(after[0], &"combo_slam", "the slam's clip plays on through the recovery")
		var slam: BossClip = ColossusClips.library()[&"combo_slam"]
		assert_gt(float(after[2]), slam.strike, "past its strike pose")


func test_the_colossus_breaks_through_its_shatter_and_holds_the_fold() -> void:
	ViewPrefs.reduced_motion = true  # No tremble: the poses compare exactly
	var a := _avatar(ColossusAvatar) as ColossusAvatar
	_settle(a, {"state": WorldReader.STATE_MOVE})
	var stood := a.anchor(&"halo").y
	var fist_stood := a.anchor(&"fist_r").y
	assert_true(a.plays_break(), "its file acts the break out")
	_settle(a, {"state": WorldReader.STATE_SHATTER, "shatter": 0.5}, 5, 40)
	var an := a.animator
	assert_eq(an.slot_clip[BossAnimator.DEATH].name, FinalBodyAvatar.SHATTER_CLIP)
	assert_almost_eq(an.slot_t[BossAnimator.DEATH], 0.5, 0.001, "the break follows the shatter")
	assert_almost_eq(a.pivot.position.y, 0.0, 0.001, "the animation sinks it: no sink added")
	_settle(a, {"state": WorldReader.STATE_SHATTER, "shatter": 1.0}, 5, 50)
	var chest := a.skeleton.find_bone("chest")
	var held := a.skeleton.get_bone_global_pose(chest)
	var l := a.anchor(&"fist_l")
	var r := a.anchor(&"fist_r")
	assert_lt(a.anchor(&"halo").y, stood - 1.0, "it ends folded low")
	assert_lt(maxf(l.y, r.y), fist_stood - 1.0, "its fists on the floor")
	assert_almost_eq(l.z, -1.3 * BossModels.SIZE_SCALE, 0.12, "1.3 m to its left")
	assert_almost_eq(r.z, 1.3 * BossModels.SIZE_SCALE, 0.12, "and to its right")
	assert_almost_eq(r.x, 0.5 * BossModels.SIZE_SCALE, 0.12, "half a metre forward")
	assert_gt(a.glow_amount(), 0.3, "glowing from inside")
	# Held: more frames at the shatter's end leave the fold where it is.
	_settle(a, {"state": WorldReader.STATE_SHATTER, "shatter": 1.0}, 20, 60)
	var later := a.skeleton.get_bone_global_pose(chest)
	assert_almost_eq(later.origin.distance_to(held.origin), 0.0, 0.0005, "the fold holds")
	assert_almost_eq(later.basis.y.dot(held.basis.y), 1.0, 0.0005)
	assert_almost_eq(a.anchor(&"fist_r").distance_to(r), 0.0, 0.005, "the fists stay down")
	assert_false(a.die(), "a shattered body leaves at once")
	# With motion on, a light tremble is left under the animation.
	ViewPrefs.reduced_motion = false
	_settle(a, {"state": WorldReader.STATE_SHATTER, "shatter": 1.0}, 3, 90)
	var shake := Vector2(a.pivot.position.x, a.pivot.position.z).length()
	assert_lt(shake, FinalBodyAvatar.SHATTER_SHAKE * 0.75, "a reduced tremble")
	assert_almost_eq(a.pivot.position.y, 0.0, 0.001)


func test_a_body_without_a_break_shatters_as_before() -> void:
	ViewPrefs.reduced_motion = true
	var a := _avatar(NemesisAvatar) as FinalBodyAvatar
	assert_false(a.plays_break(), "the Nemesis's file has no break")
	_settle(a, {"state": WorldReader.STATE_MOVE})
	var y := a.pivot.position.y
	_settle(a, {"state": WorldReader.STATE_SHATTER, "shatter": 1.0}, 3, 40)
	assert_almost_eq(a.pivot.position.y, y - FinalBodyAvatar.SHATTER_SINK, 0.03, "it sinks")
	assert_eq(a.animator.slot_w[BossAnimator.DEATH], 0.0, "no clip plays over its shatter")


func test_the_colossus_gathers_itself_off_the_floor_over_its_intro() -> void:
	var a := _avatar(ColossusAvatar) as ColossusAvatar
	var seen := {}
	for intro: float in [0.0, 0.5, 1.0]:
		_settle(a, {"state": WorldReader.STATE_SPAWN, "intro": intro}, 4, int(intro * 60) + 1)
		assert_almost_eq(a.model.position.y, 0.0, 0.001, "on the floor, never under it")
		assert_almost_eq(
			a.animator.slot_t[BossAnimator.RISE], intro, 0.001, "the rise is the intro"
		)
		seen[intro] = [a.anchor(&"halo").y, a.anchor(&"fist_r").y]
	assert_lt(seen[0.0][0], 2.4, "it starts low and hunched")
	assert_lt(seen[0.0][1], 0.8, "its fists on the floor")
	assert_gt(seen[0.5][0], 3.5, "the torso is up by the middle")
	_settle(a, {"state": WorldReader.STATE_MOVE}, 1, 70)
	var stands := a.anchor(&"halo").y
	assert_almost_eq(float(seen[1.0][0]), stands, 0.08, "it stands as the intro ends")
	assert_eq(a.animator.slot_w[BossAnimator.RISE], 0.0, "and the rise is over")


## A bone's pose now in the skeleton's space.
func _global(a: BossAvatar, bone: StringName) -> Transform3D:
	return a.skeleton.get_bone_global_pose(a.skeleton.find_bone(String(bone)))


func test_each_crystal_turns_about_its_own_length_with_its_point_still() -> void:
	var a := _avatar(ColossusAvatar) as ColossusAvatar
	_settle(a, {"state": WorldReader.STATE_MOVE})
	# The same frame posed at two shares of a turn: only the crystals' own turn differs.
	a._spin = 0.0
	a._pose_any(0.0)
	var before := {}
	for row: Array in ColossusAvatar.SPIKES:
		before[row[0]] = _global(a, row[0])
	a._spin = 0.25
	a._pose_any(0.0)
	for row: Array in ColossusAvatar.SPIKES:
		var was: Transform3D = before[row[0]]
		var now := _global(a, row[0])
		assert_almost_eq(now.origin.distance_to(was.origin), 0.0, 0.0001, "%s stays put" % row[0])
		var axis := was.basis.y.normalized()
		assert_almost_eq(now.basis.y.normalized().dot(axis), 1.0, 0.0001, "%s: its length" % row[0])
		var x0 := was.basis.x.normalized()
		var x1 := now.basis.x.normalized()
		assert_almost_eq(x1.dot(x0), 0.0, 0.001, "%s: a quarter turn" % row[0])
		assert_almost_eq(
			x0.cross(x1).dot(axis), float(row[1]), 0.001, "%s: its own way round" % row[0]
		)
	# One turn in ten seconds of frame time, whatever plays; still with reduced motion.
	a._spin = 0.0
	for n in 150:
		a.advance(DT)
	assert_almost_eq(a._spin, 0.25, 0.002, "a quarter turn in 2.5 s")
	_settle(a, {"state": WorldReader.STATE_SHATTER, "shatter": 0.5}, 60, 200)
	assert_almost_eq(a._spin, 0.35, 0.002, "a clip never resets it")
	ViewPrefs.reduced_motion = true
	for n in 60:
		a.advance(DT)
	assert_almost_eq(a._spin, 0.35, 0.002, "still with reduced motion")
	# The point of each crystal lies on its bone's Y, so the turn leaves it in place.
	var arrays := a.imported.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / verts.size()
	var skin := a.imported.skin
	var of_bind := {}
	for j in skin.get_bind_count():
		var bone := skin.get_bind_bone(j)
		var bone_name := (
			StringName(a.skeleton.get_bone_name(bone)) if bone >= 0 else skin.get_bind_name(j)
		)
		for row: Array in ColossusAvatar.SPIKES:
			if row[0] == bone_name:
				of_bind[j] = bone_name
	assert_eq(of_bind.size(), ColossusAvatar.SPIKES.size(), "every crystal has its own bone's skin")
	var tips := {}
	for v in verts.size():
		for j in per:
			var b := bones[v * per + j]
			if weights[v * per + j] > 0.9 and of_bind.has(b):
				var p := skin.get_bind_pose(b) * verts[v]
				if not tips.has(of_bind[b]) or absf(p.y) > absf((tips[of_bind[b]] as Vector3).y):
					tips[of_bind[b]] = p
	for row: Array in ColossusAvatar.SPIKES:
		var tip: Vector3 = tips.get(row[0], Vector3.ZERO)
		assert_gt(absf(tip.y), 0.03, "%s has a point" % row[0])
		assert_lt(
			Vector2(tip.x, tip.z).length(), absf(tip.y) * 0.05, "%s: its point on the axis" % row[0]
		)


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


## v0.8.0 N4 (owner O56: "The bosses should have one full bar and refill when changing phases, specially the last
## boss"): one bar per body under the fight's name, the line naming the body; full as each body starts.
func test_the_boss_bar_is_one_bar_per_body() -> void:
	var w := _arena(204)
	var reader := WorldReader.new(w)
	var bar := BossBar.new()
	add_child_autofree(bar)
	FinalLab.past_rise(w)
	bar.sync(reader)
	assert_true(bar.visible)
	assert_eq(bar.boss_name(), tr("BOSS_HOLLOW_CROWN"))
	assert_eq(bar.phase_text(), tr(reader.final_segment_name_key(0)))
	assert_almost_eq(bar.hp_fraction(), 1.0, 0.01, "the Colossus's bar is full")
	# owner O59: "not show 1/3 just the colossus so later phases come as surprise"
	assert_false(bar.phase_text().contains("3"), "no count of the bodies")
	assert_false(bar.phase_text().contains("/"))
	for l: Label in bar.find_children("*", "Label", true, false):
		assert_false(l.text.contains("/ 3") or l.text.contains("1/3"), "no line counts the bodies")
	var b := FinalLab.body(w)
	var phase_hp := w.actors.max_hp[b] - w.actors.max_hp[b] * 500 / 1000  # its first phase: full .. 50 %
	FinalLab.hit(w, phase_hp / 2)
	bar.sync(reader)
	assert_almost_eq(bar.hp_fraction(), 0.5, 0.05, "the bar is its first phase's HP")
	FinalLab.end_segment(w)
	bar.sync(reader)
	assert_almost_eq(bar.hp_fraction(), 0.0, 0.01)
	assert_eq(bar.status_text(), tr("HUD_FINAL_SHATTER"))
	assert_true(bar.invulnerable(), "a shatter can't be hurt: the bar says so")
	assert_string_contains(bar.shield_text(), tr("HUD_BOSS_INVULNERABLE"))
	FinalLab.through_shatter(w)
	bar.sync(reader)
	assert_almost_eq(bar.hp_fraction(), 1.0, 0.01, "the Prism's own bar, full once it rose")
	assert_eq(bar.phase_text(), tr(reader.final_segment_name_key(1)))
	var plain := BossLab.world()
	BossLab.ready_boss(plain, &"gatekeeper")
	bar.sync(WorldReader.new(plain))
	assert_eq(bar.phase_text(), tr("HUD_BOSS_PHASE") % [1, 3], "a floor's boss: its phase")
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
	# v0.9.0 MI2: the owner's pieces are drawn (his wall segment on every ring block, in the walls' own faded and
	# solid materials so the occlusion still fades it; his far pillars, braziers and gate).
	for id in [&"arena_wall_segment", &"arena_pillar", &"arena_brazier", &"arena_gate"]:
		assert_has(stage.models_used, id)
	for k in stage.wall_nodes.size():
		var n := stage.wall_nodes[k]
		assert_false(n.mesh is BoxMesh, "Wall%d is his segment" % k)
		assert_eq(n.material_override, stage.wall_material)
		var out := Vector3(n.position.x, 0.0, n.position.z).normalized()
		var box := n.mesh.get_aabb()
		assert_almost_eq(
			box.size.y, FinalArenaStage.PIECES[&"arena_wall_segment"].y, 0.05, "his height"
		)
		# His arena face (the model's -X) toward the centre: the node's +X points out.
		assert_gt(n.basis.x.dot(out), 0.9, "Wall%d faces the arena" % k)
	assert_not_null(stage.wall_material.albedo_texture, "his texture")
	assert_eq(stage.wall_faded.albedo_texture, stage.wall_material.albedo_texture, "faded the same")
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
