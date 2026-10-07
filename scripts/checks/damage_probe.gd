extends SceneTree
## Damage-path frame times (PLAN v0.2.0 L11, docs/roadmap/v0.2.0/evidence/DAMAGE_LAG.md). Needs a renderer (the
## stall it looks for is shader compilation, which --headless never does):
##   godot --path . -s scripts/checks/damage_probe.gd -- hits=25 period=30 target=player
## Boots main.tscn (Enter twice to the floor), stands still, and every `period` frames lands one hit on the player
## (or the first live enemy) through the sim's own damage pipeline (Damage.hit, the call an enemy attack makes);
## the target's HP is topped up first so nothing dies. Prints the wall time of the 4 frames after each hit
## against frames more than 10 after one. A measurement harness: it pokes the World directly, so it is not an
## e2e test and nothing here is evidence until its output is pasted by hand.

var _main: Main
var _frame := 0
var _last := 0
var _hits := 0
var _n := 30
var _period := 40
var _target := "player"
var _hit_frame := -1000
var _start_frame := -1
var _after: Array = []  # [frame-after-hit offset 0..3] -> list
var _quiet: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("hits="):
			_n = int(arg.trim_prefix("hits="))
		if arg.begins_with("period="):
			_period = int(arg.trim_prefix("period="))
		if arg.begins_with("target="):
			_target = arg.trim_prefix("target=")
	for k in 4:
		_after.append([])
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_d: float) -> bool:
	var now := Time.get_ticks_usec()
	var dt := now - _last
	_last = now
	_frame += 1
	if _frame in [8, 14]:
		_key(KEY_ENTER, true)
	if _frame in [9, 15]:
		_key(KEY_ENTER, false)
	if _main.driver == null:
		return false
	if _start_frame < 0:
		_start_frame = _frame + 60  # let the stage settle
	var since := _frame - _hit_frame
	if _hits > 0 and since >= 1 and since <= 4:
		_after[since - 1].append(dt)
	elif _hits > 0 and since > 10:
		_quiet.append(dt)
	if _frame >= _start_frame and (_frame - _start_frame) % _period == 0:
		if _hits >= _n:
			_finish()
			return true
		var w := _main.driver.world
		var t := 0
		if _target == "enemy":
			t = -1
			for i in range(1, w.actors.size()):
				if w.actors.dead[i] == 0:
					t = i
					break
		if t >= 0:
			w.actors.hp[t] = maxi(w.actors.hp[t], 1000)
			w.actors.invuln[t] = 0
			Damage.hit(
				w, t, 1, 999999, 999999, 999999, 0, w.actors.pos(t) + Vector2(1, 0), w.actors.pos(t)
			)
			_hits += 1
			_hit_frame = _frame
	return false


func _finish() -> void:
	print("target=%s hits=%d period=%d" % [_target, _hits, _period])
	for k in 4:
		print("  frame +%d after the hit: %s" % [k + 1, _stats(_after[k])])
	print("  frames >10 after a hit: %s" % _stats(_quiet))
	print(
		(
			"  nodes=%d orphans=%d objects=%d"
			% [
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_COUNT)
			]
		)
	)
	quit(0)


func _stats(a: Array) -> String:
	if a.is_empty():
		return "n=0"
	var s := a.duplicate()
	s.sort()
	var sum := 0
	for v in s:
		sum += v
	return (
		"n=%d mean=%.1fms p50=%.1fms max=%.1fms"
		% [s.size(), sum / 1000.0 / s.size(), s[s.size() / 2] / 1000.0, s[-1] / 1000.0]
	)


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
