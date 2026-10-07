# Ported from riusprime/deathventory@1d697803:tests/export/export_smoke.gd.
# Changes: every Deathventory check replaced; fixture files arrive as `key=value` user args
# (tests/* is not in the pack). Checks are added step by step (docs/roadmap/v0.0.1/PLAN.md Step 3).
extends SceneTree
## Export smoke check: runs INSIDE an exported pack, so it sees what a player's build sees
## (remapped resources, the include/exclude filters). Not a GUT test; run by absolute path:
##   godot --headless --path . --export-pack "Windows Desktop" build/check/game.pck
##   godot --headless --main-pack build/check/game.pck -s "$PWD/tests/export/export_smoke.gd" -- k=v ...
## Exits 1 and names every miss.

var _misses: Array[String] = []
var _args := {}


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  MISS  ") + what)
	if not ok:
		_misses.append(what)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	var packed := not FileAccess.file_exists("res://project.godot")
	print("Export smoke check (%s)" % ("exported pack" if packed else "project folder"))
	# Godot prefers a project.godot in the working directory over --main-pack, which silently
	# skips the pack checks (it did in Deathventory). CI passes expect_pack=1 to make that a miss.
	if _args.get("expect_pack", "0") == "1":
		_check(packed, "running inside the exported pack (run from outside the project folder)")
	_check(ResourceLoader.exists("res://src/app/main.tscn"), "the main scene ships")
	_check_world_run()
	_check_content()
	_check_spanish()
	_check_boss_models()
	_check_audio()
	if packed:
		_check(
			not FileAccess.file_exists("res://addons/gut/plugin.cfg"),
			"the test framework is not shipped"
		)
		_check(not DirAccess.dir_exists_absolute("res://tests"), "tests are not shipped")
	print("%d miss(es)" % _misses.size())
	quit(1 if not _misses.is_empty() else 0)


## v0.3.0 L13: the owner's boss models ship in the pack and each boss draws its model, not the fallback.
func _check_boss_models() -> void:
	BossModels.preload_all()
	for id: StringName in BossModels.SPECS:
		_check(not BossModels.get_model(id).is_empty(), "boss model %s loads from the pack" % id)


## v0.3.0 AU: every sound ships in the pack, its cue validates there and its stream loads.
func _check_audio() -> void:
	var repo := ContentRepository.load_all()
	var cues := repo.all_of(&"audio_cues")
	_check(cues.size() > 40, "audio cues: %d" % cues.size())
	var missing: Array[String] = []
	for c: AudioCueDefinition in cues:
		var s: AudioStream = (
			load(c.default_path()) if ResourceLoader.exists(c.default_path()) else null
		)
		if s == null or s.get_length() <= 0.0:
			missing.append(String(c.id))
	_check(missing.is_empty(), "every cue's sound loads from the pack (missing: %s)" % [missing])


## Step 4: a 600-tick headless World run inside the pack reproduces the hash computed in the project.
func _check_world_run() -> void:
	var w := KernelScenario.golden(1)
	var input := ScriptedInput.new(1)
	for t in 600:
		w.step(input.frame(t))
	var got := w.state_hash()
	var path: String = _args.get("world_hash", "")
	if path.is_empty():
		_check(false, "world_hash=<fixture> was passed")
		return
	var want := FileAccess.get_file_as_string(path).strip_edges()
	_check(got == want, "600-tick World run hash %s matches the project's" % got.left(12))


## Step 6: the pack holds the project's content (counts, and the same manifest hash).
func _check_content() -> void:
	var repo := ContentRepository.load_all()
	_check(repo.count(&"player") > 0, "content player: %d" % repo.count(&"player"))
	_check(repo.count(&"biomes") > 0, "content biomes: %d" % repo.count(&"biomes"))
	_check(
		repo.errors().is_empty(),
		"content validates inside the pack (%d errors)" % repo.errors().size()
	)
	var path: String = _args.get("manifest", "")
	if path.is_empty():
		_check(false, "manifest=<file> was passed")
		return
	var want := FileAccess.get_file_as_string(path).strip_edges()
	_check(
		repo.manifest_hash == want,
		"manifest hash %s matches the project's" % repo.manifest_hash.left(12)
	)


## Step 10: Spanish ships inside the pack.
func _check_spanish() -> void:
	_check("es" in TranslationServer.get_loaded_locales(), "Spanish translation is loaded")
	TranslationServer.set_locale("es")
	var es := TranslationServer.translate("UI_PLAY")
	TranslationServer.set_locale("en")
	var en := TranslationServer.translate("UI_PLAY")
	_check(es != en and es == "JUGAR", "UI_PLAY is %s / %s" % [en, es])
