extends GutTest
## The six horde kinds reach the real game (v0.4.0 EN). On a run they join the spawner's mix from danger tiers 1-3
## (tests/content/test_spawning_validation.gd); here the dev panel, opened with backtick and clicked with the mouse,
## brings each one in at once and the test watches it act through the real loop: its model is drawn, its telegraph
## shows and its attack reaches the player (a HIT event; God mode, also clicked, keeps the player standing). The Mine
## Layer's mine is walked onto with the left stick; the Mender heals an ally the player has shot.

## How close the player stays to a Shield Bearer it stands up to (m): inside its bash's reach.
const FACE_M := 1.4


func _click(e: E2e, main: Main, button_name: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button_name, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _spawn(e: E2e, main: Main, kind: int, key: String) -> int:
	var choice := main.get_node("UI/DevPanel").find_child("EnemyChoice", true, false) as Label
	for k in 16:
		if choice.text == tr(key):
			break
		await _click(e, main, "NextEnemy")
		await e.frames(1)
	assert_eq(choice.text, tr(key), "the panel names the %s" % key)
	await _click(e, main, "SpawnEnemy")
	await e.frames(3)
	var w := e.world()
	var best := -1
	for i in range(1, w.actors.size()):
		if w.actors.kinds[i] == kind and w.actors.dead[i] == 0:
			best = maxi(best, w.actors.ids[i])  # the newest one
	assert_gt(best, 0, "%s came" % key)
	assert_not_null(main.view.actors.actor_node(best), "%s: its model is drawn" % key)
	return best


## Steps frames until actor `id` lands a HIT on the player (true), noting whether a telegraph in `styles` showed.
## `face_it`: the player steps back in front of the enemy (left stick) whenever it is more than FACE_M away, the way
## you stand up to a Shield Bearer. Its bash locks its facing at the windup and it turns slowly, while the floor's
## own spawns and the kinds spawned before it keep hitting the player in God mode, and every hit knocks the player
## aside; standing still, whether a knock lands inside a bash's windup depends only on the AI's id-staggered schedule
## (v0.4.0 SC), which one more entity id at floor setup (v0.5.0 SH's shop terminal) shifts.
func _watch(e: E2e, main: Main, id: int, styles: Array, frames: int, face_it := false) -> Array:
	var w := e.world()
	var styled := false
	var hit := false
	var seq := w.last_event_seq()
	for k in frames:
		await e.frames(1)
		var i := w.actors.index_of(id)
		if i < 0:
			break
		if face_it:
			var to := w.actors.pos(i) - w.player_pos()
			e.stick_toward(to.normalized() if to.length() > FACE_M else Vector2.ZERO)
		var tg := main.driver.reader.telegraph(i)
		if (
			not tg.is_empty()
			and styles.has(tg.get("style", &""))
			and main.view.telegraphs.count() > 0
		):
			styled = true
		for ev in w.events_since(seq):
			seq = ev.seq
			if ev.kind == SimEvent.Kind.HIT and ev.target_id == w.actors.ids[0]:
				hit = hit or ev.owner_id == id
		if styled and hit:
			break
	if face_it:
		e.stick_toward(Vector2.ZERO)
		await e.frames(1)
	return [styled, hit]


func test_the_dev_panel_brings_in_each_horde_kind_and_it_acts() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	assert_true(main.driver.debug.god, "God mode")
	for spec in [
		[ActorStore.Kind.SWARMER, "ENEMY_SWARMER", [&""]],
		[ActorStore.Kind.SPLITTER, "ENEMY_SPLITTER", [&""]],
		[ActorStore.Kind.SHIELD_BEARER, "ENEMY_SHIELD_BEARER", [&"bash"]],
		[ActorStore.Kind.SNIPER, "ENEMY_SNIPER", [&"snipe"]],
	]:
		var id: int = await _spawn(e, main, spec[0], spec[1])
		var bearer: bool = spec[0] == ActorStore.Kind.SHIELD_BEARER
		var got: Array = await _watch(e, main, id, spec[2], 900, bearer)
		assert_true(got[0], "%s: its telegraph is drawn" % spec[1])
		assert_true(got[1], "%s: its attack reached the player" % spec[1])
	# The Mine Layer drops a mine; walking onto it arms it (its circle fills) and it blows on the player.
	var layer: int = await _spawn(e, main, ActorStore.Kind.MINE_LAYER, "ENEMY_MINE_LAYER")
	var w := e.world()
	var reader := main.driver.reader
	for k in 600:
		await e.frames(1)
		if main.view.horde_fx.mine_count() > 0:
			break
	assert_gt(main.view.horde_fx.mine_count(), 0, "its mine lies on the floor, drawn")
	var mine_at := Vector2.INF
	for k in reader.mine_count():
		if w.mines.owner[k] == layer:
			mine_at = reader.mine_pos(k)
	assert_ne(mine_at, Vector2.INF, "the mine is the layer's")
	var reached: bool = await e.walk_to(mine_at, 0.4)
	assert_true(reached, "walked onto the mine")
	var got: Array = await _watch(e, main, layer, [&"mine"], 300)
	assert_true(got[0], "the armed mine's circle is drawn")
	assert_true(got[1], "the mine blew on the player")


func test_the_mender_heals_an_ally_the_player_shot() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu(&"gun")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	var mender: int = await _spawn(e, main, ActorStore.Kind.MENDER, "ENEMY_MENDER")
	var ally: int = await _spawn(e, main, ActorStore.Kind.SPLITTER, "ENEMY_SPLITTER")
	var w := e.world()
	var node := main.view.actors.actor_node(mender)
	assert_true(node.get_meta(&"enemy_avatar") is HordeAvatar, "the Mender's model")
	assert_true(
		main.driver.reader.actor_priority(w.actors.index_of(mender)), "marked as a priority target"
	)
	# Shoot the Splitter (aimed with the mouse, the shoot button held: right click) until it is hurt.
	var cam := main.view.rig.camera
	var hurt := false
	e.mouse_button(MOUSE_BUTTON_RIGHT, true)
	for k in 300:
		var j := w.actors.index_of(ally)
		if j < 0:
			break
		await e.mouse_to(cam.unproject_position(SimPlane.to_3d(w.actors.pos(j))))
		if w.actors.hp[j] < w.actors.max_hp[j]:
			hurt = true
			break
	e.mouse_button(MOUSE_BUTTON_RIGHT, false)
	assert_true(hurt, "the Splitter took a bolt")
	var healed := false
	var beam := false
	var seq := 0
	for k in 600:
		await e.frames(1)
		beam = beam or main.view.horde_fx.beam_count() > 0
		for ev in w.events_since(seq):
			seq = ev.seq
			if ev.kind == SimEvent.Kind.HEAL and ev.owner_id == mender and ev.target_id == ally:
				healed = true
		if healed and beam:
			break
	assert_true(beam, "its heal beam is drawn")
	assert_true(healed, "it healed the Splitter")
