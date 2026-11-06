extends GutTest
## v0.9.5 PF5: an enemy's rigid pieces become one skinned mesh (RigMerge); the avatar keeps animating its own nodes and
## the bones follow them. The pixel proof is scripts/checks/rig_compare.gd (needs a renderer); these are the
## structural guarantees. The merge is off by default (slower on the owner's PC, evidence/PF.md): each test turns it
## on.


func before_each() -> void:
	RigMerge.enabled = true


func after_each() -> void:
	RigMerge.enabled = false
	RigMerge.skip_kinds = {}


func _needle() -> NeedleAvatar:
	var n := NeedleAvatar.new()
	n.setup(Color.BLACK)
	add_child_autofree(n)
	return n


## Mesh instances that draw now, and the surfaces they submit.
func _drawn(n: Node) -> Array[int]:
	var out: Array[int] = [0, 0]
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		out[0] += 1
		out[1] += mi.mesh.get_surface_count()
	for c in n.get_children():
		var sub := _drawn(c)
		out[0] += sub[0]
		out[1] += sub[1]
	return out


func test_a_merged_needle_draws_a_few_surfaces_instead_of_every_piece() -> void:
	var before := _drawn(_needle())
	var n := _needle()
	var stats := RigMerge.merge(n, WorldReader.KIND_NEEDLE)
	var after := _drawn(n)
	assert_false(stats.is_empty(), "merged")
	assert_lt(after[1], before[1] / 2, "far fewer surfaces drawn")
	assert_eq(stats["pieces"], before[0], "every piece went into the merged meshes")
	assert_not_null(n.merged_rig, "the avatar knows its skeleton")


func test_the_switch_and_the_skip_list_leave_the_rig_as_built() -> void:
	RigMerge.enabled = false
	var off := _needle()
	assert_true(RigMerge.merge(off, WorldReader.KIND_NEEDLE).is_empty())
	assert_null(off.merged_rig)
	RigMerge.enabled = true
	RigMerge.skip_kinds = {WorldReader.KIND_NEEDLE: true}
	var skipped := _needle()
	assert_true(RigMerge.merge(skipped, WorldReader.KIND_NEEDLE).is_empty())
	assert_gt(_drawn(skipped)[0], 20, "its pieces still draw")


func test_a_bone_follows_the_node_the_animation_writes() -> void:
	var n := _needle()
	RigMerge.merge(n, WorldReader.KIND_NEEDLE)
	var rig := n.merged_rig
	var i := rig.nodes.find(n.barrel)
	assert_gt(i, -1, "the barrel is a bone")
	var rest := rig.get_bone_pose(i)
	n.barrel.position.x += 0.2
	assert_true(rig.update_bones(), "a moved node moves its bone")
	assert_almost_eq(rig.get_bone_pose(i).origin.x, rest.origin.x + 0.2, 0.0001)
	assert_false(rig.update_bones(), "nothing changed: nothing written")


func test_a_hidden_node_folds_its_bone_to_a_point_and_comes_back() -> void:
	var n := _needle()
	RigMerge.merge(n, WorldReader.KIND_NEEDLE)
	var rig := n.merged_rig
	var i := rig.nodes.find(n.barrel)
	n.barrel.visible = false
	rig.update_bones()
	assert_lt(rig.get_bone_pose(i).basis.get_scale().x, 0.001, "hidden: scaled away")
	n.barrel.visible = true
	rig.update_bones()
	assert_almost_eq(rig.get_bone_pose(i).basis.get_scale().x, 1.0, 0.0001, "shown again")


func test_a_pieces_material_that_the_avatar_animates_stays_the_same_object() -> void:
	var n := _needle()
	RigMerge.merge(n, WorldReader.KIND_NEEDLE)
	var seen := false
	for mi in n.merged_rig.get_children():
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			if m.get_surface_override_material(s) == n._eye_mat:
				seen = true
	assert_true(
		seen,
		"the eye's glow material is a surface of the merged mesh, so its emission still animates it"
	)


func test_equal_body_materials_are_one_and_the_flash_list_has_each_once() -> void:
	var n := _needle()
	var before := n.body_materials.size()
	RigMerge.merge(n, WorldReader.KIND_NEEDLE)
	assert_lt(n.body_materials.size(), before, "pieces of one colour share a material")
	for m in n.body_materials:
		assert_eq(n.body_materials.count(m), 1, "listed once, so a tint is applied once")


func test_the_hit_flash_reaches_the_merged_meshes_of_a_shared_material_avatar() -> void:
	var h := HordeAvatar.new()
	h.setup(WorldReader.KIND_SWARMER, Color.BLACK)
	add_child_autofree(h)
	RigMerge.merge(h, WorldReader.KIND_SWARMER)
	assert_gt(h.hit_pieces().size(), 0, "the body plates are still listed")
	for p in h.hit_pieces():
		assert_true(p.get_parent() is MergedRig, "and they are the merged meshes")
	h.show_hit(true, Color.WHITE, 1.6)
	assert_eq(h.hit_look().w, 1.0, "shown")
	var p0: GeometryInstance3D = h.hit_pieces()[0]
	assert_eq(
		p0.get_instance_shader_parameter(EnemyLooks.HIT), h.hit_look(), "written to the merged mesh"
	)


func test_a_charger_keeps_its_stretched_body_apart_and_merges_its_legs() -> void:
	var c := ChargerAvatar.new()
	c.setup(Color.BLACK)
	add_child_autofree(c)
	RigMerge.merge(c, WorldReader.KIND_CHARGER)
	for p in RigMerge.pieces_under(c.body):
		assert_not_null((p as MeshInstance3D).mesh, "the hood, face and visor still draw as nodes")
	assert_not_null(c.merged_rig, "the legs are merged")


func test_shadow_casting_follows_the_trimmed_pieces() -> void:
	var n := _needle()
	ShadowTrim.trim(n, 2)
	RigMerge.merge(n, WorldReader.KIND_NEEDLE)
	var casting := 0
	for mi in n.merged_rig.get_children():
		var m := mi as MeshInstance3D
		if m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casting += m.mesh.get_surface_count()
	assert_between(casting, 1, 2, "the two kept casters, as merged surfaces")
