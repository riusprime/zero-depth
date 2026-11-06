extends GutTest
## v0.10.5 W3-V1 (owner, 2026-11-06: the enemy VAT pilot): the Swarmer drawn as one MultiMesh posed from its baked
## pose code (VatBake, VatLooks, VatCrowd) behind ViewPrefs.enemy_vat, the old path the default. The bake matches the
## live pose (the shader's arithmetic run on the CPU), a VAT avatar keeps every drive the old one shows, and ActorViews
## draws, flashes, flinches and rebuilds them through the crowd.
## v0.10.5 W3-V4a: the same for the Charger and the Hatchling (ChargerVat's rig: twelve drives, the eight past the
## fourth in a drive texture), and the old Charger pose is untouched (test_charger_pose_hv).

const SW := ActorStore.Kind.SWARMER
const CH := ActorStore.Kind.CHARGER
const DT := 1.0 / 60.0

var _vat := false
var _calm := false


func before_each() -> void:
	_vat = ViewPrefs.enemy_vat
	_calm = ViewPrefs.reduced_motion
	VatBake.clear_cache()


func after_each() -> void:
	ViewPrefs.enemy_vat = _vat
	ViewPrefs.reduced_motion = _calm


func test_the_old_path_stays_the_default() -> void:
	assert_eq(GameSettings.DEFAULTS["enemy_vat"], "off")
	var p := ProfileStore.new("")
	ViewPrefs.apply_settings(p)
	assert_false(ViewPrefs.enemy_vat, "off unless the owner turns it on")
	p.section("settings")["enemy_vat"] = "on"
	ViewPrefs.apply_settings(p)
	assert_true(ViewPrefs.enemy_vat)
	assert_true(DebugApi.view_switches.has(&"enemy_vat"), "the dev panel's switch")
	ViewPrefs.flip_enemy_vat()
	assert_false(ViewPrefs.enemy_vat)


func test_the_bake_matches_the_live_pose() -> void:
	var pose := VatBake.pose_for(SW)
	var mesh := VatBake.mesh_for(SW, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var live := VatBake.reference_avatar(SW, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var vat := HordeAvatar.new()
	vat.vat = true
	vat.setup(SW, Color.BLACK)
	var e := VatBake.pose_error(live, vat, pose, mesh, 120, 7)
	assert_eq(e["vertices"], mesh.surface_get_array_len(0), "every vertex compared")
	# 2 mm: about an eighth of a pixel at the game's camera (17 m over 1080 px); the report gives the real number.
	assert_lt(float(e["max_m"]), 0.002, "within 2 mm: %s" % [e])
	# On a grid point the bake is the pose itself.
	live.pose_at(0.5, 0.25, 0.5, 0.0, 1.0)
	vat.pose_at(0.5, 0.25, 0.5, 0.0, 1.0)
	var a := VatBake.live_vertices(live)
	var b := VatBake.eval_vertices(pose, mesh, Vector4(0.5, 0.25, 0.5, 0.0), vat.vat_lift())
	var worst := 0.0
	for k in a.size():
		worst = maxf(worst, a[k].distance_to(b[k]))
	assert_lt(worst, 1e-5, "exact on the grid")
	live.free()
	vat.free()


func test_a_vat_avatar_has_no_pieces_and_the_same_drives() -> void:
	var live := HordeAvatar.new()
	live.setup(SW, Color.BLACK)
	var vat := HordeAvatar.new()
	vat.vat = true
	vat.setup(SW, Color.BLACK)
	add_child_autofree(live)
	add_child_autofree(vat)
	live.set_process(false)
	vat.set_process(false)
	assert_eq(vat.find_children("*", "MeshInstance3D", true, false).size(), 0, "no pieces")
	assert_eq(vat.height, live.height, "the bar's height")
	var states := [
		EnemyAi.State.MOVE, EnemyAi.State.WINDUP, EnemyAi.State.ACTIVE, EnemyAi.State.RECOVER
	]
	for k in 120:
		var st: int = states[mini(int(k / 30.0), 3)]
		var p := clampf(float(k - 30) / 30.0, 0.0, 1.0) if st == EnemyAi.State.WINDUP else 0.0
		for a: HordeAvatar in [live, vat]:
			a.apply_state({"tick": k, "state": st, "windup": p})
			a.advance(DT)
		assert_eq(vat.windup_pose(), live.windup_pose(), "tick %d: the raise" % k)
		assert_eq(vat.strike_pose(), live.strike_pose(), "tick %d: the strike" % k)
		assert_eq(vat.crouch_amount(), live.crouch_amount(), "tick %d: the crouch" % k)
		assert_eq(vat.glow_energy(), live.glow_energy(), "tick %d: the glow" % k)
		assert_eq(vat.anim_time(), live.anim_time(), "tick %d: the clock" % k)
	var bob := sin(live.anim_time() * HordeAvatar.BOB_RATE) * HordeAvatar.BOB_M
	assert_almost_eq(vat.vat_lift(), bob, 1e-6, "risen: the lift is the bob")


func _views(swarmers: int) -> Array:
	var w := CombatLab.world()
	var ids: Array[int] = []
	for k in swarmers:
		ids.append(w.add_enemy(SW, Vector2(2.0 + k, 3.0)))
	ids.append(w.add_enemy(ActorStore.Kind.CHARGER, Vector2(-3.0, 3.0)))
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	return [views, ids, w]


func test_actor_views_draw_vat_swarmers_through_one_multimesh() -> void:
	ViewPrefs.enemy_vat = true
	var made := _views(3)
	var views: ActorViews = made[0]
	var ids: Array[int] = made[1]
	assert_not_null(views.vat_crowd, "a crowd")
	assert_eq(views.vat_crowd.count(), 4, "the three Swarmers and (v0.10.5 W3-V4a) the Charger")
	assert_eq(views.vat_crowd.looks(), 2, "one look per kind, one MultiMesh each")
	for k in 3:
		var node := views.actor_node(ids[k])
		var avatar := node.get_meta(&"enemy_avatar") as HordeAvatar
		assert_true(avatar.vat)
		assert_eq(avatar.find_children("*", "MeshInstance3D", true, false).size(), 0)
		assert_null(
			node.find_child(String(EnemyShadows.PROXY_NAME), true, false), "the crowd casts it"
		)
	var charger := views.actor_node(ids[3]).get_meta(&"enemy_avatar") as ChargerAvatar
	assert_true(charger.vat, "v0.10.5 W3-V4a: the Charger too")
	assert_eq(charger.find_children("*", "MeshInstance3D", true, false).size(), 0)
	views.vat_crowd._process(DT)
	assert_eq(views.vat_crowd.drawn, 4)
	assert_eq(views.vat_crowd.shadows_drawn, 4, "their proxy shadows")
	var first := views.actor_node(ids[0])
	var inst := views.vat_crowd.instance_of(first.get_meta(&"enemy_avatar"))
	var at: Vector3 = (inst["xf"] as Transform3D).origin
	assert_almost_eq(
		Vector2(at.x, at.z), Vector2(first.position.x, first.position.z), Vector2.ONE * 1e-3
	)


func test_the_flash_and_the_flinch_reach_the_instance() -> void:
	ViewPrefs.enemy_vat = true
	var made := _views(1)
	var views: ActorViews = made[0]
	var id: int = made[1][0]
	var avatar := views.actor_node(id).get_meta(&"enemy_avatar") as HordeAvatar
	views.vat_crowd._process(DT)
	var rest: Dictionary = views.vat_crowd.instance_of(avatar)
	assert_gte((rest["color"] as Color).a, 0.0, "no hit shown: the alpha is the glow")
	views.flash(id)
	views.vat_crowd._process(DT)
	var lit: Color = views.vat_crowd.instance_of(avatar)["color"]
	assert_lt(lit.a, 0.0, "the hit shows")
	assert_gt(lit.r, 0.5, "white, at its energy")
	assert_true(avatar.flinch(Vector2.RIGHT, 1.0))
	avatar.advance_flinch(0.05)
	views.vat_crowd._process(DT)
	var bent: Transform3D = views.vat_crowd.instance_of(avatar)["xf"]
	assert_false(
		bent.basis.is_equal_approx((rest["xf"] as Transform3D).basis),
		"the flinch leans the instance"
	)


func test_flipping_the_switch_rebuilds_them_on_the_old_path() -> void:
	ViewPrefs.enemy_vat = true
	var made := _views(2)
	var views: ActorViews = made[0]
	var ids: Array[int] = made[1]
	var w: World = made[2]
	var before := views.actor_node(ids[0])
	ViewPrefs.enemy_vat = false
	views.sync(WorldReader.new(w))
	var after := views.actor_node(ids[0])
	assert_ne(after, before, "built again")
	var avatar := after.get_meta(&"enemy_avatar") as HordeAvatar
	assert_false(avatar.vat)
	assert_gt(
		avatar.find_children("*", "MeshInstance3D", true, false).size(), 3, "its pieces again"
	)
	views.vat_crowd._process(DT)
	assert_eq(views.vat_crowd.count(), 0, "the crowd let them go")
	assert_eq(views.vat_crowd.drawn, 0)


# --- v0.10.5 W3-V4a: the Charger and the Hatchling ----------------------------------------------------------------


func test_the_charger_bake_matches_the_live_pose() -> void:
	for kind: int in [CH, ActorStore.Kind.HATCHLING]:
		var pose := VatBake.pose_for(kind)
		var mesh := VatBake.mesh_for(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var live := VatBake.reference_of(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var vat := VatBake.vat_avatar_of(kind, Color.BLACK)
		assert_eq(pose["key"], "charger", "the Charger and the Hatchling share one bake")
		assert_eq(int(pose["drive_texels"]), 2, "eight drives past the fourth")
		assert_true(mesh.get_meta(&"two_sided"), "its shell is drawn from both sides")
		var e := VatBake.pose_error(live, vat, pose, mesh, 60, 11)
		assert_eq(e["vertices"], mesh.surface_get_array_len(0), "every vertex compared")
		# 15.7 mm is a pixel at the game's camera; the report gives the real number.
		assert_lt(float(e["max_m"]), 0.008, "under half a pixel: %s" % [e])
		live.free()
		vat.free()


func test_a_vat_charger_has_no_pieces_and_the_same_drives() -> void:
	var live := ChargerAvatar.new()
	live.setup(Color.BLACK)
	var vat := ChargerAvatar.new()
	vat.vat = true
	vat.setup(Color.BLACK)
	add_child_autofree(live)
	add_child_autofree(vat)
	live.set_process(false)
	vat.set_process(false)
	assert_eq(vat.find_children("*", "Node3D", true, false).size(), 0, "no nodes at all")
	var states := [
		EnemyAi.State.SPAWN,
		EnemyAi.State.MOVE,
		EnemyAi.State.WINDUP,
		EnemyAi.State.ACTIVE,
		EnemyAi.State.RECOVER,
		EnemyAi.State.MOVE,
	]
	for k in 180:
		var st: int = states[mini(int(k / 30.0), 5)]
		var p := clampf(float(k - 60) / 30.0, 0.0, 1.0) if st == EnemyAi.State.WINDUP else 0.0
		for a: ChargerAvatar in [live, vat]:
			a.apply_state({"tick": k, "pos": Vector2(0.05 * k, 0.0), "state": st, "windup": p})
			a.advance(DT)
		assert_eq(vat.vat_drives(), live.vat_drives(), "tick %d: the drives" % k)
		assert_eq(vat.vat_lift(), live.vat_lift(), "tick %d: the lift" % k)
		assert_eq(vat.visor_energy(), live.visor_energy(), "tick %d: the visor" % k)
		assert_eq(vat.windup_amount(), live.windup_amount(), "tick %d: the raise" % k)
	assert_almost_eq(live.vat_lift(), live._model.position.y, 1e-6, "the lift is the sink")


func test_actor_views_draw_vat_chargers_and_hatchlings() -> void:
	ViewPrefs.enemy_vat = true
	var w := CombatLab.world()
	var ids: Array[int] = []
	ids.append(w.add_enemy(CH, Vector2(2.0, 3.0)))
	ids.append(w.add_enemy(CH, Vector2(4.0, 3.0)))
	ids.append(w.add_enemy(ActorStore.Kind.HATCHLING, Vector2(-2.0, 3.0)))
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	assert_eq(views.vat_crowd.count(), 3)
	assert_eq(views.vat_crowd.looks(), 2, "a look per kind (their palettes differ)")
	for id in ids:
		var node := views.actor_node(id)
		var avatar := node.get_meta(&"enemy_avatar") as ChargerAvatar
		assert_true(avatar.vat)
		if avatar.kind == WorldReader.KIND_CHARGER:
			assert_true(node.has_meta(&"dazed"), "the dazed ring stays the actor's")
	views.vat_crowd._process(DT)
	assert_eq(views.vat_crowd.drawn, 3)
	var hatch := views.actor_node(ids[2]).get_meta(&"enemy_avatar") as ChargerAvatar
	var inst := views.vat_crowd.instance_of(hatch)
	assert_almost_eq(
		(inst["xf"] as Transform3D).basis.get_scale(),
		Vector3.ONE * 0.66,
		Vector3.ONE * 1e-3,
		"the Hatchling at two thirds of the size"
	)
	assert_eq(inst["drives"] as PackedFloat32Array, hatch.vat_drives(), "all twelve drives sent")
	views.flash(ids[0])
	views.vat_crowd._process(DT)
	var first := views.actor_node(ids[0]).get_meta(&"enemy_avatar") as ChargerAvatar
	assert_lt((views.vat_crowd.instance_of(first)["color"] as Color).a, 0.0, "the hit shows")
