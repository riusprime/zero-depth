extends GutTest
## The Gravity Node on the owner's model (GravityNodeAvatar): its parts load into their joints, each clip moves the
## parts it should (the hover with its rings turning, the pull, the turn, a hit, the rise-in, the death), reduced
## motion moves less and never swings or speeds the rings up, a missing model falls back to the code-made body that
## plays the same clips, and the VAT bake matches the live pose (a VAT avatar keeps the same drives, lift and glows
## through a fight).

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_GRAVITY_NODE
const G := preload("res://src/presentation/world_view/gravity_node_avatar.gd")

var _calm := false
var _vat := false


func before_each() -> void:
	_calm = ViewPrefs.reduced_motion
	_vat = ViewPrefs.enemy_vat
	ViewPrefs.reduced_motion = false
	VatBake.clear_cache()


func after_each() -> void:
	ViewPrefs.reduced_motion = _calm
	ViewPrefs.enemy_vat = _vat
	EnemyModels.dir = EnemyModels.DIR
	EnemyModels.clear_cache()


## A node under a facing node (the one ActorViews turns), its own processing off.
func _orb() -> GravityNodeAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := GravityNodeAvatar.new()
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## `n` ticks of a state: apply_state then a frame; the facing turns by `turn` (radians) a tick.
func _run(a: GravityNodeAvatar, n: int, s: Dictionary, turn := 0.0) -> void:
	for k in n:
		(a.get_parent() as Node3D).rotation.y += turn
		a.apply_state(s)
		a.advance(DT)


func _hover(draw := 0.0, hp := 50) -> Dictionary:
	return {"state": WorldReader.STATE_MOVE, "draw": draw, "hp": hp}


## How far ring `k` turned (radians, signed) over `n` ticks of `s`.
func _turned(a: GravityNodeAvatar, k: int, n: int, s: Dictionary) -> float:
	var spin := G.RING0 + 4 * k + G.SPIN
	var total := 0.0
	for j in n:
		var before := a.drives()[spin]
		_run(a, 1, s)
		total += wrapf(a.drives()[spin] - before, -PI, PI)
	return total


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	assert_true(EnemyModels.has_model(&"gravity_node"), "the model file is installed")
	var a := _orb()
	assert_true(a.has_model)
	assert_eq(a.rings.size(), 2, "the level pair and the upright ring")
	var meshes := a.find_children("*", "MeshInstance3D", true, false)
	assert_eq(
		meshes.size(), 7, "the face plate, the core, two halves, two rings and the ground disc"
	)
	for n: Node3D in [a.core, a.shell_u, a.shell_l, a.rings[0], a.rings[1]]:
		assert_eq(n.get_parent(), a.rig, "%s hangs on the body" % n.name)
		assert_eq(n.get_child_count(), 1, "%s holds its part" % n.name)
	var visor := 0
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null or mi == a.shadow:
			continue
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as StandardMaterial3D
			if m != null and m.has_meta(SoloVat.GLOW):
				visor += 1
				assert_eq(String(mi.name), "body", "the gem is on the face plate")
	assert_eq(visor, 1, "the gem visor")
	var core_mi := a.core.get_child(0) as MeshInstance3D
	var cm := core_mi.get_surface_override_material(0) as StandardMaterial3D
	assert_true(cm.emission_enabled and not cm in a.body_materials, "the core glows")
	assert_eq(a.body_materials.size(), 2, "the base and the role plates take the flash")
	var ring_box := (a.rings[0].get_child(0) as MeshInstance3D).get_aabb()
	assert_gt(ring_box.size.x, 0.6, "a ring spans the orb: %s" % ring_box)


func test_it_hovers_its_rings_turning_each_way_and_the_halves_breathing() -> void:
	var a := _orb()
	_run(a, 30, _hover())
	var lift := [99.0, -99.0]
	var crack := [99.0, -99.0]
	for k in 180:
		_run(a, 1, _hover())
		lift[0] = minf(lift[0], a.vat_lift())
		lift[1] = maxf(lift[1], a.vat_lift())
		crack[0] = minf(crack[0], a.drives()[G.UP_LIFT])
		crack[1] = maxf(crack[1], a.drives()[G.UP_LIFT])
	assert_almost_eq((lift[0] + lift[1]) * 0.5, G.HOVER_LIFT, 0.03, "it hovers: %s" % [lift])
	assert_gt(lift[1] - lift[0], 0.07, "and bobs")
	assert_gt(crack[1] - crack[0], 0.008, "the halves breathe open a crack: %s" % [crack])
	var ta := _turned(a, 0, 60, _hover())
	var tb := _turned(a, 1, 60, _hover())
	assert_gt(ta, 0.8, "the level pair turns one way: %.2f" % ta)
	assert_lt(tb, -0.8, "the upright ring the other: %.2f" % tb)
	var r0 := a.rings[0].transform
	_run(a, 10, _hover())
	assert_ne(a.rings[0].transform, r0, "the ring node follows its drives")


func test_the_pull_spins_the_rings_up_tightens_them_and_parts_the_halves() -> void:
	var a := _orb()
	_run(a, 30, _hover())
	var rest_spin := absf(_turned(a, 1, 30, _hover()))
	var rest_glow := a.core_energy()
	_run(a, 90, _hover(1.0))
	assert_almost_eq(a.draw_pose(), 1.0, 0.01, "the draw shown")
	var pull_spin := absf(_turned(a, 1, 30, _hover(1.0)))
	assert_gt(
		pull_spin, rest_spin * 2.0, "the rings spin faster: %.2f, %.2f" % [rest_spin, pull_spin]
	)
	for k in 2:
		assert_lt(a.drives()[G.RING0 + 4 * k + G.SIZE], -0.1, "ring %d tightens" % k)
	assert_gt(a.drives()[G.UP_LIFT], 0.06, "the upper half lifts")
	assert_gt(a.drives()[G.UP_TILT], 0.3, "and opens")
	assert_gt(a.drives()[G.LOW_DROP], 0.04, "the lower half drops")
	var glow := 0.0
	var sink := 0.0
	for k in 60:
		_run(a, 1, _hover(1.0))
		glow = maxf(glow, a.core_energy())
		sink = minf(sink, a.drives()[G.CORE])
	assert_gt(glow, rest_glow + 1.2, "the core glows and flashes with its beats")
	assert_lt(sink, -0.05, "the core beats inward")
	_run(a, 120, _hover())
	assert_almost_eq(a.drives()[G.RING0 + G.SIZE], 0.0, 0.01, "the hero gone, the rings loosen")


func test_turning_toward_the_hero_trails_the_body_and_tips_the_rings() -> void:
	var calm := _orb()
	var turned := _orb()
	_run(calm, 30, _hover())
	_run(turned, 30, _hover())
	_run(calm, 12, _hover())
	_run(turned, 12, _hover(), 2.0 / 60.0)
	var d0 := calm.drives()
	var d1 := turned.drives()
	assert_lt(d1[G.YAW], d0[G.YAW] - 0.1, "the body trails the turn")
	assert_gt(absf(d1[G.RING0 + G.TIP] - d0[G.RING0 + G.TIP]), 0.1, "the rings tip with it")


func test_a_hit_wobbles_it_and_knocks_the_rings_off_axis_settling_back() -> void:
	var calm := _orb()
	var hit := _orb()
	_run(calm, 30, _hover())
	_run(hit, 30, _hover())
	_run(calm, 6, _hover())
	_run(hit, 6, _hover(0.0, 40))
	var d0 := calm.drives()
	var d1 := hit.drives()
	assert_gt(absf(d1[G.ROLL] - d0[G.ROLL]), 0.1, "it rolls")
	assert_gt(absf(d1[G.RING0 + G.TIP] - d0[G.RING0 + G.TIP]), 0.2, "the level pair knocked")
	assert_gt(absf(d1[G.RING0 + 4 + G.TIP] - d0[G.RING0 + 4 + G.TIP]), 0.2, "the upright one too")
	assert_gt(hit.core_energy(), calm.core_energy() + 0.5, "the core flashes")
	# It swings back past its rest before it settles (damped swings).
	var sides := {}
	for k in 50:
		_run(calm, 1, _hover())
		_run(hit, 1, _hover(0.0, 40))
		var off := hit.drives()[G.RING0 + G.TIP] - calm.drives()[G.RING0 + G.TIP]
		if absf(off) > 0.03:
			sides[signf(off)] = true
	assert_eq(sides.size(), 2, "the ring swings back and forth")
	_run(calm, 30, _hover())
	_run(hit, 30, _hover(0.0, 40))
	assert_almost_eq(hit.drives()[G.ROLL], calm.drives()[G.ROLL], 0.01, "settled")


func test_it_rises_in_from_the_ground_its_rings_unfolding() -> void:
	var a := _orb()
	a.apply_state({"state": WorldReader.STATE_SPAWN, "hp": 50})
	a.advance(DT)
	assert_lt(a.vat_lift(), 0.25, "near the ground")
	assert_lt(a.drives()[G.RING0 + G.SIZE], -0.2, "its rings folded tight")
	assert_lt(a.visor_energy(), G.VISOR_REST, "its gem dim")
	_run(a, 150, _hover())
	assert_almost_eq(a.vat_lift(), G.HOVER_LIFT, 0.06, "risen to its hover")
	assert_gt(a.drives()[G.RING0 + G.SIZE], -0.02, "its rings open")


func test_the_death_splits_it_flings_the_rings_and_drops_it() -> void:
	var a := _orb()
	_run(a, 30, _hover(0.5, 10))
	assert_true(a.die())
	assert_true(a.dying())
	var flare := 0.0
	var highest := 0.0
	for k in int(G.DEATH_SECONDS / DT):
		a.advance(DT)
		flare = maxf(flare, a.core_energy())
		highest = maxf(highest, a.drives()[G.UP_LIFT])
	assert_gt(flare, 2.5, "the core flares")
	assert_gt(highest, 0.12, "the upper half thrown off")
	for k in 2:
		assert_almost_eq(a.drives()[G.RING0 + 4 * k + G.FLY], 1.0, 0.001, "ring %d flew off" % k)
	assert_lt(a.vat_lift(), 0.1, "dropped to the ground: %.3f" % a.vat_lift())
	assert_gt(a.drives()[G.ROLL], 0.3, "rolled onto its side")
	assert_lt(a.core_energy(), 0.2, "the core out")
	assert_lt(a.visor_energy(), 0.5, "the gem out")
	var spin := a.drives()[G.RING0 + G.SPIN]
	a.advance(DT)
	assert_eq(a.drives()[G.RING0 + G.SPIN], spin, "the rings stopped")


func test_reduced_motion_moves_less_and_never_swings_or_speeds_up() -> void:
	var out := []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _orb()
		_run(a, 30, _hover(1.0))
		var lift := [99.0, -99.0]
		for k in 150:
			_run(a, 1, _hover(1.0))
			lift[0] = minf(lift[0], a.vat_lift())
			lift[1] = maxf(lift[1], a.vat_lift())
		out.append([lift[1] - lift[0], absf(_turned(a, 1, 60, _hover(1.0)))])
	assert_lt(out[1][0], out[0][0] * 0.6, "a smaller bob: %s" % [out])
	assert_lt(out[1][1], out[0][1] * 0.4, "the rings turn slowly: %s" % [out])
	assert_almost_eq(
		out[1][1], G.SPIN_CALM * absf(G.SPIN_B), 0.02, "at one steady rate, the draw or not"
	)
	# A hit eases one lean and back: no swing.
	ViewPrefs.reduced_motion = true
	var b := _orb()
	_run(b, 30, _hover())
	var twin := _orb()
	_run(twin, 30, _hover())
	var signs := {}
	var worst := 0.0
	var last := b.drives().duplicate()
	for k in 60:
		_run(b, 1, _hover(0.0, 40))
		_run(twin, 1, _hover())
		var off := b.drives()[G.RING0 + G.TIP] - twin.drives()[G.RING0 + G.TIP]
		if absf(off) > 0.01:
			signs[signf(off)] = true
		worst = maxf(worst, absf(b.drives()[G.ROLL] - last[G.ROLL]))
		last = b.drives().duplicate()
	assert_eq(signs.size(), 1, "the ring leans one way and back")
	assert_lt(worst, 0.03, "smoothly: %.3f a frame at most" % worst)


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _orb()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 3, "the code-made plates")
	assert_eq(a.rings.size(), 2)
	_run(a, 10, _hover())
	var r0 := a.rings[1].transform
	_run(a, 20, _hover(1.0))
	assert_ne(a.rings[1].transform, r0, "its rings still turn")
	assert_null(a.vat_texture(), "no colour map")


func test_the_vat_bake_matches_the_live_pose() -> void:
	assert_true(VatCrowd.supports(KIND), "drawn by the VAT crowd")
	assert_true(SoloVat.is_solo(KIND))
	assert_false(StarfallAvatar.takes(KIND), "no stand-in body left")
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var pose := VatBake.pose_for(KIND)
		var mesh := VatBake.mesh_for(KIND, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
		var vat := VatBake.vat_avatar_of(KIND)
		var e := VatVerify.pose_error(live, vat, pose, mesh, 40, 17)
		assert_eq(e["vertices"], mesh.surface_get_array_len(0), "every vertex compared")
		assert_lt(float(e["max_m"]), 0.002, "within 2 mm (calm %s): %s" % [calm, e])
		assert_true(pose.has("albedo_tex"), "the owner's colour map")
		live.free()
		vat.free()


func test_a_vat_avatar_keeps_the_drives_lift_and_glows_through_a_fight() -> void:
	var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
	var vat := VatBake.vat_avatar_of(KIND)
	add_child_autofree(live)
	add_child_autofree(vat)
	live.set_process(false)
	vat.set_process(false)
	var pieces := vat.find_children("*", "MeshInstance3D", true, false)
	assert_eq(pieces.size(), 1, "no pieces but its live ground disc")
	var plan := [
		[WorldReader.STATE_SPAWN, 20, 0.0, 50],
		[WorldReader.STATE_MOVE, 60, 0.0, 50],
		[WorldReader.STATE_MOVE, 60, 0.8, 50],
		[WorldReader.STATE_MOVE, 30, 0.8, 35],
		[WorldReader.STATE_MOVE, 30, 0.0, 20],
	]
	var t := 0
	for step: Array in plan:
		for k in int(step[1]):
			var s := {"state": step[0], "draw": step[2], "hp": step[3]}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)
			t += 1
