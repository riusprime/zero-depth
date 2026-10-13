class_name WandMigrationDefinition
extends ContentDef
## v0.6.5 WN5b (docs/design/WAND.md "What happens to the v0.6 cards", owner G1 "Approve all"; CONTENT_SCHEMA "The
## wand"): the one table that retires the v0.6 cards and says what each becomes. One `.tres` in data/wand/.
## - Row k: the old card `old_ids[k]` (an item id or an ability id) is retired: no altar, chest, shop, event, core or
##   legendary tier offers it again. It is not deleted, so old saves and item indices still resolve, and the dev
##   panel can still grant it.
## - What it becomes in a held build (an old save's wand, a carry): `blade_into[k]` on a Blade run, `gun_into[k]` on a
##   Gun run; an empty id means no match: the card is refunded as shards (the shop's salvage price, WandMigration).
## - `pending`: target ids another step brings (the shared pool S1–S7, built by WN5a in parallel). A target in this
##   list may be missing from the data; until it exists a held card mapped to it is refunded.

@export var old_ids: Array[StringName] = []
@export var blade_into: Array[StringName] = []
@export var gun_into: Array[StringName] = []
@export var pending: Array[StringName] = []


func category() -> StringName:
	return &"wand"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if blade_into.size() != old_ids.size() or gun_into.size() != old_ids.size():
		issues.append(
			ValidationIssue.new(
				&"table_size", resource_path, "old_ids, blade_into and gun_into need one entry each"
			)
		)
	var seen := {}
	for id in old_ids:
		if String(id).is_empty():
			issues.append(ValidationIssue.new(&"missing", resource_path, "an empty old id"))
		elif seen.has(id):
			issues.append(ValidationIssue.new(&"duplicate_id", resource_path, "%s twice" % id))
		seen[id] = true
	for k in mini(old_ids.size(), mini(blade_into.size(), gun_into.size())):
		if seen.has(blade_into[k]) or seen.has(gun_into[k]):
			issues.append(
				ValidationIssue.new(
					&"retired_target", resource_path, "%s maps onto a retired card" % old_ids[k]
				)
			)
	return issues


## Every old id names an item or an ability; every target is an item of the data, or a pending one.
static func cross_check(defs: Array[ContentDef]) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var known := {}
	var items := {}
	for d in defs:
		if d is ItemDefinition:
			known[d.id] = true
			items[d.id] = true
		elif d is AbilityDefinition:
			known[d.id] = true
	for d in defs:
		var m := d as WandMigrationDefinition
		if m == null:
			continue
		for id in m.old_ids:
			if not known.has(id):
				issues.append(
					ValidationIssue.new(&"unknown_item", m.resource_path, "no card %s" % id)
				)
		for id in m.blade_into + m.gun_into:
			if String(id).is_empty() or items.has(id) or m.pending.has(id):
				continue
			issues.append(
				ValidationIssue.new(&"unknown_item", m.resource_path, "no target item %s" % id)
			)
	return issues
