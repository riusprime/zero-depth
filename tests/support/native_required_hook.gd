extends GutHookScript
## The GUT run's pre-run and post-run hook (res://.gutconfig.json): the sim runs only in the native library, so a run
## without it stops before the first test with the one error (NativeWorld.MISSING: how to build it) and exit code 1,
## instead of hundreds of failing tests. As the post-run hook it does nothing.


func run() -> void:
	if gut.get_pre_run_script_instance() != self or NativeWorld.available():
		return
	NativeWorld.report_missing()
	var post: GutHookScript = gut.get_post_run_script_instance()
	if post != null:
		post.set_exit_code(1)
	abort()
