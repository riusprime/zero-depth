extends GutTest
## v0.3.0 L11: the four slashes as the view draws them. Each step's blade moves its own way through the step's
## own arc (the shape PlayerKit hits with), the wanderer's body follows (twist, lean, spin), and the finisher hits
## harder on screen (a longer flash, a spark, a camera shake that the shake option turns off).


## A world whose next press starts combo step `step` (aim 0), with no enemies.
func _world_at(step: int) -> World:
	var w := World.new(3, PlayerTable.starting_values())
	for i in step:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
		while w.swing_t > 0:
			w.step(InputFrame.new())
	return w


## Swings the next step and records the blade every tick while it is lit: [yaw, offset, energy, tip].
func _blade_track(step: int) -> Array:
	var w := _world_at(step)
	var reader := WorldReader.new(w)
	var kit: KitView = add_child_autofree(KitView.new())
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	assert_eq(reader.combo_step(), step)
	var out := []
	while reader.swing_tick() > 0:
		kit.sync(reader)
		out.append(
			[
				kit.blade_yaw(),
				kit.blade_offset(),
				kit.blade_energy(),
				kit.blade_tip_m(),
				kit.motion()
			]
		)
		w.step(InputFrame.new())
	return out


func test_each_step_draws_its_own_motion() -> void:
	var motions := []
	for step in 4:
		motions.append(_blade_track(step)[0][4])
	assert_eq(
		motions,
		[
			WorldReader.MOTION_SLASH_RIGHT_TO_LEFT,
			WorldReader.MOTION_SLASH_LEFT_TO_RIGHT,
			WorldReader.MOTION_THRUST,
			WorldReader.MOTION_SPIN,
		]
	)


func test_the_slashes_sweep_the_steps_arc_in_opposite_directions() -> void:
	var half := TAU * PlayerTable.starting_values().step(0).half_arc / 4096.0
	var one := _blade_track(0)
	var two := _blade_track(1)
	assert_almost_eq(one[0][0], -half, 0.001, "step 1 starts on the right")
	assert_almost_eq(one[one.size() - 1][0], half, 0.001, "and ends on the left")
	assert_almost_eq(two[0][0], half, 0.001, "step 2 starts on the left")
	assert_almost_eq(two[two.size() - 1][0], -half, 0.001, "and ends on the right")
	for k in range(1, one.size()):
		assert_gte(one[k][0], one[k - 1][0] - 1e-6, "step 1 only moves right to left")
		assert_lte(two[k][0], two[k - 1][0] + 1e-6, "step 2 only moves left to right")


func test_the_thrust_stabs_straight_out_to_the_steps_reach() -> void:
	var t := PlayerTable.starting_values()
	var track := _blade_track(2)
	for s: Array in track:
		assert_almost_eq(s[0], 0.0, 0.0001, "held on the aim")
	assert_gt(track[0][1], 0.3, "it starts pulled back")
	assert_almost_eq(track[track.size() - 1][1], 0.0, 0.0001, "and ends at full stab")
	assert_almost_eq(
		track[0][3],
		t.radius_m + t.step(2).reach_m,
		0.0001,
		"its tip at full stab is the thrust's reach"
	)


func test_the_finisher_spins_once_bright_and_flares_on_the_hit() -> void:
	var t := PlayerTable.starting_values()
	var spin := _blade_track(3)
	var slash := _blade_track(0)
	assert_almost_eq(spin[spin.size() - 1][0], TAU, 0.001, "one full turn")
	assert_almost_eq(spin[0][3], t.radius_m + t.step(3).reach_m, 0.0001, "at the spin's reach")
	var active := t.step(3).active_tick
	assert_gt(spin[active - 1][2], spin[active - 2][2], "it flares when it hits")
	assert_gt(spin[0][2], slash[0][2], "brighter than a slash")


func test_the_spin_keeps_its_whole_turn_as_a_trail() -> void:
	var w := _world_at(3)
	var reader := WorldReader.new(w)
	var kit: KitView = add_child_autofree(KitView.new())
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	for k in 10:
		kit.sync(reader)
		w.step(InputFrame.new())
	assert_gte(kit.trail_samples(), PlayerTable.starting_values().step(3).sweep_ticks)


func test_the_echo_flash_uses_the_echoed_steps_shape() -> void:
	var t := PlayerTable.starting_values()
	var w := _world_at(0)
	var r := WorldReader.new(w)
	for k in 4:
		assert_eq(r.swing_shape(k), [t.step(k).half_arc, t.step(k).reach_m, t.radius_m])


# --- The wanderer's body ------------------------------------------------------------------------------------
func _avatar() -> PlayerAvatar:
	var a := PlayerAvatar.new()
	a.setup(Color("#1A1A22"))
	add_child_autofree(a)
	a.set_process(false)
	return a


## Drives the avatar through a swing of combo step `step` and returns its [body_yaw, spin, stab] per tick.
func _body_track(step: int) -> Array:
	var w := _world_at(step)
	var reader := WorldReader.new(w)
	var a := _avatar()
	a.sync(reader)
	a.advance(1.0 / 60.0)
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	var out := []
	while reader.swing_tick() > 0:
		a.sync(reader)
		a.advance(1.0 / 60.0)
		out.append([a.body_yaw(), a.spin_amount(), a.stab_amount()])
		w.step(InputFrame.new())
	return out


func _max(track: Array, field: int) -> float:
	var m := -INF
	for s: Array in track:
		m = maxf(m, s[field])
	return m


func _min(track: Array, field: int) -> float:
	var m := INF
	for s: Array in track:
		m = minf(m, s[field])
	return m


func test_the_body_twists_one_way_then_the_other() -> void:
	var one := _body_track(0)
	var two := _body_track(1)
	assert_lt(_min(one, 0), -0.2, "the slash winds back to the right")
	assert_gt(two[0][0], 0.2, "the backhand winds back to the left")
	assert_lt(_min(two, 0), -0.1, "and whips through to the right")
	assert_eq(_max(one, 1), 0.0, "no spin on a slash")


func test_the_thrust_leans_in_and_the_finisher_spins() -> void:
	var thrust := _body_track(2)
	assert_gt(_max(thrust, 2), 0.5, "the thrust leans into the stab")
	var fin := _body_track(3)
	assert_gt(_max(fin, 1), TAU * 0.9, "the finisher turns the whole wanderer once")
	assert_gt(_max(fin, 2), 0.2, "leaning into its lunge")


# --- Hit feel -------------------------------------------------------------------------------------------------
func _feel_on_finisher(shake_on: bool) -> Array:
	var w := _world_at(3)
	var id := w.add_dummy(w.player_pos() + Vector2(1.5, 0), 0.35, 999)
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	rig.shake_enabled = shake_on
	var feel := HitFeel.new(views, rig)
	add_child_autofree(feel)
	views.sync(reader)
	feel.sync(reader)
	var finisher_hits := 0
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	var after := w.last_event_seq()
	while reader.swing_tick() > 0:
		w.step(InputFrame.new())
		for e in reader.events_since(after):
			after = e.seq
			if HitFeel.finisher_hit(reader, e):
				finisher_hits += 1
		views.sync(reader)
		feel.sync(reader)
		if finisher_hits > 0:
			break
	return [finisher_hits, rig.shake_level(), views.is_flashing(id)]


func test_the_finisher_shakes_the_camera_and_flashes_its_target() -> void:
	var on := _feel_on_finisher(true)
	assert_eq(on[0], 1, "the spin's hit is read as the finisher's")
	assert_gt(on[1], 0.0, "the camera shakes")
	assert_true(on[2], "the target flashes")
	var off := _feel_on_finisher(false)
	assert_eq(off[1], 0.0, "shake off means none at all")
	assert_true(off[2], "the flash stays")


func test_a_slash_does_not_shake_the_camera() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	w.add_dummy(Vector2(1.2, 0), 0.35, 999)
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var feel := HitFeel.new(views, rig)
	add_child_autofree(feel)
	views.sync(reader)
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, 0, InputFrame.PRIMARY))
	while reader.swing_tick() > 0:
		w.step(InputFrame.new())
		views.sync(reader)
		feel.sync(reader)
	assert_eq(rig.shake_level(), 0.0)
