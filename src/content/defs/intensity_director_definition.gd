class_name IntensityDirectorDefinition
extends ContentDef
## The intensity director (v0.8.0 Step N5, owner O58, Left 4 Dead's AI director: "It doesn't change how hard the game
## hits. It changes when."; SIM_CONTRACTS §11, CONTENT_SCHEMA §7). The hero carries one hidden number, intensity
## (0..1000): a hit taken raises it by its share of max HP, an enemy dying close to the hero raises it, enemies close
## raise it a little every tick, and it drains only after calm_seconds with no hit taken and no enemy close. The
## ordinary floor spawning (SpawnDirector) runs BUILD_UP (today's packs) until intensity reaches peak_intensity, holds
## the PEAK for peak_seconds_min..max, then PULL_BACK (no new packs, the ones out stay) until few enemies are near or
## pull_back_max_seconds pass, then QUIET (no new packs) for its drawn quiet_seconds_min..max (v0.10.5 O4: it ends on
## time; intensity then drops to at most relax_intensity), then builds up again. The lengths are drawn from the
## `ai:intensity:<cycle>` stream. Every number is a starting value the owner tunes by play.

## "Close" to the hero: kills and enemies within this distance raise intensity.
@export var close_radius_m := 3.0
## Intensity a hit adds per whole max HP it takes (2000: a hit of 10 % of max HP adds 200).
@export var hit_full_hp_gain := 2000
## Intensity an enemy dying within close_radius_m adds.
@export var close_kill_gain := 25
## Intensity per second while at least one enemy is within close_radius_m.
@export var close_gain_per_second := 30
## Intensity drained per second once calm (no hit taken and no enemy close for calm_seconds).
@export var drain_per_second := 60
@export var calm_seconds := 2.0
## BUILD_UP turns into PEAK at this intensity.
@export var peak_intensity := 750
## The PEAK lasts a draw between these (new packs still arrive).
@export var peak_seconds_min := 3.0
@export var peak_seconds_max := 5.0
## PULL_BACK (no new packs) ends once at most pull_back_enemies enemies are within pull_back_radius_m of the hero, or
## after pull_back_max_seconds.
@export var pull_back_radius_m := 8.0
@export var pull_back_enemies := 2
@export var pull_back_max_seconds := 8.0
## QUIET (no new packs) lasts a draw between these (v0.10.5 O4: on time; intensity then drops to relax_intensity).
@export var quiet_seconds_min := 10.0
@export var quiet_seconds_max := 20.0
@export var relax_intensity := 300
## While building up, the curve's interval between packs × this per mille (the ramp: 500 = packs twice as often;
## never more at once than the curve's cap, never stronger).
@export var build_interval_permille := 1000

## v0.10.5 O4 (owner D46, "it feels overcrowded if you are weak, could we also adjust it to not make it unfair based
## on the strength?" → "Read your state live"): every tick the director reads the hero. STRUGGLING: HP under
## struggle_hp_permille of max, or (once a full ~10 s window of fighting is counted, with at least slow_min_alive
## enemies out) kills in that window under slow_kill_permille of the expected (the cap now × expected_kill_permille).
## STRONG: HP above strong_hp_permille and kills at least the expected: the full build-up, as before; between: as
## before. A struggling hero peaks at struggle_peak_intensity, its peak's clock runs struggle_peak_speed times as
## fast, a quiet that begins while it struggles lasts struggle_quiet_permille of its draw, and the largest pack is
## capped struggle_pack_cut smaller. Every one is a starting value (owner D46, 2026-11-01).
@export var struggle_hp_permille := 400  # starting value (owner D46, 2026-11-01)
@export var strong_hp_permille := 700  # starting value (owner D46, 2026-11-01)
## The expected kills in the window, per mille of the cap now (an 18 cap expects 3.6 kills in 10 s).
@export var expected_kill_permille := 200  # starting value (owner D46, 2026-11-01)
@export var slow_kill_permille := 500  # starting value (owner D46, 2026-11-01)
@export var slow_min_alive := 4  # starting value (owner D46, 2026-11-01)
@export var struggle_peak_intensity := 600  # starting value (owner D46, 2026-11-01)
@export var struggle_peak_speed := 2  # starting value (owner D46, 2026-11-01)
@export var struggle_quiet_permille := 1500  # starting value (owner D46, 2026-11-01)
@export var struggle_pack_cut := 1  # starting value (owner D46, 2026-11-01)


func category() -> StringName:
	return &"intensity"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	check_positive(issues, "close_radius_m", close_radius_m)
	check_positive(issues, "pull_back_radius_m", pull_back_radius_m)
	for pair: Array in [
		["hit_full_hp_gain", hit_full_hp_gain, 0, 100000],
		["close_kill_gain", close_kill_gain, 0, 1000],
		["close_gain_per_second", close_gain_per_second, 0, 1000],
		["drain_per_second", drain_per_second, 1, 1000],
		["peak_intensity", peak_intensity, 1, 1000],
		["relax_intensity", relax_intensity, 0, 1000],
		["pull_back_enemies", pull_back_enemies, 0, 1000],
		["build_interval_permille", build_interval_permille, 100, 1000],
		["struggle_hp_permille", struggle_hp_permille, 0, 1000],
		["strong_hp_permille", strong_hp_permille, 0, 1000],
		["expected_kill_permille", expected_kill_permille, 0, 10000],
		["slow_kill_permille", slow_kill_permille, 0, 1000],
		["slow_min_alive", slow_min_alive, 0, 1000],
		["struggle_peak_intensity", struggle_peak_intensity, 1, 1000],
		["struggle_peak_speed", struggle_peak_speed, 1, 10],
		["struggle_quiet_permille", struggle_quiet_permille, 1000, 5000],
		["struggle_pack_cut", struggle_pack_cut, 0, 10],
	]:
		if int(pair[1]) < int(pair[2]) or int(pair[1]) > int(pair[3]):
			issues.append(
				ValidationIssue.new(
					&"range", resource_path, "%s is outside %d..%d" % [pair[0], pair[2], pair[3]]
				)
			)
	if relax_intensity >= peak_intensity or struggle_peak_intensity > peak_intensity:
		(
			issues
			. append(
				(
					ValidationIssue
					. new(
						&"intensity_order",
						resource_path,
						"relax_intensity is not below peak_intensity (or struggle_peak_intensity is above it)"
					)
				)
			)
		)
	for f: String in [
		"calm_seconds",
		"peak_seconds_min",
		"peak_seconds_max",
		"pull_back_max_seconds",
		"quiet_seconds_min",
		"quiet_seconds_max",
	]:
		var s: float = get(f)
		check_positive(issues, f, s)
		check_duration(issues, f, s)
	for pair: Array in [
		["peak_seconds", peak_seconds_min, peak_seconds_max],
		["quiet_seconds", quiet_seconds_min, quiet_seconds_max],
	]:
		if float(pair[1]) > float(pair[2]):
			issues.append(
				ValidationIssue.new(
					&"duration_range", resource_path, "%s_min is above its max" % pair[0]
				)
			)
	return issues
