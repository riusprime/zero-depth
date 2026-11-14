extends GutTest
## v0.8.0 RT (owner O12) in the real game, by input events only (Input.parse_input_event): Play starts a run whose
## first floor is built by Main with the designed rooms (data/room_layouts): rooms of a size with a layout drew one,
## their blockers are walls of the world, their drawn pieces reach the view's kit, and the start hall keeps its own
## rules. Reads of nodes are fine. v0.11.0 O15: Main lays the large rooms' purposes, their pieces walls of the world.


func test_a_run_floor_has_designed_rooms_drawn_with_the_kit() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(3)
	var w := e.world()
	var reader := WorldReader.new(w)
	var f := w.floor_layout
	var designed := 0
	for room in reader.floor_room_count():
		if reader.floor_room_layout(room) != &"":
			designed += 1
	assert_gt(designed, 0, "floor 1 has designed rooms")
	assert_eq(
		reader.floor_room_layout(reader.floor_start_room()), &"", "the start hall keeps its rules"
	)
	var blockers := 0
	for i in range(f.slab_first, w.walls.size()):
		if reader.wall_layout_height(i) >= 0.0:
			blockers += 1
	assert_gt(blockers, 0, "their blockers are walls of the world")
	assert_gt(reader.layout_prop_count(), 0, "and they carry drawn pieces")
	assert_not_null(main.view.stage.kit, "the floor is dressed with the kit")
	# v0.11.0 O15 (PLAN P1): Main lays the large rooms' purposes; a purpose room's pieces are walls of the world
	assert_eq(f.room_purpose.size(), f.room_count(), "the purpose pass ran on Main's floor")
	for room in f.purpose_rooms():
		var solids := 0
		for i in range(f.slab_first, w.walls.size()):
			if (
				f.rooms[room].encloses(w.walls[i].bounds())
				and f.piece_tags.has(FloorLayout.piece_key(w.walls[i]))
			):
				solids += 1
		assert_gt(
			solids, 0, "purpose room %d (%s) stands in the world" % [room, f.purpose_of(room)]
		)
		assert_ne(reader.floor_room_purpose(room), &"", "the view reads its purpose")
