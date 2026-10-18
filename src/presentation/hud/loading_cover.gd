class_name LoadingCover
extends Control
## v0.8.0 N3 (owner O45: "we have to add loading screens so the game does not freeze when you start the game and take a
## portal, these could be fades into black and a little loading symbol on a corner, and the load between floors in
## portal an animation that covers the screen with the color and animation style of the portal you cross and then
## unveils it back at the new floor"; docs/roadmap/v0.8.0/evidence/N3_RING_AND_LOADING.md).
## A full-screen cover on the UI layer that hides a load:
## - BLACK (a new run, Continue, Restart, any load from a menu): the screen goes black at once with a small spinning
##   loading mark in the bottom-right corner; Main builds the floor behind it a frame later and then the cover fades out
##   (unveil) over the new floor's first moments;
## - GATE / DEEP / ASCENSION / LOOP (walking into a portal): an iris closes over the screen in that portal's colours
##   and motion (the gate's blue vortex, the Deep gate's violet with its red rim torn jagged, the Ascension portal's
##   gold rays on lavender, the Loop device's green ripples) as the hero goes in, the next floor loads under the
##   closed cover, and the iris opens on the new floor.
## Reduced motion (ViewPrefs): a plain fade in the cover's colour, and the mark breathes instead of spinning.
## Presentation only: it reads the sim's portal progress (Main passes it) and its own screen clock; no outcome waits
## on it (EI-03), and it never takes the mouse, the focus or input. No text: the mark is a symbol.

## HIDDEN: nothing drawn; COVERING: a portal's iris closing (set_closing); COVERED: the screen is covered (a load may
## run); UNVEILING: opening on what was loaded.
enum Phase { HIDDEN, COVERING, COVERED, UNVEILING }
enum Style { BLACK, GATE, DEEP, ASCENSION, LOOP }

## The loading mark: its radius and line width (px), its gap to the screen's corner, and its turn (turns a second).
const MARK_R := 13.0
const MARK_W := 3.0
const MARK_MARGIN := 34.0
const MARK_SPIN := 1.1
## The unveil waits this many drawn frames on the loaded screen before it opens (the first frame is the new one).
const HOLD_FRAMES := 1

const SHADER := """
shader_type canvas_item;
uniform vec4 c_dark : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 c_main : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 c_light : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float cover = 0.0;
uniform int style = 0;
uniform float calm = 0.0;
uniform float aspect = 1.7778;
uniform float spin = 0.0;

void fragment() {
	if (style == 0 || calm > 0.5) {
		COLOR = vec4(c_dark.rgb, cover);
	} else {
		vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
		float r = length(p);
		float a = atan(p.y, p.x);
		float reach = length(vec2(aspect, 1.0)) * 0.5 + 0.3;
		float hole = (1.0 - cover) * reach;
		float wob = 0.0;
		float bands = 0.0;
		if (style == 1) {  // the gate: a blue vortex
			wob = 0.07 * sin(a * 5.0 + r * 14.0 - spin * 3.0);
			bands = 0.5 + 0.5 * sin(a * 3.0 + r * 18.0 - spin * 4.0);
		} else if (style == 2) {  // the Deep gate: violet, torn jagged, a red rim
			wob = 0.05 * sin(a * 11.0 + spin * 2.0) + 0.04 * sin(a * 23.0 - spin * 5.0);
			bands = 0.5 + 0.5 * sin(a * 7.0 - r * 9.0 + spin * 2.5);
		} else if (style == 3) {  // the gold portal of the last floor: rays on lavender
			wob = 0.08 * pow(abs(sin(a * 8.0 + spin * 0.8)), 6.0);
			bands = pow(abs(sin(a * 12.0 - spin * 0.6)), 4.0);
		} else {  // the Loop device: green ripples
			wob = 0.03 * sin(r * 30.0 - spin * 5.0);
			bands = 0.5 + 0.5 * sin(r * 26.0 - spin * 4.0);
		}
		float edge = r + wob - hole;
		float inside = smoothstep(-0.004, 0.012, edge);
		float rim = exp(-abs(edge) * 38.0) * step(0.001, cover);
		vec3 fill = mix(c_dark.rgb, c_main.rgb, 0.42 * bands);
		vec3 col = mix(fill, c_light.rgb, clamp(rim, 0.0, 1.0) * 0.85);
		float alpha = max(inside, clamp(rim, 0.0, 1.0) * 0.9);
		if (cover >= 0.999) {
			alpha = 1.0;
		}
		COLOR = vec4(col, alpha);
	}
}
"""

var phase := Phase.HIDDEN
var style := Style.BLACK
## 0 = open .. 1 = closed.
var amount := 0.0
## Reduced motion, read when a cover starts.
var calm := false
## Frames drawn while fully closed (the load runs only after at least one).
var frames_covered := 0
var fill := ColorRect.new()
var mark := Control.new()
var _mat := ShaderMaterial.new()
var _spin := 0.0
var _unveil_s := 0.45
var _hold := 0


func _init() -> void:
	name = "LoadingCover"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	fill.name = "Fill"
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = Color.WHITE
	fill.material = _mat
	add_child(fill)
	mark.name = "Mark"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mark.custom_minimum_size = Vector2(MARK_R, MARK_R) * 2.0
	mark.offset_left = -MARK_MARGIN - MARK_R * 2.0
	mark.offset_top = -MARK_MARGIN - MARK_R * 2.0
	mark.offset_right = -MARK_MARGIN
	mark.offset_bottom = -MARK_MARGIN
	mark.visible = false
	mark.draw.connect(_draw_mark)
	add_child(mark)


## The screen is covered now (black or `p_style`), the loading mark showing: a load may start after the next frame.
func cover_now(p_style: int = Style.BLACK) -> void:
	_start(p_style)
	amount = 1.0
	phase = Phase.COVERED
	_apply()


## A portal's iris closing as `t` (0..1, the hero's way in) rises; it never opens again on its own (only unveil does).
func set_closing(p_style: int, t: float) -> void:
	if phase == Phase.HIDDEN or phase == Phase.UNVEILING or style != p_style:
		_start(p_style)
		amount = 0.0
		phase = Phase.COVERING
	amount = maxf(amount, clampf(t, 0.0, 1.0))
	if amount >= 1.0:
		phase = Phase.COVERED
	_apply()


## Opens the cover over `seconds` (after HOLD_FRAMES drawn frames of what was loaded). A hidden cover stays hidden.
func unveil(seconds: float) -> void:
	if phase == Phase.HIDDEN:
		return
	phase = Phase.UNVEILING
	_unveil_s = maxf(0.05, seconds)
	_hold = HOLD_FRAMES
	_apply()


## v0.8.0 N12: the cover's own clock (s), which turns the mark and moves the iris: it advances every drawn frame.
func clock() -> float:
	return _spin


## The screen is fully covered.
func is_covered() -> bool:
	return phase == Phase.COVERED


## Anything of the cover is on screen.
func showing() -> bool:
	return phase != Phase.HIDDEN


## v0.8.0 N18: the cover hides the screen (closing or closed; while it fades out, what is under it shows).
func shut() -> bool:
	return phase == Phase.COVERING or phase == Phase.COVERED


## The cover's colours for `p_style`, dark to light (the portal's palette; black for BLACK).
static func palette(p_style: int) -> Array[Color]:
	match p_style:
		Style.GATE:
			return PortalGate.swirl_colors()
		Style.DEEP:
			return [
				PortalGate.DEEP_VIOLET.darkened(0.8), PortalGate.DEEP_VIOLET, PortalGate.DEEP_RIM
			]
		Style.ASCENSION:
			return [
				AscensionPortal.LAVENDER.darkened(0.7), AscensionPortal.GOLD, AscensionPortal.CORE
			]
		Style.LOOP:
			return [
				LoopDevice.GREEN_DEEP.darkened(0.6),
				LoopDevice.GREEN,
				LoopDevice.GREEN.lightened(0.6)
			]
	return [Color.BLACK, Color.BLACK, Color(0.85, 0.85, 0.85)]


## The style of the portal the hero is going into on this floor (the Loop device, the Ascension portal, the Deep gate,
## or the gate).
static func portal_style(reader: WorldReader) -> int:
	if reader.ascension_choice() == WorldReader.ASCEND_LOOP:
		return Style.LOOP
	if reader.ascension_floor():
		return Style.ASCENSION
	if reader.route_taken() == WorldReader.ROUTE_DEEP:
		return Style.DEEP
	return Style.GATE


func _start(p_style: int) -> void:
	style = p_style
	calm = ViewPrefs.reduced_motion
	frames_covered = 0
	var c := palette(p_style)
	_mat.set_shader_parameter("c_dark", c[0])
	_mat.set_shader_parameter("c_main", c[1])
	_mat.set_shader_parameter("c_light", c[2])
	_mat.set_shader_parameter("style", p_style)
	_mat.set_shader_parameter("calm", 1.0 if calm else 0.0)


func _apply() -> void:
	visible = phase != Phase.HIDDEN
	_mat.set_shader_parameter("cover", amount)
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(16, 9)
	_mat.set_shader_parameter("aspect", vp.x / maxf(1.0, vp.y))
	mark.visible = phase == Phase.COVERED
	mark.queue_redraw()


func _process(delta: float) -> void:
	if phase == Phase.HIDDEN:
		return
	_spin += delta
	_mat.set_shader_parameter("spin", 0.0 if calm else _spin)
	if phase == Phase.COVERED:
		frames_covered += 1
	if phase == Phase.UNVEILING:
		if _hold > 0:
			_hold -= 1
		else:
			amount = maxf(0.0, amount - delta / _unveil_s)
			if amount <= 0.0:
				phase = Phase.HIDDEN
	_apply()


## The loading mark: a three-quarter ring turning (reduced motion: a still ring that breathes).
func _draw_mark() -> void:
	var c := palette(style)[2]
	var centre := mark.size * 0.5
	if calm:
		var a := 0.55 + 0.35 * sin(_spin * TAU * 0.5)
		mark.draw_arc(centre, MARK_R, 0.0, TAU, 32, Color(c, a), MARK_W, true)
		return
	var start := _spin * TAU * MARK_SPIN
	mark.draw_arc(centre, MARK_R, 0.0, TAU, 32, Color(c, 0.18), MARK_W, true)
	mark.draw_arc(centre, MARK_R, start, start + TAU * 0.72, 24, Color(c, 0.95), MARK_W, true)
