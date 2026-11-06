class_name FinalBossDefinition
extends BossDefinition
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F3-F8): one body of the final boss (the Colossus, the Prism, the Nemesis):
## a boss in every field (BossDefinition, CONTENT_SCHEMA §4), kept in its own category so the floors' boss indices
## (ContentCompiler.compile_bosses, saved in every run save) stay what they were. The run names its bodies in order
## (RunDefinition.final_bosses); data/final_boss/.
## v0.8.0 FB2 (owner F7, "Phase-by-phase mix": the Prism "is a skill phase … her HP is set from your measured damage
## per second so she always lasts about 60 s however strong you are"): a body with hp_from_dps takes its HP, as it
## rises, from the damage per second the fight measured (FinalBoss.dps_hp_of):
##   dps = the damage of the last dps_measure_seconds measured seconds / those seconds
##   hp  = clamp(dps × dps_target_seconds × (its Cross's window share), dps_hp_min, dps_hp_max)
## (the window share: the part of each Cross's cycle with the shield down), or its own hp when fewer than
## dps_min_measured_seconds were measured (a fight jumped straight to it). Its `hp` and the loop's scaling don't apply
## otherwise. Its shards (shard_count, shard_orbit_m from its centre, turning shard_turn_dps) orbit it and fire.

## v0.9.5 BH6: the interphase dictionary's keys and bounds.
## key: [default, min, max]
const INTERPHASE_SPEC := {
	"first_permille": [660, 100, 900],
	"second_permille": [330, 50, 800],
	"seconds": [15.0, 5.0, 30.0],
	"finish_seconds": [1.0, 0.1, 1.0],
	"grace_seconds": [0.5, 0.3, 2.0],
	"slam_m": [2.5, 1.0, 5.0],
	"beam_count": [3, 2, 5],
	"beam_width_m": [0.6, 0.2, 1.5],
	"beam_turn_dps": [25.0, 5.0, 60.0],
	"erupt_seconds": [2.0, 1.5, 6.0],
	"erupt_m": [1.4, 0.5, 3.0],
	"rain_seconds": [1.2, 0.6, 4.0],
	"rain_balls": [16, 8, 24],
	"rain_gap_slots": [3, 2, 5],
	"rain_speed_mps": [2.8, 1.0, 5.0],
	"rain_radius_m": [0.3, 0.1, 0.6],
	"rain_inset_m": [1.0, 0.5, 3.0],
	"spike_seconds": [3.0, 1.5, 8.0],
	"spike_width_m": [1.0, 0.4, 2.0],
	"spike_speed_mps": [4.0, 1.0, 8.0],
	"spike_length_m": [10.0, 4.0, 20.0],
	"dark_balls": [6, 1, 12],
	"dark_ball_speed_mps": [1.6, 0.5, 3.0],
	"dark_ball_radius_m": [0.35, 0.1, 0.8],
	"dark_erupt_seconds": [2.5, 1.5, 6.0],
	"light_m": [3.5, 1.0, 8.0],
	"lamp_m": [3.0, 1.0, 8.0],
	"lamp_seconds": [8.0, 2.0, 30.0],
	"relight_m": [1.5, 0.5, 4.0],
	"lamp_inset_m": [1.5, 0.5, 4.0],
	"dash_telegraph_seconds": [0.4, 0.3, 1.0],
	"dash_seconds": [0.2, 0.1, 0.6],
	"dash_min_m": [6.0, 2.0, 12.0],
	"dash_max_m": [9.0, 2.0, 14.0],
	"dash_wall_m": [3.0, 1.0, 6.0],
}

@export var hp_from_dps := false
@export var dps_measure_seconds := 20
@export var dps_min_measured_seconds := 5
@export var dps_target_seconds := 60.0
@export var dps_hp_min := 600
@export var dps_hp_max := 250000
@export var shard_count := 0
@export var shard_orbit_m := 0.0
@export var shard_turn_dps := 0.0
## v0.8.0 PR (owner O84): the body casts its phase's attacks in their listed order, one at a time (a fixed rotation;
## no weighted pick), and each waits until every shot it fired is gone (BossTable.rotation). Its phases list each
## attack once (the rotation finds its place by the last attack).
@export var spell_rotation := false
## v0.8.0 FB3 (owner F6 "Weapon + dash + 2-3 cards", F7 "Nemesis takes its HP and damage from your own build, an even
## duel"; CONTENT_SCHEMA §4 "the Nemesis"): a mimic body. It echoes the player's path echo_seconds behind, dashes
## dash_reaction_seconds after the player dashes, keeps a stance for stance_seconds (stance_weights: echo, mirror,
## close, back; back off to back_off_m) and casts the card_casts strongest cards of the player's wand.
## With hp_from_build its HP as it rises is the player's max HP × build_hp_permille / 1000 + the measured damage per
## second (the last dps_measure_seconds, at least dps_min_measured_seconds of them, else nothing) × dps_target_seconds,
## clamped to dps_hp_min..dps_hp_max; its hit is the player's weapon damage × build_damage_permille / 1000, at least
## build_damage_min, at most build_damage_cap_permille of the player's max HP; each of its attacks deals its `damage`
## per cent of that hit. Its copies of the player's shots fly shot_speed_min_mps..shot_speed_max_mps, are
## shot_radius_min_m..shot_radius_max_m, reach at most shot_range_m, shots_max a volley; its arcs reach at most
## reach_max_m; its blasts are blast_min_m..blast_max_m (every one a row of F10's Bosses page).
@export var mimic := false
@export var echo_seconds := 0.5
@export var dash_reaction_seconds := 0.25
@export var stance_seconds := 1.5
@export var stance_weights := PackedInt32Array([3, 2, 2, 2])
@export var back_off_m := 6.0
@export var card_casts := 3
@export var hp_from_build := false
@export var build_hp_permille := 2500
@export var build_damage_permille := 1500
@export var build_damage_min := 8
@export var build_damage_cap_permille := 200
@export var shot_speed_min_mps := 7.0
@export var shot_speed_max_mps := 13.0
@export var shot_radius_min_m := 0.15
@export var shot_radius_max_m := 0.5
@export var shot_range_m := 14.0
@export var shots_max := 12
@export var reach_max_m := 4.5
@export var blast_min_m := 1.0
@export var blast_max_m := 3.0
## v0.8.0 N2 (owner O41 "each phase takes 1-2 minutes 1 minute being the most op and longer if you are not op,
## oneshoting (killing a phase in seconds should never happen)"; FINAL_BOSS.md "N2"; FinalPace): a paced body. Its HP
## is set from the measured damage per second (the last dps_measure_seconds, at least dps_min_measured_seconds of
## them; as it rises, or as soon as the meter holds them) so that at that rate it lasts
##   pace_ref_seconds × sqrt(pace_ref_dps / dps), within pace_min_seconds .. pace_max_seconds
## (× the window share for a body with Cross windows), clamped to dps_hp_min..dps_hp_max; and it never takes more than
## its max HP / pace_min_seconds a second (a bucket holding at most pace_burst_seconds of it), so no build kills it in
## under pace_min_seconds.
@export var pace := false
@export var pace_ref_dps := 30
@export var pace_ref_seconds := 120.0
@export var pace_min_seconds := 60.0
@export var pace_max_seconds := 180.0
@export var pace_burst_seconds := 10.0
## v0.8.0 N2 (owner O42 "it should mimic and nerf you into what he has so the match is even", O52 "should only be at
## certain times not the whole fight, so on and off"): a mimic body copies the build only in windows of
## mimic_window_seconds, one every mimic_every_seconds, the first mimic_first_seconds after its rise, each shown
## mimic_warn_seconds ahead; in a window the player's damage on it is pulled to pace_ref_dps (at least
## mimic_nerf_min_permille of it) and their move speed to the base. Outside, it fights with its own kit.
## 0 mimic_window_seconds: it copies the whole fight (FB3).
@export var mimic_window_seconds := 0.0
@export var mimic_every_seconds := 20.0
@export var mimic_first_seconds := 12.0
@export var mimic_warn_seconds := 1.5
@export var mimic_nerf_min_permille := 100
## v0.9.5 BH6 (owner, 2026-10-25; BOSSES_HARD.md HC4-HC6): The Fallen's two interphases and its dashes between moves.
## An empty dictionary: none. Otherwise the keys of INTERPHASE_SPEC (a key left out takes its default); times in
## seconds, lengths in metres, speeds in m/s, turns in degrees a second, *_permille in per mille of max HP. See
## BossInterphase and InterphaseTable. The hits and telegraphs are the damage and telegraph of the five `interphase`
## attacks of the table (fallen_rays, fallen_rain, fallen_dark, fallen_erupt, fallen_return): 15 damage each, every
## telegraph at least 0.8 s (HardRules; the dash's 0.4 s apart); the pattern sets always leave a gap of at least 1.6 m.
@export var interphase := {}


func category() -> StringName:
	return &"final_bosses"


## The interphase dictionary's value for `key` (its default when the dictionary leaves it out).
func interphase_value(key: String) -> float:
	return float(interphase.get(key, (INTERPHASE_SPEC[key] as Array)[0]))


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var p := resource_path
	_check_pace(issues)
	if hp_from_dps:
		if dps_measure_seconds < 1 or dps_measure_seconds > BossSchemas.DPS_MAX_SECONDS:
			issues.append(
				ValidationIssue.new(
					&"range", p, "dps_measure_seconds: 1..%d" % BossSchemas.DPS_MAX_SECONDS
				)
			)
		if dps_min_measured_seconds < 1 or dps_min_measured_seconds > dps_measure_seconds:
			issues.append(
				ValidationIssue.new(&"range", p, "dps_min_measured_seconds: 1..dps_measure_seconds")
			)
		if dps_target_seconds <= 0.0:
			issues.append(ValidationIssue.new(&"not_positive", p, "dps_target_seconds must be > 0"))
		if dps_hp_min < 1 or dps_hp_max < dps_hp_min:
			issues.append(ValidationIssue.new(&"range", p, "needs 1 <= dps_hp_min <= dps_hp_max"))
		if not attacks.any(
			func(a: BossAttackDefinition) -> bool: return a != null and a.move == &"cross"
		):
			issues.append(
				ValidationIssue.new(&"missing", p, "hp_from_dps needs a cross (its windows)")
			)
	if shard_count < 0 or shard_count > 12:
		issues.append(ValidationIssue.new(&"range", p, "shard_count: 0..12"))
	if shard_count > 0 and (shard_orbit_m <= radius_m or shard_turn_dps < 0.0):
		issues.append(
			ValidationIssue.new(
				&"range", p, "shards orbit outside the body (shard_orbit_m > radius_m)"
			)
		)
	_check_crosses(issues)
	_check_mimic(issues)
	_check_interphase(issues)
	if spell_rotation:  # v0.8.0 PR (O84)
		for ph in phases:
			if ph == null:
				continue
			var seen := {}
			for id in ph.attack_ids:
				if seen.has(id):
					issues.append(
						ValidationIssue.new(&"range", p, "spell_rotation: %s listed twice" % id)
					)
				seen[id] = true
	return issues


## v0.9.5 BH6: the interphase's keys are known and within their bounds, its two thresholds fall in order, the dash's
## range holds (min <= max) and the rain's two gaps leave balls in its ring.
func _check_interphase(issues: Array[ValidationIssue]) -> void:
	if interphase.is_empty():
		return
	var p := resource_path
	if not mimic:
		issues.append(ValidationIssue.new(&"missing", p, "interphase needs mimic"))
	for k: Variant in interphase:
		if not INTERPHASE_SPEC.has(k):
			issues.append(
				ValidationIssue.new(&"unknown_field", p, "interphase: unknown key %s" % k)
			)
			continue
		var spec: Array = INTERPHASE_SPEC[k]
		var v := float(interphase[k])
		if v < float(spec[1]) or v > float(spec[2]):
			issues.append(
				ValidationIssue.new(&"range", p, "interphase.%s: %s..%s" % [k, spec[1], spec[2]])
			)
	if interphase_value("second_permille") >= interphase_value("first_permille"):
		issues.append(
			ValidationIssue.new(&"range", p, "interphase: second_permille < first_permille")
		)
	if interphase_value("dash_min_m") > interphase_value("dash_max_m"):
		issues.append(ValidationIssue.new(&"range", p, "interphase: dash_min_m <= dash_max_m"))
	if interphase_value("rain_gap_slots") * 2.0 >= interphase_value("rain_balls") * 0.5:
		issues.append(ValidationIssue.new(&"range", p, "interphase: the rain's gaps leave balls"))


## v0.8.0 FB3: a mimic body's numbers: an echo the fight's ring holds (2 s), a dash answered after a reaction (at least
## 0.1 s), four stance weights (one at least > 0), up to MAX_CARD_CASTS cards, an HP rule with its meter, a hit that
## can never take the player's whole HP (cap under 1000 per mille), and ranges with min <= max.
func _check_mimic(issues: Array[ValidationIssue]) -> void:
	var p := resource_path
	if hp_from_build and not mimic:
		issues.append(ValidationIssue.new(&"missing", p, "hp_from_build needs mimic"))
	if not mimic:
		return
	if echo_seconds < 0.0 or int(round(echo_seconds * 60.0)) > 120:
		issues.append(ValidationIssue.new(&"range", p, "echo_seconds: 0..2"))
	if dash_reaction_seconds < 0.1:
		issues.append(ValidationIssue.new(&"range", p, "dash_reaction_seconds >= 0.1"))
	if stance_seconds <= 0.0 or back_off_m <= 0.0:
		issues.append(ValidationIssue.new(&"not_positive", p, "stance_seconds, back_off_m > 0"))
	var negative := false
	var total := 0
	for v in stance_weights:
		negative = negative or v < 0
		total += maxi(0, v)
	if stance_weights.size() != 4 or negative or total <= 0:
		issues.append(ValidationIssue.new(&"range", p, "stance_weights: 4 weights >= 0, one > 0"))
	if card_casts < 0 or card_casts > BossSchemas.MAX_CARD_CASTS:
		issues.append(
			ValidationIssue.new(&"range", p, "card_casts: 0..%d" % BossSchemas.MAX_CARD_CASTS)
		)
	if hp_from_build:
		if dps_measure_seconds < 1 or dps_measure_seconds > BossSchemas.DPS_MAX_SECONDS:
			issues.append(ValidationIssue.new(&"range", p, "dps_measure_seconds: 1..60"))
		if dps_min_measured_seconds < 1 or dps_min_measured_seconds > dps_measure_seconds:
			issues.append(
				ValidationIssue.new(&"range", p, "dps_min_measured_seconds: 1..dps_measure_seconds")
			)
		if dps_target_seconds < 0.0 or build_hp_permille < 0:
			issues.append(ValidationIssue.new(&"range", p, "dps_target_seconds, build_hp >= 0"))
		if dps_hp_min < 1 or dps_hp_max < dps_hp_min:
			issues.append(ValidationIssue.new(&"range", p, "needs 1 <= dps_hp_min <= dps_hp_max"))
	if build_damage_permille < 1 or build_damage_min < 1:
		issues.append(ValidationIssue.new(&"not_positive", p, "build_damage_permille, _min >= 1"))
	if build_damage_cap_permille < 1 or build_damage_cap_permille >= 1000:
		issues.append(
			ValidationIssue.new(&"range", p, "build_damage_cap_permille: 1..999 (never a one-shot)")
		)
	for r in [
		["shot_speed", shot_speed_min_mps, shot_speed_max_mps],
		["shot_radius", shot_radius_min_m, shot_radius_max_m],
		["blast", blast_min_m, blast_max_m],
	]:
		if float(r[1]) <= 0.0 or float(r[2]) < float(r[1]):
			issues.append(ValidationIssue.new(&"range", p, "%s: 0 < min <= max" % r[0]))
	if shot_range_m <= 0.0 or reach_max_m <= 0.0 or shots_max < 1 or shots_max > 24:
		issues.append(
			ValidationIssue.new(&"range", p, "shot_range_m, reach_max_m > 0; shots 1..24")
		)


## v0.8.0 N2: a paced body's numbers (its meter, its times in order, a reference DPS) and a window that fits its cycle.
func _check_pace(issues: Array[ValidationIssue]) -> void:
	var p := resource_path
	if pace:
		if dps_measure_seconds < 1 or dps_measure_seconds > BossSchemas.DPS_MAX_SECONDS:
			issues.append(ValidationIssue.new(&"range", p, "dps_measure_seconds: 1..60"))
		if dps_min_measured_seconds < 1 or dps_min_measured_seconds > dps_measure_seconds:
			issues.append(
				ValidationIssue.new(&"range", p, "dps_min_measured_seconds: 1..dps_measure_seconds")
			)
		if pace_ref_dps < 1:
			issues.append(ValidationIssue.new(&"not_positive", p, "pace_ref_dps >= 1"))
		if (
			pace_min_seconds < 30.0
			or pace_ref_seconds < pace_min_seconds
			or pace_max_seconds < pace_ref_seconds
		):
			issues.append(ValidationIssue.new(&"range", p, "pace: 30 <= min <= ref <= max seconds"))
		if pace_burst_seconds < 0.0 or pace_burst_seconds > pace_min_seconds:
			issues.append(ValidationIssue.new(&"range", p, "pace_burst_seconds: 0..min"))
		if dps_hp_min < 1 or dps_hp_max < dps_hp_min:
			issues.append(ValidationIssue.new(&"range", p, "needs 1 <= dps_hp_min <= dps_hp_max"))
	if mimic_window_seconds < 0.0:
		issues.append(ValidationIssue.new(&"range", p, "mimic_window_seconds >= 0"))
	if mimic_window_seconds > 0.0:
		if not mimic:
			issues.append(ValidationIssue.new(&"missing", p, "mimic windows need mimic"))
		if mimic_every_seconds < mimic_window_seconds + mimic_warn_seconds + 1.0:
			issues.append(
				ValidationIssue.new(&"range", p, "mimic_every_seconds: over window + warning + 1 s")
			)
		if mimic_warn_seconds < 0.5 or mimic_first_seconds < mimic_warn_seconds:
			issues.append(
				ValidationIssue.new(&"range", p, "mimic_warn_seconds >= 0.5, first >= warning")
			)
		if mimic_nerf_min_permille < 1 or mimic_nerf_min_permille > 1000:
			issues.append(ValidationIssue.new(&"range", p, "mimic_nerf_min_permille: 1..1000"))


## A Cross's shards and bolt: shards to fire from, and its bolt attack a `bolt_fan` of this boss with a lock (the aim
## line) that ends before the next bolt aims.
func _check_crosses(issues: Array[ValidationIssue]) -> void:
	var p := resource_path
	for a in attacks:
		if a == null or a.move != &"cross":
			continue
		var sp := a.shape_params
		if (sp.has("pattern_id") or sp.has("bolt_attack")) and shard_count < 1:
			issues.append(
				ValidationIssue.new(
					&"missing", p, "attack %s fires from shards: shard_count >= 1" % a.id
				)
			)
		if not sp.has("bolt_attack"):
			continue
		var bolt := attack(StringName(sp["bolt_attack"]))
		if bolt == null or bolt.move != &"bolt_fan" or bolt.lock_seconds <= 0.0:
			issues.append(
				ValidationIssue.new(
					&"unknown_attack",
					p,
					"attack %s: bolt_attack must be a bolt_fan with lock_seconds" % a.id
				)
			)
			continue
		var every := int(round(float(sp.get("bolt_every_seconds", 0.0)) * 60.0))
		if every <= int(round(bolt.lock_seconds * 60.0)):
			issues.append(
				ValidationIssue.new(
					&"duration",
					p,
					"attack %s: bolt_every_seconds must be over the bolt's lock" % a.id
				)
			)
