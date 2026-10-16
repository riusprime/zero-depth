extends GutTest
## v0.8.0 N1 (owner O43: "we have to balance damage reduction for blade it is way easier to die since you have to be
## closer to kill"; D39 "go for D39": -25 % while held): the Blade build takes 750 per mille of every hit through the
## one damage-taken path (Damage.hit), multiplied with Armour; the Gun and the kernel worlds take full damage.

var _repo := ContentRepository.load_all()


func _world(build: StringName) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	if build != &"":
		ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	var w := World.new(31, t)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	return w


func _hit(w: World, amount: int) -> int:
	return Damage.hit(w, 0, amount, 9, 9, 9, 0, Vector2(3, 0), Vector2.ZERO)


func test_the_data_gives_the_blade_its_reduction() -> void:
	var blade: BuildDefinition = _repo.get_def(&"build", &"blade")
	var gun: BuildDefinition = _repo.get_def(&"build", &"gun")
	assert_eq(blade.damage_taken_permille, 750, "D39: -25 %")
	assert_eq(gun.damage_taken_permille, 1000, "the Gun takes full damage")
	assert_eq(_world(&"blade").player.damage_taken_permille, 750, "compiled into the player table")


func test_the_blade_takes_a_quarter_less() -> void:
	assert_eq(_hit(_world(&"blade"), 40), 30, "40 -> 30")
	assert_eq(_hit(_world(&"blade"), 22), 17, "22 -> 16.5, rounded half up")
	assert_eq(_hit(_world(&"blade"), 1), 1, "a hit never drops to 0")
	assert_eq(_hit(_world(&"gun"), 40), 40, "the Gun: full")
	assert_eq(_hit(_world(&""), 40), 40, "a kernel world (both weapons): full")
	assert_eq(PlayerBuild.taken_permille(_world(&"")), 1000)


func test_it_stacks_with_armour() -> void:
	var w := _world(&"blade")
	Stats.add_card(w, Stats.Stat.ARMOUR, Stats.Rarity.EPIC)  # -10 %
	assert_eq(PlayerBuild.taken_permille(w), 750)
	assert_eq(_hit(w, 100), 68, "100 x 0.90 x 0.75 = 67.5 -> 68")
	var g := _world(&"gun")
	Stats.add_card(g, Stats.Stat.ARMOUR, Stats.Rarity.EPIC)
	assert_eq(_hit(g, 100), 90, "the Gun: armour alone")


func test_enemies_take_full_damage_from_the_hero() -> void:
	var w := _world(&"blade")
	var id := w.add_dummy(Vector2(2, 0), 0.35, 1000)
	var i := w.actors.index_of(id)
	var hp := w.actors.hp[i]
	var pid := w.actors.ids[0]
	var got := Damage.hit(w, i, 10, pid, pid, w.take_root(), 0, w.player_pos(), w.actors.pos(i))
	assert_eq(hp - w.actors.hp[i], got, "the hero's hits are not cut")
	assert_eq(got, 10)
