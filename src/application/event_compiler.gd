class_name EventCompiler
extends RefCounted
## Compiles the event rooms' content (v0.5.0 EV; CONTENT_SCHEMA §9) into sim tables: events and curses by id (the
## order World.ev's indices refer to), and the rules. Percent becomes per mille, seconds ticks. Kept beside
## ContentCompiler so the shared compiler stays as it was.
## v0.9.0 EL (owner Q25: the Marked curse and the Ambush Cache event "Remove it"): a deleted curse or event keeps its
## place in the id order (a retired table: never drawn on a floor built today, no effect), so the indices a save holds
## still name the same curses and events. RETIRED_EVENTS' weight is drawn only when a floor saved before EL is rebuilt
## (`legacy`), so that floor's draws are the ones it was saved with.

const RETIRED_CURSES: Array[StringName] = [&"marked_hunt"]
const RETIRED_EVENTS := {&"ambush_cache": 10}


static func compile_curses(repo: ContentRepository) -> Array[CurseTable]:
	var out: Array[CurseTable] = []
	for cid in curse_ids(repo):
		var def: CurseDefinition = repo.get_def(&"curses", cid)
		if def == null:
			var r := CurseTable.new()
			r.id = cid
			r.effect = -1
			r.threat = 0
			r.retired = true
			out.append(r)
			continue
		var t := CurseTable.new()
		t.id = def.id
		t.name_key = def.name_key
		t.desc_key = def.desc_key
		t.effect = CurseDefinition.EFFECTS.find(def.effect)
		t.amount = curse_amount(def.effect, def.amount)
		if def.effect_2 != &"":  # v0.6.0 CU: a second drawback, and a trade-off's upside
			t.effect_2 = CurseDefinition.EFFECTS.find(def.effect_2)
			t.amount_2 = curse_amount(def.effect_2, def.amount_2)
		if def.up_effect != &"":
			t.up_effect = CurseDefinition.EFFECTS.find(def.up_effect)
			t.up_amount = curse_amount(def.up_effect, def.up_amount)
			t.up_desc_key = def.up_desc_key
		t.threat = def.threat
		t.weight = def.weight
		out.append(t)
	return out


## A curse effect's amount in sim units: a count stays a count, seconds become ticks, a percent becomes per mille.
static func curse_amount(effect: StringName, amount: float) -> int:
	if CurseDefinition.COUNTS.has(effect):
		return int(round(amount))
	if CurseDefinition.SECONDS.has(effect):
		return SimTick.seconds_to_ticks(amount)
	return int(round(amount * 10.0))


## v0.9.0 EL: every curse id, the retired ones too, in id order (the order World.ev.curses' indices refer to).
static func curse_ids(repo: ContentRepository) -> Array[StringName]:
	return _ids(repo, &"curses", RETIRED_CURSES)


## v0.9.0 EL: every event id, the retired ones too, in id order.
static func event_ids(repo: ContentRepository) -> Array[StringName]:
	var retired: Array[StringName] = []
	for k: StringName in RETIRED_EVENTS:
		retired.append(k)
	return _ids(repo, &"events", retired)


static func _ids(
	repo: ContentRepository, category: StringName, retired: Array[StringName]
) -> Array[StringName]:
	var keys: Array[String] = []
	for def: ContentDef in repo.all_of(category):
		keys.append(String(def.id))
	for r in retired:
		if not keys.has(String(r)):
			keys.append(String(r))
	keys.sort()
	var out: Array[StringName] = []
	for k in keys:
		out.append(StringName(k))
	return out


## `legacy` (v0.9.0 EL): a floor saved before EL is being rebuilt; a retired event keeps its old weight there.
static func compile_events(repo: ContentRepository, legacy := false) -> Array[EventTable]:
	var curses := curse_ids(repo)
	var out: Array[EventTable] = []
	for eid in event_ids(repo):
		var def: EventDefinition = repo.get_def(&"events", eid)
		if def == null:
			var r := EventTable.new()
			r.id = eid
			r.retired = true
			r.legacy_weight = int(RETIRED_EVENTS.get(eid, 0))
			r.weight = r.legacy_weight if legacy else 0
			out.append(r)
			continue
		var t := EventTable.new()
		t.id = def.id
		t.name_key = def.name_key
		t.desc_key = def.desc_key
		t.weight = def.weight
		t.min_floor = def.min_floor
		t.requires = EventDefinition.REQUIRES.find(def.requires)
		t.deep_only = def.deep_only  # v0.5.5 DS (S5)
		t.curse_room = def.curse_room  # v0.8.0 N17 (O75)
		for c in def.choices:
			t.labels.append(c.label_key)
			var cost := EventChoiceDefinition.COSTS.find(c.cost)
			t.cost.append(cost)
			t.cost_amount.append(_cost_amount(cost, c.cost_amount))
			var reward := EventChoiceDefinition.REWARDS.find(c.reward)
			t.reward.append(reward)
			var permille := reward == Events.Reward.OVERCLOCK
			t.reward_amount.append(int(round(c.reward_amount * (10.0 if permille else 1.0))))
			if c.curse == &"":
				t.curse.append(Events.CURSE_NONE)
			elif c.curse == &"random":
				t.curse.append(Events.CURSE_RANDOM)
			else:
				t.curse.append(curses.find(c.curse))
		out.append(t)
	return out


static func _cost_amount(cost: int, amount: float) -> int:
	match cost:
		Events.Cost.HP, Events.Cost.MAX_HP:
			return int(round(amount * 10.0))
		Events.Cost.DEFEND:
			return SimTick.seconds_to_ticks(amount)
	return int(round(amount))


static func compile_rules(def: EventRulesDefinition) -> EventRules:
	var t := EventRules.new()
	if def == null:
		return t
	t.rooms_min = def.rooms_min
	t.rooms_max = def.rooms_max
	t.interact_radius_m = def.interact_radius_m
	t.clear_radius_m = def.clear_radius_m
	t.reward_gap_m = def.reward_gap_m
	t.cursed_chest_permille = int(round(def.cursed_chest_chance * 10.0))
	t.cursed_chest_first_floor = def.cursed_chest_first_floor  # v0.7.5 MG (N10)
	t.cursed_chest_every_floors = def.cursed_chest_every_floors
	t.cursed_chests_per_floor = def.cursed_chests_per_floor
	t.defend_radius_m = def.defend_radius_m
	t.cleanse_price = def.cleanse_price
	t.core_window_ticks = SimTick.seconds_to_ticks(def.core_window_seconds)  # v0.6.0 CU: core theft
	t.core_mod_weight = def.core_mod_weight
	t.drop_offset_m = def.drop_offset_m
	t.curse_room_floor_chance_permille = def.curse_room_floor_chance_permille  # v0.8.0 N17 (O75)
	t.curse_room_deep_chance_permille = def.curse_room_deep_chance_permille  # v0.8.0 N19 (O80)
	return t


## Sets up a built floor's event rooms from the repository (Main, the shot scripts and the tests). `curse_rules`
## (v0.8.0 N17, N19; Events.CURSE_RULES_*): a floor saved under older floor rules keeps its event rooms as they were
## (FloorScenario.curse_room_rules_of).
## v0.9.0 EL: `legacy` for a floor saved before EL (FloorScenario.retired_events_of): the retired event keeps its old
## weight in the draw, so the floor rebuilds as saved.
static func setup(
	w: World, repo: ContentRepository, curse_rules: int = Events.CURSE_RULES_N19, legacy := false
) -> void:
	Events.setup(
		w,
		compile_events(repo, legacy),
		compile_curses(repo),
		compile_rules(repo.get_def(&"event_rules", &"floor")),
		curse_rules
	)
