extends GutTest
## v0.9.0 CV (owner C20-C22: "Replace it with a short, subtle vibration … without visibly pulling the camera across
## the screen … increase slightly during the buildup and peak at the spawn, then fade out naturally"; Q17: the
## arrival, the boss door and the final-boss travel): IsoRig's vibration stays within VIBRATE_M × its level on each
## axis, averages to nothing (no direction), fades by itself, and is off with shake off or reduced motion.

const DT := 1.0 / 60.0


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _rig() -> IsoRig:
	var rig := IsoRig.new()
	autofree(rig)
	return rig


func test_a_held_vibration_is_small_and_has_no_direction() -> void:
	var rig := _rig()
	var sum := Vector2.ZERO
	var top := 0.0
	var frames := 240
	for k in frames:
		rig.vibrate_to(1.0)
		rig._process(DT)
		var off := Vector2(rig.camera.h_offset, rig.camera.v_offset)
		top = maxf(top, maxf(absf(off.x), absf(off.y)))
		sum += off
	assert_gt(top, IsoRig.VIBRATE_M * 0.5, "it moves")
	assert_lte(top, IsoRig.VIBRATE_M + 1e-5, "but only a few centimetres")
	var mean := sum / frames
	assert_lt(mean.length(), IsoRig.VIBRATE_M * 0.1, "no pull to one side: it averages out")


func test_a_thud_peaks_then_fades_out() -> void:
	var rig := _rig()
	rig.thud(0.9)
	assert_almost_eq(rig.vibration_level(), 0.9, 1e-5)
	var last := rig.vibration_level()
	for k in 30:
		rig._process(DT)
		assert_lte(rig.vibration_level(), last, "it only eases out")
		last = rig.vibration_level()
	for k in 60:
		rig._process(DT)
	assert_eq(rig.vibration_level(), 0.0, "gone within a second and a half")
	assert_eq(rig.vibration_offset(), Vector2.ZERO)


func test_off_with_shake_off_or_reduced_motion() -> void:
	var rig := _rig()
	rig.shake_enabled = false
	rig.thud(1.0)
	rig.vibrate_to(1.0)
	assert_eq(rig.vibration_level(), 0.0, "shake off: none")
	rig.shake_enabled = true
	ViewPrefs.reduced_motion = true
	rig.thud(1.0)
	rig.vibrate_to(1.0)
	assert_eq(rig.vibration_level(), 0.0, "reduced motion: none")
