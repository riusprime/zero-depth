class_name ShadeRules
extends RefCounted
## v0.9.0 NB4 (BOSSES_4_5.md N4; BossShade): the Lantern Shade's content rules (its own file: the boss definitions
## stay small). A Lights Out is a shielded `pattern` with dark_seconds: its room's light (light_m round the player,
## lamps lanterns lamp_m wide burning lamp_seconds, relit within relight_m, inset_m in from each wall's middle). A
## `marks` attack may carry snuff (1: each struck circle puts out the lit lantern nearest it). NB4b (owner, PLAN "Owner
## decisions" NB4: "Dark comes and goes"): dark_lasts_seconds is how long each dark lasts, shorter than the boss's
## signature cadence (the light comes back before the next Lights Out).

## Lights Out's params on a `pattern` (all of them, when dark_seconds is given).
const LIGHT_PARAMS: Array[String] = [
	"dark_seconds",
	"dark_lasts_seconds",
	"light_m",
	"lamps",
	"lamp_m",
	"lamp_seconds",
	"relight_m",
	"inset_m"
]
## The most lanterns a room takes.
const MAX_LAMPS := 8


static func is_lights_out(a: BossAttackDefinition) -> bool:
	return a != null and a.move == &"pattern" and a.shape_params.has("dark_seconds")


## BossAttackDefinition.validate_into: a Lights Out is shielded, darkens after a real time and names a real light; a
## Snuff's flag is 0 or 1 on a `marks` attack.
static func validate(
	a: BossAttackDefinition, issues: Array[ValidationIssue], path: String, where: String
) -> void:
	var sp := a.shape_params
	if sp.has("snuff") and (a.move != &"marks" or not int(sp["snuff"]) in [0, 1, 2]):
		issues.append(
			ValidationIssue.new(
				&"range", path, where + "snuff is 0, 1 or 2 (lanterns put out) on a marks attack"
			)
		)
	if not is_lights_out(a):
		return
	for k in LIGHT_PARAMS:
		if not sp.has(k):
			issues.append(ValidationIssue.new(&"missing", path, where + "Lights Out needs " + k))
	if not a.shielded:
		issues.append(ValidationIssue.new(&"missing", path, where + "Lights Out is shielded"))
	if int(round(float(sp.get("dark_seconds", 0.0)) * 60.0)) < 1:
		issues.append(
			ValidationIssue.new(&"not_positive", path, where + "dark_seconds must be > 0")
		)
	var n := int(sp.get("lamps", 0))
	if n < 1 or n > MAX_LAMPS:
		issues.append(ValidationIssue.new(&"range", path, where + "lamps is 1..8"))
	for k: String in ["dark_lasts_seconds", "light_m", "lamp_m", "lamp_seconds", "relight_m"]:
		if float(sp.get(k, 0.0)) <= 0.0:
			issues.append(ValidationIssue.new(&"not_positive", path, where + k + " must be > 0"))
	if float(sp.get("inset_m", -1.0)) < 0.0:
		issues.append(ValidationIssue.new(&"range", path, where + "inset_m must be >= 0"))


## BossDefinition._check_cadence, NB4b: a Lights Out's dark lifts before the next one starts (dark_lasts_seconds
## less than the boss's signature_every_seconds).
static func check_cadence(
	a: BossAttackDefinition, every_seconds: float, issues: Array[ValidationIssue], path: String
) -> void:
	if not is_lights_out(a):
		return
	if float(a.shape_params.get("dark_lasts_seconds", 0.0)) >= every_seconds:
		issues.append(
			ValidationIssue.new(
				&"duration", path, "dark_lasts_seconds must be less than signature_every_seconds"
			)
		)
