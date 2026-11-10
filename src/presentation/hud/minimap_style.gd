class_name MinimapStyle
extends RefCounted
## The minimap's look in one place (PLAN v0.3.0 MM), so a HUD restyle touches only this file. Thin lines with a
## soft glow: cyan for you, dim grey rooms, amber stubs where a doorway leads somewhere you haven't been, red for
## the boss door, blue for the open portal. Every number here is a starting value.
## v0.5.5 A5 (owner: "minimap from B (we should remove the black background tho)"): the corner map has no panel; it
## floats over the game. Every line draws over a soft dark halo (SHADOW) and every room over a faint dark wash, so
## the map reads over light and dark floors alike; four small ember corner ticks mark the window's extent. The
## full map (held) keeps its dimmed backdrop and panel.
## UI style Astral; owner: "and what about the rest of the UI? it should match the new style": the
## colours and the frame only (the map's content is unchanged): lilac-tinted silver rooms, the current room in the
## moon-blue accent, the hero near-white, the unexplored stubs moon-blue, the chest pale gold (no orange or brown); the
## full map's panel is Astral's ink with a contour line; the corner window's ticks are 1 px silver L's with an inner
## tick, a small diamond at each corner and a four-point star under its foot (MinimapView._draw_corner_ticks).

const PANEL := Color("#0D1120", 0.93)
const PANEL_EDGE := Color("#6E76A0", 0.7)
const BACKDROP := Color("#070913", 0.62)
const ROOM_FILL := Color("#C9CCE6", 0.08)
const ROOM_EDGE := Color("#C9CCE6", 0.62)
const CURRENT_FILL := Color("#B5BDF0", 0.14)
const CURRENT_EDGE := Color("#E4E6FF", 1.0)
const UNEXPLORED := Color("#B5BDF0")
const PLAYER := Color("#F4F5FF")
const ALTAR := Color("#F2D16B")
## The gamble shrine.
const SHRINE := Color("#D46BFF")
## An event pedestal (dim once spent), green so it reads apart from the shop.
const EVENT := Color("#9EE37D")
## The shop terminal, in the shards' violet.
const SHOP := Color("#B48CFF")
const CHEST := Color("#E2CB8E")
const CHEST_POOR := Color(0.56, 0.58, 0.70, 0.85)
const BOSS := Color("#FF4A3D")
## The boss door once the boss is dead (open both ways): the same red, dimmed.
const BOSS_OPEN := Color(1.0, 0.29, 0.24, 0.38)
## The Overrun room (its doorways and its mark): a hotter, pinker red than the boss door.
const OVERRUN := Color("#FF2E6A")
## A sealed arena (its doorways and its mark): amber, like its frames in the world.
const ARENA := Color("#FFB020")
const PORTAL_OPEN := Color("#4DA3FF")
const PORTAL_SEALED := Color(0.55, 0.60, 0.70, 0.8)
## The Deep portal, violet in a red ring (the gate's own colours).
const PORTAL_DEEP := Color("#8B3DFF")
const PORTAL_DEEP_RIM := Color("#FF2A3D")
const TEXT := Color("#ECEEFA", 0.95)
const TEXT_DIM := Color("#9095B4", 0.9)

## The corner map draws a panel behind itself (false since v0.5.5 A5: no black background).
const CORNER_PANEL := false
## The halo under every map line and icon, and the wash under every room (corner map).
const SHADOW := Color(0.0, 0.0, 0.0, 0.5)
const SHADOW_WIDTH := 3.0
const ROOM_WASH := Color(0.02, 0.02, 0.03, 0.3)
## The corner ticks (B's ember accent): their arm length and colour.
const TICK_ARM := 16.0
const TICK := Color("#C9CCE6", 0.85)

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


## Draws a line three times: a dark halo, a wide faint glow, then the line.
static func glow_line(
	ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = LINE
) -> void:
	ci.draw_line(a, b, Color(SHADOW, SHADOW.a * color.a), width + SHADOW_WIDTH, true)
	ci.draw_line(a, b, Color(color, color.a * GLOW_ALPHA), width + GLOW_WIDTH, true)
	ci.draw_line(a, b, color, width, true)
