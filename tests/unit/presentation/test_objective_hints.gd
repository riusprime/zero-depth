extends GutTest
## v0.11.0 O2 (owner L4, Q12 a): the boss hint's view. A marker off screen shows an arrow at the screen's edge
## pointing at it; on screen, a ping on it; each reason has its line in English and Spanish; it hides once the reason
## was met in 2 earlier runs and when Options "Boss hints" is off; it never takes the mouse. Options carries the
## toggle. The projection is a test stand-in (sim metres x 100 px from the screen's centre), so no camera is needed.

const PILLAR := ObjectiveMarkers.GATEKEEPER_PILLAR
const LANTERN := ObjectiveMarkers.SHADE_LANTERN

var _locale := ""


func before_all() -> void:
	_locale = TranslationServer.get_locale()


func after_all() -> void:
	TranslationServer.set_locale(_locale)


func _view(gate: Callable) -> ObjectiveHints:
	var v := ObjectiveHints.new()
	add_child_autofree(v)
	var centre := v.get_viewport().get_visible_rect().size * 0.5
	v.project = func(sim: Vector2) -> Vector2: return centre + sim * 100.0
	v.gate = gate
	return v


func test_off_screen_an_arrow_at_the_edge_on_screen_a_ping() -> void:
	var w := SaveLab.floor_world(77, 1)
	var r := WorldReader.new(w)
	var v := _view(func(_reason: StringName) -> bool: return true)
	v.sync(r)
	assert_false(v.visible, "nothing pointed at: nothing shows")
	w.objectives.point(PILLAR, Vector2(1, 0.5))
	v.sync(r)
	assert_true(v.visible)
	assert_true(v.showing(PILLAR, ObjectiveHints.PING), "on screen: a ping")
	assert_eq(v.shown()[0]["at"], v.shown()[0]["target"], "on the target")
	w.objectives.clear(PILLAR)
	w.objectives.point(PILLAR, Vector2(400, 0))  # far to the right
	v.sync(r)
	assert_true(v.showing(PILLAR, ObjectiveHints.ARROW), "off screen: an arrow")
	var screen := v.get_viewport().get_visible_rect()
	var m: Dictionary = v.shown()[0]
	assert_true(screen.has_point(m["at"]), "the arrow is on screen")
	assert_gt((m["at"] as Vector2).x, screen.size.x * 0.8, "at the right edge")
	assert_almost_eq((m["dir"] as Vector2).x, 1.0, 0.01, "pointing right, at the target")
	assert_eq(v.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it blocks nothing")


func test_every_reason_has_its_line_in_both_languages() -> void:
	var v := _view(func(_reason: StringName) -> bool: return true)
	for lang in ["en", "es"]:
		TranslationServer.set_locale(lang)
		for reason: StringName in ObjectiveHints.LABELS:
			var key: String = ObjectiveHints.LABELS[reason]
			assert_ne(v.line(reason), key, "%s: %s has a line" % [lang, key])
	TranslationServer.set_locale("en")
	assert_eq(v.line(PILLAR), "", "the pillar has an arrow and no line")
	assert_eq(v.line(&"no_such_reason"), "")


func test_it_hides_after_two_meetings_and_with_boss_hints_off() -> void:
	var profile := ProfileStore.new("")
	var hints := MechanicHints.new(CodexStore.new(profile))
	var w := SaveLab.floor_world(77, 1)
	var r := WorldReader.new(w)
	w.objectives.point(LANTERN, Vector2(1, 1))
	for run_seed in [11, 22]:
		var v := _view(hints.shows.bind(run_seed))
		hints.observe(r, run_seed)
		v.sync(r)
		assert_true(v.showing(LANTERN), "meeting run %d shows" % run_seed)
	var third := _view(hints.shows.bind(33))
	hints.observe(r, 33)
	third.sync(r)
	assert_false(third.showing(LANTERN), "the third run doesn't")
	assert_false(third.visible)
	var fresh := MechanicHints.new(CodexStore.new(ProfileStore.new("")))
	GameSettings.set_value(fresh.codex.profile, MechanicHints.SETTING, "off")
	var off := _view(fresh.shows.bind(11))
	off.sync(r)
	assert_false(off.visible, "Boss hints: Off shows none")


func test_options_carry_boss_hints() -> void:
	var o := OptionsMenu.new(ProfileStore.new(""))
	add_child_autofree(o)
	var acc := o.sections[&"accessibility"] as Control
	var c := acc.find_child(MechanicHints.SETTING, true, false) as OptionCycler
	assert_not_null(c, "Accessibility carries Boss hints")
	if c != null:
		assert_eq(c.value(), "on", "on by default")
