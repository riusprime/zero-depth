class_name RoomPurposeDefinition
extends ContentDef
## A large room's purpose (v0.11.0 O15, PLAN P1, owner Q26 (a) and Q-O15a/b: "authored templates (like shops) with
## seeded variation"; docs/roadmap/v0.11.0/G2_ROOMS.md; CONTENT_SCHEMA §5 "Purpose rooms"). Files:
## data/rooms/purposes/<id>.tres, written by scripts/content/room_purposes.gd.
##
## The template is authored in a frame of the room's half-size: x along the room's long side, y across, the room's
## centre at (0, 0). Each group sits at a fraction of the half-size plus metres (RoomPurposeGroup), its parts in metres
## round it. Per room the seed (the `map:purpose:<room>` stream, RoomPurposes) draws the mirror (either axis), each
## choice's option, the groups' and parts' chances, a lean-to's side, a shift of each group (under SHIFT_MAX_M), a turn
## of each part (under TURN_MAX_DEG) and stack heights; a biome's palette names the kit piece of every token. A group
## whose solid would stand in a doorway's box, on an item spot or outside the room is dropped whole; a mirror that
## drops a focal group is tried last; the room takes the purpose only where every focal group stands.

## The variation's bounds (G2_ROOMS.md: "small shifts and turns (under 1 m, under 15 degrees)").
const SHIFT_MAX_M := 1.0
const TURN_MAX_DEG := 15.0
## A palette piece's drawn height bound: a big room's focal piece stands up to the hall's 6 m monolith.
const MAX_HEIGHT_M := 8.0
## The least opening between a piece's two legs: wide enough that the enemies' path flood passes it (FloorParams
## nav_clearance 0.6 m each side of a FloorReach cell of 0.5 m, rounded up), so a way through looks like one and is.
const MIN_OPENING_M := 2.0
## The kit pieces a palette may name: the designed rooms' (RoomLayoutDefinition.KIT), the biomes' own pieces and the
## purpose rooms' own (KitModels.SPECS; tests/content/test_room_purpose_validation.gd checks every one is installed).
const PIECES: Array[StringName] = [
	&"wall_broken",
	&"wall_pillar",
	&"slab_concrete",
	&"slab_wide",
	&"crate_stack",
	&"car_wreck",
	&"rock_large",
	&"dead_tree",
	&"fire_barrel",
	&"brazier_pole",
	&"rubble_small",
	&"grass_tuft",
	&"debris_low",
	&"building_corner",
	&"ladder_frame",
	&"column_broken",
	&"barricade",
	&"tire_stack",
	&"boulder_small",
	&"rock_spire",
	&"stone_arch",
	&"mushroom_cluster",
	&"bone_pile",
	&"mesa_chunk",
	&"dry_shrub",
	&"wagon_wreck",
	&"cattle_skull_post",
	&"snow_drift",
	&"ice_shard",
	&"ice_rock",
	&"boat_wreck",
	&"fish_rack",
	&"star_crystal",
	&"meteorite",
	&"star_monolith",
	&"ruined_observatory",
	&"camp_tent",
	&"log_seat",
	&"cook_pot",
	&"statue_whole",
	&"statue_broken",
	&"column_round",
	&"column_drum",
	&"quarry_crane",
	&"mine_cart",
	&"stone_block",
	&"tool_rack",
	&"grand_arch",
	&"great_monolith",
]
## The low pieces a palette may draw on open floor (never solid; "looks solid = is solid"). A taller drawn piece must
## rest on its group's solids (RoomPurposePiece.lift: a lintel), so nothing tall stands on open floor. A solid on legs
## (RoomPurposePiece.legs: an arch) is solid only under its legs: the opening between them is floor, so it is at
## least MIN_OPENING_M wide.
const DECOR: Array[StringName] = [
	&"rubble_small",
	&"grass_tuft",
	&"debris_low",
	&"boulder_small",
	&"mushroom_cluster",
	&"bone_pile",
	&"dry_shrub",
	&"snow_drift",
	&"ice_shard",
	&"star_crystal",
	&"meteorite",
]

## The least room it takes, in cells (long side first): 3 x 3 is "large" (PLAN P1).
@export var min_cells := Vector2i(3, 3)
## Its draw weight among the purposes that fit a room.
@export var weight := 1
## The biomes it fits; each has a palette.
@export var biomes: Array[StringName] = []
## True: the mirror prefers the frame's +y (the focal wall) on a far wall from the iso camera (G2_ROOMS.md, Quarry).
@export var far_wall := false
## The seeded shift of each group (m, each axis, under SHIFT_MAX_M) and turn of each part (degrees, under
## TURN_MAX_DEG).
@export var shift_m := 0.6
@export var turn_deg := 10.0
@export var choices: Array[RoomPurposeChoice] = []
@export var groups: Array[RoomPurposeGroup] = []
@export var palettes: Array[RoomPurposePalette] = []


func category() -> StringName:
	return &"room_purpose"


## The palette of `biome`, or null.
func palette_for(biome: StringName) -> RoomPurposePalette:
	for p in palettes:
		if p != null and p.biome == biome:
			return p
	return null


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if min_cells.y < 3 or min_cells.x < min_cells.y or min_cells.x > 4:
		issues.append(ValidationIssue.new(&"range", resource_path, "min_cells is 3 <= y <= x <= 4"))
	check_positive(issues, "weight", weight)
	if shift_m < 0.0 or shift_m >= SHIFT_MAX_M:
		issues.append(ValidationIssue.new(&"range", resource_path, "shift_m is 0 .. under 1 m"))
	if turn_deg < 0.0 or turn_deg >= TURN_MAX_DEG:
		issues.append(ValidationIssue.new(&"range", resource_path, "turn_deg is 0 .. under 15"))
	if biomes.is_empty():
		issues.append(ValidationIssue.new(&"empty", resource_path, "a purpose fits a biome"))
	var ids := _check_choices(issues)
	var tokens := {}
	var focal := 0
	if groups.is_empty():
		issues.append(ValidationIssue.new(&"empty", resource_path, "a purpose needs a group"))
	for g in groups.size():
		var group := groups[g]
		if group == null or group.parts.is_empty():
			issues.append(ValidationIssue.new(&"empty", resource_path, "group %d has no part" % g))
			continue
		focal += 1 if group.focal else 0
		_check_group(issues, g, group, ids, tokens)
	if focal == 0:
		issues.append(ValidationIssue.new(&"focal", resource_path, "a purpose has a focal group"))
	for b in biomes:
		var pal := palette_for(b)
		if pal == null:
			issues.append(
				ValidationIssue.new(&"palette", resource_path, "biome %s has no palette" % b)
			)
			continue
		for t: StringName in tokens:
			if pal.piece_for(t) == null:
				issues.append(
					ValidationIssue.new(
						&"palette", resource_path, "%s's palette has no '%s'" % [b, t]
					)
				)
		_check_palette(issues, pal)
	return issues


## The choices' ids and option counts ({id: count}), each checked.
func _check_choices(issues: Array[ValidationIssue]) -> Dictionary:
	var ids := {}
	for c in choices:
		if c == null or c.id == &"" or ids.has(c.id) or c.weights.size() < 2:
			issues.append(
				ValidationIssue.new(
					&"choice", resource_path, "a choice has a unique id and 2+ option weights"
				)
			)
			continue
		var total := 0
		for wt in c.weights:
			if wt < 0:
				issues.append(ValidationIssue.new(&"negative", resource_path, "a weight is < 0"))
			total += maxi(wt, 0)
		check_positive(issues, "choice %s's weights" % c.id, total)
		ids[c.id] = c.weights.size()
	return ids


func _check_group(
	issues: Array[ValidationIssue],
	g: int,
	group: RoomPurposeGroup,
	ids: Dictionary,
	tokens: Dictionary
) -> void:
	if absf(group.anchor.x) > 1.0001 or absf(group.anchor.y) > 1.0001:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "group %d: the anchor is -1..1" % g)
		)
	if group.choice != &"":
		if not ids.has(group.choice):
			issues.append(
				ValidationIssue.new(
					&"choice", resource_path, "group %d: no choice '%s'" % [g, group.choice]
				)
			)
		elif group.options.is_empty():
			issues.append(ValidationIssue.new(&"choice", resource_path, "group %d: no option" % g))
		else:
			for o in group.options:
				if o < 0 or o >= int(ids[group.choice]):
					issues.append(
						ValidationIssue.new(
							&"choice", resource_path, "group %d: option %d is out of range" % [g, o]
						)
					)
	if group.focal and (group.choice != &"" or group.chance_permille < 1000):
		issues.append(
			ValidationIssue.new(
				&"focal", resource_path, "group %d: a focal group is always laid" % g
			)
		)
	if group.chance_permille < 0 or group.chance_permille > 1000:
		issues.append(ValidationIssue.new(&"range", resource_path, "group %d: chance 0..1000" % g))
	for k in group.parts.size():
		var p := group.parts[k]
		var where := "group %d part %d" % [g, k]
		if p == null or p.token == &"":
			issues.append(ValidationIssue.new(&"empty", resource_path, "%s: no token" % where))
			continue
		tokens[p.token] = true
		if p.side < 0 or p.side > 2:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: side 0..2" % where))
		if p.chance_permille < 0 or p.chance_permille > 1000:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "%s: chance 0..1000" % where)
			)
		if p.height_scale <= 0.0 or p.height_scale > 3.0:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: height 0..3" % where))
		if p.height_spread < 0.0 or p.height_spread > 0.5:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: spread 0..0.5" % where))


func _check_palette(issues: Array[ValidationIssue], pal: RoomPurposePalette) -> void:
	for p in pal.pieces:
		if p == null:
			continue
		var where := "%s's %s" % [pal.biome, p.token]
		if not PIECES.has(p.piece):
			issues.append(
				ValidationIssue.new(
					&"unknown_piece", resource_path, "%s: no kit piece '%s'" % [where, p.piece]
				)
			)
		if p.size.x <= 0.0 or p.size.y <= 0.0 or maxf(p.size.x, p.size.y) > 12.0:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: size 0..12 m" % where))
		if p.height < 0.0 or p.height > MAX_HEIGHT_M:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: height 0..8 m" % where))
		if p.solid and DECOR.has(p.piece):
			issues.append(
				ValidationIssue.new(
					&"solid_decor", resource_path, "%s: decoration is never solid" % where
				)
			)
		if p.solid and minf(p.size.x, p.size.y) < 0.3:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "%s: a solid is 0.3 m+" % where)
			)
		if p.lift < 0.0 or p.lift > 4.0 or (p.solid and p.lift > 0.0):
			issues.append(
				ValidationIssue.new(&"range", resource_path, "%s: lift 0..4 m, drawn only" % where)
			)
		if p.legs != Vector2.ZERO:
			_check_legs(issues, where, p)
		if not p.solid and not DECOR.has(p.piece) and p.lift <= 0.0:
			issues.append(
				ValidationIssue.new(
					&"floating_tall",
					resource_path,
					"%s: '%s' is taller than decoration and not solid" % [where, p.piece]
				)
			)


## A piece on legs: a solid on the floor, each leg a blocker inside the drawn footprint, the opening between them
## MIN_OPENING_M or wider.
func _check_legs(issues: Array[ValidationIssue], where: String, p: RoomPurposePiece) -> void:
	if not p.solid or p.lift > 0.0:
		issues.append(
			ValidationIssue.new(&"legs", resource_path, "%s: a piece on legs is a solid" % where)
		)
	if minf(p.legs.x, p.legs.y) < 0.3:
		issues.append(ValidationIssue.new(&"legs", resource_path, "%s: a leg is 0.3 m+" % where))
	var eps := 0.001
	if p.leg_at + p.legs.x * 0.5 > p.size.x * 0.5 + eps or p.legs.y > p.size.y + eps:
		issues.append(
			ValidationIssue.new(
				&"legs", resource_path, "%s: the legs stand inside its footprint" % where
			)
		)
	if p.leg_at * 2.0 - p.legs.x < MIN_OPENING_M - eps:
		issues.append(
			ValidationIssue.new(
				&"legs",
				resource_path,
				"%s: the opening between the legs is %.1f m+" % [where, MIN_OPENING_M]
			)
		)
