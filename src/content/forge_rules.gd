class_name ForgeRules
extends RefCounted
## The content rules of a boss's forge (BossDefinition.forge: the Foundry's Forged Plate, its cooling slag, the
## Overpressure cast and the scald gauge it puts on the hero; its own file, as the dance's rules). Every key is known
## and within its bounds, so no single step of these mechanics takes more than MAX_HIT per mille of the hero's max HP;
## each cast lasts the telegraph minimum; an Overpressure ends before the next begins and a slab outlasts one (or no
## slab could ever be safe for it); the boss holds a `brood` attack (the drones that blow the plate off) and the
## attacks the death recap names.

## The most one step may take, per mille of the hero's max HP: never a kill from full HP by one mistake.
const MAX_HIT := 400
## key: [default, min, max]. Starting values (the lead's brief: a plate that takes 60 % less, blown off for 5 s at
## 125 %; slabs after 12 s for 8 s; Overpressure 3 s then 4 s at 6 % a second off a slab; the scald gauge to 1000 at
## 5 % a second). A phase index past the boss's last phase means never.
const SPEC := {
	"plate_phase": [1, 0, 9],
	"plate_first_seconds": [8.0, 0.0, 120.0],
	"plate_every_seconds": [20.0, 1.0, 120.0],
	"plate_cast_seconds": [1.5, 0.4, 10.0],
	"plate_taken_permille": [400, 0, 1000],
	"exposed_seconds": [5.0, 0.5, 30.0],
	"exposed_taken_permille": [1250, 1000, 3000],
	"drone_blast_m": [1.5, 0.1, 6.0],
	"drone_distance_m": [3.0, 0.5, 8.0],
	"drone_gap_seconds": [2.0, 0.0, 30.0],
	"slab_phase": [2, 0, 9],
	"slab_cool_seconds": [12.0, 1.0, 60.0],
	"slab_seconds": [8.0, 1.0, 60.0],
	"slag_drop_seconds": [6.0, 0.0, 120.0],
	"overpressure_phase": [2, 0, 9],
	"overpressure_first_seconds": [10.0, 0.0, 120.0],
	"overpressure_every_seconds": [22.0, 5.0, 120.0],
	"overpressure_cast_seconds": [3.0, 0.4, 10.0],
	"overpressure_seconds": [4.0, 0.5, 30.0],
	"overpressure_tick_seconds": [0.5, 0.1, 2.0],
	"overpressure_permille_per_second": [60, 1, 200],
	"scald_phase": [2, 0, 9],
	"scald_max": [1000, 1, 100000],
	"scald_hit": [200, 0, 100000],
	"scald_lava": [60, 0, 100000],
	"scald_open": [40, 0, 100000],
	"scald_drain_per_second": [250, 0, 100000],
	"scald_tick_seconds": [0.5, 0.1, 2.0],
	"scald_burn_permille_per_second": [50, 1, 200],
}
## The keys that name one of the boss's attacks (the death recap's line): Overpressure's and the scald's.
const CAUSE_KEYS := ["overpressure_cause", "scald_cause"]


## The forge dictionary's value for `key` (its default when the dictionary leaves it out).
static func value(forge: Dictionary, key: String) -> float:
	return float(forge.get(key, (SPEC[key] as Array)[0]))


## The per mille one step of `per_second_key` takes over `tick_key`'s step.
static func step_permille(forge: Dictionary, per_second_key: String, tick_key: String) -> float:
	return value(forge, per_second_key) * value(forge, tick_key)


static func _has_move(def: BossDefinition, move: StringName) -> bool:
	for a in def.attacks:
		if a != null and a.move == move:
			return true
	return false


## BossDefinition.validate: nothing to check without a forge.
static func validate(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var f := def.forge
	if f.is_empty():
		return
	var p := def.resource_path
	for k: Variant in f:
		if CAUSE_KEYS.has(k):
			if def.attack(StringName(str(f[k]))) == null:
				issues.append(ValidationIssue.new(&"attacks", p, "forge.%s: no such attack" % k))
			continue
		if not SPEC.has(k):
			issues.append(ValidationIssue.new(&"unknown_field", p, "forge: unknown key %s" % k))
			continue
		var spec: Array = SPEC[k]
		var v := float(f[k])
		if v < float(spec[1]) or v > float(spec[2]):
			issues.append(
				ValidationIssue.new(&"range", p, "forge.%s: %s..%s" % [k, spec[1], spec[2]])
			)
	for k: String in CAUSE_KEYS:
		if not f.has(k):
			issues.append(ValidationIssue.new(&"missing", p, "forge.%s is required" % k))
	for k: String in ["plate_cast_seconds", "overpressure_cast_seconds"]:
		if int(round(value(f, k) * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
			issues.append(
				ValidationIssue.new(&"telegraph_short", p, "forge.%s is under the minimum" % k)
			)
	var over := value(f, "overpressure_cast_seconds") + value(f, "overpressure_seconds")
	if value(f, "overpressure_every_seconds") <= over:
		issues.append(
			ValidationIssue.new(&"duration", p, "forge.overpressure_every_seconds must exceed it")
		)
	if value(f, "slab_seconds") < over:
		issues.append(
			ValidationIssue.new(&"duration", p, "forge.slab_seconds must last an Overpressure")
		)
	for pair: Array in [
		["overpressure_permille_per_second", "overpressure_tick_seconds"],
		["scald_burn_permille_per_second", "scald_tick_seconds"],
	]:
		var step := step_permille(f, pair[0], pair[1])
		if step < 1.0 or step > MAX_HIT:
			issues.append(
				ValidationIssue.new(
					&"range", p, "forge.%s: a step takes 1..%d per mille" % [pair[0], MAX_HIT]
				)
			)
	if not _has_move(def, &"brood"):
		issues.append(ValidationIssue.new(&"attacks", p, "forge needs a brood attack (drones)"))
