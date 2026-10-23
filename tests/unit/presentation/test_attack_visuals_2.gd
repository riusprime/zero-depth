extends GutTest
## v0.8.0 AV part 2 (owner O7): every boss ground attack in the content (the move list comes from data/bosses) has a
## look: a styled marker (its pattern while it fills or once locked, the dull outline and no fill while it tracks) and
## a 3D strike that spawns on the very tick the sim strikes (read from WorldReader), from pooled MultiMeshes with fixed
## caps, thinned with Low density, stilled with reduced motion, its explosions, lights and marks within VfxCore's
## budgets, its colours off the hero's.

## Moves that are not ground attacks (shots and the vortex) or that have their own view (the shock lanes' spikes; the
## Hive Lens's Gaze and the Foundry's meltdown, v0.8.0 BS2, drawn by BossSignatureViews and tested in
## test_boss_signature_views_2.gd).
const NOT_GROUND := [
	WorldReader.MOVE_PATTERN,
	WorldReader.MOVE_BOLT_FAN,
	WorldReader.MOVE_PULL,
	WorldReader.MOVE_ROW_LANES,
	WorldReader.MOVE_GAZE,
	WorldReader.MOVE_MELT,
	WorldReader.MOVE_TIDE,  # v0.9.0 NB1: the Pull is the whole room's current (TideViews), not a marker
]


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	ViewPrefs.reduced_motion = false


func after_each() -> void:
	ViewPrefs.effects_density = "high"
	ViewPrefs.reduced_motion = false


## [boss id, attack id, kind, move] of every ground attack in the content.
func _ground_attacks() -> Array:
	var out := []
	for t in BossLab.tables():
		for atk in t.attacks:
			if not NOT_GROUND.has(atk.move):
				out.append([t.id, atk.id, t.kind, atk.move])
	return out


func _fight(boss: StringName, attack_id: StringName) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, boss, Vector2.ZERO)
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(5, 2))
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	BossLab.start(w, i, attack_id)
	return [w, aid]


## The tick the sim strikes, read from the world's own state (not from the view): a marker or grid circle locked at
## 1000, a leap landing, a burrow coming up, else the windup turning active.
func _sim_strikes(w: World, aid: int, move: int, was: Dictionary) -> bool:
	var i := w.actors.index_of(aid)
	if i < 0:
		return false
	var reader := WorldReader.new(w)
	var state := w.actors.state[i]
	var hidden := reader.boss_hidden(i)
	var out := false
	match move:
		WorldReader.MOVE_MARKS, WorldReader.MOVE_GRID:
			var tg := reader.telegraph(i)
			for item: Dictionary in tg.get("items", []):
				out = out or (item["locked"] and int(item["progress"]) >= 1000)
		WorldReader.MOVE_LEAP:
			var leap := reader.boss_leap(i)
			out = bool(leap[0]) and float(leap[1]) >= 1.0
		WorldReader.MOVE_BURROW:
			out = bool(was.get("hidden", false)) and not hidden and state == EnemyAi.State.ACTIVE
		_:
			out = (
				int(was.get("state", -1)) == EnemyAi.State.WINDUP and state == EnemyAi.State.ACTIVE
			)
	was["state"] = state
	was["hidden"] = hidden
	return out


func test_every_boss_ground_attack_in_the_content_has_a_look() -> void:
	var attacks := _ground_attacks()
	assert_gt(attacks.size(), 20, "the content's ground attacks")
	var geometry := {
		WorldReader.MOVE_MARKS: BossStrikeLooks.DISC_STRIKES,
		WorldReader.MOVE_GRID: BossStrikeLooks.DISC_STRIKES,
		WorldReader.MOVE_LEAP: BossStrikeLooks.DISC_STRIKES,
		WorldReader.MOVE_BURROW: BossStrikeLooks.DISC_STRIKES,
		WorldReader.MOVE_BROOD: BossStrikeLooks.DISC_STRIKES,
		WorldReader.MOVE_DEPLOY: BossStrikeLooks.DISC_STRIKES,
		WorldReader.MOVE_BARRAGE: BossStrikeLooks.DISC_STRIKES,
		WorldReader.MOVE_SLAM_RING: BossStrikeLooks.RING_STRIKES,
		WorldReader.MOVE_SWEEP: BossStrikeLooks.ARC_STRIKES,
		WorldReader.MOVE_LANES: BossStrikeLooks.LANE_STRIKES,
		WorldReader.MOVE_FLOOD: BossStrikeLooks.LANE_STRIKES,
		WorldReader.MOVE_ROW_FLOOD: BossStrikeLooks.LANE_STRIKES,
		WorldReader.MOVE_CHARGE: BossStrikeLooks.CHARGE_STRIKES,
	}
	for a: Array in attacks:
		var look := BossStrikeLooks.look_for(a[2], a[3])
		assert_ne(look, &"", "%s %s has a look" % [a[0], a[1]])
		if look == &"":
			continue
		assert_true(geometry.has(a[3]), "%s %s: a known shape" % [a[0], a[1]])
		var strike := BossStrikeLooks.strike_of(look)
		assert_true(
			(geometry.get(a[3], []) as Array).has(strike),
			"%s %s strikes as %s, which fits its shape" % [a[0], a[1], strike]
		)
		assert_true(BossStrikeViews.LIFE.has(strike), "%s lasts a while" % strike)


func test_each_ground_attack_strikes_on_the_sims_strike_tick_with_its_look() -> void:
	for a: Array in _ground_attacks():
		var s := _fight(a[0], a[1])
		var w: World = s[0]
		var aid: int = s[1]
		var reader := WorldReader.new(w)
		var view := BossStrikeViews.new()
		add_child_autofree(view)
		var look := BossStrikeLooks.look_for(a[2], a[3])
		var i0 := w.actors.index_of(aid)
		assert_true(w.actors.state[i0] == EnemyAi.State.WINDUP, "%s %s winds up" % [a[0], a[1]])
		var was := {"state": w.actors.state[i0], "hidden": false}
		var first_sim := -1
		var first_view := -1
		var hits_off := 0
		var hurt := CombatLab.player_damage(w).size()
		for t in 600:
			w.step(InputFrame.new())
			w.actors.hp[0] = w.actors.max_hp[0]
			var sim := _sim_strikes(w, aid, a[3], was)
			var before := view.strike_count()
			view.sync(reader)
			var spawned := view.strike_count() > before
			if sim and first_sim < 0:
				first_sim = reader.tick()
			if spawned and first_view < 0:
				first_view = reader.tick()
				for st: Array in view.strikes():
					assert_eq(st[0], look, "%s %s strikes with its look" % [a[0], a[1]])
			var dmg := CombatLab.player_damage(w).size()
			if dmg > hurt and not spawned and view.strike_count() == 0:
				hits_off += 1  # a hit with no strike drawn
			hurt = dmg
			var i := w.actors.index_of(aid)
			if first_view >= 0 and (i < 0 or w.actors.state[i] == EnemyAi.State.RECOVER):
				break
		assert_gt(first_sim, 0, "%s %s strikes in the sim" % [a[0], a[1]])
		assert_eq(first_view, first_sim, "%s %s: drawn on the sim's strike tick" % [a[0], a[1]])
		assert_eq(hits_off, 0, "%s %s: no hit lands without its strike drawn" % [a[0], a[1]])


## The fill materials drawn now: the rebuilt meshes' surfaces and the visible fill nodes' overrides.
func _fill_materials(tv: TelegraphViews) -> Array:
	var out := []
	for mi: MeshInstance3D in tv.find_children("Fill", "MeshInstance3D", true, false):
		if mi.mesh is ImmediateMesh:
			var im := mi.mesh as ImmediateMesh
			for k in im.get_surface_count():
				out.append(im.surface_get_material(k))
		elif mi.visible:
			out.append(mi.material_override)
	return out


func test_markers_are_styled_dull_while_tracking_and_hot_once_locked() -> void:
	var styled := 0
	for a: Array in _ground_attacks():
		var s := _fight(a[0], a[1])
		var w: World = s[0]
		var reader := WorldReader.new(w)
		var tv := TelegraphViews.new()
		add_child_autofree(tv)
		var look := BossStrikeLooks.look_for(a[2], a[3])
		var tracked_seen := false
		var styled_seen := false
		for t in 400:  # the windup, and the active time (a burrow's circle shows while it is underground)
			w.step(InputFrame.new())
			w.actors.hp[0] = w.actors.max_hp[0]
			var i := w.actors.index_of(s[1])
			if i < 0 or w.actors.state[i] == EnemyAi.State.RECOVER:
				break
			var tg := reader.telegraph(i)
			if tg.is_empty() or not tg.get("ground", true):
				continue
			assert_eq(TelegraphViews.look_of(reader, i, tg), look)
			tv.sync(reader)
			var mats := _fill_materials(tv)
			var locked_any: bool = tg.get("locked", false)
			for item: Dictionary in tg.get("items", []):
				locked_any = locked_any or item["locked"]
			if tg.get("tracked", false) and not locked_any:
				tracked_seen = true
				assert_eq(mats.size(), 0, "%s %s: tracking, no fill" % [a[0], a[1]])
				continue
			for m in mats:
				assert_true(
					m is ShaderMaterial, "%s %s: a styled fill, not flat red" % [a[0], a[1]]
				)
				if m is ShaderMaterial:
					assert_eq((m as ShaderMaterial).shader, BossStrikeLooks.mark_shader())
					var pat := int((m as ShaderMaterial).get_shader_parameter("pattern"))
					assert_eq(pat, BossStrikeLooks.pattern_of(look))
					styled_seen = true
		assert_true(styled_seen, "%s %s: its marker is styled" % [a[0], a[1]])
		if tracked_seen:
			styled += 1
	assert_gt(styled, 5, "the tracked ones were seen tracking dull first")


func test_the_lock_flash_burns_hotter_than_the_windup_fill_and_holds_still_with_reduced_motion(
) -> void:
	var tv := TelegraphViews.new()
	add_child_autofree(tv)
	var pair := tv._look_pair(&"se_mortar")
	tv._process(0.0)
	var hot := float((pair[1] as ShaderMaterial).get_shader_parameter("heat"))
	assert_gt(hot, float((pair[0] as ShaderMaterial).get_shader_parameter("heat")))
	ViewPrefs.reduced_motion = true
	tv._process(0.03)
	assert_eq(
		float((pair[1] as ShaderMaterial).get_shader_parameter("heat")),
		TelegraphViews.CRACK_LOCK_HEAT.y,
		"steady"
	)
	assert_eq(float((pair[1] as ShaderMaterial).get_shader_parameter("motion")), 0.0, "no flow")


func test_strikes_draw_from_pools_with_fixed_caps() -> void:
	var view := BossStrikeViews.new()
	add_child_autofree(view)
	var lanes := []
	for k in 12:
		lanes.append(AttackShapes.lane(Vector2(-15, k * 1.2), 0, 30.0, 0.7))
	var discs := []
	for k in 40:
		discs.append([Vector2(k * 0.7, -k * 0.5), 2.0])
	for look: StringName in BossStrikeLooks.LOOKS:
		var kind := BossStrikeLooks.strike_of(look)
		for rep in 2:
			if BossStrikeLooks.LANE_STRIKES.has(kind):
				view._spawn(look, 7, {"lanes": lanes})
			elif BossStrikeLooks.RING_STRIKES.has(kind):
				view._spawn(look, 7, {"ring": [Vector2.ZERO, 1.0, 9.0]})
			elif BossStrikeLooks.ARC_STRIKES.has(kind):
				view._spawn(look, 7, {"arc": [Vector2.ZERO, 1.5, 6.0, -1.0, 1.0]})
			elif kind == &"skid":
				view._spawn(
					look, 7, {"lane": lanes[0], "from": Vector2(-15, 0), "to": Vector2(10, 0)}
				)
			else:
				view._spawn(look, 7, {"discs": discs.duplicate(true)})
	assert_lte(view.strike_count(), BossStrikeViews.MAX_STRIKES, "at most MAX_STRIKES alive")
	for age in [2.0, 6.0, 12.0]:
		view._draw(age)
		for pool: StringName in BossStrikeViews.CAPS:
			assert_lte(view.drawn(pool), view.pool_cap(pool), "%s within its cap" % pool)
			assert_eq(view.multimesh(pool).instance_count, view.pool_cap(pool), "fixed, not grown")
			assert_eq(view.multimesh(pool).visible_instance_count, view.drawn(pool))
	assert_gt(view.drawn_total(), 0)
	assert_lte(view.live_bursts(), BurstBudget.MAX_LIVE, "the live explosions within PF's budget")


func test_a_flood_of_spears_stands_while_its_lanes_do_then_retracts_into_the_pool() -> void:
	var s := _fight(&"warlord", &"spear_lines")
	var w: World = s[0]
	var aid: int = s[1]
	var reader := WorldReader.new(w)
	var view := BossStrikeViews.new()
	add_child_autofree(view)
	var standing := 0
	var ended := false
	for t in 600:
		w.step(InputFrame.new())
		w.actors.hp[0] = w.actors.max_hp[0]
		view.sync(reader)
		var i := w.actors.index_of(aid)
		if w.actors.state[i] == EnemyAi.State.ACTIVE and view.strike_count() > 0:
			standing = maxi(standing, view.drawn(&"blade"))
		if standing > 0 and w.actors.state[i] != EnemyAi.State.ACTIVE:
			ended = true
			break
	assert_gt(standing, 15, "rows of spears stand along the lanes")
	assert_true(ended)
	for t in int(BossStrikeViews.LIFE[&"spears"]) + 2:
		w.step(InputFrame.new())
		view.sync(reader)
	assert_eq(view.strike_count(), 0, "the strike ends")
	assert_eq(view.drawn(&"blade"), 0, "retracted into the pool")


func test_an_eggs_shadow_grows_on_its_circle_before_the_acid_splat() -> void:
	var s := _fight(&"brood_mother", &"egg_storm")
	var w: World = s[0]
	var reader := WorldReader.new(w)
	var view := BossStrikeViews.new()
	add_child_autofree(view)
	var fell := false
	var splat := false
	for t in 400:
		w.step(InputFrame.new())
		w.actors.hp[0] = w.actors.max_hp[0]
		view.sync(reader)
		if view.falling_count() > 0:
			fell = true
			assert_gt(view.drawn(&"ground"), 0, "the shadow on the floor")
		if view.strike_count() > 0:
			splat = true
			assert_true(fell, "the shadow came first")
			break
	assert_true(splat, "then the splat")


func test_low_density_thins_the_rocks_and_reduced_motion_stills_the_flow() -> void:
	var view := BossStrikeViews.new()
	add_child_autofree(view)
	view._spawn(&"bm_burrow", 3, {"discs": [[Vector2.ZERO, 2.0]]})
	view._draw(6.0)
	var rocks := view.drawn(&"rock")
	assert_gt(rocks, 0)
	ViewPrefs.effects_density = "low"
	view._draw(6.0)
	assert_lt(view.drawn(&"rock"), rocks, "fewer rocks")
	assert_gt(view.drawn(&"ground"), 0, "the crater stays")
	ViewPrefs.reduced_motion = true
	view._draw(6.0)
	var m := view.get_node("Strike_ground") as MultiMeshInstance3D
	assert_eq(float((m.material_override as ShaderMaterial).get_shader_parameter("motion")), 0.0)


func test_the_effects_go_through_the_layers_budgets() -> void:
	var view := BossStrikeViews.new()
	add_child_autofree(view)
	var layer: VfxLayer = add_child_autofree(VfxLayer.new())
	view.vfx = layer
	layer.drawers.append(view.draw_fx)
	for k in 30:
		view._tick = k
		view._spawn(&"se_mortar", 9, {"discs": [[Vector2(k % 6, k / 6), 1.1]]})
	for look: StringName in [&"gk_slam", &"hl_flare", &"fd_molten", &"se_rail", &"wl_spears"]:
		var kind := BossStrikeLooks.strike_of(look)
		var lane := AttackShapes.lane(Vector2(-8, 3), 0, 16.0, 0.6)
		if BossStrikeLooks.LANE_STRIKES.has(kind):
			view._spawn(look, 9, {"lanes": [lane]})
		elif BossStrikeLooks.RING_STRIKES.has(kind):
			view._spawn(look, 9, {"ring": [Vector2.ZERO, 1.5, 4.0]})
		else:
			view._spawn(look, 9, {"discs": [[Vector2(2, 2), 1.8]]})
	view._tick = 32
	layer.begin(33.0)
	layer.finish()
	assert_gt(layer.bursts_asked, 0, "the shells explode through VfxLayer.burst")
	assert_lte(layer.bursts_drawn, VfxLayer.BURST_MAX, "within the frame's burst budget")
	assert_lte(view.live_bursts(), BurstBudget.MAX_LIVE)
	assert_gt(layer.lights_asked(), 0, "flashes ask for light")
	assert_lte(layer.lights_on(), VfxCore.LIGHTS, "the 10-light pool")
	assert_lte(layer.marks(), VfxCore.DECALS, "the decal cap")
	assert_gt(layer.used(&"smoke") + layer.used(&"spark") + layer.used(&"debris"), 0, "sprites")
	var high := layer.sprites_asked
	layer.density = 0.3
	layer.begin(33.0)
	layer.finish()
	assert_lt(layer.sprites_asked, high, "thinned with the density")


func test_the_looks_stay_off_the_heros_colours() -> void:
	var hero := ThemePalette.color(&"player_core")
	for p: int in BossStrikeLooks.PATTERN_COLORS:
		var glow: Color = BossStrikeLooks.PATTERN_COLORS[p][1]
		var d := absf(glow.h - hero.h) * 360.0
		d = minf(d, 360.0 - d)
		assert_gt(d, 60.0, "pattern %d's glow is far from the hero's hue" % p)


func test_the_shock_lanes_stay_the_spikes() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2.ZERO)
	w.actors.set_pos(0, Vector2(6, 3))
	w.actors.hp[0] = 1 << 20
	BossLab.start(w, i, &"shock_lanes")
	var reader := WorldReader.new(w)
	var view := BossStrikeViews.new()
	add_child_autofree(view)
	for t in 200:
		w.step(InputFrame.new())
		w.actors.hp[0] = 1 << 20
		view.sync(reader)
		assert_eq(view.strike_count(), 0, "StoneSpikeViews draws those")
