extends GutTest
## v0.7.5 BF3 (owner N15; BOSS_FIGHTS.md "Fireball looks", "Readable"): the Siege Engine's cannon embers (orange, a
## smoke trail that doesn't glow) and the Foundry's white-yellow molten drops are drawn in their looks, never the
## hero's colours; the Slag Fountain's drops are drawn in the air on an arc before they land; the Mortar Grid's board
## and the Molten Flood's rows are drawn where they strike (EI-07); the Foundry's model takes its shielded pose while
## the fountain runs.

const LONG := 1 << 20


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _world(id: StringName, player_at: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


func test_the_two_looks_are_set_and_keep_off_the_heros_colours() -> void:
	var hero := [
		ThemePalette.color(&"player_core"), HeatLooks.HOT, HeatLooks.OVERCLOCK, HeatLooks.WHITE_HOT
	]
	for key: StringName in [&"cannon_ember", &"molten_drop"]:
		assert_true(FireballViews.LOOKS.has(key), "%s has its own look" % key)
		var look := FireballViews.look_of(key)
		for c: Color in hero:
			assert_gt(_dist(look["core"], c), 0.2, "%s is not a hero colour" % key)
		assert_gt((look["core"] as Color).get_luminance(), 0.55, "a bright core")
		assert_lt((look["edge"] as Color).get_luminance(), 0.15, "a dark edge")
	assert_true(FireballViews.look_of(&"cannon_ember").get("smoke", false), "a smoke trail")
	var core: Color = FireballViews.look_of(&"cannon_ember")["core"]
	assert_gt(core.r, core.g, "orange: red over green")
	assert_gt(core.g, core.b, "and green over blue")
	var drop: Color = FireballViews.look_of(&"molten_drop")["core"]
	assert_gt(drop.g, 0.85, "white-yellow")
	assert_lt(drop.b, drop.g, "yellow, not white")


func test_the_cannon_embers_draw_with_an_unlit_smoke_trail() -> void:
	var s := _world(&"siege_engine", Vector2(9, 0))
	var w: World = s[0]
	BossLab.start(w, w.actors.index_of(s[1]), &"turret_cross")
	CombatLab.idle(w, 90)
	var reader := WorldReader.new(w)
	var fb := FireballViews.new()
	add_child_autofree(fb)
	fb.sync(reader)
	assert_gt(reader.projectile_count(), 0)
	assert_eq(fb.ball_count(&"cannon_ember"), reader.projectile_count(), "every ember in its look")
	# v0.8.0 AV: shaded 3D looks; the smoke trail is mixed (not added light) at plain brightness, the core glows.
	var trail: MultiMeshInstance3D = fb.get_node("cannon_ember_trail")
	var mat := trail.material_override as ShaderMaterial
	assert_eq(mat.shader, FireballShaders.trail(false), "smoke doesn't glow")
	assert_eq(float(mat.get_shader_parameter("glow")), 1.0)
	var core: MultiMeshInstance3D = fb.get_node("cannon_ember_core")
	assert_gt(
		float((core.material_override as ShaderMaterial).get_shader_parameter("energy")),
		1.0,
		"the core does"
	)


func test_the_slag_fountains_drops_are_drawn_in_the_air_then_as_fireballs() -> void:
	var s := _world(&"foundry", Vector2(0, 7))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"slag_fountain")
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	CombatLab.idle(w, atk.windup_ticks + 10)
	var reader := WorldReader.new(w)
	var fb := FireballViews.new()
	add_child_autofree(fb)
	fb.sync(reader)
	var drops := reader.boss_rain(w.actors.index_of(aid))
	assert_gt(drops.size(), 0)
	assert_eq(fb.rain_count(), drops.size(), "each drop in the air is drawn")
	assert_eq(fb.ball_count(&"molten_drop"), drops.size(), "in the molten look")
	assert_eq(fb.count(), 0, "no shot yet")
	var d: Array = drops[0]
	var mid := FireballViews.rain_point(d[0], d[1], 0.5)
	var land := FireballViews.rain_point(d[0], d[1], 1.0)
	assert_gt(mid.y, FireballViews.RAIN_FROM_Y, "it arcs up")
	assert_almost_eq(land.y, FireballViews.HEIGHT, 0.001, "and lands at the fireballs' height")
	assert_lt(land.distance_to(SimPlane.to_3d(d[1], FireballViews.HEIGHT)), 0.001, "where it lands")
	fb._process(0.016)
	assert_eq(fb.rain_count(), drops.size(), "drawn between ticks too")
	CombatLab.idle(w, atk.pattern.rain_ticks)
	fb.sync(reader)
	assert_gt(fb.count(), 0, "landed: drawn as fireballs")
	assert_eq(fb.ball_count(&"molten_drop"), fb.count() + fb.rain_count())


func test_the_mortar_grid_draws_one_colour_and_strikes_what_it_drew() -> void:
	var pr := PlayerTable.starting_values().radius_m
	var s := _world(&"siege_engine", Vector2(7, 0))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"mortar_grid")
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	CombatLab.idle(w, atk.windup_ticks - 2)
	var reader := WorldReader.new(w)
	var tg := reader.telegraph(w.actors.index_of(aid))
	var tv := TelegraphViews.new()
	add_child_autofree(tv)
	tv.sync(reader)
	assert_eq(tv.count(), 1, "the board is drawn")
	assert_true(tg["locked"])
	var drawn := []
	for item: Dictionary in tg["items"]:
		drawn.append(item["center"])
	assert_eq(drawn.size(), 23, "all but the two safe cells of a 5 x 5 board (v0.9.5 BH2)")
	var discs := BossDodge.grid_discs(w, w.actors.index_of(aid), 0)
	assert_eq(PackedVector2Array(drawn), discs, "drawn = struck (EI-07)")
	var r: float = tg["items"][0]["radius"]
	for off in [0.0, r + pr - 0.04, r + pr + 0.04]:
		var c: Vector2 = drawn[0]
		var p := c + Vector2(0, off)
		var inside := false
		for d: Vector2 in discs:
			inside = inside or AttackShapes.disc_touches(d, r, p, pr)
		var s2 := _world(&"siege_engine", Vector2(7, 0))
		var w2: World = s2[0]
		BossLab.start(w2, w2.actors.index_of(s2[1]), &"mortar_grid")
		var hit := false
		for t in atk.windup_ticks + 2:
			var stand: Vector2 = Vector2(7, 0) if t <= atk.windup_ticks - atk.lock_ticks else p
			w2.actors.set_pos(0, stand)
			var seq := w2.last_event_seq()
			w2.step(InputFrame.new())
			for e in w2.events_since(seq):
				hit = hit or (e.kind == SimEvent.Kind.DAMAGE and e.target_id == w2.actors.ids[0])
		assert_eq(hit, inside, "offset %.2f: hit iff inside a drawn circle" % off)


func test_the_molten_flood_draws_its_rows_dull_then_flashing_then_molten() -> void:
	var s := _world(&"foundry", Vector2(6, 2))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"molten_flood")
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	var reader := WorldReader.new(w)
	CombatLab.idle(w, 5)
	var tg := reader.telegraph(w.actors.index_of(aid))
	assert_true(tg["tracked"])
	assert_false(tg["locked"], "a dull outline while it follows your row")
	CombatLab.idle(w, atk.windup_ticks - atk.lock_ticks)
	assert_true(reader.telegraph(w.actors.index_of(aid))["locked"], "the lock flash")
	CombatLab.idle(w, atk.lock_ticks + 2)
	tg = reader.telegraph(w.actors.index_of(aid))
	assert_eq(tg.get("style", &""), &"molten", "standing molten rows")
	assert_eq((tg["obbs"] as Array).size(), 3)


func test_the_foundry_hunkers_while_its_fountain_runs() -> void:
	var s := _world(&"foundry", Vector2(0, 7))
	var w: World = s[0]
	var aid: int = s[1]
	var views := ActorViews.new()
	add_child_autofree(views)
	var reader := WorldReader.new(w)
	views.sync(reader)
	var avatar: BossAvatar = views.actor_node(aid).get_meta(&"enemy_avatar")
	BossLab.start(w, w.actors.index_of(aid), &"slag_fountain")
	for t in 40:
		w.step(InputFrame.new())
		views.sync(reader)
		avatar.advance(1.0 / 60.0)
	assert_gt(avatar.shielded_amount(), 0.5, "the door shut: the shielded pose")


func test_the_siege_engine_poses_its_new_moves_as_its_old_ones() -> void:
	var a: BossAvatar = SiegeEngineAvatar.new()
	a.setup(Color("#1A1A22"), &"outline")
	add_child_autofree(a)
	a.set_process(false)
	for spec in [
		[WorldReader.MOVE_PATTERN, WorldReader.MOVE_BOLT_FAN],
		[WorldReader.MOVE_GRID, WorldReader.MOVE_BARRAGE],
		[WorldReader.MOVE_MARKS, WorldReader.MOVE_BARRAGE],
		[WorldReader.MOVE_LANES, WorldReader.MOVE_RAIL],
	]:
		a.apply_state(
			{"tick": 1, "pos": Vector2.ZERO, "state": WorldReader.STATE_WINDUP, "move": spec[0]}
		)
		assert_eq(a._move, spec[1])
	var f: BossAvatar = FoundryAvatar.new()
	f.setup(Color("#1A1A22"), &"outline")
	add_child_autofree(f)
	f.set_process(false)
	for spec in [
		[WorldReader.MOVE_ROW_FLOOD, WorldReader.MOVE_FLOOD],
		[WorldReader.MOVE_PATTERN, WorldReader.MOVE_BARRAGE],
	]:
		f.apply_state(
			{"tick": 1, "pos": Vector2.ZERO, "state": WorldReader.STATE_WINDUP, "move": spec[0]}
		)
		assert_eq(f._move, spec[1])
