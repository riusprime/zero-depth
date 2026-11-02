extends GutTest
## v0.10.5 D1: SaveLab.build_floor mirrors FloorPlan ("as Main"). It once lacked World.pair_table (v0.9.5 EE3), so a
## replay from a SaveLab base world zeroed the element-pair mask on its first tick. Every World field WorldSnapshot
## marks "loadout" that FloorPlan fills on a floor must be filled by SaveLab.build_floor too.

## Fields FloorPlan fills that SaveLab's floor leaves out on purpose (none yet; name each with its reason).
const ALLOWED_GAPS: Array[StringName] = []


func _filled(w: World, field: StringName) -> bool:
	var v: Variant = w.get(field)
	if v == null:
		return false
	if v is Array or v is Dictionary or v is PackedInt32Array:
		return not v.is_empty()
	return true


func test_save_lab_sets_every_loadout_table_floor_plan_sets() -> void:
	var plan := FloorPlan.new_run(RunSaver.RUN_ID, 4242, &"blade", false)
	plan.build()
	assert_not_null(plan.world, "FloorPlan builds floor 1")
	var lab := SaveLab.floor_world(4242, 1, &"blade")
	var checked := 0
	var missing: Array[String] = []
	for field: StringName in WorldSnapshot.WORLD_KEPT:
		if not str(WorldSnapshot.WORLD_KEPT[field]).begins_with("loadout"):
			continue
		checked += 1
		if _filled(plan.world, field) and not _filled(lab, field) and field not in ALLOWED_GAPS:
			missing.append(str(field))
	assert_gt(checked, 15, "the loadout marks were read (%d)" % checked)
	assert_eq(missing, [] as Array[String], "SaveLab.build_floor sets what FloorPlan sets")
