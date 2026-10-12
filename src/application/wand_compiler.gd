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
	return t


## The shipped wand (data/wand/wand.tres) from a repository, or null without one.
static func from_repo(repo: ContentRepository) -> WandTable:
	return compile(repo.get_def(&"wand", &"wand") as WandDefinition)
