extends SceneTree
## Regenerates tests/golden/fixtures/native_kernels_hash.txt and native_horde_hash.txt (NativeFixtures) from the
## native library loaded now. On purpose only, from the owner's Windows build (MSVC, template_debug), and only when a
## kernel's code changes: name the change in PROGRESS ("Goldens changed on purpose") with the old and new values.
##   godot --headless --path . -s tests/golden/generate_native_fixtures.gd


func _initialize() -> void:
	if not NativeWorld.available():
		NativeWorld.report_missing()
		quit(1)
		return
	var kernels := NativeFixtures.kernel_hashes()
	var f := FileAccess.open(NativeFixtures.KERNELS_FILE, FileAccess.WRITE)
	f.store_string(NativeFixtures.kernels_text(kernels))
	f.close()
	var scene := NativeFixtures.scene_hash()
	f = FileAccess.open(NativeFixtures.SCENE_FILE, FileAccess.WRITE)
	f.store_string(scene + "\n")
	f.close()
	for k in NativeFixtures.ORDER:
		print("GOLD| native %s=%s" % [k, kernels[k]])
	print("GOLD| native scene=%s" % scene)
	quit(0)
