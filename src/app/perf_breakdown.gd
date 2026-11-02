class_name PerfBreakdown
extends RefCounted
## v0.10.5 (owner: "play a normal game, log it and then you can measure what takes the most frames"): the main-thread
## breakdown shared by the frame probe (scripts/checks/frame_probe.gd --breakdown) and the play recorder (PerfRecorder,
## --perf-log). Probe-only: nothing here runs unless one of them switches it on. The sim never reads the clock; the
## phase timer it reports to (World.phase_probe) lives here, on the app side.


## The phase timer World.step reports to (World.phase_probe): probe-only, the sim never reads the clock.
class PhaseTimer:
	extends RefCounted
	var us := {}
	var _open := {}

	func begin(k: StringName) -> void:
		_open[k] = Time.get_ticks_usec()

	func end(k: StringName) -> void:
		us[k] = int(us.get(k, 0)) + Time.get_ticks_usec() - int(_open[k])

	func reset() -> void:
		us.clear()


## One signal listener called through a timer into PerfMarks bucket `key`.
class TimedListener:
	extends RefCounted
	var cb: Callable
	var key: StringName

	func call_it() -> void:
		var t0 := PerfMarks.start()
		cb.call()
		PerfMarks.add(key, t0)


## Every SimDriver.ticked listener (view sync, audio, codex, HUD, ...) called through a timer, in the order it was
## connected; v0.10.5 Q5: and every SimDriver.frame_ticked listener (the views' once-a-frame sync), as
## "frame.<script>.<method>". The timers are appended to `keep` (the caller holds them).
static func time_listeners(drv: SimDriver, keep: Array) -> void:
	time_signal(drv.ticked, "tick", keep)
	time_signal(drv.frame_ticked, "frame", keep)


static func time_signal(sig: Signal, prefix: String, keep: Array) -> void:
	var cons := sig.get_connections()
	for c: Dictionary in cons:
		sig.disconnect(c["callable"])
	for c: Dictionary in cons:
		var cb: Callable = c["callable"]
		var key := StringName("%s.%s.%s" % [prefix, cb.get_object().get_class(), cb.get_method()])
		var script: Script = (cb.get_object() as Object).get_script()
		if script != null:
			key = StringName(
				"%s.%s.%s" % [prefix, script.resource_path.get_file(), cb.get_method()]
			)
		var t := TimedListener.new()
		t.cb = cb
		t.key = key
		keep.append(t)
		sig.connect(t.call_it)


## Puts this frame's marks into `into` (microseconds): the PerfMarks buckets by name, each view's sync as
## "view.<id>" (the view may be null), the sim's phases as "phase.<name>".
static func gather(view: WorldViewRoot, phases: PhaseTimer, into: Dictionary) -> void:
	for k: StringName in PerfMarks.us:
		into[String(k)] = float(PerfMarks.us[k])
	if view != null:
		for k: StringName in view.sync_profile:
			into["view." + String(k)] = float(view.sync_profile[k]) * 1000.0
	if phases != null:
		for k: StringName in phases.us:
			into["phase." + String(k)] = float(phases.us[k])


## Clears the marks `gather` read.
static func clear(view: WorldViewRoot, phases: PhaseTimer) -> void:
	PerfMarks.clear()
	if phases != null:
		phases.reset()
	if view != null:
		view.sync_profile.clear()
