class_name RunRecap
extends RefCounted
## The run recap's numbers (EndPanel, the pause menu's run line): floor reached, run time and kills over every floor,
## shards when the world counts them, and the items held. (v0.9.0 HB: moved here from Main.run_recap, unchanged.)


static func of(run: RunState, driver: SimDriver) -> Dictionary:
	if run == null or driver == null:
		return {}
	var w := driver.world
	var names: Array[String] = []
	for idx in driver.reader.items_owned():
		names.append(String(driver.reader.item_name_key(idx)))
	var out := {
		"floor": run.floor_index,
		"floors": run.table.floors,
		"seconds": float(run.total_ticks(w)) / SimTick.TICKS_PER_SECOND,
		"kills": run.total_kills(w),
		"items": names,
		"routes": run.routes.duplicate(),  # v0.5.0 RT: the route of each floor reached
		"loop": run.loop,  # v0.7.5 AP: the loop reached and the loops cleared
		"loops_cleared": run.loops_cleared(w),
		"true_ending": run.final_fight and driver.reader.final_won(),  # v0.8.0 FB1: the final boss beaten
		"final_reached": run.final_fight,
		"fragments": RuneFragments.total(run, w),  # v0.9.0 MP: Rune Fragments (the end panel banks them)
	}
	if &"shards" in w:
		out["shards"] = int(w.get(&"shards"))
	out["threat"] = driver.reader.threat()  # v0.5.0 EV: threat T now, and the run's peak
	out["threat_peak"] = driver.reader.threat_peak()
	return out
