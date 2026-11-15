# gdlint: disable=max-public-methods
extends GutTest
## The Fallen remembers the run (BossRemembered; owner direction HC-A): it never vanishes; at 66 % and 33 % of its HP
## and every 30 s between, one at a time and clear of its mimic windows, it casts the mechanic of a boss the run killed
## (Time Wave, Riptide, quake pillars, the ward), each on The Fallen's own numbers with no source boss in the room.
## Tick-exact runs of each mechanic, the pool, the rhythm over a long fight, the pace's floor, determinism, a snapshot
## mid-mechanic, and the end of everything with the body and the hero.

const L := preload("res://tests/support/fallen_lab.gd")
const R := preload("res://src/sim/ai/boss_remembered.gd")
const SEED := 811
const ALL: Array = [&"clockwork_judge", &"tidecaller", &"gatekeeper", &"twin_wardens"]


func _taken(w: World, amount: int) -> int:
	var taken := Stats.armour_permille(w) * PlayerBuild.taken_permille(w) / 1000
	return amount if taken == 1000 else maxi(1, (amount * taken + 500) / 1000)


func _part(w: World, permille: int) -> int:
	return _taken(w, maxi(1, w.actors.max_hp[0] * permille / 1000))


# --- data -----------------------------------------------------------------------------------------------------------


func test_the_data_compiles_to_the_brief_and_no_hit_is_over_forty_per_cent() -> void:
	var w := L.world(SEED)
	var m := L.table(w)
	var t := BossAi.table_of(w, L.body(w))
	assert_not_null(m)
	assert_eq(m.gates, PackedInt32Array([660, 330]))
	assert_eq([m.every_ticks, m.first_ticks, m.calm_ticks, m.cast_ticks], [1800, 720, 180, 90])
	assert_eq([m.time_cut, m.time.orb_count, m.time.orb.amount, m.time_ticks], [750, 3, 250, 720])
	assert_almost_eq(m.time.orb.radius_m, 1.2, 0.001)
	assert_almost_eq(m.time.orb_gap_m, 8.0, 0.001)
	assert_eq([m.dance.rip_casts, m.dance.rip_warn_ticks, m.dance.rip_hit], [3, 150, 300])
	var q := t.quake
	assert_eq([q.count, q.pulse_ticks, q.warn_ticks, q.damage_permille], [3, 180, 48, 60])
	assert_eq([q.stun_ticks, q.stun_permille, q.stuns_per_phase], [180, 1500, 2])
	assert_almost_eq(q.ring_m, 7.0, 0.001)
	assert_eq(m.pillar_ticks, 900)
	assert_eq(
		[m.ward_ticks, m.ward_windup_ticks, m.ward_lock_ticks, m.ward_charges], [720, 84, 30, 2]
	)
	assert_eq([m.ward_gap_ticks, m.ward_stun_ticks], [180, 240])
	assert_almost_eq(m.ward_speed * 60.0, 26.0, 0.001)
	for hit in [m.dance.rip_hit, q.damage_permille, m.ward_hit, m.ward_burst_hit]:
		assert_lte(hit, FallenRules.MAX_HIT, "no single hit over 40 % of the hero's max HP")
	assert_eq(t.attacks[m.dance.rip_cause].cause_key, &"CAUSE_TIDECALLER_WAVE")
	assert_eq(t.attacks[m.ward_cause].cause_key, &"CAUSE_TWIN_CHARGE")
	assert_eq(q.cause_key, &"CAUSE_GATEKEEPER_PILLAR")
	assert_null(t.time, "the Judge's own clocks are not The Fallen's")
	assert_null(t.dance, "nor the Tidecaller's")


func test_bad_numbers_are_refused() -> void:
	var d: FinalBossDefinition = SharedContent.repo().get_def(&"final_bosses", &"nemesis")
	assert_eq(d.validate().size(), 0, "the shipped body is valid")
	for bad in [
		["riptide_permille", 401],
		["ward_burst_permille", 500],
		["second_permille", 700],
		["ward_lock_seconds", 2.0],
		["nonsense", 1],
	]:
		var e: FinalBossDefinition = d.duplicate()
		e.remembered = d.remembered.duplicate()
		e.remembered[bad[0]] = bad[1]
		assert_gt(e.validate().size(), 0, "%s = %s is refused" % bad)


# --- the pool -------------------------------------------------------------------------------------------------------


func test_the_pool_follows_the_bosses_killed() -> void:
	var w := L.world(SEED)
	assert_eq(R.pool(w), [R.TIME, R.RIPTIDE], "none killed: Time Wave and Riptide")
	w.boss_fight.fl_beaten = PackedStringArray(["warlord", "foundry", "lantern_shade"])
	assert_eq(R.pool(w), [R.TIME, R.RIPTIDE], "none of them has one: the same")
	w.boss_fight.fl_beaten = PackedStringArray(
		["brood_mother", "gatekeeper", "hive_lens", "twin_wardens"]
	)
	assert_eq(R.pool(w), [R.QUAKE, R.WARD], "the Gatekeeper's and the Wardens'")
	w.boss_fight.fl_beaten = PackedStringArray(ALL)
	assert_eq(R.pool(w), [R.TIME, R.RIPTIDE, R.QUAKE, R.WARD])


func test_the_run_records_its_bosses_and_saves_them() -> void:
	var run := FinalLab.run_state(SEED, &"blade")
	var w := FinalLab.arena(run, false)
	var k := -1
	for j in w.boss_tables.size():
		if w.boss_tables[j].id == &"tidecaller":
			k = j
	w.boss_flow.boss_index = k
	run._note_boss(w)
	assert_eq(run.bosses_beaten, [] as Array[StringName], "its portal never opened: not killed")
	w.boss_flow.opened_tick = 30
	run._note_boss(w)
	run._note_boss(w)
	assert_eq(run.bosses_beaten, [&"tidecaller"] as Array[StringName], "killed, once")
	var payload := RunSaver.payload_of(w, run, 1, PackedByteArray())
	assert_true(RunSaver.is_usable(payload))
	var back := RunSaver.run_from(payload, run.table)
	assert_eq(back.bosses_beaten, [&"tidecaller"] as Array[StringName], "saved with the run")
	var w2 := FinalLab.arena(back, false)
	assert_eq(w2.boss_fight.fl_beaten, PackedStringArray(["tidecaller"]), "handed to the world")


func test_never_the_same_twice_running_and_one_boss_repeats() -> void:
	var w := L.world(SEED, &"blade", ALL)
	var fs := w.boss_fight
	var kinds: Array[int] = []
	for n in 10:
		fs.fl_open = w.tick
		fs.fl_next = w.tick
		fs.fl_end = -1
		assert_gt(L.until_stage(w, R.STAGE_CAST, 400), -1, "cast %d" % n)
		kinds.append(fs.fl_kind)
		R._finish(w, L.body(w))
		fs.fl_end = w.tick - 1000
		w.step(InputFrame.new())
	for n in range(1, kinds.size()):
		assert_ne(kinds[n], kinds[n - 1], "never twice running: %s" % [kinds])
	var one := L.world(SEED, &"blade", [&"twin_wardens", &"warlord"])
	assert_eq(R.pool(one), [R.WARD])
	one.boss_fight.fl_open = one.tick
	one.boss_fight.fl_next = one.tick
	assert_gt(L.until_stage(one, R.STAGE_CAST, 400), -1)
	assert_eq(one.boss_fight.fl_kind, R.WARD, "a pool of one repeats")


# --- each mechanic, tick-exact, with no source boss ------------------------------------------------------------------


func test_the_time_wave() -> void:
	var w := L.world(SEED)
	var i := L.body(w)
	var m := L.table(w)
	L.due(w, R.TIME)
	var seq := w.last_event_seq()
	assert_eq(L.until_stage(w, R.STAGE_CAST, 300), 1, "cast on the first tick it is due")
	w.step(InputFrame.new())
	var casts := L.events(w, R.CAST, seq)
	assert_eq(casts.size(), 1)
	assert_eq(casts[0].amount, 90, "a 1.5 s cast")
	assert_eq(casts[0].amount_applied, R.TIME)
	var cast_tick := casts[0].tick
	assert_gt(L.until_stage(w, R.STAGE_RUN, 200), -1)
	var began := w.boss_fight.fl_from
	assert_eq(began, cast_tick + 90, "it begins as the cast ends")
	assert_eq(L.source_bosses(w), 0, "no Judge in the room")
	assert_eq(BossSlow.cut(w), 750, "the weapon loses 75 %")
	assert_eq(w.bosses.aslow_boss, w.actors.ids[i])
	var orbs := WorldReader.new(w).boss_pickups()
	assert_eq(orbs.size(), 3, "three hour orbs")
	var inner := R.inner_of(w)
	for a: Dictionary in orbs:
		assert_true(inner.has_point(a["centre"]), "inside the round room")
		assert_almost_eq(float(a["radius"]), 1.2, 0.001)
		assert_eq(int(a["amount"]), 250)
		assert_gte(Vector2(a["centre"]).distance_to(w.player_pos()), 8.0, "8 m from the hero")
		for b: Dictionary in orbs:
			if a != b:
				assert_gte(Vector2(a["centre"]).distance_to(b["centre"]), 8.0, "8 m apart")
	assert_eq(int(orbs[0]["left"]), 719, "they last 12 s (a read after the tick they were placed)")
	assert_true(WorldReader.new(w).boss_fallen()["source"] == &"clockwork_judge")
	w.actors.set_pos(0, orbs[0]["centre"])
	w.step(InputFrame.new())
	assert_eq(BossSlow.cut(w), 500, "one orb returns 25 %")
	w.actors.set_pos(0, w.final_fight.home)
	var ended := -1
	for k in 800:
		w.step(InputFrame.new())
		if w.boss_fight.fl_stage == R.STAGE_NONE:
			ended = w.tick - 1  # A read after a step describes the tick about to run
			break
	assert_eq(ended, began + 720, "it ends as the last orbs run out")
	assert_eq(BossSlow.cut(w), 0, "what was still taken comes back")
	assert_eq(WorldReader.new(w).boss_pickups().size(), 0)
	assert_eq(w.boss_fight.fl_next, ended + m.every_ticks, "the next 30 s after its end")


func test_taking_every_orb_ends_the_time_wave() -> void:
	var w := L.world(SEED)
	var began := L.run(w, R.TIME)
	assert_gt(began, -1)
	for k in 3:
		var orbs := WorldReader.new(w).boss_pickups()
		w.actors.set_pos(0, orbs[0]["centre"])
		w.step(InputFrame.new())
	assert_eq(BossSlow.cut(w), 0, "every orb back")
	assert_eq(w.boss_fight.fl_stage, R.STAGE_NONE, "and it is over")


func test_riptide() -> void:
	var w := L.world(SEED, &"blade", [], false)
	var m := L.table(w)
	var seq := w.last_event_seq()
	var began := L.run(w, R.RIPTIDE)
	assert_gt(began, -1)
	assert_eq(L.source_bosses(w), 0, "no Tidecaller in the room")
	var st := WorldReader.new(w).boss_dance()
	assert_false(st.is_empty(), "boss_dance reports The Fallen's row")
	assert_eq((st["strips"] as Array).size(), 4)
	assert_eq(Rect2(st["room"]), R.room_of(w), "the strips cover the round room")
	var full := w.actors.max_hp[0]
	var hits: Array[int] = []
	var last := -1
	for k in 900:
		var hp := w.actors.hp[0]
		w.step(InputFrame.new())
		if w.actors.hp[0] < hp:
			hits.append(hp - w.actors.hp[0])
		w.actors.hp[0] = full
		w.actors.invuln[0] = 0
		if w.boss_fight.fl_stage == R.STAGE_NONE:
			last = w.tick - 1
			break
	var casts := L.events(w, BossDance.RIP_CAST, seq)
	var waves := L.events(w, BossDance.RIP_WAVE, seq)
	assert_eq(casts.size(), 3, "one row of three casts")
	assert_eq(waves.size(), 3)
	var safes: Array[int] = []
	for n in 3:
		assert_gte(casts[n].amount, 150, "a 2.5 s warning at least")
		assert_eq(waves[n].tick, casts[n].tick + casts[n].amount, "the wave after its warning")
		safes.append(casts[n].amount_applied)
	assert_true(
		safes == [1, 2, 0] or safes == [2, 1, 3], "safe strips 2, 3, 1 or the mirror: %s" % [safes]
	)
	assert_eq(last, waves[2].tick + m.dance.rip_wave_ticks, "it ends with the last wave")
	assert_gt(hits.size(), 0, "a hero standing still is struck")
	for h in hits:
		assert_eq(h, _part(w, 300), "30 % of max HP a strike")


## A way across pillar c (half side h) with `need` metres of open floor beyond each face, or ZERO.
func _pillar_way(w: World, c: Vector2, h: float, need: float) -> Vector2:
	for k in 16:
		var d := Kin.dir(k * 256)
		if (
			EnemyAi.clear_run(w, c + d * (h + 0.6), k * 256, need, 0.5) >= need - 0.01
			and (
				EnemyAi.clear_run(w, c - d * (h + 0.6), (k * 256 + 2048) & 4095, need, 0.5)
				>= need - 0.01
			)
		):
			return d
	return Vector2.ZERO


func test_the_quake_pillars_and_the_dash_that_shatters_one() -> void:
	var w := L.world(SEED, &"blade", [], false)
	var i := L.body(w)
	var m := L.table(w)
	var q := BossAi.table_of(w, i).quake
	var seq := w.last_event_seq()
	var began := L.run(w, R.QUAKE)
	assert_gt(began, -1)
	assert_eq(L.source_bosses(w), 0, "no Gatekeeper in the room")
	var id := w.actors.ids[i]
	var mine := BossQuake.pillars_of(w, id)
	assert_eq(mine.size(), 3, "three pillars")
	for k in mine:
		var c := BossQuake.center(w.bosses, k)
		assert_true(R.inner_of(w).has_point(c), "inside the round room")
		assert_gte(c.distance_to(w.player_pos()), m.pillar_hero_m + q.half_m, "clear of the hero")
	assert_eq(WorldReader.new(w).boss_quake_pillars().size(), 3, "boss_quake_pillars reports them")
	# The first pulse: 6 % to a hero within 7 m of a pillar, 3 s after they rose
	var c0 := BossQuake.center(w.bosses, mine[0])
	w.actors.set_pos(0, c0 + Vector2(0, q.half_m + 1.5))
	var hp := w.actors.hp[0]
	while w.tick <= began + 180:
		w.step(InputFrame.new())
		w.actors.set_pos(0, c0 + Vector2(0, q.half_m + 1.5))
	assert_lt(w.actors.hp[0], hp, "the pulse hits on its tick")
	assert_lte(hp - w.actors.hp[0], w.actors.max_hp[0] * 400 / 1000)
	w.actors.hp[0] = w.actors.max_hp[0]
	# A pillar between the hero and The Fallen: its dash runs into it
	var way := _pillar_way(w, c0, q.half_m, 4.0)
	assert_ne(way, Vector2.ZERO, "room both sides of a pillar")
	var fallen := c0 + way * (q.half_m + w.actors.radius[i] + 2.0)
	var hero := c0 - way * (q.half_m + w.player.radius_m + 1.2)
	w.actors.set_pos(i, fallen)
	w.actors.set_pos(0, hero)
	w.boss_fight.fl_dash_at = w.tick
	var stunned := -1
	for k in 120:
		w.step(InputFrame.new())
		w.actors.set_pos(0, hero)
		w.actors.hp[0] = w.actors.max_hp[0]
		if w.actors.state[i] == BossAi.STAGGERED:
			stunned = w.tick - 1
			break
	assert_gt(stunned, -1, "the dash shatters the pillar and stuns it")
	assert_eq(L.events(w, BossQuake.SHATTER, seq).size(), 1, "one pillar shattered")
	assert_eq(L.events(w, BossQuake.STUN, seq).size(), 1)
	assert_eq(L.events(w, BossQuake.STUN, seq)[0].amount, 180, "a 3 s stun")
	assert_eq(BossQuake.pillars_of(w, id).size(), 2)
	assert_eq(BossQuake.taken_permille(w, i), 1500, "it takes 150 % meanwhile")
	var ended := -1
	for k in 1000:
		w.step(InputFrame.new())
		w.actors.hp[0] = w.actors.max_hp[0]
		if w.boss_fight.fl_stage == R.STAGE_NONE:
			ended = w.tick - 1  # A read after a step describes the tick about to run
			break
	assert_eq(ended, began + 900, "15 s of pillars")
	assert_eq(BossQuake.pillars_of(w, id).size(), 0, "they sink with it")


func test_at_most_two_stuns_a_quake() -> void:
	var w := L.world(SEED, &"blade")
	var i := L.body(w)
	assert_gt(L.run(w, R.QUAKE), -1)
	var id := w.actors.ids[i]
	var seq := w.last_event_seq()
	for n in 3:
		var mine := BossQuake.pillars_of(w, id)
		BossQuake.shatter(w, i, PackedInt32Array([mine[0]]))
		w.bosses.stagger_t[BossAi.entry_of(w, i)] = 1
		w.step(InputFrame.new())
	assert_eq(
		L.events(w, BossQuake.STUN, seq).size(), 2, "two stuns, the third break only removes it"
	)


func _ward_world() -> Array:
	var w := L.world(SEED, &"blade", [], false)
	var i := L.body(w)
	w.actors.set_pos(i, w.final_fight.home + Vector2(0.0, 6.0))  # Off the centre: off the line to the hero
	w.actors.set_pos(0, w.final_fight.home + Vector2(4.0, 0.0))
	var seq := w.last_event_seq()
	var began := L.run(w, R.WARD)
	return [w, i, began, seq]


func test_the_ward_takes_nothing_and_its_shade_charges_from_the_far_edge() -> void:
	var r := _ward_world()
	var w: World = r[0]
	var i: int = r[1]
	var m := L.table(w)
	assert_gt(int(r[2]), -1)
	assert_eq(L.source_bosses(w), 0, "no Warden in the room")
	var at := w.actors.pos(i)
	var pid := w.actors.ids[0]
	var hp := w.actors.hp[i]
	w.actors.invuln[i] = 0
	Damage.hit(w, i, 500, pid, pid, w.take_root(), 0, w.player_pos(), at)
	assert_eq(w.actors.hp[i], hp, "under the ward it takes nothing")
	assert_true(WorldReader.new(w).boss_invulnerable(i))
	var sh: Dictionary = WorldReader.new(w).boss_fallen()["shade"]
	assert_false(sh.is_empty(), "the shade stands")
	var away := (w.final_fight.home - w.player_pos()).normalized()
	var expect := w.final_fight.home + away * (w.boss_fight.fl_r - m.ward_edge_m)
	assert_lt(
		Vector2(sh["position"]).distance_to(expect), 0.6, "at the edge farthest from the hero"
	)
	assert_eq(int(sh["stage"]), FallenWard.WINDUP)


func test_a_charge_through_the_fallen_breaks_the_ward_and_stuns_it() -> void:
	var r := _ward_world()
	var w: World = r[0]
	var i: int = r[1]
	var seq := w.last_event_seq()
	var shade := Vector2(w.boss_fight.fl_sh_x, w.boss_fight.fl_sh_y)
	var line := (w.actors.pos(i) - shade).normalized()
	var hero := w.actors.pos(i) + line * 4.0  # The Fallen on the shade's line
	var broke := -1
	var flagged := false
	for k in 300:
		w.actors.set_pos(0, hero)
		w.step(InputFrame.new())
		if w.boss_fight.fl_ward == 0:
			broke = w.tick - 1
			break
		var sh: Dictionary = WorldReader.new(w).boss_fallen()["shade"]
		flagged = flagged or (not sh.is_empty() and bool(sh["breaks"]))
	assert_gt(broke, -1, "the ward breaks")
	assert_true(flagged, "the reader said the lane runs through The Fallen")
	assert_false(w.objectives.has(ObjectiveMarkers.TWINS_WARD), "the ward is down: no marker")
	var breaks := L.events(w, FallenWard.BREAK, seq)
	assert_eq(breaks.size(), 1)
	assert_eq(breaks[0].amount, 240, "a 4 s stun")
	assert_eq(w.actors.state[i], BossAi.STAGGERED)
	assert_eq(BossQuake.taken_permille(w, i), 1500, "it takes 150 % meanwhile")
	assert_eq(L.events(w, BossChargeBurst.ARMED, seq).size(), 0, "no burst after a break")
	var pid := w.actors.ids[0]
	var hp := w.actors.hp[i]
	w.actors.invuln[i] = 0
	Damage.hit(w, i, 100, pid, pid, w.take_root(), 0, w.player_pos(), w.actors.pos(i))
	assert_lt(w.actors.hp[i], hp, "it can be hurt again")
	var ended := -1
	for k in 400:
		w.step(InputFrame.new())
		if w.boss_fight.fl_stage == R.STAGE_NONE:
			ended = w.tick - 1  # A read after a step describes the tick about to run
			break
	assert_eq(ended, broke + 240, "the mechanic ends with the stun")


func test_a_missed_charge_comes_again_then_the_ward_ends_by_itself() -> void:
	var r := _ward_world()
	var w: World = r[0]
	var i: int = r[1]
	var m := L.table(w)
	var seq: int = r[3]
	var began: int = r[2]
	var full := w.actors.max_hp[0]
	var hit_costs: Array[int] = []
	var ended := -1
	for k in 900:
		# Where it stood: the shade's lane runs through the hero, never through The Fallen
		w.actors.set_pos(0, w.final_fight.home + Vector2(4.0, 0.0))
		var hp := w.actors.hp[0]
		w.step(InputFrame.new())
		if w.actors.hp[0] < hp:
			hit_costs.append(hp - w.actors.hp[0])
		w.actors.hp[0] = full
		w.actors.invuln[0] = 0
		if w.boss_fight.fl_stage == R.STAGE_NONE:
			ended = w.tick - 1  # A read after a step describes the tick about to run
			break
	var charges := L.events(w, FallenWard.CHARGE, seq)
	assert_eq(charges.size(), 2, "two charges")
	assert_eq(L.events(w, FallenWard.BREAK, seq).size(), 0, "none through The Fallen")
	var armed := L.events(w, BossChargeBurst.ARMED, seq)
	assert_eq(armed.size(), 2, "each ends in a burst")
	assert_eq(
		charges[1].tick, armed[0].tick + m.ward_gap_ticks, "the second 3 s after the first's end"
	)
	assert_eq(ended, armed[1].tick + m.ward_burst_ticks, "the ward ends after the last burst")
	assert_lte(ended - began, m.ward_ticks, "within its 12 s")
	assert_gt(hit_costs.size(), 0, "the charge or its burst hit the hero")
	for c in hit_costs:
		assert_lte(c, full * 400 / 1000, "never over 40 %")
		assert_true(c == _part(w, 250) or c == _part(w, 300), "the touch or the burst: %d" % c)


func test_the_hint_marker_is_on_the_fallen_while_the_shade_winds_up_under_the_ward() -> void:
	var r := _ward_world()
	var w: World = r[0]
	var i: int = r[1]
	var fid := w.actors.ids[i]
	var marked := 0
	var winding := 0
	for k in 900:
		w.actors.set_pos(0, w.final_fight.home + Vector2(4.0, 0.0))  # Never on The Fallen's line
		w.actors.hp[0] = w.actors.max_hp[0]
		var fs := w.boss_fight
		var want := fs.fl_ward == 1 and fs.fl_sh_stage == FallenWard.WINDUP
		var got := w.objectives.has(ObjectiveMarkers.TWINS_WARD)
		assert_eq(got, want, "tick %d: the marker is up exactly while the shade winds up" % w.tick)
		if want:
			winding += 1
			var o := WorldReader.new(w).objectives()
			assert_eq(o.size(), 1)
			assert_eq(o[0]["entity"], fid, "on The Fallen")
			assert_false(bool(WorldReader.new(w).boss_fallen()["shade"]["breaks"]), "off its line")
		marked += 1 if got else 0
		if fs.fl_stage == R.STAGE_NONE:
			break
		w.step(InputFrame.new())
	assert_gt(winding, 0, "the shade wound up")
	assert_eq(marked, winding)
	assert_false(w.objectives.has(ObjectiveMarkers.TWINS_WARD), "gone with the ward")


# --- the rhythm against the mimic windows ----------------------------------------------------------------------------


## A scripted fight of `ticks` with the windows as shipped: the world's own hits take The Fallen to 65 % at 50 s and
## to 32 % at 110 s. Returns [mechanics [[cast tick, end tick, kind, gate]], windows [[warn tick, close tick]]].
func _scripted(seed_value: int, ticks: int, beaten: Array = ALL) -> Array:
	var w := L.world(seed_value, &"blade", beaten, true, true)
	var i := L.body(w)
	var fs := w.boss_fight
	var mech := []
	var wins := []
	var prev_stage := 0
	var prev_win := FinalPace.Mimic.OFF
	var gates := 0
	for k in ticks:
		if k == 3000:
			w.actors.hp[i] = w.actors.max_hp[i] * 650 / 1000
		if k == 6600:
			w.actors.hp[i] = w.actors.max_hp[i] * 320 / 1000
		w.step(FinalLab.walk(w, w.final_fight.home + Kin.dir(k * 7 & 4095) * 4.0))
		w.actors.hp[0] = w.actors.max_hp[0]
		var win := FinalPace.window(w)
		if win == FinalPace.Mimic.WARN and prev_win == FinalPace.Mimic.OFF:
			wins.append([w.tick, -1])
		if win == FinalPace.Mimic.OFF and prev_win != FinalPace.Mimic.OFF and not wins.is_empty():
			wins[wins.size() - 1][1] = w.tick
		prev_win = win
		if fs.fl_stage == R.STAGE_CAST and prev_stage == R.STAGE_NONE:
			var g := 1 if fs.fl_gates != gates else 0
			gates = fs.fl_gates
			mech.append([w.tick - 1, -1, fs.fl_kind, g])  # The tick it was cast
		if fs.fl_stage == R.STAGE_NONE and prev_stage != R.STAGE_NONE:
			mech[mech.size() - 1][1] = w.tick - 1  # The tick it ended
		prev_stage = fs.fl_stage
		assert_false(
			fs.fl_stage != R.STAGE_NONE and win != FinalPace.Mimic.OFF,
			"tick %d: never a mechanic in a window or its warning" % w.tick
		)
	return [mech, wins, w]


func test_the_rhythm_holds_against_the_mimic_windows() -> void:
	var r := _scripted(SEED, 60 * 240)
	var mech: Array = r[0]
	var wins: Array = r[1]
	var w: World = r[2]
	var m := L.table(w)
	gut.p(
		(
			"FALLEN rhythm: mechanics [cast, end, kind, gate] %s; windows [warn, close] %s"
			% [mech, wins]
		)
	)
	assert_gte(mech.size(), 4, "several mechanics over four minutes")
	var gate_casts := 0
	for n in mech.size():
		var a: Array = mech[n]
		gate_casts += int(a[3])
		if a[1] < 0:
			continue
		if n > 0:
			var b: Array = mech[n - 1]
			assert_gte(a[0] - b[1], m.calm_ticks, "the calm between two mechanics")
			if int(a[3]) == 0:
				assert_gte(a[0] - b[1], m.every_ticks, "a timed one 30 s after the last ended")
		for win: Array in wins:
			if win[1] < 0:
				continue
			var clear: bool = a[1] + m.calm_ticks <= win[0] or win[1] + m.calm_ticks <= a[0]
			assert_true(clear, "mechanic %s keeps 3 s from window %s" % [a, win])
	assert_eq(gate_casts, 2, "one at 66 % and one at 33 %")


func test_a_mimic_window_waits_for_a_mechanic() -> void:
	var w := L.world(SEED, &"blade", ALL, true, true)
	var fs := w.boss_fight
	fs.fl_open = 1 << 30  # None of its own until this one
	NemesisLab.until_window(w, FinalPace.Mimic.ON)
	NemesisLab.until_window(w, FinalPace.Mimic.OFF)
	for k in 200:
		w.step(InputFrame.new())
	var clock := FinalPace.window_clock(w)
	L.due(w, R.QUAKE)
	assert_gt(L.until_stage(w, R.STAGE_CAST, 60), -1)
	var due_warn := w.tick + clock[0]
	assert_gt(L.until_stage(w, R.STAGE_NONE, 2000), -1, "it runs to its end")
	var ended := w.tick - 1
	assert_gt(ended, due_warn, "the mechanic ran past the window's own time")
	var warned := -1
	for k in 600:
		if FinalPace.window(w) == FinalPace.Mimic.WARN:
			warned = w.tick
			break
		w.step(InputFrame.new())
	assert_gte(warned, ended + L.table(w).calm_ticks, "the window waited for it and its calm")
	assert_gt(fs.fl_delay, 0, "the windows' clock waited")


# --- the per-minute share, the pace, determinism --------------------------------------------------------------------


func test_the_seconds_a_minute_a_big_thing_runs() -> void:
	var r := _scripted(SEED, 60 * 180)
	var mech: Array = r[0]
	var wins: Array = r[1]
	var busy := PackedInt32Array()
	busy.resize(3)
	var w: World = r[2]
	var start := w.tick - 60 * 180
	for spans in [mech, wins]:
		for s: Array in spans:
			var to: int = s[1] if s[1] >= 0 else w.tick
			for t in range(s[0], to):
				var minute := (t - start) / 3600
				if minute >= 0 and minute < 3:
					busy[minute] += 1
	var secs := []
	for v in busy:
		secs.append(snappedf(v / 60.0, 0.1))
	gut.p("FALLEN per minute: seconds a remembered mechanic or a mimic window runs %s" % [secs])
	for s: float in secs:
		assert_lt(s, 60.0, "never all the time")


func test_the_pace_floor_holds_through_ward_and_stuns() -> void:
	var w := L.world(SEED, &"blade", ALL, true, true)
	var i := L.body(w)
	var id := w.actors.ids[i]
	var t := BossAi.table_of(w, i)
	var from := w.final_fight.phase_tick
	var pid := w.actors.ids[0]
	var died := -1
	for k in 60 * 200:
		var j := w.actors.index_of(id)
		if j < 0 or w.actors.dead[j] == 1:
			died = w.tick
			break
		w.actors.invuln[j] = 0
		Damage.hit(w, j, 999999, pid, pid, w.take_root(), 0, w.player_pos(), w.actors.pos(j))
		w.step(InputFrame.new())
	assert_gt(died, -1, "it dies")
	var floor_ticks := t.pace_min_ticks * FinalPace.ease_permille(w) / 1000
	gut.p("FALLEN pace floor: died %d ticks after its rise (floor %d)" % [died - from, floor_ticks])
	assert_gte(died - from, floor_ticks, "never sooner than the pace's floor")


func _fight_hash(seed_value: int) -> String:
	var w := L.world(seed_value, &"gun", ALL, false, true)
	for k in 60 * 90:
		if k == 1800:
			w.actors.hp[L.body(w)] = w.actors.max_hp[L.body(w)] * 600 / 1000
		w.step(FinalLab.walk(w, w.final_fight.home + Kin.dir(k * 11 & 4095) * 5.0))
		w.actors.hp[0] = w.actors.max_hp[0]
	return w.state_hash()


func test_a_fight_is_deterministic() -> void:
	assert_eq(_fight_hash(SEED), _fight_hash(SEED), "two runs agree")


# --- saves and ends -------------------------------------------------------------------------------------------------


func test_a_snapshot_mid_mechanic_round_trips_and_runs_on_the_same() -> void:
	for kind in [R.TIME, R.RIPTIDE, R.QUAKE, R.WARD]:
		var run := FinalLab.run_state(841, &"blade")
		var w := FinalLab.arena(run)
		w.actors.invuln[0] = NemesisLab.LONG
		FinalLab.past_rise(w)
		FinalBoss.jump(w, 2)
		FinalLab.past_rise(w)
		assert_gt(L.run(w, kind), -1, "kind %d runs" % kind)
		for k in 40:
			w.step(FinalLab.walk(w, w.final_fight.home + Vector2(3, 2)))
		var snap := w.to_snapshot()
		var w2 := FinalLab.arena(run, false)
		assert_eq(WorldSnapshot.apply(w2, snap), "", "kind %d restores" % kind)
		assert_eq(w2.state_hash(), w.state_hash(), "kind %d: the same hash" % kind)
		assert_eq(w2.boss_fight.fl_kind, kind)
		for k in 900:
			var fr := FinalLab.walk(w, w.final_fight.home + Vector2(-3, 1))
			w.step(fr)
			w2.step(fr)
		assert_eq(w2.state_hash(), w.state_hash(), "kind %d: the same to its end" % kind)


func test_everything_clears_with_the_hero_s_death() -> void:
	for kind in [R.TIME, R.RIPTIDE, R.QUAKE, R.WARD]:
		var w := L.world(SEED, &"blade", [], false)
		var i := L.body(w)
		assert_gt(L.run(w, kind), -1)
		w.actors.hp[0] = 0
		w.actors.dead[0] = 1
		w.step(InputFrame.new())
		_assert_clear(w, i, "kind %d, the hero dead" % kind)
		assert_eq(w.boss_fight.fl_stage, R.STAGE_NONE)


func test_everything_clears_with_the_fallen() -> void:
	for kind in [R.TIME, R.RIPTIDE, R.QUAKE, R.WARD]:
		var w := L.world(SEED, &"blade", [])
		var i := L.body(w)
		var id := w.actors.ids[i]
		assert_gt(L.run(w, kind), -1)
		FinalLab.end_segment(w)
		w.step(InputFrame.new())
		assert_true(w.final_fight.won, "kind %d: won" % kind)
		assert_eq(w.boss_fight.fl_boss, -1, "its clocks go")
		assert_eq(BossQuake.pillars_of(w, id).size(), 0)
		assert_eq(BossSlow.cut(w), 0)
		assert_eq(w.bosses.pk_x.size(), 0)
		assert_eq(w.boss_fight.fl_ward, 0)
		assert_eq(w.boss_fight.dance_rip_from, -1)
		assert_true(WorldReader.new(w).boss_fallen().is_empty())


func _assert_clear(w: World, i: int, why: String) -> void:
	var id := w.actors.ids[i]
	assert_eq(BossQuake.pillars_of(w, id).size(), 0, why + ": no pillar")
	assert_eq(BossSlow.cut(w), 0, why + ": the weapon whole")
	assert_eq(BossPickups.count_of(w, id), 0, why + ": no orb")
	assert_eq(w.boss_fight.fl_ward, 0, why + ": no ward")
	assert_eq(w.boss_fight.fl_sh_stage, 0, why + ": no shade")
	assert_eq(w.boss_fight.dance_rip_from, -1, why + ": no strip")


func test_it_never_vanishes() -> void:
	var r := _scripted(SEED, 60 * 120)
	var w: World = r[2]
	var i := L.body(w)
	assert_false(BossAi.hidden(w, i), "it stays in the room")


func test_the_death_recap_names_each_mechanic() -> void:
	var w := L.world(SEED)
	var t := BossAi.table_of(w, L.body(w))
	var m := t.remembered
	w.killer_kind = w.actors.kinds[L.body(w)]
	for pair in [
		[m.dance.rip_cause, &"CAUSE_TIDECALLER_WAVE"],
		[m.ward_cause, &"CAUSE_TWIN_CHARGE"],
		[BossQuake.ATTACK, &"CAUSE_GATEKEEPER_PILLAR"],
	]:
		w.killer_attack = pair[0]
		assert_eq(BossCauses.key(w), pair[1])
