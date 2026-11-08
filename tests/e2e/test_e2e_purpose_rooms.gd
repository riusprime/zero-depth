extends GutTest
## v0.11.0 O15 (PLAN P1; owner picked all three in the G2) in the real game, by input events only
## (Input.parse_input_event): for each purpose (camp, stone-ring hall, quarry), a run save on the first floor (2-4) and
## seed SaveLab finds holding one (SaveLab builds floors as Main does; floor 1 is small: on the e2e's fixed seeds it
## holds 0 or 1 large candidate room) is continued from the menu (Enter), as test_e2e_twin_wardens. Main builds that
## floor: the purpose room is laid, its pieces stand in the world as walls, and the view reads the room as named (its
## pieces drawn as the purpose's: StageDresser's named rooms). Reads are fine.

const FLOORS: Array[int] = [2, 3, 4]
const PURPOSES: Array[StringName] = [&"camp", &"hall", &"quarry"]
const SEEDS := 40


## [seed, floor] of the first SaveLab floor holding purpose `p`, or [].
static func find(p: StringName, repo: ContentRepository) -> Array:
	for s in range(1, SEEDS + 1):
		for n in FLOORS:
			var w := SaveLab.build_floor(SaveLab.run_state(s, n, &"blade", 0, repo), &"", repo)
			for room in w.floor_layout.purpose_rooms():
				if w.floor_layout.purpose_of(room) == p:
					return [s, n]
	return []


func test_main_lays_camps_halls_and_quarries_in_its_floors() -> void:
	var repo := ContentRepository.load_all()
	for p in PURPOSES:
		var at := find(p, repo)
		assert_false(at.is_empty(), "SaveLab finds a floor with a %s" % p)
		if at.is_empty():
			continue
		var run_seed: int = at[0]
		var n: int = at[1]
		var e := E2e.new(self)
		var run := SaveLab.run_state(run_seed, n, &"blade")
		var saved := SaveLab.build_floor(run)
		var store := RunSaveStore.new("")
		assert_true(store.write(RunSaver.payload_of(saved, run, run_seed, PackedByteArray())))
		var main: Main = await e.boot(null, store, run_seed)
		e.key(KEY_ENTER, true)
		e.key(KEY_ENTER, false)
		await main.loads.finished
		await e.frames(3)
		assert_eq(main.run.floor_index, n, "floor %d continues" % n)
		var w := e.world()
		var reader := main.driver.reader
		var f := w.floor_layout
		var rects := reader.floor_purpose_rects()
		var rooms := f.purpose_rooms()
		gut.p(
			(
				"O15 e2e: seed %d floor %d biome %s: purpose rooms %s"
				% [run_seed, n, main.run_biome_id(), str(Array(rooms).map(f.purpose_of))]
			)
		)
		assert_eq(rects.size(), rooms.size(), "the view reads every purpose room")
		var found := false
		for room in rooms:
			var purpose := reader.floor_room_purpose(room)
			found = found or purpose == p
			var solids := 0
			for i in range(f.slab_first, w.walls.size()):
				if (
					f.rooms[room].encloses(w.walls[i].bounds())
					and f.piece_tags.has(FloorLayout.piece_key(w.walls[i]))
				):
					solids += 1
			assert_gt(solids, 0, "the %s's pieces stand in the world" % purpose)
			assert_true(rects.has(f.rooms[room]), "the view draws the %s as named" % purpose)
		assert_true(found, "Main laid a %s on that floor" % p)
		main.queue_free()
		await e.frames(2)
