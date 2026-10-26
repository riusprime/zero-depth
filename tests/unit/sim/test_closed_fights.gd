extends GutTest
## v0.9.0 CF (owner: "lets never make it a 1x1 it is too small and so many enemies appear, the enemies that spawn at the
## same time should be proportional to the room size, where smaller rooms are a challenge but not impossible crazy"):
## - no closed fight (an arena, the Overrun room, a Lockdown, the Chaos shrine) in a room of fewer than 2 grid cells,
##   over RUNS run seeds x floors 1-5 as Main builds them; a big room's at-once cap is over every fight's size;
## - the at-once cap follows the floor area (ClosedFights), an elite counting EliteRules.elite_weight;
## - in a small room (the budget raised so the cap is 2) the arena wave, the Lockdown formation and the Chaos challenge
##   put only that many out, the rest come in as earlier ones die, and the totals, the kinds and the clears are those
##   of the same fight uncapped;
## - a floor saved under the rules before CF (15) keeps its small-room fights; a save mid-fight with members waiting
##   round-trips (snapshot, hash).

const RUNS := 40
const FLOORS := 5
const LONG := 1 << 24

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func after_each() -> void:
	NavField.skip_build = false


func _floor(s: int, floor_index: int, rules: int = RunState.FLOOR_RULES) -> World:
	var run := SaveLab.run_state(s, floor_index, &"blade", 0, _repo)
	run.floor_rules = rules
	return SaveLab.build_floor(run, &"", _repo)


## Kind -> the floor's closed-fight rooms.
func _fights(w: World) -> Dictionary:
	var f := w.floor_layout
	var over := PackedInt32Array()
	if f.overrun_room >= 0:
		over.append(f.overrun_room)
	var chaos := PackedInt32Array()
	if w.shrine != null and w.shrine.kind == ShrineTable.Kind.CHAOS:
		chaos.append(f.room_of(w.shrine.pos))
	return {
		&"arena": f.arena_rooms.duplicate(),
		&"overrun": over,
		&"lockdown": f.lockdown_rooms.duplicate(),
		&"chaos": chaos,
	}


func _has_small(w: World) -> bool:
	var fights := _fights(w)
	for k: StringName in fights:
		for r in fights[k] as PackedInt32Array:
			if w.floor_layout.room_cell_count(r) < 2:
				return true
	return false


# --- The cap ------------------------------------------------------------------------------------------------------
func test_the_cap_follows_the_floor_area() -> void:
	assert_eq(ClosedFights.cap_for(250.0, 30.0), 8, "250 m2 at 30 m2 an enemy")
	assert_eq(ClosedFights.cap_for(540.0, 30.0), 18)
	assert_eq(ClosedFights.cap_for(10.0, 30.0), 1, "at least one")
	assert_eq(ClosedFights.cap_for(500.0, 0.0), ClosedFights.NO_CAP, "no budget: no cap")
	var w := World.new(1, PlayerTable.new())
	w.elite_rules = EliteRules.new()
	var elite := -1 - ActorStore.Kind.BREAKER
	var kinds := PackedInt32Array([elite, 0, 0, 0])
	assert_eq(ClosedFights.queued_weight(w, elite), 3, "an elite counts 3")
	assert_eq(ClosedFights.first_batch(w, kinds, 4), 2, "the elite and one")
	assert_eq(ClosedFights.first_batch(w, kinds, 2), 1, "a heavy elite still comes, alone")
	assert_eq(ClosedFights.first_batch(w, kinds, 100), 4, "a big room: all")


# --- The rooms ----------------------------------------------------------------------------------------------------
func test_no_closed_fight_in_a_1x1_room_and_big_rooms_hold_every_fight() -> void:
	NavField.skip_build = true
	var arena := RunContentCompiler.compile_arena(_repo.get_def(&"arena", &"arena"))
	var over := ContentCompiler.compile_overrun(_repo.get_def(&"overrun", &"overrun"))
	var lock := RunContentCompiler.compile_lockdown(_repo.get_def(&"lockdown", &"lockdown"))
	var shr := RunContentCompiler.compile_shrines(_repo.get_def(&"shrines", &"shrines"))
	var rules := EliteCompiler.compile_rules(_repo.get_def(&"elite_rules", &"rules"))
	var seen := {&"arena": 0, &"overrun": 0, &"lockdown": 0, &"chaos": 0}
	var bad := PackedStringArray()
	for s in range(1, RUNS + 1):
		for fl in range(1, FLOORS + 1):
			var w := _floor(s, fl)
			var f := w.floor_layout
			var fights := _fights(w)
			for k: StringName in fights:
				for r in fights[k] as PackedInt32Array:
					seen[k] += 1
					if f.room_cell_count(r) < 2:
						bad.append("seed %d floor %d: %s in room %d (1 x 1)" % [s, fl, k, r])
					if f.room_cell_count(r) < 4:
						continue
					var size := 0
					var per := 0.0
					match k:
						&"arena":
							size = ArenaTable.size_on(arena.wave_sizes, fl)
							per = arena.area_per_enemy_m2
						&"overrun":
							size = ArenaTable.size_on(over.wave_sizes, fl)
							per = over.area_per_enemy_m2
						&"lockdown":
							size = maxi(
								lock.size_on(fl), rules.elite_weight + rules.lockdown_escort
							)
							per = lock.area_per_enemy_m2
						_:
							size = shr.chaos_size(fl) + rules.elite_weight
							per = shr.chaos_area_per_enemy_m2
					if ClosedFights.cap(f, r, per) < size:
						bad.append(
							"seed %d floor %d: %s room %d holds fewer than %d" % [s, fl, k, r, size]
						)
	gut.p("CF_ROOMS| floors=%d fights=%s bad=%d" % [RUNS * FLOORS, seen, bad.size()])
	assert_eq(bad.size(), 0, "; ".join(bad.slice(0, 10)))
	for k: StringName in seen:
		assert_gt(seen[k], 0, "%s fights to check" % k)


func test_a_floor_saved_before_cf_keeps_its_rooms() -> void:
	NavField.skip_build = true
	var found := false
	for s in range(1, 60):
		for fl in range(1, FLOORS + 1):
			var old := _floor(s, fl, RunState.FLOOR_RULES_V090_EL)
			if not _has_small(old):
				continue
			var again := _floor(s, fl, RunState.FLOOR_RULES_V090_EL)
			assert_eq(_fights(again), _fights(old), "seed %d floor %d: rebuilt as saved" % [s, fl])
			var now := _floor(s, fl)
			assert_eq(now.floor_layout.room_cells, old.floor_layout.room_cells, "the same rooms")
			assert_false(_has_small(now), "today's rules: none in a 1 x 1")
			gut.p(
				(
					"CF_OLD| seed %d floor %d: before %s, today %s"
					% [s, fl, _fights(old), _fights(now)]
				)
			)
			found = true
			break
		if found:
			break
	assert_true(found, "a floor under the old rules with a closed fight in a 1 x 1")


# --- Arenas -------------------------------------------------------------------------------------------------------
func _arena_world(from: int) -> World:
	for s in range(from, from + 40):
		var w := _floor(s, 1, RunState.FLOOR_RULES_V095_AQ)  # v0.9.5 DR: the wave Arenas are rules 19's
		if not w.floor_layout.arena_rooms.is_empty():
			w.actors.invuln[0] = LONG
			w.actors.hp[0] = 100000
			w.actors.max_hp[0] = 100000
			return w
	return null


## Raises the arena budget so room `room` holds `cap` at once.
func _squeeze_arena(w: World, room: int, cap: int) -> void:
	w.arena_table.area_per_enemy_m2 = ClosedFights.area_m2(w.floor_layout, room) / (cap + 0.5)


func _enter_arena(w: World, room: int) -> void:
	while w.boss_flow != null and w.boss_flow.holds_world():
		w.step(InputFrame.new())
	w.actors.set_pos(0, w.floor_layout.spawn_points[room][0])
	w.vel = Vector2.ZERO
	w.step(InputFrame.new())


func _kill_in_arena(w: World) -> void:
	if not w.arenas.sealed():
		return
	var rect := w.floor_layout.rooms[w.arenas.room].grow(Arenas.ROOM_MARGIN_M)
	for i in range(1, w.actors.size()):
		var at := w.actors.pos(i)
		if w.actors.dead[i] == 0 and w.actors.invuln[i] == 0 and rect.has_point(at):
			Damage.hit(w, i, 1000000, w.actors.ids[0], w.actors.ids[0], w.take_root(), 0, at, at)


## Fights the sealed arena to its clear, killing what is inside every `every` ticks; returns the kinds that came, in
## arrival order, and the most out right after a refill (a Splitling's halves may add to it later).
func _fight_arena(w: World, every: int) -> Dictionary:
	var kinds := PackedInt32Array()
	var seen := {}
	var most := 0
	var refills := 0
	var guard := 0
	while w.arenas.sealed() and guard < 20000:
		guard += 1
		if guard % every == 0:
			_kill_in_arena(w)
		var waiting := w.arenas.later_kinds.size()
		w.step(InputFrame.new())
		if w.arenas.later_kinds.size() < waiting and w.arenas.next_wave_tick < 0:
			refills += 1
			most = maxi(most, Arenas.alive_in_room(w))
		for i in range(1, w.actors.size()):
			var id := w.actors.ids[i]
			if EnemyAi.is_enemy_kind(w.actors.kinds[i]) and not seen.has(id):
				seen[id] = true
				kinds.append(w.actors.kinds[i])
	return {"kinds": kinds, "most": most, "refills": refills, "cleared": not w.arenas.sealed()}


func test_a_small_arena_holds_its_cap_and_the_rest_come_in() -> void:
	var w := _arena_world(1)
	var plain := _arena_world(1)
	assert_not_null(w)
	if w == null:
		return
	var room := w.floor_layout.arena_rooms[0]
	_squeeze_arena(w, room, 2)
	_enter_arena(w, room)
	_enter_arena(plain, room)
	assert_eq(Arenas.at_once(w), 2, "the squeezed room holds 2")
	assert_gte(
		Arenas.at_once(plain), Arenas.wave_size(plain), "today's budget holds the whole wave"
	)
	var waves := w.arenas.waves
	assert_eq(waves, plain.arenas.waves, "the same waves")
	var t0 := w.tick
	while w.arenas.wave == 0 and w.tick - t0 < 300:
		w.step(InputFrame.new())
	assert_eq(Arenas.alive_in_room(w), 2, "two out at once")
	assert_eq(w.arenas.later_kinds.size(), Arenas.wave_size(w) - 2, "the rest wait")
	var capped := _fight_arena(w, 20)
	var free := _fight_arena(plain, 20)
	gut.p("CF_ARENA| capped=%s free=%s" % [capped, free])
	assert_true(capped["cleared"], "the capped arena clears")
	assert_true(free["cleared"])
	assert_lte(capped["most"], 2, "never more than the cap out")
	assert_gt(capped["refills"], 0, "the rest came in")
	assert_eq(capped["kinds"], free["kinds"], "the same enemies, in the same order")
	assert_eq(w.arenas.spawned, plain.arenas.spawned, "the same total")
	assert_eq(w.arenas.spawned, Arenas.wave_size(w) * waves, "every wave whole")


func test_a_save_with_members_waiting_round_trips() -> void:
	var w := _arena_world(1)
	if w == null:
		return
	var room := w.floor_layout.arena_rooms[0]
	_squeeze_arena(w, room, 1)
	_enter_arena(w, room)
	var t0 := w.tick
	while w.arenas.later_kinds.is_empty() and w.tick - t0 < 300:
		w.step(InputFrame.new())
	assert_false(w.arenas.later_kinds.is_empty(), "members wait")
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray(), "every object is classified")
	var base := _arena_world(1)
	_squeeze_arena(base, room, 1)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored, WorldSnapshot.apply(_arena_world(1), snap))
	if restored == null:
		return
	assert_eq(restored.arenas.later_kinds, w.arenas.later_kinds, "the waiting members come back")
	assert_eq(restored.arenas.later_pos, w.arenas.later_pos)
	assert_eq(restored.state_hash(), w.state_hash(), "the hash")
	for n in 400:
		if n % 30 == 0:
			_kill_in_arena(w)
			_kill_in_arena(restored)
		w.step(InputFrame.new())
		restored.step(InputFrame.new())
	assert_eq(restored.state_hash(), w.state_hash(), "equal after 400 ticks")
	var h := w.state_hash()
	w.arenas.later_kinds.append(0)
	w.arenas.later_pos.append(Vector2.ZERO)
	assert_ne(w.state_hash(), h, "the waiting members are hashed")


# --- Lockdowns ----------------------------------------------------------------------------------------------------
func _lock_world(floor_index: int, elite: bool) -> World:
	for s in range(1, 80):
		var w := SaveLab.floor_world(s, floor_index)
		if w.lockdown == null or w.floor_layout.lockdown_rooms.is_empty():
			continue
		if elite and not w.floor_layout.lockdown_kinds.has(LockdownTable.Kind.ELITE):
			continue
		LockLab.calm(w)
		return w
	return null


func _lock_room(w: World, elite: bool) -> int:
	var f := w.floor_layout
	for k in f.lockdown_rooms.size():
		if not elite or f.lockdown_kinds[k] == LockdownTable.Kind.ELITE:
			return f.lockdown_rooms[k]
	return -1


## Clears the sealed Lockdown killing every fighter every `every` ticks; the most out by weight right after a refill
## (a Splitling's halves may add to it later), the members that came and whether a refill happened.
func _fight_lock(w: World, every: int) -> Dictionary:
	var s := w.lockdown
	var most := 0
	var refills := 0
	var guard := 0
	while s.sealed() and guard < 8000:
		guard += 1
		if guard % every == 0:
			LockLab.kill_all(w)
		var waiting := s.later_kinds.size()
		w.step(InputFrame.new())
		if s.later_kinds.size() < waiting and s.next_wave_tick < 0:
			refills += 1
			var out := 0
			for i in Lockdowns.fighters(w):
				out += ClosedFights.weight(w, i)
			most = maxi(most, out)
	return {
		"most": most, "refills": refills, "members": s.members.size(), "forced": s.forced.size()
	}


func test_a_small_lockdown_fields_a_smaller_formation_then_reinforcements() -> void:
	var w := _lock_world(2, false)
	var plain := _lock_world(2, false)
	assert_not_null(w)
	if w == null:
		return
	var r := _lock_room(w, false)
	w.lockdown.table.area_per_enemy_m2 = ClosedFights.area_m2(w.floor_layout, r) / 2.5
	LockLab.enter(w, r)
	LockLab.enter(plain, r)
	assert_eq(Lockdowns.at_once(w), 2, "the squeezed room holds 2")
	LockLab.to_wave(w)
	var size := w.lockdown.table.size_on(w.floor_index)
	assert_eq(w.lockdown.members.size(), 2, "a formation of 2")
	assert_eq(w.lockdown.later_kinds.size(), size - 2, "the rest wait")
	var capped := _fight_lock(w, 20)
	var free := _fight_lock(plain, 20)
	gut.p("CF_LOCKDOWN| capped=%s free=%s" % [capped, free])
	assert_false(w.lockdown.sealed(), "it opens")
	assert_eq(capped["forced"], 0, "by the clear, not the cap")
	assert_lte(capped["most"], 2, "never more than the cap out")
	assert_gt(capped["refills"], 0, "reinforcements came in")
	assert_eq(capped["members"], free["members"], "the same total as uncapped")
	assert_eq(capped["members"], size * w.lockdown.waves, "every formation whole")


func test_an_elite_counts_three_in_a_small_lockdown() -> void:
	var w: World = null
	for fl in [4, 5]:
		w = _lock_world(fl, true)
		if w != null:
			break
	assert_not_null(w, "an Elite Lockdown within 80 seeds")
	if w == null:
		return
	var r := _lock_room(w, true)
	w.lockdown.table.area_per_enemy_m2 = ClosedFights.area_m2(w.floor_layout, r) / 4.5
	LockLab.enter(w, r)
	assert_eq(Lockdowns.at_once(w), 4, "the squeezed room holds 4")
	LockLab.to_wave(w)
	var s := w.lockdown
	assert_eq(s.members.size(), 2, "the elite (3) and one escort (1)")
	assert_eq(
		s.later_kinds.size(), w.elite_rules.lockdown_escort - 1, "the rest of the escort waits"
	)
	assert_eq(Elites.alive(w), 1, "the elite is out first")
	var capped := _fight_lock(w, 20)
	assert_false(s.sealed(), "it opens")
	assert_lte(capped["most"], 4, "never more than the cap out (an elite counts 3)")
	assert_eq(
		capped["members"], 1 + w.elite_rules.lockdown_escort, "the elite and its whole escort"
	)


# --- The Chaos shrine ---------------------------------------------------------------------------------------------
func _alive_members(w: World) -> int:
	var n := 0
	for id in w.shrine.members:
		var i := w.actors.index_of(id)
		if i >= 0 and w.actors.dead[i] == 0:
			n += 1
	return n


func test_a_small_chaos_challenge_comes_in_turns() -> void:
	var w := ShrineLab.with_kind(ShrineTable.Kind.CHAOS, 2)
	assert_not_null(w, "a Chaos shrine on floor 2")
	if w == null:
		return
	var room := w.floor_layout.room_of(w.shrine.pos)
	assert_gte(w.floor_layout.room_cell_count(room), 2, "never in a 1 x 1")
	w.shrine.table.chaos_area_per_enemy_m2 = ClosedFights.area_m2(w.floor_layout, room) / 2.5
	ShrineLab.stand_by(w, w.shrine.pos)
	ShrineLab.press(w)
	var size := w.shrine.table.chaos_size(w.floor_index)
	assert_eq(w.shrine.chaos_phase, 1, "the challenge begins")
	assert_eq(_alive_members(w), 2, "two out at once")
	assert_eq(w.shrine.later_kinds.size(), size - 2, "the rest wait")
	var most := 0
	var guard := 0
	while w.shrine.chaos_phase == 1 and guard < 6000:
		guard += 1
		if guard % 20 == 0:
			for id in w.shrine.members:
				var i := w.actors.index_of(id)
				if i >= 0 and w.actors.dead[i] == 0:
					var p := w.actors.pos(i)
					Damage.hit(w, i, 1 << 20, 0, 0, w.take_root(), 0, p, p)
		var waiting := w.shrine.later_kinds.size()
		w.step(InputFrame.new())
		if w.shrine.later_kinds.size() < waiting:  # right after a refill
			most = maxi(most, Shrines.alive_weight(w))
	assert_eq(w.shrine.chaos_phase, 2, "won")
	assert_lte(most, 2, "never more than the cap out")
	assert_eq(w.shrine.members.size(), size, "every member came")
