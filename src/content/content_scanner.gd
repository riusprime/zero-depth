class_name ContentScanner
extends RefCounted
## Finds resources under a folder by their logical names, in the editor and inside exported packs
## (CONTENT_SCHEMA §1). ResourceLoader.list_directory (4.4+) is remap-safe; it isn't recursive, so folders
## (entries ending in "/") are walked here. Deathventory's DirAccess scan shipped empty exports (LESSONS L4).


## Every .tres under root, sorted.
static func scan(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	_walk(root.trim_suffix("/"), out)
	out.sort()
	return out


static func _walk(dir: String, out: PackedStringArray) -> void:
	for entry in ResourceLoader.list_directory(dir):
		if entry.ends_with("/"):
			_walk(dir.path_join(entry.trim_suffix("/")), out)
		elif entry.ends_with(".tres"):
			out.append(dir.path_join(entry))
