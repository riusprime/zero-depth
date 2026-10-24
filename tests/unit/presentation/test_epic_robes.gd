extends GutTest
## v0.9.0 MP2 (owner, PLAN "Owner decisions" MP2): the two epic robes on the hero (EpicRobeView). The Fallen's robe
## builds its long robe, mantle, sheen and trim, the spiked crown and the red-violet eyes, and hides the blue face
## square (owner, 2026-10-24: "if it has the red eyes it should not have the blue square") and turns the plain shots
## violet ("the black one should also modify the attack color to a purle violet kind of attack"); the divine one its
## crown and halo (band, core, beads, glow), keeps the visor and the usual shot colour. Both draw in the poncho's
## place, ride its springs (the hem lags a move and settles), trail while moving, and a colour robe brings the
## poncho and the visor back. Effects density Low keeps every shape and drops the trail, the motes and the light;
## reduced motion stills the halo. No enemy red or hostile yellow on the cloth or the trim.

const ENEMY_RED := Color("#E25A4C")
const HOSTILE_YELLOW := Color("#FBD07A")

var _repo: ContentRepository
var _density := "high"
var _calm := false


func before_all() -> void:
	_repo = ContentRepository.load_all()


func before_each() -> void:
	_density = ViewPrefs.effects_density
	_calm = ViewPrefs.reduced_motion
	ViewPrefs.effects_density = "high"
	ViewPrefs.reduced_motion = false


func after_each() -> void:
	ViewPrefs.effects_density = _density
	ViewPrefs.reduced_motion = _calm
	ElementLooks.set_energy(&"")


func _look(robe: StringName) -> Dictionary:
	return Wardrobe.look(_repo, _repo.get_def(&"robe", robe), &"ember")


func _avatar(robe: StringName) -> PlayerAvatar:
	var a := PlayerAvatar.new()
	a.setup(Color("#1A1A22"))
	add_child_autofree(a)
	a.set_look(_look(robe))
	return a


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_the_look_carries_the_style() -> void:
	assert_eq(_look(&"fallen")["style"], &"fallen")
	assert_eq(_look(&"divine")["style"], &"divine")
	assert_eq(_look(&"night")["style"], &"", "a colour robe has none")


func test_the_fallen_robe_builds_its_pieces_and_hides_the_blue_square() -> void:
	var a := _avatar(&"fallen")
	assert_not_null(a.epic, "an epic robe's pieces")
	assert_eq(a.epic.style, &"fallen")
	for n in ["Cape", "Sheen", "Trim", "Crown", "Gems", "Eyes", "Trail", "Light"]:
		assert_true(a.epic.pieces().has(n), "The Fallen's %s" % n)
	assert_null(a.epic.halo, "no halo on The Fallen")
	assert_eq(a.epic.eye_glow.size(), 2, "two eyes glowing")
	assert_false(a.visor.visible, "owner: red eyes, no blue square")
	assert_false(a.cloak.visible, "the robe is drawn in the poncho's place")
	assert_not_null(a.epic.hood_sheen, "a sheen layered on the hood")
	assert_gt((a.epic.crown.mesh as ArrayMesh).get_faces().size(), 300, "a crown mesh, not a box")
	assert_gt((a.epic.cape.mesh as ArrayMesh).get_faces().size(), 100, "the robe's cloth is built")


func test_the_divine_robe_builds_its_halo_and_keeps_the_visor() -> void:
	var a := _avatar(&"divine")
	for n in ["Cape", "Crown", "Gems", "Halo", "HaloMotes", "Trail", "Light"]:
		assert_true(a.epic.pieces().has(n), "the divine %s" % n)
	assert_null(a.epic.eyes, "no eyes: the visor is its face")
	for n in ["HaloBand", "HaloCore", "HaloBeads", "HaloGlow"]:
		assert_not_null(a.epic.halo.get_node_or_null(n), "the halo's %s" % n)
	assert_true(a.visor.visible, "the divine robe keeps the blue visor")


func test_a_colour_robe_brings_the_poncho_and_visor_back() -> void:
	var a := _avatar(&"fallen")
	a.set_look(_look(&"night"))
	assert_null(a.epic, "the epic pieces are gone")
	assert_true(a.visor.visible, "the blue square is back with a normal robe")
	assert_true(a.cloak.visible, "and the poncho")
	assert_eq(a.hood.get_child(0).get_child_count(), 0, "the hood's sheen went with them")
	a.set_look(_look(&"divine"))
	a.set_look(_look(&"fallen"))
	assert_eq(a.epic.style, &"fallen", "switching epic robes rebuilds")
	assert_false(a.visor.visible)


func test_low_density_keeps_the_shapes_and_drops_the_effects() -> void:
	ViewPrefs.effects_density = "low"
	var f := _avatar(&"fallen")
	var d := _avatar(&"divine")
	for n in ["Cape", "Sheen", "Trim", "Crown", "Gems", "Eyes"]:
		assert_true(f.epic.pieces().has(n), "Low keeps The Fallen's %s" % n)
	for n in ["Cape", "Crown", "Gems", "Halo"]:
		assert_true(d.epic.pieces().has(n), "Low keeps the divine %s" % n)
	assert_not_null(d.epic.halo.get_node_or_null("HaloGlow"), "and the halo's glow")
	for a: PlayerAvatar in [f, d]:
		assert_null(a.epic.trail, "no trail at Low")
		assert_null(a.epic.light, "no light at Low")
	assert_null(d.epic.halo_motes, "no motes at Low")
	ViewPrefs.effects_density = "medium"
	var m := _avatar(&"divine")
	assert_eq(m.epic.trail_cap, EpicRobeView.TRAIL_CAP / 2, "Medium halves the trail's pool")


func test_the_cloth_rides_the_springs_and_trails_while_moving() -> void:
	var a := _avatar(&"fallen")
	var rest := a.epic.hem()
	a.set("_vel", Vector2(6.0, 0.0))
	for _i in 30:
		a.advance(1.0 / 60.0)
	var moved := a.epic.hem()
	var lag := 0.0
	for k in rest.size():
		lag = maxf(lag, rest[k].distance_to(moved[k]))
	assert_gt(lag, 0.05, "the hem swings with the move")
	assert_gt(a.epic.hem_offset(), 0.03, "and lags behind it (the springs)")
	assert_gt(a.epic.trail_alive(), 0, "smoke trails from the hem while moving")
	assert_lte(a.epic.trail_alive(), a.epic.trail_cap, "never past the pool's cap")
	a.set("_vel", Vector2.ZERO)
	for _i in 240:
		a.advance(1.0 / 60.0)
	assert_eq(a.epic.trail_alive(), 0, "the trail fades out once still")
	assert_lt(a.epic.hem_offset(), 0.01, "the hem settles back on its rest")


func test_reduced_motion_stills_the_halo() -> void:
	ViewPrefs.reduced_motion = true
	var a := _avatar(&"divine")
	var before := a.epic.halo.transform
	var motes := a.epic.halo_motes.multimesh.get_instance_transform(0)
	for _i in 20:
		a.advance(1.0 / 60.0)
	assert_true(a.epic.halo.transform.is_equal_approx(before), "no turn, no bob")
	assert_true(
		a.epic.halo_motes.multimesh.get_instance_transform(0).is_equal_approx(motes), "motes still"
	)


func test_no_enemy_red_or_hostile_yellow_on_the_cloth() -> void:
	for s: StringName in EpicRobeView.STYLES:
		var look: Dictionary = EpicRobeView.LOOKS[s]
		for k in ["hi", "mid", "lo", "in", "trim", "trim_hot"]:
			var c: Color = look[k]
			assert_gt(_dist(c, ENEMY_RED), 0.2, "%s %s is not the enemy red" % [s, k])
			assert_gt(_dist(c, HOSTILE_YELLOW), 0.2, "%s %s is not the hostile yellow" % [s, k])


func test_the_back_rune_sits_on_the_robe() -> void:
	var a := _avatar(&"fallen")
	a.advance(1.0 / 60.0)
	assert_true(a.runes.back.visible, "the affinity's rune still shows on the back")
	var at := a.runes.back.position
	assert_lt(at.x, -0.1, "behind the body, on the robe's back")


func test_the_dark_robe_turns_the_plain_shots_violet() -> void:
	var blue := AttackView.bolt_look({})["color"] as Color
	assert_eq(blue, ThemePalette.color(&"player_core"), "the usual colour first")
	var a := _avatar(&"fallen")
	assert_eq(
		AttackView.bolt_look({})["color"], ElementLooks.FALLEN_CORE, "the plain bolt is violet"
	)
	var look := FormLook.new()
	look.set_elements(PackedStringArray())
	assert_eq(
		[look.core, look.edge],
		[ElementLooks.FALLEN_HOT, ElementLooks.FALLEN_CORE],
		"hot core, violet"
	)
	assert_eq(look.deep, ElementLooks.FALLEN_DEEP, "a deep violet behind it")
	assert_eq(
		ElementLooks.pair(PackedStringArray()), [ElementLooks.FALLEN_HOT, ElementLooks.FALLEN_CORE]
	)
	look.set_elements(PackedStringArray(["ember"]))
	assert_eq(look.edge, ElementLooks.core(&"ember"), "an element keeps its own colour")
	var pulse := HeroPulseViews.colors(ElementLooks.FALLEN_CORE)
	assert_gt(
		pulse[0].get_luminance(), pulse[1].get_luminance(), "layered: a pale core over the violet"
	)
	a.set_look(_look(&"divine"))
	assert_eq(AttackView.bolt_look({})["color"], blue, "the divine robe keeps the usual colour")
	a.set_look(_look(&"night"))
	assert_eq(
		ElementLooks.pair(PackedStringArray()),
		[ElementLooks.DEFAULT_HOT, ElementLooks.DEFAULT_CORE]
	)
	assert_eq(AttackView.bolt_look({})["color"], blue, "and a colour robe")


func test_the_violet_is_apart_from_the_hostile_looks() -> void:
	var hostile := [
		Color("#E9B8FF"),
		Color("#9A4AE0"),
		ShrinesView.CHAOS,
		NemesisAvatar.EDGE,
		ENEMY_RED,
		HOSTILE_YELLOW
	]
	for c: Color in [ElementLooks.FALLEN_HOT, ElementLooks.FALLEN_CORE]:
		for h: Color in hostile:
			assert_gt(
				_dist(c, h), 0.2, "%s is apart from %s" % [c.to_html(false), h.to_html(false)]
			)
	assert_gt(ElementLooks.FALLEN_DEEP.get_luminance(), 0.0, "no black edge (V50)")
