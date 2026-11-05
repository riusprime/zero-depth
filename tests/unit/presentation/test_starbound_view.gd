extends GutTest
## v0.10.5 W3-P10b (owner W7, "don't get crazy with visuals for explosions"): what the Starbound cards draw. V1:
## Detonation's burst is the hook blast tinted moon-blue (#8FB8E8), no particles, no flash; V2: at most 8 drawn a
## frame; V3: Arc Jump a thin moon-blue line, at most 16 a frame; Rising Edge, Echo Cast and Fervour only a count on
## the HUD's buff row. The pick: a Starbound card wears the owner's gold frame and back (no focused twin; the game's
## own focus look), its kind line and its stacks as the level badge.

var _repo: ContentRepository
var _density := "high"


func before_all() -> void:
	_repo = ContentRepository.load_all()


func before_each() -> void:
	_density = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"


func after_each() -> void:
	ViewPrefs.effects_density = _density


func _world() -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	t.crit_chance_permille = 0
	var w := World.new(7, t)
	w.dummy_speed = 0.0
	w.dummy_fire_period = 100000
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.reward_table = ContentCompiler.compile_rewards(_repo.get_def(&"rewards", &"floor"))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	w.starbound_tables = ContentCompiler.compile_starbound(_repo)
	w.loop = 2
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	return w


func _take(w: World, k: int, n: int = 1) -> void:
	for i in n:
		Offers.apply(w, Offers.starbound_code(k))


func _hit(w: World, id: int, amount: int) -> void:
	var pid := w.actors.ids[0]
	var i := w.actors.index_of(id)
	Damage.hit(
		w, i, amount, pid, pid, w.take_root(), SimEvent.TAG_MELEE, Vector2.ZERO, w.actors.pos(i)
	)


func test_the_burst_and_the_line_are_moon_blue_and_plain() -> void:
	for form in [AttackFormLooks.BURST, AttackFormLooks.BEAM]:
		var look := AttackFormView.sb_look(form)
		assert_eq(look["core"], AstralCardArt.STARBOUND_BLUE, "moon-blue")
		assert_eq(look["edge"], AstralCardArt.STARBOUND_BLUE)
		assert_eq((look["particles"] as Array).size(), 0, "no lingering particles")
		assert_false(bool(look["crit"]), "no flash")


func test_at_most_eight_bursts_and_sixteen_lines_drawn_a_frame() -> void:
	var w := _world()
	var view: AttackFormView = add_child_autofree(AttackFormView.new())
	var reader := WorldReader.new(w)
	var first := w.add_dummy(Vector2(2, 0), 0.3, 100)
	for k in 30:
		w.add_dummy(Vector2(2, 0), 0.3, 100)
	_take(w, Starbound.DETONATION, 5)
	_hit(w, first, 100)
	assert_eq(
		w.starbound_fx_kind.count(Starbound.FX_BURST), Starbound.BURSTS_PER_TICK, "the sim's 24"
	)
	view.sync(reader)
	assert_between(view.sb_bursts_drawn, 1, AttackFormView.SB_BURSTS_MAX, "V2: at most 8 drawn")
	var drawn := view.sb_bursts_drawn
	view.sync(reader)
	assert_eq(view.sb_bursts_drawn, drawn, "each burst once")
	var w2 := _world()
	var view2: AttackFormView = add_child_autofree(AttackFormView.new())
	var root := w2.add_dummy(Vector2(1, 0), 0.3, 1000000)
	for k in 24:
		w2.add_dummy(Vector2(1.5 + k * 1.5, 0), 0.3, 1000000)
	_take(w2, Starbound.ARC_JUMP, 30)
	_hit(w2, root, 100000)
	assert_eq(w2.starbound_fx_kind.count(Starbound.FX_JUMP), 24, "a chain of 24 jumps")
	view2.sync(WorldReader.new(w2))
	assert_eq(view2.sb_jumps_drawn, AttackFormView.SB_JUMPS_MAX, "V3: 16 lines drawn")


func test_the_buff_row_counts_rising_edge_echo_cast_and_fervour() -> void:
	var w := _world()
	var reader := WorldReader.new(w)
	var row: StarboundHud = add_child_autofree(StarboundHud.new())
	row.sync(reader)
	for k in StarboundHud.SHOWN:
		assert_eq(row.count_text(k), "", "nothing held: empty")
	_take(w, Starbound.ECHO_CAST, 3)
	_take(w, Starbound.FERVOUR)
	row.sync(reader)
	assert_eq(row.count_text(WorldReader.STARBOUND_ECHO_CAST), "3", "Echo Cast: its stacks")
	assert_eq(row.count_text(WorldReader.STARBOUND_FERVOUR), "", "no kill yet")
	_hit(w, w.add_dummy(Vector2(2, 0), 0.3, 10), 100)
	_hit(w, w.add_dummy(Vector2(2, 0), 0.3, 10), 100)
	row.sync(reader)
	assert_eq(row.count_text(WorldReader.STARBOUND_FERVOUR), "2", "Fervour: the kills counted")


func test_a_starbound_card_wears_the_gold_frame_and_its_stacks() -> void:
	var w := _world()
	_take(w, Starbound.RISING_EDGE, 2)
	var reader := WorldReader.new(w)
	var code := Offers.starbound_code(Starbound.RISING_EDGE)
	var face := PickPanel.card_face(self, reader, code)
	assert_eq(int(face["type"]), WorldReader.CARD_STARBOUND)
	assert_eq(face["id"], &"starbound_rising_edge")
	assert_eq(face["tier_text"], tr("STARBOUND_KIND"), "the kind line")
	assert_eq(
		face["level_text"], tr("UI_CARD_LEVEL_UP") % [2, 3], "two stacks, the third after the pick"
	)
	var s := PickSlot.new(0)
	add_child_autofree(s)
	s.show_card(face)
	assert_eq(s.card.frame_variant, AstralCardArt.STARBOUND)
	var gold := "res://assets/ui/card_frames/frame_starbound.png"
	assert_eq(s.card.frame_texture().resource_path, gold, "the owner's gold frame")
	assert_eq(
		s.card.fx.back.art_texture().resource_path,
		"res://assets/ui/card_backs/back_starbound.png",
		"and its back"
	)
	s.set_focused(true)
	assert_eq(
		s.card.frame_texture().resource_path, gold, "no focused twin: the game's own focus look"
	)
	assert_true(s.card.focused)
	assert_eq(AstralCardArt.variant_of(&"wildfire"), AstralCardArt.variant_of(&"wildfire"))
	assert_between(
		AstralCardArt.variant_of(&"wildfire"), 1, AstralCardArt.FRAMES, "the others keep theirs"
	)
