extends GutTest
## v0.11.0 O17d (ENEMIES.md R6): the Cinder Priest on the owner's model (CinderPriestAvatar). Its parts load into the
## joint chain; each clip moves the parts it should (the chant, the glide, the vent's cycle, the flinch, the death, the
## rise-in); reduced motion is smaller; without the model file a code-made body of the same joints stands in; the VAT
## bake matches the live pose and a VAT avatar keeps the live one's drives; ActorViews draws it and its pulse is the
## sim's (a real World's vent).

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_CINDER_PRIEST

var _vat := false
var _calm := false


func before_each() -> void:
	_vat = ViewPrefs.enemy_vat
	_calm = ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = false
	VatBake.clear_cache()


func after_each() -> void:
	ViewPrefs.enemy_vat = _vat
	ViewPrefs.reduced_motion = _calm
	EnemyModels.dir = EnemyModels.DIR
	EnemyModels.clear_cache()
	VatBake.clear_cache()


func _priest() -> CinderPriestAvatar:
	var a := CinderPriestAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	return a


## Drives `a` through `ticks` ticks (one state and one frame each): `pulse` (permille) and `age` (ticks since the vent
## erupted, -1 none) as callables of the tick, `x` its place's speed (m a tick).
func _run(a: CinderPriestAvatar, ticks: int, pulse: Callable, age: Callable, dx := 0.0) -> void:
	for k in ticks:
		(
			a
			. apply_state(
				{
					"tick": k + 1,
					"state": WorldReader.STATE_MOVE,
					"pos": Vector2(dx * k, 0.0),
					"pulse": pulse.call(k),
					"erupt_age": age.call(k),
					"vent_yaw": 0.6,
				}
			)
		)
		a.advance(DT)


func _d(a: CinderPriestAvatar, drive: int) -> float:
	return a._vd[drive]


func _top(a: CinderPriestAvatar, part: String) -> Vector3:
	return (a.parts[part] as Node3D).global_position


## The lowest vertex height of `mi` (flip 1), or minus its highest (flip -1), posed.
func _lowest(mi: MeshInstance3D, flip: float) -> float:
	var out := INF
	for s in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out = minf(out, (mi.global_transform * v).y * flip)
	return out


func _zero(_k: int) -> int:
	return 0


func _none(_k: int) -> int:
	return -1


func test_the_model_s_parts_load_into_the_joint_chain() -> void:
	assert_true(EnemyModels.has_model(&"cinder_priest"), "the owner's model is installed")
	var a := _priest()
	a.apply_state({"tick": 1, "state": WorldReader.STATE_MOVE})
	assert_true(a.has_model)
	for j: String in ["body", "waist", "hem", "torso", "hood", "arm_l", "arm_r", "staff"]:
		assert_true(a.parts.has(j), "joint %s" % j)
	assert_eq(
		(a.parts["staff"] as Node).get_parent(), a.parts["arm_r"], "the hand carries the staff"
	)
	assert_eq((a.parts["hood"] as Node).get_parent(), a.parts["torso"])
	var meshes := a.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 6, "one mesh per part")
	var glows := {}
	for mi: MeshInstance3D in meshes:
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k)
			if m == a._crystal_mat or m == a._visor_mat:
				glows[mi.get_parent().name] = m
	assert_eq(glows.get(&"Staff"), a._crystal_mat, "the crystal glows on the staff")
	assert_eq(glows.get(&"Hood"), a._visor_mat, "the visor glows on the hood")
	assert_eq(a.body_materials.size(), 2, "the base and the role plates flash")
	var top := 0.0
	for mi: MeshInstance3D in meshes:
		top = maxf(top, _lowest(mi, -1.0) * -1.0)
	assert_almost_eq(top, CinderPriestAvatar.HEIGHT, 0.12, "about its height with the staff")


func test_the_chant_turns_the_free_hand_and_keeps_the_head_bowed() -> void:
	var a := _priest()
	var seen: Array[Vector3] = []
	for k in 120:
		_run(a, 1, _zero, _none)
		seen.append(_top(a, "arm_l") + (a.parts["arm_l"] as Node3D).global_basis.y * -0.4)
		assert_gt(_d(a, CinderPriestAvatar.HOOD_F), 0.1, "the head bowed")
	var spread := AABB(seen[0], Vector3.ZERO)
	for v in seen:
		spread = spread.expand(v)
	assert_gt(spread.size.x, 0.04, "the hand moves forward and back")
	assert_gt(spread.size.z, 0.03, "and out and in: a circle")


func test_the_glide_leans_into_the_travel_and_the_hem_trails() -> void:
	var a := _priest()
	_run(a, 60, _zero, _none, 2.4 / 60.0)
	assert_gt(_d(a, CinderPriestAvatar.LEAN_F), 0.08, "it leans into the travel")
	assert_lt(_d(a, CinderPriestAvatar.HEM_F), -0.08, "its hem trails behind")
	assert_lt(_d(a, CinderPriestAvatar.ARM_L_F), 0.3, "the free arm trails back")


func test_the_staff_rises_through_the_vent_s_warning_and_slams_on_the_eruption() -> void:
	var a := _priest()
	_run(a, 30, _zero, _none)
	var rest_staff := _top(a, "staff").y
	var rest_glow := a.glow_energy()
	_run(a, 1, func(_k: int) -> int: return 800, _none)
	for k in 6:
		_run(a, 1, func(_k: int) -> int: return 800, _none)
	assert_gt(_top(a, "staff").y, rest_staff + 0.15, "the staff is raised")
	assert_gt(a.glow_energy(), rest_glow + 3.0, "the crystal brightens")
	assert_lt(_d(a, CinderPriestAvatar.HOOD_F), 0.0, "it looks up")
	assert_gt(a.vat_lift(), 0.04, "it rises a little")
	assert_gt(_d(a, CinderPriestAvatar.YAW), 0.2, "it turns toward its vent")
	var raised := _top(a, "staff").y
	# The eruption tick: the pulse ends, its vent's last eruption is 0 ticks old.
	_run(a, 1, _zero, _zero)
	assert_lt(_top(a, "staff").y, raised - 0.1, "slammed down on the eruption tick")
	assert_gt(_d(a, CinderPriestAvatar.TORSO_F), 0.35, "it bows into the strike")
	assert_gt(a.glow_energy(), rest_glow + 8.0, "the crystal flares")
	# The recoil and the settle.
	_run(a, 18, _zero, func(k: int) -> int: return k + 1)
	assert_lt(_d(a, CinderPriestAvatar.TORSO_F), 0.2, "it springs back past its rest bow")
	_run(a, 90, _zero, func(k: int) -> int: return k + 19)
	assert_almost_eq(_d(a, CinderPriestAvatar.TORSO_F), 0.1, 0.06, "settled to its chant")
	assert_almost_eq(_top(a, "staff").y, rest_staff, 0.05, "the staff back down")


func test_a_hit_snaps_the_hood_back() -> void:
	var a := _priest()
	_run(a, 30, _zero, _none)
	var rest := _d(a, CinderPriestAvatar.HOOD_F)
	a.flinch(Vector2(1, 0), 1.0)
	a.advance_flinch(0.05)
	a.advance(DT)
	assert_lt(_d(a, CinderPriestAvatar.HOOD_F), rest - 0.3, "the hood snaps back")


func test_the_death_drops_the_staff_and_crumples_the_robe() -> void:
	var a := _priest()
	_run(a, 30, _zero, _none)
	var staff := _top(a, "staff").y
	var head := _top(a, "hood").y
	assert_true(a.die())
	assert_false(a.die(), "once")
	for k in int(CinderPriestAvatar.DEATH_SECONDS / DT) + 2:
		a.advance(DT)
	assert_true(a.dying())
	assert_gt(_d(a, CinderPriestAvatar.CRUMPLE), 0.8, "crumpled into its robe")
	assert_lt(_top(a, "hood").y, head - 0.4, "the head sinks")
	assert_lt(_top(a, "staff").y, staff - 0.4, "the staff falls")
	assert_lt(a.glow_energy(), 0.2, "the crystal's glow dies")
	var hem := a.parts["hem"] as Node3D
	var lowest := INF
	for mi: MeshInstance3D in hem.find_children("*", "MeshInstance3D", true, false):
		lowest = minf(lowest, _lowest(mi, 1.0))
	assert_almost_eq(lowest, 0.0, 0.06, "the hem stays on the floor")


func test_it_rises_out_of_its_robe_when_it_spawns() -> void:
	var a := _priest()
	a.apply_state({"tick": 1, "state": WorldReader.STATE_SPAWN})
	a.advance(DT)
	assert_gt(_d(a, CinderPriestAvatar.CRUMPLE), 0.8, "it starts crumpled")
	for k in 60:
		a.apply_state({"tick": k + 2, "state": WorldReader.STATE_MOVE})
		a.advance(DT)
	assert_lt(_d(a, CinderPriestAvatar.CRUMPLE), 0.01, "risen")


func test_reduced_motion_is_smaller() -> void:
	var ranges: Array[float] = []
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _priest()
		var lo := INF
		var hi := -INF
		for k in 300:
			_run(a, 1, _zero, _none)
			lo = minf(lo, a.vat_lift())
			hi = maxf(hi, a.vat_lift())
		ranges.append(hi - lo)
	assert_lt(ranges[1], ranges[0] * 0.5, "the sway is smaller: %s" % [ranges])
	assert_gt(ranges[1], 0.0, "but still there")
	# The tell stays: the staff still rises.
	var b := _priest()
	_run(b, 10, func(_k: int) -> int: return 800, _none)
	assert_gt(_d(b, CinderPriestAvatar.ARM_R_F), 0.7, "the raise reads with reduced motion too")


func test_without_the_model_a_code_body_of_the_same_joints_stands_in() -> void:
	EnemyModels.dir = "res://tests/no_such_dir/"
	EnemyModels.clear_cache()
	var a := _priest()
	assert_false(a.has_model)
	assert_eq(a.parts.size(), 8, "the same joints")
	assert_gt(a.find_children("*", "MeshInstance3D", true, false).size(), 10, "its own pieces")
	_run(a, 10, func(_k: int) -> int: return 800, _none)
	assert_gt(_d(a, CinderPriestAvatar.ARM_R_F), 0.7, "posed by the same code")
	var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
	assert_eq(
		String(VatBake.rig_of(live)["key"]), "cinder_priest_code", "baked apart from the model's"
	)
	live.free()


func test_the_bake_matches_the_live_pose() -> void:
	assert_true(SoloVat.is_solo(KIND))
	assert_true(VatCrowd.supports(KIND))
	var pose := VatBake.pose_for(KIND)
	assert_true(pose.has("albedo_tex"), "the model's colour map")
	assert_eq(int(pose["drives"]), CinderPriestAvatar.VAT_DRIVES.size())
	var mesh := VatBake.mesh_for(KIND, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
		var vat := VatBake.vat_avatar_of(KIND)
		var e := VatBake.pose_error(live, vat, pose, mesh, 40, 7)
		assert_eq(e["vertices"], mesh.surface_get_array_len(0), "every vertex compared")
		assert_lt(float(e["max_m"]), 0.002, "calm %s: well under a pixel: %s" % [calm, e])
		live.free()
		vat.free()
	var c2: PackedFloat32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM2]
	var sources := {}
	for k in range(0, c2.size(), 4):
		sources[int(c2[k + 2])] = true
	assert_true(sources.has(CinderPriestAvatar.VISOR + 1), "the visor glows at its own drive")


func test_a_vat_avatar_keeps_the_live_drives_lift_and_glow() -> void:
	var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
	var vat := VatBake.vat_avatar_of(KIND)
	add_child_autofree(live)
	add_child_autofree(vat)
	for a: Node in [live, vat]:
		(a as Node).set_process(false)
	for k in 260:
		var pulse := clampi((k - 100) * 1000 / 45, 0, 1000) if k >= 100 and k < 145 else 0
		var age := k - 145 if k >= 145 else -1
		for a: AvatarBase in [live, vat]:
			(
				a
				. apply_state(
					{
						"tick": k,
						"state": WorldReader.STATE_SPAWN if k < 20 else WorldReader.STATE_MOVE,
						"pos": Vector2(0.03 * mini(k, 80), 0.0),
						"pulse": pulse,
						"erupt_age": age,
						"vent_yaw": -0.4,
					}
				)
			)
			if k == 200:
				a.flinch(Vector2(0, 1), 1.0)
			if k == 230:
				(a as CinderPriestAvatar).die()
			a.advance(DT)
			a.advance_flinch(DT)
		assert_eq(vat.call(&"vat_drives"), live.call(&"vat_drives"), "tick %d: drives" % k)
		assert_eq(vat.call(&"vat_lift"), live.call(&"vat_lift"), "tick %d: lift" % k)
		assert_eq(vat.call(&"glow_energy"), live.call(&"glow_energy"), "tick %d: glow" % k)


func test_actor_views_draw_it_and_its_pulse_is_the_sim_s() -> void:
	for on: bool in [false, true]:
		ViewPrefs.enemy_vat = on
		var w := CombatLab.world()
		w.actors.invuln[0] = 1 << 24
		var priest := w.add_enemy(ActorStore.Kind.CINDER_PRIEST, Vector2(-3, 0))
		w.canyon_shore.add_vent(Vector2(-1, 0), 1.0, priest, 120, 180, 45, 10)
		for _t in SimTick.SPAWN_IN_TICKS + 2:
			w.step(InputFrame.new())
		var views: ActorViews = add_child_autofree(ActorViews.new())
		views.set_process(false)
		var reader := WorldReader.new(w)
		views.sync(reader)
		var a := views.actor_node(priest).get_meta(&"enemy_avatar") as CinderPriestAvatar
		assert_not_null(a, "vat %s: its own avatar" % on)
		assert_eq(a.vat, on)
		if on:
			assert_eq(views.vat_crowd.count(), 1, "drawn by the crowd")
		var seen_pulse := false
		var seen_strike := false
		for _t in 200:
			w.step(InputFrame.new())
			views.sync(reader)
			a.advance(DT)
			var i := w.actors.index_of(priest)
			if reader.priest_pulse(i) > 0:
				seen_pulse = true
				assert_almost_eq(
					a._pulse, reader.priest_pulse(i) / 1000.0, 0.0001, "the sim's pulse"
				)
			if a._erupt_s >= 0.0:
				seen_strike = true
		assert_true(seen_pulse, "the vent's warning was read")
		assert_true(seen_strike, "and its eruption")


func _caster() -> CinderPriestAvatar:
	var a := CinderPriestAvatar.new()
	a.kind = WorldReader.KIND_ARC_CASTER
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	return a


## v0.11.0 F6: the Arc Caster is this model in its own palette; the Priest keeps its look.
func test_the_arc_caster_wears_the_model_in_its_own_colours() -> void:
	var priest := _priest()
	var caster := _caster()
	assert_eq(priest.has_model, caster.has_model)
	var pc: Color = priest.palette["role"]
	var cc: Color = caster.palette["role"]
	assert_eq(pc, CinderPriestAvatar.ROLE, "the Priest keeps its violet")
	assert_ne(cc, pc, "the caster's plates differ")
	assert_ne(caster.palette["gem"], priest.palette["gem"], "and its gem")
	assert_true(SoloVat.is_solo(WorldReader.KIND_ARC_CASTER))
	assert_true(SoloVat.vat_avatar_of(WorldReader.KIND_ARC_CASTER) is CinderPriestAvatar)
	var rig_c: Dictionary = caster.vat_rig()
	var rig_p: Dictionary = priest.vat_rig()
	assert_ne(rig_c["key"], rig_p["key"], "a rig per kind")


func test_the_caster_gathers_in_its_windup_and_strikes_on_the_shot() -> void:
	var a := _caster()
	for k in 40:
		a.apply_state({"tick": k, "state": WorldReader.STATE_MOVE})
		a.advance(DT)
	var rest := a.glow_energy()
	var raised := 0.0
	for k in 30:
		a.apply_state(
			{"tick": 40 + k, "state": WorldReader.STATE_WINDUP, "pulse": (k + 1) * 1000 / 30}
		)
		a.advance(DT)
		raised = maxf(raised, a._vd[CinderPriestAvatar.STAFF_F])
	assert_gt(a.glow_energy(), rest + 2.0, "the crystal brightens through the windup")
	assert_gt(raised, 0.5, "the staff comes up")
	a.apply_state({"tick": 70, "state": WorldReader.STATE_ACTIVE})
	a.advance(DT)
	assert_gt(a.glow_energy(), rest + 5.0, "the shot flares the crystal")
	for k in 120:
		a.apply_state({"tick": 71 + k, "state": WorldReader.STATE_RECOVER})
		a.advance(DT)
	assert_lt(a.glow_energy(), rest + 1.0, "and settles back")
