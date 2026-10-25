class_name FloorShape
extends RefCounted
## v0.9.0 FV (owner Q24, "we are gonna be making the game 5 floors"; PD-03 changed): what a run's floor is by its
## number within the loop, beside RunState (which is at the lint's method limit): its room range (about 10, 13, 15,
## 17 and 19 rooms, RunTable.rooms_min/max_by_floor; loops reuse the same sizes) and its boss (floors 4 and 5, until
## their own bosses arrive, draw one the run has not met yet). Pure sim code.


## Whether `run`'s current floor takes its size from the run (a five-floor run's floor; false without a run, for the
## v0.8.0 3-floor shape, and for a v0.7.0 floor resumed from an old save, which keep their own rules).
static func sized(run: RunState) -> bool:
	return run != null and not run.v070_floor() and not run.table.rooms_min_by_floor.is_empty()


## Sets `p`'s room range to floor f's of `run` (f within the loop; the last entry past the end) and returns `p`; a run
## without per-floor sizes (the v0.8.0 3-floor shape) leaves the map's range.
static func size_floor(run: RunState, p: FloorParams, f: int) -> FloorParams:
	var t := run.table
	var n := mini(t.rooms_min_by_floor.size(), t.rooms_max_by_floor.size())
	if n > 0:
		var k := clampi(f - 1, 0, n - 1)
		p.rooms_min = t.rooms_min_by_floor[k]
		p.rooms_max = t.rooms_max_by_floor[k]
	return p


## Floor f's boss (f within the loop) from every floor's pool (`pools[f − 1]`; RunContentCompiler.compile_boss_pools):
## its own pool when it has one (RunState.pick_boss, as before FV), else one of the pools' bosses not yet met on the
## loop's floors before it, so a run never meets a boss twice (any of them once every one is met). Drawn from the same
## `boss_<run floor>` stream. -1 when no pool names a boss.
static func boss(run: RunState, pools: Array[PackedInt32Array], f: int) -> int:
	if f >= 1 and f <= pools.size() and not pools[f - 1].is_empty():
		return run.pick_boss(pools[f - 1], run.run_floor(f))
	var met := PackedInt32Array()
	for k in range(1, f):
		met.append(boss(run, pools, k))
	var all := PackedInt32Array()
	var fresh := PackedInt32Array()
	for p in pools:
		for b in p:
			if not all.has(b):
				all.append(b)
				if not met.has(b):
					fresh.append(b)
	return run.pick_boss(fresh if not fresh.is_empty() else all, run.run_floor(f))
