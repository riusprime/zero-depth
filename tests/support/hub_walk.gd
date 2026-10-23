class_name HubWalk
extends RefCounted
## v0.9.0 HB (owner Q27): drives the hub the way a player does (E2e: Input.parse_input_event only; reads are fine):
## Play from the main menu, the left stick to a station (the hub's plan: the screen's up is its north), E to use it.

var e: E2e


func _init(p_e: E2e) -> void:
	e = p_e


## Enter on the main menu's Play (focused at boot without a save): the hub. True when it runs.
func enter() -> bool:
	await e.tap(KEY_ENTER)
	await e.frames(2)
	return e.main.hub != null


## Walks the hero until it stands at station `id` (HubSession.at; the machine is &"portal"), at most `limit` frames,
## the stick let go after. Steers round the machine's dais. True when it stands there.
func walk_to(id: StringName, limit: int = 900) -> bool:
	var hub := e.main.hub
	if hub == null:
		return false
	var goal := Vector2.ZERO
	if id != HubLayout.MACHINE:
		goal = hub.layout.station(id).at
	var ok := false
	for k in limit:
		if e.main.hub == null:
			break
		if hub.at == id:
			ok = true
			break
		var p := HubLayout.to_plan(hub.driver.reader.player_pos())
		var to := goal - p
		# Round the machine: aim beside it while the straight line would cut across its dais.
		if (
			id != HubLayout.MACHINE
			and p.length() < 4.5
			and to.normalized().dot(-p.normalized()) > 0.5
		):
			to = Vector2(signf(goal.x) if goal.x != 0.0 else 1.0, 0.0) * 4.5 - p
		var d := to.normalized()
		e.joy_axis(JOY_AXIS_LEFT_X, d.x)
		e.joy_axis(JOY_AXIS_LEFT_Y, -d.y)
		await e.frames(1)
	e.joy_axis(JOY_AXIS_LEFT_X, 0.0)
	e.joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	await e.frames(2)
	return ok


## Play, then the Portal Machine: its build screen opens (what Play alone did before the hub). True when it did.
func to_build_screen() -> bool:
	await enter()
	await use(HubLayout.MACHINE)
	return e.main.get_node_or_null("UI/BuildPicker") != null


## Walks to station `id` and presses interact (E): its panel opens over the hub. True when the hero got there.
func use(id: StringName) -> bool:
	var there := await walk_to(id)
	e.test.assert_true(there, "the hero walked to the %s" % id)
	await e.tap(KEY_E)
	await e.frames(2)
	return there
