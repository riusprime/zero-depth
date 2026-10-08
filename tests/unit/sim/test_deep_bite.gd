extends GutTest
## v0.5.5 Step DS (owner S5, "Used deep portals but I felt like nothing changed"): Deep floors bite. An elite in every
## combat room (the first pack in each room), +1 threat T (which raises the hidden catch-up's caps), the epic altar at
## the floor's end (the free spot nearest the boss door), and a Deep-only event on every Deep floor (never on a normal
## one). The violet look is the view's (tests/unit/presentation/test_deep_look.gd).

const LONG := 1 << 24


func _deep(seed_value: int, f: int = 2) -> World:
	return SaveLab.build_floor(SaveLab.run_state(seed_value, f, &"blade", Routes.Route.DEEP))


func _normal(seed_value: int, f: int = 2) -> World:
	return SaveLab.build_floor(SaveLab.run_state(seed_value, f, &"blade", Routes.Route.NORMAL))


func _room_of_event(w: World, id: StringName) -> int:
	for k in w.ev.ids.size():
		if w.ev.events[w.ev.event[k]].id == id:
			return k
	return -1


func test_the_first_pack_in_each_room_of_a_deep_floor_brings_an_elite() -> void:
	var w := _deep(51)
	var f := w.floor_layout
	var kind := w.spawner.kinds[0]
	var a := f.rooms[1].get_center()
	var b := f.rooms[2].get_center()
	w.add_enemy(kind, a)
	assert_true(SpawnDirector.deep_elite(w, w.actors.size() - 1, a), "room 1's first")
	assert_true(Curses.is_elite(w, w.actors.ids[w.actors.size() - 1]))
	w.add_enemy(kind, a)
	assert_false(SpawnDirector.deep_elite(w, w.actors.size() - 1, a), "one per room")
	w.add_enemy(kind, b)
	assert_true(SpawnDirector.deep_elite(w, w.actors.size() - 1, b), "room 2's first")
	assert_eq(w.deep_elite_rooms, PackedInt32Array([1, 2]))
	var n := _normal(51)
	n.add_enemy(kind, a)
	assert_false(SpawnDirector.deep_elite(n, n.actors.size() - 1, a), "a normal floor has none")


func test_on_a_deep_floor_the_spawns_bring_their_elites() -> void:
	var w := _deep(52)
	w.actors.invuln[0] = LONG
	var b := FightBot.new(3)
	SaveLab.run(w, b, 1500)
	assert_false(w.deep_elite_rooms.is_empty(), "packs arrived and their rooms had an elite")
	var n := _normal(52)
	n.actors.invuln[0] = LONG
	SaveLab.run(n, FightBot.new(3), 1500)
	assert_true(n.deep_elite_rooms.is_empty())


func test_a_deep_floor_is_one_threat_higher_and_its_caps_follow() -> void:
	var w := _deep(53)
	assert_eq(Curses.threat(w), 1)
	assert_eq(w.catch_up.cap, 2000 + 250, "the extra T raises the cap")
	assert_eq(_normal(53).catch_up.cap, 2000)


func test_the_epic_altar_stands_at_the_floors_end() -> void:
	for s in 6:
		var w := _deep(60 + s)
		var f := w.floor_layout
		var epic := w.rewards.index_of(w.boss_flow.epic_altar_id)
		assert_gte(epic, 0, "seed %d: guaranteed" % (60 + s))
		var spots := Routes.free_spots(w, f)  # what is left after the Deep rewards
		var d := Kin.length(w.rewards.pos(epic) - f.boss_door_center)
		for q in spots:
			assert_lte(d, Kin.length(q - f.boss_door_center) + 0.001, "nearest the boss door")
		for i in w.rewards.size():
			if (
				i != epic
				and w.rewards.price[i] > 0
				and w.rewards.ids[i] > w.boss_flow.epic_altar_id
			):
				assert_lte(d, Kin.length(w.rewards.pos(i) - f.boss_door_center) + 0.001)


func test_every_deep_floor_has_the_deep_event_and_no_normal_floor_does() -> void:
	for s in 8:
		var w := _deep(70 + s)
		if w.ev.ids.is_empty():
			continue  # a layout with no event room
		assert_gte(_room_of_event(w, &"whispering_deep"), 0, "Deep seed %d" % (70 + s))
		for f in [2, 3]:
			assert_eq(
				_room_of_event(_normal(70 + s, f), &"whispering_deep"),
				-1,
				"normal seed %d" % (70 + s)
			)


func test_the_deep_event_offers_its_two_choices() -> void:
	var w := _deep(71)
	var k := _room_of_event(w, &"whispering_deep")
	assert_gte(k, 0)
	var t := w.ev.events[w.ev.event[k]]
	assert_true(t.deep_only)
	assert_eq(t.choice_count(), 2)
	assert_eq(t.curse[0], Events.CURSE_RANDOM, "listen: an epic card for a curse")
	assert_eq(t.reward[0], Events.Reward.STAT_EPIC)
	assert_eq(t.cost[1], Events.Cost.HP, "bleed: HP for a mod")
	assert_eq(t.reward[1], Events.Reward.MOD)
	assert_eq(tr(t.name_key), "Whispering Deep")
