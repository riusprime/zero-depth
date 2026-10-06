extends SceneTree
## 600-tick kernel runs over a seed range, one JSONL line per seed (seed, final hash, event counts).
## CI runs it twice and diffs the files, so any nondeterminism inside one OS fails the build.
##   godot --headless --path . -s scripts/sim/kernel_smoke.gd -- seeds=1..20 out=build/smoke_a.jsonl


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var bounds: PackedStringArray = String(args.get("seeds", "1..20")).split("..")
	var out_path: String = args.get("out", "build/kernel_smoke.jsonl")
	var lines := PackedStringArray()
	for s in range(int(bounds[0]), int(bounds[1]) + 1):
		var w := KernelScenario.golden(s)
		var input := ScriptedInput.new(s)
		for t in 600:
			w.step(input.frame(t))
		var counts := {}
		for e in w.events_since(0):
			var k: String = SimEvent.Kind.keys()[e.kind]
			counts[k] = int(counts.get(k, 0)) + 1
		lines.append(
			JSON.stringify({"seed": s, "final": w.state_hash(), "events": counts}, "", true)
		)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("kernel_smoke: cannot write %s" % out_path)
		quit(1)
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("kernel_smoke: %d runs -> %s" % [lines.size(), out_path])
	quit(0)
