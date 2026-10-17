extends SceneTree
## v0.8.0 N12 (owner O70: "the loading screens still freeze the game … it should be like a surely animation where
## things move … but never stop moving or freezing"; docs/roadmap/v0.8.0/evidence/LOADS_NO_FREEZE.md): times every
## real floor load of the game in the real main.tscn, frame by frame. A tool, not a test: it calls Main's own loads
## and poses the hero by script (as scripts/shots/loading_cover.gd does): a new run from the build pick, the gate
## portal, Continue from the main menu, the Deep gate, the Ascension portal (to the final arena), Restart, and the
## Loop device. For each it prints the longest single frame and the total time while the cover shows (and the frame
## the cover starts on), the longest frame in the 60 frames after the cover opened (the "catch up" the owner saw), the
## frames the corner mark or the iris did not move on, and the load's phases (CoverLoads.phases, in ms).
##   godot --headless --fixed-fps 60 --path . -s scripts/checks/load_probe.gd
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" \
##     godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 640x360 -s scripts/checks/load_probe.gd \
##     -- --menu-only   (llvmpipe: only the new run, Continue and Restart: a frame of play takes ~1 s there)
## Writes nothing into the tracked tree; the lines are pasted into the evidence by hand.

const AFTER_FRAMES := 60
## A load that hasn't opened after this long (wall clock: headless frames take microseconds) is reported stuck.
const LIMIT_MS := 180000

var main: Main
var _last_us := 0
var _recording := false
var _samples: Array[float] = []
var _covered: Array[bool] = []
var _still: Array[bool] = []
## Per frame: how far the load was (w: the World on its worker, v: the view's build, -: neither).
var _stage: Array[String] = []
var _last_spin := -1.0
var _rows: Array[String] = []


func _initialize() -> void:
	print(
		(
			"load_probe: renderer=%s device=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	Main.fixed_seed = Main.STAGE_SEED
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if _recording and _last_us > 0:
		var c := main.loads.cover
		_samples.append((now - _last_us) / 1000.0)
		_covered.append(c.showing())
		var spin: float = c.get("_spin")
		_still.append(c.showing() and spin == _last_spin)
		var ph: Variant = main.loads.get("phases")
		var at := "-"
		if ph is Dictionary and _busy():
			at = "v" if (ph as Dictionary).has("world") else "w"
		_stage.append(at)
		_last_spin = spin
	_last_us = now
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _world() -> World:
	return main.driver.world if main.driver != null else null


func _put(p: Vector2) -> void:
	var w := _world()
	w.actors.set_pos(0, p)
	w.vel = Vector2.ZERO
	main.view.rig.snap_to(SimPlane.to_3d(p))


## A load is still running (the N3 loads had only `waiting`).
func _busy() -> bool:
	return main.loads.call("busy") if main.loads.has_method("busy") else main.loads.waiting


## Waits until a floor is up (a driver, and no cover over it).
func _ready_floor() -> void:
	var from := Time.get_ticks_msec()
	while Time.get_ticks_msec() - from < LIMIT_MS:
		if main.driver != null and not main.loads.cover.showing() and not _busy():
			return
		await process_frame
	push_error("load_probe: no floor after %d ms" % LIMIT_MS)


## Into the boss room, the boss killed: the floor's portals open.
func _clear_boss() -> void:
	var from := Time.get_ticks_msec()  # v0.8.0 N11: the hero lands on the receiver first
	while main.driver.reader.arriving() and Time.get_ticks_msec() - from < LIMIT_MS:
		await process_frame
	var w := _world()
	w.actors.invuln[0] = 1 << 24
	_put(w.floor_layout.boss_door_inside(2.5))
	await _frames(40)
	var i := w.actors.index_of(w.boss_id)
	if i >= 0:
		w.actors.invuln[i] = 0
		Damage.hit(w, i, 999999, 0, 0, w.take_root(), 0, w.actors.pos(i), w.actors.pos(i))
	await _frames(40)


func _into_gate(pos: Vector2, angle: int) -> void:
	_put(pos + Kin.dir(angle) * (FloorLayout.GATE_HALF_DEPTH + 0.6))


## Runs `trigger` and records every frame until the new floor's cover is gone, then AFTER_FRAMES more.
func _load(label: String, trigger: Callable) -> void:
	var old_view := main.view
	_samples.clear()
	_covered.clear()
	_still.clear()
	_stage.clear()
	_recording = true
	_last_us = Time.get_ticks_usec()
	trigger.call()
	var from := Time.get_ticks_msec()
	while Time.get_ticks_msec() - from < LIMIT_MS:
		await process_frame
		if (
			main.view != null
			and main.view != old_view
			and not main.loads.cover.showing()
			and not _busy()
		):
			break
	await _frames(AFTER_FRAMES)
	_recording = false
	_report(label, Time.get_ticks_msec() - from < LIMIT_MS)


func _report(label: String, opened: bool) -> void:
	var during_max := 0.0
	var during_total := 0.0
	var during_n := 0
	var still := 0
	var after_max := 0.0
	var first := _covered.find(true)
	var last := _covered.rfind(true)
	for i in _samples.size():
		if first >= 0 and i >= first and i <= last:
			during_max = maxf(during_max, _samples[i])
			during_total += _samples[i]
			during_n += 1
			if _still[i]:
				still += 1
		elif first >= 0 and i > last:
			after_max = maxf(after_max, _samples[i])
	var w := _world()
	var got: Variant = main.loads.get("phases")
	var phases: Dictionary = got if got is Dictionary else Engine.get_meta("lm", {})
	var keys := phases.keys()
	keys.sort()
	var ph := PackedStringArray()
	for key: String in keys:
		ph.append("%s=%.1f" % [key, float(phases[key])])
	var line := (
		(
			"load_probe: %-9s covered %4d frames, %7.1f ms; longest frame %6.1f ms; still mark frames %d;"
			+ " after-60 longest %6.1f ms; floor=%s hash=%s"
		)
		% [
			label,
			during_n,
			during_total,
			during_max,
			still,
			after_max,
			str(main.run.floor_index) if main.run != null else "-",
			w.state_hash().substr(0, 12) if w != null else "-"
		]
	)
	print(line)
	print("load_probe: %-9s phases ms: %s" % [label, " ".join(ph)])
	_rows.append(line)
	var lens := PackedStringArray()
	for i in _samples.size():
		if _samples[i] > 50.0:
			lens.append(
				"%d:%.0f%s%s" % [i - first, _samples[i], "c" if _covered[i] else "", _stage[i]]
			)
	print(
		(
			"load_probe: %-9s frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): %s"
			% [label, ", ".join(lens)]
		)
	)
	if not opened:
		push_error("load_probe: %s never opened" % label)


## A control: the main menu for `ms` with no load (the machine's own hitches, shared with other jobs).
func _idle(ms: int) -> void:
	var longest := 0.0
	var over := 0
	var n := 0
	var last := Time.get_ticks_usec()
	var from := Time.get_ticks_msec()
	while Time.get_ticks_msec() - from < ms:
		await process_frame
		var now := Time.get_ticks_usec()
		var d := (now - last) / 1000.0
		last = now
		longest = maxf(longest, d)
		over += 1 if d > 50.0 else 0
		n += 1
	print(
		(
			"load_probe: idle      menu %d frames, %d ms; longest frame %6.1f ms; frames over 50 ms %d"
			% [n, ms, longest, over]
		)
	)


## With --menu-only: after the new run, Continue from the main menu and Restart (no walking: no portal).
func _menu_loads() -> void:
	main.show_main_menu()
	await _frames(10)
	await _load(
		"continue",
		func() -> void: main.loads.behind(self, main.ui, main._covered_continue, Main.FADE_SECONDS)
	)
	await _load("restart", main.restart)
	print("load_probe: done (menu loads only)")
	quit(0)


func _run() -> void:
	await _frames(5)
	await _idle(5000)
	await _load(
		"new_run",
		func() -> void: main.loads.behind(self, main.ui, main._covered_start, Main.FADE_SECONDS)
	)
	if OS.get_cmdline_user_args().has("--menu-only"):  # llvmpipe: a frame of play there takes ~1 s
		await _menu_loads()
		return
	await _clear_boss()
	var f := _world().floor_layout
	await _load("gate", _into_gate.bind(f.portal_pos, f.portal_angle))
	main.show_main_menu()
	await _frames(10)
	await _load(
		"continue",
		func() -> void: main.loads.behind(self, main.ui, main._covered_continue, Main.FADE_SECONDS)
	)
	await _clear_boss()
	f = _world().floor_layout
	if f.has_deep_portal:
		await _load("deep", _into_gate.bind(f.deep_portal_pos, f.deep_portal_angle))
	else:
		print("load_probe: floor %d has no Deep gate" % main.run.floor_index)
	main.run.floor_index = main.run.table.floors
	main._restart_floor()
	await _ready_floor()
	await _clear_boss()
	f = _world().floor_layout
	await _load("ascension", _into_gate.bind(f.portal_pos, f.portal_angle))
	await _load("restart", main.restart)
	main.run.floor_index = main.run.table.floors
	main._restart_floor()
	await _ready_floor()
	await _clear_boss()
	await _load("loop", func() -> void: _put(main.driver.reader.loop_device_pos()))
	var out: Array = []
	OS.execute("cat", ["/proc/loadavg"], out)
	print(
		(
			"load_probe: done; load average %s"
			% (str(out[0]).strip_edges() if not out.is_empty() else "-")
		)
	)
	quit(0)
