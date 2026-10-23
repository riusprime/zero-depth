extends GutTest
## v0.9.0 EL views (read only, EI-07): the owner's three elite models posed in code (EliteAvatar: the windup raises,
## the punish window slumps, the Rift Hunter's vanish hides it); the elite's framed bar with its name (EliteBar, in
## place of G2 mockups: the owner judges it in play); the ability's mark on the ground (TelegraphViews, the slam's
## circle; the punch draws nothing there); the arrival, rift, beam and dust marks and the slam's camera thud near the
## hero only (EliteViews); the elites' sounds (AudioEvents).

const K := ActorStore.Kind


func _world() -> World:
	var w := CombatLab.world()
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	return w


func test_the_owners_models_load_with_their_parts() -> void:
	var parts := {
		WorldReader.KIND_BREAKER: ["arm_r", "arm_l", "leg_l", "leg_r"],
		WorldReader.KIND_RIFT_HUNTER: ["blade_r", "blade_l", "shards"],
		WorldReader.KIND_CONDUIT: ["staff", "ring", "shards"],
	}
	for kind: int in parts:
		var a := EliteAvatar.new()
		add_child_autofree(a)
		a.setup(kind, Color.BLACK)
		assert_true(a.has_model(), "kind %d: the owner's model" % kind)
		for p: String in parts[kind]:
			assert_true(a.parts.has(p), "kind %d has its %s" % [kind, p])
		assert_gt(a.hit_pieces().size(), 0, "its body takes the hit flash")


func test_the_breaker_raises_its_fist_then_slumps_stuck() -> void:
	var a := EliteAvatar.new()
	add_child_autofree(a)
	a.setup(WorldReader.KIND_BREAKER, Color.BLACK)
	var base := {"tick": 0, "state": WorldReader.STATE_MOVE, "pick": WorldReader.ELITE_ABILITY}
	a.apply_state(base)
	a.advance(0.05)
	var arm := a.parts["arm_r"] as Node3D
	var rest := arm.rotation.z
	a.apply_state(base.merged({"state": WorldReader.STATE_WINDUP, "windup": 0.9}, true))
	for k in 10:
		a.advance(0.05)
	assert_gt(a.raise_pose(), 0.9, "raised by the windup's progress")
	assert_gt(arm.rotation.z, rest + 1.5, "the fist up overhead")
	var lit := a.glow_energy()
	a.apply_state(base.merged({"state": WorldReader.STATE_RECOVER, "vulnerable": true}, true))
	for k in 10:
		a.advance(0.05)
	assert_gt(a.slump_pose(), 0.9, "slumped into its stuck window")
	assert_lt(a.glow_energy(), lit, "the accent dims: open to hits")


func test_the_rift_hunter_is_gone_while_it_has_vanished() -> void:
	var a := EliteAvatar.new()
	add_child_autofree(a)
	a.setup(WorldReader.KIND_RIFT_HUNTER, Color.BLACK)
	a.apply_state(
		{
			"tick": 0,
			"state": WorldReader.STATE_WINDUP,
			"pick": WorldReader.ELITE_ABILITY,
			"vanished": true
		}
	)
	a.advance(0.05)
	assert_false(a.visible, "no body while it has vanished")
	a.apply_state({"tick": 1, "state": WorldReader.STATE_ACTIVE, "pick": WorldReader.ELITE_ABILITY})
	a.advance(0.05)
	assert_true(a.visible, "back on its mark")


func test_an_elite_gets_its_framed_bar_with_its_name() -> void:
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var w := _world()
	var id := Elites.spawn(w, K.BREAKER, Vector2(5, 0), Elites.Source.DEV)
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	views.sync(reader)
	var node := views.actor_node(id)
	assert_true(node.has_meta(&"elite_bar"), "its own bar")
	assert_true(node.get_meta(&"enemy_avatar") is EliteAvatar)
	var bar := node.get_meta(&"elite_bar") as EliteBar
	assert_eq(bar.name_text(), tr("ELITE_BREAKER"), "named")
	TranslationServer.set_locale(locale)
	assert_false(bar.visible, "not while it rises")
	for k in SimTick.SPAWN_IN_TICKS + 2:
		w.step(InputFrame.new())
	views.sync(reader)
	assert_true(bar.visible, "shown once it is out, before any hit")
	assert_false((node.get_meta(&"bar") as Node3D).visible, "the small bar never shows for it")
	var i := w.actors.index_of(id)
	var p := w.actors.pos(i)
	Damage.hit(
		w, i, w.actors.max_hp[i] / 2, w.actors.ids[0], w.actors.ids[0], w.take_root(), 0, p, p
	)
	views.sync(reader)
	assert_almost_eq(bar.fraction(), 0.5, 0.01, "half its HP")
	assert_almost_eq(bar.chunk_fraction(), 1.0, 0.01, "the chunk holds where the hit took it")
	bar._process(1.0)
	bar._process(1.0)
	assert_almost_eq(bar.chunk_fraction(), 0.5, 0.01, "then drains")
	assert_gt(EliteBar.WIDTH, ActorViews.BAR_W * 2.0, "wider than an enemy's bar")


func test_the_slam_circle_is_on_the_ground_and_the_punch_is_not() -> void:
	var w := _world()
	var id := Elites.spawn(w, K.BREAKER, Vector2(2.8, 0), Elites.Source.DEV)
	var i := w.actors.index_of(id)
	w.actors.cd[i] = 0
	w.actors.fire_cd[i] = 1 << 20
	var reader := WorldReader.new(w)
	var tv := TelegraphViews.new()
	add_child_autofree(tv)
	var drawn := 0
	for k in 120:
		w.actors.set_pos(0, Vector2.ZERO)
		w.step(InputFrame.new())
		tv.sync(reader)
		drawn = maxi(drawn, tv.count())
	assert_eq(drawn, 1, "the slam's circle on the ground")
	var v := _world()
	var j := Elites.spawn(v, K.BREAKER, Vector2(2.0, 0), Elites.Source.DEV)
	var vi := v.actors.index_of(j)
	v.actors.cd[vi] = 1 << 20
	v.actors.fire_cd[vi] = 0
	var vr := WorldReader.new(v)
	var tv2 := TelegraphViews.new()
	add_child_autofree(tv2)
	var punch_drawn := 0
	for k in 120:
		v.actors.set_pos(0, Vector2.ZERO)
		v.step(InputFrame.new())
		tv2.sync(vr)
		punch_drawn = maxi(punch_drawn, tv2.count())
	assert_eq(punch_drawn, 0, "the punch is a body cue only")


func test_elite_views_mark_the_arrival_the_rift_the_beam_and_thud_near_only() -> void:
	var w := _world()
	var reader := WorldReader.new(w)
	var ev := EliteViews.new()
	add_child_autofree(ev)
	var rid := Elites.spawn(w, K.RIFT_HUNTER, Vector2(5, 0), Elites.Source.DEV)
	ev.sync(reader)
	assert_gt(ev.fx_count(), 0, "the arrival's sigil and burst")
	w.actors.cd[w.actors.index_of(rid)] = 0
	var marked := 0
	for k in 120:
		w.actors.set_pos(0, Vector2.ZERO)
		w.step(InputFrame.new())
		ev.sync(reader)
		marked = maxi(marked, ev.mark_count())
	assert_eq(marked, 1, "the rift on its mark")
	var c := _world()
	var cr := WorldReader.new(c)
	var cv := EliteViews.new()
	add_child_autofree(cv)
	var cid := Elites.spawn(c, K.CONDUIT, Vector2(8, 0), Elites.Source.DEV)
	c.actors.cd[c.actors.index_of(cid)] = 0
	c.actors.fire_cd[c.actors.index_of(cid)] = 1 << 20
	cv.sync(cr)
	cv._process(1.0)  # the arrival fades
	var beams := 0
	for k in 200:
		c.actors.set_pos(0, Vector2(0, 2))
		c.step(InputFrame.new())
		cv.sync(cr)
		if cr.elite_beam(c.actors.index_of(cid)) != null:
			beams = maxi(beams, cv.fx_count())
	assert_gt(beams, 0, "the beam flashes along its line")
	for far in [false, true]:
		var b := _world()
		var br := WorldReader.new(b)
		var bv := EliteViews.new()
		add_child_autofree(bv)
		var bid := Elites.spawn(b, K.BREAKER, Vector2(2.8, 0), Elites.Source.DEV)
		b.actors.cd[b.actors.index_of(bid)] = 0
		b.actors.fire_cd[b.actors.index_of(bid)] = 1 << 20
		var thud := false
		var hero := Vector2.ZERO
		for k in 120:
			b.actors.set_pos(0, hero)
			b.step(InputFrame.new())
			if far and b.actors.state[b.actors.index_of(bid)] == EnemyAi.State.WINDUP:
				hero = Vector2(-12, 0)  # walked well away during the windup
			bv.sync(br)
			thud = thud or bv.take_thud()
		assert_eq(thud, not far, "the slam thuds the camera only near the hero (far: %s)" % far)


func test_the_elites_sounds() -> void:
	assert_eq(AudioEvents.elite_cue(K.BREAKER, WorldReader.STATE_ACTIVE, true), &"elite_slam")
	assert_eq(AudioEvents.elite_cue(K.RIFT_HUNTER, WorldReader.STATE_WINDUP, true), &"elite_rift")
	assert_eq(AudioEvents.elite_cue(K.RIFT_HUNTER, WorldReader.STATE_ACTIVE, true), &"elite_slash")
	assert_eq(AudioEvents.elite_cue(K.CONDUIT, WorldReader.STATE_WINDUP, true), &"elite_charge")
	assert_eq(AudioEvents.elite_cue(K.CONDUIT, WorldReader.STATE_ACTIVE, true), &"elite_beam")
	assert_eq(
		AudioEvents.elite_cue(K.CONDUIT, WorldReader.STATE_ACTIVE, false),
		&"arc_bolt",
		"the orb fan"
	)
	assert_eq(
		AudioEvents.elite_cue(K.BREAKER, WorldReader.STATE_ACTIVE, false),
		&"shield_bash",
		"the punch"
	)
	for id in [
		&"elite_arrive",
		&"elite_slam",
		&"elite_rift",
		&"elite_slash",
		&"elite_charge",
		&"elite_beam"
	]:
		assert_true(
			ResourceLoader.exists("res://data/audio/cues/%s.tres" % id), "%s has its cue" % id
		)
		assert_true(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % id), "and its sound")
	var w := _world()
	var reader := WorldReader.new(w)
	var ae := AudioEvents.new()
	ae.prime(reader)
	Elites.spawn(w, K.BREAKER, Vector2(5, 0), Elites.Source.DEV)
	var cues := []
	for c: Array in ae.collect(reader):
		cues.append(c[0])
	assert_has(cues, &"elite_arrive", "its arrival is heard")
