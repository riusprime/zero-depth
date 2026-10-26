class_name InterphaseTable
extends RefCounted
## v0.9.5 BH6 (owner, 2026-10-25: "for phase 3 ... some interphases ... where he dissapears and then he makes different
## kind of patterns, with rays, balls, and thing that come out of the ground ... for about 15 seconds ... 6/10
## difficulty"; docs/roadmap/v0.9.5/BOSSES_HARD.md rows HC4, HC5, HC6): the Fallen's interphases and dashes in sim units
## (ticks, m, per-tick speeds), compiled from FinalBossDefinition.interphase (BossInterphase). `from` names the HP
## thresholds (per mille of max HP), `ticks` the length of the vanished stretch, `finish_ticks` the most a move in
## progress may run on once a threshold is reached. Every number is data.

## The HP thresholds (per mille), in order: the interphase at 66 % and at 33 %.
var thresholds := PackedInt32Array()
var ticks := 900
var finish_ticks := 60
## The table's attack indices of the five carriers (damage, telegraph and recap cause): the Rays' beams, the Rain's
## spike lines, Lights Out's drifting balls, the ground eruptions, the return slam.
var atk_rays := -1
var atk_rain := -1
var atk_dark := -1
var atk_erupt := -1
var atk_return := -1
## No two hits from the interphase land closer than this (ticks).
var grace_ticks := 30
var slam_m := 2.5
## Rays.
var beam_count := 3
var beam_half_m := 0.3
## 1/4096 turns a tick x 1000.
var beam_turn_milli := 4740
var erupt_ticks := 120
var erupt_m := 1.4
## Rain.
var rain_ticks := 72
var rain_balls := 16
var rain_gap_slots := 3
var rain_speed := 2.8 / 60.0
var rain_radius_m := 0.3
var rain_inset_m := 1.0
var spike_ticks := 180
var spike_half_m := 0.5
var spike_speed := 4.0 / 60.0
var spike_len_m := 10.0
## Lights Out.
var dark_balls := 6
var dark_ball_speed := 1.6 / 60.0
var dark_ball_radius_m := 0.35
var dark_erupt_ticks := 150
var light_m := 3.5
var lamp_m := 3.0
var lamp_ticks := 480
var relight_m := 1.5
var lamp_inset_m := 1.5
## HC6: the dash between moves.
var dash_telegraph_ticks := 24
var dash_ticks := 12
var dash_min_m := 6.0
var dash_max_m := 9.0
var dash_wall_m := 3.0
var dash_every := true


func enabled() -> bool:
	return not thresholds.is_empty()
