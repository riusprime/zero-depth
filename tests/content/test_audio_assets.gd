extends GutTest
## The synthesised sounds (v0.3.0 AU): assets/audio/manifest.json lists every file with its id, path, sha256 and the
## generator version, and the files on disk match it both ways; durations are sane; every cue has its file and
## every file a cue; every biome has a loop; every caption key has en and es. Regenerate with
## `python3 scripts/audio/generate_sfx.py` (docs/audio/README.md).

const MANIFEST := "res://assets/audio/manifest.json"
const DIRS := ["res://assets/audio/sfx", "res://assets/audio/ambience"]


func _manifest() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	assert_typeof(data, TYPE_DICTIONARY, "the manifest parses")
	return data if data is Dictionary else {}


func test_the_manifest_records_its_generator_and_licence() -> void:
	var m := _manifest()
	assert_eq(m.get("generator"), "scripts/audio/generate_sfx.py")
	assert_gte(int(m.get("generator_version", 0)), 1)
	assert_false(String(m.get("licence", "")).is_empty(), "the licence is recorded (SFX_NEEDS)")
	assert_true(
		FileAccess.file_exists("res://scripts/audio/generate_sfx.py"),
		"the generator ships in the repo"
	)


func test_every_listed_sound_exists_with_its_hash() -> void:
	var sounds: Array = _manifest().get("sounds", [])
	assert_gt(sounds.size(), 40)
	for s: Dictionary in sounds:
		var path := "res://" + String(s["path"])
		assert_true(FileAccess.file_exists(path), path)
		assert_eq(FileAccess.get_sha256(path), s["sha256"], "%s matches its hash" % s["id"])
		assert_eq(path.get_file().get_basename(), String(s["id"]), "file named by id")


func test_every_sound_file_is_listed() -> void:
	var listed := {}
	for s: Dictionary in _manifest().get("sounds", []):
		listed["res://" + String(s["path"])] = true
	for dir: String in DIRS:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".wav") or f.ends_with(".ogg"):
				assert_true(listed.has(dir.path_join(f)), "%s is in the manifest" % f)


func test_durations_are_sane_and_the_streams_match() -> void:
	for s: Dictionary in _manifest().get("sounds", []):
		var seconds := float(s["seconds"])
		var ambience := String(s["kind"]) == "ambience"
		if ambience:
			assert_between(seconds, 5.0, 30.0, "%s loop length" % s["id"])
		else:
			assert_between(seconds, 0.05, 3.0, "%s length" % s["id"])
		assert_lt(float(s["peak_dbfs"]), -0.5, "%s never clips" % s["id"])
		var stream: AudioStream = load("res://" + String(s["path"]))
		assert_not_null(stream, "%s imports" % s["id"])
		if stream != null:
			assert_almost_eq(stream.get_length(), seconds, 0.02, "%s imported length" % s["id"])


func test_every_cue_has_a_file_and_every_file_a_cue() -> void:
	var repo := ContentRepository.load_all()
	assert_eq(repo.errors().size(), 0, "content validates")
	var cue_ids := {}
	for c: AudioCueDefinition in repo.all_of(&"audio_cues"):
		cue_ids[c.id] = true
		assert_true(ResourceLoader.exists(c.default_path()), "%s has its file" % c.id)
	for s: Dictionary in _manifest().get("sounds", []):
		assert_true(cue_ids.has(StringName(s["id"])), "%s has a cue" % s["id"])
	for b: BiomeDefinition in repo.all_of(&"biomes"):
		var cue: AudioCueDefinition = repo.get_def(&"audio_cues", b.id)
		assert_not_null(cue, "biome %s has an ambience loop" % b.id)
		if cue != null:
			assert_eq(cue.kind, &"ambience")


func test_caption_keys_have_en_and_es() -> void:
	var rows := {}
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3:
			rows[row[0]] = row
	var captioned := 0
	for c: AudioCueDefinition in ContentRepository.load_all().all_of(&"audio_cues"):
		if c.caption_key == &"":
			continue
		captioned += 1
		assert_true(rows.has(String(c.caption_key)), "%s is in strings.csv" % c.caption_key)
		if rows.has(String(c.caption_key)):
			assert_false(rows[String(c.caption_key)][1].is_empty())
			assert_false(rows[String(c.caption_key)][2].is_empty())
	assert_gte(captioned, 8, "boss telegraphs, low HP, the portal and the rest carry captions")


func test_a_bad_cue_is_refused() -> void:
	var c := AudioCueDefinition.new()
	c.id = &"not_a_sound"
	c.bus = &"loud"
	c.max_voices = 0
	var codes := c.validate().map(func(i: ValidationIssue) -> StringName: return i.code)
	assert_has(codes, &"bad_bus")
	assert_has(codes, &"not_positive")
	assert_has(codes, &"missing_file")
