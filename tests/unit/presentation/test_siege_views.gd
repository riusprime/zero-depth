extends GutTest
## The Siege Engine's fight apart as the player sees it, each view built from WorldReader only, in SiegeLab's walled
## 24 m room: SiegeFieldViews (the Target Lock's reticle of the reader's exact radius on its centre, dull while it
## tracks and locked at the end, the shell's fall and explosion; each boulder the rock of its exact square, rising,
## cracking near its end and gone with it; the cover's shadow behind each boulder and the hero's ring, teal when
## covered and red when seen, only while a blast that needs cover comes), SiegeCartViews (the cart drawn as a wagon on
## its place with its HP, its track, its blast circle, the Engine's countdown ring and the Doom Shell's cast), the
## armour stripped (BossVulnerableViews' pulse and stars on the Engine, the bar's gold shimmer, no words), the hint
## arrow on the boulders, the borrowed sounds and the reduced-motion path. Nothing stays once the fight ends.

const DT := 1.0 / 60.0


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _view(script: GDScript, fx: PackFx = null) -> Node3D:
	var v: Node3D = script.new()
	add_child_autofree(v)
	v.set_process(false)
	if fx != null:
		v.set(&"pack_fx", fx)
	return v


func _pack() -> PackFx:
	var fx := PackFx.new()
	add_child_autofree(fx)
	return fx


## Steps `n` ticks (the hero refilled), each view synced and advanced after it.
func _run(w: World, r: WorldReader, views: Array, n: int) -> void:
	for k in n:
		w.step(InputFrame.new())
		SiegeLab.take_lost(w)
		for v: Node in views:
			v.call(&"sync", r)
			if v.has_method(&"advance"):
				if v is BossVulnerableViews:
					v.call(&"advance")
				else:
					v.call(&"advance", DT)


func _until(w: World, r: WorldReader, views: Array, done: Callable, limit: int) -> bool:
	for k in limit:
		if done.call():
			return true
		_run(w, r, views, 1)
	return done.call()


func test_the_lock_is_the_readers_circle_then_the_shell_leaves_a_boulder_of_its_footprint() -> void:
	var s := SiegeLab.only(Vector2(-6, 2), Vector2(6, 0), 1, ["lock"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var view: SiegeFieldViews = _view(SiegeFieldViews, fx)
	var locking := func() -> bool: return not r.boss_siege().get("lock", {}).is_empty()
	assert_true(_until(w, r, [view], locking, 600), "a lock begins")
	_run(w, r, [view], 5)
	var lock: Dictionary = r.boss_siege()["lock"]
	var c := view.lock_circle()
	assert_eq(c.size(), 3, "the reticle is drawn")
	assert_almost_eq(c[0], lock["centre"], Vector2(0.001, 0.001), "on the circle's centre")
	assert_almost_eq(c[1], float(lock["radius"]), 0.0001, "of its exact radius")
	assert_false(c[2], "turning while it tracks")
	assert_true(view.hold.has(&"lock_rim"), "the pack's rim on it")
	var held := func() -> bool: return bool(r.boss_siege().get("lock", {}).get("locked", false))
	assert_true(_until(w, r, [view], held, 300))
	assert_true(view.lock_circle()[2], "locked for its last moments")
	var falling := func() -> bool: return view.hold.has(&"shell")
	assert_true(_until(w, r, [view], falling, 60), "the shell falls from above")
	var landed := func() -> bool: return not r.boss_siege().get("boulders", []).is_empty()
	assert_true(_until(w, r, [view], landed, 60))
	_run(w, r, [view], 1)
	assert_gt(fx.live_count(&"explosion"), 0, "the pack's explosion where it landed")
	assert_eq(view.lock_circle(), [], "the reticle goes")
	_run(w, r, [view], 30)
	assert_eq(view.boulders_shown(), 1)
	var row: Dictionary = r.boss_siege()["boulders"][0]
	var f := view.boulder_footprint(0)
	assert_almost_eq(f["centre"], row["centre"], Vector2(0.001, 0.001), "on the wall's centre")
	assert_almost_eq(
		f["half"], Vector2(row["half"], row["half"]), Vector2(0.001, 0.001), "its square"
	)
	assert_almost_eq(float(f["top"]), SiegeLooks.ROCK_H, 0.01, "risen, low enough to see the hero")
	assert_lt(SiegeLooks.ROCK_H, 1.4)


func test_boulders_crack_near_their_end_and_go_with_their_walls() -> void:
	var s := SiegeLab.only(Vector2(-6, 2), Vector2(6, 0), 1, [])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var view: SiegeFieldViews = _view(SiegeFieldViews)
	SiegeLab.boulder(w, s[1], Vector2(-2, -4))
	SiegeLab.boulder(w, s[1], Vector2(0, 6))
	_run(w, r, [view], 2)
	assert_eq(view.boulders_shown(), 2, "one rock per boulder")
	var rows: Array = r.boss_siege()["boulders"]
	for k in 2:
		var f := view.boulder_footprint(k)
		assert_almost_eq(f["centre"], rows[k]["centre"], Vector2(0.001, 0.001))
		assert_almost_eq((f["half"] as Vector2).x, float(rows[k]["half"]), 0.001)
		assert_eq(float(f["crack"]), 0.0, "whole while it has time")
	w.boss_fight.sg_b_until[0] = w.tick + 100
	_run(w, r, [view], 50)
	assert_gt(float(view.boulder_footprint(0)["crack"]), 0.0, "its cracks glow near its end")
	assert_lt(float(view.boulder_footprint(0)["top"]), SiegeLooks.ROCK_H, "and it sinks")
	BossSiege.drop(w, BossSiege.ALL)
	_run(w, r, [view], 1)
	assert_eq(view.boulders_shown(), 0, "gone with their walls")


func test_the_cover_reads_only_while_a_blast_comes_and_follows_covered() -> void:
	var s := SiegeLab.only(Vector2(9, 0), Vector2.ZERO, 2, [])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var view: SiegeFieldViews = _view(SiegeFieldViews, fx)
	SiegeLab.boulder(w, s[1], Vector2(5, 0))
	_run(w, r, [view], 2)
	assert_true(r.boss_siege()["covered"])
	assert_eq(view.hero_read(), &"", "quiet while nothing comes")
	assert_eq(view.shadows(), [], "no shadow either")
	BossLab.start(w, _i(w, s[1]), &"shockwave")
	_run(w, r, [view], 2)
	assert_eq(view.hero_read(), &"covered", "behind it: the teal ring")
	assert_true(view.hold.has(&"cover"), "with the pack's rim")
	var shadows := view.shadows()
	assert_eq(shadows.size(), 1, "a shadow behind the boulder")
	var poly := PackedVector2Array()
	for p: Array in shadows[0]:
		poly.append(p[0])
	assert_true(Geometry2D.is_point_in_polygon(r.player_pos(), poly), "the hero stands in it")
	assert_false(Geometry2D.is_point_in_polygon(Vector2(5, 4), poly), "beside it is not")
	assert_false(
		Geometry2D.is_point_in_polygon(Vector2(1, 0), poly), "nor between it and the Engine"
	)
	var room: Rect2 = r.boss_siege()["room"]
	for p: Vector2 in poly:
		assert_true(room.grow(0.01).has_point(p), "clipped to the room")
	w.actors.set_pos(0, Vector2(5, 4))
	_run(w, r, [view], 1)
	assert_false(r.boss_siege()["covered"])
	assert_eq(view.hero_read(), &"exposed", "seen: the red ring")
	var tg := r.telegraph(_i(w, s[1]))
	assert_eq(float(tg["inner"]), 0.0, "its ring shows no safe ring round the Engine")


func test_the_cart_is_a_wagon_on_its_place_with_its_hp_track_and_the_doom_cast() -> void:
	var s := SiegeLab.only(Vector2(-6, 6), Vector2(6, 0), 1, ["doom"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var view: SiegeCartViews = _view(SiegeCartViews, fx)
	var field: SiegeFieldViews = _view(SiegeFieldViews, fx)
	var rolling := func() -> bool: return int(r.boss_siege().get("cart", {}).get("id", -1)) >= 0
	assert_true(_until(w, r, [view, field], rolling, 900), "a cart sets off")
	_run(w, r, [view, field], 60)
	var cart: Dictionary = r.boss_siege()["cart"]
	assert_true(view.cart_shown())
	assert_almost_eq(view.cart_position(), cart["position"], Vector2(0.001, 0.001), "on its place")
	assert_eq(view.cart_hp_fraction(), 1.0, "its bar full")
	assert_eq(view.cart_wheels(), 4, "the code-made wagon")
	assert_true(view.track_shown(), "its track")
	assert_almost_eq(
		view.cast_share(), float(cart["progress"]) / 1000.0, 0.001, "the Engine's ring fills"
	)
	var blast := view.blast_circle()
	assert_eq(blast[1], SiegeCartViews.CART_BLAST_M, "its blast's radius")
	assert_false(blast[2], "far from the Engine: red")
	assert_eq(field.hero_read(), &"", "no cover read yet")
	var ci := SiegeLab.cart(w)
	w.actors.hp[ci] = w.actors.max_hp[ci] / 2
	_run(w, r, [view, field], 1)
	assert_almost_eq(view.cart_hp_fraction(), 0.5, 0.02, "its bar follows its HP")
	var near := func() -> bool: return int(r.boss_siege().get("cart", {}).get("left", 999)) <= 100
	assert_true(_until(w, r, [view, field], near, 700))
	assert_true(view.blast_circle()[2], "near the Engine: gold")
	assert_ne(field.hero_read(), &"", "its last 2 s: the cover reads")
	var doom := func() -> bool: return int(r.boss_siege()["doom"]) >= 0
	assert_true(_until(w, r, [view, field], doom, 200), "it arrives")
	_run(w, r, [view, field], 1)
	assert_false(view.cart_shown(), "the cart is gone")
	assert_true(view.doom_shown(), "the Doom Shell's cast on the Engine")
	var fired := func() -> bool: return int(r.boss_siege()["doom"]) < 0
	assert_true(_until(w, r, [view, field], fired, 120))
	_run(w, r, [view, field], 1)
	assert_gt(fx.live_count(&"explosion"), 0, "the Doom Shell's blast")
	assert_false(view.doom_shown())


func test_the_cart_body_is_not_drawn_as_a_warden() -> void:
	var s := SiegeLab.only(Vector2(-6, 6), Vector2(6, 0), 1, ["doom"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	actors.set_process(false)
	var rolling := func() -> bool: return int(r.boss_siege().get("cart", {}).get("id", -1)) >= 0
	assert_true(_until(w, r, [], rolling, 900))
	_run(w, r, [actors], 2)
	var node := actors.actor_node(int(r.boss_siege()["cart"]["id"]))
	assert_not_null(node, "the sim's body has its node")
	var facing := node.get_meta(&"facing") as Node3D
	assert_false(facing.visible, "but its warden model never shows")
	var boss := actors.actor_node(r.actor_id(int(r.boss_siege()["boss"])))
	assert_true((boss.get_meta(&"facing") as Node3D).visible, "the Engine's does")


func test_the_stripped_armour_glows_on_the_engine_and_shimmers_the_bar_without_words() -> void:
	var s := SiegeLab.only(Vector2(-6, 6), Vector2(6, 0), 1, ["doom"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var vuln: BossVulnerableViews = _view(BossVulnerableViews, fx)
	var bar := BossBar.new()
	add_child_autofree(bar)
	var close := func() -> bool:
		return int(r.boss_siege().get("cart", {}).get("progress", 0)) >= 950
	assert_true(_until(w, r, [], close, 1600))
	SiegeLab.break_cart(w)
	_run(w, r, [vuln], 2)
	assert_gt(int(r.boss_siege()["stripped"]), 0, "blown up against the Engine")
	assert_eq(vuln.shown(), 1, "the Engine glows vulnerable")
	assert_true(vuln.hold.has([&"pulse", r.actor_id(int(r.boss_siege()["boss"]))]))
	bar.sync(r)
	assert_eq(bar.tone(), BossBarTones.VULNERABLE, "the bar shimmers gold")
	assert_eq(bar.phase_text(), tr("HUD_BOSS_PHASE") % [2, 3], "and says nothing more")
	var gone := func() -> bool: return int(r.boss_siege()["stripped"]) == 0
	assert_true(_until(w, r, [vuln], gone, 600))
	_run(w, r, [vuln], 1)
	assert_eq(vuln.shown(), 0)
	bar.sync(r)
	assert_eq(bar.tone(), BossBarTones.NONE)


func test_the_boulders_carry_hint_arrows_without_text() -> void:
	var s := SiegeLab.only(Vector2(-6, 0), Vector2(6, 0), 2, [])
	var w: World = s[0]
	var r := WorldReader.new(w)
	SiegeLab.boulder(w, s[1], Vector2(-2, 0))
	BossLab.start(w, _i(w, s[1]), &"shockwave")
	w.step(InputFrame.new())
	var hints := ObjectiveHints.new()
	add_child_autofree(hints)
	var centre := hints.get_viewport().get_visible_rect().size * 0.5
	hints.project = func(sim: Vector2) -> Vector2: return centre + sim * 10.0
	hints.gate = func(_reason: StringName) -> bool: return true
	hints.sync(r)
	assert_eq(MechanicHints.SIEGE_BOULDER, ObjectiveMarkers.SIEGE_BOULDER)
	assert_true(hints.showing(MechanicHints.SIEGE_BOULDER, ObjectiveHints.PING), "an arrow over it")
	assert_true(ObjectiveHints.DOWN_GAPS.has(MechanicHints.SIEGE_BOULDER), "above the rock")
	assert_false(MechanicHints.SIEGE_BOULDER in MechanicHints.ALWAYS, "the first two runs only")


func test_nothing_stays_once_the_fight_ends_and_reduced_motion_builds() -> void:
	ViewPrefs.reduced_motion = true
	var s := SiegeLab.only(Vector2(-6, 6), Vector2(6, 0), 1, ["doom", "lock"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var field: SiegeFieldViews = _view(SiegeFieldViews, fx)
	var cart: SiegeCartViews = _view(SiegeCartViews, fx)
	SiegeLab.boulder(w, s[1], Vector2(-2, 6))
	var rolling := func() -> bool: return cart.cart_shown()
	assert_true(_until(w, r, [field, cart], rolling, 900))
	assert_gt(field.boulders_shown(), 0)
	var i := _i(w, s[1])
	w.actors.dead[i] = 1
	w.actors.hp[i] = 0
	_run(w, r, [field, cart], 3)
	assert_eq(r.boss_siege(), {})
	assert_eq(field.boulders_shown(), 0, "no rock")
	assert_eq(field.lock_circle(), [])
	assert_eq(field.hero_read(), &"")
	assert_false(cart.cart_shown(), "no cart")
	assert_false(cart.track_shown())
	assert_eq(cart.cast_share(), -1.0)
	assert_eq(field.hold.count() + cart.hold.count(), 0, "no pack effect held")
	assert_true(field.quiet and cart.quiet, "both views quiet")


func test_the_siege_events_borrow_existing_sounds() -> void:
	for effect: StringName in SiegeCues.CUES:
		var e := SimEvent.new()
		e.effect_id = effect
		var out := []
		assert_true(SiegeCues.add(e, out), String(effect))
		var cue: StringName = out[0][0]
		assert_true(ResourceLoader.exists("res://data/audio/cues/%s.tres" % cue), "%s exists" % cue)
	var other := SimEvent.new()
	other.effect_id = &"not_a_siege_event"
	assert_false(SiegeCues.add(other, []))
