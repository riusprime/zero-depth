class_name BossTable
extends RefCounted
## One boss's compiled numbers in sim units (metres, metres per tick, ticks, 1/4096 turns, per mille). Built from
## BossDefinition by ContentCompiler.compile_bosses; give the list to World.set_boss_tables.
## The arena (arena_cells, arena_template) is what the floor generator reads to build the boss room.

## v0.8.0 FB3: a mimic body's stances (BossNemesis; doc at `mimic` below).
const STANCE_ECHO := 0
const STANCE_MIRROR := 1
const STANCE_CLOSE := 2
const STANCE_BACK := 3

var id := &""
var name_key := &""
var kind := ActorStore.Kind.GATEKEEPER
var hp := 1
var radius_m := 1.0
var speed := 0.0
## 1/4096 turns per tick while pursuing (0 = always faces the player).
var turn_rate := 0
var keep_distance_m := 0.0
## Armour by hit direction, as EnemyTable (Damage.target_mult).
var front_half_arc := 0
var front_mult_permille := 1000
var rear_half_arc := 0
var rear_mult_permille := 1000
## Stagger meter: size and decay per tick in milli-points (1000 per damage point), and the stagger's length.
var stagger_size_milli := 1000
var stagger_decay_milli := 0
var stagger_ticks := 150
var attacks: Array[BossAttackTable] = []
## Phases, in order: HP threshold (per mille of max HP), the attack indices it picks from, its entry attack (-1 =
## none), and its speed and cooldown per mille.
var phase_threshold := PackedInt32Array()
var phase_attacks: Array[PackedInt32Array] = []
var phase_entry := PackedInt32Array()
var phase_speed_permille := PackedInt32Array()
var phase_cd_permille := PackedInt32Array()
## The boss room: size in cells and its interior template (a FloorLayout.Template value).
var arena_cells := Vector2i(2, 2)
var arena_template := 0
## v0.7.5 BF1 (N18): the room an older save's floor is rebuilt with (BossDefinition.legacy_arena_cells).
var legacy_arena_cells := Vector2i(2, 2)
## Boss challenge (v0.3.0 BX, L17 and L26; BossChallenge). Distances are from the boss's edge to the player's centre.
## Ranged armour: the player's hits deal 1000 per mille up to ranged_full_m, falling linearly to ranged_far_permille
## at ranged_far_m and beyond.
var ranged_full_m := 5.0
var ranged_far_m := 12.0
var ranged_far_permille := 1000
## Punish: beyond punish_distance_m for punish_ticks, it performs attack punish_attack (-1 = none).
var punish_distance_m := 9.0
var punish_ticks := 0
var punish_attack := -1
## Weak point: open for weak_ticks after an attack that opens it; hits from within weak_range_m deal weak_mult and
## fill the stagger meter by weak_stagger (per mille).
var weak_ticks := 0
var weak_range_m := 2.5
var weak_mult_permille := 1000
var weak_stagger_permille := 1000
## v0.4.0 BO: while the weak point is open the front armour doesn't apply (the Warlord lifts its shield).
var weak_drops_armour := false
## Closing arena: it starts at phase close_phase (-1 = not by phase) or after close_after_ticks of fighting (0 = not
## by time); every close_step_ticks the band moves close_step_m inward (0 = never closes), each step marked
## close_warn_ticks first, and stops safe_half_m short of the room's centre on each axis. Standing in the band hurts
## hazard_damage every hazard_ticks.
var close_phase := -1
var close_after_ticks := 0
var close_step_ticks := 1
var close_step_m := 0.0
var close_warn_ticks := 24
var safe_half_m := 5.0
var hazard_damage := 0
var hazard_ticks := 30
## Harder AI: attacks aim where the player will be in lead_ticks at their current velocity.
var lead_ticks := 0
## v0.3.5 AI (owner F3): aimed windups keep tracking the player until their last commit_ticks (0 = they lock at the
## start); for dash_read_ticks after a dash, aimed attacks go at its landing point (0 = off); beyond
## gap_distance_m for gap_ticks, it performs gap_attack, its gap-closer (-1 = none).
var commit_ticks := 0
var dash_read_ticks := 0
var gap_distance_m := 0.0
var gap_ticks := 0
var gap_attack := -1
## v0.8.0 FB2 (owner F7, "Phase-by-phase mix"; FINAL_BOSS.md F5, F7; BossPrism): a body whose HP is set as it rises
## from the player's measured damage per second (FinalFight's meter: the last dps_seconds closed seconds, at least
## dps_min_seconds of them, else its own hp): hp = dps × dps_target_ticks / 60 × window_permille / 1000, clamped to
## dps_hp_min..dps_hp_max. window_permille is the share of its Cross's cycle that is a window (compiled from its
## `cross` attacks), so at the measured DPS in every window it lasts about dps_target_ticks. It floats home (the
## fight's centre) and its shards orbit it: shard_count of them, shard_orbit_m from its centre, turning shard_turn_milli
## thousandths of 1/4096 of a turn a tick (0 shards: none).
var dps_hp := false
var dps_seconds := 0
var dps_min_seconds := 0
var dps_target_ticks := 0
var dps_hp_min := 1
var dps_hp_max := 1
var window_permille := 1000
var floats_home := false
var shard_count := 0
var shard_orbit_m := 0.0
var shard_turn_milli := 0
## v0.8.0 PR (owner O84: "he shouldnt have all 3 spells at the same time, we should rotate"; BossPrism.next_spell): a
## body whose phase attacks are a fixed rotation, cast in their listed order, one at a time, with no draw from the ai
## stream; each waits until every shot the body fired is gone.
var rotation := false
## v0.8.0 FB3 (owner F6 "Weapon + dash + 2-3 cards", F7 "Nemesis takes its HP and damage from your own build, an even
## duel"; FINAL_BOSS.md F6, F7; BossNemesis, NemesisBuild): a mimic body. It echoes the player's path echo_ticks later
## (a ring of the player's positions), dashes when the player dashes (dash_react_ticks later, the player's own dash),
## and between attacks keeps a stance for stance_ticks: STANCE_ECHO, STANCE_MIRROR (across the fight's centre from the
## player), STANCE_CLOSE (at the player), STANCE_BACK (back off to back_off_m), drawn from the ai stream by
## stance_weights (in that order). It casts the card_casts strongest cards of the player's wand.
## Its HP as it rises (build_hp): the player's max HP × build_hp_permille / 1000 + the measured DPS × dps_target_ticks
## / 60 (FinalFight's meter, its dps_seconds / dps_min_seconds; without enough measured, the first term alone), clamped
## to dps_hp_min..dps_hp_max. Its hit: the player's weapon damage (Modifiers.weapon_damage) × build_damage_permille /
## 1000, at least damage_min, at most damage_cap_permille of the player's max HP (never a one-shot); each attack deals
## its `damage` per cent of that hit (still at most the cap). Its hostile copies of the player's attacks are clamped:
## shots shot_speed_min..shot_speed_max (m per tick), shot_radius_min_m..shot_radius_max_m, at most shot_range_m and
## shots_max a volley; arcs reach at most reach_max_m; blasts blast_min_m..blast_max_m.
var mimic := false
var echo_ticks := 30
var dash_react_ticks := 15
var stance_ticks := 90
var stance_weights := PackedInt32Array([3, 2, 2, 2])
var back_off_m := 6.0
var card_casts := 3
var build_hp := false
var build_hp_permille := 2000
var build_damage_permille := 1500
var damage_min := 6
var damage_cap_permille := 200
var shot_speed_min := 0.1167
var shot_speed_max := 0.2167
var shot_radius_min_m := 0.15
var shot_radius_max_m := 0.5
var shot_range_m := 14.0
var shots_max := 12
var reach_max_m := 4.5
var blast_min_m := 1.0
var blast_max_m := 3.0
## v0.8.0 N2 (owner O41; FinalPace; FINAL_BOSS.md "N2"): a paced body. Its HP is set from the player's measured damage
## per second (the meter's last dps_seconds, at least dps_min_seconds of them: as it rises, or the first tick the
## meter holds them) so that at that rate it lasts pace_ref_ticks × sqrt(pace_ref_dps / dps), within pace_min_ticks ..
## pace_max_ticks (× window_permille: the Prism's windows), clamped to dps_hp_min..dps_hp_max; and it takes at most
## max HP / pace_min_ticks a tick, from a bucket that holds at most pace_burst_ticks of it (the rate cap: never under
## pace_min_ticks of fighting, whatever the build).
var pace := false
var pace_ref_dps := 30
var pace_ref_ticks := 7200
var pace_min_ticks := 3600
var pace_max_ticks := 10800
var pace_burst_ticks := 600
## v0.8.0 N2 (owner O42, O52; BossNemesis): The Fallen copies the build only in windows: window_ticks long, one every
## window_every_ticks, the first window_first_ticks after it rises (past its rise), each shown window_warn_ticks ahead.
## In a window the player's damage on it is pulled to the reference level (FinalPace.nerf_permille, at least
## nerf_min_permille) and their move speed to the base (at most 1000 per mille). 0 window_ticks: it copies all the time.
var window_ticks := 0
var window_every_ticks := 1200
var window_first_ticks := 720
var window_warn_ticks := 90
var nerf_min_permille := 100


## The attack index with this id, or -1.
func attack_index(attack_id: StringName) -> int:
	for k in attacks.size():
		if attacks[k].id == attack_id:
			return k
	return -1


## A boss from a floor's pool (indices into World.boss_tables), drawn from `rng` (the map stream). -1 if empty.
static func pick(pool: PackedInt32Array, rng: RngStream) -> int:
	if pool.is_empty():
		return -1
	return pool[rng.range_int(0, pool.size() - 1)]
