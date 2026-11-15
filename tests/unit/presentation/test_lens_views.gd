extends GutTest
## The Hive Lens's drones, Lattice and burnt glass as the player sees them, each view built from WorldReader only, in
## LensLab's walled 24 m room: a thread into the Lens and a shield ring per feeding drone (a ring and its thread gone
## with its drone, with a flash), the bar's fed tone and a pip per drone, the gold glow on a drone a Focus Beam's lane
## crosses and its burst and snapping thread when the beam cuts it, the Lattice's cast (the Lens charging, its drones
## brightening), each strand on the reader's exact pair of points and width and gone with its drone, the orbit trails,
## each glass strip on its exact rectangle and cooling; nothing stays once the fight ends; the reduced-motion path; the
## borrowed sounds; no words.

const DT := 1.0 / 60.0
const P1 := 0
const P2 := 1
const P3 := 2
const PLACES := [Vector2(4, 0), Vector2(0, 8), Vector2(-7.07, -7.07)]
const EPS := 0.02


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _pack() -> PackFx:
	var fx := PackFx.new()
	add_child_autofree(fx)
	return fx


func _view(script: GDScript, fx: PackFx) -> Node:
	var v: Node = script.new()
	add_child_autofree(v)
	v.set_process(false)
	v.set(&"pack_fx", fx)
	return v


## The Hive Lens hushed (only its lattice runs, unless `no_lattice`) in phase `phase`. Returns [world, its id].
func _lens(phase: int, hero_at := Vector2(-10, 10), no_lattice := false) -> Array:
	var s := LensLab.fight(hero_at)
	var w: World = s[0]
	LensLab.hush(w, s[1])
	if no_lattice:
		LensLab.lens(w, s[1]).lat_phase = 9
	LensLab.set_phase(w, s[1], phase)
	w.step(InputFrame.new())
	return s


func _three(w: World, aid: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for at: Vector2 in PLACES:
		out.append(LensLab.drone(w, aid, at))
	return out


func _kill(w: World, aid: int) -> void:
	var j := w.actors.index_of(aid)
	w.actors.hp[j] = 0
	w.actors.dead[j] = 1


## One tick, each view synced and advanced after it; `hold` pins drones (id -> place) while they do not orbit.
func _tick(w: World, r: WorldReader, views: Array, hold := {}) -> void:
	for id: int in hold:
		var j := w.actors.index_of(id)
		if j >= 0 and w.actors.state[j] != BossLattice.ORBIT:
			w.actors.set_pos(j, hold[id])
	w.step(InputFrame.new())
	for v: Node in views:
		v.call(&"sync", r)
		if v.has_method(&"advance"):
			v.call(&"advance", DT)


func _until(w: World, r: WorldReader, views: Array, done: Callable, limit: int, hold := {}) -> bool:
	for k in limit:
		if done.call():
			return true
		_tick(w, r, views, hold)
	return done.call()


func _pins(ids: PackedInt32Array) -> Dictionary:
	var out := {}
	for n in ids.size():
		out[ids[n]] = PLACES[n]
	return out


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func test_each_feeding_drone_has_a_thread_into_the_lens_and_a_ring_of_its_shield() -> void:
	var s := _lens(P2, Vector2(-10, 10), true)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var feed: LensFeedViews = _view(LensFeedViews, fx)
	var ids := _three(w, s[1])
	_tick(w, r, [feed], _pins(ids))
	var lens := r.boss_lens()
	assert_eq(lens["drones"].size(), 3, "three feed it")
	assert_eq(feed.threads().size(), 3, "a thread from each")
	assert_eq(feed.layers(), 3, "a ring of its shield for each")
	var at := _flat(SimPlane.to_3d(r.actor_pos(int(lens["boss"]))))
	for d: Dictionary in lens["drones"]:
		var found := false
		for t: Array in feed.threads():
			if _flat(t[0]).distance_to(_flat(SimPlane.to_3d(d["position"]))) < EPS:
				found = true
				assert_lt(_flat(t[1]).distance_to(at), EPS, "it runs into the Lens")
		assert_true(found, "drone %d's thread starts on it" % d["id"])
		var n := feed.thread_node(int(d["id"]))
		assert_not_null(n, "the pack's beam")
		if n != null:
			assert_almost_eq(LensLooks.beam_radius(n), LensFeedViews.THREAD_R, 0.005, "thin")
	var flashes := fx.live_count(&"impact")
	_kill(w, ids[0])
	_tick(w, r, [feed], _pins(ids))
	assert_eq(feed.threads().size(), 2, "its thread goes with it")
	assert_eq(feed.layers(), 2, "and a ring of the shield")
	assert_gt(fx.live_count(&"impact"), flashes, "with a flash")


func test_no_feeding_read_in_the_first_phase() -> void:
	var s := _lens(P1, Vector2(-10, 10), true)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var feed: LensFeedViews = _view(LensFeedViews, _pack())
	var bar := BossBar.new()
	add_child_autofree(bar)
	var ids := _three(w, s[1])
	_tick(w, r, [feed, bar], _pins(ids))
	assert_eq(feed.threads().size(), 0)
	assert_eq(feed.layers(), 0)
	assert_ne(bar.tone(), BossBarTones.FED)
	assert_eq(bar.shield_pips(), 0)


func test_the_bar_turns_its_fed_tone_with_a_pip_per_feeding_drone() -> void:
	var s := _lens(P2, Vector2(-10, 10), true)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var bar := BossBar.new()
	add_child_autofree(bar)
	var ids := _three(w, s[1])
	_tick(w, r, [bar], _pins(ids))
	assert_eq(bar.tone(), BossBarTones.FED, "fed")
	assert_eq(bar.shield_pips(), 3, "a pip per drone")
	assert_eq(bar.phase_text().find("%"), -1, "no words added")
	_kill(w, ids[0])
	_tick(w, r, [bar], _pins(ids))
	assert_eq(bar.shield_pips(), 2)
	_kill(w, ids[1])
	_kill(w, ids[2])
	_tick(w, r, [bar], _pins(ids))
	assert_ne(bar.tone(), BossBarTones.FED, "none feed it")
	assert_eq(bar.shield_pips(), 0)


func test_a_drone_on_a_focus_beams_lane_glows_then_bursts_and_its_thread_snaps_back() -> void:
	var s := _lens(P2, Vector2(10, 0), true)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var feed: LensFeedViews = _view(LensFeedViews, fx)
	var on_line := LensLab.drone(w, s[1], Vector2(5, 0))
	var beside := LensLab.drone(w, s[1], Vector2(5, 2.5))
	var pins := {on_line: Vector2(5, 0), beside: Vector2(5, 2.5)}
	_tick(w, r, [feed], pins)
	assert_eq(feed.lane_glows().size(), 0, "no beam, no glow")
	BossLab.start(w, w.actors.index_of(s[1]), &"focus_beam")
	_tick(w, r, [feed], pins)
	_tick(w, r, [feed], pins)
	assert_eq(feed.lane_glows(), [on_line] as Array[int], "only the drone on its lane glows")
	var cut := func() -> bool: return feed.snapping() > 0
	assert_true(_until(w, r, [feed], cut, 200, pins), "the beam cuts it")
	assert_gt(fx.live_count(&"impact"), 0, "it bursts")
	assert_eq(feed.threads().size(), 2, "the live drone's thread and the one snapping back")
	for k in 20:
		_tick(w, r, [feed], pins)
	assert_eq(feed.snapping(), 0, "the snap is over")
	assert_eq(feed.threads().size(), 1, "one drone feeds it")


## Steps until the web rises, the drones pinned until they orbit; the views synced every tick.
func _web(w: World, r: WorldReader, views: Array, ids: PackedInt32Array) -> bool:
	var up := func() -> bool: return bool(r.boss_lens()["lattice"].get("running", false))
	return _until(w, r, views, up, 900, _pins(ids))


func _assert_strands_match(r: WorldReader, lat: LensLatticeViews) -> void:
	var want: Array = r.boss_lens()["lattice"]["strands"]
	var hw := float(r.boss_lens()["lattice"]["half_width"])
	assert_eq(lat.strands().size(), want.size(), "a strand drawn for each")
	for k in want.size():
		var d: Array = lat.strands()[k]
		var row: Dictionary = want[k]
		assert_lt(_flat(d[0]).distance_to(_flat(SimPlane.to_3d(row["from"]))), EPS, "its first end")
		assert_lt(_flat(d[1]).distance_to(_flat(SimPlane.to_3d(row["to"]))), EPS, "its last end")
		assert_almost_eq(float(d[2]), hw, 0.01, "as wide as the sim's strand")
		var n: Node3D = d[3]
		if "beam_length" in n:
			var tip: Vector3 = (
				n.global_position
				- n.global_transform.basis.z.normalized() * float(n.get("beam_length"))
			)
			assert_lt(_flat(tip).distance_to(_flat(d[1])), EPS, "the beam reaches its last end")


func test_the_cast_charges_then_each_strand_is_the_readers_pair_and_goes_with_its_drone() -> void:
	var s := _lens(P2)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var feed: LensFeedViews = _view(LensFeedViews, fx)
	var lat: LensLatticeViews = _view(LensLatticeViews, fx)
	var ids := _three(w, s[1])
	var views := [feed, lat]
	var casting := func() -> bool: return int(r.boss_lens()["lattice"].get("casting", -1)) >= 0
	assert_true(_until(w, r, views, casting, 900, _pins(ids)), "the cast begins")
	_tick(w, r, views, _pins(ids))
	assert_true(lat.charging(), "the Lens gathers light")
	assert_eq(lat.brightened(), 3, "its drones brighten")
	assert_eq(lat.strands().size(), 0, "no strand yet")
	assert_true(_web(w, r, views, ids), "the web rises")
	_tick(w, r, views)
	assert_false(lat.charging(), "the charge ends with the cast")
	assert_eq(lat.strands().size(), 4, "boss, three drones, boss: four strands")
	_assert_strands_match(r, lat)
	assert_eq(lat.orbit_trails(), 3, "each orbiting drone trails")
	assert_eq(feed.threads().size(), 0, "the strands carry the read while the web stands")
	for k in 40:
		_tick(w, r, views)
	_assert_strands_match(r, lat)  # they turn: still on the reader's points
	var dead_at := _flat(SimPlane.to_3d(w.actors.pos(w.actors.index_of(ids[1]))))
	_kill(w, ids[1])
	_tick(w, r, views)
	assert_eq(lat.strands().size(), 2, "its two strands are gone the same frame")
	_assert_strands_match(r, lat)
	for d: Array in lat.strands():
		assert_gt(_flat(d[0]).distance_to(dead_at), 1.0, "no strand starts at the dead drone")
		assert_gt(_flat(d[1]).distance_to(dead_at), 1.0, "nor ends there")
	assert_eq(lat.orbit_trails(), 2)


func test_each_glass_strip_lies_on_its_rectangle_and_cools_until_it_goes() -> void:
	var s := _lens(P3, Vector2(6, 0), true)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var lat: LensLatticeViews = _view(LensLatticeViews, _pack())
	BossLab.start(w, w.actors.index_of(s[1]), &"focus_beam_3")
	var laid := func() -> bool: return r.boss_lens()["glass"].size() == 3
	assert_true(_until(w, r, [lat], laid, 600), "three strips")
	_tick(w, r, [lat])
	assert_eq(lat.strips().size(), 3, "a strip drawn for each")
	var rows: Array = r.boss_lens()["glass"]
	var heat0: Array[float] = []
	for k in rows.size():
		var g: Dictionary = rows[k]
		var mi: MeshInstance3D = lat.strips()[k]
		var a: Vector2 = g["from"]
		var b: Vector2 = g["to"]
		var mid := _flat(SimPlane.to_3d((a + b) * 0.5))
		assert_lt(_flat(mi.transform.origin).distance_to(mid), EPS, "on its centre")
		assert_almost_eq(mi.transform.basis.x.length(), a.distance_to(b), EPS, "its length")
		assert_almost_eq(
			mi.transform.basis.z.length(), float(g["half_width"]) * 2.0, EPS, "its width"
		)
		var along := _flat(mi.transform.basis.x).normalized()
		var want := _flat(SimPlane.to_3d(b) - SimPlane.to_3d(a)).normalized()
		assert_almost_eq(absf(along.dot(want)), 1.0, 0.001, "along its line")
		heat0.append(float((mi.material_override as ShaderMaterial).get_shader_parameter("heat")))
	for k in 180:
		_tick(w, r, [lat])
	for k in lat.strips().size():
		var h := float(
			(lat.strips()[k].material_override as ShaderMaterial).get_shader_parameter("heat")
		)
		assert_lt(h, heat0[k], "strip %d cools" % k)
		assert_gt(h, 1.0 - LensLatticeViews.COOL - 0.01, "but still glows")
	var gone := func() -> bool: return r.boss_lens()["glass"].is_empty()
	assert_true(_until(w, r, [lat], gone, 400))
	_tick(w, r, [lat])
	assert_eq(lat.strips().size(), 0, "gone with it")


func test_nothing_stays_once_the_lens_is_gone() -> void:
	var s := _lens(P2)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var fx := _pack()
	var feed: LensFeedViews = _view(LensFeedViews, fx)
	var lat: LensLatticeViews = _view(LensLatticeViews, fx)
	var bar := BossBar.new()
	add_child_autofree(bar)
	var views := [feed, lat, bar]
	var ids := _three(w, s[1])
	assert_true(_web(w, r, views, ids))
	_tick(w, r, views)
	assert_gt(lat.hold.count(), 0)
	_kill(w, s[1])
	for k in 3:
		_tick(w, r, views)
	assert_eq(r.boss_lens(), {})
	assert_eq(feed.hold.count() + lat.hold.count(), 0, "no pack effect held")
	assert_eq(lat.strands().size() + feed.threads().size(), 0)
	assert_true(feed.quiet and lat.quiet, "the views quiet")
	for c in feed.get_children() + lat.get_children():
		assert_false((c as Node3D).visible, "%s hidden" % c.name)


func test_the_reduced_motion_path_builds_and_holds_still() -> void:
	ViewPrefs.reduced_motion = true
	var s := _lens(P2)
	var w: World = s[0]
	var r := WorldReader.new(w)
	var lat: LensLatticeViews = _view(LensLatticeViews, _pack())
	var ids := _three(w, s[1])
	assert_true(_web(w, r, [lat], ids))
	_tick(w, r, [lat])
	assert_eq(lat.strands().size(), 4, "the web is drawn")
	_assert_strands_match(r, lat)
	w.boss_fight.hl_s_from.append(w.tick)
	w.boss_fight.hl_s_until.append(w.tick + 300)
	w.boss_fight.hl_s_a.append(0)
	w.boss_fight.hl_s_x.append(-9.0)
	w.boss_fight.hl_s_y.append(-9.0)
	w.boss_fight.hl_s_len.append(6.0)
	for k in 10:
		_tick(w, r, [lat])
	assert_eq(lat.strips().size(), 1, "the glass is drawn")
	var clock: Variant = (lat.strips()[0].material_override as ShaderMaterial).get_shader_parameter(
		"clock"
	)
	assert_eq(float(clock), 0.0, "and it does not shimmer")


func test_the_lens_events_borrow_existing_sounds() -> void:
	for effect: StringName in LensCues.CUES:
		var e := SimEvent.new()
		e.effect_id = effect
		var out := []
		assert_true(LensCues.add(e, out), String(effect))
		var cue: StringName = out[0][0]
		assert_true(ResourceLoader.exists("res://data/audio/cues/%s.tres" % cue), "%s exists" % cue)
	for effect: StringName in [
		&"lens_drone_cut", &"lattice_cast", &"lattice_start", &"lattice_end", &"lens_glass_laid"
	]:
		assert_true(LensCues.CUES.has(effect), "%s sounds" % effect)
	var other := SimEvent.new()
	other.effect_id = &"not_a_lens_event"
	assert_false(LensCues.add(other, []))


func test_the_lens_effects_are_in_the_pack_table() -> void:
	var fx := _pack()
	for id: StringName in [
		LensFeedViews.THREAD_ID,
		LensFeedViews.LAYER_ID,
		LensFeedViews.FLASH_ID,
		LensFeedViews.CUT_ID,
		LensFeedViews.GLOW_ID,
		LensLatticeViews.STRAND_ID,
		LensLatticeViews.CHARGE_ID,
		LensLatticeViews.ORBIT_ID,
		LensLatticeViews.SPARK_ID,
		LensLatticeViews.SIZZLE_ID,
	]:
		assert_true(fx.has_id(id), String(id))


func test_the_views_hold_no_words() -> void:
	var fx := _pack()
	for script: GDScript in [LensFeedViews, LensLatticeViews]:
		var v: Node = _view(script, fx)
		assert_eq(v.find_children("*", "Label3D", true, false).size(), 0)
		assert_eq(v.find_children("*", "Label", true, false).size(), 0)
