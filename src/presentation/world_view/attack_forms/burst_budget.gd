class_name BurstBudget
extends RefCounted
## v0.8.0 PF (owner O9: Spread + Split + Explosive "goes two FPS … maybe we can stop applying some effects"): how
## many VfxLayer bursts (explosions, bomb landings) AttackFormCanvas keeps alive. Below BURST_CROWD every burst is
## kept, as before. With BURST_CROWD or more alive, a new one within MERGE_M of a live burst that started within
## MERGE_TICKS of it is merged into that one (not added); with MAX_LIVE alive, the oldest goes to make room. Starting
## values from the probe (scripts/checks/perf_probe.gd; docs/roadmap/v0.8.0/evidence/PERF.md). Presentation only.

const MAX_LIVE := 32
const BURST_CROWD := 12
const MERGE_M := 1.2
const MERGE_TICKS := 12.0
## admit()'s answer when the new burst merges into a live one.
const MERGED := -2
## admit()'s answer when it joins and nothing goes.
const JOIN := -1


## Whether burst `e` ({origin, start}) joins `effects` (the canvas's live effects; bursts carry "vfx_burst"):
## MERGED, JOIN, or the index of the oldest burst to drop before it joins.
static func admit(effects: Array[Dictionary], e: Dictionary) -> int:
	var live := 0
	var oldest := -1
	var near := false
	var at: Vector2 = e["origin"]
	var start: float = e["start"]
	for k in effects.size():
		var o := effects[k]
		if not o.has("vfx_burst"):
			continue
		live += 1
		if oldest < 0:
			oldest = k
		if not near and absf(float(o["start"]) - start) <= MERGE_TICKS:
			near = (o["origin"] as Vector2).distance_to(at) < MERGE_M
	if near and live >= BURST_CROWD:
		return MERGED
	return oldest if live >= MAX_LIVE else JOIN
