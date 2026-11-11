extends GutTest
## v0.3.0 MM (owner L30): the minimap's discovery. The start hall is known at floor start and nothing else; walking
## into a room reveals it and only it; doorways from known rooms into unknown ones are flagged (the map's stubs);
## reward icons show only in known rooms and leave when the reward is taken; a new floor starts over. The views draw
## one Control each and redraw only on a change.

const I := InputFrame.INTERACT

var _items: Array[ItemTable] = []
var _enemies: Array[EnemyTable] = []
var _rewards: RewardTable


func before_all() -> void:
	var repo := ContentRepository.load_all()
	_items = ContentCompiler.compile_items(repo)
	_enemies = ContentCompiler.compile_enemies(repo)
	_rewards = ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor"))


func _floor(seed_value: int, floor_index: int = 1) -> World:
	return FloorScenario.build(
		seed_value,
		PlayerTable.starting_values(),
		_enemies,
		SpawnTable.new(),
		_items,
		_rewards,
		floor_index
	)


func test_the_start_hall_is_known_and_nothing_else() -> void:
	for s in [3, 11, 27]:
		var w := _floor(s)
		var r := WorldReader.new(w)
		var st := MinimapState.new()
		assert_true(st.update(r), "seed %d: the first read draws" % s)
		var start := w.floor_layout.start_room
		assert_eq(st.discovered_count(), 1, "seed %d: one room known" % s)
		assert_true(st.is_discovered(start))
		assert_eq(st.current, start)
		# The hall has one exit (FloorGenerator), and it leads somewhere unexplored.
		var unknown := st.unknown_doors(r)
		assert_eq(unknown.size(), 1, "seed %d: the hall's exit is the one way on" % s)
		var d := r.floor_door_rooms(unknown[0])
		assert_true(d.x == start or d.y == start)
		for i in r.floor_door_count():
			var dr := r.floor_door_rooms(i)
			if dr.x != start and dr.y != start:
				assert_false(
					st.door_known(r, i), "seed %d: door %d of unknown rooms is hidden" % [s, i]
				)
		assert_eq(st.visible_rewards(r).size(), 0, "seed %d: no rewards in the hall" % s)
		assert_false(st.update(r), "seed %d: nothing changed, no redraw" % s)


func test_entering_a_room_reveals_it_and_flags_its_doors() -> void:
	var w := _floor(11)
	var r := WorldReader.new(w)
	var st := MinimapState.new()
	st.update(r)
	var start := w.floor_layout.start_room
	var door := st.unknown_doors(r)[0]
	var d := r.floor_door_rooms(door)
	var room := d.y if d.x == start else d.x
	var rev := st.revision
	w.actors.set_pos(0, r.floor_room(room).get_center())
	assert_true(st.update(r), "entering redraws")
	assert_gt(st.revision, rev)
	assert_true(st.is_discovered(room), "the room entered is known")
	assert_eq(st.current, room, "and is the current room")
	assert_eq(st.discovered_count(), 2, "and no other")
	assert_false(
		st.door_to_unknown(r, door), "the door between two known rooms is no longer a stub"
	)
	for n in w.floor_layout.neighbours(room):
		if n != start:
			assert_false(st.is_discovered(n), "neighbour %d stays hidden" % n)
	var stubs := 0
	for i in st.unknown_doors(r):
		var dr := r.floor_door_rooms(i)
		assert_true(dr.x == room or dr.y == room, "every stub leaves the new room")
		stubs += 1
	assert_eq(
		stubs, w.floor_layout.neighbours(room).size() - 1, "one stub per unexplored neighbour"
	)
	# Standing in a doorway (no room) keeps the last room as current.
	w.actors.set_pos(0, r.floor_door_rect(door).get_center())
	st.update(r)
	assert_eq(st.current, room)


func test_reward_icons_show_in_known_rooms_and_leave_when_taken() -> void:
	var w := _floor(11)
	var r := WorldReader.new(w)
	var st := MinimapState.new()
	st.update(r)
	var altar := E2e.nearest_reward(w, RewardStore.Kind.ALTAR)
	assert_gt(altar, -1, "the floor has an altar")
	var id := w.rewards.ids[altar]
	var room := w.floor_layout.room_of(w.rewards.pos(altar))
	assert_false(st.visible_rewards(r).has(altar), "hidden while its room is unknown")
	w.actors.set_pos(0, w.rewards.pos(altar) + Vector2(0.6, 0))
	st.update(r)
	assert_true(st.is_discovered(room))
	assert_true(st.visible_rewards(r).has(altar), "shown once its room is known")
	# Open it and take the first card through the sim's own input.
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, I))
	assert_eq(w.choosing, id, "the altar opened")
	var f := InputFrame.make(Vector2i.ZERO, 0, 0, 0, 0)
	f.pick = 1
	w.step(f)
	assert_eq(w.rewards.index_of(id), -1, "the altar is consumed")
	var rev := st.revision
	assert_true(st.update(r), "a taken reward redraws")
	assert_gt(st.revision, rev)
	for i in st.visible_rewards(r):
		assert_ne(w.rewards.ids[i], id, "its icon is gone")


func test_a_new_floor_starts_over() -> void:
	var w := _floor(11)
	var r := WorldReader.new(w)
	var st := MinimapState.new()
	st.update(r)
	var door := st.unknown_doors(r)[0]
	var d := r.floor_door_rooms(door)
	w.actors.set_pos(0, r.floor_room(d.y).get_center())
	st.update(r)
	assert_eq(st.discovered_count(), 2)
	var w2 := _floor(12, 2)
	var r2 := WorldReader.new(w2)
	assert_true(st.update(r2))
	assert_eq(st.discovered.size(), w2.floor_layout.rooms.size(), "sized for the new floor")
	assert_eq(st.discovered_count(), 1, "only the new floor's hall")
	assert_true(st.is_discovered(w2.floor_layout.start_room))


func test_the_views_draw_once_per_change() -> void:
	var w := _floor(11)
	var r := WorldReader.new(w)
	var map := Minimap.new()
	add_child_autofree(map)
	map.sync(r)
	await get_tree().process_frame
	await get_tree().process_frame
	var drawn := map.corner.draw_count()
	assert_gt(drawn, 0, "the corner map drew")
	assert_false(map.full_map_showing(), "the full map waits for the button")
	for k in 5:
		map.sync(r)
		await get_tree().process_frame
	assert_eq(map.corner.draw_count(), drawn, "no change, no redraw")
	w.actors.set_pos(0, w.player_pos() + Vector2(1.0, 0))
	map.sync(r)
	await get_tree().process_frame
	assert_eq(map.corner.draw_count(), drawn + 1, "a step redraws once")
	assert_eq(map.get_child_count(), 3, "two views and the corner's frame, no node per room")


func test_the_arrow_follows_the_walk_not_only_the_aim() -> void:
	var w := _floor(11)
	var r := WorldReader.new(w)
	var map := Minimap.new()
	add_child_autofree(map)
	# A fresh view with no walk points at the aim.
	w.aim_angle = 0
	map.sync(r)
	await get_tree().process_frame
	assert_almost_eq(map.corner.arrow_dir().x, 1.0, 0.001, "no walk: the aim (east)")
	# Aim east while walking west: the arrow points west, and the view redraws.
	var drawn := map.corner.draw_count()
	w.move_intent = Vector2i(-1, 0)
	map.sync(r)
	await get_tree().process_frame
	assert_almost_eq(map.corner.arrow_dir().x, -1.0, 0.001, "walking west: west")
	assert_gt(map.corner.draw_count(), drawn, "the turn redraws")
	# Stop walking: it stays west.
	w.move_intent = Vector2i.ZERO
	map.sync(r)
	await get_tree().process_frame
	assert_almost_eq(map.corner.arrow_dir().x, -1.0, 0.001, "standing: still west")


## v0.10.5 W3-V3 (DRAW_GROWTH): the rooms, doors and icons go into one texture, rendered again only when the map
## changes (a room found), not on the hero's every step; the view draws that texture and the arrow.
func test_the_map_layer_renders_once_per_map_change_not_per_step() -> void:
	var w := _floor(11)
	var r := WorldReader.new(w)
	var map := Minimap.new()
	add_child_autofree(map)
	map.sync(r)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(map.corner.layer_cached(), "the corner map uses its layer")
	var layer := map.corner.layer_draw_count()
	assert_eq(layer, 1, "the layer rendered once for the floor")
	var drawn := map.corner.draw_count()
	for k in 4:
		w.actors.set_pos(0, w.player_pos() + Vector2(0.5, 0))
		map.sync(r)
		await get_tree().process_frame
	assert_gt(map.corner.draw_count(), drawn, "the steps redraw the view (the arrow, the scroll)")
	assert_eq(map.corner.layer_draw_count(), layer, "but not the layer")
	var st := map.state
	var start := w.floor_layout.start_room
	var d := r.floor_door_rooms(st.unknown_doors(r)[0])
	w.actors.set_pos(0, r.floor_room(d.y if d.x == start else d.x).get_center())
	map.sync(r)
	await get_tree().process_frame
	assert_eq(
		map.corner.layer_draw_count(), layer + 1, "a room found renders the layer again, once"
	)
