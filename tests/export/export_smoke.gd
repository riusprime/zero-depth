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
	if packed:
		_check(
			not FileAccess.file_exists("res://addons/gut/plugin.cfg"),
			"the test framework is not shipped"
		)
		_check(not DirAccess.dir_exists_absolute("res://tests"), "tests are not shipped")
	print("%d miss(es)" % _misses.size())
	quit(1 if not _misses.is_empty() else 0)
