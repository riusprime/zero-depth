extends SceneTree
## The one-frame spikes of play, measured in the real game: the shop panel opening, a reward's pick opening, and a
## boss appearing. It boots main.tscn, starts a run (Play, Blade) and, with the hero unhurt, repeats each a few times:
## - shop: the hero stands at the terminal with shards to spend, E opens the panel, Escape closes it;
## - pick: an altar is put beside the hero, E opens its three cards, 1 takes the first;
## - boss: each of the floor's bosses is spawned beside the hero (and removed again after its frames are read);
## - walk (only when asked): the hero circles the arrival room, and the mean frame and buckets are printed.
## For each it prints the slowest frame of the frames after the key (or the spawn) and the PerfMarks buckets over 1 ms
## in that window. Probe setup only (the hero placed, shards and altars given directly); the input is real keys.
## Needs a renderer (not --headless); run it off screen:
##   godot --path . --position -10000,-10000 --resolution 2560x1440 --windowed -s scripts/checks/ui_spike_probe.gd \
##     [-- --rounds=4] [-- --only=shop,pick,boss,walk]
## Report on stdout and in build/perf/ui_spikes_<sha>.txt (never into docs).

const WINDOW := 14
const WALK_FRAMES := 600
const GIVE_UP_FRAMES := 20000

var _main: Main
var _frame := 0
var _rounds := 4
var _only := PackedStringArray(["shop", "pick", "boss"])
var _plan: Array[StringName] = []
var _step := &"boot"
var _step_frame := 0
var _round := 0
var _last_us := 0
var _win_max := 0.0
var _win_frames := 0
var _win_marks := {}
var _boss_id := -1
var _lines := PackedStringArray()
var _walk_ms := 0.0
var _walk_marks := {}
var _walk_at := Vector2.ZERO


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rounds="):
			_rounds = int(a.trim_prefix("--rounds="))
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",")
	for s in _only:
		_plan.append(StringName(s))
	Main.quick_start = true  # Play opens the build screen, the pick starts the run (no hub walk)
	Main.fixed_seed = Main.STAGE_SEED
	ProfileStore.use_shared(ProfileStore.new(""))
	SwordLock.grant(ProfileStore.shared())
	RunSaveStore.use_shared(RunSaveStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	var now := Time.get_ticks_usec()
	var ms := float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	if _frame > GIVE_UP_FRAMES:
		_out("ui_spike_probe: gave up in step %s" % _step)
		_finish(1)
		return false
	if _main.driver != null and _main.driver.world != null:
		_main.driver.world.actors.invuln[0] = 2  # probe setup: the hero can't be hurt
	_step_frame += 1
	if _win_frames > 0:
		_collect(ms)
	match _step:
		&"boot":
			if _frame in [10, 20]:
				_tap(KEY_ENTER)  # Play, then Blade
			if _main.driver != null and _main.driver.world != null and _frame > 300:
				PerfMarks.on = true
				_next_part()
		&"shop":
			_shop_step()
		&"pick":
			_pick_step()
		&"boss":
			_boss_step()
		&"walk":
			_walk_step(ms)
	PerfMarks.clear()
	return false


func _next_part() -> void:
	_round = 0
	if _plan.is_empty():
		_finish(0)
		return
	_go(_plan.pop_front())


func _go(step: StringName) -> void:
	_step = step
	_step_frame = 0


func _shop_step() -> void:
	var w := _main.driver.world
	if _step_frame == 1:
		if w.shop.room < 0:
			_out("shop: this floor has no shop")
			_next_part()
			return
		w.shards = 999
		w.actors.set_pos(0, ShopPlacement.front(w.floor_layout) + Vector2(0.4, 0.4))
	elif _step_frame == 30:
		_open_window()
		_tap(KEY_E)
	elif _step_frame == 30 + WINDOW:
		_close_window("shop open", _main.driver.reader.shop_open())
		_tap(KEY_ESCAPE)
	elif _step_frame == 30 + WINDOW + 20:
		_again()


func _pick_step() -> void:
	var w := _main.driver.world
	if _step_frame == 1:
		w.add_reward(RewardStore.Kind.ALTAR, w.player_pos() + Vector2(0.9, 0.0), 0)
	elif _step_frame == 20:
		_open_window()
		_tap(KEY_E)
	elif _step_frame == 20 + WINDOW:
		_close_window("pick open", _main.driver.reader.choosing())
		_tap(KEY_1)
	elif _step_frame == 20 + WINDOW + 60:
		_again()


## The floor as play shows it: the hero walks round the arrival room for WALK_FRAMES frames; the mean frame and the
## mean of each PerfMarks bucket over 50 us (the per-frame drawers, the effects layer).
func _walk_step(ms: float) -> void:
	var w := _main.driver.world
	if _step_frame == 1:
		_walk_ms = 0.0
		_walk_marks = {}
		_walk_at = w.player_pos()
	var t := float(_step_frame) / 60.0
	w.actors.set_pos(0, _walk_at + Vector2(cos(t), sin(t)) * 3.0)
	if _step_frame > 30:
		_walk_ms += ms
		for k: StringName in PerfMarks.us:
			_walk_marks[k] = float(_walk_marks.get(k, 0.0)) + float(PerfMarks.us[k])
	if _step_frame == 30 + WALK_FRAMES:
		var keys := _walk_marks.keys()
		keys.sort_custom(
			func(a: StringName, b: StringName) -> bool: return _walk_marks[a] > _walk_marks[b]
		)
		var top := PackedStringArray()
		for k: StringName in keys:
			var us := float(_walk_marks[k]) / WALK_FRAMES
			if us >= 50.0 and top.size() < 16:
				top.append("%s %.0f" % [k, us])
		_out(
			(
				"walk: %d frames, mean frame %.2f ms; buckets (mean us a frame): %s"
				% [WALK_FRAMES, _walk_ms / WALK_FRAMES, ", ".join(top)]
			)
		)
		_next_part()


func _boss_step() -> void:
	var w := _main.driver.world
	if _step_frame == 1:
		if _round >= w.boss_tables.size():
			_next_part()
			return
		_open_window()
		_boss_id = w.spawn_boss(_round, w.player_pos() + Vector2(4.0, 0.0))
	elif _step_frame == 1 + WINDOW:
		_close_window("boss %d appears" % _round, _boss_id >= 0)
		_remove_boss(w)
	elif _step_frame == 1 + WINDOW + 60:
		_again(w.boss_tables.size())


func _remove_boss(w: World) -> void:
	var i := w.actors.index_of(_boss_id)
	if i >= 0:
		w.actors.hp[i] = 0  # the sim's own death path removes it on the next tick


func _again(limit: int = -1) -> void:
	_round += 1
	var n := _rounds if limit < 0 else mini(_rounds, limit)
	if _round >= n:
		_next_part()
	else:
		_step_frame = 0


func _open_window() -> void:
	_win_frames = WINDOW
	_win_max = 0.0
	_win_marks = {}


func _collect(ms: float) -> void:
	_win_frames -= 1
	_win_max = maxf(_win_max, ms)
	for k: StringName in PerfMarks.us:
		var v := float(PerfMarks.us[k]) / 1000.0
		if v > float(_win_marks.get(k, 0.0)):
			_win_marks[k] = v


func _close_window(what: String, happened: bool) -> void:
	_win_frames = 0
	var keys := _win_marks.keys()
	keys.sort_custom(
		func(a: StringName, b: StringName) -> bool: return _win_marks[a] > _win_marks[b]
	)
	var top := PackedStringArray()
	for k: StringName in keys:
		if float(_win_marks[k]) >= 0.3 and top.size() < 14:
			top.append("%s %.1f" % [k, _win_marks[k]])
	_out(
		(
			"%s round %d: %s  slowest frame %.1f ms  buckets (max ms a frame): %s"
			% [what, _round, "yes" if happened else "NO", _win_max, ", ".join(top)]
		)
	)


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _out(line: String) -> void:
	print(line)
	_lines.append(line)


func _finish(code: int) -> void:
	var out := []
	OS.execute("git", ["rev-parse", "--short", "HEAD"], out)
	var tag := String(out[0]).strip_edges() if not out.is_empty() else "nosha"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/perf"))
	var f := FileAccess.open("res://build/perf/ui_spikes_%s.txt" % tag, FileAccess.WRITE)
	if f != null:
		f.store_string(
			"ui_spike_probe sha=%s adapter=%s\n" % [tag, RenderingServer.get_video_adapter_name()]
		)
		f.store_string("\n".join(_lines) + "\n")
	quit(code)
