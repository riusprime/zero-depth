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

@export var hp_from_dps := false
@export var dps_measure_seconds := 20
@export var dps_min_measured_seconds := 5
@export var dps_target_seconds := 60.0
@export var dps_hp_min := 600
@export var dps_hp_max := 250000
@export var shard_count := 0
@export var shard_orbit_m := 0.0
@export var shard_turn_dps := 0.0


func category() -> StringName:
	return &"final_bosses"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var p := resource_path
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
	return issues


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
