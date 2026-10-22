extends GutTest
## v0.5.5 Step DS (owner S5, "Used deep portals but I felt like nothing changed"): Deep floors bite (v0.9.0 DP, owner
## Q24: no longer with an elite in every combat room): +1 threat T (which raises the hidden catch-up's caps), the epic
## altar at the floor's end (the free spot nearest the boss door), and a Deep-only event on every Deep floor (never on
## a normal one). The violet look is the view's (tests/unit/presentation/test_deep_look.gd).

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


## v0.9.0 DP (owner Q24, Q26b): a Deep floor's rooms no longer bring an elite (elites come from floors 4-5 and Elite
## Lockdowns, Step EL): its packs arrive as on a normal floor.
func test_a_deep_floors_packs_bring_no_elite() -> void:
	var w := _deep(52)
	w.actors.invuln[0] = LONG
	SaveLab.run(w, FightBot.new(3), 1500)
	var arrived := 0
	for i in range(1, w.actors.size()):
		if EnemyAi.is_enemy_kind(w.actors.kinds[i]):
			arrived += 1
			assert_false(Curses.is_elite(w, w.actors.ids[i]), "no Deep elite")
	assert_gt(arrived, 0, "packs arrived")
	assert_true(w.deep_elite_rooms.is_empty(), "no room brought one")


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
