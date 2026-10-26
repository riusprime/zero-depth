class_name MetaProgress
extends RefCounted
## v0.9.0 MP (PLAN W49-W52, Q28; LOCKED_DECISIONS PD-06: sideways only): the profile's Rune Fragments and the forms
## they gate, in the profile's `progress` section (ProfileStore version 2):
## - `fragments`: the balance; `earned`: every fragment ever banked (a record, never spent);
## - `portal`: the player has travelled through a Purple Portal (owner: "void unlocked when traveling through a purple
##   portal, lance is unlocked by default"): until then RuneFragmentsDefinition.portal_unlocks (the Void) is out of
##   every offer of a new run (RunState.locked_cards -> World.locked_items).
## A run earns fragments in the sim (RunState.total_fragments); the run's end banks them here (MetaHooks). The
## Progression Station spends them on the robes (price_of; Wardrobe.unlock_robe). Nothing here is a stat.

const DEF_ID := &"rune_fragments"


static func fresh() -> Dictionary:
	return {"fragments": 0, "earned": 0, "portal": false}


static func fragments(profile: ProfileStore) -> int:
	return maxi(0, int(profile.section("progress").get("fragments", 0)))


static func earned(profile: ProfileStore) -> int:
	return maxi(0, int(profile.section("progress").get("earned", 0)))


## Banks `n` fragments (a run's tally) into the balance and the lifetime count.
static func bank(profile: ProfileStore, n: int) -> void:
	if n <= 0:
		return
	var p := profile.section("progress")
	p["fragments"] = fragments(profile) + n
	p["earned"] = earned(profile) + n


## The content's fragment rules (null when the content has none).
static func definition(repo: ContentRepository) -> RuneFragmentsDefinition:
	return repo.get_def(&"rune_fragments", DEF_ID) as RuneFragmentsDefinition


## The sim's FragmentTable from the content (null: the run earns none).
static func compile_table(repo: ContentRepository) -> FragmentTable:
	var d := definition(repo)
	if d == null:
		return null
	var t := FragmentTable.new()
	t.floor_cleared = d.floor_cleared
	t.boss = d.boss
	t.secret = d.secret
	t.purple_portal = d.purple_portal
	t.final_boss = d.final_boss
	t.collectible = d.collectible
	return t


static func portal_travelled(profile: ProfileStore) -> bool:
	return bool(profile.section("progress").get("portal", false))


## Marks the Purple Portal travelled; true the first time (the unlock's toast).
static func travel_portal(profile: ProfileStore) -> bool:
	if portal_travelled(profile):
		return false
	profile.section("progress")["portal"] = true
	return true


## The card ids a new run starts with locked: the portal's forms until the profile has travelled through one.
static func locked_cards(repo: ContentRepository, profile: ProfileStore) -> Array[StringName]:
	var out: Array[StringName] = []
	if not portal_travelled(profile):
		out = portal_cards(repo)
	return out


## The forms a Purple Portal unlocks (RuneFragmentsDefinition.portal_unlocks; none without the content).
static func portal_cards(repo: ContentRepository) -> Array[StringName]:
	var out: Array[StringName] = []
	var d := definition(repo)
	if d != null:
		out.assign(d.portal_unlocks)
	return out


## The item indices of `ids` among the compiled `items` (an id the content lacks is skipped), ascending.
static func locked_items(ids: Array[StringName], items: Array[ItemTable]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in items.size():
		if ids.has(items[k].id):
			out.append(k)
	return out


## What the Progression Station sells: the robes not free, in Wardrobe order (the four, then the two epic robes;
## PD-06: nothing that is a stat).
static func wares(repo: ContentRepository) -> Array:
	return Wardrobe.robes(repo).filter(
		func(r: RobeDefinition) -> bool: return not r.free and String(r.unlock_hint_key).is_empty()
	)


## v0.9.0 MP2 (owner, PLAN "Owner decisions" MP2: "ascending cost starting from 75 and 25 more each one, then 250 the
## epic robe"): what robe `def` costs now: its `price`, plus its `price_step` for each robe of the ladder (a robe with
## a step) the profile already owns. The four robes cost 75, 100, 125, 150 in the order bought; the epic robes 250.
static func price_of(repo: ContentRepository, profile: ProfileStore, def: RobeDefinition) -> int:
	if def == null:
		return 0
	if def.price_step <= 0:
		return def.price
	var bought := 0
	for r: RobeDefinition in wares(repo):
		if r.price_step > 0 and Wardrobe.robe_unlocked(profile, r):
			bought += 1
	return def.price + def.price_step * bought


## Buys robe `def` with fragments at its price now (price_of): false when it is free, already owned or too dear.
static func buy_robe(repo: ContentRepository, profile: ProfileStore, def: RobeDefinition) -> bool:
	if def == null or Wardrobe.robe_unlocked(profile, def):
		return false
	var cost := price_of(repo, profile, def)
	if fragments(profile) < cost:
		return false
	profile.section("progress")["fragments"] = fragments(profile) - cost
	Wardrobe.unlock_robe(profile, def.id)
	return true
