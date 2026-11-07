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
		26,
		(
			"charger, warden, needle, the hatchling (v0.3.0 C), the Arc Caster and the Bomb Drone (v0.3.5),"
			+ " six horde kinds and the Splitling (v0.4.0 EN), the Lens Drone (v0.4.0 BO),"
			+ " the five horde critters (v0.11.0 O9)"
			+ ", the five biome variants (v0.11.0 O13a)"
			+ " and the two Starfall signatures (v0.11.0 O13d)"
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
	assert_eq(arc.windup_ticks, 30, "the bolt winds up for 30 ticks")
	assert_eq(arc.rune_windup_ticks, 36, "the rune erupts after 36 ticks")
	var drone := ContentCompiler.compile_enemy(repo.get_def(&"enemies", &"bomb_drone"))
	assert_eq(drone.kind, ActorStore.Kind.BOMB_DRONE)
	assert_eq([drone.hp, drone.damage, drone.shards], [30, 16, 4])
	assert_eq([drone.keep_min_m, drone.keep_distance_m], [5.0, 8.0])
	assert_eq(drone.windup_ticks, 48, "the bomb winds up for 48 ticks")


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


## v0.7.0 audit A-13: a shape param the compiler divides by or turns into ticks must be > 0 (a 0 speed made the
## bolt's life an undefined tick count); every shipped enemy passes (test_the_shipped_enemies_are_valid_and_compile).
func test_a_zero_shape_param_is_rejected() -> void:
	for k in ["speed_mps", "length_m"]:
		var d := _def()
		var atk: AttackDefinition = d.attacks[0].duplicate()
		atk.shape_params = atk.shape_params.duplicate()
		atk.shape_params[k] = 0.0
		d.attacks[0] = atk
		assert_has(_codes(d), &"not_positive", k)
	var ok := _def()
	assert_eq(_codes(ok), [], "the shipped charger passes")


## v0.7.5 EF (owner N16): the three fireball enemies name patterns that exist, each slow (the design's 3-5 m/s) and in
## its own look; the Needle, the Sniper and the melee kinds keep their own attacks (no pattern).
func test_the_fireball_enemies_name_slow_patterns_in_their_own_looks() -> void:
	var repo := ContentRepository.load_all()
	var want := {
		&"arc_caster": [[2, &"arc_plasma"], [2, &"arc_plasma"], null],
		&"lens_drone": [[0, &"lens_orb"]],
		&"bomb_drone": [[6, &"bomb_cinder"]],
	}
	for id: StringName in want:
		var t := ContentCompiler.compile_enemy(repo.get_def(&"enemies", id), repo)
		var specs: Array = want[id]
		assert_eq(t.patterns.size(), specs.size(), String(id))
		for k in specs.size():
			var pat: BulletPatternTable = t.patterns[k]
			if specs[k] == null:
				assert_null(pat, "%s attack %d fires no pattern (the rune)" % [id, k])
				continue
			assert_not_null(pat, "%s attack %d names a pattern that exists" % [id, k])
			assert_eq([pat.kind, pat.look], specs[k], String(id))
			assert_between(pat.speed * 60.0, 3.0, 5.0, "%s: slow" % id)
	for id: StringName in [&"needle", &"sniper", &"charger", &"warden"]:
		var t := ContentCompiler.compile_enemy(repo.get_def(&"enemies", id), repo)
		assert_true(t.patterns.is_empty(), "%s keeps its own attack" % id)


## v0.11.0 O9 (PLAN H1; owner Q14): the five critters, one per biome, share one rule set: no attack, a touch, 8 HP;
## only the Cave Bat flies. A non-bool `flies` and a biome naming no critter are refused.
func test_the_horde_critters_compile_to_one_rule_set() -> void:
	var repo := ContentRepository.load_all()
	var by_biome := {}
	for b: BiomeDefinition in repo.all_of(&"biomes"):
		by_biome[b.id] = b.critter_id
	assert_eq(
		by_biome,
		{
			&"ruins": &"dust_mite",
			&"night_rocks": &"cave_bat",
			&"red_canyon": &"ember_flea",
			&"frozen_shore": &"ice_crab",
			&"starfall": &"star_mote",
		}
	)
	for id: StringName in by_biome.values():
		var t := ContentCompiler.compile_enemy(repo.get_def(&"enemies", id))
		assert_true(EnemyAi.is_critter(t.kind), String(id))
		assert_eq(t.hp, 8, "%s: ~8 HP" % id)
		assert_gt(t.damage, 0, "%s: its touch hurts" % id)
		assert_eq(t.contact_cd_ticks, 30, "%s: 0.5 s between touches" % id)
		assert_eq(t.attack_range_m, 0.0, "%s: no attack" % id)
		assert_eq(t.flies, id == &"cave_bat", "%s: only the bat flies" % id)
	var bad := (repo.get_def(&"enemies", &"dust_mite") as EnemyDefinition).duplicate(true)
	bad.behaviour_params["flies"] = 1
	assert_has(_codes(bad), &"flies")
	bad.behaviour_params["flies"] = false
	bad.behaviour_params["contact_damage"] = 0
	assert_has(_codes(bad), &"not_positive")
	var biome := (repo.get_def(&"biomes", &"ruins") as BiomeDefinition).duplicate(true)
	biome.critter_id = &"charger"
	var defs: Array[ContentDef] = [biome]
	defs.append_array(repo.all_of(&"enemies"))
	var codes := BiomeDefinition.cross_check(defs).map(
		func(v: ValidationIssue) -> StringName: return v.code
	)
	assert_eq(codes, [&"critter_unknown"], "a Charger is no critter")


## v0.11.0 O13a (PLAN M3; owner Q23; ENEMIES.md V1-V5): each biome's roster is the shared core of four, its two
## signature enemies (R1-R10, listed before their kinds exist) and its variant; the five variants are valid, compile as
## their base plus their own numbers, and each belongs to one biome.
func test_each_biome_has_its_roster_and_variant() -> void:
	var repo := ContentRepository.load_all()
	var want := {
		&"ruins": [&"rubble_warden", [&"wire_weaver", &"scrap_hound"]],
		&"night_rocks": [&"dim_needle", [&"rock_lurker", &"stone_thrower"]],
		&"red_canyon": [&"ember_charger", [&"kiln_beetle", &"cinder_priest"]],
		&"frozen_shore": [&"frost_charger", [&"frost_spitter", &"glacier_turtle"]],
		&"starfall": [&"split_sniper", [&"star_warper", &"gravity_node"]],
	}
	for id: StringName in want:
		var b: BiomeDefinition = repo.get_def(&"biomes", id)
		assert_eq(b.validate(), [], String(id))
		for c: StringName in [&"charger", &"needle", &"swarmer", &"warden"]:
			assert_has(b.core_ids, c, "%s: the shared core" % id)
		assert_eq(b.core_ids.size(), 4, "%s: the core of four" % id)
		assert_eq(b.variant_id, want[id][0], "%s: its variant" % id)
		assert_eq(Array(b.signature_ids), want[id][1], "%s: its two signatures" % id)
		var kinds := VariantCompiler.roster_kinds(repo, b)
		var v := ContentCompiler.compile_enemy(repo.get_def(&"enemies", b.variant_id))
		# its variant and its signatures already built (O13b-d add theirs; v0.11.0 O13d: Starfall's two)
		var own := PackedInt32Array([v.kind])
		for sig: StringName in b.signature_ids:
			if repo.get_def(&"enemies", sig) != null:
				own.append(ContentCompiler.compile_enemy(repo.get_def(&"enemies", sig)).kind)
		own.sort()
		assert_eq(kinds, own, "%s: its variant and its built signatures" % id)
		if id == &"starfall":
			assert_eq(
				kinds.size(), 3, "starfall: the Split Sniper, the Star Warper, the Gravity Node"
			)
	var defs: Array[ContentDef] = []
	defs.append_array(repo.all_of(&"enemies"))
	defs.append_array(repo.all_of(&"biomes"))
	assert_eq(BiomeDefinition.cross_check(defs), [], "the shipped rosters cross-check")
	var bases := {
		&"rubble_warden": ActorStore.Kind.WARDEN,
		&"dim_needle": ActorStore.Kind.NEEDLE,
		&"ember_charger": ActorStore.Kind.CHARGER,
		&"frost_charger": ActorStore.Kind.CHARGER,
		&"split_sniper": ActorStore.Kind.SNIPER,
	}
	for id: StringName in bases:
		var t := ContentCompiler.compile_enemy(repo.get_def(&"enemies", id))
		assert_eq(EnemyAi.behaviour_of(t.kind), bases[id], "%s runs its base" % id)
		assert_true(Variants.is_variant(t.kind), String(id))
	assert_eq(ContentCompiler.compile_enemy(repo.get_def(&"enemies", &"rubble_warden")).hp, 130)


func test_bad_rosters_are_rejected() -> void:
	var repo := ContentRepository.load_all()
	var ruins := (repo.get_def(&"biomes", &"ruins") as BiomeDefinition).duplicate(true)
	ruins.core_ids.assign([&"charger", &"needle", &"swarmer"])
	assert_has(
		ruins.validate().map(func(v: ValidationIssue) -> StringName: return v.code), &"roster"
	)
	var typo := (repo.get_def(&"biomes", &"ruins") as BiomeDefinition).duplicate(true)
	typo.signature_ids.assign([&"wire_weavr", &"scrap_hound"])
	var twice := (repo.get_def(&"biomes", &"starfall") as BiomeDefinition).duplicate(true)
	twice.variant_id = &"rubble_warden"
	var plain := (repo.get_def(&"biomes", &"red_canyon") as BiomeDefinition).duplicate(true)
	plain.variant_id = &"charger"
	for b: BiomeDefinition in [typo, twice, plain]:
		var defs: Array[ContentDef] = [repo.get_def(&"biomes", &"ruins"), b]
		defs.append_array(repo.all_of(&"enemies"))
		var codes := BiomeDefinition.cross_check(defs).map(
			func(v: ValidationIssue) -> StringName: return v.code
		)
		assert_has(codes, &"roster", String(b.id))
	var crust := (repo.get_def(&"enemies", &"ember_charger") as EnemyDefinition).duplicate(true)
	crust.behaviour_params["trail_arm_seconds"] = 0.1
	assert_has(_codes(crust), &"telegraph_short", "fire never burns before the telegraph minimum")
