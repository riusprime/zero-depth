extends GutTest
## The gamble shrine's content (v0.3.0 L19): the shipped shrine validates and names every stat once; bad values are
## rejected.


func _def() -> GambleDefinition:
	return (load("res://data/gamble/shrine.tres") as GambleDefinition).duplicate_deep(
		Resource.DEEP_DUPLICATE_ALL
	)


func _codes(d: GambleDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_the_shipped_shrine_is_valid_and_names_every_stat() -> void:
	var repo := ContentRepository.load_all()
	assert_eq(repo.count(&"gamble"), 1)
	var def: GambleDefinition = repo.get_def(&"gamble", &"shrine")
	assert_eq(def.validate(), [])
	var named := []
	for e in def.stats:
		named.append(String(e.stat))
	named.sort()
	var all := Array(GambleStatEntry.STATS).map(func(s: StringName) -> String: return String(s))
	all.sort()
	assert_eq(named, all, "every stat in the pool, once")


func test_bad_values_are_rejected() -> void:
	var d := _def()
	d.base_price = 0
	d.price_step = -0.1
	d.floor_price_step = -1.0
	d.interact_radius_m = 0.0
	d.stats[0].weight = 0
	d.stats[1].max_stacks = 0
	d.stats[2].amount = 0.0
	var codes := _codes(d)
	assert_gte(codes.count(&"not_positive"), 5)
	assert_eq(codes.count(&"negative"), 2)


func test_unknown_and_duplicate_stats_are_rejected() -> void:
	var d := _def()
	d.stats[0].stat = &"luck"
	d.stats[2].stat = d.stats[1].stat
	var codes := _codes(d)
	assert_has(codes, &"unknown_stat")
	assert_has(codes, &"duplicate_stat")
	d.stats.clear()
	assert_has(_codes(d), &"missing")
