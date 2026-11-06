extends GutTest
## v0.10.5 (owner: "play a normal game, log it and then you can measure what takes the most frames"): the play
## recorder in the real game. main.tscn boots with no recorder (off by default); switched on (as `-- --perf-log`
## does), it records the hub, the load and the run through real input, F9 marks a moment, and the CSV holds a row per
## frame with the scene, the sim ticks, the load and the breakdown, and the mark.


func after_each() -> void:
	PerfMarks.on = false
	PerfMarks.clear()


func test_a_logged_run_with_an_f9_mark() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	assert_null(main.perf, "no recorder without the flag")
	assert_false(PerfMarks.on)
	main.perf = PerfRecorder.attach(main, true, "user://perf_e2e_%d/" % Time.get_ticks_usec())
	var r := main.perf
	await e.start_from_menu()
	await e.frames(180)  # three seconds of the run
	await e.tap(KEY_F9)
	await e.frames(30)
	assert_eq(r.marks, 1, "F9 marked the moment")
	r.stop()
	var f := FileAccess.open(r.path, FileAccess.READ)
	assert_not_null(f, "the CSV is on disk")
	var lines := f.get_as_text().strip_edges().split("\n")
	var cols := lines[0].split(",")
	assert_true(cols.has("bd"), "the full header")
	var c_scene := cols.find("scene")
	var c_ticks := cols.find("ticks")
	var c_mark := cols.find("mark")
	var c_bd := cols.find("bd")
	var scenes := {}
	var run_rows := 0
	var ticks := 0
	var marked := 0
	var sim_bd := 0
	var short := 0
	for line in lines.slice(1):
		var v := line.split(",")
		if v.size() != cols.size():
			short += 1
			continue
		scenes[v[c_scene]] = true
		if v[c_scene] == "run":
			run_rows += 1
			ticks += int(v[c_ticks])
			if v[c_bd].contains("sim_step="):
				sim_bd += 1
		if v[c_mark] == "1":
			marked += 1
	assert_eq(short, 0, "every row has every column")
	assert_eq(lines.size() - 1, r.rows, "every frame reached the file")
	assert_true(
		scenes.has("hub") and scenes.has("run"), "the hub and the run: %s" % [scenes.keys()]
	)
	assert_gt(run_rows, 150, "the run's frames")
	assert_gt(ticks, 150, "the sim ticked in them")
	assert_gt(sim_bd, 100, "the breakdown names the sim's step")
	assert_eq(marked, 1, "one row carries the F9 mark")
