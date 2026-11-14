class_name PrismRules
extends RefCounted
## The content rules of the Prism's last phase (their own
## file: the definitions stay small). The Facet Lances: 1..MAX_LANCES lances (BossStore.MAX_PTS holds their points),
## each tracking a real time, locked at least the telegraph minimum (the attack's lock), striking a real time and over
## before the next one strikes, from a real rim spot as real lanes, all within the attack's active time; shielded.
## The Shattered Kneel: not shielded (it is her opening), a crack of 1..1000 per mille of her max HP, a burst of
## 0..1000, a core multiplier of at least 1000, and a down time of at least the telegraph minimum.

## The most lances (BossStore.MAX_PTS: one tracked point each).
const MAX_LANCES := 8


static func validate(
	d: BossAttackDefinition, issues: Array[ValidationIssue], path: String, where: String
) -> void:
	if d.move == &"lances":
		_lances(d, issues, path, where)
	elif d.move == &"kneel":
		_kneel(d, issues, path, where)


static func _ticks(s: float) -> int:
	return int(round(s * 60.0))


static func _lances(
	d: BossAttackDefinition, issues: Array[ValidationIssue], path: String, where: String
) -> void:
	var sp := d.shape_params
	var n := int(sp.get("count", 0))
	if n < 1 or n > MAX_LANCES:
		issues.append(
			ValidationIssue.new(&"range", path, where + "lances: count 1..%d" % MAX_LANCES)
		)
	var gap := _ticks(float(sp.get("stagger_seconds", 0.0)))
	var track := _ticks(float(sp.get("track_seconds", 0.0)))
	var strike := _ticks(float(sp.get("strike_seconds", 0.0)))
	var lock := _ticks(d.lock_seconds)
	if track < 1 or strike < 1:
		issues.append(
			ValidationIssue.new(
				&"duration", path, where + "lances: track and strike of a tick or more"
			)
		)
	if n > 1 and gap <= strike:
		issues.append(
			ValidationIssue.new(
				&"duration", path, where + "lances: stagger_seconds must be over strike_seconds"
			)
		)
	for k in ["distance_m", "length_m", "width_m"]:
		if float(sp.get(k, 0.0)) <= 0.0:
			issues.append(ValidationIssue.new(&"not_positive", path, where + "%s must be > 0" % k))
	if _ticks(d.active_seconds) < (n - 1) * gap + track + lock + strike:
		issues.append(
			ValidationIssue.new(
				&"duration", path, where + "lances: active_seconds must cover every lance"
			)
		)
	if not d.shielded:
		issues.append(ValidationIssue.new(&"missing", path, where + "the lances are shielded"))


static func _kneel(
	d: BossAttackDefinition, issues: Array[ValidationIssue], path: String, where: String
) -> void:
	var sp := d.shape_params
	if d.shielded:
		issues.append(
			ValidationIssue.new(&"range", path, where + "a kneel is her opening: not shielded")
		)
	var crack := int(sp.get("crack_permille", 0))
	var burst := int(sp.get("burst_permille", -1))
	if crack < 1 or crack > 1000 or burst < 0 or burst > 1000:
		issues.append(
			ValidationIssue.new(
				&"range", path, where + "kneel: crack 1..1000, burst 0..1000 per mille"
			)
		)
	if int(sp.get("core_mult_permille", 0)) < 1000:
		issues.append(
			ValidationIssue.new(&"range", path, where + "kneel: core_mult_permille >= 1000")
		)
	if _ticks(d.active_seconds) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
		issues.append(
			ValidationIssue.new(
				&"duration", path, where + "kneel: down for at least the telegraph minimum"
			)
		)
