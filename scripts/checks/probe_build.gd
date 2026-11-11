extends RefCounted
## The frame probe's build (scripts/checks/frame_probe.gd): which cards the Gun is given before the measured fight.
## Probe-only, never loaded by the game.
## By default the Gun gets BUILD_KEYS at BUILD_LEVEL; --heavy adds HEAVY_KEYS at HEAVY_LEVEL.
## --cards=<id[:level],id[:level],...> grants exactly the named cards instead of BUILD_KEYS (item or ability ids as in
## data/items and data/abilities, level BUILD_LEVEL when none is given), so a scene can be "Gun + Ring" alone;
## --cards=none is the Gun alone:
##   ... -s scripts/checks/frame_probe.gd -- --cards=gun_ring
##   ... -s scripts/checks/frame_probe.gd -- --cards=gun_ring,gun_seekers,storm_core:5
## A card that is not in the catalog, that the Gun can't use, or whose grant does not take (the card is not held
## afterwards) is an error: the probe reports it and quits with a non-zero code instead of measuring another build.

## [name_key] of the cards granted at BUILD_LEVEL: Gun forms and two elements (fire and lightning).
const BUILD_KEYS: Array[StringName] = [
	&"ITEM_GUN_GLAIVE",
	&"ITEM_GUN_RING",
	&"ITEM_SPLIT_SHOT",
	&"ITEM_EMBER_CORE",
	&"ITEM_STORM_CORE",
]
const BUILD_LEVEL := 3
## The extra cards of --heavy, at HEAVY_LEVEL.
const HEAVY_KEYS: Array[StringName] = [
	&"ITEM_GUN_TWIN",
	&"ITEM_HALO_SHOT",
	&"ITEM_GUN_RAPID_FIRE",
	&"ITEM_WILDFIRE",
	&"ITEM_CHAIN_BLAST",
	&"ITEM_GUN_RUNE_EXPLOSION",
]
const HEAVY_LEVEL := 5

var heavy := false  # --heavy
var cards: PackedStringArray = []  # --cards, as given ("none": the Gun alone)
var exact := false  # --cards was given
## The report's build line: every card asked for, with its level, or why it is missing.
var names: PackedStringArray = []


## Takes the option `s` (without its "--"); false when it is not one of this file's.
func parse(s: String) -> bool:
	if s == "heavy":
		heavy = true
	elif s.begins_with("cards="):
		exact = true
		cards = s.trim_prefix("cards=").split(",", false)
		if cards.has("none"):
			cards.remove_at(cards.find("none"))
	else:
		return false
	return true


## The report's description of the build.
func describe() -> String:
	var what := (
		"exactly the --cards"
		if exact
		else "at level %d (Glaive, Ring, Split, fire core, lightning core)" % BUILD_LEVEL
	)
	return (
		"build: Gun + "
		+ ", ".join(names)
		+ "  ("
		+ what
		+ (" + the --heavy cards at level %d" % HEAVY_LEVEL if heavy else "")
		+ ")"
	)


## Grants the build through the Playground's own take. Returns the errors (empty: every card is held).
func grant(api: PlaygroundApi) -> PackedStringArray:
	names.clear()
	var errors: PackedStringArray = []
	if not exact:
		_grant_keys(api, BUILD_KEYS, BUILD_LEVEL, errors)
	else:
		for c in cards:
			var p := c.split(":", false)
			var level := int(p[1]) if p.size() > 1 else BUILD_LEVEL
			var code := _code_of(api.world, StringName(p[0]))
			_take(api, code, String(p[0]), level, errors)
	if heavy:
		_grant_keys(api, HEAVY_KEYS, HEAVY_LEVEL, errors)
	return errors


func _grant_keys(
	api: PlaygroundApi, keys: Array[StringName], level: int, errors: PackedStringArray
) -> void:
	var codes := {}
	for e: Dictionary in api.catalog():
		if keys.has(e["name_key"]):
			codes[e["name_key"]] = int(e["code"])
	for k in keys:
		_take(api, int(codes.get(k, -1)), String(k), level, errors)


## One card in, checked: the grant must say yes and the card must be held after it.
func _take(
	api: PlaygroundApi, code: int, label: String, level: int, errors: PackedStringArray
) -> void:
	if code < 0:
		names.append("%s (NOT IN THE CATALOG)" % label)
		errors.append("%s is not a card the Gun can be given here" % label)
		return
	var ok := api.grant_now(code, level)
	if not ok or not BuildSlots.held(api.world, code):
		names.append("%s (GRANT FAILED)" % label)
		errors.append(
			"%s: grant_now said %s, held %s" % [label, ok, BuildSlots.held(api.world, code)]
		)
		return
	names.append("%s L%d" % [label, level])


## The Offers code of the item or ability `id` in the catalog (usable by this build), or -1.
static func _code_of(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k if ItemPool.usable(w, k) else -1
	for a in w.ability_tables.size():
		if w.ability_tables[a].id == id:
			return Offers.ability_code(a)
	return -1
