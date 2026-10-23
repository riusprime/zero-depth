extends GutTest
## v0.9.0 FV (owner Q24, "we are gonna be making the game 5 floors … we need to adjust difficulty scaling and loot to 5
## floors"; PD-03 changed): a run is five floors of about 10, 13, 15, 17 and 19 rooms plus the boss room; today's
## curve stretched so floor 5 ends where floor 3 ended; wand slots 4, 5, 6, 7, 8; all five biomes once each; altars and
## chests by the floor's rooms; floors 4 and 5 meet a boss the run has not met yet; the Ascension portal on floor 5.
## The v0.8.0 shape (three_floors) stays loadable for old saves (test_old_saves).

const SEEDS := 1000
const LONG := 1 << 24
const ROOMS_MIN := [9, 12, 14, 16, 18]
const ROOMS_MAX := [11, 14, 16, 18, 19]

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _table(id: StringName = RunSaver.RUN_ID) -> RunTable:
	return ContentCompiler.compile_run(_repo.get_def(&"run", id))


func test_the_run_is_five_floors_with_the_stretched_curve() -> void:
	var t := _table()
	assert_eq(t.id, &"five_floors")
	assert_eq(t.floors, 5)
	assert_eq(t.enemy_hp_floor_permille, PackedInt32Array([1000, 1380, 1900, 2620, 3610]))
	assert_eq(t.enemy_damage_floor_permille, PackedInt32Array([1000, 1180, 1400, 1660, 1960]))
	assert_eq(t.boss_hp_per_floor_permille, 200, "boss +20 % HP a floor: 1.8 on floor 5")
	assert_eq(t.boss_damage_per_floor_permille, 100, "boss +10 % damage a floor: 1.4 on 5")
	assert_eq(t.rooms_min_by_floor, PackedInt32Array(ROOMS_MIN))
	assert_eq(t.rooms_max_by_floor, PackedInt32Array(ROOMS_MAX))
	assert_eq(t.heal_permille, 600, "v0.9.0 SV: 60 % between floors (was 40 %)")
	assert_eq(t.shard_carry_permille, 500)
	assert_eq(t.final_arena, &"hollow_arena", "the final arena stays")
	var old := _table(RunSaver.LEGACY_RUN_ID)
	assert_eq(old.floors, 3, "the v0.8.0 shape stays loadable for old saves")
	assert_eq(old.enemy_hp_floor_permille, PackedInt32Array([1000, 1900, 3610]))
	assert_true(old.rooms_min_by_floor.is_empty(), "its floors keep data/map's 15-19 rooms")


## Floor 5 ends where floor 3 ended: an enemy of 1000 HP and 1000 damage on floors 1-5; a boss +20 % HP and +10 %
## damage a floor, floor 1's boss eased to 800 per mille.
func test_enemies_and_bosses_scale_per_floor() -> void:
	var hp := [1000, 1380, 1900, 2620, 3610]
	var dmg := [1000, 1180, 1400, 1660, 1960]
	for f in range(1, 6):
		var r := RunState.start(3, _table())
		r.floor_index = f
		var e := EnemyTable.new()
		e.hp = 1000
		e.damage = 1000
		var list: Array[EnemyTable] = [e]
		r.scale_enemies(list)
		assert_eq(e.hp, hp[f - 1], "floor %d enemy HP" % f)
		assert_eq(e.damage, dmg[f - 1], "floor %d enemy damage" % f)
		var bosses := ContentCompiler.compile_bosses(_repo)
		var base := ContentCompiler.compile_bosses(_repo)
		r.scale_bosses(bosses)
		var ease := 800 if f == 1 else 1000
		var hp_pm := (1000 + 200 * (f - 1)) * ease / 1000
		var dmg_pm := (1000 + 100 * (f - 1)) * ease / 1000
		for k in bosses.size():
			if base[k].mimic:
				continue
			assert_eq(bosses[k].hp, maxi(1, base[k].hp * hp_pm / 1000), "floor %d boss HP" % f)
			if not base[k].attacks.is_empty():
				var want := base[k].attacks[0].damage * dmg_pm / 1000
				assert_eq(bosses[k].attacks[0].damage, want, "floor %d boss damage" % f)
	var last := RunState.start(3, _table())
	last.floor_index = 5
	var old := RunState.start(3, _table(RunSaver.LEGACY_RUN_ID))
	old.floor_index = 3
	var a := EnemyTable.new()
	a.hp = 1000
	var b := EnemyTable.new()
	b.hp = 1000
	var la: Array[EnemyTable] = [a]
	var lb: Array[EnemyTable] = [b]
	last.scale_enemies(la)
	old.scale_enemies(lb)
	assert_eq(a.hp, b.hp, "floor 5 now is floor 3 then")


func test_the_wand_grows_one_slot_a_floor() -> void:
	var w := WandCompiler.for_run(_repo, _table())
	for f in range(1, 6):
		assert_eq(w.slots_at(f), 3 + f, "floor %d: %d slots" % [f, 3 + f])
	assert_eq(w.slots_at(6), 8, "a loop's floors keep the last count")
	var old := WandCompiler.for_run(_repo, _table(RunSaver.LEGACY_RUN_ID))
	assert_eq([old.slots_at(1), old.slots_at(2), old.slots_at(3)], [4, 6, 8], "the 3-floor shape")


func test_every_run_visits_all_five_biomes_once() -> void:
	var seen_first := {}
	for s in 200:
		var r := RunState.start(1000 + s, _table())
		var order := {}
		for f in range(1, 6):
			order[r.biome_of(f)] = true
		assert_eq(order.size(), 5, "seed %d: five different biomes" % s)
		seen_first[r.biome_of(1)] = true
		r.loop = 2
		r._draw_loop_biomes()
		var loop := {}
		for f in range(6, 11):
			loop[r.biome_of(f)] = true
		assert_eq(loop.size(), 5, "seed %d: the next loop visits all five again" % s)
	assert_eq(seen_first.size(), 5, "any biome can come first (random order)")


## Floors 1-3 draw from their own pools as before; floors 4 and 5 (no pool yet) draw a boss not met on the run's
## floors before, so the five bosses of a run are all different.
func test_a_run_never_meets_a_boss_twice() -> void:
	var pools := RunContentCompiler.compile_boss_pools(_repo, 5)
	assert_eq(pools.size(), 5)
	assert_true(pools[3].is_empty() and pools[4].is_empty(), "floors 4 and 5 have no pool yet")
	var on_four := {}
	for s in 300:
		var r := RunState.start(50 + s, _table())
		var met := []
		for f in range(1, 6):
			var b := FloorShape.boss(r, pools, f)
			assert_gte(b, 0, "seed %d floor %d has a boss" % [s, f])
			if f <= 3:
				assert_true(pools[f - 1].has(b), "floor %d: its own pool" % f)
				assert_eq(b, r.pick_boss(pools[f - 1], f), "floor %d: the same draw as before" % f)
			assert_false(b in met, "seed %d floor %d: not met before" % [s, f])
			met.append(b)
		on_four[met[3]] = true
	assert_eq(on_four.size(), 6, "floor 4 can meet any of the six")


## Generation over 1,000 seeds for every floor: the room count in the floor's range, a whole tree of doorways from
## the hall (one exit), no overlaps, inside the span, and the 4 x 4 boss room attached to the farthest room by one
## door. The first seeds of each floor also walk it: every room, the boss door and the boss's spot reachable from
## the start at the player's radius.
func test_generation_holds_for_every_floor_over_a_thousand_seeds() -> void:
	var map_def: MapDefinition = _repo.get_def(&"map", &"floor")
	var map := RunContentCompiler.compile_map(map_def)
	var r := RunState.start(1, _table())
	var counts := {}
	for f in range(1, 6):
		var lo := 99
		var hi := 0
		for s in SEEDS:
			var seed_value := 7 + s * 7919 + f * 104729
			var p := FloorShape.size_floor(r, RunContentCompiler.compile_map(map_def), f)
			var layout := FloorGenerator.generate(seed_value, p)
			var n := layout.room_count()
			lo = mini(lo, n)
			hi = maxi(hi, n)
			var tag := "floor %d seed %d" % [f, seed_value]
			if not _check_layout(layout, ROOMS_MIN[f - 1], ROOMS_MAX[f - 1], map.max_span, tag):
				return
			BossRoomBuilder.attach(
				layout, BossArenaSpec.make(Vector2i(4, 4), FloorLayout.Template.OPEN)
			)
			if not _check_boss_room(layout, tag):
				return
			if s < 15 and not _walk(layout, tag, s < 3):
				return
		counts[f] = [lo, hi]
		gut.p("floor %d: %d-%d rooms over %d seeds" % [f, lo, hi, SEEDS])
	assert_eq(counts.size(), 5)


func _check_layout(f: FloorLayout, lo: int, hi: int, span: int, tag: String) -> bool:
	var why := _layout_fault(f, lo, hi, span)
	if why != "":
		assert_true(false, "%s: %s" % [tag, why])
	return why == ""


## What is wrong with the plain floor `f` ("" when nothing).
func _layout_fault(f: FloorLayout, lo: int, hi: int, span: int) -> String:
	var n := f.room_count()
	var why := ""
	if n < lo or n > hi:
		why = "%d rooms, outside %d-%d" % [n, lo, hi]
	elif f.room_cells[0].size != Vector2i(3, 3) or f.neighbours(0).size() != 1:
		why = "the hall is not 3 x 3 cells with one exit"
	elif f.cols > span or f.rows > span:
		why = "wider than the span"
	var far := 0
	for h in f.hops:
		if h < 0:
			why = "a room without a doorway path"
		far = maxi(far, h)
	if why == "" and f.hops[f.portal_room] != far:
		why = "the portal room is not the farthest"
	for a in n:
		for b in range(a + 1, n):
			if f.room_cells[a].intersects(f.room_cells[b]):
				why = "rooms overlap"
	return why


func _check_boss_room(f: FloorLayout, tag: String) -> bool:
	var boss := f.boss_room
	var ok := boss == f.room_count() - 1 and f.portal_room == boss
	ok = ok and f.hops[boss] == f.hops[f.boss_host_room] + 1
	ok = ok and f.neighbours(boss) == PackedInt32Array([f.boss_host_room])
	ok = ok and f.room_of(f.boss_spawn) == boss
	if not ok:
		assert_true(false, tag + ": the boss room is not attached by one door to its host")
	return ok


## The boss door and the boss's spot are reachable from the start at the player's radius; with `rooms`, every room
## has open floor in the start's region too.
func _walk(f: FloorLayout, tag: String, rooms: bool) -> bool:
	var reach := FloorReach.new()
	reach.build(f.bounds.grow(1.0), f.walls, 0.35)
	var home := reach.region_at(f.start_pos)
	var ok := home >= 0
	ok = ok and reach.region_at(f.boss_door_outside(1.6)) == home
	ok = ok and reach.region_at(f.boss_spawn) == home
	if not ok:
		assert_true(false, tag + ": the boss room is not reachable from the start")
		return false
	if not rooms:
		return true
	var open := PackedByteArray()
	open.resize(f.room_count())
	for k in reach.size.x * reach.size.y:
		if reach.region[k] == home:
			var room := f.room_of(reach.center(Vector2i(k % reach.size.x, k / reach.size.x)))
			if room >= 0:
				open[room] = 1
	for room in f.room_count():
		if open[room] == 0:
			assert_true(false, "%s: room %d is cut off from the start" % [tag, room])
			return false
	return true


## Altars and chests by the floor's rooms (data/rewards: up to 11 rooms 2 altars and 1-2 chests, up to 14 rooms 2
## and 2, more rooms 2-3 and 2-3 as in v0.8.0; at most 2 altars stand, S1), as placed on real floors of the run.
func test_loot_follows_the_floor_size() -> void:
	var t := ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor"))
	assert_eq(t.counts_for(10), PackedInt32Array([2, 2, 1, 2]))
	assert_eq(t.counts_for(13), PackedInt32Array([2, 2, 2, 2]))
	assert_eq(t.counts_for(15), PackedInt32Array([2, 3, 2, 3]), "v0.8.0's counts from 15 rooms")
	assert_eq(t.counts_for(19), PackedInt32Array([2, 3, 2, 3]))
	var totals := {}
	for f in range(1, 6):
		var sum := 0
		for s in 12:
			var r := RunState.start(300 + s, _table())
			r.floor_index = f
			var w := _floor_world(r)
			var rooms := w.floor_layout.room_count() - 1
			var c := t.counts_for(rooms)
			var n := w.rewards.size()
			assert_between(n, c[0] + c[2], c[1] + c[3], "floor %d (%d rooms)" % [f, rooms])
			var altars := w.rewards.kind.count(RewardStore.Kind.ALTAR)
			assert_lte(altars, t.altars_cap, "at most two altars")
			sum += n
		totals[f] = sum
	assert_lt(totals[1], totals[5], "the small first floor holds less than the long last one")


## A whole run in the sim, floor by floor as Main builds them (RunLab): floors 1 to 5 of their sizes, the Deep gate
## offered before the last floor, each boss beaten and its portal taken; floor 5 has the Ascension portal and the
## Loop device, and its portal leads to the final arena.
func test_a_run_goes_through_five_floors_to_the_ascension_portal() -> void:
	var lab := RunLab.new(_repo, 4242, &"blade")
	for f in range(1, 6):
		assert_eq(lab.run.floor_index, f)
		var w := lab.floor_world()
		w.actors.invuln[0] = LONG
		var layout := w.floor_layout
		assert_between(
			layout.room_count() - 1, ROOMS_MIN[f - 1], ROOMS_MAX[f - 1], "floor %d rooms" % f
		)
		assert_eq(w.floor_count, 5)
		assert_eq(w.boss_flow.ascension, f == 5, "floor %d: the Ascension portal only on 5" % f)
		assert_eq(layout.has_loop_device, f == 5, "floor %d: the Loop device only on 5" % f)
		assert_eq(layout.has_deep_portal, f < 5, "floor %d: the Deep gate before the last" % f)
		_beat_boss_and_take_portal(w)
		var reader := WorldReader.new(w)
		assert_eq(reader.outcome(), 3, "floor %d: the portal ends the floor" % f)
		if f == 5:
			assert_eq(reader.ascension_choice(), WorldReader.ASCEND_PORTAL)
		lab.next_floor(w)
	assert_true(lab.run.final_fight, "floor 5's portal leads to the final boss")
	assert_eq(lab.run.loop, 1)
	assert_eq(lab.run.floor_index, 5)
	assert_eq(lab.run.routes.size(), 5, "a route for each of the five floors")


func _floor_world(r: RunState) -> World:
	var enemies := ContentCompiler.compile_enemies(_repo)
	r.scale_enemies(enemies)
	return FloorScenario.build(
		r.floor_seed(),
		PlayerTable.starting_values(),
		enemies,
		ContentCompiler.compile_spawning(_repo.get_def(&"spawning", &"floor_1"), _repo),
		ContentCompiler.compile_items(_repo),
		ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor")),
		r.floor_index,
		null,
		r
	)


## Seals the boss room, kills the boss, then walks into the (normal or Ascension) portal until the floor ends.
func _beat_boss_and_take_portal(w: World) -> void:
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 4)
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT, "the boss room sealed")
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 99999999, 0, 0, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	CombatLab.idle(w, 1)
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN, "the portal opened")
	w.actors.set_pos(0, f.portal_front_point())
	CombatLab.until(
		w,
		func(x: World) -> bool:
			var frame := InputFrame.new()
			var d := (f.portal_pos - x.player_pos()).normalized()
			frame.move = Vector2i(roundi(d.x * SimTick.MOVE_MAX), roundi(d.y * SimTick.MOVE_MAX))
			x.step(frame)
			return x.boss_flow.state == BossFlow.State.ENTERING,
		240
	)
	CombatLab.idle(w, BossFlow.ENTER_TICKS + 2)
