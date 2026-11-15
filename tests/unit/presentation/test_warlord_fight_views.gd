extends GutTest
## The Warlord's new fight as the player sees it, each view built from WorldReader only, in WarlordLab's walled 24 m
## room: its faster charge's end circle and burst (ChargeBurstViews, shared with the Twins), the War Banner
## (WarBannerViews: raised through its cast, its ring on the reader's exact circle, the Warlord's embers and the hero's
## warm hand by who stands inside, the warmer hits, its fall to its time and to a charge), the Duel (DuelCageViews: the
## javelins raining in through the cast, then planted on the fence's exact circle and closing with it, the fence's
## spark, the recall's circle filling with its warning and the shafts flying through the centre), the shield lowered on
## WarlordAvatar only while the cage stands and the front's hits then plain hits, the borrowed sounds, the
## reduced-motion path, and nothing left once the fight ends. No words anywhere.

const DT := 1.0 / 60.0


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _view(script: GDScript, fx: PackFx = null) -> Node:
	var v: Node = script.new()
	add_child_autofree(v)
	v.set_process(false)
	if fx != null:
		v.set(&"pack_fx", fx)
	return v


func _pack() -> PackFx:
	var fx := PackFx.new()
	add_child_autofree(fx)
	return fx


func _avatar() -> WarlordAvatar:
	var a := WarlordAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	return a


## Steps `n` ticks (the hero refilled), each view synced and advanced after it.
func _run(w: World, r: WorldReader, views: Array, n: int) -> void:
	for k in n:
		w.step(InputFrame.new())
		WarlordLab.take_lost(w)
		_draw(r, views)


func _draw(r: WorldReader, views: Array) -> void:
	for v: Node in views:
		if v is BossAvatar:
			if r.boss_index() >= 0:
				v.call(&"sync", r, r.boss_index())
			v.call(&"advance", DT)
			continue
		v.call(&"sync", r)
		v.call(&"advance", DT)


func _until(w: World, r: WorldReader, views: Array, done: Callable, limit: int) -> bool:
	for k in limit:
		if done.call():
			return true
		_run(w, r, views, 1)
	return done.call()


## The hero's hit of `amount` on boss i from `from`; returns every event it made.
func _hero_hit(w: World, i: int, amount: int, from: Vector2) -> Array[SimEvent]:
	var seq := w.last_event_seq()
	var hero := w.actors.ids[0]
	w.actors.invuln[i] = 0
	Damage.hit(
		w, i, amount, hero, hero, w.take_root(), SimEvent.TAG_PROJECTILE, from, w.actors.pos(i)
	)
	return w.events_since(seq)


func test_the_warlords_charge_draws_its_end_circle_then_bursts_there() -> void:
	var s := WarlordLab.fight(Vector2(-10, 0))
	var w: World = s[0]
	var i := _i(w, s[1])
	WarlordLab.hush(w, s[1])
	var r := WorldReader.new(w)
	var fx := _pack()
	var bursts: ChargeBurstViews = _view(ChargeBurstViews, fx)
	BossLab.start(w, i, &"lunge_dash")
	_run(w, r, [bursts], 3)
	var b: Dictionary = r.telegraph(i).get("burst", {})
	assert_false(b.is_empty(), "the charge's telegraph carries the end circle")
	var c := bursts.circles()
	assert_eq(c.size(), 1, "drawn for the Warlord")
	if c.size() != 1:
		return
	assert_almost_eq(c[0][0], b["center"], Vector2(0.001, 0.001), "where the lane ends")
	assert_almost_eq(float(c[0][1]), 3.5, 0.0001, "of the burst's 3.5 m")
	assert_false(c[0][2], "dull while the aim tracks")
	var locked := func() -> bool: return bursts.circles().size() > 0 and bursts.circles()[0][2]
	assert_true(_until(w, r, [bursts], locked, 40), "it locks within the 0.6 s wind-up")
	var armed := func() -> bool: return not r.boss_charge_bursts().is_empty()
	assert_true(_until(w, r, [bursts], armed, 120), "the run stops and the burst arms")
	var gone := func() -> bool: return r.boss_charge_bursts().is_empty()
	assert_true(_until(w, r, [bursts], gone, 60))
	_run(w, r, [bursts], 1)
	assert_gt(fx.live_count(&"explosion"), 0, "the pack's explosion where it ended")


func test_the_banner_rises_through_its_cast_and_stands_on_the_readers_circle() -> void:
	var s := WarlordLab.ready(Vector2(3, 0), WarlordLab.BANNER)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var view: WarBannerViews = _view(WarBannerViews, fx)
	var casting := func() -> bool:
		return int(r.boss_warlord().get("banner", {}).get("cast", -1)) >= 300
	assert_true(_until(w, r, [view], casting, 120), "the cast begins")
	assert_true(view.banner_shown(), "the banner is drawn through its cast")
	assert_lt(view.raised(), 0.95, "still being raised")
	assert_gt(view.raised(), 0.0)
	assert_true(view.hold.has(&"cast"), "in the pack's warm lift")
	var standing := func() -> bool:
		return int(r.boss_warlord().get("banner", {}).get("cast", 0)) < 0
	assert_true(_until(w, r, [view], standing, 120), "planted")
	_run(w, r, [view], 1)
	var banner: Dictionary = r.boss_warlord()["banner"]
	assert_almost_eq(view.raised(), 1.0, 0.001, "upright once planted")
	assert_almost_eq(view.pole(), banner["centre"], Vector2(0.001, 0.001), "on its pole")
	var ring := view.ring_circle()
	assert_eq(ring.size(), 2, "its ring")
	assert_almost_eq(ring[0], banner["centre"], Vector2(0.001, 0.001), "on the circle's centre")
	assert_almost_eq(float(ring[1]), float(banner["radius"]), 0.0001, "of its exact radius")
	assert_almost_eq(float(ring[1]), 6.0, 0.0001)
	assert_true(view.hold.has(&"rim"), "the pack's warm rim on it")
	assert_false(view.hold.has(&"cast"), "the lift goes with the cast")


func test_who_stands_inside_shows_on_the_warlord_and_on_the_hero() -> void:
	var s := WarlordLab.ready(Vector2(3, 0), WarlordLab.BANNER)
	var w: World = s[0]
	var i := _i(w, s[1])
	var r := WorldReader.new(w)
	var fx := _pack()
	var view: WarBannerViews = _view(WarBannerViews, fx)
	var avatar := _avatar()
	var views := [view, avatar]
	assert_gt(WarlordLab.to_banner(w), 0)
	_run(w, r, views, 60)
	var banner: Dictionary = r.boss_warlord()["banner"]
	assert_true(bool(banner["boss_inside"]) and bool(banner["hero_inside"]))
	assert_true(view.boss_enraged(), "the Warlord inside: its embers")
	assert_gt(avatar.rage(), 0.9, "and its body glows hot")
	assert_true(view.hero_warmed(), "the hero inside: its warm hand")
	var hits := view.warm_hits()
	_hero_hit(w, i, 10, w.actors.pos(i) + Vector2(-3, 0))
	_draw(r, views)
	assert_eq(view.warm_hits(), hits + 1, "a hit from inside lands warmer")
	assert_gt(fx.live_count(&"hit"), 0, "the pack's warm burst")
	w.actors.set_pos(0, Vector2(-10, 0))
	_run(w, r, views, 2)
	assert_false(bool(r.boss_warlord()["banner"]["hero_inside"]))
	assert_false(view.hero_warmed(), "out of it: no warm hand")
	hits = view.warm_hits()
	_hero_hit(w, i, 10, w.actors.pos(i) + Vector2(-3, 0))
	_draw(r, views)
	assert_eq(view.warm_hits(), hits, "nor warmer hits")
	assert_true(view.boss_enraged(), "the Warlord still in it")
	w.actors.set_pos(i, Vector2(9, 0))
	_run(w, r, views, 60)
	assert_false(bool(r.boss_warlord()["banner"]["boss_inside"]))
	assert_false(view.boss_enraged(), "the Warlord out of it: no embers")
	assert_lt(avatar.rage(), 0.1, "and no heat")


func test_the_banner_burns_down_with_its_time() -> void:
	var s := WarlordLab.ready(Vector2(-8, 0), WarlordLab.BANNER)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var view: WarBannerViews = _view(WarBannerViews, fx)
	assert_gt(WarlordLab.to_banner(w), 0)
	var wt := WarlordLab.wl(w, s[1])
	w.boss_fight.wl_bn_from = w.tick - wt.banner_ticks + 60  # one second left
	_run(w, r, [view], 30)
	assert_true(view.hold.has(&"burn"), "its last seconds: it starts to burn")
	var fell := func() -> bool: return view.falling() == WarBannerViews.FELL_TIME
	assert_true(_until(w, r, [view], fell, 60), "it falls to its time")
	assert_true(view.banner_shown(), "and burns away")
	_run(w, r, [view], 70)
	assert_false(view.banner_shown(), "gone")
	assert_eq(view.ring_circle(), [])
	assert_eq(view.hold.count(), 0)


func test_a_charge_through_the_pole_snaps_it() -> void:
	var s := WarlordLab.ready(Vector2(-8, 0), WarlordLab.BANNER)
	var w: World = s[0]
	var i := _i(w, s[1])
	var r := WorldReader.new(w)
	var fx := _pack()
	var view: WarBannerViews = _view(WarBannerViews, fx)
	assert_gt(WarlordLab.to_banner(w), 0)
	var pole := BossWarlord.pole(w)
	w.actors.set_pos(i, pole + Vector2(8, 1.0))
	w.actors.set_pos(0, pole + Vector2(-8, 1.0))
	_run(w, r, [view], 1)
	BossLab.start(w, i, &"lunge_dash")
	var snapped := func() -> bool: return view.falling() == WarBannerViews.FELL_CHARGE
	assert_true(_until(w, r, [view], snapped, 90), "its charge knocks it down")
	assert_gt(fx.live_count(&"impact"), 0, "the pack's shards at the pole")
	_run(w, r, [view], 60)
	assert_false(view.banner_shown(), "the top flew off and the stump is gone")


func test_the_cage_rains_in_then_stands_on_the_fence_and_closes_with_it() -> void:
	var s := WarlordLab.ready(Vector2(-4, 0), WarlordLab.DUEL)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var view: DuelCageViews = _view(DuelCageViews, fx)
	var half := func() -> bool: return int(r.boss_warlord().get("duel", {}).get("cast", -1)) >= 500
	assert_true(_until(w, r, [view], half, 120), "the cast")
	assert_gt(view.shafts_shown(), 0, "javelins rain in")
	assert_lt(view.shafts_shown(), DuelCageViews.SHAFTS, "one after another")
	var cage := func() -> bool: return int(r.boss_warlord().get("duel", {}).get("stage", 0)) == 2
	assert_true(_until(w, r, [view], cage, 120), "the cage closes")
	_run(w, r, [view], 1)
	var radii := []
	for t in 2:
		var duel: Dictionary = r.boss_warlord()["duel"]
		var c: Vector2 = duel["centre"]
		var radius := float(duel["radius"])
		radii.append(radius)
		assert_eq(view.shafts_shown(), DuelCageViews.SHAFTS, "every shaft planted")
		for k in DuelCageViews.SHAFTS:
			assert_almost_eq(view.shaft_head(k).distance_to(c), radius, 0.001, "on the fence")
		var rim := view.rim_circle()
		assert_almost_eq(rim[0], c, Vector2(0.001, 0.001), "the rim on its centre")
		assert_almost_eq(float(rim[1]), radius, 0.0001, "of its radius")
		assert_false(view.hold.has(&"zone"), "no recall circle yet")
		_run(w, r, [view], 300)
	assert_lt(float(radii[1]), float(radii[0]) - 1.0, "the shafts follow the closing fence")
	var seq := w.last_event_seq()
	var dc: Vector2 = r.boss_warlord()["duel"]["centre"]
	var fence := float(r.boss_warlord()["duel"]["radius"])
	w.actors.set_pos(0, dc + (w.player_pos() - dc).normalized() * fence)
	_run(w, r, [view], 3)
	assert_gt(WarlordLab.effects(w, BossDuel.FENCE, seq).size(), 0, "the hero touched the fence")
	assert_gt(view.sparks(), 0, "sparks at the hero")
	assert_gt(fx.live_count(&"hit"), 0)


func test_the_recall_circle_fills_with_its_warning_and_the_shafts_fly_through_the_centre() -> void:
	var s := WarlordLab.ready(Vector2(-4, 0), WarlordLab.DUEL)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var view: DuelCageViews = _view(DuelCageViews, fx)
	assert_gt(WarlordLab.to_cage(w), 0)
	var c := BossDuel.centre(w)
	_run(w, r, [view], 5)
	assert_eq(view.zone_circle(), [], "no centre circle before the warning")
	var warned := func() -> bool:
		w.actors.set_pos(0, c + Vector2(-3.8, 0))
		return int(r.boss_warlord().get("duel", {}).get("stage", 0)) == 3
	assert_true(_until(w, r, [view], warned, 800), "the warning")
	_run(w, r, [view], 30)
	var zone: Dictionary = r.boss_warlord()["duel"]["zone"]
	var z := view.zone_circle()
	assert_eq(z.size(), 3, "the centre's circle")
	assert_almost_eq(z[0], zone["centre"], Vector2(0.001, 0.001))
	assert_almost_eq(float(z[1]), float(zone["radius"]), 0.0001, "of its radius")
	assert_almost_eq(float(z[2]), float(zone["warn"]) / 1000.0, 0.0001, "filling with the warning")
	assert_true(view.hold.has(&"zone"), "with the pack's rim")
	var over := func() -> bool: return r.boss_warlord().get("duel", {}).is_empty()
	assert_true(_until(w, r, [view], over, 60), "the recall")
	assert_true(view.recalling(), "the shafts fly in")
	var flying := view.shaft_head(0).distance_to(c)
	_run(w, r, [view], 10)
	assert_lt(view.shaft_head(0).distance_to(c), flying, "toward the centre")
	_run(w, r, [view], 20)
	assert_false(view.recalling())
	assert_gt(fx.live_count(&"impact"), 0, "the pack's impact at the centre")
	assert_eq(view.shafts_shown(), 0, "and the cage is gone")


func test_the_shield_is_lowered_only_in_the_cage_and_its_front_takes_plain_hits() -> void:
	var s := WarlordLab.ready(Vector2(-4, 0), WarlordLab.DUEL)
	var w: World = s[0]
	var i := _i(w, s[1])
	var r := WorldReader.new(w)
	var avatar := _avatar()
	_run(w, r, [avatar], 30)
	assert_lt(avatar.shield_lowered(), 0.05, "carried before the cage")
	var front := w.actors.pos(i) + Kin.dir(w.actors.facing[i]) * 3.0
	var tags := 0
	for e in _hero_hit(w, i, 10, front):
		tags |= e.tags
	assert_true(tags & SimEvent.TAG_BLOCKED != 0, "the shield blocks a front hit before the cage")
	var carried := avatar.anchor(&"shield")
	assert_gt(WarlordLab.to_cage(w), 0)
	_run(w, r, [avatar], 60)
	assert_true(bool(r.boss_warlord()["duel"]["shield_down"]))
	assert_gt(avatar.shield_lowered(), 0.9, "lowered while the cage stands")
	if avatar.imported != null:
		assert_gt(
			avatar.anchor(&"shield").distance_to(carried), 0.2, "the shield hangs off its front"
		)
	else:
		gut.p("NOTE: the owner's Warlord model is missing here: the code body lowers it")
	front = w.actors.pos(i) + Kin.dir(w.actors.facing[i]) * 2.0
	tags = 0
	for e in _hero_hit(w, i, 10, front):
		tags |= e.tags
	assert_eq(
		tags & (SimEvent.TAG_BLOCKED | SimEvent.TAG_ARMOURED), 0, "a front hit is a plain hit"
	)


func test_nothing_stays_once_the_fight_ends_and_reduced_motion_builds() -> void:
	ViewPrefs.reduced_motion = true
	var s := WarlordLab.ready(Vector2(3, 0), WarlordLab.BANNER)
	var w: World = s[0]
	var i := _i(w, s[1])
	var r := WorldReader.new(w)
	var fx := _pack()
	var banner: WarBannerViews = _view(WarBannerViews, fx)
	var cage: DuelCageViews = _view(DuelCageViews, fx)
	var avatar := _avatar()
	var views := [banner, cage, avatar]
	assert_gt(WarlordLab.to_banner(w), 0)
	_run(w, r, views, 5)
	assert_true(banner.banner_shown() and banner.hero_warmed(), "drawn with reduced motion")
	WarlordLab.set_phase(w, s[1], WarlordLab.DUEL)
	w.boss_fight.wl_next = w.tick + 1
	assert_gt(WarlordLab.to_cage(w), 0)
	_run(w, r, views, 5)
	assert_eq(cage.shafts_shown(), DuelCageViews.SHAFTS)
	w.actors.hp[i] = 0
	w.actors.dead[i] = 1
	_run(w, r, views, 3)
	assert_eq(r.boss_warlord(), {})
	_run(w, r, views, 90)
	assert_false(banner.banner_shown(), "no banner")
	assert_eq(banner.ring_circle(), [])
	assert_eq(cage.shafts_shown(), 0, "no shaft")
	assert_eq(cage.rim_circle(), [])
	assert_eq(cage.zone_circle(), [])
	assert_eq(banner.hold.count() + cage.hold.count(), 0, "no pack effect held")
	assert_true(banner.quiet and cage.quiet, "both views quiet")


func test_the_warlord_events_borrow_existing_sounds() -> void:
	var effects: Array = WarlordCues.CUES.keys()
	for effect: StringName in effects:
		var e := SimEvent.new()
		e.effect_id = effect
		var out := []
		assert_true(WarlordCues.add(e, out), String(effect))
		var cue: StringName = out[0][0]
		assert_true(ResourceLoader.exists("res://data/audio/cues/%s.tres" % cue), "%s exists" % cue)
	for why: int in [0, 1, 2]:
		var e := SimEvent.new()
		e.effect_id = WarlordCues.FALLEN
		e.amount = why
		var out := []
		assert_true(WarlordCues.add(e, out))
		assert_eq(out.size(), 0 if why == 2 else 1, "a fall at the fight's end is silent")
		for row: Array in out:
			assert_true(ResourceLoader.exists("res://data/audio/cues/%s.tres" % row[0]))
	var other := SimEvent.new()
	other.effect_id = &"not_a_warlord_event"
	assert_false(WarlordCues.add(other, []))
