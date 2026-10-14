class_name ShopRoomDefinition
extends RoomLayoutDefinition
## A biome's shop room (v0.8.0 SR, owner O13: "this shop room that is gonna be designed in a way for each biome that
## will have like its own vendor like with a model and it will be like in a tent shop"; CONTENT_SCHEMA §5 "Shop
## rooms"). Files: data/shop_rooms/<biome>.tres, written by scripts/content/shop_rooms.py.
##
## When a floor's shop room is chosen (ShopPlacement, unchanged), its interior is replaced by this layout (ShopRoom):
## the stall, a tent over a counter, stands at the first of `stall_spots` that fits, its counter facing the room's
## first doorway; the groups (RoomLayoutDefinition's, at fractions of the room) dress the room around it. The layout's
## frame is turned so that its -y points toward that doorway (y = 0 is the way in, y = 1 the back of the room), never
## mirrored. The shop's interaction point is the counter (Shop.pos), so you walk up to it.
##
## Pieces named shop_* are the stall's own (drawn by ShopStallView from the owner's models or code stand-ins); the
## rest are kit pieces drawn by the dresser, restyled by the biome as in any designed room. `cells` is unused.

## The shop's own pieces: the counter and the tent over it (the stall's two solids), the goods on the counter and
## crates, sacks of stock, and a lantern post (a solid with its warm light).
const SHOP_KIT: Array[StringName] = [
	&"shop_counter", &"shop_tent", &"shop_wares", &"shop_sack", &"shop_lantern"
]
## The stall's size, the counter and the tent together (m, across x front-to-back): the owner's desert merchant stall
## at its in-game scale (ShopModels: 4.0 m across, 3.3 m deep), with a little room behind it.
const STALL_SIZE := Vector2(4.0, 3.4)

## The biome this shop room dresses (a BiomeDefinition id).
@export var biome := &""
## The stall: pieces in metres from the stall's centre, its front (the counter) toward -y. Its anchor is unused (the
## stall goes to a spot). Exactly one solid shop_counter at the front and one solid shop_tent behind it.
@export var stall: RoomLayoutGroup
## Where the stall's centre may stand, tried in order: fractions of the room in the shop frame (0..1). A stall within
## the slab gap of a side or the back is pushed flush to it (no slit).
@export var stall_spots: Array[Vector2] = [Vector2(0.5, 0.55)]
## The box kept clear in front of the counter (m): its width, centred on the counter, and its depth from the
## counter's face. Nothing solid stands in it, so you walk straight up to the counter.
@export var approach := Vector2(5.0, 3.0)


func category() -> StringName:
	return &"shop_room"


func kit() -> Array[StringName]:
	var out: Array[StringName] = KIT.duplicate()
	out.append_array(SHOP_KIT)
	return out


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if biome == &"":
		issues.append(ValidationIssue.new(&"empty", resource_path, "a shop room names its biome"))
	if stall == null or stall.pieces.is_empty():
		issues.append(ValidationIssue.new(&"empty", resource_path, "a shop room needs its stall"))
	else:
		_check_group(issues, groups.size(), stall)
		_check_stall(issues)
	if stall_spots.is_empty():
		issues.append(ValidationIssue.new(&"empty", resource_path, "a stall needs a spot"))
	for k in stall_spots.size():
		if not Rect2(0, 0, 1, 1).grow(0.0001).has_point(stall_spots[k]):
			issues.append(
				ValidationIssue.new(&"range", resource_path, "stall_spots[%d] is 0..1" % k)
			)
	if approach.x < STALL_SIZE.x or approach.y < 1.5:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "approach is at least the stall's width by 1.5 m"
			)
		)
	for g in groups.size():
		if groups[g] == null:
			continue
		for p in groups[g].pieces:
			if p != null and p.piece in [&"shop_counter", &"shop_tent"]:
				issues.append(
					ValidationIssue.new(
						&"stall_piece",
						resource_path,
						"group %d: the stall's pieces go in stall" % g
					)
				)
	return issues


## One counter and one tent, both solid, the counter in front (lower y) and the tent behind it; together the art
## list's stall size.
func _check_stall(issues: Array[ValidationIssue]) -> void:
	var counter: RoomLayoutPiece = null
	var tent: RoomLayoutPiece = null
	var others := 0
	for p in stall.pieces:
		if p == null or not p.solid:
			continue
		if p.piece == &"shop_counter" and counter == null:
			counter = p
		elif p.piece == &"shop_tent" and tent == null:
			tent = p
		else:
			others += 1
	if counter == null or tent == null or others > 0:
		issues.append(
			ValidationIssue.new(
				&"stall",
				resource_path,
				"the stall is one solid shop_counter and one solid shop_tent"
			)
		)
		return
	if counter.at.y >= tent.at.y:
		issues.append(
			ValidationIssue.new(&"stall", resource_path, "the counter stands in front of the tent")
		)
	var foot := footprint(counter).merge(footprint(tent))
	if not foot.size.is_equal_approx(STALL_SIZE) or not foot.get_center().is_zero_approx():
		issues.append(
			ValidationIssue.new(
				&"stall",
				resource_path,
				"the stall is %.1f x %.1f m round its centre" % [STALL_SIZE.x, STALL_SIZE.y]
			)
		)
