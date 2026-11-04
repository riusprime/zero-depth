extends ColorRect
## v0.10.5 W3-O13b G2 mockups (scripts/shots/mock_ui_refs.gd): the soft blur of the world behind the panels the
## painter listed on its last draw (rectangles, their corners cut by the given amount). A prototype, not game code.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 rects[24];
uniform float cuts[24];
uniform int count = 0;
uniform vec2 view = vec2(1920.0, 1080.0);
uniform vec4 tint : source_color = vec4(0.03, 0.05, 0.09, 0.35);
float sd_cut(vec2 p, vec2 c, vec2 h, float k) {
	vec2 q = abs(p - c);
	float box = max(q.x - h.x, q.y - h.y);
	float diag = (q.x + q.y - (h.x + h.y - k)) * 0.70710678;
	return max(box, diag);
}
void fragment() {
	vec2 px = UV * view;
	float d = 1e6;
	for (int i = 0; i < 24; i++) {
		if (i >= count) { break; }
		vec4 r = rects[i];
		d = min(d, sd_cut(px, r.xy + r.zw * 0.5, r.zw * 0.5, cuts[i]));
	}
	float inside = 1.0 - step(0.0, d);
	vec3 blur = textureLod(screen_tex, SCREEN_UV, 3.5).rgb * 0.5;
	blur += textureLod(screen_tex, SCREEN_UV + vec2(0.003, 0.0), 4.0).rgb * 0.25;
	blur += textureLod(screen_tex, SCREEN_UV - vec2(0.003, 0.0), 4.0).rgb * 0.25;
	COLOR = vec4(mix(blur, tint.rgb, tint.a), inside);
}
"""

var painter: Control


func _init(p: Control) -> void:
	painter = p
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	material = mat


func _process(_d: float) -> void:
	var rs: Array[Vector4] = []
	var cuts := PackedFloat32Array()
	var listed: Array = painter.get("glass")
	for g: Array in listed:
		var r: Rect2 = g[0]
		rs.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
		cuts.append(float(g[1]))
	while rs.size() < 24:
		rs.append(Vector4.ZERO)
		cuts.append(0.0)
	var m := material as ShaderMaterial
	m.set_shader_parameter("rects", rs.slice(0, 24))
	m.set_shader_parameter("cuts", cuts.slice(0, 24))
	m.set_shader_parameter("count", mini(listed.size(), 24))
