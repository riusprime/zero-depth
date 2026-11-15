class_name FallenLooks
extends RefCounted
## What The Fallen's remembered mechanics look like, shared by the views that draw them (EI-07: looks only):
## - each source boss's colours (WorldReader.FALLEN_SOURCES' ids): the Clockwork Judge gold, the Tidecaller sea blue,
##   the Gatekeeper stone amber, the Twin Wardens amber over violet. The emblem, the aura and the pack effects of a
##   remembered mechanic wear them, so the player sees whose mechanic comes without a word;
## - the ghost of a boss: its own model (BossModels, read with the stage) drawn as light, a tinted rim that brightens
##   at its edges and faint bands running up it, no texture. The emblem over The Fallen and the amber Warden's shade
##   are such ghosts;
## - whether a lane crosses a body (the shade's charge breaking the ward), for the lane's white-hot look.

## Each source boss's [primary, secondary] colours.
const COLOURS := {
	&"clockwork_judge": [Color(1.0, 0.78, 0.3), Color(1.0, 0.62, 0.12)],
	&"tidecaller": [Color(0.42, 0.86, 1.0), Color(0.1, 0.45, 0.9)],
	&"gatekeeper": [Color(0.95, 0.62, 0.3), Color(0.55, 0.45, 0.38)],
	&"twin_wardens": [Color("#FFB347"), Color("#B98CFF")],
}
## Each source boss's model ids (BossModels), the colour each ghost wears (0 primary, 1 secondary).
const MODELS := {
	&"clockwork_judge": [[&"boss_clockwork_judge", 0]],
	&"tidecaller": [[&"boss_tidecaller", 0]],
	&"gatekeeper": [[&"stone_sentinel", 0]],
	&"twin_wardens": [[&"boss_twin_warden_amber", 0], [&"boss_twin_warden_violet", 1]],
}
## The shade is the amber Warden's model.
const SHADE_MODEL := &"boss_twin_warden_amber"
## The sim's contact slack: a lane within this of a body touches it (EnemyAi.CONTACT_SLOP_M).
const CONTACT_M := 0.02
const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.3, 1.0);
uniform float alpha = 0.0;
uniform float clock = 0.0;
varying float height_m;

void vertex() {
	height_m = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float rim = (1.0 - facing) * (1.0 - facing);
	float bands = 0.8 + 0.2 * sin(height_m * 14.0 - clock * 3.0);
	ALBEDO = mix(tint.rgb, vec3(1.0), rim * 0.45) * (0.5 + 1.7 * rim) * bands;
	ALPHA = clamp(alpha * (0.22 + 0.95 * rim), 0.0, 1.0);
}
"""

static var _shader: Shader = null


## Source boss `source`'s [primary, secondary] colours (the Judge's for an unknown one).
static func colours(source: StringName) -> Array:
	return COLOURS.get(source, COLOURS[&"clockwork_judge"])


## The pack's colours for a remembered mechanic of `source` (PackFx.spawn's `colors`).
static func pack_colours(source: StringName) -> Dictionary:
	var c := colours(source)
	return {
		&"primary": (c[0] as Color).lightened(0.35),
		&"secondary": c[0],
		&"tertiary": c[1],
	}


## A new ghost material in `tint`.
static func ghost_material(tint: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GHOST_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", tint)
	return m


## A hidden ghost of model `id` (BossModels), its feet at the node's origin, its front +X, `height` m tall, wearing
## `mat` on every mesh; null when the model is missing.
static func ghost(id: StringName, mat: ShaderMaterial, height: float) -> Node3D:
	var m := BossModels.get_model(id)
	if m.is_empty():
		return null
	var root := Node3D.new()
	root.name = "Ghost_%s" % id
	root.visible = false
	var body: Node3D = null
	if m.get("skinned", false):
		body = (m["scene"] as PackedScene).instantiate() as Node3D
		body.transform = m["transform"]
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = m["mesh"]
		body = mi
	var box: AABB = m["aabb"]
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * (height / maxf(box.size.y, 0.01))
	holder.add_child(body)
	root.add_child(holder)
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var g := n as MeshInstance3D
		g.material_override = mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n: Node in root.find_children("*", "AnimationPlayer", true, false):
		(n as AnimationPlayer).autoplay = ""
	return root


## Whether lane `o` touches a body of `radius` at `at` (the lane's half width is the charger's own radius).
static func lane_crosses(o: Obb, at: Vector2, radius: float) -> bool:
	var d := at - o.center
	var u := clampf(d.dot(o.axis_u), -o.half.x, o.half.x)
	var v := clampf(d.dot(o.axis_v), -o.half.y, o.half.y)
	var near := o.center + o.axis_u * u + o.axis_v * v
	return near.distance_to(at) <= radius + CONTACT_M


## Where the line `from` → `to` first enters a square pillar of half side `half` at `c` grown by `grow`, as a share
## of the line (0..1), or -1 when it misses.
static func line_enters(from: Vector2, to: Vector2, c: Vector2, half: float, grow: float) -> float:
	var d := to - from
	var lo := 0.0
	var hi := 1.0
	var h := half + grow
	for axis in 2:
		var p := from[axis]
		var dv := d[axis]
		var a := c[axis] - h
		var b := c[axis] + h
		if absf(dv) < 0.00001:
			if p < a or p > b:
				return -1.0
			continue
		var t0 := (a - p) / dv
		var t1 := (b - p) / dv
		lo = maxf(lo, minf(t0, t1))
		hi = minf(hi, maxf(t0, t1))
		if lo > hi:
			return -1.0
	return lo
