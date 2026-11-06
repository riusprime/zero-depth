extends GutTest
## v0.9.5 MC2: the owner's cursor sheet as seven states: textures per height class, hotspots from hotspots.json, the
## state picks (button, disabled, invalid meta, prompt, run, click) and no hardware call when the state is unchanged.

var _c: GameCursor
var _calls: Array = []
var _hover: Control = null
var _prompt := false
var _run := false


func before_each() -> void:
	_calls = []
	_hover = null
	_prompt = false
	_run = false
	_c = GameCursor.new()
	_c.cursor_setter = func(t: Texture2D, h: Vector2) -> void: _calls.append([t, h])
	_c.hover_probe = func() -> Control: return _hover
	_c.prompt_probe = func() -> bool: return _prompt
	_c.in_run = func() -> bool: return _run
	add_child_autofree(_c)
	_c.setup(1080)


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _frame(delta := 0.016) -> void:
	_c._process(delta)


func test_every_state_loads_at_each_height_class() -> void:
	for pair: Array in [[800, 32], [899, 32], [900, 48], [1080, 48], [1440, 64], [2160, 64]]:
		_c.setup(pair[0])
		assert_eq(_c.current_size(), pair[1], "size at %d" % pair[0])
		for s in GameCursor.NAMES.size():
			var t := _c.texture(s)
			assert_not_null(t, "%s at %d" % [GameCursor.NAMES[s], pair[0]])
			assert_eq(t.get_size(), Vector2(pair[1], pair[1]))


func test_hotspots_match_the_json() -> void:
	var f := FileAccess.open("res://assets/ui/cursors/hotspots.json", FileAccess.READ)
	var j: Dictionary = JSON.parse_string(f.get_as_text())
	for s in GameCursor.NAMES.size():
		var e: Dictionary = j[GameCursor.NAMES[s]]
		assert_almost_eq(GameCursor.HOTSPOTS[s].x, float(e["x"]), 0.0001, "x of %d" % s)
		assert_almost_eq(GameCursor.HOTSPOTS[s].y, float(e["y"]), 0.0001, "y of %d" % s)
	assert_eq(GameCursor.hotspot(GameCursor.State.AIM, 48), Vector2i(24, 24), "aim: the centre")
	var tip := GameCursor.hotspot(GameCursor.State.DEFAULT, 48)
	for s in [GameCursor.State.HOVER, GameCursor.State.CLICK, GameCursor.State.INTERACT]:
		assert_eq(GameCursor.hotspot(s, 48), tip, "the arrow tip does not jump")


func test_hotspot_pixel_is_inside_the_art() -> void:
	var img := _c.texture(GameCursor.State.DEFAULT).get_image()
	var h := GameCursor.hotspot(GameCursor.State.DEFAULT, 48)
	var hit := false
	for dy in range(0, 5):
		for dx in range(0, 5):
			hit = hit or img.get_pixel(h.x + dx, h.y + dy).a > 0.5
	assert_true(hit, "the arrow's body starts at its hotspot")
	assert_lt(img.get_pixel(46, 2).a, 0.05, "the far corner is transparent")


func test_menu_picks() -> void:
	_frame()
	assert_eq(_c.state(), GameCursor.State.DEFAULT)
	var b := Button.new()
	add_child_autofree(b)
	_hover = b
	_frame()
	assert_eq(_c.state(), GameCursor.State.HOVER, "an enabled button")
	b.disabled = true
	_frame()
	assert_eq(_c.state(), GameCursor.State.DISABLED, "a disabled button")
	b.disabled = false
	b.set_meta(GameCursor.META_INVALID, true)
	_frame()
	assert_eq(_c.state(), GameCursor.State.INVALID, "the invalid meta wins")
	var p := Control.new()
	var kid := Control.new()
	add_child_autofree(p)
	p.add_child(kid)
	p.set_meta(GameCursor.META_INVALID, true)
	_hover = kid
	_frame()
	assert_eq(_c.state(), GameCursor.State.INVALID, "the meta on a parent counts")
	p.set_meta(GameCursor.META_INVALID, false)
	var hand := Control.new()
	hand.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child_autofree(hand)
	_hover = hand
	_frame()
	assert_eq(_c.state(), GameCursor.State.HOVER, "a pointing-hand control")
	_hover = null
	_frame()
	assert_eq(_c.state(), GameCursor.State.DEFAULT)


func test_hub_prompt_is_interact_and_run_is_aim() -> void:
	_prompt = true
	_frame()
	assert_eq(_c.state(), GameCursor.State.INTERACT)
	_prompt = false
	_run = true
	_frame()
	assert_eq(_c.state(), GameCursor.State.AIM)
	var b := Button.new()
	add_child_autofree(b)
	_hover = b
	_prompt = true
	_frame()
	assert_eq(_c.state(), GameCursor.State.AIM, "a run is always aim")


func test_click_lasts_a_moment() -> void:
	_frame()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	_c._input(ev)
	_frame(0.01)
	assert_eq(_c.state(), GameCursor.State.CLICK)
	_frame(0.1)
	assert_eq(_c.state(), GameCursor.State.CLICK, "0.11 s in")
	_frame(0.03)
	assert_eq(_c.state(), GameCursor.State.DEFAULT, "back after 0.12 s")


func test_hardware_cursor_is_set_only_on_change() -> void:
	_frame()
	var n := _calls.size()
	assert_eq(n, 1, "the first state")
	for i in 30:
		_frame()
	assert_eq(_calls.size(), n, "no call while the state holds")
	_run = true
	_frame()
	_frame()
	assert_eq(_calls.size(), n + 1, "one call for the change")
	assert_same(_calls[n][0], _c.texture(GameCursor.State.AIM))
	assert_eq(_calls[n][1], Vector2(GameCursor.hotspot(GameCursor.State.AIM, 48)))
	_c.setup(1080)
	assert_eq(_calls.size(), n + 1, "the same size class issues nothing")
	_c.setup(1440)
	assert_eq(_calls.size(), n + 2, "a new size class re-issues once")


func test_textures_load_once_per_class() -> void:
	var t := _c.texture(GameCursor.State.HOVER)
	_c.setup(1000)
	_c.setup(1080)
	assert_same(_c.texture(GameCursor.State.HOVER), t)
