class_name MenuBackdrop
extends ColorRect
## The menus' backdrop (v0.8.0 MU, Ember stone; MenuStyle): one canvas shader on a full-screen rect.
## - Over the game (pause, the run recap, the Build page, a modal): the game blurred (a lower mip of the screen) and
##   sunk into a warm near-black, darker toward the left where the list sits, a low ember glow rising from the bottom.
## - With nothing behind it (the main menu and the screens it opens: the screen behind is one flat colour, or
##   `own_scene` is set): its own scene, a dark ember-lit stone floor
##   (slow mottled slabs with carved seams and cracks), a warm glow breathing up from below, a vignette.
## - Both: a few sparks drifting up from the embers.
## Reduced motion (HudStyle.reduced_motion): the clock stops, so the sparks stand still and nothing flickers or
## breathes. The clock is the screen's (a look only, never an outcome: EI-03). It takes no input. Cheap: one pass
## of value noise per pixel, only while a menu shows.

## How dark the left and right edges are over the game (0..1), and the blur's mip level (starting values).
const DARK_LEFT := 0.84
const DARK_RIGHT := 0.5
const BLUR_LOD := 2.6
## The sparks' strength (starting value).
const SPARKS := 1.0

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 2.6;
uniform float dark_left = 0.84;
uniform float dark_right = 0.5;
uniform float t = 0.0;
uniform float sparks = 1.0;
uniform float scene = 0.0;
const vec3 EMBER = vec3(0.92, 0.68, 0.45);
const vec3 HOTCORE = vec3(1.0, 0.86, 0.66);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x);
	float b = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}
// The ember-lit stone floor (the main menu's own scene): big slabs with seams, mottle and cracks, lit from below.
vec3 stone_scene(vec2 px, vec2 uv) {
	vec2 q = px / vec2(260.0, 180.0);
	q.x += floor(q.y) * 0.5;
	vec2 cell = fract(q);
	vec2 id = floor(q);
	float seam = min(min(cell.x, 1.0 - cell.x) * 260.0, min(cell.y, 1.0 - cell.y) * 180.0);
	float m = fbm(px / 140.0 + id * 3.1);
	vec3 col = vec3(0.075, 0.059, 0.05) * (0.55 + 0.8 * m) * (0.8 + 0.4 * hash(id));
	col *= mix(0.3, 1.0, smoothstep(1.0, 7.0, seam));
	col += vec3(0.05, 0.035, 0.02) * (1.0 - smoothstep(0.0, 2.5, abs(seam - 8.0))) * uv.y;
	float cr = abs(fbm(px / 90.0 + id) * 2.0 - 1.0);
	col *= 1.0 - (1.0 - smoothstep(0.006, 0.025, cr)) * 0.3 * step(0.55, hash(id + 0.5));
	float breathe = 0.9 + 0.1 * sin(t * 0.7) + 0.05 * sin(t * 1.9 + 1.3);
	float glow = pow(uv.y, 2.4) * 0.45 * breathe;
	glow += 0.35 * exp(-length((uv - vec2(0.7 + 0.03 * sin(t * 0.21), 1.05)) * vec2(1.3, 2.4)) * 2.0) * breathe;
	col += EMBER * glow * (0.3 + 0.8 * m);
	float v = length((uv - vec2(0.6, 0.62)) * vec2(1.25, 1.0));
	col *= 1.0 - smoothstep(0.3, 1.1, v) * 0.85;
	return col;
}
// Sparks: in columns, each rising, swaying and fading; their speed and phase from the column's hash.
vec3 spark_layer(vec2 px, vec2 screen, float cellw, float speed, float k) {
	float col = floor(px.x / cellw);
	vec3 acc = vec3(0.0);
	for (int j = 0; j < 2; j++) {
		float h = hash(vec2(col, float(j) * 7.13 + k));
		float h2 = hash(vec2(col + 3.7, float(j) * 1.9 + k));
		float life = fract(t * speed * (0.6 + 0.8 * h) + h2);
		float y = screen.y * (1.05 - life * (0.55 + 0.4 * h));
		float x = (col + 0.2 + 0.6 * h2) * cellw + sin(t * (1.0 + h) + h * 6.28) * cellw * 0.18;
		float d = length(px - vec2(x, y));
		float r = 1.3 + 1.4 * h;
		float a = smoothstep(r + 1.2, r * 0.3, d) + 0.25 * exp(-d / (r * 2.5));
		a *= (1.0 - life) * smoothstep(0.0, 0.08, life) * smoothstep(0.2, 0.75, y / screen.y);
		acc += mix(EMBER, HOTCORE, 0.5 + 0.5 * h) * a * step(0.55, h2);
	}
	return acc;
}
void fragment() {
	vec2 screen = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = SCREEN_UV * screen;
	vec2 uv = SCREEN_UV;
	vec3 g = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	vec3 over = mix(g, vec3(0.02, 0.013, 0.01), mix(dark_left, dark_right, smoothstep(0.0, 0.85, uv.x)));
	over *= 0.78 + 0.22 * uv.y;
	over += EMBER * pow(uv.y, 3.0) * 0.16;
	// Nothing behind (the main menu): the screen is one flat colour. Five fixed probes, the same for every pixel.
	vec3 p0 = textureLod(screen_tex, vec2(0.5, 0.5), 4.0).rgb;
	float spread = length(textureLod(screen_tex, vec2(0.2, 0.25), 4.0).rgb - p0);
	spread = max(spread, length(textureLod(screen_tex, vec2(0.8, 0.3), 4.0).rgb - p0));
	spread = max(spread, length(textureLod(screen_tex, vec2(0.3, 0.8), 4.0).rgb - p0));
	spread = max(spread, length(textureLod(screen_tex, vec2(0.75, 0.75), 4.0).rgb - p0));
	float empty = max(scene, 1.0 - smoothstep(0.004, 0.03, spread));
	vec3 col = mix(over, stone_scene(px, uv), empty);
	col += sparks * spark_layer(px, screen, 46.0, 0.05, 0.0);
	col += sparks * 0.6 * spark_layer(px + vec2(23.0, 0.0), screen, 71.0, 0.035, 5.0);
	COLOR = vec4(col, 1.0);
}
"""

static var _shader: Shader

## The backdrop's clock (s): it runs unless reduced motion holds it.
var clock := 0.0
## Draws its own ember scene whatever is behind (the main menu sets it).
var own_scene := false:
	set(v):
		own_scene = v
		_mat.set_shader_parameter(&"scene", 1.0 if v else 0.0)
var _mat := ShaderMaterial.new()


func _init() -> void:
	name = "MenuBackdrop"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0.02, 0.013, 0.01, 1.0)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat.shader = _shader
	_mat.set_shader_parameter(&"lod", BLUR_LOD)
	_mat.set_shader_parameter(&"dark_left", DARK_LEFT)
	_mat.set_shader_parameter(&"dark_right", DARK_RIGHT)
	_mat.set_shader_parameter(&"sparks", SPARKS)
	_mat.set_shader_parameter(&"t", clock)
	material = _mat


func _process(delta: float) -> void:
	if HudStyle.reduced_motion or not is_visible_in_tree():
		return
	clock += minf(delta, 0.1)
	_mat.set_shader_parameter(&"t", clock)


## Sets the clock (screenshots and tests).
func seek(seconds: float) -> void:
	clock = seconds
	_mat.set_shader_parameter(&"t", clock)


## The clock the shader draws now.
func shown_clock() -> float:
	return float(_mat.get_shader_parameter(&"t"))
