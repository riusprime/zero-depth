class_name SecretsDefinition
extends ContentDef
## v0.9.0 RA (owner W §4 A, Q22; CONTENT_SCHEMA): the floor's secrets' numbers, read by FloorPlan when it builds a floor
## (data/secrets/secrets.tres, category `secrets`, id `secrets`). Every number is a starting value the owner tunes.

## The share of floors (per mille) with a rune puzzle: three pillars before a sealed dead end (starting value 30 %).
@export var rune_permille := 300
## v0.9.0 DX (owner W §4 C, §5, Q23; SecretRules has the same defaults): the share of floors with a cracked wall
## before a dead end and the Skill hits it takes; containers a room at most, their drop chance, the heals' share of
## the drops and the shards' range; explosive barrels: the share of rooms with one, at most per room, the fuse (ticks),
## the blast's radius (m) and its damage to enemies and to the hero.
@export var crack_permille := 250
@export var crack_hits := 3
@export var containers_max := 2
@export var container_drop_permille := 150
@export var container_heal_permille := 500
@export var container_shards_min := 2
@export var container_shards_max := 5
@export var barrel_room_permille := 200
@export var barrels_max := 1
@export var barrel_fuse_ticks := 60
@export var barrel_radius_m := 2.0
@export var barrel_damage := 40
@export var barrel_hero_damage := 15


func category() -> StringName:
	return &"secrets"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	_check_permille(issues, "rune_permille", rune_permille)
	for f in [
		"crack_permille",
		"container_drop_permille",
		"container_heal_permille",
		"barrel_room_permille"
	]:
		_check_permille(issues, f, int(get(f)))
	for f in [
		"crack_hits", "barrel_fuse_ticks", "barrel_radius_m", "barrel_damage", "barrel_hero_damage"
	]:
		check_positive(issues, f, float(get(f)))
	if containers_max < 0 or barrels_max < 0 or container_shards_min > container_shards_max:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "counts >= 0, shards min <= max")
		)
	if barrel_fuse_ticks < 24:  # SimTick.MIN_TELEGRAPH_TICKS: the fuse is the blast's warning
		issues.append(ValidationIssue.new(&"range", resource_path, "barrel_fuse_ticks >= 24"))
	return issues


func _check_permille(issues: Array[ValidationIssue], field: String, value: int) -> void:
	if value < 0 or value > 1000:
		issues.append(ValidationIssue.new(&"range", resource_path, "%s is 0..1000" % field))
