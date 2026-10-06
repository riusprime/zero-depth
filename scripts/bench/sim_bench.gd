extends SceneTree
## Sim tick cost (ARCHITECTURE §13, decided 2026-10-06):
## - stress: 60 movers, ~300 projectiles, 40 walls; mean <= 2 ms per tick, p99 <= 4 ms;
## - reference: 12 movers, ~40 projectiles, 12 walls; headless >= 15x real time.
## Writes build/bench.json and prints a summary; paste the output into evidence by hand.
##   godot --headless --path . -s scripts/bench/sim_bench.gd

const TICKS := 3600


func _initialize() -> void:
	var stress := _run("stress", _scene(11, 60, 5, 360, 36))
	var reference := _run("reference", _scene(12, 12, 16, 140, 8))
	var ok_stress: bool = stress["mean_ms"] <= 2.0 and stress["p99_ms"] <= 4.0
	var ok_ref: bool = reference["realtime_x"] >= 15.0
	var doc := {
		"godot": Engine.get_version_info()["string"],
		"stress": stress,
		"reference": reference,
		"stress_in_band": ok_stress,
		"reference_in_band": ok_ref,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open("res://build/bench.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t", true) + "\n")
	f.close()
	print(JSON.stringify(doc, "\t", true))
	quit(0)


## Movers keep 9 m away and shots spread ±45°, so projectiles live long enough to reach the target counts.
func _scene(seed_value: int, movers: int, period: int, life: int, inner_walls: int) -> World:
	var w := KernelScenario.build(seed_value, movers, period, life, inner_walls)
	w.dummy_keep_distance = 9.0
	w.dummy_aim_spread = 512
	return w


func _run(label: String, w: World) -> Dictionary:
	var input := ScriptedInput.new(7)
	var costs := PackedFloat64Array()
	costs.resize(TICKS)
	var live_projectiles := 0
	var t_start := Time.get_ticks_usec()
	for t in TICKS:
		var frame := input.frame(t)
		var t0 := Time.get_ticks_usec()
		w.step(frame)
		costs[t] = (Time.get_ticks_usec() - t0) / 1000.0
		live_projectiles += w.projectiles.size()
	var total_s := (Time.get_ticks_usec() - t_start) / 1000000.0
	var sorted := costs.duplicate()
	sorted.sort()
	var sum := 0.0
	for c in costs:
		sum += c
	return {
		"scene": label,
		"actors": w.actors.size(),
		"walls": w.walls.size(),
		"mean_projectiles": snappedf(float(live_projectiles) / TICKS, 0.1),
		"mean_ms": snappedf(sum / TICKS, 0.001),
		"p50_ms": snappedf(sorted[TICKS / 2], 0.001),
		"p99_ms": snappedf(sorted[int(TICKS * 0.99)], 0.001),
		"realtime_x": snappedf((TICKS / 60.0) / total_s, 0.1),
	}
