extends GutTest
## v0.8.0 FB2 (owner O17; FINAL_BOSS.md F5): the Prism read in 3D, from the sim (EI-07). Her shards are cut from her
## mesh as the separate pieces they are and orbit with the sim's shard ring, the one that fires flaring; the Cross is
## drawn where the sim's beams are (aim lines through the spin-up, beams through the spin, nothing but the window's ring
## after); a bolt's aim line shows through its 0.4 s and goes as it fires; her clips and her fireball looks.

const LONG := 1 << 24
const DT := 1.0 / 60.0


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _prism(seed_value: int = 301) -> World:
	var w := FinalLab.arena(FinalLab.run_state(seed_value))
	w.actors.invuln[0] = LONG
	w.actors.max_hp[0] = LONG
	w.actors.hp[0] = LONG
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 1)
	FinalLab.past_rise(w)
	return w


func _avatar() -> PrismAvatar:
	var a := PrismAvatar.new()
	a.setup(Color("#1A1A22"))
	add_child_autofree(a)
	a.set_process(false)
	return a


func _views() -> PrismViews:
	var v := PrismViews.new()
	add_child_autofree(v)
	v.set_process(false)
	return v


func _start(w: World, id: StringName = &"cross_ring") -> BossAttackTable:
	var i := FinalLab.body(w)
	BossAi.start_attack(w, i, BossAi.table_of(w, i).attack_index(id))
	return BossAi.attack_of(w, i)


func test_her_shards_are_their_own_pieces() -> void:
	var m := BossModels.get_model(&"final_boss_prism")
	assert_false(m.is_empty(), "the owner's Prism is installed")
	var rig: BossRig = m["rig"]
	assert_gte(rig.index_of(&"body"), 0)
	assert_gte(rig.index_of(&"core"), 0, "the orbit's axis")
	var shards := []
	for b: Array in rig.bones:
		if String(b[0]).begins_with("shard_"):
			shards.append(rig.index_of(b[0]))
	assert_gte(shards.size(), 10, "her floating crystals, each its own bone (%d)" % shards.size())
	var verts: PackedVector3Array = (m["arrays"] as Array)[Mesh.ARRAY_VERTEX]
	var counts := {}
	for k in verts.size():
		if rig.weights[k * 4] >= 0.999:
			counts[rig.bone_ids[k * 4]] = int(counts.get(rig.bone_ids[k * 4], 0)) + 1
	for s: int in shards:
		assert_gt(int(counts.get(s, 0)), 30, "%s moves with its bone alone" % rig.bones[s][0])
	assert_gt(int(counts.get(rig.index_of(&"body"), 0)), 10000, "the torn body is one piece")


func test_her_shards_orbit_with_the_sim_ring() -> void:
	var w := _prism(302)
	var i := FinalLab.body(w)
	var reader := WorldReader.new(w)
	var a := _avatar()
	assert_gte(a.shard_count(), 10)
	var bone := &"shard_00"
	a.sync(reader, i)
	a.advance(DT)
	var p0 := a.poser.bone_origin(bone)
	for k in 90:
		w.step(InputFrame.new())
		a.sync(reader, i)
		a.advance(DT)
	var ring := reader.boss_shards(i)
	var d := SimPlane.to_3d(ring[0] - reader.actor_pos(i), 0.0)
	assert_almost_eq(
		wrapf(a.orbit_angle() - atan2(-d.z, d.x), -PI, PI), 0.0, 0.01, "the sim's ring"
	)
	assert_gt(
		a.poser.bone_origin(bone).distance_to(p0), 0.3, "1.5 s on, the shard has moved round her"
	)


func test_the_shard_that_fires_flares() -> void:
	var w := _prism(303)
	var i := FinalLab.body(w)
	var atk := _start(w)
	var reader := WorldReader.new(w)
	var a := _avatar()
	var flared := 0.0
	for k in atk.windup_ticks + atk.spin_ticks:
		w.step(InputFrame.new())
		a.sync(reader, i)
		a.advance(DT)
		for s in a.shard_count():
			flared = maxf(flared, a.shard_flare(s))
	assert_gt(flared, 0.9, "a shard flares as it fires")


func test_the_cross_is_drawn_where_the_sim_beams_are() -> void:
	var w := _prism(304)
	var i := FinalLab.body(w)
	var atk := _start(w)
	var reader := WorldReader.new(w)
	var v := _views()
	for k in 20:
		w.step(InputFrame.new())
	v.sync(reader)
	assert_eq(v.aim_count(), 4, "the spin-up: four aim lines")
	assert_eq(v.beam_count(), 0)
	while w.actors.state[i] != EnemyAi.State.ACTIVE or w.actors.state_t[i] < 60:
		w.step(InputFrame.new())
	v.sync(reader)
	assert_eq(v.beam_count(), 4, "four beams turning")
	var arms: Array = reader.boss_cross(i)["arms"]
	var ends := v.arm_ends()
	for k in 4:
		var to: Vector3 = ends[k][1]
		var want := SimPlane.to_3d(arms[k][1], to.y)
		assert_almost_eq(to.distance_to(want), 0.0, 0.001, "beam %d ends where the sim's does" % k)
	assert_false(v.window_drawn())
	while w.actors.state_t[i] < atk.spin_ticks + 10:
		w.step(InputFrame.new())
	v.sync(reader)
	assert_eq(v.beam_count(), 0, "the window: the beams are out")
	assert_true(v.window_drawn(), "her ring says strike now")
	assert_false(reader.boss_shielded(i))


func test_a_bolts_aim_line_shows_then_goes() -> void:
	var w := _prism(305)
	var i := FinalLab.body(w)
	_start(w)
	var reader := WorldReader.new(w)
	var v := _views()
	var shown := 0
	var gone_after := false
	for k in 400:
		w.step(InputFrame.new())
		v.sync(reader)
		var aiming := not BossPrism.bolt_state(w, i).is_empty()
		assert_eq(v.bolt_line_drawn(), aiming, "drawn exactly while the sim aims")
		if aiming:
			shown += 1
		elif shown > 0:
			gone_after = true
	assert_gte(shown, 24, "it shows through its 0.4 s")
	assert_true(gone_after, "and goes as the bolt flies")


func test_reduced_motion_keeps_the_cross() -> void:
	ViewPrefs.reduced_motion = true
	var w := _prism(306)
	var i := FinalLab.body(w)
	_start(w)
	var reader := WorldReader.new(w)
	var v := _views()
	while w.actors.state[i] != EnemyAi.State.ACTIVE:
		w.step(InputFrame.new())
	v.sync(reader)
	assert_eq(v.beam_count(), 4, "still drawn, only stilled")


func test_her_clips() -> void:
	var lib := PrismClips.library()
	for n: StringName in PrismClips.NAMES:
		assert_true(lib.has(n), "the %s clip" % n)
	for n: StringName in BossAnimator.COMMON:
		assert_true(lib.has(n), "the common %s clip" % n)
	assert_eq(BossAnimator.clip_name_for(WorldReader.MOVE_CROSS, true, lib), &"cross")
	var c: BossClip = lib[&"cross"]
	var spin := c.track_of(&"spin", BossClip.PARAM)
	var open := c.track_of(&"open", BossClip.PARAM)
	assert_almost_eq(c.value(spin, 0.5), 1.0, 0.01, "the shards race through the spin")
	assert_almost_eq(c.value(open, 0.9), 1.0, 0.01, "she sags open in the window")


func test_her_orbs_and_bolts_have_their_looks() -> void:
	var orb := FireballViews.look_of(&"crown_orb")
	var bolt := FireballViews.look_of(&"crown_bolt")
	assert_eq(orb["mesh"], &"gem", "crystal orbs")
	assert_gt(float(orb["facets"]), 0.0)
	assert_eq(bolt["mesh"], &"spear", "the bolts are long crystal spears")
	assert_gt(float(bolt["tip"]), 2.0)
	assert_ne(orb["core"], FireballViews.look_of(&"prism_orb")["core"], "not the Hive Lens's")
