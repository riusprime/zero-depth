class_name CanyonShoreCompiler
extends RefCounted
## v0.11.0 O13c (PLAN M2; ENEMIES.md R5-R8, approved 2026-11-07): the Red Canyon's and the Frozen Shore's signature
## enemies' own numbers in the sim's units (CanyonShore reads them). The Kiln Beetle and the Glacier Turtle compile as a
## Warden first (BehaviourSchemas.CANYON_SHORE_BASE); the Cinder Priest and the Frost Spitter keep a distance band
## (ContentCompiler._compile_horde: keep_min_m, keep_max_m). Signatures open on a floor's curve with the Warden
## (inherit_phases) and only on their own biome's floors (VariantCompiler.biome_only_rows, roster_kinds).


## A signature's own numbers onto its compiled table `t` (nothing for any other behaviour).
static func compile(def: EnemyDefinition, t: EnemyTable) -> void:
	var bp := def.behaviour_params
	match def.behaviour_id:
		&"kiln_beetle":
			t.burst_delay_ticks = SimTick.seconds_to_ticks(float(bp["burst_delay_seconds"]))
			t.burst_radius_m = float(bp["burst_radius_m"])
			t.burst_damage = int(bp["burst_damage"])
			t.burst_enemy_damage = int(bp["burst_enemy_damage"])
		&"cinder_priest":
			t.vent_reach_m = float(bp["vent_reach_m"])
			t.vent_period_ticks = maxi(
				1, SimTick.seconds_to_ticks(float(bp["vent_period_seconds"]))
			)
			t.vent_warn_ticks = SimTick.seconds_to_ticks(float(bp["vent_warn_seconds"]))
			t.vent_radius_m = float(bp["vent_radius_m"])
			t.vent_damage = int(bp["vent_damage"])
			t.vent_linger_ticks = SimTick.seconds_to_ticks(float(bp["vent_linger_seconds"]))
		&"frost_spitter":
			t.flight_ticks = maxi(1, SimTick.seconds_to_ticks(float(bp["flight_seconds"])))
			t.slick_radius_m = float(def.attacks[0].shape_params["radius_m"])
			t.slick_ticks = SimTick.seconds_to_ticks(float(bp["slick_seconds"]))
			t.slick_permille = ContentCompiler.ease_permille(float(bp["slick_ease_seconds"]))
		&"glacier_turtle":
			t.shell_hp = int(bp["shell_hp"])
			t.chunk_count = int(bp["chunk_count"])
			t.chunk_speed = float(bp["chunk_speed_mps"]) / SimTick.TICKS_PER_SECOND
			t.chunk_ticks = maxi(1, SimTick.seconds_to_ticks(float(bp["chunk_seconds"])))
			t.chunk_damage = int(bp["chunk_damage"])


## A curve's phase per actor kind (`phase_of`) gains every biome's signature enemy at the Warden's phase (the last of
## the shared core to open), so a signature opens on any floor of its biome once the core has; every floor's curve
## names the Warden, so a signature never comes before its floor.
static func inherit_phases(repo: ContentRepository, phase_of: Dictionary) -> void:
	var warden: int = ContentCompiler.ENEMY_KINDS[&"warden"]
	if not phase_of.has(warden):
		return
	for b: BiomeDefinition in repo.all_of(&"biomes"):
		for id: StringName in b.signature_ids:
			var def: EnemyDefinition = repo.get_def(&"enemies", id)
			if def != null and ContentCompiler.ENEMY_KINDS.has(def.behaviour_id):
				var kind: int = ContentCompiler.ENEMY_KINDS[def.behaviour_id]
				if not phase_of.has(kind):
					phase_of[kind] = phase_of[warden]
