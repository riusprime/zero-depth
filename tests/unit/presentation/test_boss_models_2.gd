extends GutTest
## The owner's Warlord, Hive Lens and Foundry models (v0.7.5 BM, owner N14): each loads, stands at its height in our
## frame facing +X (the Hive Lens floating), dressed like the first three (flashable, outlined, textured, an X-ray
## twin); the Warlord and the Hive Lens keep their own skeletons and the Foundry's mesh is cut into four legs and a
## body; and the sim's read state moves the bones: velocity (a walk, trailing tails, steps), the shield state (the
## weak point), the attack phase (the spear), a hit, the "shielded" hook, the death fall. Presentation only: the
## avatars change no shader and the sim never sees them.

const DT := 1.0 / 60.0
const IDS: Array[StringName] = [&"warlord", &"hive_lens", &"foundry"]
var classes := {&"warlord": WarlordAvatar, &"hive_lens": HiveLensAvatar, &"foundry": FoundryAvatar}


func after_each() -> void:
	BossModels.dir = BossModels.DIR
	ViewPrefs.reduced_motion = false


func _avatar(cls: Variant, technique: StringName = &"xray") -> BossAvatar:
	var a: BossAvatar = cls.new()
	a.setup(Color("#1A1A22"), technique)
	add_child_autofree(a)
	a.set_process(false)
	return a


## Drives `a` through `frames` ticks of state `s` (one frame a tick); "walk" moves it 3 m/s along +x.
func _drive(a: BossAvatar, s: Dictionary, frames: int, t0: int = 0) -> void:
	for t in frames:
		var d := s.duplicate()
		d["tick"] = t0 + t + 1
		d["pos"] = Vector2((t0 + t + 1) * 0.05, 0) if s.get("walk", false) else Vector2.ZERO
		a.apply_state(d)
		a.advance(DT)


func _rot(a: BossAvatar, bone: StringName) -> Quaternion:
	return a.skeleton.get_bone_pose_rotation(a.poser.index_of(bone))


func _rest_rot(a: BossAvatar, bone: StringName) -> Quaternion:
	return a.skeleton.get_bone_rest(a.poser.index_of(bone)).basis.get_rotation_quaternion()


func _turned(a: BossAvatar, bone: StringName) -> float:
	return _rot(a, bone).angle_to(_rest_rot(a, bone))


## A bone's pivot in the avatar's model frame now.
func _at(a: BossAvatar, bone: StringName) -> Vector3:
	return a._skel_to_model() * a.poser.bone_origin(bone)


func test_each_model_loads_at_its_height_facing_plus_x() -> void:
	for id in IDS:
		var m := BossModels.get_model(id)
		assert_false(m.is_empty(), "%s loads" % id)
		var spec: Dictionary = BossModels.SPECS[id]
		var box: AABB = m["aabb"]
		assert_almost_eq(box.size.y, spec["height"], 0.01, "%s at its height" % id)
		assert_almost_eq(box.position.y, spec.get("lift", 0.0), 0.01, "%s stands (or floats)" % id)
		assert_almost_eq(box.get_center().x, 0.0, 0.01, "%s centred" % id)
		assert_almost_eq(box.get_center().z, 0.0, 0.01, "%s centred" % id)
		assert_eq(spec["yaw"], 0.0, "%s faces +X as delivered (evidence/BOSS_MODELS.md)" % id)
		var a := _avatar(classes[id])
		assert_eq(a.model_id(), id)
		assert_not_null(a.imported, "%s draws the owner's model" % id)
		assert_not_null(a.poser, "%s is posed from bones" % id)
	# The Hive Lens: 1.9 m across its pods, its sphere's centre 1.75 m up.
	var hive: AABB = BossModels.get_model(&"hive_lens")["aabb"]
	assert_almost_eq(hive.size.z, 1.9, 0.02)
	var lens := _avatar(HiveLensAvatar)
	assert_almost_eq(
		lens.weak_core.position.y, HiveLensAvatar.HOVER_Y, 0.15, "the eye at hover height"
	)


func test_the_rigged_models_keep_their_skeletons_and_face_plus_x() -> void:
	var w := _avatar(WarlordAvatar)
	assert_eq(w.skeleton.get_bone_count(), 41, "the owner's 41 joints")
	assert_true(
		w.skeleton.get_parent() != null and w.rig == null, "its own skeleton, not a code rig"
	)
	# Its left is -Z and its toes point +X: the front is +X.
	assert_lt(_at(w, &"L_Thigh").z, -0.1)
	assert_gt(_at(w, &"R_Thigh").z, 0.1)
	assert_gt(_at(w, &"L_ToeBase").x, _at(w, &"L_Foot").x)
	assert_gt(_at(w, &"Head").y, 1.6, "the head up top")
	var h := _avatar(HiveLensAvatar)
	assert_eq(h.skeleton.get_bone_count(), 23)
	assert_lt(_at(h, HiveLensAvatar.TAILS[2][0]).z, 0.0, "its left tail on the left")
	assert_gt(_at(h, HiveLensAvatar.TAILS[1][0]).z, 0.0, "its right tail on the right")
	assert_lt(_at(h, HiveLensAvatar.TAILS[0][0]).x, 0.0, "its middle tail under the back")
	assert_gt(_at(h, HiveLensAvatar.CROWN).y, 2.2, "the crown on top")


func test_the_foundry_mesh_is_cut_into_four_legs_and_a_body() -> void:
	var m := BossModels.get_model(&"foundry")
	var rig: BossRig = m["rig"]
	var verts: PackedVector3Array = m["arrays"][Mesh.ARRAY_VERTEX]
	var names := []
	for b: Array in rig.bones:
		names.append(b[0])
	assert_eq(names, [&"root", &"body", &"leg_fl", &"leg_fr", &"leg_bl", &"leg_br"])
	var counts := {}
	var bad := 0
	for v in verts.size():
		var sum := 0.0
		for j in 4:
			var wgt := rig.weights[v * 4 + j]
			sum += wgt
			if wgt > 0.9:
				var bone: StringName = rig.bones[rig.bone_ids[v * 4 + j]][0]
				counts[bone] = counts.get(bone, 0) + 1
				if bone.begins_with("leg_") and verts[v].y > BossRig.FOUNDRY_LEG_HIGH:
					bad += 1
		if absf(sum - 1.0) > 0.001:
			bad += 1
	assert_eq(bad, 0, "weights sum to 1; a leg is only below the hip band")
	for leg: StringName in BossRig.FOUNDRY_LEGS:
		assert_gt(counts.get(leg, 0), 200, "%s carries its part of the mesh" % leg)
		var hip: Vector3 = rig.bones[rig.index_of(leg)][2]
		var tag := String(leg)
		assert_eq(hip.x > 0.0, tag[4] == "f", "%s front or back" % leg)
		assert_eq(hip.z < 0.0, tag[5] == "l", "%s left or right" % leg)
	assert_gt(counts.get(&"body", 0), verts.size() / 2, "the body is the rest")


func test_the_models_are_flashable_outlined_textured_with_an_xray_twin() -> void:
	for id in IDS:
		var a := _avatar(classes[id])
		assert_eq(a.body_materials.size(), 1)
		var m := a.body_materials[0]
		assert_same(a.imported.material_override, m)
		assert_true(m.emission_enabled, "flashable: emission on")
		assert_eq(m.emission_energy_multiplier, 0.0, "dark until hit")
		assert_eq(m.stencil_mode, BaseMaterial3D.STENCIL_MODE_OUTLINE, "%s outlined" % id)
		assert_not_null(m.albedo_texture, "%s keeps its texture" % id)
		var twins := a.find_children("XrayTwin", "MeshInstance3D", true, false)
		assert_eq(twins.size(), 1, "%s has its X-ray twin" % id)
		assert_same((twins[0] as MeshInstance3D).skin, a.imported.skin, "on the same skeleton")
		var o := _avatar(classes[id], &"outline")
		assert_eq(o.find_children("XrayTwin", "MeshInstance3D", true, false).size(), 0)
	assert_true(
		(_avatar(HiveLensAvatar).body_materials[0] as StandardMaterial3D).normal_enabled,
		"the Hive Lens keeps its normal map"
	)


func test_the_code_bodies_are_freed_when_the_model_draws() -> void:
	var w := _avatar(WarlordAvatar) as WarlordAvatar
	assert_false(is_instance_valid(w.torso))
	assert_false(is_instance_valid(w.shield_arm))
	assert_false(is_instance_valid(w.spear))
	var f := _avatar(FoundryAvatar) as FoundryAvatar
	assert_false(is_instance_valid(f.door))
	BossModels.dir = "res://tests/no_such_models/"
	for id in IDS:
		var c := _avatar(classes[id])
		assert_null(c.imported, "%s falls back to its code body without the file" % id)
		assert_null(c.poser)
		assert_gt(c.body_materials.size(), 15)


func test_velocity_moves_the_bones() -> void:
	var w := _avatar(WarlordAvatar)
	_drive(w, {"state": WorldReader.STATE_MOVE}, 30)
	var still := _turned(w, &"L_Thigh")
	assert_lt(still, 0.01, "standing: the thigh at rest")
	var most := 0.0
	for t in 60:
		_drive(w, {"state": WorldReader.STATE_MOVE, "walk": true}, 1, 30 + t)
		most = maxf(most, _turned(w, &"L_Thigh"))
	assert_gt(most, 0.2, "walking swings the thigh")
	assert_gt(_turned(w, &"R_Upperarm"), 0.0, "and the arms counter-swing")
	var f := _avatar(FoundryAvatar)
	var lift := 0.0
	for t in 60:
		_drive(f, {"state": WorldReader.STATE_MOVE, "walk": true}, 1, t)
		lift = maxf(
			lift,
			_at(f, &"leg_fl").y - f.skeleton.get_bone_rest(f.poser.index_of(&"leg_fl")).origin.y
		)
	assert_gt(lift, 0.05, "the Foundry's legs step")
	var h := _avatar(HiveLensAvatar)
	var tail: StringName = HiveLensAvatar.TAILS[0][3]
	ViewPrefs.reduced_motion = true  # no idle sway: what is left is the trail
	_drive(h, {"state": WorldReader.STATE_MOVE}, 60)
	var idle := _turned(h, tail)
	_drive(h, {"state": WorldReader.STATE_MOVE, "walk": true}, 60, 60)
	assert_gt(_turned(h, tail), idle + 0.05, "moving, the tails trail")


func test_the_shield_state_moves_the_left_arm() -> void:
	var a := _avatar(WarlordAvatar) as WarlordAvatar
	_drive(a, {"state": WorldReader.STATE_MOVE}, 30)
	assert_lt(a.shield_lift(), 0.05, "shield carried")
	var down := a.anchor(&"shield")
	var arm := _rot(a, &"L_Upperarm")
	_drive(a, {"state": WorldReader.STATE_RECOVER, "weak": 1.0}, 40, 30)
	assert_gt(a.shield_lift(), 0.9, "lifted while the weak point is open")
	assert_gt(a.anchor(&"shield").y, down.y + 0.5, "the shield goes up")
	assert_gt(_rot(a, &"L_Upperarm").angle_to(arm), 0.5, "the left arm lifts it")
	assert_true(a.weak_core.visible, "baring the core")


func test_the_attack_phase_moves_the_spear() -> void:
	var a := _avatar(WarlordAvatar)
	_drive(a, {"state": WorldReader.STATE_MOVE}, 20)
	var rest := a.anchor(&"spear_tip")
	_drive(
		a,
		{"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_FLOOD, "windup": 0.9},
		40,
		20
	)
	assert_gt(_turned(a, &"R_Upperarm"), 1.5, "raised overhead for the spear lines")
	_drive(a, {"state": WorldReader.STATE_ACTIVE, "move": WorldReader.MOVE_FLOOD}, 20, 60)
	assert_lt(a.anchor(&"spear_tip").y, 0.8, "planted: the tip at the floor")
	var b := _avatar(WarlordAvatar)
	_drive(
		b, {"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_CHARGE, "windup": 0.9}, 40
	)
	var tip := b.anchor(&"spear_tip")
	assert_gt(tip.x, rest.x + 1.0, "couched: the spear points ahead")
	assert_lt(tip.y, rest.y - 0.8, "and low")
	assert_gt(_turned(b, &"Spine01"), 0.15, "a lunge lean")


func test_the_hive_lens_opens_closes_and_looks_at_the_player() -> void:
	var a := _avatar(HiveLensAvatar)
	_drive(a, {"state": WorldReader.STATE_MOVE}, 30)
	var crown := _rot(a, HiveLensAvatar.CROWN_BASE)
	_drive(a, {"state": WorldReader.STATE_MOVE, "shielded": true}, 40, 30)
	assert_gt(a.shielded_amount(), 0.9, "the shielded hook drives the closed pose")
	assert_gt(_rot(a, HiveLensAvatar.CROWN_BASE).angle_to(crown), 0.6, "the crown folds down")
	_drive(a, {"state": WorldReader.STATE_RECOVER, "weak": 1.0}, 60, 70)
	assert_lt(a.shielded_amount(), 0.1)
	assert_gt(_rot(a, HiveLensAvatar.CROWN_BASE).angle_to(crown), 0.3, "open: the crown tips back")
	assert_true(a.weak_core.visible)
	_drive(a, {"state": WorldReader.STATE_MOVE, "aim": 0.5}, 90, 130)
	assert_almost_eq(a.pivot.rotation.y, 0.5, 0.08, "its eye turns to the player")
	_drive(a, {"state": WorldReader.STATE_MOVE, "aim": 2.0}, 90, 220)
	assert_almost_eq(a.pivot.rotation.y, HiveLensAvatar.AIM_MAX, 0.08, "as far as it turns")


func test_the_hive_lens_splits_and_its_crown_spins_unless_calm() -> void:
	var a := _avatar(HiveLensAvatar) as HiveLensAvatar
	_drive(
		a,
		{
			"state": WorldReader.STATE_WINDUP,
			"move": WorldReader.MOVE_DEPLOY,
			"windup": 0.9,
			"phase": 1,
		},
		30
	)
	assert_gt(a.split_amount(), 0.2, "the pods drift off through the deploy")
	var k := a.poser.index_of(HiveLensAvatar.PODS)
	assert_gt(a.skeleton.get_bone_pose_scale(k).x, 1.05, "spread")
	var spin := _avatar(HiveLensAvatar)
	_drive(spin, {"state": WorldReader.STATE_MOVE}, 60)
	assert_gt(_turned(spin, HiveLensAvatar.CROWN), 0.2, "the crown turns slowly")
	ViewPrefs.reduced_motion = true
	var calm := _avatar(HiveLensAvatar)
	_drive(calm, {"state": WorldReader.STATE_MOVE}, 60)
	assert_lt(_turned(calm, HiveLensAvatar.CROWN), 0.01, "reduced motion: no idle spin")


func test_a_hit_flinches_and_the_shielded_hook_poses_each() -> void:
	var a := _avatar(WarlordAvatar)
	_drive(a, {"state": WorldReader.STATE_MOVE, "hp": 1000}, 20)
	assert_eq(a.flinch_amount(), 0.0)
	_drive(a, {"state": WorldReader.STATE_MOVE, "hp": 960}, 1, 20)
	assert_gt(a.flinch_amount(), 0.9, "a drop in HP flinches")
	assert_gt(_turned(a, &"Spine01"), 0.1)
	_drive(a, {"state": WorldReader.STATE_MOVE, "hp": 960}, 40, 21)
	assert_lt(a.flinch_amount(), 0.05, "and settles")
	for id in IDS:
		var b := _avatar(classes[id])
		_drive(b, {"state": WorldReader.STATE_MOVE}, 20)
		var y := b.pivot.position.y
		var before := {}
		for k in b.skeleton.get_bone_count():
			before[k] = b.skeleton.get_bone_pose_rotation(k)
		_drive(b, {"state": WorldReader.STATE_MOVE, "shielded": true}, 40, 20)
		var moved := 0
		for k in b.skeleton.get_bone_count():
			if b.skeleton.get_bone_pose_rotation(k).angle_to(before[k]) > 0.05:
				moved += 1
		var pos_moved := absf(b.pivot.position.y - y) > 0.05
		if id == &"foundry":
			var body := b.poser.index_of(&"body")
			pos_moved = pos_moved or b.skeleton.get_bone_pose_position(body).y < 1.0
		assert_true(moved > 0 or pos_moved, "%s has a shielded pose" % id)


func test_the_warlord_falls_when_it_dies_and_the_others_go_at_once() -> void:
	var a := _avatar(WarlordAvatar)
	_drive(a, {"state": WorldReader.STATE_MOVE, "weak": 1.0}, 20)
	assert_true(a.die(), "the Warlord's model falls")
	for t in int(BossAvatar.DEATH_SECONDS * 60.0):
		a.advance(DT)
	assert_almost_eq(a.death_amount(), 1.0, 0.01)
	assert_gt(a.pivot.rotation.z, 1.2, "on its back")
	assert_false(a.weak_core.visible, "the core goes with it")
	assert_false(_avatar(HiveLensAvatar).die())
	assert_false(_avatar(FoundryAvatar).die())
	BossModels.dir = "res://tests/no_such_models/"
	assert_false(_avatar(WarlordAvatar).die(), "the code body has no fall")


func test_actor_views_keep_a_falling_warlord_a_moment() -> void:
	var w := BossLab.world()
	var views := ActorViews.new()
	add_child_autofree(views)
	var reader := WorldReader.new(w)
	var aid := w.spawn_boss(BossLab.table_index(w, &"warlord"), Vector2(6, 0))
	var fid := w.spawn_boss(BossLab.table_index(w, &"foundry"), Vector2(-6, 0))
	views.sync(reader)
	var node := views.actor_node(aid)
	var other := views.actor_node(fid)
	for id in [aid, fid]:
		w.actors.dead[w.actors.index_of(id)] = 1
	w.step(InputFrame.new())
	views.sync(reader)
	assert_null(views.actor_node(aid), "gone from the sim's views")
	assert_false(node.is_queued_for_deletion(), "but still drawing its fall")
	assert_true(other.is_queued_for_deletion(), "the Foundry goes at once")
	var avatar: BossAvatar = node.get_meta(&"enemy_avatar")
	assert_gt(avatar.death_amount(), -0.01)
	await wait_seconds(BossAvatar.DEATH_SECONDS + 0.3)
	assert_false(is_instance_valid(node), "then freed")


func test_the_weak_point_rides_its_bone() -> void:
	var a := _avatar(WarlordAvatar)
	_drive(a, {"state": WorldReader.STATE_MOVE, "weak": 1.0}, 20)
	var upright := a.weak_core.position
	assert_almost_eq(upright.y, WarlordAvatar.MODEL_WEAK.y, 0.1, "on the chest")
	_drive(
		a,
		{
			"state": WorldReader.STATE_WINDUP,
			"move": WorldReader.MOVE_CHARGE,
			"windup": 0.9,
			"weak": 1.0,
		},
		40,
		20
	)
	assert_gt(a.weak_core.position.distance_to(upright), 0.08, "the lunge lean carries it")


func test_sync_reads_the_bearing_and_hp_from_the_sim() -> void:
	assert_almost_eq(BossAvatar.bearing(Vector2.ZERO, 0, Vector2(0, 5)), PI * 0.5, 0.001)
	assert_almost_eq(BossAvatar.bearing(Vector2.ZERO, 1024, Vector2(0, 5)), 0.0, 0.001)
	assert_almost_eq(BossAvatar.bearing(Vector2.ZERO, 0, Vector2(0, -5)), -PI * 0.5, 0.001)
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"hive_lens", Vector2(0, 0))
	w.actors.set_pos(0, Vector2(0, 6))
	var reader := WorldReader.new(w)
	var a := _avatar(HiveLensAvatar)
	var before := w.actors.hp[i]
	a.sync(reader, i)
	w.actors.hp[i] = before - 10
	a.sync(reader, i)
	assert_eq(w.actors.hp[i], before - 10, "the avatar wrote nothing back")
	a.advance(DT)
	assert_gt(a.flinch_amount(), 0.5, "the drop it read flinches")
	for t in 90:
		a.advance(DT)
	assert_almost_eq(a.pivot.rotation.y, HiveLensAvatar.AIM_MAX, 0.08, "turned toward the player")


func test_posing_changes_no_shader() -> void:
	for id in IDS:
		var a := _avatar(classes[id])
		var before := DamageFlashKeys.of(a)
		_drive(a, {"state": WorldReader.STATE_MOVE, "walk": true}, 20)
		_drive(a, {"state": WorldReader.STATE_WINDUP, "move": 12, "windup": 0.9}, 30, 20)
		_drive(a, {"state": WorldReader.STATE_RECOVER, "weak": 1.0, "shielded": true}, 30, 50)
		_drive(a, {"state": WorldReader.STATE_STAGGERED, "hp": 10}, 30, 80)
		assert_eq(DamageFlashKeys.of(a), before, "%s: no shader changed" % id)


func test_anchors_name_points_on_each_body() -> void:
	for id in IDS:
		var a := _avatar(classes[id])
		_drive(a, {"state": WorldReader.STATE_MOVE}, 5)
		assert_has(a.anchor_names(), &"weak")
		for n: StringName in a.anchor_names():
			var p := a.anchor(n)
			assert_true(p.y > 0.3 and p.length() < 4.0, "%s %s on the body: %s" % [id, n, p])
	var f := _avatar(FoundryAvatar)
	assert_gt(f.anchor(&"door").x, 0.7, "the Foundry's door in front")
	assert_gt(f.anchor(&"chimney_l").y, 2.2, "its chimneys on top")


func test_every_boss_draws_at_the_bigger_scale() -> void:
	# v0.7.5 BM (owner N18): one scale for all six bosses, model or fallback, core and anchors with it.
	assert_eq(BossModels.SIZE_SCALE, 1.3)
	var all := [
		GatekeeperAvatar,
		BroodMotherAvatar,
		SiegeEngineAvatar,
		WarlordAvatar,
		HiveLensAvatar,
		FoundryAvatar,
	]
	for cls in all:
		var a := _avatar(cls)
		assert_eq(a.model.scale, Vector3.ONE * 1.3, "%s at 1.3x" % a.model_id())
		assert_true(a.model.is_ancestor_of(a.weak_core), "its core scales with it")
	var w := _avatar(WarlordAvatar)
	_drive(w, {"state": WorldReader.STATE_MOVE}, 5)
	assert_gt(w.anchor(&"spear_tip").y, 2.7 * 1.2, "the spear's tip at the bigger height")
	var h := _avatar(HiveLensAvatar)
	_drive(h, {"state": WorldReader.STATE_MOVE}, 5)
	assert_gt(
		h.anchor(&"eye").y, HiveLensAvatar.HOVER_Y * 1.2, "it floats higher, clear of the hero"
	)
	BossModels.dir = "res://tests/no_such_models/"
	assert_eq(_avatar(WarlordAvatar).model.scale, Vector3.ONE * 1.3, "the fallback too")
