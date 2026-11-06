extends GutTest
## v0.10.5: the play recorder (PerfRecorder, `-- --perf-log`): off by default, the header and one row per frame, the
## light and full columns, and F9 marks only while it records.

var _dir := ""


func before_each() -> void:
	_dir = "user://perf_test_%d/" % Time.get_ticks_usec()


func after_each() -> void:
	PerfMarks.on = false
	PerfMarks.clear()


func _lines(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "the CSV exists: %s" % path)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().strip_edges().split("\n")


func _host() -> Node:
	var n := Node.new()  # no driver / view / run: the menu
	add_child_autofree(n)
	return n


func _f9() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F9
	ev.keycode = KEY_F9
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()


func test_off_without_the_flag() -> void:
	assert_eq(PerfRecorder.mode_of(PackedStringArray()), "")
	assert_eq(PerfRecorder.mode_of(PackedStringArray(["--secs=3"])), "")
	assert_eq(PerfRecorder.mode_of(PackedStringArray(["--perf-log"])), "full")
	assert_eq(PerfRecorder.mode_of(PackedStringArray(["--perf-log=full"])), "full")
	assert_eq(PerfRecorder.mode_of(PackedStringArray(["--perf-log=light"])), "light")
	assert_false(PerfMarks.on, "PerfMarks stays off: one bool check per call site")


func test_light_writes_the_header_and_a_row_per_frame() -> void:
	var r := PerfRecorder.attach(_host(), false, _dir)
	assert_true(r.recording)
	assert_false(PerfMarks.on, "light keeps the marks off")
	await wait_physics_frames(20)
	var n := r.rows
	r.stop()
	assert_gt(n, 10, "about one row a frame")
	var lines := _lines(r.path)
	assert_eq(lines[0], ",".join(PerfRecorder.LIGHT_COLS), "the light header")
	assert_eq(lines.size() - 1, n, "every row reached the file")
	var row := lines[1].split(",")
	assert_eq(row.size(), PerfRecorder.LIGHT_COLS.size())
	assert_eq(row[PerfRecorder.LIGHT_COLS.find("scene")], "menu")
	assert_ne(
		row[PerfRecorder.LIGHT_COLS.find("nodes")], "", "the first row samples the node count"
	)


func test_full_adds_the_breakdown_columns() -> void:
	var r := PerfRecorder.attach(_host(), true, _dir)
	assert_true(PerfMarks.on, "full turns the marks on")
	await wait_physics_frames(8)
	r.stop()
	assert_false(PerfMarks.on, "and off again when it stops")
	var cols := PerfRecorder.LIGHT_COLS.duplicate()
	cols.append_array(PerfRecorder.FULL_COLS)
	var lines := _lines(r.path)
	assert_eq(lines[0], ",".join(cols), "the full header")
	assert_eq(lines[1].split(",").size(), cols.size())


func test_f9_marks_only_while_recording() -> void:
	var r := PerfRecorder.attach(_host(), false, _dir)
	await wait_physics_frames(3)
	_f9()
	await wait_physics_frames(3)
	assert_eq(r.marks, 1, "F9 marks while it records")
	r.stop()
	_f9()
	await wait_physics_frames(2)
	assert_eq(r.marks, 1, "and not after")
	r.mark()
	assert_eq(r.marks, 1)
	var col := PerfRecorder.LIGHT_COLS.find("mark")
	var marked := 0
	for line in _lines(r.path).slice(1):
		if line.split(",")[col] == "1":
			marked += 1
	assert_eq(marked, 1, "one row carries the mark")


func test_flushes_in_chunks_while_recording() -> void:
	var r := PerfRecorder.attach(_host(), false, _dir)
	await wait_physics_frames(PerfRecorder.FLUSH_ROWS + 20)
	r._wait()
	var on_disk := _lines(r.path).size() - 1
	assert_gte(on_disk, PerfRecorder.FLUSH_ROWS, "a chunk is on disk before the stop")
	r.stop()
