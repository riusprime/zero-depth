extends GutTest
## v0.5.0 EV (PLAN R3): which rooms hold an event, over 1,000 generated floors. Each floor gets 1-2 event rooms
## (rules rooms_min..rooms_max), always side rooms (never the start hall, the boss room or the room before the boss
## door), each with a pedestal spot inside the room, clear of every wall and of every altar or chest spot; the pick
## is a pure function of the layout and the seed, and rooms another side-room kind took (`taken`) are never used.

const SEEDS := 1000

var _rules: EventRules


func before_all() -> void:
	_rules = EventCompiler.compile_rules(EventLab.repo().get_def(&"event_rules", &"floor"))


func _layout(seed_value: int) -> FloorLayout:
	var layout := FloorGenerator.generate(seed_value)
	BossRoomBuilder.attach(layout, BossArenaSpec.new())
	return layout


func test_every_floor_gets_one_or_two_side_rooms_with_a_clear_pedestal() -> void:
	var counts := {}
	var bad := 0
	for s in SEEDS:
		var seed_value := 7000 + s * 7919
		var layout := _layout(seed_value)
		var rooms := Events.pick_rooms(layout, seed_value, _rules, PackedInt32Array())
		counts[rooms.size()] = counts.get(rooms.size(), 0) + 1
		var ok := rooms.size() >= _rules.rooms_min and rooms.size() <= _rules.rooms_max
		for r in rooms:
			ok = ok and r != layout.start_room and r != layout.boss_room
			ok = ok and r != layout.boss_host_room and r != layout.portal_room
			ok = ok and rooms.count(r) == 1
			var at := Events.spot(layout, r, _rules)
			ok = ok and at.size() == 1 and layout.room_of(at[0]) == r
			if at.size() == 1:
				for o in layout.walls:
					ok = (
						ok
						and Collide.circle_vs_obb(at[0], _rules.clear_radius_m, o) == Vector2.ZERO
					)
				for p in layout.item_spots:
					ok = ok and p.distance_to(at[0]) >= _rules.reward_gap_m
		if not ok:
			bad += 1
			gut.p("seed %d: rooms %s" % [seed_value, rooms])
	gut.p("event rooms per floor over %d seeds: %s" % [SEEDS, counts])
	assert_eq(bad, 0, "every floor's event rooms are valid side rooms")
	assert_gt(counts.get(1, 0), 0, "some floors have one")
	assert_gt(counts.get(2, 0), 0, "some floors have two")


func test_the_pick_is_deterministic_and_keeps_out_taken_rooms() -> void:
	for s in 200:
		var seed_value := 11 + s * 104729
		var layout := _layout(seed_value)
		var a := Events.pick_rooms(layout, seed_value, _rules, PackedInt32Array())
		var b := Events.pick_rooms(_layout(seed_value), seed_value, _rules, PackedInt32Array())
		assert_eq(a, b, "seed %d: same rooms" % seed_value)
		var c := Events.pick_rooms(layout, seed_value, _rules, a)
		for r in c:
			assert_false(a.has(r), "seed %d: a taken room is never an event room" % seed_value)


func test_a_floor_world_places_its_pedestals_with_different_events() -> void:
	for seed_value in [3, 17, 2026]:
		var w := EventLab.world(seed_value)
		var n := w.ev.size()
		assert_between(n, 1, 2, "seed %d: pedestals" % seed_value)
		var seen := {}
		for k in n:
			assert_eq(w.ev.state[k], Events.State.READY)
			assert_false(seen.has(w.ev.event[k]), "no event twice on a floor")
			seen[w.ev.event[k]] = true
			assert_eq(w.floor_layout.room_of(w.ev.pos(k)), w.ev.room[k])
			var t := Events.table(w, k)
			assert_true(Events.needs_met(w, t.requires), "%s fits the floor" % t.id)
			assert_ne(t.id, &"cleansing_font", "no cleanse without a curse")
