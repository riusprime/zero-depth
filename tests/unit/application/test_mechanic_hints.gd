extends GutTest
## v0.11.0 O2 (owner L4, Q12 a): a reason's boss hint shows in the first 2 runs that meet it, counted once per run
## (also across Continue: the run seed) in the Codex's profile section, and none show with "Boss hints" off. An old
## profile without the page starts at 0.

const PILLAR := ObjectiveMarkers.GATEKEEPER_PILLAR
const LANTERN := ObjectiveMarkers.SHADE_LANTERN


func test_the_first_two_runs_show_then_never() -> void:
	var profile := ProfileStore.new("")
	var h := MechanicHints.new(CodexStore.new(profile))
	assert_eq(h.runs(LANTERN), 0, "an old profile without the page starts at 0")
	assert_true(h.shows(LANTERN, 11), "run 1, before meeting it")
	h.meet(LANTERN, 11)
	h.meet(LANTERN, 11)
	assert_eq(h.runs(LANTERN), 1, "a run counts once")
	assert_true(h.shows(LANTERN, 11), "run 1 still shows")
	assert_true(h.shows(LANTERN, 22), "run 2 would show")
	h.meet(LANTERN, 22)
	assert_eq(h.runs(LANTERN), 2)
	assert_true(h.shows(LANTERN, 22), "run 2 shows to its end")
	assert_false(h.shows(LANTERN, 33), "run 3 doesn't")
	h.meet(LANTERN, 33)
	assert_eq(h.runs(LANTERN), 3, "the Codex keeps counting")
	assert_false(h.shows(LANTERN, 33))
	assert_true(h.shows(PILLAR, 33), "the pillars' arrow shows at every meeting (F5)")
	assert_true(
		profile.section(CodexStore.SECTION).has(String(MechanicHints.PAGE)),
		"kept in the Codex's section"
	)


func test_a_continued_run_counts_once_after_a_reload() -> void:
	var profile := ProfileStore.new("")
	MechanicHints.new(CodexStore.new(profile)).meet(PILLAR, 11)
	var again := ProfileStore.new("")
	again.data = JSON.parse_string(JSON.stringify(profile.data))  # the file, written and read back
	var h := MechanicHints.new(CodexStore.new(again))
	h.meet(PILLAR, 11)
	assert_eq(h.runs(PILLAR), 1, "Continue of the same run doesn't count it again")


func test_boss_hints_off_shows_none() -> void:
	var profile := ProfileStore.new("")
	var h := MechanicHints.new(CodexStore.new(profile))
	assert_true(h.enabled(), "on by default")
	GameSettings.set_value(profile, MechanicHints.SETTING, "off")
	assert_false(h.enabled())
	assert_false(h.shows(PILLAR, 11), "off hides every hint")


func test_observe_counts_what_the_world_points_at() -> void:
	var w := SaveLab.floor_world(77, 1)
	var h := MechanicHints.new(CodexStore.new(ProfileStore.new("")))
	var r := WorldReader.new(w)
	h.observe(r, 5)
	assert_eq(h.runs(PILLAR), 0, "nothing pointed at: nothing met")
	w.objectives.point(PILLAR, Vector2(1, 1))
	h.observe(r, 5)
	h.observe(r, 5)
	assert_eq(h.runs(PILLAR), 1, "met once in this run")
