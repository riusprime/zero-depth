extends GutTest
## v0.9.0 SA (owner C §2, Q16): the altar scene (AltarStage), its stand-in and its timeline, read from the progress
## alone: the stand-in is a round stepped dais about 6.6 m across with 3-4 steps, 8-12 floating runes and 6-8 jewels as
## separate objects; idle shows an empty altar; the runes light one after another before they orbit; the orbit speeds
## up to the pop and slows in the release; the buildup peaks at the pop and is gone by the end; reduced motion lights
## the runes without moving them. The final altar (FA) is the same scene in purple, its runes lit by share.

var _reduced := false


func before_each() -> void:
	_reduced = ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = false


func after_each() -> void:
	ViewPrefs.reduced_motion = _reduced


func _altar(look: AltarStage.Look = null) -> AltarStage:
	var a := AltarStage.new(look if look != null else AltarStage.arrival())
	add_child_autofree(a)
	a.setup(Vector2.ZERO)
	return a


func test_the_stand_in_is_a_big_round_stepped_dais() -> void:
	ShopModels.manifest = "res://no_such_manifest.json"  # v0.9.0 MI2: the owner's altar is listed; the fallback
	ShopModels.clear_cache()
	var a := _altar()
	ShopModels.manifest = ShopModels.MANIFEST
	ShopModels.clear_cache()
	assert_false(a.uses_model, "without the manifest: the stand-in")
	var steps := a.body.find_children("Step*", "MeshInstance3D", true, false)
	assert_between(steps.size(), 3, 4, "three or four steps")
	var bottom := steps[0] as MeshInstance3D  # the widest, laid unturned
	var box := bottom.get_aabb()
	box.size.y = (steps[steps.size() - 1] as MeshInstance3D).position.y + AltarStage.STEP_H * 0.5
	for k in range(1, steps.size()):
		var r := (steps[k] as MeshInstance3D).get_aabb().size.x
		assert_lt(r, (steps[k - 1] as MeshInstance3D).get_aabb().size.x, "step %d is narrower" % k)
	assert_almost_eq(box.size.x, 6.6, 0.25, "about 6.6 m across (%.2f)" % box.size.x)
	assert_almost_eq(box.size.x, box.size.z, 0.2, "round")
	assert_lt(box.size.y, 0.5, "low: the hero walks over it (%.2f m)" % box.size.y)
	assert_between(a.runes.size(), 8, 12, "floating runes")
	assert_between(a.jewels.size(), 6, 8, "jewels")
	assert_eq(a.panels.size(), AltarStage.PANELS, "carved rune panels")
	for r in a.runes:
		assert_eq(r.get_parent(), a.ring, "each rune its own object on the orbit ring")


func test_idle_is_an_empty_altar() -> void:
	var a := _altar()
	a.pose(0.0)
	for i in a.runes.size():
		assert_false(a.runes[i].visible, "rune %d unlit" % i)
	assert_eq(a.energy, 0.0)
	assert_false(a.swirl.visible)
	assert_false(a.motes.emitting)


func test_the_runes_light_in_sequence_before_they_orbit() -> void:
	var a := _altar()
	var l := a.look
	assert_lt(l.light_from, l.orbit_from, "lighting starts before the orbit")
	var lit_at: Array[float] = []
	for i in a.runes.size():
		lit_at.append(-1.0)
	for k in 241:
		var p := k / 240.0
		a.pose(p)
		for i in a.runes.size():
			if lit_at[i] < 0.0 and a.rune_glow_now(i) > 0.5:
				lit_at[i] = p
		if p < l.orbit_from:
			assert_eq(a.angle, 0.0, "no orbit before orbit_from (%.2f)" % p)
	for i in range(1, a.runes.size()):
		assert_gt(lit_at[i], lit_at[i - 1], "rune %d lights after rune %d" % [i, i - 1])
	assert_lt(lit_at[0], l.orbit_from, "the first rune lights before the orbit")
	for j in a.jewels.size():
		a.pose(l.light_to + 0.05)
		assert_gt(a.jewel_glow_now(j), 0.5, "jewel %d lit" % j)


func test_the_orbit_speeds_up_to_the_pop_then_slows() -> void:
	var a := _altar()
	var l := a.look
	var steps: Array[float] = []
	var last := 0.0
	for k in 241:
		a.pose(k / 240.0)
		steps.append(a.angle - last)
		last = a.angle
	var pop := int(l.pop_at * 240.0)
	var start := int(l.orbit_from * 240.0) + 2
	for k in range(start + 1, pop):
		assert_gte(steps[k], steps[k - 1] - 1e-6, "faster at %d" % k)
	for k in range(pop + 2, 241):
		assert_lte(steps[k], steps[k - 1] + 1e-6, "slower at %d" % k)
	assert_almost_eq(a.angle, TAU * l.orbit_turns, 0.001, "the whole orbit made")


func test_the_buildup_peaks_at_the_pop_and_dissipates() -> void:
	var a := _altar()
	var l := a.look
	a.pose(l.buildup_from - 0.01)
	assert_eq(a.energy, 0.0, "no buildup before buildup_from")
	a.pose(l.pop_at)
	var peak := a.energy
	assert_almost_eq(peak, 1.0, 0.01, "peak at the pop")
	assert_true(a.swirl.visible, "the centre swirl")
	assert_true(a.motes.emitting, "the particles")
	assert_gt(a.light.light_energy, 5.0, "the glow")
	a.pose(1.0)
	assert_eq(a.energy, 0.0, "gone by the end")
	assert_lt(a.rune_glow_now(0), 0.5, "the runes settle dim")
	a.pose(-1.0)
	assert_almost_eq(a.rune_glow_now(0), AltarStage.REST_GLOW, 0.001, "woken: they rest dimly lit")
	assert_false(a.motes.emitting)


func test_the_burst_runs_and_ends() -> void:
	var a := _altar()
	a.set_burst(0.3)
	assert_true(a.shock.visible)
	assert_gt(a.shock.scale.x, 1.0, "it runs out")
	a.set_burst(1.0)
	assert_false(a.shock.visible)


func test_reduced_motion_lights_the_runes_without_moving_them() -> void:
	ViewPrefs.reduced_motion = true
	var a := _altar()
	assert_true(a.calm)
	for k in 19:
		a.pose(k / 18.0)
		assert_eq(a.angle, 0.0, "no orbit")
		assert_false(a.motes.emitting, "no particles")
	a.pose(0.5)
	for i in a.runes.size():
		assert_gt(a.rune_glow_now(i), 0.5, "rune %d lit" % i)


## v0.9.0 MI2: the owner's altar (delivered 2026-10-22) is drawn: his stone in its 6.6 x 0.45 m box, a code jewel in
## each of his six sockets, the floating runes still code objects; on the final approach his stone is tinted purple.
func test_the_owners_altar_holds_the_code_jewels_and_runes() -> void:
	var a := _altar()
	assert_true(a.uses_model, "arrival_altar is listed")
	var model := a.body.find_child("Model", false, false) as MeshInstance3D
	assert_not_null(model)
	var box := model.get_aabb()
	assert_almost_eq(box.size.x, 6.6, 0.05, "6.6 m across")
	assert_almost_eq(box.size.y, AltarStage.MODEL_TOP, 0.02, "low")
	assert_eq(a.jewels.size(), AltarStage.MODEL_SOCKETS.size(), "a jewel per socket")
	for j in a.jewels.size():
		var p := a.jewels[j].position
		assert_almost_eq(Vector2(p.x, p.z).length(), AltarStage.MODEL_SOCKET_R, 0.01)
	assert_between(a.runes.size(), 8, 12, "floating runes")
	assert_eq(a.panels.size(), 0, "his carved panels, no code ones")
	var f := _altar(AltarStage.final())
	var fm := f.body.find_child("Model", false, false) as MeshInstance3D
	var mat := fm.get_surface_override_material(0) as StandardMaterial3D
	assert_eq(mat.albedo_color, AltarStage.final().model_tint, "purple stone on the approach")
	assert_gt(mat.albedo_color.b, mat.albedo_color.g)


func test_the_final_altar_is_the_same_scene_in_purple() -> void:
	var a := _altar(AltarStage.final())
	assert_eq(a.look.color, AltarStage.VIOLET)
	assert_gt(a.look.color.b, a.look.color.g, "purple, not blue")
	assert_ne(a.look.cue, AltarStage.arrival().cue, "its own sound")
	a.pose(-1.0, 0.5)
	var lit := 0
	for i in a.runes.size():
		if a.rune_glow_now(i) > 0.5:
			lit += 1
	assert_eq(lit, a.runes.size() / 2, "the first pylon lights half its runes")
	a.pose(-1.0, 1.0)
	for i in a.runes.size():
		assert_gt(a.rune_glow_now(i), 0.5, "both pylons: every rune")
	a.pose(0.3, 1.0)
	assert_gt(a.angle, 0.0, "the buildup sets them spinning")


func test_no_loose_decoration_on_the_altar() -> void:
	var near := {"kind": &"decor", "xform": Transform3D(Basis(), SimPlane.to_3d(Vector2(1, 1)))}
	var far := {"kind": &"decor", "xform": Transform3D(Basis(), SimPlane.to_3d(Vector2(6, 0)))}
	var cover := {"kind": &"cover", "xform": Transform3D(Basis(), SimPlane.to_3d(Vector2(1, 0)))}
	var out := AltarStage.clear_decor([near, far, cover], Vector2.ZERO, AltarStage.RADIUS)
	assert_eq(out, [far, cover], "the decoration on it goes; the rest stays")
	assert_eq(AltarStage.clear_decor([near], Vector2.ZERO, 0.0), [near], "no altar: untouched")
