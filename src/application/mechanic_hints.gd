class_name MechanicHints
extends RefCounted
## v0.11.0 O2 (owner L4, Q12 a): which boss hints show. A reason's hint (ObjectiveMarkers, ObjectiveHints) shows the
## first MEETINGS runs in which the player meets it, then never again, and none show with Options "Boss hints" off
## (the `boss_hints` setting, on by default).
## The count lives in the Codex's profile section (CodexStore), page PAGE (outside CodexStore.PAGES, so no Codex page
## lists it): {reason: {"runs": the runs it was met in, "last_run": the run seed it was last counted for}}. A reason
## is met when a marker of it is in the world the hero plays (observe, from WorldReader; EI-07); a run counts once per
## reason, also across Quit and Continue (its run seed). An old profile without the page starts every reason at 0.
## Outside the run and the sim: never part of RunState, a save or any hash.

const SETTING := "boss_hints"
const PAGE := &"mechanics"
const RUNS := &"runs"
const LAST_RUN := &"last_run"
## A reason's hint shows in the first this-many runs that meet it.
const MEETINGS := 2
## Reasons whose hint shows at every meeting (v0.11.0 F5: the Gatekeeper's pillars, an arrow and no text).
const ALWAYS: Array[StringName] = [WorldReader.OBJECTIVE_GATEKEEPER_PILLAR]

var codex: CodexStore


func _init(p_codex: CodexStore) -> void:
	codex = p_codex


## Options "Boss hints" is on.
func enabled() -> bool:
	return String(GameSettings.get_value(codex.profile, SETTING)) != "off"


## The runs in which the player has met `reason` (this one included once it was met).
func runs(reason: StringName) -> int:
	return codex.count(PAGE, reason, RUNS)


## Which meeting run `run_seed` is for `reason`: its count if this run already counted, else the count plus one.
func meeting(reason: StringName, run_seed: int) -> int:
	var n := runs(reason)
	if n > 0 and codex.count(PAGE, reason, LAST_RUN) == run_seed:
		return n
	return n + 1


## The hint for `reason` shows in run `run_seed`: hints are on and this is one of its first MEETINGS runs.
func shows(reason: StringName, run_seed: int) -> bool:
	if reason in ALWAYS:
		return enabled()
	return enabled() and meeting(reason, run_seed) <= MEETINGS


## Counts run `run_seed` for every reason the world points at now (once per run).
func observe(reader: WorldReader, run_seed: int) -> void:
	for m: Dictionary in reader.objectives():
		meet(m["reason"], run_seed)


## Counts run `run_seed` for `reason` (nothing when that run already counted).
func meet(reason: StringName, run_seed: int) -> void:
	if reason == &"" or meeting(reason, run_seed) == runs(reason):
		return
	codex.add(PAGE, reason, RUNS)
	codex.put(PAGE, reason, LAST_RUN, run_seed)
