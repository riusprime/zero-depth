# gdlint: disable=max-public-methods
extends GutTest
## v0.11.0 F8 (owner 4.2; BossHazard): the bosses' arena hazards: warn then arm, the strict cap (count and cover),
## expiry, hero-only, the burn rate, the slow, the snapshot and the seed; the three bosses' hooks in their real attacks.

const LONG := 1 << 20
const PLAYER_FAR := Vector2(30, 30)
## A hit pauses the fight for a few ticks (the hero's hit-stop; measured 4): the burn's clock pauses with it, so a burn
## comes this many ticks of World.tick later than its period at most.
const HIT_STOP_SLACK := 6


func _fight(id: StringName, seed_value := 11, player_at := PLAYER_FAR) -> Array:
	var w := BossLab.world(seed_value)
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	# TEST HELPER: held staggered, so it never attacks unless a test starts one (BossLab.start).
	w.actors.state[i] = BossAi.STAGGERED
	w.bosses.stagger_t[BossAi.entry_of(w, i)] = LONG
	return [w, w.actors.ids[i]]


func _index(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _step(w: World, n: int) -> void:
	for k in n:
		w.step(InputFrame.new())


func _table(w: World, aid: int) -> HazardTable:
	return BossAi.table_of(w, _index(w, aid)).hazard


## A real run floor with boss `id`'s room, the hero through its door, the boss up (null: the fight did not begin).
func _real_room(run_seed: int, id: StringName) -> World:
	var w := FightLab.floor_world(run_seed, 1, &"guard", [], id)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	w.actors.invuln[0] = LONG
	FightLab.enter_boss_room(w)
	for k in 240:
		w.step(InputFrame.new())
		if w.boss_id >= 0:
			return w
	return null


func _spots(n: int, gap := 6.0) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in n:
		out.append(Vector2(-18.0 + gap * (k % 7), -18.0 + gap * (k / 7)))
	return out


func _hero_damage(w: World, tick_from: int) -> int:
	var sum := 0
	for e in w.events_since(0):
		if (
			e.kind == SimEvent.Kind.DAMAGE
			and e.target_id == w.actors.ids[0]
			and e.tick >= tick_from
		):
			sum += e.amount_applied
	return sum


func _burn_ticks(w: World, tick_from: int) -> Array:
	var out := []
	for e in w.events_since(0):
		if (
			e.kind == SimEvent.Kind.DAMAGE
			and e.target_id == w.actors.ids[0]
			and e.tick >= tick_from
		):
			out.append(e.tick)
	return out


## The gaps between the burns since tick_from are the period (plus the hit's pause); `amount` the DOT each.
func _assert_burn_rate(w: World, tick_from: int, period: int, amount: int) -> void:
	var ticks := _burn_ticks(w, tick_from)
	assert_gte(ticks.size(), 3, "it kept burning")
	for k in range(1, ticks.size()):
		var gap: int = ticks[k] - ticks[k - 1]
		assert_gte(gap, period, "never faster than its period")
		assert_lte(gap, period + HIT_STOP_SLACK, "a burn each period")
	assert_eq(_hero_damage(w, tick_from), ticks.size() * amount, "lava_damage each")


func _hero_hits(w: World, tick_from: int) -> int:
	var n := 0
	for e in w.events_since(0):
		if (
			e.kind == SimEvent.Kind.DAMAGE
			and e.target_id == w.actors.ids[0]
			and e.tick >= tick_from
		):
			n += 1
	return n


func test_the_three_bosses_compile_their_hazards_and_no_other_boss_has_one() -> void:
	var w := BossLab.world()
	var seen := []
	for t: BossTable in w.boss_tables:
		if t.hazard != null:
			seen.append(t.id)
	assert_eq(seen.size(), 3, "only the owner's three")
	for id: StringName in [&"brood_mother", &"foundry", &"siege_engine"]:
		assert_true(seen.has(id), "%s has one" % id)
	var f := w.boss_tables[BossLab.table_index(w, &"foundry")].hazard
	assert_eq([f.look, f.radius_m, f.life_ticks], [&"lava", 2.0, 1200])
	assert_eq([f.damage, f.burn_ticks, f.max_count, f.max_cover_permille], [6, 30, 6, 250])
	assert_eq(f.cause_key, &"CAUSE_FOUNDRY_POOL")
	var b := w.boss_tables[BossLab.table_index(w, &"brood_mother")].hazard
	assert_eq([b.look, b.life_ticks, b.damage, b.slow_permille], [&"venom", 900, 4, 800])
	assert_eq([b.radius_m, b.max_count, b.max_cover_permille], [1.8, 6, 250])
	var s := w.boss_tables[BossLab.table_index(w, &"siege_engine")].hazard
	assert_eq([s.look, s.kind, s.life_ticks, s.slow_permille], [&"rock", 1, 600, 600])
	assert_eq([s.radius_m, s.warn_ticks, s.max_count, s.damage], [2.0, 72, 8, 0])
	assert_eq(s.impact_damage, 30, "the rock lands at the boss's normal tier (its mortar's 30)")
	assert_eq(s.cause_key, &"CAUSE_SIEGE_ROCK")


# --- the cap --------------------------------------------------------------------------------------------------


func test_never_more_than_max_count_and_the_oldest_goes_first() -> void:
	var s := _fight(&"foundry")
	var w: World = s[0]
	var i := _index(w, s[1])
	var h := _table(w, s[1])
	var spots := _spots(h.max_count + 3)
	for k in spots.size():
		assert_true(BossHazard.place(w, i, spots[k]), "placed %d" % k)
		assert_lte(BossHazard.count_of(w, s[1]), h.max_count, "the count holds")
	assert_eq(BossHazard.count_of(w, s[1]), h.max_count)
	assert_eq(w.bosses.hz_x[0], spots[3].x, "the first three went first")


func test_the_cover_cap_removes_the_oldest_first() -> void:
	var s := _fight(&"foundry")
	var w: World = s[0]
	var i := _index(w, s[1])
	var h := _table(w, s[1])
	# A small room: 3 pools of 2 m cover 3 x 12.57 = 37.7 m² of 144: 26 %, over the 25 %: only two fit.
	w.bosses.arena = Rect2(-6, -6, 12, 12)
	var spots: Array[Vector2] = [Vector2(-3, -3), Vector2(3, 3), Vector2(-3, 3)]
	for p in spots:
		BossHazard.place(w, i, p)
	assert_eq(BossHazard.count_of(w, s[1]), 2, "the cover cap, not the count")
	assert_eq(Vector2(w.bosses.hz_x[0], w.bosses.hz_y[0]), spots[1], "the oldest went")
	assert_lte(BossHazard.cover_permille(w, s[1]), h.max_cover_permille)


func test_a_real_arena_stays_at_least_60_percent_clear() -> void:
	var lowest := 1000
	var rooms := 0
	for id: StringName in [&"foundry", &"brood_mother", &"siege_engine"]:
		for run_seed in 12:
			var w := _real_room(1000 + run_seed * 37, id)
			if w == null:
				continue
			rooms += 1
			var i := w.actors.index_of(w.boss_id)
			var h := BossAi.table_of(w, i).hazard
			var room := w.bosses.arena
			var rng := RngStream.new(run_seed + 5)
			var placed := 0
			for k in 80:  # far past the cap: every place keeps both caps
				var p := Vector2(
					room.position.x + rng.range_int(0, 1000) * 0.001 * room.size.x,
					room.position.y + rng.range_int(0, 1000) * 0.001 * room.size.y
				)
				if BossHazard.place(w, i, p):
					placed += 1
			assert_gt(placed, 0, "%s: some placed" % id)
			assert_lte(BossHazard.count_of(w, w.boss_id), h.max_count, "%s: count" % id)
			assert_lte(
				BossHazard.cover_permille(w, w.boss_id), h.max_cover_permille, "%s: cover" % id
			)
			lowest = mini(lowest, _clear_permille(w))
	assert_gte(rooms, 30, "real boss rooms were built")
	gut.p(
		(
			"F8: lowest uncovered share over %d rooms: %d permille of the walkable floor"
			% [rooms, lowest]
		)
	)
	assert_gte(lowest, 600, "at least 60 % of the floor stays clear")


## The share of the arena's walkable field cells (per mille) outside every hazard.
func _clear_permille(w: World) -> int:
	var room := w.bosses.arena
	var nav := w.nav
	var bs := w.bosses
	var free := 0
	var clear := 0
	var c0 := nav.cell_of(room.position)
	var c1 := nav.cell_of(room.end)
	for y in range(maxi(c0.y, 0), mini(c1.y + 1, nav.size.y)):
		for x in range(maxi(c0.x, 0), mini(c1.x + 1, nav.size.x)):
			var p := nav.center(Vector2i(x, y))
			if not room.has_point(p) or nav.blocked[y * nav.size.x + x] != 0:
				continue
			free += 1
			var inside := false
			for k in bs.hz_x.size():
				inside = inside or Kin.length(p - Vector2(bs.hz_x[k], bs.hz_y[k])) <= bs.hz_r[k]
			clear += 0 if inside else 1
	return clear * 1000 / maxi(1, free)


func test_a_hazard_is_never_in_the_doorway() -> void:
	var w := _real_room(1001, &"foundry")
	assert_not_null(w, "the fight began")
	var i := w.actors.index_of(w.boss_id)
	var door: Vector2 = BossLava.exits(w)[0]
	assert_false(BossHazard.place(w, i, door), "not on the door")
	assert_true(BossHazard.in_doorway(w, door, 2.0))
	assert_eq(w.bosses.hz_x.size(), 0, "none placed")


# --- arming, lifetime ------------------------------------------------------------------------------------------


func test_it_warns_first_then_arms_then_ends() -> void:
	var s := _fight(&"foundry", 11, Vector2(4, 0))
	var w: World = s[0]
	var i := _index(w, s[1])
	var h := _table(w, s[1])
	var before := w.tick
	assert_true(BossHazard.place(w, i, Vector2(4, 0)), "placed under the hero")
	var rows := WorldReader.new(w).boss_hazards()
	assert_eq(rows.size(), 1)
	assert_false(rows[0]["armed"], "warning first, even under the hero's feet")
	_step(w, h.warn_ticks - 1)
	assert_eq(_hero_hits(w, before), 0, "no burn during the warning")
	_step(w, 2)
	assert_true(WorldReader.new(w).boss_hazards()[0]["armed"], "armed after its warning")
	assert_gt(_hero_hits(w, before), 0, "it burns once armed")
	_step(w, h.life_ticks)
	assert_eq(WorldReader.new(w).boss_hazards().size(), 0, "gone after its life")


func test_the_warning_lasts_the_telegraph_minimum() -> void:
	var w := BossLab.world()
	for t: BossTable in w.boss_tables:
		if t.hazard != null:
			assert_gte(t.hazard.warn_ticks, SimTick.MIN_TELEGRAPH_TICKS, "%s" % t.id)


func test_the_burn_is_one_tick_per_period_however_many_overlap() -> void:
	var s := _fight(&"foundry", 11, Vector2(4, 0))
	var w: World = s[0]
	var i := _index(w, s[1])
	var h := _table(w, s[1])
	BossHazard.place(w, i, Vector2(4, 0))
	BossHazard.place(w, i, Vector2(4.5, 0))
	_step(w, h.warn_ticks + 2)
	var from := w.tick
	_step(w, 300)
	_assert_burn_rate(w, from, h.burn_ticks, BossAi.powered(w, i, h.damage))


func test_a_hero_outside_is_untouched_and_enemies_never_are() -> void:
	var s := _fight(&"foundry", 11, Vector2(12, 0))
	var w: World = s[0]
	var i := _index(w, s[1])
	var h := _table(w, s[1])
	BossHazard.place(w, i, Vector2.ZERO)  # under the boss
	w.actors.max_hp[i] = LONG
	w.actors.hp[i] = LONG
	var from := w.tick
	_step(w, h.warn_ticks + 120)
	assert_eq(_hero_hits(w, from), 0, "the hero is outside")
	assert_eq(w.actors.hp[i], LONG, "the boss on it takes nothing")
	assert_true(w.nav.extra.is_empty(), "nothing in the flow field")


func test_the_slow_applies_only_while_armed_and_inside() -> void:
	var s := _fight(&"siege_engine", 11, Vector2(4, 0))
	var w: World = s[0]
	var i := _index(w, s[1])
	var h := _table(w, s[1])
	BossHazard.place(w, i, Vector2(4, 0))
	assert_eq(BossHazard.move_factor(w), 1.0, "warning: not yet")
	_step(w, h.warn_ticks + 1)
	assert_eq(BossHazard.move_factor(w), 0.6, "armed: x0.6")
	w.actors.set_pos(0, Vector2(9, 0))
	assert_eq(BossHazard.move_factor(w), 1.0, "outside: none")


func test_venom_both_burns_and_slows() -> void:
	var s := _fight(&"brood_mother", 11, Vector2(4, 0))
	var w: World = s[0]
	var i := _index(w, s[1])
	var h := _table(w, s[1])
	BossHazard.place(w, i, Vector2(4, 0))
	_step(w, h.warn_ticks + 1)
	var from := w.tick
	_step(w, 240)
	_assert_burn_rate(w, from, h.burn_ticks, BossAi.powered(w, i, h.damage))
	assert_eq(BossHazard.move_factor(w), 0.8, "and x0.8")


func test_a_slow_rock_zone_truly_slows_the_walk() -> void:
	var s := _fight(&"siege_engine", 11, Vector2(4, 0))
	var w: World = s[0]
	var i := _index(w, s[1])
	var h := _table(w, s[1])
	BossHazard.place(w, i, Vector2(4, 0))
	_step(w, h.warn_ticks + 2)
	var f := InputFrame.make(Vector2i(127, 0), 0, 300, 0, 0)
	var start := w.actors.pos(0).x
	for k in 30:
		w.step(f)
		if k == 0:
			start = w.actors.pos(0).x
	var slow := w.actors.pos(0).x - start
	var s2 := _fight(&"siege_engine", 11, Vector2(4, 0))
	var w2: World = s2[0]
	var start2 := w2.actors.pos(0).x
	for k in 30:
		w2.step(f)
		if k == 0:
			start2 = w2.actors.pos(0).x
	var free := w2.actors.pos(0).x - start2
	assert_almost_eq(slow / free, 0.6, 0.06, "the walk at x0.6 inside")


func test_they_go_with_their_boss() -> void:
	var s := _fight(&"foundry")
	var w: World = s[0]
	BossHazard.place(w, _index(w, s[1]), Vector2(3, 0))
	BossSignatures.on_boss_gone(w, s[1])
	assert_eq(w.bosses.hz_x.size(), 0, "cleared with its boss")


func test_a_rock_lands_once_on_the_tick_it_arms_and_only_there() -> void:
	var s := _fight(&"siege_engine", 11, Vector2(4, 0))
	var w: World = s[0]
	var i := _index(w, s[1])
	var h := _table(w, s[1])
	BossHazard.place(w, i, Vector2(4, 0))
	var from := w.tick
	_step(w, h.warn_ticks - 1)
	assert_eq(_hero_hits(w, from), 0, "nothing during the ring")
	_step(w, 2)
	assert_eq(_hero_hits(w, from), 1, "the rock lands once")
	_step(w, 200)
	assert_eq(_hero_hits(w, from), 1, "the zone itself never burns")


# --- hooks ---------------------------------------------------------------------------------------------------


func test_the_foundrys_flood_leaves_pools_on_its_lanes() -> void:
	var s := _fight(&"foundry", 11, Vector2(8, 3))
	var w: World = s[0]
	var i := _index(w, s[1])
	w.actors.state[i] = EnemyAi.State.MOVE
	w.actors.state_t[i] = 0
	BossLab.start(w, i, &"molten_flood")
	for k in 400:  # (a hit pauses the fight: as long as it takes)
		w.step(InputFrame.new())
		if not w.bosses.hz_x.is_empty():
			break
	assert_gt(w.bosses.hz_x.size(), 0, "a pool stayed")
	assert_lte(w.bosses.hz_x.size(), BossAi.table_of(w, i).hazard.per_attack, "at most per_attack")
	for k in w.bosses.hz_x.size():
		var p := Vector2(w.bosses.hz_x[k], w.bosses.hz_y[k])
		var near := false
		for r in BossLava.rects(w):
			near = near or absf(r.get_center().y - p.y) < 0.01
		assert_true(near, "on a lane")


func test_an_egg_storm_leaves_one_pool_where_its_chosen_egg_bursts() -> void:
	var s := _fight(&"brood_mother", 11, Vector2(8, 3))
	var w: World = s[0]
	var i := _index(w, s[1])
	w.actors.state[i] = EnemyAi.State.MOVE
	w.actors.state_t[i] = 0
	BossLab.start(w, i, &"egg_storm")
	var a := BossAi.attack_of(w, i)
	var eggs_at: Array[Vector2] = []
	var limit := a.windup_ticks + a.count * a.mark_gap_ticks + a.egg_ticks + 30
	for k in limit:
		w.step(InputFrame.new())
		for j in w.actors.size():
			if BossSignatures.is_egg(w, j) and not eggs_at.has(w.actors.pos(j)):
				eggs_at.append(w.actors.pos(j))
	assert_gt(eggs_at.size(), 1, "more than one egg landed")
	assert_eq(w.bosses.hz_x.size(), 1, "exactly one pool a storm")
	assert_true(
		eggs_at.has(Vector2(w.bosses.hz_x[0], w.bosses.hz_y[0])), "where one of its eggs lay"
	)


func test_a_broken_chosen_egg_leaves_no_pool() -> void:
	var s := _fight(&"brood_mother", 11, Vector2(8, 3))
	var w: World = s[0]
	var i := _index(w, s[1])
	w.actors.state[i] = EnemyAi.State.MOVE
	w.actors.state_t[i] = 0
	BossLab.start(w, i, &"egg_storm")
	var a := BossAi.attack_of(w, i)
	var limit := a.windup_ticks + a.count * a.mark_gap_ticks + a.egg_ticks + 30
	for k in limit:
		w.step(InputFrame.new())
		for e in w.bosses.hz_egg:  # TEST HELPER: breaks the chosen egg as soon as it lies
			var j := w.actors.index_of(e)
			if j >= 0:
				w.actors.dead[j] = 1
				w.actors.hp[j] = 0
	assert_eq(w.bosses.hz_x.size(), 0, "no pool from a broken chosen egg")


func test_the_siege_engines_mortar_ends_with_a_rock_on_the_hero() -> void:
	var s := _fight(&"siege_engine", 11, Vector2(8, 3))
	var w: World = s[0]
	var i := _index(w, s[1])
	w.actors.state[i] = EnemyAi.State.MOVE
	w.actors.state_t[i] = 0
	BossLab.start(w, i, &"mortar_grid")
	for k in 400:  # (a hit pauses the fight: as long as it takes)
		w.step(InputFrame.new())
		if not w.bosses.hz_x.is_empty():
			break
	assert_eq(w.bosses.hz_x.size(), 1, "one rock on the last volley")
	var c := Vector2(w.bosses.hz_x[0], w.bosses.hz_y[0])
	assert_almost_eq(c.distance_to(w.player_pos()), 0.0, 0.05, "where the hero stands")
	assert_false(WorldReader.new(w).boss_hazards()[0]["armed"], "warning first")


func test_the_cover_cap_holds_while_a_boss_keeps_laying() -> void:
	var s := _fight(&"foundry", 11, Vector2(8, 3))
	var w: World = s[0]
	var i := _index(w, s[1])
	w.bosses.arena = Rect2(-15, -15, 30, 30)
	var h := _table(w, s[1])
	for k in 40:
		BossHazard.place(w, i, Vector2(-12 + (k % 8) * 3.5, -12 + (k % 5) * 5.0))
		assert_lte(BossHazard.count_of(w, s[1]), h.max_count)
		assert_lte(BossHazard.cover_permille(w, s[1]), h.max_cover_permille)


# --- recap, snapshot, seed -------------------------------------------------------------------------------------


func test_the_recap_names_the_hazard_in_both_languages() -> void:
	var rc := ReadableCause.new(BossLab.world())
	var w: World
	for id: StringName in [&"foundry", &"brood_mother", &"siege_engine"]:
		var s := _fight(id, 11, Vector2(4, 0))
		w = s[0]
		rc = ReadableCause.new(w)
		var i := _index(w, s[1])
		var h := _table(w, s[1])
		w.actors.hp[0] = 1
		w.actors.max_hp[0] = 1
		BossHazard.place(w, i, Vector2(4, 0))
		for k in h.warn_ticks + 3:
			w.step(InputFrame.new())
			rc.observe(w)
		assert_true(w.player_dead(), "%s kills" % id)
		assert_eq(WorldReader.new(w).killer_cause_key(), h.cause_key, "%s: recap" % id)
		assert_eq(rc.last_cause, String(h.cause_key), "%s: readable" % id)
		assert_eq(rc.violations.size(), 0, "%s: no unreadable hit" % id)


func test_a_snapshot_keeps_them() -> void:
	var s := _fight(&"foundry", 11, Vector2(4, 0))
	var w: World = s[0]
	var i := _index(w, s[1])
	BossHazard.place(w, i, Vector2(4, 0))
	BossHazard.place(w, i, Vector2(-4, 0))
	_step(w, 20)
	var snap := WorldSnapshot.take(w)
	var hash_a := w.state_hash()
	var back := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), BossLab.world(11))
	assert_not_null(back, "restores")
	if back == null:
		return
	assert_eq(back.state_hash(), hash_a, "the restored world hashes the same")
	assert_eq(back.bosses.hz_x, w.bosses.hz_x)
	_step(w, 120)
	_step(back, 120)
	assert_eq(back.state_hash(), w.state_hash(), "and runs on the same")


func test_an_untouched_world_hashes_as_before() -> void:
	var w := BossLab.world(7)
	assert_eq(w.bosses.hz_next, 0)
	var h1 := w.state_hash()
	w.bosses.hz_burn_cd = 0
	assert_eq(w.state_hash(), h1)


func test_same_seed_same_hazards() -> void:
	var run := func(seed_value: int) -> Array:
		var w := BossLab.world(seed_value)
		var i := BossLab.ready_boss(w, &"foundry", Vector2.ZERO)
		w.actors.set_pos(0, Vector2(6, 2))
		w.actors.hp[0] = LONG
		w.actors.max_hp[0] = LONG
		w.actors.invuln[0] = LONG
		var aid := w.actors.ids[i]
		for k in 3600:
			w.step(InputFrame.new())
		return [w.state_hash(), w.bosses.hz_x.size(), w.bosses.hz_next, BossHazard.count_of(w, aid)]
	var a: Array = run.call(21)
	var b: Array = run.call(21)
	assert_eq(a, b, "the same seed, the same hazards and hash")
	assert_gt(a[2], 0, "the fight laid some")
