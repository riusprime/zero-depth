class_name WandCompiler
extends RefCounted
## v0.6.5 WN1 (docs/design/WAND.md; CONTENT_SCHEMA "The wand"): WandDefinition → WandTable. Its own file
## (content_compiler.gd is near the lint's line limit).


static func compile(def: WandDefinition) -> WandTable:
	if def == null:
		return null
	var t := WandTable.new()
	t.slots_per_floor = def.slots_per_floor.duplicate()
	t.child_size_permille = def.child_size_permille
	t.child_range_permille = def.child_range_permille
	t.child_damage_permille = def.child_damage_permille
	t.blade_hit_casts = def.blade_hit_casts  # v0.8.0 BL (BLADE_AUDIT B3, B6)
	t.blade_cast_gap_ticks = SimTick.seconds_to_ticks(def.blade_cast_gap_seconds)
	t.once_per_line = def.once_per_line.duplicate()
	t.cast_free_lines = def.cast_free_lines.duplicate()  # v0.8.0 PF2
	t.blast_merge_after = def.blast_merge_after
	t.blast_merge_ids = def.blast_merge_ids.duplicate()
	t.hole_ticks = SimTick.seconds_to_ticks(def.hole_seconds)  # v0.8.0 P2 (O24): Void's black holes
	t.hole_max = def.hole_max
	t.hole_pull_radius_m = def.hole_pull_radius_m
	t.hole_pull_step_m = def.hole_pull_mps / SimTick.TICKS_PER_SECOND
	t.hole_radius_m = def.hole_radius_m
	t.hole_period_ticks = maxi(1, SimTick.seconds_to_ticks(def.hole_period_seconds))
	t.secondary_proc_permille = def.secondary_proc_permille  # v0.8.0 MR (O91)
	t.after_trigger_dead = def.after_trigger_dead.duplicate()
	t.remnant_max = def.remnant_max  # v0.8.0 RM (O91): the remnants' limits, Thermal Break
	t.remnant_kind_max = def.remnant_kind_max.duplicate()
	t.remnant_activations_max = def.remnant_activations_max
	t.thermal_base = def.thermal_base
	t.thermal_per_burn = def.thermal_per_burn
	t.thermal_shatter_ticks = SimTick.seconds_to_ticks(def.thermal_shatter_seconds)
	return t


## The shipped wand (data/wand/wand.tres) from a repository, or null without one; v0.6.5 WN5b: with the old cards'
## migration (data/wand/migration.tres).
static func from_repo(repo: ContentRepository) -> WandTable:
	var t := compile(repo.get_def(&"wand", &"wand") as WandDefinition)
	if t != null:
		add_migration(t, migration(repo))
	return t


## v0.9.0 FV: from_repo, with the run's own slots per floor when it has them (RunTable.wand_slots_per_floor: the
## v0.8.0 3-floor shape keeps 4 → 6 → 8; empty: data/wand's).
static func for_run(repo: ContentRepository, run: RunTable) -> WandTable:
	var t := from_repo(repo)
	if t != null and run != null and not run.wand_slots_per_floor.is_empty():
		t.slots_per_floor = run.wand_slots_per_floor.duplicate()
	return t


## v0.6.5 WN5b: the old cards' map (null without one).
static func migration(repo: ContentRepository) -> WandMigrationDefinition:
	return repo.get_def(&"wand", &"migration") as WandMigrationDefinition


## v0.6.5 WN5b: `def`'s rows into `t` (WandMigration reads them on a load).
static func add_migration(t: WandTable, def: WandMigrationDefinition) -> void:
	if def == null:
		return
	var n := mini(def.old_ids.size(), mini(def.blade_into.size(), def.gun_into.size()))
	for k in n:
		t.migrate_ids.append(def.old_ids[k])
		t.migrate_blade.append(def.blade_into[k])
		t.migrate_gun.append(def.gun_into[k])


## v0.6.5 WN5b (WAND.md "What happens to the v0.6 cards"): the compiled items the migration table retires are marked
## (ItemTable.retired: ItemPool never offers them). Returns `items`.
static func retire_items(repo: ContentRepository, items: Array[ItemTable]) -> Array[ItemTable]:
	var def := migration(repo)
	if def != null:
		for t in items:
			t.retired = def.old_ids.has(t.id)
	return items


## v0.6.5 WN5b: the same for the six old ability modifiers (AbilityTable.retired: Abilities.can_take refuses them).
static func retire_abilities(
	repo: ContentRepository, abilities: Array[AbilityTable]
) -> Array[AbilityTable]:
	var def := migration(repo)
	if def != null:
		for t in abilities:
			t.retired = def.old_ids.has(t.id)
	return abilities


## v0.9.0 AS (owner Q2–Q5, Q13): the slot limits, the projectile caps and the form × card compatibility table
## (data/wand/attack_slots.tres) against `items` (World.item_tables: its ids become item indices), or null without the
## data (a lab: no limits).
static func slots(repo: ContentRepository, items: Array[ItemTable]) -> SlotTable:
	return compile_slots(repo.get_def(&"wand", &"attack_slots") as AttackSlotsDefinition, items)


static func compile_slots(def: AttackSlotsDefinition, items: Array[ItemTable]) -> SlotTable:
	if def == null:
		return null
	var t := SlotTable.new()
	t.gun_limits = def.gun_limits.duplicate()
	t.blade_limits = def.blade_limits.duplicate()
	t.shots_per_attack_max = def.shots_per_attack_max
	t.shots_per_second_max = def.shots_per_second_max
	t.merge_radius_max_permille = def.merge_radius_max_permille
	var index := {}
	for k in items.size():
		index[items[k].id] = k
	for r in def.forms:
		t.form_ids.append(r.id)
		t.form_cards.append(int(index.get(r.card, -1)) if not String(r.card).is_empty() else -1)
		var cells := {}
		for id in r.allowed:
			if index.has(id):
				cells[int(index[id])] = SlotTable.CELL_ON
		for id in r.ruled:
			if index.has(id):
				cells[int(index[id])] = SlotTable.CELL_RULED
		t.form_cells.append(cells)
		if String(r.card).is_empty() and t.default_form < 0:
			t.default_form = t.form_ids.size() - 1
	return t
