class_name PairingSetDefinition
extends ContentDef
## The enemy pairings (v0.10.5 O15; CONTENT_SCHEMA §7): authored duos the spawner adds to a pack. See PairingRow.

@export var rows: Array[PairingRow] = []


func category() -> StringName:
	return &"pairing"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if rows.is_empty():
		issues.append(ValidationIssue.new(&"pairing_empty", resource_path, "no pairing rows"))
	for k in rows.size():
		var r := rows[k]
		if r == null:
			issues.append(
				ValidationIssue.new(&"pairing_null", resource_path, "row %d is empty" % k)
			)
			continue
		if r.lead_id == &"" or r.partner_id == &"":
			issues.append(
				ValidationIssue.new(&"pairing_kind", resource_path, "row %d lacks a kind" % k)
			)
		if r.from_floor < 1 or r.from_floor > 9:
			issues.append(
				ValidationIssue.new(&"pairing_floor", resource_path, "row %d from_floor" % k)
			)
		if r.chance_permille < 1 or r.chance_permille > 1000:
			issues.append(
				ValidationIssue.new(&"pairing_chance", resource_path, "row %d chance 1..1000" % k)
			)
		if r.partners < 1 or r.partners > 3:
			issues.append(
				ValidationIssue.new(&"pairing_count", resource_path, "row %d partners 1..3" % k)
			)
		if r.placement < 0 or r.placement >= PairingRow.PLACEMENTS.size():
			issues.append(
				ValidationIssue.new(&"pairing_place", resource_path, "row %d placement" % k)
			)
		if r.name_key == &"":
			issues.append(
				ValidationIssue.new(&"pairing_name", resource_path, "row %d name_key" % k)
			)
	return issues
