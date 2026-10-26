class_name GameCursor
extends Node
## v0.9.5 MC2 (owner L16, his cursor sheet): the game's own mouse cursor, a faceted stone arrowhead with a red gem.
## Seven states, cut from his sheet by scripts/art/cut_cursor_sheet.py into assets/ui/cursors/<state>_<size>.png:
## DEFAULT, HOVER (an enabled button), CLICK (0.12 s after a left press in a menu), DISABLED (a disabled button),
## AIM (always in a run), INTERACT (the hub's InteractPrompt is shown) and INVALID (a control with meta
## `cursor_invalid`, for example the padlocked Blade or a shop card you can't afford).
## The textures load once per size class (32 px below 900 px of window height, 48, 64 from 1440). The hardware cursor
## is set only when the state or the size changes; a frame costs one hovered-control lookup.
## When a pad was the last device used, the cursor is hidden during a run and comes back on mouse motion.

enum State { DEFAULT, HOVER, CLICK, DISABLED, AIM, INTERACT, INVALID }

const DIR := "res://assets/ui/cursors/"
const NAMES := ["default", "hover", "click", "disabled", "aim", "interact", "invalid"]
## The hotspot of each state as a fraction of the size (the same numbers as hotspots.json, which a test compares).
const HOTSPOTS := [
	Vector2(0.17532467532467533, 0.07792207792207792),
	Vector2(0.17532467532467533, 0.07792207792207792),
	Vector2(0.17532467532467533, 0.07792207792207792),
	Vector2(0.17532467532467533, 0.07792207792207792),
	Vector2(0.5, 0.5),
	Vector2(0.17532467532467533, 0.07792207792207792),
	Vector2(0.17532467532467533, 0.07792207792207792),
]
const SMALL_BELOW := 900
const TALL_HEIGHT := 1440
const CLICK_S := 0.12
const META_INVALID := &"cursor_invalid"
const META_HOVER := &"cursor_hover"
const ANCESTORS := 6

## Whether the game is in a run right now. The default asks the parent (Main): a driver that is not paused (a menu,
## the pause and the dev panel pause it) and no end panel. Tests set their own.
var in_run: Callable = _parent_in_run
## The control under the mouse (null: none). Tests set their own.
var hover_probe: Callable = _viewport_hover
## Whether an InteractPrompt is shown. Tests set their own.
var prompt_probe: Callable = _any_prompt
## Sets the hardware cursor: (texture, hotspot). Tests count the calls.
var cursor_setter: Callable = _set_hardware
var pad_active := false

var _size := 0
var _textures: Array[Texture2D] = []
var _context := -1  # 0 menu, 1 run, -1 none yet
var _state := -1
var _click_left := 0.0


func _init() -> void:
	name = "GameCursor"
	pad_active = not Input.get_connected_joypads().is_empty()


func _ready() -> void:
	setup(get_window().size.y)
	get_window().size_changed.connect(func() -> void: setup(get_window().size.y))


func _input(event: InputEvent) -> void:
	var was := pad_active
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pad_active = false
	elif (
		event is InputEventJoypadButton
		or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3)
	):
		pad_active = true
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and _context == 0
	):
		_click_left = CLICK_S
	if pad_active != was and _context >= 0:
		_apply_visibility()


func _process(delta: float) -> void:
	_click_left = maxf(_click_left - delta, 0.0)
	var run := in_run.is_valid() and bool(in_run.call())
	if int(run) != _context:
		_context = int(run)
		_apply_visibility()
	_set_state(wanted(run))


## The size in px for a window of this height.
static func size_for(height: int) -> int:
	if height < SMALL_BELOW:
		return 32
	return 64 if height >= TALL_HEIGHT else 48


## The hotspot in px of a state at a size.
static func hotspot(state: int, size: int) -> Vector2i:
	var f: Vector2 = HOTSPOTS[state]
	return Vector2i(roundi(f.x * size), roundi(f.y * size))


## The state a cursor over `hovered` shows, outside a run.
static func state_over(hovered: Control, prompt: bool) -> int:
	var h := hovered
	for i in ANCESTORS:
		if h == null:
			break
		if bool(h.get_meta(META_INVALID, false)):
			return State.INVALID
		h = h.get_parent() as Control
	if hovered != null:
		if hovered is BaseButton:
			return State.DISABLED if (hovered as BaseButton).disabled else State.HOVER
		if (
			hovered.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
			or bool(hovered.get_meta(META_HOVER, false))
		):
			return State.HOVER
	return State.INTERACT if prompt else State.DEFAULT


## The state for this frame.
func wanted(run: bool) -> int:
	if run:
		return State.AIM
	if _click_left > 0.0:
		return State.CLICK
	var hovered := hover_probe.call() as Control if hover_probe.is_valid() else null
	return state_over(hovered, prompt_probe.is_valid() and bool(prompt_probe.call()))


## Loads the textures for a window of this height (again only when its size class changes).
func setup(height: int) -> void:
	var sz := size_for(height)
	if sz == _size:
		return
	_size = sz
	_textures.clear()
	for n: String in NAMES:
		_textures.append(load("%s%s_%d.png" % [DIR, n, sz]) as Texture2D)
	if _state >= 0:
		_issue(_state)
		_apply_visibility()


func current_size() -> int:
	return _size


func state() -> int:
	return _state


func texture(s: int) -> Texture2D:
	return _textures[s] if s < _textures.size() else null


func set_context(run: bool) -> void:
	if int(run) == _context:
		return
	_context = int(run)
	_set_state(wanted(run))
	_apply_visibility()


func _set_state(s: int) -> void:
	if s == _state:
		return
	_state = s
	_issue(s)


func _issue(s: int) -> void:
	if s < _textures.size() and _textures[s] != null and cursor_setter.is_valid():
		cursor_setter.call(_textures[s], Vector2(hotspot(s, _size)))


func _set_hardware(tex: Texture2D, hot: Vector2) -> void:
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hot)


func _viewport_hover() -> Control:
	return get_viewport().gui_get_hovered_control() if is_inside_tree() else null


func _any_prompt() -> bool:
	if not is_inside_tree():
		return false
	for p in get_tree().get_nodes_in_group(&"interact_prompt"):
		if p is InteractPrompt and (p as InteractPrompt).text() != "":
			return true
	return false


func _parent_in_run() -> bool:
	var m := get_parent()
	if m == null:
		return false
	var d: Object = m.get("driver")
	return d != null and not bool(d.get("paused")) and m.get("_end") == null


func _apply_visibility() -> void:
	var hide := _context == 1 and pad_active
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hide else Input.MOUSE_MODE_VISIBLE
