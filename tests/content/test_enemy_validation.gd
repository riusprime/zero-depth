extends GutTest
## Enemy content rules (CONTENT_SCHEMA §3): the telegraph minimum and the behaviour param schema.


func _def() -> EnemyDefinition:
	return (load("res://data/enemies/charger.tres") as EnemyDefinition).duplicate(true)


func _codes(d: EnemyDefinition) -> Array:
	return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)


func test_the_shipped_enemies_are_valid_and_compile() -> void:
	var repo := ContentRepository.load_all()
	assert_eq(
		repo.count(&"enemies"),
		14,
		(
			"charger, warden, needle, the hatchling (v0.3.0 C), the Arc Caster and the Bomb Drone (v0.3.5),"
			+ " six horde kinds and the Splitling (v0.4.0 EN), the Lens Drone (v0.4.0 BO)"
		)
	)
	for def: EnemyDefinition in repo.all_of(&"enemies"):
		assert_eq(def.validate(), [], String(def.id))
		var t := ContentCompiler.compile_enemy(def)
		assert_gte(t.windup_ticks, SimTick.MIN_TELEGRAPH_TICKS, String(def.id))
		assert_gte(t.windup_max_ticks, t.windup_ticks, String(def.id))
		assert_gte(t.rune_windup_ticks, SimTick.MIN_TELEGRAPH_TICKS, String(def.id))


## v0.3.5 AI (F4): the four old kinds draw their windup from 24..40 ticks.
func test_the_old_kinds_wind_up_for_24_to_40_ticks() -> void:
	var repo := ContentRepository.load_all()
	for id in [&"charger", &"warden", &"needle", &"hatchling"]:
		var t := ContentCompiler.compile_enemy(repo.get_def(&"enemies", id))
		assert_eq([t.windup_ticks, t.windup_max_ticks], [24, 40], String(id))


## v0.3.5 AI (F5, F6): the new kinds' numbers (PLAN "Enemy and boss AI", starting values).
func test_the_arc_caster_and_the_bomb_drone_compile_to_the_plan() -> void:
	var repo := ContentRepository.load_all()
	var arc := ContentCompiler.compile_enemy(repo.get_def(&"enemies", &"arc_caster"))
	assert_eq(arc.kind, ActorStore.Kind.ARC_CASTER)
	assert_eq([arc.hp, arc.damage, arc.shards], [40, 12, 4])
	assert_eq([arc.keep_min_m, arc.keep_distance_m], [6.0, 9.0])
	assert_almost_eq(arc.bolt_speed * 60.0, 22.0, 0.001, "a 22 m/s bolt")
	assert_eq(arc.windup_ticks, 30, "the bolt's line shows for 30 ticks")
	assert_eq(arc.spread_count, 3)
	assert_eq(arc.rune_windup_ticks, 36, "the rune erupts after 36 ticks")
	var drone := ContentCompiler.compile_enemy(repo.get_def(&"enemies", &"bomb_drone"))
	assert_eq(drone.kind, ActorStore.Kind.BOMB_DRONE)
	assert_eq([drone.hp, drone.damage, drone.shards], [30, 16, 4])
	assert_eq([drone.keep_min_m, drone.keep_distance_m], [5.0, 8.0])
	assert_eq(drone.slam_radius_m, 1.8)
	assert_eq(drone.windup_ticks, 48, "the bomb's circle fills for 48 ticks")


## v0.4.0 EN: the horde kinds' starting values (docs/roadmap/v0.4.0/evidence/ENEMIES_12.md).
func test_the_horde_kinds_compile_to_their_starting_values() -> void:
	var repo := ContentRepository.load_all()
	var c := func(id: StringName) -> EnemyTable:
		return ContentCompiler.compile_enemy(repo.get_def(&"enemies", id))
	var sw: EnemyTable = c.call(&"swarmer")
	assert_eq([sw.kind, sw.hp, sw.damage, sw.shards], [ActorStore.Kind.SWARMER, 8, 5, 1])
	assert_eq([sw.windup_ticks, sw.windup_max_ticks], [24, 30], "a 24-30 tick bite telegraph")
	assert_almost_eq(sw.charge_distance_m, 2.0, 0.001, "a short lunge")
	var sp: EnemyTable = c.call(&"splitter")
	assert_eq([sp.kind, sp.hp, sp.split_count], [ActorStore.Kind.SPLITTER, 50, 2])
	var sl: EnemyTable = c.call(&"splitling")
	assert_eq(
		[sl.kind, sl.hp, sl.split_count], [ActorStore.Kind.SPLITLING, 16, 0], "it never splits"
	)
	var sb: EnemyTable = c.call(&"shield_bearer")
	assert_eq([sb.kind, sb.hp, sb.front_mult_permille], [ActorStore.Kind.SHIELD_BEARER, 90, 0])
	assert_eq(sb.front_half_arc, ContentCompiler.degrees_to_units(60.0), "a 120-degree shield")
	var me: EnemyTable = c.call(&"mender")
	assert_eq(
		[me.kind, me.damage, me.heal_amount, me.heal_period_ticks],
		[ActorStore.Kind.MENDER, 0, 5, 30]
	)
	var ml: EnemyTable = c.call(&"mine_layer")
	assert_eq(
		[ml.kind, ml.fuse_ticks, ml.windup_ticks, ml.max_mines],
		[ActorStore.Kind.MINE_LAYER, 36, 30, 3]
	)
	assert_gte(ml.fuse_ticks, SimTick.MIN_TELEGRAPH_TICKS, "the fuse is the mine's telegraph")
	var sn: EnemyTable = c.call(&"sniper")
	assert_eq([sn.kind, sn.hp, sn.damage, sn.windup_ticks], [ActorStore.Kind.SNIPER, 30, 28, 60])


func test_a_horde_param_out_of_range_is_rejected() -> void:
	var d := (load("res://data/enemies/splitter.tres") as EnemyDefinition).duplicate(true)
	assert_eq(d.validate(), [])
	d.behaviour_params["split_count"] = 0
	assert_has(_codes(d), &"not_positive")
	d = (load("res://data/enemies/shield_bearer.tres") as EnemyDefinition).duplicate(true)
	d.behaviour_params["shield_arc_degrees"] = 400.0
	assert_has(_codes(d), &"armour")
	d = (load("res://data/enemies/mine_layer.tres") as EnemyDefinition).duplicate(true)
	d.attacks[0].telegraph_seconds = 0.3
	assert_has(_codes(d), &"telegraph_short", "a mine's fuse is held to the telegraph minimum")


func test_the_arc_caster_needs_its_three_spells_in_order() -> void:
	var d := (load("res://data/enemies/arc_caster.tres") as EnemyDefinition).duplicate(true)
	assert_eq(d.validate(), [])
	var spells: Array[AttackDefinition] = d.attacks.duplicate()
	var swapped: Array[AttackDefinition] = [spells[1], spells[0], spells[2]]
	d.attacks = swapped
	assert_has(d.validate().map(func(v: ValidationIssue) -> StringName: return v.code), &"attacks")
	var short: Array[AttackDefinition] = [spells[0], spells[1]]
	d.attacks = short
	assert_has(d.validate().map(func(v: ValidationIssue) -> StringName: return v.code), &"attacks")


func test_a_windup_range_below_its_minimum_is_rejected() -> void:
	var d := _def()
	d.attacks[0].telegraph_max_seconds = 0.3
	assert_has(_codes(d), &"telegraph_range")


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
