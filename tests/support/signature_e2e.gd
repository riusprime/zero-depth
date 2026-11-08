class_name SignatureE2e
extends RefCounted
## v0.11.0 E2E: the shared steps of the biome-roster e2e (test_e2e_signatures_*): a run on a chosen biome, started
## from the menu through real input (the seed is the fixed-seed mode the e2e already use, Main.fixed_seed: the first
## seed whose floor 1 is that biome), the dev panel's God and enemy spawn (backtick, mouse clicks), and the Gun's shot
## held on an enemy with the mouse until it dies. Reads only, besides input events.

const SEED_FROM := 1
const SEED_TO := 400

var e: E2e
var main: Main
var test: GutTest


func _init(p_test: GutTest) -> void:
	test = p_test
	e = E2e.new(p_test)


## The first run seed (from SEED_FROM) whose floor 1 is `biome` for `build`, or -1.
static func seed_for(biome: StringName, build: StringName = &"gun") -> int:
	var repo := ContentRepository.load_all()
	var def: RunDefinition = repo.get_def(&"run", SaveLab.RUN_ID)
	var compiled := ContentCompiler.compile_run(def)
	for s in range(SEED_FROM, SEED_TO):
		var run := RunState.start(s, compiled, build)
		if def.biomes[run.biome_of(1)] == biome:
			return s
	return -1


## Boots main.tscn on that seed, plays from the menu (hub, portal, Gun) and opens the dev panel with God on. The panel
## stays open (closing it drops God, v0.8.0 BP). False when the floor is not `biome`.
func start_on(biome: StringName) -> bool:
	TranslationServer.set_locale("en")
	var s := seed_for(biome)
	test.assert_gt(s, 0, "a seed whose floor 1 is %s" % biome)
	if s < 0:
		return false
	main = await e.boot(null, null, s)
	await e.start_from_menu(&"gun")
	test.assert_eq(main.run_biome_id(), biome, "the run's floor 1 is %s" % biome)
	await e.tap(KEY_QUOTELEFT)
	test.assert_true(main.is_dev_panel_open(), "the dev panel")
	await click("God")
	test.assert_true(main.driver.debug.god, "God mode")
	return main.run_biome_id() == biome


func click(button_name: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button_name, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


## The floor's own roster (FloorPlan: VariantCompiler.roster_kinds) holds every kind in `kinds`.
func roster_has(kinds: Array) -> bool:
	var w := e.world()
	for k: int in kinds:
		if not w.roster_kinds.has(k):
			return false
	return true


## The dev panel's NextEnemy until it names `key`, then SpawnEnemy (about 6 m from the hero). Returns the newest
## living actor of `kind` (its id), -1 when none came. Asserts its model is drawn.
func spawn(kind: int, key: String) -> int:
	var choice := main.get_node("UI/DevPanel").find_child("EnemyChoice", true, false) as Label
	for k in 64:
		if choice.text == tr(key):
			break
		await click("NextEnemy")
		await e.frames(1)
	test.assert_eq(choice.text, tr(key), "the panel names the %s" % key)
	await click("SpawnEnemy")
	await e.frames(3)
	var w := e.world()
	var best := -1
	for i in range(1, w.actors.size()):
		if w.actors.kinds[i] == kind and w.actors.dead[i] == 0:
			best = maxi(best, w.actors.ids[i])
	test.assert_gt(best, 0, "%s came" % key)
	if best > 0:
		test.assert_not_null(main.view.actors.actor_node(best), "%s: its model is drawn" % key)
	return best


func alive(id: int) -> bool:
	var w := e.world()
	var i := w.actors.index_of(id)
	return i >= 0 and w.actors.dead[i] == 0


## Steps up to `n` frames until `cond` (no arguments, returns bool) holds. True when it did.
func until(cond: Callable, n: int) -> bool:
	for k in n:
		if cond.call():
			return true
		await e.frames(1)
	return cond.call()


## Points the mouse at sim point `at` (the aim plane's height).
func aim_at(at: Vector2) -> void:
	var cam := main.view.rig.camera
	await e.mouse_to(cam.unproject_position(SimPlane.to_3d(at, SimPlane.CORE_HEIGHT)))


## Holds Shoot (the right mouse button) with the mouse on actor `id` each frame, `n` frames at most, while `each`
## (called with the actor's index every frame; may be a no-op) watches. True when it died. `stand_off_m` > 0: the left
## stick keeps the hero at least that far from it (a slam or a bite would knock the aim about).
func shoot_dead(id: int, n: int, each: Callable = Callable(), stand_off_m: float = 0.0) -> bool:
	var w := e.world()
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	for k in n:
		var i := w.actors.index_of(id)
		if i < 0 or w.actors.dead[i] == 1:
			break
		if each.is_valid():
			each.call(i)
		var to := w.actors.pos(i) - w.player_pos()
		if stand_off_m > 0.0:
			e.stick_toward(-to.normalized() if to.length() < stand_off_m else Vector2.ZERO)
		await aim_at(w.actors.pos(i))
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	e.stick_toward(Vector2.ZERO)
	await e.frames(1)
	return not alive(id)
