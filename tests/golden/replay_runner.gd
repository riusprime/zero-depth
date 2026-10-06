class_name ReplayRunner
extends RefCounted
## Runs a seeded kernel world with scripted input and records a hash every `every` ticks (SIM_CONTRACTS §10).


static func run(seed_value: int, ticks: int, every: int) -> Dictionary:
	var w := KernelScenario.golden(seed_value)
	var input := ScriptedInput.new(seed_value)
	var hashes := PackedStringArray()
	var hits := 0
	for t in ticks:
		w.step(input.frame(t))
		if (t + 1) % every == 0:
			hashes.append(w.state_hash())
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.HIT:
			hits += 1
	return {
		"seed": seed_value,
		"ticks": ticks,
		"every": every,
		"hashes": hashes,
		"final": w.state_hash(),
		"projectiles_alive": w.projectiles.size(),
		"recent_hits": hits,
	}
