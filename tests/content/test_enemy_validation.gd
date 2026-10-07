extends GutTest
## Enemy content rules (CONTENT_SCHEMA §3): the telegraph minimum and the behaviour param schema.


func _def() -> EnemyDefinition:
	return (load("res://data/enemies/charger.tres") as EnemyDefinition).duplicate(true)


func _codes(d: EnemyDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_the_shipped_enemies_are_valid_and_compile() -> void:
	var repo := ContentRepository.load_all()
	assert_eq(repo.count(&"enemies"), 3)
	for def: EnemyDefinition in repo.all_of(&"enemies"):
		assert_eq(def.validate(), [], String(def.id))
		var t := ContentCompiler.compile_enemy(def)
		assert_gte(t.windup_ticks, SimTick.MIN_TELEGRAPH_TICKS, String(def.id))


func test_a_short_telegraph_is_rejected() -> void:
	var d := _def()
	d.attacks[0].telegraph_seconds = 0.2
	assert_has(_codes(d), &"telegraph_short")


func test_params_are_checked_against_the_schema() -> void:
	var d := _def()
	d.behaviour_params.erase("attack_range_m")
	d.behaviour_params["mystery"] = 1
	var codes := _codes(d)
	assert_has(codes, &"param_missing")
	assert_has(codes, &"param_unknown")


func test_an_unknown_behaviour_is_rejected() -> void:
	var d := _def()
	d.behaviour_id = &"dragon"
	assert_has(_codes(d), &"unknown_behaviour")


func _warden() -> EnemyDefinition:
	return (load("res://data/enemies/warden.tres") as EnemyDefinition).duplicate(true)


func test_the_warden_has_no_shield_param() -> void:
	var d := _warden()
	assert_false(d.behaviour_params.has("shield_arc_degrees"))
	d.behaviour_params["shield_arc_degrees"] = 120.0
	assert_has(_codes(d), &"param_unknown", "the old block param is gone")


func test_bad_warden_armour_is_rejected() -> void:
	var bad := [
		["front_mult_permille", 0],
		["front_mult_permille", 1200],
		["rear_mult_permille", 900],
		["rear_mult_permille", 5000],
		["front_arc_degrees", -10.0],
		["rear_arc_degrees", 400.0],
		["front_arc_degrees", 270.0],
	]
	for b in bad:
		var d := _warden()
		d.behaviour_params[b[0]] = b[1]
		assert_has(_codes(d), &"armour", "%s = %s" % b)
	assert_eq(_warden().validate(), [], "the shipped Warden passes")
