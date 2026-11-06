extends GutTest
## v0.9.5 HU: the four ability squares (bottom right, design A): the order and what a build hides, the falling
## cover, the seconds text, the one-shot ready flash, the binding glyph of the last device used, Blink's charges.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()
	InputDefaults.apply()


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _world(build: StringName, blink := false) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	var w := World.new(3, t)
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	if blink:
		Abilities.grant(w, Abilities.index_of_kind(w, AbilityTable.Kind.BLINK))
	return w


func _squares() -> AbilitySquares:
	var s := AbilitySquares.new()
	add_child_autofree(s)
	s.set_anchors_preset(Control.PRESET_TOP_LEFT)
	s.size = Vector2(1920, 1080)
	return s


func test_the_order_is_attack_skill_dash_blink_and_a_missing_one_closes_up() -> void:
	var s := _squares()
	s.sync(WorldReader.new(_world(&"gun")))
	assert_eq(
		s.shown(),
		[&"attack", &"skill", &"dash"] as Array[StringName],
		"no Blink card: no Blink square"
	)
	var rects: Array[Rect2] = []
	for id in s.shown():
		rects.append(s.rect_of(id))
	assert_almost_eq(
		rects[2].end.x, 1920.0 - AbilitySquares.MARGIN_RIGHT, 0.01, "closed up at the right edge"
	)
	assert_almost_eq(
		rects[0].end.y, 1080.0 - AbilitySquares.MARGIN_BOTTOM, 0.01, "20 px above the bottom"
	)
	assert_almost_eq(rects[1].position.x - rects[0].end.x, AbilitySquares.GAP, 0.01, "6 px apart")
	assert_eq(rects[0].size, Vector2(76, 76))
	s.sync(WorldReader.new(_world(&"gun", true)))
	assert_eq(s.shown(), [&"attack", &"skill", &"dash", &"blink"] as Array[StringName])
	var b := _squares()
	b.sync(WorldReader.new(_world(&"blade")))
	assert_eq(b.slot_of(&"attack")["icon"], &"combo_sword", "the Blade's attack")
	assert_eq(b.slot_of(&"skill")["icon"], &"lunge_cleave", "the Blade's skill is the Lunge Cleave")
	assert_eq(s.slot_of(&"skill")["icon"], &"skill", "the Gun's is the Scatter Blast")
	var none := _squares()
	none.sync(WorldReader.new(World.new(3, PlayerTable.starting_values())))
	assert_false(none.shown().has(&"skill"), "a build without a skill hides it")


func test_the_cover_height_follows_the_remaining_share() -> void:
	var w := _world(&"gun")
	var s := _squares()
	var r := WorldReader.new(w)
	s.sync(r)
	assert_eq(s.cover_height(&"dash"), 0.0, "ready: no cover")
	var total := r.dash_cooldown_total()
	w.dash_cooldown_left = total
	s.sync(r)
	assert_almost_eq(
		s.cover_height(&"dash"), AbilitySquares.SIDE - 4.0, 0.01, "just used: full cover"
	)
	w.dash_cooldown_left = total / 2
	s.sync(r)
	assert_almost_eq(
		s.cover_height(&"dash"), (AbilitySquares.SIDE - 4.0) * 0.5, 0.6, "half left: half the cover"
	)
	w.dash_cooldown_left = total / 4
	s.sync(r)
	assert_lt(
		s.cover_height(&"dash"),
		(AbilitySquares.SIDE - 4.0) * 0.3,
		"it shrinks as the time runs out"
	)


func test_the_seconds_have_a_decimal_under_ten_and_are_whole_above() -> void:
	assert_eq(AbilitySquares.seconds_text(3.2), "3.2")
	assert_eq(AbilitySquares.seconds_text(0.4), "0.4")
	assert_eq(AbilitySquares.seconds_text(9.94), "9.9")
	assert_eq(AbilitySquares.seconds_text(10.0), "10")
	assert_eq(AbilitySquares.seconds_text(10.2), "11", "whole seconds round up")


func test_a_square_flashes_once_the_tick_it_becomes_ready() -> void:
	var w := _world(&"gun")
	var s := _squares()
	var r := WorldReader.new(w)
	s.sync(r)
	assert_false(s.flashing(&"dash"), "ready from the start: no flash")
	w.dash_cooldown_left = 120
	s.sync(r)
	assert_false(s.flashing(&"dash"), "cooling: no flash")
	w.dash_cooldown_left = 0
	s.sync(r)
	assert_true(s.flashing(&"dash"), "it just came back")
	s._process(AbilitySquares.FLASH_SECONDS + 0.01)
	assert_false(s.flashing(&"dash"), "0.15 s later it is over")
	s.sync(r)
	assert_false(s.flashing(&"dash"), "and it does not flash again")


func test_reduced_motion_has_no_flash() -> void:
	ViewPrefs.reduced_motion = true
	var w := _world(&"gun")
	var s := _squares()
	var r := WorldReader.new(w)
	w.dash_cooldown_left = 120
	s.sync(r)
	w.dash_cooldown_left = 0
	s.sync(r)
	assert_false(s.flashing(&"dash"))


func test_the_glyph_follows_the_last_device_used() -> void:
	var s := _squares()
	var r := WorldReader.new(_world(&"gun", true))
	s.pad_active = false
	s.sync(r)
	assert_eq(s.slot_of(&"skill")["glyph"], "Q")
	assert_eq(s.slot_of(&"blink")["glyph"], "Shift")
	s._input(_pad_button())
	assert_true(s.pad_active)
	s.sync(r)
	assert_eq(s.slot_of(&"attack")["glyph"], "RT", "the Gun shoots on the right trigger")
	assert_eq(s.slot_of(&"skill")["glyph"], "LT", "the Skill is on the left trigger now")
	assert_eq(s.slot_of(&"dash")["glyph"], "RB")
	assert_eq(s.slot_of(&"blink")["glyph"], "LB")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_W
	s._input(k)
	assert_false(s.pad_active, "a key press brings the keyboard names back")
	assert_true(AbilitySquares.is_playstation("PS5 Controller"))
	assert_true(AbilitySquares.is_playstation("Sony DualSense"))
	assert_false(AbilitySquares.is_playstation("Xbox 360 Controller"))
	assert_eq(AbilitySquares.PS_NAMES["LT"], "L2")


func _pad_button() -> InputEventJoypadButton:
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_A
	b.pressed = true
	return b


func test_charges_show_only_above_one() -> void:
	var w := _world(&"gun", true)
	var s := _squares()
	var r := WorldReader.new(w)
	w.ab.blink_charges = 1
	s.sync(r)
	assert_false(s.charges_shown(&"blink"))
	w.ab.blink_charges = 2
	s.sync(r)
	assert_true(s.charges_shown(&"blink"))
	assert_false(s.charges_shown(&"dash"), "only Blink has charges")
