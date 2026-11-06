class_name RunicLinesDefinition
extends ContentDef
## v0.9.5 RS1 (RUNIC_STONE.md): the Runic Stone's lines, in the order the easter eggs were written (r1, r2, ...). A
## line is learned in the profile's `runes` section by its id; what triggers each one is the application's
## (RunicStone). The English is the cipher's plain text and is never shown (no translation, by design).

static var _line_id_re := RegEx.create_from_string("^r[0-9]+$")
static var _text_re := RegEx.create_from_string("^[A-Z]+( [A-Z]+)*$")

@export var lines: Array[RunicLineEntry] = []


func category() -> StringName:
	return &"runic_lines"


func line(line_id: StringName) -> RunicLineEntry:
	for l in lines:
		if l != null and l.id == line_id:
			return l
	return null


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var seen := {}
	if lines.is_empty():
		issues.append(ValidationIssue.new(&"runic_empty", resource_path, "no lines"))
	for l in lines:
		if l == null:
			issues.append(ValidationIssue.new(&"runic_null", resource_path, "a line is empty"))
			continue
		if not _line_id_re.search(String(l.id)):
			issues.append(
				ValidationIssue.new(&"runic_id", resource_path, "line id %s is not rN" % l.id)
			)
		if seen.has(l.id):
			issues.append(ValidationIssue.new(&"runic_dup", resource_path, "line %s twice" % l.id))
		seen[l.id] = true
		if not _text_re.search(l.english):
			issues.append(
				ValidationIssue.new(
					&"runic_text", resource_path, "%s: only A-Z and single spaces" % l.id
				)
			)
	return issues
