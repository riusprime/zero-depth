class_name ShadeRules
extends RefCounted
## v0.9.0 NB4 (BOSSES_4_5.md N4; BossShade): the Lantern Shade's content rules (its own file: the boss definitions
## stay small). A Lights Out is a `pattern` with dark_seconds (O4: unshielded): its room's light (light_m round the
## player, lamps lanterns lamp_m wide burning lamp_seconds, relit within relight_m, inset_m in from each wall's middle).
## A `marks` attack may carry snuff (1: each struck circle puts out the lit lantern nearest it). NB4b (owner, PLAN
## "Owner decisions" NB4: "Dark comes and goes"): dark_lasts_seconds is how long each dark lasts, shorter than the
## boss's signature cadence (the light comes back before the next Lights Out).
## v0.11.0 O4 (owner Q10 a: "40 % damage in the dark, 150 % inside a lit pool; a lantern stays lit 6 s; dark 9 s /
## light 4 s"): light_lasts_seconds is how long each light lasts before the dark falls again; dark_mult_permille
## (1..999: never immune) the Shade's damage taken in the dark, lit_mult_permille (>= 1000) in a lit lantern's pool.

## Lights Out's params on a `pattern` (all of them, when dark_seconds is given).
const LIGHT_PARAMS: Array[String] = [
	"dark_seconds",
	"dark_lasts_seconds",
	"light_lasts_seconds",
	"dark_mult_permille",
	"lit_mult_permille",
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


## BossAttackDefinition.validate_into: a Lights Out is unshielded (O4), darkens after a real time, names a real light
## and a real cut (never immune); a
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
	if a.shielded:  # v0.11.0 O4 (owner Q10 a: "No more immunity"): no shield, even through its telegraph
		issues.append(ValidationIssue.new(&"range", path, where + "Lights Out is never shielded"))
	if int(round(float(sp.get("dark_seconds", 0.0)) * 60.0)) < 1:
		issues.append(
			ValidationIssue.new(&"not_positive", path, where + "dark_seconds must be > 0")
		)
	var n := int(sp.get("lamps", 0))
	if n < 1 or n > MAX_LAMPS:
		issues.append(ValidationIssue.new(&"range", path, where + "lamps is 1..8"))
	for k: String in [
		"dark_lasts_seconds",
		"light_lasts_seconds",
		"light_m",
		"lamp_m",
		"lamp_seconds",
		"relight_m"
	]:
		if float(sp.get(k, 0.0)) <= 0.0:
			issues.append(ValidationIssue.new(&"not_positive", path, where + k + " must be > 0"))
	if float(sp.get("inset_m", -1.0)) < 0.0:
		issues.append(ValidationIssue.new(&"range", path, where + "inset_m must be >= 0"))
	var dim := int(sp.get("dark_mult_permille", 1000))
	if dim < 1 or dim > 999:
		issues.append(
			ValidationIssue.new(
				&"range", path, where + "dark_mult_permille is 1..999 (less, never immune)"
			)
		)
	var lit := int(sp.get("lit_mult_permille", 1000))
	if lit < 1000 or lit > 4000:
		issues.append(
			ValidationIssue.new(&"range", path, where + "lit_mult_permille is 1000..4000")
		)


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
