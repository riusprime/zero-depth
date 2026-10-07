class_name ProcLedger
extends RefCounted
## Which item effects already fired in which root chain (SIM_CONTRACTS §7 RootLedger, the part the engines need):
## one record per (root, effect code, target id). Engines.try_fire asks it before every payoff, so each effect
## fires at most once per root chain (per target for status payoffs, as Ember Edge's burn does). A root lives a
## few ticks (a swing, a bolt's flight), so records older than KEEP_TICKS are dropped in tick phase 8. Hashed.

const KEEP_TICKS := 240

var roots := PackedInt32Array()
var codes := PackedInt32Array()
var targets := PackedInt32Array()
var ticks := PackedInt32Array()


func size() -> int:
	return roots.size()


## True if (root, code, target) is new, and records it; false if it already fired.
func try_mark(root: int, code: int, target: int, tick: int) -> bool:
	for k in roots.size():
		if roots[k] == root and codes[k] == code and targets[k] == target:
			return false
	roots.append(root)
	codes.append(code)
	targets.append(target)
	ticks.append(tick)
	return true


func has(root: int, code: int, target: int) -> bool:
	for k in roots.size():
		if roots[k] == root and codes[k] == code and targets[k] == target:
			return true
	return false


## Drops records older than KEEP_TICKS (they are in tick order, so the old ones are at the front).
func prune(tick: int) -> void:
	var n := 0
	while n < ticks.size() and tick - ticks[n] > KEEP_TICKS:
		n += 1
	if n == 0:
		return
	roots = roots.slice(n)
	codes = codes.slice(n)
	targets = targets.slice(n)
	ticks = ticks.slice(n)


func hash_into(h: StateHasher) -> void:
	h.add_ints(roots)
	h.add_ints(codes)
	h.add_ints(targets)
	h.add_ints(ticks)
