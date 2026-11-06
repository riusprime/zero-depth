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
	# v0.9.5 BH4 (T1): the tide's drift cap is data; (T3) a crossing wave's numbers
	if sp.has("max_mps"):
		t.tide_max = float(sp["max_mps"]) / SimTick.TICKS_PER_SECOND
	if def.move == &"wave":
		t.wave_lengths = PackedFloat32Array(sp.get("lengths_m", []))
		t.wave_thick_m = float(sp.get("thickness_m", 0.0))
		t.wave_speed = float(sp.get("speed_mps", 0.0)) / SimTick.TICKS_PER_SECOND
		t.wave_shove_m = float(sp.get("shove_m", 0.0))
		t.wave_clear_m = float(sp.get("clear_m", 0.0))


## ContentCompiler.compile_boss, after phase `ph` is appended: its ring stream and crossing wave (attack indices, -1 for
## none, and the ticks between).
static func compile_phase(ph: BossPhaseDefinition, t: BossTable) -> void:
	var ring := -1 if String(ph.stream_attack).is_empty() else t.attack_index(ph.stream_attack)
	var wave := -1 if String(ph.wave_attack).is_empty() else t.attack_index(ph.wave_attack)
	t.phase_ring_atk.append(ring)
	t.phase_ring_ticks.append(SimTick.seconds_to_ticks(ph.stream_every_seconds) if ring >= 0 else 0)
	t.phase_wave_atk.append(wave)
	t.phase_wave_ticks.append(SimTick.seconds_to_ticks(ph.wave_every_seconds) if wave >= 0 else 0)
	t.phase_wave_n.append(ph.wave_count if wave >= 0 else 0)
	t.streams = t.streams or ring >= 0 or wave >= 0
