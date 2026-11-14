extends GutTest
## v0.11.0 O14b (owner Q-O14b "Both"; OWNER_QUESTIONS §J N1, N2): the hidden room under the Hollow Crown's throne,
## built the way the game builds it (FloorPlan from the run, RunState.heart_room from the profile's Runic Stone lines):
## only a profile with all ten lines gets it; without the flag the final approach and the floors are as they were; its
## cracked wall, its pedestal (the City's Heart: once a run the first killing blow leaves 1 HP and pulses a 4 m ring;
## the second kills) and its door, which stays sealed (N2's hook says no). Snapshots restore it exactly.

const FULL_SEEDS := 1000

static var _repo: ContentRepository
var _seeds := Seeds.count(FULL_SEEDS)  # v0.11.1 Step 4: 200 here, 1,000 in the GitHub full suite


func _content() -> ContentRepository:
	if _repo == null:
		_repo = ContentRepository.load_all()
	return _repo


## The final approach of run seed `seed_value` (its last floor after the Ascension portal), as Main builds it.
func _final(seed_value: int, heart: bool) -> World:
	var repo := _content()
	var run := FinalLab.run_state(seed_value)
	run.heart_room = heart
	var def: RunDefinition = repo.get_def(&"run", RunSaver.RUN_ID)
	var plan := FloorPlan.next_floor(run, def.biomes.duplicate(), {}, true)
	plan.repo = repo
	plan.build()
	return plan.world


func _profile(lines: int, final := false) -> ProfileStore:
	var p := ProfileStore.new("")
	var learned := []
	for k in lines:
		learned.append("r%d" % (k + 1))
	if final:
		learned.append("r11")
	p.data["runes"] = {"learned": learned}
	return p


func _step(w: World, n: int, frame: InputFrame = null) -> void:
	for k in n:
		w.step(frame if frame != null else InputFrame.new())


func _press(w: World) -> void:
	var f := InputFrame.new()
	f.pressed = InputFrame.INTERACT
	w.step(f)
	_step(w, 2)


func _break_and_enter(w: World) -> void:
	_step(w, 2)  # the wall stands as a barrier from the first tick
	var k := 0
	while w.boss_flow != null and w.boss_flow.arrive_left > 0 and k < 900:  # the landing at the causeway's foot
		w.step(InputFrame.new())
		k += 1
	w.breakables.crack_hp = 1
	var f := w.floor_layout
	var center := f.door_centers[f.crack_door]
	Breakables.on_skill(w, center - Vector2(1.0, 0.0), 0, true)
	if w.breakables.crack_broken == 0:  # the cleave's fan didn't reach: break it as the Skill would
		w.breakables.crack_hp = 0
		w.breakables.crack_broken = 1
		var slab: Array[Obb] = [f.crack_wall]
		w.remove_barriers(slab)
		w.breakables.crack_up = 0
	w.actors.set_pos(0, f.heart_pedestal + Vector2(-1.2, 0.0))


func _enemy_at(w: World, at: Vector2) -> int:
	var id := w.add_enemy(int(w.enemy_tables.keys()[0]), at)
	var i := w.actors.index_of(id)
	w.actors.invuln[i] = 0
	return i


func test_the_profile_needs_all_ten_lines() -> void:
	assert_false(RunicStone.knows_final(_profile(9)), "nine lines: no")
	assert_false(RunicStone.knows_final(_profile(10)), "ten without r11 learned yet: no")
	assert_true(RunicStone.knows_final(_profile(10, true)), "r11 (all ten known): yes")
	assert_false(RunicStone.knows_final(ProfileStore.new("")), "a fresh profile: no")
	assert_false(FloorPlan.of_profile(&"five_floors", 7, _profile(10), true).heart_room)
	assert_true(FloorPlan.of_profile(&"five_floors", 7, _profile(10, true), true).heart_room)


func test_the_room_is_there_only_with_the_flag() -> void:
	var off := _final(31, false)
	assert_not_null(off.approach, "the final approach")
	assert_null(off.heart, "no heart room without the flag")
	assert_null(off.breakables, "no cracked wall")
	assert_eq(off.floor_layout.heart_room, -1)
	assert_eq(off.floor_layout.rooms.size(), 1, "one room, as before")
	assert_true(off.floor_layout.door_rooms.is_empty(), "no doorway")
	assert_eq(off.interactables.size(), 2, "the two pylons only")
	var on := _final(31, true)
	var f := on.floor_layout
	assert_not_null(on.heart, "the heart room")
	assert_eq(f.heart_room, 1)
	assert_eq(f.crack_room, f.heart_room, "behind the cracked wall")
	assert_true(on.breakables != null and on.breakables.has_crack(), "a crack the Skill wears down")
	assert_eq(on.breakables.crack_max, 3, "three Skill uses (the secrets' crack_hits)")
	assert_true(f.rooms[1].position.x >= FinalArena.radius_of(f), "beyond the ring")
	assert_true(f.light_walls.has(f.crack_wall), "the walls of light seal its doorway at the fight")
	assert_eq(on.interactables.size(), 4, "the pylons, the pedestal and the door")
	assert_true(on.heart.relic_here(on), "the City's Heart on its pedestal")


func test_without_the_flag_the_final_approach_is_as_it_was_on_1000_seeds() -> void:
	var def: FinalArenaDefinition = _content().get_def(
		&"final_arena", FinalLab.run_state(1).table.final_arena
	)
	var changed := 0
	var added_only := 0
	for s in _seeds:
		var seed_value := RngStream.derive(s + 1, "o14b").next_u32()
		var off := FinalArena.approach_layout(seed_value, def.radius_m, def.segments)
		var again := FinalArena.approach_layout(seed_value, def.radius_m, def.segments)
		if _layout_key(off) != _layout_key(again) or off.heart_room != -1 or off.crack_room != -1:
			changed += 1
		var on := FinalArena.approach_layout(seed_value, def.radius_m, def.segments)
		FinalArena.add_heart_room(on)
		# The room only adds: the ring less its one segment, the causeway, the plateau, the pylons stay.
		var kept: Array[Obb] = []
		for i in off.walls.size():
			if (
				off.walls[i] != null
				and not (off.walls[i].angle == 0 and off.walls[i].center.x > 0.0)
			):
				kept.append(off.walls[i])
		var same := on.heart_wall_first == kept.size()
		for i in mini(kept.size(), on.heart_wall_first):
			same = same and _obb_key(kept[i]) == _obb_key(on.walls[i])
		same = same and on.rooms[0] == off.rooms[0] and on.start_pos == off.start_pos
		same = same and on.pylons == off.pylons and on.altar_pos == off.altar_pos
		if same:
			added_only += 1
	gut.p("HEART_1000| seeds=%d off_changed=%d on_added_only=%d" % [_seeds, changed, added_only])
	assert_eq(changed, 0, "flag off: the final approach's layout is the plain one, seed for seed")
	assert_eq(added_only, _seeds, "flag on: the room only adds to it")


func test_the_floors_do_not_read_the_flag() -> void:
	var repo := _content()
	var def: RunDefinition = repo.get_def(&"run", RunSaver.RUN_ID)
	var differ := 0
	for s in 12:
		var hashes := []
		for heart in [false, true]:
			var run := SaveLab.run_state(900 + s, 1 + s % 5)
			run.heart_room = heart
			var plan := FloorPlan.next_floor(run, def.biomes.duplicate(), {}, true)
			plan.repo = repo
			plan.build()
			_step(plan.world, 30)
			hashes.append(plan.world.state_hash())
		if hashes[0] != hashes[1]:
			differ += 1
	assert_eq(differ, 0, "a run floor hashes the same with the flag on or off")


func test_the_pedestal_gives_the_city_heart_once() -> void:
	var w := _final(44, true)
	_break_and_enter(w)
	assert_false(Relics.held(w, Relics.CITY_HEART), "not yet held")
	assert_eq(
		w.interactables.kind[w.interactables.in_reach(w.player_pos())],
		Interactables.Kind.HEART_PEDESTAL
	)
	_press(w)
	assert_true(Relics.held(w, Relics.CITY_HEART), "taken")
	assert_eq(w.heart.taken, 1)
	assert_false(w.heart.relic_here(w), "the pedestal is empty")
	assert_eq(w.interactables.in_reach(w.player_pos()), -1, "no prompt by an empty pedestal")


func test_the_heart_catches_the_first_killing_blow_only() -> void:
	var w := _final(45, true)
	_break_and_enter(w)
	_press(w)
	var t := Relics.table(w, Relics.CITY_HEART)
	assert_eq(t.saved_hp, 1)
	assert_eq(t.ring_radius_m, 4.0)
	var me := w.player_pos()
	var near := _enemy_at(w, me + Vector2(0.0, -2.5))
	var far := _enemy_at(w, me + Vector2(0.0, -6.0))
	var near_hp := w.actors.hp[near]
	var far_hp := w.actors.hp[far]
	w.actors.hp[0] = 20
	w.actors.invuln[0] = 0
	Damage.hit(w, 0, 500, w.actors.ids[near], w.actors.ids[near], w.take_root(), 0, me, me)
	assert_eq(w.actors.hp[0], 1, "left at 1 HP")
	assert_eq(w.actors.dead[0], 0, "alive")
	assert_eq(Relics.spent(w, Relics.CITY_HEART), 1, "its one use spent")
	assert_eq(w.relic_pulse_tick, w.tick, "the ring pulsed now")
	assert_eq(near_hp - w.actors.hp[near], t.ring_damage, "an enemy 2.5 m away takes the ring")
	assert_eq(w.actors.hp[far], far_hp, "one 6 m away does not")
	w.actors.invuln[0] = 0
	Damage.hit(w, 0, 500, w.actors.ids[near], w.actors.ids[near], w.take_root(), 0, me, me)
	assert_eq(w.actors.dead[0], 1, "the second killing blow kills")


func test_once_a_run_the_carry_keeps_the_spent_heart() -> void:
	var w := _final(46, true)
	_break_and_enter(w)
	_press(w)
	w.actors.hp[0] = 5
	w.actors.invuln[0] = 0
	Damage.hit(w, 0, 99, 0, 0, w.take_root(), 0, w.player_pos(), w.player_pos())
	var carry := RunCarry.take(w, 0)
	assert_true(carry.has(&"relics"), "the carry holds the relic")
	var next := _final(47, false)
	RunCarry.apply(next, carry)
	assert_true(Relics.held(next, Relics.CITY_HEART), "held on the next floor")
	assert_false(Relics.ready(next, Relics.CITY_HEART), "its use already spent this run")
	next.actors.hp[0] = 5
	next.actors.invuln[0] = 0
	Damage.hit(next, 0, 99, 0, 0, next.take_root(), 0, next.player_pos(), next.player_pos())
	assert_eq(next.actors.dead[0], 1, "no second save")
	var none := RunCarry.take(_final(48, false), 0)
	assert_false(none.has(&"relics"), "no relic held: no key in the carry (as before)")


func test_without_the_heart_the_hero_dies() -> void:
	var w := _final(49, true)
	w.actors.hp[0] = 5
	w.actors.invuln[0] = 0
	Damage.hit(w, 0, 99, 0, 0, w.take_root(), 0, w.player_pos(), w.player_pos())
	assert_eq(w.actors.dead[0], 1, "not taken: no save")


func test_the_door_stays_sealed() -> void:
	var w := _final(50, true)
	_break_and_enter(w)
	var f := w.floor_layout
	w.actors.set_pos(0, f.heart_door + Vector2(0.0, -1.2))
	_step(w, 2)
	assert_eq(w.interactables.in_reach(w.player_pos()), -1, "no prompt at the sealed door")
	_press(w)
	_step(w, 600)
	assert_eq(w.heart.door, HeartRoom.Door.SEALED, "still sealed (N2)")
	assert_false(HeartRoom.door_opens(w), "the remembered Crown's hook says no")
	assert_eq(w.heart.door_tick, -1)
	assert_true(
		WorldReader.new(w).heart_door_near(),
		"the hero stands within its reach (the rune line shows)"
	)


func test_the_fight_seals_the_heart_room_and_sets_the_hero_back() -> void:
	var w := _final(51, true)
	_break_and_enter(w)
	w.approach.state = FinalApproach.State.BUILDUP
	w.approach.buildup_tick = w.tick
	_step(w, w.approach.buildup_ticks + 2)
	assert_eq(w.approach.state, FinalApproach.State.FIGHT, "the fight began")
	assert_true(
		(
			Kin.length(w.player_pos() - w.floor_layout.altar_pos)
			< FinalArena.radius_of(w.floor_layout)
		),
		"the hero is back on the plateau"
	)
	var f := w.floor_layout
	var blocked := false
	for o in w.walls:
		blocked = blocked or (o.center == f.crack_wall.center and o.half == f.crack_wall.half)
	assert_true(blocked, "a wall of light shuts the doorway")


func test_a_snapshot_restores_the_room_exactly() -> void:
	var w := _final(52, true)
	_break_and_enter(w)
	_press(w)
	_step(w, 20)
	var snap := w.to_snapshot()
	var base := _final(52, true)
	assert_eq(WorldSnapshot.apply(base, snap), "", "restores")
	assert_eq(base.state_hash(), w.state_hash(), "the same hash")
	_step(w, 60)
	_step(base, 60)
	assert_eq(base.state_hash(), w.state_hash(), "and they play on the same")
	assert_true(Relics.held(base, Relics.CITY_HEART))
	assert_eq(base.breakables.crack_broken, 1)


func test_the_same_seed_builds_the_same_room() -> void:
	var a := _final(53, true)
	var b := _final(53, true)
	_step(a, 90)
	_step(b, 90)
	assert_eq(a.state_hash(), b.state_hash(), "deterministic")


func _layout_key(f: FloorLayout) -> String:
	var parts := PackedStringArray()
	for o in f.walls:
		parts.append(_obb_key(o))
	parts.append(str(f.rooms))
	parts.append(str(f.start_pos))
	parts.append(str(f.light_walls.size()))
	parts.append(str(f.pylons))
	return "|".join(parts)


func _obb_key(o: Obb) -> String:
	return "%s/%s/%d" % [o.center, o.half, o.angle]
