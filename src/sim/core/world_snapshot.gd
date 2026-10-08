class_name WorldSnapshot
extends RefCounted
## v0.4.0 SV: the canonical snapshot of a whole World as plain data (SIM_CONTRACTS §10b), and its restore. Pure: no
## file I/O (the application's RunSaveStore writes the bytes).
##
## Every script variable of World, and of every state object it holds (STATE_CLASSES), is copied field by field,
## so state a workstream adds later is snapshotted without a list to keep. What is NOT copied is named here:
## - WORLD_KEPT: World fields the base world already has, because it was built from the same generation inputs
##   (the run seed, the floor, the build, the content), or that are derived and rebuilt on restore;
## - LOADOUT_CLASSES: content tables compiled at setup and never written in play, kept wherever they appear.
## An object of a class in neither list is an error naming it (the guard test fails), never a silent skip.
##
## Restore (apply) writes the snapshot into a base World built the way the original was: same seed, floor and
## loadout, any tick. Packed arrays are duplicated both ways, so a snapshot never shares memory with a world.

const FORMAT := 1
const CLASS_KEY := "@class"
## An Array[Obb] (the walls) is copied as packed columns: a dictionary per wall cost ~1.4 ms a snapshot.
const OBBS := &"Obb[]"
## World fields not copied field by field, and why. A value of "rebuilt" means apply() derives it again.
const WORLD_KEPT := {
	&"player": "loadout",
	&"enemy_tables": "loadout",
	&"encounter": "loadout",
	&"spawner": "loadout",
	&"floor_layout": "loadout (generated from the floor seed)",
	&"item_tables": "loadout",
	&"boss_tables": "loadout",
	&"reward_table": "loadout",
	&"gamble_table": "loadout",
	&"combo_tables": "loadout",
	&"ability_tables": "loadout",
	&"stat_tables": "loadout",
	&"_events": "the presentation's event log, not state (its counter _event_seq is copied)",
	&"_wall_grid": "rebuilt: derived from walls",
	&"_wall_next": "setup (prepare_wall): only whether it is still pending is copied",
	&"_nav_next": "setup (prepare_wall): only whether it is still pending is copied",
	&"nav": "rebuilt from walls; its last flood (dist, the flood key) is copied",
}
## Content tables: compiled from content at setup, read-only in play (the guard test checks they don't change).
const LOADOUT_CLASSES: Array[StringName] = [
	&"PlayerTable",
	&"EnemyTable",
	&"EncounterTable",
	&"SpawnTable",
	&"FloorLayout",
	&"ItemTable",
	&"BossTable",
	&"RewardTable",
	&"GambleTable",
	&"ComboTable",
	&"AbilityTable",
	&"StatTable",
	&"HeatTable",
	&"BossAttackTable",
	&"SwingStep",
	&"SkillTable",
]
## State objects: every script variable is copied.
const STATE_CLASSES: Array[StringName] = [
	&"RngStream",
	&"ActorStore",
	&"ProjectileStore",
	&"PickupStore",
	&"MineStore",
	&"BossStore",
	&"RewardStore",
	&"AbilityState",
	&"KitState",
	&"HeatState",
	&"PlayerBuildState",
	&"ProcLedger",
	&"BossFlow",
	&"ItemMods",
	&"DenseGrid",
	&"Obb",
]

## script_fields' cache (Script -> Array[StringName]); derived from the class declarations only.
static var _fields := {}


## The snapshot of `w` between ticks. `errors` (optional) collects every unclassified object found.
static func take(w: World, errors: PackedStringArray = PackedStringArray()) -> Dictionary:
	var data := _encode_object(w, WORLD_KEPT, "World", errors)
	data[&"nav"] = {
		"size": w.nav.size, "dist": w.nav.dist.duplicate(), "flooded": w.nav.get(&"_flooded")
	}
	data[&"_wall_next"] = w.get(&"_wall_next") != null
	data[&"_nav_next"] = w.get(&"_nav_next") != null
	return {"format": FORMAT, "world": data}


## Writes `snap` into `base` (a World built from the same generation inputs). Returns "" or what went wrong; on an
## error the base is partly written and must be dropped.
static func apply(base: World, snap: Dictionary) -> String:
	if int(snap.get("format", -1)) != FORMAT or typeof(snap.get("world")) != TYPE_DICTIONARY:
		return "snapshot format %s, expected %d" % [str(snap.get("format")), FORMAT]
	var data: Dictionary = snap["world"]
	var walls_before := base.walls.size()
	# The base's walls come from generating the floor; the snapshot's start with the same ones (walls are only ever
	# added in play). A difference means another floor or other content: the save doesn't fit this build.
	var saved: Dictionary = data.get(&"walls", {})
	var built := _encode_obbs(base.walls)
	var saved_c: PackedVector2Array = saved.get("center", PackedVector2Array())
	if saved_c.size() < walls_before or saved_c.slice(0, walls_before) != built["center"]:
		return "World.walls: the snapshot's floor differs from the one generated from its inputs"
	# The boss door sealed in play: add it the way play did (its prepared flow field swaps in, no rebuild).
	var door: Obb = base.get(&"_wall_next")
	if (
		door != null
		and saved_c.size() == walls_before + 1
		and saved_c[walls_before] == door.center
		and not bool(data.get(&"_wall_next", true))
	):
		base.add_wall_now(door)
		walls_before += 1
	var err := _apply_object(base, data, WORLD_KEPT, "World")
	if err != "":
		return err
	if base.walls.size() != walls_before:  # any other wall added in play: the grid and field are rebuilt
		base.set_walls(base.walls)
	var nav: Dictionary = data.get(&"nav", {})
	if nav.get("size") != base.nav.size:
		return (
			"World.nav: field size %s, the rebuilt walls give %s" % [nav.get("size"), base.nav.size]
		)
	base.nav.dist = (nav["dist"] as PackedInt32Array).duplicate()
	base.nav.set(&"_flooded", nav["flooded"])
	for f: StringName in [&"_wall_next", &"_nav_next"]:
		if not bool(data.get(f, false)):
			base.set(f, null)
		elif base.get(f) == null:
			return "World.%s: pending in the snapshot, missing in the base" % f
	return ""


## The script variables of `obj`, in declaration order (cached per script: a class's fields don't change).
static func script_fields(obj: Object) -> Array[StringName]:
	var s: Script = obj.get_script()
	if s != null and _fields.has(s):
		return _fields[s]
	var out: Array[StringName] = []
	for p: Dictionary in obj.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(StringName(p["name"]))
	if s != null:
		_fields[s] = out
	return out


## The global class name of a script instance ("" for a plain Object).
static func class_of(obj: Object) -> StringName:
	var s: Script = obj.get_script()
	return s.get_global_name() if s != null else &""


static func _encode_object(
	obj: Object, kept: Dictionary, where: String, errors: PackedStringArray
) -> Dictionary:
	var out := {CLASS_KEY: class_of(obj)}
	for f in script_fields(obj):
		if kept.has(f):
			continue
		var v: Variant = obj.get(f)
		out[f] = _encode(v, "%s.%s" % [where, f], errors) if _is_ref(v) else _copy(v)
	return out


## Objects, arrays and dictionaries are copied deeply (_encode); the rest by _copy.
static func _is_ref(v: Variant) -> bool:
	var t := typeof(v)
	return t == TYPE_OBJECT or t == TYPE_ARRAY or t == TYPE_DICTIONARY


static func _encode(v: Variant, where: String, errors: PackedStringArray) -> Variant:
	match typeof(v):
		TYPE_OBJECT:
			if v == null:
				return null
			var cls := class_of(v)
			if STATE_CLASSES.has(cls):
				return _encode_object(v, {}, where, errors)
			if not LOADOUT_CLASSES.has(cls):
				(
					errors
					. append(
						(
							(
								"%s holds a %s: add it to WorldSnapshot.STATE_CLASSES (copy its fields) or "
								+ "LOADOUT_CLASSES (content, never written in play)"
							)
							% [where, cls if cls != &"" else "plain Object"]
						)
					)
				)
			return null
		TYPE_ARRAY:
			var arr: Array = v
			if arr.get_typed_script() == Obb:
				return _encode_obbs(arr)
			var out := []
			for i in arr.size():
				out.append(
					(
						_encode(arr[i], "%s[%d]" % [where, i], errors)
						if _is_ref(arr[i])
						else _copy(arr[i])
					)
				)
			return out
		TYPE_DICTIONARY:
			var out := {}
			var d: Dictionary = v
			for k: Variant in d:
				out[k] = (
					_encode(d[k], "%s[%s]" % [where, str(k)], errors)
					if _is_ref(d[k])
					else _copy(d[k])
				)
			return out
	return _copy(v)


## Value types as they are; packed arrays duplicated (a packed array read from a field is shared with it).
static func _copy(v: Variant) -> Variant:
	if typeof(v) >= TYPE_PACKED_BYTE_ARRAY:
		return (v as Variant).duplicate()
	return v


static func _apply_object(obj: Object, data: Dictionary, kept: Dictionary, where: String) -> String:
	if StringName(data.get(CLASS_KEY, &"")) != class_of(obj):
		return (
			"%s: a %s in the snapshot, a %s in the base"
			% [where, data.get(CLASS_KEY), class_of(obj)]
		)
	for f in script_fields(obj):
		if kept.has(f):
			continue
		if not data.has(f):
			return "%s.%s: not in the snapshot" % [where, f]
		var cur: Variant = obj.get(f)
		var r: Array = _decode(cur, data[f], "%s.%s" % [where, f])
		if r[1] != "":
			return r[1]
		if typeof(cur) != TYPE_ARRAY and typeof(cur) != TYPE_DICTIONARY:
			obj.set(f, r[0])
	return ""


## [value, error]. Objects, arrays and dictionaries are written in place into `cur` when it has the same shape (typed
## arrays keep their type); value types are returned for the caller to set.
static func _decode(cur: Variant, v: Variant, where: String) -> Array:
	if typeof(v) == TYPE_DICTIONARY and (v as Dictionary).get(CLASS_KEY) == OBBS:
		if typeof(cur) != TYPE_ARRAY:
			return [null, "%s: walls in the snapshot, no array in the base" % where]
		_decode_obbs(cur, v)
		return [cur, ""]
	if typeof(v) == TYPE_DICTIONARY and (v as Dictionary).has(CLASS_KEY):
		var cls := StringName(v[CLASS_KEY])
		var target: Object = cur if typeof(cur) == TYPE_OBJECT and cur != null else _make(cls)
		if target == null:
			return [null, "%s: can't make a %s" % [where, cls]]
		return [target, _apply_object(target, v, {}, where)]
	if typeof(cur) == TYPE_OBJECT and cur != null and v == null:
		var cls := class_of(cur)
		return [cur if LOADOUT_CLASSES.has(cls) else null, ""]
	if typeof(v) == TYPE_ARRAY and typeof(cur) == TYPE_ARRAY:
		var arr: Array = cur
		arr.clear()
		var src: Array = v
		for i in src.size():
			var r: Array = _decode(null, src[i], "%s[%d]" % [where, i])
			if r[1] != "":
				return r
			arr.append(r[0])
		return [arr, ""]
	if typeof(v) == TYPE_DICTIONARY and typeof(cur) == TYPE_DICTIONARY:
		var d: Dictionary = cur
		d.clear()
		var src: Dictionary = v
		for k: Variant in src:
			var r: Array = _decode(null, src[k], "%s[%s]" % [where, str(k)])
			if r[1] != "":
				return r
			d[k] = r[0]
		return [d, ""]
	if typeof(v) == TYPE_ARRAY or typeof(v) == TYPE_DICTIONARY:
		return [(v as Variant).duplicate(true), ""]
	return [_copy(v), ""]


## A fresh state object for a class the base didn't hold (an element of an array, such as a wall added in play).
static func _make(cls: StringName) -> Object:
	match cls:
		&"Obb":
			return Obb.new()
		&"RngStream":
			return RngStream.new()
		&"ActorStore":
			return ActorStore.new()
		&"ProjectileStore":
			return ProjectileStore.new()
		&"PickupStore":
			return PickupStore.new()
		&"MineStore":
			return MineStore.new()
		&"BossStore":
			return BossStore.new()
		&"RewardStore":
			return RewardStore.new()
		&"AbilityState":
			return AbilityState.new()
		&"KitState":
			return KitState.new()
		&"PlayerBuildState":
			return PlayerBuildState.new()
		&"ProcLedger":
			return ProcLedger.new()
		&"BossFlow":
			return BossFlow.new()
		&"ItemMods":
			return ItemMods.new()
		&"DenseGrid":
			return DenseGrid.new()
	return null  # HeatState needs its table: a base without heat can't take a snapshot with it


static func _encode_obbs(arr: Array) -> Dictionary:
	var c := PackedVector2Array()
	var h := PackedVector2Array()
	var a := PackedInt32Array()
	var u := PackedVector2Array()
	var v := PackedVector2Array()
	for o: Obb in arr:
		c.append(o.center)
		h.append(o.half)
		a.append(o.angle)
		u.append(o.axis_u)
		v.append(o.axis_v)
	return {CLASS_KEY: OBBS, "center": c, "half": h, "angle": a, "axis_u": u, "axis_v": v}


static func _decode_obbs(arr: Array, d: Dictionary) -> void:
	arr.clear()
	var c: PackedVector2Array = d["center"]
	var h: PackedVector2Array = d["half"]
	var a: PackedInt32Array = d["angle"]
	var u: PackedVector2Array = d["axis_u"]
	var v: PackedVector2Array = d["axis_v"]
	for i in c.size():
		var o := Obb.new()
		o.center = c[i]
		o.half = h[i]
		o.angle = a[i]
		o.axis_u = u[i]
		o.axis_v = v[i]
		arr.append(o)
