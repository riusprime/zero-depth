class_name ContentDef
extends Resource
## Base for every content definition (CONTENT_SCHEMA §0): a stable id, a category, and validate().

@export var id: StringName


## The repository groups definitions by this name.
func category() -> StringName:
	return &""


func validate() -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	if String(id).is_empty():
		issues.append(ValidationIssue.new(&"id_empty", resource_path, "id is empty"))
	elif not RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(String(id)):
		issues.append(
			ValidationIssue.new(&"id_format", resource_path, "id must be snake_case: %s" % id)
		)
	return issues


## An ERROR if a non-zero duration rounds to 0 ticks at 60 Hz.
func check_duration(issues: Array[ValidationIssue], field: String, seconds: float) -> void:
	if seconds < 0.0:
		issues.append(
			ValidationIssue.new(&"duration_negative", resource_path, "%s is negative" % field)
		)
	elif seconds > 0.0 and int(round(seconds * 60.0)) == 0:
		issues.append(
			ValidationIssue.new(
				&"duration_zero_ticks", resource_path, "%s rounds to 0 ticks" % field
			)
		)


func check_positive(issues: Array[ValidationIssue], field: String, value: float) -> void:
	if value <= 0.0:
		issues.append(ValidationIssue.new(&"not_positive", resource_path, "%s must be > 0" % field))


## v0.4.0 SC: an ERROR unless `table` is a per-mille lookup table (scaling by floor or by danger tier): 1 to 64
## entries, the first exactly 1000 (×1), each entry in 1 .. 100000 (×100, which keeps the integer products the sim
## takes safe), and rising (`rising`, never lower than the one before) or falling (never higher).
func check_permille_table(
	issues: Array[ValidationIssue], field: String, table: PackedInt32Array, rising: bool
) -> void:
	if table.is_empty() or table.size() > 64:
		issues.append(
			ValidationIssue.new(&"table_size", resource_path, "%s needs 1 to 64 entries" % field)
		)
		return
	if table[0] != 1000:
		issues.append(
			ValidationIssue.new(&"table_start", resource_path, "%s must start at 1000" % field)
		)
	for k in table.size():
		if table[k] < 1 or table[k] > 100000:
			issues.append(
				ValidationIssue.new(
					&"table_range", resource_path, "%s[%d] is outside 1..100000" % [field, k]
				)
			)
		elif k > 0 and (table[k] < table[k - 1] if rising else table[k] > table[k - 1]):
			issues.append(
				ValidationIssue.new(
					&"table_order",
					resource_path,
					"%s[%d] goes the wrong way (%s)" % [field, k, "rising" if rising else "falling"]
				)
			)
