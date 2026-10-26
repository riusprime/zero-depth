class_name HardCompiler
extends RefCounted
## v0.9.5 BH2 (BOSSES_HARD.md B1-B5; BossHard): compiles the five harder spells' numbers onto their attack tables (their
## own file: ContentCompiler is at its line limit). Validation: HardRules.


## PatternCompiler.compile_boss_attack, after the active time is set: the second cross's lag and shift (the active time
## covers the last one), the fans' lead, the last leap's lead and width, the beam's turn (degrees a second -> 1/4096
## turns a tick x 1000), the grid's safe cells.
static func compile_attack(def: BossAttackDefinition, t: BossAttackTable) -> void:
	var sp := def.shape_params
	t.second_ticks = SimTick.seconds_to_ticks(float(sp.get("second_seconds", 0.0)))
	t.second_offset_m = float(sp.get("second_offset_m", 0.0))
	t.lead_ticks = SimTick.seconds_to_ticks(float(sp.get("lead_seconds", 0.0)))
	t.last_lead_ticks = SimTick.seconds_to_ticks(float(sp.get("last_lead_seconds", 0.0)))
	t.last_radius_bonus_permille = int(sp.get("last_radius_bonus_permille", 0))
	t.beam_turn_milli = int(
		round(float(sp.get("turn_dps", 0.0)) * 4096.0 / 360.0 * 1000.0 / SimTick.TICKS_PER_SECOND)
	)
	t.safe_cells = int(sp.get("safe_cells", 0))
	if t.second_ticks > 0:
		var last := (t.count - 1) * t.mark_gap_ticks + t.second_ticks
		t.active_ticks = maxi(t.active_ticks, last + (2 if t.pillar_ticks > 0 else 1))
	# v0.9.5 BH3 (B8): the Crossfire's tracking (degrees a second -> 1/4096 turns a tick x 1000)
	t.lines_ticks = SimTick.seconds_to_ticks(float(sp.get("lines_follow_seconds", 0.0)))
	t.lines_turn_milli = int(
		round(
			(
				float(sp.get("lines_turn_dps", 0.0))
				* 4096.0
				/ 360.0
				* 1000.0
				/ SimTick.TICKS_PER_SECOND
			)
		)
	)
