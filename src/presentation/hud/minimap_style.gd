class_name MinimapStyle
extends RefCounted
## The minimap's look in one place (PLAN v0.3.0 MM), so a HUD restyle touches only this file. Thin lines with a
## soft glow: cyan for you, dim grey rooms, amber stubs where a doorway leads somewhere you haven't been, red for
## the boss door, blue for the open portal. Every number here is a starting value.

const PANEL := Color(0.02, 0.04, 0.07, 0.93)
const PANEL_EDGE := Color(0.80, 0.84, 0.88, 0.30)
const BACKDROP := Color(0.0, 0.01, 0.03, 0.62)
const ROOM_FILL := Color(0.55, 0.62, 0.70, 0.22)
const ROOM_EDGE := Color(0.70, 0.78, 0.86, 0.75)
const CURRENT_FILL := Color(0.30, 0.85, 1.0, 0.24)
const CURRENT_EDGE := Color(0.45, 0.92, 1.0, 1.0)
const UNEXPLORED := Color("#F2B84B")
const PLAYER := Color("#3FE0FF")
const ALTAR := Color("#F2D16B")
## The gamble shrine (v0.3.0 L19).
const SHRINE := Color("#D46BFF")
## v0.5.0 EV: an event pedestal (dim once spent), green so it reads apart from the shop.
const EVENT := Color("#9EE37D")
## The shop terminal (v0.5.0 SH), in the shards' violet.
const SHOP := Color("#B48CFF")
const CHEST := Color("#E0A458")
const CHEST_POOR := Color(0.62, 0.55, 0.50, 0.85)
const BOSS := Color("#FF4A3D")
## v0.5.0 PB: the boss door once the boss is dead (open both ways): the same red, dimmed.
const BOSS_OPEN := Color(1.0, 0.29, 0.24, 0.38)
## v0.4.0 AB: the Overrun room (its doorways and its mark): a hotter, pinker red than the boss door.
const OVERRUN := Color("#FF2E6A")
const PORTAL_OPEN := Color("#4DA3FF")
const PORTAL_SEALED := Color(0.55, 0.60, 0.70, 0.8)
## v0.5.0 RT: the Deep portal, violet in a red ring (the gate's own colours).
const PORTAL_DEEP := Color("#8B3DFF")
const PORTAL_DEEP_RIM := Color("#FF2A3D")
const TEXT := Color(0.85, 0.95, 1.0, 0.95)
const TEXT_DIM := Color(0.70, 0.80, 0.88, 0.75)

## Line widths in pixels; the glow is the same line drawn this much wider and this transparent beneath it.
const LINE := 1.5
const GLOW_WIDTH := 4.0
const GLOW_ALPHA := 0.12
const CORNER_RADIUS := 0

## The corner map: its size and gap from the screen's top-right corner (under the shard counter), and its scale.
const CORNER_SIZE := Vector2(300, 300)
const CORNER_TOP := 84.0
const CORNER_RIGHT := 28.0
const CORNER_PX_PER_M := 5.0
## The full map: the share of the screen it may use, and the legend's width beside it.
const FULL_SHARE := 0.86
const LEGEND_WIDTH := 400.0
const FONT_SIZE := 20
const TITLE_SIZE := 30

## The map turns with the iso camera, so up on the map is up on screen (the camera looks along sim (-X, +Y), 45 degrees
## off the sim's axes; MinimapView.turn), and squashes the vertical a little toward the camera's tilt so rooms look as
## they do in the world. 1.0 would be a plain diamond; the camera's true squash is about 0.58.
const SQUASH := 0.72
## The stub drawn into an unexplored room, past the doorway (m), and its arrowhead (m).
const STUB_M := 5.0
const STUB_HEAD_M := 2.0
## The stub's drawn length is kept within these pixels at any scale.
const STUB_MIN_PX := 14.0
const STUB_MAX_PX := 34.0
## Icon sizes in pixels at the corner map's scale (the full map grows them a little).
const ICON := 6.0
const PLAYER_ICON := 11.0


## Draws a line twice: a wide faint glow, then the line.
static func glow_line(
	ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = LINE
) -> void:
	ci.draw_line(a, b, Color(color, color.a * GLOW_ALPHA), width + GLOW_WIDTH, true)
	ci.draw_line(a, b, color, width, true)


static func glow_polyline(
	ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float = LINE
) -> void:
	ci.draw_polyline(pts, Color(color, color.a * GLOW_ALPHA), width + GLOW_WIDTH, true)
	ci.draw_polyline(pts, color, width, true)
