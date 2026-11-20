extends GutTest
## The hall's centrepieces in the sim. Starfall's great monolith stands on the blocker it always had: its seeded hall
## floor has the same walls and plays to the same state as before the centrepieces came. The Ruins and Night Rocks
## grand arch stands at its own size on two leg blockers (RoomPurposePiece.legs) in place of the one 3 x 1 m blocker:
## their floors' walls and play are measured anew, and the opening between the legs is floor the hero walks through
## and the enemies' path flood passes.

const TICKS := 300
## Per biome: [run seed (its second floor lays a hall), sha256 of its walls' keys, state hash after TICKS of FightBot].
const FLOORS := {
	&"ruins":
	[
		5,
		"4224f1193745fe1785980743d513505fa343f46c0a7ad9725456500d7b358353",
		"ac50d672650c211009f21eabb442b54b0a3be3c0b80efda7d460e6337790cfd8"
	],
	&"starfall":
	[
		1,
		"368b8cc8d44871bc7301afcb63b635766341730b473b1c70054feeeb6f1b854e",
		"67f9b366b6d818070570f7595fd7f26a5aeb73af0d93059b07519901eea077a3"
	],
	&"night_rocks":
	[
		1,
		"cbef6308c179832773e58e2dc49a21416c5a3f08912b1dc9ba711f7f53e8e153",
		"a13a2f5774c5badbfab8dcd8fbdb7206ac84285461977cab7102e3538fe822fb"
	],
}
## The arch's legs as the hall's palette lays them (scripts/content/room_purposes.gd FOCAL_ARCH): each leg's
## footprint and the legs' centres each side of the arch's.
const LEG := Vector2(1.52, 2.0)
const LEG_AT := 2.07
const ARCH_BIOMES: Array[StringName] = [&"ruins", &"night_rocks"]


static func _walls_sha(w: World) -> String:
	var keys := PackedStringArray()
	for o in w.walls:
		keys.append(FloorLayout.piece_key(o))
	return "|".join(keys).sha256_text()


func test_a_hall_floor_plays_as_measured() -> void:
	for biome: StringName in FLOORS:
		var want: Array = FLOORS[biome]
		var w := SaveLab.build_floor(SaveLab.run_state(want[0], 2), biome)
		assert_true(w.floor_layout.room_purpose.has(&"hall"), "%s: the floor lays a hall" % biome)
		var walls := _walls_sha(w)
		var bot := FightBot.new(5)
		for t in TICKS:
			w.step(SaveLab.frame(w, bot))
		var state := w.state_hash()
		assert_eq(walls, want[1], "%s: the same walls" % biome)
		assert_eq(state, want[2], "%s: the same play" % biome)


## The arch's two legs on a seeded hall floor of `biome`: [leg, leg, the hall's room rect].
static func _legs(w: World) -> Array:
	var f := w.floor_layout
	var legs: Array[Obb] = []
	for o in w.walls:
		if f.piece_tag(o) == &"grand_arch":
			legs.append(o)
	var room := Rect2()
	for i in f.room_purpose.size():
		if f.room_purpose[i] == &"hall":
			room = f.rooms[i]
	return [legs, room]


func test_the_arch_stands_on_two_legs_inside_its_span() -> void:
	for biome in ARCH_BIOMES:
		var w := SaveLab.build_floor(SaveLab.run_state(FLOORS[biome][0], 2), biome)
		var legs: Array[Obb] = _legs(w)[0]
		assert_eq(legs.size(), 2, "%s: the arch is two leg blockers" % biome)
		if legs.size() != 2:
			continue
		for o in legs:
			assert_almost_eq(o.half.x * 2.0, LEG.x, 0.011, "%s: a leg along the span" % biome)
			assert_almost_eq(o.half.y * 2.0, LEG.y, 0.011, "%s: a leg across it" % biome)
			assert_eq(o.angle, legs[0].angle, "%s: both legs turn with the arch" % biome)
		var apart := legs[0].center.distance_to(legs[1].center)
		assert_almost_eq(apart, LEG_AT * 2.0, 0.03, "%s: the legs stand at its ends" % biome)
		var axis := (legs[1].center - legs[0].center) / apart
		assert_almost_eq(absf(axis.dot(legs[0].axis_u)), 1.0, 0.001, "%s: side by side" % biome)


## The opening between the legs is floor: the hero and the widest enemy fit in it, and with the floor walled off past
## each leg (so the only way from in front of the arch to behind it is through it) the path flood still joins the two.
func test_the_opening_between_the_legs_is_passable_floor() -> void:
	var clearance := FloorParams.defaults().nav_clearance
	for biome in ARCH_BIOMES:
		var w := SaveLab.build_floor(SaveLab.run_state(FLOORS[biome][0], 2), biome)
		var got := _legs(w)
		var legs: Array[Obb] = got[0]
		var room: Rect2 = got[1]
		if legs.size() != 2:
			fail_test("%s: no arch" % biome)
			continue
		var mid := (legs[0].center + legs[1].center) * 0.5
		var axis := (legs[1].center - legs[0].center).normalized()
		var across := Vector2(-axis.y, axis.x)
		var opening := legs[0].center.distance_to(legs[1].center) - LEG.x
		assert_gt(
			opening, 2.0 * clearance + FloorReach.CELL, "%s: wider than the flood needs" % biome
		)
		for o in w.walls:
			assert_eq(
				Collide.circle_vs_obb(mid, clearance, o),
				Vector2.ZERO,
				"%s: the opening is clear" % biome
			)
		for i in w.solids.size():  # No container nor the purple dais stands in it
			assert_eq(
				Collide.circle_vs_obb(mid, clearance, w.solids.obb(i)),
				Vector2.ZERO,
				"%s: nothing solid stands in the opening" % biome
			)
		var ways := w.floor_layout.purpose_ways
		assert_eq(ways.size(), 1, "%s: the hall's one way through" % biome)
		if ways.size() == 1:
			assert_almost_eq(ways[0].distance_to(mid), 0.0, 0.02, "%s: between the legs" % biome)
		for q in w.spawn_points:
			assert_gte(q.distance_to(mid), RoomPurposes.WAY_CLEAR_M, "%s: no spawn in it" % biome)
		var closed: Array[Obb] = w.walls.duplicate()
		for side: float in [-1.0, 1.0]:  # A wall from each leg's outer side to well past the room
			var c := mid + axis * side * (opening * 0.5 + 30.0)
			closed.append(Obb.make(c, Vector2(30.0, LEG.y * 0.5), legs[0].angle))
		var front := mid + across * 3.0
		var back := mid - across * 3.0
		var reach := FloorReach.new()
		reach.build(room, closed, clearance)
		assert_gte(reach.region_at(front), 0, "%s: in front of the arch is floor" % biome)
		assert_eq(
			reach.region_at(front), reach.region_at(back), "%s: the way through the arch" % biome
		)
		closed.append(Obb.make(mid, Vector2(opening * 0.5, LEG.y * 0.5), legs[0].angle))
		reach.build(room, closed, clearance)
		assert_ne(
			reach.region_at(front), reach.region_at(back), "%s: and it is the only way" % biome
		)


## The hero walks straight through the opening, from 3 m in front of the arch to behind it.
func test_the_hero_walks_through_the_arch() -> void:
	for biome in ARCH_BIOMES:
		var w := SaveLab.build_floor(SaveLab.run_state(FLOORS[biome][0], 2), biome)
		var legs: Array[Obb] = _legs(w)[0]
		if legs.size() != 2:
			fail_test("%s: no arch" % biome)
			continue
		var mid := (legs[0].center + legs[1].center) * 0.5
		var axis := (legs[1].center - legs[0].center).normalized()
		var across := Vector2(-axis.y, axis.x)
		w.actors.set_pos(0, mid + across * 3.0)
		var step := InputFrame.new()
		step.move = Vector2i(roundi(-across.x * 127.0), roundi(-across.y * 127.0))
		for t in 240:  # The hero stands still through the floor's arrival first
			if (w.actors.pos(0) - mid).dot(across) < -2.0:
				break
			w.step(step)
		var at := w.actors.pos(0) - mid
		assert_lt(at.dot(across), -2.0, "%s: the hero is behind the arch" % biome)
		assert_lt(absf(at.dot(axis)), 0.5, "%s: having walked straight through" % biome)
