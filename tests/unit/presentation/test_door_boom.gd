extends GutTest
## v0.9.0 DS (owner C35: "the large impact or boom … is slightly late … move it a bit earlier"; Q19: "0.3 s earlier"):
## `boss_door_impact` starts AudioEvents.DOOR_IMPACT_LEAD_TICKS before the slab touches down, so the file's peak
## (about 0.3 s in) lands on the touchdown. It plays once, and nothing in the sim moves.


func _world() -> World:
	var lab := RunLab.new(ContentRepository.load_all(), 8311, &"blade")
	lab.run.floor_rules = RunState.FLOOR_RULES
	return lab.floor_world()


func _press(w: World) -> void:
	w.step(InputFrame.new())
	w.actors.set_pos(0, w.floor_layout.boss_door_outside(0.8))
	w.vel = Vector2.ZERO
	var f := InputFrame.new()
	f.pressed = InputFrame.INTERACT
	w.step(f)


func _impacts(cues: Array) -> int:
	var n := 0
	for c in cues:
		if c[0] == &"boss_door_impact":
			n += 1
	return n


func test_the_boom_starts_eighteen_ticks_before_the_slab_lands() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var a := AudioEvents.new()
	a.prime(r)
	_press(w)
	assert_eq(w.boss_flow.door, BossFlow.Door.OPENING, "the press started the opening")
	var at := -1.0
	var total := 0
	for k in BossFlow.DOOR_OPEN_TICKS + 10:
		w.step(InputFrame.new())
		var n := _impacts(a.collect(r))
		if n > 0 and at < 0.0:
			at = r.boss_door_progress() * BossFlow.DOOR_OPEN_TICKS
		total += n
	assert_eq(total, 1, "the impact plays once")
	assert_almost_eq(
		at,
		float(BossFlow.DOOR_OPEN_TICKS - AudioEvents.DOOR_IMPACT_LEAD_TICKS),
		0.01,
		"it starts 18 ticks (0.3 s) before the slab is down"
	)


func test_a_door_never_pressed_stays_silent() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var a := AudioEvents.new()
	a.prime(r)
	var total := 0
	for k in 60:
		w.step(InputFrame.new())
		total += _impacts(a.collect(r))
	assert_eq(total, 0)
