class_name AbilityDefinition
extends ContentDef
## An ability (v0.4.0 BS, owner F8; CONTENT_SCHEMA §8): one of the build's four slots. Slot 1 holds the starting
## weapon (Combo Sword for the Blade, Pulse Gun for the Gun); ability cards fill slots 2–4 and level them up to
## MAX_LEVEL. Times in seconds, compiled to ticks once (ContentCompiler.compile_abilities). Every number is a
## starting value the owner tunes after playing.
## The per-level tables hold one entry per level (L1..L5); each kind reads only the ones it uses:
## - COMBO_SWORD: level_damage scales the swings and the Lunge Cleave; level_radius the reach; level_extra 1 = the
##   finisher's shockwave (radius_m, damage).
## - PULSE_GUN: level_damage scales the bolts and the Scatter Blast; level_extra 1 = bolts pierce one enemy;
##   level_count = bolts per shot (2 = twin bolts).
## - BOMB_LOBBER: every cooldown_seconds, level_count bombs at the densest cluster within range_m; each lands after
##   duration_seconds for `damage` in radius_m x level_radius.
## - DRONE_BUDDY: level_count drones trail the player; each fires a bolt (speed_mps) at the nearest enemy within
##   range_m every period_seconds / level_rate for `damage`; level_extra 1 = a bolt chains once (radius_m).
## - ORBIT_BLADES: level_count blades circle at radius_m x level_radius, one turn per period_seconds; `damage` per
##   touch, once per enemy every hit_seconds.
## - BLINK (utility button): the v0.3.0 blink (range_m, level_cooldown, duration_seconds of iframes) with a landing
##   shock of `damage` in radius_m x level_radius; level_extra = charges.
## - AEGIS (utility button): the guard (guard numbers from the player table); level_extra = the guard-charge cap,
##   `damage` = each charge's bonus to the next swing, in per mille.
## v0.4.0 AB: three auto abilities that feed the v0.3.0 status engines (Engines). `engine_item` names the item whose
## engine numbers (threshold, how long stacks last, the DoT or discharge, the freeze) the ability's status uses when no
## owned item brings stronger ones; level_extra = the status stacks each hit adds.
## - ARC_FIELD: every level_cooldown, lightning strikes level_count enemies within range_m (picked at random from the
##   `ability` stream) for `damage` and level_extra shock stacks.
## - FROST_NOVA: every level_cooldown, a nova of radius_m x level_radius around the player: `damage` and level_extra
##   frost stacks to every enemy in it.
## - FLAME_TRAIL: while the player moves, a fire patch (radius_m x level_radius) every period_seconds lasting
##   duration_seconds x level_rate; an enemy in fire takes `damage` x level_damage and level_extra burn stacks, once
##   every hit_seconds.

## Appended, never renumbered (AbilityTable.Kind mirrors it).
enum Kind {
	COMBO_SWORD,
	PULSE_GUN,
	BOMB_LOBBER,
	DRONE_BUDDY,
	ORBIT_BLADES,
	BLINK,
	AEGIS,
	ARC_FIELD,
	FROST_NOVA,
	FLAME_TRAIL,
}
## Manual abilities answer a button; auto abilities fire on their own.
enum Activation { MANUAL, AUTO }
## The button a manual ability answers (NONE for auto).
enum Binding { NONE, PRIMARY, UTILITY }
enum Rarity { COMMON, RARE }

const MAX_LEVEL := 5
const TAGS: Array[StringName] = [
	&"melee",
	&"bolt",
	&"area",
	&"auto",
	&"utility",
	&"weapon",
	&"summon",
	&"orbit",
	&"shock",
	&"frost",
	&"fire"
]
## v0.4.0 AB: the kinds that feed a status engine (they need engine_item).
const ENGINE_KINDS: Array[int] = [Kind.ARC_FIELD, Kind.FROST_NOVA, Kind.FLAME_TRAIL]
## The build weapon ids (BuildDefinition.WEAPON_IDS) a starting ability may name.
const WEAPONS: Array[StringName] = [&"blade", &"gun"]

@export var kind := Kind.BOMB_LOBBER
@export var activation := Activation.AUTO
@export var button := Binding.NONE
@export var rarity := Rarity.COMMON
@export var name_key: StringName
@export var desc_key: StringName
## The build weapon whose slot 1 this ability is (&"blade", &"gun"), or empty for an ability card.
@export var start_weapon: StringName = &""
@export var tags: Array[StringName] = []
@export var cooldown_seconds := 0.0
@export var damage := 0
@export var range_m := 0.0
@export var radius_m := 0.0
@export var speed_mps := 0.0
@export var period_seconds := 0.0
@export var duration_seconds := 0.0
@export var hit_seconds := 0.0
## v0.4.0 AB: the item (an id under data/items) whose engine numbers this ability's status uses; empty for none.
@export var engine_item: StringName = &""
@export_group("Levels (L1..L5)")
@export var level_damage := PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0])
@export var level_count := PackedInt32Array([1, 1, 1, 1, 1])
@export var level_radius := PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0])
@export var level_rate := PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0])
@export var level_cooldown := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
@export var level_extra := PackedInt32Array([0, 0, 0, 0, 0])


func category() -> StringName:
	return &"ability"


func is_start() -> bool:
	return not String(start_weapon).is_empty()


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if kind < Kind.COMBO_SWORD or kind > Kind.FLAME_TRAIL:
		issues.append(ValidationIssue.new(&"range", resource_path, "kind is out of range"))
	var manual := activation == Activation.MANUAL
	if manual == (button == Binding.NONE):
		issues.append(
			ValidationIssue.new(
				&"mismatch", resource_path, "a manual ability names a button; an auto one doesn't"
			)
		)
	if is_start() and not WEAPONS.has(start_weapon):
		issues.append(
			ValidationIssue.new(&"unknown", resource_path, "start_weapon is blade, gun or empty")
		)
	for t in tags:
		if not TAGS.has(t):
			issues.append(ValidationIssue.new(&"unknown_tag", resource_path, "tag %s" % t))
	for pair: Array in [
		["level_damage", level_damage.size()],
		["level_count", level_count.size()],
		["level_radius", level_radius.size()],
		["level_rate", level_rate.size()],
		["level_cooldown", level_cooldown.size()],
		["level_extra", level_extra.size()],
	]:
		if pair[1] != MAX_LEVEL:
			issues.append(
				ValidationIssue.new(
					&"levels", resource_path, "%s needs %d entries" % [pair[0], MAX_LEVEL]
				)
			)
	if issues.size() > 0:
		return issues
	for k in MAX_LEVEL:
		if level_damage[k] <= 0.0 or level_radius[k] <= 0.0 or level_rate[k] <= 0.0:
			issues.append(
				ValidationIssue.new(&"not_positive", resource_path, "level %d multiplier" % (k + 1))
			)
		if level_count[k] < 1 or level_extra[k] < 0 or level_cooldown[k] < 0.0:
			issues.append(ValidationIssue.new(&"range", resource_path, "level %d" % (k + 1)))
	for f: Array in [
		["cooldown_seconds", cooldown_seconds],
		["period_seconds", period_seconds],
		["duration_seconds", duration_seconds],
		["hit_seconds", hit_seconds],
	]:
		check_duration(issues, f[0], f[1])
	match kind:
		Kind.BOMB_LOBBER:
			check_positive(issues, "cooldown_seconds", cooldown_seconds)
			check_positive(issues, "range_m", range_m)
			check_positive(issues, "radius_m", radius_m)
			check_positive(issues, "damage", damage)
		Kind.DRONE_BUDDY:
			check_positive(issues, "period_seconds", period_seconds)
			check_positive(issues, "range_m", range_m)
			check_positive(issues, "speed_mps", speed_mps)
			check_positive(issues, "damage", damage)
		Kind.ORBIT_BLADES:
			check_positive(issues, "radius_m", radius_m)
			check_positive(issues, "period_seconds", period_seconds)
			check_positive(issues, "hit_seconds", hit_seconds)
			check_positive(issues, "damage", damage)
		Kind.BLINK:
			check_positive(issues, "range_m", range_m)
			check_positive(issues, "level_cooldown[0]", level_cooldown[0])
		Kind.ARC_FIELD:
			check_positive(issues, "range_m", range_m)
			check_positive(issues, "damage", damage)
		Kind.FROST_NOVA:
			check_positive(issues, "radius_m", radius_m)
			check_positive(issues, "damage", damage)
		Kind.FLAME_TRAIL:
			check_positive(issues, "radius_m", radius_m)
			check_positive(issues, "period_seconds", period_seconds)
			check_positive(issues, "duration_seconds", duration_seconds)
			check_positive(issues, "hit_seconds", hit_seconds)
			check_positive(issues, "damage", damage)
	if kind in ENGINE_KINDS:
		if String(engine_item).is_empty():
			issues.append(ValidationIssue.new(&"missing", resource_path, "engine_item is required"))
		if kind != Kind.FLAME_TRAIL:
			for k in MAX_LEVEL:
				check_positive(issues, "level_cooldown[%d]" % k, level_cooldown[k])
		for k in MAX_LEVEL:
			check_positive(issues, "level_extra[%d]" % k, level_extra[k])
	return issues


## v0.4.0 AB (ContentValidator, over the whole set): every engine_item names an item that exists.
static func cross_check(defs: Array[ContentDef]) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var items := {}
	for d in defs:
		if d is ItemDefinition:
			items[d.id] = true
	for d in defs:
		var a := d as AbilityDefinition
		if a != null and not String(a.engine_item).is_empty() and not items.has(a.engine_item):
			issues.append(
				ValidationIssue.new(&"unknown_item", a.resource_path, "no item %s" % a.engine_item)
			)
	return issues
