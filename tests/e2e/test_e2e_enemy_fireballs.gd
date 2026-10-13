extends GutTest
## v0.7.5 EF (owner N16): an Arc Caster in the real game (main.tscn, real input only) casts a fan of 3 slow
## blue-white plasma balls, drawn by the world view's FireballViews in its own look, and draws no line on the ground
## while it winds up. The dev panel (backtick, then clicks) brings it in; God mode keeps the player standing.

const K := ActorStore.Kind


func _click(e: E2e, main: Main, button_name: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button_name, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _alive_enemies(w: World) -> int:
	var n := 0
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(w.actors.kinds[i]):
			n += 1
	return n


func test_an_arc_caster_casts_a_fan_of_three_plasma_balls_with_no_ground_line() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	assert_true(main.driver.debug.god, "God mode")
	var choice := main.get_node("UI/DevPanel").find_child("EnemyChoice", true, false) as Label
	for k in 16:
		if choice.text == tr("ENEMY_ARC_CASTER"):
			break
		await _click(e, main, "NextEnemy")
		await e.frames(1)
	assert_eq(choice.text, tr("ENEMY_ARC_CASTER"))
	await _click(e, main, "SpawnEnemy")
	await e.frames(3)
	await e.tap(KEY_QUOTELEFT)  # close the panel: the run goes on
	var w := e.world()
	var id := -1
	for i in range(1, w.actors.size()):
		if w.actors.kinds[i] == K.ARC_CASTER and w.actors.dead[i] == 0:
			id = w.actors.ids[i]
	assert_gt(id, 0, "the Arc Caster came")
	var casts := 0
	var lined := 0
	var best := 0
	var was_state := -1
	var known := {}
	var drawn := 0
	for k in 1800:
		await e.frames(1)
		var i := w.actors.index_of(id)
		if i < 0:
			break
		var st := w.actors.state[i]
		var spell := w.actors.pick[i]
		var fan := spell != EnemyAi.Spell.RUNE
		if st == EnemyAi.State.WINDUP and fan and _alive_enemies(w) == 1:
			var tg := main.driver.reader.telegraph(i)
			assert_eq(tg.get("ground", true), false, "a body cue, not a ground line")
			lined = maxi(lined, main.view.telegraphs.count())
		if st == EnemyAi.State.ACTIVE and was_state != EnemyAi.State.ACTIVE and fan:
			casts += 1
		var fresh := 0
		for j in w.projectiles.size():
			var pid := w.projectiles.ids[j]
			if w.projectiles.owner[j] != id or known.has(pid):
				continue
			known[pid] = true
			assert_eq(w.projectiles.look_of(j), "arc_plasma", "in the plasma look")
			var v := Vector2(w.projectiles.vel_x[j], w.projectiles.vel_y[j])
			assert_lte(Kin.length(v) * 60.0, 4.01, "slow plasma")
			fresh += 1
		if fresh > 0:
			best = maxi(best, fresh)
			drawn = maxi(drawn, main.view.fireballs.ball_count(&"arc_plasma"))
		was_state = st
		if best >= 3 and casts >= 2:
			break
	assert_gt(casts, 0, "it cast its fan")
	assert_eq(best, 3, "a fan of 3 plasma balls at once")
	assert_gte(drawn, 3, "drawn by the fireball view in its look")
	assert_eq(lined, 0, "no trajectory drawn on the ground while it winds up")
