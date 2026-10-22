class_name CodexCatalog
extends RefCounted
## v0.7.5 CX (owner N6): every entry the Codex lists, read from the content (ContentRepository), so new cards, enemies,
## bosses and biomes appear without code (NB1 / NB2's biomes land on the Biomes page by their data alone).
## - Cards: the items, abilities and stat cards, minus the v0.6 cards `data/wand/migration.tres` retires and the
##   starting weapons (they are never a card). Sections (in this order): the Gun pool (wand cards that need the Gun),
##   the Blade pool, the shared pool (the other wand cards), the triggers, the legendary cards (legendary-rarity
##   items: the unique triggers), the stat cards, the utilities (Blink, Aegis), other abilities, and the passives
##   (the v0.5 items outside the wand that are still offered; WAND.md "Not in the table").
## - Enemies, bosses and biomes: every definition of their category. v0.8.0 FB1: the Bosses page has a second
##   section, the final boss's bodies (FinalBossDefinition, in the run's order), after the floors' bosses.
## Each entry is a Dictionary: page, id, section, name_key, desc_key, and by page: type (WorldReader.CARD_*), rarity
## (0 common, 1 rare, 2 epic, 3 legendary), leveled (it levels 1–5), alt_name_key (the Gun face of a two-faced
## card), desc_permille (a stat card's numbers at common rarity, per mille, for its sentence's %s), kind (an enemy's
## or boss's actor kind), palette (a biome's colours, ground first).
## The order inside a section is the content's (by id). Pure reads; nothing here touches a run.

const SECTIONS := {
	&"cards":
	[
		&"gun",
		&"blade",
		&"shared",
		&"triggers",
		&"legendary",
		&"stats",
		&"utilities",
		&"abilities",
		&"passives",
	],
	&"enemies": [&"enemies"],
	&"bosses": [&"bosses", &"final"],
	&"biomes": [&"biomes"],
}
const WAND_TAG := "wand"
const TRIGGER_TAG := "trigger"

var _entries := {}
var _index := {}
## Actor kind -> enemy id, and -> boss id (the recorder's per-tick lookups).
var _enemy_kinds := {}
var _boss_kinds := {}


func _init() -> void:
	for page: StringName in CodexStore.PAGES:
		_entries[page] = []


## The catalog of `repo` (the shipped content: ContentRepository.load_all()).
static func build(repo: ContentRepository) -> CodexCatalog:
	var c := CodexCatalog.new()
	var retired := retired_ids(repo)
	var sorted := {}
	for s: StringName in SECTIONS[&"cards"]:
		sorted[s] = []
	for def: ItemDefinition in repo.all_of(&"items"):
		if not retired.has(def.id):
			sorted[item_section(def)].append(_item_entry(def))
	for def: AbilityDefinition in repo.all_of(&"ability"):
		if retired.has(def.id) or def.start_weapon != &"":
			continue
		var util := def.tags.has(&"utility")
		sorted[&"utilities" if util else &"abilities"].append(_ability_entry(def, util))
	for def: StatCardDefinition in repo.all_of(&"stat_card"):
		sorted[&"stats"].append(_stat_entry(def))
	for s: StringName in SECTIONS[&"cards"]:
		for e: Dictionary in sorted[s]:
			c._add(e)
	for def: EnemyDefinition in repo.all_of(&"enemies"):
		(
			c
			. _add(
				{
					"page": &"enemies",
					"section": &"enemies",
					"id": def.id,
					"name_key": def.name_key,
					"desc_key": def.desc_key,
					"kind": ContentCompiler.compile_enemy(def).kind,
					"behaviour": def.behaviour_id,
				}
			)
		)
	for def: BossDefinition in repo.all_of(&"bosses"):
		(
			c
			. _add(
				{
					"page": &"bosses",
					"section": &"bosses",
					"id": def.id,
					"name_key": def.name_key,
					"desc_key": def.desc_key,
					"kind": int(ContentCompiler.BOSS_KINDS.get(def.id, -1)),
				}
			)
		)
	for def: BossDefinition in _final_bodies(repo):  # v0.8.0 FB1
		(
			c
			. _add(
				{
					"page": &"bosses",
					"section": &"final",
					"id": def.id,
					"name_key": def.name_key,
					"desc_key": def.desc_key,
					"kind": int(ContentCompiler.BOSS_KINDS.get(def.id, -1)),
				}
			)
		)
	for def: BiomeDefinition in repo.all_of(&"biomes"):
		var palette: Array[Color] = []
		for k in BiomeDefinition.PALETTE_KEYS:
			palette.append(def.palette.get(k, Color.GRAY))
		(
			c
			. _add(
				{
					"page": &"biomes",
					"section": &"biomes",
					"id": def.id,
					"name_key": def.name_key,
					"desc_key": def.desc_key,
					"palette": palette,
				}
			)
		)
	return c


## v0.8.0 FB1: the final boss's bodies in the run's order (RunDefinition.final_bosses), then any other by id.
static func _final_bodies(repo: ContentRepository) -> Array:
	var out := []
	var run: RunDefinition = repo.get_def(&"run", RunSaver.RUN_ID)
	if run != null:
		for id: StringName in run.final_bosses:
			var d := repo.get_def(&"final_bosses", id)
			if d != null:
				out.append(d)
	for d: ContentDef in repo.all_of(&"final_bosses"):
		if not out.has(d):
			out.append(d)
	return out


## The ids `data/wand/migration.tres` retires (never offered again, so never listed).
static func retired_ids(repo: ContentRepository) -> Dictionary:
	var out := {}
	for d: ContentDef in repo.all_of(&"wand"):
		if d is WandMigrationDefinition:
			for id in (d as WandMigrationDefinition).old_ids:
				out[id] = true
	return out


## The Cards page section of an item.
static func item_section(def: ItemDefinition) -> StringName:
	if def.rarity == ItemDefinition.Rarity.LEGENDARY:
		return &"legendary"
	if def.tags.has(TRIGGER_TAG):
		return &"triggers"
	if def.tags.has(WAND_TAG):
		match def.requires_weapon:
			&"gun":
				return &"gun"
			&"blade":
				return &"blade"
		return &"shared"
	return &"passives"


static func _item_entry(def: ItemDefinition) -> Dictionary:
	return {
		"page": &"cards",
		"section": item_section(def),
		"id": def.id,
		"name_key": def.name_key,
		"alt_name_key": def.name_key_gun,
		"desc_key": def.desc_key,
		"type": Offers.MOD,
		"rarity": ItemTable.tier_of(int(def.rarity)),  # v0.8.0 RR: the four tiers in order
		"leveled": def.tags.has(WAND_TAG),
	}


static func _ability_entry(def: AbilityDefinition, utility: bool) -> Dictionary:
	return {
		"page": &"cards",
		"section": &"utilities" if utility else &"abilities",
		"id": def.id,
		"name_key": def.name_key,
		"alt_name_key": &"",
		"desc_key": def.desc_key,
		"type": Offers.ABILITY,
		"rarity": int(def.rarity),
		"leveled": true,
	}


static func _stat_entry(def: StatCardDefinition) -> Dictionary:
	var nums := PackedInt32Array()
	if not def.amounts.is_empty():
		nums.append(int(round(def.amounts[0] * 10.0)))
	if not def.side.is_empty():
		nums.append(int(round(def.side[0] * 10.0)))
	return {
		"page": &"cards",
		"section": &"stats",
		"id": def.id,
		"name_key": def.name_key,
		"alt_name_key": &"",
		"desc_key": def.desc_key,
		"desc_permille": nums,
		"type": Offers.STAT,
		"rarity": 0,
		"leveled": false,
	}


func _add(e: Dictionary) -> void:
	var page: StringName = e["page"]
	_entries[page].append(e)
	_index["%s/%s" % [page, e["id"]]] = e
	if page == &"enemies" and not _enemy_kinds.has(e["kind"]):
		_enemy_kinds[e["kind"]] = e["id"]
	elif page == &"bosses" and int(e["kind"]) >= 0:
		_boss_kinds[e["kind"]] = e["id"]


## A page's entries, section by section.
func entries(page: StringName) -> Array:
	return _entries.get(page, [])


## A page's entries in one section.
func section_entries(page: StringName, section: StringName) -> Array:
	return entries(page).filter(func(e: Dictionary) -> bool: return e["section"] == section)


## The sections of a page that have entries, in order.
func sections(page: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: StringName in SECTIONS.get(page, []):
		if not section_entries(page, s).is_empty():
			out.append(s)
	return out


func has(page: StringName, id: StringName) -> bool:
	return _index.has("%s/%s" % [page, id])


func entry(page: StringName, id: StringName) -> Dictionary:
	return _index.get("%s/%s" % [page, id], {})


func size(page: StringName) -> int:
	return entries(page).size()


## The enemy id of actor kind `kind` (&"" when none).
func enemy_of_kind(kind: int) -> StringName:
	return _enemy_kinds.get(kind, &"")


## The boss id of actor kind `kind` (&"" when none).
func boss_of_kind(kind: int) -> StringName:
	return _boss_kinds.get(kind, &"")
