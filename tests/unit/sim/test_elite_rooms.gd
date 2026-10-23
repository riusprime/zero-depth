extends GutTest
## v0.9.0 EL (owner Q24: "15 % / 25 %", floors 4-5, at most 1 alive, at least 2 rooms apart; Q21: Elite Lockdowns;
## Q25: the ×2 HP elite, Marked and the Ambush Cache deleted): where elites appear.
## - Placement over SEEDS floor seeds a floor (as test_lockdowns builds them, Lockdowns marked first): none on floors
##   1-3; on floors 4-5 the rooms drawn are the share of the candidates (rounded half up) unless the spacing leaves
##   fewer, never a forbidden room, never two within 2 rooms (an Elite Lockdown counts); the counts printed
##   (EL_PLACEMENT).
## - On real floors (SaveLab, as Main): an elite room's elite arrives the first time you walk in, at most one alive,
##   the next pack one smaller; an Elite Lockdown fights an elite and its escort; a floor saved before EL has none.

const SEEDS := 200

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _rules() -> EliteRules:
	return EliteCompiler.compile_rules(_repo.get_def(&"elite_rules", &"rules"))


func _layout(seed_value: int, run: RunState, floor_index: int) -> FloorLayout:
	var map := RunContentCompiler.compile_map(_repo.get_def(&"map", &"floor"))
	map.room_layouts = RunContentCompiler.compile_room_layouts(_repo)
	var arenas := RunContentCompiler.compile_arena(_repo.get_def(&"arena", &"arena"))
	var secrets: SecretsDefinition = _repo.get_def(&"secrets", &"secrets")
	var p := FloorShape.size_floor(run, map, floor_index)
	var f := FloorGenerator.generate(seed_value, p)
	BossRoomBuilder.attach(f, BossArenaSpec.make(Vector2i(4, 4), FloorLayout.Template.OPEN))
	OverrunRooms.mark(f)
	ArenaRooms.mark(f, arenas.share_permille)
	Routes.place_deep_gate(f)
	var speed := PlayerTable.starting_values().move_speed
	var none := PackedInt32Array()
	TimedDoorRooms.mark(f, map.timed_door_permille, 900, speed, none, PackedVector2Array())
	RuneRooms.mark(f, secrets.rune_permille, none, PackedVector2Array())
	CrackedRooms.mark(f, secrets.crack_permille, none)
	PurpleRooms.mark(f, 500, none, PackedVector2Array())
	var lock := RunContentCompiler.compile_lockdown(_repo.get_def(&"lockdown", &"lockdown"))
	LockdownRooms.mark(f, lock, floor_index, none)
	return f


func test_placement_over_many_seeds() -> void:
	var run := RunState.start(
		1, ContentCompiler.compile_run(_repo.get_def(&"run", RunSaver.RUN_ID))
	)
	var rules := _rules()
	var bad := 0
	var lines := PackedStringArray()
	for floor_index in range(1, 6):
		var placed := 0
		var wanted := 0
		var cands_n := 0
		var floors_with := 0
		var kinds := [0, 0, 0]
		var lock_elites := 0
		for s in SEEDS:
			var f := _layout(7001 + s * 7919 + floor_index * 104729, run, floor_index)
			var marked := Elites.mark(f, rules, floor_index, PackedInt32Array())
			var rooms: PackedInt32Array = marked[0]
			var never := f.lockdown_rooms.duplicate()
			var cands := LockdownRooms.candidates(f, never)
			var want := (cands.size() * rules.room_permille_on(floor_index) + 500) / 1000
			cands_n += cands.size()
			wanted += want
			placed += rooms.size()
			floors_with += 1 if not rooms.is_empty() else 0
			var spaced := Elites.elite_lockdowns(f)
			lock_elites += spaced.size()
			if rooms.size() > want:
				bad += 1
			for k in rooms.size():
				var r := rooms[k]
				kinds[Elites.KINDS.find(marked[1][k])] += 1
				if not cands.has(r):
					bad += 1
					gut.p("forbidden room %d on seed %d floor %d" % [r, s, floor_index])
				var d := Elites.hops(f, r)
				for o in spaced:
					if o != r and d[o] >= 0 and d[o] <= rules.min_gap_rooms:
						bad += 1
						gut.p(
							(
								"two elite rooms %d hops apart on seed %d floor %d"
								% [d[o], s, floor_index]
							)
						)
				spaced.append(r)
			if floor_index <= 3 and not rooms.is_empty():
				bad += 1
		lines.append(
			(
				(
					"EL_PLACEMENT| floor=%d seeds=%d candidates=%d wanted=%d placed=%d share=%.3f"
					+ " floors_with=%d breaker=%d rift=%d conduit=%d elite_lockdowns=%d"
				)
				% [
					floor_index,
					SEEDS,
					cands_n,
					wanted,
					placed,
					float(placed) / maxi(1, cands_n),
					floors_with,
					kinds[0],
					kinds[1],
					kinds[2],
					lock_elites
				]
			)
		)
		if floor_index == 4:
			assert_between(
				float(placed) / cands_n, 0.11, 0.16, "about 15 % of floor 4's combat rooms"
			)
		if floor_index == 5:
			assert_between(
				float(placed) / cands_n, 0.17, 0.26, "about 25 % of floor 5's (less where spacing)"
			)
		if floor_index >= 4:
			for k in 3:
				assert_gt(kinds[k], 0, "every archetype appears on floor %d" % floor_index)
	for l in lines:
		gut.p(l)
	assert_eq(
		bad,
		0,
		"floors 1-3 none, never a forbidden room, never two within 2 rooms, never past the share"
	)


## The first floor-`floor` seed from `first` whose world has at least `n` elite rooms (a real floor, as Main).
func _floor_with_rooms(floor: int, n: int, first := 1, tries := 40) -> World:
	for s in range(first, first + tries):
		var w := SaveLab.floor_world(s, floor)
		if w.elites != null and w.elites.rooms.size() >= n:
			LockLab.calm(w)
			return w
	return null


func _enter(w: World, room: int) -> void:
	w.actors.set_pos(0, w.floor_layout.rooms[room].get_center())
	w.vel = Vector2.ZERO
	w.step(InputFrame.new())


func _kill(w: World, id: int) -> void:
	var i := w.actors.index_of(id)
	if i < 0:
		return
	w.actors.invuln[i] = 0
	var p := w.actors.pos(i)
	Damage.hit(w, i, 1 << 24, 0, 0, w.take_root(), 0, p, p)
	w.step(InputFrame.new())


func test_floors_1_to_3_have_no_elites_on_real_floors() -> void:
	for f in range(1, 4):
		for s in range(1, 6):
			var w := SaveLab.floor_world(s, f)
			assert_null(w.elites, "seed %d floor %d: no elite rooms" % [s, f])
			assert_false(WorldReader.new(w).elites()["active"])
			assert_false(
				w.floor_layout.lockdown_kinds.has(LockdownTable.Kind.ELITE), "no Elite Lockdown"
			)
			for i in range(1, w.actors.size()):
				assert_false(EliteAi.is_elite_kind(w.actors.kinds[i]))


func test_an_elite_arrives_on_entry_one_alive_at_most_and_shrinks_the_next_pack() -> void:
	var w := _floor_with_rooms(5, 2)
	assert_not_null(w, "a floor-5 seed with two elite rooms")
	if w == null:
		return
	var s := w.elites
	var a := s.rooms[0]
	var b := s.rooms[1]
	assert_eq(Elites.alive(w), 0, "nothing before you walk in")
	_enter(w, a)
	assert_eq(Elites.alive(w), 1, "the room's elite arrived")
	var id := s.ids[0]
	var i := w.actors.index_of(id)
	assert_eq(w.actors.kinds[i], s.room_kinds[0], "the archetype the floor drew")
	assert_eq(w.floor_layout.room_of(w.actors.pos(i)), a, "inside its room")
	assert_eq(w.actors.state[i], EnemyAi.State.SPAWN, "rising (0.7 s: the arrival)")
	assert_eq(s.arrive_id, id, "the views know it arrived")
	assert_true(CoreTheft.has_core(w, i), "it carries a core")
	assert_eq(s.escort_pending, 1, "the next pack waits one smaller")
	assert_eq(Elites.escort_size(w, 4), 3, "one smaller")
	assert_eq(Elites.escort_size(w, 4), 4, "only the first")
	_enter(w, b)
	assert_eq(Elites.alive(w), 1, "at most one alive: room %d's waits" % b)
	assert_eq(s.room_spawned[1], 0)
	_enter(w, a)  # back out of room b
	_kill(w, id)
	assert_eq(Elites.alive(w), 0, "killed")
	assert_gte(s.kill_tick, 0, "the views know it fell")
	w.step(InputFrame.new())
	assert_eq(Elites.alive(w), 0, "a room's elite never comes again")
	_enter(w, b)
	assert_eq(Elites.alive(w), 1, "the second room's elite, now the first is down")


func test_elites_scale_with_the_floor() -> void:
	var w := _floor_with_rooms(4, 1)
	assert_not_null(w)
	if w == null:
		return
	var kind := w.elites.room_kinds[0]
	var base := EliteCompiler.compile_elite(_repo.get_def(&"elites", _id_of(kind)), _repo)
	var t := w.enemy_table(kind)
	assert_gt(t.hp, base.hp, "floor 4's tables are scaled (RunState.scale_enemies)")
	assert_gt(t.elite.damage, base.elite.damage, "and its ability's damage with them")


func _id_of(kind: int) -> StringName:
	return EliteDefinition.ARCHETYPES[Elites.KINDS.find(kind)]


func test_an_elite_lockdown_fights_an_elite_and_its_escort() -> void:
	var w: World = null
	for s in range(1, 80):
		for f in [4, 5]:
			var c := SaveLab.floor_world(s, f)
			if c.floor_layout.lockdown_kinds.has(LockdownTable.Kind.ELITE):
				w = c
				break
		if w != null:
			break
	assert_not_null(w, "a floor 4-5 seed with an Elite Lockdown")
	if w == null:
		return
	LockLab.calm(w)
	var f := w.floor_layout
	var r := f.lockdown_rooms[f.lockdown_kinds.find(LockdownTable.Kind.ELITE)]
	LockLab.enter(w, r)
	var s := w.lockdown
	assert_eq(s.kind, LockdownTable.Kind.ELITE)
	assert_eq(s.waves, 1, "one formation")
	LockLab.to_wave(w)
	var elites := 0
	for id in s.members:
		if EliteAi.is_elite_kind(w.actors.kinds[w.actors.index_of(id)]):
			elites += 1
	assert_eq(elites, 1, "one elite")
	assert_eq(s.members.size(), 1 + w.elite_rules.lockdown_escort, "and its escort of 3")
	LockLab.clear(w)
	assert_false(s.sealed(), "cleared: it opens")
	assert_eq(s.reward_ids.size(), 1, "with its reward")


func test_a_floor_saved_before_el_has_no_elite_rooms_nor_elite_lockdown() -> void:
	var with := 0
	for s in range(1, 13):
		var r := SaveLab.run_state(s, 5)
		r.floor_rules = RunState.FLOOR_RULES_V090_SH
		var old := SaveLab.build_floor(r)
		assert_null(old.elites, "seed %d: no elite rooms under floor rules 14" % s)
		assert_false(
			old.floor_layout.lockdown_kinds.has(LockdownTable.Kind.ELITE), "no Elite Lockdown"
		)
		if SaveLab.floor_world(s, 5).elites != null:
			with += 1
	assert_gt(with, 0, "today's floor 5s have them")


func test_the_elite_state_is_hashed_and_saved() -> void:
	var seed_value := -1
	var w: World = null
	for s in range(1, 40):
		w = SaveLab.floor_world(s, 5)
		if w.elites != null:
			seed_value = s
			break
	assert_gte(seed_value, 0, "a floor-5 seed with an elite room")
	if seed_value < 0:
		return
	LockLab.calm(w)
	var h0 := w.state_hash()
	_enter(w, w.elites.rooms[0])
	for k in 30:
		w.step(InputFrame.new())
	assert_ne(w.state_hash(), h0, "the arrival is hashed")
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray(), "every elite object is classified (state or loadout)")
	var base := SaveLab.floor_world(seed_value, 5)
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save with an elite alive fits")
	assert_eq(base.state_hash(), w.state_hash(), "same state")
	for k in 120:
		w.step(InputFrame.new())
		base.step(InputFrame.new())
	assert_eq(base.state_hash(), w.state_hash(), "and the same 2 s later")
