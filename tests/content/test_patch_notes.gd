extends GutTest
## Patch notes ship inside the export as content, and match their docs (ROADMAP §0.4).

const BUILDER := "res://scripts/content/build_patch_notes.gd"


func test_committed_copies_match_the_docs() -> void:
	var built: Array = load(BUILDER).build_all()
	assert_gt(built.size(), 0)
	for def: PatchNotesDefinition in built:
		var path := "res://data/patch_notes/v%s.tres" % def.version
		var shipped: PatchNotesDefinition = load(path)
		assert_not_null(shipped, path)
		if shipped == null:
			continue
		assert_eq(shipped.id, def.id)
		assert_eq(shipped.body_en, def.body_en, "rebuild %s with %s" % [path, BUILDER])
		assert_eq(shipped.body_es, def.body_es, "rebuild %s with %s" % [path, BUILDER])


func test_a_released_version_has_its_notes() -> void:
	if GameVersion.is_prerelease():
		pass_test("a -dev version needs no notes yet")
		return
	var repo := ContentRepository.load_all()
	var def := repo.get_def(&"patch_notes", PatchNotesDefinition.id_for(GameVersion.numeric()))
	assert_not_null(def, "patch notes for " + GameVersion.numeric())
