extends SceneTree
## v0.9.0 SV (PLAN "Owner decisions" EL, SV: "we should not make the player rely on picking dmg reduction cards this
## hard … I am not able to get to the finall boss due to dying way too fast"): whole five-floor runs played by scripted
## heroes (tests/support/survival_run.gd, a damage ledger: healed every tick, the HP lost counted per floor), with no
## defence card and with one a floor, then the HP pool replayed from each ledger under the rules before SV (no growth,
## 40 % heal) and after (data/run/five_floors.tres: +15 max HP a floor, 60 % heal), at shares of the bot's damage a
## player takes (100 % = the bot itself). For each: how many runs reach the final boss and beat it, the mean HP on
## arrival, at the boss door and after the boss, floor by floor, and per seed the largest share that still reaches the
## final boss. Not the retired balance bots (SCORECARD): a survival check, read against the owner's play.
## Prints the tables and writes build/balance/survival.txt; copy the printed output into evidence by hand.
##   godot --headless --path . -s scripts/balance/survival.gd -- seeds=20 from=1 floor_s=90

const Run := preload("res://tests/support/survival_run.gd")
## [label, weapon, defence]
const SETS := [
	["blade, no defence card", &"blade", false],
	["gun, no defence card", &"gun", false],
	["blade, a defence card a floor", &"blade", true],
	["gun, a defence card a floor", &"gun", true],
]
const SHARES := [1000, 500, 350, 250, 200, 150, 100]
## The shares the floor-by-floor HP table is printed at.
const TABLE_SHARES := [1000, 250]


func _initialize() -> void:
	var seeds := 20
	var from := 1
	var floor_s := 90
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.trim_prefix("seeds="))
		elif a.begins_with("from="):
			from = int(a.trim_prefix("from="))
		elif a.begins_with("floor_s="):
			floor_s = int(a.trim_prefix("floor_s="))
		elif a.begins_with("only="):
			only = a.trim_prefix("only=")
	var repo := ContentRepository.load_all()
	var after_table := ContentCompiler.compile_run(repo.get_def(&"run", RunSaver.RUN_ID))
	var rules := [["before SV", true, 400], ["after SV", false, after_table.heal_permille]]
	var lines: Array[String] = []
	var head := (
		"survival: seeds %d..%d, %d s of floor fighting a floor, %d stat cards a floor;"
		% [from, from + seeds - 1, floor_s, Run.CARDS_PER_FLOOR]
	)
	head += (
		" after SV: +%d max HP a floor, heal %d permille"
		% [after_table.max_hp_per_floor, after_table.heal_permille]
	)
	lines.append(head)
	var t0 := Time.get_ticks_msec()
	for s: Array in SETS:
		if only != "" and not (s[0] as String).contains(only):
			continue
		var runs: Array = []
		for k in seeds:
			var r = Run.new(repo, from + k, s[1], s[2])
			r.floor_s = floor_s
			r.play()
			runs.append(r)
			print(
				(
					"  %s seed %d: %s final lost %d won %s%s"
					% [s[0], from + k, r.floors, r.final_lost, r.final_won, r.note]
				)
			)
		var block := _block(s[0], runs, rules, after_table.boss_room_heal_floor_permille)
		print("\n".join(block))
		lines.append_array(block)
	lines.append("took %d s" % ((Time.get_ticks_msec() - t0) / 1000))
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute("res://build/balance")
	var f := FileAccess.open("res://build/balance/survival.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
	quit(0)


static func _block(
	label: String, runs: Array, rules: Array, room_heal: PackedInt32Array
) -> Array[String]:
	var out: Array[String] = ["", "== %s (%d runs)" % [label, runs.size()]]
	var lost := "  the bot's HP lost (mean) floor/boss:"
	for f in range(1, 6):
		var a := 0
		var b := 0
		var mx_after := 0
		var mx_before := 0
		for r in runs:
			var row: Array = r.floors[f - 1]
			a += row[3]
			b += row[4]
			mx_after += row[1]
			mx_before += row[2]
		var n := runs.size()
		lost += (
			" F%d %d/%d (max HP %d before, %d after);"
			% [f, a / n, b / n, mx_before / n, mx_after / n]
		)
	var fl := 0
	var won := 0
	for r in runs:
		fl += r.final_lost
		won += 1 if r.final_won else 0
	out.append(lost)
	out.append(
		(
			"  final fight: HP lost %d (mean), the healed bot beat it %d/%d"
			% [fl / runs.size(), won, runs.size()]
		)
	)
	out.append(
		(
			"  share of the bot's damage | "
			+ " | ".join(rules.map(func(x: Array) -> String: return x[0]))
		)
	)
	for sh: int in SHARES:
		var cells: Array[String] = []
		for rule: Array in rules:
			var reached := 0
			var beat := 0
			var died := [0, 0, 0, 0, 0, 0]
			for r in runs:
				var p: Array = Run.pool(r, rule[1], rule[2], room_heal, sh)
				if p[0] == 0:
					reached += 1
					beat += 1 if p[3] else 0
				else:
					died[p[0]] += 1
			cells.append(
				(
					"reach %d/%d, beat %d, died on F1-F5 %s"
					% [reached, runs.size(), beat, str(died.slice(1))]
				)
			)
		out.append("  %d%% | %s" % [sh / 10, " | ".join(cells)])
	for rule: Array in rules:
		var best := []
		for r in runs:
			var top := 0
			for sh in range(10, 1001, 10):
				if (Run.pool(r, rule[1], rule[2], room_heal, sh) as Array)[0] == 0:
					top = sh
			best.append(top)
		best.sort()
		(
			out
			. append(
				(
					"  %s: the largest share that still reaches the final boss, per seed (%%): median %d, min %d, max %d"
					% [
						rule[0],
						best[best.size() / 2] / 10,
						best[0] / 10,
						best[best.size() - 1] / 10
					]
				)
			)
		)
	for sh: int in TABLE_SHARES:
		for rule: Array in rules:
			(
				out
				. append(
					(
						"  HP by floor at %d%% of the bot's damage, %s: floor | reached | arrive | boss door | after boss"
						% [sh / 10, rule[0]]
					)
				)
			)
			for f in range(1, 6):
				var sums := [0, 0, 0]
				var n := 0
				for r in runs:
					var p: Array = Run.pool(r, rule[1], rule[2], room_heal, sh)
					if p[1].size() >= f:
						n += 1
						for j in 3:
							sums[j] += p[1][f - 1][j]
				if n == 0:
					out.append("    %d | 0 | - | - | -" % f)
				else:
					out.append(
						"    %d | %d | %d | %d | %d" % [f, n, sums[0] / n, sums[1] / n, sums[2] / n]
					)
			var at := 0
			var m := 0
			for r in runs:
				var p: Array = Run.pool(r, rule[1], rule[2], room_heal, sh)
				if p[0] == 0:
					at += p[2]
					m += 1
			out.append(
				"    final arena arrival HP (mean of %d): %s" % [m, str(at / m) if m > 0 else "-"]
			)
	return out
