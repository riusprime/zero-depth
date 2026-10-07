extends GutTest
## Every SimEvent tag is its own bit (v0.3.0: two parallel workstreams once picked the same values).


func test_every_tag_is_a_distinct_power_of_two() -> void:
	var seen := {}
	for c in (SimEvent as Script).get_script_constant_map().keys():
		var name := String(c)
		if not name.begins_with("TAG_"):
			continue
		var v: int = (SimEvent as Script).get_script_constant_map()[c]
		assert_gt(v, 0, "%s is positive" % name)
		assert_eq(v & (v - 1), 0, "%s is a single bit" % name)
		assert_false(seen.has(v), "%s reuses the bit of %s" % [name, seen.get(v, "")])
		seen[v] = name
	assert_gt(seen.size(), 15)
