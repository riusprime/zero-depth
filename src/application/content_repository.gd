class_name ContentRepository
extends RefCounted
## Loads every definition under a root through ContentScanner, indexes it by category and id, validates it,
## and computes the manifest hash over canonical property values (CONTENT_SCHEMA §1). It lives in application
## because the hash uses the sim's CanonicalValue, and content may not import upward.

var by_category := {}
var issues: Array[ValidationIssue] = []
var manifest_hash := ""
var paths := PackedStringArray()


static func load_all(root: String = "res://data") -> ContentRepository:
	var repo := ContentRepository.new()
	var defs: Array[ContentDef] = []
	repo.paths = ContentScanner.scan(root)
	for path in repo.paths:
		var res := load(path)
		if res is ContentDef:
			defs.append(res)
		else:
			repo.issues.append(
				ValidationIssue.new(&"unsupported_resource", path, "not a ContentDef")
			)
	repo.issues.append_array(ContentValidator.validate(defs))
	for d in defs:
		var cat := String(d.category())
		if not repo.by_category.has(cat):
			repo.by_category[cat] = {}
		repo.by_category[cat][String(d.id)] = d
	repo.manifest_hash = _manifest(defs)
	return repo


func get_def(category: StringName, id: StringName) -> ContentDef:
	return by_category.get(String(category), {}).get(String(id), null)


func count(category: StringName) -> int:
	return by_category.get(String(category), {}).size()


func errors() -> Array[ValidationIssue]:
	return ContentValidator.errors(issues)


static func _manifest(defs: Array[ContentDef]) -> String:
	var rows := []
	for d in defs:
		rows.append([String(d.category()), String(d.id), canonical(d)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return [a[0], a[1]] < [b[0], b[1]])
	return CanonicalValue.sha256_hex(rows)


## A resource's storage properties as plain data (nested resources recurse; paths are left out, because they
## differ between the project and an export).
static func canonical(res: Resource) -> Dictionary:
	var out := {}
	for prop in res.get_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_STORAGE):
			continue
		var name: String = prop["name"]
		if (
			name
			in [
				"script",
				"resource_path",
				"resource_name",
				"resource_local_to_scene",
				"resource_scene_unique_id"
			]
		):
			continue
		out[name] = _plain(res.get(name))
	return out


static func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_OBJECT:
			return canonical(v) if v is Resource else null
		TYPE_COLOR:
			var c: Color = v
			return [c.r, c.g, c.b, c.a]
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _plain(v[k])
			return d
		TYPE_ARRAY:
			return (v as Array).map(_plain)
		TYPE_STRING_NAME:
			return String(v)
		_:
			return v
