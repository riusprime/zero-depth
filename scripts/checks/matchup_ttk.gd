extends SceneTree
## v0.10.5 O10 (owner P3; docs/roadmap/v0.10.5/O10_STRESS_MATRIX.md): each enemy kind against each matchup form or
## element, headless at 60 Hz, with the matchups off (before) and on (after). Prints the tables and writes
## build/matchup_ttk.txt; paste into evidence by hand; this tool never writes outside build/.
##   godot --headless --path . -s scripts/checks/matchup_ttk.gd -- seconds=20 hp=400
## The arena: the Playground's World (PlaygroundScenario: one walled room, floor 1's tables, no spawning), the hero
## unhurtable (PlaygroundApi.god) with the Gun and one card at level 1 (none: the plain bolt), standing still, holding
## Shoot at the nearest live body (BuildFight's input; with the Lance it lets go one tick a second). One enemy of
## the kind, its real AI, 5 m ahead; its HP set to
## `hp` (so a one-hit kind still shows a rate). Counted: the damage the player dealt that body and the tick it died
## (none within `seconds`: "-"). Before: every enemy table's weak_to and resists cleared on that world. Per kind:
## which form killed fastest (most damage a second) and slowest; per form: on how many kinds it was best and worst.
## Determinism: the first fight runs twice; the world hashes must match (MATCH/MISMATCH).

const FORMS: Array[String] = [
	"bolt",
	"gun_laser",
	"gun_lance",
	"gun_wave",
	"gun_glaive",
	"ember_core",
	"storm_core",
	"venom_core"
]

## The Lance charges while Shoot is held and a full one fires on release: the bot lets go one tick in this many.
const LANCE_HOLD_TICKS := 60

var _lines := PackedStringArray()
var _repo: ContentRepository
var _biome: BiomeDefinition


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var seconds := float(args.get("seconds", 20))
	var hp := int(args.get("hp", 400))
	_repo = ContentRepository.load_all()
	var run_def: RunDefinition = _repo.get_def(&"run", RunSaver.RUN_ID)
	_biome = _repo.get_def(&"biomes", run_def.biomes[0])
	var kinds := _kinds()
	_line(
		(
			"matchup_ttk: %d kinds x %d forms, %.0f s a fight, target HP %d, 60 Hz headless"
			% [kinds.size(), FORMS.size(), seconds, hp]
		)
	)
	var a := _fight(kinds[0][0], FORMS[0], true, seconds, hp)
	var b := _fight(kinds[0][0], FORMS[0], true, seconds, hp)
	_line("determinism: %s" % ("MATCH" if a["hash"] == b["hash"] else "MISMATCH"))
	var dps := {}  # "on"/"off" -> kind name -> form -> dps
	for on in [false, true]:
		var mode := "after" if on else "before"
		dps[mode] = {}
		_line("")
		_line(
			(
				"== %s (matchups %s): time to kill s (dps on the target) =="
				% [mode, "on" if on else "off"]
			)
		)
		_line("kind | weak / resists | " + " | ".join(FORMS))
		for k: Array in kinds:
			var row := PackedStringArray()
			dps[mode][k[1]] = {}
			for f in FORMS:
				var r := _fight(k[0], f, on, seconds, hp)
				dps[mode][k[1]][f] = r["dps"]
				var ttk := "-" if r["ttk"] < 0 else "%.2f" % (r["ttk"] / 60.0)
				row.append("%s (%.1f)" % [ttk, r["dps"]])
			_line("%s | %s / %s | %s" % [k[1], k[2], k[3], " | ".join(row)])
	for mode in ["before", "after"]:
		_summary(mode, dps[mode], kinds)
	_ratios(dps, kinds)
	_write("res://build/matchup_ttk.txt")
	quit(0)


## [kind, id, weak_to, resists] of every placeable enemy kind (PlaygroundApi.enemy_choices' order).
func _kinds() -> Array:
	var w := PlaygroundScenario.build(_repo, &"gun", _biome)
	var api := PlaygroundApi.new(w)
	var by_name := {}
	for def: EnemyDefinition in _repo.all_of(&"enemies"):
		by_name[def.name_key] = def
	var out := []
	for c in api.enemy_choices():
		var def: EnemyDefinition = by_name.get(c["name_key"])
		if def != null:
			out.append([c["kind"], String(def.id), String(def.weak_to), String(def.resists)])
	return out


func _fight(kind: int, form: String, on: bool, seconds: float, hp: int) -> Dictionary:
	var w := PlaygroundScenario.build(_repo, &"gun", _biome)
	var api := PlaygroundApi.new(w)
	api.god = true
	var saved := {}
	if not on:
		for k: int in w.enemy_tables:
			var t: EnemyTable = w.enemy_tables[k]
			saved[k] = [t.weak_to, t.resists]
			t.weak_to = &""
			t.resists = &""
	if form != "bolt":
		var missing := BuildFight.grant_tokens(w, api, PackedStringArray(["m:%s:1" % form]))
		if not missing.is_empty():
			push_error("could not grant %s" % form)
	var reader := WorldReader.new(w)
	var at := w.player_pos() + Vector2(5.0, 0.0)
	var ok := api.place_enemy_now(kind, at)
	var out := {"ttk": -1, "dps": 0.0, "hash": 0}
	if not ok:
		_restore(w, saved)
		return out
	var i := w.actors.size() - 1
	var id := w.actors.ids[i]
	w.actors.hp[i] = hp
	w.actors.max_hp[i] = hp
	var pid := w.actors.ids[0]
	var dealt := 0
	var last := w.last_event_seq()
	var total := int(round(seconds * SimTick.TICKS_PER_SECOND))
	var ticks := total
	for t in total:
		api.apply_pending()
		var frame := BuildFight._input(w, reader, false, false, t)
		if form == "gun_lance" and t % LANCE_HOLD_TICKS == LANCE_HOLD_TICKS - 1:
			frame.held &= ~InputFrame.SHOOT  # the Lance fires on release (a full one waits for it)
		w.step(frame)
		var dead := false
		for e in w.events_since(last):
			last = e.seq
			if e.target_id != id or e.owner_id != pid:
				continue
			if e.kind == SimEvent.Kind.DAMAGE:
				dealt += e.amount_applied
			elif e.kind == SimEvent.Kind.KILL:
				dead = true
		if dead:
			out["ttk"] = t + 1
			ticks = t + 1
			break
	out["dps"] = float(dealt) * SimTick.TICKS_PER_SECOND / maxi(1, ticks)
	out["hash"] = w.state_hash()
	_restore(w, saved)
	return out


func _restore(w: World, saved: Dictionary) -> void:
	for k: int in saved:
		w.enemy_tables[k].weak_to = saved[k][0]
		w.enemy_tables[k].resists = saved[k][1]


func _summary(mode: String, d: Dictionary, kinds: Array) -> void:
	_line("")
	_line("== %s: best and worst form per kind (by dps on the target) ==" % mode)
	var best := {}
	var worst := {}
	for f in FORMS:
		best[f] = 0
		worst[f] = 0
	for k: Array in kinds:
		var row: Dictionary = d[k[1]]
		var hi := FORMS[0]
		var lo := FORMS[0]
		for f in FORMS:
			if float(row[f]) > float(row[hi]):
				hi = f
			if float(row[f]) < float(row[lo]):
				lo = f
		best[hi] += 1
		worst[lo] += 1
		_line("%s: best %s (%.1f), worst %s (%.1f)" % [k[1], hi, row[hi], lo, row[lo]])
	var n := kinds.size()
	var uni_best := PackedStringArray()
	var uni_worst := PackedStringArray()
	_line("form | best on | worst on (of %d kinds)" % n)
	for f in FORMS:
		_line("%s | %d | %d" % [f, best[f], worst[f]])
		if best[f] == n:
			uni_best.append(f)
		if worst[f] == n:
			uni_worst.append(f)
	_line(
		(
			"%s: a form best on every kind: %s; a form worst on every kind: %s"
			% [
				mode,
				"none" if uni_best.is_empty() else ", ".join(uni_best),
				"none" if uni_worst.is_empty() else ", ".join(uni_worst)
			]
		)
	)


## after / before dps per cell, per mille, so the matchup's own effect reads apart from the fight's.
func _ratios(dps: Dictionary, kinds: Array) -> void:
	_line("")
	_line("== after / before dps, per mille ==")
	_line("kind | " + " | ".join(FORMS))
	for k: Array in kinds:
		var row := PackedStringArray()
		for f in FORMS:
			var b := float(dps["before"][k[1]][f])
			var a := float(dps["after"][k[1]][f])
			row.append("-" if b <= 0.0 else str(int(round(a / b * 1000.0))))
		_line("%s | %s" % [k[1], " | ".join(row)])


func _line(s: String) -> void:
	print(s)
	_lines.append(s)


func _write(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
