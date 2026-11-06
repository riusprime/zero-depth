extends GutTest
## v0.9.5 DR (owner Q6: "falling bars on every seal; Overrun's doorway has a small red floor rune instead of the glowing
## frame"): every sealed door drops the Lockdowns' bars (the locked room, an arena room on floor rules 20, the
## Overrun), no translucent barrier box stands in a doorway, and the Overrun's red rune lies outside each doorway
## before the seal and goes dark once the room is cleared.


func _view(w: World) -> WorldViewRoot:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	v.stage.prop_style = biome.id
	add_child_autofree(v)
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	return v


func _overrun_world() -> World:
	for s in range(1, 60):
		var w := SaveLab.floor_world(s, 2)
		if Overrun.enabled(w):
			LockLab.calm(w)
			return w
	return null


func _kill_inside(w: World) -> void:
	if not w.arenas.sealed():
		return
	var rect := w.floor_layout.rooms[w.arenas.room].grow(Arenas.ROOM_MARGIN_M)
	for i in range(1, w.actors.size()):
		var at := w.actors.pos(i)
		if w.actors.dead[i] == 0 and w.actors.invuln[i] == 0 and rect.has_point(at):
			Damage.hit(w, i, 100000, w.actors.ids[0], w.actors.ids[0], w.take_root(), 0, at, at)


func _barrier_boxes(v: WorldViewRoot) -> int:
	var n := 0
	for c in v.arenas.get_children():
		if c.name == "ArenaBarrier":
			n += 1
	return n


func test_the_overrun_has_a_floor_rune_before_the_seal_and_bars_on_it() -> void:
	var w := _overrun_world()
	assert_not_null(w, "a floor-2 seed with an Overrun room")
	if w == null:
		return
	var f := w.floor_layout
	var v := _view(w)
	var runes := v.overrun_doors
	var bars := v.lockdowns
	assert_not_null(bars, "the bars are built for the Overrun too")
	assert_eq(runes.rune_count(), f.overrun_doors.size(), "a rune outside each doorway")
	assert_true(runes.is_lit(), "lit before the seal")
	assert_almost_eq(runes.energy(), OverrunDoorViews.ENERGY, 0.001, "a low glow")
	assert_true(runes.rune_material.disable_fog, "fog off")
	assert_eq(runes.rune_material.blend_mode, BaseMaterial3D.BLEND_MODE_ADD, "additive")
	assert_eq(bars.door_count(f.overrun_room), f.overrun_doors.size(), "bars for each doorway")
	assert_false(bars.bars_visible(f.overrun_room), "open: unseen above the doorways")
	for c in runes.get_children():  # outside: not inside the Overrun room
		var at := SimPlane.to_sim((c as Node3D).position)
		assert_false(f.rooms[f.overrun_room].has_point(at), "the rune lies outside the room")
	# The seal.
	w.actors.set_pos(0, Overrun.reward_spot(f))
	w.step(InputFrame.new())
	v.sync()
	assert_true(w.arenas.sealed())
	bars._process(LockdownView.DROP_S * 2.0)
	assert_eq(bars.bars_down(f.overrun_room), 1.0, "the bars fall into the doorways")
	assert_true(bars.bars_visible(f.overrun_room))
	assert_eq(_barrier_boxes(v), 0, "no glowing barrier box")
	assert_eq(v.arenas.barrier_count(), 0)
	# The clear.
	var guard := 0
	while not w.overrun.cleared() and guard < 12000:
		guard += 1
		w.actors.invuln[0] = 5
		_kill_inside(w)
		w.step(InputFrame.new())
	assert_true(w.overrun.cleared(), "cleared")
	v.sync()
	assert_false(runes.is_lit(), "the rune goes dark")
	assert_almost_eq(runes.energy(), 0.0, 0.001)
	bars._process(LockdownView.RISE_S + 0.1)
	assert_eq(bars.bars_down(f.overrun_room), 0.0, "and the bars rise")


func test_an_arena_room_on_rules_20_drops_the_lockdown_bars_and_no_box() -> void:
	var room := -1
	var w: World
	for s in range(1, 60):
		w = SaveLab.floor_world(s, 2)
		if w.lockdown != null and not w.floor_layout.arena_rooms.is_empty():
			room = w.floor_layout.arena_rooms[0]
			break
	assert_gte(room, 0, "a floor with an arena room")
	if room < 0:
		return
	LockLab.calm(w)
	var v := _view(w)
	assert_eq(v.arenas.frame_count(), 0, "no amber frames: it is a locked room")
	assert_eq(
		v.lockdowns.door_count(room),
		ArenaRooms.doors_of(w.floor_layout, room).size(),
		"bars waiting"
	)
	LockLab.enter(w, room)
	v.sync()
	v.lockdowns._process(LockdownView.DROP_S * 2.0)
	assert_eq(v.lockdowns.bars_down(room), 1.0, "the bars fell")
	assert_eq(_barrier_boxes(v), 0, "no translucent barrier")
