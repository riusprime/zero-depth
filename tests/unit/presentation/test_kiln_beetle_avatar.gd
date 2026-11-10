extends GutTest
## v0.11.0 O17e: the Kiln Beetle on the owner's model (KilnBeetleAvatar): its parts load into their joints, each clip
## moves the parts it should (the tetrapod walk, the stepping turn, the heat as its HP drops, read from a real World,
## the slam's windup and the slam, a hit, the death over the burst's fuse), reduced motion moves less and never
## shakes, a missing model falls back to the code-made body that plays the same clips, and the VAT bake matches the live
## pose (a VAT avatar keeps the same drives, lift and glows through a fight).

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_KILN_BEETLE

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


## A beetle under a facing node (the one ActorViews turns), its own processing off.
func _beetle() -> KilnBeetleAvatar:
	var facing := Node3D.new()
	add_child_autofree(facing)
	var a := KilnBeetleAvatar.new()
	a.setup()
	facing.add_child(a)
	a.set_process(false)
	return a


## Ticks of a state: apply_state then a frame, `n` times; the place moves by `step` a tick, the facing turns by
## `turn` (radians) a tick.
func _run(
	a: KilnBeetleAvatar, from: int, n: int, s: Dictionary, step := Vector2.ZERO, turn := 0.0
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


func _move(hp := 60) -> Dictionary:
	return {"state": WorldReader.STATE_MOVE, "windup": 0.0, "hp": hp, "max_hp": 60}


func _sweep(a: KilnBeetleAvatar, leg: int) -> float:
	return a.drives()[KilnBeetleAvatar.LEG0 + 3 * leg]


func test_the_owner_s_model_is_cut_into_its_joints() -> void:
	assert_true(EnemyModels.has_model(&"kiln_beetle"), "the model file is installed")
	var a := _beetle()
	assert_true(a.has_model)
	assert_eq(a.uppers.size(), 8, "eight upper legs")
	assert_eq(a.lowers.size(), 8, "eight claws")
	var meshes := a.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 19, "the body, the shell, the head and sixteen leg halves")
	for k in 8:
		assert_eq(a.lowers[k].get_parent(), a.uppers[k], "a claw hangs from its leg")
	assert_eq(a.shell.get_parent(), a.rig, "the shell sits on the body")
	var heat := 0
	var visor := 0
	for mi: MeshInstance3D in meshes:
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as StandardMaterial3D
			if m != null and m.has_meta(SoloVat.GLOW):
				visor += 1
				assert_eq(String(mi.name), "head", "the visor is the head's glow")
			elif m != null and m.emission_enabled and not m in a.body_materials:
				heat += 1
	assert_gt(heat, 1, "the vents and the belly glow with the heat")
	assert_eq(visor, 1, "the gem visor")
	assert_eq(a.body_materials.size(), 2, "the base and the role plates take the flash")


func test_the_walk_is_a_tetrapod_and_rocks_the_body() -> void:
	var a := _beetle()
	var t := _run(a, 0, 40, _move(), Vector2(1.2 / 60.0, 0))
	var lo := 99.0
	var hi := -99.0
	var same := 0.0
	var opposite := 0.0
	var roll := [99.0, -99.0]
	var r0 := a.uppers[0].rotation
	var moved := false
	for k in 40:
		t = _run(a, t, 1, _move(), Vector2(1.2 / 60.0, 0))
		var r1 := _sweep(a, 0)
		lo = minf(lo, r1)
		hi = maxf(hi, r1)
		same += r1 * _sweep(a, 5)  # l2: r1's set
		opposite += r1 * _sweep(a, 4)  # l1: the other set
		roll[0] = minf(roll[0], a.drives()[KilnBeetleAvatar.ROLL])
		roll[1] = maxf(roll[1], a.drives()[KilnBeetleAvatar.ROLL])
		moved = moved or a.uppers[0].rotation.distance_to(r0) > 0.2
	assert_gt(hi - lo, 0.7, "the front leg sweeps a stride: %.2f" % (hi - lo))
	assert_gt(same, 0.0, "r1 and l2 step together")
	assert_lt(opposite, 0.0, "r1 and l1 step in turn")
	assert_gt(roll[1] - roll[0], 0.04, "the body rocks with the sets")
	assert_true(moved, "the leg node follows its drives")


func test_turning_in_place_steps_its_legs() -> void:
	var a := _beetle()
	var t := _run(a, 0, 20, _move())
	var span := [99.0, -99.0]
	var lifted := 0.0
	var turn := deg_to_rad(90.0) / 60.0  # the sim's turn rate
	t = _run(a, t, 20, _move(), Vector2.ZERO, turn)
	for k in 60:
		t = _run(a, t, 1, _move(), Vector2.ZERO, turn)
		span[0] = minf(span[0], _sweep(a, 1))
		span[1] = maxf(span[1], _sweep(a, 1))
		lifted = maxf(lifted, a.drives()[KilnBeetleAvatar.LEG0 + 3 * 1 + 1])
	assert_gt(span[1] - span[0], 0.3, "its legs step while it turns: %s" % [span])
	assert_gt(lifted, 0.1, "lifting off the ground")
	assert_lt(absf(a.drives()[KilnBeetleAvatar.SWAY]), 0.03, "the body stays steady")
	_run(a, t, 60, _move())
	assert_almost_eq(_sweep(a, 1), 0.0, 0.08, "and settles when the turn stops")


func test_it_glows_hotter_and_its_shell_sits_higher_as_its_hp_drops() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	w.actors.invuln[0] = 1 << 24
	w.add_enemy(ActorStore.Kind.KILN_BEETLE, Vector2(4, 0))
	for _t in SimTick.SPAWN_IN_TICKS + 2:
		w.step(InputFrame.new())
	var reader := WorldReader.new(w)
	ViewPrefs.reduced_motion = true  # (no breath's puff in the way)
	var a := _beetle()
	for _k in 20:
		a.sync(reader, 1)
		a.advance(0.05)
	var full := a.heat_energy()
	var shell0 := a.drives()[KilnBeetleAvatar.SHELL_UP]
	w.actors.hp[1] = w.actors.max_hp[1] / 5
	for _k in 20:
		a.sync(reader, 1)
		a.advance(0.05)
	assert_almost_eq(a.heat(), 0.8, 0.01, "the heat is the HP lost")
	assert_gt(a.heat_energy(), full + 4.0, "hotter at a fifth of its HP")
	assert_gt(
		a.drives()[KilnBeetleAvatar.SHELL_UP],
		shell0 + 0.005,
		"the shell sits higher on its glowing gap"
	)


func test_the_windup_rears_it_up_and_flashes_the_visor() -> void:
	var a := _beetle()
	var t := _run(a, 0, 30, _move())
	var peak := 0.0
	var crouch := 0.0
	for k in 30:
		t = _run(
			a,
			t,
			1,
			{
				"state": WorldReader.STATE_WINDUP,
				"windup": float(k + 1) / 30.0,
				"hp": 60,
				"max_hp": 60
			}
		)
		peak = maxf(peak, a.visor_energy())
		if k < 6:
			crouch = minf(crouch, a.drives()[KilnBeetleAvatar.SHELL_SW])
	assert_lt(crouch, -0.01, "a short crouch first")
	assert_gt(peak, KilnBeetleAvatar.VISOR_REST + 3.0, "the visor climbs and flashes")
	assert_gt(a.drives()[KilnBeetleAvatar.PITCH], 0.3, "reared up")
	assert_gt(a.drives()[KilnBeetleAvatar.LEG0 + 1], 0.8, "the front legs raised")
	assert_lt(a.drives()[KilnBeetleAvatar.LEG0 + 3 * 2 + 1], 0.0, "the hind legs bracing")


func test_the_slam_crashes_down_and_squashes_the_shell() -> void:
	var a := _beetle()
	var t := _run(a, 0, 30, _move())
	t = _run(a, t, 30, {"state": WorldReader.STATE_WINDUP, "windup": 1.0, "hp": 60, "max_hp": 60})
	var glow0 := a.heat_energy()
	t = _run(a, t, 1, {"state": WorldReader.STATE_ACTIVE, "hp": 60, "max_hp": 60})
	t = _run(a, t, 4, {"state": WorldReader.STATE_RECOVER, "hp": 60, "max_hp": 60})
	assert_lt(a.drives()[KilnBeetleAvatar.PITCH], -0.08, "nose down: it crashed onto its front")
	assert_lt(a.drives()[KilnBeetleAvatar.SHELL_SW], -0.1, "the shell squashed")
	assert_gt(a.heat_energy(), glow0 + 2.0, "the vents puff")
	_run(a, t, 60, _move())
	assert_almost_eq(a.drives()[KilnBeetleAvatar.PITCH], 0.0, 0.05, "and it heaves back up")


func test_a_hit_jolts_the_shell_and_flares_the_vents() -> void:
	var a := _beetle()
	var t := _run(a, 0, 30, _move())
	var glow0 := a.heat_energy()
	_run(a, t, 3, _move(50))
	assert_lt(a.drives()[KilnBeetleAvatar.SHELL_SW], -0.03, "the shell jolts")
	assert_gt(a.heat_energy(), glow0 + 1.0, "the vents flare")


func test_the_death_swells_the_shell_white_hot_over_the_burst_s_fuse() -> void:
	var def := load("res://data/enemies/kiln_beetle.tres") as EnemyDefinition
	assert_almost_eq(
		float(def.behaviour_params["burst_delay_seconds"]),
		KilnBeetleAvatar.DEATH_SECONDS,
		0.001,
		"the death lasts the burst's fuse"
	)
	var a := _beetle()
	var t := _run(a, 0, 30, _move(20))
	assert_true(a.die())
	assert_true(a.dying())
	var mid := 0.0
	for k in int(KilnBeetleAvatar.DEATH_SECONDS / DT):
		a.advance(DT)
		if k == 15:
			mid = a.drives()[KilnBeetleAvatar.SHELL_SW]
	assert_gt(a.drives()[KilnBeetleAvatar.SHELL_SW], 0.2, "the shell swelled")
	assert_gt(a.drives()[KilnBeetleAvatar.SHELL_SW], mid + 0.1, "swelling up to the burst")
	assert_gt(a.drives()[KilnBeetleAvatar.SHELL_UP], 0.04, "lifted off its glowing belly")
	assert_gt(a.heat_energy(), 12.0, "white-hot")
	assert_gt(a.drives()[KilnBeetleAvatar.LEG0 + 1], 0.15, "the legs splayed")
	assert_gt(t, 0)


func test_reduced_motion_moves_less_and_never_shakes() -> void:
	var spans := []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _beetle()
		var t := _run(a, 0, 40, _move(), Vector2(1.2 / 60.0, 0))
		var p := [99.0, -99.0]
		for k in 40:
			t = _run(a, t, 1, _move(), Vector2(1.2 / 60.0, 0))
			p[0] = minf(p[0], a.drives()[KilnBeetleAvatar.ROLL])
			p[1] = maxf(p[1], a.drives()[KilnBeetleAvatar.ROLL])
		t = _run(
			a, t, 30, {"state": WorldReader.STATE_WINDUP, "windup": 0.7, "hp": 60, "max_hp": 60}
		)
		spans.append([p[1] - p[0], a.drives()[KilnBeetleAvatar.PITCH]])
	assert_lt(spans[1][0], spans[0][0] * 0.6, "the walk's rock is smaller: %s" % [spans])
	assert_lt(spans[1][1], spans[0][1] * 0.6, "the rearing is lower: %s" % [spans])
	# No shake in the death with reduced motion: the roll and the legs move smoothly frame to frame.
	ViewPrefs.reduced_motion = true
	var b := _beetle()
	_run(b, 0, 30, _move(10))
	b.die()
	var worst := 0.0
	var last := b.drives().duplicate()
	for k in 50:
		b.advance(DT)
		for j in [
			KilnBeetleAvatar.ROLL,
			KilnBeetleAvatar.PITCH,
			KilnBeetleAvatar.LEG0 + 1,
			KilnBeetleAvatar.LEG0 + 4
		]:
			worst = maxf(worst, absf(b.drives()[j] - last[j]))
		last = b.drives().duplicate()
	assert_lt(worst, 0.05, "no shake or scrabble: %.3f a frame at most" % worst)


func test_a_missing_model_falls_back_to_the_code_body() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _beetle()
	assert_false(a.has_model)
	assert_gt(a.body_materials.size(), 4, "the code-made plates")
	assert_eq(a.uppers.size(), 8)
	var t := _run(a, 0, 30, _move())
	var r0 := a.uppers[0].rotation
	_run(a, t, 20, _move(), Vector2(1.2 / 60.0, 0))
	assert_ne(a.uppers[0].rotation, r0, "its legs still walk")
	assert_null(a.vat_texture(), "no colour map")


func test_the_vat_bake_matches_the_live_pose() -> void:
	assert_true(VatCrowd.supports(KIND), "drawn by the VAT crowd")
	assert_true(SoloVat.is_solo(KIND))
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var pose := VatBake.pose_for(KIND)
		var mesh := VatBake.mesh_for(KIND, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
		var vat := VatBake.vat_avatar_of(KIND)
		var e := VatBake.pose_error(live, vat, pose, mesh, 40, 17)
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
	assert_eq(vat.find_children("*", "MeshInstance3D", true, false).size(), 0, "no pieces")
	var plan := [
		[WorldReader.STATE_SPAWN, 20, 0.0, 60],
		[WorldReader.STATE_MOVE, 60, 1.2, 60],
		[WorldReader.STATE_WINDUP, 30, 0.0, 60],
		[WorldReader.STATE_ACTIVE, 1, 0.0, 60],
		[WorldReader.STATE_RECOVER, 48, 0.0, 40],
		[WorldReader.STATE_MOVE, 30, 1.2, 12],
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
				"windup": float(k + 1) / 30.0 if step[0] == WorldReader.STATE_WINDUP else 0.0,
				"hp": step[3],
				"max_hp": 60,
			}
			for a: Node in [live, vat]:
				a.call(&"apply_state", s)
				a.call(&"advance", DT)
			assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % t)
			t += 1
