extends GutTest
## v0.8.0 FB3 (owner F6, F7; FINAL_BOSS.md F6, F7; starting values, tunable in F10): the Nemesis's numbers are rows of
## the F10 Bosses page (DevFields walks every field of the boss file): its echo, dash, stances and cards, its HP and hit
## from the build (the formula's factors and clamps), the clamps on its copies of your attacks, and each attack's lock.

const PATH := "res://data/final_boss/nemesis.tres"


func _rows() -> Dictionary:
	var out := {}
	for r: Dictionary in DevFields.rows(load(PATH)):
		out[r["path"]] = r["value"]
	return out


func test_the_nemesis_numbers_are_f10_rows() -> void:
	var rows := _rows()
	var body := {
		"mimic": true,
		"echo_seconds": 0.5,
		"dash_reaction_seconds": 0.25,
		"stance_seconds": 1.5,
		"stance_weights/0": 3,
		"stance_weights/3": 2,
		"back_off_m": 6.0,
		"card_casts": 3,
		"hp_from_build": false,  # v0.8.0 N2: paced (O41)
		"build_hp_permille": 2500,
		"dps_target_seconds": 12.0,
		"dps_hp_min": 400,
		"dps_hp_max": 5000000,
		"build_damage_permille": 1500,
		"build_damage_min": 8,
		"build_damage_cap_permille": 500,  # v0.8.0 N2 (O27, D36 superseded)
		"pace": true,  # v0.8.0 N2: the pace and the mimic windows are F10 rows too
		"pace_ref_dps": 30,
		"pace_ref_seconds": 120.0,
		"pace_min_seconds": 60.0,
		"pace_max_seconds": 180.0,
		"pace_burst_seconds": 10.0,
		"mimic_window_seconds": 7.0,
		"mimic_every_seconds": 20.0,
		"mimic_first_seconds": 12.0,
		"mimic_warn_seconds": 1.5,
		"mimic_nerf_min_permille": 100,
		"shot_speed_min_mps": 7.0,
		"shot_speed_max_mps": 13.0,
		"shots_max": 12,
		"reach_max_m": 4.5,
		"blast_max_m": 3.0,
	}
	for key: String in body:
		assert_true(rows.has(key), "%s is a row" % key)
		assert_eq(rows.get(key), body[key], "%s: its starting value" % key)
	var def := load(PATH) as BossDefinition
	for k in def.attacks.size():
		assert_true(rows.has("attacks/%d/lock_seconds" % k), "%s's lock" % def.attacks[k].id)


func test_its_data_validates() -> void:
	var def := load(PATH) as FinalBossDefinition
	assert_eq(def.validate().size(), 0, "no issue")
	var bad := def.duplicate(true) as FinalBossDefinition
	bad.build_damage_cap_permille = 1000
	bad.card_casts = 4
	bad.attacks[0].shape_params["weapon"] = "bow"
	var codes: Array[StringName] = []
	for issue in bad.validate():
		codes.append(issue.code)
	assert_gte(codes.size(), 3, "a one-shot cap, too many cards and an unknown weapon are refused")
