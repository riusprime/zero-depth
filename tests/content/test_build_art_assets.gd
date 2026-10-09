extends GutTest
## The owner's build-picker art (v0.6.1 R2b): assets/ui/build_picker/manifest.json lists the title plaque, the two
## build card frames and the two weapon emblems cropped by scripts/art/crop_build_art.py, each with its hash and size
## (and the dark panel for the frames and the plaque); the files match it both ways, every piece has alpha, the sizes
## are the ones BuildArt draws, and the text and emblem boxes sit inside both frames' dark panels.

const MANIFEST := "res://assets/ui/build_picker/manifest.json"
const DIR := "res://assets/ui/build_picker"
const IDS := ["title_plaque", "frame_blade", "frame_gun", "emblem_blade", "emblem_gun"]


func _manifest() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	assert_typeof(data, TYPE_DICTIONARY, "the manifest parses")
	return data if data is Dictionary else {}


func _pieces() -> Dictionary:
	var out := {}
	for p: Dictionary in _manifest().get("pieces", []):
		out[p["id"]] = p
	return out


func test_manifest_records_sources_and_licence() -> void:
	var m := _manifest()
	assert_eq(m.get("generator"), "scripts/art/crop_build_art.py")
	assert_true(FileAccess.file_exists("res://" + String(m.get("generator", ""))))
	var sources: Array = m.get("sources", [])
	assert_eq(sources.size(), 3)
	for s: Dictionary in sources:
		var path := "res://" + String(s["path"])
		assert_true(FileAccess.file_exists(path), "the owner's sheet ships: %s" % path)
		assert_eq(FileAccess.get_sha256(path), s["sha256"], "cropped from this exact sheet")
	assert_string_contains(String(m.get("licence", "")), "owner")


func test_every_piece_exists_with_its_hash_alpha_and_size() -> void:
	var pieces := _pieces()
	assert_eq(pieces.keys().size(), IDS.size())
	var want := {
		"title_plaque": BuildArt.TITLE_SIZE,
		"frame_blade": BuildArt.FRAME_SIZE,
		"frame_gun": BuildArt.FRAME_SIZE,
		"emblem_blade": BuildArt.EMBLEM_SIZE,
		"emblem_gun": BuildArt.EMBLEM_SIZE,
	}
	for id: String in IDS:
		assert_true(pieces.has(id), id)
		if not pieces.has(id):
			continue
		var p: Dictionary = pieces[id]
		var path := "res://" + String(p["path"])
		assert_eq(path, BuildArt.path(id), "BuildArt names %s" % id)
		assert_eq(FileAccess.get_sha256(path), p["sha256"], "%s matches its hash" % id)
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(img)
		if img == null:
			continue
		assert_eq(Vector2(img.get_size()), want[id], "%s size" % id)
		assert_ne(img.detect_alpha(), Image.ALPHA_NONE, "%s has alpha" % id)
		assert_eq(img.get_pixel(0, 0).a, 0.0, "%s: the corner is transparent" % id)
	for name in DirAccess.get_files_at(DIR):
		if name.ends_with(".png"):
			assert_true(IDS.has(name.get_basename()), "%s is in the manifest" % name)


func test_the_text_and_emblem_boxes_sit_in_the_dark_panels() -> void:
	var pieces := _pieces()
	for id in ["frame_blade", "frame_gun"]:
		var p: Array = pieces[id]["panel"]
		var panel := Rect2(p[0], p[1], p[2], p[3])
		assert_true(panel.encloses(BuildArt.TEXT_BOX), "%s: the text box in the panel" % id)
		assert_true(panel.encloses(BuildArt.EMBLEM_BOX), "%s: the emblem in the panel" % id)
		var img := Image.load_from_file(
			ProjectSettings.globalize_path("res://" + String(pieces[id]["path"]))
		)
		var c := Vector2i(BuildArt.TEXT_BOX.get_center())
		assert_eq(img.get_pixel(c.x, c.y).a, 1.0, "%s: the panel is opaque" % id)
		assert_lt(img.get_pixel(c.x, c.y).v, 0.35, "%s: the panel is dark" % id)
	var t: Array = pieces["title_plaque"]["panel"]
	assert_true(
		Rect2(t[0], t[1], t[2], t[3]).encloses(BuildArt.TITLE_BOX), "the title in the plaque"
	)
