# gdlint: disable=max-public-methods
extends GutTest
## The boss challenge (PLAN v0.3.0 BX; owner lines L17, L20, L22, L26): ranged armour, the punish move of each boss,
## the weak point up close, the closing arena, the harder AI (shorter recoveries, follow-ups, leading aim) and the
## floor's enemies dissolving when the boss is summoned. Real compiled bosses from data/ (BossLab).

const S := EnemyAi.State


## Boss `id` at the origin, past its rise, the player at `stand`. Returns [world, boss index, boss actor id].
func _boss(id: StringName, stand: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id)
	w.actors.set_pos(0, stand)
	w.actors.hp[0] = 100000
	w.actors.max_hp[0] = 100000
	return [w, i, w.actors.ids[i]]


## A HIT event on `target` since `seq`, the last one, or null.
func _last_hit(w: World, target: int, seq: int) -> SimEvent:
	var got: SimEvent = null
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.HIT and e.target_id == target:
			got = e
	return got


# --- ranged armour ------------------------------------------------------------------------------------------------


func test_ranged_armour_falls_off_with_distance_and_tags_the_hit() -> void:
	# The Brood Mother has no directional armour, so only the distance counts.
	var r := BossLab.tables()[0].radius_m  # any; recomputed below per boss
	var got := {}
	for edge in [2.0, 5.0, 8.5, 12.0, 20.0]:
		var s := _boss(&"brood_mother", Vector2.ZERO)
		var w: World = s[0]
		var i: int = s[1]
		r = w.actors.radius[i]
		w.actors.set_pos(0, Vector2(edge + r, 0))
		var seq := w.last_event_seq()
		got[edge] = Damage.hit(w, i, 100, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i))
		var h := _last_hit(w, s[2], seq)
		var deflected := (h.tags & SimEvent.TAG_DEFLECTED) != 0
		assert_eq(deflected, edge > 5.0, "%.1f m: tagged deflected iff beyond 5 m" % edge)
	assert_eq(got[2.0], 100, "up close: full")
	assert_eq(got[5.0], 100, "5 m: still full")
	assert_eq(got[8.5], 70, "halfway to 12 m: 70 %")
	assert_eq(got[12.0], 40, "12 m: 40 %")
	assert_eq(got[20.0], 40, "beyond: 40 %")


func test_ranged_armour_only_softens_the_players_hits() -> void:
	var s := _boss(&"brood_mother", Vector2(15, 0))
	var w: World = s[0]
	var i: int = s[1]
	assert_eq(Damage.hit(w, i, 100, 99, 99, 99, 0, Vector2(15, 0), w.actors.pos(i)), 100)


func test_ranged_armour_is_data() -> void:
	for t in BossLab.tables():
		assert_eq(t.ranged_full_m, 5.0, "%s: full up to 5 m" % t.id)
		assert_eq(t.ranged_far_m, 12.0)
		assert_eq(t.ranged_far_permille, 400, "40 % from 12 m")


# --- the weak point -----------------------------------------------------------------------------------------------


func test_the_weak_point_opens_after_a_slam_and_doubles_close_hits() -> void:
	var s := _boss(&"gatekeeper", Vector2(0, 3))  # inside the slam's ring, beside the boss (no armour)
	var w: World = s[0]
	var aid: int = s[2]
	var i: int = s[1]
	var b := BossAi.entry_of(w, i)
	var t := BossAi.table_of(w, i)
	BossLab.start(w, i, &"fist_slam")
	assert_eq(w.bosses.exposed_t[b], 0, "closed while it winds up")
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
	)
	i = w.actors.index_of(aid)
	assert_eq(w.bosses.exposed_t[b], t.weak_ticks, "open for its whole time as the recovery starts")
	assert_eq(t.weak_ticks, 120, "2 s")
	# Up close (2 m from its edge, from its side: no directional armour): x2 damage, and the meter fills x2.
	w.actors.facing[i] = 0
	w.actors.set_pos(0, Vector2(0, w.actors.radius[i] + 2.0))
	var meter := w.bosses.meter[b]
	var seq := w.last_event_seq()
	assert_eq(Damage.hit(w, i, 50, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i)), 100, "x2")
	assert_ne(_last_hit(w, aid, seq).tags & SimEvent.TAG_EXPOSED, 0, "tagged exposed")
	assert_eq(w.bosses.meter[b] - meter, 100 * 2000, "stagger fills twice as fast")
	# From afar it is only the ranged armour.
	w.actors.set_pos(0, Vector2(0, w.actors.radius[i] + 12.0))
	seq = w.last_event_seq()
	assert_eq(Damage.hit(w, i, 100, 1, 1, 1, 0, w.player_pos(), w.actors.pos(i)), 40)
	assert_eq(_last_hit(w, aid, seq).tags & SimEvent.TAG_EXPOSED, 0, "far: not the weak point")
	CombatLab.idle(w, t.weak_ticks)
	assert_eq(w.bosses.exposed_t[b], 0, "it closes after 2 s")


func test_attacks_that_dont_open_it_leave_it_shut() -> void:
	var s := _boss(&"gatekeeper", Vector2(2.5, 0))
	var w: World = s[0]
	var aid: int = s[2]
	BossLab.start(w, s[1], &"sweep")
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
	)
	assert_eq(w.bosses.exposed_t[0], 0)


func test_each_boss_has_attacks_that_open_it() -> void:
	for t in BossLab.tables():
		var n := 0
		for a in t.attacks:
			if a.opens_weak:
				n += 1
		assert_gte(n, 2, "%s: two or more openings" % t.id)
		assert_eq(t.weak_mult_permille, 2000)
		assert_eq(t.weak_range_m, 2.5)


# --- punish -------------------------------------------------------------------------------------------------------


func test_staying_far_starts_the_punish_move_after_four_seconds() -> void:
	for id: StringName in [&"gatekeeper", &"brood_mother", &"siege_engine"]:
		var s := _boss(id, Vector2(30, 0))
		var w: World = s[0]
		var aid: int = s[2]
		var t := BossAi.table_of(w, s[1])
		assert_eq(t.punish_ticks, 240, "4 s")
		t.gap_attack = -1  # v0.3.5 AI: the gap-closer would come first (2 s); this test is the punish's
		var b := BossAi.entry_of(w, s[1])
		var started := -1
		for k in 400:
			w.actors.set_pos(0, Vector2(30, 0))
			w.actors.cd[w.actors.index_of(aid)] = 9999  # no other attack: only the punish ignores it
			w.step(InputFrame.new())
			var i := w.actors.index_of(aid)
			if w.bosses.attack[b] == t.punish_attack and w.actors.state[i] == S.WINDUP:
				started = k
				break
		assert_gte(started, t.punish_ticks - 1, "%s: not before 4 s far away" % id)
		assert_lt(started, t.punish_ticks + 60, "%s: soon after" % id)


func test_coming_close_resets_the_far_timer() -> void:
	var s := _boss(&"gatekeeper", Vector2(30, 0))
	var w: World = s[0]
	var b := BossAi.entry_of(w, s[1])
	CombatLab.idle(w, 100)
	assert_gt(w.bosses.far_t[b], 90)
	w.actors.set_pos(0, Vector2(5, 0))
	w.step(InputFrame.new())
	assert_eq(w.bosses.far_t[b], 0)


func test_the_gatekeepers_vortex_drags_you_in_then_slams() -> void:
	var s := _boss(&"gatekeeper", Vector2(9, 0))
	var w: World = s[0]
	var aid: int = s[2]
	var t := BossAi.table_of(w, s[1])
	BossLab.start(w, s[1], &"vortex_slam")
	var atk := t.attacks[t.punish_attack]
	assert_eq(atk.id, &"vortex_slam")
	assert_gte(atk.windup_ticks, SimTick.MIN_TELEGRAPH_TICKS)
	var x0 := w.player_pos().x
	CombatLab.idle(w, 30)
	assert_almost_eq(x0 - w.player_pos().x, atk.pull * 30, 0.01, "dragged at 5.5 m/s")
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
	)
	assert_eq(CombatLab.player_damage(w).size(), 1, "pulled into the slam")
	assert_gt(w.bosses.exposed_t[0], 0, "then its weak point opens")


func test_a_dash_or_walking_away_escapes_the_vortex() -> void:
	var s := _boss(&"gatekeeper", Vector2(12, 0))
	var w: World = s[0]
	var aid: int = s[2]
	BossLab.start(w, s[1], &"vortex_slam")
	for k in 200:
		if w.actors.state[w.actors.index_of(aid)] == S.RECOVER:
			break
		w.step(InputFrame.make(Vector2i(127, 0), 0, 100, 0, 0))
	assert_eq(CombatLab.player_damage(w), [], "walking away holds you out of the slam")


func test_the_brood_mothers_pounce_chain_closes_the_gap() -> void:
	var s := _boss(&"brood_mother", Vector2(14, 0))
	var w: World = s[0]
	var aid: int = s[2]
	BossLab.start(w, s[1], &"pounce_chain")
	var leaps := 0
	for k in 600:
		var i := w.actors.index_of(aid)
		if w.actors.state[i] == S.RECOVER:
			break
		if w.actors.state[i] == S.WINDUP and w.actors.state_t[i] == 0:
			leaps += 1
		w.actors.set_pos(0, Vector2(14, 0))
		w.step(InputFrame.new())
	assert_eq(leaps, 3, "three leaps in a row")
	assert_gt(CombatLab.player_damage(w).size(), 0, "and it lands on you")


func test_the_siege_engines_shockwave_spares_a_ring_near_it() -> void:
	for spec in [[Vector2(3.0, 0), false], [Vector2(14, 0), true], [Vector2(0, 25), true]]:
		var s := _boss(&"siege_engine", spec[0])
		var w: World = s[0]
		var aid: int = s[2]
		BossLab.start(w, s[1], &"shockwave")
		CombatLab.until(
			w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
		)
		assert_eq(CombatLab.player_damage(w).size() > 0, spec[1], "%s" % spec[0])


# --- harder AI ----------------------------------------------------------------------------------------------------


## v0.3.0 BX cut recoveries by a fifth (800); v0.3.5 AI (F3) by a further quarter (600).
func test_recoveries_are_forty_percent_shorter() -> void:
	var repo := ContentRepository.load_all()
	for def: BossDefinition in repo.all_of(&"bosses"):
		assert_eq(def.recovery_permille, 600, "%s: -40 %%" % def.id)
		var t := ContentCompiler.compile_boss(def, repo)
		for k in def.attacks.size():
			var full := SimTick.seconds_to_ticks(def.attacks[k].recovery_seconds)
			assert_eq(t.attacks[k].recover_ticks, full * 600 / 1000, "%s" % def.attacks[k].id)


func test_an_attack_chains_into_its_follow_up_once() -> void:
	var s := _boss(&"gatekeeper", Vector2(2.5, 0))
	var w: World = s[0]
	var aid: int = s[2]
	var t := BossAi.table_of(w, s[1])
	var sweep := t.attacks[t.attack_index(&"sweep")]
	assert_eq(sweep.follow_up, t.attack_index(&"fist_slam"))
	sweep.follow_up_permille = 1000  # this world's table only
	BossAi.start_attack(w, s[1], t.attack_index(&"sweep"))
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.ACTIVE
	)
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] != S.ACTIVE
	)
	var i := w.actors.index_of(aid)
	assert_eq(w.actors.state[i], S.WINDUP, "no recovery: the follow-up winds up at once")
	assert_eq(w.bosses.attack[0], t.attack_index(&"fist_slam"))
	assert_eq(w.bosses.chained[0], 1)
	assert_gte(BossAi.telegraph(w, i).size(), 1, "and it is telegraphed")
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
	)
	assert_eq(w.bosses.attack[0], t.attack_index(&"fist_slam"), "a follow-up never chains again")


func test_without_the_roll_it_recovers() -> void:
	var s := _boss(&"gatekeeper", Vector2(2.5, 0))
	var w: World = s[0]
	var aid: int = s[2]
	var t := BossAi.table_of(w, s[1])
	t.attacks[t.attack_index(&"sweep")].follow_up_permille = 0
	BossAi.start_attack(w, s[1], t.attack_index(&"sweep"))
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.RECOVER
	)
	assert_eq(w.bosses.attack[0], t.attack_index(&"sweep"))


func test_aimed_attacks_lead_a_moving_player() -> void:
	var s := _boss(&"brood_mother", Vector2(8, 0))
	var w: World = s[0]
	var t := BossAi.table_of(w, s[1])
	assert_eq(t.lead_ticks, 21, "0.35 s")
	w.vel = Vector2(0, 0.1)  # 6 m/s across
	BossLab.start(w, s[1], &"leap")
	var d: Array = BossAi.leap_disc(w, s[1])
	assert_almost_eq((d[0] as Vector2).y, 0.1 * 21, 0.001, "the leap lands where you're going")
	# A sweep around itself doesn't lead.
	var g := _boss(&"gatekeeper", Vector2(2.5, 0))
	var gw: World = g[0]
	gw.vel = Vector2(0, 0.1)
	BossLab.start(gw, g[1], &"sweep")
	assert_eq(gw.actors.lock_a[g[1]], Kin.angle_of(Vector2(2.5, 0)))


func test_phase_two_is_more_aggressive() -> void:
	for t in BossLab.tables():
		assert_lt(t.phase_cd_permille[1], 700, "%s: phase 2 cooldowns" % t.id)


# --- the closing arena --------------------------------------------------------------------------------------------


## Boss `id` at the origin in a 30 m arena, held staggered (so it never attacks), the player beside it.
func _arena_world(id: StringName) -> Array:
	var s := _boss(id, Vector2(0, 4))
	var w: World = s[0]
	w.bosses.arena = Rect2(-15, -15, 30, 30)
	w.actors.state[s[1]] = BossAi.STAGGERED
	w.bosses.stagger_t[BossAi.entry_of(w, s[1])] = 99999
	return s


func test_the_arena_starts_closing_in_phase_two() -> void:
	var s := _arena_world(&"gatekeeper")
	var w: World = s[0]
	var aid: int = s[2]
	var t := BossAi.table_of(w, s[1])
	CombatLab.idle(w, 60)
	assert_eq(WorldReader.new(w).boss_arena_band(), {}, "phase 1, early: no band")
	var i := w.actors.index_of(aid)
	w.actors.hp[i] = w.actors.max_hp[i] / 2
	w.step(InputFrame.new())
	var bd := BossChallenge.band(w)
	assert_false(bd.is_empty(), "phase 2: it begins")
	assert_eq(bd["depth"], Vector2.ZERO, "nothing hurts yet")
	assert_eq(bd["warn"], -1)
	CombatLab.idle(w, t.close_step_ticks - t.close_warn_ticks)
	bd = BossChallenge.band(w)
	assert_eq(bd["warn"], 0, "the first step is marked")
	assert_eq(bd["next"], Vector2(1, 1))
	CombatLab.idle(w, t.close_warn_ticks - 1)
	bd = BossChallenge.band(w)
	assert_gt(bd["warn"], 950, "marked for its whole warning (%d ticks)" % t.close_warn_ticks)
	assert_gte(t.close_warn_ticks, SimTick.MIN_TELEGRAPH_TICKS)
	CombatLab.idle(w, 1)
	bd = BossChallenge.band(w)
	assert_eq(bd["depth"], Vector2(1, 1), "then it creeps in 1 m")


func test_the_arena_also_closes_after_45_seconds() -> void:
	var s := _arena_world(&"brood_mother")
	var w: World = s[0]
	var t := BossAi.table_of(w, s[1])
	assert_eq(t.close_after_ticks, 45 * 60)
	var b := BossAi.entry_of(w, s[1])
	w.bosses.fight_t[b] = t.close_after_ticks - 2
	w.actors.set_pos(0, Vector2(3, 3))
	w.step(InputFrame.new())
	assert_eq(w.bosses.close_t[b], 0)
	w.step(InputFrame.new())
	assert_gt(w.bosses.close_t[b], 0)


func test_the_band_is_capped_so_the_centre_stays_safe() -> void:
	var s := _arena_world(&"gatekeeper")
	var w: World = s[0]
	var t := BossAi.table_of(w, s[1])
	var arena := Rect2(-15, -15, 30, 8)
	assert_eq(BossChallenge.band_depth(arena, t, 100), Vector2(10, 0), "5 m short of the centre")
	assert_eq(BossChallenge.band_depth(arena, t, 3), Vector2(3, 0), "a narrow side never closes")


func test_standing_in_the_band_hurts_and_can_kill() -> void:
	var s := _arena_world(&"gatekeeper")
	var w: World = s[0]
	var b := BossAi.entry_of(w, s[1])
	var t := BossAi.table_of(w, s[1])
	w.bosses.close_t[b] = t.close_step_ticks * 3 + 1  # 3 m deep
	assert_eq(BossChallenge.band(w)["depth"], Vector2(3, 3))
	w.actors.set_pos(0, Vector2(0, 11.0))  # 1 m short of the band
	CombatLab.idle(w, 60)
	assert_eq(CombatLab.player_damage(w), [], "outside it: safe")
	for k in 150:
		w.actors.set_pos(0, Vector2(0, 12.5))
		w.step(InputFrame.new())
	var ticks := []
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
			assert_eq(e.amount_applied, t.hazard_damage)
			assert_eq(e.effect_id, &"arena_band")
			ticks.append(e.tick)
	assert_gte(ticks.size(), 3, "in the band it hurts again and again")
	for k in range(1, ticks.size()):
		assert_between(
			ticks[k] - ticks[k - 1],
			t.hazard_ticks,
			t.hazard_ticks + w.player.hurt_freeze_ticks,
			"every 0.5 s (plus the hurt's hit-stop)"
		)
	w.actors.hp[0] = 3
	CombatLab.idle(w, 31)
	assert_true(w.player_dead())
	assert_eq(WorldReader.new(w).killer_cause_key(), &"CAUSE_BOSS_ARENA")


# --- summoning ----------------------------------------------------------------------------------------------------


func test_summoning_dissolves_the_floors_enemies_without_kills_or_shards() -> void:
	var w := BossLab.world()
	var ids := []
	for k in [ActorStore.Kind.CHARGER, ActorStore.Kind.WARDEN, ActorStore.Kind.NEEDLE]:
		ids.append(w.add_enemy(k, Vector2(5 + ids.size() * 2, 4)))
	var seq := w.last_event_seq()
	assert_eq(BossChallenge.dissolve_floor(w), 3)
	assert_eq(w.actors.size(), 1, "only the player is left")
	var gone := w.events_since(seq).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.ENEMY_DISSOLVED
	)
	assert_eq(gone.map(func(e: SimEvent) -> int: return e.target_id), ids, "one event each")
	assert_eq(gone[1].amount, ActorStore.Kind.WARDEN, "with its kind")
	var killed := w.events_since(seq).filter(
		func(e: SimEvent) -> bool:
			return e.kind == SimEvent.Kind.KILL or e.kind == SimEvent.Kind.SHARDS
	)
	assert_eq(killed, [], "no kill, no shards")
	assert_eq(w.kills, 0)
	assert_eq(w.shards, 0)


func test_a_living_bosss_brood_stays() -> void:
	var s := _boss(&"brood_mother", Vector2(6, 0))
	var w: World = s[0]
	w.add_enemy(ActorStore.Kind.HATCHLING, Vector2(3, 3))
	assert_eq(BossChallenge.dissolve_floor(w), 0)
	assert_eq(w.actors.size(), 3)


func test_the_dev_panels_summon_clears_the_floor_too() -> void:
	var w := BossLab.world()
	w.add_enemy(ActorStore.Kind.CHARGER, Vector2(5, 5))
	var api := DebugApi.new(w)
	api.request_boss()
	var id := api.apply_pending()
	assert_gt(id, 0)
	assert_eq(w.actors.size(), 2, "the player and the boss")


# --- the rise (L22) -----------------------------------------------------------------------------------------------


func test_the_intro_progress_runs_over_the_rise() -> void:
	var w := BossLab.world()
	var id := w.spawn_boss(BossLab.table_index(w, &"gatekeeper"), Vector2(6, 0))
	var reader := WorldReader.new(w)
	assert_eq(reader.boss_intro_permille(w.actors.index_of(id)), 0, "empty as it appears")
	CombatLab.idle(w, BossAi.INTRO_TICKS / 2)
	assert_eq(reader.boss_intro_permille(w.actors.index_of(id)), 500, "half way")
	CombatLab.idle(w, BossAi.INTRO_TICKS / 2)
	assert_eq(reader.boss_intro_permille(w.actors.index_of(id)), 1000, "full as it acts")
