class_name VariantCompiler
extends RefCounted
## v0.11.0 O13a (PLAN M3; ENEMIES.md V1-V5; owner Q23): the biome variants and rosters in the sim's units. A variant
## compiles as its base (ContentCompiler matches BehaviourSchemas.base_of), then its own numbers here; it opens on a
## floor's curve with its base (inherit_phases), and only on its own biome's floors (biome_only_rows,
## FloorPlan.roster_kinds_of, SpawnDirector.unlocked).


## A variant's own numbers onto its compiled table `t` (nothing for any other behaviour).
static func compile(def: EnemyDefinition, t: EnemyTable) -> void:
	var bp := def.behaviour_params
	match def.behaviour_id:
		&"rubble_warden":
			t.hp = def.hp + int(bp["crust_hp"])  # the crust sits on top of the Warden's HP
			t.crust_pieces = int(bp["crust_pieces"])
			t.piece_half_m = float(bp["piece_half_m"])
		&"dim_needle":
			t.dark_beyond_m = float(bp["dark_beyond_m"])
		&"ember_charger", &"frost_charger":
			var fire := def.behaviour_id == &"ember_charger"
			t.trail = Variants.TRAIL_FIRE if fire else Variants.TRAIL_SLICK
			t.trail_radius_m = float(bp["trail_radius_m"])
			t.trail_ticks = maxi(1, SimTick.seconds_to_ticks(float(bp["trail_seconds"])))
			t.trail_step_ticks = maxi(1, SimTick.seconds_to_ticks(float(bp["trail_step_seconds"])))
			if fire:
				t.trail_arm_ticks = SimTick.seconds_to_ticks(float(bp["trail_arm_seconds"]))
				t.burn_damage = int(bp["burn_damage"])
				t.burn_period_ticks = maxi(
					1, SimTick.seconds_to_ticks(float(bp["burn_period_seconds"]))
				)
			else:
				t.slick_permille = ContentCompiler.ease_permille(float(bp["slick_ease_seconds"]))
		&"split_sniper":
			t.split_at_permille = int(bp["split_at_permille"])
			t.split_turn = ContentCompiler.degrees_to_units(float(bp["split_degrees"]))


## A curve's phase per actor kind (`phase_of`, from the kinds it names) gains every variant at its base's phase, so a
## variant opens when its base does on that floor (floor depth unlocks it as it unlocks the base).
static func inherit_phases(repo: ContentRepository, phase_of: Dictionary) -> void:
	for e: EnemyDefinition in repo.all_of(&"enemies"):
		var base: StringName = BehaviourSchemas.VARIANT_OF.get(e.behaviour_id, &"")
		if base == &"":
			continue
		var base_kind: int = ContentCompiler.ENEMY_KINDS.get(base, -1)
		if phase_of.has(base_kind):
			phase_of[ContentCompiler.ENEMY_KINDS[e.behaviour_id]] = phase_of[base_kind]


## Per mix row of `def`: 1 when its enemy is some biome's signature or variant (it spawns only on that biome's floors),
## else 0 (the shared core and the floor-unlocked kinds spawn on every biome).
static func biome_only_rows(
	def: SpawnDirectorDefinition, repo: ContentRepository
) -> PackedByteArray:
	var own := {}
	for b: BiomeDefinition in repo.all_of(&"biomes"):
		for id: StringName in b.signature_ids:
			own[id] = true
		if b.variant_id != &"":
			own[b.variant_id] = true
	var out := PackedByteArray()
	for e in def.mix:
		out.append(1 if own.has(e.enemy_id) else 0)
	return out


## The actor kinds `biome` alone spawns (its variant and its signatures whose definitions exist; a signature not built
## yet is skipped), sorted; empty for none (no biome, or the final arena).
static func roster_kinds(repo: ContentRepository, biome: BiomeDefinition) -> PackedInt32Array:
	var out := PackedInt32Array()
	if biome == null or biome.category() != &"biomes":
		return out
	var ids: Array[StringName] = biome.signature_ids.duplicate()
	ids.append(biome.variant_id)
	for id in ids:
		var def: EnemyDefinition = repo.get_def(&"enemies", id) if id != &"" else null
		if def != null and ContentCompiler.ENEMY_KINDS.has(def.behaviour_id):
			out.append(ContentCompiler.ENEMY_KINDS[def.behaviour_id])
	out.sort()
	return out
