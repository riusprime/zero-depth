class_name PatchNotesDefinition
extends ContentDef
## One version's patch notes for the in-game What's New panel. Exports drop *.md, so
## scripts/content/build_patch_notes.gd copies docs/patch-notes/vX.Y.Z(.es).md into data/patch_notes/.

@export var version := ""
@export_multiline var body_en := ""
@export_multiline var body_es := ""


func category() -> StringName:
	return &"patch_notes"


static func id_for(p_version: String) -> StringName:
	return StringName("v" + p_version.replace(".", "_"))


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if not RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$").search(version):
		issues.append(
			ValidationIssue.new(&"version_format", resource_path, "bad version: %s" % version)
		)
	elif id != id_for(version):
		issues.append(
			ValidationIssue.new(&"id_mismatch", resource_path, "id must be %s" % id_for(version))
		)
	if body_en.strip_edges().is_empty() or body_es.strip_edges().is_empty():
		issues.append(
			ValidationIssue.new(&"missing_text", resource_path, "both languages are required")
		)
	return issues
