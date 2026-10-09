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
	_check_tag_list(issues, "target", target)
	if ops.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "a modifier needs ops"))
	for k in ops.size():
		if ops[k] == null:
			issues.append(ValidationIssue.new(&"missing", resource_path, "ops[%d] is empty" % k))
		else:
			_check_op(issues, k, ops[k])
	return issues


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
	if o.op < ModifierOpDefinition.Op.SET or o.op > ModifierOpDefinition.Op.HOOK:
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
	if o.op == ModifierOpDefinition.Op.SET_FORM:
		if o.form < ModifierOpDefinition.Form.ARC or o.form > ModifierOpDefinition.Form.BURST:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown form" % where))


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
		or o.hook_when > ModifierOpDefinition.When.OVERCLOCK
	):
		issues.append(ValidationIssue.new(&"range", resource_path, "%s: unknown when" % where))
	_check_tag_list(issues, "%s.hook_tags" % where, o.hook_tags)
	for k in o.hook_ops.size():  # v0.6.0 MX4: the child's shaping ops (any op but a hook)
		var c := o.hook_ops[k]
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
			mods[d.id] = true
	for d in defs:
		var names: Array[StringName] = []
		if d is ItemDefinition:
			names = (d as ItemDefinition).modifiers
		elif d is AbilityDefinition:
			names = (d as AbilityDefinition).modifiers
		for id in names:
			if not mods.has(id):
				issues.append(
					ValidationIssue.new(&"unknown_modifier", d.resource_path, "no modifier %s" % id)
				)
	return issues
