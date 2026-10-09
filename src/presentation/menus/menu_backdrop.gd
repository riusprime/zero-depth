class_name MenuBackdrop
extends ColorRect
## The cold glass menus' backdrop (v0.5.5 A5, MenuStyle): the game behind, blurred and dimmed, darker toward the
## left where the list sits. One canvas shader on a full-screen rect: it reads the screen behind it at a lower mip
## (a soft blur) and lays a left-to-right dark gradient over it. Over an empty screen (the main menu) it is just the
## gradient. It takes no input.

## How dark the left and right edges are (0..1), and the blur's mip level (starting values).
const DARK_LEFT := 0.82
const DARK_RIGHT := 0.4
const BLUR_LOD := 2.6

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 2.6;
uniform float dark_left = 0.82;
uniform float dark_right = 0.4;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	float g = mix(dark_left, dark_right, smoothstep(0.0, 0.85, UV.x));
	vec3 tint = vec3(0.012, 0.02, 0.03);
	COLOR = vec4(mix(c, tint, g), 1.0);
}
"""

static var _shader: Shader


func _init() -> void:
	name = "MenuBackdrop"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0, 0, 0, DARK_LEFT)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter(&"lod", BLUR_LOD)
	m.set_shader_parameter(&"dark_left", DARK_LEFT)
	m.set_shader_parameter(&"dark_right", DARK_RIGHT)
	material = m
