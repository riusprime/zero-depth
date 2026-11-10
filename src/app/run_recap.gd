class_name RunRecap
extends RefCounted
## The run recap's numbers (EndPanel, the pause menu's run line): floor reached, run time and kills over every floor,
## shards when the world counts them, and the items held. (moved here from Main.run_recap, unchanged.)


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
		"routes": run.routes.duplicate(),  # The route of each floor reached
		"loop": run.loop,  # The loop reached and the loops cleared
		"loops_cleared": run.loops_cleared(w),
		"true_ending": run.final_fight and driver.reader.final_won(),  # The final boss beaten
		"final_reached": run.final_fight,
		"fragments": RuneFragments.total(run, w),  # Rune Fragments (the end panel banks them)
		"rules": rule_keys(run),  # The loop rules held (name keys)
	}
	if &"shards" in w:
		out["shards"] = int(w.get(&"shards"))
	out["threat"] = driver.reader.threat()  # Threat T now, and the run's peak
	out["threat_peak"] = driver.reader.threat_peak()
	return out


## The name keys of the loop rules `run` holds, in the order drawn.
static func rule_keys(run: RunState) -> PackedStringArray:
	var out := PackedStringArray()
	for id in run.loop_rules:
		out.append(LoopRules.name_key(id))
	return out
