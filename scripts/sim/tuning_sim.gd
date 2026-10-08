extends SceneTree
## The tuning sims (v0.4.0 TU): whole runs (floors 1–3) of the expected-build bot (tests/support/run_bot.gd) for each
## build and seed, through TuningRun. Writes one JSON line per run to `out` (under build/) and prints a summary;
## evidence is pasted from the output by hand. `summarize=` merges earlier outputs instead of running (so seeds can
## run in parallel processes).
##   godot --headless --path . -s scripts/sim/tuning_sim.gd -- seeds=6 first=1 builds=blade,gun out=build/tuning/a.jsonl
##   godot --headless --path . -s scripts/sim/tuning_sim.gd -- summarize=build/tuning/a.jsonl,build/tuning/b.jsonl

var seeds := 4
var first := 1
var floors := 3
var builds := PackedStringArray(["blade", "gun"])
var out := "build/tuning/runs.jsonl"
var summarize := ""
var god := 0
var preset := "average"
var killboss := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"seeds", "first", "floors", "god", "killboss":
				set(kv[0], int(kv[1]))
			"builds":
				builds = kv[1].split(",")
			"preset":
				preset = kv[1]
			"out":
				out = kv[1]
			"summarize":
				summarize = kv[1]
	var runs := []
	if summarize != "":
		for path in summarize.split(","):
			var f := FileAccess.open(path, FileAccess.READ)
			while f != null and not f.eof_reached():
				var line := f.get_line()
				if not line.is_empty():
					runs.append(JSON.parse_string(line))
	else:
		var repo := ContentRepository.load_all()
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var file := FileAccess.open(out, FileAccess.WRITE)
		for s in seeds:
			for b in builds:
				var r := TuningRun.run(
					repo,
					7300 + first + s,
					StringName(b),
					floors,
					TuningRun.FLOOR_LIMIT_TICKS,
					god == 1,
					preset,
					killboss == 1
				)
				var line := JSON.stringify(_compact(r), "", true)
				file.store_line(line)
				file.flush()
				print(_one_line(r))
				runs.append(JSON.parse_string(line))
	for line in summary(runs):
		print(line)
	quit(0)


## The run without its raw time-to-kill samples, but with per-floor medians kept (and the samples, for merging).
static func _compact(r: Dictionary) -> Dictionary:
	return r


static func _one_line(r: Dictionary) -> String:
	var parts := PackedStringArray()
	for f: Dictionary in r["floors"]:
		(
			parts
			. append(
				(
					"F%d %s door %.0fs floor %.0fs kills %d cards %d/%d/%d peak %d %s"
					% [
						f["floor"],
						f["result"],
						f["door_s"],
						f["floor_s"],
						f["kills"],
						f["cards_2m"],
						f["cards_5m"],
						f["cards_end"],
						f["peak_alive"],
						_orbs(f),
					]
				)
			)
		)
	return "seed %d %s: %s" % [r["seed"], r["build"], " | ".join(parts)]


## Orbs taken and HP they gave on a floor record (0 in records from before v0.4.0 TU's orbs).
static func _orbs(f: Dictionary) -> String:
	return "orbs %d (+%d HP)" % [int(f.get("orbs", 0)), int(f.get("orb_hp", 0))]


## Summary lines per floor and build.
static func summary(runs: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("runs: %d" % runs.size())
	for b in ["blade", "gun", "all"]:
		var mine := runs.filter(func(r: Dictionary) -> bool: return b == "all" or r["build"] == b)
		if mine.is_empty():
			continue
		var died_by := 0
		for fl in [1, 2, 3]:
			var recs := []
			for r: Dictionary in mine:
				for f: Dictionary in r["floors"]:
					if int(f["floor"]) == fl:
						recs.append(f)
			var reached := recs.size()
			if reached == 0:
				lines.append("%s F%d: not reached" % [b, fl])
				continue
			var died := (
				recs
				. filter(
					func(f: Dictionary) -> bool: return String(f["result"]).begins_with("died")
				)
				. size()
			)
			var died_boss := (
				recs.filter(func(f: Dictionary) -> bool: return f["result"] == "died_boss").size()
			)
			var timeouts := (
				recs.filter(func(f: Dictionary) -> bool: return f["result"] == "timeout").size()
			)
			died_by += died
			var door := (
				recs
				. filter(func(f: Dictionary) -> bool: return float(f["door_s"]) >= 0.0)
				. map(func(f: Dictionary) -> float: return float(f["door_s"]))
			)
			var start_ttk := []
			var end_ttk := []
			for f: Dictionary in recs:
				var last := (
					int(float(f["door_s"]) / 60.0)
					if float(f["door_s"]) >= 0.0
					else int(float(f["floor_s"]) / 60.0)
				)
				for s: Array in f["ttk"]:
					var m := int(s[0])
					if m < 2:
						start_ttk.append(int(s[1]))
					elif m >= last - 2 and m < last:
						end_ttk.append(int(s[1]))
			var ttk0 := TuningRun.median(start_ttk) / 60.0
			var ttk1 := TuningRun.median(end_ttk) / 60.0
			lines.append(
				(
					(
						"%s F%d: reached %d, died %d (boss %d), timeouts %d; died by F%d %d/%d (%.0f%%);"
						+ " door s med %.0f [%s..%s]; kills med %.0f; cards 2m/5m/end med %.1f/%.1f/%.1f;"
						+ " first chest s med %.0f; peak alive med %.0f max %d;"
						+ " ttk s start %.2f (n %d) end %.2f (n %d) change %+.0f%%"
					)
					% [
						b,
						fl,
						reached,
						died,
						died_boss,
						timeouts,
						fl,
						died_by,
						mine.size(),
						100.0 * died_by / mine.size(),
						TuningRun.median(door),
						"%.0f" % door.min() if not door.is_empty() else "-",
						"%.0f" % door.max() if not door.is_empty() else "-",
						TuningRun.median(
							recs.map(func(f: Dictionary) -> int: return int(f["kills"]))
						),
						TuningRun.median(
							recs.map(func(f: Dictionary) -> int: return int(f["cards_2m"]))
						),
						TuningRun.median(
							recs.map(func(f: Dictionary) -> int: return int(f["cards_5m"]))
						),
						TuningRun.median(
							recs.map(func(f: Dictionary) -> int: return int(f["cards_end"]))
						),
						TuningRun.median(
							recs.map(func(f: Dictionary) -> float: return float(f["first_chest_s"]))
						),
						TuningRun.median(
							recs.map(func(f: Dictionary) -> int: return int(f["peak_alive"]))
						),
						recs.map(func(f: Dictionary) -> int: return int(f["peak_alive"])).max(),
						ttk0,
						start_ttk.size(),
						ttk1,
						end_ttk.size(),
						(100.0 * (ttk1 - ttk0) / ttk0) if ttk0 > 0.0 else 0.0,
					]
				)
			)
			# Median time-to-kill per minute (pooled), for the curve over the floor.
			var per_min := {}
			for f: Dictionary in recs:
				for s: Array in f["ttk"]:
					if not per_min.has(int(s[0])):
						per_min[int(s[0])] = []
					per_min[int(s[0])].append(int(s[1]))
			var cells := PackedStringArray()
			var keys := per_min.keys()
			keys.sort()
			for m: int in keys:
				cells.append(
					"%d:%.2f(%d)" % [m, TuningRun.median(per_min[m]) / 60.0, per_min[m].size()]
				)
			lines.append("%s F%d ttk by minute: %s" % [b, fl, " ".join(cells)])
			for book in ["hurt_floor", "hurt_boss"]:
				var hurt := {}
				for f: Dictionary in recs:
					for k: String in f.get(book, {}):
						hurt[k] = int(hurt.get(k, 0)) + int(f[book][k])
				var ks := hurt.keys()
				ks.sort_custom(func(x: String, y: String) -> bool: return hurt[x] > hurt[y])
				var parts := PackedStringArray()
				for k: String in ks:
					parts.append("%s %d" % [k, hurt[k]])
				lines.append("%s F%d %s: %s" % [b, fl, book, ", ".join(parts)])
	return lines
