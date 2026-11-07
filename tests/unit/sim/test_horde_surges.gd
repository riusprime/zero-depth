extends GutTest
## v0.11.0 O9 (PLAN H1, M4; ENEMIES.md H1-H5; owner Q14, Q15, Q16): the horde critters and their surges. A critter hurts
## by touch only (no windup), contact_damage at most every contact_cd_ticks; the Cave Bat flies over the floor's
## hazards. Once or twice a floor the spawner sends a surge of the biome's critter: 30-60 over 10 s, a SURGE event
## first, never while the hero is in an Overrun room or a Lockdown, never above the spawner's hard cap; its plan comes
## from its own stream (no other stream moves) and a save mid-surge resumes it exactly.

const LONG := 1 << 24
const KIND := ActorStore.Kind


## A wall-less world with the real enemies, rings of spawn points at 9 m and 12 m and the real floor-1 spawner (its
## surges included); the floor's critter the Dust Mite.
func _world(seed_value: int = 11) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	for r in [9.0, 12.0]:
		for k in 8:
			w.spawn_points.append(Kin.dir(k * 512) * r)
	w.spawner = ContentCompiler.compile_floor_spawning(ContentRepository.load_all(), 1)
	w.floor_index = 1
	w.critter_kind = KIND.DUST_MITE
	w.actors.invuln[0] = LONG
	return w


func _kill_all(w: World) -> void:
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0:
			w.actors.invuln[i] = 0
			Damage.hit(w, i, 99999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))


func _surge_events(w: World, since: int) -> Array:
	return w.events_since(since).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.SURGE
	)


## Steps until the floor's first surge begins (at most `limit` ticks); returns the SURGE event (null if none).
func _to_first_surge(w: World, limit: int, kill: bool) -> SimEvent:
	for t in limit:
		var seq := w.last_event_seq()
		w.step(InputFrame.new())
		var ev := _surge_events(w, seq)
		if not ev.is_empty():
			return ev[0]
		if kill:
			_kill_all(w)
	return null


func _critters_alive(w: World) -> int:
	var n := 0
	for i in range(1, w.actors.size()):
		if EnemyAi.is_critter(w.actors.kinds[i]) and w.actors.dead[i] == 0:
			n += 1
	return n


func test_the_plan_is_once_or_twice_a_floor_from_its_own_stream() -> void:
	var counts := {}
	var t := _world().spawner.surge
	for s in range(1, 41):
		var w := _world(s)
		var map_before := w.rng_map.state
		var ai_before := w.rng_ai.state
		Surges.plan(w, t)
		assert_eq(
			[w.rng_map.state, w.rng_ai.state],
			[map_before, ai_before],
			"seed %d: no other stream moves" % s
		)
		var n := w.surge_at.size()
		counts[n] = int(counts.get(n, 0)) + 1
		assert_true(n >= 1 and n <= 2, "seed %d: once or twice (%d)" % [s, n])
		assert_true(
			w.surge_at[0] >= 40 * 60 and w.surge_at[0] <= 80 * 60,
			"seed %d: the first 40-80 s in" % s
		)
		for k in n:
			assert_true(
				w.surge_sizes[k] >= 30 and w.surge_sizes[k] <= 60,
				"seed %d: 30-60 (%d)" % [s, w.surge_sizes[k]]
			)
		if n == 2:
			assert_gte(
				w.surge_at[1] - w.surge_at[0],
				600 + 60 * 60,
				"seed %d: the second a minute past the first" % s
			)
		var again := _world(s)
		Surges.plan(again, t)
		assert_eq(
			[again.surge_at, again.surge_sizes],
			[w.surge_at, w.surge_sizes],
			"seed %d: deterministic" % s
		)
	assert_true(counts.has(1) and counts.has(2), "both happen over 40 seeds: %s" % counts)


func test_a_surge_brings_its_size_in_critters_over_10_s_after_its_cue() -> void:
	var w := _world()
	var ev := _to_first_surge(w, 90 * 60, true)
	assert_not_null(ev, "a surge began within 90 s")
	if ev == null:
		return
	var size := w.surge_sizes[0]
	assert_eq(ev.amount, size, "the cue carries its size")
	assert_true(size >= 30 and size <= 60, "30-60 (%d)" % size)
	var start := w.tick
	var arrivals := PackedInt32Array()
	var seen := {}
	for t in 700:
		for i in range(1, w.actors.size()):
			if w.actors.kinds[i] == KIND.DUST_MITE and not seen.has(w.actors.ids[i]):
				seen[w.actors.ids[i]] = true
				arrivals.append(w.tick - start)
		_kill_all(w)
		w.step(InputFrame.new())
	assert_eq(arrivals.size(), size, "all of it came (nothing held it)")
	assert_lt(arrivals[arrivals.size() - 1], 600, "within its 10 s")
	var early := 0
	for a in arrivals:
		early += 1 if a < 300 else 0
	assert_true(
		early > size / 4 and early < size * 3 / 4,
		"spread over the window, not one burst (%d early)" % early
	)
	assert_false(Surges.running(w), "its window closed")
	assert_eq(w.surge_next, 1)


func test_at_most_twice_a_floor() -> void:
	var w := _world(5)
	var t := w.spawner.surge
	t.surges_min = 2
	t.surges_max = 2
	t.first_min_ticks = 30
	t.first_max_ticks = 30
	t.gap_min_ticks = 30
	t.gap_max_ticks = 30
	t.size_min = 30
	t.size_max = 30
	var seq := w.last_event_seq()
	for k in 4000:
		w.step(InputFrame.new())
		_kill_all(w)
	assert_eq(_surge_events(w, seq).size(), 2, "two surges, then none")
	assert_eq(Surges.started(w), 2)


## v0.11.0 O9b (owner Q16-b: "Optimise, then cap"); v0.11.0 O9c (Q16-c: "Batch now"): the shipped surge stops at 120
## enemies alive (the batched critters held 144 fps with 120 alive on the idle owner's PC), however big the surge.
func test_the_shipped_surge_stops_at_120_alive() -> void:
	var w := _world(7)
	var t := w.spawner.surge
	assert_eq(t.alive_cap, 120, "surge.tres's cap")
	t.first_min_ticks = 30
	t.first_max_ticks = 30
	t.size_min = 60
	t.size_max = 60
	for k in 70:  # 70 standing enemies first: the surge brings the floor to 120, not 130
		var id := w.add_enemy(KIND.WARDEN, Vector2(20.0 + (k % 10), 20.0 + (k / 10)))
		w.actors.invuln[w.actors.index_of(id)] = LONG
	var most := 0
	for k in 800:
		w.step(InputFrame.new())
		most = maxi(most, WaveDirector.enemies_alive(w))
	assert_eq(most, 120, "it filled to the cap and no further")


func test_a_surge_may_pass_the_floor_cap_but_never_the_hard_cap() -> void:
	var w := _world(7)
	var t := w.spawner.surge
	t.alive_cap = SurgeDefinition.HARD_CAP  # v0.11.0 O9b: the shipped cap is 50 (below); this one is the hard cap's
	t.first_min_ticks = 30
	t.first_max_ticks = 30
	t.size_min = 60
	t.size_max = 60
	for k in 100:  # fill the floor near the hard cap with standing enemies
		var id := w.add_enemy(KIND.WARDEN, Vector2(20.0 + (k % 10), 20.0 + (k / 10)))
		w.actors.invuln[w.actors.index_of(id)] = LONG
	var most := 0
	for k in 800:
		w.step(InputFrame.new())
		most = maxi(most, WaveDirector.enemies_alive(w))
	assert_gt(most, w.spawner.cap_now(1, w.run_ticks), "above the floor's normal cap")
	assert_lte(most, w.spawner.cap_max, "never above the hard cap (%d)" % w.spawner.cap_max)
	assert_eq(most, 120, "it filled to the cap")
	assert_lt(_critters_alive(w), 60, "so some of the 60 were dropped")


func test_never_during_a_lockdown() -> void:
	var w := LockLab.world()
	assert_not_null(w, "a floor with a Lockdown")
	if w == null:
		return
	w.critter_kind = KIND.DUST_MITE
	LockLab.enter(w, LockLab.room(w))
	assert_true(Lockdowns.holds_spawns(w), "sealed")
	assert_true(Surges.held(w), "held while sealed")
	w.surge_at = PackedInt32Array([w.run_ticks])  # due now
	w.surge_sizes = PackedInt32Array([40])
	var seq := w.last_event_seq()
	var sealed_ticks := 0
	for k in 600:
		if not Lockdowns.holds_spawns(w):
			break
		w.step(InputFrame.new())
		sealed_ticks += 1
	assert_gt(sealed_ticks, 120, "it stayed sealed a while")
	if Lockdowns.holds_spawns(w):
		assert_eq(_surge_events(w, seq).size(), 0, "no surge while sealed")
		assert_eq(_critters_alive(w), 0, "no critter came in")
		assert_eq(w.surge_next, 0, "the surge still waits")
	w.overrun.inside = true
	assert_true(Surges.held(w), "inside the Overrun")


func test_never_in_an_overrun_room() -> void:
	var w: World = null
	for s in range(1, 80):
		var c := SaveLab.floor_world(s, 2)
		if c.floor_layout.overrun_room >= 0:
			w = c
			break
	assert_not_null(w, "a floor with an Overrun room")
	if w == null:
		return
	w.critter_kind = KIND.DUST_MITE
	w.actors.invuln[0] = LONG
	if w.boss_flow != null:
		w.boss_flow.arrive_left = 0
	var r := w.floor_layout.overrun_room
	w.actors.set_pos(0, w.floor_layout.rooms[r].get_center())
	assert_true(Surges.held(w), "the hero stands in the Overrun room")
	assert_true(Surges.barred_room(w.floor_layout, r))
	w.actors.set_pos(0, w.floor_layout.start_pos)
	assert_false(Surges.held(w), "the start hall holds nothing")
	w.surge_at = PackedInt32Array([1])
	w.surge_sizes = PackedInt32Array([40])
	var seen := {}
	var arrived := 0
	for k in 650:
		w.step(InputFrame.new())
		for i in range(1, w.actors.size()):
			if EnemyAi.is_critter(w.actors.kinds[i]) and not seen.has(w.actors.ids[i]):
				seen[w.actors.ids[i]] = true
				arrived += 1
				var room := w.floor_layout.room_of(w.actors.pos(i))
				assert_false(
					Surges.barred_room(w.floor_layout, room),
					"a critter arrived in barred room %d" % room
				)
	assert_eq(Surges.started(w), 1, "the surge ran outside it")
	assert_gt(arrived, 0, "and brought critters")


func test_a_critter_hurts_by_touch_with_a_cooldown_and_no_windup() -> void:
	var w := CombatLab.world()
	w.player.hurt_iframe_ticks = 0  # the hero's own i-frames off: the critter's clock alone
	w.player.hurt_freeze_ticks = 0  # and the hit-stop (it holds every clock a few ticks)
	var id := w.add_enemy(KIND.DUST_MITE, Vector2(1.5, 0.0))
	var t := w.enemy_table(KIND.DUST_MITE)
	var hits := PackedInt32Array()
	var seq := w.last_event_seq()
	for k in 200:
		w.step(InputFrame.new())
		var i := w.actors.index_of(id)
		assert_ne(w.actors.state[i], EnemyAi.State.WINDUP, "never a windup")
		for e in w.events_since(seq):
			seq = e.seq
			if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
				hits.append(e.tick)
				assert_eq(e.owner_id, id)
				assert_eq(e.amount, t.damage)
	assert_gte(hits.size(), 3, "it kept touching")
	for k in range(1, hits.size()):
		assert_eq(
			hits[k] - hits[k - 1], t.contact_cd_ticks, "one touch per %d ticks" % t.contact_cd_ticks
		)
	assert_eq(EndPanel.CAUSES[KIND.DUST_MITE], "CAUSE_DUST_MITE", "its recap line")


func test_the_bat_flies_over_the_hero_s_ground_mines() -> void:
	var w := CombatLab.world()
	var bat := w.add_enemy(KIND.CAVE_BAT, Vector2(4, 0))
	var mite := w.add_enemy(KIND.DUST_MITE, Vector2(-4, 0))
	w.step(InputFrame.new())  # the actor grid the mines query is built each tick
	assert_true(EnemyAi.flies(w, w.actors.index_of(bat)), "the Cave Bat flies")
	assert_false(
		LaserMods._grounded_near(w, w.actors.pos(w.actors.index_of(bat)), 0.5),
		"a mine under it stays unset"
	)
	assert_false(EnemyAi.flies(w, w.actors.index_of(mite)))
	assert_true(
		LaserMods._grounded_near(w, w.actors.pos(w.actors.index_of(mite)), 0.5),
		"a mite sets one off"
	)
	for k in [KIND.EMBER_FLEA, KIND.ICE_CRAB, KIND.STAR_MOTE]:
		assert_false(w.enemy_table(k).flies, "only the bat flies (%d)" % k)


func test_the_same_seed_gives_the_same_surge_and_a_save_resumes_it() -> void:
	var a := _world(13)
	var b := _world(13)
	for w: World in [a, b]:
		w.spawner.surge.first_min_ticks = 60
		w.spawner.surge.first_max_ticks = 60
	for k in 300:
		a.step(InputFrame.new())
		b.step(InputFrame.new())
	assert_true(Surges.running(a), "mid-surge")
	assert_eq(a.state_hash(), b.state_hash(), "deterministic")
	var base := _world(13)
	base.spawner = a.spawner
	assert_eq(WorldSnapshot.apply(base, WorldSnapshot.take(a)), "", "the snapshot fits")
	for k in 400:
		a.step(InputFrame.new())
		base.step(InputFrame.new())
	assert_eq(base.state_hash(), a.state_hash(), "the restored surge runs on exactly")
	assert_eq(base.surge_next, 1)


## v0.11.0 O9c (owner Q16-c): the critters' fast path (CritterAi) is deterministic: two worlds with the same seed and a
## crowd of 120 critters packed round the hero hash the same tick for tick, and the crowd chases and touches the hero.
func test_a_120_critter_crowd_is_deterministic_on_the_fast_path() -> void:
	var worlds: Array[World] = [_world(17), _world(17)]
	for w in worlds:
		w.spawner.surge.surges_min = 0
		w.spawner.surge.surges_max = 0
		for k in 120:
			var id := w.add_enemy(KIND.DUST_MITE, Kin.dir(k * 4096 / 120) * (2.0 + (k % 6) * 0.8))
			w.actors.invuln[w.actors.index_of(id)] = LONG
	var touches := 0
	for t in 600:
		var seq := worlds[0].last_event_seq()
		for w in worlds:
			w.step(InputFrame.new())
		for e: SimEvent in worlds[0].events_since(seq):
			touches += (
				1 if e.kind == SimEvent.Kind.HIT and e.target_id == worlds[0].actors.ids[0] else 0
			)
		if t % 60 == 59:
			assert_eq(worlds[0].state_hash(), worlds[1].state_hash(), "tick %d" % worlds[0].tick)
	assert_gt(touches, 10, "the crowd reached the hero and touched it (%d)" % touches)
	var near := 0
	for i in range(1, worlds[0].actors.size()):
		near += 1 if Kin.length(worlds[0].actors.pos(i)) < 2.0 else 0
	assert_gt(near, 10, "a crowd round the hero (%d within 2 m)" % near)
