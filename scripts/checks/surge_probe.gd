extends SceneTree
## v0.11.0 O9 (owner Q16: "Measure a 120-enemy surge on the owner's PC; cap the surge if it drops under 144 fps"): the
## horde surge's frame-time probe. Boots the real game (main.tscn), starts a real run (Main.start_stage: floor 1 of
## the run seed, its biome and its critter), waits for the hero to land, then has the sim's own surge (Surges) bring
## the floor up to --count enemies alive (default 120, the spawner's hard cap): a surge of (count - alive) critters
## made due now, over its real 10 s window, through the real spawner, views and VAT crowd. It times every rendered
## frame for --secs seconds from the surge's start (Time.get_ticks_usec between two _process calls: CPU + GPU + the
## present; vsync off, no fps cap): the window (the crowd growing) and the rest (the crowd at its full size), each with
## its average, its percentiles and its 1 % low, against the 144 fps budget (6.94 ms).
## Probe-only writes to the world (a tool, as frame_probe's hero HP): the hero is unhurtable and stands still (no
## input), and every enemy is made unhurtable too, so the crowd stays at its size for the whole run (nothing dies).
## Writes build/perf/surge_<sha>.txt (never into docs), prints it, and saves the last frame to
## build/shots/v0.11.0/surge_<biome>.png. Needs a renderer (NOT --headless):
##   APPDATA=$PWD/build/appdata_surge godot --path . --position -10000,-10000 --resolution 1920x1080 --windowed \
##     -s scripts/checks/surge_probe.gd -- [--count=120] [--secs=20] [--seed=1]
## v0.11.0 O9b: [--breakdown] (where the crowd-full frame goes), [--process] (and each script's _process),
## [--hide=bodies|shadows] (an A/B: that VAT set not drawn).

const OUT_DIR := "res://build/perf/"
const BUDGET_MS := 1000.0 / 144.0
const LONG := 1 << 30

var _count := 120
var _secs := 20.0
var _seed := 1
var _sha := "nosha"
var _main: Main
var _frame := 0
var _phase := &"boot"
var _t0 := 0
var _last_us := 0
var _window_ms := PackedFloat64Array()
var _full_ms := PackedFloat64Array()
var _samples: Array = []
var _next_sample := 0
var _surge_size := 0
var _alive_before := 0
## v0.11.0 O9b: --breakdown (main-thread buckets over the crowd-full frames: PerfMarks, the views, the sim phases,
## the listeners; the render thread's CPU and GPU time; draw calls) and --process (each script's _process timed).
var _bd := false
var _proc := false
var _timers: Array = []
var _bk := {}
var _bk_n := 0
var _phase_timer := PerfBreakdown.PhaseTimer.new()
var _t_proc := 0
var _t_pre := 0
var _t_post := 0
var _has_process := {}
var _stolen := {}
var _hide := ""  # --hide=bodies|shadows (an A/B: the VAT crowd's sets of that kind not drawn)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("count="):
			_count = int(s.trim_prefix("count="))
		elif s.begins_with("secs="):
			_secs = float(s.trim_prefix("secs="))
		elif s.begins_with("seed="):
			_seed = int(s.trim_prefix("seed="))
		elif s.begins_with("hide="):
			_hide = s.trim_prefix("hide=")
		elif s == "breakdown":
			_bd = true
		elif s == "process":
			_bd = true
			_proc = true
	var git: Array = []
	if OS.execute("git", ["rev-parse", "--short", "HEAD"], git) == 0 and git.size() > 0:
		_sha = String(git[0]).strip_edges()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = "en"
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	_frame += 1
	var now := Time.get_ticks_usec()
	match _phase:
		&"boot":
			if _frame == 5:
				_main.set(&"_stage_seed", _seed)
				_main.start_stage()
				_phase = &"land"
		&"land":
			var d := _main.driver
			if d != null and not d.reader.arriving() and d.world.run_ticks > 2:
				_start_surge(now)
		&"measure":
			var w := _main.driver.world
			for i in range(1, w.actors.size()):  # nothing dies: the crowd keeps its size
				w.actors.invuln[i] = LONG
			if _proc:
				_steal_and_time(delta)
			if _hide != "" and _main.view.actors.vat_crowd != null:
				for m in _main.view.actors.vat_crowd.instances():
					m.visible = not ((m.name == "VatBodies") == (_hide == "bodies"))
			var dt_ms := (now - _last_us) / 1000.0
			if Surges.running(w):
				_window_ms.append(dt_ms)
			else:
				_full_ms.append(dt_ms)
				if _bd:
					_collect(now)
			if _bd:
				PerfBreakdown.clear(_main.view, _phase_timer)
				_t_proc = now
			if now >= _next_sample:
				_next_sample = now + 1000000
				_samples.append(
					[
						snappedf((now - _t0) / 1e6, 0.1),
						WaveDirector.enemies_alive(w),
						_drawn(),
						dt_ms
					]
				)
			if (now - _t0) >= int(_secs * 1e6):
				_finish()
	_last_us = now
	return false


## The floor's own surge, due now, sized to bring the floor to _count alive (the hero unhurtable, standing still).
func _start_surge(now: int) -> void:
	var w := _main.driver.world
	w.actors.invuln[0] = LONG
	_alive_before = WaveDirector.enemies_alive(w)
	_surge_size = clampi(_count - _alive_before, 1, SurgeDefinition.HARD_CAP)
	w.spawner.surge.alive_cap = mini(_count, w.spawner.cap_max)
	w.surge_at = PackedInt32Array([w.run_ticks + 1])
	w.surge_sizes = PackedInt32Array([_surge_size])
	w.surge_next = 0
	w.surge_t = -1
	if _bd:
		PerfMarks.on = true
		RenderingServer.frame_pre_draw.connect(func() -> void: _t_pre = Time.get_ticks_usec())
		RenderingServer.frame_post_draw.connect(func() -> void: _t_post = Time.get_ticks_usec())
		_main.view.profile_sync = true
		w.phase_probe = _phase_timer
		PerfBreakdown.time_listeners(_main.driver, _timers)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_t0 = now
	_next_sample = now
	_phase = &"measure"


func _stats(label: String, ms: PackedFloat64Array) -> String:
	if ms.is_empty():
		return "%s: no frames" % label
	var s := ms.duplicate()
	s.sort()
	var n := s.size()
	var sum := 0.0
	var over := 0
	for v in s:
		sum += v
		over += 1 if v > BUDGET_MS else 0
	var worst_n := maxi(1, int(ceil(n * 0.01)))
	var worst := 0.0
	for k in worst_n:
		worst += s[n - 1 - k]
	return (
		(
			"%s: frames=%d avg=%.2f ms (%.1f fps) p50=%.2f p95=%.2f p99=%.2f max=%.2f ms"
			+ "  1%%-low=%.1f fps  over 6.94 ms: %d (%.1f %%)"
		)
		% [
			label,
			n,
			sum / n,
			1000.0 * n / sum,
			_pct(s, 0.5),
			_pct(s, 0.95),
			_pct(s, 0.99),
			s[n - 1],
			1000.0 / (worst / worst_n),
			over,
			100.0 * over / n
		]
	)


static func _pct(sorted: PackedFloat64Array, q: float) -> float:
	return sorted[clampi(int(ceil(q * sorted.size())) - 1, 0, sorted.size() - 1)]


func _finish() -> void:
	var w := _main.driver.world
	var lines: PackedStringArray = []
	lines.append(
		(
			"surge_probe  sha=%s  seed=%d  biome=%s  critter=%s"
			% [
				_sha,
				_seed,
				_main.run_biome_id(),
				ActorStore.Kind.keys()[w.critter_kind] if w.critter_kind >= 0 else "none"
			]
		)
	)
	(
		lines
		. append(
			(
				"machine: renderer=%s adapter=%s window=%s (the report cannot see other processes: say what else ran)"
				% [
					RenderingServer.get_current_rendering_method(),
					RenderingServer.get_video_adapter_name(),
					root.size
				]
			)
		)
	)
	(
		lines
		. append(
			(
				(
					"scenario: real floor %d, %d alive before, a surge of %d critters (10 s window), cap %d;"
					+ " hero still, nothing dies; %.0f s"
				)
				% [w.floor_index, _alive_before, _surge_size, w.spawner.surge.alive_cap, _secs]
			)
		)
	)
	lines.append(_stats("surge window (crowd growing)", _window_ms))
	lines.append(_stats("after (crowd full)", _full_ms))
	var all := _window_ms.duplicate()
	all.append_array(_full_ms)
	lines.append(_stats("whole run", all))
	var crit := 0
	for i in range(1, w.actors.size()):
		crit += 1 if EnemyAi.is_critter(w.actors.kinds[i]) and w.actors.dead[i] == 0 else 0
	lines.append(
		"at the end: %d enemies alive, %d of them critters" % [WaveDirector.enemies_alive(w), crit]
	)
	if _bd:
		lines.append_array(_breakdown_lines())
	lines.append("per second: [t s, enemies alive, VAT instances drawn, that frame's ms]")
	for s: Array in _samples:
		lines.append("  %s" % str(s))
	var shot := "res://build/shots/v0.11.0/surge_%s.png" % _main.run_biome_id()  # after the timing
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot.get_base_dir()))
	root.get_texture().get_image().save_png(shot)
	lines.append("shot: %s" % ProjectSettings.globalize_path(shot))
	var text := "\n".join(lines)
	print(text)
	var f := FileAccess.open(OUT_DIR + "surge_%s.txt" % _sha, FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	quit(0)


## The VAT crowd's instances drawn last frame (0 before the first VAT enemy made the crowd).
func _drawn() -> int:
	var crowd := _main.view.actors.vat_crowd
	return crowd.drawn if crowd != null else 0


## v0.11.0 O9b (--breakdown): this crowd-full frame's buckets (microseconds), then the render thread's CPU and GPU
## time of the last frame drawn (ms → us) and the draw calls / objects (Performance).
func _collect(now: int) -> void:
	var this := {}
	if _t_post >= _t_pre and _t_pre >= _t_proc and _t_proc > 0:
		this["frame.scene_process"] = float(_t_pre - _t_proc)
		this["frame.draw_pre_to_post"] = float(_t_post - _t_pre)
		this["frame.rest_after_draw"] = float(now - _t_post)
	PerfBreakdown.gather(_main.view, _phase_timer, this)
	var vp := root.get_viewport_rid()
	this["render.cpu"] = RenderingServer.viewport_get_measured_render_time_cpu(vp) * 1000.0
	this["render.gpu"] = RenderingServer.viewport_get_measured_render_time_gpu(vp) * 1000.0
	this["count.draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	this["count.objects"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	this["count.nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	this["ticks"] = float(PerfMarks.calls.get(&"sim_step", 0))
	this["engine.process"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1e6
	this["engine.physics_process"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1e6
	this["frame_total"] = (now - _last_us) * 1.0
	for k: String in this:
		_bk[k] = float(_bk.get(k, 0.0)) + float(this[k])
	_bk_n += 1


func _breakdown_lines() -> PackedStringArray:
	var out: PackedStringArray = [
		"breakdown over %d crowd-full frames (mean per frame; us unless count.*):" % _bk_n
	]
	var keys: Array = _bk.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _bk[a] > _bk[b])
	for k: String in keys:
		out.append("  %-44s %10.1f" % [k, float(_bk[k]) / maxf(_bk_n, 1)])
	return out


## --process: every script node's _process taken off the engine's list and called from here, timed by script (the
## probe's _process runs first). Nodes switched off by set_process(false) are still called: overstated.
func _steal_and_time(delta: float) -> void:
	var stack: Array[Node] = [root]
	var per := {}
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is SimDriver:
			continue
		var kids := n.get_children()
		for k in range(kids.size() - 1, -1, -1):
			stack.append(kids[k])
		var sc: Script = n.get_script()
		if sc == null or n.is_queued_for_deletion() or n == root:
			continue
		if not _has_process.has(sc):
			_has_process[sc] = n.has_method(&"_process")
		if not _has_process[sc]:
			continue
		if n.is_processing():
			n.set_process(false)
			_stolen[n.get_instance_id()] = true
		if not _stolen.has(n.get_instance_id()):
			continue
		var t0 := Time.get_ticks_usec()
		n.call(&"_process", delta)
		var key := "script." + String(sc.resource_path.get_file())
		per[key] = int(per.get(key, 0)) + Time.get_ticks_usec() - t0
	for k: String in per:
		PerfMarks.us[StringName(k)] = per[k]
