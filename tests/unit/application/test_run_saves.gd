extends GutTest
## v0.4.0 SV: the run save file (RunSaveStore: atomic write, envelope, save_version-only compatibility, a bad file
## ignored and kept) and when the run saves (RunSaver: the start hall and each first room entry, close, discard).

var _dir := ""


func before_each() -> void:
	_dir = "user://test_saves_%d" % Time.get_ticks_usec()


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for f in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(f))
		DirAccess.remove_absolute(_dir)


func _store() -> RunSaveStore:
	return RunSaveStore.new(_dir.path_join("run.save"))


func _payload() -> Dictionary:
	return {
		"version": RunSaver.PAYLOAD_VERSION,
		"run": {"run_seed": 5},
		"rooms": PackedByteArray([1, 0, 1]),
		"world": {"format": 1, "world": {"tick": 9, "xs": PackedFloat32Array([0.5, -0.0])}},
	}


func test_write_then_read_gives_the_payload_back_and_leaves_no_tmp() -> void:
	var s := _store()
	assert_false(s.has_save(), "no save yet")
	assert_true(s.write(_payload()))
	assert_true(FileAccess.file_exists(s.path))
	assert_false(FileAccess.file_exists(s.path + ".tmp"), "the .tmp was renamed over the save")
	assert_eq(var_to_bytes(s.read()), var_to_bytes(_payload()), "the same payload, byte for byte")
	assert_eq(s.last_error, "")
	assert_true(RunSaveStore.new(s.path).has_save(), "another store reads the same file")


func test_an_async_write_lands_and_writes_keep_their_order() -> void:
	var s := _store()
	var a := _payload()
	var b := _payload()
	b["rooms"] = PackedByteArray([1, 1, 1])
	s.write_async(a)
	s.write_async(b)
	assert_true(s.flush())
	assert_eq(s.read()["rooms"], PackedByteArray([1, 1, 1]), "the later write wins")


func test_a_corrupt_file_is_ignored_and_kept() -> void:
	var s := _store()
	DirAccess.make_dir_recursive_absolute(_dir)
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string("not a save at all")
	f.close()
	assert_eq(s.read(), {}, "nothing to continue from")
	assert_string_contains(s.last_error, "not a run save")
	assert_false(FileAccess.file_exists(s.path), "moved aside")
	var kept := Array(DirAccess.get_files_at(_dir)).filter(
		func(n: String) -> bool: return n.begins_with("run.bad.")
	)
	assert_eq(kept.size(), 1, "kept on disk as run.bad.*.save, never deleted (EI-09)")
	assert_false(s.has_save())


func test_a_damaged_body_fails_its_checksum() -> void:
	var s := _store()
	s.write(_payload())
	var bytes := FileAccess.get_file_as_bytes(s.path)
	bytes[bytes.size() - 3] ^= 0x5A
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	assert_eq(s.read(), {})
	assert_string_contains(s.last_error, "checksum")


func test_another_save_version_is_ignored() -> void:
	var bytes := RunSaveStore.encode(_payload())
	bytes.encode_u32(4, RunSaveStore.SAVE_VERSION + 1)
	var r := RunSaveStore.decode(bytes)
	assert_eq(r[0], {})
	assert_string_contains(r[1], "save_version")
	assert_eq(RunSaveStore.decode(PackedByteArray())[1], "not a run save")


func test_delete_and_memory_mode() -> void:
	var s := _store()
	s.write(_payload())
	s.delete()
	assert_false(FileAccess.file_exists(s.path))
	assert_eq(s.read(), {})
	var m := RunSaveStore.new("")
	m.write_async(_payload())
	assert_true(m.has_save(), "memory mode keeps the bytes")
	m.delete()
	assert_false(m.has_save())


func test_run_state_round_trips_through_the_payload() -> void:
	var run := SaveLab.run_state(321, 2, &"gun")
	run.carry = {&"shards": 40, &"items_owned": PackedInt32Array([3, 1])}
	run.ticks_done = 5000
	run.kills_done = 77
	var w := SaveLab.build_floor(run)
	var p := RunSaver.payload_of(w, run, 99, PackedByteArray([1]))
	assert_true(RunSaver.is_usable(p))
	var back := RunSaver.run_from(bytes_to_var(var_to_bytes(p)), run.table)
	assert_eq(back.run_seed, 321)
	assert_eq(back.floor_index, 2)
	assert_eq(back.build_id, &"gun")
	assert_eq(back.biome_order, run.biome_order)
	assert_eq(back.carry, run.carry)
	assert_eq([back.ticks_done, back.kills_done], [5000, 77])
	assert_eq(back.floor_seed(), run.floor_seed(), "the same floor seed, so the same floor")
	assert_eq(int(p["run"]["stage_seed"]), 99)
	assert_false(RunSaver.is_usable({"version": 0}))
	assert_eq(back.routes, run.routes, "v0.5.0 RT: the routes too")


## v0.5.0 RT: a Deep run's route per floor survives the save, so Continue rebuilds a Deep floor as Deep.
func test_the_routes_round_trip_through_the_payload() -> void:
	var run := SaveLab.run_state(55, 3, &"blade", Routes.Route.DEEP)
	var w := SaveLab.build_floor(run)
	var p := RunSaver.payload_of(w, run, 1, PackedByteArray([1]))
	assert_eq(int(p["version"]), RunSaver.PAYLOAD_VERSION)
	var back := RunSaver.run_from(bytes_to_var(var_to_bytes(p)), run.table)
	assert_eq(back.routes, PackedInt32Array([0, 1, 1]))
	assert_true(back.is_deep(), "floor 3 is Deep again")
	assert_eq(back.route_permille(), run.table.deep_scale_permille)


## The first room the player walks into saves, after the tick of the entry; the same room again doesn't.
func test_a_first_room_entry_saves_at_that_tick() -> void:
	var run := SaveLab.run_state(11, 1)
	var w := SaveLab.build_floor(run)
	var saver := RunSaver.new(RunSaveStore.new(""))
	saver.begin_floor(w, run, 11)
	assert_eq(saver.entries, 1, "the floor's start hall saves at once")
	var f := w.floor_layout
	assert_eq(saver.rooms[f.start_room], 1)
	assert_eq(int(saver.last["tick"]), 0)
	var bot := FightBot.new(2)
	for i in 30:
		w.step(SaveLab.frame(w, bot))
		assert_false(saver.after_tick(w, run, 11), "still in the start hall")
	var other := f.neighbours(f.start_room)[0]
	w.actors.set_pos(0, f.rooms[other].get_center())
	w.vel = Vector2.ZERO
	w.step(InputFrame.new())
	var h := w.state_hash()
	assert_true(saver.after_tick(w, run, 11), "a first entry saves")
	assert_eq(saver.entries, 2)
	assert_eq(saver.rooms[other], 1)
	assert_eq(int(saver.last["tick"]), w.tick, "taken right after the entry tick")
	w.step(InputFrame.new())
	assert_false(saver.after_tick(w, run, 11), "the same room doesn't save twice")
	var saved := saver.store.read()
	var base := SaveLab.build_floor(RunSaver.run_from(saved, run.table))
	assert_not_null(World.from_snapshot(saved["world"], base))
	assert_eq(base.state_hash(), h, "the save resumes at that room's entry")
	assert_eq(saved["rooms"], saver.rooms)


func test_resume_keeps_the_rooms_and_close_and_discard() -> void:
	var run := SaveLab.run_state(12, 1)
	var w := SaveLab.build_floor(run)
	var store := RunSaveStore.new(_dir.path_join("run.save"))
	var saver := RunSaver.new(store)
	var rooms := PackedByteArray()
	rooms.resize(w.floor_layout.room_count())
	rooms[0] = 1
	rooms[1] = 1
	saver.begin_floor(w, run, 12, rooms)
	assert_eq(saver.entries, 0, "a resumed floor doesn't save again at once")
	assert_eq(saver.rooms, rooms, "its rooms entered come back")
	saver.begin_floor(w, run, 12)
	saver.close()
	assert_true(store.has_save(), "on close the last room entry is on disk")
	assert_false(store.is_writing())
	w.actors.hp[0] = 0
	w.actors.dead[0] = 1
	saver.begin_floor(w, run, 12)
	saver.discard()
	assert_false(store.has_save(), "a death deletes the save")
	assert_false(saver.after_tick(w, run, 12), "nothing saves after the run ended")
