class_name DevTuning
extends RefCounted
## The dev panel's tuning store (docs/tools/DEV_PANEL.md, owner 2026-10-12: "a master dev panel … all the variables
## that affect the balancing of the game"). An override is a key `<content path>|<field path>` and a value; the field
## path walks exported fields, array indices and dictionary keys ("attacks/0/damage", "behaviour_params/cooldown_s").
## apply() writes every override into the loaded definitions and holds them (Godot keeps one instance per .tres
## while it is held, so every later ContentRepository.load_all() and compile sees them) and puts back the shipped
## value of any override that was removed. Overrides are kept in user://dev_tuning.json between launches.
## Lighting (a biome's mood) is not a balance tweak: balance_tweaked() ignores it (LOCKED_DECISIONS, 2026-10-12).

const SAVE_PATH := "user://dev_tuning.json"
const SEP := "|"
## The field (and its sub-fields) that is lighting only: a biome's mood.
const LIGHTING_FIELD := "mood"

## key -> value.
var overrides := {}
var save_path := SAVE_PATH
## key -> the shipped value, captured the first time the key is touched.
var _shipped := {}
## Keys whose shipped value must go back on the next apply().
var _restore := {}
## Content path -> the loaded definition this store wrote into. Godot frees a loaded resource (and drops it from its
## cache) once nothing holds it, and the next load reads the file again; holding it keeps the edit.
var _held := {}


static func key_of(res_path: String, field_path: String) -> String:
	return res_path + SEP + field_path


static func split_key(key: String) -> PackedStringArray:
	return PackedStringArray([key.get_slice(SEP, 0), key.get_slice(SEP, 1)])


## A store read from `path` (empty when there is no file or it doesn't parse).
static func load_saved(path: String = SAVE_PATH) -> DevTuning:
	var t := DevTuning.new()
	t.save_path = path
	if not FileAccess.file_exists(path):
		return t
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and (data as Dictionary).get("overrides") is Dictionary:
		for k: String in data["overrides"]:
			t.overrides[k] = _from_json(data["overrides"][k])
	return t


func save() -> void:
	var out := {}
	for k: String in overrides:
		out[k] = _to_json(overrides[k])
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": 1, "overrides": out}, "\t", true))


## Sets field `field_path` of the definition at `res_path` to `value` (typed like the shipped value); a value equal
## to the shipped one removes the override.
func set_value(res_path: String, field_path: String, value: Variant) -> void:
	var key := key_of(res_path, field_path)
	var shipped: Variant = shipped_value(key)
	value = _typed(value, shipped)
	if _same(value, shipped):
		clear(key)
		return
	overrides[key] = value
	_restore.erase(key)


func clear(key: String) -> void:
	if overrides.has(key):
		overrides.erase(key)
		_restore[key] = true


func reset_all() -> void:
	for k: String in overrides.keys():
		clear(k)


## Writes the overrides into the loaded definitions, and the shipped values back where an override went.
func apply() -> void:
	for k: String in _restore:
		if _shipped.has(k):
			_write(k, _shipped[k])
	_restore.clear()
	for k: String in overrides.keys():  # a copy: the loop retypes the values
		overrides[k] = _typed(overrides[k], shipped_value(k))  # JSON reads every number as a float
		_write(k, overrides[k])


## The value the game ships with for `key` (read from the definition before any override touched it).
func shipped_value(key: String) -> Variant:
	if not _shipped.has(key):
		var v: Variant = current_value(key)
		if overrides.has(key) and _same(v, overrides[key]):
			# Already written this session before the shipped value was captured: reload it from disk.
			var parts := split_key(key)
			var fresh: Resource = ResourceLoader.load(
				parts[0], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
			)
			v = read(fresh, parts[1]) if fresh != null else v
		_shipped[key] = _copy(v)
	return _shipped[key]


## The value the loaded definition holds now.
func current_value(key: String) -> Variant:
	var parts := split_key(key)
	var res: Resource = load(parts[0]) if ResourceLoader.exists(parts[0]) else null
	return read(res, parts[1]) if res != null else null


func is_overridden(key: String) -> bool:
	return overrides.has(key)


## True while any balance value differs from the shipped game (the DEV mark; tweaked runs don't count).
func balance_tweaked() -> bool:
	for k: String in overrides:
		if not is_lighting(k):
			return true
	return false


static func is_lighting(key: String) -> bool:
	var field := split_key(key)[1]
	return field == LIGHTING_FIELD or field.begins_with(LIGHTING_FIELD + "/")


## One line per change, for the owner to paste back: `data/enemies/grunt.tres  hp: 30 -> 45`.
func copy_text() -> String:
	var keys := overrides.keys()
	keys.sort()
	var lines := PackedStringArray()
	for k: String in keys:
		var parts := split_key(k)
		(
			lines
			. append(
				(
					"%s  %s: %s -> %s"
					% [
						parts[0].trim_prefix("res://"),
						parts[1],
						_show(shipped_value(k)),
						_show(overrides[k]),
					]
				)
			)
		)
	return "\n".join(lines)


# --- Field paths ---------------------------------------------------------------------------------------------------
## The value at `field_path` under `root` (null when the path doesn't exist).
static func read(root: Variant, field_path: String) -> Variant:
	var v: Variant = root
	for seg: String in field_path.split("/"):
		v = _child(v, seg)
		if v == null:
			return null
	return v


func _write(key: String, value: Variant) -> void:
	var parts := split_key(key)
	if not ResourceLoader.exists(parts[0]):
		return
	var res: Resource = load(parts[0])
	_held[parts[0]] = res
	_set_path(res, parts[1].split("/"), _copy(value))


## Sets the value at `segs` under `node`; packed arrays are copies in GDScript, so each level is written back.
static func _set_path(node: Variant, segs: PackedStringArray, value: Variant) -> Variant:
	var seg := segs[0]
	if segs.size() == 1:
		return _assign(node, seg, value)
	var child: Variant = _child(node, seg)
	if child == null:
		return node
	var rest := segs.slice(1)
	var new_child: Variant = _set_path(child, rest, value)
	return _assign(node, seg, new_child)


static func _child(node: Variant, seg: String) -> Variant:
	if node is Object:
		return (node as Object).get(seg)
	if node is Dictionary:
		var d: Dictionary = node
		if d.has(seg):
			return d[seg]
		if d.has(StringName(seg)):
			return d[StringName(seg)]
		return null
	if _is_list(node) and seg.is_valid_int():
		var i := int(seg)
		return node[i] if i >= 0 and i < node.size() else null
	return null


static func _assign(node: Variant, seg: String, value: Variant) -> Variant:
	if node is Object:
		(node as Object).set(seg, value)
	elif node is Dictionary:
		var d: Dictionary = node
		d[StringName(seg) if d.has(StringName(seg)) else seg] = value
	elif _is_list(node) and seg.is_valid_int():
		var i := int(seg)
		if i >= 0 and i < node.size():
			node[i] = value
	return node


static func _is_list(v: Variant) -> bool:
	return (
		v is Array
		or v is PackedInt32Array
		or v is PackedInt64Array
		or v is PackedFloat32Array
		or v is PackedFloat64Array
	)


# --- Values --------------------------------------------------------------------------------------------------------
static func _typed(value: Variant, like: Variant) -> Variant:
	match typeof(like):
		TYPE_INT:
			return int(round(float(value)))
		TYPE_FLOAT:
			return float(value)
		TYPE_BOOL:
			return bool(value)
		TYPE_COLOR:
			return value if value is Color else _from_json(value)
	return value


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return is_equal_approx(float(a), float(b))
	if a is Color and b is Color:
		return (a as Color).is_equal_approx(b)
	return a == b


static func _copy(v: Variant) -> Variant:
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	return v


static func _show(v: Variant) -> String:
	if v is float:
		return String.num(v, 4)
	if v is Color:
		var c: Color = v
		return (
			"Color(%s, %s, %s, %s)"
			% [String.num(c.r, 3), String.num(c.g, 3), String.num(c.b, 3), String.num(c.a, 3)]
		)
	return str(v)


static func _to_json(v: Variant) -> Variant:
	if v is Color:
		var c: Color = v
		return {"color": [c.r, c.g, c.b, c.a]}
	return v


static func _from_json(v: Variant) -> Variant:
	if v is Dictionary and (v as Dictionary).has("color"):
		var a: Array = v["color"]
		return Color(a[0], a[1], a[2], a[3])
	return v
