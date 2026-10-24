class_name CollectibleBook
extends RefCounted
## v0.9.0 CL (owner: "collectibles are fine", COLLECTIBLES.md as drafted; PLAN W38-W40, W43, W47): the Rune Archive's
## collectibles (CollectibleDefinition, data/collectibles/) and the profile's record of them, the `collectibles`
## section of user://profile.json (ProfileStore version 3): one key per collectible found, its id, holding the run
## seed it was found in (0 for the hub's). HubFlags' `count:collectibles:N` counts the keys (the floor runes, the north
## gate at 12). Found once per profile: a run starts with the profile's found ones in RunState.collected, so no floor
## arms them again (arm). Each find is written to the profile the moment it is taken (MetaHooks.observe), so a death
## never loses it, and gives the MP fragment (RuneFragments.add_collectibles; the Keystone banks its own at once).

const SECTION := "collectibles"
## The shelves' title keys, in shelf order.
const SHELF_KEYS := {
	&"stone": &"COLLECTIBLE_SHELF_STONE",
	&"sealed": &"COLLECTIBLE_SHELF_SEALED",
	&"crown": &"COLLECTIBLE_SHELF_CROWN",
	&"hub": &"COLLECTIBLE_SHELF_HUB",
}
## The glyph a find's toast shows (AchievementGlyphs), by shelf.
const SHELF_GLYPHS := {&"stone": &"shard", &"sealed": &"gate", &"crown": &"crown", &"hub": &"star"}
const HEADER_KEY := &"COLLECTIBLE_TOAST"

static var _colors := {}


## Every collectible of the content, in shelf order (`order`).
static func defs(repo: ContentRepository) -> Array[CollectibleDefinition]:
	var out: Array[CollectibleDefinition] = []
	for d: ContentDef in repo.all_of(&"collectible"):
		out.append(d as CollectibleDefinition)
	out.sort_custom(
		func(a: CollectibleDefinition, b: CollectibleDefinition) -> bool: return a.order < b.order
	)
	return out


## Every collectible's colour by id (the views' pickups), read from the shipped content once per process.
static func colors() -> Dictionary:
	if _colors.is_empty():
		for d in defs(ContentRepository.load_all()):
			_colors[d.id] = d.color
	return _colors


## The collectible whose source is `source` (the first in shelf order), or null.
static func of_source(repo: ContentRepository, source: StringName) -> CollectibleDefinition:
	for d in defs(repo):
		if d.source == source:
			return d
	return null


# --- The profile ---------------------------------------------------------------------------------------------------


static func fresh() -> Dictionary:
	return {}


## Whether the profile has found `id`.
static func found(profile: ProfileStore, id: StringName) -> bool:
	return profile.section(SECTION).has(String(id))


## The ids the profile has found.
static func found_ids(profile: ProfileStore) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in profile.section(SECTION).keys():
		out.append(StringName(String(k)))
	return out


static func count(profile: ProfileStore) -> int:
	return profile.section(SECTION).size()


## Records `id` as found (in run `run_seed`; 0: the hub). Returns false when the profile already had it.
static func record(profile: ProfileStore, id: StringName, run_seed: int = 0) -> bool:
	var s := profile.section(SECTION)
	if s.has(String(id)):
		return false
	s[String(id)] = run_seed
	return true


## One bool per collectible in shelf order: found.
static func found_flags(profile: ProfileStore, all: Array[CollectibleDefinition]) -> Array[bool]:
	var out: Array[bool] = []
	for d in all:
		out.append(found(profile, d.id))
	return out


## A find's toast (AchievementToast.push): "Added to the Rune Archive", its name and lore line.
static func toast_of(d: CollectibleDefinition) -> Dictionary:
	return {
		"id": d.id,
		"glyph": SHELF_GLYPHS.get(d.shelf, &"star"),
		"header_key": HEADER_KEY,
		"name_key": d.name_key,
		"desc_key": d.lore_key,
	}


# --- A floor's collectibles ----------------------------------------------------------------------------------------


## Arms `w`'s collectibles (FloorPlan, after the floor's secrets, shrine and Lockdowns, or the final arena's fight):
## each one of `all` the run hasn't collected (RunState.collected) whose source this floor has (`biome`: the floor's
## BiomeDefinition id). No-op when none fits (World.collect stays null).
static func arm(
	w: World, run: RunState, all: Array[CollectibleDefinition], biome: StringName
) -> void:
	var stone_taken := false
	for id in run.collected_run:
		for d in all:
			stone_taken = stone_taken or (d.id == id and d.source == &"hidden_room")
	for d in all:
		if run.collected.has(d.id):
			continue
		var s := _source_of(w, run, d, biome, stone_taken)
		if s >= 0:
			Collectibles.arm(w, d.id, s, _param_of(run, d))
	if w.collect != null:
		w.collect.marked_before = run.marked_done


static func _source_of(
	w: World, run: RunState, d: CollectibleDefinition, biome: StringName, stone_taken: bool
) -> int:
	var final := run.final_fight
	var s := -1
	match d.source:
		&"hidden_room":
			if not final and not stone_taken and d.biome == biome and _has_crack(w):
				s = Collectibles.Source.HIDDEN_ROOM
		&"rune_alignment":
			if not final and w.runes != null and run.floor_index >= d.floor_min:
				s = Collectibles.Source.RUNE_ALIGNMENT
		&"timed_door":
			if not final and w.timed != null and run.floor_index >= d.floor_min:
				s = Collectibles.Source.TIMED_DOOR
		&"hazard_lockdown":
			if not final and _has_hazard(w):
				s = Collectibles.Source.HAZARD_LOCKDOWN
		&"purple_portal":
			if not final and run.is_deep():
				s = Collectibles.Source.PURPLE_PORTAL
		&"blood_shrine":
			if not final and w.shrine != null and w.shrine.kind == ShrineTable.Kind.BLOOD:
				s = Collectibles.Source.BLOOD_SHRINE
		&"fountain":
			var has := w.shrine != null and w.shrine.fountain_entry >= 0
			if not final and has and run.is_last_floor():
				s = Collectibles.Source.FOUNTAIN
		&"rune_markings":
			if not final and (w.timed != null or w.runes != null or _has_crack(w)):
				s = Collectibles.Source.MARKINGS
		&"final_body":
			if final and run.table.final_bosses.has(d.body):
				s = Collectibles.Source.FINAL_BODY
	return s


static func _param_of(run: RunState, d: CollectibleDefinition) -> int:
	match d.source:
		&"rune_markings":
			return d.count
		&"final_body":
			return run.table.final_bosses.find(d.body)  # its place in the fight (FinalFight.phase)
	return 0


static func _has_crack(w: World) -> bool:
	return w.breakables != null and w.breakables.has_crack()


static func _has_hazard(w: World) -> bool:
	var f := w.floor_layout
	return w.lockdown != null and f != null and f.lockdown_kinds.has(LockdownTable.Kind.HAZARD)
