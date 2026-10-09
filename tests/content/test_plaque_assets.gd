extends GutTest
## The owner's wide crystal plaques (v0.6.1 R1): assets/ui/plaques/manifest.json lists the 12 plaques cropped by
## scripts/art/crop_plaques.py, each with its hash, size, dark panel, text box and nine-slice margins; the files on
## disk match it both ways, every plaque has an alpha channel (transparent corners, an opaque dark panel) and the
## size Plaques draws, the shared nine-slice margins and text box (Plaques) hold for every plaque, and every colour
## the card frames' family table names has a plaque.

const MANIFEST := "res://assets/ui/plaques/manifest.json"
const DIR := "res://assets/ui/plaques"
const COUNT := 12


func _manifest() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	assert_typeof(data, TYPE_DICTIONARY, "the manifest parses")
	return data if data is Dictionary else {}


func _plaques() -> Array:
	return _manifest().get("plaques", [])


func _image(p: Dictionary) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path("res://" + String(p["path"])))


func test_manifest_records_source_and_licence() -> void:
	var m := _manifest()
	assert_eq(m.get("generator"), "scripts/art/crop_plaques.py")
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


func test_twelve_plaques_exist_with_their_hash() -> void:
	var plaques := _plaques()
	assert_eq(plaques.size(), COUNT)
	for p: Dictionary in plaques:
		var path := "res://" + String(p["path"])
		assert_true(FileAccess.file_exists(path), path)
		assert_eq(FileAccess.get_sha256(path), p["sha256"], "%s matches its hash" % p["id"])
		assert_eq(path.get_file(), "plaque_%s.png" % p["id"], "file named by id")


func test_every_plaque_has_alpha_and_the_expected_size() -> void:
	for p: Dictionary in _plaques():
		var img := _image(p)
		assert_not_null(img, p["id"])
		if img == null:
			continue
		assert_eq(Vector2(img.get_size()), Plaques.SIZE, "%s is %s" % [p["id"], Plaques.SIZE])
		assert_eq(Vector2(p["size"][0], p["size"][1]), Plaques.SIZE, "manifest size")
		assert_ne(img.detect_alpha(), Image.ALPHA_NONE, "%s has an alpha channel" % p["id"])
		assert_eq(img.get_pixel(0, 0).a, 0.0, "%s: the corner is transparent" % p["id"])
		var c := Vector2i(Plaques.CONTENT.get_center())
		assert_eq(img.get_pixel(c.x, c.y).a, 1.0, "%s: the panel is opaque" % p["id"])
		assert_lt(img.get_pixel(c.x, c.y).v, 0.35, "%s: the panel is dark" % p["id"])


func test_no_white_fringe() -> void:
	# A light pixel next to a fully transparent one is a halo left by a white background.
	for p: Dictionary in _plaques():
		var img := _image(p)
		if img == null:
			continue
		var halos := 0
		for y in range(1, img.get_height() - 1, 2):
			for x in range(1, img.get_width() - 1):
				var px := img.get_pixel(x, y)
				if px.a > 0.0 and px.a < 1.0 and minf(px.r, minf(px.g, px.b)) > 0.85:
					if img.get_pixel(x - 1, y).a == 0.0 or img.get_pixel(x + 1, y).a == 0.0:
						halos += 1
		assert_eq(halos, 0, "%s has no white edge pixels" % p["id"])


func test_the_shared_nine_slice_covers_every_plaques_end_clusters() -> void:
	for p: Dictionary in _plaques():
		var n: Array = p["nine_slice"]
		assert_gte(
			Plaques.SLICE_LEFT, int(n[0]), "%s: the left cluster is in the left margin" % p["id"]
		)
		assert_gte(Plaques.SLICE_TOP, int(n[1]), "%s: top" % p["id"])
		assert_gte(
			Plaques.SLICE_RIGHT, int(n[2]), "%s: the right cluster is in the right margin" % p["id"]
		)
		assert_gte(Plaques.SLICE_BOTTOM, int(n[3]), "%s: bottom" % p["id"])
	var mid := Plaques.SIZE.x - Plaques.SLICE_LEFT - Plaques.SLICE_RIGHT
	assert_gt(mid, 100.0, "a plain middle to stretch")
	assert_gt(Plaques.SIZE.y - Plaques.SLICE_TOP - Plaques.SLICE_BOTTOM, 0.0, "a middle band")


func test_the_middle_columns_are_plain() -> void:
	# Every column of the stretched middle is the same shape as the centre column: no crystal or gem gets stretched.
	for p: Dictionary in _plaques():
		var img := _image(p)
		if img == null:
			continue
		var cx := int(Plaques.SIZE.x * 0.5)
		var ref := _span(img, cx)
		for x in range(Plaques.SLICE_LEFT, int(Plaques.SIZE.x) - Plaques.SLICE_RIGHT):
			var s := _span(img, x)
			if absi(s.x - ref.x) > 3 or absi(s.y - ref.y) > 3:
				fail_test("%s: column %d is not plain (%s vs %s)" % [p["id"], x, s, ref])
				break
	pass_test("checked")


func test_the_text_box_sits_inside_every_plaques_clear_panel() -> void:
	for p: Dictionary in _plaques():
		var t: Array = p["text"]
		var clear := Rect2(t[0], t[1], t[2], t[3])
		assert_true(clear.encloses(Plaques.CONTENT), "%s: CONTENT inside %s" % [p["id"], clear])


func test_every_png_is_listed_and_every_family_colour_has_a_plaque() -> void:
	var listed := {}
	for p: Dictionary in _plaques():
		listed[String(p["path"]).get_file()] = true
	for name in DirAccess.get_files_at(DIR):
		if name.ends_with(".png"):
			assert_true(listed.has(name), "%s is in the manifest" % name)
	for fam: StringName in CardFrames.FRAME:
		var id := Plaques.of_family(fam)
		assert_eq(id, CardFrames.FRAME[fam], "one table: %s" % fam)
		assert_true(ResourceLoader.exists(Plaques.path(id)), "%s → %s installed" % [fam, id])


## The first and last opaque row of column x.
func _span(img: Image, x: int) -> Vector2i:
	var top := -1
	var bottom := -1
	for y in img.get_height():
		if img.get_pixel(x, y).a > 0.0:
			if top < 0:
				top = y
			bottom = y
	return Vector2i(top, bottom)
