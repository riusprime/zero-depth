class_name StressMarkCompiler
extends RefCounted
## v0.9.5 CLV, SM: the card-level cap and the Stress Mark's numbers of one item definition, in sim units
## (ContentCompiler.compile_item; split out to keep that file under the line cap).


static func compile(def: ItemDefinition, t: ItemTable) -> void:
	t.level_max = def.level_max  # v0.9.5 CLV
	t.mark_radius_m = def.mark_radius_m  # v0.9.5 SM
	t.mark_half_angle_deg = def.mark_half_angle_deg
	t.mark_mult_permille = def.mark_mult_permille
	t.mark_cooldown_ticks = SimTick.seconds_to_ticks(def.mark_cooldown_seconds)
	t.mark_boss_marks = def.mark_boss_marks
