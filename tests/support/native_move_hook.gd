extends GutHookScript
## A GUT pre-run hook that turns native kernels on for the whole run (NativeSwitch), so the rule tests can be run
## against them: the kernels the environment names (ZD_NATIVE_MOVE=1, ZD_NATIVE_AI=1, ..., ZD_NATIVE_ALL=1), or the
## collision passes (move) when it names none. Fails the run if the native library is not loaded, rather than
## quietly testing GDScript:
##   godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd
##     -gpre_run_script=res://tests/support/native_move_hook.gd -gdir=... -gexit


func run() -> void:
	var want := NativeSwitch.requested()
	if want == 0:
		want = NativeWorld.MOVE
	if NativeSwitch.install(want) != want:
		push_error("native_move_hook: the native library is not loaded")
		abort()
		return
	print("native_move_hook: native kernels on: %s" % NativeWorld.names_of(want))
