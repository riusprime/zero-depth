class_name SharedContent
extends RefCounted
## v0.11.1 Step 3 (audit T4): the game's content for tests, loaded once per process instead of once per case.
## Test-side only.
##
## What is shared, and why it is safe:
## - repo(): one ContentRepository over res://data. The definitions in it are the resource cache's, the same objects a
##   fresh ContentRepository.load_all() hands out, so sharing the repository shares nothing new; it saves the folder
##   scan. A test that edits a definition edits a duplicate (as the tests do today), and a test that edits the
##   repository itself, checks its errors after an edit, or loads another root keeps its own load_all().
## - room_layouts(): the designed room interiors (RunContentCompiler.compile_room_layouts). Nothing writes into them:
##   FloorGenerator and RoomLayouts only read them, and a test that wants other layouts assigns a dictionary of its own.
## - boss_pools(floors): each floor's boss pool, as a deep copy on every call, so a caller may change what it gets.
##
## Not cached here: the tables a World holds (player, enemies, bosses, items, rewards, the gamble, the wand and slot
## tables, the legendary and loot pacing tables, abilities, ...). The run scales its enemies and bosses in place, and
## tests set fields on them (w.reward_table.heal_orb_meter, w.item_tables[i].slot_category, w.loot_pacing.*); the
## tables are RefCounted and have no copy, so every world compiles its own. FloorParams is not cached either:
## FloorShape.size_floor writes the floor's room range into it, so a test file keeps its own map.

static var _repo: ContentRepository
static var _room_layouts: Variant = null
static var _boss_pools := {}


## The shared repository over res://data (loaded on the first call).
static func repo() -> ContentRepository:
	if _repo == null:
		_repo = ContentRepository.load_all()
	return _repo


## The compiled room layouts by footprint (shared, read-only).
static func room_layouts() -> Dictionary:
	if _room_layouts == null:
		_room_layouts = RunContentCompiler.compile_room_layouts(repo())
	return _room_layouts


## Every floor's boss pool for a run of `floors` floors (a deep copy each call).
static func boss_pools(floors: int) -> Array[PackedInt32Array]:
	if not _boss_pools.has(floors):
		_boss_pools[floors] = RunContentCompiler.compile_boss_pools(repo(), floors)
	var pools: Array[PackedInt32Array] = _boss_pools[floors]
	return pools.duplicate(true)
