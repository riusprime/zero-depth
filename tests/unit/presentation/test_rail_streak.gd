extends GutTest
## The Siege Engine's rail streak (RailStreakViews): the owner's streak laid down in tiles behind the shot as it runs
## down its lane, each tile at the texture's own aspect (never stretched), read from the sim only, gone after its fade.


func _lane(len: float) -> Obb:
	return AttackShapes.lane(Vector2(-4, 2), 0, len, 0.6)


func test_the_texture_is_installed() -> void:
	assert_not_null(
		FxTextures.get_tex(RailStreakViews.TEX_ID), "assets/textures/vfx/fx_rail_streak.png"
	)
	var t := FxTextures.get_tex(RailStreakViews.TEX_ID)
	assert_almost_eq(
		float(t.get_width()) / (t.get_height() / float(RailStreakViews.ROWS)),
		RailStreakViews.STRIP_ASPECT,
		0.001,
		"a row of the sheet is STRIP_ASPECT times as long as it is tall"
	)


## Each tile's length on the floor over its width equals the share of the row it shows times the row's aspect.
func test_every_tile_keeps_the_textures_aspect() -> void:
	for len: float in [26.0, 11.2, 4.0, 2.8, 13.37]:
		var ts := RailStreakViews.tiles(len)
		var covered := 0.0
		for t in ts:
			assert_almost_eq(
				t.y / RailStreakViews.ROW_W_M,
				t.w * RailStreakViews.STRIP_ASPECT,
				1e-4,
				"no stretch"
			)
			assert_almost_eq(t.x, covered, 1e-4, "end to end")
			assert_lte(t.y, RailStreakViews.TILE_M + 1e-4)
			covered += t.y
		assert_almost_eq(covered, len, 1e-3, "the tiles cover the lane %.2f m" % len)


## The tiles appear in order, each on the tick the shot's front passes its start.
func test_tiles_appear_in_order_as_the_front_passes() -> void:
	var s := {"lanes": [_lane(26.0)], "seed": 5}
	var front := 0.0
	for tick in range(100, 112):
		front += 26.0 / 12.0
		RailStreakViews.lay(s, tick, PackedFloat32Array([front]))
	var laid: PackedFloat32Array = s["streak"][0]
	var ts := RailStreakViews.tiles(26.0)
	assert_eq(laid.size(), ts.size())
	for k in laid.size():
		assert_gte(laid[k], 100.0, "tile %d laid" % k)
		if k > 0:
			assert_gte(laid[k], laid[k - 1], "after the one before it")
		var due := 100 + int(floor(ts[k].x / (26.0 / 12.0)))  # the first tick the front is past its start
		assert_eq(int(laid[k]), due, "tile %d on the tick the front passes it" % k)
	assert_gt(laid[laid.size() - 1], laid[0], "laid over the shot's run, not all at once")


func test_it_draws_what_is_laid_then_clears_after_the_fade() -> void:
	var v: RailStreakViews = add_child_autofree(RailStreakViews.new())
	assert_true(v.installed)
	var s := {"lanes": [_lane(26.0)], "seed": 5}
	RailStreakViews.lay(s, 100, PackedFloat32Array([5.0]))
	var strikes: Array[Dictionary] = [s]
	v.draw(strikes, 100.0)
	assert_eq(v.drawn(), 2, "the two tiles the front has passed")
	RailStreakViews.lay(s, 101, PackedFloat32Array([INF]))
	v.draw(strikes, 101.0)
	assert_eq(v.drawn(), RailStreakViews.tiles(26.0).size(), "the rest laid")
	var ts := RailStreakViews.tiles(26.0)
	for t in ts:
		var tr3 := RailStreakViews.tile_transform(s["lanes"][0], t)
		assert_almost_eq(tr3.basis.x.length(), t.y, 1e-4, "a tile's length on the floor")
		assert_almost_eq(tr3.basis.z.length(), RailStreakViews.ROW_W_M, 1e-4, "its width")
		assert_almost_eq(absf(tr3.basis.x.dot(tr3.basis.z)), 0.0, 1e-4, "square to the lane")
	var last := RailStreakViews.tile_transform(s["lanes"][0], ts[ts.size() - 1])
	var lane: Obb = s["lanes"][0]
	var far := SimPlane.to_3d(lane.center + lane.axis_u * lane.half.x, RailStreakViews.FLOOR_Y)
	assert_almost_eq(
		(last.origin + last.basis.x * 0.5).distance_to(far),
		0.0,
		1e-3,
		"the last tile ends at the lane's end"
	)
	v.draw(strikes, 100.0 + RailStreakViews.HOLD + RailStreakViews.FADE + 1.0)
	assert_eq(v.drawn(), 0, "faded out")
	assert_lt(
		RailStreakViews.span(12), float(BossStrikeViews.LIFE[&"rail"]), "gone before the strike is"
	)


## Through the real sim: the Siege Engine's rail, the views synced from WorldReader each tick. The streak is laid
## over the shot's active ticks, in order, the sim's state unchanged by the reading, and nothing is left once over.
func test_a_real_rail_lays_its_streak_and_reads_only() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"siege_engine")
	BossLab.ensure_attack(w, &"siege_engine", &"rail")
	var aid := w.actors.ids[i]
	var reader := WorldReader.new(w)
	var views: BossStrikeViews = add_child_autofree(BossStrikeViews.new())
	w.actors.set_pos(0, Vector2(9, 0))
	BossLab.start(w, i, &"rail")
	var fronts := []
	var laid_ticks := {}
	for t in 130:  # its windup, its active ticks and the streak's fade, inside its recovery
		var j := w.actors.index_of(aid)
		if j < 0:
			break
		var f := reader.boss_lane_front(j, 0)
		if f >= 0.0:
			fronts.append(f)
		var before := w.state_hash()
		views.sync(reader)
		assert_eq(w.state_hash(), before, "the views read only")
		for s: Dictionary in views._strikes:
			if s.has("streak"):
				for x: float in s["streak"][0]:
					if x >= 0.0:
						laid_ticks[x] = true
		w.step(InputFrame.new())
	assert_gt(fronts.size(), 2, "the shot runs over several ticks")
	for k in range(1, fronts.size()):
		assert_gte(fronts[k], fronts[k - 1], "its front only moves on")
	assert_gt(laid_ticks.size(), 2, "the tiles were laid on several ticks, not at once")
	assert_eq(views.streak.drawn(), 0, "the streak has faded by now")
	for k in 60:
		views._tick += 1
		views._prune()
	assert_eq(views.strike_count(), 0, "the strike is gone")


func test_nothing_leaks() -> void:
	var v := RailStreakViews.new()
	add_child(v)
	var s := {"lanes": [_lane(10.0)], "seed": 1}
	RailStreakViews.lay(s, 0, PackedFloat32Array([INF]))
	var strikes: Array[Dictionary] = [s]
	v.draw(strikes, 1.0)
	v.free()
	assert_no_new_orphans()
