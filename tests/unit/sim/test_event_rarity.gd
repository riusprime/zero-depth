extends GutTest
## v0.9.5 AQ (owner: event altars "more special like the curse room"): an event room on about a third of floors, at
## most two a run, never the same event twice; the run's list rides the carry and old saves load without it.

const SEEDS := 2000
const RUNS := 200
const WORLD_RUNS := 40
const FLOORS := 5

var _rules: EventRules


func before_all() -> void:
	_rules = EventCompiler.compile_rules(EventLab.repo().get_def(&"event_rules", &"floor"))


func _layout(seed_value: int) -> FloorLayout:
	var layout := FloorGenerator.generate(seed_value)
	BossRoomBuilder.attach(layout, BossArenaSpec.new())
	OverrunRooms.mark(layout)
	ShopPlacement.pick(layout)
	return layout


func test_the_shipped_rules_are_rare() -> void:
	assert_eq(
		[_rules.event_floor_chance_permille, _rules.events_max_per_run, _rules.rooms_max],
		[300, 2, 1]
	)


func test_about_a_third_of_floors_have_an_event_room() -> void:
	var with_room := 0
	var most := 0
	for s in SEEDS:
		var seed_value := 5000 + s * 7919
		var rooms := Events.pick_rooms(_layout(seed_value), seed_value, _rules, PackedInt32Array())
		if not rooms.is_empty():
			with_room += 1
		most = maxi(most, rooms.size())
	var rate := float(with_room) / SEEDS
	gut.p("event-room rate over %d floors: %d (%.1f %%)" % [SEEDS, with_room, rate * 100.0])
	assert_between(rate, 0.25, 0.35, "about 30 % of floors")
	assert_lte(most, 1, "never two on a floor")


func test_a_run_never_gets_a_third_event_room() -> void:
	var worst := 0
	for s in RUNS:
		var done := 0
		for f in FLOORS:
			var seed_value := 5000 + (s * FLOORS + f) * 7919
			var layout := _layout(seed_value)
			done += Events.pick_rooms(layout, seed_value, _rules, PackedInt32Array(), done).size()
		worst = maxi(worst, done)
		assert_lte(done, _rules.events_max_per_run, "run %d" % s)
	gut.p("most event rooms in a %d-floor run over %d runs: %d" % [FLOORS, RUNS, worst])


func test_a_run_never_places_the_same_event_twice() -> void:
	var total := 0
	for s in WORLD_RUNS:
		var seen := PackedInt32Array()
		for f in range(1, FLOORS + 1):
			var w := EventLab.world(60 + s, f, &"blade", [], true, {&"events_seen": seen})
			for k in w.ev.size():
				if k == w.ev.curse_k:
					continue
				assert_false(seen.has(w.ev.event[k]), "run %d floor %d: a repeat" % [s, f])
				total += 1
			assert_lte(w.events_seen.size() - seen.size(), 1, "at most one common event a floor")
			seen = w.events_seen
		assert_lte(seen.size(), _rules.events_max_per_run, "run %d: the cap" % s)
	gut.p("common event rooms over %d runs x %d floors: %d" % [WORLD_RUNS, FLOORS, total])


func test_a_floor_saved_before_aq_keeps_its_old_draw() -> void:
	var w := EventLab.world(3, 1)  # the lab's default: the old rules
	assert_between(w.ev.size(), 1, 2)
	assert_eq(w.events_seen.size(), 0, "the old draw records nothing")


func test_the_list_rides_the_carry_and_the_run_save() -> void:
	var w := EventLab.world(11, 1, &"blade", [], true, {&"events_seen": PackedInt32Array([2, 5])})
	assert_true(w.events_seen.has(2) and w.events_seen.has(5), "the carry arrives")
	var carry := RunCarry.take(w, 0)
	assert_eq(carry[&"events_seen"], w.events_seen, "the carry keeps the list")
	var run := SaveLab.run_state(11, 2)
	run.carry = carry
	var back := SaveLab.run_from(RunSaver.payload_of(w, run, 1, PackedByteArray()))
	assert_eq(back.carry[&"events_seen"], w.events_seen, "the run save round-trips it")


func test_a_carry_without_the_list_loads_as_empty() -> void:
	var carry := RunCarry.take(EventLab.world(11, 1), 0)
	carry.erase(&"events_seen")
	var run := SaveLab.run_state(11, 2)
	run.carry = carry
	var back := SaveLab.run_from(
		RunSaver.payload_of(EventLab.world(11, 1), run, 1, PackedByteArray())
	)
	var w := EventLab.world(11, 2, &"blade", [], true, back.carry)
	assert_false(w.events_seen.has(-1))
	assert_lte(w.events_seen.size(), 1, "no list: only this floor's own draw")
