class_name AchievementBook
extends RefCounted
## v0.7.5 AC (owner N7): every achievement the game has, from the content (`data/achievements/*.tres`,
## AchievementDefinition), with a CODEX_EACH definition expanded into one achievement per Codex entry (CodexCatalog),
## so a new boss or biome in the data has its own. It answers what each one needs and how far along the profile is
## (AchievementStore for what unlocked and the run counters, CodexStore for the Codex's counters). Pure reads; the
## tracker decides when to unlock.
##
## Each achievement is a Dictionary: id, def_id, group, order, glyph, hidden, kind, stat, page, section, counter,
## target, name_key, desc_key, and, for one expanded from CODEX_EACH, entry_id and arg_key (the entry's own name key,
## the %s in its name and sentence).

var store: AchievementStore
var codex: CodexStore
var catalog: CodexCatalog
var _list: Array[Dictionary] = []
var _index := {}


func _init(p_store: AchievementStore, p_codex: CodexStore, p_catalog: CodexCatalog) -> void:
	store = p_store
	codex = p_codex
	catalog = p_catalog


## The book of `repo`'s achievement definitions.
static func build(
	repo: ContentRepository, p_store: AchievementStore, p_codex: CodexStore, p_catalog: CodexCatalog
) -> AchievementBook:
	var b := AchievementBook.new(p_store, p_codex, p_catalog)
	var defs: Array = repo.all_of(&"achievements")
	defs.sort_custom(
		func(x: AchievementDefinition, y: AchievementDefinition) -> bool:
			var gx := AchievementDefinition.GROUPS.find(x.group)
			var gy := AchievementDefinition.GROUPS.find(y.group)
			return [gx, x.order, String(x.id)] < [gy, y.order, String(y.id)]
	)
	for def: AchievementDefinition in defs:
		if def.kind == AchievementDefinition.Kind.CODEX_EACH:
			for e: Dictionary in b._scope(def.page, def.section):
				var a := _from(def)
				a["id"] = StringName("%s_%s" % [def.id, e["id"]])
				a["entry_id"] = e["id"]
				a["arg_key"] = e["name_key"]
				b._add(a)
		else:
			b._add(_from(def))
	return b


static func _from(def: AchievementDefinition) -> Dictionary:
	return {
		"id": def.id,
		"def_id": def.id,
		"group": def.group,
		"order": def.order,
		"glyph": def.glyph,
		"hidden": def.hidden,
		"kind": def.kind,
		"stat": def.stat,
		"page": def.page,
		"section": def.section,
		"counter": def.counter,
		"target": def.target,
		"name_key": def.name_key,
		"desc_key": def.desc_key,
		"entry_id": &"",
		"arg_key": &"",
	}


func _add(a: Dictionary) -> void:
	if _index.has(a["id"]):
		push_error("AchievementBook: duplicate achievement id %s" % a["id"])
		return
	_list.append(a)
	_index[a["id"]] = a


## The Codex entries a CODEX_EACH / CODEX_EVERY achievement reads: a page, or one section of it.
func _scope(page: StringName, section: StringName) -> Array:
	return catalog.entries(page) if section == &"" else catalog.section_entries(page, section)


## Every achievement, in the page's order (group, then order, then id; an expanded one in its Codex order).
func all() -> Array[Dictionary]:
	return _list


func size() -> int:
	return _list.size()


func has(id: StringName) -> bool:
	return _index.has(id)


func get_entry(id: StringName) -> Dictionary:
	return _index.get(id, {})


## The groups that hold achievements, in order.
func groups() -> Array[StringName]:
	var out: Array[StringName] = []
	for g: StringName in AchievementDefinition.GROUPS:
		if _list.any(func(a: Dictionary) -> bool: return a["group"] == g):
			out.append(g)
	return out


func in_group(group: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in _list:
		if a["group"] == group:
			out.append(a)
	return out


func is_unlocked(id: StringName) -> bool:
	return store.is_unlocked(id)


func unlocked_count() -> int:
	var n := 0
	for a in _list:
		n += 1 if store.is_unlocked(a["id"]) else 0
	return n


## How far along `a` is, in its own units, capped at its goal (goal()).
func progress(a: Dictionary) -> int:
	return mini(_value(a), goal(a))


## What `a` needs: its target, or for CODEX_EVERY the number of entries in its scope.
func goal(a: Dictionary) -> int:
	if int(a["kind"]) == AchievementDefinition.Kind.CODEX_EVERY:
		return maxi(1, _scope(a["page"], a["section"]).size())
	return int(a["target"])


## True when the profile meets `a`'s condition (whether or not it is unlocked yet).
func met(a: Dictionary) -> bool:
	return _value(a) >= goal(a)


func _value(a: Dictionary) -> int:
	var page: StringName = a["page"]
	var counter: StringName = a["counter"]
	match int(a["kind"]):
		AchievementDefinition.Kind.STAT:
			return store.stat(a["stat"])
		AchievementDefinition.Kind.CODEX_TOTAL:
			return codex.total(page, counter)
		AchievementDefinition.Kind.CODEX_MAX:
			var best := 0
			for id in codex.unlocked_ids(page):
				best = maxi(best, codex.count(page, id, counter))
			return best
		AchievementDefinition.Kind.CODEX_EACH:
			return _entry_value(page, a["entry_id"], counter)
		AchievementDefinition.Kind.CODEX_EVERY:
			var n := 0
			for e: Dictionary in _scope(page, a["section"]):
				n += 1 if _entry_value(page, e["id"], counter) >= int(a["target"]) else 0
			return n
	return 0


## An entry's counter, or 1 / 0 for met / not met when `counter` is empty.
func _entry_value(page: StringName, id: StringName, counter: StringName) -> int:
	if counter == &"":
		return 1 if codex.is_unlocked(page, id) else 0
	return codex.count(page, id, counter)


## The achievements whose condition reads Codex page `page`.
func reading_page(page: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in _list:
		if int(a["kind"]) != AchievementDefinition.Kind.STAT and a["page"] == page:
			out.append(a)
	return out


## The achievements whose condition reads run counter `key`.
func reading_stat(key: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in _list:
		if int(a["kind"]) == AchievementDefinition.Kind.STAT and a["stat"] == key:
			out.append(a)
	return out
