class_name AttackSlotsDefinition
extends ContentDef
## v0.9.0 AS (owner Q2–Q5, Q13; PLAN C37–C45, C60–C67; docs/roadmap/v0.9.0/ATTACK_FORMS.md): the wand's slot
## categories' limits, the per-attack projectile caps and the one form × card compatibility table. One `.tres` in
## data/wand/ (attack_slots.tres; its own file so data/wand/wand.tres stays the wand's), compiled by WandCompiler into
## SlotTable (World.slot_table); every check reads it: the offers (ItemPool.usable), the equip (BuildSlots.take through
## AttackSlots), the compile (Modifiers.build_modifiers) and an old save's trim (AttackSlots.trim).
## - gun_limits / blade_limits: per category in AttackSlots' order (Form, Pattern, Secondary, Element) the most cards
##   of it the wand holds on a Gun / Blade run (-1: no limit; Free cards never have one). Q4: Form 1, Pattern 1,
##   Secondary 2, Elements 2 on the Gun; Q6: the Blade gets only the one-pattern rule.
## - shots_per_attack_max (Q13): the most projectiles one attack launches (pattern × Twin × Split children); extra
##   copies merge into bigger shots that keep the damage (ShotCap). shots_per_second_max: the most player projectiles
##   launched in any second on a Gun run; past it a volley merges into the shots that fit (Q13's "40 a second"
##   line, kept as a budget so the worst legal build holds it at any attack speed). merge_radius_max_permille: a
##   merged shot's radius grows with the copies it took in, at most this much (per mille of its own).
## - forms: one AttackFormRow per Gun form (Q7: ten approved, built in later steps). Exactly one row has no card: the
##   default form, Orbs (the Gun's own shot, data/player/runner.tres). Every cell not on is off (C62).
## Every number is a starting value, editable without code (C45).

const CATEGORY_COUNT := 4
const LIMIT_MAX := 8

@export var gun_limits := PackedInt32Array([1, 1, 2, 2])
@export var blade_limits := PackedInt32Array([-1, 1, -1, -1])
@export var shots_per_attack_max := 12
@export var shots_per_second_max := 40
@export var merge_radius_max_permille := 2000
@export var forms: Array[AttackFormRow] = []


func category() -> StringName:
	return &"wand"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	for pair: Array in [["gun_limits", gun_limits], ["blade_limits", blade_limits]]:
		var lim: PackedInt32Array = pair[1]
		if lim.size() != CATEGORY_COUNT:
			issues.append(
				ValidationIssue.new(
					&"table_size", resource_path, "%s has one entry per category (4)" % pair[0]
				)
			)
		for v in lim:
			if v < -1 or v > LIMIT_MAX:
				issues.append(
					ValidationIssue.new(&"range", resource_path, "%s entries are -1..8" % pair[0])
				)
	if shots_per_attack_max < 1 or shots_per_attack_max > 256:
		issues.append(ValidationIssue.new(&"range", resource_path, "shots_per_attack_max 1..256"))
	if shots_per_second_max < 1 or shots_per_second_max > 1000:
		issues.append(ValidationIssue.new(&"range", resource_path, "shots_per_second_max 1..1000"))
	if merge_radius_max_permille < 1000 or merge_radius_max_permille > 4000:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "merge_radius_max_permille 1000..4000")
		)
	var defaults := 0
	var seen := {}
	for r in forms:
		if r == null or String(r.id).is_empty():
			issues.append(
				ValidationIssue.new(&"missing", resource_path, "a form row without an id")
			)
			continue
		if seen.has(r.id):
			issues.append(
				ValidationIssue.new(&"duplicate_id", resource_path, "form %s twice" % r.id)
			)
		seen[r.id] = true
		if String(r.card).is_empty():
			defaults += 1
		issues.append_array(_check_params(r))
		var cells := {}
		for c in r.allowed + r.ruled:
			if cells.has(c):
				issues.append(
					ValidationIssue.new(
						&"duplicate_id", resource_path, "%s: card %s twice" % [r.id, c]
					)
				)
			cells[c] = true
	if defaults != 1:
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "exactly one form row has no card")
		)
	return issues


## v0.9.5 FC1: a form row's params are whole numbers above 0 named for something the form reads; the Laser row has
## every number LaserMods reads.
func _check_params(r: AttackFormRow) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	for k in r.params:
		var v: Variant = r.params[k]
		if not (v is int) or int(v) <= 0:
			issues.append(
				ValidationIssue.new(
					&"range", resource_path, "%s: param %s is a whole number > 0" % [r.id, k]
				)
			)
		var keys := _keys_of(r.id)
		if not keys.is_empty() and not keys.has(String(k)):
			issues.append(
				ValidationIssue.new(&"unknown_key", resource_path, "%s: no param %s" % [r.id, k])
			)
	for k in _keys_of(r.id):
		if not r.params.has(k):
			issues.append(
				ValidationIssue.new(&"missing", resource_path, "%s: param %s missing" % [r.id, k])
			)
	return issues


## The param keys form `id` must carry (v0.9.5 FC1 Laser, FC2 Bomb, FC3 Void); none for the other forms.
func _keys_of(id: StringName) -> Array[String]:
	if id == &"laser":
		return AttackFormRow.LASER_KEYS
	if id == &"bomb":
		return AttackFormRow.BOMB_KEYS
	if id == &"void":
		return AttackFormRow.VOID_KEYS
	if id == &"lance":
		return AttackFormRow.LANCE_KEYS
	if id == &"glaive":
		return AttackFormRow.GLAIVE_KEYS
	return []


## v0.9.0 AS: every live card (an item the migration table doesn't retire) that takes a wand slot (it names modifiers)
## names its slot category; a form row's card is a live Form card; every cell names a live Pattern, Secondary or
## Element card (C60: every table id is real).
static func cross_check(defs: Array[ContentDef]) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var retired := {}
	for d in defs:
		if d is WandMigrationDefinition:
			for id in (d as WandMigrationDefinition).old_ids:
				retired[id] = true
	var live := {}
	for d in defs:
		var it := d as ItemDefinition
		if it == null or retired.has(it.id):
			continue
		live[it.id] = it.slot_category
		if not it.modifiers.is_empty() and String(it.slot_category).is_empty():
			issues.append(
				ValidationIssue.new(
					&"missing", it.resource_path, "a live wand card names its slot_category"
				)
			)
	for d in defs:
		var t := d as AttackSlotsDefinition
		if t == null:
			continue
		for r in t.forms:
			if r == null:
				continue
			if not String(r.card).is_empty() and live.get(r.card, &"") != &"form":
				issues.append(
					ValidationIssue.new(
						&"unknown_item",
						t.resource_path,
						"%s: no live form card %s" % [r.id, r.card]
					)
				)
			for c in r.allowed + r.ruled:
				if not live.get(c, &"") in [&"pattern", &"secondary", &"element"]:
					issues.append(
						ValidationIssue.new(
							&"unknown_item",
							t.resource_path,
							"%s: no live pattern, secondary or element card %s" % [r.id, c]
						)
					)
	return issues
