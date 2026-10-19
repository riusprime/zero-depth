class_name ScreenCull
extends RefCounted
## v0.8.0 HV (owner O89: "if something is not going to be loaded when far make sure it is far enough so it does not
## happen in the screen it should be for outside of the screen"): which points are far enough outside the iso
## camera's view that their frame-time animation and effects can be skipped. Presentation only (EI-07).
##
## The view is the camera's own rectangle, read from the camera (its position, its roll, its size with the flourish's
## zoom, the shake and kick offsets, the viewport's aspect), not a circle round the hero. A point's gap is how far
## outside that rectangle it lands on screen, in metres. An orthographic projection never lengthens a distance, so a
## gap of g screen metres means at least g metres on the ground too (along the screen's vertical the ground is
## stretched by 1 / sin(pitch), about 1.7x). A thing of radius r (its model, its flames, its light's reach) is skipped
## only when its gap is over r + MARGIN_M: it is at least MARGIN_M past the edge, wholly out of the picture. Things
## that keep a state (an enemy's animation) use HYSTERESIS_M on top while on, so they turn back on well before they
## could show, and a camera move of a few metres in a frame never brings one into view still.

## Starting values (owner rule: at least 6 m beyond the largest radius).
const MARGIN_M := 6.0
## The largest enemy model's reach from its actor point, height included (a boss, about 3.2 m tall: 4 m).
const AVATAR_RADIUS_M := 4.0
## Extra reach a thing that is on keeps before it turns off.
const HYSTERESIS_M := 2.0

## Whether the last refresh found an orthographic camera in the tree (off: everything shows).
var active := false
var _origin := Vector3.ZERO
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _half_w := 0.0
var _half_h := 0.0


## Reads the camera's view now (WorldViewRoot, once a tick before the views sync).
func refresh(cam: Camera3D) -> void:
	active = (
		cam != null and cam.is_inside_tree() and cam.projection == Camera3D.PROJECTION_ORTHOGONAL
	)
	if not active:
		return
	var vp := cam.get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	if cam.keep_aspect == Camera3D.KEEP_WIDTH:
		_half_w = cam.size * 0.5
		_half_h = _half_w / maxf(aspect, 0.01)
	else:
		_half_h = cam.size * 0.5
		_half_w = _half_h * aspect
	var t := cam.global_transform
	_right = t.basis.x.normalized()
	_up = t.basis.y.normalized()
	_origin = t.origin + _right * cam.h_offset + _up * cam.v_offset


## How far outside the view `p` (3D) is on screen, in metres (0 on the edge, negative inside).
func gap(p: Vector3) -> float:
	var d := p - _origin
	return maxf(absf(d.dot(_right)) - _half_w, absf(d.dot(_up)) - _half_h)


## Whether a thing of `radius` at `p` may show (or is within MARGIN_M of showing). True without a camera.
func shows(p: Vector3, radius: float) -> bool:
	return not active or gap(p) <= radius + MARGIN_M


## shows() with hysteresis for a thing that keeps a state: `was_on` keeps it on HYSTERESIS_M farther out.
func keeps(p: Vector3, radius: float, was_on: bool) -> bool:
	return not active or gap(p) <= radius + MARGIN_M + (HYSTERESIS_M if was_on else 0.0)


## The view's half width and half height on screen (metres; tests).
func half_extents() -> Vector2:
	return Vector2(_half_w, _half_h)
