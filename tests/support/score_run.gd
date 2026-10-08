class_name ScoreRun
extends RefCounted
## One scorecard run (v0.5.0 SCD; SCORECARD §5 "run record"): a whole run of the real game, each floor built the
## way Main._start_floor builds it (the run's floor seed, build, scaling, boss pool and arena, spawning, rewards,
## items, combos, gamble shrine, shop, abilities, stat cards, Overrun, heat, the carry), played by a ScoreBot until it
## dies, wins or a floor runs past FLOOR_LIMIT_TICKS. A read-only recorder watches every tick and writes one record
## (ints, floats, strings, bools, arrays and dictionaries; no wall time, so a record is byte-reproducible).
## The only writes to a world are exploit:chain's starting items (a scripted exploit search, like the bench's).
##
## Rooms (the metrics' "Room N"): this game's floors are continuous-spawn room graphs, not a list of encounters, so
## Room N is the N-th distinct room the player walks into on a floor, the start hall being Room 0 of each floor; the
## run's global room count `g` adds every floor's rooms (start halls excluded). An encounter (M-ENC) is a combat bout:
## from the first tick a living enemy is within COMBAT_RANGE_M of the player to the last one before BOUT_GAP_TICKS
## without one; the boss fight (door sealed to the boss's death) is its own encounter.

const FLOOR_LIMIT_TICKS := 25 * 60 * 60
const COMBAT_RANGE_M := 12.0
const BOUT_GAP_TICKS := 180
## Abilities that bring an engine with them (v0.4.0 AB) and the mod tags that are engines (BLUEPRINT §D).
const ENGINE_ABILITIES: Array[StringName] = [&"arc_field", &"frost_nova", &"flame_trail"]
const ENGINE_TAGS: Array[String] = ["fire", "shock", "bleed", "frost", "guard", "heat"]

var repo: ContentRepository
var run: RunState
## Test-side only (the route tests, never the scorecard): the player's HP is topped up after every tick.
var god := false
var bot: ScoreBot
var record := {}

var _seq := 0
var _cause: ReadableCause
var _me := 0
var _first_hit := {}
var _hit_kind := {}
var _room_seen := {}
var _floor_rec := {}
var _room_rec := {}
var _bout_start := -1
var _bout_last := -1
var _boss_start := -1
var _choice_open := -1
var _shop_seen := false
var _reward_src := {}
var _offer_index := {}
var _floor_room_n := 0
var _global_room := 0
var _kinds := {}


## Plays the run of seed `run_seed` with policy `policy` ("competent", "element", "competent+t" ...) on build
## `build` (&"blade" or &"gun"), skill preset `skill`, at most `floors` floors. Returns the record.
static func play(
	p_repo: ContentRepository,
	run_seed: int,
	policy: String,
	build: StringName,
	skill: String = "average",
	floors: int = 3,
	floor_limit: int = FLOOR_LIMIT_TICKS,
	p_god: bool = false
) -> Dictionary:
	var r := setup(p_repo, run_seed, policy, build, skill)
	r.god = p_god
	r.record = {
		"schema": "scorecard_run.v1",
		"seed": run_seed,
		"policy": policy,
		"skill": r.bot.preset,
		"build": String(build),
		"focus": r.bot.focus,
		"result": "timeout",
		"floor_reached": 1,
		"run_ticks": 0,
		"death": null,
		"floors": [],
		"rooms": [],
		"offers": [],
		"picks": [],
		"limit": {},
		"cap": {},
		"cause": {"damage": 0, "violations": 0, "first": []},
		"salvage": [],
	}
	var biomes: Array = p_repo.get_def(&"run", &"three_floors").biomes
	for f in mini(floors, r.run.table.floors):
		var w := r.floor_world()
		r.bot.start_floor(w)
		var res := r.play_floor(w, String(biomes[r.run.biome_of()]), floor_limit)
		r.record["floor_reached"] = r.run.floor_index
		if res != "next":
			r.record["result"] = res
			break
		if r.run.is_last_floor():
			r.record["result"] = "won"
			break
		r.run.finish_floor(w)
	if r.record["result"] == "next":
		r.record["result"] = "timeout"  # a floor budget shorter than the run (quick mode)
	r.record["salvage"] = r.bot.salvage_log
	r.record["explore_capped"] = r.bot.explore_capped
	return r.record


## A run of seed `run_seed` on its first floor, with its bot, not yet played (play() and the bot tests).
static func setup(
	p_repo: ContentRepository,
	run_seed: int,
	policy: String,
	build: StringName,
	skill: String = "average"
) -> ScoreRun:
	var r := ScoreRun.new()
	r.repo = p_repo
	r.run = RunState.start(
		run_seed, ContentCompiler.compile_run(p_repo.get_def(&"run", &"three_floors")), build
	)
	r.bot = ScoreBot.new(run_seed, policy, skill)
	return r


## The run's current floor as a fresh World (as Main builds it; no arrival hold, so the sim starts at once).
func floor_world() -> World:
	var table := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(table, repo.get_def(&"build", run.build_id))
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	var boss := run.pick_boss(ContentCompiler.compile_boss_pool(repo, run.floor_index))
	var arena := (
		BossArenaSpec.make(bosses[boss].arena_cells, bosses[boss].arena_template, boss)
		if boss >= 0
		else null
	)
	var w := FloorScenario.build(
		run.floor_seed(),
		table,
		enemies,
		ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo),
		ContentCompiler.compile_items(repo),
		ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor")),
		run.floor_index,
		arena,
		run,
		ContentCompiler.compile_combos(repo),
		ContentCompiler.compile_gamble(repo.get_def(&"gamble", &"shrine"))
	)
	FloorScenario.add_shop(w, ContentCompiler.compile_shop(repo.get_def(&"shop", &"terminal")))
	w.set_boss_tables(bosses)
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	w.overrun_table = ContentCompiler.compile_overrun(repo.get_def(&"overrun", &"overrun"))
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	if bot.exploit == "chain":
		for c in w.combo_tables:
			for k in [c.item_a, c.item_b]:
				if k >= 0:
					w.add_item(k)
	return w


## Plays one floor; returns "next", "died" or "timeout".
func play_floor(w: World, biome: String, limit: int) -> String:
	_seq = w.last_event_seq()
	_me = w.actors.ids[0]
	_cause = ReadableCause.new(w)
	_first_hit = {}
	_hit_kind = {}
	_room_seen = {}
	_bout_start = -1
	_bout_last = -1
	_boss_start = -1
	_choice_open = -1
	_shop_seen = false
	_reward_src = {}
	_offer_index = {}
	_floor_room_n = 0
	_kinds = {}
	_floor_rec = {
		"floor": run.floor_index,
		"biome": biome,
		"ticks": 0,
		"door_tick": -1,
		"boss_ticks": -1,
		"result": "timeout",
		"kills": 0,
		"damage_taken": 0,
		"peak_alive": 0,
		"ttk": {},
		"encounters": [],
		"dealt_by_effect": {},
		"dealt_total": 0,
		"kinds_seen": [],
		"overrun": {},
		"end_items": [],
		"end_abilities": [],
		"shards_end": 0,
	}
	for i in w.rewards.size():
		_reward_src[w.rewards.ids[i]] = (
			"chest" if w.rewards.kind[i] == RewardStore.Kind.CHEST else "altar"
		)
	var start := w.tick
	_enter_room(w, start)
	var result := "timeout"
	for t in limit:
		var was_choosing := w.choosing
		w.step(bot.frame(w))
		if god and not w.player_dead():
			w.actors.hp[0] = w.actors.max_hp[0]
		_observe(w, start, was_choosing)
		if w.player_dead():
			result = "died"
			_death(w, start)
			break
		if w.boss_flow != null and w.boss_flow.exited():
			result = "next"
			break
	_close_bout()
	var f := _floor_rec
	f["ticks"] = w.tick - start
	f["result"] = result
	f["kills"] = w.kills
	f["kinds_seen"] = _sorted_keys(_kinds)
	f["overrun"] = {
		"room": w.floor_layout.overrun_room,
		"entered": w.overrun.enter_tick >= 0,
		"cleared": w.overrun.cleared(),
		"kills": w.overrun.kills,
		"bonus_shards": w.overrun.bonus,
	}
	var items: Array = []
	for idx in w.items_owned:
		items.append(String(w.item_tables[idx].id))
	f["end_items"] = items
	var abil: Array = []
	for s in w.ability_owned.size():
		abil.append([String(w.ability_tables[w.ability_owned[s]].id), w.ability_levels[s]])
	f["end_abilities"] = abil
	f["shards_end"] = w.shards
	record["floors"].append(f)
	record["run_ticks"] = int(record["run_ticks"]) + f["ticks"]
	var c: Dictionary = record["cause"]
	c["damage"] = int(c["damage"]) + _cause.damage_count
	c["violations"] = int(c["violations"]) + _cause.violations.size()
	for v in _cause.violations:
		if (c["first"] as Array).size() < 5:
			(c["first"] as Array).append(str(v))
	if _room_rec.size() > 0:
		_room_rec = {}
	return result


func _observe(w: World, start: int, was_choosing: int) -> void:
	var el := w.tick - start
	# Offers: an altar or chest choice that just opened, and the shop's stock on its first open.
	if w.choosing >= 0 and w.choosing != was_choosing:
		var i := w.rewards.index_of(w.choosing)
		if i >= 0:
			var src: String = _reward_src.get(w.choosing, "altar")
			if w.floor_layout.room_of(w.rewards.pos(i)) == w.floor_layout.overrun_room:
				src = "overrun"
			_offer(w, w.rewards.offer_of(i), src, w.choosing, el)
	if w.shop.open and not _shop_seen:
		_shop_seen = true
		_offer(w, w.shop.offer, "shop", w.shop.id, el)
	var p := w.player_pos()
	var room := w.floor_layout.room_of(p)
	if room >= 0 and not _room_seen.has(room):
		_enter_room(w, start, room)
	# Events once per tick.
	var dealt := 0
	if w.last_event_seq() != _seq:
		for e in w.events_since(_seq):
			_event(w, e, start)
			if e.kind == SimEvent.Kind.DAMAGE and e.target_id != _me and e.owner_id == _me:
				dealt += e.amount_applied
		_seq = w.last_event_seq()
	_cause.observe(w)
	if not _room_rec.is_empty():
		_room_rec["dealt"] = int(_room_rec["dealt"]) + dealt
	# Combat bouts and the boss fight.
	var bf := w.boss_flow
	if bf != null and bf.door_sealed() and _boss_start < 0:
		_close_bout()
		_boss_start = w.tick
		_floor_rec["door_tick"] = el
	if _boss_start >= 0:
		if bf.portal_active() and int(_floor_rec["boss_ticks"]) < 0:
			_floor_rec["boss_ticks"] = w.tick - _boss_start
			(_floor_rec["encounters"] as Array).append([w.tick - _boss_start, true])
	elif w.tick % 6 == 0:
		if _enemy_near(w, p):
			if _bout_start < 0:
				_bout_start = w.tick
			_bout_last = w.tick
			if not _room_rec.is_empty():
				_room_rec["combat_ticks"] = int(_room_rec["combat_ticks"]) + 6
		elif _bout_start >= 0 and w.tick - _bout_last > BOUT_GAP_TICKS:
			_close_bout()
	if w.tick % 60 == 0:
		_floor_rec["peak_alive"] = maxi(_floor_rec["peak_alive"], WaveDirector.enemies_alive(w))
		for i in range(1, w.actors.size()):
			if w.actors.dead[i] == 0 and w.actors.teams[i] == ActorStore.TEAM_ENEMY:
				_kinds[kind_name(w.actors.kinds[i])] = true


func _event(w: World, e: SimEvent, start: int) -> void:
	match e.kind:
		SimEvent.Kind.DAMAGE:
			if e.target_id == _me:
				_floor_rec["damage_taken"] = int(_floor_rec["damage_taken"]) + e.amount_applied
			elif e.owner_id == _me:
				var key := String(e.effect_id) if e.effect_id != &"" else "-"
				var d: Dictionary = _floor_rec["dealt_by_effect"]
				d[key] = int(d.get(key, 0)) + e.amount_applied
				_floor_rec["dealt_total"] = int(_floor_rec["dealt_total"]) + e.amount_applied
				if not _first_hit.has(e.target_id):
					_first_hit[e.target_id] = e.tick
					var i := w.actors.index_of(e.target_id)
					_hit_kind[e.target_id] = w.actors.kinds[i] if i >= 0 else -1
		SimEvent.Kind.KILL:
			if _first_hit.has(e.target_id):
				var k: int = _hit_kind.get(e.target_id, -1)
				if k >= 0:
					var ttk: Dictionary = _floor_rec["ttk"]
					var name := kind_name(k)
					if not ttk.has(name):
						ttk[name] = []
					(ttk[name] as Array).append(e.tick - int(_first_hit[e.target_id]))
				_first_hit.erase(e.target_id)
		SimEvent.Kind.PICKUP:
			if _offer_index.has(e.source_id):
				var o: Dictionary = record["offers"][_offer_index[e.source_id]]
				(o["picked"] as Array).append(card_key(w, e.amount))
			(
				record["picks"]
				. append(
					{
						"floor": run.floor_index,
						"room": _floor_room_n,
						"g": _global_room,
						"tick": e.tick - start,
						"card": card_key(w, e.amount),
					}
				)
			)
		SimEvent.Kind.LIMIT:
			var key := String(e.effect_id) if e.effect_id != &"" else "-"
			var lim: Dictionary = record["limit"]
			lim[key] = int(lim.get(key, 0)) + 1
		SimEvent.Kind.HEAL, SimEvent.Kind.BARRIER:
			if e.target_id == _me:
				var kind := "heal" if e.kind == SimEvent.Kind.HEAL else "barrier"
				var key := "%s:%s" % [kind, String(e.effect_id) if e.effect_id != &"" else "-"]
				var cap: Dictionary = record["cap"]
				if not cap.has(key):
					cap[key] = [0, 0]
				cap[key][0] += e.amount
				cap[key][1] += e.amount_applied


func _offer(w: World, codes: PackedInt32Array, src: String, ref: int, el: int) -> void:
	var cards: Array = []
	var relevant := 0
	var engine := 0
	for c in codes:
		if c < 0:
			continue
		cards.append(card_key(w, c))
		if is_relevant(w, c, bot.focus):
			relevant += 1
		if is_engine(w, c):
			engine += 1
	_offer_index[ref] = (record["offers"] as Array).size()
	(
		record["offers"]
		. append(
			{
				"floor": run.floor_index,
				"room": _floor_room_n,
				"g": _global_room,
				"tick": el,
				"source": src,
				"cards": cards,
				"picked": [],
				"relevant": relevant,
				"engine": engine,
			}
		)
	)


func _enter_room(w: World, start: int, room: int = -1) -> void:
	if room < 0:
		room = w.floor_layout.room_of(w.player_pos())
	_room_seen[room] = true
	var n := _room_seen.size() - 1  # the start hall is entered first: Room 0
	_floor_room_n = n
	if n > 0:
		_global_room += 1
	var a := w.actors
	var armour := maxi(1, Stats.armour_permille(w)) if Stats.enabled(w) else 1000
	_room_rec = {
		"floor": run.floor_index,
		"room": n,
		"g": _global_room,
		"tick": w.tick - start,
		"max_hp": a.max_hp[0],
		"hp": a.hp[0],
		"ehp": a.max_hp[0] * 1000 / armour,
		"dealt": 0,
		"combat_ticks": 0,
		"boss": room == w.floor_layout.boss_room,
		"overrun": room == w.floor_layout.overrun_room,
	}
	(record["rooms"] as Array).append(_room_rec)


func _death(w: World, start: int) -> void:
	var reader := WorldReader.new(w)
	var cause := String(reader.killer_cause_key())
	if cause.is_empty():
		cause = String(EndPanel.CAUSES.get(reader.killer_kind(), "CAUSE_UNKNOWN"))
	record["death"] = {
		"floor": run.floor_index,
		"room": _floor_room_n,
		"g": _global_room,
		"tick": w.tick - start,
		"kind": kind_name(reader.killer_kind()) if reader.killer_kind() >= 0 else "-",
		"cause": cause,
		"in_boss_room": _boss_start >= 0,
	}


func _close_bout() -> void:
	if _bout_start >= 0:
		(_floor_rec["encounters"] as Array).append([_bout_last - _bout_start + 6, false])
	_bout_start = -1
	_bout_last = -1


static func _enemy_near(w: World, p: Vector2) -> bool:
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0 and w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			if Kin.length(w.actors.pos(i) - p) <= COMBAT_RANGE_M:
				return true
	return false


# --- Card and kind names (shared with the metrics) ----------------------------------------------------------------
## A card's key: "ability:<id>", "stat:<id>" or "mod:<id>" (CardPoolSurvey.key).
static func card_key(w: World, code: int) -> String:
	return CardPoolSurvey.key(w, code)


## A build-relevant card (M-DROUGHT): for a specialist, a card of its focus; for every other policy an ability card
## (new or a level-up) or a mod, never a plain stat card.
static func is_relevant(w: World, code: int, focus: String) -> bool:
	if not focus.is_empty():
		return ScoreBot.in_focus(w, code, focus)
	return Offers.type_of(code) != Offers.STAT


## An engine payoff (M-ENGINE): an ability that brings an engine (Arc Field, Frost Nova, Flame Trail) or a mod tagged
## with an engine (fire, shock, bleed, frost, guard, heat). Offers only hold cards the build can use.
static func is_engine(w: World, code: int) -> bool:
	match Offers.type_of(code):
		Offers.ABILITY:
			return ENGINE_ABILITIES.has(w.ability_tables[Offers.ability_of(code)].id)
		Offers.STAT:
			return false
	for tag in ScoreBot.mod_tags(w.item_tables[code].id):
		if ENGINE_TAGS.has(tag):
			return true
	return false


static func kind_name(kind: int) -> String:
	var names: Array = ActorStore.Kind.keys()
	return String(names[kind]).to_lower() if kind >= 0 and kind < names.size() else "-"


static func _sorted_keys(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k
