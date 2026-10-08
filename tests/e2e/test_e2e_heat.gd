extends GutTest
## Overclock heat in the real game (v0.3.0 PLAN L18), through real input only: the left stick walks the wanderer
## up to the nearest enemy, the right stick aims at it and the left trigger swings until heat reaches Hot (the HUD
## meter fills and shows the VENT prompt), then the Vent button (pad B, v0.3.5 K) vents it. Read through
## WorldReader and the HUD: the blast hits the enemy beside you, heat resets to 0, the meter empties and the
## world view draws the blast ring at the sim's radius.

const MAX_FRAMES := 9000
const CLOSE_M := 1.5
## Stop swinging this far past the Hot threshold, and vent once an enemy is this close.
const HOT_MARGIN := 8.0
const VENT_M := 1.7
## v0.4.0 EN: at most this many Wardens from the dev panel to swing at.
const WARDENS := 12


func after_each() -> void:
	Input.action_release(&"primary")
	Input.action_release(&"dash")
	Input.action_release(&"vent")


func _nearest_enemy(r: WorldReader) -> int:
	var best := -1
	var best_d := INF
	for i in range(1, r.actor_count()):
		# v0.4.0 EN: a Shield Bearer blocks every swing from its front (no damage, so no heat); the bot leaves it be.
		if r.actor_dead(i) or r.actor_kind(i) == WorldReader.KIND_SHIELD_BEARER:
			continue
		var d := r.actor_pos(i).distance_to(r.player_pos())
		if d < best_d:
			best_d = d
			best = i
	return best


func _has_kind(r: WorldReader, kind: int) -> bool:
	for i in range(1, r.actor_count()):
		if not r.actor_dead(i) and r.actor_kind(i) == kind:
			return true
	return false


func _stick(e: E2e, x_axis: JoyAxis, y_axis: JoyAxis, dir: Vector2) -> void:
	var c := InputLatch.C45
	e.joy_axis(x_axis, (dir.x + dir.y) * c)
	e.joy_axis(y_axis, -(dir.y - dir.x) * c)


func _release(e: E2e) -> void:
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		e.joy_axis(axis, 0.0)
	e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)


func _click(e: E2e, button: String) -> void:
	var b := e.main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	assert_not_null(b, "the dev panel has %s" % button)
	await e.click_at(b.get_global_rect().get_center())


func test_hit_enemies_until_hot_then_press_vent() -> void:
	var e := E2e.new(self)
	await e.boot()
	await e.start_from_menu()
	var w := e.world()
	var r := WorldReader.new(w)
	var hud: Hud = e.main.get_node("UI/Hud")
	var meter := hud.heat_meter
	assert_false(r.heat_state().is_empty(), "the run has heat")
	assert_true(meter.visible, "the meter is on the HUD")
	assert_eq(meter.marks().size(), 3, "Hot, Overclock and the overheat point are marked")
	# The bot never dodges: the dev panel's God mode (backtick, a click) keeps it alive while the floor fills up
	# with enemies. Heat itself comes only from the bot's real swings.
	await e.tap(KEY_QUOTELEFT)
	await _click(e, "God")
	assert_true(e.main.driver.debug.god)
	# v0.4.0 EN: the floor's mix now brings Swarmers that die to one swing and kinds that keep away, so heat (which
	# needs swings landing without a 1 s gap) is built on Wardens the panel brings in next to the wanderer, a new one
	# whenever none is left (up to WARDENS).
	var choice := e.main.get_node("UI/DevPanel").find_child("EnemyChoice", true, false) as Label
	for k in 16:
		if choice.text == tr("ENEMY_WARDEN"):
			break
		await _click(e, "NextEnemy")
		await e.frames(1)
	assert_eq(choice.text, tr("ENEMY_WARDEN"), "the panel names the Warden")
	var wardens := 0
	var nav := NavField.new()
	nav.build(w.walls)
	var trigger := false
	var charging := true
	var ready := false
	var peak := 0.0
	for k in MAX_FRAMES:
		if wardens < WARDENS and charging and not _has_kind(r, WorldReader.KIND_WARDEN):
			await _click(e, "SpawnEnemy")
			wardens += 1
		var target := _nearest_enemy(r)
		var p := r.player_pos()
		var s := r.heat_state()
		var h: float = s["heat"]
		peak = maxf(peak, h)
		# Swing until a margin past Hot, then stop and close in to vent before the decay takes it back under.
		if charging and h >= float(s["hot"]) + HOT_MARGIN:
			charging = false
		elif not charging and h < float(s["hot"]):
			charging = true
		if target >= 0:
			var to := r.actor_pos(target) - p
			if k % 20 == 0:
				nav.flood(r.actor_pos(target))
			var walk := Vector2.ZERO
			if to.length() > CLOSE_M:
				walk = to.normalized() if to.length() < 3.0 else nav.direction(p)
			_stick(e, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, walk)
			_stick(e, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, to.normalized())
			if trigger or not charging:
				e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
				trigger = false
			elif r.swing_tick() == 0 and to.length() < CLOSE_M + 0.5:
				e.joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
				trigger = true
			if (
				not charging
				and int(s["tier"]) >= HeatLooks.TIER_HOT
				and s["vent_ready"]
				and to.length() < VENT_M
				and r.swing_tick() == 0
				and not r.actor_invulnerable(target)
			):
				ready = true
				break
		await e.frames(1)
	_release(e)
	gut.p("heat peak %.1f, ready %s at tick %d" % [peak, ready, r.tick()])
	assert_true(ready, "real swings made the wanderer Hot next to an enemy")
	if not ready:
		return
	await e.frames(1)
	var before := r.heat_state()
	var heat_before: float = before["heat"]
	assert_gte(heat_before, float(before["hot"]), "Hot before the vent")
	# v0.5.5 LK (A2): the blade wears the heat meter's tier colour: orange at Hot, red at Overclock.
	var kit: KitView = e.main.view.kit
	assert_eq(kit.hue(), HeatLooks.attack_color(kit.color, int(before["tier"])), "a hot blade")
	assert_ne(kit.hue(), kit.color, "not its cool colour")
	var hint := hud.kit_hud
	assert_true(hint.vent_lit(), "the vent hint is lit")
	assert_false(KitHud.key_text(&"vent").is_empty(), "the vent has a key")
	assert_true(hint.vent_text().contains(KitHud.key_text(&"vent")), "the hint names it")
	assert_ne(meter.vent_text(), "", "the meter shows the VENT prompt")
	assert_gt(meter.fill(), 0.35, "the meter is filled past the Hot mark")
	var seq := r.last_event_seq()
	e.joy_button(JOY_BUTTON_B, true)
	await e.frames(2)
	e.joy_button(JOY_BUTTON_B, false)
	await e.frames(2)
	var blast: Array[SimEvent] = []
	for ev in r.events_since(seq):
		if ev.kind == SimEvent.Kind.HIT and ev.effect_id == &"heat_vent":
			blast.append(ev)
	var after := r.heat_state()
	gut.p("vented %d heat, %d blast hit(s)" % [after["vent_heat"], blast.size()])
	assert_gt(int(after["vent_tick"]), -1, "the Vent button vented")
	assert_false(r.is_dashing(), "without a dash")
	assert_gt(blast.size(), 0, "the blast hit the enemy beside you")
	if not blast.is_empty():
		assert_eq(
			blast[0].amount,
			maxi(1, int(after["vent_heat"]) / 2),
			"damage scales with the heat vented"
		)
	assert_almost_eq(float(after["heat"]), 0.0, 0.3, "heat reset to 0")
	assert_eq(kit.hue(), kit.color, "vented: the blade is back to its own colour")
	assert_eq(meter.vent_text(), "", "no VENT prompt once vented")
	assert_lt(meter.fill(), 0.05, "the meter emptied")
	var fx: HeatVisuals = e.main.view.heat_fx
	assert_gt(fx.fx_count_of(&"ring"), 0, "the blast ring is drawn")
	assert_almost_eq(
		fx.ring_radius(), float(after["vent_radius"]), 1e-5, "at the sim's blast radius"
	)
