extends GutTest
## The hall's new centrepieces and the larger focal pieces are presentation only: a seeded hall floor of each hall
## biome has the same walls and plays to the same state as before them. The fingerprints were measured on the data
## before the centrepieces came (the hall's stone arch and observatory, the first fire-pit stones and quarry face).

const TICKS := 300
## Per biome: [run seed (its second floor lays a hall), sha256 of its walls' keys, state hash after TICKS of FightBot].
const FLOORS := {
	&"ruins":
	[
		5,
		"cc90ca0ddb42fe14ee4269bd03679509fe3d15d1e28497165d8198b4ee91ab61",
		"a5bd87e3ac5c8fed4c4715f3727a9c31ff7653850079dd5fef51512712ecd3e8"
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
		"e92439179d186871e61b07275b92c0030153a066d6ceffd441a58bf80b8619c3",
		"bf5fbd7f6c6e40f9f032f85c9213633b29371cfdef3c15319cb723d5c8010ca3"
	],
}


static func _walls_sha(w: World) -> String:
	var keys := PackedStringArray()
	for o in w.walls:
		keys.append(FloorLayout.piece_key(o))
	return "|".join(keys).sha256_text()


func test_a_hall_floor_plays_as_before() -> void:
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
