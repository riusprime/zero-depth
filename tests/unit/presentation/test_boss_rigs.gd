extends GutTest
## The owner's boss models rigged in code (PLAN v0.3.0 L13): each rig has its bones, every vertex is weighted to at
## most 4 bones with weights that sum to 1, the Crawler Queen's eight legs are found, a rig is built once per boss
## type, and the boss state moves the bones (fists up for the slam, legs scuttling, the cannon's recoil).

const DT := 1.0 / 60.0
const BONES := {&"stone_sentinel": 9, &"crawler_queen": 11, &"fortress_turret": 13}


func _avatar(cls: Variant) -> BossAvatar:
	var a: BossAvatar = cls.new()
	a.setup(Color("#1A1A22"))
	add_child_autofree(a)
	a.set_process(false)
	return a


func _run(a: BossAvatar, frames: int, s: Dictionary, t0: int = 0) -> void:
	for t in frames:
		var d := s.duplicate()
		d["tick"] = t0 + t + 1
		if not d.has("pos"):
			d["pos"] = Vector2.ZERO
		a.apply_state(d)
		a.advance(DT)


func test_each_rig_weights_every_vertex_to_at_most_four_bones() -> void:
	for id: StringName in BONES:
		var m := BossModels.get_model(id)
		var rig: BossRig = m["rig"]
		var verts: PackedVector3Array = m["arrays"][Mesh.ARRAY_VERTEX]
		assert_eq(rig.bones.size(), BONES[id], "%s bones" % id)
		assert_eq(rig.bone_ids.size(), verts.size() * 4)
		assert_eq(rig.weights.size(), verts.size() * 4)
		var bad := 0
		var used := {}
		for v in verts.size():
			var sum := 0.0
			for j in 4:
				var w := rig.weights[v * 4 + j]
				sum += w
				if w > 0.0:
					used[rig.bone_ids[v * 4 + j]] = true
				if rig.bone_ids[v * 4 + j] < 0 or rig.bone_ids[v * 4 + j] >= rig.bones.size():
					bad += 1
			if absf(sum - 1.0) > 0.001:
				bad += 1
		assert_eq(bad, 0, "%s: every vertex weighted, normalised, to real bones" % id)
		# Every bone but the root moves some of the mesh.
		assert_gte(used.size(), rig.bones.size() - 1, "%s: the bones all carry vertices" % id)


func test_the_queen_has_four_legs_a_side() -> void:
	var rig: BossRig = BossModels.get_model(&"crawler_queen")["rig"]
	var left := 0
	var right := 0
	for b: Array in rig.bones:
		var n := String(b[0])
		if n.begins_with("leg_l"):
			left += 1
			assert_lt((b[2] as Vector3).z, 0.0, "%s on the left" % n)
		elif n.begins_with("leg_r"):
			right += 1
			assert_gt((b[2] as Vector3).z, 0.0, "%s on the right" % n)
	assert_eq(left, 4)
	assert_eq(right, 4)


func test_a_rig_is_built_once_per_type() -> void:
	BossModels.preload_all()
	var before := BossRig.builds
	for k in 2:
		_avatar(GatekeeperAvatar)
		_avatar(BroodMotherAvatar)
		_avatar(SiegeEngineAvatar)
	assert_eq(BossRig.builds, before, "avatars reuse the cached rig")


func test_the_avatar_skins_its_mesh_to_a_skeleton() -> void:
	var a := _avatar(GatekeeperAvatar)
	assert_not_null(a.skeleton)
	assert_eq(a.skeleton.get_bone_count(), BONES[&"stone_sentinel"])
	assert_not_null(a.imported.skin)
	assert_eq(a.imported.get_node(a.imported.skeleton), a.skeleton)


func test_the_slam_raises_the_fists() -> void:
	var a := _avatar(GatekeeperAvatar)
	var arm := a.skeleton.find_bone("arm_r")
	_run(a, 10, {"state": WorldReader.STATE_MOVE})
	var rest := a.skeleton.get_bone_pose_rotation(arm)
	_run(
		a,
		40,
		{"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_SLAM_RING, "windup": 0.9},
		10
	)
	var up := a.skeleton.get_bone_pose_rotation(arm)
	assert_gt(rest.angle_to(up), 1.5, "the arm swings up over the head")
	var fist := a.skeleton.get_bone_global_pose(a.skeleton.find_bone("fist_r")).origin
	assert_gt(fist.y, 1.6, "the fist is up high")


func test_the_queen_scuttles_and_rears() -> void:
	var a := _avatar(BroodMotherAvatar)
	var leg := a.skeleton.find_bone("leg_l0")
	var poses := {}
	for t in 40:
		a.apply_state({"tick": t + 1, "pos": Vector2(t * 0.04, 0), "state": WorldReader.STATE_MOVE})
		a.advance(DT)
		poses[str(a.skeleton.get_bone_pose_rotation(leg))] = true
	assert_gt(poses.size(), 10, "the leg moves while walking")
	_run(
		a, 40, {"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_LEAP, "windup": 0.9}, 40
	)
	var body := a.skeleton.get_bone_pose_rotation(a.skeleton.find_bone("body"))
	assert_gt(body.get_angle(), 0.1, "the body rears up before the leap")


func test_the_turret_cannon_recoils() -> void:
	var a := _avatar(SiegeEngineAvatar)
	var gun := a.skeleton.find_bone("cannon")
	var rest := a.skeleton.get_bone_rest(gun).origin
	_run(
		a, 5, {"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_BOLT_FAN, "windup": 0.9}
	)
	_run(a, 2, {"state": WorldReader.STATE_ACTIVE, "move": WorldReader.MOVE_BOLT_FAN}, 5)
	assert_lt(a.skeleton.get_bone_pose_position(gun).x, rest.x - 0.2, "the cannon kicks back")
