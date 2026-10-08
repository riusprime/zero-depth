extends SceneTree
## Every SCORECARD §2 cell from one command (v0.5.0 SCD; PLAN R7, the v0.5.0 exit gate). Whole runs of the real
## game (ScoreRun: every floor built as Main builds it) played by the SCORECARD §3 bot policies (ScoreBot), on paired
## seeds, then every cell (ScoreCells) and the bench (scripts/bench/sim_bench.gd, run after the sims so it has the
## machine to itself). Deterministic: the same commit and arguments give byte-identical run records and
## scorecard.json cells (M-BENCH's timings excepted); wall time goes to timings.tsv only.
##
##   godot --headless --path . -s scripts/sims/scorecard.gd -- [--quick] [seeds=N|seeds=A..B] [policies=a,b,...]
##       [floors=3] [floor_ticks=90000] [jobs=4] [--no-bench] [--fresh] [out=build/scorecard/<sha>]
##
## Full mode (default): FULL_POLICIES x seeds 1..12, 3 floors, jobs=4. --quick: QUICK_POLICIES x 2 seeds, 1 floor of
## 30 s, the bench's reference scenes only (well-formed cells, not bands). Output (never under docs/):
##   build/scorecard/<sha>/scorecard.json, scorecard.md, timings.tsv, bench.json, runs/<task>.json
## Finished run records are kept: a rerun (after a container restart) plays only the missing tasks; --fresh replays
## every one. Workers: `jobs` child processes of this script (`--worker tasks=...`), each writing its own records.

const FULL_SEEDS := 12
const QUICK_SEEDS := 2

var quick := false
var worker := false
var bench := true
var fresh := false
var seeds: Array = []
var policies: Array = []
var floors := 3
var floor_ticks := ScoreRun.FLOOR_LIMIT_TICKS
var jobs := 4
var out_dir := ""
var worker_tasks := PackedStringArray()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	quick = args.has("--quick")
	worker = args.has("--worker")
	bench = not args.has("--no-bench")
	fresh = args.has("--fresh")
	if quick:
		floors = ScoreSuite.QUICK_FLOORS
		floor_ticks = ScoreSuite.QUICK_FLOOR_TICKS
		policies = ScoreSuite.QUICK_POLICIES.duplicate()
		seeds = range(1, QUICK_SEEDS + 1)
	else:
		policies = ScoreSuite.FULL_POLICIES.duplicate()
		seeds = range(1, FULL_SEEDS + 1)
	for a in args:
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"seeds":
				seeds = _seed_list(kv[1])
			"policies":
				policies = Array(kv[1].split(","))
			"floors":
				floors = int(kv[1])
			"floor_ticks":
				floor_ticks = int(kv[1])
			"jobs":
				jobs = maxi(1, int(kv[1]))
			"out":
				out_dir = kv[1]
			"tasks":
				worker_tasks = kv[1].split(",")
	var sha := _sha()
	if out_dir.is_empty():
		out_dir = "res://build/scorecard/%s" % sha
	elif not out_dir.begins_with("res://") and not out_dir.begins_with("/"):
		out_dir = "res://" + out_dir
	if worker:
		_work(worker_tasks)
		quit(0)
		return
	var t0 := Time.get_ticks_msec()
	var all := ScoreSuite.tasks(policies, seeds)
	var todo := PackedStringArray()
	for t in all:
		if fresh or not FileAccess.file_exists(_run_path(t)):
			todo.append(t)
	print("scorecard: %d tasks, %d to play, jobs %d -> %s" % [all.size(), todo.size(), jobs, out_dir])
	_dispatch(todo)
	var sims_ms := Time.get_ticks_msec() - t0
	var records: Array = []
	var missing := PackedStringArray()
	for t in all:
		var r: Variant = ScoreSuite.read_json(_run_path(t))
		if r == null:
			missing.append(t)
		else:
			records.append(r)
	var bench_doc := {}
	var bench_note := ""
	if not bench:
		bench_note = "--no-bench given"
	else:
		var b0 := Time.get_ticks_msec()
		bench_doc = _bench()
		bench_note = "" if not bench_doc.is_empty() else "the bench did not write build/bench.json"
		if quick and not bench_doc.is_empty():
			bench_note = " (quick mode: the reference scenes only)"
		_time_line("bench", Time.get_ticks_msec() - b0)
	var repo := ContentRepository.load_all()
	var config := {
		"sha": sha,
		"mode": "quick" if quick else "full",
		"command": _command_line(),
		"seeds": "%d..%d" % [seeds.min(), seeds.max()] if not seeds.is_empty() else "",
		"seed_base": ScoreSuite.SEED_BASE,
		"policies": policies,
		"floors": floors,
		"floor_ticks": floor_ticks,
		"missing_tasks": missing,
		"godot": Engine.get_version_info()["string"],
	}
	var doc := ScoreSuite.document(records, config, bench_doc, bench_note, repo)
	ScoreSuite.write_json(out_dir + "/scorecard.json", doc)
	var md := FileAccess.open(out_dir + "/scorecard.md", FileAccess.WRITE)
	md.store_string(ScoreSuite.markdown(doc))
	md.close()
	_time_line("sims", sims_ms)
	_time_line("total", Time.get_ticks_msec() - t0)
	print(ScoreSuite.markdown(doc).split("\n## M-CAUSE")[0])
	print(
		(
			"scorecard: wrote %s/scorecard.json and scorecard.md; sims %.1f min wall; missing %d"
			% [ProjectSettings.globalize_path(out_dir), sims_ms / 60000.0, missing.size()]
		)
	)
	quit(0 if missing.is_empty() else 1)


func _seed_list(s: String) -> Array:
	if s.contains(".."):
		return range(int(s.get_slice("..", 0)), int(s.get_slice("..", 1)) + 1)
	return range(1, int(s) + 1)


func _run_path(task: String) -> String:
	return out_dir + "/runs/" + ScoreSuite.file_of(task)


## Plays `todo`: here when jobs is 1, else split round-robin over `jobs` worker processes.
func _dispatch(todo: PackedStringArray) -> void:
	if todo.is_empty():
		return
	if jobs <= 1 or todo.size() == 1:
		_work(todo)
		return
	var exe := OS.get_executable_path()
	var pids: Array[int] = []
	for j in mini(jobs, todo.size()):
		var mine := PackedStringArray()
		for k in range(j, todo.size(), jobs):
			mine.append(todo[k])
		var args := [
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"-s",
			"res://scripts/sims/scorecard.gd",
			"--",
			"--worker",
			"tasks=" + ",".join(mine),
			"floors=%d" % floors,
			"floor_ticks=%d" % floor_ticks,
			"out=" + out_dir,
		]
		pids.append(OS.create_process(exe, args))
	var left := pids.size()
	while left > 0:
		OS.delay_msec(2000)
		left = 0
		for p in pids:
			if p > 0 and OS.is_process_running(p):
				left += 1


func _work(list: PackedStringArray) -> void:
	var repo := ContentRepository.load_all()
	for t in list:
		var t0 := Time.get_ticks_msec()
		var rec := ScoreSuite.play(repo, t, floors, floor_ticks)
		ScoreSuite.write_json(_run_path(t), rec)
		var ms := Time.get_ticks_msec() - t0
		_time_line(t, ms, int(rec["run_ticks"]))
		print("scorecard: %s %s floor %d (%.1f s)" % [t, rec["result"], rec["floor_reached"], ms / 1000.0])


func _time_line(what: String, ms: int, ticks: int = -1) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var path := out_dir + "/timings.tsv"
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	f.seek_end()
	f.store_line("%s\t%d\t%d" % [what, ms, ticks])
	f.close()


## Runs the bench (its own process, after the sims) and returns its JSON ({} if it wrote none).
func _bench() -> Dictionary:
	var src := "res://build/bench.json"
	if FileAccess.file_exists(src):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(src))
	var args := [
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://scripts/bench/sim_bench.gd"
	]
	if quick:
		args.append_array(["--", "--only=reference"])
	var output := []
	OS.execute(OS.get_executable_path(), args, output, true)
	var doc: Variant = ScoreSuite.read_json(src)
	if doc == null:
		return {}
	ScoreSuite.write_json(out_dir + "/bench.json", doc)
	return doc


func _sha() -> String:
	var out := []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], out)
	var sha := String(out[0]).strip_edges() if not out.is_empty() else ""
	if sha.is_empty():
		return "nogit"
	var st := []
	OS.execute(
		"git",
		["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain", "--untracked-files=no"],
		st
	)
	if not st.is_empty() and not String(st[0]).strip_edges().is_empty():
		sha += "-dirty"
	return sha


func _command_line() -> String:
	var a := OS.get_cmdline_user_args()
	return "godot --headless --path . -s scripts/sims/scorecard.gd" + (
		(" -- " + " ".join(a)) if not a.is_empty() else ""
	)
