class_name FloorShape
extends RefCounted
## What a run's floor is by its
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
## A floor's own pool loses the bosses already met too (floor 1's pool shares the Brood
## Mother with floor 2's: when floor 1 drew her, floor 2 draws its other boss); a pool that holds none of them draws
## exactly as before. A run saved before O11 (RunState.BOSS_DRAW_LEGACY) draws as it did then: each pool without the
## bosses a deeper pool also names (floor 1: the Gatekeeper and the Warlord), the bosses met not read.
static func boss(run: RunState, pools: Array[PackedInt32Array], f: int) -> int:
	var own := f >= 1 and f <= pools.size() and not pools[f - 1].is_empty()
	if own and run.boss_draw == RunState.BOSS_DRAW_LEGACY:
		return run.pick_boss(_without_deeper(pools, f), run.run_floor(f))
	var met := PackedInt32Array()
	for k in range(1, f):
		met.append(boss(run, pools, k))
	if own:
		var left := PackedInt32Array()
		for b in pools[f - 1]:
			if not met.has(b):
				left.append(b)
		return run.pick_boss(left if not left.is_empty() else pools[f - 1], run.run_floor(f))
	var all := PackedInt32Array()
	var fresh := PackedInt32Array()
	for p in pools:
		for b in p:
			if not all.has(b):
				all.append(b)
				if not met.has(b):
					fresh.append(b)
	return run.pick_boss(fresh if not fresh.is_empty() else all, run.run_floor(f))


## Floor f's pool without the bosses a deeper floor's pool also names (the pool before O11 shared
## one; the whole pool if that would empty it).
static func _without_deeper(pools: Array[PackedInt32Array], f: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for b in pools[f - 1]:
		var deeper := false
		for k in range(f, pools.size()):
			deeper = deeper or pools[k].has(b)
		if not deeper:
			out.append(b)
	return out if not out.is_empty() else pools[f - 1]
