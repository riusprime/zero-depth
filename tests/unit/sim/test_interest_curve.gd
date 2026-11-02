extends GutTest
## v0.10.5 O14 (theory audit P12, Schell's interest curve at several scales): floor 2's first Lockdown is an Elite set
## piece near the main path's middle (LockdownDefinition.set_piece_floor), and on floor 3 no pack spawns while the
## hero stands in the boss room's host room (SpawnDirectorDefinition.calm_antechamber_floor).

const SEEDS := 50

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func before_each() -> void:
	NavField.skip_build = true


func after_each() -> void:
	NavField.skip_build = false


func _build(s: int, floor_index: int) -> World:
	var run := SaveLab.run_state(s, floor_index, &"blade", 0, _repo)
	return SaveLab.build_floor(run, &"", _repo)


func test_floor_2_places_an_elite_lockdown_near_the_middle() -> void:
	var placed := 0
	var near := 0
	for s in range(1, SEEDS + 1):
		var f := _build(s, 2).floor_layout
		if f.lockdown_rooms.is_empty():
			continue
		var path := LockdownRooms.main_path(f)
		var mid := path.size() / 2
		var first := f.lockdown_rooms[0]
		if f.lockdown_kinds[0] != LockdownTable.Kind.ELITE:
			continue
		placed += 1
		var key := LockdownRooms._path_key(f, first, path, mid)
		if key.x <= 1:
			near += 1
	gut.p("floor 2 set piece: %d of %d seeds, %d within 1 of the middle" % [placed, SEEDS, near])
	assert_gt(placed, SEEDS / 2, "most floor-2 seeds get an Elite first Lockdown")
	assert_gt(near, 0, "the set piece sits at the main path's middle on some seeds")
	for s in range(1, 11):  # other floors keep the draw
		var f1 := _build(s, 1).floor_layout
		for k in f1.lockdown_kinds:
			assert_ne(k, LockdownTable.Kind.ELITE, "floor 1 has no Elite Lockdown")


func test_floor_3_spawns_nothing_in_the_boss_host_room() -> void:
	var w := _build(3, 3)
	var f := w.floor_layout
	assert_eq(w.floor_index, 3)
	assert_gt(w.spawner.calm_antechamber_floor, 0)
	w.actors.invuln[0] = 1 << 24
	var host := f.rooms[f.boss_host_room]
	w.actors.set_pos(0, host.get_center())
	for i in 1800:
		w.actors.set_pos(0, host.get_center())
		w.step(InputFrame.new())
	assert_eq(WaveDirector.enemies_alive(w), 0, "no pack in the antechamber")
	var start := f.rooms[f.start_room]
	for i in 3000:
		w.actors.set_pos(0, start.get_center())
		w.step(InputFrame.new())
	assert_gt(WaveDirector.enemies_alive(w), 0, "packs resume when the hero leaves")
