extends SceneTree
## Copies every docs/patch-notes/vX.Y.Z.md (+ .es.md) into data/patch_notes/vX.Y.Z.tres for the in-game
## What's New panel (exports drop *.md). Run after editing patch notes:
## godot --headless --path . -s scripts/content/build_patch_notes.gd

const SRC := "res://docs/patch-notes/"
const OUT := "res://data/patch_notes/"


func _initialize() -> void:
	var failed := false
	for def in build_all():
		var path := OUT + "v" + def.version + ".tres"
		if ResourceSaver.save(def, path) != OK:
			push_error("could not write " + path)
			failed = true
		else:
			print("wrote ", path)
	quit(1 if failed else 0)


## The definitions the docs describe, newest file names first. Tests compare these with the committed copies.
static func build_all() -> Array[PatchNotesDefinition]:
	var out: Array[PatchNotesDefinition] = []
	var re := RegEx.create_from_string("^v(\\d+\\.\\d+\\.\\d+)\\.md$")
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(SRC)):
		var m := re.search(f)
		if m == null:
			continue
		var def := PatchNotesDefinition.new()
		def.version = m.get_string(1)
		def.id = PatchNotesDefinition.id_for(def.version)
		def.body_en = FileAccess.get_file_as_string(SRC + f)
		def.body_es = FileAccess.get_file_as_string(SRC + f.replace(".md", ".es.md"))
		out.append(def)
	return out
