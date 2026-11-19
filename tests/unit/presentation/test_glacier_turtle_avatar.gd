extends GutTest
## The Glacier Turtle on the owner's model (GlacierTurtleAvatar): its parts load into their joints, each clip moves the
## parts it should (the walk with its feet planted, the stepping turn, the shield kept on the ground, the tell's rearing
## with the shield hoisted, the slam, the brace under a hit on the shield, the break and the bare stance after it, a
## hit, the rise-in, the death with the shield toppling), the knees stay off the ground, reduced motion moves less and
## never shakes, a missing model falls back to the code-made body that plays the same clips, and the VAT bake matches
## the live pose (a VAT avatar keeps the same drives, lift and glow through a fight).

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_GLACIER_TURTLE
## A step a tick at its walk speed (the sim's plane, toward its front).
const RUN := Vector2(1.1 / 60.0, 0.0)

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


## A turtle under a facing node (the one ActorViews turns), its own processing off.
func _turtle() -> GlacierTurtleAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := GlacierTurtleAvatar.new()
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## Ticks of a state: apply_state then a frame, `n` times; the place moves by `step` a tick (sim plane), the facing
## turns by `turn` (radians) a tick.
func _run(
	a: GlacierTurtleAvatar, from: int, n: int, s: Dictionary, step := Vector2.ZERO, turn := 0.0
) -> int:
	for k in n:
		var t := from + k
		var d := s.duplicate()
		d["tick"] = t
		d["pos"] = step * float(t)
		(a.get_parent() as Node3D).rotation.y += turn
		a.apply_state(d)
		a.advance(DT)
		a.advance_flinch(DT)
	return from + n


func _move(hp := 80, shell := 60) -> Dictionary:
	return {"state": WorldReader.STATE_MOVE, "windup": 0.0, "hp": hp, "shell": shell}


func _windup(p: float, shell := 60) -> Dictionary:
	return {"state": WorldReader.STATE_WINDUP, "windup": p, "hp": 80, "shell": shell}


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	assert_true(EnemyModels.has_model(&"glacier_turtle"), "the model file is installed")
	var a := _turtle()
	assert_true(a.has_model)
	assert_eq(a.uppers.size(), 4, "four upper legs")
	assert_eq(a.lowers.size(), 4, "four feet")
	var meshes := a.find_children("*", "MeshInstance3D", true, false)
	assert_eq(
		meshes.size(), 12, "the body, the carapace, the head, the shield and eight leg halves"
	)
	for k in 4:
		assert_eq(a.lowers[k].get_parent(), a.uppers[k], "a foot hangs from its leg")
	for n: Node3D in [a.carapace, a.head, a.shield]:
		assert_eq(n.get_parent(), a.rig, "%s sits on the body" % n.name)
	var visor := 0
	for mi: MeshInstance3D in meshes:
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as StandardMaterial3D
			if m != null and m.emission_enabled and not m in a.body_materials:
				visor += 1
				assert_eq(String(mi.name), "head", "the visor is the head's glow")
	assert_eq(visor, 1, "the gem visor")
	assert_eq(a.body_materials.size(), 2, "the base and the role plates take the flash")
	var shield := a.shield.get_child(0) as MeshInstance3D
	var box := shield.get_aabb()
	assert_gt(box.size.y * shield.scale.y, 0.8, "a shield taller than the head")


func test_the_walk_plants_its_feet_and_steps_the_diagonals_together() -> void:
	var a := _turtle()
	var t := _run(a, 0, 40, _move(), RUN)
	var low := 99.0
	var high := -99.0
	var span := [99.0, -99.0]
	var same := 0.0
	var opposite := 0.0
	var roll := [99.0, -99.0]
	var r0 := a.uppers[0].rotation
	var moved := false
	for k in 90:
		t = _run(a, t, 1, _move(), RUN)
		var f := a.foot_at(0)
		low = minf(low, f.y)
		high = maxf(high, f.y)
		span[0] = minf(span[0], f.x)
		span[1] = maxf(span[1], f.x)
		var h0 := f.y - 0.03
		same += h0 * (a.foot_at(3).y - 0.03)  # bl: fr's diagonal
		opposite += h0 * (a.foot_at(1).y - 0.03)  # fl: the other pair
		roll[0] = minf(roll[0], a.drives()[GlacierTurtleAvatar.ROLL])
		roll[1] = maxf(roll[1], a.drives()[GlacierTurtleAvatar.ROLL])
		moved = moved or a.uppers[0].rotation.distance_to(r0) > 0.1
	assert_lt(low, 0.03, "the front foot comes down to the ground: %.3f" % low)
	assert_gt(high, 0.05, "and lifts in its swing: %.3f" % high)
	assert_gt(span[1] - span[0], 0.15, "the foot sweeps a stride: %s" % [span])
	assert_gt(same, 0.0, "fr and bl step together")
	assert_lt(opposite, 0.0, "fr and fl step in turn")
	assert_gt(roll[1] - roll[0], 0.05, "the body rolls with the pairs")
	assert_true(moved, "the leg node follows its drives")


func test_a_planted_foot_stays_put_on_the_ground_while_the_body_moves() -> void:
	for shell in [60, 0]:  # held, and bare (shorter, quicker steps)
		var a := _turtle()
		var t := _run(a, 0, 90, _move(80, shell), RUN)
		var worst := [0.0, 0.0]
		var down := 0
		for j in [0, 2]:
			var last := a.foot_at(j)
			for k in 60:
				t = _run(a, t, 1, _move(80, shell), RUN)
				var f := a.foot_at(j)
				var q := fposmod(a._phase - float(GlacierTurtleAvatar.STRIDE_AT[j]), 1.0)
				if q > 0.05 and q < GlacierTurtleAvatar.DUTY - 0.05:
					down += 1
					worst[0] = maxf(worst[0], f.y)
					worst[1] = maxf(worst[1], absf((f.x - last.x) + 1.1 * DT))
				last = f
		assert_gt(down, 20)
		assert_lt(worst[0], 0.03, "a planted foot on the ground (shell %d): %s" % [shell, worst])
		assert_lt(worst[1], 0.005, "and still (shell %d): %s" % [shell, worst])


func test_turning_in_place_steps_its_legs_and_the_head_leads() -> void:
	var a := _turtle()
	var t := _run(a, 0, 20, _move())
	var span := [99.0, -99.0]
	var lifted := 0.0
	var turn := 0.75 / 60.0
	t = _run(a, t, 30, _move(), Vector2.ZERO, turn)
	var head := 0.0
	for k in 90:
		t = _run(a, t, 1, _move(), Vector2.ZERO, turn)
		span[0] = minf(span[0], a.drives()[GlacierTurtleAvatar.LEG0])
		span[1] = maxf(span[1], a.drives()[GlacierTurtleAvatar.LEG0])
		lifted = maxf(lifted, a.foot_at(0).y)
		head += a.drives()[GlacierTurtleAvatar.HEAD_Y] / 90.0
	assert_gt(span[1] - span[0], 0.08, "its legs swing round while it turns: %s" % [span])
	assert_gt(lifted, 0.04, "lifting off the ground")
	assert_gt(head, 0.1, "the head leads the turn: %.2f" % head)
	_run(a, t, 90, _move())
	assert_lt(
		a.foot_at(0).distance_to(GlacierTurtleAvatar.FEET[0]),
		0.04,
		"and its foot settles when the turn stops"
	)


func test_a_held_shield_keeps_to_the_ground() -> void:
	var a := _turtle()
	var t := _run(a, 0, 60, _move())
	var worst := 0.0
	for k in 120:
		t = _run(a, t, 1, _move(), RUN if k < 60 else Vector2.ZERO)
		worst = maxf(worst, absf(a.shield_foot().y))
	assert_lt(
		worst, 0.03, "its front foot on the ground through the walk and the idle: %.3f" % worst
	)


func test_the_tell_rears_it_up_hoisting_the_shield() -> void:
	var a := _turtle()
	var t := _run(a, 0, 30, _move())
	var hind := a.foot_at(2)
	var peak := 0.0
	for k in 40:
		t = _run(a, t, 1, _windup(float(k + 1) / 40.0))
		peak = maxf(peak, a.visor_energy())
	assert_gt(a.drives()[GlacierTurtleAvatar.PITCH], 0.18, "reared up")
	assert_gt(a.shield_foot().y, 0.15, "the shield hoisted: %.2f" % a.shield_foot().y)
	assert_gt(a.drives()[GlacierTurtleAvatar.HEAD_P], 0.15, "the head up")
	assert_gt(peak, GlacierTurtleAvatar.VISOR_REST + 3.0, "the visor climbs and flashes")
	assert_gt(a.foot_at(0).y, 0.08, "the front feet off the ground")
	assert_lt(a.foot_at(2).y, 0.03, "the hind feet stay down")
	assert_almost_eq(a.foot_at(2).x, hind.x, 0.03, "and where they stood")


func test_the_slam_drives_the_shield_down_and_it_heaves_back_up() -> void:
	var a := _turtle()
	var t := _run(a, 0, 30, _move())
	t = _run(a, t, 40, _windup(1.0))
	t = _run(a, t, 1, {"state": WorldReader.STATE_ACTIVE, "hp": 80, "shell": 60})
	t = _run(a, t, 8, {"state": WorldReader.STATE_RECOVER, "hp": 80, "shell": 60})
	assert_lt(
		a.drives()[GlacierTurtleAvatar.SHIELD_P], -0.1, "the shield driven forward into the ground"
	)
	assert_lt(a.drives()[GlacierTurtleAvatar.PITCH], 0.0, "the body crashed down on its front")
	assert_lt(a.vat_lift(), -0.03, "squashed")
	assert_lt(a.foot_at(0).y, 0.04, "the front feet stamped down")
	_run(a, t, 60, _move())
	assert_almost_eq(
		a.drives()[GlacierTurtleAvatar.PITCH], 0.0, 0.05, "and it heaved itself back up"
	)


func test_a_hit_on_the_shield_braces_it() -> void:
	var calm := _turtle()  # the same moments with no hit
	var hit := _turtle()
	var t := _run(calm, 0, 30, _move())
	_run(hit, 0, 30, _move())
	_run(calm, t, 5, _move())
	_run(hit, t, 5, _move(80, 45))
	var d0 := calm.drives()
	var d1 := hit.drives()
	assert_gt(
		d1[GlacierTurtleAvatar.SHIELD_P],
		d0[GlacierTurtleAvatar.SHIELD_P] + 0.04,
		"the shield tips back"
	)
	assert_lt(
		d1[GlacierTurtleAvatar.HEAD_P], d0[GlacierTurtleAvatar.HEAD_P] - 0.05, "the head ducks"
	)
	assert_lt(hit.vat_lift(), calm.vat_lift() - 0.005, "the body braces low")
	assert_gt(hit.visor_energy(), calm.visor_energy() + 0.5, "the visor flares")
	assert_eq(hit.shield_shown(), 1.0, "the shield still stands")


func test_the_break_pops_the_shield_and_it_stands_bare() -> void:
	var a := _turtle()
	var t := _run(a, 0, 30, _move())
	var held := a.drives().duplicate()
	t = _run(a, t, 1, _move(80, 0))
	assert_gt(a.shield_shown(), 1.0, "the shield swells for a blink")
	assert_true(a.shield.visible)
	var reel := 0.0
	for k in 20:
		t = _run(a, t, 1, _move(80, 0))
		reel = maxf(reel, a.drives()[GlacierTurtleAvatar.PITCH])
	assert_eq(a.shield_shown(), 0.0, "then it is gone")
	assert_false(a.shield.visible)
	assert_gt(reel, 0.08, "it reels back")
	t = _run(a, t, 90, _move(80, 0))
	assert_almost_eq(a.bareness(), 1.0, 0.01, "bare")
	assert_lt(
		a.drives()[GlacierTurtleAvatar.HEAD_P],
		held[GlacierTurtleAvatar.HEAD_P] - 0.05,
		"the head drawn in"
	)
	assert_lt(
		a.drives()[GlacierTurtleAvatar.BACK_UP],
		held[GlacierTurtleAvatar.BACK_UP] - 0.005,
		"the carapace tucked down"
	)
	assert_lt(a.vat_lift(), -0.015, "crouched lower")
	# Its walk: the same speed in quicker steps.
	var steps := []
	for shell in [60, 0]:
		var b := _turtle()
		var u := _run(b, 0, 120, _move(80, shell), RUN)
		var p0 := b._phase
		_run(b, u, 30, _move(80, shell), RUN)
		steps.append(fposmod(b._phase - p0, 1.0))
	assert_gt(steps[1], steps[0] * 1.2, "bare, it steps quicker: %s" % [steps])


func test_a_turtle_met_with_its_shield_broken_never_shows_it() -> void:
	var a := _turtle()
	a.apply_state({"tick": 0, "state": WorldReader.STATE_MOVE, "pos": Vector2.ZERO, "shell": 0})
	assert_eq(a.shield_shown(), 0.0)
	assert_false(a.shield.visible)
	assert_eq(a.bareness(), 1.0)
	_run(a, 1, 10, _move(80, 0))
	assert_eq(a.shield_shown(), 0.0, "no break clip")


func test_a_hit_jolts_it_and_ducks_the_head() -> void:
	var calm := _turtle()
	var hit := _turtle()
	var t := _run(calm, 0, 30, _move())
	_run(hit, 0, 30, _move())
	_run(calm, t, 5, _move())
	_run(hit, t, 5, _move(60))
	var d0 := calm.drives()
	var d1 := hit.drives()
	assert_lt(
		d1[GlacierTurtleAvatar.SURGE], d0[GlacierTurtleAvatar.SURGE] - 0.015, "the body jolts back"
	)
	assert_lt(
		d1[GlacierTurtleAvatar.HEAD_P], d0[GlacierTurtleAvatar.HEAD_P] - 0.08, "the head ducks"
	)
	assert_almost_eq(
		d1[GlacierTurtleAvatar.SHIELD_P],
		d0[GlacierTurtleAvatar.SHIELD_P],
		0.02,
		"no brace: the shield took nothing"
	)


func test_it_rises_in_from_a_crouch_on_its_feet() -> void:
	var a := _turtle()
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO, "shell": 60})
	a.advance(DT)
	assert_lt(a.vat_lift(), -0.1, "crouched")
	for k in 4:
		assert_lt(
			absf(a.foot_at(k).y - GlacierTurtleAvatar.FEET[k].y), 0.02, "foot %d on the ground" % k
		)
	assert_lt(absf(a.shield_foot().y), 0.02, "the shield on the ground")
	_run(a, 1, 90, _move())
	assert_almost_eq(a.vat_lift(), 0.0, 0.02, "risen")


func test_the_death_drops_it_on_its_belly_and_topples_the_shield() -> void:
	var a := _turtle()
	_run(a, 0, 30, _move(10))
	assert_true(a.die())
	assert_true(a.dying())
	for k in int(GlacierTurtleAvatar.DEATH_SECONDS / DT):
		a.advance(DT)
	assert_lt(a.vat_lift(), -0.09, "the body dropped")
	assert_gt(absf(a.drives()[GlacierTurtleAvatar.ROLL]), 0.07, "tipped to one side")
	assert_lt(a.drives()[GlacierTurtleAvatar.HEAD_P], -0.3, "the head drooped")
	assert_lt(a.visor_energy(), 0.5, "the visor out")
	assert_lt(a.drives()[GlacierTurtleAvatar.SHIELD_P], -1.0, "the shield toppled forward")
	assert_gt(a.shield_foot().y, -0.03, "onto the ground, not through it")
	# A bare turtle's death has no shield to topple.
	var b := _turtle()
	_run(b, 0, 30, _move(10, 0))
	b.die()
	for k in int(GlacierTurtleAvatar.DEATH_SECONDS / DT):
		b.advance(DT)
	assert_eq(b.shield_shown(), 0.0)


func test_the_knees_stay_off_the_ground_through_every_clip() -> void:
	var a := _turtle()
	var lowest := [99.0, -1]
	var check := func(at: String) -> void:
		for k in 4:
			var y := a.knee_at(k).y
			if y < lowest[0]:
				lowest[0] = y
				lowest[1] = "%s, leg %d" % [at, k]
	a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN, "pos": Vector2.ZERO, "shell": 60})
	a.advance(DT)
	check.call("rise-in")
	var t := 1
	for k in 60:
		t = _run(a, t, 1, _move(), RUN)
		check.call("walk")
	for k in 40:
		t = _run(a, t, 1, _windup(float(k + 1) / 40.0))
		check.call("tell")
	t = _run(a, t, 1, {"state": WorldReader.STATE_ACTIVE, "hp": 80, "shell": 60})
	for k in 50:
		t = _run(a, t, 1, {"state": WorldReader.STATE_RECOVER, "hp": 70, "shell": 30})
		check.call("slam, brace")
	for k in 50:
		t = _run(a, t, 1, _move(70, 0), RUN)
		check.call("break, bare walk")
	a.die()
	for k in 80:
		a.advance(DT)
		check.call("death")
	assert_gt(float(lowest[0]), 0.03, "the lowest knee: %s" % [lowest])


func test_reduced_motion_moves_less_and_never_shakes() -> void:
	var spans := []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _turtle()
		var t := _run(a, 0, 60, _move(), RUN)
		var p := [99.0, -99.0]
		for k in 60:
			t = _run(a, t, 1, _move(), RUN)
			p[0] = minf(p[0], a.drives()[GlacierTurtleAvatar.ROLL])
			p[1] = maxf(p[1], a.drives()[GlacierTurtleAvatar.ROLL])
		t = _run(a, t, 30, _windup(0.7))
		spans.append([p[1] - p[0], a.drives()[GlacierTurtleAvatar.PITCH]])
	assert_lt(spans[1][0], spans[0][0] * 0.6, "the walk's roll is smaller: %s" % [spans])
	assert_lt(spans[1][1], spans[0][1] * 0.6, "the rearing is lower: %s" % [spans])
	# No shudder, shake or tremble with reduced motion: the brace, the break and the death move smoothly.
	ViewPrefs.reduced_motion = true
	var b := _turtle()
	var u := _run(b, 0, 30, _move(10))
	# A shake turns a drive's way back and forth many times; a smooth move only a few. And none jumps.
	var watch := [
		GlacierTurtleAvatar.ROLL,
		GlacierTurtleAvatar.HEAD_Y,
		GlacierTurtleAvatar.SHIELD_P,
		GlacierTurtleAvatar.SHIELD_R,
		GlacierTurtleAvatar.BACK_P,
		GlacierTurtleAvatar.BACK_UP,
	]
	var n := b.drives().size()
	var last: Array = Array(b.drives())  # (Arrays: the lambda shares them)
	var steps: Array = []
	steps.resize(n)
	steps.fill(0.0)
	var turns := {}
	var jump := [0.0]
	var frame := func() -> void:
		var d := b.drives()
		for j: int in watch:
			var step: float = d[j] - float(last[j])
			var was: float = steps[j]
			if absf(step) > 0.0005 and absf(was) > 0.0005 and signf(step) != signf(was):
				turns[j] = int(turns.get(j, 0)) + 1
			if absf(step) > 0.0005:
				steps[j] = step
			jump[0] = maxf(float(jump[0]), absf(step))
		for j in n:
			last[j] = d[j]
	for k in 30:  # the brace
		u = _run(b, u, 1, _move(10, 40))
		frame.call()
	for k in 50:  # the break
		u = _run(b, u, 1, _move(10, 0))
		frame.call()
	assert_lt(float(jump[0]), 0.06, "no jump in the brace and the break: %.3f a frame" % jump[0])
	b.die()  # (the shield's topple is a fall, quick by design: only its turns are counted)
	for k in 30:
		b.advance(DT)
		frame.call()
	for j: int in turns:
		assert_lt(int(turns[j]), 4, "drive %d turns its way %d times: no shake" % [j, turns[j]])


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _turtle()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 3, "the code-made plates")
	assert_eq(a.uppers.size(), 4)
	var t := _run(a, 0, 30, _move())
	var r0 := a.uppers[0].rotation
	t = _run(a, t, 30, _move(), RUN)
	assert_ne(a.uppers[0].rotation, r0, "its legs still walk")
	_run(a, t, 20, _move(80, 0))
	assert_false(a.shield.visible, "its shield still breaks")
	assert_null(a.vat_texture(), "no colour map")


func test_the_vat_bake_matches_the_live_pose() -> void:
	assert_true(VatCrowd.supports(KIND), "drawn by the VAT crowd")
	assert_true(SoloVat.is_solo(KIND))
	assert_false(HordeAvatar.is_horde_kind(KIND), "no stand-in body left")
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


func test_a_vat_avatar_keeps_the_drives_lift_and_glow_through_a_fight() -> void:
	var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
	var vat := VatBake.vat_avatar_of(KIND)
	add_child_autofree(live)
	add_child_autofree(vat)
	live.set_process(false)
	vat.set_process(false)
	assert_eq(vat.find_children("*", "MeshInstance3D", true, false).size(), 0, "no pieces")
	var plan := [
		[WorldReader.STATE_SPAWN, 20, 0.0, 80, 60],
		[WorldReader.STATE_MOVE, 60, 1.1, 80, 60],
		[WorldReader.STATE_MOVE, 20, 0.0, 80, 35],
		[WorldReader.STATE_WINDUP, 40, 0.0, 80, 35],
		[WorldReader.STATE_ACTIVE, 1, 0.0, 80, 35],
		[WorldReader.STATE_RECOVER, 50, 0.0, 80, 0],
		[WorldReader.STATE_MOVE, 30, -1.1, 50, 0],
	]
	var t := 0
	var x := 0.0
	for step: Array in plan:
		for k in int(step[1]):
			x += float(step[2]) / 60.0
			var s := {
				"tick": t,
				"pos": Vector2(x, 0.0),
				"state": step[0],
				"windup": float(k + 1) / 40.0 if step[0] == WorldReader.STATE_WINDUP else 0.0,
				"hp": step[3],
				"shell": step[4],
			}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)
			t += 1
