extends SceneTree
## The readable-cause check over many seeds (v0.3.0 O; PLAN v0.1.0 Step 9). Every floor of a run, its boss, both
## utilities; the fighting bot (FightBot), real floors (FightLab) and the checker (ReadableCause) as in
## tests/unit/sim/test_readable_cause.gd, only longer and over more seeds. Writes build/readable_cause.json and
## prints a summary; paste it into evidence by hand. Exits 1 when any hit to the player had no readable cause.
##   godot --headless --path . -s scripts/checks/readable_cause.gd -- seeds=12 floor_ticks=3600 boss_ticks=3600

var seeds := 12
var floor_ticks := 3600
var boss_ticks := 3600


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2 and kv[0] in ["seeds", "floor_ticks", "boss_ticks"]:
			set(kv[0], int(kv[1]))
	var runs := []
	var damage := 0
	var violations := []
	var by_cause := {}
	var deaths := 0
	var death_mismatch := []
	var bosses := 0
	for s in seeds:
		for f in [1, 2, 3]:
			var utility := &"guard" if s % 2 == 0 else &"blink"
			var r := CauseRun.run(9100 + s, f, floor_ticks, boss_ticks, utility)
			damage += int(r["damage"])
			violations.append_array(r["violations"])
			for k: String in r["by_cause"]:
				by_cause[k] = int(by_cause.get(k, 0)) + int(r["by_cause"][k])
			if bool(r["boss_seen"]):
				bosses += 1
			if not String(r["death_cause"]).is_empty():
				deaths += 1
				if r["death_cause"] != r["death_expected"]:
					death_mismatch.append(
						[r["seed"], r["floor"], r["death_cause"], r["death_expected"]]
					)
			(
				runs
				. append(
					{
						"seed": r["seed"],
						"floor": f,
						"utility": utility,
						"ticks": r["ticks"],
						"damage": r["damage"],
						"violations": (r["violations"] as Array).size(),
						"boss_seen": r["boss_seen"],
						"death_cause": r["death_cause"],
					}
				)
			)
	var doc := {
		"godot": Engine.get_version_info()["string"],
		"seeds": seeds,
		"floor_ticks": floor_ticks,
		"boss_ticks": boss_ticks,
		"runs": runs.size(),
		"boss_fights": bosses,
		"damage_to_player": damage,
		"by_cause": by_cause,
		"violations": violations.size(),
		"first_violations": violations.slice(0, 20),
		"deaths_checked": deaths,
		"death_recap_mismatches": death_mismatch,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var file := FileAccess.open("res://build/readable_cause.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(doc, "\t", true) + "\n")
	file.close()
	doc.erase("first_violations")
	print(JSON.stringify(doc, "\t", true))
	for v in violations.slice(0, 20):
		print("VIOLATION ", JSON.stringify(v, "", true))
	quit(0 if violations.is_empty() and death_mismatch.is_empty() else 1)
