class_name ScoreStats
extends RefCounted
## Groups and statistics for the scorecard's cells (v0.5.0 SCD; ScoreCells): archetype labels, which records a cell
## reads, win rates with 95 % Wilson intervals (SCORECARD §1.4) and nearest-rank distributions.

## Damage effect ids (SimEvent.effect_id) that come from a multiplicative interaction (M-SYNERGY): an engine's
## status ticks and payoffs, the named item combos and the ability combos, by engine. Everything else (weapon
## swings and bolts, the abilities' own hits, plain item procs) is additive.
const ENGINE_EFFECTS := {
	"fire": [&"ember_edge", &"cinder_shot", &"wildfire", &"napalm_drone", &"ember_ward"],
	"shock":
	[
		&"shock",
		&"shock_discharge",
		&"static_chain",
		&"overcharge",
		&"plasma_arc",
		&"storm_bombs",
		&"superconductor"
	],
	"bleed": [&"bleed", &"bleed_burst", &"blood_harvest"],
	"frost":
	[
		&"frost",
		&"freeze",
		&"cold_snap",
		&"frost_core",
		&"glacial_edge",
		&"glacier_ring",
		&"frozen_bastion",
		&"shatter_dash"
	],
	"guard": [&"bulwark", &"thorn_mantle", &"spiked_phase"],
	"heat": [&"heat_vent", &"meltdown", &"overclock_heat"],
	"combo":
	[&"resonance", &"shrapnel_storm", &"slipstream", &"blink_charge", &"blade_dance", &"wingman"],
}
## The engine an element ability brings (it counts as a stack of that engine).
const ENGINE_OF_ABILITY := {&"arc_field": "shock", &"frost_nova": "frost", &"flame_trail": "fire"}


## A record's archetype label: "<policy>:<build>", plus "@<skill>" off the average preset.
static func label(r: Dictionary) -> String:
	var s := "%s:%s" % [r["policy"], r["build"]]
	if r["skill"] != "average" and r["policy"] != "novice":
		s += "@%s" % r["skill"]
	return s


static func is_specialist(r: Dictionary) -> bool:
	return not String(r["focus"]).is_empty() and r["skill"] == "average"


static func is_competent(r: Dictionary) -> bool:
	return r["policy"] == "competent" and r["skill"] == "average"


## Records that play the game normally (no idle reference, no exploit search, no threat opt-in).
static func is_normal(r: Dictionary) -> bool:
	var p := String(r["policy"])
	return p != "idle" and not p.begins_with("exploit:") and not p.ends_with("+t")


static func by_label(records: Array, keep: Callable) -> Dictionary:
	var out := {}
	for r: Dictionary in records:
		if keep.call(r):
			var k := label(r)
			if not out.has(k):
				out[k] = []
			(out[k] as Array).append(r)
	var sorted := {}
	var keys := out.keys()
	keys.sort()
	for k in keys:
		sorted[k] = out[k]
	return sorted


## Wins over n with the 95 % Wilson interval: {wins, n, rate, lo, hi} (rates rounded to 4 places).
static func wilson(wins: int, n: int) -> Dictionary:
	if n <= 0:
		return {"wins": 0, "n": 0, "rate": null, "lo": null, "hi": null}  # nothing measured, no number
	var z := 1.959964
	var p := float(wins) / n
	var den := 1.0 + z * z / n
	var centre := (p + z * z / (2.0 * n)) / den
	var half := z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / den
	return {
		"wins": wins,
		"n": n,
		"rate": snappedf(p, 0.0001),
		"lo": snappedf(maxf(0.0, centre - half), 0.0001),
		"hi": snappedf(minf(1.0, centre + half), 0.0001),
	}


## Median, p10 and p90 (nearest rank) of numbers, rounded to 3 places: {n, median, p10, p90, max}.
static func dist(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0, "median": null, "p10": null, "p90": null, "max": null}
	var v := values.duplicate()
	v.sort()
	return {
		"n": v.size(),
		"median": snappedf(_rank(v, 0.5), 0.001),
		"p10": snappedf(_rank(v, 0.1), 0.001),
		"p90": snappedf(_rank(v, 0.9), 0.001),
		"max": snappedf(float(v[-1]), 0.001),
	}


static func _rank(sorted: Array, q: float) -> float:
	var k := clampi(int(ceil(q * sorted.size())) - 1, 0, sorted.size() - 1)
	return float(sorted[k])


static func won(r: Dictionary) -> bool:
	return r["result"] == "won"


static func win_rate(rs: Array) -> Dictionary:
	var w := 0
	for r: Dictionary in rs:
		if won(r):
			w += 1
	return wilson(w, rs.size())


static func floor_clear(rs: Array, f: int) -> Dictionary:
	var reached := 0
	var cleared := 0
	for r: Dictionary in rs:
		for fr: Dictionary in r["floors"]:
			if int(fr["floor"]) == f:
				reached += 1
				cleared += 1 if fr["result"] == "next" else 0
	return wilson(cleared, reached)


static func sorted_sets(d: Dictionary) -> Dictionary:
	var out := {}
	var keys := d.keys()
	keys.sort()
	for k: String in keys:
		var v: Array = (d[k] as Dictionary).keys()
		v.sort()
		out[k] = v
	return out


## The engine whose effect id `effect` is (ENGINE_EFFECTS), or "".
static func engine_of(effect: String) -> String:
	for e: String in ENGINE_EFFECTS:
		if (ENGINE_EFFECTS[e] as Array).has(StringName(effect)):
			return e
	return ""
