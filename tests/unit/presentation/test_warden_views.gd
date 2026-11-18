extends GutTest
## The Twin Wardens' fight apart as the player sees it, each view built from WorldReader only, in TwinsLab's walled
## 24 m room: ChargeBurstViews (the end circle of the burst's exact radius where the lane ends, dull while it tracks
## and flashing once it locks, then filling where it was armed, and the debris slam where it burst), WardenWardViews
## (the resting Warden's dome, the Mirror Ward's wall rising through the cast and standing on the reader's arc, the
## whole ward, the long lane glowing under it, the break and the ring to its return), WardenBladeViews (the shadow
## blades on their spots and their slashes, the dash's streak, the rift portals on the reader's spots with only the
## marked exit glowing), the violet rifts, the bar's gold shimmer, the hint arrow without text, the clips, the
## borrowed sounds and the reduced-motion path. Nothing stays once the pair is gone.

const DT := 1.0 / 60.0
const S := EnemyAi.State


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


## The pair hushed and still, the amber Warden at `amber`, the violet at `violet`, the hero at `hero`, in phase
## `phase`. Returns [world, amber id, violet id, reader].
func _stage(hero: Vector2, amber: Vector2, violet: Vector2, phase := 0) -> Array:
	var s := TwinsLab.fight(hero, amber)
	var w: World = s[0]
	TwinsLab.hush(w, s[1])
	if phase > 0:
		TwinsLab.set_phase(w, s[1], phase)
	if phase >= TwinsLab.wardens(w, s[1]).ward_phase:
		TwinsLab.raise_ward(w, s[1])  # As her cast would, at once
	w.actors.set_pos(_i(w, s[1]), amber)
	w.actors.set_pos(_i(w, s[2]), violet)
	w.actors.set_pos(0, hero)
	return [w, s[1], s[2], WorldReader.new(w)]


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


## Steps `n` ticks, each view synced and advanced after it.
func _run(w: World, r: WorldReader, views: Array, n: int) -> void:
	for k in n:
		w.step(InputFrame.new())
		for v: Node in views:
			v.call(&"sync", r)
			v.call(&"advance", DT)


func _until(w: World, r: WorldReader, views: Array, effect: StringName, limit: int) -> SimEvent:
	var seq := TwinsLab.mark(w)
	for k in limit:
		_run(w, r, views, 1)
		var got := TwinsLab.effects(w, effect, seq)
		if not got.is_empty():
			return got[0]
	return null


func test_the_end_circle_is_the_bursts_and_flashes_locked_then_fills_and_explodes() -> void:
	var s := _stage(Vector2(6, 0), Vector2(-8, 0), Vector2(-8, 9))
	var w: World = s[0]
	var r: WorldReader = s[3]
	var fx := _pack()
	var view: ChargeBurstViews = _view(ChargeBurstViews, fx)
	var i := _i(w, s[1])
	BossLab.start(w, i, &"warden_charge_long")
	_run(w, r, [view], 2)
	var charge: Dictionary = r.boss_wardens()["charge"]
	assert_eq(view.shown(), 1, "one circle while he winds up")
	var c: Array = view.circles()[0]
	assert_almost_eq(c[0], charge["end"], Vector2(0.001, 0.001), "where the lane ends")
	assert_eq(c[1], charge["radius"], "the burst's radius")
	assert_eq(c[1], 3.5)
	assert_false(c[2], "dull while the aim tracks")
	var atk := BossAi.attack_of(w, i)
	_run(w, r, [view], atk.windup_ticks - atk.lock_ticks)
	assert_true(view.circles()[0][2], "it flashes locked")
	assert_almost_eq(view.circles()[0][0], r.boss_wardens()["charge"]["end"], Vector2(0.001, 0.001))
	w.actors.set_pos(0, Vector2(-11, 11))
	assert_not_null(_until(w, r, [view], BossChargeBurst.ARMED, 80), "armed where the run stopped")
	_run(w, r, [view], 5)
	var row: Dictionary = r.boss_charge_bursts()[0]
	c = view.circles()[0]
	assert_almost_eq(c[0], row["centre"], Vector2(0.001, 0.001), "the armed circle stays put")
	assert_gt(c[3], 0.0, "and fills as the burst comes")
	assert_not_null(_until(w, r, [view], BossChargeBurst.BURST, 30))
	_run(w, r, [view], 1)
	assert_eq(view.slams.live(), 1, "the ground slam where it burst")
	assert_eq(fx.live_count(&"impact"), 0, "no pack impact")
	assert_eq(fx.live_count(&"explosion"), 0, "no explosion")
	assert_eq(view.shown(), 0, "the circle is gone")


## Each of the amber Warden's charges (phase 1's flash charge, the long charge) in the whole game view: every view
## together plays exactly one effect at the charge's end, the debris slam on the burst's tick at its spot, and no
## explosion, then nothing more.
func test_each_amber_charge_ends_in_one_ground_slam_and_no_explosion() -> void:
	for attack: StringName in [&"warden_charge", &"warden_charge_long"]:
		var s := _stage(Vector2(6, 0), Vector2(-8, 0), Vector2(-8, 9))
		var w: World = s[0]
		var biome: BiomeDefinition = SharedContent.repo().get_def(&"biomes", &"ruins")
		var root := WorldViewRoot.new()
		root.stage.mood = biome.mood
		add_child_autofree(root)
		root.setup(s[3], biome.palette, 60.0)
		root.sync()
		var fx := root.pack_fx
		BossLab.start(w, _i(w, s[1]), attack)
		w.actors.set_pos(0, Vector2(-11, 11))
		var seq := TwinsLab.mark(w)
		var armed: SimEvent = null
		for k in 300:
			_step_root(w, root)
			var got := TwinsLab.effects(w, BossChargeBurst.ARMED, seq)
			if not got.is_empty():
				armed = got[0]
				break
		assert_not_null(armed, "%s: the run stopped and armed its burst" % attack)
		if armed == null:
			continue
		var before := fx.spawned_in.duplicate()
		var slams_before := root.charge_bursts.slams.started()
		var spawned := func(fam: StringName) -> int:
			return int(fx.spawned_in.get(fam, 0)) - int(before.get(fam, 0))
		var burst: SimEvent = null
		for k in 60:
			_step_root(w, root)
			var got := TwinsLab.effects(w, BossChargeBurst.BURST, seq)
			if not got.is_empty():
				burst = got[0]
				break
		assert_not_null(burst, "%s: it burst" % attack)
		var slams := root.charge_bursts.slams
		assert_eq(slams.started() - slams_before, 1, "%s: one slam on the burst's tick" % attack)
		var spots := slams.spots()
		assert_eq(spots.size(), 1, "%s: one slam playing" % attack)
		if spots.size() == 1:
			assert_almost_eq(
				spots[0][0], burst.pos, Vector2(0.01, 0.01), "%s: at the burst's spot" % attack
			)
			assert_eq(spots[0][1], 3.5, "%s: sized to the burst" % attack)
		for k in 90:
			_step_root(w, root)
		var total := 0
		for fam: StringName in fx.spawned_in:
			total += spawned.call(fam)
		assert_eq(spawned.call(&"explosion"), 0, "%s: no explosion" % attack)
		assert_eq(total, 0, "%s: no pack effect played at its end" % attack)
		assert_eq(
			root.charge_bursts.slams.started() - slams_before, 1, "%s: and no second slam" % attack
		)
		root.charge_bursts.advance(GroundSlamViews.LIFE_S)
		assert_eq(
			root.charge_bursts.slams.live(), 0, "%s: the slam is over within its life" % attack
		)


func _step_root(w: World, root: WorldViewRoot) -> void:
	w.actors.hp[0] = w.actors.max_hp[0]
	w.step(InputFrame.new())
	root.sync()


func test_the_resting_warden_wears_its_dome_and_the_whole_ward_is_its_own() -> void:
	var s := _stage(Vector2(6, 0), Vector2(-8, 0), Vector2(0, 6))
	var w: World = s[0]
	var r: WorldReader = s[3]
	var fx := _pack()
	var view: WardenWardViews = _view(WardenWardViews, fx)
	_run(w, r, [view], 2)
	assert_eq(view.resting_domes(), 1, "phase 1: the violet Warden stands back under her dome")
	assert_true(view.hold.has([&"rest", &"violet"]), "the pack's forcefield, hers")
	assert_false(view.full_shown())
	var p := _stage(Vector2(6, 0), Vector2(-8, 0), Vector2(0, 6), 2)
	var v2: WardenWardViews = _view(WardenWardViews, fx)
	_run(p[0], p[3], [v2], 2)
	assert_eq(v2.resting_domes(), 0, "the last phase: both fight")
	assert_true(v2.full_shown(), "her whole ward")
	assert_true(v2.hold.has(&"full") and v2.hold.has(&"full_rim"), "its own dome and floor rim")


func test_the_mirror_wall_rises_through_the_cast_and_stands_on_the_readers_arc() -> void:
	var s := _stage(Vector2(6, 0), Vector2(-9, 0), Vector2.ZERO, 1)
	var w: World = s[0]
	var r: WorldReader = s[3]
	var view: WardenWardViews = _view(WardenWardViews)
	BossLab.start(w, _i(w, s[2]), &"mirror_ward")
	_run(w, r, [view], 30)
	assert_true(view.wall_shown(), "it rises through the cast")
	assert_between(view.wall_up(), 0.3, 0.7, "half way through it")
	assert_eq(view.wall_centre(), 0, "toward the hero")
	assert_not_null(_until(w, r, [view], BossWard.UP, 60))
	_run(w, r, [view], 1)
	var ward: Dictionary = r.boss_wardens()["ward"]
	assert_eq(view.wall_centre(), int(ward["centre"]), "on the reader's arc")
	assert_eq(view.wall_half(), int(ward["half_arc"]), "as wide: 80 degrees each side")
	assert_eq(view.wall_half(), 910)
	assert_almost_eq(view.wall_up(), 1.0, 0.001, "at full height")
	w.actors.set_pos(0, Vector2(0, 7))
	assert_not_null(_until(w, r, [view], BossWard.DOWN, 300))
	_run(w, r, [view], 20)
	assert_false(view.wall_shown(), "gone at its end")


func test_a_returned_shot_flashes_and_flies_back_hostile() -> void:
	var s := _stage(Vector2(6, 0), Vector2(-9, 0), Vector2.ZERO, 1)
	var w: World = s[0]
	var r: WorldReader = s[3]
	var fx := _pack()
	var view: WardenWardViews = _view(WardenWardViews, fx)
	BossLab.start(w, _i(w, s[2]), &"mirror_ward")
	assert_not_null(_until(w, r, [view], BossWard.UP, 80))
	w.queue_projectile(
		w.actors.ids[0],
		ActorStore.TEAM_PLAYER,
		Vector2(4, 0),
		Vector2(-0.3, 0),
		30,
		0.2,
		200,
		SimEvent.TAG_PROJECTILE
	)
	var hits := fx.live_count(&"hit")
	assert_not_null(_until(w, r, [view], BossWard.REFLECT, 30), "turned back")
	assert_gt(fx.live_count(&"hit"), hits, "a flash where it struck")
	_run(w, r, [view], 1)
	assert_eq(r.projectile_count(), 1)
	assert_eq(r.projectile_team(0), ActorStore.TEAM_ENEMY, "it comes back as a hostile shot")
	var wt := TwinsLab.wardens(w, s[1])
	assert_eq(wt.mirror_look, &"warden_violet_ember", "in the violet's own look, not the hero's")
	var seq := TwinsLab.mark(w)
	w.actors.set_pos(0, Vector2(1.5, 0))
	TwinsLab.hit(w, s[2], 80, Vector2(1.5, 0), SimEvent.TAG_MELEE)
	var impacts := fx.live_count(&"impact")
	_run(w, r, [view], 1)
	assert_false(TwinsLab.effects(w, BossWard.BLOCK, seq).is_empty(), "a swing blocked")
	assert_gt(fx.live_count(&"impact"), impacts, "a ring on the hero, pushed back")


func test_the_long_lane_glows_under_the_ward_and_its_break_reads() -> void:
	var s := _stage(Vector2(5, 0), Vector2(-9, 0), Vector2.ZERO, 2)
	var w: World = s[0]
	var r: WorldReader = s[3]
	var fx := _pack()
	var view: WardenWardViews = _view(WardenWardViews, fx)
	var bar := BossBar.new()
	add_child_autofree(bar)
	_run(w, r, [view], 1)
	BossLab.start(w, _i(w, s[1]), &"warden_charge_long")
	_run(w, r, [view], 2)
	assert_true(view.lane_shown(), "his long lane glows on the floor")
	assert_true(r.boss_wardens()["charge"]["breaks"], "white-hot: she stands on it")
	assert_true(view.full_shown())
	assert_not_null(_until(w, r, [view], BossWard.BREAK, 200), "the ward breaks")
	_run(w, r, [view], 2)
	assert_false(view.full_shown(), "the dome is gone")
	assert_true(view.return_shown(), "a ring counts down to its return")
	assert_true(view.hold.has(&"stars"), "stars over her while she is stunned")
	bar.sync(r)
	assert_eq(bar.tone(), BossBarTones.VULNERABLE, "the bar shimmers gold while she is stunned")
	assert_eq(
		r.actor_state(_i(w, s[2])), WorldReader.STATE_STAGGERED, "her avatar's stagger clip plays"
	)


func test_shadow_blades_hang_on_their_spots_then_slash_and_leave_violet_rifts() -> void:
	var s := _stage(Vector2(3, 0), Vector2(-9, 9), Vector2(-6, 0), 1)
	var w: World = s[0]
	var r: WorldReader = s[3]
	var fx := _pack()
	var view: WardenBladeViews = _view(WardenBladeViews, fx)
	var hz := HazardViews.new()
	add_child_autofree(hz)
	BossLab.start(w, _i(w, s[2]), &"shadow_swords")
	_run(w, r, [view], 2)
	var rows: Array = r.boss_wardens()["swords"]
	assert_eq(view.blades_shown(), 5, "five blades")
	for k in 5:
		assert_almost_eq(
			view.blade_at(k), rows[k]["from"], Vector2(0.01, 0.01), "blade %d on its spot" % k
		)
	var slashed := 0
	for k in 120:
		_run(w, r, [view], 1)
		slashed = maxi(slashed, view.slashes_shown())
	assert_gt(slashed, 0, "a dark slash runs down each line as it cuts")
	hz.sync(r)
	assert_gt(hz.hazard_count(), 0, "the cuts left rifts")
	assert_true(hz.twin_rifts(), "drawn violet while the Wardens fight")
	var j := JudgeLab.fight(Vector2(-6, 0), Vector2(6, 0))
	hz.sync(WorldReader.new(j[0]))
	assert_false(hz.twin_rifts(), "another boss's keep their look")


func test_the_rift_portals_are_the_readers_and_only_the_marked_exit_glows() -> void:
	var s := _stage(Vector2(0, -8), Vector2(-9, 0), Vector2(9, 6), 2)
	var w: World = s[0]
	var r: WorldReader = s[3]
	TwinsLab.wardens(w, s[1]).rift_hp_permille = 500
	TwinsLab.set_hp(w, s[1], 166)
	var fx := _pack()
	var view: WardenBladeViews = _view(WardenBladeViews, fx)
	assert_not_null(_until(w, r, [view], BossRift.OPENED, 5))
	_run(w, r, [view], 30)
	var rifts: Array = r.boss_wardens()["rift"]["rifts"]
	var drawn := view.portals()
	assert_eq(drawn.size(), 3, "three portals")
	for k in 3:
		assert_eq(drawn[k][0], rifts[k]["centre"], "portal %d on its rift" % k)
		assert_eq(drawn[k][1], rifts[k]["radius"])
	assert_eq(view.exits_glowing(), 0, "no exit glows yet")
	assert_not_null(_until(w, r, [view], BossRift.ENTER, 300), "he goes in")
	assert_eq(view.exits_glowing(), 0, "still none while the exit is hidden")
	assert_not_null(_until(w, r, [view], BossRift.MARK, 120), "the exit is marked")
	_run(w, r, [view], 1)
	assert_eq(view.exits_glowing(), 1, "only the marked one glows")
	var glowing := -1
	for k in 3:
		if view.portals()[k][3]:
			glowing = k
	assert_true(r.boss_wardens()["rift"]["rifts"][glowing]["exit"], "the reader's exit")
	assert_true(view.exit_lane_shown(), "its lane on the floor")
	var rift: Dictionary = r.boss_wardens()["rift"]
	var end: Array = view.exit_end()
	assert_eq(end.size(), 2, "and the burst's circle at its end")
	if end.size() == 2:
		assert_almost_eq(end[0], rift["lane"][1], Vector2(0.01, 0.01))
		assert_eq(end[1], rift["burst_radius"])


func test_the_side_dash_leaves_a_streak() -> void:
	var s := _stage(Vector2(4, 0), Vector2(-2, 0), Vector2(-8, 9))
	var w: World = s[0]
	var r: WorldReader = s[3]
	var view: WardenBladeViews = _view(WardenBladeViews)
	var wt := TwinsLab.wardens(w, s[1])
	wt.dash_every_ticks = 180
	w.boss_fight.wd_dash_cd = 0
	w.actors.cd[_i(w, s[1])] = 60  # between two attacks
	var streaked := false
	for k in 60:
		_run(w, r, [view], 1)
		streaked = streaked or view.streak_shown()
	assert_false(TwinsLab.effects(w, BossWardenAmber.DASH).is_empty(), "he dashed")
	assert_true(streaked, "an afterimage streak behind him")


func test_nothing_stays_after_the_pair_is_gone() -> void:
	var s := _stage(Vector2(5, 0), Vector2(-9, 0), Vector2.ZERO, 2)
	var w: World = s[0]
	var r: WorldReader = s[3]
	var fx := _pack()
	var views := [
		_view(ChargeBurstViews, fx), _view(WardenWardViews, fx), _view(WardenBladeViews, fx)
	]
	BossLab.start(w, _i(w, s[1]), &"warden_charge_long")
	_run(w, r, views, 3)
	assert_gt((views[0] as ChargeBurstViews).shown(), 0)
	assert_gt((views[1] as WardenWardViews).hold.count(), 0)
	var me := w.actors.ids[0]
	for k in 1500:
		var i := _i(w, s[1])
		if i < 0:
			break
		Damage.hit(w, i, 1 << 24, me, me, w.take_root(), 0, w.player_pos(), w.actors.pos(i))
		w.step(InputFrame.new())
	assert_lt(_i(w, s[1]), 0, "the pair is gone")
	assert_true(r.boss_wardens().is_empty())
	for v: Node in views:
		v.call(&"sync", r)
	for k in 60:
		for v: Node in views:
			v.call(&"advance", DT)
	assert_eq((views[0] as ChargeBurstViews).shown(), 0)
	var wards: WardenWardViews = views[1]
	assert_false(wards.wall_shown() or wards.lane_shown() or wards.return_shown())
	var blades: WardenBladeViews = views[2]
	assert_eq(blades.blades_shown() + blades.slashes_shown(), 0)
	for v: Node in views:
		var hold := v.get(&"hold") as FormPackHold  # (the charge's circle holds no pack effect)
		assert_eq(hold.count() if hold != null else 0, 0, "%s released its effects" % v.name)
		assert_true(bool(v.get(&"quiet")), "%s idles" % v.name)


func test_reduced_motion_builds_every_view() -> void:
	ViewPrefs.reduced_motion = true
	var s := _stage(Vector2(6, 0), Vector2(-8, 0), Vector2(0, 6), 1)
	var w: World = s[0]
	var r: WorldReader = s[3]
	var views := [_view(ChargeBurstViews), _view(WardenWardViews), _view(WardenBladeViews)]
	BossLab.start(w, _i(w, s[2]), &"shadow_swords")
	_run(w, r, views, 3)
	assert_eq((views[2] as WardenBladeViews).blades_shown(), 5, "the blades hang still")
	BossLab.start(w, _i(w, s[1]), &"warden_charge_long")
	_run(w, r, views, 3)
	assert_eq((views[0] as ChargeBurstViews).shown(), 1, "the end circle, its pulse still")


func test_the_hint_on_the_warded_violet_is_an_arrow_without_text() -> void:
	assert_eq(MechanicHints.TWINS_WARD, ObjectiveMarkers.TWINS_WARD)
	assert_eq(
		ObjectiveHints.DOWN_GAPS[MechanicHints.TWINS_WARD], 150.0, "a small arrow over her dome"
	)
	assert_false(MechanicHints.TWINS_WARD in MechanicHints.ALWAYS, "the first two runs only")


func test_each_new_move_plays_a_file_clip() -> void:
	var a := TwinWardenAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	for move: int in [
		WorldReader.MOVE_SWORD_COMBO,
		WorldReader.MOVE_SWEEP,
		WorldReader.MOVE_MIRROR_WARD,
		WorldReader.MOVE_SHADOW_SWORDS
	]:
		var clip := BossAnimator.clip_name_for(move, false, a.animator.clips)
		assert_ne(clip, &"", "move %d has a clip" % move)
		assert_true(a.animator.owner_has(clip), "%s plays the file's animation" % clip)


func test_the_sounds_borrow_cues_that_exist() -> void:
	for effect: StringName in WardenCues.CUES:
		var e := SimEvent.new()
		e.effect_id = effect
		var out := []
		assert_true(WardenCues.add(e, out), "%s has a cue" % effect)
		var id: StringName = out[0][0]
		assert_true(ResourceLoader.exists("res://data/audio/cues/%s.tres" % id), "cue %s" % id)
	for effect: StringName in [
		BossChargeBurst.ARMED,
		BossChargeBurst.BURST,
		BossWardenAmber.DASH,
		BossWard.UP,
		BossWard.BREAK,
		BossWard.REFLECT,
		BossWard.BLOCK,
		BossShadowSwords.CUT,
		BossRift.OPENED,
		BossRift.ENTER,
		BossRift.MARK,
		BossRift.EXIT
	]:
		assert_true(WardenCues.CUES.has(effect), "%s sounds" % effect)
	for none: StringName in [BossWard.DOWN, BossRift.CLOSED]:
		var e := SimEvent.new()
		e.effect_id = none
		assert_false(WardenCues.add(e, []), "%s is silent" % none)


func test_the_pack_rows_are_in_the_table() -> void:
	var def := PackFx.shared_def()
	for id: StringName in (
		[
			WardenWardViews.RIM_ID,
			WardenWardViews.REFLECT_ID,
			WardenWardViews.PUSH_ID,
			WardenWardViews.SHATTER_ID,
			WardenWardViews.REFORM_ID,
			WardenWardViews.STARS_ID,
			WardenWardViews.STUN_ID,
			WardenWardViews.RIPPLE_ID,
			WardenBladeViews.FLARE_ID,
			WardenBladeViews.PORTAL_ID,
			WardenBladeViews.EXIT_ID,
			HazardViews.RIFT_ID,
			HazardViews.RIFT_WARN_ID,
		]
		+ WardenWardViews.DOME_IDS.values()
	):
		var k := def.row(id)
		assert_gte(k, 0, "%s is in the table" % id)
		if k >= 0:
			assert_string_starts_with(def.scenes[k], "res://assets/BinbunVFX/", "a pack scene")


func test_the_phase_one_charge_draws_nothing_on_the_ground() -> void:
	var s := _stage(Vector2(6, 0), Vector2(-8, 0), Vector2(-8, 9))
	var w: World = s[0]
	var r: WorldReader = s[3]
	var fx := _pack()
	var view: ChargeBurstViews = _view(ChargeBurstViews, fx)
	var ward: WardenWardViews = _view(WardenWardViews, fx)
	var i := _i(w, s[1])
	BossLab.start(w, i, &"warden_charge")
	var flashed := false
	while w.actors.state[i] == S.WINDUP:
		_run(w, r, [view, ward], 1)
		assert_eq(view.shown(), 0, "no end circle")
		assert_false(ward.lane_shown(), "no lane")
		flashed = flashed or r.boss_twin(i).has("flash")
	assert_true(flashed, "his body's flash instead")
	w.actors.set_pos(0, Vector2(-11, 11))
	assert_not_null(_until(w, r, [view], BossChargeBurst.ARMED, 80), "its burst stays")


func test_the_whole_ward_is_cast_with_the_re_forming_light_not_a_wall() -> void:
	var s := _stage(Vector2(6, 0), Vector2(-8, 0), Vector2(0, 6))
	var w: World = s[0]
	var r: WorldReader = s[3]
	TwinsLab.set_phase(w, s[1], 2)
	var fx := _pack()
	var view: WardenWardViews = _view(WardenWardViews, fx)
	_run(w, r, [view], 2)
	assert_false(view.full_shown(), "no ward at the phase's start")
	var j := _i(w, s[2])
	var seen := false
	for k in TwinsLab.wardens(w, s[1]).ward_first_ticks + 90:
		_run(w, r, [view], 1)
		if BossWard.casting(w, j):
			seen = true
			assert_true(view.raising_shown(), "the re-forming light on her through the cast")
			assert_true(view.hold.has(&"reform"))
			assert_false(view.wall_shown(), "not the Mirror Ward's wall")
	assert_true(seen, "she cast it")
	assert_true(view.full_shown(), "then her whole ward stands")
	assert_false(view.raising_shown())


## The ground slam alone: stone pieces thrown up off the floor and a crack under them at once, everything back down
## and gone within its life, sized to the radius, from one pooled MultiMesh.
func test_a_ground_slam_throws_stone_up_and_is_gone_within_its_life() -> void:
	var g := GroundSlamViews.new()
	add_child_autofree(g)
	g.floor_palette({"ground": Color(0.8, 0.7, 0.6), "cover": Color(0.3, 0.3, 0.3)})
	g.slam(Vector3(2, 0, -1), 3.5)
	g.advance(1.0 / 60.0)
	assert_gt(g.pieces_shown(), 0, "pieces at once")
	assert_eq(g.cracks_shown(), 1, "the floor cracked at once")
	g.advance(0.2)
	assert_gt(g.highest(), 0.5, "chunks kicked up off the floor")
	assert_lte(g.pieces_shown(), GroundSlamViews.PIECES)
	g.advance(0.5)
	assert_lt(g.highest(), 0.35, "back down on the floor by 0.7 s")
	g.advance(GroundSlamViews.LIFE_S - 0.7)
	assert_eq(g.live(), 0, "over")
	assert_eq(g.pieces_shown(), 0, "every piece gone")
	assert_eq(g.cracks_shown(), 0, "the crack faded")
	assert_false(g.busy())
