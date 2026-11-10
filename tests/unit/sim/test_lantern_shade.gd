# gdlint: disable=max-public-methods
extends GutTest
## v0.9.0 NB4 (owner Q24 "ok go for those"; docs/roadmap/v0.9.0/BOSSES_4_5.md row N4; PLAN NB "Keep the empty hood"):
## The Lantern Shade, floor 5's second boss. Lights out (every 12 s; v0.11.0 O4b: shielded only through its 1 s
## telegraph): 4 s after the first
## starts the room goes dark; only 3.5 m round you and the lit lanterns on the room's edge (3 m wide) stay lit.
## v0.11.0 O4 (owner Q10 a: "40 % damage in the dark, 150 % inside a lit pool; a lantern stays lit 6 s; dark 9 s /
## light 4 s"): the lanterns start out and stepping on one lights it 6 s; dark 9 s and light 4 s alternate; the Shade
## takes 40 % in the dark, 100 % in your light or the full light, 150 % in a lit pool, never 0; the hint points at the
## unlit lanterns in the dark. Wisp Bloom: a slow flower of wisps. Snuff: a tracked circle that, on strike, puts out
## the nearest lanterns. Markers always draw. Phases at 66 % and 33 %, determinism, a mid-dark save, an older save, the
## death lines. The two scripted bots: test_lantern_shade_bots.gd.

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
	assert_eq(t.lamp_ticks, 360, "v0.11.0 O4 (owner Q10 a): a lantern stays lit 6 s")
	assert_almost_eq(t.lamp_m, 3.0, 0.0001, "a lantern lights 3 m round it")
	assert_eq(t.dark_hold_ticks, 540, "O4: dark 9 s")
	assert_eq(t.light_hold_ticks, 240, "O4: then light 4 s")
	assert_eq(t.dark_mult_permille, 400, "O4: 40 % damage in the dark")
	assert_eq(t.lit_mult_permille, 1500, "O4: 150 % inside a lit pool")
	var lo := t.attacks[t.attack_index(&"lights_out")]
	assert_true(lo.shielded, "v0.11.0 O4b (owner: Bring it back): shielded through its telegraph")
	assert_eq(lo.shield_active_ticks, 0, "O4b: and only the telegraph (1 s)")
	assert_eq(lo.windup_ticks, 60, "the telegraph is 1 s")
	assert_eq(lo.dark_ticks, 240, "dark 4 s after the first signature starts")
	assert_eq(lo.windup_ticks + lo.active_ticks, 240, "the wisps play out until the dark falls")
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


func _param_codes(key: String, value: Variant) -> Array:
	return _codes_with(
		func(d: BossDefinition) -> void: d.attack(&"lights_out").shape_params[key] = value
	)


func test_bad_light_numbers_are_errors() -> void:
	var unshielded := func(d: BossDefinition) -> void: d.attack(&"lights_out").shielded = false
	assert_has(_codes_with(unshielded), &"missing", "O4b: Lights Out is shielded (its telegraph)")
	assert_has(_param_codes("dark_seconds", 0.0), &"not_positive", "a real time to the dark")
	assert_has(_param_codes("lamps", 9), &"range", "at most 8 lanterns")
	assert_has(_param_codes("light_m", 0.0), &"not_positive", "a real light round you")
	var bad_snuff := func(d: BossDefinition) -> void: d.attack(&"snuff").shape_params["snuff"] = 3
	assert_has(_codes_with(bad_snuff), &"range", "snuff is 0 to 2")
	var short := func(d: BossDefinition) -> void: d.signature_every_seconds = 4.5
	assert_has(_codes_with(short), &"duration", "the cadence outlasts the windup and the dark")
	var endless := _param_codes("dark_lasts_seconds", 12.0)
	assert_has(endless, &"duration", "NB4b: the dark lifts before the next Lights Out")
	assert_eq(endless.size(), 1, "only that")
	assert_has(_param_codes("dark_lasts_seconds", 0.0), &"not_positive", "a real stretch of dark")
	var missing := func(d: BossDefinition) -> void:
		d.attack(&"lights_out").shape_params.erase("dark_lasts_seconds")
	assert_has(_codes_with(missing), &"missing", "a Lights Out names how long its dark lasts")
	assert_has(_param_codes("light_lasts_seconds", 0.0), &"not_positive", "O4: a real light")
	assert_has(_param_codes("dark_mult_permille", 0), &"range", "O4: never immune in the dark")
	assert_has(_param_codes("dark_mult_permille", 1000), &"range", "O4: the dark cuts the damage")
	assert_has(_param_codes("lit_mult_permille", 900), &"range", "O4: a lit pool never cuts it")
	var no_cut := func(d: BossDefinition) -> void:
		d.attack(&"lights_out").shape_params.erase("dark_mult_permille")
	assert_has(_codes_with(no_cut), &"missing", "O4: a Lights Out names its cut")


func test_four_lanterns_stand_on_the_edge_out_and_the_room_starts_lit() -> void:
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
		assert_eq(w.bosses.lamp_t[k], 0, "O4: out until the player lights it")
	assert_false(BossShade.dark(w), "the room is lit before the first Lights Out")
	assert_true(BossShade.lit(w, Vector2(30, 30)), "everywhere")
	assert_eq(BossShade.light_permille(w, _i(w, s[1])), 1000, "the Shade takes full damage")
	assert_eq(w.objectives.size(), 0, "no hint in the light")


func test_lights_out_is_shielded_through_its_telegraph_and_the_dark_falls_4_s_after_it_starts(
) -> void:
	var s := _fight(Vector2(-3, 0))
	var w: World = s[0]
	var aid: int = s[1]
	_hush(w, aid)
	_hold(w, Vector2(-3, 0), 2)
	BossLab.start(w, _i(w, aid), &"lights_out")
	var started := w.tick
	var shield_ticks := 0
	for k in 239:
		var sh := BossDodge.shielded(w, _i(w, aid))
		if sh:
			shield_ticks += 1
			assert_eq(w.actors.state[_i(w, aid)], EnemyAi.State.WINDUP, "O4b: only the telegraph")
		_hold(w, Vector2(-3, 0), 1)
	assert_gte(shield_ticks, 59, "O4b: shielded through the 1 s telegraph")
	assert_lte(shield_ticks, 60, "O4b: and no longer (the wisps fly open)")
	gut.p("O4b shield ticks: %d (%.2f s)" % [shield_ticks, shield_ticks / 60.0])
	assert_false(BossShade.dark(w), "not yet dark")
	_hold(w, Vector2(-3, 0), 2)
	assert_true(BossShade.dark(w), "dark 4 s (240 ticks) after it started")
	assert_eq(w.bosses.shade_at, -1)
	assert_eq(w.bosses.shade_from, started)
	for k in 4:
		assert_eq(w.bosses.lamp_t[k], 0, "O4: the lanterns stay out as the dark falls")


func test_in_the_dark_only_your_circle_and_the_lit_lanterns_are_lit() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	var me := Vector2(-1.5, -1.5)
	var lt := w.bosses.lamp_t
	lt[0] = 200
	w.bosses.lamp_t = lt
	assert_true(BossShade.lit(w, me + Vector2(3.4, 0)), "3.4 m from you: lit")
	assert_false(BossShade.lit(w, me + Vector2(3.6, 0)), "3.6 m from you (no lantern near): dark")
	assert_true(BossShade.lit(w, LAMPS[0] + Vector2(2.9, 0)), "2.9 m from a lit lantern: lit")
	assert_true(BossShade.in_pool(w, LAMPS[0] + Vector2(2.9, 0)), "in its pool")
	assert_false(BossShade.in_pool(w, me), "your own light is no pool")
	assert_false(BossShade.lit(w, Vector2(5.5, 5.5)), "a corner between lanterns: dark")
	lt[0] = 0
	w.bosses.lamp_t = lt
	assert_false(BossShade.lit(w, LAMPS[0] + Vector2(1.0, 0)), "an out lantern lights nothing")
	var st := BossShade.state(w)
	assert_true(st["dark"])
	assert_eq(st["lamps"].size(), 4)
	assert_false(st["lamps"][0]["lit"], "the reader says it is out")


## O4 (owner Q10 a: "a lantern stays lit 6 s"): stepping on a lantern lights it for 6 s, dark or light.
func test_a_lantern_stepped_on_stays_lit_6_s() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	_hold(w, LAMPS[1] + Vector2(-1.0, 0), 1)
	assert_eq(w.bosses.lamp_t[1], 360, "stepping within reach lights it for 6 s")
	assert_eq(w.bosses.lamp_t[0], 0, "the others stay out")
	_hold(w, Vector2(-1.5, -1.5), 359)
	assert_eq(w.bosses.lamp_t[1], 1, "still alight a tick before 6 s")
	_hold(w, Vector2(-1.5, -1.5), 1)
	assert_eq(w.bosses.lamp_t[1], 0, "out 6 s after you left it")
	var f := _fight(Vector2(-3, 0))
	var lw: World = f[0]
	_hush(lw, f[1])
	_hold(lw, LAMPS[3] + Vector2(1.0, 0), 1)
	assert_false(BossShade.dark(lw))
	assert_eq(lw.bosses.lamp_t[3], 360, "in the light too")
	_hold(lw, Vector2(-1.5, -1.5), 60)
	assert_eq(lw.bosses.lamp_t[3], 300, "and it burns down in the light")


func _hit_tags(w: World, aid: int, amount: int) -> Array:
	var seq := w.last_event_seq()
	var got := _hit(w, aid, amount)
	var ds := w.events_since(seq).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.DAMAGE and e.target_id == aid
	)
	return [got, ds[0].tags if not ds.is_empty() else 0]


## O4 (owner Q10 a: "40 % damage in the dark, 150 % inside a lit pool"): no immunity; the hero's own light is 100 %.
## The player stands 6 m off (outside their 3.5 m light, inside the ranged armour's full 5 m) unless said.
func test_the_shade_takes_40_in_the_dark_100_in_your_light_150_in_a_lit_pool() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	var aid: int = s[1]
	var i := _i(w, aid)
	var lt := w.bosses.lamp_t
	lt.fill(0)
	w.bosses.lamp_t = lt
	var corner := Vector2(5.5, 5.5)  # between lanterns
	w.actors.set_pos(i, corner)
	w.actors.set_pos(0, corner + Vector2(-6.0, 0))
	assert_eq(BossShade.light_permille(w, i), 400, "in the dark: 40 %")
	var hp := w.actors.hp[i]
	var dk := _hit_tags(w, aid, 100)
	assert_between(
		int(dk[0]), 40, 160, "a hit lands in the dark (cut to 40 %; a crit may raise it)"
	)
	assert_eq(w.actors.hp[i], hp - int(dk[0]))
	assert_ne(int(dk[1]) & SimEvent.TAG_SHADE_DARK, 0, "tagged: in the dark")
	assert_eq(int(dk[1]) & SimEvent.TAG_BLOCKED, 0, "never blocked")
	assert_false(WorldReader.new(w).boss_invulnerable(i), "the bar never says Invulnerable")
	assert_eq(WorldReader.new(w).boss_light_permille(i), 400, "the bar reads 40 %")
	w.actors.set_pos(0, corner + Vector2(-4.4, 0))  # its body inside your 3.5 m light
	assert_eq(BossShade.light_permille(w, i), 1000, "in your light: 100 %")
	var mine := int(_hit_tags(w, aid, 100)[1])
	assert_eq(mine & (SimEvent.TAG_SHADE_DARK | SimEvent.TAG_SHADE_LIT), 0, "no light tag at 100 %")
	w.actors.set_pos(i, LAMPS[1] + Vector2(-2.0, 0))
	w.actors.set_pos(0, LAMPS[1] + Vector2(-8.0, 0))
	assert_eq(BossShade.light_permille(w, i), 400, "by an out lantern: dark")
	lt = w.bosses.lamp_t
	lt[1] = 200
	w.bosses.lamp_t = lt
	assert_eq(BossShade.light_permille(w, i), 1500, "the lantern lit: 150 %")
	var lit := _hit_tags(w, aid, 100)
	assert_gte(int(lit[0]), 150, "a hit in the pool: 150 %")
	assert_ne(int(lit[1]) & SimEvent.TAG_SHADE_LIT, 0, "tagged: in the light")
	w.actors.set_pos(0, LAMPS[1] + Vector2(-3.0, 0))
	assert_eq(BossShade.light_permille(w, i), 1500, "a pool beats your own light")
	assert_eq(BossShade.light_permille(w, 0), 1000, "only the Shade is scaled")


## O4: Damage.tick_dot takes the same cut and bonus (a burn ticking in the dark still lands).
func test_damage_over_time_takes_the_light_too() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	var aid: int = s[1]
	var i := _i(w, aid)
	w.actors.set_pos(i, Vector2(5.5, 5.5))
	w.actors.set_pos(0, Vector2(-0.5, 5.5))
	var me := w.actors.ids[0]
	assert_eq(Damage.tick_dot(w, i, 100, me, me, &"burn"), 40, "a tick in the dark: 40 %")
	var lt := w.bosses.lamp_t
	lt[1] = 100
	w.bosses.lamp_t = lt
	w.actors.set_pos(i, LAMPS[1])
	assert_eq(Damage.tick_dot(w, i, 100, me, me, &"burn"), 150, "in a lit pool: 150 %")


## O4 (owner Q10 a: "dark 9 s / light 4 s"): from the first dark the room alternates on its own clock: dark 9 s, the
## whole room lit 4 s, dark again, repeating; a Lights Out while that runs leaves the cycle be.
func test_the_dark_lasts_9_s_then_the_light_4_s_repeating() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	var aid: int = s[1]
	assert_eq(int(BossShade.state(w)["dark_left"]), w.bosses.shade_until - w.tick)
	assert_eq(int(BossShade.state(w)["light_left"]), -1)
	var darks := PackedInt32Array()
	var lights := PackedInt32Array()
	var was := true
	var since := 0
	for k in 60 * 40:
		_hold(w, Vector2(-1.5, -1.5), 1)
		since += 1
		var now := BossShade.dark(w)
		if now != was:
			if was:
				darks.append(since)
			else:
				lights.append(since)
			since = 0
			was = now
		if k == 60 * 15:
			BossLab.start(w, _i(w, aid), &"lights_out")  # mid-cycle: only its wisps
	assert_gte(darks.size(), 3, "three darks in 40 s")
	assert_gte(lights.size(), 3, "three lights between them")
	# (the first is counted from the tick it fell on, like the rest)
	for k in darks.size():
		assert_eq(darks[k], 540, "each dark lasts 9 s")
	for n in lights:
		assert_eq(n, 240, "each light lasts 4 s")
	assert_eq(w.bosses.shade_at, -1, "no Lights Out reschedules the dark once it cycles")


## O4: in the full light the Shade takes 100 % anywhere (150 % still in a lit pool); a Snuff puts lanterns out there
## too.
func test_in_the_full_light_100_anywhere_and_snuff_still_works() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	var aid: int = s[1]
	_hold(w, Vector2(-1.5, -1.5), 540)
	assert_false(BossShade.dark(w), "the dark lifted")
	assert_between(
		int(BossShade.state(w)["light_left"]), 238, 240, "the reader counts the light down"
	)
	var i := _i(w, aid)
	w.actors.set_pos(i, Vector2(5.5, 5.5))
	w.actors.set_pos(0, Vector2(-0.5, 5.5))
	assert_eq(BossShade.light_permille(w, i), 1000, "full light: 100 % far from any light")
	var lt := w.bosses.lamp_t
	lt[2] = 100
	w.bosses.lamp_t = lt
	w.actors.set_pos(i, LAMPS[2])
	assert_eq(BossShade.light_permille(w, i), 1500, "a lit pool: 150 % in the light too")
	var t := BossAi.table_of(w, i)
	BossShade.snuff(w, t.attacks[t.attack_index(&"snuff")], LAMPS[2])
	assert_eq(w.bosses.lamp_t[2], 0, "a Snuff puts it out in the light")


## O4 (L4, Q12): while dark the hint points at every unlit lantern; lighting one drops its marker; none in the light,
## none once the Shade is gone.
func test_the_hint_points_at_the_unlit_lanterns_in_the_dark() -> void:
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	assert_eq(w.objectives.size(), 4, "four unlit lanterns, four markers")
	for k in 4:
		assert_eq(w.objectives.reason_at(k), ObjectiveMarkers.SHADE_LANTERN)
		assert_almost_eq(w.objectives.pos(k).distance_to(LAMPS[k]), 0.0, 0.001, "at lantern %d" % k)
	_hold(w, LAMPS[1] + Vector2(-1.0, 0), 1)
	assert_eq(w.objectives.size(), 3, "the lit one drops out")
	_hold(w, Vector2(-1.5, -1.5), 539)
	assert_false(BossShade.dark(w))
	assert_eq(w.objectives.size(), 0, "cleared in the light")
	_hold(w, Vector2(-1.5, -1.5), 240)
	assert_true(BossShade.dark(w))
	assert_eq(w.objectives.size(), 4, "back as the dark falls")
	BossSignatures.on_boss_gone(w, s[1])
	assert_eq(w.objectives.size(), 0, "cleared at the fight's end")


func test_snuff_puts_out_the_two_lanterns_nearest_its_strike() -> void:
	var p := LAMPS[1] + Vector2(-1.5, 0.5)
	var s := _dark(Vector2(-1.5, -1.5))
	var w: World = s[0]
	var aid: int = s[1]
	var lt := w.bosses.lamp_t
	lt.fill(360)
	w.bosses.lamp_t = lt
	_hold(w, p, 1)
	BossLab.start(w, _i(w, aid), &"snuff")
	var tel := BossAi.telegraph(w, _i(w, aid))
	assert_false(tel.is_empty(), "the Snuff's marker draws in the dark")
	_hold(w, p, 96)
	var out := []
	for k in 4:
		out.append(w.bosses.lamp_t[k] == 0)
	assert_eq(out, [false, true, true, false], "the two nearest the circle (east, south) went out")


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
	var rose := -1
	var lights := PackedInt32Array()
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
			if rose >= 0:
				lights.append(w.tick - rose)
		elif not BossShade.dark(w) and fell >= 0:
			stretches.append(w.tick - fell)
			fell = -1
			rose = w.tick
	assert_gte(starts.size(), 3, "three Lights Outs in 40 s")
	assert_between(starts[0], 170, 420, "the first about 3 s in")
	for k in range(1, starts.size()):
		assert_between(starts[k] - starts[k - 1], 720, 980, "every 12 s, start to start")
	# NB4b (owner: "Dark comes and goes"): each dark lasts 9 s, then the light comes back until the next one.
	assert_gte(stretches.size(), 2, "the dark came and went at least twice")
	for n in stretches:
		# (counted on w.tick: a hit's freeze, which holds the world's phases, can add a few ticks)
		assert_between(n, 540, 552, "each dark lasts 9 s")
	# v0.11.0 O4 (owner Q10 a): then 4 s of light, on the room's own clock (not the next Lights Out's).
	assert_gte(lights.size(), 2, "the light came and went at least twice")
	for n in lights:
		assert_between(n, 240, 252, "each light lasts 4 s")


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


## v0.11.0 S2b (owner Q2, "Wider still"): the escape lane in a Wisp Bloom wave (the edge-to-edge gap between the two
## wisps either side of a petal valley, where the wave crosses 4 m from the Shade) is at least the hero's diameter
## (0.70 m) + 0.7 m = 1.40 m. Bloom 1 too (owner, 2026-11-07: 30 -> 25 wisps a wave).
func test_s2b_bloom_lanes_leave_hero_plus_0_7_m_at_4_m() -> void:
	var ring := 4.0
	var away := Vector2(0, -400)
	var need := 2.0 * PlayerTable.starting_values().radius_m + 0.7
	for atk in [&"wisp_bloom", &"wisp_bloom_2", &"wisp_bloom_3"]:
		var s := _fight(Vector2(ring, 0))
		var w: World = s[0]
		_hush(w, s[1])
		_hold(w, Vector2(ring, 0), 2)
		BossLab.start(w, _i(w, s[1]), atk)
		var prev := {}
		var first_wave := {}  # proj id -> true, the ids seen on the first tick any wisp exists
		var angles: Array[float] = []
		var radius := 0.0
		var fired := false
		for tick in 400:
			_hold(w, away if fired else Vector2(ring, 0), 1)
			var ps := w.projectiles
			var any := false
			for j in ps.ids.size():
				if ps.team[j] != ActorStore.TEAM_ENEMY:
					continue
				any = true
				var id: int = ps.ids[j]
				if not fired:
					first_wave[id] = true
				var p := Vector2(ps.pos_x[j], ps.pos_y[j])
				radius = ps.radius[j]
				if first_wave.has(id) and prev.has(id):
					var a: Vector2 = prev[id]
					if a.length() < ring and p.length() >= ring:
						angles.append(
							a.lerp(p, (ring - a.length()) / (p.length() - a.length())).angle()
						)
				prev[id] = p
			if any:
				fired = true
			if fired and not any:
				break
		assert_gt(angles.size(), 6, "%s: the first wave crossed 4 m" % atk)
		angles.sort()
		var widest := 0.0
		for q in angles.size():
			var nxt: float = angles[(q + 1) % angles.size()]
			var d: float = nxt - angles[q] + (TAU if q == angles.size() - 1 else 0.0)
			widest = maxf(widest, 2.0 * ring * sin(d / 2.0) - 2.0 * radius)
		assert_gte(widest, need, "%s: lane %.3f m at 4 m (need %.2f)" % [atk, widest, need])
