class_name SpecialRoomDefinition
extends ContentDef
## v0.9.0 RG (PLAN W73 "each special room defines category, eligible biomes, floors, interactions … entry and exit
## configuration, rewards, difficulty, optional"; W74 "not every floor needs every interaction": per-floor chances and
## caps; CONTENT_SCHEMA §5): one special room kind the floor places (data/special_rooms/<id>.tres, category
## `special_rooms`, the id the kind's name). It describes what the placement code (`code`) does: the floors, how often,
## at most how many a floor, what room it needs and which rooms it never takes. It drives no draw: the numbers it
## repeats stay in the files the floor reads (`sources`), and the content check fails when the two disagree
## (cross_check), so a tuning change is made there and copied here. The no-softlock property tests
## (test_special_room_rules) check every floor they build against these rules (avoid, host_avoid, dead_end,
## skippable, keeps_every_room, min_spawn_spots, never_adjacent_to_same, off_critical_path, floors), and
## test_special_room_schema checks the code's own constants (stream, min_spawn_spots, min_cells) against these files.

## How the floor decides how many it gets.
enum Placement {
	## chance_permille of the floors, one at most.
	CHANCE,
	## floor_chance_permille[floor - 1] of the floors (the loop's floors), one at most.
	FLOOR_CHANCE,
	## count_min..count_max a floor, drawn.
	COUNT,
	## share_permille of the floor's combat rooms (at least 1 when a room fits).
	SHARE,
	## every every_floors floors from floor_min (one a floor).
	EVERY_FLOORS,
	## one on every floor where a room fits.
	ALWAYS,
}

## W72's pacing bands.
const BANDS: Array[StringName] = [&"special_combat", &"puzzle_secret", &"service_event"]
## How the room is entered.
const ENTRIES: Array[StringName] = [
	&"open", &"sealed_on_entry", &"red_frame", &"timed_door", &"rune_slab", &"cracked_wall"
]
## The rooms an avoid list may name: the fixed rooms, the hosts (the room before a secret, holding its pieces), the
## floor's rewards' rooms and the special room kinds (these files' ids).
const ROOMS: Array[StringName] = [
	&"start",
	&"boss",
	&"boss_host",
	&"portal",
	&"reward",
	&"timed_door_host",
	&"rune_puzzle_host",
	&"cracked_wall_host",
	&"arena",
	&"overrun",
	&"lockdown",
	&"shop",
	&"curse",
	&"event",
	&"shrine",
	&"fountain",
	&"timed_door",
	&"rune_puzzle",
	&"cracked_wall",
	&"purple_runes",
]
const _SOURCE_PATTERN := "^[a-z_]+/[a-z0-9_]+:[a-z0-9_]+$"

## W72's band (BANDS).
@export var band: StringName = &"service_event"
## The function that places it (the rules below describe it).
@export var code := ""
## Its place in the floor's order (1 first: a kind placed later keeps out of the earlier ones' rooms).
@export var order := 1
## The sub-stream of the floor seed its draws come from (EI-05); &"" for a pure function of the layout.
@export var stream: StringName = &""
## Whether the floor can be finished without it.
@export var optional := true
## How it is entered (ENTRIES) and whether it shuts the hero in while it runs (an arena, a Lockdown).
@export var entry: StringName = &"open"
@export var seals := false
## The biomes it may appear in (empty: every biome).
@export var biomes: Array[StringName] = []
## The floors it may appear on, within a loop (floor_max 0: no upper bound).
@export var floor_min := 1
@export var floor_max := 0
## How many a floor (Placement), and the numbers that go with it.
@export var placement: Placement = Placement.CHANCE
@export var chance_permille := 0
@export var floor_chance_permille := PackedInt32Array()
@export var count_min := 0
## At most this many a floor (0: no fixed cap, as a share of the rooms).
@export var count_max := 1
@export var share_permille := 0
@export var every_floors := 0
## Room needs: a dead end (one doorway); a host (its pieces stand in the room before it); at least this many enemy
## spawn spots; at least this many grid cells (a preference: the biggest that fit when none is that big).
@export var dead_end := false
@export var uses_host := false
@export var min_spawn_spots := 0
@export var min_cells := 0
## The boss room stays reached from the start hall with every room of this kind shut: never the only way on.
@export var skippable := true
## Stronger: with this kind shut (and the arenas and the Overrun room), every room reached before is still reached.
@export var keeps_every_room := false
## Never on the shortest doorway path from the start hall to the boss room's host.
@export var off_critical_path := false
## Never two of it side by side.
@export var never_adjacent_to_same := false
## The rooms (ROOMS) its room never is, and its host never is.
@export var avoid: Array[StringName] = []
@export var host_avoid: Array[StringName] = []
## Where the numbers above live: field -> "category/id:field" (a share of 0..1 is read as per mille).
@export var sources := {}


func category() -> StringName:
	return &"special_rooms"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if not band in BANDS:
		issues.append(
			ValidationIssue.new(&"enum", resource_path, "band %s is not one of %s" % [band, BANDS])
		)
	if not entry in ENTRIES:
		issues.append(ValidationIssue.new(&"enum", resource_path, "entry %s is unknown" % entry))
	if code.is_empty() or order < 1:
		issues.append(ValidationIssue.new(&"range", resource_path, "code is named, order >= 1"))
	if floor_min < 1 or (floor_max != 0 and floor_max < floor_min):
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "floor_min >= 1, floor_max 0 or >= floor_min"
			)
		)
	if count_min < 0 or count_max < 0 or (count_max > 0 and count_min > count_max):
		issues.append(
			ValidationIssue.new(&"range", resource_path, "0 <= count_min <= count_max (0: no cap)")
		)
	if keeps_every_room and not skippable:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "keeps_every_room needs skippable")
		)
	if min_spawn_spots < 0 or min_cells < 0:
		issues.append(ValidationIssue.new(&"range", resource_path, "room needs >= 0"))
	_check_placement(issues)
	for r in avoid + host_avoid:
		if not r in ROOMS:
			issues.append(
				ValidationIssue.new(&"unknown_room", resource_path, "no room kind %s" % r)
			)
	if not host_avoid.is_empty() and not uses_host:
		issues.append(ValidationIssue.new(&"range", resource_path, "host_avoid needs uses_host"))
	if dead_end and not skippable:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "a dead end is never on the way")
		)
	var re := RegEx.create_from_string(_SOURCE_PATTERN)
	var fields := _fields()
	for key: Variant in sources:
		if not String(key) in fields:
			issues.append(
				ValidationIssue.new(&"unknown_field", resource_path, "sources: no field %s" % key)
			)
		if not sources[key] is String or re.search(sources[key]) == null:
			issues.append(
				ValidationIssue.new(
					&"source_format", resource_path, "sources[%s] is category/id:field" % key
				)
			)
	return issues


func _check_placement(issues: Array[ValidationIssue]) -> void:
	var ok := true
	match placement:
		Placement.CHANCE:
			ok = chance_permille >= 0 and chance_permille <= 1000 and count_max == 1
		Placement.FLOOR_CHANCE:
			ok = not floor_chance_permille.is_empty() and count_max == 1
			for v in floor_chance_permille:
				ok = ok and v >= 0 and v <= 1000
		Placement.COUNT:
			ok = count_max >= 1
		Placement.SHARE:
			ok = share_permille > 0 and share_permille <= 1000
		Placement.EVERY_FLOORS:
			ok = every_floors >= 1 and count_max == 1
		Placement.ALWAYS:
			ok = count_max == 1
	if not ok:
		issues.append(
			ValidationIssue.new(
				&"placement", resource_path, "placement %d's numbers are out of range" % placement
			)
		)


func _fields() -> PackedStringArray:
	var out := PackedStringArray()
	for p in get_property_list():
		if p["usage"] & PROPERTY_USAGE_STORAGE:
			out.append(p["name"])
	return out


## The value `source` ("category/id:field") names among `defs`, or null when there is none.
static func source_value(defs: Array[ContentDef], source: String) -> Variant:
	var cat := source.get_slice("/", 0)
	var rest := source.get_slice("/", 1)
	var id := rest.get_slice(":", 0)
	var field := rest.get_slice(":", 1)
	for d in defs:
		if String(d.category()) == cat and String(d.id) == id:
			for p in d.get_property_list():
				if p["name"] == field:
					return d.get(field)
	return null


## v0.9.0 RG: every source names a field of a definition, and the value here equals it (a float share of 0..1 here as
## per mille).
static func cross_check(defs: Array[ContentDef]) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	for d in defs:
		var s := d as SpecialRoomDefinition
		if s == null:
			continue
		for key: Variant in s.sources:
			var src: Variant = source_value(defs, String(s.sources[key]))
			if src == null:
				issues.append(
					ValidationIssue.new(
						&"special_room_source", s.resource_path, "no %s" % s.sources[key]
					)
				)
				continue
			var here: Variant = s.get(String(key))
			if typeof(src) == TYPE_FLOAT:
				src = roundi(float(src) * 1000.0)
			if typeof(src) != typeof(here) or src != here:
				issues.append(
					ValidationIssue.new(
						&"special_room_source",
						s.resource_path,
						"%s is %s here but %s in %s" % [key, here, src, s.sources[key]]
					)
				)
	return issues
