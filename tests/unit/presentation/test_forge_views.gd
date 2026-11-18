extends GutTest
## The Foundry's forge as the player sees it, each view built from WorldReader only, in ForgeLab's walled 24 m room:
## the Forged Plate (the forging read, the steel shell on the owner's model while it is on, the bombs' flare and the
## faint ring only while one flies, the shards and BossVulnerableViews' gold pulse for its exposed time, the bar's
## iron then gold), the cooling slag (a pool's crust following its cooling, each slab of its exact centre and radius,
## cracking near its end and gone once shattered), the Overpressure (the room's heat rising with the cast, the slabs
## cut out of it, the safe ones ringed, the HUD's fire edge off a slab), the scald gauge (its fill, burn and drain on
## the HUD, hidden before its phase, not the Overclock meter) and the hero's ember, flames and steam. No words; the
## hint arrow on the safe slab; the borrowed sounds; nothing stays once the fight ends; the reduced-motion path.

const DT := 1.0 / 60.0
const NEVER := 9
const PLATE := 1
const LAST := 2


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


## A hushed, still Foundry at the room's centre in phase index `phase`, with only the named parts of its forge on.
func _only(hero_at: Vector2, phase: int, parts: Array) -> Array:
	var s := ForgeLab.fight(hero_at, Vector2.ZERO)
	var w: World = s[0]
	ForgeLab.hush(w, s[1])
	var f := ForgeLab.forge(w, s[1])
	if not parts.has("plate"):
		f.plate_phase = NEVER
	if not parts.has("slab"):
		f.slab_phase = NEVER
	if not parts.has("drop"):
		f.drop_ticks = 0
	if not parts.has("over"):
		f.over_phase = NEVER
	if not parts.has("scald"):
		f.scald_phase = NEVER
	ForgeLab.set_phase(w, s[1], phase)
	w.step(InputFrame.new())  # The forge takes its clocks
	return s


## Steps `n` ticks (the hero refilled), each view synced and advanced after it.
func _run(w: World, r: WorldReader, views: Array, n: int) -> void:
	for k in n:
		w.step(InputFrame.new())
		ForgeLab.take_lost(w)
		_draw(r, views)


func _draw(r: WorldReader, views: Array) -> void:
	for v: Node in views:
		if v is BossAvatar:
			v.call(&"sync", r, r.boss_index())
			v.call(&"advance", DT)
			continue
		v.call(&"sync", r)
		if v is BossVulnerableViews or v is ForgeHeroViews:
			v.call(&"advance")
		elif v.has_method(&"advance"):
			v.call(&"advance", DT)


func _until(w: World, r: WorldReader, views: Array, done: Callable, limit: int) -> bool:
	for k in limit:
		if done.call():
			return true
		_run(w, r, views, 1)
	return done.call()


func _foundry() -> FoundryAvatar:
	var a := FoundryAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	return a


func test_the_plate_forges_then_shells_the_model_and_a_bomb_blows_it_off_into_the_vulnerable_read(
) -> void:
	var s := _only(Vector2(2.6, 0), PLATE, ["plate"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var plate: ForgePlateViews = _view(ForgePlateViews, fx)
	var vuln: BossVulnerableViews = _view(BossVulnerableViews, fx)
	var avatar := _foundry()
	var bar := BossBar.new()
	add_child_autofree(bar)
	var views := [plate, vuln, avatar]
	w.boss_fight.fg_plate_due = w.tick  # forge at once
	_run(w, r, views, 10)
	assert_gte(int(r.boss_forge()["plate"]["forging"]), 0, "forging")
	assert_true(plate.forging_shown(), "the forge's lift on the Foundry")
	assert_gt(fx.live_count(&"hit"), 0, "and the hammer's sparks")
	var on := func() -> bool: return bool(r.boss_forge()["plate"]["on"])
	assert_true(_until(w, r, views, on, 200), "the plate goes on")
	_run(w, r, views, 30)
	assert_false(plate.forging_shown(), "the forging read ends with the cast")
	if avatar.imported != null:
		assert_almost_eq(avatar.plate_amount(), 1.0, 0.05, "the model wears its steel shell")
		assert_gt(avatar.plate_shell.albedo_color.a, 0.15)
	else:
		gut.p("NOTE: the owner's Foundry model is missing here: no shell to check")
	bar.sync(r)
	assert_eq(bar.tone(), BossBarTones.PLATED, "the bar turns iron")
	assert_eq(vuln.shown(), 0, "not vulnerable while plated")
	var flying := func() -> bool: return plate.bombs_shown() > 0
	assert_true(_until(w, r, views, flying, 600), "the drone lobs a bomb")
	_run(w, r, views, 1)
	assert_true(plate.hold.has([&"bomb", 0]), "the bomb carries the ember flare")
	assert_ne(plate.reach_read(), &"", "the faint ring by the Foundry while it flies")
	var blown := func() -> bool: return int(r.boss_forge()["plate"]["exposed_left"]) > 0
	assert_true(_until(w, r, views, blown, 200), "it lands by the Foundry and blows the plate")
	_run(w, r, views, 1)
	assert_gt(fx.live_count(&"impact"), 0, "the plate's shards")
	assert_eq(vuln.shown(), 1, "the exposed Foundry glows vulnerable")
	assert_eq(plate.reach_read(), &"", "no ring once nothing flies at a plate")
	if avatar.imported != null:
		assert_eq(avatar.plate_amount(), 0.0, "the shell is gone at once")
	bar.sync(r)
	assert_eq(bar.tone(), BossBarTones.VULNERABLE, "the bar shimmers gold")
	assert_eq(bar.phase_text(), tr("HUD_BOSS_PHASE") % [2, 3], "and says nothing more")
	var plain := func() -> bool: return int(r.boss_forge()["plate"]["exposed_left"]) == 0
	assert_true(_until(w, r, views, plain, 400))
	_run(w, r, views, 1)
	assert_eq(vuln.shown(), 0, "the vulnerable read ends with the exposed time")


func test_the_ring_is_gold_only_while_the_bomb_is_aimed_inside_the_reach() -> void:
	var s := _only(Vector2(-8, 0), PLATE, ["plate"])
	var r := WorldReader.new(s[0])
	var boss := r.actor_pos(r.boss_index())
	var rr := r.actor_radius(r.boss_index())
	var blast := float(r.boss_forge()["plate"]["blast"])
	assert_eq(
		blast,
		ForgeLab.forge(s[0], s[1]).drone_blast_m,
		"the reader gives the data's blast distance"
	)
	assert_true(Vector2(rr + 1.4, 0).distance_to(boss) <= rr + blast)
	assert_false(Vector2(rr + 1.6, 0).distance_to(boss) <= rr + blast)


func test_pools_darken_as_they_cool_and_slabs_match_the_reader() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["slab"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var slag: ForgeSlagViews = _view(ForgeSlagViews, fx)
	var i := _i(w, s[1])
	assert_true(BossHazard.place(w, i, Vector2(6, 6)))
	_run(w, r, [slag], 120)
	var crusts := slag.crusts()
	assert_eq(crusts.size(), 1, "the pool is cooling")
	var row: Dictionary = r.boss_forge()["slabs"][0]
	assert_almost_eq(crusts[0]["centre"], row["centre"], Vector2(0.001, 0.001), "on the pool")
	assert_almost_eq(float(crusts[0]["radius"]), float(row["radius"]), 0.001, "its radius")
	assert_almost_eq(float(crusts[0]["cool"]), float(row["cooling"]) / 1000.0, 0.001, "its cooling")
	var early := float(crusts[0]["cool"])
	_run(w, r, [slag], 300)
	assert_gt(float(slag.crusts()[0]["cool"]), early, "darker as it cools")
	var cooled := func() -> bool: return not slag.slabs().is_empty()
	assert_true(_until(w, r, [slag], cooled, 400), "it becomes a slab")
	_run(w, r, [slag], 1)
	assert_eq(slag.crusts().size(), 0, "no pool left")
	var slab: Dictionary = slag.slabs()[0]
	row = r.boss_forge()["slabs"][0]
	assert_true(bool(row["slab"]))
	assert_almost_eq(slab["centre"], row["centre"], Vector2(0.001, 0.001), "on its centre")
	assert_almost_eq(float(slab["radius"]), float(row["radius"]), 0.001, "of its radius")
	assert_lt(float(slab["crack"]), 0.05, "whole while it has time")
	assert_eq(float(slab["alpha"]), 1.0)
	var late := func() -> bool: return int(r.boss_forge()["slabs"][0]["left"]) <= 30
	assert_true(_until(w, r, [slag], late, 600))
	assert_gt(float(slag.slabs()[0]["crack"]), 0.9, "cracked near its end")
	assert_lt(float(slag.slabs()[0]["alpha"]), 1.0, "and fading")
	var gone := func() -> bool: return r.boss_forge()["slabs"].is_empty()
	assert_true(_until(w, r, [slag], gone, 60))
	_run(w, r, [slag], 1)
	assert_eq(slag.slabs().size(), 0, "crumbled")
	assert_gt(fx.live_count(&"impact"), 0, "in the pack's dust")


func test_a_shattered_slab_is_not_drawn() -> void:
	var s := _only(Vector2(3, 0), LAST, ["slab"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var slag: ForgeSlagViews = _view(ForgeSlagViews, _pack())
	ForgeLab.slab(w, s[1], Vector2(3, 0))
	_run(w, r, [slag], 2)
	assert_eq(slag.slabs().size(), 1)
	BossLab.start(w, _i(w, s[1]), &"vent_blast")
	var broke := func() -> bool:
		var rows: Array = r.boss_forge()["slabs"]
		return not rows.is_empty() and bool(rows[0]["shattered"])
	assert_true(_until(w, r, [slag], broke, 120), "the vent blast breaks it")
	_run(w, r, [slag], 1)
	assert_eq(slag.slabs().size(), 0, "broken: nothing to stand on")


func test_overpressure_heats_the_floor_around_the_slabs_and_burns_the_edge_off_a_slab() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["over"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var slag: ForgeSlagViews = _view(ForgeSlagViews, fx)
	ForgeLab.slab(w, s[1], Vector2(6, 6), 6000)
	w.boss_fight.fg_over_due = w.tick + 1
	var casting := func() -> bool: return not r.boss_forge()["overpressure"].is_empty()
	assert_true(_until(w, r, [slag], casting, 30), "the cast begins")
	_run(w, r, [slag], 60)
	var over: Dictionary = r.boss_forge()["overpressure"]
	var heat := slag.heat_read()
	assert_false(heat.is_empty(), "the floor heats")
	assert_almost_eq(
		float(heat["level"]),
		ForgeSlagViews.CAST_LEVEL * float(over["cast"]) / 1000.0,
		0.001,
		"with the cast"
	)
	assert_eq(float(heat["burn"]), 0.0, "not burning yet")
	var holes: PackedVector3Array = heat["holes"]
	assert_eq(holes.size(), 1, "the slab is cut out of it")
	assert_almost_eq(holes[0].z, float(r.boss_forge()["slabs"][0]["radius"]), 0.001)
	assert_true(slag.slabs()[0]["safe"], "the safe slab stands out")
	assert_eq(slag.hold.count(), 0, "no pack ring: the plinth's own cool rim reads safe")
	assert_false(ForgeBurnEdge.burning(r), "no edge before the burn")
	var burning := func() -> bool: return int(r.boss_forge()["overpressure"].get("burn", -1)) >= 0
	assert_true(_until(w, r, [slag], burning, 300))
	_run(w, r, [slag], 1)
	assert_eq(float(slag.heat_read()["burn"]), 1.0, "it burns")
	assert_true(ForgeBurnEdge.burning(r), "off a slab: the fire edge")
	var edge := ForgeBurnEdge.new()
	add_child_autofree(edge)
	edge.active = ForgeBurnEdge.burning(r)
	assert_true(edge.visible)
	assert_ne(ForgeBurnEdge.FIRE, HudStyle.warn(), "fire, not the low-HP red")
	w.actors.set_pos(0, Vector2(6, 6))
	_run(w, r, [slag], 1)
	assert_false(ForgeBurnEdge.burning(r), "on the slab: none")
	var ended := func() -> bool: return r.boss_forge()["overpressure"].is_empty()
	assert_true(_until(w, r, [slag], ended, 400))
	_run(w, r, [slag], 40)
	assert_eq(slag.heat_read(), {}, "it fades out")


func test_the_scald_gauge_follows_the_reader_and_is_not_the_overclock_meter() -> void:
	var s := _only(Vector2(-8, 0), PLATE, ["scald"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var hud := ScaldHud.new()
	add_child_autofree(hud)
	var hero: ForgeHeroViews = _view(ForgeHeroViews, fx)
	hud.sync(r)
	hero.sync(r)
	hero.advance()
	assert_eq(r.boss_forge().get("scald", {}), {}, "before its phase")
	assert_false(hud.visible, "hidden before its phase")
	assert_eq(hero.body_read(), &"")
	ForgeLab.set_phase(w, s[1], LAST)
	_run(w, r, [hero], 2)
	hud.sync(r)
	assert_true(hud.visible, "shown in its phase")
	assert_eq(hud.fill(), 0.0)
	assert_eq(hud.state(), &"filling")
	w.boss_fight.fg_scald = 500
	_run(w, r, [hero], 1)
	hud.sync(r)
	assert_almost_eq(hud.fill(), 0.5, 0.001, "the fill follows gauge / max")
	assert_eq(hero.body_read(), &"ember", "an ember glow on the hero")
	var half := hero.ember_size()
	w.boss_fight.fg_scald = 900
	_run(w, r, [hero], 1)
	assert_gt(hero.ember_size(), half, "growing as it fills")
	w.boss_fight.fg_scald = 1000
	w.boss_fight.fg_burning = 1
	_run(w, r, [hero], 1)
	hud.sync(r)
	assert_eq(hud.state(), &"burning", "pulsing red")
	assert_eq(hero.body_read(), &"burning", "flames on the hero")
	var puffs := hero.puffs()
	w.boss_fight.fg_burning = 0
	ForgeLab.slab(w, s[1], r.player_pos(), 6000)
	_run(w, r, [hero], 2)
	hud.sync(r)
	assert_true(bool(r.boss_forge()["scald"]["draining"]))
	assert_eq(hud.state(), &"draining", "the blue tick")
	assert_eq(hero.puffs(), puffs + 1, "a steam puff as it starts draining")
	var mark: Object = hud
	assert_false(mark is HeatMeter, "not the Overclock meter's class")
	for theirs: Color in [HudStyle.A_METAL, HudStyle.A_HEAT, HudStyle.A_WARN, HudStyle.A_INK]:
		for ours: Color in [ScaldHud.ORANGE, ScaldHud.INK, ScaldHud.BURN]:
			var d := Vector3(ours.r - theirs.r, ours.g - theirs.g, ours.b - theirs.b).length()
			assert_gt(d, 0.12, "the scald's %s is not the Overclock meter's %s" % [ours, theirs])
	var hud_main := Hud.new()
	add_child_autofree(hud_main)
	assert_ne(hud_main.scald, null)
	assert_ne(hud_main.scald.get_parent(), hud_main.heat_meter, "not inside the heat meter")
	var main_mark: Object = hud_main.scald
	assert_false(main_mark is HeatMeter)


func test_the_safe_slab_carries_a_hint_arrow_without_text() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["over"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	ForgeLab.slab(w, s[1], Vector2(6, 6), 6000)
	w.boss_fight.fg_over_due = w.tick + 1
	for k in 5:
		w.step(InputFrame.new())
	var hints := ObjectiveHints.new()
	add_child_autofree(hints)
	var centre := hints.get_viewport().get_visible_rect().size * 0.5
	hints.project = func(sim: Vector2) -> Vector2: return centre + sim * 10.0
	hints.gate = func(_reason: StringName) -> bool: return true
	hints.sync(r)
	assert_eq(MechanicHints.FOUNDRY_SLAB, ObjectiveMarkers.FOUNDRY_SLAB)
	assert_true(hints.showing(MechanicHints.FOUNDRY_SLAB), "an arrow at the safe slab")
	assert_false(MechanicHints.FOUNDRY_SLAB in MechanicHints.ALWAYS, "the first two runs only")


func test_nothing_stays_once_the_fight_ends_and_reduced_motion_builds() -> void:
	ViewPrefs.reduced_motion = true
	var s := _only(Vector2(-8, 0), LAST, ["slab", "over", "scald", "plate"])
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var plate: ForgePlateViews = _view(ForgePlateViews, fx)
	var slag: ForgeSlagViews = _view(ForgeSlagViews, fx)
	var hero: ForgeHeroViews = _view(ForgeHeroViews, fx)
	var hud := ScaldHud.new()
	add_child_autofree(hud)
	ForgeLab.slab(w, s[1], Vector2(6, 6), 6000)
	assert_true(BossHazard.place(w, _i(w, s[1]), Vector2(-6, 6)))
	w.boss_fight.fg_scald = 600
	w.boss_fight.fg_over_due = w.tick + 1
	w.boss_fight.fg_plate_due = w.tick
	_run(w, r, [plate, slag, hero], 40)
	hud.sync(r)
	assert_true(hud.visible)
	assert_false(slag.slabs().is_empty())
	assert_false(slag.heat_read().is_empty())
	var i := _i(w, s[1])
	w.actors.dead[i] = 1
	w.actors.hp[i] = 0
	_run(w, r, [plate, slag, hero], 40)
	hud.sync(r)
	assert_eq(r.boss_forge(), {})
	assert_eq(slag.slabs(), [], "no slab")
	assert_eq(slag.crusts(), [], "no crust")
	assert_eq(slag.heat_read(), {}, "no burning floor")
	assert_false(plate.forging_shown())
	assert_eq(hero.body_read(), &"")
	assert_false(hud.visible, "no gauge")
	assert_eq(plate.hold.count() + slag.hold.count() + hero.hold.count(), 0, "no pack effect held")
	assert_true(plate.quiet and slag.quiet, "the views quiet")


func test_the_forge_events_borrow_existing_sounds_and_none_of_the_heats() -> void:
	for effect: StringName in ForgeCues.CUES:
		var e := SimEvent.new()
		e.effect_id = effect
		var out := []
		assert_true(ForgeCues.add(e, out), String(effect))
		var cue: StringName = out[0][0]
		assert_true(ResourceLoader.exists("res://data/audio/cues/%s.tres" % cue), "%s exists" % cue)
		assert_false(String(cue).begins_with("heat_"), "%s is not the Overclock's" % cue)
	var other := SimEvent.new()
	other.effect_id = &"not_a_forge_event"
	assert_false(ForgeCues.add(other, []))


func test_the_forge_effects_are_in_the_pack_table() -> void:
	var fx := _pack()
	for id: StringName in [
		ForgePlateViews.FORGE_ID,
		ForgePlateViews.SPARK_ID,
		ForgePlateViews.SHARDS_ID,
		ForgePlateViews.REACH_ID,
		ForgePlateViews.REACH_ON_ID,
		ForgePlateViews.BOMB_ID,
		ForgeSlagViews.DROP_ID,
		ForgeSlagViews.SPLASH_ID,
		ForgeSlagViews.DUST_ID,
		ForgeHeroViews.EMBER_ID,
		ForgeHeroViews.FLAME_ID,
		ForgeHeroViews.STEAM_ID,
	]:
		assert_true(fx.has_id(id), String(id))
