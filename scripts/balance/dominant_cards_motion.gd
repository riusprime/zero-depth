extends SceneTree
## v0.10.5 W3-P6 (the progression G1's P6 probes, measure only): two dominant cards outside the audit's standing scenes.
## - a: Blade Storm L3 on the Blade default with floor-3 stats (scripts/balance/progression_audit.gd section c's base),
##   its single-target gain (with / without the card) in four scenes: the audit's standing endless dummy 1.6 m ahead;
##   an endless dummy the harness walks up and down a 6 m line 2.5 m ahead at `speed` m/s (ping-pong; the hero walks
##   at it as in the audit); every Playground boss (World.boss_tables, its own AI, attacks and HP; the hero unhurtable)
##   placed 4 m ahead, fought up to `boss_s` s or its death. DPS = HP taken (DpsTally) / ticks from the first hit to
##   the end (the boss's intro invulnerability left out).
## - b: Ring L1 on the Orbs on the shipped run (FloorPlan as Main builds it, floor 3 reached by finishing floors 1-2
##   unplayed), with the survival bot's nine offence stat cards for floors 1-3 (three_curves.gd's), the survival bot
##   (tests/support/survival_run.gd's Survivor, the Gun) in the start hall for `floor_s` s, healed every tick; with
##   and without Ring on the same seed: enemy HP removed, kills, the mean seconds a killed enemy lived, the mean
##   enemies alive.
## Writes build/dominant_cards_motion/<section>.txt; copy numbers by hand.
##   godot --headless --path . -s scripts/balance/dominant_cards_motion.gd -- section=a seconds=12 boss_s=30
##   godot --headless --path . -s scripts/balance/dominant_cards_motion.gd -- section=b seeds=3 floor_s=120

const AUDIT := preload("res://scripts/balance/progression_audit.gd")
const Run := preload("res://tests/support/survival_run.gd")

var _repo: ContentRepository
var _biome: BiomeDefinition
var _items := {}
var _stats := {}
var _out := PackedStringArray()


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_repo = ContentRepository.load_all()
	var run_def: RunDefinition = _repo.get_def(&"run", RunSaver.RUN_ID)
	_biome = _repo.get_def(&"biomes", run_def.biomes[0])
	var section := String(args.get("section", "a"))
	if section == "a":
		_section_a(args)
	else:
		_section_b(args)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://build/dominant_cards_motion")
	)
	var f := FileAccess.open("res://build/dominant_cards_motion/%s.txt" % section, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_out) + "\n")
		f.close()
	quit(0)


func _line(s: String) -> void:
	print(s)
	_out.append(s)


# --- a: Blade Storm L3 ----------------------------------------------------------------------------------------
func _section_a(args: Dictionary) -> void:
	var seconds := float(args.get("seconds", 12))
	var boss_s := float(args.get("boss_s", 30))
	var base_toks: Array = AUDIT._stat_tokens(1, 3)
	var storm_toks := base_toks.duplicate()
	storm_toks.append("blade_storm:3")
	_line("## a: Blade Storm L3 on the Blade default + floor-3 stats, single target")
	_line("scene | base dps | storm dps | x | base end s | storm end s")
	var scenes: Array = [["stand", 0.0], ["patrol 1.5 m/s", 1.5], ["patrol 3 m/s", 3.0]]
	for sc: Array in scenes:
		var b := _fight_dummy(base_toks, sc[1], seconds)
		var s := _fight_dummy(storm_toks, sc[1], seconds)
		_row(sc[0], b, s)
	var probe := _world(&"blade", [])
	for k in probe.boss_tables.size():
		var name := String(probe.boss_tables[k].name_key)
		var b := _fight_boss(base_toks, k, boss_s)
		var s := _fight_boss(storm_toks, k, boss_s)
		if b["dps"] <= 0.0 and s["dps"] <= 0.0:
			_line("boss %d %s | (not placed or never hit)" % [k, name])
			continue
		_row("boss %d %s (hp %d)" % [k, name, b["hp"]], b, s)


func _row(name: String, b: Dictionary, s: Dictionary) -> void:
	_line(
		(
			"%s | %.1f | %.1f | %.2f | %.1f | %.1f"
			% [name, b["dps"], s["dps"], s["dps"] / maxf(0.01, b["dps"]), b["end_s"], s["end_s"]]
		)
	)


func _fight_dummy(tokens: Array, speed: float, seconds: float) -> Dictionary:
	var w := _world(&"blade", tokens)
	var api: PlaygroundApi = w.get_meta(&"api")
	var reader := WorldReader.new(w)
	var hero := w.player_pos()
	var start := hero + (Vector2(1.6, 0.0) if speed <= 0.0 else Vector2(2.5, 0.0))
	api.place_dummy_now(start, AUDIT.ENDLESS)
	var di := w.actors.size() - 1
	var did := w.actors.ids[di]
	var y := 0.0
	var dir := 1.0
	var step := speed / SimTick.TICKS_PER_SECOND
	var tally := DpsTally.new()
	var total := int(round(seconds * SimTick.TICKS_PER_SECOND))
	for t in total:
		api.apply_pending()
		if speed > 0.0:
			y += dir * step
			if absf(y) >= 3.0:
				dir = -dir
				y = clampf(y, -3.0, 3.0)
			var i := w.actors.index_of(did)
			if i >= 0:
				w.actors.set_pos(i, start + Vector2(0.0, y))
		w.step(AUDIT._input(w, reader, true, false, 0, t))
		tally.observe(reader)
	return _result(tally, w.tick, 0)


func _fight_boss(tokens: Array, table: int, seconds: float) -> Dictionary:
	var w := _world(&"blade", tokens)
	var api: PlaygroundApi = w.get_meta(&"api")
	var reader := WorldReader.new(w)
	if not api.place_boss_now(table, w.player_pos() + Vector2(4.0, 0.0)):
		return {"dps": 0.0, "end_s": 0.0, "hp": 0}
	var bid := w.actors.ids[w.actors.size() - 1]
	var hp := w.actors.hp[w.actors.size() - 1]
	var tally := DpsTally.new()
	var total := int(round(seconds * SimTick.TICKS_PER_SECOND))
	for t in total:
		api.apply_pending()
		w.step(AUDIT._input(w, reader, true, false, 0, t))
		tally.observe(reader)
		var i := w.actors.index_of(bid)
		if i < 0 or w.actors.dead[i] == 1:
			break
	return _result(tally, w.tick, hp)


func _result(tally: DpsTally, now: int, hp: int) -> Dictionary:
	var span := 0 if tally.first_tick < 0 else now - tally.first_tick + 1
	return {
		"dps": float(tally.total) * SimTick.TICKS_PER_SECOND / maxf(1.0, float(span)),
		"end_s": float(now) / SimTick.TICKS_PER_SECOND,
		"hp": hp,
	}


# --- b: Ring on the Orbs on the shipped run -------------------------------------------------------------------
func _section_b(args: Dictionary) -> void:
	var seeds := int(args.get("seeds", 3))
	var floor_s := int(args.get("floor_s", 120))
	var fl := int(args.get("floor", 3))
	_line(
		(
			"## b: Ring L1 on the Orbs, shipped run floor %d, survival bot %d s, floor-%d offence stats"
			% [fl, floor_s, fl]
		)
	)
	_line("seed | ring | granted | hp removed | kills | arrivals | mean life s | mean alive")
	var sums := {false: [0, 0], true: [0, 0]}
	for s in range(1, seeds + 1):
		for ring: bool in [false, true]:
			var r := _play(s, fl, floor_s, ring)
			sums[ring][0] += r["hp_removed"]
			sums[ring][1] += r["kills"]
			_line(
				(
					"%d | %s | %s | %d | %d | %d | %.2f | %.2f"
					% [
						s,
						"yes" if ring else "no",
						r["granted"],
						r["hp_removed"],
						r["kills"],
						r["arrivals"],
						r["life_s"],
						r["alive"],
					]
				)
			)
	_line(
		(
			"total | hp removed x %.2f | kills x %.2f"
			% [
				float(sums[true][0]) / maxf(1.0, float(sums[false][0])),
				float(sums[true][1]) / maxf(1.0, float(sums[false][1])),
			]
		)
	)


func _play(seed_value: int, fl: int, floor_s: int, ring: bool) -> Dictionary:
	var plan := FloorPlan.new_run(RunSaver.RUN_ID, seed_value, &"gun", false)
	plan.repo = _repo
	plan.build()
	for f in range(1, fl):
		plan.run.finish_floor(plan.world)
		plan = FloorPlan.next_floor(plan.run, plan.run_biomes, {}, false)
		plan.repo = _repo
		plan.build()
	var w := plan.world
	for f in range(1, fl + 1):
		for c in Run.CARDS_PER_FLOOR:
			var r := Stats.Rarity.COMMON
			if f >= 5:
				r = Stats.Rarity.EPIC
			elif f >= 3:
				r = Stats.Rarity.RARE
			Stats.add_card(
				w, Run.OFFENCE[(Run.CARDS_PER_FLOOR * (f - 1) + c) % Run.OFFENCE.size()], r
			)
	var granted := "-"
	if ring:
		var api := PlaygroundApi.new(w)
		granted = "ok" if api.grant_now(_item_idx(&"gun_ring"), 1) else "FAILED"
	var bot := Run.Survivor.new(true)
	var a := w.actors
	var born := {}
	var hp := {}
	var removed := 0
	var kills := 0
	var arrivals := 0
	var life := 0
	var alive_sum := 0
	var ticks := floor_s * SimTick.TICKS_PER_SECOND
	for k in ticks:
		a.hp[0] = a.max_hp[0]
		w.step(bot.frame(w))
		var seen := {}
		var alive := 0
		for i in range(1, a.size()):
			if a.teams[i] != ActorStore.TEAM_ENEMY or BossAi.is_boss_kind(a.kinds[i]):
				continue
			var id := a.ids[i]
			seen[id] = true
			var now_hp: int = a.hp[i] if a.dead[i] == 0 else 0
			if not hp.has(id):
				if now_hp > 0:
					arrivals += 1
					born[id] = w.tick
				hp[id] = now_hp
				continue
			if now_hp > 0:
				alive += 1
			var prev: int = hp[id]
			if now_hp < prev:
				removed += prev - now_hp
			if prev > 0 and now_hp == 0:
				kills += 1
				life += w.tick - int(born.get(id, w.tick))
			hp[id] = now_hp
		for id: int in hp.keys():
			if not seen.has(id):
				if hp[id] > 0:
					removed += hp[id]
					kills += 1
					life += w.tick - int(born.get(id, w.tick))
				hp.erase(id)
		alive_sum += alive
	return {
		"granted": granted,
		"hp_removed": removed,
		"kills": kills,
		"arrivals": arrivals,
		"life_s": float(life) / SimTick.TICKS_PER_SECOND / maxf(1.0, float(kills)),
		"alive": float(alive_sum) / maxf(1.0, float(ticks)),
	}


# --- shared ---------------------------------------------------------------------------------------------------
## A Playground world holding `tokens` (progression_audit.gd's tokens), the hero unhurtable.
func _world(weapon: StringName, tokens: Array) -> World:
	var w := PlaygroundScenario.build(_repo, weapon, _biome)
	var api := PlaygroundApi.new(w)
	api.god = true
	for tok: String in tokens:
		var p := tok.split(":")
		if p[0] == "s":
			api.grant_now(Offers.stat_code(_stat_index(StringName(p[1])), int(p[2])))
		else:
			api.grant_now(_item_idx(StringName(p[0])), int(p[1]))
	w.set_meta(&"api", api)
	return w


func _item_idx(id: StringName) -> int:
	if _items.is_empty():
		var t := ContentCompiler.compile_items(_repo)
		for k in t.size():
			_items[t[k].id] = k
	return int(_items.get(id, -1))


func _stat_index(id: StringName) -> int:
	if _stats.is_empty():
		var t := ContentCompiler.compile_stat_cards(_repo)
		for k in t.size():
			if t[k] != null:
				_stats[t[k].id] = k
	return int(_stats.get(id, -1))
