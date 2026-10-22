extends SceneTree
## v0.8.0 BV (owner O91; docs/roadmap/v0.8.0/BALANCE_PASS.md "BV: validation"): seeded reward sampling over the game's
## own reward code, floor by floor, with a scripted build-seeking pick (LootSampler: the run model, the sources, the
## assumptions and the pick are documented there). Prints the tables and writes build/loot_sample.txt, plus every run's
## build at every floor end in build/loot_wands.txt (scripts/checks/build_fights.gd from_loot= fights them). Paste
## into evidence by hand; this tool never writes outside build/.
##   godot --headless --path . -s scripts/checks/loot_sample.gd -- seeds=200 weapon=both
## Args: seeds=N (runs per weapon, seeds 1..N), weapon=blade|gun|both, loops=L (1: floors 1-3 of a normal route; 2
## adds loop 2), income=S (shards added at each floor's entry, an assumption), cores=N (elite cores stolen a floor),
## rerolls=N (shop rerolls at most), shop_rank=R (the worst pick rank the shop buys), show=N (runs whose wands are
## printed in full).
## Determinism: the first seed of each weapon runs twice; every floor's World.state_hash must match (MATCH/MISMATCH).

const OUT := "res://build/loot_sample.txt"
const WANDS := "res://build/loot_wands.txt"

var _lines := PackedStringArray()


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var seeds := int(args.get("seeds", 200))
	var loops := int(args.get("loops", 1))
	var show := int(args.get("show", 3))
	var weapons: Array[StringName] = [&"blade", &"gun"]
	var wa := String(args.get("weapon", "both"))
	if wa != "both":
		weapons = [StringName(wa)]
	var repo := ContentRepository.load_all()
	var sampler := LootSampler.new(repo)
	sampler.income = int(args.get("income", sampler.income))
	sampler.cores = int(args.get("cores", sampler.cores))
	sampler.rerolls = int(args.get("rerolls", sampler.rerolls))
	sampler.shop_rank = int(args.get("shop_rank", sampler.shop_rank))
	_line(
		(
			"loot_sample: seeds=%d weapons=%s loops=%d income=%d cores=%d rerolls=%d shop_rank=%d"
			% [
				seeds,
				weapons,
				loops,
				sampler.income,
				sampler.cores,
				sampler.rerolls,
				sampler.shop_rank
			]
		)
	)
	var wand_lines := PackedStringArray()
	wand_lines.append(
		"# seed weapon loop floor jackpot_ever early p_end | tokens (LootSampler.tokens)"
	)
	for weapon in weapons:
		var recs: Array = []  # per run: Array[Dictionary] (one per floor)
		for s in range(1, seeds + 1):
			var run := sampler.run(s, weapon, loops)
			recs.append(run)
			for r: Dictionary in run:
				wand_lines.append(
					(
						"%d %s %d %d %d %d %d | %s"
						% [
							s,
							weapon,
							r["loop"],
							r["floor"],
							r["jackpot_ever"],
							r["early"],
							r["p_end"],
							r["tokens"]
						]
					)
				)
		_report(weapon, recs, show)
		var again := sampler.run(1, weapon, loops)
		_line(
			(
				"determinism %s seed 1, %d floors run twice: %s"
				% [weapon, again.size(), _same(recs[0], again)]
			)
		)
	_write(OUT, _lines)
	_write(WANDS, wand_lines)
	quit(0)


func _same(a: Array, b: Array) -> String:
	if a.size() != b.size():
		return "MISMATCH (floors %d vs %d)" % [a.size(), b.size()]
	for k in a.size():
		if a[k]["hash"] != b[k]["hash"]:
			return "MISMATCH at floor record %d (%s vs %s)" % [k, a[k]["hash"], b[k]["hash"]]
	return "MATCH (last hash %s)" % [a[a.size() - 1]["hash"] if not a.is_empty() else "-"]


func _report(weapon: StringName, recs: Array, show: int) -> void:
	var n_floors := 0
	for run: Array in recs:
		n_floors = maxi(n_floors, run.size())
	_line("== %s: %d runs ==" % [weapon, recs.size()])
	for f in n_floors:
		var rows: Array[Dictionary] = []
		for run: Array in recs:
			if f < run.size():
				rows.append(run[f])
		if rows.is_empty():
			continue
		var head: Dictionary = rows[0]
		_line(
			(
				"-- %s loop %d floor %d (%d runs; per-run means unless a total) --"
				% [weapon, head["loop"], head["floor"], rows.size()]
			)
		)
		_line("offers opened (mean): %s" % _mean_dict(rows, "offers"))
		_line("cards seen by category (mean): %s" % _mean_dict(rows, "seen"))
		_line("cards taken by category (mean): %s" % _mean_dict(rows, "taken"))
		_line(
			(
				"level-ups taken %.2f  purchases %.2f  shards spent %.1f  rerolls %.2f  chests left shut %.2f"
				% [
					_mean(rows, "level_ups"),
					_mean(rows, "purchases"),
					_mean(rows, "spent"),
					_mean(rows, "rerolls"),
					_mean(rows, "chests_shut")
				]
			)
		)
		_line(
			(
				"jackpots seen %d taken %d (runs with one taken by now: %d)  mutations seen %d taken %d (totals)"
				% [
					_sum(rows, "jackpots_seen"),
					_sum(rows, "jackpots_taken"),
					_sum(rows, "jackpot_ever"),
					_sum(rows, "mutations_seen"),
					_sum(rows, "mutations_taken")
				]
			)
		)
		var lv := PackedInt32Array([0, 0, 0, 0, 0])
		for r in rows:
			var l: PackedInt32Array = r["levels"]
			for k in 5:
				lv[k] += l[k]
		_line("wand card levels at floor end (totals L1..L5): %s" % lv)
		_line(
			(
				"shards at entry (carry + income) median %d, at end median %d"
				% [_median(rows, "shards_in"), _median(rows, "shards_end")]
			)
		)
		_line(
			(
				"catch-up: P at entry median %d, P at end median %d (p90 %d), m at entry median %d, boss m median %d"
				% [
					_median(rows, "p_entry"),
					_median(rows, "p_end"),
					_pct(rows, "p_end", 90),
					_median(rows, "m_entry"),
					_median(rows, "m_boss")
				]
			)
		)
		for k in mini(show, rows.size()):
			_line("  run %d wand: %s" % [k + 1, rows[k]["wand"]])


func _mean(rows: Array[Dictionary], key: String) -> float:
	return float(_sum(rows, key)) / maxf(rows.size(), 1)


func _sum(rows: Array[Dictionary], key: String) -> int:
	var s := 0
	for r in rows:
		s += int(r[key])
	return s


func _median(rows: Array[Dictionary], key: String) -> int:
	return _pct(rows, key, 50)


func _pct(rows: Array[Dictionary], key: String, p: int) -> int:
	var v := PackedInt32Array()
	for r in rows:
		v.append(int(r[key]))
	v.sort()
	return v[mini(v.size() - 1, v.size() * p / 100)] if not v.is_empty() else 0


func _mean_dict(rows: Array[Dictionary], key: String) -> String:
	var tot := {}
	for r in rows:
		var d: Dictionary = r[key]
		for k: String in d:
			tot[k] = int(tot.get(k, 0)) + int(d[k])
	var keys := tot.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k: String in keys:
		parts.append("%s %.2f" % [k, float(tot[k]) / maxf(rows.size(), 1)])
	return ", ".join(parts)


func _line(s: String) -> void:
	print(s)
	_lines.append(s)


static func _write(path: String, lines: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")
