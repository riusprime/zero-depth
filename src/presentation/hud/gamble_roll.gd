class_name GambleRoll
extends Control
## The Fortune shrine's reward, rolled above the shrine (v0.11.0 F13, owner: the big centre notification goes). The
## sim decided the use at activation (Gamble); this replays it as frame-time dressing and decides nothing. A symbol
## appears over the shrine and cycles through the stats like a reel, slowing, then stops on the real result (a short
## pop and a hold). A win then flies, shrinking, into that stat's row of the corner panel (GambleStatsPanel), which
## shows the new value only on arrival. A fail stops on a cracked symbol that shakes and fades over the shrine.
## Several uses at once each have their own symbol. Reduced motion: no cycling, no flight: the result shows, holds and
## fades, and the panel updates at once. The tree's pause stops it with everything else; no Timer.

enum Phase { SPIN, HOLD, FLY, FAIL, FADE }

const SPIN_S := 0.9
const HOLD_S := 0.35
const FLY_S := 0.45
const FAIL_S := 0.6
const REDUCED_HOLD_S := 1.0
const REDUCED_FADE_S := 0.35
## Symbols the reel shows before it stops (the last steps are the slowest).
const STEPS := 18
const POP_S := 0.14
const SIZE := 56.0
const REF_H := 720.0
## Height over the shrine's foot the symbol floats at (m).
const ABOVE_M := 4.3

## Set by the HUD: the corner panel the symbols fly into.
var panel: GambleStatsPanel
## Where the shrine's symbol floats (sim position), set from the reader each sync.
var shrine := Vector2.ZERO
## Symbols that reached the panel, ever (tests).
var arrived := 0
## Where the last symbol arrived (it is freed on arrival; tests).
var last_center := Vector2.ZERO
var _rolls: Array[Roll] = []


func _init() -> void:
	name = "GambleRoll"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## A use landed: `stat` is the stat index won (-1 for a failed use), `ids` every stat's id in order.
func start(reader: WorldReader, stat: int) -> void:
	var r := Roll.new()
	r.won = stat >= 0
	r.stat = stat
	for s in reader.gamble_stat_count():
		r.reel.append(reader.gamble_stat_id(s))
	r.id = reader.gamble_stat_id(stat) if r.won else &""
	r.start = (reader.gamble_tick() + stat + 3) % maxi(1, r.reel.size())
	shrine = reader.gamble_pos()
	r.view = GambleIconView.new(&"", SIZE, true)
	r.view.size = Vector2(SIZE, SIZE)
	r.view.pivot_offset = Vector2(SIZE, SIZE) * 0.5
	add_child(r.view)
	if ViewPrefs.reduced_motion:
		r.phase = Phase.HOLD
		_show(r)
	else:
		r.view.set_stat(r.reel[r.start])
	if r.won and panel != null and not ViewPrefs.reduced_motion:  # reduced: the panel updates at once
		panel.hold(stat)
		r.held = true
	r.pos = _anchor()
	_place(r)
	_rolls.append(r)
	set_process(true)


## Drops everything (no shrine on this floor).
func clear() -> void:
	for r in _rolls:
		_release(r, false)
		r.view.queue_free()
	_rolls.clear()
	set_process(false)


## A win's symbol is still on its way to the panel.
func holding() -> bool:
	for r in _rolls:
		if r.held:
			return true
	return false


func count() -> int:
	return _rolls.size()


## Roll k's phase, symbol, screen centre and whether it is a win (tests).
func phase_of(k: int) -> int:
	return _rolls[k].phase


func shown_id(k: int) -> StringName:
	return _rolls[k].view.stat_id


func is_broken(k: int) -> bool:
	return _rolls[k].view.broken


func center_of(k: int) -> Vector2:
	return _rolls[k].view.global_position + Vector2(SIZE, SIZE) * 0.5


func center_of_last() -> Vector2:
	return last_center


func view_of(k: int) -> GambleIconView:
	return _rolls[k].view


func _process(delta: float) -> void:
	for r in _rolls.duplicate():
		_step(r, delta)
	if _rolls.is_empty():
		set_process(false)


func _step(r: Roll, delta: float) -> void:
	r.t += delta
	match r.phase:
		Phase.SPIN:
			var u := minf(1.0, r.t / SPIN_S)
			var eased := 1.0 - pow(1.0 - u, 2.2)  # fast, then slowing toward the stop
			var step := int(eased * STEPS)
			r.view.set_stat(r.reel[(r.start + step) % r.reel.size()])
			r.pos = _anchor()
			if r.t >= SPIN_S:
				r.t = 0.0
				r.phase = Phase.HOLD
				_show(r)
		Phase.HOLD:
			r.pos = _anchor()
			var hold := REDUCED_HOLD_S if ViewPrefs.reduced_motion else HOLD_S
			if r.t >= hold:
				r.t = 0.0
				if ViewPrefs.reduced_motion:
					r.phase = Phase.FADE
				elif r.won:
					r.phase = Phase.FLY
					r.from = r.pos
				else:
					r.phase = Phase.FAIL
		Phase.FLY:
			var u := minf(1.0, r.t / FLY_S)
			var e := u * u * (3.0 - 2.0 * u)
			var target := _target(r)
			r.pos = r.from.lerp(target, e) + Vector2(0.0, -48.0 * _k() * sin(PI * e))
			r.view.scale = Vector2.ONE * _k() * lerpf(1.0, 0.45, e)
			if u >= 1.0:
				_arrive(r)
				return
		Phase.FAIL:
			r.pos = _anchor()
			var u := minf(1.0, r.t / FAIL_S)
			r.view.modulate.a = 1.0 - u * u
			if r.t >= FAIL_S:
				_finish(r)
				return
		Phase.FADE:
			r.pos = _anchor()
			r.view.modulate.a = 1.0 - minf(1.0, r.t / REDUCED_FADE_S)
			if r.t >= REDUCED_FADE_S:
				_finish(r)
				return
	_place(r)


## The symbol stops on the result: a pop (a failed use: the cracked symbol).
func _show(r: Roll) -> void:
	if r.won:
		r.view.set_stat(r.id)
	else:
		r.view.set_broken(true)


func _place(r: Roll) -> void:
	var k := _k()
	var sc := r.view.scale.x
	if r.phase == Phase.SPIN:
		sc = k
	elif r.phase == Phase.HOLD and not ViewPrefs.reduced_motion:
		var pop := minf(1.0, r.t / POP_S)
		sc = k * (1.0 + 0.35 * sin(PI * pop))
	elif r.phase != Phase.FLY:
		sc = k
	r.view.scale = Vector2.ONE * sc
	var shake := 0.0
	if r.phase == Phase.FAIL:
		shake = sin(r.t * 90.0) * 7.0 * k * (1.0 - r.t / FAIL_S)
	r.view.position = r.pos - Vector2(SIZE, SIZE) * 0.5 + Vector2(shake, 0.0)


func _arrive(r: Roll) -> void:
	last_center = r.view.position + Vector2(SIZE, SIZE) * 0.5
	arrived += 1
	_release(r, true)
	_finish(r)


func _release(r: Roll, glow: bool) -> void:
	if r.held and panel != null:
		r.held = false
		panel.release(r.stat, glow)


func _finish(r: Roll) -> void:
	_rolls.erase(r)
	r.view.queue_free()


func _k() -> float:
	var vp := get_viewport()
	return (vp.get_visible_rect().size.y / REF_H) if vp != null else 1.0


## The point over the shrine on the screen (follows the camera).
func _anchor() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	var cam := vp.get_camera_3d()
	if cam == null:
		return vp.get_visible_rect().size * Vector2(0.5, 0.3)
	return cam.unproject_position(SimPlane.to_3d(shrine) + Vector3(0.0, ABOVE_M, 0.0))


func _target(r: Roll) -> Vector2:
	if panel == null:
		return r.pos
	return panel.landing_point(r.stat)


class Roll:
	extends RefCounted
	var stat := -1
	var id := &""
	var won := true
	var phase: int = Phase.SPIN
	var t := 0.0
	var reel: Array[StringName] = []
	var start := 0
	var from := Vector2.ZERO
	var pos := Vector2.ZERO
	var held := false
	var view: GambleIconView
