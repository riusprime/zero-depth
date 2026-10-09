extends GutTest
## v0.5.0 EV content: the shipped events, curses and rules validate and compile as CONTENT_SCHEMA §7 says, and bad
## definitions are refused with their codes.


func _codes(issues: Array[ValidationIssue]) -> Array:
	return issues.map(func(i: ValidationIssue) -> StringName: return i.code)


func test_the_shipped_events_curses_and_rules_compile() -> void:
	var repo := EventLab.repo()
	assert_eq(repo.errors().size(), 0, "content validates")
	assert_eq(repo.count(&"events"), 9, "nine events (v0.5.5 DS: Whispering Deep)")
	assert_eq(repo.count(&"curses"), 13, "five plain curses and eight trade-offs (v0.6.0 CU)")
	var events := EventCompiler.compile_events(repo)
	for t in events:
		assert_between(t.choice_count(), 1, 2, "%s choices" % t.id)
		for c in t.choice_count():
			assert_gte(t.cost[c], 0, "%s cost known" % t.id)
			assert_gte(t.reward[c], 0, "%s reward known" % t.id)
			assert_ne(t.curse[c], -3)
	var curses := EventCompiler.compile_curses(repo)
	var by_id := {}
	for c in curses:
		by_id[c.id] = c
	assert_eq(by_id[&"swift_foes"].amount, 150, "15 % in per mille")
	assert_eq(by_id[&"swarm_call"].amount, 1, "a count stays a count")
	var rules := EventCompiler.compile_rules(repo.get_def(&"event_rules", &"floor"))
	assert_eq([rules.rooms_min, rules.rooms_max], [1, 2])
	assert_eq(rules.cursed_chest_permille, 250)
	var drone: EventTable = events.filter(func(t: EventTable) -> bool: return t.id == &"wandering_drone")[0]
	assert_eq(drone.cost_amount[0], 20 * 60, "20 s in ticks")


func test_bad_definitions_are_refused() -> void:
	var e := EventDefinition.new()
	e.id = &"bad_event"
	e.requires = &"luck"
	var free := EventChoiceDefinition.new()
	free.label_key = &"X"
	free.cost = &"none"
	var chest := EventChoiceDefinition.new()
	chest.label_key = &"Y"
	chest.cost = &"hp"
	chest.cost_amount = 120.0
	chest.reward = &"chest"
	var three: Array[EventChoiceDefinition] = [free, chest, free]
	e.choices = three
	var codes := _codes(e.validate())
	for code in [&"missing", &"unknown", &"range", &"free"]:
		assert_has(codes, code)
	var c := CurseDefinition.new()
	c.id = &"bad_curse"
	c.name_key = &"N"
	c.desc_key = &"D"
	c.effect = &"bad_luck"
	c.amount = 0.0
	c.threat = 0
	codes = _codes(c.validate())
	for code in [&"unknown", &"not_positive", &"range"]:
		assert_has(codes, code)
	var r := EventRulesDefinition.new()
	r.id = &"bad_rules"
	r.rooms_min = 3
	r.rooms_max = 1
	r.cursed_chest_chance = 120.0
	assert_has(_codes(r.validate()), &"range")
