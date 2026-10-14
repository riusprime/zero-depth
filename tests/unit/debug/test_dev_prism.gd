extends GutTest
## v0.8.0 FB2 (owner F7; FINAL_BOSS.md F5; starting values, tunable in F10): the Prism's numbers are rows of the F10
## Bosses page (DevFields walks every field of the boss file): the DPS-based HP (its seconds, target, clamps), her
## shards, and each Cross's beams, speeds, spin, window, orbs and bolts.

const PATH := "res://data/final_boss/prism.tres"


func _rows() -> Dictionary:
	var out := {}
	for r: Dictionary in DevFields.rows(load(PATH)):
		out[r["path"]] = r["value"]
	return out


func test_the_prism_numbers_are_f10_rows() -> void:
	var rows := _rows()
	var body := {
		"hp_from_dps": true,
		"dps_measure_seconds": 20,
		"dps_min_measured_seconds": 5,
		"dps_target_seconds": 60.0,
		"dps_hp_min": 600,
		"dps_hp_max": 250000,
		"shard_count": 6,
		"shard_orbit_m": 2.3,
		"shard_turn_dps": 50.0,
	}
	for key: String in body:
		assert_true(rows.has(key), "%s is a row" % key)
		assert_eq(rows.get(key), body[key], "%s: its starting value" % key)
	var def := load(PATH) as BossDefinition
	var cross := -1
	for k in def.attacks.size():
		if def.attacks[k].id == &"cross_ring":
			cross = k
	assert_gte(cross, 0)
	var params := {
		"quarter_seconds": 2.4,
		"fast_quarter_seconds": 1.2,
		"reverse_seconds": 3.0,
		"spin_seconds": 5.0,
		"window_seconds": 2.5,
		"orb_every_seconds": 1.6,
		"bolt_every_seconds": 1.1,
	}
	for p: String in params:
		var key := "attacks/%d/shape_params/%s" % [cross, p]
		assert_true(rows.has(key), "%s is a row" % key)
		assert_eq(rows.get(key), params[p], "%s: its starting value" % key)
