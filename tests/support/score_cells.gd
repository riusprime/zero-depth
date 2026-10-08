class_name ScoreCells
extends RefCounted
## Every SCORECARD §2 cell from the scorecard's run records (v0.5.0 SCD). build() turns ScoreRun records (plus the
## bench's output and the content) into one Dictionary per metric:
##   {id, band, status, value, note}
## where status is "met", "missed", "no band yet", "no data" (nothing to measure on this sample) or "NOT YET RUN"
## (with the reason in note). A band from a source is checked as written; nothing is widened. Bands written as
## "GA §1–3" are open design questions (docs/design/ROGUELIKE_GAP_ANALYSIS_v0.1.md), so those cells report numbers and
## "no band yet". Mappings onto this game (rooms, encounters, starters, threat) are written in each cell's note and in
## SCORECARD.md (2026-10-08 note).

const IDS: Array[String] = [
	"M-CAUSE",
	"M-LIMIT",
	"M-GAP",
	"M-WIN",
	"M-ENGINE",
	"M-DROUGHT",
	"M-PICK",
	"M-DEAD",
	"M-TTK",
	"M-ENC",
	"M-FLOOR",
	"M-RUN",
	"M-THREAT",
	"M-CAP",
	"M-STRESS",
	"M-HAZARD",
	"M-BENCH",
	"M-MORT",
	"M-POWER",
	"M-SYNERGY",
	"M-LOOP",
	"M-DIVERGE",
	"M-GENERALIST",
]
const STATUSES: Array[String] = ["met", "missed", "no band yet", "no data", "NOT YET RUN"]
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
## The v0.4.0 PLAN TU starting band (expected-build bot): deaths on floor 1 under 30 %, by floor 3 30–60 %.
const TU_FLOOR1_DEATH_MAX := 0.30
const MIN_PICK_OFFERS := 5


## The cells. `records`: ScoreRun records; `bench`: the bench's JSON ({} = not run, `bench_note` says why);
## `stress`: StressMatrix rows ({kind: tags}); `kinds_by_floor` comes from the records.
static func build(
	records: Array, bench: Dictionary, bench_note: String, stress_tags: Dictionary
) -> Dictionary:
	var cells := {}
	cells["M-CAUSE"] = _cause(records)
	cells["M-LIMIT"] = _limit(records)
	cells["M-GAP"] = _gap(records)
	cells["M-WIN"] = _win(records)
	cells["M-ENGINE"] = _engine(records)
	cells["M-DROUGHT"] = _drought(records)
	cells["M-PICK"] = _pick(records)
	cells["M-DEAD"] = _dead(records)
	cells["M-TTK"] = _ttk(records)
	cells["M-ENC"] = _enc(records)
	cells["M-FLOOR"] = _floor(records)
	cells["M-RUN"] = _run(records)
	cells["M-THREAT"] = _threat(records)
	cells["M-CAP"] = _cap(records)
	cells["M-STRESS"] = _stress(records, stress_tags)
	cells["M-HAZARD"] = _hazard(records)
	cells["M-BENCH"] = _bench(bench, bench_note)
	cells["M-MORT"] = _mort(records)
	cells["M-POWER"] = _power(records)
	cells["M-SYNERGY"] = _synergy(records)
	cells["M-LOOP"] = _loop(records)
	cells["M-DIVERGE"] = _diverge(records)
	cells["M-GENERALIST"] = _generalist(records)
	for id: String in cells:
		cells[id]["id"] = id
	return cells


static func cell(band: String, status: String, value: Variant, note: String = "") -> Dictionary:
	assert(STATUSES.has(status), status)
	return {"band": band, "status": status, "value": value, "note": note}


# --- Groups and statistics -------------------------------------------------------------------------------------
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
		return {"wins": 0, "n": 0, "rate": 0.0, "lo": 0.0, "hi": 0.0}
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


static func _win_rate(rs: Array) -> Dictionary:
	var w := 0
	for r: Dictionary in rs:
		if won(r):
			w += 1
	return wilson(w, rs.size())


# --- P0 / P1 cells ---------------------------------------------------------------------------------------------
static func _cause(records: Array) -> Dictionary:
	var dmg := 0
	var bad := 0
	var first: Array = []
	for r: Dictionary in records:
		dmg += int(r["cause"]["damage"])
		bad += int(r["cause"]["violations"])
		for v in r["cause"]["first"]:
			if first.size() < 5:
				first.append(v)
	if dmg == 0:
		return cell("100%", "no data", {"damage": 0}, "no damage to the player in this sample")
	var share := snappedf(float(dmg - bad) / dmg, 0.0001)
	return cell(
		"100%",
		"met" if bad == 0 else "missed",
		{"damage": dmg, "violations": bad, "readable_share": share, "first_violations": first},
		"ReadableCause on every hit the bots took, every run"
	)


static func _limit(records: Array) -> Dictionary:
	var per_run: Array = []
	var by_effect := {}
	for r: Dictionary in records:
		if String(r["policy"]).begins_with("exploit:"):
			continue
		var n := 0
		for k: String in r["limit"]:
			n += int(r["limit"][k])
			by_effect[k] = int(by_effect.get(k, 0)) + int(r["limit"][k])
		per_run.append(n)
	if per_run.is_empty():
		return cell("0", "no data", {})
	var total := 0
	for n: int in per_run:
		total += n
	var runs_with := 0
	for n: int in per_run:
		if n > 0:
			runs_with += 1
	return cell(
		"0",
		"met" if total == 0 else "missed",
		{
			"runs": per_run.size(),
			"runs_with_limit": runs_with,
			"total": total,
			"per_run": dist(per_run),
			"by_effect": by_effect
		},
		(
			"LIMIT events per run over every non-exploit run. A LIMIT is either the chain watchdog or a sustain cap "
			+ "clipping (vampiric_core); by_effect splits them"
		)
	)


static func _gap(records: Array) -> Dictionary:
	var groups := by_label(records, is_specialist)
	if groups.is_empty():
		return cell("GA §1–3 (open design question)", "no data", {})
	var rates := {}
	var best := 0.0
	for k: String in groups:
		rates[k] = _win_rate(groups[k])
		best = maxf(best, float(rates[k]["rate"]))
	var gaps := {}
	for k: String in rates:
		gaps[k] = snappedf(best - float(rates[k]["rate"]), 0.0001)
	return cell(
		"GA §1–3 (open design question)",
		"no band yet",
		{"win_rate": rates, "best": best, "gap_to_best": gaps},
		"run win rate of each Blade/Gun x focus specialist (average preset) and its gap to the best"
	)


static func _win(records: Array) -> Dictionary:
	var groups := by_label(records, func(_r: Dictionary) -> bool: return true)
	var out := {}
	for k: String in groups:
		var rs: Array = groups[k]
		var floors := {}
		for f in [1, 2, 3]:
			var reached := 0
			var cleared := 0
			for r: Dictionary in rs:
				for fr: Dictionary in r["floors"]:
					if int(fr["floor"]) == f:
						reached += 1
						if fr["result"] == "next":
							cleared += 1
			floors[str(f)] = wilson(cleared, reached)
		out[k] = {"run": _win_rate(rs), "floor_clear": floors}
	var comp := []
	for r: Dictionary in records:
		if is_competent(r):
			comp.append(r)
	var died1 := 0
	for r: Dictionary in comp:
		var d: Variant = r["death"]
		if d != null and int(d["floor"]) == 1:
			died1 += 1
	var f1 := wilson(died1, comp.size())
	var status := "no data"
	if not comp.is_empty():
		status = "met" if float(f1["rate"]) < TU_FLOOR1_DEATH_MAX else "missed"
	return cell(
		"GA §1–3 (open); v0.4.0 PLAN TU starting band: competent dies on floor 1 in < 30 % of runs",
		status,
		{"by_policy": out, "competent_floor1_death": f1},
		"status checks only the TU starting band; the GA bands are an open design question"
	)


## Runs where the policy plays for a build (competent and specialists, average preset) and entered floor 1's Room 4.
static func _engine(records: Array) -> Dictionary:
	var n := 0
	var hit := 0
	for r: Dictionary in records:
		if not (is_competent(r) or is_specialist(r)):
			continue
		var deepest := 0
		for rm: Dictionary in r["rooms"]:
			if int(rm["floor"]) == 1:
				deepest = maxi(deepest, int(rm["room"]))
		if deepest < 4:
			continue
		n += 1
		for o: Dictionary in r["offers"]:
			if int(o["floor"]) == 1 and int(o["room"]) <= 4 and int(o["engine"]) > 0:
				hit += 1
				break
	if n == 0:
		return cell(">= 90% (v0.3.0 gate)", "no data", {"runs": 0}, "no run reached Room 4")
	var w := wilson(hit, n)
	return cell(
		">= 90% (v0.3.0 gate)",
		"met" if float(w["rate"]) >= 0.9 else "missed",
		w,
		(
			"share of runs (competent + specialists, average) that reached floor 1's Room 4 and were offered an "
			+ "engine card (Arc Field, Frost Nova, Flame Trail or an engine-tagged mod) at an altar, chest or shop "
			+ "opened in Rooms 0-4"
		)
	)


static func _drought(records: Array) -> Dictionary:
	var longest: Array = []
	for r: Dictionary in records:
		if not (is_competent(r) or is_specialist(r)):
			continue
		var relevant := {}
		for o: Dictionary in r["offers"]:
			if int(o["relevant"]) > 0:
				relevant[int(o["g"])] = true
		var last_g := 0
		for rm: Dictionary in r["rooms"]:
			last_g = maxi(last_g, int(rm["g"]))
		var streak := 0
		var best := 0
		for g in range(1, last_g + 1):
			if relevant.has(g):
				streak = 0
			else:
				streak += 1
				best = maxi(best, streak)
		longest.append(best)
	if longest.is_empty():
		return cell("<= 2 (PD-07)", "no data", {})
	var d := dist(longest)
	return cell(
		"<= 2 (PD-07)",
		"met" if float(d["max"]) <= 2.0 else "missed",
		{"longest_per_run": d},
		(
			"rooms counted over the run (start halls excluded); a room is build-relevant when a card offered in it "
			+ "is an ability or a mod (competent) or of the specialist's focus"
		)
	)


static func _pick(records: Array) -> Dictionary:
	var groups := by_label(records, func(r: Dictionary) -> bool: return is_normal(r))
	var table := {}
	var candidates := {}
	for k: String in groups:
		var offered := {}
		var picked := {}
		for r: Dictionary in groups[k]:
			for o: Dictionary in r["offers"]:
				for c: String in o["cards"]:
					offered[c] = int(offered.get(c, 0)) + 1
				for c: String in o["picked"]:
					picked[c] = int(picked.get(c, 0)) + 1
		var rows := {}
		var cards := offered.keys()
		cards.sort()
		for c: String in cards:
			var rate := float(picked.get(c, 0)) / int(offered[c])
			rows[c] = [int(offered[c]), int(picked.get(c, 0)), snappedf(rate, 0.0001)]
			if int(offered[c]) >= MIN_PICK_OFFERS and rate >= 0.9:
				if not candidates.has(c):
					candidates[c] = []
				(candidates[c] as Array).append(k)
		table[k] = rows
	var universal: Array = []
	for c: String in candidates:
		var everywhere := true
		for k: String in table:
			var row: Variant = table[k].get(c)
			if row != null and int(row[0]) >= MIN_PICK_OFFERS and float(row[2]) < 0.9:
				everywhere = false
		if everywhere and (candidates[c] as Array).size() >= 2:
			universal.append(c)
	universal.sort()
	return cell(
		"No item universally dominant (GA §1–3, no numeric threshold)",
		"no band yet",
		{"per_archetype": table, "picked_90pct_everywhere": universal},
		(
			"[offered, picked, pick rate] per card per archetype. Bots pick by a fixed score table "
			+ "(ScoreBot), so a rate measures the table, not a player; picked_90pct_everywhere lists cards picked in "
			+ ">= 90 % of >= 5 offers by every archetype that saw them that often (a lead reading, not a band)"
		)
	)


static func _dead(records: Array) -> Dictionary:
	var out := {}
	for b in ["blade", "gun"]:
		var rs: Array = []
		for r: Dictionary in records:
			if is_normal(r) and r["build"] == b:
				rs.append(r)
		out[b] = _win_rate(rs)
	return cell(
		"No dead starter (GA §1–3)",
		"no band yet",
		{"win_rate_by_build": out, "pick_through": "NOT YET RUN"},
		(
			"starters are the two builds (Blade, Gun) picked before a run. Win rate over every normal policy; "
			+ "pick-through needs human build picks (bots are assigned a build), NOT YET RUN until v0.6.0's "
			+ "human-session recordings"
		)
	)


static func _ttk(records: Array) -> Dictionary:
	var acc := {}
	for r: Dictionary in records:
		if not (is_competent(r) or is_specialist(r)):
			continue
		for fr: Dictionary in r["floors"]:
			for kind: String in fr["ttk"]:
				var key := "%s|floor %d|%s" % [r["build"], int(fr["floor"]), kind]
				if not acc.has(key):
					acc[key] = []
				for t: int in fr["ttk"][kind]:
					(acc[key] as Array).append(t / 60.0)
	var out := {}
	var keys := acc.keys()
	keys.sort()
	for k: String in keys:
		out[k] = dist(acc[k])
	return cell(
		"GA §1–3 (open design question)",
		"no band yet" if not out.is_empty() else "no data",
		out,
		(
			"seconds from an enemy's first hit by the player's side to its death, by build, floor and kind "
			+ "(competent + specialists, average preset; per-policy splits are in the run records)"
		)
	)


static func _enc(records: Array) -> Dictionary:
	var out := {}
	for f in [1, 2, 3]:
		var bouts: Array = []
		var boss: Array = []
		for r: Dictionary in records:
			if not is_normal(r):
				continue
			for fr: Dictionary in r["floors"]:
				if int(fr["floor"]) != f:
					continue
				for e: Array in fr["encounters"]:
					if bool(e[1]):
						boss.append(int(e[0]) / 60.0)
					else:
						bouts.append(int(e[0]) / 60.0)
		out[str(f)] = {"bouts_s": dist(bouts), "boss_s": dist(boss)}
	return cell(
		"GA §1–3 (open design question)",
		"no band yet",
		out,
		(
			"an encounter is a combat bout (an enemy within 12 m, gaps under 3 s merged) or a boss fight (door "
			+ "sealed to the boss's death); floors spawn continuously, so there is no fixed encounter list"
		)
	)


static func _floor(records: Array) -> Dictionary:
	var out := {}
	var mins: Array = []
	for f in [1, 2, 3]:
		var m: Array = []
		for r: Dictionary in records:
			if not is_normal(r):
				continue
			for fr: Dictionary in r["floors"]:
				if int(fr["floor"]) == f and fr["result"] == "next":
					m.append(int(fr["ticks"]) / 3600.0)
		out[str(f)] = dist(m)
		mins.append_array(m)
	var capped := 0
	for r: Dictionary in records:
		capped += int(r.get("explore_capped", 0))
	out["all"] = dist(mins)
	out["explore_budget_used_up"] = capped
	var status := "no data"
	if not mins.is_empty():
		var med := float(out["all"]["median"])
		status = "met" if med >= 10.0 and med <= 15.0 else "missed"
	return cell(
		"10–15 min (v0.3.0 gate)",
		status,
		out,
		(
			"minutes from a floor's start to its portal, floors the bot finished (normal policies). The bot explores "
			+ "every room, takes what it can afford, shops, farms for unaffordable chests, and heads for the boss "
			+ "after 15 min at most; status checks the median"
		)
	)


static func _run(records: Array) -> Dictionary:
	var mins: Array = []
	for r: Dictionary in records:
		if is_normal(r) and won(r):
			mins.append(int(r["run_ticks"]) / 3600.0)
	var d := dist(mins)
	if mins.is_empty():
		return cell(
			"median 35–45 (PD-03); every full run 30–60 (v0.5.0)",
			"no data",
			{"full_runs": d},
			"no bot finished a run in this sample, so no run length can be measured"
		)
	var all_in := true
	for m: float in mins:
		all_in = all_in and m >= 30.0 and m <= 60.0
	var med := float(d["median"])
	return cell(
		"median 35–45 (PD-03); every full run 30–60 (v0.5.0)",
		"met" if med >= 35.0 and med <= 45.0 and all_in else "missed",
		{"full_runs": d, "every_run_30_60": all_in},
		"minutes of play (floor clocks, portal holds included) of every finished run"
	)


static func _threat(records: Array) -> Dictionary:
	var base: Array = []
	var t: Array = []
	for r: Dictionary in records:
		if r["skill"] != "average":
			continue
		if r["policy"] == "competent":
			base.append(r)
		elif r["policy"] == "competent+t":
			t.append(r)
	if t.is_empty():
		return cell(
			"win rate falls as T rises; rewards make T worth it", "no data", {}, "no +t runs"
		)
	var cards := 0
	var bonus := 0
	var entered := 0
	var cleared := 0
	for r: Dictionary in t:
		for o: Dictionary in r["offers"]:
			if o["source"] == "overrun":
				cards += (o["picked"] as Array).size()
		for fr: Dictionary in r["floors"]:
			entered += 1 if bool(fr["overrun"]["entered"]) else 0
			cleared += 1 if bool(fr["overrun"]["cleared"]) else 0
			bonus += int(fr["overrun"]["bonus_shards"])
	var wr0 := _win_rate(base)
	var wr1 := _win_rate(t)
	var f1_0 := _floor_clear(base, 1)
	var f1_1 := _floor_clear(t, 1)
	var status := "missed"
	if float(wr1["rate"]) < float(wr0["rate"]) or (
		float(wr0["rate"]) == 0.0 and float(f1_1["rate"]) < float(f1_0["rate"])
	):
		status = "met"
	return cell(
		"win rate falls as T rises; rewards make T worth it (GA: threat)",
		status,
		{
			"t0_win": wr0,
			"t1_win": wr1,
			"t0_floor1_clear": f1_0,
			"t1_floor1_clear": f1_1,
			"overrun_entered": entered,
			"overrun_cleared": cleared,
			"overrun_cards": cards,
			"overrun_bonus_shards": bonus,
		},
		(
			"no threat number T exists on this base (EV adds it); T here is the Overrun room (v0.4.0 AB, the first T "
			+ "branch): competent (T = 0) against competent+t, which takes every floor's Overrun room, on the same "
			+ "seeds and builds. Status: the T = 1 win rate (floor 1 clears when no run is won) is below T = 0's; "
			+ "whether the rewards make T worth it is the owner's call"
		)
	)


static func _floor_clear(rs: Array, f: int) -> Dictionary:
	var reached := 0
	var cleared := 0
	for r: Dictionary in rs:
		for fr: Dictionary in r["floors"]:
			if int(fr["floor"]) == f:
				reached += 1
				cleared += 1 if fr["result"] == "next" else 0
	return wilson(cleared, reached)


static func _cap(records: Array) -> Dictionary:
	var acc := {}
	for r: Dictionary in records:
		for k: String in r["cap"]:
			if not acc.has(k):
				acc[k] = [0, 0]
			acc[k][0] += int(r["cap"][k][0])
			acc[k][1] += int(r["cap"][k][1])
	var out := {}
	var keys := acc.keys()
	keys.sort()
	for k: String in keys:
		var req: int = acc[k][0]
		out[k] = {
			"requested": req,
			"applied": acc[k][1],
			"applied_share": snappedf(float(acc[k][1]) / maxi(1, req), 0.0001)
		}
	return cell(
		"reported every version; bands from GA: caps (open)",
		"no band yet" if not out.is_empty() else "no data",
		out,
		(
			"HEAL and BARRIER events on the player, requested (amount) vs applied, by effect, every run. No refund "
			+ "event exists in the sim yet"
		)
	)


## The SCORECARD §4 rules over the data's stress tags (S) and the enemies the runs met on each floor. The data has
## no drain (D) tags.
static func _stress(records: Array, stress_tags: Dictionary) -> Dictionary:
	var seen := {}
	for r: Dictionary in records:
		for fr: Dictionary in r["floors"]:
			var f := str(fr["floor"])
			if not seen.has(f):
				seen[f] = {}
			for k: String in fr["kinds_seen"]:
				seen[f][k] = true
	var archetypes: Array = []
	for k: String in stress_tags:
		for tag: String in stress_tags[k]:
			if not archetypes.has(tag):
				archetypes.append(tag)
	archetypes.sort()
	var untagged: Array = []
	for f: String in ["element", "ordnance"]:
		if not archetypes.has(f):
			untagged.append(f)
	var rule_a := {}
	var ok := true
	var floors := seen.keys()
	floors.sort()
	for a: String in archetypes + untagged:
		rule_a[a] = {}
		for f: String in floors:
			var by: Array = []
			for k: String in seen[f]:
				if stress_tags.has(k) and (stress_tags[k] as Array).has(a):
					by.append(k)
			by.sort()
			rule_a[a][f] = by
			ok = ok and not by.is_empty()
	if floors.is_empty():
		return cell("all §4 rules", "no data", {})
	return cell(
		"all §4 rules",
		"met" if ok else "missed",
		{
			"rule_every_archetype_stressed_each_floor": rule_a,
			"rule_no_archetype_drained_by_all": "holds (no D tags in the data)",
			"rule_no_enemy_drains_two": "holds (no D tags in the data)",
			"kinds_seen_by_floor": _sorted_sets(seen),
			"untagged_archetypes": untagged,
		},
		(
			"tags from EnemyDefinition.stress_tags (S only; no D tag exists), floors from the enemies the bots met. "
			+ "The tags name the v0.2.0 engines (bleed, guard); the element and ordnance specialists have no tags, "
			+ "so the rule fails for them"
		)
	)


static func _sorted_sets(d: Dictionary) -> Dictionary:
	var out := {}
	var keys := d.keys()
	keys.sort()
	for k: String in keys:
		var v: Array = (d[k] as Dictionary).keys()
		v.sort()
		out[k] = v
	return out


static func _hazard(records: Array) -> Dictionary:
	var out := {}
	var worst := 0.0
	var any := false
	for f in [1, 2, 3]:
		var reached := {}
		var died := {}
		for r: Dictionary in records:
			if not is_normal(r):
				continue
			for fr: Dictionary in r["floors"]:
				if int(fr["floor"]) != f:
					continue
				var b: String = fr["biome"]
				reached[b] = int(reached.get(b, 0)) + 1
				died[b] = int(died.get(b, 0)) + (1 if fr["result"] == "died" else 0)
		var rates := {}
		var lo := 2.0
		var hi := -1.0
		var keys := reached.keys()
		keys.sort()
		for b: String in keys:
			rates[b] = wilson(died[b], reached[b])
			lo = minf(lo, float(rates[b]["rate"]))
			hi = maxf(hi, float(rates[b]["rate"]))
		var diff := snappedf((hi - lo) * 100.0, 0.01) if keys.size() >= 2 else 0.0
		if keys.size() >= 2:
			any = true
			worst = maxf(worst, diff)
		out[str(f)] = {"death_rate_by_biome": rates, "spread_pp": diff}
	if not any:
		return cell("<= 10 pp (v0.7.0 gate)", "no data", out, "no floor was played in two biomes")
	return cell(
		"<= 10 pp (v0.7.0 gate)",
		"met" if worst <= 10.0 else "missed",
		out,
		"a floor's death rate per biome (normal policies), and the widest spread between two biomes"
	)


static func _bench(bench: Dictionary, note: String) -> Dictionary:
	var band := "stress mean <= 2 ms, p99 <= 4 ms; reference >= 15x real time (ARCHITECTURE §13)"
	if bench.is_empty():
		return cell(band, "NOT YET RUN", {}, note)
	var ok := true
	var any := false
	for k in ["stress", "reference", "stress_ai", "reference_floor", "reference_boss"]:
		if bench.has(k + "_in_band"):
			any = true
			ok = ok and bool(bench[k + "_in_band"])
	var value := {}
	for k: String in bench:
		if bench[k] is Dictionary:
			var row := {}
			for f in ["mean_ms", "p99_ms", "realtime_x"]:
				if (bench[k] as Dictionary).has(f):
					row[f] = bench[k][f]
			value[k] = row
		else:
			value[k] = bench[k]
	return cell(
		band,
		("met" if ok else "missed") if any else "no data",
		value,
		"scripts/bench/sim_bench.gd (wall-clock timings: the only cell that is not byte-reproducible)" + note
	)


static func _mort(records: Array) -> Dictionary:
	var groups := by_label(records, func(r: Dictionary) -> bool: return is_normal(r))
	var out := {}
	for k: String in groups:
		var rows := {}
		var deaths := 0
		for r: Dictionary in groups[k]:
			var d: Variant = r["death"]
			if d == null:
				continue
			deaths += 1
			var key := "floor %d room %d%s" % [
				int(d["floor"]), int(d["room"]), " (boss)" if bool(d["in_boss_room"]) else ""
			]
			rows[key] = int(rows.get(key, 0)) + 1
		var sorted := {}
		var keys := rows.keys()
		keys.sort()
		for key: String in keys:
			sorted[key] = [rows[key], snappedf(float(rows[key]) / maxi(1, deaths), 0.0001)]
		out[k] = {"runs": (groups[k] as Array).size(), "deaths": deaths, "where": sorted}
	return cell(
		"reported every version; bands from GA §1–3 (open)",
		"no band yet" if not out.is_empty() else "no data",
		out,
		"[deaths, share of that archetype's deaths] per floor and room index (Room N of that floor)"
	)


static func _power(records: Array) -> Dictionary:
	var groups := by_label(records, func(r: Dictionary) -> bool: return is_normal(r))
	var out := {}
	for k: String in groups:
		var dps := {}
		var ehp := {}
		for r: Dictionary in groups[k]:
			for rm: Dictionary in r["rooms"]:
				var g := str(int(rm["g"]))
				if not ehp.has(g):
					ehp[g] = []
					dps[g] = []
				(ehp[g] as Array).append(int(rm["ehp"]))
				if int(rm["combat_ticks"]) >= 60:
					(dps[g] as Array).append(int(rm["dealt"]) * 60.0 / int(rm["combat_ticks"]))
		var rows := {}
		var gs := ehp.keys()
		gs.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
		for g: String in gs:
			rows[g] = {
				"dps_median": dist(dps[g])["median"],
				"ehp_median": dist(ehp[g])["median"],
				"n": (ehp[g] as Array).size()
			}
		out[k] = rows
	return cell(
		"no plateau longer than GA §3 allows, no vertical spike (open)",
		"no band yet" if not out.is_empty() else "no data",
		out,
		(
			"by the run's room count g (start halls excluded): median damage per combat second dealt while that was "
			+ "the latest room entered, and median effective HP on entering it (max HP / armour multiplier)"
		)
	)


static func _engine_of(effect: String) -> String:
	for e: String in ENGINE_EFFECTS:
		if (ENGINE_EFFECTS[e] as Array).has(StringName(effect)):
			return e
	return ""


static func _synergy(records: Array) -> Dictionary:
	var tags := {}
	for def: ItemDefinition in ContentRepository.load_all().all_of(&"items"):
		tags[String(def.id)] = def.tags
	var share_all: Array = []
	var acc := {}  # engine -> stacks -> [engine damage, total damage, floors]
	for r: Dictionary in records:
		if not is_normal(r):
			continue
		for fr: Dictionary in r["floors"]:
			var total := int(fr["dealt_total"])
			if total <= 0:
				continue
			var by_engine := {}
			var syn := 0
			for eff: String in fr["dealt_by_effect"]:
				var e := _engine_of(eff)
				if e != "":
					syn += int(fr["dealt_by_effect"][eff])
					by_engine[e] = int(by_engine.get(e, 0)) + int(fr["dealt_by_effect"][eff])
			share_all.append(float(syn) / total)
			var stacks := {}
			for id: String in fr["end_items"]:
				for t: String in tags.get(id, PackedStringArray()):
					stacks[t] = int(stacks.get(t, 0)) + 1
			for ab: Array in fr["end_abilities"]:
				var e: String = ENGINE_OF_ABILITY.get(StringName(ab[0]), "")
				if e != "":
					stacks[e] = int(stacks.get(e, 0)) + 1
			for e: String in ENGINE_EFFECTS:
				if e == "combo":
					continue
				var s := str(mini(int(stacks.get(e, 0)), 3))
				if not acc.has(e):
					acc[e] = {}
				if not acc[e].has(s):
					acc[e][s] = [0, 0, 0]
				acc[e][s][0] += int(by_engine.get(e, 0))
				acc[e][s][1] += total
				acc[e][s][2] += 1
	if share_all.is_empty():
		return cell("rises with stacks for every engine (GA §2)", "no data", {})
	var table := {}
	var rises := true
	var judged := 0
	for e: String in acc:
		var row := {}
		var prev := -1.0
		var buckets := 0
		for s in ["0", "1", "2", "3"]:
			if acc[e].has(s):
				var v: Array = acc[e][s]
				var share := float(v[0]) / maxi(1, int(v[1]))
				row[s + ("+" if s == "3" else "")] = {"share": snappedf(share, 0.0001), "floors": v[2]}
				if int(v[2]) >= 3:
					if prev >= 0.0 and share <= prev:
						rises = false
					prev = share
					buckets += 1
		if buckets >= 2:
			judged += 1
		table[e] = row
	var status := "no data"
	if judged > 0:
		status = "met" if rises else "missed"
	return cell(
		"rises with stacks for every engine (GA §2)",
		status,
		{"synergy_share_per_floor": dist(share_all), "engine_share_by_stacks": table},
		(
			"a floor's share of the player's damage from engine statuses, payoffs and combos (ENGINE_EFFECTS), by "
			+ "the engine's stacks at the floor's end (mods with its tag + its element ability; 3 = 3 or more). "
			+ "Status: the share must rise strictly from each bucket with >= 3 floors to the next; %d engine(s) had two such buckets" % judged
		)
	)


static func _loop(records: Array) -> Dictionary:
	var trades: Array = []
	var loops: Array = []
	var chain_runs := 0
	var chain_limits := {}
	var salvage_runs := 0
	for r: Dictionary in records:
		match r["policy"]:
			"exploit:salvage":
				salvage_runs += 1
				for e: Array in r["salvage"]:
					trades.append(e)
					if int(e[2]) >= int(e[1]):
						loops.append({"seed": r["seed"], "card_code": e[0], "spent": e[1], "back": e[2]})
			"exploit:chain":
				chain_runs += 1
				for k: String in r["limit"]:
					if k != "vampiric_core":
						chain_limits[k] = int(chain_limits.get(k, 0)) + int(r["limit"][k])
	var watchdog := 0
	for k: String in chain_limits:
		watchdog += int(chain_limits[k])
	if salvage_runs == 0 and chain_runs == 0:
		return cell("0", "no data", {})
	var spent := 0
	var back := 0
	for e: Array in trades:
		spent += int(e[1])
		back += int(e[2])
	return cell(
		"0",
		"met" if loops.is_empty() and watchdog == 0 else "missed",
		{
			"salvage_runs": salvage_runs,
			"salvage_trades": trades.size(),
			"salvage_spent": spent,
			"salvage_returned": back,
			"salvage_loops": loops,
			"chain_runs": chain_runs,
			"chain_watchdog_limits": chain_limits,
		},
		(
			"exploit:salvage buys every shop card it can and sells it straight back (a loop: returned >= spent); "
			+ "exploit:chain starts each floor with every named combo's items, a chain the watchdog had to stop "
			+ "counts. Cases not yet scripted: gamble-shrine shard gain, doorway cheese, Overrun farming"
		)
	)


static func _diverge(records: Array) -> Dictionary:
	var comp := {}
	for r: Dictionary in records:
		if is_competent(r):
			comp["%d|%s" % [int(r["seed"]), r["build"]]] = r
	var per := {}
	var all_g: Array = []
	var never := 0
	for r: Dictionary in records:
		if not is_specialist(r):
			continue
		var c: Variant = comp.get("%d|%s" % [int(r["seed"]), r["build"]])
		if c == null:
			continue
		var a: Array = r["picks"]
		var b: Array = c["picks"]
		var g := -1
		for k in maxi(a.size(), b.size()):
			if k >= a.size() or k >= b.size() or a[k]["card"] != b[k]["card"]:
				var src: Dictionary = a[k] if k < a.size() else b[k]
				g = int(src["g"])
				break
		var lbl := label(r)
		if not per.has(lbl):
			per[lbl] = []
		if g < 0:
			never += 1
		else:
			(per[lbl] as Array).append(g)
			all_g.append(g)
	if per.is_empty():
		return cell("by Room 3–4 (framework pillar 3)", "no data", {})
	var out := {}
	for k: String in per:
		out[k] = dist(per[k])
	var d := dist(all_g)
	var status := "no data"
	if not all_g.is_empty():
		status = "met" if float(d["median"]) <= 4.0 and never == 0 else "missed"
	return cell(
		"by Room 3–4 (framework pillar 3)",
		status,
		{"all": d, "by_specialist": out, "never_diverged": never},
		(
			"the run's room count g at the first card a specialist took differently from competent on the same "
			+ "seed and build. Both share movement code and draws, so their inputs are identical until then; "
			+ "status: median <= 4 and every pair diverged"
		)
	)


static func _generalist(records: Array) -> Dictionary:
	var comp: Array = []
	for r: Dictionary in records:
		if is_competent(r):
			comp.append(r)
	var groups := by_label(records, is_specialist)
	if comp.is_empty() or groups.is_empty():
		return cell("the generalist is below the best specialist", "no data", {})
	var gw := _win_rate(comp)
	var best := ""
	var best_rate := -1.0
	for k: String in groups:
		var w := _win_rate(groups[k])
		if float(w["rate"]) > best_rate:
			best_rate = float(w["rate"])
			best = k
	var bw := _win_rate(groups[best])
	return cell(
		"the generalist is below the best specialist (framework pillar 3)",
		"met" if float(gw["rate"]) < float(bw["rate"]) else "missed",
		{"competent": gw, "best_specialist": best, "best": bw},
		"run win rates, average preset; equal rates (e.g. both 0) count as a miss"
	)
