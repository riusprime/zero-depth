extends GutTest
## The HUD costs the frame nothing while it does not change: a HUD synced every frame from a world that does not
## change redraws none of its parts; each part redraws when what it shows changes; the DPS meter writes its lines at
## most once a frame; and HudStill draws a still part from its texture and goes back to drawing it directly the frame
## it changes.

const QUIET_FRAMES := 60

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()
	InputDefaults.apply()


func after_each() -> void:
	ViewPrefs.reduced_motion = false
	HudStyle.reduced_motion = false


## A gun world with its abilities, Overclock heat (Hot) and three items: most of the HUD's run parts show.
func _world() -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	var w := World.new(3, t)
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	Heat.enable(w, ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock")))
	w.heat.milli = 30 * HeatTable.MILLI
	w.heat.idle = 0
	Heat.advance(w)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	for k in 3:
		w.add_item(k)
	return w


## Counts each Hud child's redraws (any item of its subtree) while connected.
class Counter:
	extends RefCounted
	var by_part := {}

	func watch(hud: Hud) -> void:
		for part in hud.get_children():
			if not part is CanvasItem:
				continue
			by_part[String(part.name)] = 0
			var stack: Array[Node] = [part]
			while not stack.is_empty():
				var n: Node = stack.pop_back()
				stack.append_array(n.get_children())
				if n is CanvasItem:
					(n as CanvasItem).draw.connect(func() -> void: _hit(String(part.name)))

	func _hit(key: String) -> void:
		by_part[key] = int(by_part[key]) + 1

	func total() -> int:
		var n := 0
		for k: String in by_part:
			n += int(by_part[k])
		return n

	func busy() -> Dictionary:
		var out := {}
		for k: String in by_part:
			if int(by_part[k]) > 0:
				out[k] = by_part[k]
		return out


func _hud() -> Hud:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.size = Vector2(1920, 1080)
	return hud


func test_a_hud_synced_from_a_world_that_does_not_change_redraws_nothing() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var hud := _hud()
	for k in 10:  # settle: the first syncs draw everything once
		hud.sync(r)
		await wait_process_frames(1)
	var c := Counter.new()
	c.watch(hud)
	for k in QUIET_FRAMES:
		hud.sync(r)
		await wait_process_frames(1)
	assert_true(hud.ability_squares.visible, "the ability squares show")
	assert_true(hud.heat_meter.visible, "the heat meter shows")
	assert_true(hud.build_hud.visible, "the build row shows")
	assert_eq(c.total(), 0, "redraws over %d still frames, by part: %s" % [QUIET_FRAMES, c.busy()])


func test_each_part_redraws_when_what_it_shows_changes() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var hud := _hud()
	for k in 10:
		hud.sync(r)
		await wait_process_frames(1)
	var c := Counter.new()
	c.watch(hud)
	w.actors.hp[0] -= 10
	w.dash_cooldown_left = r.dash_cooldown_total()
	w.heat.milli += 20 * HeatTable.MILLI
	Heat.advance(w)
	hud.sync(r)
	await wait_process_frames(1)
	assert_gt(int(c.by_part["HpCorner"]), 0, "the HP bar redraws when the HP falls")
	assert_gt(
		int(c.by_part["AbilitySquares"]), 0, "the squares redraw when the dash starts cooling"
	)
	assert_gt(int(c.by_part["HeatMeter"]), 0, "the heat meter redraws when the heat rises")
	var squares := int(c.by_part["AbilitySquares"])
	w.dash_cooldown_left -= 1
	hud.sync(r)
	await wait_process_frames(1)
	assert_gt(
		int(c.by_part["AbilitySquares"]),
		squares,
		"a cooling square redraws each tick (its wedge moves)"
	)


func test_the_hp_bar_redraws_only_when_its_fraction_moves() -> void:
	var bar := HudBar.new()
	add_child_autofree(bar)
	bar.size = Vector2(345, 12)
	bar.set_fraction(1.0, true)
	await wait_process_frames(2)
	var n := [0]
	bar.draw.connect(func() -> void: n[0] += 1)
	for k in 10:
		bar.set_fraction(1.0)
		await wait_process_frames(1)
	assert_eq(n[0], 0, "the same fraction every tick draws nothing")
	bar.set_fraction(0.5)
	await wait_process_frames(1)
	assert_gt(n[0], 0, "a hit redraws")
	bar.warn = true
	var before: int = n[0]
	await wait_process_frames(3)
	assert_gt(n[0], before, "the low-HP pulse animates")


func test_the_danger_meter_redraws_when_its_pixel_or_colour_moves() -> void:
	var m := DangerMeter.new()
	add_child_autofree(m)
	m.set_danger(2, 0.5)
	await wait_process_frames(2)
	var n := [0]
	m.draw.connect(func() -> void: n[0] += 1)
	m.set_danger(2, 0.5001)
	await wait_process_frames(2)
	assert_eq(
		n[0], 0, "a progress step under a pixel and under an 8-bit step of the colour draws nothing"
	)
	m.set_danger(3, 0.0)
	await wait_process_frames(1)
	assert_gt(n[0], 0, "a new tier redraws")
	m.set_danger(DangerMeter.FULL_TIER, 0.0)
	await wait_process_frames(1)
	var before: int = n[0]
	await wait_process_frames(3)
	assert_gt(n[0], before, "full, the bar blinks")
	HudStyle.reduced_motion = true
	await wait_process_frames(2)
	before = n[0]
	await wait_process_frames(3)
	assert_eq(n[0], before, "under reduced motion it holds steady and draws nothing more")


func test_the_dps_meter_writes_its_lines_at_most_once_a_frame() -> void:
	var w := World.new(9, PlayerTable.starting_values())
	var r := WorldReader.new(w)
	var meter := DpsMeter.new()
	add_child_autofree(meter)
	meter.sync(r)
	await wait_process_frames(1)
	var before := meter.writes
	for k in 4:  # four ticks in one frame
		w.tick += 1
		meter.sync(r)
	await wait_process_frames(1)
	assert_eq(meter.writes - before, 1, "four ticks in a frame: the lines written once")
	before = meter.writes
	meter.sync(r)  # the same tick again (the sim paused)
	await wait_process_frames(2)
	assert_eq(meter.writes - before, 0, "nothing new: nothing written")


## Frames as the game runs them: the redraws, then HudStill's step (headless, the renderer's pre-draw signal does not
## come; a second step in a frame only freezes sooner).
func _frames(still: HudStill, n: int) -> void:
	for k in n:
		await wait_process_frames(1)
		still.step()


func test_a_still_part_is_drawn_from_its_texture_until_it_changes() -> void:
	var host := Control.new()
	add_child_autofree(host)
	var part := ColorRect.new()
	part.color = Color(0.3, 0.6, 0.9, 0.5)
	part.position = Vector2(40, 40)
	part.size = Vector2(80, 30)
	host.add_child(part)
	var still := HudStill.new()
	host.add_child(still)
	still.add_part(part)
	var bit := 1 << HudStill.FIRST_BIT
	assert_true(
		host.get_child(part.get_index() + 1) is HudStill.Proxy, "the proxy right after the part"
	)
	assert_eq(part.visibility_layer, bit, "the part draws on its own layer")
	assert_ne(host.visibility_layer & bit, 0, "its parent shares the layer")
	await _frames(still, 4)
	assert_true(still.frozen(part), "still for two frames: drawn from its texture")
	assert_eq(still.renders(part), 1, "rendered once")
	assert_eq(get_viewport().canvas_cull_mask & bit, 0, "the screen leaves the part's layer out")
	part.color = Color.RED  # a redraw
	await _frames(still, 1)
	assert_false(still.frozen(part), "the frame it changes, drawn directly")
	assert_ne(get_viewport().canvas_cull_mask & bit, 0, "the screen draws the layer again")
	await _frames(still, HudStill.MAX_WAIT + 2)
	assert_true(still.frozen(part), "still again: from the texture")
	assert_eq(still.renders(part), 2, "rendered again, once")
	part.modulate = Color(1, 1, 1, 0.5)  # no redraw, no signal: the tint check sees it
	await _frames(still, 1)
	assert_false(still.frozen(part), "a tint change is a change")
	var child := ColorRect.new()
	part.add_child(child)
	assert_eq(child.visibility_layer, bit, "a child added later joins the part's layer")
	await _frames(still, HudStill.MAX_WAIT + 2)
	assert_true(still.frozen(part))
	child.position = Vector2(5, 5)
	await _frames(still, 1)
	assert_false(still.frozen(part), "a child that moves is a change")
	still.set_enabled(false)
	await _frames(still, 4)
	assert_false(still.frozen(part), "switched off: always drawn directly")
	assert_ne(get_viewport().canvas_cull_mask & bit, 0)


func test_a_part_that_keeps_changing_waits_longer_before_its_next_render() -> void:
	var host := Control.new()
	add_child_autofree(host)
	var part := ColorRect.new()
	part.size = Vector2(40, 40)
	host.add_child(part)
	var still := HudStill.new()
	host.add_child(still)
	still.add_part(part)
	await _frames(still, 3)
	assert_eq(still.renders(part), 1, "the first still frame renders")
	for k in 4:  # changes a few frames after each render: wasted renders
		part.color = Color(0.1 * k, 0.2, 0.3)
		await _frames(still, 3)
	var wasted := still.renders(part)
	assert_lt(wasted, 5, "the wait grows: fewer renders than changes (%d)" % wasted)
	await _frames(still, HudStill.MAX_WAIT + HudStill.PAYBACK + 2)
	assert_true(still.frozen(part), "a long still spell freezes it")
	part.color = Color.WHITE
	await _frames(still, 3)
	assert_true(
		still.renders(part) > wasted + 1, "after a still spell the wait is back to one frame"
	)
