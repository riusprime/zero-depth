extends GutTest
## v0.9.0 TD (owner W §2: "Two interactive switches … must be activated. Activating both opens the door … The player
## must reach the entrance before the timer expires. If the player fails, the door closes and the mechanisms reset";
## "No permanent penalty for failure. Reset safely without trapping the player"; Q20: 15 s from the second switch, an
## epic altar or a chest inside; Q22: puzzle calm, a quarter of the rate; Q23: the room unseen until it opens): the
## timed door in the sim (TimedDoor on the shared interactables). Either switch order opens it; the timer is 900 ticks
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


## A spot in the host room away from the door (its centre, or a switch).
func _host_spot(w: World) -> Vector2:
	return w.floor_layout.timed_switches[0] + Vector2(0.3, 0.0)


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
		assert_eq(reader.timed_timer_ticks(), 900, "15 s at 60 Hz")
		_put(w, _host_spot(w))
		while reader.timed_door_state() == WorldReader.TIMED_OPEN and w.tick - t0 < 1000:
			w.step(InputFrame.new())
		assert_eq(reader.timed_shut_tick() - t0, 900, "it shuts when the timer runs out")
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
	while w.tick - t0 < 960:
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
	assert_true(reader.puzzle_calm(), "calm in the switches' room")
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
	for k in 900:
		w.step(InputFrame.new())
		base.step(InputFrame.new())
	assert_eq(base.state_hash(), w.state_hash(), "and runs on the same (the shut included)")
	assert_eq(base.timed.state, TimedDoor.State.SHUT)
	var shut := WorldSnapshot.take(w)
	var base2 := _world()
	assert_eq(WorldSnapshot.apply(base2, shut), "", "a save with the slab back fits")
	assert_eq(base2.state_hash(), w.state_hash())
