extends GutTest
## v0.8.0 BS1 (owner O5; BOSS_SIGNATURES.md S1-S3): the signature mechanics read in 3D, from the sim (EI-07): the
## Gatekeeper's pillars stand as clusters of its stone spikes for their life and sink when the walls go; the Warlord's
## javelins stand in the floor where they stuck (a code-made 3D javelin until the owner's model is listed) and its
## recall clip plays while they stand; the Brood Mother's eggs are 3D eggs with an HP pip and a hatch wobble, the
## Hatchling inside hidden; her Egg Storm clip lays before it flings.

const LONG := 1 << 20


func after_each() -> void:
	BossSignatureViews.model_path = BossSignatureViews.MODEL_PATH
	BossSignatureViews.clear_cache()


func _fight(id: StringName, player_at: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	w.actors.invuln[0] = LONG
	return [w, w.actors.ids[i]]


func test_the_pillars_stand_as_spikes_where_the_sim_has_them_then_sink() -> void:
	var s := _fight(&"gatekeeper", Vector2(5, 3))
	var w: World = s[0]
	var aid: int = s[1]
	var reader := WorldReader.new(w)
	var spikes := StoneSpikeViews.new()
	add_child_autofree(spikes)
	BossLab.start(w, w.actors.index_of(aid), &"shock_lanes")
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	for t in atk.windup_ticks + 60:
		w.step(InputFrame.new())
		spikes.sync(reader)
	var n := w.bosses.pillar_x.size()
	assert_gt(n, 0)
	assert_eq(spikes.pillar_count(), n, "every pillar drawn")
	var bases := spikes.spike_positions()
	for k in n:
		var o := BossSignatures.pillar_obb(w.bosses, k)
		var near := 0
		for b in bases:
			if Collide.circle_vs_obb(SimPlane.to_sim(b), 0.05, o) != Vector2.ZERO:
				near += 1
		assert_eq(near, StoneSpikeViews.PILLAR_SATELLITES + 1, "pillar %d's spikes stand on it" % k)
	CombatLab.idle(w, int(w.bosses.pillar_until[0]) - w.tick - 2)
	spikes.sync(reader)
	assert_eq(spikes.pillar_count(), n, "still standing just before the wall goes")
	CombatLab.idle(w, 3)
	spikes.sync(reader)
	assert_eq(spikes.pillar_count(), 0, "gone with the wall")
	assert_eq(spikes.spike_count(), 0)


func test_the_javelins_stand_where_they_stuck_and_go_on_the_recall() -> void:
	var s := _fight(&"warlord", Vector2(20, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var reader := WorldReader.new(w)
	var view := BossSignatureViews.new()
	add_child_autofree(view)
	BossLab.start(w, w.actors.index_of(aid), &"javelin_fan")
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	var most := 0
	for t in atk.windup_ticks + atk.active_ticks:
		w.step(InputFrame.new())
		view.sync(reader)
		most = maxi(most, view.javelin_count())
		var tips := view.javelin_tips()
		assert_eq(tips.size(), w.bosses.jav_x.size(), "one javelin a stuck one")
		for k in tips.size():
			var at := Vector2(w.bosses.jav_x[k], w.bosses.jav_y[k])
			assert_almost_eq(SimPlane.to_sim(tips[k]).distance_to(at), 0.0, 0.001, "planted there")
	assert_eq(most, atk.pattern.count * atk.pattern.waves, "every javelin stood in the floor")
	assert_eq(view.javelin_count(), 0, "all flew back")
	var mm: MultiMesh = (view.get_node("Javelins") as MultiMeshInstance3D).multimesh
	assert_eq(mm.visible_instance_count, 0)


func test_the_javelin_is_code_made_until_the_owners_model_is_listed() -> void:
	BossSignatureViews.model_path = "res://assets/models/fx/no_such_javelin.glb"
	BossSignatureViews.clear_cache()
	assert_false(BossSignatureViews.from_model(), "no model: the code javelin")
	var m := BossSignatureViews.javelin_mesh()
	assert_not_null(m)
	var box := m.get_aabb()
	assert_almost_eq(box.size.x, BossSignatureViews.JAVELIN_LENGTH, 0.1, "its length along +X")
	assert_lt(box.size.y, 0.25, "and thin")


func test_the_warlord_pulls_while_its_javelins_stand() -> void:
	assert_true(WarlordClips.library().has(BossAvatar.RECALL_CLIP), "a recall clip")
	var s := _fight(&"warlord", Vector2(20, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var reader := WorldReader.new(w)
	var avatar := WarlordAvatar.new()
	add_child_autofree(avatar)
	avatar.setup(Color.BLACK)
	BossLab.start(w, w.actors.index_of(aid), &"javelin_fan")
	var seen := -1
	var pulled := false
	for t in 400:
		w.step(InputFrame.new())
		var i := w.actors.index_of(aid)
		avatar.sync(reader, i)
		avatar.advance(1.0 / 60.0)
		var r := reader.boss_recall_permille(i)
		if r >= 0:
			seen = maxi(seen, r)
			if avatar.animator != null and avatar.animator.action_clip() != null:
				pulled = pulled or avatar.animator.action_clip().name == BossAvatar.RECALL_CLIP
	assert_eq(seen, 1000, "the recall ran to its pull")
	if avatar.animator != null:
		assert_true(pulled, "the recall clip played")


func test_an_egg_is_a_3d_egg_with_an_hp_pip_and_its_hatchling_hidden() -> void:
	var s := _fight(&"brood_mother", Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var reader := WorldReader.new(w)
	var view := BossSignatureViews.new()
	add_child_autofree(view)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	BossLab.start(w, w.actors.index_of(aid), &"egg_storm")
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	CombatLab.idle(w, atk.windup_ticks + 2)
	view.sync(reader)
	actors.sync(reader)
	var egg := -1
	for i in w.actors.size():
		if BossSignatures.is_egg(w, i):
			egg = i
	assert_gte(egg, 0)
	var id := w.actors.ids[egg]
	assert_eq(view.egg_count(), 1, "one egg landed so far")
	var node := view.egg_node(id)
	assert_almost_eq(SimPlane.to_sim(node.position).distance_to(w.actors.pos(egg)), 0.0, 0.001)
	var facing: Node3D = actors.actor_node(id).get_meta(&"facing")
	assert_false(facing.visible, "the Hatchling inside is hidden")
	assert_eq(view.egg_pip(id), 1.0, "full HP")
	Damage.hit(
		w,
		egg,
		6,
		w.actors.ids[0],
		w.actors.ids[0],
		w.take_root(),
		SimEvent.TAG_MELEE,
		w.player_pos(),
		w.actors.pos(egg)
	)
	view.sync(reader)
	assert_lt(view.egg_pip(id), 1.0, "the pip shows the hit")
	assert_gt(view.egg_pip(id), 0.0)
	CombatLab.idle(w, atk.egg_ticks)
	view.sync(reader)
	actors.sync(reader)
	assert_eq(view.egg_node(id), null, "hatched: no egg")
	var i := w.actors.index_of(id)
	if i >= 0 and not reader.actor_spawning(i):
		assert_true(facing.visible, "the Hatchling shows")


func test_the_hatch_wobble_grows_as_it_nears_and_stills_with_reduced_motion() -> void:
	var view := BossSignatureViews.new()
	add_child_autofree(view)
	var e := view._take_egg(7)
	var amp := func(permille: int, still: bool) -> float:
		var top := 0.0
		for k in 120:
			view._pose_egg(e, [Vector2.ZERO, permille, 10, 10, 7], float(k), still)
			var body: MeshInstance3D = e["body"]
			top = maxf(top, absf(body.transform.basis.get_euler().x))
		return top
	assert_gt(amp.call(950, false), amp.call(100, false) * 2.0, "harder near the hatch")
	assert_almost_eq(amp.call(950, true), 0.0, 0.0001, "reduced motion: still")


func test_the_brood_mother_lays_before_she_flings() -> void:
	var c: BossClip = BroodMotherClips.library()[&"marks"]
	var dips := false
	for k in c.targets.size():
		if c.targets[k] == &"sac" and c.channels[k] == BossClip.SHIFT:
			dips = c.value(k, 0.08, false) < -0.05
	assert_true(dips, "the sac dips to lay before the fling")
