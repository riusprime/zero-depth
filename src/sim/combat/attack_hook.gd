class_name AttackHook
extends RefCounted
## v0.6.0 MX1 (MODIFIER_ENGINE §1–§2; SIM_CONTRACTS §5b): an attack a spec spawns. On its trigger (AttackSpec.Trigger)
## it launches `child`, a full spec the build's modifiers also rewrote (Modifiers.compile), with this damage: flat
## `damage`, or `damage_permille` of the parent's base damage (at least 1). Attacks.run_hook guards the recursion:
## depth at most Attacks.MAX_HOOK_DEPTH, the proc coefficient halving at each level (100 → 50 → 25), a hook never
## inside its own chain (ancestry), and the per-tick launch cap.

const WHEN_ALWAYS := 0
const WHEN_OVERCLOCK := 1
const WHEN_COUNTER := 2  # v0.6.5 WN4: only on a slash that counters (BladeForms.countering)

## The modifier that added it (its ancestry key: a hook never runs inside a chain it already opened).
var id := &""
var trigger: int = AttackSpec.Trigger.ON_HIT
## Fires every Nth time its trigger comes (0 = each time). ON_HIT hooks of the bolt count landed player bolts on
## World.chain_count (v0.5's Static Chain counter), one count per landed bolt.
var every := 0
var damage := 0
var damage_permille := 0
var child: AttackSpec
## v0.6.0 MX4: ticks between the trigger and the launch (ModifierRuntime queues it; 0 = at once), and when it may
## fire (WHEN_ALWAYS, or WHEN_OVERCLOCK: only while the heat is at Overclock).
var delay_ticks := 0
var when := 0
## v0.8.0 RM (owner O91; Remnants): a REMNANT op's hook: the remnant it leaves (null: a plain hook, which launches its
## child), its card's wand slot and trigger section (the slots between two triggers: Grand Finale's reach), and on a
## FINISHER remnant whether this spec extracts (the combo's finisher) or lodges (the other steps). Run by
## Remnants.on_hook instead of a launch; its child is what an activation casts.
var remnant: RemnantRule
var slot := -1
var section := 0
var extract := false


## The damage the child deals when the parent's base damage is `base`.
func damage_for(base: int) -> int:
	if damage > 0:
		return damage
	return maxi(1, base * damage_permille / 1000)


func hash_into(h: StateHasher) -> void:
	h.add_string(String(id))
	for v in [trigger, every, damage, damage_permille, delay_ticks, when]:
		h.add_int(v)
	if remnant != null:  # v0.8.0 RM: only a remnant's (a build without one hashes as before)
		remnant.digest_into(h)
		for v in [slot, section, 1 if extract else 0]:
			h.add_int(v)
	child.hash_into(h)
