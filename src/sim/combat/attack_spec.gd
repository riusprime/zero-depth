class_name AttackSpec
extends RefCounted
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md §1; SIM_CONTRACTS §5b): one attack the player makes, as data. The
## base spec comes from the player table (a combo step, the bolt, the Skill); Modifiers.compile rewrites it with the
## build's modifiers in the fixed stage order and caches the result (World.attack_book); Attacks.launch runs it and
## the view draws it (WorldReader.attack_spec). Sim units: ticks, metres, metres per tick, 1/4096 turns, per mille.
## A spec is rebuilt by every compile and never written in play, so a launch can't change the next one.

## ModifierOpDefinition.Form, same numbers. v0.6.0 MX4: WEAPON, a hook child that launches a copy of the weapon's
## last attack (Attacks.launch resolves it).
enum Form { ARC, BOLT, RING, BEAM, ZONE, ORBITER, LOB, BURST, WEAPON }
## ModifierOpDefinition.Trigger, same numbers. ON_END: where an attack ends (an arc's tip, a burst, a bolt's end, a
## bomb's blast, a ring at its radius, the dash's end); the form-layering rule makes them too (Modifiers: a second
## form fires where the first one ends). v0.6.0 MX4: ON_LAUNCH as the attack launches (and the dash's start, a walk
## step, a blink, a vent), EVERY_NTH: every Nth launch of the spec launches the child instead.
enum Trigger { ON_HIT, ON_KILL, ON_NTH, ON_END, ON_LAUNCH, EVERY_NTH }

## Numeric fields a modifier op may change (sim names; ModifierTable.FIELD_OF maps the content names), and which of
## them are floats.
const INT_FIELDS: Array[StringName] = [
	&"count",
	&"spread",
	&"repeat_delay_ticks",
	&"repeat_damage_permille",
	&"bounces",
	&"pierce",
	&"damage",
	&"damage_permille",
	&"nth_every",
	&"nth_damage_permille",
	&"hitstop_ticks",
	&"half_arc",
	&"reach_bonus_permille",
	&"life_ticks",
	&"period_ticks",
	&"rate_bonus_permille",
	# v0.6.0 MX4 (appended: the hash order)
	&"mirror",
	&"directions",
	&"back_permille",
	&"aim_offset",
	&"chains",
	&"homing",
	&"returns",
	&"orbit_ticks",
	&"intangible",
	&"barrier_ticks",
	&"charge_ticks",
	&"charge_permille",
	&"resonance_permille",
	&"heat_rate_permille",
	&"damage_mul_permille",
]
const FLOAT_FIELDS: Array[StringName] = [&"reach_m", &"radius_m", &"speed", &"pull_m"]
## v0.6.0 MX4: directions (the pattern's way): forward along the aim, or a full circle (count spread evenly).
const DIR_FORWARD := 0
const DIR_CIRCLE := 1

## Which attack this is (Modifiers' ids: blade_step_<n>, gun_bolt, skill, MX2 the ability modifiers' ids; a hook's
## child: its hook id).
var id := &""
## v0.6.0 MX2: where the book files it (AttackBook.register: a root's id, a hook child's "<parent key>/<n>"), so a
## projectile, a bomb or a patch names the spec it runs. Not copied, not hashed (derived from the book).
var key := ""
var form: int = Form.ARC
## What it is, for target filters (ModifierDefinition.TAGS).
var tags := PackedStringArray()
## The modifier ids that rewrote it, in the order they applied (for the view and the tests).
var modifier_ids := PackedStringArray()
## Hook depth: 0 for a root attack, 1 for an attack a hook of a root spawns, 2 for one below that (the deepest).
var depth := 0
## Form ops taken so far: the first sets `form`, each later one layers (an ON_END hook in its form).
var form_layers := 0

# --- pattern
## How many (bolts in a shot) over the full fan `spread` (1/4096 turns), centred on the aim.
var count := 1
var spread := 0
## Again after this many ticks (0 = no repeat) at this share of the first's damage (Twin Arc's echo).
var repeat_delay_ticks := 0
var repeat_damage_permille := 0

# --- size, speed, reach
## An arc: half its width (1/4096 turns) and its reach past the attacker's edge, × (1000 + bonus) / 1000.
var half_arc := 0
var reach_m := 0.0
var reach_bonus_permille := 0
## A bolt's radius (or a burst's), its speed per tick and its life; the weapon's period between shots.
var radius_m := 0.0
var speed := 0.0
var life_ticks := 0
var period_ticks := 0
var rate_bonus_permille := 0

# --- payload
## Damage per hit (a share `damage_permille` of it when the shot splits into count > 1 bolts, rounded down, at least
## 1); every nth_every-th step of the combo (0 = none) deals × nth_damage_permille / 1000 and runs its ON_NTH hooks.
var damage := 0
var damage_permille := 1000
var nth_every := 0
var nth_damage_permille := 1000
var hitstop_ticks := 0
## Statuses a landed hit feeds (parallel arrays): the engine status (ModifierOpDefinition.STATUSES), its stacks,
## one application every `every` landed hits (0 = each), and whether it rides on an engine the build already runs
## (Modifiers' riders: a v0.5 rule kept exact, not drawn as an element).
var status_ids := PackedStringArray()
var status_stacks := PackedInt32Array()
var status_every := PackedInt32Array()
var status_rider := PackedInt32Array()
## Elements the view draws (ModifierOpDefinition.ELEMENTS), in the order the modifiers added them.
var elements := PackedStringArray()

# --- behaviour
var bounces := 0
var pierce := 0
## A beam that jumps from the hit to the nearest other enemy within reach_m (Static Chain).
var seek := false

# --- v0.6.0 MX4 (the M-list's runner features; Attacks, ProjectileMoves, ModifierRuntime read them)
## Pattern: DIR_FORWARD or DIR_CIRCLE (Halo Shot: `count` evenly round; an arc: the full circle); also fired straight
## back at this share of its damage (Rearguard; 0 = not); every bolt's aim turned by this (1/4096 turns).
var directions := DIR_FORWARD
var back_permille := 0
var aim_offset := 0
## Behaviour: a seeking beam jumps on to this many more enemies (Storm Core); a projectile turns toward the nearest
## enemy by this much a tick, an arc snaps to it (Seeker); a projectile flies back to the player at half its life
## (Boomerang, 1); circles the player for this many ticks before it leaves (Orbit Rounds); the dash passes through
## bodies untouchable (Phase Dash, 1).
var chains := 0
var homing := 0
var returns := 0
var orbit_ticks := 0
var intangible := 0
## Ability merges (Modifiers.mirror): 1 the spec copies the weapon's form, pattern and every hook (Mirror Drone); 2
## it takes every hook of the weapon (Blade Orbit).
var mirror := 0
## Payload: a burst pulls the enemies it touches this far toward its centre (Gravity Well).
var pull_m := 0.0
## The body spec's rules (never launched): out of combat this long, a barrier absorbs one hit (Aether Shell); after
## this long without attacking the next attack deals × charge_permille (Ascension); each status on an enemy adds
## this to the damage it takes (Resonance).
var barrier_ticks := 0
var charge_ticks := 0
var charge_permille := 1000
var resonance_permille := 0
## The drone's fire rate + this per mille per heat point held (Overclocked Drone).
var heat_rate_permille := 0
## v0.6.0 MX4: the product of the MUL_PERMILLE ops on `damage` (the view's weight: Short Fuse ×1.4; 1000 = none).
var damage_mul_permille := 1000
## v0.6.0 MX4: the modifier ids whose hooks made this spec (a hook child's parents'): a modifier never adds its hook
## to a spec its own hook made (Split Shot's shards never split again; the ancestry guard, at compile time).
var lineage := PackedStringArray()

# --- hooks
var hooks: Array[AttackHook] = []
## The effect id its hits carry (&"" for the plain weapon attacks, as before MX1).
var effect_id := &""


func has_tag(tag: StringName) -> bool:
	return tags.has(String(tag))


## True if every tag in `filter` is one of this spec's (an empty filter matches every spec).
func matches(filter: PackedStringArray) -> bool:
	for t in filter:
		if not tags.has(t):
			return false
	return true


## The status's index in status_ids, or -1.
func status_index(status: StringName) -> int:
	return status_ids.find(String(status))


func has_status(status: StringName) -> bool:
	return status_index(status) >= 0


## Stacks `status` feeds per landed hit (0 = none).
func stacks_of(status: StringName) -> int:
	var k := status_index(status)
	return status_stacks[k] if k >= 0 else 0


func every_of(status: StringName) -> int:
	var k := status_index(status)
	return status_every[k] if k >= 0 else 0


## Sets `status` to `stacks` every `every` (the last op in pick order wins, as v0.5's items did).
func set_status(status: StringName, stacks: int, every: int, rider: bool = false) -> void:
	var k := status_index(status)
	if k < 0:
		status_ids.append(String(status))
		status_stacks.append(stacks)
		status_every.append(every)
		status_rider.append(1 if rider else 0)
		return
	status_stacks[k] = stacks
	status_every[k] = every
	status_rider[k] = 1 if rider else 0


func hooks_on(trigger: int) -> Array[AttackHook]:
	var out: Array[AttackHook] = []
	for h in hooks:
		if h.trigger == trigger:
			out.append(h)
	return out


## A copy whose own fields and arrays are fresh (hooks are shared: a compile never writes a hook once built).
func copy() -> AttackSpec:
	var s := AttackSpec.new()
	for f: StringName in [&"id", &"form", &"depth", &"form_layers", &"seek", &"effect_id"]:
		s.set(f, get(f))
	for f in INT_FIELDS + FLOAT_FIELDS:
		s.set(f, get(f))
	for f: StringName in [
		&"tags",
		&"modifier_ids",
		&"status_ids",
		&"status_stacks",
		&"status_every",
		&"status_rider",
		&"elements",
		&"lineage",
	]:
		s.set(f, get(f).duplicate())
	s.hooks = hooks.duplicate()
	return s


## Hashes every field in a fixed order (Modifiers.hash_into), hooks and their children included.
func hash_into(h: StateHasher) -> void:
	h.add_string(String(id))
	h.add_int(form)
	h.add_int(depth)
	h.add_int(form_layers)
	h.add_int(1 if seek else 0)
	h.add_string(String(effect_id))
	for f in INT_FIELDS:
		h.add_int(get(f))
	for f in FLOAT_FIELDS:
		h.add_f32(get(f))
	for arr: PackedStringArray in [tags, modifier_ids, status_ids, elements, lineage]:
		h.add_string(",".join(arr))
	h.add_ints(status_stacks)
	h.add_ints(status_every)
	h.add_ints(status_rider)
	h.add_int(hooks.size())
	for k in hooks:
		k.hash_into(h)


## The reads the views need (WorldReader.attack_spec): plain data, never the object.
func read() -> Dictionary:
	var hooks_out := []
	for k in hooks:
		(
			hooks_out
			. append(
				{
					"id": k.id,
					"trigger": k.trigger,
					"every": k.every,
					"delay_ticks": k.delay_ticks,
					"when": k.when,
					"child": k.child.read(),
				}
			)
		)
	return {
		"id": id,
		"form": form,
		"tags": tags.duplicate(),
		"modifiers": modifier_ids.duplicate(),
		"depth": depth,
		"count": count,
		"spread": spread,
		"repeat_delay_ticks": repeat_delay_ticks,
		"half_arc": half_arc,
		"reach_m": reach_m,
		"reach_bonus_permille": reach_bonus_permille,
		"radius_m": radius_m,
		"speed": speed,
		"rate_bonus_permille": rate_bonus_permille,
		"damage": damage,
		"nth_every": nth_every,
		"statuses": status_ids.duplicate(),
		"elements": elements.duplicate(),
		"bounces": bounces,
		"pierce": pierce,
		"seek": seek,
		"hooks": hooks_out,
		# v0.6.0 MX4
		# v0.6.0 MX4, for MX3's AttackFormLooks: "circle", "back" (fired back too: Rearguard) or "forward"; the
		# motion cues "home" and "return"; the weight, damage_mul_permille (1000 = none).
		"directions":
		"circle" if directions == DIR_CIRCLE else ("back" if back_permille > 0 else "forward"),
		"home": homing > 0,
		"return": returns > 0,
		"damage_mul_permille": damage_mul_permille,
		"back_permille": back_permille,
		"chains": chains,
		"homing": homing,
		"returns": returns,
		"orbit_ticks": orbit_ticks,
		"intangible": intangible,
		"mirror": mirror,
		"pull_m": pull_m,
		"barrier_ticks": barrier_ticks,
		"charge_ticks": charge_ticks,
		"charge_permille": charge_permille,
		"resonance_permille": resonance_permille,
	}
