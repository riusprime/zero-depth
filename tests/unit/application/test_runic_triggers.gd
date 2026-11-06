extends GutTest
## v0.9.5 RS2 (RUNIC_STONE.md R4-R10, S6): the Runic Stone's other seven lines. Each trigger learns its line once, also
## on load when the stored stats already meet it (r4 floor boss no-hit, r5 60 s still, r6 8 collectibles, r7 the Hollow
## Crown, r8 three loops in a run, r9 a cracked wall on 5 runs, r10 the language switched in the hub); the full stone
## unlocks the Runic robe (not on sale; locked until then; kept by the profile file).

const LONG := 1 << 24
const SAVED := "user://rs2_profile.json"

var _repo: ContentRepository
var _lines: RunicLinesDefinition
var _locale := ""


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_lines = _repo.get_def(&"runic_lines", &"main")


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func after_all() -> void:
	DirAccess.remove_absolute(SAVED)


func _stone(p: ProfileStore = null) -> RunicStone:
	return RunicStone.new(p if p != null else ProfileStore.new(""), _lines)


func _sync(s: RunicStone, ach: AchievementStore, codex: CodexStore) -> Array[StringName]:
	return s.sync_from(ach, codex)


func test_the_ten_lines_are_the_specs() -> void:
	var want := {
		&"r4": "UNTOUCHED BY THE DEEP",
		&"r5": "THE STILL ONE SEES",
		&"r6": "THE PIECES CALL TO ONE ANOTHER",
		&"r7": "THE CROWN WAS ALWAYS HOLLOW",
		&"r8": "THE WHEEL TURNS FOR THE PATIENT",
		&"r9": "THE WALLS HIDE WHAT THEY FEAR",
		&"r10": "EVERY TONGUE ONE RUNE",
	}
	assert_eq(_lines.validate().size(), 0)
	for id: StringName in want:
		assert_eq(_lines.line(id).english, want[id], String(id))


func test_the_stored_stats_grant_their_lines_on_load_once() -> void:
	var p := ProfileStore.new("")
	var ach := AchievementStore.new(p)
	var codex := CodexStore.new(p)
	var s := _stone(p)
	assert_eq(_sync(s, ach, codex), [], "nothing met yet")
	ach.add_stat(RunicStone.NO_HIT_STAT)
	ach.add_stat(RunicStone.WON_STAT)
	ach.add_stat(RunicStone.CRACK_STAT, 4)
	codex.raise_to(&"runs", &"loop", &"best", 3)
	var found := p.section("collectibles")
	for i in 7:
		found["c%d" % i] = 1
	assert_eq(
		_sync(s, ach, codex), [&"r4", &"r7"], "the no-hit and the Crown; the others are one short"
	)
	ach.add_stat(RunicStone.CRACK_STAT)
	codex.raise_to(&"runs", &"loop", &"best", 4)
	found["c7"] = 1
	assert_eq(
		_sync(s, ach, codex),
		[&"r6", &"r8", &"r9"],
		"8 collectibles, 4th loop reached, 5 cracked runs"
	)
	assert_eq(_sync(s, ach, codex), [], "each only once")
	# A fresh stone on the same profile (the next launch) learns nothing new.
	assert_eq(_sync(_stone(p), ach, codex), [])


func test_boundaries() -> void:
	var s := _stone()
	assert_eq(s.sync(0, 0, {"collectibles": 7, "loop_best": 3, "crack_runs": 4}), [])
	assert_eq(s.sync(0, 0, {"collectibles": 8}), [&"r6"])
	assert_eq(s.sync(0, 0, {"loop_best": 4}), [&"r8"])
	assert_eq(s.sync(0, 0, {"crack_runs": 5}), [&"r9"])


# --- The run's side: AchievementTracker ----------------------------------------------------------------------------


func _tracker(p: ProfileStore) -> AchievementTracker:
	var codex := CodexStore.new(p)
	var store := AchievementStore.new(p)
	var book := AchievementBook.build(_repo, store, codex, CodexCatalog.build(_repo))
	return AchievementTracker.new(book)


func _step(t: AchievementTracker, w: World, r: WorldReader, n: int = 1) -> void:
	for k in n:
		w.step(InputFrame.new())
		t.observe(r)


func _boss_fight(hurt: bool) -> int:
	var p := ProfileStore.new("")
	var t := _tracker(p)
	var w := FightLab.floor_world(51, 1)
	w.floor_count = 3
	w.actors.invuln[0] = LONG
	var r := WorldReader.new(w)
	t.attach(r)
	w.actors.set_pos(0, w.floor_layout.boss_door_inside(1.5))
	_step(t, w, r, 4)
	assert_true(r.boss_door_sealed(), "the door shut: the fight began")
	if hurt:
		w.actors.invuln[0] = 0
		Damage.hit(w, 0, 3, 0, 0, 1, 0, w.actors.pos(0), w.actors.pos(0))
		_step(t, w, r, 2)
		w.actors.invuln[0] = LONG
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 999999, 0, 0, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	_step(t, w, r, 6)
	return AchievementStore.new(p).stat(RunicStone.NO_HIT_STAT)


func test_r4_a_boss_beaten_from_the_door_without_a_hit() -> void:
	assert_eq(_boss_fight(false), 1, "clean: counted")
	assert_eq(_boss_fight(true), 0, "hurt after the door shut: not counted")


func test_r9_counts_runs_not_walls() -> void:
	var p := ProfileStore.new("")
	var t := _tracker(p)
	var ach := AchievementStore.new(p)
	var w1 := CrackLab.world()
	if w1 == null:
		pending("no run seed in range has a cracked wall floor")
		return
	var r1 := WorldReader.new(w1)
	t.attach(r1)
	_step(t, w1, r1)
	w1.breakables.crack_broken = 1
	_step(t, w1, r1)
	assert_eq(ach.stat(RunicStone.CRACK_STAT), 1, "the first run's wall")
	# Floor 2 of the same run: another wall breaks, the run already counted.
	var w2 := CrackLab.world(&"blade", true, 7)
	w2.run_floor = 2
	var r2 := WorldReader.new(w2)
	t.attach(r2)
	_step(t, w2, r2)
	w2.breakables.crack_broken = 1
	_step(t, w2, r2)
	assert_eq(ach.stat(RunicStone.CRACK_STAT), 1, "at most one per run")
	# A new run (floor 1 again).
	var w3 := CrackLab.world(&"blade", true, 13)
	var r3 := WorldReader.new(w3)
	t.attach(r3)
	_step(t, w3, r3)
	w3.breakables.crack_broken = 1
	_step(t, w3, r3)
	assert_eq(ach.stat(RunicStone.CRACK_STAT), 2, "the next run counts again")


# --- The hub's side: HubRunic (R5, R10) ----------------------------------------------------------------------------


func _hub_runic(awake: bool) -> HubRunic:
	var h := HubRunic.new()
	var s := HubSession.new()
	s.profile = ProfileStore.new("")
	s.view = HubView.new()
	autofree(s)
	autofree(s.view)
	autofree(h)
	h.session = s
	h.stone = _stone(s.profile)
	if awake:
		h.stone.learn(&"r1")
	return h


func test_r5_sixty_seconds_without_any_input() -> void:
	var h := _hub_runic(true)
	for i in RunicStone.IDLE_TICKS - 1:
		h._idle()
	assert_false(h.stone.knows(&"r5"), "one tick short")
	h._input(InputEventMouseMotion.new())
	assert_eq(h.idle_ticks, 0, "any input starts it over")
	for i in RunicStone.IDLE_TICKS - 1:
		h._idle()
	h.session.held = true  # a menu over the hub
	h._idle()
	assert_eq(h.idle_ticks, 0, "a menu or the pause starts it over")
	h.session.held = false
	for i in RunicStone.IDLE_TICKS:
		h._idle()
	assert_true(h.stone.knows(&"r5"), "60 s of stillness")
	assert_false(h.stone.pending_pulse, "it pulsed at once")
	var n := h.stone.learned().size()
	for i in 10:
		h._idle()
	assert_eq(h.stone.learned().size(), n, "once")


func test_r10_the_language_switched_with_the_stone_awake() -> void:
	TranslationServer.set_locale("en")
	var asleep := _hub_runic(false)
	asleep._locale = "en"
	TranslationServer.set_locale("es")
	asleep._notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	assert_false(asleep.stone.knows(&"r10"), "a sleeping stone doesn't hear")
	TranslationServer.set_locale("en")
	var h := _hub_runic(true)
	h._locale = "en"
	h._notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	assert_false(h.stone.knows(&"r10"), "no change, no line")
	TranslationServer.set_locale("es")
	h.bubble.show_line(RuneCipher.encode("A"))
	h._notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	assert_true(h.stone.knows(&"r10"))
	var want := RuneCipher.encode("EVERY TONGUE ONE RUNE").filter(
		func(g: int) -> bool: return g != RuneCipher.GAP
	)
	assert_eq(h.bubble.glyph_count(), want.size(), "the open bubble shows it at once")


# --- S6 -------------------------------------------------------------------------------------------------------------


func test_the_runic_robe_is_locked_not_on_sale_and_hinted() -> void:
	var def: RobeDefinition = _repo.get_def(&"robe", &"runic")
	assert_not_null(def)
	assert_eq(def.validate().size(), 0)
	var p := ProfileStore.new("")
	assert_false(Wardrobe.robe_unlocked(p, def), "locked at first")
	assert_false(MetaProgress.wares(_repo).has(def), "the Progression Station doesn't sell it")
	assert_true(Wardrobe.robes(_repo).has(def), "but the Wardrobe lists it")
	TranslationServer.set_locale("en")
	assert_eq(tr(def.name_key), "Runic")
	assert_eq(tr(def.unlock_hint_key), "Learn every line of the Runic Stone")
	TranslationServer.set_locale("es")
	assert_eq(tr(def.name_key), "Rúnica")
	assert_eq(tr(def.unlock_hint_key), "Aprende todas las líneas de la Piedra rúnica")


func test_the_full_stone_unlocks_the_robe_and_the_profile_keeps_it() -> void:
	var p := ProfileStore.new(SAVED)
	var s := _stone(p)
	var def: RobeDefinition = _repo.get_def(&"robe", &"runic")
	for l: RunicLineEntry in _lines.lines:
		assert_false(s.is_full())
		assert_false(Wardrobe.robe_unlocked(p, def), "not before the last line")
		s.learn(l.id)
	assert_true(s.is_full())
	assert_true(Wardrobe.robe_unlocked(p, def), "the tenth line unlocks it")
	assert_true(p.save_file())
	var loaded := ProfileStore.open(SAVED)
	assert_true(Wardrobe.robe_unlocked(loaded, def), "kept across save and load")
	assert_true(_stone(loaded).is_full())
	Wardrobe.set_robe(loaded, &"runic")
	assert_eq(Wardrobe.worn_robe(_repo, loaded).id, &"runic", "and it can be worn")


func test_a_profile_already_full_gets_the_robe_on_load() -> void:
	var p := ProfileStore.new("")
	var sec := p.section("runes")
	var ids := []
	for l: RunicLineEntry in _lines.lines:
		ids.append(String(l.id))
	sec["learned"] = ids
	var def: RobeDefinition = _repo.get_def(&"robe", &"runic")
	assert_false(Wardrobe.robe_unlocked(p, def))
	_stone(p).sync_from(AchievementStore.new(p), CodexStore.new(p))
	assert_true(Wardrobe.robe_unlocked(p, def))


func test_an_old_profile_loads_and_syncing_it_creates_nothing() -> void:
	var p := ProfileStore.new("")
	var ach := AchievementStore.new(p)
	var codex := CodexStore.new(p)
	var before := p.data.duplicate(true)
	var s := _stone(p)
	assert_eq(_sync(s, ach, codex), [])
	assert_false(p.data.has("runes"))
	assert_eq(p.data.keys().size(), before.keys().size(), "no section was added by reading")
