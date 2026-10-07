extends GutTest
## The audio director (v0.3.0 AU, L27): sim events and read-state edges map to the right cues, voices are limited,
## captions follow their setting, an override file replaces a cue, the ambience crossfades and telegraphs duck.
## Headless runs on the Dummy audio driver: these tests assert the cue ids the director chose, never what is heard.

const OVERRIDE_DIR := "user://audio_override"


func _director() -> AudioDirector:
	var d := AudioDirector.new()
	add_child_autofree(d)
	d.captions_forced = 0
	return d


func _cue(id: StringName, voices: int, cooldown: float) -> AudioCueDefinition:
	var c := AudioCueDefinition.new()
	c.id = id
	c.max_voices = voices
	c.cooldown_s = cooldown
	return c


func test_every_cue_loads_its_shipped_stream() -> void:
	var d := _director()
	assert_gt(d.cues.size(), 40, "the cue table loads from data/audio/cues")
	for id: StringName in d.cues:
		assert_not_null(d.stream_for(id), "%s has a stream" % id)


func test_the_mixer_limits_voices_and_drops_quick_repeats() -> void:
	var m := SfxMixer.new()
	var c := _cue(&"x", 2, 0.05)
	assert_true(m.allows(c, 0.0))
	m.note_play(c, 0.0, 1.0)
	assert_false(m.allows(c, 0.02), "inside the cooldown")
	assert_true(m.allows(c, 0.1))
	m.note_play(c, 0.1, 1.0)
	assert_false(m.allows(c, 0.2), "two voices already sound")
	assert_eq(m.active(&"x", 0.5), 2)
	assert_true(m.allows(c, 1.05), "the first voice ended")
	assert_eq(m.active(&"x", 1.05), 1)


func test_the_director_drops_a_play_over_the_voice_limit() -> void:
	var d := _director()
	var limit: int = d.cues[&"enemy_hit"].max_voices
	var allowed := 0
	for k in limit + 2:
		if d.play(&"enemy_hit"):
			allowed += 1
		d.advance(0.031)  # past the cooldown, well inside the sound
	assert_eq(allowed, limit)
	assert_false(d.play(&"no_such_cue"))


func test_damage_kill_and_guard_events_pick_their_cues() -> void:
	var w := CombatLab.world()
	var r := WorldReader.new(w)
	var ev := AudioEvents.new()
	var charger := w.actors.index_of(w.add_enemy(WorldReader.KIND_CHARGER, Vector2(6, 0)))
	w.actors.invuln[charger] = 0
	var me := w.actors.ids[0]
	ev.prime(r)
	Damage.hit(w, charger, 1, me, me, 0, SimEvent.TAG_PROJECTILE, Vector2.ZERO, Vector2(6, 0))
	assert_has(_ids(ev.collect(r)), &"bolt_hit")
	Damage.hit(w, charger, 1, me, me, 0, SimEvent.TAG_MELEE, Vector2.ZERO, Vector2(6, 0))
	assert_has(_ids(ev.collect(r)), &"enemy_hit")
	Damage.hit(w, charger, 999, me, me, 0, SimEvent.TAG_MELEE, Vector2.ZERO, Vector2(6, 0))
	assert_has(_ids(ev.collect(r)), &"enemy_death_charger")
	Damage.hit(w, 0, 5, 9, 9, 9, 0, Vector2(3, 0), Vector2.ZERO)
	assert_has(_ids(ev.collect(r)), &"hit_taken")


func test_a_swing_plays_its_slash_once() -> void:
	var w := CombatLab.world()
	var r := WorldReader.new(w)
	var ev := AudioEvents.new()
	ev.prime(r)
	var heard: Array = []
	w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY))
	heard.append_array(_ids(ev.collect(r)))
	for k in 5:
		w.step(InputFrame.new())
		heard.append_array(_ids(ev.collect(r)))
	assert_eq(heard.count(&"blade_slash_1"), 1, "the first slash, once: %s" % [heard])


func test_swing_and_attack_cue_tables() -> void:
	assert_eq(AudioEvents.swing_cue(WorldReader.MOTION_SLASH_RIGHT_TO_LEFT, 0), &"blade_slash_1")
	assert_eq(AudioEvents.swing_cue(WorldReader.MOTION_SLASH_LEFT_TO_RIGHT, 1), &"blade_slash_2")
	assert_eq(AudioEvents.swing_cue(WorldReader.MOTION_SLASH_RIGHT_TO_LEFT, 2), &"blade_slash_3")
	assert_eq(AudioEvents.swing_cue(WorldReader.MOTION_THRUST, 2), &"blade_thrust")
	assert_eq(AudioEvents.swing_cue(WorldReader.MOTION_SPIN, 3), &"blade_spin")
	assert_eq(AudioEvents.attack_cue(WorldReader.MOVE_SLAM_RING), &"boss_slam")
	assert_eq(AudioEvents.attack_cue(WorldReader.MOVE_RAIL), &"boss_laser")
	assert_eq(AudioEvents.attack_cue(WorldReader.MOVE_BARRAGE), &"boss_mortar")
	for k: int in AudioEvents.BOSS_FLAVOUR:
		assert_true(
			ResourceLoader.exists("res://data/audio/cues/%s.tres" % AudioEvents.BOSS_FLAVOUR[k])
		)
	for k: int in AudioEvents.DEATHS:
		assert_true(ResourceLoader.exists("res://data/audio/cues/%s.tres" % AudioEvents.DEATHS[k]))


func test_a_boss_windup_plays_the_warning_and_its_flavour() -> void:
	var w := BossLab.world()
	var r := WorldReader.new(w)
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(6, 0))
	var ev := AudioEvents.new()
	ev.prime(r)
	BossLab.start(w, i, &"fist_slam")
	var heard: Array = []
	for k in 240:
		w.step(InputFrame.new())
		heard.append_array(_ids(ev.collect(r)))
		if heard.has(&"boss_slam"):
			break
	assert_has(heard, &"boss_telegraph")
	assert_has(heard, &"boss_telegraph_gatekeeper")
	assert_has(heard, &"boss_slam", "the slam lands with its sound")


func test_low_hp_beats_a_heartbeat() -> void:
	var w := CombatLab.world()
	var r := WorldReader.new(w)
	var ev := AudioEvents.new()
	ev.prime(r)
	w.actors.hp[0] = r.player_max_hp() * 2 / 10
	var beats := 0
	for k in AudioEvents.HEARTBEAT_TICKS * 2:
		beats += _ids(ev.collect(r)).count(&"low_hp_heartbeat")
	assert_eq(beats, 2)
	w.actors.hp[0] = r.player_max_hp()
	assert_does_not_have(_ids(ev.collect(r)), &"low_hp_heartbeat")


func test_captions_follow_their_setting() -> void:
	var d := _director()
	var p := ProfileStore.new("")
	d.setup(p)
	d.captions_forced = -1
	assert_eq(GameSettings.get_value(p, "captions"), "off", "captions are off by default")
	d.play(&"portal_open")
	assert_eq(d.caption_text, "", "no caption while off")
	GameSettings.set_value(p, "captions", "on")
	d.advance(2.0)
	d.play(&"low_hp_heartbeat")
	assert_eq(d.caption_text, tr(&"CAPTION_LOW_HP"))
	assert_ne(d.caption_text, "CAPTION_LOW_HP", "the key is translated")
	d.advance(AudioDirector.CAPTION_S + 0.1)
	assert_eq(d.caption_text, "", "it times out")
	d.play(&"ui_move")
	assert_eq(d.caption_text, "", "a menu tick has no caption")


func test_a_boss_telegraph_ducks_the_world_sounds() -> void:
	var d := _director()
	var bus := AudioServer.get_bus_index("SFX")
	assert_gte(bus, 0, "the SFX bus exists")
	d.play(&"boss_telegraph")
	d.advance(0.1)
	d.advance(0.1)
	assert_lt(AudioServer.get_bus_volume_db(bus), -1.0, "ducked")
	d.advance(3.0)
	d.advance(0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), 0.0, 0.01, "back up")


func test_ambience_loops_and_crossfades_on_a_floor_change() -> void:
	var d := _director()
	d.set_ambience(&"ruins")
	var first := d.ambience_player()
	assert_true(first.stream is AudioStreamWAV)
	assert_ne((first.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED, "it loops")
	d.advance(AudioDirector.AMBIENCE_FADE_S + 0.1)
	assert_almost_eq(first.volume_db, d.cues[&"ruins"].volume_db, 0.01, "faded in")
	d.set_ambience(&"night_rocks")
	var second := d.ambience_player()
	assert_ne(second, first, "the next biome fades in on the other player")
	d.advance(AudioDirector.AMBIENCE_FADE_S * 0.5)
	assert_lt(first.volume_db, d.cues[&"ruins"].volume_db, "the old loop is fading out")
	assert_gt(second.volume_db, AudioDirector.SILENT_DB, "the new loop is fading in")
	d.set_ambience(&"night_rocks")
	assert_eq(d.ambience_player(), second, "the same biome keeps playing")
	d.set_ambience(&"")
	assert_eq(d.ambience_id(), &"")


func test_an_override_file_replaces_the_shipped_sound() -> void:
	DirAccess.make_dir_recursive_absolute(OVERRIDE_DIR)
	var path := OVERRIDE_DIR + "/ui_back.wav"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(_tiny_wav(4410))
	f.close()
	var d := _director()
	var s := d.stream_for(&"ui_back")
	assert_true(s is AudioStreamWAV)
	assert_almost_eq(s.get_length(), 0.1, 0.01, "the override's length, not the shipped file's")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_null(AudioDirector.override_stream(&"ui_back"), "gone again")


func _ids(reqs: Array) -> Array:
	return reqs.map(func(q: Array) -> StringName: return q[0])


## A silent mono 16-bit 44.1 kHz WAV of n frames.
static func _tiny_wav(n: int) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_data("RIFF".to_ascii_buffer())
	b.put_32(36 + n * 2)
	b.put_data("WAVEfmt ".to_ascii_buffer())
	b.put_32(16)
	b.put_16(1)
	b.put_16(1)
	b.put_32(44100)
	b.put_32(88200)
	b.put_16(2)
	b.put_16(16)
	b.put_data("data".to_ascii_buffer())
	b.put_32(n * 2)
	var zeros := PackedByteArray()
	zeros.resize(n * 2)
	b.put_data(zeros)
	return b.data_array


func test_heat_edges_ask_for_their_sounds_once() -> void:
	var cool := {"tier_tick": -1, "overheat_tick": -1, "vent_tick": -1, "tier": 0}
	assert_eq(AudioEvents._heat_edges({}), [-1, -1, -1, 0], "no heat: no edges")
	assert_eq(AudioEvents._heat_edges(cool), [-1, -1, -1, 0])
	var hot := {"tier_tick": 120, "overheat_tick": -1, "vent_tick": -1, "tier": 1}
	assert_eq(AudioEvents._heat_edges(hot), [120, -1, -1, 1])
