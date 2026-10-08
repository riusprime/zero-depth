extends GutTest
## v0.5.5 LK (owner A2: "the color of the swrod/bullets the current hit color as well, once reached the first
## threshold they turn orangem second one red"): the blade and its trail, the Gun's bolts and the skills' effects take
## the heat tier's colour from the heat meter's palette (HeatLooks.attack_color): their own colour below Hot, the
## meter's Hot orange at Hot, its Overclock red at Overclock. Read from a real world through WorldReader.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(build: StringName, enemies: Array = []) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	t.crit_chance_permille = 0
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	Heat.enable(w, ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock")))
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, 5000)
	return w


## Holds the heat at `points` (no decay) and returns the tier the sim reads for it.
func _hold(w: World, points: int) -> int:
	w.heat.milli = points * HeatTable.MILLI
	w.heat.idle = 0
	return int(WorldReader.new(w).heat_state()["tier"])


func _f(held: int = 0, pressed: int = 0) -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 300, held, pressed)


func test_the_attack_palette_is_the_meters_tier_colours() -> void:
	var base := Color("#7FE9FF")
	assert_eq(HeatLooks.attack_color(base, HeatLooks.TIER_COOL), base, "below Hot: its own colour")
	assert_eq(HeatLooks.attack_color(base, HeatLooks.TIER_HOT), HeatLooks.HOT, "Hot: the orange")
	assert_eq(
		HeatLooks.attack_color(base, HeatLooks.TIER_OVERCLOCK),
		HeatLooks.OVERCLOCK,
		"Overclock: red"
	)
	assert_eq(
		HeatLooks.attack_color(base, HeatLooks.TIER_OVERHEAT),
		HeatLooks.OVERCLOCK,
		"overheated: still red"
	)
	assert_gt(HeatLooks.HOT.g, HeatLooks.OVERCLOCK.g + 0.25, "orange and red read apart")
	assert_eq(HeatLooks.tier_of({}), HeatLooks.TIER_COOL, "no heat: cool")


func test_the_blade_and_its_trail_follow_the_heat_tier() -> void:
	var w := _world(&"blade")
	var r := WorldReader.new(w)
	var kit := KitView.new()
	add_child_autofree(kit)
	var base := kit.color
	var want := {0: base, 30: base, 41: HeatLooks.HOT, 74: HeatLooks.HOT, 76: HeatLooks.OVERCLOCK}
	var tiers := {0: 0, 30: 0, 41: 1, 74: 1, 76: 2}
	for points: int in want:
		assert_eq(_hold(w, points), tiers[points], "%d heat is tier %d" % [points, tiers[points]])
		kit.sync(r)
		assert_eq(kit.hue(), want[points], "%d heat: the blade's colour" % points)
		assert_eq(kit.heat_tier, tiers[points])
	# A swing at Overclock: the trail's tip colour is the blade's red (lightened as the trail always is).
	_hold(w, 80)
	w.step(_f(InputFrame.PRIMARY, InputFrame.PRIMARY))
	for k in 3:
		w.step(_f())
		kit.sync(r)
	assert_true(kit.blade_visible(), "swinging")
	assert_eq(kit.hue(), HeatLooks.OVERCLOCK, "the swing is red")


func _bolt_color(actors: ActorViews, r: WorldReader) -> Color:
	var id := r.projectile_id(r.projectile_count() - 1)
	var holder := actors.projectile_node(id)
	var mesh := holder.get_child(0) as MeshInstance3D
	return (mesh.material_override as StandardMaterial3D).albedo_color


func test_bolts_take_the_heat_tier_colour_when_fired() -> void:
	var w := _world(&"gun")
	var r := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	actors.sync(r)
	var base := actors.bolt_color()
	assert_eq(base, ThemePalette.color(&"player_core"), "cool: the player's cyan")
	var seen := {}
	for points: int in [10, 50, 90]:
		_hold(w, points)
		var before := r.projectile_count()
		for k in 40:
			w.heat.milli = points * HeatTable.MILLI
			w.step(_f(InputFrame.SHOOT, InputFrame.SHOOT if k == 0 else 0))
			actors.sync(r)
			if r.projectile_count() > before:
				break
		assert_gt(r.projectile_count(), before, "%d heat: a bolt flew" % points)
		seen[points] = _bolt_color(actors, r)
	assert_eq(seen[10], base, "under Hot: the bolt keeps its colour")
	assert_eq(seen[50], HeatLooks.HOT, "Hot: orange bolts")
	assert_eq(seen[90], HeatLooks.OVERCLOCK, "Overclock: red bolts")


func test_the_skills_effects_take_the_heat_tier_colour() -> void:
	var w := _world(&"gun", [Vector2(2, 0)])
	var r := WorldReader.new(w)
	var fx := SkillVisuals.new()
	add_child_autofree(fx)
	fx.sync(r)
	assert_eq(fx.fx_color(), SkillVisuals.COLOR, "cool: the skill's own cyan")
	_hold(w, 80)
	w.step(_f(0, InputFrame.SKILL))
	w.heat.milli = 80 * HeatTable.MILLI
	fx.sync(r)
	assert_eq(fx.fx_color(), HeatLooks.OVERCLOCK, "Overclock: red")
	assert_eq(fx.fx_color_of(&"cone"), HeatLooks.OVERCLOCK, "the blast's cone flash is red")
	var b := _world(&"blade", [Vector2(5.5, 0)])
	var rb := WorldReader.new(b)
	var fb := SkillVisuals.new()
	add_child_autofree(fb)
	_hold(b, 50)
	b.step(_f(0, InputFrame.SKILL))
	for k in 12:
		b.heat.milli = 50 * HeatTable.MILLI
		b.step(_f())
		fb.sync(rb)
	assert_eq(fb.fx_color(), HeatLooks.HOT, "Hot: orange")
	assert_eq(fb.fx_color_of(&"streak"), HeatLooks.HOT, "the lunge's streak is orange")
	assert_gt(fb.cleave_sweep()[1], 0.0, "and the cleave sweep is drawn")
