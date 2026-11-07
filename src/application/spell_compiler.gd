class_name SpellCompiler
extends RefCounted
## v0.11.0 O10 (owner Q17-Q20; SPELLS.md): the spells and their rules, compiled from SpellDefinition and
## SpellRulesDefinition (CONTENT_SCHEMA §9: seconds to ticks once, speeds to metres a tick).


## The spells the content ships, in SpellDefinition.SPELLS order (each keeps its index there). `items`: the world's
## compiled items (a spell's element card becomes an item index; -1 when absent, so it is never offered).
static func compile(repo: ContentRepository, items: Array[ItemTable]) -> Array[SpellTable]:
	var out: Array[SpellTable] = []
	for k in SpellDefinition.SPELLS.size():
		var def: SpellDefinition = repo.get_def(&"spells", SpellDefinition.SPELLS[k])
		if def == null:
			continue
		var t := SpellTable.new()
		t.id = def.id
		t.spell = k
		t.name_key = def.name_key
		t.desc_key = def.desc_key
		t.level_keys = def.level_keys.duplicate()
		t.element = maxi(0, SpellDefinition.ELEMENTS.find(def.element))
		for i in items.size():
			if items[i].id == def.element_card:
				t.element_item = i
		t.affinity = def.affinity
		t.weight = def.weight
		t.cooldown_ticks = maxi(1, SimTick.seconds_to_ticks(def.cooldown_s))
		t.reach_m = def.reach_m
		t.damage = def.damage.duplicate()
		t.radius_m = def.radius_m.duplicate()
		for s in def.seconds:
			t.ticks.append(maxi(1, SimTick.seconds_to_ticks(s)))
		t.count = def.count.duplicate()
		t.push_m = def.push_m
		t.jump_m = def.jump_m
		t.speed_m_tick = def.speed_mps / SimTick.TICKS_PER_SECOND
		t.stacks = def.stacks
		out.append(t)
	return out


## The rules (null when the content has none: a world without spells never offers one).
static func compile_rules(repo: ContentRepository) -> SpellRules:
	var def: SpellRulesDefinition = repo.get_def(&"spell_rules", &"spell_rules")
	if def == null:
		return null
	var r := SpellRules.new()
	r.slots = def.slots
	r.offer_permille = def.offer_permille
	r.affinity_permille = def.affinity_permille
	r.loop1_max_level = def.loop1_max_level
	r.pack_radius_m = def.pack_radius_m
	return r
