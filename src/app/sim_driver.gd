class_name SimDriver
extends Node
## Steps the sim in _physics_process at 60 Hz (ARCHITECTURE §4). Godot's catch-up cap
## (max_physics_steps_per_frame = 4) slows the game on a long hitch instead of skipping time.

signal ticked
## v0.10.5 Q5 (owner: "Q5 yes fix it"): once a rendered frame that ran one tick or more, after them (from _process,
## before the views' own _process): the world views sync here, once, on the latest state. A frame that falls behind
## runs several ticks, and syncing the views on each of them paid the whole sync again (PERF_Q5 §5). What happened
## between two frames still reaches the views: they read the event log from their own cursor (events_since), and
## WorldViewRoot.note_tick (on `ticked`) keeps the facts that last one tick. The gameplay listeners (the save, the
## Codex, the achievements, the HUD, the audio) stay on `ticked`.
signal frame_ticked
## v0.7.5 PG: Playground commands changed the World between ticks (also while paused): the views read it again.
signal edited

var world: World
var reader: WorldReader
var latch := InputLatch.new()
## Sim ticks run since the last rendered frame (the dev panel shows it; the hitch probe checks it).
var ticks_this_frame := 0
var paused := false
## Optional dev-panel commands (debug builds); null in release play.
var debug: DebugApi
## v0.7.5 PG: the Playground's commands (null outside it), applied before every tick and, while paused, each frame.
var playground: PlaygroundApi
## Where input comes from: a Callable returning [move_screen: Vector2, aim_world: Vector2, aim_dist_m: float].
var input_source: Callable
## v0.8.0 N11 (owner O69): while the world's arrival hasn't played yet and this returns true, the world waits (Main:
## the loading cover still shows, so the arrival plays once the cover opened). Empty: never.
var hold: Callable
## v0.11.1 T1 (owner L7): a test-only start (Main.quick_start): the world's arrival runs in the first tick frame, every
## tick of it as in play (no hold), so the World after it is the one a normal arrival leaves. False in the game.
var rush_arrival := false
## v0.6.5 WN2: the frame the last tick stepped with (read only: the e2e tests record a run's frames to replay it).
var last_frame: InputFrame


func setup(p_world: World) -> void:
	world = p_world
	reader = WorldReader.new(world)


func _input(event: InputEvent) -> void:
	for action: StringName in InputDefaults.BUTTON_BITS:
		if event.is_action_pressed(action):
			latch.note_pressed(InputDefaults.BUTTON_BITS[action])
		elif event.is_action_released(action):
			latch.note_released(InputDefaults.BUTTON_BITS[action])


func _process(_delta: float) -> void:
	if debug != null:
		debug.ticks_last_frame = ticks_this_frame
	var ran := ticks_this_frame
	ticks_this_frame = 0
	if ran > 0:
		var t0 := PerfMarks.start()
		frame_ticked.emit()
		PerfMarks.add(&"frame_synced", t0)


func _physics_process(_delta: float) -> void:
	if world == null:
		return
	if paused:
		if playground != null and playground.apply_pending():
			edited.emit()
		return
	if debug != null and not debug.should_step():
		return
	if rush_arrival and reader.arriving():
		while reader.arriving():
			step_once()
		return
	if hold.is_valid() and reader.arriving() and hold.call():
		return
	var t_phys := PerfMarks.start()
	step_once()
	PerfMarks.add(&"step_once", t_phys)


## One tick: close the latched frame, then step the world.
func step_once() -> void:
	var move := Vector2.ZERO
	var aim := Vector2.ZERO
	var dist := 0.0
	if input_source.is_valid():
		var src: Array = input_source.call()
		move = src[0]
		aim = src[1]
		dist = src[2]
	else:
		var v := Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up")
		move = v
	if debug != null:
		debug.apply_pending()  # dev-panel commands land between ticks
	if playground != null:
		playground.apply_pending()  # v0.7.5 PG: so do the Playground's (and its upkeep)
	last_frame = latch.close_frame(move, aim, dist)
	var t0 := PerfMarks.start()
	world.step(last_frame)
	PerfMarks.add(&"sim_step", t0)
	ticks_this_frame += 1
	t0 = PerfMarks.start()
	ticked.emit()
	PerfMarks.add(&"ticked_all", t0)
