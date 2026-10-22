extends GutTest
## v0.9.0 FA (owner C §3: "Purple replaces blue … Activation mechanisms must provide obvious visual feedback"; Q18;
## Q17): the final approach's view (FinalApproachView) posed from the sim alone. The altar is SA's AltarStage in purple;
## each pylon locks in when the sim switches it on (lit rune and crystal, a light) and lights its share of the altar's
## runes; the buildup spins them with the vibration climbing; when the sim's walls rise they are drawn, the camera
## thuds and the pylons sink; reduced motion keeps the lighting without the motion. The arena stage draws the stair
## causeway with no pillar or brazier in its gap. Presentation only (EI-07).

const SEED := 20261022

var _reduced := false


func before_each() -> void:
	_reduced = ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = false


func after_each() -> void:
	ViewPrefs.reduced_motion = _reduced


func _press() -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 1000, InputFrame.INTERACT, InputFrame.INTERACT)


func _view(w: World) -> Array:
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var v := FinalApproachView.new()
	add_child_autofree(v)
	v.setup(WorldReader.new(w), rig)
	return [v, rig]


## Puts the hero by pylon k (a test: the walk is the sim's own test) and presses.
func _switch(w: World, k: int) -> void:
	w.actors.set_pos(0, w.floor_layout.pylons[k])
	w.step(_press())


func test_the_pylons_lock_in_and_light_the_purple_altar() -> void:
	var w := FinalLab.approach(FinalLab.run_state(SEED))
	CombatLab.idle(w, 60)  # past the arrival
	var reader := WorldReader.new(w)
	var got := _view(w)
	var v: FinalApproachView = got[0]
	assert_eq(v.altar.look.color, AltarStage.VIOLET, "purple")
	assert_eq(
		v.altar.position, SimPlane.to_3d(reader.approach_altar_pos()), "at the plateau's centre"
	)
	assert_eq(v.pylons.size(), 2)
	for k in 2:
		assert_false(v.locked[k], "dark at first")
	for i in v.altar.runes.size():
		assert_eq(v.altar.rune_glow_now(i), 0.0, "the altar idle")
	_switch(w, 0)
	v.sync(reader)
	assert_true(v.locked[0], "pylon A locked in")
	assert_false(v.locked[1])
	var lit := 0
	for i in v.altar.runes.size():
		lit += 1 if v.altar.rune_glow_now(i) > 0.5 else 0
	assert_eq(lit, v.altar.runes.size() / 2, "its share of the runes")
	assert_eq(v.altar.angle, 0.0, "not spinning yet")
	_switch(w, 1)
	var rig: IsoRig = got[1]
	var vib := 0.0
	for k in FinalApproach.BUILDUP_TICKS - 5:
		w.step(InputFrame.new())
		v.sync(reader)
		vib = maxf(vib, rig.vibration_level())
	assert_gt(v.altar.angle, 0.0, "the second sets them spinning")
	assert_gt(v.altar.energy, 0.5, "the buildup")
	assert_gt(vib, FinalApproachView.BUILD_LOW, "the vibration climbs")
	assert_false(v.walls_up)
	for w8 in v.walls:
		assert_false(w8.visible, "no walls yet")
	CombatLab.idle(w, 10)
	v.sync(reader)
	assert_true(v.walls_up, "the walls rose")
	for w8 in v.walls:
		assert_true(w8.visible)
	assert_eq(v.walls.size(), reader.approach_light_wall_count())
	assert_gt(rig.vibration_level(), vib * 0.9, "a thud as they rise")


func test_reduced_motion_lights_without_motion() -> void:
	ViewPrefs.reduced_motion = true
	var w := FinalLab.approach(FinalLab.run_state(SEED))
	CombatLab.idle(w, 60)
	var reader := WorldReader.new(w)
	var got := _view(w)
	var v: FinalApproachView = got[0]
	var rig: IsoRig = got[1]
	_switch(w, 0)
	_switch(w, 1)
	for k in FinalApproach.BUILDUP_TICKS + 5:
		w.step(InputFrame.new())
		v.sync(reader)
		assert_eq(rig.vibration_level(), 0.0, "no vibration")
		assert_eq(v.altar.angle, 0.0, "no spin")
	assert_true(v.locked[0] and v.locked[1], "both lit")
	assert_true(v.walls_up)
	for w8 in v.walls:
		assert_eq(w8.scale.y, 1.0, "no rise: they stand")


func test_the_stage_draws_the_causeway_with_its_gap_clear() -> void:
	var w := FinalLab.approach(FinalLab.run_state(SEED))
	var reader := WorldReader.new(w)
	var repo := ContentRepository.load_all()
	var def: FinalArenaDefinition = repo.get_def(&"final_arena", &"hollow_arena")
	var stage := FinalArenaStage.new()
	add_child_autofree(stage)
	stage.build(reader, def.palette, reader.final_arena_radius(), reader.seed_value())
	assert_eq(stage.treads.size(), FinalArenaStage.CAUSEWAY_STEPS, "the stair treads")
	var top := SimPlane.to_3d(reader.approach_causeway_top())
	var gap := atan2(top.z, top.x)
	for n in stage.get_children():
		if n.name.begins_with("Pillar") or n.name.begins_with("Brazier"):
			var p := (n as Node3D).position
			var a := atan2(p.z, p.x)
			assert_gt(
				absf(wrapf(a - gap, -PI, PI)),
				FinalArenaStage.GAP_CLEAR,
				"%s clear of the gap" % n.name
			)
	var bare := FinalLab.arena(FinalLab.run_state(SEED))
	var ring := FinalArenaStage.new()
	add_child_autofree(ring)
	var rb := WorldReader.new(bare)
	ring.build(rb, def.palette, rb.final_arena_radius(), rb.seed_value())
	assert_eq(ring.treads.size(), 0, "the ring arena (direct path) has no causeway")
