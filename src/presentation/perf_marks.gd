class_name PerfMarks
extends RefCounted
## v0.9.5 PF2: opt-in main-thread timing for the frame probe (scripts/checks/frame_probe.gd --breakdown). Off in
## play: every call site is one bool check. The sim never calls it (it reads the clock); the callers around it do.
## `us` holds the microseconds each bucket took since the probe last cleared it, `calls` how often it was entered.

static var on := false
static var us := {}
static var calls := {}


## The start stamp for `add` (0 when off).
static func start() -> int:
	return Time.get_ticks_usec() if on else 0


## Adds the time since `t0` (from `start`) to bucket `key`. Does nothing when off.
static func add(key: StringName, t0: int) -> void:
	if not on:
		return
	us[key] = int(us.get(key, 0)) + Time.get_ticks_usec() - t0
	calls[key] = int(calls.get(key, 0)) + 1


static func clear() -> void:
	us.clear()
	calls.clear()
