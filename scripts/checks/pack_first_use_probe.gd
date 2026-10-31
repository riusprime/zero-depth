extends SceneTree
## v0.10.0 VX-W: does the first spawn of a pack effect in a live floor stall? Starts a run in the real main.tscn, waits
## for the floor, then spawns `count` ids spread over the table (one every SPAWN_EVERY frames) in front of the camera
## and prints each spawn's worst frame time. A tool, not a test; writes nothing into the tree.
##   godot --path . --position -10000,-10000 --fixed-fps 60 --audio-driver Dummy --resolution 640x360 \
##     -s scripts/checks/pack_first_use_probe.gd -- [--warm=menu|load|session|none] [--restart] [--count=10] \
##     [--idle=<ms at the menu before Play>]
## --restart: a second load (Main.restart) before the spawns, so a PackFx warmed in the first one is gone.
const LIMIT_MS := 180000
const SPAWN_EVERY := 12

var main: Main
var _last_us := 0
var _samples: Array[float] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--warm="):
			PackFx.warm_mode = StringName(a.trim_prefix("--warm="))
	print(
		(
			"first_use: renderer=%s device=%s warm=%s"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name(),
				PackFx.warm_mode
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
	if _last_us > 0:
		_samples.append((now - _last_us) / 1000.0)
	_last_us = now
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _floor() -> void:
	var from := Time.get_ticks_msec()
	await _frames(3)
	while Time.get_ticks_msec() - from < LIMIT_MS:
		if main.driver != null and not main.loads.cover.showing() and not main.loads.call("busy"):
			break
		await process_frame
	await _frames(90)


func _run() -> void:
	await _frames(5)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--idle="):
			await create_timer(float(a.trim_prefix("--idle=")) / 1000.0).timeout
	main.loads.behind(self, main.ui, main._covered_start, Main.FADE_SECONDS)
	await _floor()
	var args := OS.get_cmdline_user_args()
	if args.has("--restart"):
		main.restart()
		await _floor()
	var count := 10
	for a in args:
		if a.begins_with("--count="):
			count = int(a.trim_prefix("--count="))
	var fx: PackFx = main.view.pack_fx
	var ids := fx.warm_ids()
	var step := maxi(1, ids.size() / count)
	var worst := 0.0
	var all := 0.0
	for k in count:
		var id := ids[(k * step + 3) % ids.size()]
		_samples.clear()
		fx.spawn(id, fx._focus())
		await _frames(SPAWN_EVERY)
		var m := 0.0
		for s in _samples:
			m = maxf(m, s)
		worst = maxf(worst, m)
		all += m
		print("first_use: %-34s worst frame %6.1f ms" % [id, m])
	print(
		(
			"first_use: summary spawns=%d worst=%.1f ms mean-of-worst=%.1f ms"
			% [count, worst, all / count]
		)
	)
	quit(0)
