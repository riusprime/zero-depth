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
