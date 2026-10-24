class_name Wardrobe
extends RefCounted
## v0.9.0 RB (owner, PLAN "Owner decisions" RB; docs/roadmap/v0.9.0/AFFINITIES.md): the hub Wardrobe's choices in the
## profile, and the run's affinity built from content. The profile's `loadout` section holds the robe (`robe`, a
## RobeDefinition id) and the affinity (`affinity`, an AffinityDefinition id); a profile from before RB has neither and
## reads as Cream and None (no profile version change: missing keys fall back here). The robe is cosmetic; the
## affinity is copied into the run when it starts (RunState.affinity) and stays locked for that run.
## Locked robes: a robe that isn't `free` is worn only once its id is in the profile's `unlocks.robes` list. MP (Rune
## Fragments): the Progression Station buys Night, Canyon, Frost and Moss (MetaProgress.buy_robe calls unlock_robe);
## MP2 adds the two epic robes (The Fallen's regalia, shown as "???" until bought, and the divine Hollow Crown). A
## profile from before MP2 keeps every id it owns: the list only ever grows, so no migration.

const NONE := &"none"
const DEFAULT_ROBE := &"cream"
## MP2: a hidden robe's name until it is bought.
const HIDDEN_NAME := &"ROBE_HIDDEN"


## True for an affinity id that is not None (&"" or &"none").
static func has_affinity(id: StringName) -> bool:
	return id != &"" and id != NONE


## The build last picked at the Portal Machine (the same `loadout` section; Blade on a fresh profile).
static func build_of(profile: ProfileStore) -> StringName:
	return StringName(String(profile.section("loadout").get("build", "blade")))


## The hero's look for a run: the worn robe (the profile's) and the run's locked affinity.
static func hero_look(
	repo: ContentRepository, profile: ProfileStore, affinity: StringName
) -> Dictionary:
	return look(repo, worn_robe(repo, profile), affinity)


static func robe_of(profile: ProfileStore) -> StringName:
	return StringName(String(profile.section("loadout").get("robe", String(DEFAULT_ROBE))))


static func affinity_of(profile: ProfileStore) -> StringName:
	return StringName(String(profile.section("loadout").get("affinity", String(NONE))))


static func set_robe(profile: ProfileStore, id: StringName) -> void:
	profile.section("loadout")["robe"] = String(id)


static func set_affinity(profile: ProfileStore, id: StringName) -> void:
	profile.section("loadout")["affinity"] = String(id)


## The robes in Wardrobe order.
static func robes(repo: ContentRepository) -> Array:
	return _sorted(repo.all_of(&"robe"))


## The affinities in Wardrobe order (None first).
static func affinities(repo: ContentRepository) -> Array:
	return _sorted(repo.all_of(&"affinity"))


static func _sorted(defs: Array) -> Array:
	var out := defs.duplicate()
	out.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a.order) < int(b.order))
	return out


## The robe `def` may be worn: free, or bought (its id in unlocks.robes).
static func robe_unlocked(profile: ProfileStore, def: RobeDefinition) -> bool:
	if def == null:
		return false
	if def.free:
		return true
	var list: Variant = profile.section("unlocks").get("robes", [])
	return list is Array and (list as Array).has(String(def.id))


## MP's hook: robe `id` bought (kept in the profile's unlocks).
static func unlock_robe(profile: ProfileStore, id: StringName) -> void:
	var u := profile.section("unlocks")
	var list: Array = u.get("robes", []) if u.get("robes", []) is Array else []
	if not list.has(String(id)):
		list.append(String(id))
	u["robes"] = list


## MP2: robe `def`'s name as shown: "???" (ROBE_HIDDEN) for a hidden robe not bought yet, else its own name key.
static func shown_name(profile: ProfileStore, def: RobeDefinition) -> StringName:
	if def != null and def.hidden and not robe_unlocked(profile, def):
		return HIDDEN_NAME
	return def.name_key if def != null else HIDDEN_NAME


## The robe the hero wears: the profile's, when it exists and is unlocked; else Cream.
static func worn_robe(repo: ContentRepository, profile: ProfileStore) -> RobeDefinition:
	var def: RobeDefinition = repo.get_def(&"robe", robe_of(profile))
	if def == null or not robe_unlocked(profile, def):
		def = repo.get_def(&"robe", DEFAULT_ROBE)
	return def


## The affinity the next run starts with: the profile's, when it exists; else None.
static func chosen_affinity(repo: ContentRepository, profile: ProfileStore) -> StringName:
	var id := affinity_of(profile)
	return id if has_affinity(id) and repo.get_def(&"affinity", id) != null else NONE


## The hero's look for the presentation: the robe's cloak and underside, its epic style (MP2: &"fallen", &"divine";
## &"" for a colour robe; EpicRobeView builds it), and the rune's colour and glyph (glyph 0 and no rune for None).
## `affinity` is the run's (locked) or, in the hub, the profile's choice.
static func look(repo: ContentRepository, robe: RobeDefinition, affinity: StringName) -> Dictionary:
	var out := {
		"cloak": robe.cloak if robe != null else Color("#EBDCCB"),
		"under": robe.underside if robe != null else Color("#C9B8A6"),
		"style": robe.style if robe != null else &"",
		"rune": Color.WHITE,
		"glyph": 0,
	}
	var a: AffinityDefinition = (
		repo.get_def(&"affinity", affinity) if has_affinity(affinity) else null
	)
	if a != null:
		out["rune"] = a.color
		out["glyph"] = a.glyph
	return out
