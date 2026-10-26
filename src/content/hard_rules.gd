class_name HardRules
extends RefCounted
## v0.9.5 BH2 (BOSSES_HARD.md B1-B5; BossHard): the content rules of the five harder spells (their own file: the
## definitions stay small). Every telegraph of these spells is at least HARD_MIN_TELEGRAPH_TICKS (0.55 s, the owner's
## rule for them), a turn is a real speed, a lead is real, and a grid with safe cells leaves nowhere to hide but them.

## The owner's rule for the hard spells: every telegraph at least 0.55 s (33 ticks).
const HARD_MIN_TELEGRAPH_TICKS := 33
## The params, by the move that takes them.
const PARAMS := {
	&"row_lanes": ["second_seconds", "second_offset_m"],
	&"pattern": ["lead_seconds", "hard"],
	&"crossfire": ["lines_follow_seconds", "lines_turn_dps"],
	&"leap": ["last_lead_seconds", "last_radius_bonus_permille"],
	&"lanes": ["turn_dps"],
	&"grid": ["safe_cells"],
}
## The widest board with safe cells (its inner cells are ordered by one draw: 3 x 3 at most).
const MAX_SAFE_GRID := 5
## The points a boss keeps (BossStore.MAX_PTS; a test pins the match): crosses and their seconds fit in them.
const MAX_POINTS := 8
## v0.9.5 BH3 (B8): the Crossfire's lines turn at most this fast (degrees a second).
const MAX_TRACK_DPS := 90.0
## v0.9.5 BH3 (B9): the narrowest path the counter-rotating spirals must leave (metres; a test measures it).
const MIN_SPIRAL_PATH_M := 1.6
## The hero's radius the grid's pockets are measured against (the base hero: PlayerDefinition.radius_m).
const HERO_RADIUS_M := 0.35


## BossAttackDefinition.validate_into: the hard params sit on the moves that read them, with real values.
static func validate(
	a: BossAttackDefinition, issues: Array[ValidationIssue], path: String, where: String
) -> void:
	var sp := a.shape_params
	for move: StringName in PARAMS:
		for k: String in PARAMS[move]:
			if sp.has(k) and a.move != move:
				var msg := "%s belongs to %s" % [k, move]
				issues.append(ValidationIssue.new(&"param_unknown", path, where + msg))
	_validate_second(sp, issues, path, where)
	_validate_leads(sp, issues, path, where)
	if sp.has("turn_dps"):
		var dps := float(sp["turn_dps"])
		if dps <= 0.0 or dps > 90.0:
			issues.append(ValidationIssue.new(&"range", path, where + "turn_dps: 0..90"))
		if int(round(a.active_seconds * 60.0)) < HARD_MIN_TELEGRAPH_TICKS:
			issues.append(
				ValidationIssue.new(&"duration", path, where + "a turning beam burns >= 0.55 s")
			)
	if sp.has("safe_cells"):
		_validate_grid(a, issues, path, where)
	if sp.has("lines_follow_seconds") or sp.has("lines_turn_dps"):
		_validate_follow(a, issues, path, where)
	if not _is_hard(a):
		return
	if int(round(a.telegraph_seconds * 60.0)) < HARD_MIN_TELEGRAPH_TICKS:
		issues.append(ValidationIssue.new(&"telegraph_short", path, where + "telegraph >= 0.55 s"))
	var lock := int(round(a.lock_seconds * 60.0))
	if a.lock_seconds > 0.0 and lock < HARD_MIN_TELEGRAPH_TICKS:
		issues.append(ValidationIssue.new(&"telegraph_short", path, where + "lock >= 0.55 s"))


static func _validate_second(
	sp: Dictionary, issues: Array[ValidationIssue], path: String, where: String
) -> void:
	if not (sp.has("second_seconds") or sp.has("second_offset_m")):
		return
	if not (sp.has("second_seconds") and sp.has("second_offset_m")):
		issues.append(
			ValidationIssue.new(&"missing", path, where + "second_seconds and second_offset_m")
		)
		return
	if int(round(float(sp["second_seconds"]) * 60.0)) < 1 or float(sp["second_offset_m"]) <= 0.0:
		issues.append(
			ValidationIssue.new(
				&"not_positive", path, where + "a second cross needs a lag and a shift"
			)
		)
	if int(sp.get("count", 1)) * 2 > MAX_POINTS:
		issues.append(
			ValidationIssue.new(&"too_many", path, where + "crosses and seconds fit in 8 points")
		)


static func _validate_leads(
	sp: Dictionary, issues: Array[ValidationIssue], path: String, where: String
) -> void:
	for k: String in ["lead_seconds", "last_lead_seconds"]:
		if sp.has(k) and (float(sp[k]) <= 0.0 or float(sp[k]) > 1.0):
			issues.append(
				ValidationIssue.new(&"range", path, where + "%s: over 0, at most 1 s" % k)
			)
	if sp.has("last_radius_bonus_permille"):
		var bonus := int(sp["last_radius_bonus_permille"])
		if bonus < 1 or bonus > 1000:
			issues.append(
				ValidationIssue.new(&"range", path, where + "last_radius_bonus_permille: 1..1000")
			)
	if (
		(sp.has("last_lead_seconds") or sp.has("last_radius_bonus_permille"))
		and int(sp.get("chain", 1)) < 2
	):
		issues.append(
			ValidationIssue.new(&"range", path, where + "a last leap needs a chain of 2 or more")
		)


## A grid with safe cells: a board of 3 or 5, fewer safe cells than inner cells, circles wide enough that no pocket
## between four cells fits the hero (only the safe cells are safe), the gap between volleys over the lock, and a lock
## (the later volleys' showing, the swap's warning) of at least 0.55 s.
static func _validate_grid(
	a: BossAttackDefinition, issues: Array[ValidationIssue], path: String, where: String
) -> void:
	var sp := a.shape_params
	var count := int(sp.get("count", 1))
	if count < 3 or count > MAX_SAFE_GRID or count % 2 == 0:
		issues.append(
			ValidationIssue.new(&"range", path, where + "safe_cells needs a board of 3 or 5")
		)
		return
	var inner := (count - 2) * (count - 2)
	var n := int(sp["safe_cells"])
	if n < 1 or n >= inner:
		issues.append(
			ValidationIssue.new(&"range", path, where + "safe_cells: 1..%d" % (inner - 1))
		)
	var pocket := float(sp.get("cell_m", 0.0)) * 0.7071 - float(sp.get("radius_m", 0.0))
	if pocket >= HERO_RADIUS_M:
		issues.append(
			ValidationIssue.new(
				&"no_gap", path, where + "the circles leave a pocket the hero fits in"
			)
		)
	if int(sp.get("volleys", 1)) < 2:
		issues.append(ValidationIssue.new(&"range", path, where + "safe cells swap: volleys >= 2"))
	var gap := int(round(float(sp.get("stagger_seconds", 0.0)) * 60.0))
	if gap <= int(round(a.lock_seconds * 60.0)):
		issues.append(
			ValidationIssue.new(&"duration", path, where + "stagger_seconds must be over the lock")
		)


static func _is_hard(a: BossAttackDefinition) -> bool:
	for k: String in [
		"second_seconds",
		"lead_seconds",
		"last_lead_seconds",
		"turn_dps",
		"safe_cells",
		"lines_follow_seconds",
		"hard"
	]:
		if a.shape_params.has(k):
			return true
	return false


# --- v0.9.5 BH3 (BOSSES_HARD.md B6, B8, B9): the walls, the crossfire's tracking, the counter spiral ------------------


## BulletPatternDefinition.validate, a WALL: the crossing wall may leave later, but within the wave gap, and only when
## there is a crossing wall.
static func validate_walls(d: BulletPatternDefinition, issues: Array[ValidationIssue]) -> void:
	if d.cross_delay_seconds == 0.0:
		return
	var p := d.resource_path
	if not d.crossing:
		issues.append(ValidationIssue.new(&"range", p, "cross_delay_seconds needs crossing"))
	var delay := int(round(d.cross_delay_seconds * 60.0))
	if delay < 1 or delay >= int(round(d.wave_gap_seconds * 60.0)):
		issues.append(
			ValidationIssue.new(&"duration", p, "cross_delay_seconds: a tick up to the wave gap")
		)


## BulletPatternDefinition.validate, a SPIRAL: a counter spiral has 1..6 arms (12 in all) and turns the other way.
static func validate_spiral(d: BulletPatternDefinition, issues: Array[ValidationIssue]) -> void:
	var p := d.resource_path
	if d.counter_arms == 0 and d.counter_spin_dps == 0.0:
		return
	if d.counter_arms < 1 or d.counter_arms > 6 or d.arms + d.counter_arms > 12:
		issues.append(ValidationIssue.new(&"range", p, "counter_arms: 1..6 (12 arms in all)"))
	if d.counter_spin_dps * d.spin_dps >= 0.0:
		issues.append(
			ValidationIssue.new(&"range", p, "counter_spin_dps turns the other way from spin_dps")
		)


## A Crossfire that tracks (B8): both params, a real turn speed, and a telegraph that shows the lines the whole time
## they follow the hero (at least lines_follow_seconds, and at least 0.55 s).
static func _validate_follow(
	a: BossAttackDefinition, issues: Array[ValidationIssue], path: String, where: String
) -> void:
	var sp := a.shape_params
	if not (sp.has("lines_follow_seconds") and sp.has("lines_turn_dps")):
		issues.append(
			ValidationIssue.new(&"missing", path, where + "lines_follow_seconds and lines_turn_dps")
		)
		return
	var dps := float(sp["lines_turn_dps"])
	if dps <= 0.0 or dps > MAX_TRACK_DPS:
		issues.append(ValidationIssue.new(&"range", path, where + "lines_turn_dps: 0..90"))
	var follow := int(round(float(sp["lines_follow_seconds"]) * 60.0))
	if follow < HARD_MIN_TELEGRAPH_TICKS:
		issues.append(ValidationIssue.new(&"telegraph_short", path, where + "follow >= 0.55 s"))
	if int(round(a.telegraph_seconds * 60.0)) < follow:
		issues.append(
			ValidationIssue.new(&"duration", path, where + "the lines show the whole tracking")
		)
