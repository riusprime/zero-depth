class_name ModifierDefinition
extends ContentDef
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md §2; CONTENT_SCHEMA "Modifiers"): a modifier, one `.tres` in
## data/modifiers/, discovered by ContentScanner like every definition. It rewrites the attack specs whose tags
## include every tag of `target` (empty: every spec), at `stage` (an op may name another), with `ops` in order.
## Modifiers apply stage by stage (FORM, PATTERN, BEHAVIOUR, PAYLOAD, HOOK, SCALE), each stage in pick order
## (Modifiers.compile). A modifier enters the build through the card that names it (ItemDefinition.modifiers, v0.6.0
## MX2 also AbilityDefinition.modifiers); MX2: that card takes one of the six modifier slots (BuildSlots), and the
## slot order is the layer order.

## The fixed stage order (appended, never renumbered: it is the compile order).
enum Stage { FORM, PATTERN, BEHAVIOUR, PAYLOAD, HOOK, SCALE }
## Appended, never renumbered. v0.6.0 MX4: LEGENDARY (the boss's tier only).
enum Rarity { COMMON, RARE, LEGENDARY }
## v0.8.0 AO (owner O37: "make the order of the attacks be more important"; evidence/ATTACK_ORDER.md): what the card
## does to the cards to its left in the wand. FREE: a plain rewrite (stat-like; order changes nothing on its own).
## SHAPE: it changes what the attack is, and takes in what is left of it (Ring: a count left of it becomes the ring's
## pulses, a motion left of it throws the whole ring). COUNT: it multiplies what is left of it (Spread, Halo: right of
## a Ring, more rings). MOTION: it moves what is left of it (Swirl). WandCompile reads SHAPE; the wand's tiles show
## the other two. Appended, never renumbered.
enum OrderKind { FREE, SHAPE, COUNT, MOTION }

## Spec tags a target filter (and a hook's attack) may name. weapon: the run's weapon attacks; melee / projectile:
## what they physically are; skill: the Skill button; area / chain: a burst or a jump; hook: an attack a hook spawned.
## v0.6.0 MX2: the six ability modifiers' own attacks (Modifiers.ability specs): bomb (Bomb Lobber's lob), drone (the
## drone's copy), orbit (Orbit Blades' orbiters), field (Arc Field's shock zone), nova (Frost Nova's ring), trail
## (Flame Trail's fire).
const TAGS: Array[StringName] = [
	&"weapon",
	&"melee",
	&"projectile",
	&"skill",
	&"ability",
	&"area",
	&"chain",
	&"hook",
	&"auto",
	&"bomb",
	&"drone",
	&"orbit",
	&"field",
	&"nova",
	&"trail",
	# v0.6.0 MX4: the moments that launch from specs too: the dash (its start and end), Vent's blast, walking (every
	# Modifiers.MOVE_STEP_M), a blink's start, and the player's body (the defence and charge rules: Aether Shell,
	# Ascension, Resonance read its numbers; it never launches).
	&"dash",
	&"vent",
	&"move",
	&"blink",
	&"body",
	# v0.6.5 WN4 (the Blade pool): a flying slash (Wave's crescent, Counter's: Split Wave targets it) and the combo's
	# last step (Finisher+).
	&"wave",
	&"finisher",
]
## The card families (CardFrames.FRAME's keys: the frame colour a card of this modifier wears).
const FAMILIES: Array[StringName] = [
	&"damage",
	&"projectile",
	&"economy",
	&"dash",
	&"healing",
	&"time",
	&"crit",
	&"area",
	&"fire",
	&"curse",
	&"epic",
	&"trinket",
]

@export var family: StringName = &"damage"
@export var rarity := Rarity.COMMON
## Every tag a spec must carry to be rewritten (TAGS); empty = all specs.
@export var target: PackedStringArray = PackedStringArray()
@export var stage := Stage.PAYLOAD
@export var ops: Array[ModifierOpDefinition] = []
## An optional visual overlay id (the design's §4: only when the spec change alone isn't readable). Empty in MX1.
@export var overlay: StringName = &""
## v0.8.0 AO: OrderKind (what the card does to the cards to its left).
@export var order_kind := OrderKind.FREE
## v0.8.0 MR (owner O91, Split Wave without Wave): the card's other reading: on a spec carrying every tag here (and not
## the target) that has no hook child matching the target yet, the ops marked `alt` run instead of the others
## (ModifierTable.alt_target). Empty: none.
@export var alt_target: PackedStringArray = PackedStringArray()


func category() -> StringName:
	return &"modifiers"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if not family in FAMILIES:
		issues.append(ValidationIssue.new(&"range", resource_path, "unknown family %s" % family))
	if rarity < Rarity.COMMON or rarity > Rarity.LEGENDARY:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "rarity is common, rare or legendary")
		)
	if stage < Stage.FORM or stage > Stage.SCALE:
		issues.append(ValidationIssue.new(&"range", resource_path, "unknown stage %d" % stage))
	if order_kind < OrderKind.FREE or order_kind > OrderKind.MOTION:
		issues.append(ValidationIssue.new(&"range", resource_path, "unknown order kind"))
	if order_kind == OrderKind.SHAPE and not _sets_form():  # v0.8.0 AO: a shape card changes the form
		issues.append(ValidationIssue.new(&"order", resource_path, "a shape card sets a form"))
	_check_tag_list(issues, "target", target)
	_check_tag_list(issues, "alt_target", alt_target)  # v0.8.0 MR
	if _has_alt() and alt_target.is_empty():
		issues.append(ValidationIssue.new(&"alt", resource_path, "an alt op needs an alt_target"))
	if ops.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "a modifier needs ops"))
	if is_trigger() and ops.size() != 1:  # v0.6.5 WN1: a trigger card is its cut, nothing else
		issues.append(
			ValidationIssue.new(&"trigger", resource_path, "a trigger modifier has its one op only")
		)
	for k in ops.size():
		if ops[k] == null:
			issues.append(ValidationIssue.new(&"missing", resource_path, "ops[%d] is empty" % k))
		else:
			_check_op(issues, k, ops[k])
	return issues


## v0.8.0 MR: some op is of the card's other reading (ModifierOpDefinition.alt).
func _has_alt() -> bool:
	for o in ops:
		if o != null and o.alt:
			return true
	return false


func _check_tag_list(issues: Array[ValidationIssue], what: String, tags: PackedStringArray) -> void:
	var seen := {}
	for t in tags:
		if not StringName(t) in TAGS:
			issues.append(
				ValidationIssue.new(&"tags", resource_path, "%s: unknown tag %s" % [what, t])
			)
		elif seen.has(t):
			issues.append(
				ValidationIssue.new(&"tags", resource_path, "%s: tag %s twice" % [what, t])
			)
		seen[t] = true


func _check_op(issues: Array[ValidationIssue], k: int, o: ModifierOpDefinition) -> void:
	var where := "ops[%d]" % k
	var at := o.stage_in(stage)
	if o.op < ModifierOpDefinition.Op.SET or o.op > ModifierOpDefinition.Op.REMNANT:
		issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown op" % where))
		return
	if o.is_numeric() and not ModifierOpDefinition.FIELD_STAGE.has(o.field):
		issues.append(
			ValidationIssue.new(&"range", resource_path, "%s: unknown field %s" % [where, o.field])
		)
		return
	if at != o.required_stage():
		issues.append(
			ValidationIssue.new(
				&"stage",
				resource_path,
				(
					"%s runs in stage %d, its kind belongs to stage %d"
					% [where, at, o.required_stage()]
				)
			)
		)
	match o.op:
		ModifierOpDefinition.Op.MUL_PERMILLE:
			check_positive(issues, "%s.value" % where, o.value)
		ModifierOpDefinition.Op.STATUS:
			if not o.status in ModifierOpDefinition.STATUSES:
				issues.append(
					ValidationIssue.new(&"range", resource_path, "%s: unknown status" % where)
				)
			check_positive(issues, "%s.stacks" % where, o.stacks)
			if o.every < 0:
				issues.append(
					ValidationIssue.new(&"range", resource_path, "%s: every >= 0" % where)
				)
		ModifierOpDefinition.Op.ELEMENT:
			if not o.element in ModifierOpDefinition.ELEMENTS:
				issues.append(
					ValidationIssue.new(&"range", resource_path, "%s: unknown element" % where)
				)
		ModifierOpDefinition.Op.HOOK:
			_check_hook(issues, where, o)
		ModifierOpDefinition.Op.TRIGGER:
			_check_trigger(issues, where, o)
		ModifierOpDefinition.Op.REMNANT:  # v0.8.0 RM
			_check_remnant(issues, where, o)
	if o.op == ModifierOpDefinition.Op.SET_FORM:
		if o.form < ModifierOpDefinition.Form.ARC or o.form > ModifierOpDefinition.Form.BURST:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown form" % where))
	if (
		o.hook_casts != 1
		and (o.op != ModifierOpDefinition.Op.TRIGGER or o.hook_casts < 1 or o.hook_casts > 3)
	):
		issues.append(  # v0.6.5 WN5b: a legendary trigger casts its spell 1..3 times
			ValidationIssue.new(
				&"range", resource_path, "%s: hook_casts is 1..3, on a trigger" % where
			)
		)
	var hooked := o.op == ModifierOpDefinition.Op.HOOK or o.op == ModifierOpDefinition.Op.REMNANT
	if o.per_level != 0.0 and not (o.is_numeric() or hooked):
		issues.append(  # v0.6.5 WN3: a level grows a number (or a hook's damage share)
			ValidationIssue.new(
				&"range", resource_path, "%s: per_level on a numeric op or a hook" % where
			)
		)
	if o.per_level_after < 1 or o.per_level_after > 4:  # v0.8.0 BL (B2): the steps start above 1..4
		issues.append(
			ValidationIssue.new(&"range", resource_path, "%s: per_level_after is 1..4" % where)
		)


## v0.8.0 RM (Remnants): a remnant's numbers are in range, and its cast (unless it never casts: an anchor's pull) is
## a hook's child (_check_hook's rules, but its trigger: the remnant decides when).
func _check_remnant(issues: Array[ValidationIssue], where: String, o: ModifierOpDefinition) -> void:
	if (
		o.remnant_kind < ModifierOpDefinition.RemnantKind.SEGMENT
		or o.remnant_kind > ModifierOpDefinition.RemnantKind.FRAGMENT
	):
		issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown remnant" % where))
	if (
		o.remnant_spawn < ModifierOpDefinition.RemnantSpawn.LINK
		or o.remnant_spawn > ModifierOpDefinition.RemnantSpawn.NONE
	):
		issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown spawn" % where))
	var act := int(o.remnant_activate)
	if (
		act < ModifierOpDefinition.RemnantActivate.ENEMY_CROSS
		or act > ModifierOpDefinition.RemnantActivate.CONSUME
	):
		issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown activate" % where))
	var consumer := act == ModifierOpDefinition.RemnantActivate.CONSUME
	if consumer != (o.remnant_spawn == ModifierOpDefinition.RemnantSpawn.NONE):
		issues.append(
			ValidationIssue.new(&"remnant", resource_path, "%s: a consumer leaves nothing" % where)
		)
	var segment := o.remnant_kind == ModifierOpDefinition.RemnantKind.SEGMENT
	if (
		(
			o.remnant_spawn
			in [ModifierOpDefinition.RemnantSpawn.LINK, ModifierOpDefinition.RemnantSpawn.PATH]
		)
		and not segment
	):
		issues.append(
			ValidationIssue.new(
				&"remnant", resource_path, "%s: a link or a path is a segment" % where
			)
		)
	var on_enemy := (
		o.remnant_kind
		in [ModifierOpDefinition.RemnantKind.MARK, ModifierOpDefinition.RemnantKind.FRAGMENT]
	)
	if on_enemy and o.remnant_spawn != ModifierOpDefinition.RemnantSpawn.HIT:
		issues.append(
			ValidationIssue.new(&"remnant", resource_path, "%s: a mark is left by a hit" % where)
		)
	if not consumer:
		check_positive(issues, "%s.remnant_seconds" % where, o.remnant_seconds)
		check_duration(issues, "%s.remnant_seconds" % where, o.remnant_seconds)
		if o.remnant_max < 1 or o.remnant_max > 64:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "%s: remnant_max 1..64" % where)
			)
	if o.remnant_max_per_level < 0 or o.remnant_stack_per_level < 0:
		issues.append(ValidationIssue.new(&"range", resource_path, "%s: a level adds >= 0" % where))
	if (
		o.remnant_charges < 0
		or o.remnant_hit_gap_seconds < 0.0
		or o.remnant_seconds_per_level < 0.0
	):
		issues.append(
			ValidationIssue.new(&"range", resource_path, "%s: remnant numbers >= 0" % where)
		)
	if o.remnant_spawn == ModifierOpDefinition.RemnantSpawn.CONTACT:
		check_positive(issues, "%s.remnant_length_m" % where, o.remnant_length_m)
	if o.remnant_spawn == ModifierOpDefinition.RemnantSpawn.LINK:
		check_positive(issues, "%s.remnant_link_seconds" % where, o.remnant_link_seconds)
	if act == ModifierOpDefinition.RemnantActivate.PULL:
		check_positive(issues, "%s.remnant_pull_radius_m" % where, o.remnant_pull_radius_m)
	if (
		act == ModifierOpDefinition.RemnantActivate.TURN
		and (o.remnant_turn_degrees <= 0.0 or o.remnant_turn_degrees > 180.0)
	):
		issues.append(ValidationIssue.new(&"range", resource_path, "%s: a turn of 0..180" % where))
	if act == ModifierOpDefinition.RemnantActivate.DELAY:
		check_positive(issues, "%s.remnant_delay_seconds" % where, o.remnant_delay_seconds)
	if (
		act == ModifierOpDefinition.RemnantActivate.FINISHER
		and (o.remnant_stack_max < 1 or o.remnant_stack_max > 16)
	):
		issues.append(
			ValidationIssue.new(&"range", resource_path, "%s: remnant_stack_max 1..16" % where)
		)
	if consumer:
		check_positive(issues, "%s.remnant_period_seconds" % where, o.remnant_period_seconds)
		if o.remnant_release_max < 1 or o.remnant_release_max > 64:
			issues.append(
				ValidationIssue.new(
					&"range", resource_path, "%s: remnant_release_max 1..64" % where
				)
			)
	if act != ModifierOpDefinition.RemnantActivate.PULL:
		_check_hook(issues, where, o)


## v0.8.0 AO: one of the card's own ops changes the form (SET_FORM).
func _sets_form() -> bool:
	for o in ops:
		if o != null and o.op == ModifierOpDefinition.Op.SET_FORM:
			return true
	return false


## v0.6.5 WN1: the modifier is a wand trigger (its op is TRIGGER).
func is_trigger() -> bool:
	for o in ops:
		if o != null and o.op == ModifierOpDefinition.Op.TRIGGER:
			return true
	return false


## v0.6.5 WN1: a trigger cuts on one of the wand's triggers (and its Gun trigger, when set, is one too).
func _check_trigger(issues: Array[ValidationIssue], where: String, o: ModifierOpDefinition) -> void:
	if not int(o.hook_trigger) in ModifierOpDefinition.WAND_TRIGGERS:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "%s: not a wand trigger" % where)
		)
	if o.hook_trigger_gun != -1 and not o.hook_trigger_gun in ModifierOpDefinition.WAND_TRIGGERS:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "%s: the Gun's trigger is not a wand trigger" % where
			)
		)


## A hook spawns a burst (needs a radius) or a beam that jumps (needs a reach); v0.6.0 MX2 adds the lingering forms:
## a lob (a bomb thrown hook_reach_m along the parent's way, landing for hook_radius_m), a zone (a patch of
## hook_radius_m) and a ring (expanding to hook_radius_m). On the triggers Trigger names.
func _check_hook(issues: Array[ValidationIssue], where: String, o: ModifierOpDefinition) -> void:
	if (
		o.hook_trigger < ModifierOpDefinition.Trigger.ON_HIT
		or o.hook_trigger > ModifierOpDefinition.Trigger.EVERY_NTH
	):
		issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown trigger" % where))
	if o.hook_trigger == ModifierOpDefinition.Trigger.EVERY_NTH and o.hook_every < 2:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "%s: every_nth needs hook_every >= 2" % where
			)
		)
	if o.hook_delay_seconds < 0.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "%s: a delay >= 0" % where))
	if (
		o.hook_when < ModifierOpDefinition.When.ALWAYS
		or o.hook_when > ModifierOpDefinition.When.COUNTER
	):
		issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown when" % where))
	_check_tag_list(issues, "%s.hook_tags" % where, o.hook_tags)
	for k in o.hook_ops.size():  # v0.6.0 MX4: the child's shaping ops (any op but a hook)
		var c := o.hook_ops[k] as ModifierOpDefinition
		var cw := "%s.hook_ops[%d]" % [where, k]
		if (
			c == null
			or c.op == ModifierOpDefinition.Op.HOOK
			or c.op == ModifierOpDefinition.Op.SET_FORM
		):
			issues.append(
				ValidationIssue.new(&"range", resource_path, "%s: not a hook or a form" % cw)
			)
		elif c.is_numeric() and not ModifierOpDefinition.FIELD_STAGE.has(c.field):
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown field" % cw))
		elif (
			c.op == ModifierOpDefinition.Op.STATUS and not c.status in ModifierOpDefinition.STATUSES
		):
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown status" % cw))
		elif (
			c.op == ModifierOpDefinition.Op.ELEMENT
			and not c.element in ModifierOpDefinition.ELEMENTS
		):
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown element" % cw))
	match o.form:
		ModifierOpDefinition.Form.BURST, ModifierOpDefinition.Form.ZONE:
			check_positive(issues, "%s.hook_radius_m" % where, o.hook_radius_m)
		ModifierOpDefinition.Form.RING, ModifierOpDefinition.Form.LOB:
			check_positive(issues, "%s.hook_radius_m" % where, o.hook_radius_m)
		ModifierOpDefinition.Form.BEAM:
			check_positive(issues, "%s.hook_reach_m" % where, o.hook_reach_m)
		ModifierOpDefinition.Form.BOLT, ModifierOpDefinition.Form.ARC:  # v0.6.0 MX4: a shot, a slash
			check_positive(
				issues,
				"%s.hook_radius_m or hook_reach_m" % where,
				maxf(o.hook_radius_m, o.hook_reach_m)
			)
		ModifierOpDefinition.Form.WEAPON:  # v0.6.0 MX4: a copy of the weapon's attack (its own sizes)
			pass
		ModifierOpDefinition.Form.ORBITER:  # v0.6.5 WN4: Orbit Blades' blade (its orbit's radius)
			check_positive(issues, "%s.hook_reach_m" % where, o.hook_reach_m)
		_:
			(
				issues
				. append(
					(
						ValidationIssue
						. new(
							&"range",
							resource_path,
							(
								"%s: a hook spawns a burst, a beam, a lob, a zone, a ring, a bolt, an arc or a weapon copy"
								% where
							)
						)
					)
				)
			)
	if o.hook_damage <= 0 and o.hook_damage_permille <= 0:
		issues.append(
			ValidationIssue.new(
				&"not_positive", resource_path, "%s: hook_damage or hook_damage_permille" % where
			)
		)
	if o.hook_every < 0:
		issues.append(ValidationIssue.new(&"range", resource_path, "%s: hook_every >= 0" % where))


## v0.6.0 MX1: every item's modifiers exist (ItemDefinition.modifiers names ModifierDefinition ids); MX2: every
## ability's too (AbilityDefinition.modifiers).
static func cross_check(defs: Array[ContentDef]) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var mods := {}
	for d in defs:
		if d is ModifierDefinition:
			mods[d.id] = (d as ModifierDefinition).is_trigger()
	for d in defs:
		var names: Array[StringName] = []
		var trigger_card := false
		if d is ItemDefinition:
			names = (d as ItemDefinition).modifiers
			trigger_card = (d as ItemDefinition).kind == ItemDefinition.Kind.TRIGGER
		elif d is AbilityDefinition:
			names = (d as AbilityDefinition).modifiers
		for id in names:
			if not mods.has(id):
				issues.append(
					ValidationIssue.new(&"unknown_modifier", d.resource_path, "no modifier %s" % id)
				)
			elif bool(mods[id]) != trigger_card:  # v0.6.5 WN1: a trigger only on a trigger card
				(
					issues
					. append(
						(
							ValidationIssue
							. new(
								&"trigger",
								d.resource_path,
								(
									"a trigger card names one trigger modifier, no other card names one (%s)"
									% id
								)
							)
						)
					)
				)
		if trigger_card and names.size() != 1:
			issues.append(
				ValidationIssue.new(
					&"trigger", d.resource_path, "a trigger card names one modifier"
				)
			)
	return issues
