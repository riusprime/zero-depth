extends GutTest
## v0.8.0 BS2 (owner O5; BOSS_SIGNATURES.md "What every row also gets": starting values, tunable in F10): the new
## signature numbers of the Hive Lens (the Gaze's turn), the Siege Engine (its ricochets) and the Foundry (its lava and
## meltdown) are rows of the F10 Bosses page (DevFields walks every field of the boss file, shape params included).


func _rows(path: String) -> Dictionary:
	var out := {}
	for r: Dictionary in DevFields.rows(load(path)):
		out[r["path"]] = r["value"]
	return out


func _attack(path: String, id: StringName) -> int:
	var def := load(path) as BossDefinition
	for k in def.attacks.size():
		if def.attacks[k].id == id:
			return k
	return -1


func test_the_new_signature_numbers_are_f10_rows() -> void:
	var cases := [
		[
			"res://data/bosses/hive_lens.tres",
			&"gaze",
			{
				"quarter_seconds": 2.0,
				"reverse_seconds": 8.0,
				"orb_every_seconds": 3.0,
				"burn_seconds": 0.5
			}
		],
		["res://data/bosses/siege_engine.tres", &"turret_cross", {"bounces": 1}],
		["res://data/bosses/siege_engine.tres", &"deploy", {"bounce_phase": 3}],
		[
			"res://data/bosses/foundry.tres",
			&"molten_flood",
			{"lava_seconds": 5.0, "lava_damage": 6, "lava_burn_seconds": 0.5, "ford_m": 2.0}
		],
		[
			"res://data/bosses/foundry.tres",
			&"meltdown",
			{
				"ring_m": 4.0,
				"min_radius_m": 7.0,
				"step_m": 2.0,
				"step_seconds": 8.0,
				"warn_seconds": 2.0
			}
		],
	]
	for c: Array in cases:
		var rows := _rows(c[0])
		var k := _attack(c[0], c[1])
		assert_gte(k, 0, "%s has %s" % [c[0], c[1]])
		for p: String in c[2] as Dictionary:
			var key := "attacks/%d/shape_params/%s" % [k, p]
			assert_true(rows.has(key), "%s: %s is a row" % [c[1], key])
			assert_eq(rows.get(key), c[2][p], "%s: its starting value" % key)
