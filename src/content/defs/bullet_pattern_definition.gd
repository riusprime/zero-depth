class_name BulletPatternDefinition
extends ContentDef
## v0.7.5 BF1 (owner N15; docs/design/BOSS_FIGHTS.md): a bullet pattern, the shape a boss (or, from EF, an enemy)
## fires its slow fireballs in. A boss attack with move `pattern` names one by id (shape_params "pattern_id");
## ContentCompiler resolves it into a BulletPatternTable and the sim's BulletPatterns fires it (CONTENT_SCHEMA §4b,
## SIM_CONTRACTS §10d). Every number is a starting value the owner tunes (F10).
## Kinds and the fields each reads (the rest are ignored):
## - RING: `count` shots evenly round, minus `gap_count` gaps of `gap_width` shots each (evenly spaced).
## - SPIRAL: `arms` streams turning at `spin_dps`, one shot an arm every wave; the turn reverses at
##   `reverse_at_seconds` (0 = never). v0.9.5 BH3 (B9): with `counter_arms` > 0 a second spiral of that many arms
##   turns the other way at `counter_spin_dps` (the Judge's Gear Spiral); HardRules checks the pair leaves a path.
## - FAN: `count` shots over `spread_degrees` toward the aim.
## - CROSS: `arms` streams (4 = a plus) turning at `spin_dps`, one shot an arm every wave.
## - WALL: a line of shots `spacing_m` apart, `wall_length_m` long, across the aim, marching along it, with a gap of
##   `gap_m` placed `gap_offset_m` off the aim line (moving `gap_shift_m` a wave, bouncing at the ends); `crossing`
##   adds a second wall at right angles; v0.9.5 BH3 (B6): with `cross_delay_seconds` > 0 its wave leaves that long
##   after the first wall's (the Foundry's Furnace Waves).
## - FLOWER: `count` shots round whose speed follows a rose of `petals` petals (|cos(petals × angle / 2)|, a table
##   lookup), from `petal_min_permille` of the speed in a valley to the full speed on a petal; shots under
##   `petal_cut_permille` are left out, which opens the gaps between the petals. v0.7.5 BF3: with `rain_seconds`
##   > 0 the flower rains: each wave's drops are thrown up from the body and land `rain_seconds` later, `rain_m`
##   (× the petal's factor) out from its edge, in the flower's shape round it, then roll on outward as the shots
##   (in the air they draw and don't hurt; a drop landing on the player or in a wall is left out).
## - BURST: a lobbed shell lands after `lob_seconds` on the attack's locked target (a marker of `land_radius_m`
##   that hurts as it lands) and bursts into a star of `count` shots.
## Every kind: `waves` waves `wave_gap_seconds` apart; each wave turns by `turn_per_wave_degrees` (with `alternate`,
## every other wave only), from the aim plus `aim_offset_degrees`. Shots fly at `speed_mps`, `radius_m` wide, for
## `range_m`, and stop at walls. Fair (BOSS_FIGHTS.md "Rules" 5): no shot spawns within `safe_radius_m` of the
## player or inside a wall, and every kind has a gap the validation checks. `look` is the fireball's look key (the
## presentation's FireballLooks; each boss and enemy its own).

enum Kind { RING, SPIRAL, FAN, CROSS, WALL, FLOWER, BURST }

## Shots one wave may hold (a ring's count, a wall's shots); BulletPatterns caps a tick's shots too.
const MAX_SHOTS_PER_WAVE := 64
## "Small, many, slow (about 3–5 m/s against the hero's run)": the band the validation allows.
const MIN_SPEED_MPS := 1.5
const MAX_SPEED_MPS := 7.0
## A gap must let the hero through: at least this wide (metres) where the shots are `GAP_CHECK_M` out.
const MIN_GAP_M := 1.0
const GAP_CHECK_M := 4.0

@export var kind := Kind.RING
@export var look: StringName
@export var speed_mps := 4.0
@export var radius_m := 0.18
@export var range_m := 18.0
@export var waves := 1
@export var wave_gap_seconds := 0.5
@export var turn_per_wave_degrees := 0.0
@export var alternate := false
@export var aim_offset_degrees := 0.0
@export var safe_radius_m := 1.4
## RING, FAN, FLOWER, BURST: shots a wave.
@export var count := 12
## RING: gaps, and the shots each one leaves out.
@export var gap_count := 1
@export var gap_width := 3
## FAN: the whole spread.
@export var spread_degrees := 60.0
## SPIRAL, CROSS: streams and their turn (degrees per second; negative turns clockwise).
@export var arms := 2
@export var spin_dps := 90.0
## SPIRAL: the turn reverses this long after the first wave (0 = never).
@export var reverse_at_seconds := 0.0
## v0.9.5 BH3 (B9): a second spiral turning the other way (0 arms = none).
@export var counter_arms := 0
@export var counter_spin_dps := 0.0
## WALL.
@export var wall_length_m := 18.0
@export var spacing_m := 0.6
@export var gap_m := 2.2
@export var gap_offset_m := 0.0
@export var gap_shift_m := 1.5
@export var crossing := false
## v0.9.5 BH3 (B6): the crossing wall's wave leaves this long after the first wall's (0 = together).
@export var cross_delay_seconds := 0.0
## FLOWER.
@export var petals := 5
@export var petal_min_permille := 450
@export var petal_cut_permille := 300
## BURST.
@export var lob_seconds := 0.8
@export var land_radius_m := 1.4
## FLOWER (v0.7.5 BF3): the drops' flight before they land (0 = no rain: the shots leave the body), and how far out
## a petal's tip lands.
@export var rain_seconds := 0.0
@export var rain_m := 0.0


func category() -> StringName:
	return &"bullet_patterns"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var p := resource_path
	if String(look).is_empty():
		issues.append(ValidationIssue.new(&"missing", p, "look is required (the fireball's look)"))
	if speed_mps < MIN_SPEED_MPS or speed_mps > MAX_SPEED_MPS:
		issues.append(
			ValidationIssue.new(
				&"range",
				p,
				"speed_mps must be %.1f..%.1f (slow shots)" % [MIN_SPEED_MPS, MAX_SPEED_MPS]
			)
		)
	check_positive(issues, "radius_m", radius_m)
	check_positive(issues, "range_m", range_m)
	if safe_radius_m < 0.5:
		issues.append(ValidationIssue.new(&"range", p, "safe_radius_m must be >= 0.5"))
	if waves < 1:
		issues.append(ValidationIssue.new(&"not_positive", p, "waves must be >= 1"))
	if waves > 1 and int(round(wave_gap_seconds * 60.0)) < 1:
		issues.append(ValidationIssue.new(&"duration", p, "wave_gap_seconds is under a tick"))
	match kind:
		Kind.RING:
			_check_count(issues, count)
			if gap_count < 1 or gap_width < 1:
				issues.append(ValidationIssue.new(&"no_gap", p, "a ring needs a gap"))
			elif gap_count * gap_width >= count:
				issues.append(ValidationIssue.new(&"no_gap", p, "the gaps leave no shots"))
			elif _ring_gap_m() < MIN_GAP_M:
				issues.append(ValidationIssue.new(&"no_gap", p, "the ring's gap is too narrow"))
		Kind.FAN, Kind.BURST:
			_check_count(issues, count)
			if kind == Kind.FAN and (spread_degrees <= 0.0 or spread_degrees > 300.0):
				issues.append(ValidationIssue.new(&"no_gap", p, "a fan spreads 0..300 degrees"))
			if kind == Kind.BURST:
				if int(round(lob_seconds * 60.0)) < 1:
					issues.append(
						ValidationIssue.new(&"duration", p, "lob_seconds is under a tick")
					)
				check_positive(issues, "land_radius_m", land_radius_m)
				if count > 16:
					issues.append(ValidationIssue.new(&"no_gap", p, "a burst's star holds <= 16"))
		Kind.SPIRAL, Kind.CROSS:
			# v0.8.0 PR (O84): up to 12 (the Prism's 10-arm spiral: 36° between the arms)
			if arms < 1 or arms > 12:
				issues.append(ValidationIssue.new(&"range", p, "arms must be 1..12"))
			if reverse_at_seconds < 0.0:
				issues.append(ValidationIssue.new(&"duration", p, "reverse_at_seconds < 0"))
			HardRules.validate_spiral(self, issues)  # v0.9.5 BH3 (B9)
		Kind.WALL:
			check_positive(issues, "spacing_m", spacing_m)
			check_positive(issues, "wall_length_m", wall_length_m)
			if gap_m < MIN_GAP_M or gap_m >= wall_length_m:
				issues.append(ValidationIssue.new(&"no_gap", p, "a wall needs a gap of >= 1 m"))
			if spacing_m > 0.0 and wall_length_m / spacing_m > MAX_SHOTS_PER_WAVE:
				issues.append(ValidationIssue.new(&"too_many", p, "a wall holds too many shots"))
			HardRules.validate_walls(self, issues)  # v0.9.5 BH3 (B6)
		Kind.FLOWER:
			_check_count(issues, count)
			if petals < 2 or petals > 12:
				issues.append(ValidationIssue.new(&"range", p, "petals must be 2..12"))
			if petal_cut_permille < 100 or petal_cut_permille > 900:
				issues.append(ValidationIssue.new(&"no_gap", p, "petal_cut_permille: 100..900"))
			if petal_min_permille < 100 or petal_min_permille > 1000:
				issues.append(ValidationIssue.new(&"range", p, "petal_min_permille: 100..1000"))
			if rain_seconds < 0.0 or rain_m < 0.0:
				issues.append(ValidationIssue.new(&"range", p, "rain_seconds and rain_m >= 0"))
			elif rain_seconds > 0.0 and int(round(rain_seconds * 60.0)) < 1:
				issues.append(ValidationIssue.new(&"duration", p, "rain_seconds is under a tick"))
	return issues


## Seconds from the first wave to the last shot leaving (the lob too): what the attack's active time covers.
func duration_seconds() -> float:
	return _lob_seconds() + wave_gap_seconds * (waves - 1) + cross_delay_seconds


## The flight before the first wave's shots exist: a burst's shell, a raining flower's drops (v0.7.5 BF3).
func _lob_seconds() -> float:
	if kind == Kind.BURST:
		return lob_seconds
	return rain_seconds if kind == Kind.FLOWER else 0.0


func _check_count(issues: Array[ValidationIssue], n: int) -> void:
	if n < 1 or n > MAX_SHOTS_PER_WAVE:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "count must be 1..%d" % MAX_SHOTS_PER_WAVE)
		)


## The width of a ring's gap at GAP_CHECK_M out, between the shots' edges: the arc of (gap_width + 1) steps minus
## a shot's width. Sizes only (no trig): the arc is 2π r × steps / count.
func _ring_gap_m() -> float:
	return 2.0 * PI * GAP_CHECK_M * (gap_width + 1) / count - 2.0 * radius_m
