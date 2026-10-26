extends GutTest
## v0.9.0 TD (owner W §2: "Two interactive switches … must be activated. Activating both opens the door … The player
## must reach the entrance before the timer expires. If the player fails, the door closes and the mechanisms reset";
## "No permanent penalty for failure. Reset safely without trapping the player"; Q20: 15 s from the second switch, an
## epic altar or a chest inside; Q22: puzzle calm, a quarter of the rate; Q23: the room unseen until it opens): the
## timed door in the sim (TimedDoor on the shared interactables). Either switch order opens it; the timer is 1200 ticks
## (v0.9.5 TS: 20 s)
## from the second; on expiry it shuts and both switches reset; it never shuts with the hero in the doorway or inside,
## and shuts once the hero has left through it; the room's reward is there; calm holds in the switches' room until it
## opens; a save mid-timer resumes exactly.


func _world() -> World:
	return TimedLab.world()


func _press() -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 1000, InputFrame.INTERACT, InputFrame.INTERACT)


func _put(w: World, p: Vector2) -> void:
	w.actors.set_pos(0, p)
	w.vel = Vector2.ZERO


func _slab_up(w: World) -> bool:
	var o := w.floor_layout.timed_door_wall
	for x in w.walls:
		if x.center == o.center and x.half == o.half and x.angle == o.angle:
			return true
	return false


## Stands by switch k and presses.
func _switch(w: World, k: int) -> void:
	_put(w, w.floor_layout.timed_switches[k] + Vector2(0.3, 0.0))
	w.step(InputFrame.new())
	w.step(_press())


## A spot in the host room (the door's neighbour; the switches are in other rooms since v0.9.5 TS).
func _host_spot(w: World) -> Vector2:
	return w.floor_layout.rooms[w.floor_layout.timed_host].get_center()


func test_either_switch_order_opens_it_and_the_timer_runs_out_and_resets() -> void:
	for order: Array in [[0, 1], [1, 0]]:
		var w := _world()
		assert_not_null(w, "a floor with a timed door")
		if w == null:
			return
		var reader := WorldReader.new(w)
		w.step(InputFrame.new())
		assert_true(_slab_up(w), "shut: the slab stands from the first tick")
		assert_eq(reader.timed_door_state(), WorldReader.TIMED_SHUT)
		assert_eq(reader.hidden_room(), w.floor_layout.timed_room, "the secret room unseen")
		_switch(w, order[0])
		var a := reader.timed_switch_entry(order[0])
		assert_eq(reader.interactable_state(a), 1, "the first switch is on")
		assert_eq(reader.timed_door_state(), WorldReader.TIMED_SHUT, "one switch: still shut")
		w.step(_press())
		assert_eq(reader.interactable_state(a), 1, "a switch that is on takes no press")
		for k in 20:  # the untaken press ages out of the input buffer
			w.step(InputFrame.new())
		_switch(w, order[1])
		assert_eq(reader.timed_door_state(), WorldReader.TIMED_OPEN, "both: open")
		assert_false(_slab_up(w), "the slab is gone")
		assert_eq(reader.timed_opened(), 1)
		assert_eq(reader.hidden_room(), -1, "the room is seen once it opens")
		var t0 := reader.timed_open_tick()
		assert_eq(t0, w.tick - 1, "the timer starts at the second switch")
		assert_eq(reader.timed_timer_ticks(), 1200, "20 s at 60 Hz")
		_put(w, _host_spot(w))
		while reader.timed_door_state() == WorldReader.TIMED_OPEN and w.tick - t0 < 1300:
			w.step(InputFrame.new())
		assert_eq(reader.timed_shut_tick() - t0, 1200, "it shuts when the timer runs out")
		assert_eq(reader.timed_door_state(), WorldReader.TIMED_SHUT)
		assert_true(_slab_up(w), "the slab is back")
		for k in reader.timed_switch_count():
			var e := reader.timed_switch_entry(k)
			assert_eq(reader.interactable_state(e), 0, "switch %d reset" % k)
			assert_true(reader.interactable_enabled(e), "and takes a press again")
		_switch(w, 0)
		_switch(w, 1)
		assert_eq(reader.timed_door_state(), WorldReader.TIMED_OPEN, "no penalty: it opens again")
		assert_eq(reader.timed_opened(), 2)


func test_it_never_shuts_on_the_hero() -> void:
	var w := _world()
	if w == null:
		return
	var reader := WorldReader.new(w)
	var f := w.floor_layout
	w.step(InputFrame.new())
	_switch(w, 0)
	_switch(w, 1)
	var t0 := reader.timed_open_tick()
	_put(w, f.rooms[f.timed_room].get_center())
	while w.tick - t0 < 1260:
		w.step(InputFrame.new())
	assert_eq(
		reader.timed_door_state(), WorldReader.TIMED_HELD, "inside the secret room: held open"
	)
	assert_false(_slab_up(w), "no slab with the hero inside")
	_put(w, f.door_centers[f.timed_door])
	for k in 30:
		w.step(InputFrame.new())
	assert_eq(reader.timed_door_state(), WorldReader.TIMED_HELD, "in the doorway: still open")
	assert_false(_slab_up(w))
	_put(w, _host_spot(w))
	w.step(InputFrame.new())
	assert_eq(reader.timed_door_state(), WorldReader.TIMED_SHUT, "left through it: it shuts")
	assert_true(_slab_up(w))


func test_the_secret_room_holds_its_reward_and_no_spawns() -> void:
	var w := _world()
	if w == null:
		return
	var reader := WorldReader.new(w)
	var f := w.floor_layout
	var i := w.rewards.index_of(w.timed.reward_id)
	assert_gte(i, 0, "the reward is placed")
	assert_eq(f.room_of(w.rewards.pos(i)), f.timed_room, "in the secret room")
	assert_true(reader.reward_hidden(i), "unseen until the door opens")
	if w.timed.reward_epic == 1:
		assert_eq(w.rewards.kind[i], RewardStore.Kind.ALTAR, "an epic altar")
		assert_true(reader.reward_is_epic(i))
	else:
		assert_eq(w.rewards.kind[i], RewardStore.Kind.CHEST, "a chest")
	for q in w.spawn_points:
		assert_ne(f.room_of(q), f.timed_room, "no enemy spawns inside")


func test_puzzle_calm_until_it_opens_or_you_leave() -> void:
	var w := _world()
	if w == null:
		return
	var reader := WorldReader.new(w)
	var f := w.floor_layout
	_put(w, _host_spot(w))
	var steps := 0
	for k in 8:
		w.run_ticks += 1
		steps += Interactables.spawn_clock_step(w)
	assert_true(reader.puzzle_calm(), "calm in the door's host room")
	assert_eq(steps, 2, "the spawn clock at a quarter of the rate")
	_put(w, f.start_pos)
	assert_false(reader.puzzle_calm(), "left the room: normal spawning")
	assert_eq(Interactables.spawn_clock_step(w), 1)
	w.step(InputFrame.new())
	_switch(w, 0)
	_switch(w, 1)
	_put(w, _host_spot(w))
	assert_false(reader.puzzle_calm(), "solved: normal spawning in it from now on")


func test_a_save_mid_timer_resumes_exactly() -> void:
	var w := _world()
	if w == null:
		return
	w.step(InputFrame.new())
	_switch(w, 1)
	_switch(w, 0)
	for k in 120:
		w.step(InputFrame.new())
	var snap := WorldSnapshot.take(w)
	var base := _world()
	assert_eq(WorldSnapshot.apply(base, snap), "", "fits")
	assert_eq(base.state_hash(), w.state_hash(), "same state")
	for k in 1200:
		w.step(InputFrame.new())
		base.step(InputFrame.new())
	assert_eq(base.state_hash(), w.state_hash(), "and runs on the same (the shut included)")
	assert_eq(base.timed.state, TimedDoor.State.SHUT)
	var shut := WorldSnapshot.take(w)
	var base2 := _world()
	assert_eq(WorldSnapshot.apply(base2, shut), "", "a save with the slab back fits")
	assert_eq(base2.state_hash(), w.state_hash())


## Shuts the door on a hero standing inside (a knock-back, a teleport: the only way, as the door holds for the hero).
func _shut_inside(w: World) -> void:
	var f := w.floor_layout
	_switch(w, 0)
	_switch(w, 1)
	_put(w, f.rooms[f.timed_room].get_center())
	w.step(InputFrame.new())
	w.timed.state = TimedDoor.State.SHUT
	for s in w.timed.switches:
		w.interactables.state[s] = 0
		w.interactables.enabled[s] = 1
	w.interactables.enabled[w.timed.lever] = 1
	w.step(InputFrame.new())


func test_the_switches_are_elsewhere_and_the_lever_waits_inside() -> void:
	var w := _world()
	if w == null:
		return
	var f := w.floor_layout
	var reader := WorldReader.new(w)
	assert_eq(f.timed_switch_rooms.size(), 2, "two rooms")
	assert_ne(f.timed_switch_rooms[0], f.timed_switch_rooms[1])
	for r in f.timed_switch_rooms:
		assert_ne(r, f.timed_room, "never the secret room")
		assert_ne(r, f.timed_host, "1-2 steps away, not the host")
	assert_true(
		f.rooms[f.timed_room].has_point(f.timed_lever), "the lever is inside the secret room"
	)
	assert_eq(w.timed.lever_ticks, 300)
	assert_eq(w.interactables.kind[w.timed.lever], Interactables.Kind.TIMED_LEVER)
	assert_eq(reader.timed_lever_entry(), w.timed.lever)


func test_the_lever_inside_reopens_a_shut_door_for_five_seconds_as_often_as_needed() -> void:
	var w := _world()
	if w == null:
		return
	var reader := WorldReader.new(w)
	var f := w.floor_layout
	w.step(InputFrame.new())
	_shut_inside(w)
	assert_true(_slab_up(w), "shut with the hero inside")
	_put(w, f.timed_lever + Vector2(0.3, 0.0))
	w.step(InputFrame.new())
	assert_eq(reader.interact_prompt_key(), &"TIMED_LEVER_PROMPT", "the prompt by the lever")
	for pull in 2:
		w.step(_press())
		assert_eq(reader.timed_door_state(), WorldReader.TIMED_OPEN, "pulled: open")
		assert_false(_slab_up(w), "the slab is gone")
		assert_eq(reader.timed_timer_ticks(), 300, "for 5 s")
		assert_false(
			w.interactables.enabled[w.timed.lever] == 1, "the lever takes no press while open"
		)
		var t0 := reader.timed_open_tick()
		_put(w, f.rooms[f.timed_host].get_center())  # walked out
		while reader.timed_door_state() == WorldReader.TIMED_OPEN and w.tick - t0 < 400:
			w.step(InputFrame.new())
		assert_eq(reader.timed_shut_tick() - t0, 300, "it shuts after 300 ticks")
		assert_true(_slab_up(w))
		assert_true(w.interactables.enabled[w.timed.lever] == 1, "and the lever is ready again")
		_put(w, f.timed_lever + Vector2(0.3, 0.0))
		for k in 20:  # the untaken press ages out of the input buffer
			w.step(InputFrame.new())


func test_the_door_still_holds_while_the_hero_stands_inside_after_a_lever_pull() -> void:
	var w := _world()
	if w == null:
		return
	var f := w.floor_layout
	w.step(InputFrame.new())
	_shut_inside(w)
	_put(w, f.timed_lever + Vector2(0.3, 0.0))
	w.step(InputFrame.new())
	w.step(_press())
	var t0 := w.timed.open_tick
	while w.tick - t0 < 360:
		w.step(InputFrame.new())
	assert_eq(w.timed.state, TimedDoor.State.HELD, "inside when the 5 s end: held open")
	_put(w, f.rooms[f.timed_host].get_center())
	w.step(InputFrame.new())
	assert_eq(w.timed.state, TimedDoor.State.SHUT, "out: it shuts")


func test_a_save_with_the_lever_open_resumes_exactly() -> void:
	var w := _world()
	if w == null:
		return
	var f := w.floor_layout
	w.step(InputFrame.new())
	_shut_inside(w)
	_put(w, f.timed_lever + Vector2(0.3, 0.0))
	w.step(InputFrame.new())
	w.step(_press())
	for k in 100:
		w.step(InputFrame.new())
	var base := _world()
	assert_eq(WorldSnapshot.apply(base, WorldSnapshot.take(w)), "", "fits")
	assert_eq(base.state_hash(), w.state_hash())
	for k in 300:
		w.step(InputFrame.new())
		base.step(InputFrame.new())
	assert_eq(base.state_hash(), w.state_hash())
