extends SceneTree
## Checks the native library loaded now against the recorded fixtures (NativeFixtures,
## tests/golden/fixtures/native_*_hash.txt) and exits 1 on any difference, printing each one. What
## scripts/native/check_release.sh runs with the release library; also usable on any machine.
##   godot --headless --path . -s scripts/checks/native_fixtures.gd


func _initialize() -> void:
	if not NativeWorld.available():
		NativeWorld.report_missing()
		quit(1)
		return
	var diffs := NativeFixtures.differences()
	for d in diffs:
		push_error(d)
	print("native_fixtures: %s" % ("ok" if diffs.is_empty() else "%d differences" % diffs.size()))
	quit(0 if diffs.is_empty() else 1)
