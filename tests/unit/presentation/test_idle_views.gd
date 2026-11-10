extends GutTest
## A view with nothing to show does no work: once a sync (or a frame) has drawn its empty state, the next ones return
## at once (the view's `quiet`), and the view wakes as soon as there is something again, then hides it all when it
## goes. Each test checks all three: quiet when idle, drawn when there is something, hidden and quiet again after.

const W := preload("res://tests/support/mx4_world.gd")
const DT := 1.0 / 60.0


func after_each() -> void:
	ViewPrefs.reduced_motion = false


func _visible(nodes: Array) -> int:
	var n := 0
	for node: Node3D in nodes:
		n += 1 if node.visible else 0
	return n


func test_seekers_idle_then_wake_on_a_volley() -> void:
	var view: SeekersView = add_child_autofree(SeekersView.new())
	view.set_process(false)
	var w := W.world(&"gun", [&"gun_seekers"])
	var r := WorldReader.new(w)
	view.sync(r)
	view.sync(r)
	assert_true(view.quiet, "no dart: quiet")
	W.run(w, 1, 0, W.S)
	view.sync(r)
	assert_false(view.quiet, "a volley wakes it")
	assert_eq(view.darts, 3)
	assert_eq(_visible(view._needles), 3, "its needles show")
	W.run(w, 80, 0, 0)
	view.sync(r)
	assert_eq(view.darts, 0, "gone")
	assert_eq(_visible(view._needles) + _visible(view._motes), 0, "and hidden")
	view.sync(r)
	assert_true(view.quiet, "quiet again")


func test_wisps_idle_without_the_card_and_wake_with_it() -> void:
	var view: WispsView = add_child_autofree(WispsView.new())
	view.set_process(false)
	var plain := WorldReader.new(W.world(&"gun"))
	var w := W.world(&"gun", [&"gun_wisps"])
	W.run(w, 2, 0, 0)
	var wisps := WorldReader.new(w)
	view.sync(plain)
	view.sync(plain)
	assert_true(view.quiet, "no wisp: quiet")
	view.sync(wisps)
	assert_false(view.quiet, "wisps wake it")
	assert_gt(view.wisps, 0)
	assert_eq(_visible(view._orbs), view.wisps, "each orb shows")
	view.sync(plain)
	assert_eq(_visible(view._orbs), 0, "hidden when they go")
	view.sync(plain)
	assert_true(view.quiet, "quiet again")


func test_a_void_wakes_its_view_and_its_collapse_plays_out_before_quiet() -> void:
	var view: VoidView = add_child_autofree(VoidView.new())
	var w := W.world(&"gun", [&"gun_void"])
	var r := WorldReader.new(w)
	view.sync(r)
	view.sync(r)
	assert_true(view.quiet, "no shot: quiet")
	W.run(w, 3, 0, W.S)
	view.sync(r)
	assert_false(view.quiet, "a shot wakes it")
	assert_eq(view.voids, 1)
	W.run(w, 90, 0, 0)
	view.sync(r)
	assert_eq(view.voids, 0, "gone with the shot")
	for k in 60:
		W.run(w, 1, 0, 0)
		view.sync(r)
	assert_eq(_visible(view._cores) + _visible(view._gone_cores), 0, "its collapse played out")
	assert_true(view.quiet, "then quiet")


func test_blade_forms_idle_then_wake_on_a_crescent() -> void:
	var w := WandLab.fight(&"blade", [&"echo_slash"])
	var r := WorldReader.new(w)
	var view: BladeFormView = add_child_autofree(BladeFormView.new())
	view.sync(r)
	view.sync(r)
	assert_true(view.quiet, "nothing flying yet: quiet")
	var woke := false
	var slept_again := false
	for t in 420:
		w.step(AttackScenario.frame(t))
		view.sync(r)
		if int(view.drawn.get(&"crescent", 0)) > 0:
			woke = true
			assert_false(view.quiet, "a crescent is drawn awake")
		elif woke and view.quiet:
			slept_again = true
	assert_true(woke, "a crescent was drawn")
	assert_true(slept_again, "quiet again between slashes")


func test_the_prism_view_idles_outside_her_fight_and_wakes_in_it() -> void:
	var view: PrismViews = add_child_autofree(PrismViews.new())
	view.set_process(false)
	var plain := WorldReader.new(W.world(&"gun"))
	view.sync(plain)
	view.sync(plain)
	assert_true(view.quiet, "no fight: quiet")
	var w := FinalLab.arena(FinalLab.run_state(304))
	w.actors.invuln[0] = 1 << 24
	w.actors.max_hp[0] = 1 << 24
	w.actors.hp[0] = 1 << 24
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 1)
	FinalLab.past_rise(w)
	var i := FinalLab.body(w)
	BossAi.start_attack(w, i, BossAi.table_of(w, i).attack_index(&"cross_ring"))
	for k in 20:
		w.step(InputFrame.new())
	view.sync(WorldReader.new(w))
	assert_false(view.quiet, "her fight wakes it")
	assert_eq(view.aim_count(), 4, "the spin-up's aim lines")
	view.sync(plain)
	assert_eq(view.aim_count() + view.beam_count(), 0, "hidden when it ends")
	view.sync(plain)
	assert_true(view.quiet, "quiet again")


func test_the_tide_view_waits_for_its_fades_then_idles() -> void:
	var view: TideViews = add_child_autofree(TideViews.new())
	view.set_process(false)
	view.advance(DT)
	view.advance(DT)
	assert_true(view.quiet, "no tide: quiet")
	view._tide = {
		"phase": WorldReader.TIDE_PULL, "speed": WorldReader.TIDE_MAX_MPS, "centre": Vector2.ZERO
	}
	view.advance(DT)
	assert_false(view.quiet, "a tide wakes it")
	assert_gt(view.strength(), 0.0)
	view._tide = {}
	view.advance(DT)
	assert_false(view.quiet, "still fading")
	for k in 120:
		view.advance(DT)
	assert_eq(view.strength(), 0.0, "faded")
	assert_eq(view.bubbles_drawn(), 0, "nothing drawn")
	assert_true(view.quiet, "then quiet")


func test_the_judge_view_waits_for_its_fades_then_idles() -> void:
	var view: JudgeViews = add_child_autofree(JudgeViews.new())
	view.set_process(false)
	view.advance(DT)
	view.advance(DT)
	assert_true(view.quiet, "no echo: quiet")
	view._spawn_ghost(0, Vector3.ZERO)
	view.advance(DT)
	assert_false(view.quiet, "a ghost strike wakes it")
	assert_eq(view.ghosts_shown(), 1)
	for k in 240:
		view.advance(DT)
	assert_eq(view.ghosts_shown() + view.filings_shown(), 0, "played out")
	assert_true(view.quiet, "then quiet")


func test_the_twin_view_waits_for_its_fades_then_idles() -> void:
	var view: TwinViews = add_child_autofree(TwinViews.new())
	view.set_process(false)
	for k in 30:  # the chain's heat settles to its cold level
		view.advance(DT)
	assert_true(view.quiet, "no chain: quiet")
	view._chain = [Vector2(-3, 0), Vector2(3, 0)]
	view.advance(DT)
	assert_false(view.quiet, "a chain wakes it")
	assert_gt(view._links.multimesh.visible_instance_count, 0, "its links show")
	view._chain = []
	for k in 30:
		view.advance(DT)
	assert_eq(view._links.multimesh.visible_instance_count, 0, "hidden when it goes")
	assert_true(view.quiet, "then quiet")


func test_the_shade_view_idles_without_its_dark() -> void:
	var view: ShadeViews = add_child_autofree(ShadeViews.new())
	view.set_process(false)
	view.advance(DT)
	view.advance(DT)
	assert_true(view.quiet, "no dark: quiet")
	view._light = {"dark": true, "falling": -1, "light_m": 3.5, "lamp_m": 3.0, "lamps": []}
	view.advance(DT)
	assert_false(view.quiet, "the dark wakes it")
	assert_true(view.dark_quad.visible, "the dark shows")
	view._light = {}
	for k in 300:
		view.advance(DT)
	assert_false(view.dark_quad.visible, "lifted")
	assert_true(view.quiet, "then quiet")


func test_the_tide_wave_view_idles_without_waves() -> void:
	var view: TideWaveViews = add_child_autofree(TideWaveViews.new())
	view.set_process(false)
	var plain := WorldReader.new(W.world(&"gun"))
	view.sync(plain)
	view.advance(DT)
	view.advance(DT)
	assert_true(view.quiet, "no wave: quiet")
	assert_true(view._placed_empty, "and its placing too")


func test_the_interphase_view_idles_outside_the_interphase() -> void:
	var view: InterphaseViews = add_child_autofree(InterphaseViews.new())
	view.set_process(false)
	var plain := WorldReader.new(W.world(&"gun"))
	view.sync(plain)
	view.sync(plain)
	assert_true(view.quiet, "no interphase: quiet")
	view._process(DT)
	assert_true(view.quiet, "and its frames")
	view._bursts.append([0, Vector3.ZERO, 0.0])  # (a sync starts a burst, then draws)
	view._redraw(0.0)
	assert_false(view.quiet, "something to show wakes it")
	assert_gt(view._runes.multimesh.visible_instance_count, 0, "the burst's runes show")
	for k in 120:
		view._process(DT)
	assert_true(view.quiet, "the burst played out: quiet")


func test_an_attack_form_pool_writes_only_a_change() -> void:
	var p: AttackFormPool = add_child_autofree(
		AttackFormPool.new(&"t", QuadMesh.new(), StandardMaterial3D.new(), 4)
	)
	p.begin()
	p.add(Transform3D.IDENTITY, Color.WHITE)
	p.finish()
	assert_eq(p.multimesh.visible_instance_count, 1)
	assert_true(p.visible)
	p.begin()
	p.finish()
	assert_eq(p.multimesh.visible_instance_count, 0, "an empty frame shows none")
	assert_false(p.visible)
