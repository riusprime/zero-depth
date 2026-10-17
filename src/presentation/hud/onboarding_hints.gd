class_name OnboardingHints
extends Control
## v0.7.5 SM (owner N8; ROADMAP §5 "Onboarding hints"): the first-run hints. Each shows once (HintStore, the
## profile's `hints` section), on a small Ember-stone slab with a cold top line at the top centre of the screen:
## - at a first run's start: move and aim, then attack, then dash (each closes when you do it);
## - when the heat first reads Hot: vent; when the first card pick opens: the wand reads left to right;
## - after the first card joins the wand: the Build page (pause → Build); the first trigger card in the wand;
## - the first shop, the first open portal; at the second floor's start: the Codex (pause → Codex).
## Non-blocking: it never takes the mouse, the focus or an input (it only listens), and the game never waits for it.
## A hint closes when its action is done or its panel closes (after MIN_S at least), else after MAX_S; Options
## "Show hints: Off" hides it at once. The keys it names are the live bindings of the device used last (keyboard
## and mouse, or a pad), so a remap or a device switch shows at once. Its clock is the screen's (a look, never an
## outcome: EI-03); it reads WorldReader only (EI-07). Main owns it on the UI layer, so it outlives a floor.

signal shown(id: StringName)

const W := 720.0
const PAD := Vector2(20, 12)
const TOP := 150.0
## While a centre panel is open (a pick, the Swap, the shop, an event) the slab sits low instead, its bottom this far
## above the screen's bottom edge: under the panel's key line, over the heat meter, so it never covers the panel's
## title or its cards.
const LOW_BOTTOM := 82.0
## A hint stays up at least this long, so a quick player still reads it, and closes on its own after MAX_S.
const MIN_S := 2.0
const MAX_S := 9.0
const FADE_S := 0.25
## The move hint closes once the hero walked this far (m).
const MOVE_DONE_M := 1.5
## Hints about a moment (a panel, a portal): they come before the first-run steps and close with their moment.
const CONTEXT: Array[StringName] = [&"pick", &"shop", &"portal", &"vent"]
## The input that closes a hint (the attack's is the build's: `primary` swings, `shoot` fires).
const DONE_ACTIONS := {&"dash": &"dash", &"vent": &"vent"}
## The key each hint names (besides move's four keys and attack's, which is the build's).
const KEYED := {&"dash": &"dash", &"vent": &"vent", &"build": &"pause", &"codex": &"pause"}

var store: HintStore
var header := HudStyle.label(13, true)
var line := HudStyle.label(20, true)
## The device used last (InputRebind.KBM or PAD): the keys named follow it.
var device := InputRebind.KBM
var _current := &""
var _queue: Array[StringName] = []
var _t := 0.0
var _closing := false
var _covered := false
var _attack_action := &"primary"
var _move_from := Vector2.INF
## What the last observed tick said (the context hints close when their moment ends).
var _moment := {}
var _was_choosing := false
## A floor is running (between begin_floor and end_floor): only then does a hint show and its clock run.
var _live := false
## A centre panel is open (the last observed tick): the slab sits low.
var _panel_open := false
## v0.8.0 N11 (owner O69): the hero is still arriving (the last observed tick): no hint shows and its clock waits.
var _landing := false


func _init() -> void:
	name = "OnboardingHints"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	custom_minimum_size = Vector2(W, 0)
	offset_left = -W * 0.5
	offset_right = W * 0.5
	offset_top = TOP
	visible = false
	var col := VBoxContainer.new()
	col.name = "Col"
	col.position = PAD
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	header.name = "Header"
	header.add_theme_color_override("font_color", HudStyle.ACCENT)
	line.name = "Line"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l: Label in [header, line]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(W - PAD.x * 2.0, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)


func setup(p_store: HintStore) -> void:
	store = p_store


## A floor started (its reader is live): a first run's opening steps on floor 1, the Codex on a later floor.
func begin_floor(floor_index: int, reader: WorldReader) -> void:
	_attack_action = &"shoot" if reader.wand().get("weapon", &"blade") == &"gun" else &"primary"
	_move_from = reader.player_pos()
	_was_choosing = false
	_moment = {}
	_live = true
	_landing = reader.arriving()  # v0.8.0 N11
	if floor_index <= 1:
		for id: StringName in [&"move", &"attack", &"dash"]:
			_enqueue(id)
	else:
		_enqueue(&"codex")


## The floor's nodes are going: a hint about this floor's moment goes too; the first-run steps carry over.
func end_floor() -> void:
	_live = false
	_panel_open = false
	_moment = {}
	if _current in CONTEXT:
		_close_now()
	_queue = _queue.filter(func(id: StringName) -> bool: return not id in CONTEXT)
	_refresh_visible()


## Reads one tick: queues the hints whose moment has come.
func observe(reader: WorldReader) -> void:
	if _landing != reader.arriving():  # v0.8.0 N11: the hints wait for the hero to land
		_landing = reader.arriving()
		_refresh_visible()
	if store == null or not store.enabled():
		return
	var choosing := reader.choosing() and not reader.swapping()
	_panel_open = reader.choosing() or reader.shop_open() or reader.event_open()
	_moment = {
		&"pick": choosing,
		&"shop": reader.shop_open(),
		&"portal": reader.portal_active(),
		# the heat read builds a dictionary: only while the vent hint is due or showing
		&"vent": (store.due(&"vent") or _current == &"vent") and _vent_ready(reader),
	}
	for id: StringName in CONTEXT:
		if _moment[id]:
			_enqueue(id)
	if _current == &"move" and _move_from != Vector2.INF:
		if reader.player_pos().distance_to(_move_from) >= MOVE_DONE_M:
			_done()
	if _was_choosing and not choosing:  # a pick just closed: the wand may hold its first card or a trigger
		if store.due(&"build") and not reader.build()["slots"].is_empty():
			_enqueue(&"build")
		if store.due(&"trigger") and not (reader.wand()["cuts"] as PackedInt32Array).is_empty():
			_enqueue(&"trigger")
	_was_choosing = choosing


static func _vent_ready(reader: WorldReader) -> bool:
	var h := reader.heat_state()
	return not h.is_empty() and bool(h.get("vent_ready", false))


## A full-screen menu (pause, Options, Build page, Codex) is over the game: the hint hides and its clock stops. A
## hint that pointed at the pause menu (Build, Codex) has done its job.
func set_covered(on: bool) -> void:
	_covered = on
	if on and (_current == &"build" or _current == &"codex"):
		_close_now()
	_refresh_visible()


func _enqueue(id: StringName) -> void:
	if store == null or not store.due(id) or id == _current or _queue.has(id):
		return
	if id in CONTEXT:
		if _current != &"" and not _current in CONTEXT:  # a moment comes first; the step waits its turn again
			_queue.push_front(_current)
			_current = &""
		_queue.push_front(id)
	else:
		_queue.append(id)
	if _current == &"":
		_next()


func _next() -> void:
	_current = &""
	_closing = false
	_t = 0.0
	while not _queue.is_empty():
		var id: StringName = _queue.pop_front()
		if id in CONTEXT and not _moment.get(id, false):
			continue  # its moment passed while it waited: it shows the next time
		_current = id
		break
	if _current == &"":
		_refresh_visible()
		return
	store.mark(_current)
	_word()
	modulate.a = 0.0
	_refresh_visible()
	shown.emit(_current)


func _refresh_visible() -> void:
	visible = (
		_current != &""
		and _live
		and not _covered
		and not _landing
		and store != null
		and store.enabled()
	)


## The hint's action was done: it fades out (once it has been up MIN_S).
func _done() -> void:
	if _current != &"":
		_closing = true


func _close_now() -> void:
	_current = &""
	_next()


func _process(delta: float) -> void:
	if _current == &"":
		return
	if store == null or not store.enabled():  # Options "Show hints: Off": gone at once
		_queue.clear()
		_current = &""
		_refresh_visible()
		return
	if _covered or not _live or _landing:
		return
	_t += delta
	if _current in CONTEXT and not _moment.get(_current, false) and _t >= MIN_S:
		_closing = true  # its panel closed, its portal was taken
	if _closing and _t >= MIN_S:
		_t = maxf(_t, MAX_S - FADE_S)
	if _t >= MAX_S:
		_next()
		return
	var left := MAX_S - _t
	modulate.a = minf(1.0, _t / FADE_S) if _t < FADE_S else minf(1.0, left / FADE_S)
	_place()


## Top centre, or low while a centre panel is open (LOW_BOTTOM).
func _place() -> void:
	var h := size.y  # read first: moving one offset resizes the box
	var y := TOP
	if _panel_open:
		y = get_viewport_rect().size.y - LOW_BOTTOM - h
	offset_top = y
	offset_bottom = y + h


## The slab sits low (a centre panel is open).
func is_low() -> bool:
	return _panel_open


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_set_device(InputRebind.KBM)
	elif (
		event is InputEventJoypadButton
		or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3)
	):
		_set_device(InputRebind.PAD)
	if _current == &"" or _covered or _landing:
		return
	var action: StringName = (
		_attack_action if _current == &"attack" else DONE_ACTIONS.get(_current, &"")
	)
	if action != &"" and event.is_action_pressed(action):
		_done()


func _set_device(d: StringName) -> void:
	if d != device:
		device = d
		_word()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_word()


## The hint's words in the language now, with the keys of the device used last.
func _word() -> void:
	if _current == &"":
		return
	header.text = tr("HINT_HEADER")
	line.text = hint_text(_current)
	_fit.call_deferred()


func hint_text(id: StringName) -> String:
	var line_key := "HINT_" + String(id).to_upper()  # HINT_MOVE, HINT_ATTACK, HINT_PICK …
	if id == &"move":
		var pad := device == InputRebind.PAD
		var keys := PackedStringArray()
		for a: StringName in [&"move_up", &"move_left", &"move_down", &"move_right"]:
			keys.append(key(a, InputRebind.KBM, false))
		var move := tr("HINT_PAD_LEFT_STICK") if pad else " ".join(keys)
		var aim := tr("HINT_PAD_RIGHT_STICK" if pad else "HINT_MOUSE")
		return tr(line_key) % ["[%s]" % move, aim]
	var action: StringName = _attack_action if id == &"attack" else KEYED.get(id, &"")
	return tr(line_key) % key(action, device) if action != &"" else tr(line_key)


## `action`'s bound key or button on `dev` (the keyboard's when the pad has none), short ("RT", "LMB", "Space"),
## in brackets unless `brackets` is false.
static func key(action: StringName, dev: StringName, brackets: bool = true) -> String:
	var spec := InputRebind.binding(action, dev)
	if spec.is_empty():
		spec = InputRebind.binding(action, InputRebind.KBM)
	var t := InputLabels.short_text(spec)
	return "[%s]" % t if brackets else t


func _fit() -> void:
	var col := get_node("Col") as Control
	col.reset_size()
	size = Vector2(W, col.get_combined_minimum_size().y + PAD.y * 2.0)
	queue_redraw()


func _draw() -> void:
	HudStyle.draw_plate(self, Rect2(Vector2.ZERO, size), false)
	draw_rect(
		Rect2(Vector2(size.x * 0.3, 1.0), Vector2(size.x * 0.4, 2.0)), Color(HudStyle.ACCENT, 0.85)
	)


# --- Reads (tests) ------------------------------------------------------------------------------------------
## The hint shown now (&"" when none).
func current_id() -> StringName:
	return _current


func queued_ids() -> Array[StringName]:
	return _queue.duplicate()


func showing() -> bool:
	return _current != &"" and visible


func text() -> String:
	return line.text
