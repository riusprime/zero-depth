class_name DevFields
extends RefCounted
## What the dev panel shows (docs/tools/DEV_PANEL.md): the groups of content it covers, and every tunable field of a
## definition found by reflection, so new fields and new content files show up without touching the panel ("add
## everything": owner, 2026-10-12). A field is a number, a toggle or a colour; arrays, dictionaries and nested
## resources (attacks, phases, swings) are walked, and their entries get paths like "attacks/0/damage".

## Group key -> [title key, content folders, field filter ("" = all fields, "mood" = only the mood)].
const GROUPS := [
	["lighting", "UI_DEVM_G_LIGHTING", ["res://data/biomes"], "mood"],
	[
		"player",
		"UI_DEVM_G_PLAYER",
		["res://data/player", "res://data/builds", "res://data/heat"],
		""
	],
	["enemies", "UI_DEVM_G_ENEMIES", ["res://data/enemies"], ""],
	["sim", "UI_DEVM_G_SIM", ["res://data/tuning"], ""],
	["bosses", "UI_DEVM_G_BOSSES", ["res://data/bosses", "res://data/boss_pools"], ""],
	[
		"difficulty",
		"UI_DEVM_G_DIFFICULTY",
		[
			"res://data/spawning",
			"res://data/curves",
			"res://data/run",
			"res://data/scaling",
			"res://data/arenas",
			"res://data/overrun",
		],
		"",
	],
	[
		"economy",
		"UI_DEVM_G_ECONOMY",
		[
			"res://data/rewards",
			"res://data/shop",
			"res://data/gamble",
			"res://data/legendary",
			"res://data/event_rules",
			"res://data/events",
			"res://data/curses",
		],
		"",
	],
	[
		"build",
		"UI_DEVM_G_BUILD",
		[
			"res://data/items",
			"res://data/modifiers",
			"res://data/abilities",
			"res://data/combos",
			"res://data/stat_cards",
		],
		"",
	],
]
## Never shown: identity, text and engine fields.
const SKIP := [
	"id",
	"script",
	"resource_local_to_scene",
	"resource_name",
	"resource_path",
	"resource_scene_unique_id"
]
const MAX_DEPTH := 5


## The content files of group `g` (a GROUPS row), sorted.
static func sources(g: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for dir: String in g[2]:
		for path in ContentScanner.scan(dir):
			out.append(path)
	out.sort()
	return out


## Every tunable field of `res` under `filter` ("" = all): [{path, value}] in declaration order.
static func rows(res: Resource, filter: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if filter != "":
		_walk(res.get(filter), filter, out, 0)
	else:
		_walk(res, "", out, 0)
	return out


static func _walk(v: Variant, path: String, out: Array[Dictionary], depth: int) -> void:
	if depth > MAX_DEPTH:
		return
	if _leaf(v):
		out.append({"path": path, "value": v})
	elif v is Resource:
		for p: Dictionary in (v as Resource).get_property_list():
			var name: String = p["name"]
			if name in SKIP or not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
				continue
			if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			_walk((v as Resource).get(name), _join(path, name), out, depth + 1)
	elif v is Dictionary:
		var keys := (v as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for k: Variant in keys:
			_walk(v[k], _join(path, str(k)), out, depth + 1)
	elif DevTuning._is_list(v):
		for i in v.size():
			_walk(v[i], _join(path, str(i)), out, depth + 1)


static func _leaf(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_COLOR]


static func _join(a: String, b: String) -> String:
	return b if a == "" else a + "/" + b


## The name a source shows in the list: its file name without the extension ("arc_caster").
static func label_of(path: String) -> String:
	return path.get_file().get_basename()
