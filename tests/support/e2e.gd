class_name E2e
extends RefCounted
## Drives the real game the way a player does: Input.parse_input_event, then flush, then wait for physics
## frames (TEST_MATRIX T-E2E). No calls into game objects to make things happen; reads are fine.

## walk_to's budget (frames of stick input).
const WALK_FRAMES := 2400
## v0.8.0 N12: the longest a load behind the cover may take (wall clock) before loaded() gives up.
const LOAD_MS := 120000

var test: GutTest
var main: Main
## v0.9.0: the window's mouse scale, measured once (the probe move it takes aimed the hero at (100, 100) for a
## frame on every mouse_to; AF2, AF3 found shots firing at it).
var _scale := Vector2.ZERO


func _init(p_test: GutTest) -> void:
	test = p_test


## Boots main.tscn with a memory-only profile (optionally pre-filled) and waits for the menu. v0.6.5 WN5b: `saves`, a
## memory-only run save store already holding a save (an old one to Continue), else an empty one. v0.8.0 N1 (O53):
## `seed`, the seed mode (Main.fixed_seed): the e2e keep the fixed STAGE_SEED order on purpose (the first new run takes
## it, each later one the next); RunSeeds.RANDOM plays as the game does.
func boot(
	profile: ProfileStore = null, saves: RunSaveStore = null, seed: int = Main.STAGE_SEED
) -> Main:
	Main.fixed_seed = seed
	center_sticks()  # v0.8.0 fix: no stick an earlier test left pushed
	ProfileStore.use_shared(profile if profile != null else ProfileStore.new(""))
	RunSaveStore.use_shared(saves if saves != null else RunSaveStore.new(""))  # v0.4.0 SV: none from an earlier test
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	test.add_child_autofree(main)
	await frames(2)
	return main


## v0.8.0 N12 (owner O70): `n` frames of play. A load behind the cover (a new run, Continue, Restart, a portal) now
## runs over many frames; those are not counted: when one is running, this waits until its floor is live (wall
## clock, at most LOAD_MS), so a test's frame counts stay frames of play. test_e2e_loading_cover watches the load's
## own frames with the tree's physics_frame directly.
func frames(n: int) -> void:
	for i in n:
		await test.get_tree().physics_frame
		await _through_load()


func _through_load() -> void:
	if main == null or not is_instance_valid(main):
		return
	# v0.9.0 HB2: the hero's walk into the portal leads into the run's load: waited through like it (a test that
	# watches the walk steps raw frames: HubWalk.through_portal).
	var walk_frames := 0
	while main.hub != null and main.hub.walking and not main.loads.busy() and walk_frames < 600:
		walk_frames += 1
		await test.get_tree().physics_frame
	if not main.loads.busy():
		return
	var from := Time.get_ticks_msec()
	while main.loads.busy() and Time.get_ticks_msec() - from < LOAD_MS:
		await test.get_tree().physics_frame
	if main.loads.busy():
		test.fail_test("a load behind the cover took over %d ms" % LOAD_MS)


func send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = pressed
	send(ev)


## Press and release in the same frame: a tap shorter than one tick.
func tap(keycode: Key) -> void:
	key(keycode, true)
	key(keycode, false)
	await frames(1)


func joy_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	send(ev)


func joy_button(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	send(ev)


func mouse_button(button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	send(ev)


## Moves the mouse so the game receives `pos` in viewport coordinates. Headless windows are 0x0, so Godot's
## stretch transform rescales injected positions; the scale is measured once and divided out.
func mouse_to(pos: Vector2) -> void:
	var scale := await _mouse_scale()
	var ev := InputEventMouseMotion.new()
	ev.position = pos / scale
	ev.global_position = pos / scale
	send(ev)
	await frames(1)


func _mouse_scale() -> Vector2:
	if _scale != Vector2.ZERO:
		await frames(1)  # the probe's frame, kept so a test's frame counts stay as they were
		return _scale
	var probe := InputEventMouseMotion.new()
	probe.position = Vector2(100, 100)
	probe.global_position = probe.position
	send(probe)
	await frames(1)
	var got := main.get_viewport().get_mouse_position()
	_scale = got / 100.0 if got.x > 0.0 and got.y > 0.0 else Vector2.ONE
	return _scale


## Play from the main menu with the keyboard: the Play button has focus, then the build screen's last pick (Blade on
## a fresh profile; Right moves to Gun). v0.4.0 BS (F11): no utility pick; the run starts with weapon, dash, skill
## and vent. v0.8.0 N11: then waits for the hero to land on the receiver (`land` false: returns as the floor opens).
## v0.9.0 HB (owner Q27): Play goes to the hub; the hero walks (the left stick) to the Portal Machine and presses E,
## and its build screen starts the run as before.
func start_from_menu(build: StringName = &"blade", land: bool = true) -> void:
	var walk := HubWalk.new(self)
	await walk.enter()
	await walk.use(&"portal")
	if build == &"gun":
		await tap(KEY_RIGHT)
	await tap(KEY_ENTER)
	await walk.through_portal()  # v0.9.0 HB2: the hero walks up into the portal first
	await loaded()  # v0.8.0 N12: the run's first floor builds over frames behind the cover
	await frames(4)
	if land:
		await landed()


## v0.8.0 N11 (owner O69): waits (reading only) until the floor's arrival is over and play is on, `limit` frames at
## most (the cover's fade, then the arrival: floor 1's 4.0 s, v0.9.0 SA). True when it was.
func landed(limit: int = 900) -> bool:
	for k in limit:
		if main.driver != null and not main.driver.reader.arriving():
			return true
		await frames(1)
	return false


## v0.8.0 N12 (owner O70): a load behind the cover (a new run, Continue, Restart, a portal) builds its floor over
## frames, the World on a worker thread; headless frames take microseconds, so this waits on the wall clock (at most
## LOAD_MS) until the load is done (frames() does too). Returns at once when no load runs.
func loaded() -> void:
	await _through_load()


## v0.8.0 N6 (owner O60): the Playground from the main menu through the dev tools: F10, then Enter on the panel's
## Playground button (GUT's output window lies over the panel's top bar in a test run, so it gets focus directly;
## the press is a real key event). Leaves the Playground's weapon pick open, on the Gun.
func open_playground_picker() -> void:
	await tap(KEY_F10)
	var panel := main.get_node_or_null("UI/DevMasterPanel")
	test.assert_not_null(panel, "F10 opens the master dev panel")
	if panel == null:
		return
	var b := panel.find_child("Playground", true, false) as Button
	test.assert_not_null(b, "the panel's Playground button")
	if b == null:
		return
	b.grab_focus()
	await frames(1)
	await tap(KEY_ENTER)
	await frames(2)


func world() -> World:
	return main.driver.world if main.driver != null else null


## A left click at `pos` in viewport coordinates (move there, press, release), scaled like mouse_to.
func click_at(pos: Vector2) -> void:
	var scale := await _mouse_scale()
	await mouse_to(pos)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos / scale
		ev.global_position = pos / scale
		send(ev)
		await frames(1)


## Pushes the left stick toward a sim-plane direction (the inverse of the +45 degree screen-to-sim rotation; stick y
## is down). ZERO releases it.
func stick_toward(dir: Vector2) -> void:
	var c := InputLatch.C45
	joy_axis(JOY_AXIS_LEFT_X, (dir.x + dir.y) * c)
	joy_axis(JOY_AXIS_LEFT_Y, -(dir.y - dir.x) * c)


## v0.8.0 fix: lets go of both sticks (Input keeps an axis where the last motion left it, across tests). A stick
## still pushed when a test ends rode into the next file: Godot's LineEdit then doesn't start editing on focus, so
## test_e2e_dev_master_panel's typing went nowhere after test_e2e_difficulty. boot() calls it (and difficulty's
## after_each).
static func center_sticks() -> void:
	for axis: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axis
		ev.axis_value = 0.0
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


## The reward (RewardStore.Kind) nearest the player (v0.3.0 E), or -1. A read, not an action.
static func nearest_reward(w: World, kind: int) -> int:
	var best := -1
	for i in w.rewards.size():
		if w.rewards.kind[i] != kind or Arenas.locked(w, i):  # v0.5.5 AR: a locked one can't be opened
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


## The flood's goal for `target`: its own cell, or (when a wall is within the enemies' nav clearance of it, as on
## a v0.5.9 themed floor where a vignette may stand by a shop's front) the nearest free cell, from which the walk goes
## straight in. The player's radius is smaller than the nav clearance, so the target itself stays reachable.
static func _free_goal(nav: NavField, target: Vector2) -> Vector2:
	var c := nav.cell_of(target)
	if not nav.inside(c) or nav.blocked[c.y * nav.size.x + c.x] == 0:
		return target
	for ring in range(1, 8):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var n := c + Vector2i(dx, dy)
				if nav.inside(n) and nav.blocked[n.y * nav.size.x + n.x] == 0:
					return nav.center(n)
	return target


## v0.5.5 AR: the walls a walk plans around: the floor's, plus a stand-in barrier in each doorway of every arena that
## isn't cleared and doesn't hold `target`, so a walk to the boss, a shop or an event never seals an arena on the way
## (they're skippable; the player would walk around too). A read for planning only: the sim is untouched.
static func walk_walls(w: World, target: Vector2) -> Array[Obb]:
	var out: Array[Obb] = []
	for o in w.walls:  # v0.9.5 SB: a prop's footprint is planned round in a shrunk form (the nav keeps a clearance)
		var prop := false
		for i in w.solids.size():
			if (
				w.solids.placed[i] == 1
				and w.solids.center[i] == o.center
				and w.solids.half[i] == o.half
			):
				prop = true
		if not prop:
			out.append(o)
	for i in w.solids.size():
		out.append(
			Obb.make(w.solids.center[i], w.solids.half[i] - Vector2(0.3, 0.3), w.solids.angle[i])
		)
	var f := w.floor_layout
	if f == null:
		return out
	var rooms := f.arena_rooms.duplicate()
	if f.overrun_room >= 0 and Overrun.enabled(w):
		rooms.append(f.overrun_room)
	for room in rooms:
		if Arenas.is_cleared(w, room) or f.room_of(target) == room or w.arenas.room == room:
			continue
		for d in ArenaRooms.doors_of(f, room):
			out.append(ArenaRooms.barrier(f, d))
	# v0.9.0 LK: the Lockdowns the same way (skippable as arenas; a walk only enters the one it goes to)
	for room in f.lockdown_rooms:
		if Lockdowns.is_open(w, room) or f.room_of(target) == room:
			continue
		if w.lockdown != null and w.lockdown.room == room:
			continue
		for d in ArenaRooms.doors_of(f, room):
			out.append(ArenaRooms.barrier(f, d))
	return out


## Walks with the left stick only (a flow field toward `target`, then straight in) until within `within` m, then
## lets go and waits for the player to stop. False if it didn't get there (or died).
func walk_to(target: Vector2, within: float) -> bool:
	var w := world()
	# v0.9.5 SB: a solid prop (an altar, a pedestal) stops the hero at its surface, 1.0-1.25 m from its centre.
	for i in w.solids.size():
		if w.solids.center[i].distance_to(target) < 0.05:
			within = maxf(within, 1.35)
	var nav := NavField.new()
	nav.build(walk_walls(w, target))
	nav.flood(_free_goal(nav, target))
	var ok := false
	for k in WALK_FRAMES:
		var p := w.player_pos()
		if (target - p).length() <= within:
			ok = true
			break
		if w.player_dead():
			break
		var dir := nav.direction(p)
		if dir == Vector2.ZERO:  # v0.9.5 SB: against a prop the hero's cell can be blocked: use a free cell near it
			for ring in [0.6, 1.0]:
				for a in 8:
					var q: Vector2 = p + Vector2.from_angle(TAU * a / 8.0) * ring
					var d: Vector2 = nav.direction(q)
					if dir == Vector2.ZERO and d != Vector2.ZERO:
						dir = (q - p).normalized() if ring > 0.0 else d
		if (target - p).length() < 1.5 or dir == Vector2.ZERO:
			dir = (target - p).normalized()
		# Sim direction -> screen stick (the inverse of the +45 degree screen-to-sim rotation); stick y is down.
		var c := InputLatch.C45
		var screen := Vector2((dir.x + dir.y) * c, (dir.y - dir.x) * c)
		joy_axis(JOY_AXIS_LEFT_X, screen.x)
		joy_axis(JOY_AXIS_LEFT_Y, -screen.y)
		await frames(1)
	joy_axis(JOY_AXIS_LEFT_X, 0.0)
	joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	await frames(12)
	return ok


## v0.8.0 BD (owner O83): walks up to the shut boss door, presses interact (E) and waits until it is open. True when
## it is open (at once on a floor without the press, or once it already opened or the fight began).
## v0.9.0 FA (owner Q18): on the final approach, walks (the stick) up the causeway to each rune pylon and presses E
## by it, then waits (reading only) through the buildup until the fight has begun. True when the Colossus rose.
## Returns at once (true) off the approach or once its fight began.
func awaken_final_altar() -> bool:
	var w := world()
	if w == null or w.approach == null:
		return true
	await landed()
	var f := w.floor_layout
	for k in f.pylons.size():
		if w.approach.lit[k] == 0:
			await walk_to(f.pylons[k], 1.2)
			stick_toward(Vector2.ZERO)
			await tap(KEY_E)
			await frames(2)
	for k in FinalApproach.BUILDUP_TICKS + 60:
		if w.final_fight != null:
			break
		await frames(1)
	return w.final_fight != null


func open_boss_door() -> bool:
	var w := world()
	var bf := w.boss_flow
	if bf == null or w.floor_layout == null or w.floor_layout.boss_room < 0:
		return true
	if bf.door == BossFlow.Door.PASSAGE or bf.door == BossFlow.Door.OPEN:
		return true
	await walk_to(w.floor_layout.boss_door_outside(0.9), 0.5)
	if bf.door == BossFlow.Door.SHUT:
		await tap(KEY_E)
	for k in BossFlow.DOOR_OPEN_TICKS + 30:
		if bf.door == BossFlow.Door.OPEN or w.player_dead():
			break
		await frames(1)
	return bf.door == BossFlow.Door.OPEN
