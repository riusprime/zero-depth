class_name CollectibleDefinition
extends ContentDef
## v0.9.0 CL (owner: "collectibles are fine", COLLECTIBLES.md as drafted; PLAN W38-W40, W43, W47): one of the Rune
## Archive's collectibles. Category `collectible`, in data/collectibles/. Found once per profile (CollectibleBook keeps
## the profile's `collectibles` section); a run never depends on them. `order` is its place on the shelves (1..16,
## unique), `shelf` the shelf it stands on, `source` where a run (or the hub) holds it:
## - hidden_room: the cracked wall's hidden room on a floor of `biome` (at most one of these a run);
## - rune_alignment: the rune puzzle solved, on floor `floor_min` or deeper;
## - timed_door: the timed door's room, on floor `floor_min` or deeper (reached before it shuts);
## - hazard_lockdown: a Hazard Lockdown cleared (not opened by its cap);
## - purple_portal: the first floor reached through a Purple Portal;
## - blood_shrine: a Blood Shrine's deal taken;
## - fountain: a healing fountain drunk on a run's last floor;
## - rune_markings: `count` secrets behind hidden rune markings (timed door, rune puzzle, cracked wall) found in one
##   run;
## - final_body: the final boss's body `body` (a FinalBossDefinition id) falls;
## - hub_keystone: the hub's sealed alcove, once `count` collectibles are on the shelves.

const SHELVES: Array[StringName] = [&"stone", &"sealed", &"crown", &"hub"]
const SOURCES: Array[StringName] = [
	&"hidden_room",
	&"rune_alignment",
	&"timed_door",
	&"hazard_lockdown",
	&"purple_portal",
	&"blood_shrine",
	&"fountain",
	&"rune_markings",
	&"final_body",
	&"hub_keystone",
]

@export var order := 1
@export var shelf := &"stone"
@export var source := &"hidden_room"
@export var name_key := &""
@export var lore_key := &""
## hidden_room: the biome (a BiomeDefinition id) whose hidden room holds it.
@export var biome := &""
## rune_alignment, timed_door: the first floor (of a loop) it can be found on.
@export var floor_min := 1
## final_body: the body (a FinalBossDefinition id).
@export var body := &""
## rune_markings: the secrets to find in one run; hub_keystone: the collectibles on the shelves that open the alcove.
@export var count := 0
## The look: the gem's colour (its glow, halo and light take it).
@export var color := Color(0.62, 0.78, 1.0)


func category() -> StringName:
	return &"collectible"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if order < 1 or order > 32:
		issues.append(ValidationIssue.new(&"order_range", resource_path, "order must be 1..32"))
	if not SHELVES.has(shelf):
		issues.append(
			ValidationIssue.new(&"shelf_unknown", resource_path, "unknown shelf %s" % shelf)
		)
	if not SOURCES.has(source):
		issues.append(
			ValidationIssue.new(&"source_unknown", resource_path, "unknown source %s" % source)
		)
	if name_key == &"" or lore_key == &"":
		issues.append(ValidationIssue.new(&"keys_missing", resource_path, "name and lore keys"))
	if source == &"hidden_room" and biome == &"":
		issues.append(ValidationIssue.new(&"biome_missing", resource_path, "a hidden room's biome"))
	if source == &"final_body" and body == &"":
		issues.append(ValidationIssue.new(&"body_missing", resource_path, "a final body's id"))
	if (source == &"rune_markings" or source == &"hub_keystone") and count < 1:
		issues.append(ValidationIssue.new(&"count_missing", resource_path, "count must be >= 1"))
	if floor_min < 1:
		issues.append(ValidationIssue.new(&"floor_min", resource_path, "floor_min must be >= 1"))
	return issues
