class_name SiegeRules
extends RefCounted
## The content rules of a boss's siege mechanics (BossDefinition.siege: the Siege Engine's Target Lock and its
## boulders, the Shockwave that needs cover, and the Doom Shell's ammo cart; its own file, as the dance's rules).
## Every key is known and within its bounds, so no single hit takes more than MAX_HIT per mille of the hero's max HP;
## a lock's painted circle lasts the telegraph minimum and locks before it lands; one lock and one cart each end
## before the next begins; the boss holds a `marks` attack (the death recap names its shells).

## The most one hit of the siege may take, per mille of the hero's max HP: never a kill from full HP by one mistake.
const MAX_HIT := 400
## key: [default, min, max]. Starting values (the lead's brief: a 2.2 m circle for 4 s that lands 35 %, 3 m
## boulders for 30 s, four at most; a cart worth 6 % of the boss that rolls 10 s; a Doom Shell of 40 %; a blast of
## 25 % in 6 m that strips the armour for 8 s). A phase index past the boss's last phase means never.
const SPEC := {
	"lock_phase": [1, 0, 9],
	"lock_first_seconds": [6.0, 1.0, 120.0],
	"lock_every_seconds": [14.0, 5.0, 120.0],
	"lock_seconds": [4.0, 1.0, 10.0],
	"lock_hold_seconds": [0.6, 0.1, 3.0],
	"lock_radius_m": [2.2, 0.5, 5.0],
	"lock_follow_permille": [800, 0, 1500],
	"lock_permille": [350, 1, MAX_HIT],
	"boulder_size_m": [3.0, 0.5, 5.0],
	"boulder_seconds": [30.0, 1.0, 120.0],
	"boulder_max": [4, 1, 8],
	"cover_phase": [2, 0, 9],
	"shockwave_cap_permille": [400, 1, MAX_HIT],
	"doom_phase": [1, 0, 9],
	"doom_first_seconds": [14.0, 1.0, 120.0],
	"doom_every_seconds": [35.0, 5.0, 120.0],
	"doom_count": [1, 0, 6],
	"doom_late_phase": [2, 0, 9],
	"doom_late_count": [2, 0, 6],
	"cart_hp_permille": [60, 1, 500],
	"cart_radius_m": [1.0, 0.3, 2.0],
	"cart_roll_seconds": [10.0, 2.0, 30.0],
	"doom_delay_seconds": [1.0, 0.3, 5.0],
	"doom_permille": [400, 1, MAX_HIT],
	"cart_blast_m": [6.0, 1.0, 12.0],
	"cart_blast_permille": [250, 1, MAX_HIT],
	"strip_seconds": [8.0, 1.0, 30.0],
	"strip_taken_permille": [1500, 1000, 3000],
}


## The siege dictionary's value for `key` (its default when the dictionary leaves it out).
static func value(siege: Dictionary, key: String) -> float:
	return float(siege.get(key, (SPEC[key] as Array)[0]))


static func _is_marks(a: BossAttackDefinition) -> bool:
	return a != null and a.move == &"marks"


## BossDefinition.validate.
static func validate(def: BossDefinition, issues: Array[ValidationIssue]) -> void:
	var sg := def.siege
	var p := def.resource_path
	if sg.is_empty():
		return
	for k: Variant in sg:
		if not SPEC.has(k):
			issues.append(ValidationIssue.new(&"unknown_field", p, "siege: unknown key %s" % k))
			continue
		var spec: Array = SPEC[k]
		var v := float(sg[k])
		if v < float(spec[1]) or v > float(spec[2]):
			issues.append(
				ValidationIssue.new(&"range", p, "siege.%s: %s..%s" % [k, spec[1], spec[2]])
			)
	var lock := value(sg, "lock_seconds")
	if value(sg, "lock_hold_seconds") >= lock:
		issues.append(
			ValidationIssue.new(&"duration", p, "siege.lock_hold_seconds must end inside the lock")
		)
	if value(sg, "lock_every_seconds") <= lock:
		issues.append(
			ValidationIssue.new(&"duration", p, "siege.lock_every_seconds must exceed the lock")
		)
	if int(round(lock * 60.0)) < BehaviourSchemas.MIN_TELEGRAPH_TICKS:
		issues.append(
			ValidationIssue.new(&"telegraph_short", p, "siege: the lock is under the minimum")
		)
	var doom := value(sg, "cart_roll_seconds") + value(sg, "doom_delay_seconds")
	if value(sg, "doom_every_seconds") <= doom:
		issues.append(
			ValidationIssue.new(
				&"duration", p, "siege.doom_every_seconds must exceed the cart's roll and the shell"
			)
		)
	if not def.attacks.any(_is_marks):
		issues.append(ValidationIssue.new(&"attacks", p, "siege needs a marks attack"))
