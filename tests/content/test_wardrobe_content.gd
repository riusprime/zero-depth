extends GutTest
## v0.9.0 RB (owner, PLAN "Owner decisions" RB; docs/roadmap/v0.9.0/AFFINITIES.md): the shipped affinities (A0-A5)
## and robes (R1-R6) are valid, as approved, and every card they weigh exists. No robe is near the enemy red or the
## hostile yellow; each affinity's colour is its element's (ART_DIRECTION §4).

const ENEMY_RED := Color("#E25A4C")
const HOSTILE_YELLOW := Color("#FBD07A")
const COLOURS := {
	&"ember": "#FFAA33",
	&"storm": "#7FB2FF",
	&"venom": "#5FE03C",
	&"astral": "#8B55FF",
	&"guardian": "#E8C870"
}

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_the_six_affinities_validate() -> void:
	var ids := []
	for a: AffinityDefinition in Wardrobe.affinities(_repo):
		ids.append(a.id)
		assert_eq(a.validate().size(), 0, "%s validates" % a.id)
	assert_eq(
		ids, [&"none", &"ember", &"storm", &"venom", &"astral", &"guardian"], "None first, A1-A5"
	)
	assert_true(
		(_repo.get_def(&"affinity", &"none") as AffinityDefinition).is_none(), "None does nothing"
	)


func test_the_numbers_are_the_approved_drafts() -> void:
	var e: AffinityDefinition = _repo.get_def(&"affinity", &"ember")
	assert_eq(
		[e.burn_duration_permille, e.favoured_permille, e.disfavoured_permille], [1500, 1300, 700]
	)
	var s: AffinityDefinition = _repo.get_def(&"affinity", &"storm")
	assert_eq(
		[s.dash_shock_radius_m, s.dash_shock_stacks, s.dash_cooldown_add_seconds], [1.0, 1, 0.3]
	)
	var v: AffinityDefinition = _repo.get_def(&"affinity", &"venom")
	assert_eq(v.poison_jump_m, 3.0)
	var a: AffinityDefinition = _repo.get_def(&"affinity", &"astral")
	assert_eq([a.secret_sense_m, a.map_secrets, a.favoured_permille], [8.0, true, 1300])
	assert_true(
		a.disfavoured_cards.is_empty(), "Astral's cost is no combat effect, not an offer cut"
	)
	var g: AffinityDefinition = _repo.get_def(&"affinity", &"guardian")
	assert_eq([g.ward_charges, g.shard_permille], [1, 800])
	assert_true(g.favoured_cards.is_empty() and g.disfavoured_cards.is_empty(), "no offer bias")


func test_every_weighed_card_exists() -> void:
	for a: AffinityDefinition in Wardrobe.affinities(_repo):
		for id: StringName in a.favoured_cards + a.disfavoured_cards:
			assert_not_null(_repo.get_def(&"items", id), "%s weighs card %s" % [a.id, id])


func test_affinity_colours_are_their_elements() -> void:
	for id: StringName in COLOURS:
		var a: AffinityDefinition = _repo.get_def(&"affinity", id)
		assert_lt(_dist(a.color, Color(COLOURS[id])), 0.01, "%s is %s" % [id, COLOURS[id]])
		assert_gt(a.glyph, 0, "%s draws a glyph" % id)
	assert_eq((_repo.get_def(&"affinity", &"none") as AffinityDefinition).glyph, 0, "None: no rune")


func test_the_six_robes() -> void:
	var ids := []
	var free := []
	for r: RobeDefinition in Wardrobe.robes(_repo):
		ids.append(r.id)
		if r.free:
			free.append(r.id)
		assert_eq(r.validate().size(), 0, "%s validates" % r.id)
		for c: Color in [r.cloak, r.underside]:
			assert_gt(_dist(c, ENEMY_RED), 0.2, "%s is not the enemy red" % r.id)
			assert_gt(_dist(c, HOSTILE_YELLOW), 0.2, "%s is not the hostile yellow" % r.id)
	assert_eq(
		ids,
		[&"cream", &"ash", &"night", &"canyon", &"frost", &"moss", &"fallen", &"divine"],
		"R1-R6 and MP2's two epic robes"
	)
	assert_eq(free, [&"cream", &"ash"], "Cream and Ash free; the rest for Rune Fragments")
	var cream: RobeDefinition = _repo.get_def(&"robe", &"cream")
	assert_lt(_dist(cream.cloak, Color("#EBDCCB")), 0.01, "Cream is today's cloak")
	assert_lt(_dist(cream.underside, Color("#C9B8A6")), 0.01)


## MP2 (owner, PLAN "Owner decisions" MP2): the four robes on the 75 + 25 ladder; the two epic robes at 250, styled, the
## first hidden ("???").
func test_the_robe_prices_and_the_epic_robes() -> void:
	for id: StringName in [&"night", &"canyon", &"frost", &"moss"]:
		var r: RobeDefinition = _repo.get_def(&"robe", id)
		assert_eq(
			[r.price, r.price_step, r.epic], [75, 25, false], "%s: 75, +25 a robe bought" % id
		)
	var f: RobeDefinition = _repo.get_def(&"robe", &"fallen")
	var d: RobeDefinition = _repo.get_def(&"robe", &"divine")
	assert_eq([f.price, f.price_step, f.epic, f.hidden, f.style], [250, 0, true, true, &"fallen"])
	assert_eq([d.price, d.price_step, d.epic, d.hidden, d.style], [250, 0, true, false, &"divine"])
