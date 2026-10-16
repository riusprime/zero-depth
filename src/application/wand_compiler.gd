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
	return t


## The shipped wand (data/wand/wand.tres) from a repository, or null without one; v0.6.5 WN5b: with the old cards'
## migration (data/wand/migration.tres).
static func from_repo(repo: ContentRepository) -> WandTable:
	var t := compile(repo.get_def(&"wand", &"wand") as WandDefinition)
	if t != null:
		add_migration(t, migration(repo))
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
