extends GutTest
## Taking damage, dying and restarting, again and again, through real input only (PLAN v0.2.0 L11: "when receiving
## dmg the game sometime lags and even crash"; docs/roadmap/v0.2.0/evidence/DAMAGE_LAG.md). The left stick walks
## the wanderer into the nearest enemy until it dies; Enter on the end panel restarts. Across the deaths: no engine
## or script error, no orphan nodes, the node count back to where the first fight started, and every material on
## the wanderer keeps its shader through all the hits (the flash changes only parameters).

const DEATHS := 2
## Out-of-combat regen (v0.3.0 L25) heals between the sparse early hits, so a life lasts longer than before (the
## second life measured 9330 frames with regen, about 7200 without): twice that as the limit.
const MAX_FRAMES_PER_LIFE := 18000


func after_each() -> void:
	Input.action_release(&"move_up")


func test_take_hits_die_and_restart_with_no_errors_or_growth() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.frames(5)
	# The stage (ground tiles, props, walls) differs from floor to floor, and a restart rolls a new floor, so the
	# leak check counts every node outside the stage.
	var start_nodes := _nodes_outside_stage(main)
	var hits := 0
	var frames := 0
	var swapped := 0
	for life in DEATHS:
		var w := e.world()
		assert_not_null(w, "life %d: the fight is running" % life)
		var player := main.view.actors.actor_node(w.actors.ids[0])
		var keys := DamageFlashKeys.of(player)
		var last_hp := w.actors.hp[0]
		var nav := NavField.new()
		nav.build(E2e.walk_walls(w, w.player_pos()))
		for k in MAX_FRAMES_PER_LIFE:
			if w.player_dead():
				break
			var target := _nearest_enemy(w)
			if k % 20 == 0:
				nav.flood(target)
			var p := w.player_pos()
			var dir := (
				(target - p).normalized() if (target - p).length() < 2.0 else nav.direction(p)
			)
			var c := InputLatch.C45
			e.joy_axis(JOY_AXIS_LEFT_X, (dir.x + dir.y) * c)
			e.joy_axis(JOY_AXIS_LEFT_Y, -(dir.y - dir.x) * c)
			await e.frames(1)
			frames += 1
			if w.actors.hp[0] < last_hp:
				hits += 1
				# The flash is on now: it must not have swapped a shader.
				if DamageFlashKeys.of(player) != keys:
					swapped += 1
			last_hp = w.actors.hp[0]
		e.joy_axis(JOY_AXIS_LEFT_X, 0.0)
		e.joy_axis(JOY_AXIS_LEFT_Y, 0.0)
		assert_true(w.player_dead(), "life %d: walking into the enemies killed the wanderer" % life)
		await e.frames(Main.END_PANEL_DELAY_TICKS + 5)
		assert_not_null(main.get_node_or_null("UI/EndPanel"), "life %d: the end panel" % life)
		await e.tap(KEY_ENTER)  # Restart has focus
		await e.frames(5)
		assert_ne(e.world(), w, "life %d: Enter restarted the fight" % life)
	var nodes := _nodes_outside_stage(main)
	gut.p(
		(
			"soak: %d deaths, %d hits, %d frames; nodes %d -> %d"
			% [DEATHS, hits, frames, start_nodes, nodes]
		)
	)
	assert_gt(hits, DEATHS * 2, "the wanderer was hit again and again (%d hits)" % hits)
	assert_eq(swapped, 0, "no hit swapped a shader on the wanderer")
	assert_eq(get_errors().size(), 0, "no engine or script error while taking damage")
	assert_eq(
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), 0, "no orphan nodes"
	)
	assert_lt(
		absi(nodes - start_nodes),
		start_nodes / 10,
		(
			"after %d deaths the node count (%d) is back near the first fight's (%d)"
			% [DEATHS, nodes, start_nodes]
		)
	)


func _nodes_outside_stage(main: Main) -> int:
	var total := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	return total - _subtree_size(main.view.stage)


func _subtree_size(n: Node) -> int:
	var count := 1
	for c in n.get_children():
		count += _subtree_size(c)
	return count


func _nearest_enemy(w: World) -> Vector2:
	var best := w.player_pos() + Vector2(1, 0)
	var dist := INF
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 1 or not EnemyAi.is_enemy_kind(w.actors.kinds[i]):
			continue
		var d := w.actors.pos(i).distance_to(w.player_pos())
		if d < dist:
			dist = d
			best = w.actors.pos(i)
	return best
