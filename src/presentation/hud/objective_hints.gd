class_name ObjectiveHints
extends Control
## v0.11.0 O2 (owner L4, Q12 a): the boss hint. For each objective marker (WorldReader.objectives, set by boss code:
## World.objectives) whose reason the gate lets show (Main: MechanicHints, the first 2 runs that meet it, and Options
## "Boss hints"), it draws, in the HUD's accent:
## - off screen: an arrow at the screen's edge, on the line from the screen's centre to the target, pointing at it;
## - on screen: a soft ping ring on the target, widening and fading every PING_S;
## and the reason's short line (LABELS, tr()) beside it. Reduced motion: the ring holds still and the arrow doesn't
## bob. Never takes the mouse or an input; reads only (EI-07); its clock is the screen's, a look only (EI-03).
## Hud owns it (synced each frame with the HUD).

## Each reason's line (a locale key). A reason without one shows its arrow or ping alone.
const LABELS := {
	WorldReader.OBJECTIVE_SHADE_LANTERN: "HINT_SHADE_LANTERN",
	WorldReader.OBJECTIVE_TWINS_ACTIVE: "HINT_TWINS_ACTIVE",
}
## A target this close to the screen's edge (px at 1080p) counts as off screen: the arrow sits this far in.
const EDGE_PX := 64.0
const REF_H := 1080.0
const ARROW_PX := 22.0
const RING_PX := 34.0
const PING_S := 1.2
const BOB_PX := 6.0
const FONT_PX := 18
const ARROW := &"arrow"
const PING := &"ping"
## v0.11.0 F5: reasons marked on screen by a small bobbing arrow above the target, pointing down (no ring, no text).
const DOWN_ARROW: Array[StringName] = [WorldReader.OBJECTIVE_GATEKEEPER_PILLAR]
const DOWN_GAP_PX := 54.0

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


## The reason's line as shown (tr()), "" when it has none.
func line(reason: StringName) -> String:
	return tr(LABELS[reason]) if LABELS.has(reason) else ""


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
	var f := HudStyle.font(true)
	var fs := roundi(FONT_PX * k)
	for m in _marks:
		var at: Vector2 = m["at"]
		var label_at := at
		if m["mode"] == PING and m["reason"] in DOWN_ARROW:
			var bob_y := (
				0.0 if HudStyle.reduced_motion else BOB_PX * k * (0.5 + 0.5 * sin(_t * TAU))
			)
			var tip_d := at + Vector2(0, -DOWN_GAP_PX * k + bob_y)
			var back_d := tip_d + Vector2.UP * ARROW_PX * k
			var side_d := Vector2.RIGHT * ARROW_PX * k * 0.6
			draw_colored_polygon(
				PackedVector2Array(
					[
						tip_d,
						back_d + side_d,
						back_d + Vector2.UP * ARROW_PX * k * 0.3,
						back_d - side_d
					]
				),
				Color(c, 0.92)
			)
			continue
		if m["mode"] == PING:
			var phase := 0.0 if HudStyle.reduced_motion else fmod(_t, PING_S) / PING_S
			var r := RING_PX * k * (0.6 + 0.6 * phase)
			var a := 0.85 if HudStyle.reduced_motion else 0.9 * (1.0 - phase)
			draw_arc(at, r, 0.0, TAU, 48, Color(c, a), 3.0 * k, true)
			draw_arc(at, RING_PX * k * 0.45, 0.0, TAU, 32, Color(c, 0.55), 2.0 * k, true)
			label_at = at + Vector2(0, -RING_PX * k * 1.3)
		else:
			var dir: Vector2 = m["dir"]
			var bob := 0.0 if HudStyle.reduced_motion else BOB_PX * k * (0.5 + 0.5 * sin(_t * TAU))
			var tip := at + dir * bob
			var side := dir.orthogonal() * ARROW_PX * k * 0.6
			var back := tip - dir * ARROW_PX * k
			draw_colored_polygon(
				PackedVector2Array(
					[tip, back + side, back - dir * ARROW_PX * k * -0.3, back - side]
				),
				Color(c, 0.92)
			)
			label_at = at - dir * ARROW_PX * k * 2.2
		var text := line(m["reason"])
		if text == "":
			continue
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var scr := _screen().size
		var p := Vector2(clampf(label_at.x - w * 0.5, 8.0, scr.x - w - 8.0), label_at.y)
		p.y = clampf(p.y, fs + 8.0, scr.y - 8.0)
		draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
		draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, HudStyle.text_color())
