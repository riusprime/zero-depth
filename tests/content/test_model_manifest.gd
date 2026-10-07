extends GutTest
## Owner-supplied models (docs/art/ART_DIRECTION.md §5.2): assets/models/manifest.json lists each model's id, path
## and sha256, and the files on disk match it exactly, both ways.

const MANIFEST := "res://assets/models/manifest.json"


func _manifest() -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	assert_typeof(data, TYPE_DICTIONARY, "the manifest parses")
	return (data as Dictionary).get("models", [])


func test_every_listed_model_exists_with_its_hash() -> void:
	var models := _manifest()
	assert_gt(models.size(), 0)
	for m: Dictionary in models:
		var path := "res://" + String(m["path"])
		assert_true(FileAccess.file_exists(path), path)
		assert_eq(FileAccess.get_sha256(path), m["sha256"], "%s matches its hash" % m["id"])
		assert_true(path.get_file().get_basename() == String(m["id"]), "file named by id")


func test_every_model_file_is_listed() -> void:
	var listed := {}
	for m: Dictionary in _manifest():
		listed["res://" + String(m["path"])] = true
	for dir in ["res://assets/models/bosses"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".glb"):
				assert_true(listed.has(dir.path_join(f)), "%s is in the manifest" % f)


func test_the_boss_models_are_the_ids_the_avatars_ask_for() -> void:
	var ids := []
	for m: Dictionary in _manifest():
		ids.append(StringName(m["id"]))
	for id: StringName in BossModels.SPECS:
		assert_has(ids, id)
