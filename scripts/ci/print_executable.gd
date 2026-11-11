extends SceneTree
## Prints the running Godot executable's path (scripts/ci/export_smoke.sh copies it beside the pack and the native
## library, as an export folder has them).


func _initialize() -> void:
	print("EXE|", OS.get_executable_path())
	quit(0)
