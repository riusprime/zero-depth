class_name RuneFragments
extends RefCounted
## v0.9.0 MP (PLAN W49-W50, Q28): the Rune Fragments a floor earned, read from the floor's own state (no new state,
## no event: the boss's flow, the secrets' solved flags, the final fight). RunState.finish_floor adds a finished
## floor's to the run's tally; total() adds the current floor's so far. The profile banks the tally
## when the run ends (MetaProgress, app side). Pure.


## The run's Rune Fragments including the current floor's so far (`w`; null = the finished floors only).
static func total(run: RunState, w: World) -> int:
	return run.fragments_done + of_floor(w, run.fragment_table, false)


## CL's hook: `n` collectibles found in `run`, each worth FragmentTable.collectible.
static func add_collectibles(run: RunState, n: int = 1) -> void:
	if run.fragment_table != null:
		run.fragments_done += run.fragment_table.collectible * n


## The secrets found on floor `w`: the timed door opened, the rune puzzle solved, the cracked wall broken, the purple
## runes awakened.
static func secrets_found(w: World) -> int:
	var n := 0
	if w.timed != null and w.timed.opened > 0:
		n += 1
	if w.runes != null and w.runes.solved > 0:
		n += 1
	if w.breakables != null and w.breakables.has_crack() and w.breakables.crack_broken > 0:
		n += 1
	if w.purple != null and w.purple.lit > 0:
		n += 1
	return n


## The fragments floor `w` earned under table `t` (null: none). `cleared`: its portal was taken (RunState.finish_floor),
## which also counts the Purple Portal when that was the gate taken.
static func of_floor(w: World, t: FragmentTable, cleared: bool) -> int:
	if t == null or w == null:
		return 0
	var n := secrets_found(w) * t.secret
	if w.final_fight != null:
		return n + (t.final_boss if w.final_fight.won else 0)
	if w.boss_flow != null and w.boss_flow.state >= BossFlow.State.OPEN:
		n += t.boss
	if cleared:
		n += t.floor_cleared
		if w.boss_flow != null and w.boss_flow.route_taken == Routes.Route.DEEP:
			n += t.purple_portal
	return n
