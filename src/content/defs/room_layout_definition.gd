class_name RoomLayoutDefinition
extends ContentDef
## A hand-designed room interior (v0.8.0 RT, owner O12: "design maybe two, three rooms of each size and have them like
## nicely looking like the image we use for reference … procedural generation to place them as templates … a room that
## could be in different directions"; CONTENT_SCHEMA §5 "Designed rooms"). Files: data/room_layouts/<x>x<y>_<n>.tres.
##
## The layout is drawn in its own frame: x along the room's long side (`cells.x` >= `cells.y`), y across, (0, 0) the
## room's corner. Each group sits at a fraction of the room (RoomLayoutGroup.anchor) and keeps its shape in metres.
## The generator (FloorGenerator, through RoomLayouts) picks a layout for a room of these cells, turns it (0/90/180/
## 270; a long room only the two ways that keep its long side long) and mirrors it, then keeps each group only where
## it fits (doorways' approaches, the start, the gate, the room one region). Pieces name kit pieces (KIT); a biome's
## swap rules restyle them (StageDresser). Compiled by RunContentCompiler.compile_room_layouts.

## The kit pieces a layout may name (assets/models/kit; KitModels.SPECS).
const KIT: Array[StringName] = [
	&"wall_1m",
	&"wall_2m",
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
]
## Decoration: low pieces (drawn at most StageDresser.DECOR_MAX_HEIGHT tall) that may lie on open floor.
const DECOR: Array[StringName] = [&"rubble_small", &"grass_tuft", &"debris_low"]
## No slit inside a group: two solid pieces facing each other across a corridor are either at most SHUT apart (too
## narrow for the player, 0.35 m radius) or at least MIN_LANE apart (wide enough for an enemy, FloorParams.nav_clearance
## 0.6 m either side, with 0.8 m to spare so the floor's 0.5 m walkability grid always finds the lane open whatever its
## alignment), unless the group's other solids fill the corridor between them. Pieces meeting only at a diagonal make
## no corridor.
const SHUT := 0.6
const MIN_LANE := 2.0
## A drawn piece standing on a solid one may overhang its footprint by this much (the model's own silhouette).
const OVERHANG := 0.05

## The room size it is drawn for, in cells: x >= y (its long side first). A room of y x x cells takes it turned.
@export var cells := Vector2i(2, 2)
## Its draw weight among the layouts of its size.
@export var weight := 1
@export var groups: Array[RoomLayoutGroup] = []
## Open fighting lanes kept clear on purpose: rects in per mille of the room in the layout's frame (0..1000). No solid
## piece may fall in one (tests/unit/sim/test_room_layouts.gd checks it in a typical room, every turn and mirror).
@export var keep_clear: Array[Rect2i] = []


func category() -> StringName:
	return &"room_layout"


## The pieces this layout may name (v0.8.0 SR: a shop room adds its stall's pieces, ShopRoomDefinition).
func kit() -> Array[StringName]:
	return KIT


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if cells.y < 1 or cells.x < cells.y or cells.x > 4:
		issues.append(ValidationIssue.new(&"range", resource_path, "cells is 1 <= y <= x <= 4"))
	check_positive(issues, "weight", weight)
	if groups.is_empty():
		issues.append(ValidationIssue.new(&"empty", resource_path, "a layout needs a group"))
	for g in groups.size():
		_check_group(issues, g, groups[g])
	for k in keep_clear.size():
		var r := keep_clear[k]
		if r.size.x <= 0 or r.size.y <= 0 or not Rect2i(0, 0, 1000, 1000).encloses(r):
			issues.append(
				ValidationIssue.new(
					&"range", resource_path, "keep_clear[%d] is a rect inside 0..1000" % k
				)
			)
	return issues


func _check_group(issues: Array[ValidationIssue], g: int, group: RoomLayoutGroup) -> void:
	if group == null or group.pieces.is_empty():
		issues.append(ValidationIssue.new(&"empty", resource_path, "group %d has no piece" % g))
		return
	if not Rect2(0, 0, 1, 1).grow(0.0001).has_point(group.anchor):
		issues.append(
			ValidationIssue.new(&"range", resource_path, "group %d: the anchor is 0..1" % g)
		)
	var solids: Array[Rect2] = []
	for p in group.pieces:
		if p != null and p.solid:
			solids.append(footprint(p))
	for k in group.pieces.size():
		var p := group.pieces[k]
		var where := "group %d piece %d" % [g, k]
		if p == null:
			issues.append(ValidationIssue.new(&"empty", resource_path, "%s is empty" % where))
			continue
		if not kit().has(p.piece):
			issues.append(
				ValidationIssue.new(
					&"unknown_piece", resource_path, "%s: no kit piece '%s'" % [where, p.piece]
				)
			)
		if p.size.x <= 0.0 or p.size.y <= 0.0 or maxf(p.size.x, p.size.y) > 12.0:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: size 0..12 m" % where))
		if p.height < 0.0 or p.height > 4.0:
			issues.append(ValidationIssue.new(&"range", resource_path, "%s: height 0..4 m" % where))
		if p.solid:
			if DECOR.has(p.piece):
				issues.append(
					ValidationIssue.new(
						&"solid_decor", resource_path, "%s: decoration is never solid" % where
					)
				)
			if p.yaw != 0.0:
				issues.append(
					ValidationIssue.new(
						&"solid_turned", resource_path, "%s: a solid piece is not turned" % where
					)
				)
			if minf(p.size.x, p.size.y) < 0.3:
				issues.append(
					ValidationIssue.new(&"range", resource_path, "%s: a solid is 0.3 m+" % where)
				)
		elif not DECOR.has(p.piece) and not _stands_on(p, solids):
			issues.append(
				ValidationIssue.new(
					&"floating_tall",
					resource_path,
					(
						"%s: '%s' is taller than decoration and stands outside its group's solids"
						% [where, p.piece]
					)
				)
			)
	for a in solids.size():
		for b in range(a + 1, solids.size()):
			var slit := corridor(solids[a], solids[b])
			if slit.has_area() and not _filled(slit, solids, a, b):
				(
					issues
					. append(
						(
							ValidationIssue
							. new(
								&"slit",
								resource_path,
								(
									"group %d: a %.2f m slit between two solids (at most %.1f m, or %.1f m+)"
									% [g, minf(slit.size.x, slit.size.y), SHUT, MIN_LANE]
								)
							)
						)
					)
				)


## The corridor between two solids that face each other across a gap wider than SHUT and narrower than MIN_LANE
## (the box between them over the stretch they share), or an empty Rect2.
static func corridor(a: Rect2, b: Rect2) -> Rect2:
	var y0 := maxf(a.position.y, b.position.y)
	var y1 := minf(a.end.y, b.end.y)
	var x0 := maxf(a.position.x, b.position.x)
	var x1 := minf(a.end.x, b.end.x)
	if y1 - y0 > 0.01:
		var gx := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
		if gx > SHUT and gx < MIN_LANE:
			var left := a.end.x if b.position.x >= a.end.x else b.end.x
			return Rect2(left, y0, gx, y1 - y0)
	elif x1 - x0 > 0.01:
		var gy := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
		if gy > SHUT and gy < MIN_LANE:
			var top := a.end.y if b.position.y >= a.end.y else b.end.y
			return Rect2(x0, top, x1 - x0, gy)
	return Rect2()


## True when every sample point of `box` lies in a solid other than a and b.
static func _filled(box: Rect2, solids: Array[Rect2], a: int, b: int) -> bool:
	var n := 8
	for u in n:
		for v in n:
			var q := box.position + box.size * Vector2((u + 0.5) / n, (v + 0.5) / n)
			var covered := false
			for k in solids.size():
				if k != a and k != b and solids[k].grow(0.0001).has_point(q):
					covered = true
					break
			if not covered:
				return false
	return true


## A piece's footprint around its group's anchor (its yaw left out).
static func footprint(p: RoomLayoutPiece) -> Rect2:
	return Rect2(p.at - p.size * 0.5, p.size)


## The gap between two rects (m): 0 when they touch or overlap.
static func gap_between(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dy := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return sqrt(dx * dx + dy * dy)


## True when the piece's turned footprint lies inside one of the solids (within OVERHANG).
static func _stands_on(p: RoomLayoutPiece, solids: Array[Rect2]) -> bool:
	var a := deg_to_rad(p.yaw)
	var u := Vector2(cos(a), sin(a)) * p.size.x * 0.5
	var v := Vector2(-sin(a), cos(a)) * p.size.y * 0.5
	for s in solids:
		var box := s.grow(OVERHANG)
		var inside := true
		for c in [p.at + u + v, p.at + u - v, p.at - u + v, p.at - u - v]:
			if not box.has_point(c):
				inside = false
		if inside:
			return true
	return false
