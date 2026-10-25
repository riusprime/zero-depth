extends GutTest
## v0.9.0 VX V45 (VFX_AUDIT.md; PLAN C83): assets/textures/vfx/manifest.json lists every effect texture id the code
## asks for, with its use, tint and code fallback; each listed id has its PNG ("installed") or is marked "fallback",
## and every PNG in the folder is listed. The ids the code asks for are read from the source: VfxCore's pools and
## floor marks, every "fx_..." id, FxTextures.get_tex / VfxCore.has_tex look-ups, the vfx folder's paths, and
## BeamLooks' beam_core_<look>.

const MANIFEST := "res://assets/textures/vfx/manifest.json"
const DIR := "res://assets/textures/vfx/"


func _entries() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	assert_typeof(data, TYPE_DICTIONARY, "the manifest parses")
	var out := {}
	for e: Dictionary in (data as Dictionary).get("ids", []):
		out[String(e["id"])] = e
	return out


## Every texture id the source asks for.
func _asked() -> Dictionary:
	var out := {}
	for id: StringName in VfxCore.POOLS:
		out[String(VfxCore.POOLS[id][0])] = true
		out[String(VfxCore.POOLS[id][5])] = true
	for id: StringName in VfxCore.MARK_TEX:
		out[String(VfxCore.MARK_TEX[id][0])] = true
	for look: StringName in BeamLooks.LOOKS:
		out[BeamLooks.TEX_PREFIX + String(look)] = true
	var res: Array[RegEx] = []
	for pat: String in [
		'"(fx_[a-z0-9_]+)"',
		'get_tex\\("([a-z0-9_]+)"\\)',
		'has_tex\\("([a-z0-9_]+)"\\)',
		"textures/vfx/([a-z0-9_]+)\\.png",
	]:
		var re := RegEx.new()
		re.compile(pat)
		res.append(re)
	for path: String in _scripts("res://src"):
		var text := FileAccess.get_file_as_string(path)
		for re in res:
			for m in re.search_all(text):
				out[m.get_string(1)] = true
	return out


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out


func test_every_id_the_code_asks_for_is_listed() -> void:
	var listed := _entries()
	var asked := _asked()
	assert_gt(asked.size(), 40, "the source was read")
	for id: String in asked:
		assert_true(listed.has(id), "%s is in the VFX manifest" % id)


func test_each_listed_id_has_its_file_or_is_marked_fallback() -> void:
	for id: String in _entries():
		var e: Dictionary = _entries()[id]
		var there := ResourceLoader.exists(DIR + id + ".png")
		for key in ["use", "tint", "fallback", "status"]:
			assert_ne(String(e.get(key, "")), "", "%s has its %s" % [id, key])
		if String(e["status"]) == "installed":
			assert_true(there, "%s is installed" % id)
		else:
			assert_eq(String(e["status"]), "fallback", "%s: installed or fallback" % id)
			assert_false(there, "%s is marked fallback but its PNG is here" % id)


func test_every_png_in_the_folder_is_listed() -> void:
	var listed := _entries()
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".png"):
			assert_true(listed.has(f.get_basename()), "%s is in the VFX manifest" % f)


func test_the_code_fallbacks_draw_without_their_png() -> void:
	for id: String in VfxCore.CODE_TEX:
		var t := VfxCore._tex(id)
		assert_not_null(t, "%s: a code sheet or the owner's" % id)
	for id: StringName in VfxCore.OPTIONAL_POOLS:
		var layer: VfxLayer = add_child_autofree(VfxLayer.new())
		assert_eq(
			layer.has_pool(id), VfxCore.has_tex(VfxCore.POOLS[id][0]), "%s only when installed" % id
		)
