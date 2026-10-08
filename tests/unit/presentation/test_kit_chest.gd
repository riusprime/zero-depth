extends GutTest
## The owner's chest (v0.5.9 Step 5): the model is cut at its lid seam into a body and a lid on a back hinge; with
## the new look the reward chest uses it, and a taken chest opens its lid and then goes (cosmetic only).


func after_each() -> void:
	KitModels.clear_cache()


func test_the_chest_splits_at_its_seam() -> void:
	var parts := KitModels.split(&"chest", KitModels.CHEST_LID_CUT)
	assert_false(parts.is_empty(), "the chest model splits")
	var size: Vector3 = parts["size"]
	var body: AABB = (parts["body"] as ArrayMesh).get_aabb()
	var lid: AABB = (parts["lid"] as ArrayMesh).get_aabb()
	assert_almost_eq(size.y, 0.6, 0.001, "natural height")
	assert_almost_eq(
		lid.position.y, size.y * KitModels.CHEST_LID_CUT, 0.05, "the lid starts at the seam"
	)
	assert_almost_eq(lid.end.y, size.y, 0.001, "and reaches the top")
	assert_lte(body.position.y, 0.001, "the body sits on the ground")


func test_the_new_look_uses_the_model_and_a_taken_chest_opens_then_goes() -> void:
	var v := RewardViews.new()
	add_child_autofree(v)
	var old := v.make_chest()
	assert_false(old.has_meta(&"lid"), "the old look keeps the stone chest")
	old.free()
	v.kit_chest = true
	var chest := v.make_chest()
	v.add_child(chest)
	assert_true(chest.has_meta(&"lid"), "the new look: the owner's chest with a hinged lid")
	assert_true(chest.has_meta(&"price"), "it still floats its price")
	v._opening[chest] = 0.0
	v._process(RewardViews.LID_OPEN_S)
	var hinge: Node3D = chest.get_meta(&"lid")
	assert_almost_eq(hinge.rotation.x, RewardViews.LID_OPEN_RAD, 0.01, "the lid swings open")
	v._process(RewardViews.OPENED_S)
	assert_true(chest.is_queued_for_deletion(), "then the chest goes")
