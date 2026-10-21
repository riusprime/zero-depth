extends SceneTree
## v0.8.0 BV (owner O91; docs/roadmap/v0.8.0/BALANCE_PASS.md "BV: validation"): reproducible scripted fights of named
## builds (BuildFight: the arena, the dummies, the hero's input and every count are documented there), and of the
## builds loot_sample.gd sampled. Prints the tables and writes build/build_fights.txt (named) or
## build/build_fights_sampled.txt (from_loot); paste into evidence by hand; this tool never writes outside build/.
##   godot --headless --path . -s scripts/checks/build_fights.gd -- seconds=20
##   godot --headless --path . -s scripts/checks/build_fights.gd -- from_loot=build/loot_wands.txt seconds=6
## Named mode args: seconds=S (each fight; default 20), builds=a,b (BuildFight.BUILDS names; default all, in
## BuildFight.ORDER), levels=1,3 (every card of the build at that level), pack_hp=N, boss_hp=N (default: the
## Charger's and the first boss table's floor-1 HP).
## Per build and level: damage and DPS in the pack fight (the reference fight) and against the boss dummy, player
## projectiles a second and weapon casts a second apart (and projectiles per cast), procs a second (status
## applications / remnant activations / child hits), the times to kill the pack's first 12 and the boss dummy,
## peak live projectiles, LIMIT events, and CatchUp: P, the floor's m and the boss's m on floors 1-3, and the boss
## dummy's time to kill × the boss's m (its HP × m at the same DPS: what the hidden scaling leaves of the gain).
## Sampled mode (from_loot= or sampled=, a loot_wands.txt): each run's build at each floor end fights the pack for
## `seconds` (default 6); per weapon and floor: the median DPS and the share of builds at >= EXCEPTIONAL x the median
## ("exceptional", BALANCE_PASS.md), how many of those had taken a jackpot or an early (floor-1 jackpot or mutation)
## card, and how many floor-3 exceptional builds were already exceptional at floor 1 or 2. floors=1,2,3 filters,
## limit=N fights only the first N lines.
## Determinism: the first fight runs twice; the world hashes must match (MATCH/MISMATCH).

const EXCEPTIONAL := 2.5

var _lines := PackedStringArray()
var _fights: BuildFight
var _hp_seen := {}


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var repo := ContentRepository.load_all()
	_fights = BuildFight.new(repo)
	_fights.pack_hp = int(args.get("pack_hp", 0))
	_fights.boss_hp = int(args.get("boss_hp", 0))
	var loot := String(args.get("from_loot", args.get("sampled", "")))
	if loot != "":
		_sampled(loot, float(args.get("seconds", 6)), args)
		_write("res://build/build_fights_sampled.txt")
	else:
		_named(float(args.get("seconds", 20)), args)
		_write("res://build/build_fights.txt")
	quit(0)


func _named(seconds: float, args: Dictionary) -> void:
	var names: Array[String] = BuildFight.ORDER.duplicate()
	if args.has("builds"):
		names.clear()
		for n in String(args["builds"]).split(",", false):
			names.append(n)
	var levels := PackedInt32Array()
	for l in String(args.get("levels", "1,3")).split(",", false):
		levels.append(int(l))
	_line(
		(
			"build_fights: %d builds x levels %s, %.0f s a fight, 60 Hz headless"
			% [names.size(), levels, seconds]
		)
	)
	_line(
		(
			"columns: build L | pack dmg, DPS | boss DPS | proj/s casts/s proj/cast | procs/s (status remnant child)"
			+ " | pack TTK s | boss TTK s | peak proj | LIMITs | P | m f1-3 | boss m f1-3 | boss TTK x m f1-3 s"
		)
	)
	var checked := false
	for name in names:
		if not BuildFight.BUILDS.has(name):
			_line("%s: unknown build" % name)
			continue
		var spec: Array = BuildFight.BUILDS[name]
		for level in levels:
			var tokens := BuildFight.named_tokens(name, level)
			var pack := _fights.fight(spec[0], tokens, BuildFight.Mode.PACK, seconds, spec[2])
			var boss := _fights.fight(spec[0], tokens, BuildFight.Mode.BOSS, seconds, spec[2])
			_line(_row(name, level, pack, boss))
			if not checked:
				checked = true
				var again := _fights.fight(spec[0], tokens, BuildFight.Mode.PACK, seconds, spec[2])
				_line(
					(
						"determinism %s L%d pack fight run twice: %s"
						% [name, level, _match(pack, again)]
					)
				)
	_line("pack HP %s, boss dummy HP %s (BuildFight doc)" % [_hp_note(true), _hp_note(false)])


func _hp_note(pack: bool) -> String:
	return str(_hp_seen.get(pack, "-"))


func _row(name: String, level: int, pack: Dictionary, boss: Dictionary) -> String:
	_hp_seen[true] = pack["hp"]
	_hp_seen[false] = boss["hp"]
	var secs := float(pack["ticks"]) / SimTick.TICKS_PER_SECOND
	var casts := float(pack["casts"]) / secs
	var proj := float(pack["projectiles"]) / secs
	var procs := float(pack["status"] + pack["remnant"] + pack["child_hits"]) / secs
	var boss_dps: float = boss["dps"]
	var mb: PackedInt32Array = boss["m_boss"]
	var eff := PackedStringArray()
	for m in mb:
		eff.append("%.1f" % (boss["hp"] * m / 1000.0 / boss_dps) if boss_dps > 0.0 else "-")
	return (
		(
			"%-22s L%d | %d, %.1f | %.1f | %.2f %.2f %.2f | %.2f (%.2f %.2f %.2f) | %s | %s | %d | %s | %d | %s | %s"
			+ " | %s%s"
		)
		% [
			name,
			level,
			pack["damage"],
			pack["dps"],
			boss_dps,
			proj,
			casts,
			proj / maxf(casts, 0.001),
			procs,
			pack["status"] / secs,
			pack["remnant"] / secs,
			pack["child_hits"] / secs,
			_ttk(pack, secs),
			_ttk(boss, float(boss["ticks"]) / SimTick.TICKS_PER_SECOND),
			pack["peak"],
			_limits(pack["limits"]),
			pack["p"],
			pack["m"],
			mb,
			" ".join(eff),
			(
				""
				if (pack["missing"] as PackedStringArray).is_empty()
				else " | MISSING %s" % pack["missing"]
			)
		]
	)


static func _ttk(r: Dictionary, secs: float) -> String:
	var t: int = r["ttk_ticks"]
	return (
		"not killed in %.0f s" % secs if t < 0 else "%.2f" % (float(t) / SimTick.TICKS_PER_SECOND)
	)


static func _limits(d: Dictionary) -> String:
	if d.is_empty():
		return "none"
	var parts := PackedStringArray()
	for k: String in d:
		parts.append("%s %d" % [k, d[k]])
	return ", ".join(parts)


static func _match(a: Dictionary, b: Dictionary) -> String:
	return (
		"MATCH (%s)" % a["hash"]
		if a["hash"] == b["hash"]
		else "MISMATCH (%s vs %s)" % [a["hash"], b["hash"]]
	)


## Sampled mode (class doc). A loot_wands.txt line: "seed weapon loop floor jackpot_ever early p_end | tokens".
func _sampled(path: String, seconds: float, args: Dictionary) -> void:
	var f := FileAccess.open(
		path if path.begins_with("res://") else "res://" + path, FileAccess.READ
	)
	if f == null:
		_line("build_fights: can't read %s (run scripts/checks/loot_sample.gd first)" % path)
		return
	var floors := PackedInt32Array()
	for x in String(args.get("floors", "1,2,3")).split(",", false):
		floors.append(int(x))
	var limit := int(args.get("limit", 0))
	var rows: Array[Dictionary] = []
	var checked := false
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		var halves := l.split("|", true, 1)
		var head := halves[0].strip_edges().split(" ", false)
		if head.size() < 7:
			continue
		var fl := int(head[3])
		if not floors.has(fl):
			continue
		if limit > 0 and rows.size() >= limit:
			break
		var tokens := (
			halves[1].strip_edges().split(",", false) if halves.size() > 1 else PackedStringArray()
		)
		var weapon := StringName(head[1])
		var r := _fights.fight(weapon, tokens, BuildFight.Mode.PACK, seconds)
		if not checked:
			checked = true
			var again := _fights.fight(weapon, tokens, BuildFight.Mode.PACK, seconds)
			_line(
				(
					"determinism sampled seed %s %s floor %d run twice: %s"
					% [head[0], weapon, fl, _match(r, again)]
				)
			)
		(
			rows
			. append(
				{
					"seed": int(head[0]),
					"weapon": String(weapon),
					"loop": int(head[2]),
					"floor": fl,
					"jackpot": int(head[4]),
					"early": int(head[5]),
					"dps": float(r["dps"]),
					"missing": (r["missing"] as PackedStringArray).size(),
				}
			)
		)
	_line(
		(
			(
				"build_fights sampled: %d builds from %s, pack fight %.0f s each; exceptional = DPS >= %.1f x the median"
				+ " of the same weapon, loop and floor"
			)
			% [rows.size(), path, seconds, EXCEPTIONAL]
		)
	)
	var groups := {}
	for r in rows:
		var key := "%s loop %d floor %d" % [r["weapon"], r["loop"], r["floor"]]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(r)
	var keys := groups.keys()
	keys.sort()
	var exceptional := {}  # "weapon seed loop floor" -> true
	for key: String in keys:
		var g: Array = groups[key]
		var v := PackedFloat64Array()
		for r: Dictionary in g:
			v.append(r["dps"])
		v.sort()
		var med := v[v.size() / 2]
		var n_ex := 0
		var jp := 0
		var early := 0
		var missing := 0
		for r: Dictionary in g:
			missing += r["missing"]
			if med > 0.0 and r["dps"] >= EXCEPTIONAL * med:
				n_ex += 1
				jp += r["jackpot"]
				early += r["early"]
				exceptional["%s %d %d %d" % [r["weapon"], r["seed"], r["loop"], r["floor"]]] = true
		_line(
			(
				(
					"%s: %d builds, DPS min %.1f p10 %.1f median %.1f p90 %.1f max %.1f; exceptional %d (%.1f %%), of"
					+ " which %d took a jackpot, %d an early card; tokens not granted %d"
				)
				% [
					key,
					g.size(),
					v[0],
					v[v.size() / 10],
					med,
					v[mini(v.size() - 1, v.size() * 9 / 10)],
					v[v.size() - 1],
					n_ex,
					100.0 * n_ex / g.size(),
					jp,
					early,
					missing
				]
			)
		)
	# Assembled late: of the builds exceptional at a loop's floor 3, those already exceptional at its floor 1 or 2.
	var late := 0
	var before := 0
	for k: String in exceptional:
		var p := k.split(" ")
		if int(p[3]) != 3:
			continue
		late += 1
		for earlier in [1, 2]:
			if exceptional.has("%s %s %s %d" % [p[0], p[1], p[2], earlier]):
				before += 1
				break
	_line(
		(
			"exceptional at floor 3: %d; of them already exceptional at floor 1 or 2: %d (needs floors=1,2,3)"
			% [late, before]
		)
	)


func _line(s: String) -> void:
	print(s)
	_lines.append(s)


func _write(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
