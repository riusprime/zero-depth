extends GutTest
## v0.10.5 O10 (owner P3; Matchups): the Codex's enemy entry lists "Weak to / Resists" (en and es), and the damage
## numbers read the hit's WEAK_TO / RESISTED flag (a bigger red-pink number, a smaller dim grey one).

const WEAK := SimEvent.TAG_WEAK_TO
const RESISTED := SimEvent.TAG_RESISTED

var _repo := ContentRepository.load_all()


func test_the_codex_lists_weak_to_and_resists() -> void:
	TranslationServer.set_locale("en")
	var c := CodexCatalog.build(_repo)
	var e := c.entry(&"enemies", &"mender")
	assert_eq([e["weak_to"], e["resists"]], [&"storm", &"ember"])
	var ci := Node.new()
	assert_eq(CodexView.matchup_text(ci, e), "Weak to: Lightning\nResists: Fire")
	TranslationServer.set_locale("es")
	assert_eq(CodexView.matchup_text(ci, e), "Débil contra: Rayo\nResiste: Fuego")
	TranslationServer.set_locale("en")
	assert_eq(CodexView.matchup_text(ci, {"weak_to": &""}), "", "no matchup: no line")
	ci.free()


func test_every_matchup_id_has_its_name_key() -> void:
	for def: EnemyDefinition in _repo.all_of(&"enemies"):
		for id: StringName in [def.weak_to, def.resists]:
			var key := CodexView.matchup_key(id)
			assert_ne(tr(key), key, "%s has %s" % [def.id, key])


func test_damage_numbers_read_the_flag() -> void:
	assert_eq(
		DamageNumbers.matchup_look(WEAK, false),
		[DamageNumbers.WEAK_TO_COLOR, DamageNumbers.WEAK_TO_SIZE]
	)
	assert_eq(
		DamageNumbers.matchup_look(RESISTED, false),
		[DamageNumbers.RESISTED_COLOR, DamageNumbers.RESISTED_SIZE]
	)
	assert_eq(DamageNumbers.matchup_look(0, false)[1], 0, "plain")
	assert_eq(DamageNumbers.matchup_look(WEAK, true)[1], 0, "a crit keeps its own look")
	assert_gt(DamageNumbers.WEAK_TO_SIZE, DamageNumbers.SIZE, "a weak hit is bigger")
	assert_lt(DamageNumbers.RESISTED_SIZE, DamageNumbers.SIZE, "a resisted hit is smaller")
	var dn := DamageNumbers.new()
	add_child_autofree(dn)
	var l := dn.matchup_look(WEAK, false)
	dn.show_number(Vector2.ZERO, 12, false, l[0], l[1])
	assert_eq(dn.shown(), [["12", false, DamageNumbers.WEAK_TO_SIZE]])
