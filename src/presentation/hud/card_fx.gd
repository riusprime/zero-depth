class_name CardFx
extends Node2D
## v0.8.0 N8 (owner O62, D48): a reward card's motion and light, at the card's centre: the pivot its stone face
## (StoneCard's Face) hangs from, and the light rays behind it (drawn by the pick panel under every card). The pick
## panel sets it each frame from its CardDeal and the pointer; nothing here decides an outcome (EI-07; presentation
## may animate).
## - Pose: the deal's offset and fan turn, the flip's width (scale.x to 0, the face swapped halfway by `face_up`),
##   the punch (a scale pop), the hover tilt toward the cursor (a skew and a small turn) and the focus sink.
## - Back: the face-down card, painted in its rarity's colour with a carved ember mark; a high card's back glows.
## - Light: the white flash as a high card lands, the light rays rising behind it, and a Legendary card's looping
##   holographic shine across its face (a still gloss under reduced motion).
## - Burn: a card not picked burns away from its foot (a dissolve with an ember edge, shared by every part of the
##   face through use_parent_material), and the picked one's icon flies to the HUD (CardFly).

const RAYS := 14
## Rays reach this share of the card's height past its centre; turn this fast (radians a second).
const RAY_REACH := 0.85
const RAY_SPIN := 0.35
## The hover tilt's most skew and turn (radians) and the focus sink (scale, px at scale 1).
const TILT_SKEW := 0.12
const TILT_TURN := 0.045
const SINK_SCALE := 0.965
const SINK_PX := 5.0

const BURN_SHADER := """
shader_type canvas_item;
uniform float burn : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform vec2 rect_pos = vec2(0.0);
uniform vec2 rect_size = vec2(300.0, 500.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x);
	float b = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x);
	return mix(a, b, u.y);
}
varying vec2 local;
void vertex() { local = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec2 q = (local - rect_pos) / rect_size;
	float n = noise(q * vec2(9.0, 14.0)) * 0.32 + noise(q * 31.0) * 0.14;
	float front = (1.0 - q.y) * 0.9 + n;
	float t = burn * 1.55 - 0.1;
	if (front < t) { discard; }
	float e = smoothstep(t + 0.09, t, front);
	COLOR.rgb = mix(COLOR.rgb, edge_color.rgb * 1.6, e);
	COLOR.rgb *= 1.0 - 0.35 * smoothstep(t + 0.3, t, front);
}
"""
const HOLO_SHADER := """
shader_type canvas_item;
uniform float speed = 1.0;
uniform float strength = 0.35;
uniform float phase = 0.0;
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
void fragment() {
	float t = TIME * speed + phase;
	float band = UV.x * 1.3 + UV.y * 0.7 - fract(t * 0.35) * 2.6 + 0.6;
	float sheen = exp(-band * band * 9.0);
	vec3 c = hue(fract(UV.x * 0.8 - UV.y * 0.6 + t * 0.12));
	COLOR = vec4(mix(c, vec3(1.0), 0.45) * (0.35 + sheen), strength * (0.25 + 0.75 * sheen));
}
"""

static var _burn_shader: Shader
static var _holo_shader: Shader

var face: Control
## The turning, flipping, tilting part (the face, its back and the flash); the rays stay outside it.
var pivot := Node2D.new()
var back := CardBack.new()
var flash_rect := ColorRect.new()
var shine := ColorRect.new()
## The card's size (px) and its rarity's colour.
var card_size := Vector2(275, 450)
var tier_color := Color.WHITE
## The pose the panel last set (tests read them).
var offset := Vector2.ZERO
var turn := 0.0
var width := 1.0
var punch := 0.0
var tilt := Vector2.ZERO
var sink := 0.0
var rays := 0.0
var burn := 0.0
var _burn_mat: ShaderMaterial
var _spin := 0.0
var _animate := true


func _init(p_face: Control) -> void:
	name = "CardFx"
	pivot.name = "Pivot"
	add_child(pivot)
	face = p_face
	pivot.add_child(face)
	back.name = "Back"
	back.visible = false
	pivot.add_child(back)
	shine.name = "Shine"
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.visible = false
	var holo := ShaderMaterial.new()
	holo.shader = _holo()
	shine.material = holo
	face.add_child(shine)
	flash_rect.name = "Flash"
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.visible = false
	pivot.add_child(flash_rect)


static func _holo() -> Shader:
	if _holo_shader == null:
		_holo_shader = Shader.new()
		_holo_shader.code = HOLO_SHADER
	return _holo_shader


static func _burner() -> Shader:
	if _burn_shader == null:
		_burn_shader = Shader.new()
		_burn_shader.code = BURN_SHADER
	return _burn_shader


## Lays the card's centre for a card of `s` px; the face, back and flash hang round it.
func lay_out(s: Vector2) -> void:
	card_size = s
	position = s * 0.5
	for c: Control in [back, flash_rect, shine]:
		c.size = s
	face.position = -s * 0.5
	back.position = -s * 0.5
	flash_rect.position = -s * 0.5
	shine.position = Vector2.ZERO
	_compose()


## The deal's pose: the offset from the card's place (px), its fan turn (radians), its width (0..1: the flip) and
## the punch's extra scale.
func set_pose(p_offset: Vector2, p_turn: float, p_width: float, p_punch: float = 0.0) -> void:
	offset = p_offset
	turn = p_turn
	width = p_width
	punch = p_punch
	_compose()


## The hover tilt toward the cursor (-1..1 each way; zero: none) and the focus sink (0..1).
func set_hover(p_tilt: Vector2, p_sink: float) -> void:
	tilt = p_tilt.clamp(Vector2(-1, -1), Vector2(1, 1))
	sink = clampf(p_sink, 0.0, 1.0)
	_compose()


## Face up (the face shows) or down (the back shows); a high card's back glows `glow` (0..1).
func set_side(up: bool, glow: float = 0.0) -> void:
	face.visible = up
	back.visible = not up
	back.glow = glow


## The flash (0..1) and the light rays (0..1) behind the card.
func set_light(p_flash: float, p_rays: float) -> void:
	flash_rect.visible = p_flash > 0.001
	flash_rect.color = Color(1.0, 0.97, 0.88, 0.85 * p_flash)
	rays = p_rays


## Paints the back in the rarity's colour and turns the Legendary shine on or off (`animated` false: a still gloss).
func paint(p_tier: int, color: Color, legendary: bool, animated: bool) -> void:
	tier_color = color
	back.paint(p_tier, color)
	shine.visible = legendary
	_animate = animated
	var m := shine.material as ShaderMaterial
	m.set_shader_parameter("speed", 1.0 if animated else 0.0)
	m.set_shader_parameter("phase", 0.0 if animated else 1.4)
	m.set_shader_parameter("strength", 0.32 if animated else 0.2)


## Whether the Legendary shine is on, and whether it moves.
func shining() -> bool:
	return shine.visible


func shine_moves() -> bool:
	return (
		shine.visible
		and float((shine.material as ShaderMaterial).get_shader_parameter("speed")) > 0.0
	)


## 0..1 of the burn (0: whole; 1: gone). Every part of the face burns along one front.
func set_burn(t: float) -> void:
	burn = clampf(t, 0.0, 1.0)
	if burn <= 0.0:
		if _burn_mat != null:
			face.material = null
			_share_material(false)
			_burn_mat = null
		return
	if _burn_mat == null:
		_burn_mat = ShaderMaterial.new()
		_burn_mat.shader = _burner()
		face.material = _burn_mat
		_share_material(true)
	_burn_mat.set_shader_parameter("burn", burn)
	_burn_mat.set_shader_parameter("edge_color", tier_color.lerp(Color("#FF8A3D"), 0.6))
	_burn_mat.set_shader_parameter("rect_pos", face.get_global_transform().origin)
	_burn_mat.set_shader_parameter(
		"rect_size",
		card_size * pivot.get_global_transform().get_scale().abs().max(Vector2.ONE * 0.01)
	)


func burning() -> bool:
	return _burn_mat != null


## v0.9.0 AS (owner Q5 "Marked, old one burns"): a fresh burn material (the same dissolve, its params at 0) for any
## other part that burns, the pick card's replaced-card chip (PickSlot.burn_replaced).
static func burn_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _burner()
	return m


func _share_material(on: bool) -> void:
	for c in face.find_children("*", "CanvasItem", true, false):
		(c as CanvasItem).use_parent_material = on


func _process(delta: float) -> void:
	if rays > 0.001 and _animate:
		_spin = fmod(_spin + delta * RAY_SPIN, TAU)


func _compose() -> void:
	var s := 1.0 + punch
	var sunk := lerpf(1.0, SINK_SCALE, sink)
	position = card_size * 0.5 + offset
	pivot.position = Vector2(0, SINK_PX * sink)
	pivot.rotation = turn + tilt.x * TILT_TURN
	pivot.skew = -tilt.x * TILT_SKEW
	pivot.scale = Vector2(maxf(width, 0.001) * s * sunk, s * sunk * (1.0 - absf(tilt.y) * 0.03))


## The light rays rising behind the card, and a soft glow under them, drawn on `ci` round `at` (its local px) at
## `k` px per card px: the pick panel draws every card's rays on one layer under the cards, so a card's rays never
## cross its neighbour.
func draw_rays(ci: CanvasItem, at: Vector2, k: float) -> void:
	if rays <= 0.001:
		return
	var c := tier_color.lightened(0.35)
	var reach := card_size.y * RAY_REACH * k
	var w := 0.11
	for r in RAYS:
		var a := _spin + r * TAU / RAYS
		var len_k := reach * (0.75 + 0.25 * sin(r * 2.3))
		var pts := PackedVector2Array(
			[
				at,
				at + Vector2(cos(a - w), sin(a - w)) * len_k,
				at + Vector2(cos(a + w), sin(a + w)) * len_k,
			]
		)
		var cols := PackedColorArray([Color(c, 0.38 * rays), Color(c, 0.0), Color(c, 0.0)])
		ci.draw_polygon(pts, cols)
	ci.draw_circle(at, card_size.x * 0.55 * k, Color(c, 0.08 * rays))
