extends SceneTree
## Crash-on-hit soak (PLAN v0.3.0 L28, docs/roadmap/v0.3.0/evidence/CRASH_ON_HIT.md). Plays main.tscn for a long
## time and gets the wanderer hit by everything, headless or rendered:
##   godot --headless --fixed-fps 60 --path . -s scripts/checks/hit_soak.gd -- frames=30000
##   godot --path . --audio-driver Dummy -s scripts/checks/hit_soak.gd -- frames=6000      (needs a renderer)
## A pad bot drives the game through Input.parse_input_event: the left stick walks a flow field to the nearest enemy
## (or the boss), the triggers swing and shoot along the right stick, the bumpers dash and guard; on death Enter on
## the end panel restarts. Lives take plans in PLAN_ORDER (a life past LIFE_CAP restarts from the pause menu; a
## non-run life stops fighting back after PASSIVE_AFTER frames, so it ends in a death):
##   0 brawl: no items; every enemy kind is queued near the player now and then;
##   1 brawl with every item (statuses, engines, combos on);
##   2 boss: every item, the next of the three bosses spawned 6 m away (World.spawn_boss, what the dev panel calls),
##     fought;
##   3 run: every item (after the pick), HP topped up below 40 %: an altar's pick (E, then Enter after a few hit
##     frames), through the boss door (sealing), the real boss for a while, Kill boss (the dev panel's call), the
##     portal to the next floor, a fight there, then Esc -> Restart run from the pause menu mid-fight.
## The pokes (items, boss spawn, HP top-up, boss kill) touch World between ticks, so this is a measurement harness,
## not an e2e test, and nothing it prints is evidence until pasted by hand. It never turns on God mode.
## Watches: every engine/script error (an OS logger), node/object/orphan counts, the ActorViews dictionaries, and
## hits on the wanderer by attacker kind and boss move. Exit code 1 on any error.

const PLAN_NAMES := ["brawl", "brawl_items", "boss", "run"]
## The plan of each life in turn: a boss every other life, so each boss comes round often.
const PLAN_ORDER := [0, 2, 1, 2, 3, 2]
const REPORT_EVERY := 1200
## A life that hasn't ended by then restarts from the pause menu.
const LIFE_CAP := 6000
## Non-run lives stop swinging, guarding and dashing after this many frames.
const PASSIVE_AFTER := 2500


class ErrorCounter:
	extends Logger
	var errors := 0
	var first: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors += 1
		if first.size() < 20:
			first.append("%s:%d %s: %s %s" % [file, line, function, code, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _main: Main
var _log := ErrorCounter.new()
var _frame := 0
var _frames := 30000
var _seq := 0
var _world: World
var _life := 0
var _plan := 0
var _life_frame := 0
var _stage := ""
var _stage_frame := 0
var _deaths := 0
var _floors := 0
var _restarts := 0
var _hits := 0
var _hits_by := {}
var _boss_moves := {}
var _picks := 0
var _seals := 0
var _nav: NavField
var _nav_target := Vector2.INF
var _end_wait := 0
var _max_nodes := 0
var _max_orphans := 0
var _max_tint := 0
var _max_flash := 0
var _first_nodes := -1
var _boss_cycle := 0
var _hold := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("frames="):
			_frames = int(arg.trim_prefix("frames="))
	OS.add_logger(_log)
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	print("hit_soak: frames=%d plans=%s" % [_frames, PLAN_NAMES])


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 6 or _frame == 12:
		_tap_key(KEY_ENTER)  # Play, then the utility picker's Guard
	if _frame >= _frames:
		_finish()
		return true
	if _main.driver == null:
		return false
	var w := _main.driver.world
	if w != _world:
		_new_world(w)
	_read_events(w)
	_bot(w)
	if _frame % 60 == 0:
		_watch()
	if _frame % REPORT_EVERY == 0:
		_report()
	return false


func _new_world(w: World) -> void:
	var fresh_life := _world == null or w.floor_index <= _world.floor_index
	if _world != null and not fresh_life:
		_floors += 1
	_world = w
	_seq = w.last_event_seq()
	_nav = NavField.new()
	_nav.build(w.walls)
	_nav_target = Vector2.INF
	if fresh_life:
		if _first_nodes < 0:
			_first_nodes = _node_count()
		_plan = PLAN_ORDER[_life % PLAN_ORDER.size()]
		_life += 1
		_life_frame = 0
		_stage = "fight" if _plan < 3 else "altar"
		_stage_frame = 0
		if _plan == 1 or _plan == 2:
			_grant_items(w)
		if _plan == 2 and not w.boss_tables.is_empty():
			var k := _boss_cycle % w.boss_tables.size()
			_boss_cycle += 1
			w.spawn_boss(k, DebugApi.boss_spot(w, w.boss_tables[k].radius_m))
	else:
		_stage = "fight2"
		_stage_frame = 0


func _grant_items(w: World) -> void:
	for k in w.item_tables.size():
		w.add_item(k)


func _read_events(w: World) -> void:
	for e in w.events_since(_seq):
		_seq = e.seq
		if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
			_hits += 1
			var k := w.actors.index_of(e.owner_id)
			var kind := w.actors.kinds[k] if k >= 0 else -1
			var key := "%s%s" % [_kind_name(kind), "/dot" if e.tags & SimEvent.TAG_DOT else ""]
			_hits_by[key] = _hits_by.get(key, 0) + 1
			if k >= 0 and BossAi.is_boss_kind(kind):
				var mv := "%s:%d" % [_kind_name(kind), _main.driver.reader.boss_move(k)]
				_boss_moves[mv] = _boss_moves.get(mv, 0) + 1


func _bot(w: World) -> void:
	_life_frame += 1
	_stage_frame += 1
	if w.player_dead():
		_release_all()
		_end_wait += 1
		if _main.get_node_or_null("UI/EndPanel") != null and _end_wait > 10:
			_deaths += 1
			_end_wait = 0
			_tap_key(KEY_ENTER)  # Restart has focus
		return
	_end_wait = 0
	if w.choosing >= 0:
		_release_all()
		if _stage_frame > 20:  # take hit frames with the pick panel up first
			_tap_key(KEY_ENTER)
			_picks += 1
			_grant_items(w)  # after the pick: an altar with nothing left to offer turns you away
			_stage = "door"
			_stage_frame = 0
		return
	if _plan == 3:
		if w.actors.hp[0] * 100 < w.actors.max_hp[0] * 40:
			w.actors.hp[0] = w.actors.max_hp[0]  # the run plan's top-up (never invulnerable)
		_run_plan(w)
		return
	if _stage == "paused":
		_run_plan(w)
		return
	if _life_frame > LIFE_CAP:
		# A build too strong to die: Esc -> Restart run, like the run plan's ending.
		_pause_restart()
		return
	if _plan < 2 and _life_frame % (600 if _life_frame < 2500 else 200) == 100:
		# Every enemy kind, again and again (the floor's director alone rarely sends Wardens this early).
		for kind in [ActorStore.Kind.CHARGER, ActorStore.Kind.WARDEN, ActorStore.Kind.NEEDLE]:
			w.queue_enemy(kind, DebugApi.boss_spot(w, 0.6))
	_fight(w, _boss_or_nearest(w) if _plan == 2 else _nearest_enemy(w))


func _boss_or_nearest(w: World) -> Vector2:
	var i := w.actors.index_of(w.boss_id) if w.boss_id >= 0 else -1
	if i >= 0 and w.actors.dead[i] == 0:
		return w.actors.pos(i)
	return _nearest_enemy(w)


func _run_plan(w: World) -> void:
	match _stage:
		"altar":
			_altar(w)
		"door":
			_door(w)
		"boss":
			if _stage_frame > 1800 or not w.boss_alive():
				var i := w.actors.index_of(w.boss_id) if w.boss_id >= 0 else -1
				if i >= 0:
					var at := w.actors.pos(i)
					Damage.hit(w, i, w.actors.hp[i] * 10, 0, 0, w.take_root(), 0, at, at)
				_go("portal")
			else:
				_fight(w, _boss_or_nearest(w))
		"portal":
			if _stage_frame > 5000:
				_go("fight2")
			else:
				var f := w.floor_layout
				_walk(w, f.portal_pos + f.portal_facing() * 1.0, false)
		"fight2":
			if _stage_frame > 1500:
				_pause_restart()
			else:
				_fight(w, _nearest_enemy(w))
		"paused":
			if _stage_frame == 5:
				_tap_key(KEY_DOWN)
			elif _stage_frame == 8:
				_tap_key(KEY_ENTER)  # Restart run
				_world = null  # the restart is a new life even if it starts on floor 1 again
			elif _stage_frame > 120:
				_pause_restart()  # the pause menu didn't take the input: try again


func _go(stage: String) -> void:
	_stage = stage
	_stage_frame = 0


## Esc (pad Start) opens the pause menu; the "paused" stage then picks Restart run.
func _pause_restart() -> void:
	_release_all()
	_restarts += 1
	_go("paused")
	_button(JOY_BUTTON_START, true)
	_button(JOY_BUTTON_START, false)


func _altar(w: World) -> void:
	var a := _nearest_altar(w)
	if a < 0 or _stage_frame > 3000:
		var away := w.rewards.pos(a).distance_to(w.player_pos()) if a >= 0 else -1.0
		print("run plan: no altar pick (altar %d, %.1f m away)" % [a, away])
		_grant_items(w)
		_go("door")
		return
	var at := w.rewards.pos(a)
	if (at - w.player_pos()).length() < w.reward_table.interact_radius_m * 0.6:
		_release_all()
		_button(JOY_BUTTON_X, _stage_frame % 10 == 0)
	else:
		_walk(w, at, false)


func _door(w: World) -> void:
	var f := w.floor_layout
	if f == null or f.boss_room < 0:
		_go("fight2")
	elif w.boss_flow.door_sealed():
		_seals += 1
		_go("boss")
	elif _stage_frame > 5000:
		_go("boss")
	else:
		_walk(w, f.boss_door_inside(2.0), true)


func _fight(w: World, target: Vector2) -> void:
	var p := w.player_pos()
	var d := target - p
	if d.length() > 1.6:
		_walk(w, target, false)
	else:
		_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, Vector2.ZERO)
	_stick(
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, d.normalized() if d.length() > 0.01 else Vector2.RIGHT
	)
	var t := _life_frame
	if _plan < 3 and t > PASSIVE_AFTER:
		# Long enough: stop fighting back and stand in the crowd, so this life ends in a death.
		_release_buttons()
		return
	# Melee taps, sparse enough that the enemies get their hits in.
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0 if t % 30 < 2 else 0.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0 if t % 120 > 80 else 0.0)  # bursts of shots
	_button(JOY_BUTTON_RIGHT_SHOULDER, t % 97 == 0)  # a dash now and then
	_button(JOY_BUTTON_LEFT_SHOULDER, t % 200 > 170)  # guard now and then


func _walk(w: World, target: Vector2, push_in: bool) -> void:
	if _nav_target.distance_to(target) > 0.5 or _life_frame % 30 == 0:
		_nav.flood(target)
		_nav_target = target
	var p := w.player_pos()
	var dir := _nav.direction(p)
	if (target - p).length() < 1.5 or dir == Vector2.ZERO:
		dir = (target - p).normalized() if (target - p).length() > 0.2 else Vector2.ZERO
		if push_in and w.floor_layout != null:
			dir = Kin.dir(w.floor_layout.boss_door_angle)
	_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, dir)


func _nearest_enemy(w: World) -> Vector2:
	var best := w.player_pos() + Vector2(1, 0)
	var dist := INF
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 1 or not EnemyAi.is_enemy_kind(w.actors.kinds[i]):
			continue
		var dd := w.actors.pos(i).distance_to(w.player_pos())
		if dd < dist:
			dist = dd
			best = w.actors.pos(i)
	return best


func _nearest_altar(w: World) -> int:
	var best := -1
	for i in w.rewards.size():
		if w.rewards.kind[i] != RewardStore.Kind.ALTAR:
			continue
		if (
			best < 0
			or (
				w.rewards.pos(i).distance_to(w.player_pos())
				< w.rewards.pos(best).distance_to(w.player_pos())
			)
		):
			best = i
	return best


## A sim-plane direction on a stick (the inverse of the +45 degree screen-to-sim rotation; stick y is down).
func _stick(ax: JoyAxis, ay: JoyAxis, dir: Vector2) -> void:
	var c := InputLatch.C45
	_axis(ax, (dir.x + dir.y) * c)
	_axis(ay, -(dir.y - dir.x) * c)


func _axis(axis: JoyAxis, v: float) -> void:
	if is_equal_approx(_hold.get(axis, 0.0), v):
		return
	_hold[axis] = v
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = v
	_send(ev)


func _button(b: JoyButton, pressed: bool) -> void:
	var key := 100 + b
	if _hold.get(key, false) == pressed:
		return
	_hold[key] = pressed
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	ev.pressed = pressed
	_send(ev)


func _release_buttons() -> void:
	for a in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		_axis(a, 0.0)
	for b in [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_X]:
		_button(b, false)


func _release_all() -> void:
	for a in [
		JOY_AXIS_LEFT_X,
		JOY_AXIS_LEFT_Y,
		JOY_AXIS_RIGHT_X,
		JOY_AXIS_TRIGGER_LEFT,
		JOY_AXIS_TRIGGER_RIGHT
	]:
		_axis(a, 0.0)
	for b in [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_X]:
		_button(b, false)


func _tap_key(k: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.keycode = k
		ev.pressed = pressed
		_send(ev)


func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _watch() -> void:
	_max_nodes = maxi(_max_nodes, _node_count())
	_max_orphans = maxi(
		_max_orphans, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	)
	if _main.view != null:
		_max_tint = maxi(_max_tint, _main.view.actors.get(&"_tint").size())
		_max_flash = maxi(_max_flash, _main.view.actors.get(&"_flash").size())


func _report() -> void:
	print(
		(
			(
				"frame %d life %d plan %s stage %s floor %d | deaths %d floors %d restarts %d hits %d picks %d"
				+ " seals %d | nodes %d orphans %d objects %d | errors %d"
			)
			% [
				_frame,
				_life,
				PLAN_NAMES[_plan],
				_stage,
				_world.floor_index if _world != null else 0,
				_deaths,
				_floors,
				_restarts,
				_hits,
				_picks,
				_seals,
				_node_count(),
				int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
				int(Performance.get_monitor(Performance.OBJECT_COUNT)),
				_log.errors
			]
		)
	)


func _finish() -> void:
	_report()
	print("hits on the wanderer by attacker: %s" % [_hits_by])
	print("boss hits by kind:move: %s" % [_boss_moves])
	print(
		(
			"lives %d deaths %d floor transitions %d pause restarts %d picks %d door seals %d"
			% [_life, _deaths, _floors, _restarts, _picks, _seals]
		)
	)
	print(
		(
			"nodes first fight %d max %d | max orphans %d | max ActorViews _tint %d _flash %d"
			% [_first_nodes, _max_nodes, _max_orphans, _max_tint, _max_flash]
		)
	)
	print("errors %d" % _log.errors)
	for line in _log.first:
		print("  " + line)
	_main.queue_free()
	quit(1 if _log.errors > 0 else 0)


static func _kind_name(kind: int) -> String:
	return ActorStore.Kind.keys()[kind] if kind >= 0 and kind < ActorStore.Kind.size() else "none"
