class_name EventCompiler
extends RefCounted
## Compiles the event rooms' content (v0.5.0 EV; CONTENT_SCHEMA §9) into sim tables: events and curses by id (the
## order World.ev's indices refer to), and the rules. Percent becomes per mille, seconds ticks. Kept beside
## ContentCompiler so the shared compiler stays as it was.


static func compile_curses(repo: ContentRepository) -> Array[CurseTable]:
	var out: Array[CurseTable] = []
	for def: CurseDefinition in repo.all_of(&"curses"):
		var t := CurseTable.new()
		t.id = def.id
		t.name_key = def.name_key
		t.desc_key = def.desc_key
		t.effect = CurseDefinition.EFFECTS.find(def.effect)
		var count := def.effect == &"extra_enemy"
		t.amount = int(round(def.amount)) if count else int(round(def.amount * 10.0))
		t.threat = def.threat
		t.weight = def.weight
		out.append(t)
	return out


static func compile_events(repo: ContentRepository) -> Array[EventTable]:
	var curse_ids: Array[StringName] = []
	for def: CurseDefinition in repo.all_of(&"curses"):
		curse_ids.append(def.id)
	var out: Array[EventTable] = []
	for def: EventDefinition in repo.all_of(&"events"):
		var t := EventTable.new()
		t.id = def.id
		t.name_key = def.name_key
		t.desc_key = def.desc_key
		t.weight = def.weight
		t.min_floor = def.min_floor
		t.requires = EventDefinition.REQUIRES.find(def.requires)
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
				t.curse.append(curse_ids.find(c.curse))
		out.append(t)
	return out


static func _cost_amount(cost: int, amount: float) -> int:
	match cost:
		Events.Cost.HP, Events.Cost.MAX_HP:
			return int(round(amount * 10.0))
		Events.Cost.DEFEND:
			return int(round(amount * SimTick.TICKS_PER_SECOND))
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
	t.elite_hp_bonus_permille = int(round(def.elite_hp_bonus * 10.0))
	t.ambush_min_distance_m = def.ambush_min_distance_m
	t.defend_radius_m = def.defend_radius_m
	return t


## Sets up a built floor's event rooms from the repository (Main, the shot scripts and the tests).
static func setup(w: World, repo: ContentRepository) -> void:
	Events.setup(
		w,
		compile_events(repo),
		compile_curses(repo),
		compile_rules(repo.get_def(&"event_rules", &"floor"))
	)
