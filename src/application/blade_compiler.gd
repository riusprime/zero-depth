class_name BladeCompiler
extends RefCounted
## v0.6.5 WN4 (docs/design/WAND.md, the Blade pool; CONTENT_SCHEMA "The wand"): BladeFormsDefinition → BladeTable.
## Its own file (content_compiler.gd is near the lint's line limit).


static func compile(def: BladeFormsDefinition) -> BladeTable:
	if def == null:
		return null
	var t := BladeTable.new()
	t.orbit_max = def.orbit_max
	t.orbit_turn = maxi(
		1, ContentCompiler.degrees_to_units(def.orbit_turns_per_second * 360.0) / 60
	)
	t.orbit_gap = maxi(1, SimTick.seconds_to_ticks(def.orbit_gap_seconds))
	t.knock_ticks = maxi(1, SimTick.seconds_to_ticks(def.knock_seconds))
	t.lunge_ticks = maxi(1, SimTick.seconds_to_ticks(def.lunge_seconds))
	t.rate_min = def.min_rate_permille
	return t


## The shipped numbers (data/wand/blade_forms.tres) from a repository, or null without one.
static func from_repo(repo: ContentRepository) -> BladeTable:
	return compile(repo.get_def(&"wand", &"blade_forms") as BladeFormsDefinition)
