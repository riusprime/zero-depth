class_name HazardCompiler
extends RefCounted
## Compiles a boss's arena hazards (BossDefinition.hazard, HazardRules.SPEC) into
## its table's HazardTable, in sim units (its own file: ContentCompiler is at its line limit).


## PatternCompiler.compile_cadence: the hazards, or none (t.hazard stays null).
static func compile_boss(def: BossDefinition, t: BossTable) -> void:
	var h := def.hazard
	if h.is_empty():
		return
	var ht := HazardTable.new()
	ht.kind = (
		HazardTable.Kind.SLOW if String(h.get("kind", "")) == "slow" else HazardTable.Kind.DAMAGE
	)
	ht.look = StringName(String(h.get("look", "lava")))
	ht.radius_m = HazardRules.value(h, "radius_m")
	ht.life_ticks = maxi(1, SimTick.seconds_to_ticks(HazardRules.value(h, "life_seconds")))
	ht.warn_ticks = SimTick.seconds_to_ticks(HazardRules.value(h, "warn_seconds"))
	ht.max_count = int(HazardRules.value(h, "max_count"))
	ht.max_cover_permille = int(HazardRules.value(h, "max_cover_permille"))
	ht.damage = int(HazardRules.value(h, "damage"))
	ht.burn_ticks = maxi(1, SimTick.seconds_to_ticks(HazardRules.value(h, "burn_seconds")))
	ht.slow_permille = int(HazardRules.value(h, "slow_permille"))
	ht.impact_damage = int(HazardRules.value(h, "impact_damage"))
	ht.per_attack = int(HazardRules.value(h, "per_attack"))
	for id: Variant in h.get("attack_ids", []):
		for k in def.attacks.size():
			if def.attacks[k] != null and String(def.attacks[k].id) == String(id):
				ht.attacks.append(k)
	ht.cause_key = def.hazard_cause_key
	t.hazard = ht
