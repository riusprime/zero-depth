extends GutTest
## v0.11.0 O17b: the Rock Lurker on the owner's model (RockLurkerAvatar). Its parts load onto their joints with their
## surfaces; each clip moves the joints it should (the disguise, the rumble, the burst, the slam's rear-up and smash,
## the knuckle walk, the idle breath, the flinch, the death); reduced motion drops the shudders and shrinks the
## secondary motion; without the model file it builds its stand-in on the same joints; on the VAT path it bakes within
## a fraction of a pixel, a VAT avatar keeps the old one's drives, and ActorViews draws it through the crowd and lets it
## collapse when it dies.

const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_ROCK_LURKER

var _vat := false
var _calm := false
var _tick := 0


func before_each() -> void:
	_vat = ViewPrefs.enemy_vat
	_calm = ViewPrefs.reduced_motion
	ViewPrefs.reduced_motion = false
	VatBake.clear_cache()
	_tick = 0


func after_each() -> void:
	ViewPrefs.enemy_vat = _vat
	ViewPrefs.reduced_motion = _calm
	EnemyModels.dir = EnemyModels.DIR
	EnemyModels.clear_cache()


func _lurker(hidden := false) -> RockLurkerAvatar:
	var a := RockLurkerAvatar.new()
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	_step(a, {"state": WorldReader.STATE_MOVE, "hidden": hidden})
	return a


func _step(a: RockLurkerAvatar, s: Dictionary, x := 0.0) -> void:
	_tick += 1
	var d := s.duplicate()
	d["tick"] = _tick
	d["pos"] = Vector2(x, 0.0)
	a.apply_state(d)
	a.advance(DT)


func _run(a: RockLurkerAvatar, s: Dictionary, n: int) -> void:
	for k in n:
		_step(a, s)


## The largest and smallest value drive `d` takes over `n` ticks in state `s`.
func _span(a: RockLurkerAvatar, s: Dictionary, n: int, d: int) -> Vector2:
	var lo := INF
	var hi := -INF
	for k in n:
		_step(a, s)
		lo = minf(lo, a.drives()[d])
		hi = maxf(hi, a.drives()[d])
	return Vector2(lo, hi)


func test_the_owner_s_model_loads_onto_its_joints() -> void:
	assert_true(EnemyModels.has_model(&"rock_lurker"), "the model file is installed")
	var a := _lurker()
	assert_true(a.has_model)
	for j: Node3D in [a.body, a.head] + Array(a.arms) + Array(a.hands) + Array(a.legs):
		var meshes := j.find_children("*", "MeshInstance3D", false, false)
		assert_eq(meshes.size(), 1, "%s carries its part" % j.name)
	assert_eq(a.body_materials.size(), 2, "base and role are the body plates (the hit flash)")
	var shell := a.body.get_node("Mesh") as MeshInstance3D
	var glows := 0
	for k in shell.mesh.get_surface_count():
		var m := shell.get_surface_override_material(k) as StandardMaterial3D
		if m.emission_energy_multiplier > 0.0 and m.albedo_texture == null:
			glows += 1
			assert_eq(
				m.get_meta(SoloVat.GLOW),
				RockLurkerAvatar.CRACK + 1,
				"the cracks glow at their drive"
			)
	assert_eq(glows, 1, "the shell has its crack ribbons")
	assert_almost_eq(
		(
			EnemyModels.get_model(&"rock_lurker")["height"]
			* EnemyModels.get_model(&"rock_lurker")["scale"]
		),
		RockLurkerAvatar.HEIGHT,
		0.001
	)


func test_disguised_it_sinks_folds_and_draws_its_face_in() -> void:
	var out := _lurker()
	_run(out, {"state": WorldReader.STATE_MOVE}, 30)
	var hid := _lurker(true)
	_run(hid, {"state": WorldReader.STATE_MOVE, "hidden": true}, 30)
	assert_eq(hid.amounts()["tuck"], 1.0)
	assert_lt(hid.body.position.y, out.body.position.y - 0.2, "sunk to the ground")
	assert_gt(hid.drives()[RockLurkerAvatar.HX], 0.2, "its face drawn in under the rock")
	assert_lt(
		hid.drives()[RockLurkerAvatar.AS_R], out.drives()[RockLurkerAvatar.AS_R] - 0.8, "arms back"
	)
	assert_lt(hid.crack_energy(), out.crack_energy(), "its cracks only faint")
	var still := _span(
		hid, {"state": WorldReader.STATE_MOVE, "hidden": true}, 120, RockLurkerAvatar.BY
	)
	assert_almost_eq(still.x, still.y, 0.0001, "perfectly still")


func test_the_rumble_lifts_shudders_and_pulses_the_cracks() -> void:
	var a := _lurker(true)
	_run(a, {"state": WorldReader.STATE_MOVE, "hidden": true}, 10)
	var rest_y := a.drives()[RockLurkerAvatar.BY]
	var s := {"state": WorldReader.STATE_MOVE, "hidden": true, "rumbling": true}
	_run(a, s, 30)
	var peak := 0.0
	for k in 60:
		_step(a, s)
		peak = maxf(peak, a.crack_energy())
	assert_gte(peak, RockLurkerAvatar.CRACK_RUMBLE, "the cracks pulse up")
	assert_gt(a.drives()[RockLurkerAvatar.BY], rest_y + 0.01, "the rock lifts a little")
	var shake := _span(a, s, 30, RockLurkerAvatar.BX)
	assert_gt(shake.y - shake.x, 0.01, "it shudders")
	ViewPrefs.reduced_motion = true
	var calm := _span(a, s, 30, RockLurkerAvatar.BX)
	assert_almost_eq(calm.y - calm.x, 0.0, 0.0001, "no shudder with reduced motion")


func test_the_burst_heaves_it_out() -> void:
	var a := _lurker(true)
	_run(a, {"state": WorldReader.STATE_MOVE, "hidden": true}, 20)
	var top := -INF
	for k in 40:
		_step(a, {"state": WorldReader.STATE_MOVE, "hidden": false})
		top = maxf(top, a.drives()[RockLurkerAvatar.BY])
	assert_gt(top, 0.03, "the rock heaves up above its stance")
	assert_eq(a.amounts()["tuck"], 0.0, "out")
	assert_lt(a.drives()[RockLurkerAvatar.HX], 0.05, "its face out")


func test_the_slam_rears_back_then_smashes_down_in_front() -> void:
	var a := _lurker()
	_run(a, {"state": WorldReader.STATE_MOVE}, 20)
	for k in range(1, 31):
		_step(a, {"state": WorldReader.STATE_WINDUP, "windup": k / 30.0})
		if k == 18:
			assert_gt(a.amounts()["rear"], 0.95, "reared by 55 % of the windup")
	assert_gt(a.drives()[RockLurkerAvatar.BP], 0.5, "pitched back on its hind legs")
	assert_gt(a.drives()[RockLurkerAvatar.AS_R], 1.3, "both arms overhead")
	assert_gt(a.drives()[RockLurkerAvatar.AS_L], 1.3)
	assert_gt(a.visor_energy(), RockLurkerAvatar.VISOR_REST * 2.0, "the visor flashes")
	_step(a, {"state": WorldReader.STATE_ACTIVE})
	_run(a, {"state": WorldReader.STATE_RECOVER}, 6)
	assert_gt(a.amounts()["slam"], 0.95, "the smash is down")
	assert_lt(a.drives()[RockLurkerAvatar.BP], -0.05, "pitched forward")
	assert_between(a.drives()[RockLurkerAvatar.AS_R], 0.2, 0.6, "claws down in front")
	_run(a, {"state": WorldReader.STATE_RECOVER}, 42)
	_run(a, {"state": WorldReader.STATE_MOVE}, 40)
	assert_lt(a.amounts()["slam"], 0.05, "back up after the recovery")


func test_the_knuckle_walk_swings_the_arms_in_turn() -> void:
	var a := _lurker()
	var x := 0.0
	var opposite := 0
	for k in 120:
		x += 2.2 * DT
		_step(a, {"state": WorldReader.STATE_MOVE}, x)
		if k > 60:
			var r := a.drives()[RockLurkerAvatar.AS_R]
			var l := a.drives()[RockLurkerAvatar.AS_L]
			if absf(r - l) > 0.5:
				opposite += 1
	assert_gt(a.amounts()["walk"], 0.8, "walking at its speed")
	assert_gt(opposite, 10, "one arm reaches while the other plants")


func test_idle_it_breathes() -> void:
	var a := _lurker()
	_run(a, {"state": WorldReader.STATE_MOVE}, 30)
	var b := _span(a, {"state": WorldReader.STATE_MOVE}, 150, RockLurkerAvatar.BY)
	assert_between(b.y - b.x, 0.015, 0.05, "a slow heavy breath")


func test_a_hit_recoils_its_face() -> void:
	var a := _lurker()
	_run(a, {"state": WorldReader.STATE_MOVE}, 30)
	var rest := a.drives()[RockLurkerAvatar.HX]
	assert_true(a.flinch(Vector2(1, 0), 1.0))
	a.advance_flinch(0.05)
	a.advance(0.0001)
	assert_gt(a.drives()[RockLurkerAvatar.HX], rest + 0.03, "the face recoils under the rock")


func test_death_collapses_it_into_a_dark_rock() -> void:
	var a := _lurker()
	_run(a, {"state": WorldReader.STATE_MOVE}, 30)
	assert_true(a.die())
	assert_false(a.die(), "once")
	for k in int(RockLurkerAvatar.DEATH_SECONDS / DT):
		a.advance(DT)
	assert_lt(a.drives()[RockLurkerAvatar.BY], -0.2, "down on the ground")
	assert_lt(a.crack_energy(), 0.05, "its glow gone")
	assert_lt(a.visor_energy(), 0.05)


func test_reduced_motion_is_calmer() -> void:
	var a := _lurker()
	_run(a, {"state": WorldReader.STATE_MOVE}, 20)
	var x := 0.0
	var roll := 0.0
	for k in 120:
		x += 2.2 * DT
		_step(a, {"state": WorldReader.STATE_MOVE}, x)
		roll = maxf(roll, absf(a.drives()[RockLurkerAvatar.BR]))
	ViewPrefs.reduced_motion = true
	var calm_roll := 0.0
	for k in 120:
		x += 2.2 * DT
		_step(a, {"state": WorldReader.STATE_MOVE}, x)
		calm_roll = maxf(calm_roll, absf(a.drives()[RockLurkerAvatar.BR]))
	assert_lt(calm_roll, roll * 0.6, "the walk's roll smaller")
	var b := _lurker()
	_run(b, {"state": WorldReader.STATE_MOVE}, 20)
	for k in range(1, 30):
		_step(b, {"state": WorldReader.STATE_WINDUP, "windup": k / 30.0})
	var hold := _span(
		b, {"state": WorldReader.STATE_WINDUP, "windup": 0.99}, 10, RockLurkerAvatar.BR
	)
	assert_almost_eq(hold.y - hold.x, 0.0, 0.0001, "no tremble in the beat")


func test_without_the_model_it_builds_its_stand_in() -> void:
	EnemyModels.dir = "res://tests/fixtures/no_models/"
	EnemyModels.clear_cache()
	var a := _lurker()
	assert_false(a.has_model)
	assert_gt(
		a.body.find_children("*", "MeshInstance3D", false, false).size(), 1, "a boulder with cracks"
	)
	for j: Node3D in [a.head] + Array(a.hands) + Array(a.legs):
		assert_gt(
			j.find_children("*", "MeshInstance3D", false, false).size(), 0, "%s drawn" % j.name
		)
	_run(a, {"state": WorldReader.STATE_MOVE, "hidden": true}, 45)
	assert_almost_eq(a.amounts()["tuck"], 1.0, 0.0001, "it still hides")
	assert_null(a.vat_texture())


func test_it_bakes_within_a_fraction_of_a_pixel_and_keeps_its_drives() -> void:
	assert_true(VatCrowd.supports(KIND))
	assert_true(SoloVat.is_solo(KIND))
	var pose := VatBake.pose_for(KIND)
	assert_true(pose.has("albedo_tex"), "the model's colour map")
	var mesh := VatBake.mesh_for(KIND, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var live := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
	var vat := VatBake.vat_avatar_of(KIND)
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var e := VatVerify.pose_error(live, vat, pose, mesh, 40, 7)
		assert_eq(e["vertices"], mesh.surface_get_array_len(0), "every vertex compared")
		assert_lt(float(e["max_m"]), 0.002, "well under a pixel (calm %s): %s" % [calm, e])
	live.free()
	vat.free()
	ViewPrefs.reduced_motion = false
	var a := VatBake.reference_of(KIND, Color(0, 0, 0, 0), 0.0)
	var b := VatBake.vat_avatar_of(KIND)
	add_child_autofree(a)
	add_child_autofree(b)
	a.set_process(false)
	b.set_process(false)
	assert_eq(
		b.find_children("*", "MeshInstance3D", true, false).size(), 0, "a VAT avatar has no pieces"
	)
	var plan := [
		[20, {"state": WorldReader.STATE_SPAWN, "hidden": true}],
		[40, {"state": WorldReader.STATE_MOVE, "hidden": true, "rumbling": true}],
		[30, {"state": WorldReader.STATE_WINDUP, "hidden": false}],
		[1, {"state": WorldReader.STATE_ACTIVE}],
		[48, {"state": WorldReader.STATE_RECOVER}],
		[30, {"state": WorldReader.STATE_MOVE}],
	]
	var t := 0
	for step: Array in plan:
		for k in int(step[0]):
			t += 1
			var s: Dictionary = (step[1] as Dictionary).duplicate()
			s["tick"] = t
			s["pos"] = Vector2(0.03 * t, 0.0)
			s["windup"] = float(k + 1) / 30.0
			for av: AvatarBase in [a, b]:
				av.call(&"apply_state", s)
				av.advance(DT)
			assert_eq(b.call(&"vat_drives"), a.call(&"vat_drives"), "tick %d: drives" % t)
			assert_eq(b.call(&"vat_lift"), a.call(&"vat_lift"), "tick %d: lift" % t)
			assert_eq(b.call(&"glow_energy"), a.call(&"glow_energy"), "tick %d: glow" % t)


func test_actor_views_draw_it_through_the_crowd_and_let_it_collapse() -> void:
	ViewPrefs.enemy_vat = true
	var w := CombatLab.world()
	var id := w.add_enemy(ActorStore.Kind.ROCK_LURKER, Vector2(3.0, 3.0))
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	var node := views.actor_node(id)
	var a := node.get_meta(&"enemy_avatar") as RockLurkerAvatar
	assert_not_null(a, "its own avatar")
	assert_true(a.vat)
	assert_eq(views.vat_crowd.count(), 1)
	views.vat_crowd._process(DT)
	assert_eq(views.vat_crowd.drawn, 1)
	var inst := views.vat_crowd.instance_of(a)
	assert_eq(
		(inst["drives"] as PackedFloat32Array).slice(0, RockLurkerAvatar.VAT_DRIVES.size()),
		a.vat_drives()
	)
	views.flash(id)
	views.vat_crowd._process(DT)
	assert_lt((views.vat_crowd.instance_of(a)["color"] as Color).a, 0.0, "the hit shows")
	for t in w.tuning.spawn_in_ticks + 1:  # past the spawn's grace, then killed
		w.step(InputFrame.new())
	var i := w.actors.index_of(id)
	var at := w.actors.pos(i)
	Damage.hit(w, i, 1 << 20, 0, 0, w.take_root(), 0, at, at)
	for t in 120:
		if w.actors.index_of(id) < 0:
			break
		w.step(InputFrame.new())
	assert_lt(w.actors.index_of(id), 0, "the sim let it go")
	views.sync(WorldReader.new(w))
	views.vat_crowd._process(DT)
	assert_true(a.dying(), "it collapses")
	assert_false(views.vat_crowd.instance_of(a).is_empty(), "drawn while it collapses")
	ViewPrefs.enemy_vat = false
