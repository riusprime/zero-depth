extends GutTest
## The Tidecaller's dance as the player sees it, each view built from WorldReader only, in TideLab's walled 24 m
## room: TideDanceViews (the Riptide strips on the reader's exact rectangles, struck and dry, and the walls of water
## on the front; the High Tide's water plane, its dry circle of the exact centre and radius, the ring of time left),
## MaelstromViews (the spiral on the boss turning the sim's way, the eye of its exact radius, the throw's streak), the
## HUD's edge glow in the flood, the hint arrows on the dry circle, the tide pools' water look, the borrowed sounds,
## the cast's clip and the reduced-motion path. Nothing stays once the Tidecaller is gone.

const DT := 1.0 / 60.0
const NEVER := 9


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


## A hushed, still Tidecaller in a corner, in phase index `phase`, with only the named parts of its dance on.
## Returns [world, its id, a reader].
func _only(hero_at: Vector2, phase: int, parts: Array) -> Array:
	var s := TideLab.fight(hero_at, Vector2(-9.0, 9.0))
	var w: World = s[0]
	TideLab.hush(w, s[1])
	var d := TideLab.dance(w, s[1])
	if not parts.has("riptide"):
		d.rip_phase = NEVER
	if not parts.has("high_tide"):
		d.ht_phase = NEVER
	if not parts.has("maelstrom"):
		d.mael_phase = NEVER
	TideLab.set_phase(w, s[1], phase)
	return [w, s[1], WorldReader.new(w)]


func _to_riptide(hero_at := Vector2.ZERO) -> Array:
	var s := _only(hero_at, 1, ["riptide"])
	assert_not_null(JudgeLab.until_effect(s[0], BossDance.RIP_CAST, 700), "a row begins")
	return s


func _to_high_tide(hero_at := Vector2(9, -4)) -> Array:
	var s := _only(hero_at, 2, ["high_tide"])
	assert_not_null(JudgeLab.until_effect(s[0], BossDance.HT_CAST, 600), "a High Tide is cast")
	return s


func _view() -> TideDanceViews:
	var v := TideDanceViews.new()
	add_child_autofree(v)
	v.set_process(false)
	return v


func _mael_view() -> MaelstromViews:
	var v := MaelstromViews.new()
	add_child_autofree(v)
	v.set_process(false)
	return v


func _draw(view: Node, r: WorldReader) -> void:
	view.call(&"sync", r)
	view.call(&"advance", DT)


func _kill(w: World, aid: int) -> void:
	var me := w.actors.ids[0]
	for k in 1200:  # through its gates: a hit never takes it past one
		var i := _i(w, aid)
		if i < 0:
			break
		Damage.hit(w, i, 1 << 24, me, me, w.take_root(), 0, w.player_pos(), w.actors.pos(i))
		w.step(InputFrame.new())
	assert_lt(_i(w, aid), 0, "the Tidecaller is gone")


func test_the_strips_are_the_readers_rectangles_three_struck_one_dry() -> void:
	var s := _to_riptide()
	var r: WorldReader = s[2]
	var view := _view()
	_draw(view, r)
	var st := r.boss_dance()
	var rip: Dictionary = st["riptide"]
	assert_eq(view.strips_shown(), 4, "the four strips")
	for k in 4:
		var want: Rect2 = st["strips"][k]
		var got := view.strip_rect(k)
		assert_almost_eq(got.position.x, want.position.x, 0.001, "strip %d's place" % k)
		assert_almost_eq(got.position.y, want.position.y, 0.001)
		assert_almost_eq(got.size.x, want.size.x, 0.001, "and its size")
		assert_almost_eq(got.size.y, want.size.y, 0.001)
		assert_eq(
			view.strip_struck(k), (rip["struck"] as Array).has(k), "struck as the sim warns it"
		)
	assert_false(view.strip_struck(int(rip["safe"])), "the dry strip")
	var warn0 := view.strip_param((rip["struck"] as Array)[0], &"warn")
	CombatLab.idle(s[0], 60)
	_draw(view, r)
	var later := view.strip_param((r.boss_dance()["riptide"]["struck"] as Array)[0], &"warn")
	assert_gt(later, warn0 + 0.3, "the water rises with the warning")
	for k in 4:
		assert_false(view.wall_shown(k), "no wave before the warning ends")


func test_a_wall_of_water_runs_down_each_struck_strip_on_the_front() -> void:
	var s := _to_riptide()
	var w: World = s[0]
	var r: WorldReader = s[2]
	var view := _view()
	assert_not_null(JudgeLab.until_effect(w, BossDance.RIP_WAVE, 200), "the wave runs")
	CombatLab.idle(w, 10)
	_draw(view, r)
	var st := r.boss_dance()
	var rip: Dictionary = st["riptide"]
	assert_gte(int(rip["wave"]), 0, "mid-wave")
	var room: Rect2 = st["room"]
	assert_true(bool(st["along_x"]), "TideLab's square room runs its strips along x")
	var crest := {}
	for k in 4:
		var strip: Rect2 = st["strips"][k]
		if (rip["struck"] as Array).has(k):
			assert_true(view.wall_shown(k), "a wall on struck strip %d" % k)
			var at := view.wall_crest(k)
			assert_almost_eq(
				at.x, room.position.x + float(rip["front"]), 0.01, "its crest on the front"
			)
			assert_almost_eq(at.y, strip.get_center().y, 0.01, "down the strip's middle")
			crest[k] = at.x
		else:
			assert_false(view.wall_shown(k), "none on the dry strip")
		assert_gte(view.strip_param(k, &"front"), 0.0 if crest.has(k) else -1.0)
	CombatLab.idle(w, 8)
	_draw(view, r)
	for k: int in crest:
		assert_gt(view.wall_crest(k).x, float(crest[k]) + 2.0, "it runs on with the front")


func test_the_dry_circle_is_the_readers_and_the_water_rises_around_it() -> void:
	var s := _to_high_tide()
	var w: World = s[0]
	var r: WorldReader = s[2]
	var view := _view()
	_draw(view, r)
	var ht: Dictionary = r.boss_dance()["high_tide"]
	assert_true(view.dry_shown(), "the dry circle")
	assert_almost_eq(view.dry_centre().distance_to(ht["centre"]), 0.0, 0.001, "at its centre")
	assert_almost_eq(view.dry_radius(), float(ht["radius"]), 0.001, "its exact radius")
	var hole: Array = view.flood_hole()
	assert_almost_eq((hole[0] as Vector2).distance_to(ht["centre"]), 0.0, 0.001, "the water's hole")
	assert_almost_eq(float(hole[1]), float(ht["radius"]), 0.001)
	assert_true(view.flood_shown())
	var rising := view.flood_level()
	assert_lt(rising, TideDanceViews.CAST_LEVEL, "rising through the cast")
	assert_almost_eq(view.dry_share(), float(ht["cast"]) / 1000.0, 0.001, "the ring fills with it")
	assert_false(TideDanceViews.flooding(r), "the cast costs nothing: no edge glow")
	assert_not_null(JudgeLab.until_effect(w, BossDance.HT_FLOOD, 200), "the water is up")
	CombatLab.idle(w, 60)
	_draw(view, r)
	assert_almost_eq(view.flood_level(), 1.0, 0.001, "full")
	var share := view.dry_share()
	assert_lt(share, 1.0, "the ring shrinks with the time left")
	assert_true(TideDanceViews.flooding(r), "outside it, the edge glow")
	CombatLab.idle(w, 60)
	_draw(view, r)
	assert_lt(view.dry_share(), share - 0.1)
	w.actors.set_pos(0, r.boss_dance()["high_tide"]["centre"])
	w.step(InputFrame.new())
	assert_false(TideDanceViews.flooding(r), "inside it, none")
	assert_not_null(JudgeLab.until_effect(w, BossDance.HT_END, 400), "it ends")
	_draw(view, r)
	assert_false(view.dry_shown(), "the circle goes with it")
	assert_true(view.flood_shown(), "the water drains")
	for k in 70:
		view.advance(DT)
	assert_false(view.flood_shown(), "and is gone")


func test_the_hud_glows_at_the_edges_while_the_flood_hurts() -> void:
	var s := _to_high_tide()
	var w: World = s[0]
	var r: WorldReader = s[2]
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.sync(r)
	assert_false(hud.tide_flood.active, "not in the cast")
	assert_not_null(JudgeLab.until_effect(w, BossDance.HT_FLOOD, 200))
	w.step(InputFrame.new())
	hud.sync(r)
	assert_true(hud.tide_flood.active, "outside the circle in the flood")
	assert_true(hud.tide_flood.visible)


func test_the_dry_circle_carries_a_hint_arrow_without_a_line() -> void:
	var s := _to_high_tide()
	var r: WorldReader = s[2]
	var hints := ObjectiveHints.new()
	add_child_autofree(hints)
	var centre := hints.get_viewport().get_visible_rect().size * 0.5
	hints.project = func(sim: Vector2) -> Vector2: return centre + sim * 10.0
	hints.gate = func(_reason: StringName) -> bool: return true
	hints.sync(r)
	var dry := MechanicHints.TIDE_DRY
	assert_eq(dry, ObjectiveMarkers.TIDE_DRY)
	assert_true(hints.showing(dry, ObjectiveHints.PING), "on screen")
	assert_true(dry in ObjectiveHints.DOWN_ARROW, "the pillars' small arrow above it")
	assert_eq(hints.line(dry), "", "no line of text")
	hints.project = func(sim: Vector2) -> Vector2: return centre + sim * 1000.0
	hints.sync(r)
	assert_true(hints.showing(dry, ObjectiveHints.ARROW), "off screen: an arrow at the edge")
	assert_false(dry in MechanicHints.ALWAYS, "shown the first runs that meet it")


func test_the_spiral_turns_the_sims_way_round_the_boss_and_the_eye_is_its_radius() -> void:
	var s := _only(Vector2(8, 0), 2, ["maelstrom"])
	var w: World = s[0]
	var r: WorldReader = s[2]
	var view := _mael_view()
	_draw(view, r)
	assert_false(view.spiral_shown(), "not before it begins")
	w.step(InputFrame.new())
	_draw(view, r)
	var m: Dictionary = r.boss_dance()["maelstrom"]
	assert_false(m.is_empty(), "the Maelstrom runs")
	assert_true(view.spiral_shown())
	assert_almost_eq(view.spiral_centre().distance_to(m["centre"]), 0.0, 0.001, "on the Tidecaller")
	assert_eq(int(view.spiral_param(&"spin")), int(m["spin"]), "turning the sim's way")
	assert_almost_eq(
		view.spiral_param(&"pitch"),
		float(m["inward"]) / float(m["around"]),
		0.001,
		"as tight as its pull in"
	)
	assert_true(view.eye_shown())
	assert_almost_eq(view.eye_radius(), float(m["eye"]), 0.001, "the eye's exact radius")
	assert_almost_eq(view.eye_danger(), 1.0, 0.001, "armed")
	var c0 := view.clock()
	view.advance(DT)
	assert_gt(view.clock(), c0, "the water moves")
	var boss := w.actors.pos(_i(w, s[1]))
	w.actors.set_pos(0, boss + Vector2(float(m["eye"]) - 0.4, 0))
	w.step(InputFrame.new())
	assert_eq(JudgeLab.effects(w, BossMaelstrom.THROW).size(), 1, "the eye throws the hero")
	_draw(view, r)
	assert_true(view.streak_live(), "the throw's streak")
	assert_lt(view.eye_danger(), 1.0, "the rim dims through the eye's grace")
	for k in 40:
		view.advance(DT)
	assert_false(view.streak_live(), "gone in half a second")


func test_reduced_motion_holds_the_spiral_still_with_its_marks() -> void:
	ViewPrefs.reduced_motion = true
	var s := _only(Vector2(8, 0), 2, ["maelstrom"])
	var w: World = s[0]
	var view := _mael_view()
	w.step(InputFrame.new())
	_draw(view, s[2])
	var c0 := view.clock()
	for k in 30:
		view.advance(DT)
	assert_true(view.spiral_shown(), "still drawn")
	assert_eq(view.clock(), c0, "but held still")
	assert_almost_eq(view.spiral_param(&"still"), 1.0, 0.001, "with its rings and dashes")
	var tide := _view()
	var rs := _to_riptide()
	_draw(tide, rs[2])
	assert_eq(tide.strips_shown(), 4, "the strips build and show")


func test_nothing_stays_after_the_tidecaller_with_the_pack() -> void:
	var s := _only(Vector2(8, 0), 2, ["maelstrom", "high_tide"])
	var w: World = s[0]
	var r: WorldReader = s[2]
	var fx := PackFx.new()
	add_child_autofree(fx)
	var tide := _view()
	var mael := _mael_view()
	tide.pack_fx = fx
	mael.pack_fx = fx
	assert_not_null(JudgeLab.until_effect(w, BossDance.HT_CAST, 600))
	_draw(tide, r)
	_draw(mael, r)
	assert_true(tide.dry_shown() and mael.spiral_shown(), "the circle on the whirlpool")
	assert_gt(tide.hold.count(), 0, "the pack's effects held")
	assert_gt(mael.hold.count(), 0)
	_kill(w, s[1])
	assert_true(r.boss_dance().is_empty(), "no dance")
	_draw(tide, r)
	_draw(mael, r)
	for k in 70:
		tide.advance(DT)
		mael.advance(DT)
	assert_eq(tide.strips_shown(), 0)
	assert_false(tide.dry_shown() or tide.flood_shown(), "no circle, no water")
	assert_false(mael.spiral_shown() or mael.eye_shown(), "no whirlpool")
	assert_eq(tide.hold.count() + mael.hold.count(), 0, "every pack effect released")
	assert_true(tide.quiet and mael.quiet)


func test_the_cast_plays_the_bell_clips() -> void:
	var s := _to_riptide()
	var r: WorldReader = s[2]
	var cast := TidecallerAvatar.cast_clip(r.boss_dance())
	assert_eq(cast[0], &"pattern", "a Riptide warning tolls the bell (the file's bell_toll)")
	assert_between(float(cast[1]), 0.0, 1.0)
	var h := _to_high_tide()
	cast = TidecallerAvatar.cast_clip((h[2] as WorldReader).boss_dance())
	assert_eq(cast[0], &"tide", "a High Tide's cast raises it (bell_raise)")
	assert_eq(TidecallerAvatar.cast_clip({}), [], "none without a cast")
	var a := TidecallerAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	for clip: StringName in [&"pattern", &"tide"]:
		assert_true(a.animator.has_clip(clip), "the clip %s is there" % clip)
	a.sync(h[2], _i(h[0], h[1]))
	assert_eq(a.cast_now()[0], &"tide")
	a.advance(DT)


func test_the_tide_pools_take_the_water_look() -> void:
	var s := _only(Vector2(8, 0), 0, [])
	var hz := HazardViews.new()
	add_child_autofree(hz)
	hz.sync(s[2])
	assert_true(hz.tide_pools(), "the Tidecaller's pools draw as water")
	var j := JudgeLab.fight(Vector2(-6, 0), Vector2(6, 0))
	hz.sync(WorldReader.new(j[0]))
	assert_false(hz.tide_pools(), "another boss's keep their look")


func test_the_sounds_borrow_cues_that_exist() -> void:
	for effect: StringName in [
		&"riptide_cast",
		&"riptide_wave",
		&"high_tide_cast",
		&"high_tide",
		&"maelstrom",
		&"maelstrom_throw"
	]:
		var e := SimEvent.new()
		e.effect_id = effect
		var out := []
		assert_true(TideDanceCues.add(e, out), "%s has a cue" % effect)
		var id: StringName = out[0][0]
		assert_true(ResourceLoader.exists("res://data/audio/cues/%s.tres" % id), "cue %s" % id)
	for none: StringName in [&"riptide_hit", &"high_tide_end"]:
		var e := SimEvent.new()
		e.effect_id = none
		assert_false(
			TideDanceCues.add(e, []), "%s sounds through the hurt cue or not at all" % none
		)


func test_the_pack_rows_are_in_the_table() -> void:
	var def := PackFx.shared_def()
	for id: StringName in [
		TideDanceViews.WATER_ID,
		TideDanceViews.SPLASH_ID,
		TideDanceViews.DRY_ID,
		TideDanceViews.CAST_ID,
		MaelstromViews.EYE_ID,
		HazardViews.POOL_ID
	]:
		var k := def.row(id)
		assert_gte(k, 0, "%s is in the table" % id)
		assert_string_starts_with(def.scenes[k], "res://assets/BinbunVFX/", "a pack scene")
