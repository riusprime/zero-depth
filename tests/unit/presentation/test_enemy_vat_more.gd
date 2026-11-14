extends GutTest
## v0.10.5 W3-V4c (owner, 2026-11-06: VAT for every regular enemy): the Needle, the Warden, the Arc Caster and the Bomb
## Drone on the general VAT path (SoloVat's one-number joints). The bake matches the live pose (the shader's arithmetic
## run on the CPU), a VAT avatar keeps the old one's drives, lift and glows through a fight, the pieces' looks come
## from their own materials (the role glow, the Warden's facet colours, the unshaded glows, the Needle's muzzle on its
## own drive), and ActorViews draws, flashes and tints them through the crowd while their kept nodes stay nodes.

const DT := 1.0 / 60.0
const SOLO: Array[int] = [
	WorldReader.KIND_NEEDLE,
	WorldReader.KIND_WARDEN,
	WorldReader.KIND_ARC_CASTER,
	WorldReader.KIND_BOMB_DRONE,
	WorldReader.KIND_LENS_DRONE,
]

var _vat := false
var _calm := false


func before_each() -> void:
	_vat = ViewPrefs.enemy_vat
	_calm = ViewPrefs.reduced_motion
	VatBake.clear_cache()


func after_each() -> void:
	ViewPrefs.enemy_vat = _vat
	ViewPrefs.reduced_motion = _calm


func test_every_stand_alone_kind_is_a_vat_kind() -> void:
	for kind in SOLO:
		assert_true(VatCrowd.supports(kind), "kind %d" % kind)


func test_the_bake_matches_the_live_pose() -> void:
	for kind in SOLO:
		var pose := VatBake.pose_for(kind)
		var mesh := VatBake.mesh_for(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
		var live := VatBake.reference_of(kind, Color(0, 0, 0, 0), 0.0)
		var vat := VatBake.vat_avatar_of(kind)
		var e := VatVerify.pose_error(live, vat, pose, mesh, 40, 5)
		assert_eq(
			e["vertices"], mesh.surface_get_array_len(0), "kind %d: every vertex compared" % kind
		)
		# 15.7 mm is a pixel at the game's camera; the report gives the real number.
		assert_lt(float(e["max_m"]), 0.002, "kind %d: well under a pixel: %s" % [kind, e])
		live.free()
		vat.free()


func test_the_needle_sends_nineteen_drives_and_its_muzzle_on_its_own() -> void:
	var pose := VatBake.pose_for(WorldReader.KIND_NEEDLE)
	assert_eq(int(pose["drives"]), 19)
	assert_eq(int(pose["drive_texels"]), 4, "fifteen past the fourth")
	var mesh := VatBake.mesh_for(WorldReader.KIND_NEEDLE, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var c2: PackedFloat32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM2]
	var sources := {}
	for k in range(0, c2.size(), 4):
		sources[int(c2[k + 2])] = true
	assert_true(sources.has(NeedleAvatar.MUZZLE + 1), "the bore glows at the MUZZLE drive")
	assert_true(sources.has(0), "the rest at the instance's glow")


func test_the_pieces_keep_their_own_looks() -> void:
	# The Warden: its rocks take their facet colours; its cracks are unshaded; nothing is kept but the dust ring.
	var warden := VatBake.mesh_for(WorldReader.KIND_WARDEN, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var arrays := warden.surface_get_arrays(0)
	var c0: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var c2: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM2]
	var greys := {}
	var unshaded := 0
	for k in range(0, c0.size(), 4):
		greys[snappedf(c0[k], 0.001)] = true
		if c2[k + 3] > 0.5:
			unshaded += 1
	assert_gt(greys.size(), 10, "the facets read apart (vertex colours)")
	assert_gt(unshaded, 0, "the cracks draw their colour as is")
	# A role-coloured plate glows at the role glow's energy of its own colour at rest.
	var lit := VatBake.mesh_for(WorldReader.KIND_NEEDLE, Color(0, 0, 0, 0), 0.45, Color.BLACK)
	var e1: PackedFloat32Array = lit.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM1]
	var glow := 0.0
	for k in range(0, e1.size(), 4):
		glow = maxf(glow, e1[k])
	assert_gt(glow, 0.0, "the role glow is baked into the plates")


func test_a_vat_avatar_keeps_the_old_drives_lift_and_glow() -> void:
	var states := [
		EnemyAi.State.SPAWN,
		EnemyAi.State.MOVE,
		EnemyAi.State.WINDUP,
		EnemyAi.State.ACTIVE,
		EnemyAi.State.RECOVER,
		EnemyAi.State.MOVE,
	]
	for kind in SOLO:
		var live := VatBake.reference_of(kind, Color(0, 0, 0, 0), 0.0)
		var vat := VatBake.vat_avatar_of(kind)
		add_child_autofree(live)
		add_child_autofree(vat)
		live.set_process(false)
		vat.set_process(false)
		var kept := vat.find_children("*", "MeshInstance3D", true, false)
		for n in kept:
			assert_true(
				n.has_meta(SoloVat.LIVE), "kind %d: only its kept nodes (%s)" % [kind, n.name]
			)
		for k in 180:
			var st: int = states[mini(int(k / 30.0), 5)]
			var p := clampf(float(k - 60) / 30.0, 0.0, 1.0) if st == EnemyAi.State.WINDUP else 0.0
			for a: Node in [live, vat]:
				a.call(
					&"apply_state",
					{
						"tick": k,
						"pos": Vector2(0.04 * k, 0.0),
						"state": st,
						"windup": p,
						"radius": 2.4
					}
				)
				a.call(&"advance", DT)
			assert_eq(
				vat.call(&"vat_drives"),
				live.call(&"vat_drives"),
				"kind %d tick %d: drives" % [kind, k]
			)
			assert_eq(
				vat.call(&"vat_lift"), live.call(&"vat_lift"), "kind %d tick %d: lift" % [kind, k]
			)
			assert_eq(
				vat.call(&"glow_energy"),
				live.call(&"glow_energy"),
				"kind %d tick %d: glow" % [kind, k]
			)


func test_the_bomb_drone_s_dropped_bomb_folds_away() -> void:
	var a := BombDroneAvatar.new()
	a.vat = true
	a.setup()
	add_child_autofree(a)
	a.set_process(false)
	a.apply_state({"tick": 0, "state": EnemyAi.State.MOVE})
	a.advance(DT)
	assert_gt(a.vat_drives()[BombDroneAvatar.BOMB_S], 0.9, "armed: full size")
	for k in 30:
		a.apply_state({"tick": 1 + k, "state": EnemyAi.State.WINDUP})
		a.advance(DT)
	assert_false(a.bomb_armed())
	assert_eq(a.vat_drives()[BombDroneAvatar.BOMB_S], 0.0, "dropped: a point")


func test_actor_views_draw_them_through_the_crowd_and_flash_them() -> void:
	ViewPrefs.enemy_vat = true
	var w := CombatLab.world()
	var ids: Array[int] = []
	var kinds := [
		ActorStore.Kind.NEEDLE,
		ActorStore.Kind.WARDEN,
		ActorStore.Kind.ARC_CASTER,
		ActorStore.Kind.BOMB_DRONE,
		ActorStore.Kind.NEEDLE,
	]
	for k in kinds.size():
		ids.append(w.add_enemy(kinds[k], Vector2(-4.0 + 2.0 * k, 3.0)))
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	assert_eq(views.vat_crowd.count(), 5)
	assert_eq(views.vat_crowd.looks(), 4, "a look per kind")
	views.vat_crowd._process(DT)
	assert_eq(views.vat_crowd.drawn, 5)
	var needle := views.actor_node(ids[0]).get_meta(&"enemy_avatar") as NeedleAvatar
	assert_true(needle.vat)
	var inst := views.vat_crowd.instance_of(needle)
	var sent := (inst["drives"] as PackedFloat32Array).slice(0, 19)  # (padded to whole texels)
	assert_eq(sent, needle.vat_drives(), "all nineteen drives sent")
	var warden := views.actor_node(ids[1]).get_meta(&"enemy_avatar") as WardenAvatar
	assert_not_null(warden.dust, "the dust ring stays a node")
	var drone := views.actor_node(ids[3]).get_meta(&"enemy_avatar") as BombDroneAvatar
	assert_not_null(drone.shadow, "the ground disc stays a node")
	views.flash(ids[0])
	views.vat_crowd._process(DT)
	assert_lt((views.vat_crowd.instance_of(needle)["color"] as Color).a, 0.0, "the hit shows")
	ViewPrefs.enemy_vat = false


func test_the_lens_drone_keeps_its_hover_and_its_model_s_colour_map() -> void:
	var live := VatBake.reference_of(WorldReader.KIND_LENS_DRONE, Color(0, 0, 0, 0), 0.0)
	var vat := VatBake.vat_avatar_of(WorldReader.KIND_LENS_DRONE)
	add_child_autofree(live)
	add_child_autofree(vat)
	for a: AvatarBase in [live, vat]:
		a.set_process(false)
		a.apply_state({"tick": 1, "state": EnemyAi.State.MOVE})
		for k in 240:
			a.advance(DT)
	assert_almost_eq(vat.vat_lift(), live.hover_height(), 0.0001, "the same hover")
	assert_between(vat.vat_lift(), LensDroneAvatar.HOVER_Y - 0.1, LensDroneAvatar.HOVER_Y + 0.1)
	var pose := VatBake.pose_for(WorldReader.KIND_LENS_DRONE)
	assert_eq(pose.has("albedo_tex"), (live as LensDroneAvatar).has_model, "the model's colour map")
