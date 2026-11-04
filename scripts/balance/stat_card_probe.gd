extends SceneTree
## v0.10.5 W3-P9 (the progression G1's P9 probe): why a rare stat card moves a floor-3 build on the Gun's default
## form (the Orbs) by less than its nominal gain. For each base (floor-3 stats, scripts/balance/progression_audit.gd's
## section c) and each rare stat card it prints what the card changed: the grant, the damage and attack-speed stats,
## the damage multiplier, the shot period in ticks, the bolt's base damage, the hits and the damage per hit on one
## endless dummy 5 m ahead, and the single DPS ratio. Writes build/stat_card_probe.txt; copy numbers by hand.
##   godot --headless --path . -s scripts/balance/stat_card_probe.gd -- seconds=12

const AUDIT := preload("res://scripts/balance/progression_audit.gd")

const BASES: Array = [
	["gun_orbs", &"gun", []],
	["gun_void", &"gun", ["gun_void:1"]],
]
const STAT_CARDS: Array = [
	["damage", 1],
	["attack_speed", 1],
	["crit_chance", 1],
	["crit_damage", 1],
	["glass_cannon", 1],
]

var _repo: ContentRepository
var _biome: BiomeDefinition
var _seconds := 12.0
var _items := {}
var _stats := {}
var _out := PackedStringArray()


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_seconds = float(args.get("seconds", 12))
	_repo = ContentRepository.load_all()
	var run_def: RunDefinition = _repo.get_def(&"run", RunSaver.RUN_ID)
	_biome = _repo.get_def(&"biomes", run_def.biomes[0])
	_line("stat_card_probe seconds=%.1f" % _seconds)
	_line(
		(
			"base | card | missing | damage stat | damage x | rate | period t | bolt dmg | hits | dmg/hit"
			+ " | single dps | x"
		)
	)
	for b: Array in BASES:
		var base_toks: Array = (b[2] as Array).duplicate()
		base_toks.append_array(AUDIT._stat_tokens(1, 3))
		var base := _probe(b[1], base_toks)
		_row(b[0], "(base)", base, base)
		for sc: Array in STAT_CARDS:
			var toks := base_toks.duplicate()
			toks.append("s:%s:%d" % [sc[0], sc[1]])
			_row(b[0], String(sc[0]), _probe(b[1], toks), base)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open("res://build/stat_card_probe.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_out) + "\n")
		f.close()
	quit(0)


func _line(s: String) -> void:
	print(s)
	_out.append(s)


func _row(base: String, card: String, r: Dictionary, b: Dictionary) -> void:
	_line(
		(
			"%s | %s | %d | %d | %d | %d | %d | %d | %d | %.1f | %.1f | %.3f"
			% [
				base,
				card,
				r["missing"],
				r["dmg_stat"],
				r["dmg_x"],
				r["rate"],
				r["period"],
				r["bolt"],
				r["hits"],
				float(r["total"]) / maxf(1.0, float(r["hits"])),
				r["dps"],
				r["dps"] / maxf(0.01, b["dps"]),
			]
		)
	)


func _probe(weapon: StringName, tokens: Array) -> Dictionary:
	var w := PlaygroundScenario.build(_repo, weapon, _biome)
	var api := PlaygroundApi.new(w)
	api.god = true
	var missing := 0
	for tok: String in tokens:
		var p := tok.split(":")
		var ok := false
		if p[0] == "s":
			ok = api.grant_now(Offers.stat_code(int(_stat_index(StringName(p[1]))), int(p[2])))
		else:
			ok = api.grant_now(int(_item_idx(StringName(p[0]))), int(p[1]))
		if not ok:
			missing += 1
	var reader := WorldReader.new(w)
	api.place_dummy_now(w.player_pos() + Vector2(5.0, 0.0), AUDIT.ENDLESS)
	var tally := DpsTally.new()
	var hits := 0
	var last := -1
	var total := int(round(_seconds * SimTick.TICKS_PER_SECOND))
	var pid := reader.actor_id(0)
	for t in total:
		api.apply_pending()
		w.step(AUDIT._input(w, reader, false, false, 0, t))
		for e in reader.events_since(last):
			last = e.seq
			if (
				e.kind == SimEvent.Kind.DAMAGE
				and e.owner_id == pid
				and e.target_id != pid
				and e.amount_applied > 0
			):
				hits += 1
		tally.observe(reader)
	return {
		"missing": missing,
		"dmg_stat": Stats.value(w, Stats.Stat.DAMAGE),
		"dmg_x": Stats.damage_permille(w),
		"rate": AttackRate.weapon_rate(w),
		"period": ItemEffects.shot_period_ticks(w),
		"bolt": ItemEffects.bolt_damage(w),
		"hits": hits,
		"total": tally.total,
		"dps": float(tally.total) * SimTick.TICKS_PER_SECOND / maxf(1.0, float(total)),
	}


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
