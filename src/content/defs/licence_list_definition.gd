class_name LicenceListDefinition
extends ContentDef
## v0.7.5 SM (owner N8; ROADMAP v0.9.x "Final credits and licenses"): the credits' generated part, one entry per
## source the repo holds: each asset manifest's licence line (the owner's art, models and textures, the generated
## audio), each font's licence and each addon's licence (marked when the export leaves it out). Written by
## scripts/content/build_credits.gd from the repo (never by hand); tests/content/test_credits_licences.gd checks the
## committed copy matches a fresh build. Godot's own licence and notices come from the engine at run time
## (CreditsView). The texts are legal and provenance text, shown untranslated (like the licence texts).

## The kind of each entry.
const KIND_ASSETS := 0
const KIND_FONT := 1
const KIND_ADDON := 2

## KIND_* per entry.
@export var kinds := PackedInt32Array()
## The entry's name (the manifest's folder, the font's name, the addon's name and version).
@export var titles := PackedStringArray()
## Where it came from in the repo (the manifest, the licence file).
@export var sources := PackedStringArray()
## The licence or provenance line (with the file count), and for a font or an addon its licence's full text.
@export var bodies := PackedStringArray()
## 1 when the export ships it; 0 for an addon the export's exclude filter leaves out (a tool, not shipped).
@export var shipped := PackedByteArray()


func category() -> StringName:
	return &"licences"


func count() -> int:
	return titles.size()


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var n := titles.size()
	if kinds.size() != n or sources.size() != n or bodies.size() != n or shipped.size() != n:
		issues.append(
			ValidationIssue.new(
				&"size_mismatch", resource_path, "every list needs one entry per title"
			)
		)
	for k in mini(n, bodies.size()):
		if bodies[k].strip_edges().is_empty():
			issues.append(
				ValidationIssue.new(&"missing_text", resource_path, "%s has no licence" % titles[k])
			)
	return issues
