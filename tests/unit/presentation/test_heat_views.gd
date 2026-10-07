extends GutTest
## The Overclock heat views (v0.3.0 PLAN L18): the HUD meter (its marks, the overheat point, flashes, the VENT
## prompt, steam), the hero's visor and blade shifting toward orange and white, and the vent ring at the sim's
## radius. Every change is a material parameter, never a shader (the damage-flash rule).

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(enemies: Array = [Vector2(1.2, 0)]) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	Heat.enable(w, ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock")))
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, 5000)
	return w


func _meter() -> HeatMeter:
	var m := HeatMeter.new()
	add_child_autofree(m)
	m.set_process(false)
	return m


func _set_heat(w: World, heat: int) -> void:
	w.heat.milli = heat * HeatTable.MILLI
	w.heat.idle = 0
	Heat.advance(w)


func test_the_meter_hides_without_heat_and_marks_both_thresholds_and_the_overheat_point() -> void:
	var m := _meter()
	var plain := World.new(5, PlayerTable.starting_values())
	m.sync(WorldReader.new(plain))
	assert_false(m.visible, "no heat, no meter")
	var w := _world()
	m.sync(WorldReader.new(w))
	assert_true(m.visible)
	var marks := m.marks()
	assert_eq(marks.map(func(k: Array) -> int: return k[0]), [40, 75, 100])
	assert_eq(marks[2][1], tr("HUD_HEAT_OVERHEAT"), "the end is the overheat point, named")
	assert_eq(m.tier_text(), tr("HUD_HEAT"))
	assert_eq(m.fill(), 0.0)


func test_the_meter_fills_flashes_at_thresholds_and_prompts_the_vent() -> void:
	var m := _meter()
	var w := _world()
	var r := WorldReader.new(w)
	m.sync(r)
	_set_heat(w, 30)
	m.sync(r)
	assert_almost_eq(m.fill(), 0.3, 1e-6)
	assert_false(m.flashing())
	assert_eq(m.vent_text(), "", "no VENT prompt under Hot")
	_set_heat(w, 41)
	m.sync(r)
	assert_true(m.flashing(), "crossing Hot flashes")
	assert_eq(m.tier_text(), tr("HUD_HEAT_HOT"))
	assert_eq(m.vent_text(), tr("HUD_HEAT_VENT"), "a dash would vent now")
	w.dash_cooldown_left = 10
	m.sync(r)
	assert_eq(m.vent_text(), "", "not while the dash recharges")
	w.dash_cooldown_left = 0
	m._process(1.0)
	assert_false(m.flashing())
	_set_heat(w, 80)
	m.sync(r)
	assert_true(m.flashing(), "crossing Overclock flashes")
	assert_eq(m.tier_text(), tr("HUD_HEAT_OVERCLOCK"))


func test_overheating_vents_steam_from_the_meter() -> void:
	var m := _meter()
	var w := _world()
	var r := WorldReader.new(w)
	m.sync(r)
	Heat.add(w, 100 * HeatTable.MILLI)
	m.sync(r)
	assert_true(m.stalled())
	assert_eq(m.tier_text(), tr("HUD_HEAT_OVERHEAT"))
	assert_eq(m.vent_text(), "", "no vent while overheated")
	assert_gte(m.steam_count(), HeatMeter.STEAM_BURST, "a burst of steam")
	var burst := m.steam_count()
	m._process(0.25)
	assert_gt(m.steam_count(), 0, "steam keeps venting while stalled")
	assert_true(m.steam_count() >= burst, "new puffs keep coming")


func test_the_visor_and_blade_heat_up_without_changing_a_shader() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var kit := KitView.new()
	add_child_autofree(kit)
	var fx := HeatVisuals.new(kit, actors)
	add_child_autofree(fx)
	actors.sync(r)
	fx.sync(r)
	var node := actors.actor_node(w.actors.ids[0])
	var avatar: PlayerAvatar = node.get_meta(&"avatar")
	var before := DamageFlashKeys.of(node)
	var kit_before := DamageFlashKeys.of(kit)
	var cyan := ThemePalette.color(&"player_core")
	assert_eq(avatar.visor_color(), cyan, "cool: the visor keeps its cyan")
	assert_eq(kit.hue(), kit.color, "and the blade its colour")
	_set_heat(w, 60)
	fx.sync(r)
	var hot := avatar.visor_color()
	assert_gt(hot.r, cyan.r + 0.3, "Hot: the visor turns toward orange")
	assert_lt(hot.b, cyan.b, "and away from cyan")
	assert_gt(kit.hue().r, kit.color.r + 0.3, "so does the blade")
	_set_heat(w, 99)
	fx.sync(r)
	var white := avatar.visor_color()
	assert_gt(white.g + white.b, hot.g + hot.b, "near the overheat point it goes white-hot")
	assert_eq(DamageFlashKeys.of(node), before, "the visor changed no shader")
	assert_eq(DamageFlashKeys.of(kit), kit_before, "nor did the blade")


func test_a_vent_draws_its_ring_at_the_sim_radius_and_overheat_steams() -> void:
	var w := _world([Vector2(1.5, 0)])
	var r := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var kit := KitView.new()
	add_child_autofree(kit)
	var fx := HeatVisuals.new(kit, actors)
	add_child_autofree(fx)
	fx.set_process(false)
	actors.sync(r)
	fx.sync(r)
	assert_eq(fx.fx_count(), 0)
	_set_heat(w, 60)
	w.step(InputFrame.make(Vector2i(0, 127), 0, 300, 0, InputFrame.DASH))
	fx.sync(r)
	assert_eq(fx.fx_count_of(&"ring"), 1, "the blast ring")
	assert_eq(fx.fx_count_of(&"blast"), 1, "and its flash disc")
	assert_almost_eq(
		fx.ring_radius(), Heat.vent_radius_m(w), 1e-6, "grows to the blast's real radius"
	)
	assert_gt(fx.fx_count_of(&"ember"), 0, "embers fly")
	Heat.add(w, 100 * HeatTable.MILLI)
	w.step(InputFrame.new())
	fx.sync(r)
	assert_gt(fx.fx_count_of(&"steam"), 5, "overheat: a burst of steam")
	for k in HeatVisuals.FX_FRAMES + 1:
		fx._process(1.0 / 60.0)
	assert_eq(fx.fx_count_of(&"ring"), 0, "effects end")


func test_the_view_tiers_match_the_sim() -> void:
	assert_eq(
		[
			HeatLooks.TIER_COOL,
			HeatLooks.TIER_HOT,
			HeatLooks.TIER_OVERCLOCK,
			HeatLooks.TIER_OVERHEAT
		],
		[Heat.TIER_COOL, Heat.TIER_HOT, Heat.TIER_OVERCLOCK, Heat.TIER_OVERHEAT]
	)
