extends GutTest
## The minimap through real input (v0.3.0 MM, owner L30): at floor start only the hall is on the map; walking (left
## stick) through its exit into the next room reveals that room; holding Tab, or pad Select, shows the full map, and
## letting go puts the corner map back.


func after_each() -> void:
	Input.action_release(&"map")


func test_walking_into_a_room_reveals_it_and_tab_shows_the_full_map() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(2)
	var hud: Hud = main.get_node("UI/Hud")
	var map := hud.minimap
	var r := main.driver.reader
	var start := r.floor_start_room()
	assert_eq(map.state.discovered_count(), 1, "only the start hall is known")
	assert_true(map.state.is_discovered(start))
	assert_true(map.corner.visible, "the corner map is up")
	assert_false(map.full_map_showing())
	var exits := map.state.unknown_doors(r)
	assert_eq(exits.size(), 1, "the hall's exit is flagged as the way on")
	var d := r.floor_door_rooms(exits[0])
	var room := d.y if d.x == start else d.x
	assert_false(map.state.is_discovered(room), "the next room is hidden")
	# A spot 2 m inside the next room, past the doorway (door approaches are kept clear on every floor).
	var side: Vector2 = MinimapView.SIDES[(r.floor_door_angle(exits[0]) / 1024) % 4]
	var into := side if room == d.y else -side
	var dr := r.floor_door_rect(exits[0])
	var spot := dr.get_center() + into * (absf(dr.size.dot(side)) * 0.5 + 2.0)
	var reached: bool = await e.walk_to(spot, 0.8)
	assert_true(reached, "walked into the next room")
	assert_true(map.state.is_discovered(room), "entering it put it on the map")
	assert_eq(map.state.current, room, "and it is the current room")
	assert_eq(map.state.discovered_count(), 2, "and nothing else was revealed")
	e.key(KEY_TAB, true)
	await e.frames(2)
	assert_true(map.full_map_showing(), "holding Tab shows the full map")
	assert_false(map.corner.visible, "in place of the corner map")
	assert_gt(map.full_map.draw_count(), 0, "it drew")
	e.key(KEY_TAB, false)
	await e.frames(2)
	assert_false(map.full_map_showing(), "letting go hides it")
	assert_true(map.corner.visible)
	e.joy_button(JOY_BUTTON_BACK, true)
	await e.frames(2)
	assert_true(map.full_map_showing(), "pad Select shows it too")
	e.joy_button(JOY_BUTTON_BACK, false)
	await e.frames(2)
	assert_false(map.full_map_showing())
