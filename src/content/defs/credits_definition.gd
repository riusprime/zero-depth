class_name CreditsDefinition
extends ContentDef
## The credits screen's data (PLAN v0.0.1 Step 11). The owner's credit line is a key whose text arrives with
## owner action O4; licence texts are shown untranslated (legal text).

@export var owner_key: StringName = &"CREDITS_OWNER"
@export var made_with_key: StringName = &"CREDITS_MADE_WITH"
@export var font_name := "Atkinson Hyperlegible"
@export var font_licence_path := "res://assets/fonts/OFL.txt"


func category() -> StringName:
	return &"credits"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if not FileAccess.file_exists(font_licence_path):
		issues.append(
			ValidationIssue.new(
				&"missing_file", resource_path, "font licence %s is missing" % font_licence_path
			)
		)
	return issues
