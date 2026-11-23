class_name ObjectiveHints
extends Control
## The boss hint. For each objective marker (WorldReader.objectives, set by boss code:
## World.objectives) whose reason the gate lets show (Main: MechanicHints, the first 2 runs that meet it, and Options
## "Boss hints"), it draws, in the HUD's accent, an arrow and never a word (the owner: the player discovers a fight's
## mechanics while playing, from arrows and glows; text would give the discovery away):
## - off screen: an arrow at the screen's edge, on the line from the screen's centre to the target, pointing at it;
## - on screen: a small arrow bobbing above the target, pointing down at it.
## Reduced motion: the arrows don't bob. Never takes the mouse or an input; reads only (EI-07); its clock is the
## screen's, a look only (EI-03). Hud owns it (synced each frame with the HUD).

## A target this close to the screen's edge (px at 1080p) counts as off screen: the arrow sits this far in.
const EDGE_PX := 64.0
const REF_H := 1080.0
const ARROW_PX := 22.0
const BOB_PX := 6.0
const ARROW := &"arrow"
## On screen (the arrow above the target).
const PING := &"ping"
const DOWN_GAP_PX := 54.0
## A reason whose target carries something above it has its arrow that much higher
## (an hour orb's clock; the violet Warden's 2.2 m and her ward's dome; a boulder's 1.1 m).
const DOWN_GAPS := {
	MechanicHints.JUDGE_ORB: 132.0,
	MechanicHints.TWINS_WARD: 150.0,
	MechanicHints.SIEGE_BOULDER: 84.0,
}

## reason -> bool: whether that reason's hint shows (unset: none shows).
var gate: Callable
## Sim-plane point -> screen point (unset: the viewport's 3D camera). Tests set it.
var project: Callable
var _marks: Array[Dictionary] = []
var _t := 0.0


func _init() -> void:
	name = "ObjectiveHints"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Reads one frame: which hints show, and where (screen px).
func sync(reader: WorldReader) -> void:
	var was := _marks.size()
	_marks.clear()
	if reader != null and gate.is_valid():
		var screen := _screen()
		var inner := screen.grow(-EDGE_PX * _k(screen))
		for m: Dictionary in reader.objectives():
			if not gate.call(m["reason"]):
				continue
			var at := _to_screen(m["pos"], screen)
			var on := inner.has_point(at)
			var mark := {"reason": m["reason"], "mode": PING if on else ARROW, "target": at}
			mark["at"] = at if on else edge_point(inner, at)
			mark["dir"] = (at - inner.get_center()).normalized()
			_marks.append(mark)
	visible = not _marks.is_empty()
	if was > 0 or not _marks.is_empty():
		queue_redraw()


## The hints shown last sync: [{"reason", "mode" (ARROW or PING), "at" (where it's drawn), "target", "dir"}].
func shown() -> Array[Dictionary]:
	return _marks


func showing(reason: StringName, mode: StringName = &"") -> bool:
	for m in _marks:
		if m["reason"] == reason and (mode == &"" or m["mode"] == mode):
			return true
	return false


## Where the ray from `inner`'s centre to `target` leaves `inner` (the arrow's place).
static func edge_point(inner: Rect2, target: Vector2) -> Vector2:
	var c := inner.get_center()
	var d := target - c
	if d == Vector2.ZERO:
		return c
	var half := inner.size * 0.5
	var sx := INF if d.x == 0.0 else half.x / absf(d.x)
	var sy := INF if d.y == 0.0 else half.y / absf(d.y)
	return c + d * minf(minf(sx, sy), 1.0)


func _process(delta: float) -> void:
	if _marks.is_empty():
		return
	_t += delta
	queue_redraw()


func _screen() -> Rect2:
	var vp := get_viewport()
	return (
		Rect2(Vector2.ZERO, vp.get_visible_rect().size) if vp != null else Rect2(0, 0, 1920, 1080)
	)


func _k(screen: Rect2) -> float:
	return maxf(screen.size.y, 1.0) / REF_H


func _to_screen(sim: Vector2, screen: Rect2) -> Vector2:
	if project.is_valid():
		return project.call(sim)
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	if cam == null:
		return screen.get_center()
	return cam.unproject_position(SimPlane.to_3d(sim))


func _draw() -> void:
	var k := _k(_screen())
	var c := HudStyle.accent()
	var bob := 0.0 if HudStyle.reduced_motion else BOB_PX * k * (0.5 + 0.5 * sin(_t * TAU))
	for m in _marks:
		var at: Vector2 = m["at"]
		var dir: Vector2 = m["dir"]
		var tip := at + dir * bob
		if m["mode"] == PING:
			var gap: float = DOWN_GAPS.get(m["reason"], DOWN_GAP_PX)
			dir = Vector2.DOWN
			tip = at + Vector2(0, -gap * k + bob)
		var side := dir.orthogonal() * ARROW_PX * k * 0.6
		var back := tip - dir * ARROW_PX * k
		draw_colored_polygon(
			PackedVector2Array([tip, back + side, back + dir * ARROW_PX * k * 0.3, back - side]),
			Color(c, 0.92)
		)
