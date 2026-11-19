class_name PerfGpuPasses
extends RefCounted
## The renderer's own pass timestamps, one rendered frame at a time, for the perf log's `gp` column
## (docs/process/PERF_LOG.md). The engine writes them only when the game is launched with the engine flag
## `--gpu-profile` (before the `--`); without it the RenderingDevice holds only the viewports' own begin/end stamps
## and the column says little.
##
## Each timestamp starts a section that runs until the next one: its GPU time (the timestamps are in ns) and its CPU
## time (the render thread recording it, in µs). The engine numbers the viewports it draws in each frame's order, so
## the number moves between scenes: a section inside the main window's group ("> Render Viewport N" … "<", the one
## holding the window's measured "vp_begin_" stamp) is keyed "win/<name>", one inside any other viewport (the HUD's
## still parts, a gallery) "sub/<name>", summed over them, and one outside every viewport by its bare name. A name
## that repeats in one frame (Tonemap runs twice) is summed. The engine reads the results a couple of frames late:
## `lag` is how many.

## The characters a pass name may not carry in the CSV (the column's separators).
const BAD_CHARS := [",", ";", ":", "=", "|", "\n", '"']
## A section shorter than this on the GPU and than MIN_CPU_US on the CPU is left out of the column.
const MIN_GPU_US := 1
const MIN_CPU_US := 3

## True once a frame with the renderer's pass stamps was read (more than the viewports' own pair).
var passes_on := false
## The frames between the one drawn last and the one these stamps belong to.
var lag := 0
var _rd: RenderingDevice
var _last_frame := -1
var _ids := {}
var _new := PackedStringArray()


func _init() -> void:
	_rd = RenderingServer.get_rendering_device()


## The newest captured frame not read yet, as "@lag;id:gpu_us:cpu_us;…", or "" when there is none (no
## RenderingDevice: the Compatibility renderer or headless; or no new frame since the last call).
func frame_column() -> String:
	if _rd == null:
		return ""
	var n := _rd.get_captured_timestamps_count()
	if n < 2:
		return ""
	var fr := _rd.get_captured_timestamps_frame()
	if fr == _last_frame:
		return ""
	_last_frame = fr
	lag = maxi(Engine.get_frames_drawn() - fr, 0)
	if n > 3:
		passes_on = true
	var names := PackedStringArray()
	var gpu := PackedInt64Array()
	var cpu := PackedInt64Array()
	names.resize(n)
	gpu.resize(n)
	cpu.resize(n)
	for i in n:
		names[i] = _rd.get_captured_timestamp_name(i)
		gpu[i] = _rd.get_captured_timestamp_gpu_time(i)
		cpu[i] = _rd.get_captured_timestamp_cpu_time(i)
	var groups := _groups(names)
	var sums := {}
	var order: Array[int] = []
	for i in n - 1:
		var raw := names[i]
		if raw.begins_with("vp_begin_") or raw.begins_with("vp_end_"):
			raw = raw.get_slice("_", 0) + "_" + raw.get_slice("_", 1)
		var id := _id(String(groups[i]) + raw)
		if not sums.has(id):
			order.append(id)
		var acc: Vector2 = sums.get(id, Vector2.ZERO)
		sums[id] = (
			acc + Vector2(maxf((gpu[i + 1] - gpu[i]) / 1000.0, 0.0), maxf(cpu[i + 1] - cpu[i], 0.0))
		)
	var parts := PackedStringArray(["@%d" % lag])
	for id in order:
		var v: Vector2 = sums[id]
		var gu := roundi(v.x)
		var cu := roundi(v.y)
		if gu >= MIN_GPU_US or cu >= MIN_CPU_US:
			parts.append("%d:%d:%d" % [id, gu, cu])
	return ";".join(parts)


## The names first seen since the last call, as "id=name|id=name" ("" when none): the summary's table of passes.
func take_new_names() -> String:
	if _new.is_empty():
		return ""
	var s := "|".join(_new)
	_new.clear()
	return s


## Each stamp's prefix: "win/" inside the main window's viewport group, "sub/" inside another, "" outside them.
static func _groups(names: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	out.resize(names.size())
	var start := -1
	for i in names.size():
		var nm := names[i]
		if nm.begins_with("> Render Viewport "):
			start = i
		elif nm.begins_with("< Render Viewport") and start >= 0:
			var key := "sub/"
			for k in range(start, i + 1):
				if names[k].begins_with("vp_begin_"):
					key = "win/"
					break
			for k in range(start, i + 1):
				out[k] = key
			start = -1
	return out


func _id(raw: String) -> int:
	var id: int = _ids.get(raw, -1)
	if id >= 0:
		return id
	id = _ids.size()
	_ids[raw] = id
	var clean := raw
	for ch: String in BAD_CHARS:
		clean = clean.replace(ch, " ")
	_new.append("%d=%s" % [id, clean.strip_edges()])
	return id
