extends GutTest
## The owner's crystal card frames (v0.5.5 A4; docs/art/ART_DIRECTION.md §5): assets/ui/cards/manifest.json lists
## the 12 frames cropped by scripts/art/crop_card_frames.py, each with its hash, size and text panel; the files on
## disk match it both ways, every frame has an alpha channel (transparent corners, an opaque panel) and the size
## CardFrames draws, and every frame CardFrames names is installed.

const MANIFEST := "res://assets/ui/cards/manifest.json"
const DIR := "res://assets/ui/cards"
const COUNT := 12


func _manifest() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	assert_typeof(data, TYPE_DICTIONARY, "the manifest parses")
	return data if data is Dictionary else {}


func _frames() -> Array:
	return _manifest().get("frames", [])


func test_manifest_records_source_and_licence() -> void:
	var m := _manifest()
	assert_eq(m.get("generator"), "scripts/art/crop_card_frames.py")
	assert_true(
		FileAccess.file_exists("res://" + String(m.get("generator", ""))), "the cropper ships"
	)
	assert_true(
		FileAccess.file_exists("res://" + String(m.get("source", ""))), "the owner's sheet ships"
	)
	assert_eq(
		FileAccess.get_sha256("res://" + String(m.get("source", ""))),
		m.get("source_sha256"),
		"cropped from this exact sheet"
	)
	assert_string_contains(String(m.get("licence", "")), "owner")


func test_twelve_frames_exist_with_their_hash() -> void:
	var frames := _frames()
	assert_eq(frames.size(), COUNT)
	for f: Dictionary in frames:
		var path := "res://" + String(f["path"])
		assert_true(FileAccess.file_exists(path), path)
		assert_eq(FileAccess.get_sha256(path), f["sha256"], "%s matches its hash" % f["id"])
		assert_eq(path.get_file(), "frame_%s.png" % f["id"], "file named by id")


func test_every_frame_has_alpha_and_the_expected_size() -> void:
	for f: Dictionary in _frames():
		var img := Image.load_from_file(
			ProjectSettings.globalize_path("res://" + String(f["path"]))
		)
		assert_not_null(img, f["id"])
		if img == null:
			continue
		assert_eq(Vector2(img.get_size()), CardFrames.SIZE, "%s is %s" % [f["id"], CardFrames.SIZE])
		assert_eq(Vector2(f["size"][0], f["size"][1]), CardFrames.SIZE, "manifest size")
		assert_ne(img.detect_alpha(), Image.ALPHA_NONE, "%s has an alpha channel" % f["id"])
		assert_eq(img.get_pixel(0, 0).a, 0.0, "%s: the corner is transparent" % f["id"])
		var c := Vector2i(CardFrames.SIZE * 0.5) + Vector2i(0, 60)
		assert_eq(img.get_pixel(c.x, c.y).a, 1.0, "%s: the panel is opaque" % f["id"])
		assert_lt(img.get_pixel(c.x, c.y).v, 0.35, "%s: the panel is dark" % f["id"])


func test_no_white_fringe() -> void:
	# A light pixel next to a fully transparent one is a halo left by a white background.
	for f: Dictionary in _frames():
		var img := Image.load_from_file(
			ProjectSettings.globalize_path("res://" + String(f["path"]))
		)
		if img == null:
			continue
		var halos := 0
		for y in range(1, img.get_height() - 1, 2):
			for x in range(1, img.get_width() - 1):
				var p := img.get_pixel(x, y)
				if p.a > 0.0 and p.a < 1.0 and minf(p.r, minf(p.g, p.b)) > 0.85:
					if img.get_pixel(x - 1, y).a == 0.0 or img.get_pixel(x + 1, y).a == 0.0:
						halos += 1
		assert_eq(halos, 0, "%s has no white edge pixels" % f["id"])


func test_the_text_panel_sits_inside_every_frame() -> void:
	for f: Dictionary in _frames():
		var p: Array = f["panel"]
		var panel := Rect2(p[0], p[1], p[2], p[3])
		assert_gt(panel.size.x, 80.0, "%s: a usable dark panel" % f["id"])
		assert_true(Rect2(Vector2.ZERO, CardFrames.SIZE).encloses(panel), f["id"])
		assert_true(Rect2(Vector2.ZERO, CardFrames.SIZE).encloses(CrystalCard.CONTENT))


func test_every_png_is_listed_and_every_named_frame_installed() -> void:
	var listed := {}
	for f: Dictionary in _frames():
		listed[String(f["path"]).get_file()] = true
	for name in DirAccess.get_files_at(DIR):
		if name.ends_with(".png"):
			assert_true(listed.has(name), "%s is in the manifest" % name)
	for fam: StringName in CardFrames.FRAME:
		var fid: StringName = CardFrames.FRAME[fam]
		assert_true(ResourceLoader.exists(CardFrames.path(fid)), "%s → %s installed" % [fam, fid])
		assert_true(CardFrames.TINT.has(fid), "%s has a tint" % fid)
	assert_eq(CardFrames.FRAME.size(), COUNT, "one family per frame")
