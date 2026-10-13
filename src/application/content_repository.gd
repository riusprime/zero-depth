class_name ContentRepository
extends RefCounted
## Loads every definition under a root through ContentScanner and indexes it by category and id. Validation and
## the manifest hash over canonical property values (CONTENT_SCHEMA §1) are computed on first ask and cached:
## errors() and manifest_hash(). It lives in application because the hash uses the sim's CanonicalValue, and
## content may not import upward.
## The game reads the errors once per root per process, at the first load (each one is pushed to the log as an
## error); a dev panel edit (DevTuning.apply) asks for a fresh check, since it writes into the loaded definitions, and
## what that check finds is logged as a warning (a deliberate balance tweak, such as one Arc Caster spell's damage,
## may break a content rule on purpose).

## Roots whose content the game has checked (and logged) since the last content edit.
static var _checked_roots := {}
## True once a dev panel edit has written into the loaded definitions (DevTuning.apply).
static var _dev_edited := false

var by_category := {}
var paths := PackedStringArray()
## Every loaded definition, in scan order.
var _defs: Array[ContentDef] = []
## Files under the root that are not definitions (found while loading).
var _load_issues: Array[ValidationIssue] = []
## Cached on first ask (null / "": not computed yet).
var _issues: Variant = null
var _manifest_hash := ""


static func load_all(root: String = "res://data") -> ContentRepository:
	var repo := ContentRepository.new()
	repo.paths = ContentScanner.scan(root)
	for path in repo.paths:
		var res := load(path)
		if res is ContentDef:
			repo._defs.append(res)
		else:
			repo._load_issues.append(
				ValidationIssue.new(&"unsupported_resource", path, "not a ContentDef")
			)
	for d in repo._defs:
		var cat := String(d.category())
		if not repo.by_category.has(cat):
			repo.by_category[cat] = {}
		repo.by_category[cat][String(d.id)] = d
	if not _checked_roots.has(root):
		_checked_roots[root] = true
		repo.log_errors()
	return repo


## Forgets which roots were checked, so the next load validates (and logs) again: the dev panel calls it after it
## writes into the loaded definitions.
static func recheck() -> void:
	_checked_roots.clear()
	_dev_edited = true


## Pushes each content error to the log (the shipped content has none; a test asserts it): an error, or a warning
## once the dev panel has edited the content.
func log_errors() -> void:
	for i in errors():
		var line := "content: %s %s: %s" % [i.path, i.code, i.message]
		if _dev_edited:
			push_warning(line + " (after a dev panel edit)")
		else:
			push_error(line)


func get_def(category: StringName, id: StringName) -> ContentDef:
	return by_category.get(String(category), {}).get(String(id), null)


## Every definition in a category, by id.
func all_of(category: StringName) -> Array:
	var cat: Dictionary = by_category.get(String(category), {})
	var keys := cat.keys()
	keys.sort()
	return keys.map(func(k: String) -> ContentDef: return cat[k])


func count(category: StringName) -> int:
	return by_category.get(String(category), {}).size()


## Every validation issue (a file that is not a definition, then ContentValidator's), computed on first ask.
func issues() -> Array[ValidationIssue]:
	if _issues == null:
		var all: Array[ValidationIssue] = _load_issues.duplicate()
		all.append_array(ContentValidator.validate(_defs))
		_issues = all
	return _issues


func errors() -> Array[ValidationIssue]:
	return ContentValidator.errors(issues())


## The manifest hash over every definition's canonical values, computed on first ask.
func manifest_hash() -> String:
	if _manifest_hash.is_empty():
		_manifest_hash = _manifest(_defs)
	return _manifest_hash


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
