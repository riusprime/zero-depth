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
## v0.6.5 WN1 (the wand's triggers): ON_CRIT, a landed critical hit (Attacks); ON_FINISHER is compile-time only
## (WandCompile turns it into the combo's last step's ON_HIT).
## v0.8.0 RM: ON_REMNANT, a remnant hook that no moment fires (Remnants finds it: a link, a path, a consumer).
enum Trigger {
	ON_HIT, ON_KILL, ON_NTH, ON_END, ON_LAUNCH, EVERY_NTH, ON_CRIT, ON_FINISHER, ON_REMNANT
}

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
	# v0.6.5 WN3 (the Gun pool; appended: the hash order): GunForms reads them
	&"twin",
	&"spiral",
	&"mine_ticks",
	&"hold_ticks",
	&"hold_permille",
	# v0.6.5 WN4 (the Blade pool; BladeForms reads them; appended: the hash order)
	&"motion",
	&"parry",
	&"counter_ticks",
	&"counter_permille",
	&"carry",
	&"echo_mirror",
]
## v0.8.0 BL (BLADE_AUDIT B1): int fields added after the hash order closed. Hashed only when not 0 (each with its
## name), so a spec that doesn't use them hashes exactly as before (no golden moves for a build without them).
const LATE_INT_FIELDS: Array[StringName] = [
	&"repeats",
	&"alive_max",  # v0.8.0 PF2
	&"hole_permille",  # v0.8.0 P2 (O24: Void's black holes)
	&"hole_damage_permille",
	# v0.8.0 AO (owner O37: the order rule; WandCompile, WandRings)
	&"ring_layout",
	&"ring_share_permille",
	&"swirl",
	&"swirl_group",
	&"ring_flight",  # v0.8.0 N3 (owner O47: the travelling ring's flight, ticks)
	# v0.8.0 MR (owner O91: extra bolts share the damage; a repeat never repeats; Rapid Fire's and Flurry's rhythms)
	&"share_permille",
	&"recast",
	&"ramp_permille",
	&"ramp_cap_permille",
	&"ramp_reset_ticks",
	&"burst_permille",
	&"burst_swings",
	&"burst_pause_ticks",
	# v0.8.0 RM (owner O91: Dodge Imprint, a dash spec's; Remnants.imprint)
	&"imprint_ticks",
	&"imprint_permille",
]
const FLOAT_FIELDS: Array[StringName] = [
	&"reach_m",
	&"radius_m",
	&"speed",
	&"pull_m",
	# v0.6.5 WN4 (appended)
	&"knockback_m",
	&"line_m",
	&"step_m",
]
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
## v0.8.0 BL (B1, Double Slash's level): how many repeats (0 = the one repeat above), the first repeat_delay_ticks
## after the attack and each next one ItemEffects.REPEAT_GAP_TICKS after the one before.
var repeats := 0
## v0.8.0 PF2 (owner O9; Blade Storm's blades): a bolt form's projectiles of this attack (its id, every key) alive and
## queued at once, at most (0 = no cap of its own; SimTuning.player_shots_max still holds). Attacks._bolts doesn't
## launch a bolt past it, and a launch cut short leaves one LIMIT event (Attacks.EFFECT_ALIVE_CAP).
var alive_max := 0

## v0.8.0 AO (owner O37; docs/roadmap/v0.8.0/evidence/ATTACK_ORDER.md): the order rule's ring. ring_layout 1: a
## ring a SHAPE card made (Ring), run by WandRings. v0.8.0 N3 (owner O47): the shot itself, a ring that flies: `count`
## ring shots laid as bolts are (v0.9.0 AS: one in a legal wand), each dealing ring_share_permille of the hit (0 =
## whole). swirl 1 (Swirl, a MOTION card): every ring flies off in its own
## random direction (a bolt: each leaves at a random angle); swirl_group 1 (a Swirl left of the Ring, taken in by it):
## the group flies the aim as one, its rings spinning round its centre. Randomness: WandRings' named stream.
var ring_layout := 0
var ring_share_permille := 0
var swirl := 0
var swirl_group := 0
## v0.8.0 N3 (owner O47: "the circle should substitute the fireball"): an order-rule ring's flight in ticks, the bolt's
## life it took in (WandCompile.take_in); it flies at the bolt's `speed` (WandRings). 0 = SpecForms' hook bolt's.
var ring_flight := 0

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
## v0.8.0 MR (owner O91; FireRhythm): the rhythm cards' extra rate, counted into the attack's raw rate bonus when it
## fires. Rapid Fire (sustained fire): each consecutive shot adds ramp_permille more, up to ramp_cap_permille, and the
## ramp starts over after ramp_reset_ticks without a shot. Flurry (a burst): the first burst_swings swings after
## burst_pause_ticks without swinging come burst_permille faster, the rest at the base rate. 0 = none.
var ramp_permille := 0
var ramp_cap_permille := 0
var ramp_reset_ticks := 0
var burst_permille := 0
var burst_swings := 0
var burst_pause_ticks := 0
## v0.8.0 RM (owner O91, Dodge Imprint; a dash spec's): for imprint_ticks after a dash starts, the next weapon attack is
## cast from where the dash began at × imprint_permille (0 = none; Remnants.imprint).
var imprint_ticks := 0
var imprint_permille := 0

# --- payload
## Damage per hit (a share `damage_permille` of it when the shot splits into count > 1 bolts, rounded down, at least
## 1); every nth_every-th step of the combo (0 = none) deals × nth_damage_permille / 1000 and runs its ON_NTH hooks.
var damage := 0
var damage_permille := 1000
## v0.8.0 MR (owner O91: "Extra projectiles must not each duplicate full damage"): each projectile (or hit) of this
## attack deals this share of the launch's damage (Twin's lanes, Spread's and Halo's bolts; the cards' shares
## multiply down the wand; 0 = whole). A spec with a share marks its bolts past the first secondary (Attacks._bolts:
## WandTable.secondary_proc_permille of their statuses and their hooks' proc; SecondaryProc).
var share_permille := 0
## v0.8.0 MR (O91: "Prevent repeats repeating themselves"): 1 on a trigger's later cast (a ×2 trigger's second, a
## slash hit's second) and on every spec built from one: it casts each of its own triggers once, and a repeat's hit
## (an Echo, a Double Slash echo) never launches a hook whose child is one (Attacks.run_hook).
var recast := 0
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
## Payload: a burst pulls the enemies it touches this far toward its centre (v0.6.0 MX4's Gravity Well; v0.8.0 P2:
## retired with Void's pull, no card sets it; kept for the hash order).
var pull_m := 0.0
## v0.8.0 P2 (owner O24, Void): each shot (a projectile where it ends) or landing slash of this spec leaves a black hole
## with this chance (per mille, one draw on the `ability` stream; 0 = never); its pulses deal this share of the shot's
## damage (BlackHoles).
var hole_permille := 0
var hole_damage_permille := 0
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

# --- v0.6.5 WN3 (docs/design/WAND.md, the Gun pool; GunForms runs them)
## Pattern: every bolt fires with this many more beside it, side by side (G3 Twin; 0 = one). Behaviour: a
## projectile's heading swings this far either side of its line, a corkscrew (G11 Spiral; 1/4096 turns, 0 = none);
## it stops where its flight ends and waits this many ticks, ending on the first enemy it touches (G12 Mine).
## Payload: the root shot charges while the shoot button is held, up to hold_ticks, growing to × hold_permille in
## size and damage (G13 Charge; 0 = no charge).
var twin := 0
var spiral := 0
var mine_ticks := 0
var hold_ticks := 0
var hold_permille := 1000
# --- v0.6.5 WN4 (docs/design/WAND.md B1–B16, "the slash becomes a spell"; BladeForms runs them)
## The swing's motion when a card changes it (SwingStep.Motion: Thrust a stab, Whirl a spin; -1 = the step's own).
var motion := -1
## The arc cuts the enemy shots it touches (Parry Edge).
var parry := 0
## A slash within counter_ticks of a dash's end deals × counter_permille and casts its WHEN_COUNTER hooks (Counter).
var counter_ticks := 0
var counter_permille := 1000
## A hook child that carries its parent's statuses, elements and hit hooks (Finisher+'s shockwave).
var carry := 0
## Its echo (repeat_delay_ticks) sweeps the other way (Double Slash; the view's).
var echo_mirror := 0
## A landed hit pushes the enemy this far away (Heavy); a burst is a line this long along its angle (Fissure); each
## swing steps the player this far forward (Lunge Step).
var knockback_m := 0.0
var line_m := 0.0
var step_m := 0.0

# --- hooks
var hooks: Array[AttackHook] = []
## The effect id its hits carry (&"" for the plain weapon attacks, as before MX1).
var effect_id := &""


## v0.8.0 BL: whether `field` is a whole-number field (INT_FIELDS or LATE_INT_FIELDS).
static func is_int_field(field: StringName) -> bool:
	return field in INT_FIELDS or field in LATE_INT_FIELDS


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
	for f in INT_FIELDS + LATE_INT_FIELDS + FLOAT_FIELDS:
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
	for f in LATE_INT_FIELDS:  # v0.8.0 BL: only when used (class doc)
		if get(f) != 0:
			h.add_string(String(f))
			h.add_int(get(f))
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
					"remnant": -1 if k.remnant == null else k.remnant.kind,  # v0.8.0 RM
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
		"repeats": repeats,  # v0.8.0 BL
		"alive_max": alive_max,  # v0.8.0 PF2
		"half_arc": half_arc,
		"reach_m": reach_m,
		"reach_bonus_permille": reach_bonus_permille,
		"radius_m": radius_m,
		"speed": speed,
		"rate_bonus_permille": rate_bonus_permille,
		"damage": damage,
		"share_permille": share_permille,  # v0.8.0 MR
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
		"hole_permille": hole_permille,  # v0.8.0 P2
		# v0.8.0 AO: the order rule's ring and Swirl (the views' lightning circles, shock arcs and storm)
		"ring_layout": ring_layout,
		"ring_share_permille": ring_share_permille,
		"swirl": swirl,
		"swirl_group": swirl_group,
		"ring_flight": ring_flight,  # v0.8.0 N3
		"barrier_ticks": barrier_ticks,
		"charge_ticks": charge_ticks,
		"charge_permille": charge_permille,
		"resonance_permille": resonance_permille,
		# v0.6.5 WN3 (AttackFormLooks' cues: twin, helix, mine, swell)
		"twin": twin,
		"spiral": spiral,
		"mine_ticks": mine_ticks,
		"hold_ticks": hold_ticks,
		"hold_permille": hold_permille,
		# v0.6.5 WN4 (the Blade pool's looks: BladeFormView, KitView)
		"motion": motion,
		"parry": parry,
		"counter_ticks": counter_ticks,
		"carry": carry,
		"echo_mirror": echo_mirror,
		"knockback_m": knockback_m,
		"line_m": line_m,
		"step_m": step_m,
	}
