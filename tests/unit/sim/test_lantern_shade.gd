# gdlint: disable=max-public-methods
extends GutTest
## v0.9.0 NB4 (owner Q24 "ok go for those"; docs/roadmap/v0.9.0/BOSSES_4_5.md row N4; PLAN NB "Keep the empty hood"):
## The Lantern Shade, floor 5's second boss. Lights out (shielded, every 12 s): 4 s after it starts the room goes dark;
## only 3.5 m round you and the four lanterns on the room's edge (lit afresh, 6 s each, 3 m wide) stay lit; passing a
## lantern relights it for 6 s; the Shade is only hittable when lit. Wisp Bloom: a slow flower of wisps. Snuff: a
## tracked circle that, on strike, puts out the nearest lantern. Markers always draw. Phases at 66 % and 33 %,
## determinism, a mid-dark save, an older save, the death lines.

const LONG := 1 << 20
## The test world has no sealed room: the lanterns stand round where the Shade rose (BossShade.FALLBACK_HALF_M 7 m,
## inset 1.5 m): north, east, south, west of the origin.
const LAMPS := [Vector2(0, -5.5), Vector2(5.5, 0), Vector2(0, 5.5), Vector2(-5.5, 0)]


func _fight(player_at: Vector2, boss_at := Vector2.ZERO) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"lantern_shade", boss_at)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


## The boss picks nothing on its own (no phase list, no cadence, no punish): only what a test starts.
func _hush(w: World, aid: int) -> void:
	var t := BossAi.table_of(w, _i(w, aid))
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.sig_every_ticks = 0
	t.speed = 0.0


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


## Steps n ticks keeping the player at p (full HP, the boss never kills them).
func _hold(w: World, p: Vector2, n: int) -> void:
	for k in n:
		w.actors.set_pos(0, p)
		w.actors.hp[0] = LONG
		w.actors.invuln[0] = 0
		w.step(InputFrame.new())


## A hush, then Lights Out run to its dark with the player at p (started between ticks, the dark falls in the 241st
## step: 240 ticks after the tick it started on).
func _dark(p: Vector2) -> Array:
	var s := _fight(p)
	var w: World = s[0]
	_hush(w, s[1])
	_hold(w, p, 2)
	BossLab.start(w, _i(w, s[1]), &"lights_out")
	_hold(w, p, 241)
	return s


func _hit(w: World, target_id: int, amount: int) -> int:
	var me := w.actors.ids[0]
	var i := _i(w, target_id)
	return Damage.hit(
		w, i, amount, me, me, w.take_root(), 0, w.actors.pos(i) + Vector2(-1, 0), w.actors.pos(i)
	)


func test_the_data_is_the_approved_row() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"lantern_shade")
	assert_not_null(def)
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	assert_eq(t.kind, ActorStore.Kind.LANTERN_SHADE)
	assert_eq(t.phase_threshold, PackedInt32Array([1000, 660, 330]), "phases at 66 % and 33 %")
	assert_eq(t.sig_every_ticks, 720, "Lights Out every 12 s")
	assert_eq(t.lamp_count, 4, "four lanterns on the room's edge")
	assert_almost_eq(t.light_m, 3.5, 0.0001, "your light 3.5 m")
	assert_eq(t.lamp_ticks, 360, "a lantern burns 6 s")
	assert_almost_eq(t.lamp_m, 3.0, 0.0001, "a lantern lights 3 m round it")
	assert_eq(t.dark_hold_ticks, 480, "NB4b: each dark lasts 8 s")
	var lo := t.attacks[t.attack_index(&"lights_out")]
	assert_true(lo.shielded, "shielded during the signature")
	assert_eq(lo.dark_ticks, 240, "dark 4 s after the signature starts")
	assert_eq(lo.windup_ticks + lo.active_ticks, 240, "the shield drops as the dark falls")
	for p in 3:
		var sig := BossTide.signature_of(t, p)
		assert_gt(t.attacks[sig].dark_ticks, 0, "Lights Out is phase %d's signature" % p)
	var bloom := t.attacks[t.attack_index(&"wisp_bloom")]
	assert_eq(bloom.pattern.kind, BulletPatternTable.Kind.FLOWER, "Wisp Bloom: a flower")
	assert_eq(bloom.pattern.look, &"shade_wisp", "of wisps")
	assert_false(BossTide.on_cadence(t, bloom), "the pick may choose it")
	var snuff := t.attacks[t.attack_index(&"snuff")]
	assert_eq(snuff.move, BossAttackTable.Move.MARKS, "Snuff: a tracked circle")
	assert_true(snuff.snuff, "that puts out a lantern")
	assert_eq(snuff.lock_ticks, 48, "tracked, then locked 0.8 s")
	var pool := ContentCompiler.compile_boss_pool(repo, 5)
	var ids := BossLab.tables().map(func(x: BossTable) -> StringName: return x.id)
	var names := []
	for k in pool:
		names.append(ids[k])
	assert_eq(names, [&"clockwork_judge", &"lantern_shade"], "floor 5 draws the Judge or the Shade")


func _codes_with(change: Callable) -> Array:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = (
		(repo.get_def(&"bosses", &"lantern_shade") as BossDefinition).duplicate(true)
	)
	change.call(def)
	return def.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_bad_light_numbers_are_errors() -> void:
	var unshielded := func(d: BossDefinition) -> void: d.attack(&"lights_out").shielded = false
	assert_has(_codes_with(unshielded), &"missing", "Lights Out is shielded")
	var no_dark := func(d: BossDefinition) -> void:
		d.attack(&"lights_out").shape_params["dark_seconds"] = 0.0
	assert_has(_codes_with(no_dark), &"not_positive", "a real time to the dark")
	var lamps := func(d: BossDefinition) -> void: d.attack(&"lights_out").shape_params["lamps"] = 9
	assert_has(_codes_with(lamps), &"range", "at most 8 lanterns")
	var no_light := func(d: BossDefinition) -> void:
		d.attack(&"lights_out").shape_params["light_m"] = 0.0
	assert_has(_codes_with(no_light), &"not_positive", "a real light round you")
	var bad_snuff := func(d: BossDefinition) -> void: d.attack(&"snuff").shape_params["snuff"] = 2
	assert_has(_codes_with(bad_snuff), &"range", "snuff is 0 or 1")
	var short := func(d: BossDefinition) -> void: d.signature_every_seconds = 4.5
	assert_has(_codes_with(short), &"duration", "the cadence outlasts the windup and the dark")
	var endless := func(d: BossDefinition) -> void:
		d.attack(&"lights_out").shape_params["dark_lasts_seconds"] = 12.0
	assert_has(_codes_with(endless), &"duration", "NB4b: the dark lifts before the next Lights Out")
	assert_eq(_codes_with(endless).size(), 1, "only that")
	var no_stretch := func(d: BossDefinition) -> void:
		d.attack(&"lights_out").shape_params["dark_lasts_seconds"] = 0.0
	assert_has(_codes_with(no_stretch), &"not_positive", "a real stretch of dark")
	var missing := func(d: BossDefinition) -> void:
		d.attack(&"lights_out").shape_params.erase("dark_lasts_seconds")
	assert_has(_codes_with(missing), &"missing", "a Lights Out names how long its dark lasts")


func test_four_lanterns_stand_on_the_edge_and_the_room_starts_lit() -> void:
	var s := _fight(Vector2(-3, 0))
	var w: World = s[0]
	_hush(w, s[1])
	_hold(w, Vector2(-3, 0), 2)
	assert_eq(w.bosses.shade_boss, s[1], "the Shade owns the room's light")
	assert_eq(w.bosses.lamp_x.size(), 4)
	for k in 4:
		var at := Vector2(w.bosses.lamp_x[k], w.bosses.lamp_y[k])
		assert_almost_eq(
			at.distance_to(LAMPS[k]), 0.0, 0.001, "lantern %d at the wall's middle" % k
		)
		assert_eq(w.bosses.lamp_t[k], 360, "lit")
	assert_false(BossShade.dark(w), "the room is lit before the first Lights Out")
	assert_true(BossShade.lit(w, Vector2(30, 30)), "everywhere")
	assert_false(BossShade.unlit(w, _i(w, s[1])), "the Shade is hittable")


func test_lights_out_is_shielded_and_the_dark_falls_4_s_after_it_starts() -> void:
	var s := _fight(Vector2(-3, 0))
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	_hold(w, Vector2(-3, 0), 2)
	BossLab.start(w, _i(w, aid), &"lights_out")
	var started := w.tick
	assert_true(BossDodge.shielded(w, _i(w, aid)), "shielded while the light drains")
	_hold(w, Vector2(-3, 0), 239)
	assert_false(BossShade.dark(w), "not yet dark")
	assert_true(BossDodge.shielded(w, _i(w, aid)), "still shielded")
	_hold(w, Vector2(-3, 0), 2)
	assert_true(BossShade.dark(w), "dark 4 s (240 ticks) after it started")
	assert_eq(w.bosses.shade_at, -1)
	assert_eq(w.bosses.shade_from, started)
	assert_false(BossDodge.shielded(w, _i(w, aid)), "the shield is down as the dark falls")
	for k in 4:
		assert_gt(w.bosses.lamp_t[k], 355, "every lantern lit afresh as the dark falls")


func test_in_the_dark_only_your_circle_and_the_lit_lanterns_are_lit() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	var me := Vector2(-1.5, -1.5)
	assert_true(BossShade.lit(w, me + Vector2(3.4, 0)), "3.4 m from you: lit")
	assert_false(BossShade.lit(w, me + Vector2(3.6, 0)), "3.6 m from you (no lantern near): dark")
	assert_true(BossShade.lit(w, LAMPS[0] + Vector2(2.9, 0)), "2.9 m from a lit lantern: lit")
	assert_false(BossShade.lit(w, Vector2(5.5, 5.5)), "a corner between lanterns: dark")
	var lt := w.bosses.lamp_t
	lt[0] = 0
	w.bosses.lamp_t = lt
	assert_false(BossShade.lit(w, LAMPS[0] + Vector2(1.0, 0)), "an out lantern lights nothing")
	var st := BossShade.state(w)
	assert_true(st["dark"])
	assert_eq(st["lamps"].size(), 4)
	assert_false(st["lamps"][0]["lit"], "the reader says it is out")


func test_a_lantern_burns_6_s_and_passing_it_relights_it() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	_hold(w, Vector2(-1.5, -1.5), 359)
	assert_eq(w.bosses.lamp_t[0], 1, "still alight a tick before 6 s")
	_hold(w, Vector2(-1.5, -1.5), 1)
	for k in 4:
		assert_eq(w.bosses.lamp_t[k], 0, "lantern %d burnt out 6 s after the dark fell" % k)
	_hold(w, LAMPS[1] + Vector2(-1.0, 0), 1)
	assert_eq(w.bosses.lamp_t[1], 360, "passing within reach relights it for 6 s")
	assert_eq(w.bosses.lamp_t[0], 0, "the others stay out")
	_hold(w, Vector2(-1.5, -1.5), 60)
	assert_eq(w.bosses.lamp_t[1], 300, "it burns down again once you leave")
	assert_true(BossShade.lit(w, LAMPS[1] + Vector2(-2.5, 0)), "widening the lit area")


func test_the_shade_is_only_hittable_when_lit() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	var aid: int = s[1]
	var i := _i(w, aid)
	w.actors.set_pos(i, Vector2(5.5, 5.5))  # a corner between lanterns, far from you
	var lt := w.bosses.lamp_t
	lt.fill(0)
	w.bosses.lamp_t = lt
	var hp := w.actors.hp[i]
	assert_true(BossShade.unlit(w, i), "in the dark")
	var seq := w.last_event_seq()
	assert_eq(_hit(w, aid, 50), 0, "a hit sparks off it in the dark")
	assert_eq(w.actors.hp[i], hp)
	var hits := w.events_since(seq).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.HIT and e.target_id == aid
	)
	assert_eq(hits.size(), 1, "the hit still shows")
	assert_ne(hits[0].tags & SimEvent.TAG_BLOCKED, 0, "blocked: it sparks off")
	assert_true(WorldReader.new(w).boss_invulnerable(i), "the bar says so")
	w.actors.set_pos(i, Vector2(-1.5, -1.5) + Vector2(4.4, 0))  # its body inside your 3.5 m light
	assert_false(BossShade.unlit(w, i))
	assert_gt(_hit(w, aid, 50), 0, "lit by your light: hit")
	w.actors.set_pos(i, LAMPS[1] + Vector2(-2.0, 0))
	assert_true(BossShade.unlit(w, i), "by an out lantern: dark")
	lt = w.bosses.lamp_t
	lt[1] = 200
	w.bosses.lamp_t = lt
	assert_false(BossShade.unlit(w, i), "the lantern relit")
	assert_gt(_hit(w, aid, 50), 0, "lit by a lantern: hit")


## NB4b (owner, PLAN "Owner decisions" NB4: "Dark comes and goes"): the dark lasts 8 s, then the room is lit (the Shade
## hittable anywhere, the lanterns unburnt, a Snuff putting none out) until the next Lights Out's dark relights them.
func test_the_dark_lasts_8_s_then_the_light_comes_back_until_the_next_lights_out() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	var aid: int = s[1]
	assert_eq(int(BossShade.state(w)["dark_left"]), w.bosses.shade_until - w.tick)
	assert_between(
		int(BossShade.state(w)["dark_left"]), 478, 480, "the reader counts the dark down"
	)
	var n := 0
	while BossShade.dark(w) and n < 1000:
		_hold(w, Vector2(-1.5, -1.5), 1)
		n += 1
	assert_eq(n, 480, "the dark lifts 8 s after it fell")
	assert_eq(w.bosses.shade_until, -1)
	assert_eq(int(BossShade.state(w)["dark_left"]), -1)
	assert_false(bool(BossShade.state(w)["dark"]), "the reader says the room is lit")
	assert_true(BossShade.lit(w, Vector2(5.5, 5.5)), "a corner between lanterns: lit again")
	var i := _i(w, aid)
	w.actors.set_pos(i, Vector2(5.5, 5.5))
	var lt := w.bosses.lamp_t
	lt.fill(0)
	lt[2] = 100
	w.bosses.lamp_t = lt
	assert_false(BossShade.unlit(w, i), "in the light the Shade is hittable anywhere")
	assert_gt(_hit(w, aid, 50), 0, "hit far from any light")
	_hold(w, Vector2(-1.5, -1.5), 60)
	assert_eq(w.bosses.lamp_t[2], 100, "a lantern does not burn while the room is lit")
	var t := BossAi.table_of(w, i)
	BossShade.snuff(w, t.attacks[t.attack_index(&"snuff")], LAMPS[2])
	assert_eq(w.bosses.lamp_t[2], 100, "nor does a Snuff put it out")
	BossLab.start(w, i, &"lights_out")
	_hold(w, Vector2(-1.5, -1.5), 240)
	assert_false(BossShade.dark(w), "the next Lights Out drains the light again")
	_hold(w, Vector2(-1.5, -1.5), 1)
	assert_true(BossShade.dark(w), "and its dark falls 4 s after it starts")
	for k in 4:
		assert_eq(w.bosses.lamp_t[k], 360, "every lantern relit as the dark falls")
	w.actors.set_pos(_i(w, aid), Vector2(5.5, 5.5))
	assert_true(BossShade.unlit(w, _i(w, aid)), "and again hittable only in light")


func test_a_mid_dark_lights_out_starts_a_fresh_stretch() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	_hold(w, Vector2(-1.5, -1.5), 200)
	BossLab.start(w, _i(w, s[1]), &"lights_out")  # a phase's entry Lights Out, say, while it is dark
	_hold(w, Vector2(-1.5, -1.5), 241)
	assert_true(BossShade.dark(w))
	assert_between(int(BossShade.state(w)["dark_left"]), 478, 480, "its dark lasts its own 8 s")


func test_snuff_puts_out_the_lantern_nearest_its_strike() -> void:
	var p := LAMPS[1] + Vector2(-1.5, 0.5)
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	var aid: int = s[1]
	_hold(w, p, 1)
	BossLab.start(w, _i(w, aid), &"snuff")
	var tel := BossAi.telegraph(w, _i(w, aid))
	assert_false(tel.is_empty(), "the Snuff's marker draws in the dark")
	_hold(w, p, 96)
	var out := []
	for k in 4:
		out.append(w.bosses.lamp_t[k] == 0)
	assert_eq(out, [false, true, false, false], "the east lantern (nearest the circle) went out")


func test_markers_draw_in_the_dark() -> void:
	# The dark is the view's: the sim's telegraph is the same lit or dark (the view draws markers over the dark).
	var lit := _fight(Vector2(3, 3))
	var w0: World = lit[0]
	_hush(w0, lit[1])
	_hold(w0, Vector2(3, 3), 1)
	BossLab.start(w0, _i(w0, lit[1]), &"snuff")
	var a := BossAi.telegraph(w0, _i(w0, lit[1]))
	var dk := _dark(Vector2(3, 3))
	var w1: World = dk[0]
	BossLab.start(w1, _i(w1, dk[1]), &"snuff")
	var b := BossAi.telegraph(w1, _i(w1, dk[1]))
	assert_eq(b.get("shape"), a.get("shape"), "the same marker")
	assert_eq(b.get("ground", true), a.get("ground", true), "on the ground in the dark too")


func test_lights_out_comes_every_12_s_never_by_the_pick() -> void:
	var s := _fight(Vector2(-6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var t := BossAi.table_of(w, _i(w, aid))
	t.punish_ticks = 0
	var starts := PackedInt32Array()
	var was := false
	var fell := -1
	var stretches := PackedInt32Array()
	for k in 60 * 40:
		var a := TAU * float(k) / 300.0
		w.actors.set_pos(0, Vector2(cos(a), sin(a)) * 6.0)
		w.actors.hp[0] = LONG
		w.step(InputFrame.new())
		var atk := BossAi.attack_of(w, _i(w, aid))
		var now := atk != null and atk.dark_ticks > 0
		if now and not was:
			starts.append(w.tick)
		was = now
		if BossShade.dark(w) and fell < 0:
			fell = w.tick
		elif not BossShade.dark(w) and fell >= 0:
			stretches.append(w.tick - fell)
			fell = -1
	assert_gte(starts.size(), 3, "three Lights Outs in 40 s")
	assert_between(starts[0], 170, 420, "the first about 3 s in")
	for k in range(1, starts.size()):
		assert_between(starts[k] - starts[k - 1], 720, 980, "every 12 s, start to start")
	# NB4b (owner: "Dark comes and goes"): each dark lasts 8 s, then the light comes back until the next one.
	assert_gte(stretches.size(), 2, "the dark came and went at least twice")
	for n in stretches:
		# (counted on w.tick: a hit's freeze, which holds the world's phases, can add a few ticks)
		assert_between(n, 480, 492, "each dark lasts 8 s")


func test_the_phases_open_with_lights_out() -> void:
	var s := _fight(Vector2(-6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var i := _i(w, aid)
	w.actors.hp[i] = w.actors.max_hp[i] * 650 / 1000
	w.step(InputFrame.new())
	BossLab.through_gate(w, aid)
	assert_eq(w.bosses.phase[BossAi.entry_of(w, _i(w, aid))], 1)
	assert_eq(BossAi.attack_of(w, _i(w, aid)).id, &"lights_out", "phase 2 opens with Lights Out")
	w.actors.hp[_i(w, aid)] = w.actors.max_hp[_i(w, aid)] * 320 / 1000
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[_i(x, aid)] == BossAi.GATE, 900
	)
	BossLab.through_gate(w, aid)
	assert_eq(w.bosses.phase[BossAi.entry_of(w, _i(w, aid))], 2)
	assert_eq(BossAi.attack_of(w, _i(w, aid)).id, &"lights_out_3", "phase 3 too")


func test_deterministic_and_a_mid_dark_save_restores() -> void:
	var make := func() -> World:
		var s: Array = _dark(Vector2(-1.5, -1.5))
		var w: World = s[0]
		_hold(w, LAMPS[3] + Vector2(1, 0), 30)  # relight the west lantern
		return w
	var a: World = make.call()
	var b: World = make.call()
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree in the dark")
	assert_true(BossShade.dark(a))
	var before := a.state_hash()
	var lt := a.bosses.lamp_t
	lt[0] += 1
	a.bosses.lamp_t = lt
	assert_ne(a.state_hash(), before, "the lanterns are in the hash")
	lt[0] -= 1
	a.bosses.lamp_t = lt
	a.bosses.shade_dark = 0
	assert_ne(a.state_hash(), before, "the dark too")
	a.bosses.shade_dark = 1
	a.bosses.shade_until += 1
	assert_ne(a.state_hash(), before, "when it lifts too")
	a.bosses.shade_until -= 1
	var snap := WorldSnapshot.take(a)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), make.call())
	assert_not_null(restored, "restores")
	if restored == null:
		return
	assert_eq(restored.state_hash(), a.state_hash(), "same hash restored")
	assert_true(BossShade.dark(restored), "still dark")
	for k in 300:
		var f := (
			InputFrame.make(Vector2i(60, 40), 0, 300, 0, 0) if k % 90 < 45 else InputFrame.new()
		)
		a.step(f)
		restored.step(f)
	assert_eq(restored.state_hash(), a.state_hash(), "same hash 300 ticks on")


func test_an_older_snapshot_without_the_light_loads() -> void:
	var s := _fight(Vector2(-6, 2))
	var w: World = s[0]
	CombatLab.idle(w, 60)
	var snap := WorldSnapshot.take(w)
	var bosses: Dictionary = snap["world"][&"bosses"]
	assert_true(bosses.has(&"lamp_t"), "the light is saved")
	for f: StringName in [
		&"shade_boss",
		&"shade_dark",
		&"shade_at",
		&"shade_from",
		&"shade_until",
		&"lamp_x",
		&"lamp_y",
		&"lamp_t"
	]:
		bosses.erase(f)
	var base := BossLab.world()
	BossLab.ready_boss(base, &"lantern_shade")
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save from before NB4 loads")
	assert_eq(base.bosses.shade_boss, -1, "with no light yet")
	CombatLab.idle(base, 2)
	assert_gte(base.bosses.shade_boss, 0, "the Shade takes the room's light again")
	assert_eq(base.bosses.lamp_x.size(), 4)


func test_a_world_without_a_shade_has_no_light_state() -> void:
	var w := BossLab.world()
	BossLab.ready_boss(w, &"clockwork_judge")
	CombatLab.idle(w, 40)
	assert_eq(w.bosses.shade_boss, -1, "no Shade, no light state")
	assert_true(w.bosses.lamp_t.is_empty())
	assert_true(BossShade.state(w).is_empty())


func test_the_room_relights_when_the_shade_goes() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	assert_true(BossShade.dark(w))
	BossSignatures.on_boss_gone(w, s[1])
	assert_eq(w.bosses.shade_boss, -1)
	assert_false(BossShade.dark(w), "the room relights")
	assert_true(BossShade.lit(w, Vector2(40, 40)))


func test_the_death_lines_name_the_dark() -> void:
	var s := _fight(Vector2(-6, 0))
	var w: World = s[0]
	var t := BossAi.table_of(w, _i(w, s[1]))
	w.killer_kind = ActorStore.Kind.LANTERN_SHADE
	w.killer_attack = t.attack_index(&"lights_out")
	assert_eq(BossAi.cause_key(w), &"CAUSE_SHADE_DARK")
	var en := TranslationServer.get_translation_object("en")
	assert_eq(
		String(en.get_message(&"CAUSE_SHADE_DARK")), "The Lantern Shade found you in the dark."
	)
	var es := TranslationServer.get_translation_object("es")
	assert_ne(String(es.get_message(&"CAUSE_SHADE_DARK")), "", "in Spanish too")
	w.killer_attack = t.attack_index(&"wisp_bloom_2")
	assert_eq(BossAi.cause_key(w), &"CAUSE_SHADE_BLOOM")
	w.killer_attack = t.attack_index(&"snuff_3")
	assert_eq(BossAi.cause_key(w), &"CAUSE_SHADE_SNUFF")
	w.killer_attack = t.attack_index(&"lantern_sweep")
	assert_eq(BossAi.cause_key(w), &"CAUSE_SHADE_SWEEP")
