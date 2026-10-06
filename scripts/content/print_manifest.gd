extends SceneTree
## Prints the content manifest hash and writes it to out= (the export smoke compares the pack against it).
##   godot --headless --path . -s scripts/content/print_manifest.gd -- out=build/check/manifest.txt


func _initialize() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
	var repo := ContentRepository.load_all()
	print(
		(
			"manifest: %s (%d files, %d errors)"
			% [repo.manifest_hash, repo.paths.size(), repo.errors().size()]
		)
	)
	if not out.is_empty():
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(repo.manifest_hash + "\n")
		f.close()
	quit(0 if repo.errors().is_empty() else 1)
