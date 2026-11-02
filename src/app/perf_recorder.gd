class_name PerfRecorder
extends Node
## v0.10.5 (owner: "play a normal game, log it and then you can measure what takes the most frames"): records every
## rendered frame of normal play to a CSV under user://perf/ (docs/process/PERF_LOG.md). Launched with `-- --perf-log`
## (full: the frame probe's breakdown too, PerfBreakdown) or `-- --perf-log=light` (the frame time and the load only).
## Off by default: Main makes no recorder without the flag, and PerfMarks stays off (one bool check per call site).
## F9 marks a moment ("this felt bad here") while recording; a corner label shows it records and flashes on a mark.
## The rows are buffered and written by a worker thread every FLUSH_ROWS rows or FLUSH_USEC (so a crash loses at most
## that), on returning to the menu and on quit. App side: it reads the World (the load) and the views, never writes
## them; the sim's only hook is the existing probe-only World.phase_probe (full mode).

const DIR := "user://perf/"
const FLUSH_ROWS := 240
const FLUSH_USEC := 2000000
const SAMPLE_USEC := 2000000
const FLASH_USEC := 700000
const MARK_KEY := KEY_F9
const LIGHT_COLS: PackedStringArray = [
	"frame",
	"t_s",
	"scene",
	"floor",
	"biome",
	"paused",
	"frame_ms",
	"ticks",
	"enemies",
	"proj_player",
	"proj_enemy",
	"fx",
	"boss",
	"boss_phase",
	"mark",
	"nodes",
	"draw_calls",
	"primitives",
	"objects_drawn",
	"vram_mb",
	"rec_us",
]
const FULL_COLS: PackedStringArray = [
	"step_us",
	"sim_us",
	"views_us",
	"listeners_us",
	"other_script_us",
	"engine_us",
	"draw_us",
	"bd",
]

## True: the breakdown columns too (PerfMarks on, the views' sync profile, the sim's phase timer, timed listeners).
var full := false
var recording := false
## The CSV (user:// path) and its OS path.
var path := ""
var os_path := ""
var rows := 0
var marks := 0
var dir := DIR

var _main: Node
var _file: FileAccess
var _buf := PackedStringArray()
var _task := -1
var _t0 := 0
var _last_us := 0
var _last_flush_us := 0
var _next_sample_us := 0
var _mark_pending := 0
var _flash_until := 0
var _scene := ""
var _drv_id := 0
var _view_id := 0
var _world_id := 0
var _timers: Array = []
var _phases := PerfBreakdown.PhaseTimer.new()
var _t_pre := 0
var _t_post := 0
## The recorder's own time on the main thread last frame (the row, the flush hand-off): its overhead, in the CSV.
var _rec_us := 0
var _layer: CanvasLayer
var _label: Label


## The mode the launch flags ask for: "full" (--perf-log), "light" (--perf-log=light), "" (no flag: off).
static func mode_of(args: PackedStringArray) -> String:
	for a in args:
		if a == "--perf-log" or a == "--perf-log=full":
			return "full"
		if a == "--perf-log=light":
			return "light"
	return ""


## A recorder under `main` (Main, or any node with its driver / view / run fields), recording at once.
static func attach(main: Node, p_full: bool, p_dir: String = DIR) -> PerfRecorder:
	var r := PerfRecorder.new()
	r.name = "PerfRecorder"
	r.full = p_full
	r.dir = p_dir
	r._main = main
	main.add_child(r)
	r.start()
	return r


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100000  # before SimDriver._process clears ticks_this_frame


func columns() -> PackedStringArray:
	var c := LIGHT_COLS.duplicate()
	if full:
		c.append_array(FULL_COLS)
	return c


func start() -> void:
	if recording:
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace("-", "").replace(":", "")
	path = dir.path_join("perf_%s.csv" % stamp.replace("T", "_"))
	var n := 1
	while FileAccess.file_exists(path):
		n += 1
		path = dir.path_join("perf_%s_%d.csv" % [stamp.replace("T", "_"), n])
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("perf-log: cannot write %s" % path)
		return
	_file.store_string(",".join(columns()) + "\n")
	_file.flush()
	os_path = ProjectSettings.globalize_path(path)
	print("perf-log: recording (%s) to %s" % ["full" if full else "light", os_path])
	recording = true
	rows = 0
	marks = 0
	_t0 = Time.get_ticks_usec()
	_last_us = _t0
	_last_flush_us = _t0
	_next_sample_us = _t0
	if full:
		PerfMarks.on = true
		PerfMarks.clear()
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	_make_label()


## Stops, writes what is buffered and closes the file. Safe to call twice.
func stop() -> void:
	if not recording:
		return
	recording = false
	flush()
	_wait()
	if _file != null:
		_file.close()
		_file = null
	if full:
		PerfMarks.on = false
		PerfMarks.clear()
		if RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
			RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
			RenderingServer.frame_post_draw.disconnect(_on_post_draw)
		var view := _view()
		if view != null:
			view.profile_sync = false
		var w := _world()
		if w != null and w.phase_probe == _phases:
			w.phase_probe = null
	if _layer != null:
		_layer.queue_free()
		_layer = null
		_label = null
	print("perf-log: %d frames, %d marks in %s" % [rows, marks, os_path])


## F9: marks this moment in the next row (only while recording).
func mark() -> void:
	if not recording:
		return
	marks += 1
	_mark_pending = marks
	_flash_until = Time.get_ticks_usec() + FLASH_USEC
	if _label != null:
		_label.text = tr("PERF_REC_MARK") % marks
		_label.modulate = Color(1.0, 0.9, 0.3)


## Hands the buffered rows to a worker thread (the file write stays off the main thread).
func flush() -> void:
	_last_flush_us = Time.get_ticks_usec()
	if _buf.is_empty() or _file == null:
		return
	var chunk := "\n".join(_buf) + "\n"
	_buf.clear()
	_wait()
	_task = WorkerThreadPool.add_task(_write.bind(chunk), false, "perf-log")


func _write(chunk: String) -> void:
	_file.store_string(chunk)
	_file.flush()


func _wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _input(event: InputEvent) -> void:
	if not recording:
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode == MARK_KEY:
		get_viewport().set_input_as_handled()
		mark()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		stop()


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	if not recording:
		return
	var now := Time.get_ticks_usec()
	_buf.append(_row(now))
	rows += 1
	_last_us = now
	if _buf.size() >= FLUSH_ROWS or now - _last_flush_us >= FLUSH_USEC:
		flush()
	if _flash_until > 0 and now >= _flash_until and _label != null:
		_flash_until = 0
		_label.text = tr("PERF_REC_ON")
		_label.modulate = Color.WHITE
	_rec_us = Time.get_ticks_usec() - now


func _on_pre_draw() -> void:
	_t_pre = Time.get_ticks_usec()


func _on_post_draw() -> void:
	_t_post = Time.get_ticks_usec()


## One CSV row: the frame that ended now (since the last row).
func _row(now: int) -> String:
	var dt_us := now - _last_us
	var drv := _driver()
	var w: World = drv.world if drv != null else null
	var view := _view()
	var scene := _scene_name(drv)
	if scene != _scene:
		if _scene != "" and scene == "menu":
			flush()  # back to the menu: what was recorded is on disk
		_scene = scene
	var run: Object = _main.get(&"run")
	var floor_i := -1
	var biome := ""
	if run != null:
		floor_i = int(run.get(&"floor_index"))
		if _main.has_method(&"run_biome_id"):
			biome = String(_main.call(&"run_biome_id"))
	elif scene == "hub":
		biome = "hub"
	var enemies := 0
	var pp := 0
	var pe := 0
	var boss := 0
	var phase := -1
	if w != null:
		enemies = maxi(w.actors.size() - 1 - w.actors.dead.count(1), 0)
		pp = w.projectiles.team.count(ActorStore.TEAM_PLAYER)
		pe = w.projectiles.team.size() - pp
		if w.boss_alive():
			boss = 1
			var bi := drv.reader.boss_index()
			if bi >= 0:
				phase = drv.reader.boss_phase(bi)
	var vals: PackedStringArray = [
		str(rows),
		"%.4f" % ((now - _t0) / 1e6),
		scene,
		str(floor_i),
		biome,
		str(int(drv != null and drv.paused)),
		"%.3f" % (dt_us / 1000.0),
		str(drv.ticks_this_frame if drv != null else 0),
		str(enemies),
		str(pp),
		str(pe),
		str(_fx_count(view)),
		str(boss),
		str(phase),
		str(_mark_pending) if _mark_pending > 0 else "",
	]
	_mark_pending = 0
	if now >= _next_sample_us:
		_next_sample_us = now + SAMPLE_USEC
		vals.append(str(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))))
		vals.append(str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))))
		vals.append(str(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))))
		vals.append(str(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))))
		vals.append(
			"%.1f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
		)
	else:
		vals.append_array(["", "", "", "", ""])
	vals.append(str(_rec_us))
	if full:
		_full_cols(vals, dt_us, drv, w, view)
	return ",".join(vals)


## The breakdown: the PerfMarks buckets, the views' sync, the sim's phases and the timed listeners since the last row.
func _full_cols(
	vals: PackedStringArray, dt_us: int, drv: SimDriver, w: World, view: WorldViewRoot
) -> void:
	_hook(drv, w, view)
	var bd := {}
	PerfBreakdown.gather(view, _phases, bd)
	PerfBreakdown.clear(view, _phases)
	var step := int(bd.get("step_once", 0.0))
	var sim := int(bd.get("sim_step", 0.0))
	var tick_all := int(bd.get("ticked_all", 0.0))
	var synced := int(bd.get("frame_synced", 0.0))
	var views := int(bd.get("sync_all", 0.0))
	vals.append(str(step))
	vals.append(str(sim))
	vals.append(str(views))
	vals.append(str(maxi(tick_all + synced - views, 0)))
	vals.append(str(maxi(step - sim - tick_all, 0)))
	vals.append(str(maxi(dt_us - step - synced, 0)))
	vals.append(str(_t_post - _t_pre) if _t_post >= _t_pre and _t_pre >= _last_us else "")
	var parts := PackedStringArray()
	for k: String in bd:
		var v := int(bd[k])
		if v > 0:
			parts.append("%s=%d" % [k, v])
	vals.append(";".join(parts))


## Full mode: a new floor's driver gets its listeners timed, its view its sync profile, its World the phase timer.
## Not in the Playground: its biome switch disconnects the view's listeners by name.
func _hook(drv: SimDriver, w: World, view: WorldViewRoot) -> void:
	if drv != null and drv.get_instance_id() != _drv_id:
		_drv_id = drv.get_instance_id()
		if _main.get(&"playground") == null:
			PerfBreakdown.time_listeners(drv, _timers)
	if view != null and view.get_instance_id() != _view_id:
		_view_id = view.get_instance_id()
		view.profile_sync = true
	if w != null and w.get_instance_id() != _world_id:
		_world_id = w.get_instance_id()
		w.phase_probe = _phases


func _driver() -> SimDriver:
	if not is_instance_valid(_main):
		return null
	var d: Object = _main.get(&"driver")
	return d as SimDriver if is_instance_valid(d) else null


func _view() -> WorldViewRoot:
	if not is_instance_valid(_main):
		return null
	var v: Object = _main.get(&"view")
	return v as WorldViewRoot if is_instance_valid(v) else null


func _world() -> World:
	var d := _driver()
	return d.world if d != null else null


func _scene_name(drv: SimDriver) -> String:
	var loads: Object = _main.get(&"loads")
	if loads != null and loads.call(&"busy"):
		return "loading"
	if _main.get(&"playground") != null:
		return "playground"
	if _main.get(&"training") != null:
		return "training"
	if _main.get(&"hub") != null:
		return "hub"
	if drv != null:
		return "run" if _main.get(&"run") != null else "stage"
	return "menu"


## The effect instances drawn: the attack forms' meshes and particles and the effects layer's sprites.
static func _fx_count(view: WorldViewRoot) -> int:
	if view == null or view.attack_forms == null:
		return 0
	var forms := view.attack_forms
	var n := forms.meshes_drawn() + forms.particles_drawn()
	var layer: VfxLayer = forms.vfx
	if layer != null:
		for id: StringName in layer.pools:
			n += layer.used(id)
	return n


func _make_label() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 127
	_label = Label.new()
	_label.text = tr("PERF_REC_ON")
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.3))
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 4)
	_label.add_theme_font_size_override(&"font_size", 16)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_left = -160
	_label.offset_right = -12
	_label.offset_top = 8
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layer.add_child(_label)
	add_child(_layer)
