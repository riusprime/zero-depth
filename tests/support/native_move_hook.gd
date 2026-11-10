extends GutHookScript
## A GUT pre-run hook that turns the native collision passes on for the whole run (NativeSwitch), so the rule tests
## can be run against them. Fails the run if the native library is not loaded, rather than quietly testing GDScript:
##   godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd
##     -gpre_run_script=res://tests/support/native_move_hook.gd -gdir=... -gexit


func run() -> void:
	if not NativeSwitch.install(true):
		push_error("native_move_hook: the native library is not loaded")
		abort()
		return
	print("native_move_hook: the native collision passes are on")
